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
    IStrategyManager,
    IWithdrawalManagerQueue
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
        bytes data;
    }

    struct StrategySpecification {
        string name;
        string metadata;
        StrategyKind kind;
        address delegate;
        address asset;
        address vault;
        uint256 liquidityCap;
        uint32 delegateFeeRate;
        uint32 protocolFeeRate;
    }

    /**************************************************************************************************************************************/
    /*** Variables                                                                                                                      ***/
    /**************************************************************************************************************************************/

    string constant CONFIGURED_STRATEGY = "PYUSD - USDC";

    address liquidityRouterBot = makeAddr("liquidityRouterBot");

    address aaveStrategyUSDCDelegate = makeAddr("aaveStrategyUSDCDelegate");
    address aaveStrategyUSDTDelegate = makeAddr("aaveStrategyUSDTDelegate");
    address aaveStrategyUSDGDelegate = makeAddr("aaveStrategyUSDGDelegate");
    address skyStrategyUSDCDelegate  = makeAddr("skyStrategyUSDCDelegate");

    uint256 constant BOOTSTRAP_MINT          = 1e6;
    uint256 constant CONFIGURED_STRATEGY_CAP = type(uint256).max;
    uint256 constant DEPLOYMENT_CAP          = 10_000e6;
    uint256 constant MAX_STRATEGY_DUST       = 11;
    uint256 constant YIELD_CAP               = 10_000e6;

    uint32 constant USDC_PROTOCOL_FEE_RATE = 0.15e6;
    uint32 constant USDT_PROTOCOL_FEE_RATE = 0.125e6;
    uint32 constant USDG_PROTOCOL_FEE_RATE = 0.125e6;

    uint256 startingTime;

    address[] public poolManagers;
    address[] public openTermLoanManagers;

    StrategySpecification[] specs;

    mapping(string => address) public strategyManagers;
    mapping(string => address[]) public managedWallets;

    /**************************************************************************************************************************************/
    /*** Upgrade Function                                                                                                               ***/
    /**************************************************************************************************************************************/

    function upgradeProtocol(bool attachAaveAndSkyStrategies) public {
        // The timelock warps are measured from here, so callers that run the upgrade from a separate instance still line up.
        startingTime = block.timestamp;

        defineStrategySpecifications();
        deployContracts();
        configureGlobals();
        upgradeGlobalsAndSetupFactories();
        upgradePools();
        configureCapsAndWhitelistDelegates();
        deployModularStrategies();
        attachModularStrategies(attachAaveAndSkyStrategies);
        setupManagedWallets();
        configurePermissionsAndWalletCapOnAllocationStrategy();
        activateRemainingStrategyManagers();
    }

    /**************************************************************************************************************************************/
    /*** Strategy Specifications                                                                                                        ***/
    /**************************************************************************************************************************************/

    function defineStrategySpecifications() internal {
        // NOTE: The Aave and Sky strategies are neither deployed nor attached as part of the modular release. They are included
        //       here only to prove that the modular system works with those underlyings as well.
        specs.push(
            StrategySpecification({
                name: "Aave Strategy USDC",
                metadata: "Aave Strategy USDC",
                kind: StrategyKind.Aave,
                delegate: aaveStrategyUSDCDelegate,
                asset: USDC,
                vault: aUsdc,
                liquidityCap: 0,
                delegateFeeRate: 0,
                protocolFeeRate: USDC_PROTOCOL_FEE_RATE
            })
        );

        specs.push(
            StrategySpecification({
                name: "Aave Strategy USDT",
                metadata: "Aave Strategy USDT",
                kind: StrategyKind.Aave,
                delegate: aaveStrategyUSDTDelegate,
                asset: USDT,
                vault: aUsdt,
                liquidityCap: 0,
                delegateFeeRate: 0,
                protocolFeeRate: USDT_PROTOCOL_FEE_RATE
            })
        );

        specs.push(
            StrategySpecification({
                name: "Aave Strategy USDG",
                metadata: "Aave Strategy USDG",
                kind: StrategyKind.Aave,
                delegate: aaveStrategyUSDGDelegate,
                asset: USDG,
                vault: AAVE_USDG,
                liquidityCap: 0,
                delegateFeeRate: 0,
                protocolFeeRate: USDG_PROTOCOL_FEE_RATE
            })
        );

        specs.push(
            StrategySpecification({
                name: "Sky Strategy USDC",
                metadata: "Sky Strategy USDC",
                kind: StrategyKind.Sky,
                delegate: skyStrategyUSDCDelegate,
                asset: USDC,
                vault: address(0),
                liquidityCap: 0,
                delegateFeeRate: 0,
                protocolFeeRate: USDC_PROTOCOL_FEE_RATE
            })
        );

        specs.push(
            StrategySpecification({
                name: "DEX LP - USDC",
                metadata: "DEX LP",
                kind: StrategyKind.Allocation,
                delegate: dexLpUSDCDelegate,
                asset: USDC,
                vault: address(0),
                liquidityCap: 0,
                delegateFeeRate: 0,
                protocolFeeRate: USDC_PROTOCOL_FEE_RATE
            })
        );

        specs.push(
            StrategySpecification({
                name: "PYUSD - USDC",
                metadata: "U.S. Treasuries",
                kind: StrategyKind.Allocation,
                delegate: pyusdUSDCDelegate,
                asset: USDC,
                vault: address(0),
                liquidityCap: 0,
                delegateFeeRate: 0,
                protocolFeeRate: USDC_PROTOCOL_FEE_RATE
            })
        );

        specs.push(
            StrategySpecification({
                name: "PYUSD - USDC (PPOA only)",
                metadata: "U.S. Treasuries",
                kind: StrategyKind.Allocation,
                delegate: pyusdMislUSDCDelegate,
                asset: USDC,
                vault: address(0),
                liquidityCap: 0,
                delegateFeeRate: 0,
                protocolFeeRate: USDC_PROTOCOL_FEE_RATE
            })
        );

        specs.push(
            StrategySpecification({
                name: "USDtb - USDC",
                metadata: "U.S. Treasuries",
                kind: StrategyKind.Allocation,
                delegate: usdtbUSDCDelegate,
                asset: USDC,
                vault: address(0),
                liquidityCap: 0,
                delegateFeeRate: 0,
                protocolFeeRate: USDC_PROTOCOL_FEE_RATE
            })
        );

        specs.push(
            StrategySpecification({
                name: "USTB - USDC",
                metadata: "U.S. Treasuries",
                kind: StrategyKind.Allocation,
                delegate: ustbUSDCDelegate,
                asset: USDC,
                vault: address(0),
                liquidityCap: 0,
                delegateFeeRate: 0,
                protocolFeeRate: USDC_PROTOCOL_FEE_RATE
            })
        );

        specs.push(
            StrategySpecification({
                name: "USTB - USDC (PPOA only)",
                metadata: "U.S. Treasuries",
                kind: StrategyKind.Allocation,
                delegate: ustbMislUSDCDelegate,
                asset: USDC,
                vault: address(0),
                liquidityCap: 0,
                delegateFeeRate: 0,
                protocolFeeRate: USDC_PROTOCOL_FEE_RATE
            })
        );

        specs.push(
            StrategySpecification({
                name: "DEX LP - USDT",
                metadata: "DEX LP",
                kind: StrategyKind.Allocation,
                delegate: dexLpUSDTDelegate,
                asset: USDT,
                vault: address(0),
                liquidityCap: 0,
                delegateFeeRate: 0,
                protocolFeeRate: USDT_PROTOCOL_FEE_RATE
            })
        );

        specs.push(
            StrategySpecification({
                name: "Basis - USDT",
                metadata: "Maple Trading",
                kind: StrategyKind.Allocation,
                delegate: basisUSDTDelegate,
                asset: USDT,
                vault: address(0),
                liquidityCap: 0,
                delegateFeeRate: 0,
                protocolFeeRate: USDT_PROTOCOL_FEE_RATE
            })
        );

        specs.push(
            StrategySpecification({
                name: "PYUSD - USDT",
                metadata: "U.S. Treasuries",
                kind: StrategyKind.Allocation,
                delegate: pyusdUSDTDelegate,
                asset: USDT,
                vault: address(0),
                liquidityCap: 0,
                delegateFeeRate: 0,
                protocolFeeRate: USDT_PROTOCOL_FEE_RATE
            })
        );

        specs.push(
            StrategySpecification({
                name: "USDtb - USDT",
                metadata: "U.S. Treasuries",
                kind: StrategyKind.Allocation,
                delegate: usdtbUSDTDelegate,
                asset: USDT,
                vault: address(0),
                liquidityCap: 0,
                delegateFeeRate: 0,
                protocolFeeRate: USDT_PROTOCOL_FEE_RATE
            })
        );

        specs.push(
            StrategySpecification({
                name: "USTB - USDT",
                metadata: "U.S. Treasuries",
                kind: StrategyKind.Allocation,
                delegate: ustbUSDTDelegate,
                asset: USDT,
                vault: address(0),
                liquidityCap: 0,
                delegateFeeRate: 0,
                protocolFeeRate: USDT_PROTOCOL_FEE_RATE
            })
        );

        specs.push(
            StrategySpecification({
                name: "DEX LP - USDG",
                metadata: "DEX LP",
                kind: StrategyKind.Allocation,
                delegate: dexLpUSDGDelegate,
                asset: USDG,
                vault: address(0),
                liquidityCap: 0,
                delegateFeeRate: 0,
                protocolFeeRate: USDG_PROTOCOL_FEE_RATE
            })
        );

        specs.push(
            StrategySpecification({
                name: "PYUSD - USDG",
                metadata: "U.S. Treasuries",
                kind: StrategyKind.Allocation,
                delegate: pyusdUSDGDelegate,
                asset: USDG,
                vault: address(0),
                liquidityCap: 0,
                delegateFeeRate: 0,
                protocolFeeRate: USDG_PROTOCOL_FEE_RATE
            })
        );

        specs.push(
            StrategySpecification({
                name: "DeFi - USDC",
                metadata: "DeFi",
                kind: StrategyKind.Allocation,
                delegate: defiUSDCDelegate,
                asset: USDC,
                vault: address(0),
                liquidityCap: 0,
                delegateFeeRate: 0,
                protocolFeeRate: USDC_PROTOCOL_FEE_RATE
            })
        );

        specs.push(
            StrategySpecification({
                name: "Aave V3 - USDC",
                metadata: "DeFi",
                kind: StrategyKind.Aave,
                delegate: aaveV3USDCDelegate,
                asset: USDC,
                vault: aUsdc,
                liquidityCap: 0,
                delegateFeeRate: 0,
                protocolFeeRate: USDC_PROTOCOL_FEE_RATE
            })
        );

        specs.push(
            StrategySpecification({
                name: "DeFi - USDT",
                metadata: "DeFi",
                kind: StrategyKind.Allocation,
                delegate: defiUSDTDelegate,
                asset: USDT,
                vault: address(0),
                liquidityCap: 0,
                delegateFeeRate: 0,
                protocolFeeRate: USDT_PROTOCOL_FEE_RATE
            })
        );

        specs.push(
            StrategySpecification({
                name: "Aave V3 - USDT",
                metadata: "DeFi",
                kind: StrategyKind.Aave,
                delegate: aaveV3USDTDelegate,
                asset: USDT,
                vault: aUsdt,
                liquidityCap: 0,
                delegateFeeRate: 0,
                protocolFeeRate: USDT_PROTOCOL_FEE_RATE
            })
        );

        specs.push(
            StrategySpecification({
                name: "DeFi - USDG",
                metadata: "DeFi",
                kind: StrategyKind.Allocation,
                delegate: defiUSDGDelegate,
                asset: USDG,
                vault: address(0),
                liquidityCap: 0,
                delegateFeeRate: 0,
                protocolFeeRate: USDG_PROTOCOL_FEE_RATE
            })
        );

        defineManagedWallets();
    }

    function defineManagedWallets() internal {
        managedWallets["DEX LP - USDC"].push(dexLpUSDC_syrupUSDC_managedWallet);

        managedWallets["PYUSD - USDC"].push(pyusdUSDC_syrupUSDC_managedWallet);
        managedWallets["PYUSD - USDC"].push(pyusdUSDC_securedLending2USDC_managedWallet);

        managedWallets["PYUSD - USDC (PPOA only)"].push(pyusdMislUSDC_securedLendingUSDC_managedWallet);

        managedWallets["USDtb - USDC"].push(usdtbUSDC_syrupUSDC_managedWallet);
        managedWallets["USDtb - USDC"].push(usdtbUSDC_securedLending2USDC_managedWallet);

        managedWallets["USTB - USDC"].push(ustbUSDC_syrupUSDC_managedWallet);
        managedWallets["USTB - USDC"].push(ustbUSDC_securedLending2USDC_managedWallet);

        managedWallets["USTB - USDC (PPOA only)"].push(ustbMislUSDC_securedLendingUSDC_managedWallet);

        managedWallets["DEX LP - USDT"].push(dexLpUSDT_syrupUSDT_managedWallet);
        managedWallets["Basis - USDT"].push(basisUSDT_syrupUSDT_managedWallet);
        managedWallets["PYUSD - USDT"].push(pyusdUSDT_syrupUSDT_managedWallet);
        managedWallets["USDtb - USDT"].push(usdtbUSDT_syrupUSDT_managedWallet);
        managedWallets["USTB - USDT"].push(ustbUSDT_syrupUSDT_managedWallet);

        managedWallets["DEX LP - USDG"].push(dexLpUSDG_syrupUSDG_managedWallet);
        managedWallets["PYUSD - USDG"].push(pyusdUSDG_syrupUSDG_managedWallet);

        managedWallets["DeFi - USDC"].push(defiUSDC_syrupUSDC_managedWallet);
        managedWallets["DeFi - USDT"].push(defiUSDT_syrupUSDT_managedWallet);
        managedWallets["DeFi - USDG"].push(defiUSDG_syrupUSDG_managedWallet);
    }

    /**************************************************************************************************************************************/
    /*** Step 1 - Deploy Contracts                                                                                                      ***/
    /**************************************************************************************************************************************/

    function deployContracts() internal {
        deployFromFileTo("Contracts@34", "Globals", globalsV500Implementation);
        deployFromFileTo("Contracts@34", "PoolManager", PoolManagerV500Implementation);
        deployFromFileTo("Contracts@34", "PoolManagerInitializer", PoolManagerV500Initializer);
        deployFromFileTo("Contracts@34", "PoolManagerMigrator", PoolManagerV500Migrator);
        deployFromFileTo("Contracts@34", "WithdrawalManagerQueue", WithdrawalManagerQueueV201Implementation);
        deployFromFileTo("Contracts@34", "WithdrawalManagerQueueInitializer", WithdrawalManagerQueueV201Initializer);
        deployFromFileTo("Contracts@34", "StrategyManager", strategyManagerV100Implementation);
        deployFromFileTo("Contracts@34", "StrategyManagerInitializer", strategyManagerV100Initializer);
        deployFromFileTo("Contracts@34", "AaveV3Strategy", modularAaveStrategyV100Implementation);
        deployFromFileTo("Contracts@34", "AaveV3StrategyInitializer", modularAaveStrategyV100Initializer);
        deployFromFileTo("Contracts@34", "SkyStrategy", modularSkyStrategyV100Implementation);
        deployFromFileTo("Contracts@34", "SkyStrategyInitializer", modularSkyStrategyV100Initializer);
        deployFromFileTo("Contracts@34", "AllocationStrategy", allocationStrategyV100Implementation);
        deployFromFileTo("Contracts@34", "AllocationStrategyInitializer", allocationStrategyV100Initializer);

        deployFromFileTo("Contracts@34", "PoolDeployer", abi.encode(globals), poolDeployerV5);
        deployFromFileTo("Contracts@34", "StrategyDeployer", abi.encode(globals), strategyDeployerV100);
        deployFromFileTo("Contracts@34", "StrategyManagerFactory", abi.encode(globals), strategyManagerFactory);
        deployFromFileTo("Contracts@34", "AaveV3StrategyFactory", abi.encode(globals), modularAaveStrategyFactory);
        deployFromFileTo("Contracts@34", "SkyStrategyFactory", abi.encode(globals), modularSkyStrategyFactory);
        deployFromFileTo("Contracts@34", "AllocationStrategyFactory", abi.encode(globals), allocationStrategyFactory);
        deployFromFileTo("Contracts@34", "LiquidityRouter", abi.encode(globals), liquidityRouterV100);
    }

    /**************************************************************************************************************************************/
    /*** Step 2 - Configure Globals                                                                                                     ***/
    /**************************************************************************************************************************************/

    function configureGlobals() internal {
        vm.startPrank(operationalAdmin);

        IGlobals(globals).setValidInstanceOf("STRATEGY_MANAGER_FACTORY", strategyManagerFactory, true);
        IGlobals(globals).setValidInstanceOf("UNDERLYING_STRATEGY_FACTORY", modularAaveStrategyFactory, true);
        IGlobals(globals).setValidInstanceOf("UNDERLYING_STRATEGY_FACTORY", modularSkyStrategyFactory, true);
        IGlobals(globals).setValidInstanceOf("UNDERLYING_STRATEGY_FACTORY", allocationStrategyFactory, true);
        IGlobals(globals).setValidInstanceOf("STRATEGY_VAULT", AAVE_USDG, true);
        IGlobals(globals).setValidInstanceOf("LIQUIDITY_ROUTER", liquidityRouterV100, true);

        IGlobals(globals).setCanDeployFrom(poolManagerFactory, poolDeployerV5, true);
        IGlobals(globals).setCanDeployFrom(withdrawalManagerQueueFactory, poolDeployerV5, true);

        IGlobals(globals).setCanDeployFrom(strategyManagerFactory, strategyDeployerV100, true);
        IGlobals(globals).setCanDeployFrom(modularAaveStrategyFactory, strategyDeployerV100, true);
        IGlobals(globals).setCanDeployFrom(modularSkyStrategyFactory, strategyDeployerV100, true);
        IGlobals(globals).setCanDeployFrom(allocationStrategyFactory, strategyDeployerV100, true);

        // NOTE: Existing bootstrap mint for USDC and USDT are set from 1e5 to 1e6.
        IGlobals(globals).setBootstrapMint(USDC, BOOTSTRAP_MINT);
        IGlobals(globals).setBootstrapMint(USDT, BOOTSTRAP_MINT);
        IGlobals(globals).setBootstrapMint(USDG, BOOTSTRAP_MINT);

        vm.stopPrank();
    }

    /**************************************************************************************************************************************/
    /*** Step 3 - Upgrade Globals and Setup Factories (Timelocked)                                                                      ***/
    /**************************************************************************************************************************************/

    function upgradeGlobalsAndSetupFactories() internal {
        Proposal[] memory proposals = new Proposal[](15);

        // Globals
        proposals[0] = Proposal(globals, abi.encodeWithSignature("setImplementation(address)", globalsV500Implementation));

        // Pool Manager Factory
        proposals[1] = Proposal(
            poolManagerFactory,
            abi.encodeWithSignature(
                "registerImplementation(uint256,address,address)", 500, PoolManagerV500Implementation, PoolManagerV500Initializer
            )
        );

        proposals[2] = Proposal(poolManagerFactory, abi.encodeWithSignature("setDefaultVersion(uint256)", 500));

        proposals[3] = Proposal(
            poolManagerFactory, abi.encodeWithSignature("enableUpgradePath(uint256,uint256,address)", 400, 500, PoolManagerV500Migrator)
        );

        // Strategy Manager Factory
        proposals[4] = Proposal(
            strategyManagerFactory,
            abi.encodeWithSignature(
                "registerImplementation(uint256,address,address)", 100, strategyManagerV100Implementation, strategyManagerV100Initializer
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

        // Withdrawal Manager Queue Factory
        proposals[12] = Proposal(
            withdrawalManagerQueueFactory,
            abi.encodeWithSignature(
                "registerImplementation(uint256,address,address)",
                201,
                WithdrawalManagerQueueV201Implementation,
                WithdrawalManagerQueueV201Initializer
            )
        );

        proposals[13] = Proposal(withdrawalManagerQueueFactory, abi.encodeWithSignature("setDefaultVersion(uint256)", 201));

        // NOTE: The v2.0.1 upgrade only changes the implementation, no storage migration is needed.
        proposals[14] = Proposal(
            withdrawalManagerQueueFactory, abi.encodeWithSignature("enableUpgradePath(uint256,uint256,address)", 200, 201, address(0))
        );

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
    /*** Step 4 - Upgrade Pools                                                                                                         ***/
    /**************************************************************************************************************************************/

    function upgradePools() internal {
        poolManagers.push(syrupUSDCPoolManager);
        poolManagers.push(syrupUSDTPoolManager);
        poolManagers.push(syrupUSDGPoolManager);
        poolManagers.push(securedLendingUSDCPoolManager);
        poolManagers.push(securedLending2USDCPoolManager);
        poolManagers.push(securedLending3USDCPoolManager);

        openTermLoanManagers.push(syrupUSDCOpenTermLoanManager);
        openTermLoanManagers.push(syrupUSDTOpenTermLoanManager);
        openTermLoanManagers.push(syrupUSDGOpenTermLoanManager);
        openTermLoanManagers.push(securedLendingUSDCOpenTermLoanManager);
        openTermLoanManagers.push(securedLending2USDCOpenTermLoanManager);
        openTermLoanManagers.push(securedLending3USDCOpenTermLoanManager);

        /**********************************************************************************************************************************/
        /*** Step 4.1 - Cleanup Old Strategies                                                                                          ***/
        /**********************************************************************************************************************************/

        address[3] memory fixedTermLoanManagers =
            [syrupUSDCFixedTermLoanManager, syrupUSDTFixedTermLoanManager, securedLendingUSDCFixedTermLoanManager];

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
            assertEq(IStrategyLike(legacyStrategies[i]).unrealizedLosses(), 0);
        }

        /**********************************************************************************************************************************/
        /*** Step 4.2 - Upgrade pool managers                                                                                           ***/
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

        /**********************************************************************************************************************************/
        /*** Step 4.3 - Upgrade Withdrawal Managers                                                                                     ***/
        /**********************************************************************************************************************************/

        for (uint256 i; i < poolManagers.length; i++) {
            IWithdrawalManagerQueue withdrawalManager = IWithdrawalManagerQueue(IPoolManager(poolManagers[i]).withdrawalManager());

            uint256 totalShares = withdrawalManager.totalShares();

            vm.prank(securityAdmin);
            withdrawalManager.upgrade(201, "");

            assertEq(withdrawalManager.implementation(), WithdrawalManagerQueueV201Implementation);
            assertEq(withdrawalManager.totalShares(),    totalShares);
        }
    }

    /**************************************************************************************************************************************/
    /*** Step 5 - Configure Open Term Loan Manager Caps and Whitelist Strategy Delegates                                                ***/
    /**************************************************************************************************************************************/

    function configureCapsAndWhitelistDelegates() internal {
        for (uint256 i; i < poolManagers.length; i++) {
            assertEq(IPoolManager(poolManagers[i]).strategyCapOf(openTermLoanManagers[i]), 0);

            vm.prank(operationalAdmin);
            IPoolManager(poolManagers[i]).setStrategyCap(openTermLoanManagers[i], type(uint256).max);

            assertEq(IPoolManager(poolManagers[i]).strategyCapOf(openTermLoanManagers[i]), type(uint256).max);
        }

        for (uint256 i; i < specs.length; i++) {
            vm.prank(operationalAdmin);
            IGlobals(globals).setValidStrategyDelegate(specs[i].delegate, true);
        }
    }

    /**************************************************************************************************************************************/
    /*** Step 6 - Deploy Modular Strategies                                                                                             ***/
    /**************************************************************************************************************************************/

    function deployModularStrategies() internal {
        for (uint256 i; i < specs.length; i++) {
            erc20_mint(specs[i].asset, specs[i].delegate, BOOTSTRAP_MINT);
            erc20_approve(specs[i].asset, specs[i].delegate, strategyDeployerV100, BOOTSTRAP_MINT);
        }

        for (uint256 i; i < specs.length; i++) {
            StrategySpecification memory spec = specs[i];

            vm.prank(spec.delegate);
            (address strategyManager,) = IStrategyDeployer(strategyDeployerV100).deploy({
                strategyManagerFactory: strategyManagerFactory,
                strategyFactory:        strategyFactory(spec.kind),
                strategyLiquidityCap:   spec.liquidityCap,
                strategyDeploymentData: buildDeploymentData(spec),
                bootstrapFundingData:   ""
            });

            strategyManagers[spec.name] = strategyManager;
        }
    }

    /**************************************************************************************************************************************/
    /*** Step 7 - Attach Modular Strategies (Timelocked)                                                                                ***/
    /**************************************************************************************************************************************/

    function attachModularStrategies(bool attachAaveAndSkyStrategies) internal {
        Proposal[] memory allProposals = new Proposal[](27);

        uint256 count;

        // Syrup USDC
        if (attachAaveAndSkyStrategies) {
            allProposals[count++] = Proposal(
                syrupUSDCPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["Aave Strategy USDC"])
            );

            allProposals[count++] = Proposal(
                syrupUSDCPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["Sky Strategy USDC"])
            );
        }

        allProposals[count++] =
            Proposal(syrupUSDCPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["DEX LP - USDC"]));

        allProposals[count++] =
            Proposal(syrupUSDCPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["PYUSD - USDC"]));

        allProposals[count++] =
            Proposal(syrupUSDCPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["USDtb - USDC"]));

        allProposals[count++] =
            Proposal(syrupUSDCPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["USTB - USDC"]));

        allProposals[count++] =
            Proposal(syrupUSDCPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["DeFi - USDC"]));

        allProposals[count++] =
            Proposal(syrupUSDCPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["Aave V3 - USDC"]));

        // Syrup USDT
        if (attachAaveAndSkyStrategies) {
            allProposals[count++] = Proposal(
                syrupUSDTPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["Aave Strategy USDT"])
            );
        }

        allProposals[count++] =
            Proposal(syrupUSDTPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["DEX LP - USDT"]));

        allProposals[count++] =
            Proposal(syrupUSDTPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["Basis - USDT"]));

        allProposals[count++] =
            Proposal(syrupUSDTPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["PYUSD - USDT"]));

        allProposals[count++] =
            Proposal(syrupUSDTPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["USDtb - USDT"]));

        allProposals[count++] =
            Proposal(syrupUSDTPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["USTB - USDT"]));

        allProposals[count++] =
            Proposal(syrupUSDTPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["DeFi - USDT"]));

        allProposals[count++] =
            Proposal(syrupUSDTPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["Aave V3 - USDT"]));

        // Syrup USDG
        if (attachAaveAndSkyStrategies) {
            allProposals[count++] = Proposal(
                syrupUSDGPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["Aave Strategy USDG"])
            );
        }

        allProposals[count++] =
            Proposal(syrupUSDGPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["DEX LP - USDG"]));

        allProposals[count++] =
            Proposal(syrupUSDGPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["PYUSD - USDG"]));

        allProposals[count++] =
            Proposal(syrupUSDGPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["DeFi - USDG"]));

        // MISL
        if (attachAaveAndSkyStrategies) {
            allProposals[count++] = Proposal(
                securedLendingUSDCPoolManager,
                abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["Aave Strategy USDC"])
            );

            allProposals[count++] = Proposal(
                securedLendingUSDCPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["Sky Strategy USDC"])
            );
        }

        allProposals[count++] = Proposal(
            securedLendingUSDCPoolManager,
            abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["PYUSD - USDC (PPOA only)"])
        );

        allProposals[count++] = Proposal(
            securedLendingUSDCPoolManager,
            abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["USTB - USDC (PPOA only)"])
        );

        // MISL2
        allProposals[count++] = Proposal(
            securedLending2USDCPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["PYUSD - USDC"])
        );

        allProposals[count++] = Proposal(
            securedLending2USDCPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["USDtb - USDC"])
        );

        allProposals[count++] = Proposal(
            securedLending2USDCPoolManager, abi.encodeWithSignature("addStrategyManager(address)", strategyManagers["USTB - USDC"])
        );

        Proposal[] memory proposals = new Proposal[](count);

        for (uint256 i; i < count; i++) {
            proposals[i] = allProposals[i];
        }

        /**********************************************************************************************************************************/
        /*** Step 7.1 - Schedule Proposals                                                                                              ***/
        /**********************************************************************************************************************************/

        uint256[] memory proposalIds = scheduleProposals(proposals);

        /**********************************************************************************************************************************/
        /*** Step 7.2 - Execute Proposals                                                                                               ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + 8 days);

        executeProposals(proposalIds, proposals);
    }

    /**************************************************************************************************************************************/
    /*** Step 8 - Whitelist Managed Wallets and Activate Strategy Manager                                                               ***/
    /**************************************************************************************************************************************/

    function setupManagedWallets() internal {
        /**********************************************************************************************************************************/
        /*** Step 8.1 - Whitelist Managed Wallets                                                                                       ***/
        /**********************************************************************************************************************************/

        for (uint256 i; i < specs.length; i++) {
            address[] memory wallets = managedWallets[specs[i].name];

            for (uint256 j; j < wallets.length; j++) {
                vm.prank(operationalAdmin);
                IGlobals(globals).setValidMapleManagedWallet(wallets[j], true);
            }
        }

        vm.prank(operationalAdmin);
        IGlobals(globals).setValidInstanceOf("LIQUIDITY_ROUTER_BOT", liquidityRouterBot, true);

        /**********************************************************************************************************************************/
        /*** Step 8.2 - Configure and Activate the First Strategy Manager                                                               ***/
        /**********************************************************************************************************************************/

        address configuredStrategyManager = strategyManagers[CONFIGURED_STRATEGY];

        vm.prank(operationalAdmin);
        IPoolManager(syrupUSDCPoolManager).setStrategyCap(configuredStrategyManager, CONFIGURED_STRATEGY_CAP);

        vm.prank(operationalAdmin);
        IGlobals(globals).activateStrategyManager(configuredStrategyManager);
    }

    /**************************************************************************************************************************************/
    /*** Step 9 - Configure Permissions and Wallet Cap on Allocation Strategy                                                           ***/
    /**************************************************************************************************************************************/

    function configurePermissionsAndWalletCapOnAllocationStrategy() internal {
        for (uint256 i; i < specs.length; i++) {
            if (keccak256(bytes(specs[i].name)) != keccak256(bytes(CONFIGURED_STRATEGY))) continue;

            address underlyingStrategy = IStrategyManager(strategyManagers[specs[i].name]).underlyingStrategy();

            address[] memory addresses = managedWallets[specs[i].name];
            bool[] memory    flags     = new bool[](addresses.length);
            uint256[] memory caps      = new uint256[](addresses.length);

            for (uint256 j; j < addresses.length; j++) {
                flags[j] = true;
                caps[j]  = DEPLOYMENT_CAP;
            }

            vm.startPrank(specs[i].delegate);

            IAllocationStrategy(underlyingStrategy).setPermissions(addresses, flags, flags, flags);
            IAllocationStrategy(underlyingStrategy).setDeploymentCaps(addresses, caps);

            vm.stopPrank();
        }
    }

    /**************************************************************************************************************************************/
    /*** Step 10 - Activate Remaining Strategy Managers                                                                                 ***/
    /**************************************************************************************************************************************/

    function activateRemainingStrategyManagers() internal {
        for (uint256 i; i < specs.length; i++) {
            if (keccak256(bytes(specs[i].name)) == keccak256(bytes(CONFIGURED_STRATEGY))) continue;

            vm.prank(operationalAdmin);
            IGlobals(globals).activateStrategyManager(strategyManagers[specs[i].name]);
        }
    }

    /**************************************************************************************************************************************/
    /*** Utility Functions                                                                                                              ***/
    /**************************************************************************************************************************************/

    function buildDeploymentData(StrategySpecification memory spec_) internal view returns (bytes memory data_) {
        if (spec_.kind == StrategyKind.Aave) {
            data_ = abi.encode(
                AaveV3StrategyInitializerParams({
                    aaveToken: spec_.vault,
                    strategyDelegateFeeRate: spec_.delegateFeeRate,
                    strategyProtocolFeeRate: spec_.protocolFeeRate,
                    referralCode: 0,
                    useVirtualUnderlyingBalance: true,
                    strategyMetadata: spec_.metadata
                })
            );
        }

        if (spec_.kind == StrategyKind.Sky) {
            data_ = abi.encode(
                SkyStrategyInitializerParams({
                    fundsAsset: spec_.asset,
                    psm: USDS_LITE_PSM,
                    savingsUsds: SAVINGS_USDS,
                    strategyDelegateFeeRate: spec_.delegateFeeRate,
                    strategyProtocolFeeRate: spec_.protocolFeeRate,
                    referralCode: 0,
                    strategyMetadata: spec_.metadata
                })
            );
        }

        if (spec_.kind == StrategyKind.Allocation) {
            data_ = abi.encode(
                AllocationStrategyInitializerParams({
                    fundsAsset: spec_.asset,
                    strategyMetadata: spec_.metadata,
                    strategyDelegateFeeRate: spec_.delegateFeeRate,
                    strategyProtocolFeeRate: spec_.protocolFeeRate,
                    yieldCap: YIELD_CAP
                })
            );
        }
    }

    function executeProposals(uint256[] memory proposalIds_, Proposal[] memory proposals_) internal {
        (address[] memory targets_, bytes[] memory data_) = unzip(proposals_);

        vm.prank(operationalAdmin);
        IGovernorTimelock(timelock).executeProposals(proposalIds_, targets_, data_);
    }

    function strategyFactory(StrategyKind kind_) internal view returns (address factory_) {
        if (kind_ == StrategyKind.Aave) return modularAaveStrategyFactory;
        if (kind_ == StrategyKind.Sky) return modularSkyStrategyFactory;
        if (kind_ == StrategyKind.Allocation) return allocationStrategyFactory;
    }

    function scheduleProposals(Proposal[] memory proposals_) internal returns (uint256[] memory proposalIds_) {
        uint256 latestProposalId = IGovernorTimelock(timelock).latestProposalId();

        (address[] memory targets_, bytes[] memory data_) = unzip(proposals_);

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
