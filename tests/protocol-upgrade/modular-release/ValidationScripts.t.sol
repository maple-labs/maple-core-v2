// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { ProtocolActions } from "../../../contracts/ProtocolActions.sol";

import {
    IAaveV3Strategy,
    IAllocationStrategy,
    IGlobals,
    IGovernorTimelock,
    IMapleLiquidityRouter,
    IMapleProxyFactory,
    IPoolDeployer,
    IPoolManager,
    IProxiedLike,
    IStrategyDeployer,
    IStrategyLike,
    IStrategyManager,
    IWithdrawalManagerQueue
} from "../../../contracts/interfaces/Interfaces.sol";

import { UpgradeAddressRegistry } from "../UpgradeAddressRegistry.sol";

contract ModularReleaseValidationScriptBase is ProtocolActions, UpgradeAddressRegistry {

    uint256 constant BOOTSTRAP_MINT = 1e6;
    uint256 constant YIELD_CAP      = 0;

    uint256 constant CONFIGURED_STRATEGY_YIELD_CAP = 5_000e6;
    uint256 constant DEPLOYMENT_CAP                = 10_000e6;

    // NOTE: Aave rounds down the scaled balance on supply, so the bootstrap position can be a few wei below the bootstrap mint.
    uint256 constant AAVE_ROUNDING_ERROR = 10;

    uint256 constant CONFIGURED_STRATEGY_CAP = 10_000e6;

    uint32 constant DEX_LP_USDC_PROTOCOL_FEE_RATE     = 0.1e6;
    uint32 constant PYUSD_USDC_PROTOCOL_FEE_RATE      = 0.1e6;
    uint32 constant PYUSD_MISL_USDC_PROTOCOL_FEE_RATE = 0.08333e6;
    uint32 constant USDTB_USDC_PROTOCOL_FEE_RATE      = 0.1e6;
    uint32 constant USTB_USDC_PROTOCOL_FEE_RATE       = 0.1e6;
    uint32 constant USTB_MISL_USDC_PROTOCOL_FEE_RATE  = 0.08333e6;
    uint32 constant DEX_LP_USDT_PROTOCOL_FEE_RATE     = 0.1e6;
    uint32 constant BASIS_USDT_PROTOCOL_FEE_RATE      = 0.1e6;
    uint32 constant PYUSD_USDT_PROTOCOL_FEE_RATE      = 0.1e6;
    uint32 constant USDTB_USDT_PROTOCOL_FEE_RATE      = 0.1e6;
    uint32 constant USTB_USDT_PROTOCOL_FEE_RATE       = 0.1e6;
    uint32 constant DEX_LP_USDG_PROTOCOL_FEE_RATE     = 0.1e6;
    uint32 constant PYUSD_USDG_PROTOCOL_FEE_RATE      = 0.1e6;
    uint32 constant DEFI_USDC_PROTOCOL_FEE_RATE       = 0.1e6;
    uint32 constant AAVE_V3_USDC_PROTOCOL_FEE_RATE    = 0.1e6;
    uint32 constant DEFI_USDT_PROTOCOL_FEE_RATE       = 0.1e6;
    uint32 constant AAVE_V3_USDT_PROTOCOL_FEE_RATE    = 0.1e6;
    uint32 constant DEFI_USDG_PROTOCOL_FEE_RATE       = 0.1e6;

    uint256 constant LATEST_PROPOSAL_ID         = 13;
    uint256 constant PROPOSAL_COUNT_FIRST_BATCH = 15;

    uint256 constant POOL_MANAGER_CURRENT_VERSION       = 400;
    uint256 constant POOL_MANAGER_NEW_VERSION           = 500;
    uint256 constant STRATEGY_NEW_VERSION               = 100;
    uint256 constant WITHDRAWAL_MANAGER_CURRENT_VERSION = 200;
    uint256 constant WITHDRAWAL_MANAGER_NEW_VERSION     = 201;

    address constant DEX_LP_USDC     = 0x32b84210deaB0A44e48e4Da8c98F82620dF9bEC2;
    address constant DEX_LP_USDT     = 0xA3F2a26f3fdFB0ea456271fD13792B976921C69a;
    address constant DEX_LP_USDG     = 0x85bA7143356c023fFbb5784eafD9CCfd24AF0032;
    address constant BASIS_USDT      = 0x68706d21B0CBe66873D2A9f19f273fC53e784F83;
    address constant PYUSD_USDC      = 0x019B109329FB69047d2f7420b641b103306F0D4e;
    address constant PYUSD_MISL_USDC = 0x6598b24899Bd0E8E8b1d5294253faCA5950813E3;
    address constant PYUSD_USDT      = 0x4c6fc026DF8042Cb71D46558EA221D5c42BB0024;
    address constant PYUSD_USDG      = 0x44cED2CCe694b475ACf31C54c553AC26Cfa5081c;
    address constant USDTB_USDC      = 0xFD0c3501be98A21be893fFFc288fa267B41A1ACc;
    address constant USDTB_USDT      = 0x433D0FBaDC48334e99f269CfF0A3800fB15251a5;
    address constant USTB_USDC       = 0xe8C04874B1332a95bA15961c5E4a13f28Ba65C3c;
    address constant USTB_MISL_USDC  = 0x1109e889BB6Bc02f5ffA83B0c1E7f1FBC566eC3C;
    address constant USTB_USDT       = 0x5DDc47BDe674D4C137650e61c8193a215949C811;
    address constant DEFI_USDC       = 0x0BA365b4059db87dDa04575eBeca5ae1a9881180;
    address constant DEFI_USDT       = 0x38d09539BFAfd373507F92917552648Cc47b6555;
    address constant DEFI_USDG       = 0x7862AD5fF4e8A252cF040BD82cE07D40B4c64e9A;
    address constant AAVE_V3_USDC    = 0x083Ae322F060777bcf5a2801C5c13A8e3eC54Ec1;
    address constant AAVE_V3_USDT    = 0x029F491A17A52a8D052F711a037C1D88C9330692;

    address constant LIQUIDITY_BOT = 0xfB2C579c1D5f82C7b0f2a3479e5F9bC26bd22b62;

    address constant CONFIGURED_STRATEGY = PYUSD_USDC;

    IGovernorTimelock tl = IGovernorTimelock(timelock);

    address[] strategies = [
        DEX_LP_USDC,
        PYUSD_USDC,
        PYUSD_MISL_USDC,
        USDTB_USDC,
        USTB_USDC,
        USTB_MISL_USDC,
        DEX_LP_USDT,
        BASIS_USDT,
        PYUSD_USDT,
        USDTB_USDT,
        USTB_USDT,
        DEX_LP_USDG,
        PYUSD_USDG,
        DEFI_USDC,
        AAVE_V3_USDC,
        DEFI_USDT,
        AAVE_V3_USDT,
        DEFI_USDG
    ];

    uint32[] strategyProtocolFeeRates = [
        DEX_LP_USDC_PROTOCOL_FEE_RATE,
        PYUSD_USDC_PROTOCOL_FEE_RATE,
        PYUSD_MISL_USDC_PROTOCOL_FEE_RATE,
        USDTB_USDC_PROTOCOL_FEE_RATE,
        USTB_USDC_PROTOCOL_FEE_RATE,
        USTB_MISL_USDC_PROTOCOL_FEE_RATE,
        DEX_LP_USDT_PROTOCOL_FEE_RATE,
        BASIS_USDT_PROTOCOL_FEE_RATE,
        PYUSD_USDT_PROTOCOL_FEE_RATE,
        USDTB_USDT_PROTOCOL_FEE_RATE,
        USTB_USDT_PROTOCOL_FEE_RATE,
        DEX_LP_USDG_PROTOCOL_FEE_RATE,
        PYUSD_USDG_PROTOCOL_FEE_RATE,
        DEFI_USDC_PROTOCOL_FEE_RATE,
        AAVE_V3_USDC_PROTOCOL_FEE_RATE,
        DEFI_USDT_PROTOCOL_FEE_RATE,
        AAVE_V3_USDT_PROTOCOL_FEE_RATE,
        DEFI_USDG_PROTOCOL_FEE_RATE
    ];

    address[] strategyDelegates = [
        dexLpUSDCDelegate,
        pyusdUSDCDelegate,
        pyusdMislUSDCDelegate,
        usdtbUSDCDelegate,
        ustbUSDCDelegate,
        ustbMislUSDCDelegate,
        dexLpUSDTDelegate,
        basisUSDTDelegate,
        pyusdUSDTDelegate,
        usdtbUSDTDelegate,
        ustbUSDTDelegate,
        dexLpUSDGDelegate,
        pyusdUSDGDelegate,
        defiUSDCDelegate,
        aaveV3USDCDelegate,
        defiUSDTDelegate,
        aaveV3USDTDelegate,
        defiUSDGDelegate
    ];

    mapping(address => address) aaveTokens;

    mapping(address => address[]) managedWallets;
    mapping(address => address[]) modularStrategies;
    mapping(address => address[]) legacyStrategies;

    constructor() {
        aaveTokens[AAVE_V3_USDC] = aUsdc;
        aaveTokens[AAVE_V3_USDT] = aUsdt;

        managedWallets[DEX_LP_USDC].push(dexLpUSDC_syrupUSDC_managedWallet);

        managedWallets[PYUSD_USDC].push(pyusdUSDC_syrupUSDC_managedWallet);
        managedWallets[PYUSD_USDC].push(pyusdUSDC_securedLending2USDC_managedWallet);

        managedWallets[PYUSD_MISL_USDC].push(pyusdMislUSDC_securedLendingUSDC_managedWallet);

        managedWallets[USDTB_USDC].push(usdtbUSDC_syrupUSDC_managedWallet);
        managedWallets[USDTB_USDC].push(usdtbUSDC_securedLending2USDC_managedWallet);

        managedWallets[USTB_USDC].push(ustbUSDC_syrupUSDC_managedWallet);
        managedWallets[USTB_USDC].push(ustbUSDC_securedLending2USDC_managedWallet);

        managedWallets[USTB_MISL_USDC].push(ustbMislUSDC_securedLendingUSDC_managedWallet);

        managedWallets[DEX_LP_USDT].push(dexLpUSDT_syrupUSDT_managedWallet);
        managedWallets[BASIS_USDT].push(basisUSDT_syrupUSDT_managedWallet);
        managedWallets[PYUSD_USDT].push(pyusdUSDT_syrupUSDT_managedWallet);
        managedWallets[USDTB_USDT].push(usdtbUSDT_syrupUSDT_managedWallet);
        managedWallets[USTB_USDT].push(ustbUSDT_syrupUSDT_managedWallet);

        managedWallets[DEX_LP_USDG].push(dexLpUSDG_syrupUSDG_managedWallet);
        managedWallets[PYUSD_USDG].push(pyusdUSDG_syrupUSDG_managedWallet);

        managedWallets[DEFI_USDC].push(defiUSDC_syrupUSDC_managedWallet);
        managedWallets[DEFI_USDT].push(defiUSDT_syrupUSDT_managedWallet);
        managedWallets[DEFI_USDG].push(defiUSDG_syrupUSDG_managedWallet);

        modularStrategies[syrupUSDCPoolManager].push(DEX_LP_USDC);
        modularStrategies[syrupUSDCPoolManager].push(PYUSD_USDC);
        modularStrategies[syrupUSDCPoolManager].push(USDTB_USDC);
        modularStrategies[syrupUSDCPoolManager].push(USTB_USDC);
        modularStrategies[syrupUSDCPoolManager].push(DEFI_USDC);
        modularStrategies[syrupUSDCPoolManager].push(AAVE_V3_USDC);

        modularStrategies[syrupUSDTPoolManager].push(DEX_LP_USDT);
        modularStrategies[syrupUSDTPoolManager].push(BASIS_USDT);
        modularStrategies[syrupUSDTPoolManager].push(PYUSD_USDT);
        modularStrategies[syrupUSDTPoolManager].push(USDTB_USDT);
        modularStrategies[syrupUSDTPoolManager].push(USTB_USDT);
        modularStrategies[syrupUSDTPoolManager].push(DEFI_USDT);
        modularStrategies[syrupUSDTPoolManager].push(AAVE_V3_USDT);

        modularStrategies[syrupUSDGPoolManager].push(DEX_LP_USDG);
        modularStrategies[syrupUSDGPoolManager].push(PYUSD_USDG);
        modularStrategies[syrupUSDGPoolManager].push(DEFI_USDG);

        modularStrategies[securedLendingUSDCPoolManager].push(PYUSD_MISL_USDC);
        modularStrategies[securedLendingUSDCPoolManager].push(USTB_MISL_USDC);

        modularStrategies[securedLending2USDCPoolManager].push(PYUSD_USDC);
        modularStrategies[securedLending2USDCPoolManager].push(USDTB_USDC);
        modularStrategies[securedLending2USDCPoolManager].push(USTB_USDC);

        legacyStrategies[syrupUSDCPoolManager].push(syrupUSDCFixedTermLoanManager);
        legacyStrategies[syrupUSDCPoolManager].push(syrupUSDCAaveStrategy);
        legacyStrategies[syrupUSDCPoolManager].push(syrupUSDCSkyStrategy);

        legacyStrategies[syrupUSDTPoolManager].push(syrupUSDTFixedTermLoanManager);
        legacyStrategies[syrupUSDTPoolManager].push(syrupUSDTAaveStrategy);

        legacyStrategies[securedLendingUSDCPoolManager].push(securedLendingUSDCFixedTermLoanManager);
        legacyStrategies[securedLendingUSDCPoolManager].push(securedLendingUSDCAaveStrategy);
        legacyStrategies[securedLendingUSDCPoolManager].push(securedLendingUSDCSkyStrategy);
    }

    function _configuredStrategyIndex() internal view returns (uint256 index_) {
        for (; index_ < strategies.length; index_++) {
            if (strategies[index_] == CONFIGURED_STRATEGY) return index_;
        }

        revert("Configured strategy is not in the strategy list!");
    }

    function _proposalHash(address target_, bytes memory calldata_) internal pure returns (bytes32 hash_) {
        hash_ = keccak256(abi.encode(target_, calldata_));
    }

    function _addProposalIdToString(string memory message_, uint256 proposalId_) internal pure returns (string memory annotated_) {
        annotated_ = string(abi.encodePacked(message_, " (id: ", vm.toString(proposalId_), ")"));
    }

    function _addAddressToString(string memory message_, address account_) internal pure returns (string memory annotated_) {
        annotated_ = string(abi.encodePacked(message_, " (", vm.toString(account_), ")"));
    }

    function _pools()
        internal
        view
        returns (address[] memory poolManagers_, address[] memory withdrawalManagers_, address[] memory openTermLoanManagers_)
    {
        poolManagers_         = new address[](6);
        withdrawalManagers_   = new address[](6);
        openTermLoanManagers_ = new address[](6);

        poolManagers_[0]         = syrupUSDCPoolManager;
        withdrawalManagers_[0]   = syrupUSDCWithdrawalManagerQueue;
        openTermLoanManagers_[0] = syrupUSDCOpenTermLoanManager;

        poolManagers_[1]         = syrupUSDTPoolManager;
        withdrawalManagers_[1]   = syrupUSDTWithdrawalManagerQueue;
        openTermLoanManagers_[1] = syrupUSDTOpenTermLoanManager;

        poolManagers_[2]         = syrupUSDGPoolManager;
        withdrawalManagers_[2]   = syrupUSDGWithdrawalManagerQueue;
        openTermLoanManagers_[2] = syrupUSDGOpenTermLoanManager;

        poolManagers_[3]         = securedLendingUSDCPoolManager;
        withdrawalManagers_[3]   = securedLendingUSDCWithdrawalManagerQueue;
        openTermLoanManagers_[3] = securedLendingUSDCOpenTermLoanManager;

        poolManagers_[4]         = securedLending2USDCPoolManager;
        withdrawalManagers_[4]   = securedLending2USDCWithdrawalManagerQueue;
        openTermLoanManagers_[4] = securedLending2USDCOpenTermLoanManager;

        poolManagers_[5]         = securedLending3USDCPoolManager;
        withdrawalManagers_[5]   = securedLending3USDCWithdrawalManagerQueue;
        openTermLoanManagers_[5] = securedLending3USDCOpenTermLoanManager;
    }

}

