// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAllocationStrategy,
    IGlobals,
    IGovernorTimelock,
    ILoanManagerLike,
    IPoolManager,
    IStrategyDeployer,
    IStrategyLike,
    IStrategyManager
} from "../../../contracts/interfaces/Interfaces.sol";

import {
    AaveV3StrategyInitializerParams,
    AllocationStrategyInitializerParams,
    SkyStrategyInitializerParams
} from "../../../contracts/interfaces/Interfaces.sol";

import { ProtocolActions } from "../../../contracts/ProtocolActions.sol";

import { UpgradeAddressRegistry } from "../UpgradeAddressRegistry.sol";

contract ModularReleaseBase is ProtocolActions, UpgradeAddressRegistry {

    /**************************************************************************************************************************************/
    /*** Enums                                                                                                                          ***/
    /**************************************************************************************************************************************/

    enum StrategyKind {
        Aave,
        Sky,
        Allocation
    }

    /**************************************************************************************************************************************/
    /*** Structs                                                                                                                        ***/
    /**************************************************************************************************************************************/

    struct Proposal {
        address target;
        bytes   data;
    }

    struct StrategySpecification {
        string       name;
        StrategyKind kind;
        address      delegate;
        address      managedWallet;
        address      asset;
        address      vault;
        uint256      liquidityCap;
        uint32       delegateFeeRate;
        uint32       protocolFeeRate;
    }

    /**************************************************************************************************************************************/
    /*** Variables                                                                                                                      ***/
    /**************************************************************************************************************************************/

    uint256 constant BOOTSTRAP_MINT    = 1e6;
    uint256 constant MAX_STRATEGY_DUST = 11;
    uint256 constant YIELD_CAP         = 1_000_000e6;  // TODO: Check if this value should be updated.

    uint32 constant USDC_PROTOCOL_FEE_RATE = 0.15e6;
    uint32 constant USDT_PROTOCOL_FEE_RATE = 0.125e6;
    uint32 constant USDG_PROTOCOL_FEE_RATE = 0.125e6;

    uint256 startingTime;

    address[] poolManagers;

    StrategySpecification[] specs;

    mapping(string => address) strategyManagers;
    mapping(string => address) managedWallets;

    /**************************************************************************************************************************************/
    /*** Upgrade Function                                                                                                               ***/
    /**************************************************************************************************************************************/

    function upgradeProtocol(bool attachAaveAndSkyStrategies) internal {
        deployContracts();
        configureGlobals();
        upgradeGlobalsAndSetupFactories();
        setupModularStrategies();
        upgradePools();
        attachModularStrategies(attachAaveAndSkyStrategies);
        setupManagedWallets();
    }

    /**************************************************************************************************************************************/
    /*** Step 1 - Deploy Contracts                                                                                                      ***/
    /**************************************************************************************************************************************/

    function deployContracts() internal {
        globalsV500Implementation             = deployFromFile("Contracts@28", "Globals");
        poolManagerV500Implementation         = deployFromFile("Contracts@28", "PoolManager");
        poolManagerV500Initializer            = deployFromFile("Contracts@28", "PoolManagerInitializer");
        poolManagerV500Migrator               = deployFromFile("Contracts@28", "PoolManagerMigrator");
        strategyManagerV100Implementation     = deployFromFile("Contracts@28", "StrategyManager");
        strategyManagerV100Initializer        = deployFromFile("Contracts@28", "StrategyManagerInitializer");
        modularAaveStrategyV100Implementation = deployFromFile("Contracts@28", "AaveV3Strategy");
        modularAaveStrategyV100Initializer    = deployFromFile("Contracts@28", "AaveV3StrategyInitializer");
        modularSkyStrategyV100Implementation  = deployFromFile("Contracts@28", "SkyStrategy");
        modularSkyStrategyV100Initializer     = deployFromFile("Contracts@28", "SkyStrategyInitializer");
        allocationStrategyV100Implementation  = deployFromFile("Contracts@28", "AllocationStrategy");
        allocationStrategyV100Initializer     = deployFromFile("Contracts@28", "AllocationStrategyInitializer");

        poolDeployerV500           = deployFromFile("Contracts@28", "PoolDeployer",              abi.encode(globals));
        strategyDeployerV100       = deployFromFile("Contracts@28", "StrategyDeployer",          abi.encode(globals));
        strategyManagerFactory     = deployFromFile("Contracts@28", "StrategyManagerFactory",    abi.encode(globals));
        modularAaveStrategyFactory = deployFromFile("Contracts@28", "AaveV3StrategyFactory",     abi.encode(globals));
        modularSkyStrategyFactory  = deployFromFile("Contracts@28", "SkyStrategyFactory",        abi.encode(globals));
        allocationStrategyFactory  = deployFromFile("Contracts@28", "AllocationStrategyFactory", abi.encode(globals));
        liquidityRouterV100        = deployFromFile("Contracts@28", "LiquidityRouter",           abi.encode(globals));
    }

    /**************************************************************************************************************************************/
    /*** Step 2 - Configure Globals                                                                                                     ***/
    /**************************************************************************************************************************************/

    function configureGlobals() internal {
        vm.startPrank(operationalAdmin);

        IGlobals(globals).setValidInstanceOf("STRATEGY_MANAGER_FACTORY",    strategyManagerFactory,     true);
        IGlobals(globals).setValidInstanceOf("UNDERLYING_STRATEGY_FACTORY", modularAaveStrategyFactory, true);
        IGlobals(globals).setValidInstanceOf("UNDERLYING_STRATEGY_FACTORY", modularSkyStrategyFactory,  true);
        IGlobals(globals).setValidInstanceOf("UNDERLYING_STRATEGY_FACTORY", allocationStrategyFactory,  true);
        IGlobals(globals).setValidInstanceOf("STRATEGY_VAULT",              AAVE_USDG,                  true);
        IGlobals(globals).setValidInstanceOf("LIQUIDITY_ROUTER",            liquidityRouterV100,        true);

        IGlobals(globals).setCanDeployFrom(poolManagerFactory,            poolDeployerV500, true);
        IGlobals(globals).setCanDeployFrom(withdrawalManagerQueueFactory, poolDeployerV500, true);

        IGlobals(globals).setCanDeployFrom(strategyManagerFactory,     strategyDeployerV100, true);
        IGlobals(globals).setCanDeployFrom(modularAaveStrategyFactory, strategyDeployerV100, true);
        IGlobals(globals).setCanDeployFrom(modularSkyStrategyFactory,  strategyDeployerV100, true);
        IGlobals(globals).setCanDeployFrom(allocationStrategyFactory,  strategyDeployerV100, true);

        // NOTE: Existing bootstrap mint for USDC and USDT are set from 1e5 to 1e6.
        IGlobals(globals).setBootstrapMint(USDC, BOOTSTRAP_MINT);
        IGlobals(globals).setBootstrapMint(USDT, BOOTSTRAP_MINT);
        IGlobals(globals).setBootstrapMint(USDG, BOOTSTRAP_MINT);

        vm.stopPrank();
    }

    /**************************************************************************************************************************************/
    /*** Step 3 - Upgrade Globals and Setup Factories (Timelocked)                                                                     ***/
    /**************************************************************************************************************************************/

    function upgradeGlobalsAndSetupFactories() internal {
        Proposal[] memory proposals = new Proposal[](12);

        // Globals
        proposals[0] = Proposal(globals, abi.encodeWithSignature("setImplementation(address)", globalsV500Implementation));

        // Pool Manager Factory
        proposals[1] = Proposal(
            poolManagerFactory,
            abi.encodeWithSignature(
                "registerImplementation(uint256,address,address)",
                500,
                poolManagerV500Implementation,
                poolManagerV500Initializer
            )
        );

        proposals[2] = Proposal(poolManagerFactory, abi.encodeWithSignature("setDefaultVersion(uint256)", 500));

        proposals[3] = Proposal(
            poolManagerFactory,
            abi.encodeWithSignature("enableUpgradePath(uint256,uint256,address)", 400, 500, poolManagerV500Migrator)
        );

        // Strategy Manager Factory
        proposals[4] = Proposal(
            strategyManagerFactory,
            abi.encodeWithSignature(
                "registerImplementation(uint256,address,address)",
                100,
                strategyManagerV100Implementation,
                strategyManagerV100Initializer
            )
        );

        proposals[5] = Proposal(strategyManagerFactory, abi.encodeWithSignature("setDefaultVersion(uint256)", 100));

        // Modular Aave Strategy Factory
        proposals[6] = Proposal(
            modularAaveStrategyFactory,
            abi.encodeWithSignature(
                "registerImplementation(uint256,address,address)",
                100,
                modularAaveStrategyV100Implementation,
                modularAaveStrategyV100Initializer
            )
        );

        proposals[7] = Proposal(modularAaveStrategyFactory, abi.encodeWithSignature("setDefaultVersion(uint256)", 100));

        // Modular Sky Strategy Factory
        proposals[8] = Proposal(
            modularSkyStrategyFactory,
            abi.encodeWithSignature(
                "registerImplementation(uint256,address,address)",
                100,
                modularSkyStrategyV100Implementation,
                modularSkyStrategyV100Initializer
            )
        );

        proposals[9] = Proposal(modularSkyStrategyFactory, abi.encodeWithSignature("setDefaultVersion(uint256)", 100));

        // Allocation Strategy Factory
        proposals[10] = Proposal(
            allocationStrategyFactory,
            abi.encodeWithSignature(
                "registerImplementation(uint256,address,address)",
                100,
                allocationStrategyV100Implementation,
                allocationStrategyV100Initializer
            )
        );

        proposals[11] = Proposal(allocationStrategyFactory, abi.encodeWithSignature("setDefaultVersion(uint256)", 100));

        /**********************************************************************************************************************************/
        /*** Step 3.1 - Schedule Proposals                                                                                              ***/
        /**********************************************************************************************************************************/

        uint256[] memory proposalIds = scheduleProposals(proposals);

        /**********************************************************************************************************************************/
        /*** Step 3.2 - Execute Proposals                                                                                               ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + 4 days);

        executeProposals(proposalIds, proposals);
    }

    /**************************************************************************************************************************************/
    /*** Step 4 - Setup Modular Strategies                                                                                              ***/
    /**************************************************************************************************************************************/

    function setupModularStrategies() internal {
        specs.push(StrategySpecification({
            name:            "Aave Strategy USDC",
            kind:            StrategyKind.Aave,
            delegate:        aaveStrategyUSDCDelegate,
            managedWallet:   address(0),
            asset:           USDC,
            vault:           aUsdc,
            liquidityCap:    0,
            delegateFeeRate: 0,
            protocolFeeRate: USDC_PROTOCOL_FEE_RATE
        }));

        specs.push(StrategySpecification({
            name:            "Aave Strategy USDT",
            kind:            StrategyKind.Aave,
            delegate:        aaveStrategyUSDTDelegate,
            managedWallet:   address(0),
            asset:           USDT,
            vault:           aUsdt,
            liquidityCap:    0,
            delegateFeeRate: 0,
            protocolFeeRate: USDT_PROTOCOL_FEE_RATE
        }));

        specs.push(StrategySpecification({
            name:            "Aave Strategy USDG",
            kind:            StrategyKind.Aave,
            delegate:        aaveStrategyUSDGDelegate,
            managedWallet:   address(0),
            asset:           USDG,
            vault:           AAVE_USDG,
            liquidityCap:    0,
            delegateFeeRate: 0,
            protocolFeeRate: USDG_PROTOCOL_FEE_RATE
        }));

        specs.push(StrategySpecification({
            name:            "Sky Strategy USDC",
            kind:            StrategyKind.Sky,
            delegate:        skyStrategyUSDCDelegate,
            managedWallet:   address(0),
            asset:           USDC,
            vault:           address(0),
            liquidityCap:    0,
            delegateFeeRate: 0,
            protocolFeeRate: USDC_PROTOCOL_FEE_RATE
        }));

        specs.push(StrategySpecification({
            name:            "LP DEX USDC",
            kind:            StrategyKind.Allocation,
            delegate:        lpDexUSDCDelegate,
            managedWallet:   lpDexUSDCManagedWallet,
            asset:           USDC,
            vault:           address(0),
            liquidityCap:    0,
            delegateFeeRate: 0,
            protocolFeeRate: USDC_PROTOCOL_FEE_RATE
        }));

        specs.push(StrategySpecification({
            name:            "Cross Pool USDC",
            kind:            StrategyKind.Allocation,
            delegate:        crossPoolUSDCDelegate,
            managedWallet:   crossPoolUSDCManagedWallet,
            asset:           USDC,
            vault:           address(0),
            liquidityCap:    0,
            delegateFeeRate: 0,
            protocolFeeRate: USDC_PROTOCOL_FEE_RATE
        }));

        specs.push(StrategySpecification({
            name:            "TBills USDC",
            kind:            StrategyKind.Allocation,
            delegate:        tBillsUSDCDelegate,
            managedWallet:   tBillsUSDCManagedWallet,
            asset:           USDC,
            vault:           address(0),
            liquidityCap:    0,
            delegateFeeRate: 0,
            protocolFeeRate: USDC_PROTOCOL_FEE_RATE
        }));

        specs.push(StrategySpecification({
            name:            "PYUSD USDC",
            kind:            StrategyKind.Allocation,
            delegate:        pyusdUSDCDelegate,
            managedWallet:   pyusdUSDCManagedWallet,
            asset:           USDC,
            vault:           address(0),
            liquidityCap:    0,
            delegateFeeRate: 0,
            protocolFeeRate: USDC_PROTOCOL_FEE_RATE
        }));

        specs.push(StrategySpecification({
            name:            "Spreads USDT",
            kind:            StrategyKind.Allocation,
            delegate:        spreadsUSDTDelegate,
            managedWallet:   spreadsUSDTManagedWallet,
            asset:           USDT,
            vault:           address(0),
            liquidityCap:    0,
            delegateFeeRate: 0,
            protocolFeeRate: USDT_PROTOCOL_FEE_RATE
        }));

        specs.push(StrategySpecification({
            name:            "LP DEX USDT",
            kind:            StrategyKind.Allocation,
            delegate:        lpDexUSDTDelegate,
            managedWallet:   lpDexUSDTManagedWallet,
            asset:           USDT,
            vault:           address(0),
            liquidityCap:    0,
            delegateFeeRate: 0,
            protocolFeeRate: USDT_PROTOCOL_FEE_RATE
        }));

        specs.push(StrategySpecification({
            name:            "Cross Pool USDT",
            kind:            StrategyKind.Allocation,
            delegate:        crossPoolUSDTDelegate,
            managedWallet:   crossPoolUSDTManagedWallet,
            asset:           USDT,
            vault:           address(0),
            liquidityCap:    0,
            delegateFeeRate: 0,
            protocolFeeRate: USDT_PROTOCOL_FEE_RATE
        }));

        specs.push(StrategySpecification({
            name:            "TBills USDT",
            kind:            StrategyKind.Allocation,
            delegate:        tBillsUSDTDelegate,
            managedWallet:   tBillsUSDTManagedWallet,
            asset:           USDT,
            vault:           address(0),
            liquidityCap:    0,
            delegateFeeRate: 0,
            protocolFeeRate: USDT_PROTOCOL_FEE_RATE
        }));

        specs.push(StrategySpecification({
            name:            "PYUSD USDT",
            kind:            StrategyKind.Allocation,
            delegate:        pyusdUSDTDelegate,
            managedWallet:   pyusdUSDTManagedWallet,
            asset:           USDT,
            vault:           address(0),
            liquidityCap:    0,
            delegateFeeRate: 0,
            protocolFeeRate: USDT_PROTOCOL_FEE_RATE
        }));

        specs.push(StrategySpecification({
            name:            "LP DEX USDG",
            kind:            StrategyKind.Allocation,
            delegate:        lpDexUSDGDelegate,
            managedWallet:   lpDexUSDGManagedWallet,
            asset:           USDG,
            vault:           address(0),
            liquidityCap:    0,
            delegateFeeRate: 0,
            protocolFeeRate: USDG_PROTOCOL_FEE_RATE
        }));

        specs.push(StrategySpecification({
            name:            "Cross Pool USDG",
            kind:            StrategyKind.Allocation,
            delegate:        crossPoolUSDGDelegate,
            managedWallet:   crossPoolUSDGManagedWallet,
            asset:           USDG,
            vault:           address(0),
            liquidityCap:    0,
            delegateFeeRate: 0,
            protocolFeeRate: USDG_PROTOCOL_FEE_RATE
        }));

        specs.push(StrategySpecification({
            name:            "TBills USDG",
            kind:            StrategyKind.Allocation,
            delegate:        tBillsUSDGDelegate,
            managedWallet:   tBillsUSDGManagedWallet,
            asset:           USDG,
            vault:           address(0),
            liquidityCap:    0,
            delegateFeeRate: 0,
            protocolFeeRate: USDG_PROTOCOL_FEE_RATE
        }));

        specs.push(StrategySpecification({
            name:            "PYUSD USDG",
            kind:            StrategyKind.Allocation,
            delegate:        pyusdUSDGDelegate,
            managedWallet:   pyusdUSDGManagedWallet,
            asset:           USDG,
            vault:           address(0),
            liquidityCap:    0,
            delegateFeeRate: 0,
            protocolFeeRate: USDG_PROTOCOL_FEE_RATE
        }));

        /**********************************************************************************************************************************/
        /*** Step 4.1 - Preparation                                                                                                     ***/
        /**********************************************************************************************************************************/

        for (uint256 i; i < specs.length; i++) {
            erc20_mint(specs[i].asset, specs[i].delegate, BOOTSTRAP_MINT);
            erc20_approve(specs[i].asset, specs[i].delegate, strategyDeployerV100, BOOTSTRAP_MINT);

            vm.prank(operationalAdmin);
            IGlobals(globals).setValidStrategyDelegate(specs[i].delegate, true);
        }

        /**********************************************************************************************************************************/
        /*** Step 4.2 - Deployment                                                                                                      ***/
        /**********************************************************************************************************************************/

        for (uint256 i; i < specs.length; i++) {
            StrategySpecification memory spec = specs[i];

            vm.prank(spec.delegate);
            ( address strategyManager, ) = IStrategyDeployer(strategyDeployerV100).deploy({
                strategyManagerFactory: strategyManagerFactory,
                strategyFactory:        strategyFactory(spec.kind),
                strategyLiquidityCap:   spec.liquidityCap,
                strategyDeploymentData: buildDeploymentData(spec),
                bootstrapFundingData:   ""
            });

            strategyManagers[spec.name] = strategyManager;
        }

        /**********************************************************************************************************************************/
        /*** Step 4.3 - Activation                                                                                                      ***/
        /**********************************************************************************************************************************/

        for (uint256 i; i < specs.length; i++) {
            vm.prank(operationalAdmin);
            IGlobals(globals).activateStrategyManager(strategyManagers[specs[i].name]);
        }
    }

    /**************************************************************************************************************************************/
    /*** Step 5 - Upgrade Pools                                                                                                         ***/
    /**************************************************************************************************************************************/

    function upgradePools() internal {
        poolManagers.push(syrupUSDCPoolManager);
        poolManagers.push(syrupUSDTPoolManager);
        poolManagers.push(syrupUSDGPoolManager);
        poolManagers.push(securedLendingUSDCPoolManager);

        /**********************************************************************************************************************************/
        /*** Step 5.1 - Cleanup Old Strategies                                                                                          ***/
        /**********************************************************************************************************************************/

        address[3] memory fixedTermLoanManagers = [
            syrupUSDCFixedTermLoanManager,
            syrupUSDTFixedTermLoanManager,
            securedLendingUSDCFixedTermLoanManager
        ];

        for (uint256 i; i < fixedTermLoanManagers.length; i++) {
            assertEq(ILoanManagerLike(fixedTermLoanManagers[i]).assetsUnderManagement(), 0);
            assertEq(ILoanManagerLike(fixedTermLoanManagers[i]).unrealizedLosses(),      0);
        }

        address[5] memory legacyStrategies = [
            syrupUSDCAaveStrategy,
            syrupUSDCSkyStrategy,
            syrupUSDTAaveStrategy,
            securedLendingUSDCAaveStrategy,
            securedLendingUSDCSkyStrategy
        ];

        for (uint256 i; i < legacyStrategies.length; i++) {
            assertLe(IStrategyLike(legacyStrategies[i]).assetsUnderManagement(), MAX_STRATEGY_DUST);
            assertEq(IStrategyLike(legacyStrategies[i]).unrealizedLosses(),      0);
        }

        /**********************************************************************************************************************************/
        /*** Step 5.2 - Perform Upgrades                                                                                                ***/
        /**********************************************************************************************************************************/

        for (uint256 i; i < poolManagers.length; i++) {
            uint256 totalAssets      = IPoolManager(poolManagers[i]).totalAssets();
            uint256 unrealizedLosses = IPoolManager(poolManagers[i]).unrealizedLosses();

            vm.prank(securityAdmin);
            IPoolManager(poolManagers[i]).upgrade(500, "");

            // NOTE: Legacy strategies can contain dust, which decreases AUM after they are removed.
            assertApproxEqAbs(IPoolManager(poolManagers[i]).totalAssets(), totalAssets, 2 * MAX_STRATEGY_DUST);

            assertEq(IPoolManager(poolManagers[i]).unrealizedLosses(), unrealizedLosses);
        }
    }

    /**************************************************************************************************************************************/
    /*** Step 6 - Attach Modular Strategies (Timelocked)                                                                                ***/
    /**************************************************************************************************************************************/

    function attachModularStrategies(bool attachAaveAndSkyStrategies) internal {
        Proposal[] memory allProposals = new Proposal[](21);

        uint256 count;

        // Syrup USDC
        if (attachAaveAndSkyStrategies) {
            allProposals[count++] = Proposal(
                syrupUSDCPoolManager,
                abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["Aave Strategy USDC"])
            );

            allProposals[count++] = Proposal(
                syrupUSDCPoolManager,
                abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["Sky Strategy USDC"])
            );
        }

        allProposals[count++] = Proposal(
            syrupUSDCPoolManager,
            abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["LP DEX USDC"])
        );

        allProposals[count++] = Proposal(
            syrupUSDCPoolManager,
            abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["Cross Pool USDC"])
        );

        allProposals[count++] = Proposal(
            syrupUSDCPoolManager,
            abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["TBills USDC"])
        );

        allProposals[count++] = Proposal(
            syrupUSDCPoolManager,
            abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["PYUSD USDC"])
        );

        // Syrup USDT
        if (attachAaveAndSkyStrategies) {
            allProposals[count++] = Proposal(
                syrupUSDTPoolManager,
                abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["Aave Strategy USDT"])
            );
        }

        allProposals[count++] = Proposal(
            syrupUSDTPoolManager,
            abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["LP DEX USDT"])
        );

        allProposals[count++] = Proposal(
            syrupUSDTPoolManager,
            abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["Cross Pool USDT"])
        );

        allProposals[count++] = Proposal(
            syrupUSDTPoolManager,
            abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["TBills USDT"])
        );

        allProposals[count++] = Proposal(
            syrupUSDTPoolManager,
            abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["PYUSD USDT"])
        );

        allProposals[count++] = Proposal(
            syrupUSDTPoolManager,
            abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["Spreads USDT"])
        );

        // Syrup USDG
        if (attachAaveAndSkyStrategies) {
            allProposals[count++] = Proposal(
                syrupUSDGPoolManager,
                abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["Aave Strategy USDG"])
            );
        }

        allProposals[count++] = Proposal(
            syrupUSDGPoolManager,
            abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["LP DEX USDG"])
        );

        allProposals[count++] = Proposal(
            syrupUSDGPoolManager,
            abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["Cross Pool USDG"])
        );

        allProposals[count++] = Proposal(
            syrupUSDGPoolManager,
            abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["TBills USDG"])
        );

        allProposals[count++] = Proposal(
            syrupUSDGPoolManager,
            abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["PYUSD USDG"])
        );

        // MISL
        if (attachAaveAndSkyStrategies) {
            allProposals[count++] = Proposal(
                securedLendingUSDCPoolManager,
                abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["Aave Strategy USDC"])
            );

            allProposals[count++] = Proposal(
                securedLendingUSDCPoolManager,
                abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["Sky Strategy USDC"])
            );
        }

        allProposals[count++] = Proposal(
            securedLendingUSDCPoolManager,
            abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["TBills USDC"])
        );

        allProposals[count++] = Proposal(
            securedLendingUSDCPoolManager,
            abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["PYUSD USDC"])
        );

        Proposal[] memory proposals = new Proposal[](count);

        for (uint256 i; i < count; i++) {
            proposals[i] = allProposals[i];
        }

        /**********************************************************************************************************************************/
        /*** Step 6.1 - Schedule Proposals                                                                                              ***/
        /**********************************************************************************************************************************/

        uint256[] memory proposalIds = scheduleProposals(proposals);

        /**********************************************************************************************************************************/
        /*** Step 6.2 - Execute Proposals                                                                                               ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + 8 days);

        executeProposals(proposalIds, proposals);
    }

    /**************************************************************************************************************************************/
    /*** Step 7 - Setup Managed Wallets                                                                                                 ***/
    /**************************************************************************************************************************************/

    function setupManagedWallets() internal {
        for (uint256 i; i < specs.length; i++) {
            if (specs[i].kind == StrategyKind.Allocation) {
                managedWallets[specs[i].name] = specs[i].managedWallet;
            }
        }

        /**********************************************************************************************************************************/
        /*** Step 7.1 - Whitelist Managed Wallets                                                                                       ***/
        /**********************************************************************************************************************************/

        for (uint256 i; i < specs.length; i++) {
            if (specs[i].kind == StrategyKind.Allocation) {
                vm.prank(operationalAdmin);
                IGlobals(globals).setValidMapleManagedWallet(managedWallets[specs[i].name], true);
            }
        }

        /**********************************************************************************************************************************/
        /*** Step 7.2 - Set Managed Wallet Permissions                                                                                  ***/
        /**********************************************************************************************************************************/

        address[] memory addresses = new address[](1);
        bool[]    memory flags     = new bool[](1);

        for (uint256 i; i < specs.length; i++) {
            if (specs[i].kind != StrategyKind.Allocation) continue;

            address underlyingStrategy = IStrategyManager(strategyManagers[specs[i].name]).underlyingStrategy();

            addresses[0] = managedWallets[specs[i].name];
            flags[0]     = true;

            vm.prank(specs[i].delegate);
            IAllocationStrategy(underlyingStrategy).setPermissions(addresses, flags, flags, flags);
        }
    }

    /**************************************************************************************************************************************/
    /*** Utility Functions                                                                                                              ***/
    /**************************************************************************************************************************************/

    function buildDeploymentData(StrategySpecification memory spec_) internal view returns (bytes memory data_) {
        if (spec_.kind == StrategyKind.Aave) {
            data_ = abi.encode(AaveV3StrategyInitializerParams({
                aaveToken:                   spec_.vault,
                strategyDelegateFeeRate:     spec_.delegateFeeRate,
                strategyProtocolFeeRate:     spec_.protocolFeeRate,
                referralCode:                0,
                useVirtualUnderlyingBalance: true,
                strategyMetadata:            spec_.name
            }));
        }

        if (spec_.kind == StrategyKind.Sky) {
            data_ = abi.encode(SkyStrategyInitializerParams({
                fundsAsset:              spec_.asset,
                psm:                     USDS_LITE_PSM,
                savingsUsds:             SAVINGS_USDS,
                strategyDelegateFeeRate: spec_.delegateFeeRate,
                strategyProtocolFeeRate: spec_.protocolFeeRate,
                referralCode:            0,
                strategyMetadata:        spec_.name
            }));
        }

        if (spec_.kind == StrategyKind.Allocation) {
            data_ = abi.encode(AllocationStrategyInitializerParams({
                fundsAsset:              spec_.asset,
                strategyMetadata:        spec_.name,
                strategyDelegateFeeRate: spec_.delegateFeeRate,
                strategyProtocolFeeRate: spec_.protocolFeeRate,
                yieldCap:                YIELD_CAP
            }));
        }
    }

    function executeProposals(uint256[] memory proposalIds_, Proposal[] memory proposals_) internal {
        ( address[] memory targets_, bytes[] memory data_ ) = unzip(proposals_);

        vm.prank(operationalAdmin);
        IGovernorTimelock(timelock).executeProposals(proposalIds_, targets_, data_);
    }

    function strategyFactory(StrategyKind kind_) internal view returns (address factory_) {
        if (kind_ == StrategyKind.Aave)       return modularAaveStrategyFactory;
        if (kind_ == StrategyKind.Sky)        return modularSkyStrategyFactory;
        if (kind_ == StrategyKind.Allocation) return allocationStrategyFactory;
    }

    function scheduleProposals(Proposal[] memory proposals_) internal returns (uint256[] memory proposalIds_) {
        uint256 latestProposalId = IGovernorTimelock(timelock).latestProposalId();

        ( address[] memory targets_, bytes[] memory data_ ) = unzip(proposals_);

        vm.prank(daoMultisig);
        IGovernorTimelock(timelock).scheduleProposals(targets_, data_);

        proposalIds_ = new uint256[](proposals_.length);

        for (uint256 i; i < proposals_.length; i++) {
            proposalIds_[i] = latestProposalId + i + 1;
        }
    }

    function unzip(Proposal[] memory proposals_) internal pure returns (address[] memory targets_, bytes[] memory data_) {
        targets_ = new address[](proposals_.length);
        data_    = new bytes[](proposals_.length);

        for (uint256 i; i < proposals_.length; i++) {
            targets_[i] = proposals_[i].target;
            data_[i]    = proposals_[i].data;
        }
    }

}