contract ValidateInitialContractDeployment is ModularReleaseValidationScriptBase {

    function run() external view {
        /**********************************************************************************************************************************/
        /*** Deployed Bytecode                                                                                                          ***/
        /**********************************************************************************************************************************/

        assertGt(globalsV500Implementation.code.length, 0, "Globals implementation has no bytecode!");
        assertGt(poolDeployerV5.code.length, 0, "PoolDeployer has no bytecode!");
        assertGt(strategyDeployerV100.code.length, 0, "StrategyDeployer has no bytecode!");
        assertGt(PoolManagerV500Implementation.code.length, 0, "PoolManager implementation has no bytecode!");
        assertGt(PoolManagerV500Initializer.code.length, 0, "PoolManager initializer has no bytecode!");
        assertGt(PoolManagerV500Migrator.code.length, 0, "PoolManager migrator has no bytecode!");
        assertGt(WithdrawalManagerQueueV201Implementation.code.length, 0, "WithdrawalManager implementation has no bytecode!");
        assertGt(WithdrawalManagerQueueV201Initializer.code.length, 0, "WithdrawalManager initializer has no bytecode!");
        assertGt(strategyManagerFactory.code.length, 0, "StrategyManager factory has no bytecode!");
        assertGt(strategyManagerV100Implementation.code.length, 0, "StrategyManager implementation has no bytecode!");
        assertGt(strategyManagerV100Initializer.code.length, 0, "StrategyManager initializer has no bytecode!");
        assertGt(modularAaveStrategyFactory.code.length, 0, "AaveV3Strategy factory has no bytecode!");
        assertGt(modularAaveStrategyV100Implementation.code.length, 0, "AaveV3Strategy implementation has no bytecode!");
        assertGt(modularAaveStrategyV100Initializer.code.length, 0, "AaveV3Strategy initializer has no bytecode!");
        assertGt(modularSkyStrategyFactory.code.length, 0, "SkyStrategy factory has no bytecode!");
        assertGt(modularSkyStrategyV100Implementation.code.length, 0, "SkyStrategy implementation has no bytecode!");
        assertGt(modularSkyStrategyV100Initializer.code.length, 0, "SkyStrategy initializer has no bytecode!");
        assertGt(allocationStrategyFactory.code.length, 0, "AllocationStrategy factory has no bytecode!");
        assertGt(allocationStrategyV100Implementation.code.length, 0, "AllocationStrategy implementation has no bytecode!");
        assertGt(allocationStrategyV100Initializer.code.length, 0, "AllocationStrategy initializer has no bytecode!");
        assertGt(liquidityRouterV100.code.length, 0, "LiquidityRouter has no bytecode!");

        /**********************************************************************************************************************************/
        /*** Constructor Arguments                                                                                                      ***/
        /**********************************************************************************************************************************/

        assertEq(IPoolDeployer(poolDeployerV5).globals(),              globals, "Invalid globals on pool deployer!");
        assertEq(IStrategyDeployer(strategyDeployerV100).globals(),    globals, "Invalid globals on strategy deployer!");
        assertEq(IMapleLiquidityRouter(liquidityRouterV100).globals(), globals, "Invalid globals on liquidity router!");

        assertEq(IMapleProxyFactory(strategyManagerFactory).mapleGlobals(),     globals, "Invalid globals on SM factory!");
        assertEq(IMapleProxyFactory(modularAaveStrategyFactory).mapleGlobals(), globals, "Invalid globals on Aave factory!");
        assertEq(IMapleProxyFactory(modularSkyStrategyFactory).mapleGlobals(),  globals, "Invalid globals on Sky factory!");
        assertEq(IMapleProxyFactory(allocationStrategyFactory).mapleGlobals(),  globals, "Invalid globals on Allocation factory!");

        /**********************************************************************************************************************************/
        /*** Unconfigured Factories                                                                                                     ***/
        /**********************************************************************************************************************************/

        assertEq(IMapleProxyFactory(strategyManagerFactory).defaultVersion(),     0, "SM factory has a default version!");
        assertEq(IMapleProxyFactory(modularAaveStrategyFactory).defaultVersion(), 0, "Aave factory has a default version!");
        assertEq(IMapleProxyFactory(modularSkyStrategyFactory).defaultVersion(),  0, "Sky factory has a default version!");
        assertEq(IMapleProxyFactory(allocationStrategyFactory).defaultVersion(),  0, "Allocation factory has a default version!");

        assertEq(
            IMapleProxyFactory(strategyManagerFactory).implementationOf(STRATEGY_NEW_VERSION),
            address(0),
            "SM implementation is already registered!"
        );

        assertEq(
            IMapleProxyFactory(modularAaveStrategyFactory).implementationOf(STRATEGY_NEW_VERSION),
            address(0),
            "Aave implementation is already registered!"
        );

        assertEq(
            IMapleProxyFactory(modularSkyStrategyFactory).implementationOf(STRATEGY_NEW_VERSION),
            address(0),
            "Sky implementation is already registered!"
        );

        assertEq(
            IMapleProxyFactory(allocationStrategyFactory).implementationOf(STRATEGY_NEW_VERSION),
            address(0),
            "Allocation implementation is already registered!"
        );
    }

}

contract ValidateInitialGlobalsConfiguration is ModularReleaseValidationScriptBase {

    function run() external view {
        IGlobals mapleGlobals = IGlobals(globals);

        /**********************************************************************************************************************************/
        /*** Valid Instances                                                                                                            ***/
        /**********************************************************************************************************************************/

        assertEq(mapleGlobals.isInstanceOf("STRATEGY_MANAGER_FACTORY", strategyManagerFactory), true, "SM factory is not registered!");

        assertEq(
            mapleGlobals.isInstanceOf("UNDERLYING_STRATEGY_FACTORY", modularAaveStrategyFactory), true, "Aave factory is not registered!"
        );

        assertEq(
            mapleGlobals.isInstanceOf("UNDERLYING_STRATEGY_FACTORY", modularSkyStrategyFactory), true, "Sky factory is not registered!"
        );

        assertEq(
            mapleGlobals.isInstanceOf("UNDERLYING_STRATEGY_FACTORY", allocationStrategyFactory),
            true,
            "Allocation factory is not registered!"
        );

        assertEq(mapleGlobals.isInstanceOf("STRATEGY_FACTORY", openTermLoanManagerFactory), true, "OTLM factory is not registered!");

        assertEq(mapleGlobals.isInstanceOf("STRATEGY_VAULT", aUsdc),                 true, "aUsdc vault not strategy vault instance!");
        assertEq(mapleGlobals.isInstanceOf("STRATEGY_VAULT", aUsdt),                 true, "aUsdt vault not strategy vault instance!");
        assertEq(mapleGlobals.isInstanceOf("STRATEGY_VAULT", AAVE_USDG),             true, "aUSDG vault not strategy vault instance!");
        assertEq(mapleGlobals.isInstanceOf("STRATEGY_VAULT", savingsUsds),           true, "sUSDS vault not strategy vault instance!");
        assertEq(mapleGlobals.isInstanceOf("LIQUIDITY_ROUTER", liquidityRouterV100), true, "Liquidity router not registered!");
        assertEq(mapleGlobals.isInstanceOf("PSM", usdsLitePSM),                      true, "PSM is not registered!");

        /**********************************************************************************************************************************/
        /*** Deployment Permissions                                                                                                     ***/
        /**********************************************************************************************************************************/

        assertEq(mapleGlobals.canDeployFrom(poolManagerFactory, poolDeployerV5),            true, "PoolDeployer cannot deploy PMs!");
        assertEq(mapleGlobals.canDeployFrom(withdrawalManagerQueueFactory, poolDeployerV5), true, "PoolDeployer cannot deploy WMs!");

        assertEq(mapleGlobals.canDeployFrom(strategyManagerFactory, strategyDeployerV100),     true, "StrategyDeployer can't deploy SMs!");
        assertEq(mapleGlobals.canDeployFrom(modularAaveStrategyFactory, strategyDeployerV100), true, "StrategyDeployer can't deploy Aave!");
        assertEq(mapleGlobals.canDeployFrom(modularSkyStrategyFactory, strategyDeployerV100),  true, "StrategyDeployer can't deploy Sky!");

        assertEq(
            mapleGlobals.canDeployFrom(allocationStrategyFactory, strategyDeployerV100),
            true,
            "StrategyDeployer can't deploy Allocation strategy!"
        );

        /**********************************************************************************************************************************/
        /*** Bootstrap Mints                                                                                                            ***/
        /**********************************************************************************************************************************/

        assertEq(mapleGlobals.bootstrapMint(USDC), BOOTSTRAP_MINT, "Invalid USDC bootstrap mint!");
        assertEq(mapleGlobals.bootstrapMint(USDT), BOOTSTRAP_MINT, "Invalid USDT bootstrap mint!");
        assertEq(mapleGlobals.bootstrapMint(USDG), BOOTSTRAP_MINT, "Invalid USDG bootstrap mint!");
    }

}

contract ValidateFirstProposalsScheduling is ModularReleaseValidationScriptBase {

    function run() external view {
        (address[] memory targets, bytes[] memory data) = _scheduledProposals();

        assertEq(tl.latestProposalId(), LATEST_PROPOSAL_ID + targets.length, "Invalid latest proposal id!");

        (,, uint32 batchTimestamp,,) = tl.proposals(LATEST_PROPOSAL_ID + 1);

        for (uint256 i; i < targets.length; i++) {
            uint256 proposalId           = LATEST_PROPOSAL_ID + i + 1;
            bytes32 expectedProposalHash = _proposalHash(targets[i], data[i]);

            (bytes32 proposalHash, bool isUnschedulable, uint32 scheduledAt, uint32 delayedUntil, uint32 validUntil) =
                tl.proposals(proposalId);

            assertEq(proposalHash,    expectedProposalHash,          _addProposalIdToString("Invalid proposal hash!", proposalId));
            assertEq(isUnschedulable, true,                          _addProposalIdToString("Proposal is not unschedulable!", proposalId));
            assertEq(scheduledAt,     batchTimestamp,                _addProposalIdToString("Invalid proposal date!", proposalId));
            assertEq(delayedUntil,    scheduledAt + 3 days,          _addProposalIdToString("Invalid execution window!", proposalId));
            assertEq(validUntil,      scheduledAt + 3 days + 2 days, _addProposalIdToString("Invalid execution window!", proposalId));
        }
    }

    function _scheduledProposals() internal view returns (address[] memory targets_, bytes[] memory data_) {
        targets_ = new address[](15);
        data_    = new bytes[](15);

        targets_[0] = globals;
        data_[0]    = abi.encodeWithSignature("setImplementation(address)", globalsV500Implementation);

        targets_[1] = poolManagerFactory;
        data_[1] = abi.encodeWithSignature(
            "registerImplementation(uint256,address,address)",
            POOL_MANAGER_NEW_VERSION,
            PoolManagerV500Implementation,
            PoolManagerV500Initializer
        );

        targets_[2] = poolManagerFactory;
        data_[2]    = abi.encodeWithSignature("setDefaultVersion(uint256)", POOL_MANAGER_NEW_VERSION);

        targets_[3] = poolManagerFactory;
        data_[3] = abi.encodeWithSignature(
            "enableUpgradePath(uint256,uint256,address)", POOL_MANAGER_CURRENT_VERSION, POOL_MANAGER_NEW_VERSION, PoolManagerV500Migrator
        );

        targets_[4] = strategyManagerFactory;
        data_[4] = abi.encodeWithSignature(
            "registerImplementation(uint256,address,address)",
            STRATEGY_NEW_VERSION,
            strategyManagerV100Implementation,
            strategyManagerV100Initializer
        );

        targets_[5] = strategyManagerFactory;
        data_[5]    = abi.encodeWithSignature("setDefaultVersion(uint256)", STRATEGY_NEW_VERSION);

        targets_[6] = modularAaveStrategyFactory;
        data_[6] = abi.encodeWithSignature(
            "registerImplementation(uint256,address,address)",
            STRATEGY_NEW_VERSION,
            modularAaveStrategyV100Implementation,
            modularAaveStrategyV100Initializer
        );

        targets_[7] = modularAaveStrategyFactory;
        data_[7]    = abi.encodeWithSignature("setDefaultVersion(uint256)", STRATEGY_NEW_VERSION);

        targets_[8] = modularSkyStrategyFactory;
        data_[8] = abi.encodeWithSignature(
            "registerImplementation(uint256,address,address)",
            STRATEGY_NEW_VERSION,
            modularSkyStrategyV100Implementation,
            modularSkyStrategyV100Initializer
        );

        targets_[9] = modularSkyStrategyFactory;
        data_[9]    = abi.encodeWithSignature("setDefaultVersion(uint256)", STRATEGY_NEW_VERSION);

        targets_[10] = allocationStrategyFactory;
        data_[10] = abi.encodeWithSignature(
            "registerImplementation(uint256,address,address)",
            STRATEGY_NEW_VERSION,
            allocationStrategyV100Implementation,
            allocationStrategyV100Initializer
        );

        targets_[11] = allocationStrategyFactory;
        data_[11]    = abi.encodeWithSignature("setDefaultVersion(uint256)", STRATEGY_NEW_VERSION);

        targets_[12] = withdrawalManagerQueueFactory;
        data_[12] = abi.encodeWithSignature(
            "registerImplementation(uint256,address,address)",
            WITHDRAWAL_MANAGER_NEW_VERSION,
            WithdrawalManagerQueueV201Implementation,
            WithdrawalManagerQueueV201Initializer
        );

        targets_[13] = withdrawalManagerQueueFactory;
        data_[13]    = abi.encodeWithSignature("setDefaultVersion(uint256)", WITHDRAWAL_MANAGER_NEW_VERSION);

        targets_[14] = withdrawalManagerQueueFactory;
        data_[14] = abi.encodeWithSignature(
            "enableUpgradePath(uint256,uint256,address)", WITHDRAWAL_MANAGER_CURRENT_VERSION, WITHDRAWAL_MANAGER_NEW_VERSION, address(0)
        );
    }

}

contract ValidateFirstProposalExecution is ModularReleaseValidationScriptBase {

    function run() external view {
        /**********************************************************************************************************************************/
        /*** Globals                                                                                                                    ***/
        /**********************************************************************************************************************************/

        assertEq(IGlobals(globals).implementation(), globalsV500Implementation, "Globals was not upgraded!");

        /**********************************************************************************************************************************/
        /*** Pool Manager Factory                                                                                                       ***/
        /**********************************************************************************************************************************/

        assertEq(
            IMapleProxyFactory(poolManagerFactory).implementationOf(POOL_MANAGER_NEW_VERSION),
            PoolManagerV500Implementation,
            "Invalid pool manager implementation!"
        );

        assertEq(
            IMapleProxyFactory(poolManagerFactory).migratorForPath(POOL_MANAGER_CURRENT_VERSION, POOL_MANAGER_NEW_VERSION),
            PoolManagerV500Migrator,
            "Invalid pool manager migrator!"
        );

        assertEq(
            IMapleProxyFactory(poolManagerFactory).upgradeEnabledForPath(POOL_MANAGER_CURRENT_VERSION, POOL_MANAGER_NEW_VERSION),
            true,
            "Pool manager upgrade path is not enabled!"
        );

        assertEq(IMapleProxyFactory(poolManagerFactory).defaultVersion(), POOL_MANAGER_NEW_VERSION, "Invalid pool manager version!");

        /**********************************************************************************************************************************/
        /*** Strategy Factories                                                                                                         ***/
        /**********************************************************************************************************************************/

        assertEq(
            IMapleProxyFactory(strategyManagerFactory).implementationOf(STRATEGY_NEW_VERSION),
            strategyManagerV100Implementation,
            "Invalid strategy manager implementation!"
        );

        assertEq(
            IMapleProxyFactory(modularAaveStrategyFactory).implementationOf(STRATEGY_NEW_VERSION),
            modularAaveStrategyV100Implementation,
            "Invalid Aave strategy implementation!"
        );

        assertEq(
            IMapleProxyFactory(modularSkyStrategyFactory).implementationOf(STRATEGY_NEW_VERSION),
            modularSkyStrategyV100Implementation,
            "Invalid Sky strategy implementation!"
        );

        assertEq(
            IMapleProxyFactory(allocationStrategyFactory).implementationOf(STRATEGY_NEW_VERSION),
            allocationStrategyV100Implementation,
            "Invalid Allocation strategy implementation!"
        );

        assertEq(IMapleProxyFactory(strategyManagerFactory).defaultVersion(),     STRATEGY_NEW_VERSION, "Invalid SM version!");
        assertEq(IMapleProxyFactory(modularAaveStrategyFactory).defaultVersion(), STRATEGY_NEW_VERSION, "Invalid Aave version!");
        assertEq(IMapleProxyFactory(modularSkyStrategyFactory).defaultVersion(),  STRATEGY_NEW_VERSION, "Invalid Sky version!");
        assertEq(IMapleProxyFactory(allocationStrategyFactory).defaultVersion(),  STRATEGY_NEW_VERSION, "Invalid Allocation version!");

        /**********************************************************************************************************************************/
        /*** Withdrawal Manager Queue Factory                                                                                           ***/
        /**********************************************************************************************************************************/

        assertEq(
            IMapleProxyFactory(withdrawalManagerQueueFactory).implementationOf(WITHDRAWAL_MANAGER_NEW_VERSION),
            WithdrawalManagerQueueV201Implementation,
            "Invalid withdrawal manager implementation!"
        );

        assertEq(
            IMapleProxyFactory(withdrawalManagerQueueFactory)
                .migratorForPath(WITHDRAWAL_MANAGER_CURRENT_VERSION, WITHDRAWAL_MANAGER_NEW_VERSION),
            address(0),
            "Invalid withdrawal manager migrator!"
        );

        assertEq(
            IMapleProxyFactory(withdrawalManagerQueueFactory)
                .upgradeEnabledForPath(WITHDRAWAL_MANAGER_CURRENT_VERSION, WITHDRAWAL_MANAGER_NEW_VERSION),
            true,
            "Withdrawal manager upgrade path is not enabled!"
        );

        assertEq(
            IMapleProxyFactory(withdrawalManagerQueueFactory).defaultVersion(),
            WITHDRAWAL_MANAGER_NEW_VERSION,
            "Invalid withdrawal manager version!"
        );

        /**********************************************************************************************************************************/
        /*** Executed Proposals                                                                                                         ***/
        /**********************************************************************************************************************************/

        assertEq(tl.latestProposalId(), LATEST_PROPOSAL_ID + PROPOSAL_COUNT_FIRST_BATCH, "Invalid latest proposal id!");

        for (uint256 i; i < PROPOSAL_COUNT_FIRST_BATCH; i++) {
            uint256 proposalId = LATEST_PROPOSAL_ID + i + 1;

            (bytes32 proposalHash,,,,) = tl.proposals(proposalId);

            assertEq(proposalHash, bytes32(0), _addProposalIdToString("Proposal was not executed!", proposalId));
        }
    }

}

contract ValidateUpgradePoolsAndWMs is ModularReleaseValidationScriptBase {

    function run() external view {
        (address[] memory poolManagers, address[] memory withdrawalManagers, address[] memory openTermLoanManagers) = _pools();

        for (uint256 i; i < poolManagers.length; i++) {
            address poolManager         = poolManagers[i];
            address withdrawalManager   = withdrawalManagers[i];
            address openTermLoanManager = openTermLoanManagers[i];

            assertEq(
                IPoolManager(poolManager).implementation(),
                PoolManagerV500Implementation,
                _addAddressToString("PM was not upgraded!", poolManager)
            );

            assertEq(IPoolManager(poolManager).factory(),    poolManagerFactory, _addAddressToString("Invalid PM factory!", poolManager));
            assertEq(IPoolManager(poolManager).active(),     true,               _addAddressToString("PM is not active!", poolManager));
            assertEq(IPoolManager(poolManager).configured(), true,               _addAddressToString("PM is not configured!", poolManager));

            assertEq(
                IPoolManager(poolManager).withdrawalManager(),
                withdrawalManager,
                _addAddressToString("Invalid withdrawal manager!", poolManager)
            );

            assertEq(
                IWithdrawalManagerQueue(withdrawalManager).implementation(),
                WithdrawalManagerQueueV201Implementation,
                _addAddressToString("Withdrawal manager was not upgraded!", withdrawalManager)
            );

            assertEq(
                IWithdrawalManagerQueue(withdrawalManager).factory(),
                withdrawalManagerQueueFactory,
                _addAddressToString("Invalid WM factory!", withdrawalManager)
            );

            assertEq(
                IWithdrawalManagerQueue(withdrawalManager).poolManager(),
                poolManager,
                _addAddressToString("Invalid WM pool manager!", withdrawalManager)
            );

            assertEq(
                IPoolManager(poolManager).isStrategy(openTermLoanManager),
                true,
                _addAddressToString("Open-term loan manager is not a strategy!", poolManager)
            );

            address[] memory oldStrategies = legacyStrategies[poolManager];

            for (uint256 j; j < oldStrategies.length; j++) {
                assertEq(
                    IPoolManager(poolManager).isStrategy(oldStrategies[j]),
                    false,
                    _addAddressToString("Old strategy is still a strategy!", oldStrategies[j])
                );
            }

            assertEq(IPoolManager(poolManager).strategyListLength(), 1, _addAddressToString("Invalid strategy count!", poolManager));

            assertEq(IPoolManager(poolManager).strategyList(0), openTermLoanManager, _addAddressToString("Invalid strategy!", poolManager));

            assertEq(
                IPoolManager(poolManager).strategyCapOf(openTermLoanManager),
                0,
                _addAddressToString("Open-term loan manager cap is already set!", poolManager)
            );
        }
    }

}

contract ValidateOTLMCapsAndWhitelistDelegates is ModularReleaseValidationScriptBase {

    function run() external view {
        (address[] memory poolManagers,, address[] memory openTermLoanManagers) = _pools();

        for (uint256 i; i < poolManagers.length; i++) {
            address poolManager         = poolManagers[i];
            address openTermLoanManager = openTermLoanManagers[i];

            assertEq(
                IPoolManager(poolManager).isStrategy(openTermLoanManager),
                true,
                _addAddressToString("Open-term loan manager is not a strategy!", poolManager)
            );

            assertEq(
                IPoolManager(poolManager).strategyCapOf(openTermLoanManager),
                type(uint256).max,
                _addAddressToString("Invalid open-term loan manager cap!", poolManager)
            );
        }

        for (uint256 i; i < strategyDelegates.length; i++) {
            address delegate = strategyDelegates[i];

            (address ownedStrategyManager, bool isStrategyDelegate) = IGlobals(globals).strategyDelegates(delegate);

            assertEq(isStrategyDelegate,   true,       _addAddressToString("Strategy delegate is not registered!", delegate));
            assertEq(ownedStrategyManager, address(0), _addAddressToString("Strategy delegate already owns a manager!", delegate));
        }
    }

}

contract ValidateInitialStrategyDeployment is ModularReleaseValidationScriptBase {

    function run() external view {
        assertEq(strategies.length, strategyDelegates.length,        "Strategy and delegate counts do not match!");
        assertEq(strategies.length, strategyProtocolFeeRates.length, "Strategy and protocol fee rate counts do not match!");

        for (uint256 i; i < strategies.length; i++) {
            address sm              = strategies[i];
            address delegate        = strategyDelegates[i];
            address us              = IStrategyManager(sm).underlyingStrategy();
            uint32  protocolFeeRate = strategyProtocolFeeRates[i];

            assertEq(IStrategyManager(sm).strategyDelegate(), delegate, _addAddressToString("Invalid SD!", sm));
            assertEq(IStrategyManager(sm).configured(),       true,     _addAddressToString("SM not configured", sm));
            assertEq(IStrategyManager(sm).active(),           false,    _addAddressToString("SM active", sm));

            assertEq(IStrategyManager(sm).factory(),        strategyManagerFactory,            _addAddressToString("Invalid SM fact!", sm));
            assertEq(IStrategyManager(sm).implementation(), strategyManagerV100Implementation, _addAddressToString("Invalid SM impl!", sm));

            assertEq(IGlobals(globals).ownedStrategyManager(delegate), address(0), _addAddressToString("Delegate owns SM!", delegate));
            assertEq(IStrategyManager(sm).unrealizedLosses(),          0,          _addAddressToString("Unrealized losses are set!", sm));

            assertEq(IAllocationStrategy(us).strategyManager(),         sm,              _addAddressToString("Invalid SM!", us));
            assertEq(IAllocationStrategy(us).strategyDelegate(),        delegate,        _addAddressToString("Invalid SD!", us));
            assertEq(IAllocationStrategy(us).strategyProtocolFeeRate(), protocolFeeRate, _addAddressToString("Protocol fee rate!", us));
            assertEq(IAllocationStrategy(us).strategyDelegateFeeRate(), 0,               _addAddressToString("Delegate fee rate!", us));

            assertEq(
                IAllocationStrategy(us).assetsUnderManagement(),
                IStrategyManager(sm).assetsUnderManagement(),
                _addAddressToString("AUM missmatch!", us)
            );

            if (aaveTokens[sm] == address(0)) {
                address expectedImplementation = allocationStrategyV100Implementation;

                assertEq(IStrategyManager(sm).totalShares(),           BOOTSTRAP_MINT, _addAddressToString("Invalid total shares!", sm));
                assertEq(IStrategyManager(sm).assetsUnderManagement(), BOOTSTRAP_MINT, _addAddressToString("Invalid AUM!", sm));

                assertEq(IAllocationStrategy(us).yieldCap(), YIELD_CAP, _addAddressToString("Invalid yield cap!", us));
                assertEq(IAllocationStrategy(us).factory(), allocationStrategyFactory, _addAddressToString("Invalid us factory!", us));
                assertEq(IAllocationStrategy(us).implementation(), expectedImplementation, _addAddressToString("Implementation!", us));
            } else {
                address expectedImplementation = modularAaveStrategyV100Implementation;

                assertApproxEqAbs(
                    IStrategyManager(sm).totalShares(), BOOTSTRAP_MINT, AAVE_ROUNDING_ERROR, _addAddressToString("Total shares!", sm)
                );

                assertApproxEqAbs(
                    IStrategyManager(sm).assetsUnderManagement(), BOOTSTRAP_MINT, AAVE_ROUNDING_ERROR, _addAddressToString("AUM!", sm)
                );

                assertEq(IAaveV3Strategy(us).factory(),        modularAaveStrategyFactory, _addAddressToString("Invalid us factory!", us));
                assertEq(IAaveV3Strategy(us).implementation(), expectedImplementation,     _addAddressToString("Implementation!", us));

                assertEq(IAaveV3Strategy(us).aaveToken(),                   aaveTokens[sm], _addAddressToString("Invalid aToken!", us));
                assertEq(IAaveV3Strategy(us).useVirtualUnderlyingBalance(), true,           _addAddressToString("Virtual balance!", us));
            }
        }
    }

}

contract ValidateSecondProposalScheduling is ModularReleaseValidationScriptBase {

    function run() external view {
        (address[] memory managers,,) = _pools();

        (,, uint32 batchTimestamp,,) = tl.proposals(LATEST_PROPOSAL_ID + PROPOSAL_COUNT_FIRST_BATCH + 1);

        uint256 proposalId = LATEST_PROPOSAL_ID + PROPOSAL_COUNT_FIRST_BATCH;

        for (uint256 i; i < managers.length; i++) {
            address          poolManager    = managers[i];
            address[] memory poolStrategies = modularStrategies[poolManager];

            for (uint256 j; j < poolStrategies.length; j++) {
                proposalId++;

                bytes32 expectedProposalHash =
                    _proposalHash(poolManager, abi.encodeWithSignature("addStrategyManager(address)", poolStrategies[j]));

                (bytes32 proposalHash, bool isUnschedulable, uint32 scheduledAt, uint32 delayedUntil, uint32 validUntil) =
                    tl.proposals(proposalId);

                assertEq(proposalHash,    expectedProposalHash,          _addProposalIdToString("Invalid proposal hash!", proposalId));
                assertEq(isUnschedulable, true,                          _addProposalIdToString("Not unschedulable!", proposalId));
                assertEq(scheduledAt,     batchTimestamp,                _addProposalIdToString("Invalid proposal date!", proposalId));
                assertEq(delayedUntil,    scheduledAt + 3 days,          _addProposalIdToString("Invalid execution window!", proposalId));
                assertEq(validUntil,      scheduledAt + 3 days + 2 days, _addProposalIdToString("Invalid execution window!", proposalId));

                assertEq(
                    IPoolManager(poolManager).isStrategyManager(poolStrategies[j]),
                    false,
                    _addProposalIdToString("Strategy manager is already attached!", proposalId)
                );
            }
        }

        assertEq(tl.latestProposalId(), proposalId, "Invalid latest proposal id!");
    }

}

contract ValidateSecondProposalExecution is ModularReleaseValidationScriptBase {

    function run() external view {
        (address[] memory managers,,) = _pools();

        uint256 proposalId = LATEST_PROPOSAL_ID + PROPOSAL_COUNT_FIRST_BATCH;

        for (uint256 i; i < managers.length; i++) {
            address[] memory poolStrategies = modularStrategies[managers[i]];

            for (uint256 j; j < poolStrategies.length; j++) {
                proposalId++;

                assertEq(
                    IPoolManager(managers[i]).isStrategyManager(poolStrategies[j]),
                    true,
                    _addProposalIdToString("SM was not attached!", proposalId)
                );

                assertEq(
                    IPoolManager(managers[i]).strategyCapOf(poolStrategies[j]),
                    0,
                    _addProposalIdToString("Strategy cap is already set!", proposalId)
                );

                (bytes32 proposalHash,,,,) = tl.proposals(proposalId);

                assertEq(proposalHash, bytes32(0), _addProposalIdToString("Proposal was not executed!", proposalId));
            }
        }

        assertEq(tl.latestProposalId(), proposalId, "Invalid latest proposal id!");
    }

}

contract ValidateWhitelistManagedWalletsAndActivateSM is ModularReleaseValidationScriptBase {

    address configuredPoolManager = syrupUSDCPoolManager;

    function run() external view {
        for (uint256 i; i < strategies.length; i++) {
            address[] memory wallets = managedWallets[strategies[i]];

            for (uint256 j; j < wallets.length; j++) {
                assertEq(
                    IGlobals(globals).isInstanceOf("MAPLE_MANAGED_WALLET", wallets[j]),
                    true,
                    _addAddressToString("Managed wallet is not registered!", wallets[j])
                );
            }
        }

        assertEq(IGlobals(globals).isInstanceOf("LIQUIDITY_ROUTER_BOT", LIQUIDITY_BOT), true, "Liquidity bot is not registered!");

        address strategy = CONFIGURED_STRATEGY;
        address delegate = strategyDelegates[_configuredStrategyIndex()];

        assertEq(IStrategyManager(strategy).active(), true, _addAddressToString("Strategy manager is not active!", strategy));

        assertEq(
            IGlobals(globals).ownedStrategyManager(delegate),
            strategy,
            _addAddressToString("Strategy delegate does not own the manager!", delegate)
        );

        assertEq(
            IPoolManager(configuredPoolManager).strategyCapOf(strategy),
            CONFIGURED_STRATEGY_CAP,
            _addAddressToString("Invalid strategy cap!", configuredPoolManager)
        );

        address pyusdMislUnderlyingStrategy = IStrategyManager(PYUSD_MISL_USDC).underlyingStrategy();

        assertEq(
            IAllocationStrategy(pyusdMislUnderlyingStrategy).strategyProtocolFeeRate(),
            PYUSD_MISL_USDC_PROTOCOL_FEE_RATE,
            _addAddressToString("Invalid protocol fee rate!", pyusdMislUnderlyingStrategy)
        );

        (address[] memory poolManagers,, address[] memory openTermLoanManagers) = _pools();

        for (uint256 i; i < poolManagers.length; i++) {
            assertEq(
                IPoolManager(poolManagers[i]).strategyCapOf(openTermLoanManagers[i]),
                type(uint256).max,
                _addAddressToString("Invalid open-term loan manager cap!", poolManagers[i])
            );
        }
    }

}

contract ValidateAllocationStrategyConfiguration is ModularReleaseValidationScriptBase {

    function run() external view {
        address[] memory wallets            = managedWallets[CONFIGURED_STRATEGY];
        address          underlyingStrategy = IStrategyManager(CONFIGURED_STRATEGY).underlyingStrategy();

        for (uint256 i; i < wallets.length; i++) {
            address managedWallet = wallets[i];

            (bool canDeployAssets, bool canReturnAssets, bool canRealizeYield) =
                IAllocationStrategy(underlyingStrategy).permissions(managedWallet);

            assertEq(canDeployAssets, true, _addAddressToString("Managed wallet cannot deploy assets!", managedWallet));
            assertEq(canReturnAssets, true, _addAddressToString("Managed wallet cannot return assets!", managedWallet));
            assertEq(canRealizeYield, true, _addAddressToString("Managed wallet cannot realize yield!", managedWallet));

            assertEq(
                IAllocationStrategy(underlyingStrategy).deploymentCapOf(managedWallet),
                DEPLOYMENT_CAP,
                _addAddressToString("Invalid deployment cap!", managedWallet)
            );
        }

        assertEq(
            IAllocationStrategy(underlyingStrategy).yieldCap(),
            CONFIGURED_STRATEGY_YIELD_CAP,
            _addAddressToString("Invalid yield cap!", underlyingStrategy)
        );
    }

}

contract ValidateActivateRemainingSMs is ModularReleaseValidationScriptBase {

    function run() external view {
        for (uint256 i; i < strategies.length; i++) {
            address strategy = strategies[i];
            address delegate = strategyDelegates[i];

            assertEq(IStrategyManager(strategy).active(), true, _addAddressToString("Strategy manager is not active!", strategy));

            assertEq(
                IGlobals(globals).ownedStrategyManager(delegate),
                strategy,
                _addAddressToString("Strategy delegate does not own the manager!", delegate)
            );
        }
    }

}
