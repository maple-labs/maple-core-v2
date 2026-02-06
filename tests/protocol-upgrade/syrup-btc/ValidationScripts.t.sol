// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console as console, Test } from "../../../contracts/Runner.sol";

import {
    IAssetController,
    IAssetControllerOracle,
    IBitcoinStrategy,
    ICompositeToken,
    IERC20Like,
    IGlobals,
    IGovernorTimelock,
    IMapleProxyFactory,
    ISyrupBitcoinRouter,
    IWithdrawalManagerQueue as IWithdrawalManager,
    IPoolManager,
    IPoolPermissionManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { UpgradeAddressRegistry } from "../UpgradeAddressRegistry.sol";

contract SyrupBTCValidationScriptBase is UpgradeAddressRegistry, Test {

    uint256 expectedManagementFeeRate = 0;     // 0%
    uint256 expectedLiquidityCap      = 0.01e8; // 0.01 WBTC

    IGovernorTimelock tl = IGovernorTimelock(timelock);

    function _proposalHash(address target, bytes memory calldata_) internal pure returns (bytes32) {
        return keccak256(abi.encode(target, calldata_));
    }

}

contract ValidateInitialContractDeployment is SyrupBTCValidationScriptBase {

    function run() public virtual {
        assertEq(IMapleProxyFactory(bitcoinStrategyFactory).mapleGlobals(),   globals, "Invalid maple globals!");
        assertEq(IMapleProxyFactory(bitcoinStrategyFactory).defaultVersion(), 0,       "Invalid default version!");

        assertEq(ICompositeToken(compositeTokenProxy).name(),        "Maple synthBTC", "Invalid name!");
        assertEq(ICompositeToken(compositeTokenProxy).symbol(),      "msynthBTC",      "Invalid symbol!");
        assertEq(ICompositeToken(compositeTokenProxy).decimals(),    8,                "Invalid decimals!");
        assertEq(ICompositeToken(compositeTokenProxy).totalSupply(), 0,                "Invalid total supply!");
        assertEq(ICompositeToken(compositeTokenProxy).allAllowed(),  false,            "Expected allAllowed to be false!");
    }

}

contract ValidateGlobalsConfiguration is SyrupBTCValidationScriptBase {

    function run() public virtual {
        assertTrue(IGlobals(globals).isPoolDelegate(syrupBitcoinPoolDelegate), "Not valid pool delegate!");

        assertTrue(
            IGlobals(globals).isInstanceOf("COMPOSITE_DEPOSIT_ASSET", wbtc),
            "Not valid composite deposit asset!"
        );

        assertTrue(
            IGlobals(globals).isInstanceOf("COMPOSITE_POOL_ASSET", compositeTokenProxy),
            "Not valid composite pool asset!"
        );

        assertTrue(
            IGlobals(globals).isInstanceOf("STRATEGY_FACTORY", bitcoinStrategyFactory),
            "Not valid strategy factory!"
        );
    }

}

contract ValidateFirstProposalsScheduling is SyrupBTCValidationScriptBase {

    function run() public virtual {
        bytes32 proposalHash_1 = _proposalHash(
            withdrawalManagerQueueFactory,
            abi.encodeWithSignature(
                "registerImplementation(uint256,address,address)",
                200,
                mapleWithdrawalManagerV200Implementation,
                mapleWithdrawalManagerV200Initializer
            )
        );

        bytes32 proposalHash_2 = _proposalHash(
            withdrawalManagerQueueFactory,
            abi.encodeWithSignature(
                "enableUpgradePath(uint256,uint256,address)",
                100,
                200,
                mapleWithdrawalManagerV200Migrator
            )
        );

        bytes32 proposalHash_3 = _proposalHash(withdrawalManagerQueueFactory, abi.encodeWithSignature("setDefaultVersion(uint256)", 200));

        bytes32 proposalHash_4 = _proposalHash(
            bitcoinStrategyFactory,
            abi.encodeWithSignature(
                "registerImplementation(uint256,address,address)",
                100,
                bitcoinStrategyV100Implementation,
                bitcoinStrategyV100Initializer
            )
        );

        bytes32 proposalHash_5 = _proposalHash(bitcoinStrategyFactory, abi.encodeWithSignature("setDefaultVersion(uint256)", 100));

        bytes32 proposalHash_6 = _proposalHash(
            globals, abi.encodeWithSignature("setValidPoolAsset(address,bool)", compositeTokenProxy, true)
        );

        // TODO: Replace with the timestamp of the proposal transaction.
        uint32 proposalTimestamp = uint32(block.timestamp);

        (
            bytes32 proposalHash,
            bool    isUnschedulable,
            uint32  scheduledAt,
            uint32  delayedUntil,
            uint32  validUntil
        ) = tl.proposals(5);

        assertEq(proposalHash,    proposalHash_1,             "Invalid proposal hash! (id: 5)");
        assertEq(isUnschedulable, true,                       "Proposal is not unschedulable! (id: 5)");
        assertEq(scheduledAt,     proposalTimestamp,          "Proposal date is invalid! (id: 5)");
        assertEq(delayedUntil,    proposalTimestamp + 3 days, "Execution window starting date is invalid! (id: 5)");
        assertEq(validUntil,      proposalTimestamp + 5 days, "Execution window ending date is invalid! (id: 5)");

        (
            proposalHash,
            isUnschedulable,
            scheduledAt,
            delayedUntil,
            validUntil
        ) = tl.proposals(6);

        assertEq(proposalHash,    proposalHash_2,             "Invalid proposal hash! (id: 6)");
        assertEq(isUnschedulable, true,                       "Proposal is not unschedulable! (id: 6)");
        assertEq(scheduledAt,     proposalTimestamp,          "Proposal date is invalid! (id: 6)");
        assertEq(delayedUntil,    proposalTimestamp + 3 days, "Execution window starting date is invalid! (id: 6)");
        assertEq(validUntil,      proposalTimestamp + 5 days, "Execution window ending date is invalid! (id: 6)");

        (
            proposalHash,
            isUnschedulable,
            scheduledAt,
            delayedUntil,
            validUntil
        ) = tl.proposals(7);

        assertEq(proposalHash,    proposalHash_3,             "Invalid proposal hash! (id: 7)");
        assertEq(isUnschedulable, true,                       "Proposal is not unschedulable! (id: 7)");
        assertEq(scheduledAt,     proposalTimestamp,          "Proposal date is invalid! (id: 7)");
        assertEq(delayedUntil,    proposalTimestamp + 3 days, "Execution window starting date is invalid! (id: 7)");
        assertEq(validUntil,      proposalTimestamp + 5 days, "Execution window ending date is invalid! (id: 7)");

        (
            proposalHash,
            isUnschedulable,
            scheduledAt,
            delayedUntil,
            validUntil
        ) = tl.proposals(8);

        assertEq(proposalHash,    proposalHash_4,             "Invalid proposal hash! (id: 8)");
        assertEq(isUnschedulable, true,                       "Proposal is not unschedulable! (id: 8)");
        assertEq(scheduledAt,     proposalTimestamp,          "Proposal date is invalid! (id: 8)");
        assertEq(delayedUntil,    proposalTimestamp + 3 days, "Execution window starting date is invalid! (id: 8)");
        assertEq(validUntil,      proposalTimestamp + 5 days, "Execution window ending date is invalid! (id: 8)");

        (
            proposalHash,
            isUnschedulable,
            scheduledAt,
            delayedUntil,
            validUntil
        ) = tl.proposals(9);

        assertEq(proposalHash,    proposalHash_5,             "Invalid proposal hash! (id: 9)");
        assertEq(isUnschedulable, true,                       "Proposal is not unschedulable! (id: 9)");
        assertEq(scheduledAt,     proposalTimestamp,          "Proposal date is invalid! (id: 9)");
        assertEq(delayedUntil,    proposalTimestamp + 3 days, "Execution window starting date is invalid! (id: 9)");
        assertEq(validUntil,      proposalTimestamp + 5 days, "Execution window ending date is invalid! (id: 9)");

        (
            proposalHash,
            isUnschedulable,
            scheduledAt,
            delayedUntil,
            validUntil
        ) = tl.proposals(10);

        assertEq(proposalHash,    proposalHash_6,             "Invalid proposal hash! (id: 10)");
        assertEq(isUnschedulable, true,                       "Proposal is not unschedulable! (id: 10)");
        assertEq(scheduledAt,     proposalTimestamp,          "Proposal date is invalid! (id: 10)");
        assertEq(delayedUntil,    proposalTimestamp + 3 days, "Execution window starting date is invalid! (id: 10)");
        assertEq(validUntil,      proposalTimestamp + 5 days, "Execution window ending date is invalid! (id: 10)");

        assertEq(tl.latestProposalId(), 10, "Invalid latest proposal id!");
    }

}

contract ValidateFirstProposalsExecution is SyrupBTCValidationScriptBase {

    function run() public virtual {
        assertEq(
            IMapleProxyFactory(withdrawalManagerQueueFactory).implementationOf(200),
            mapleWithdrawalManagerV200Implementation,
            "Invalid withdrawal manager implementation for version 200!"
        );

        assertEq(
            IMapleProxyFactory(withdrawalManagerQueueFactory).versionOf(mapleWithdrawalManagerV200Implementation),
            200,
            "Invalid withdrawal manager version of new implementation!"
        );

        assertEq(
            IMapleProxyFactory(withdrawalManagerQueueFactory).migratorForPath(200, 200),
            mapleWithdrawalManagerV200Initializer,
            "Invalid withdrawal manager initializer for version 200!"
        );

        assertEq(
            IMapleProxyFactory(withdrawalManagerQueueFactory).upgradeEnabledForPath(100, 200),
            true,
            "Upgrade path is not enabled for migration from version 100 to 200!"
        );

        assertEq(
            IMapleProxyFactory(withdrawalManagerQueueFactory).migratorForPath(100, 200),
            mapleWithdrawalManagerV200Migrator,
            "Invalid withdrawal manager migrator for migration from version 100 to 200!"
        );

        assertEq(
            IMapleProxyFactory(withdrawalManagerQueueFactory).defaultVersion(),
            200,
            "Invalid default withdrawal manager version!"
        );

        assertEq(
            IMapleProxyFactory(bitcoinStrategyFactory).implementationOf(100),
            bitcoinStrategyV100Implementation,
            "Invalid bitcoin strategy implementation for version 100!"
        );

        assertEq(
            IMapleProxyFactory(bitcoinStrategyFactory).versionOf(bitcoinStrategyV100Implementation),
            100,
            "Invalid bitcoin strategy version of new implementation!"
        );

        assertEq(
            IMapleProxyFactory(bitcoinStrategyFactory).migratorForPath(100, 100),
            bitcoinStrategyV100Initializer,
            "Invalid bitcoin strategy initializer for version 100!"
        );

        assertEq(
            IMapleProxyFactory(bitcoinStrategyFactory).defaultVersion(),
            100,
            "Invalid default bitcoin strategy version!"
        );

        assertEq(
            IGlobals(globals).isPoolAsset(compositeTokenProxy),
            true,
            "Composite token is not a valid pool asset!"
        );
    }

}

contract ValidatePoolDeployment is SyrupBTCValidationScriptBase {

    function run() public virtual {
        address withdrawalManagerProxy = IPoolManager(syrupBitcoinPoolManager).withdrawalManager();

        /**********************************************************************************************************************************/
        /*** Pool Assertions                                                                                                            ***/
        /**********************************************************************************************************************************/

        assertEq(IERC20Like(syrupBitcoinPool).name(),   "syrupBTC", "Invalid pool name!");
        assertEq(IERC20Like(syrupBitcoinPool).symbol(), "syrupBTC", "Invalid pool symbol!");

        /**********************************************************************************************************************************/
        /*** Pool Manager Assertions                                                                                                    ***/
        /**********************************************************************************************************************************/

        assertEq(
            IPoolManager(syrupBitcoinPoolManager).pool(),
            syrupBitcoinPool,
            "Invalid pool on pool manager!"
        );

        assertEq(
            IPoolManager(syrupBitcoinPoolManager).strategyList(0),
            bitcoinStrategy1,
            "Invalid first bitcoin strategy on pool manager!"
        );

        assertEq(
            IPoolManager(syrupBitcoinPoolManager).strategyList(1),
            bitcoinStrategy2,
            "Invalid second bitcoin strategy on pool manager!"
        );

        assertEq(
            IPoolManager(syrupBitcoinPoolManager).strategyList(2),
            bitcoinStrategy3,
            "Invalid third bitcoin strategy on pool manager!"
        );

        assertEq(
            IPoolManager(syrupBitcoinPoolManager).strategyListLength(),
            3,
            "Invalid number of bitcoin strategies!"
        );

        assertEq(
            IPoolManager(syrupBitcoinPoolManager).factory(),
            poolManagerFactory,
            "Invalid pool manager factory!"
        );

        assertEq(
            IPoolManager(syrupBitcoinPoolManager).poolPermissionManager(),
            poolPermissionManager,
            "Invalid pool permission manager!"
        );

        assertEq(
            IPoolManager(syrupBitcoinPoolManager).delegateManagementFeeRate(),
            expectedManagementFeeRate,
            "Invalid delegate management fee rate!"
        );

        assertEq(
            IPoolManager(syrupBitcoinPoolManager).liquidityCap(),
            expectedLiquidityCap,
            "Invalid liquidity cap!"
        );

        assertEq(
            IPoolManager(syrupBitcoinPoolManager).globals(),
            globals,
            "Invalid globals on pool manager!"
        );

        assertEq(
            IPoolManager(syrupBitcoinPoolManager).governor(),
            timelock,
            "Invalid governor on pool manager!"
        );

        assertEq(
            IPoolManager(syrupBitcoinPoolManager).poolDelegate(),
            syrupBitcoinPoolDelegate,
            "Invalid pool delegate on pool manager!"
        );

        /**********************************************************************************************************************************/
        /*** Withdrawal Manager Assertions                                                                                              ***/
        /**********************************************************************************************************************************/

        assertEq(
            IWithdrawalManager(withdrawalManagerProxy).totalShares(),
            0,
            "Invalid total shares on withdrawal manager!"
        );

        assertEq(
            IWithdrawalManager(withdrawalManagerProxy).pool(),
            syrupBitcoinPool,
            "Invalid pool on withdrawal manager!"
        );

        assertEq(
            IWithdrawalManager(withdrawalManagerProxy).globals(),
            globals,
            "Invalid globals on withdrawal manager!"
        );

        assertEq(
            IWithdrawalManager(withdrawalManagerProxy).governor(),
            timelock,
            "Invalid governor on withdrawal manager!"
        );

        assertEq(
            IWithdrawalManager(withdrawalManagerProxy).poolDelegate(),
            syrupBitcoinPoolDelegate,
            "Invalid pool delegate on withdrawal manager!"
        );

        assertEq(
            IWithdrawalManager(withdrawalManagerProxy).asset(),
            compositeTokenProxy,
            "Invalid asset on withdrawal manager!"
        );

        assertEq(
            IWithdrawalManager(withdrawalManagerProxy).poolManager(),
            syrupBitcoinPoolManager,
            "Invalid pool manager on withdrawal manager!"
        );

        assertEq(
            IWithdrawalManager(withdrawalManagerProxy).factory(),
            withdrawalManagerQueueFactory,
            "Invalid withdrawal manager factory!"
        );

        assertEq(
            IWithdrawalManager(withdrawalManagerProxy).implementation(),
            mapleWithdrawalManagerV200Implementation,
            "Invalid withdrawal manager implementation!"
        );

        /**********************************************************************************************************************************/
        /*** Bitcoin Strategy Assertions                                                                                                ***/
        /**********************************************************************************************************************************/

        assertEq(
            IBitcoinStrategy(bitcoinStrategy1).pool(),
            syrupBitcoinPool,
            "Invalid pool on bitcoin strategy 1!"
        );

        assertEq(
            IBitcoinStrategy(bitcoinStrategy1).poolAsset(),
            compositeTokenProxy,
            "Invalid pool asset on bitcoin strategy 1!"
        );

        assertEq(
            IBitcoinStrategy(bitcoinStrategy1).factory(),
            bitcoinStrategyFactory,
            "Invalid factory on bitcoin strategy 1!"
        );

        assertEq(
            IBitcoinStrategy(bitcoinStrategy1).poolManager(),
            syrupBitcoinPoolManager,
            "Invalid pool manager on bitcoin strategy 1!"
        );

        assertEq(
            IBitcoinStrategy(bitcoinStrategy1).implementation(),
            bitcoinStrategyV100Implementation,
            "Invalid implementation on bitcoin strategy 1!"
        );

        assertEq(
            IBitcoinStrategy(bitcoinStrategy2).pool(),
            syrupBitcoinPool,
            "Invalid pool on bitcoin strategy 2!"
        );

        assertEq(
            IBitcoinStrategy(bitcoinStrategy2).poolAsset(),
            compositeTokenProxy,
            "Invalid pool asset on bitcoin strategy 2!"
        );

        assertEq(
            IBitcoinStrategy(bitcoinStrategy2).factory(),
            bitcoinStrategyFactory,
            "Invalid factory on bitcoin strategy 2!"
        );

        assertEq(
            IBitcoinStrategy(bitcoinStrategy2).poolManager(),
            syrupBitcoinPoolManager,
            "Invalid pool manager on bitcoin strategy 2!"
        );

        assertEq(
            IBitcoinStrategy(bitcoinStrategy2).implementation(),
            bitcoinStrategyV100Implementation,
            "Invalid implementation on bitcoin strategy 2!"
        );

        assertEq(
            IBitcoinStrategy(bitcoinStrategy3).pool(),
            syrupBitcoinPool,
            "Invalid pool on bitcoin strategy 3!"
        );

        assertEq(
            IBitcoinStrategy(bitcoinStrategy3).poolAsset(),
            compositeTokenProxy,
            "Invalid pool asset on bitcoin strategy 3!"
        );

        assertEq(
            IBitcoinStrategy(bitcoinStrategy3).factory(),
            bitcoinStrategyFactory,
            "Invalid factory on bitcoin strategy 3!"
        );

        assertEq(
            IBitcoinStrategy(bitcoinStrategy3).poolManager(),
            syrupBitcoinPoolManager,
            "Invalid pool manager on bitcoin strategy 3!"
        );

        assertEq(
            IBitcoinStrategy(bitcoinStrategy3).implementation(),
            bitcoinStrategyV100Implementation,
            "Invalid implementation on bitcoin strategy 3!"
        );

    }

}

contract ValidateAssetControllerOracleAndRouterDeployment is SyrupBTCValidationScriptBase {

    function run() public virtual {
        /**********************************************************************************************************************************/
        /*** Asset Controller Oracle Assertions                                                                                         ***/
        /**********************************************************************************************************************************/

        assertEq(
            IAssetControllerOracle(assetPriceOracleProxy).implementation(),
            assetPriceOracleV100Implementation,
            "Invalid implementation on asset controller oracle!"
        );

        assertEq(
            IAssetControllerOracle(assetPriceOracleProxy).globals(),
            globals,
            "Invalid globals on asset controller oracle!"
        );

        /**********************************************************************************************************************************/
        /*** Bitcoin Router Assertions                                                                                                  ***/
        /**********************************************************************************************************************************/

        assertEq(
            ISyrupBitcoinRouter(bitcoinRouterProxy).implementation(),
            bitcoinRouterV100Implementation,
            "Invalid implementation on bitcoin router!"
        );

        assertEq(
            ISyrupBitcoinRouter(bitcoinRouterProxy).globals(),
            globals,
            "Invalid globals on bitcoin router!"
        );

        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).poolManager(), syrupBitcoinPoolManager,
            "Invalid pool manager on bitcoin router!"
        );

        assertEq(
            ISyrupBitcoinRouter(bitcoinRouterProxy).pool(),
            syrupBitcoinPool,
            "Invalid pool on bitcoin router!"
        );
    }

}

contract ValidateSecondGlobalConfiguration is SyrupBTCValidationScriptBase {

    function run() public virtual {
        assertTrue(IGlobals(globals).isInstanceOf("CONTROLLER_ORACLE", assetPriceOracleProxy), "Not valid controller oracle!");
        assertTrue(IGlobals(globals).isInstanceOf("SYRUP_BTC_ROUTER",  bitcoinRouterProxy),    "Not valid syrup bitcoin router!");
        assertTrue(IGlobals(globals).isInstanceOf("BITCOIN_STRATEGY",  bitcoinStrategy1),      "Not valid bitcoin strategy 1!");
        assertTrue(IGlobals(globals).isInstanceOf("BITCOIN_STRATEGY",  bitcoinStrategy2),      "Not valid bitcoin strategy 2!");
        assertTrue(IGlobals(globals).isInstanceOf("BITCOIN_STRATEGY",  bitcoinStrategy3),      "Not valid bitcoin strategy 3!");
    }

}

contract ValidateAssetControllerDeployment is SyrupBTCValidationScriptBase {

    function run() public virtual {
        assertEq(
            IAssetController(assetControllerProxy).globals(),
            globals,
            "Invalid globals on asset controller!"
        );

        assertEq(
            IAssetController(assetControllerProxy).implementation(),
            assetControllerV100Implementation,
            "Invalid implementation on asset controller!"
        );

        assertEq(
            IAssetController(assetControllerProxy).oracle(),
            assetPriceOracleProxy,
            "Invalid oracle on asset controller!"
        );

        assertEq(
            IAssetController(assetControllerProxy).router(),
            bitcoinRouterProxy,
            "Invalid router on asset controller!"
        );

        assertEq(
            IAssetController(assetControllerProxy).poolAsset(),
            compositeTokenProxy,
            "Invalid pool asset on asset controller!"
        );
    }

}

contract ValidateLastGlobalConfiguration is SyrupBTCValidationScriptBase {

    function run() public virtual {
        address withdrawalManager = IPoolManager(syrupBitcoinPoolManager).withdrawalManager();

        assertTrue(
            IGlobals(globals).isInstanceOf("ASSET_CONTROLLER", assetControllerProxy),
            "Asset controller not whitelisted on globals!"
        );

        assertTrue(
            IAssetController(assetControllerProxy).isStrategy(bitcoinStrategy1),
            "Bitcoin strategy 1 is not strategy on asset controller!"
        );

        assertTrue(
            IAssetController(assetControllerProxy).isStrategy(bitcoinStrategy2),
            "Bitcoin strategy 2 is not strategy on asset controller!"
        );

        assertTrue(
            IAssetController(assetControllerProxy).isStrategy(bitcoinStrategy3),
            "Bitcoin strategy 3 is not strategy on asset controller!"
        );

        assertEq(
            ISyrupBitcoinRouter(bitcoinRouterProxy).assetController(wbtc),
            assetControllerProxy,
            "Invalid asset controller for WBTC on bitcoin router!"
        );

        assertEq(
            IBitcoinStrategy(bitcoinStrategy1).controllers(wbtc),
            assetControllerProxy,
            "Invalid asset controller for WBTC on bitcoin strategy 1!"
        );

        assertEq(
            IBitcoinStrategy(bitcoinStrategy2).controllers(wbtc),
            assetControllerProxy,
            "Invalid asset controller for WBTC on bitcoin strategy 2!"
        );

        assertEq(
            IBitcoinStrategy(bitcoinStrategy3).controllers(wbtc),
            assetControllerProxy,
            "Invalid asset controller for WBTC on bitcoin strategy 3!"
        );

        (
            bool canDeploy,
            bool canReconcile,
            bool canSchedule
        ) = IBitcoinStrategy(bitcoinStrategy1).permissions(bitcoinStrategy1Manager);

        assertEq(canDeploy,    true, "Manager not allowed to deploy on bitcoin strategy 1!");
        assertEq(canReconcile, true, "Manager not allowed to reconcile on bitcoin strategy 1!");
        assertEq(canSchedule,  true, "Manager not allowed to schedule on bitcoin strategy 1!");

        (
            canDeploy,
            canReconcile,
            canSchedule
        ) = IBitcoinStrategy(bitcoinStrategy2).permissions(bitcoinStrategy2Manager);

        assertEq(canDeploy,    true, "Manager not allowed to deploy on bitcoin strategy 2!");
        assertEq(canReconcile, true, "Manager not allowed to reconcile on bitcoin strategy 2!");
        assertEq(canSchedule,  true, "Manager not allowed to schedule on bitcoin strategy 2!");

        (
            canDeploy,
            canReconcile,
            canSchedule
        ) = IBitcoinStrategy(bitcoinStrategy3).permissions(bitcoinStrategy3Manager);

        assertEq(canDeploy,    true, "Manager not allowed to deploy on bitcoin strategy 3!");
        assertEq(canReconcile, true, "Manager not allowed to reconcile on bitcoin strategy 3!");
        assertEq(canSchedule,  true, "Manager not allowed to schedule on bitcoin strategy 3!");

        assertEq(
            IPoolPermissionManager(poolPermissionManager).permissionLevels(syrupBitcoinPoolManager),
            1,
            "Invalid permission level on pool permission manager!"
        );

        uint256 bitmap              = 2 ** 5;
        uint256 requestRedeemBitmap = 2 ** 6;

        assertEq(
            IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:transfer"),
            0,
            "Invalid transfer bitmap on pool permission manager!"
        );

        assertEq(
            IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:transferFrom"),
            0,
            "Invalid transferFrom bitmap on pool permission manager!"
        );

        assertEq(
            IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:deposit"),
            bitmap,
            "Invalid deposit bitmap on pool permission manager!"
        );

        assertEq(
            IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:depositWithPermit"),
            bitmap,
            "Invalid depositWithPermit bitmap on pool permission manager!"
        );

        assertEq(
            IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:mint"),
            bitmap,
            "Invalid mint bitmap on pool permission manager!"
        );

        assertEq(
            IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:mintWithPermit"),
            bitmap,
            "Invalid mintWithPermit bitmap on pool permission manager!"
        );

        assertEq(
            IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:redeem"),
            bitmap,
            "Invalid redeem bitmap on pool permission manager!"
        );

        assertEq(
            IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:withdraw"),
            bitmap,
            "Invalid withdraw bitmap on pool permission manager!"
        );

        assertEq(
            IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:removeShares"),
            bitmap,
            "Invalid removeShares bitmap on pool permission manager!"
        );

        assertEq(
            IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:requestRedeem"),
            requestRedeemBitmap,
            "Invalid requestRedeem bitmap on pool permission manager!"
        );

        assertEq(
            IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:requestWithdraw"),
            bitmap,
            "Invalid requestWithdraw bitmap on pool permission manager!"
        );

        assertEq(
            IPoolPermissionManager(poolPermissionManager).lenderBitmaps(bitcoinRouterProxy),
            bitmap,
            "Invalid lender bitmap for bitcoin router!"
        );

        assertEq(
            IWithdrawalManager(withdrawalManager).isManualWithdrawal(bitcoinRouterProxy),
            true,
            "Withdrawal is not manual for bitcoin router!"
        );
    }

}

contract ValidateSecondProposalsScheduling is SyrupBTCValidationScriptBase {

    function run() public virtual {
        address[] memory addresses = new address[](6);
        addresses[0]               = syrupBitcoinPool;
        addresses[1]               = assetControllerProxy;
        addresses[2]               = bitcoinRouterProxy;
        addresses[3]               = bitcoinStrategy1;
        addresses[4]               = bitcoinStrategy2;
        addresses[5]               = bitcoinStrategy3;

        bool[] memory allowed = new bool[](6);
        allowed[0]            = true;
        allowed[1]            = true;
        allowed[2]            = true;
        allowed[3]            = true;
        allowed[4]            = true;
        allowed[5]            = true;

        bytes32 proposalHash_1 = _proposalHash(
            compositeTokenProxy,
            abi.encodeWithSignature(
                "allowAddresses(address[],bool[])",
                addresses,
                allowed
            )
        );

        addresses    = new address[](1);
        addresses[0] = wbtc;

        allowed      = new bool[](1);
        allowed[0]   = true;

        bytes32 proposalHash_2 = _proposalHash(
            assetControllerProxy,
            abi.encodeWithSignature(
                "setAssets(address[],bool[],bool[],bool[],bool[])",
                addresses,
                allowed,
                allowed,
                allowed,
                allowed
            )
        );

        addresses[0] = assetControllerProxy;
        allowed[0]   = true;

        bytes32 proposalHash_3 = _proposalHash(
            compositeTokenProxy,
            abi.encodeWithSignature(
                "setAssetControllers(address[],bool[])",
                addresses,
                allowed
            )
        );

        // TODO: Replace with the timestamp of the proposal transaction.
        uint32 proposalTimestamp = uint32(block.timestamp);

        (
            bytes32 proposalHash,
            bool    isUnschedulable,
            uint32  scheduledAt,
            uint32  delayedUntil,
            uint32  validUntil
        ) = tl.proposals(11);

        assertEq(proposalHash,    proposalHash_1,             "Invalid proposal hash! (id: 11)");
        assertEq(isUnschedulable, true,                       "Proposal is not unschedulable! (id: 11)");
        assertEq(scheduledAt,     proposalTimestamp,          "Proposal date is invalid! (id: 11)");
        assertEq(delayedUntil,    proposalTimestamp + 3 days, "Execution window starting date is invalid! (id: 11)");
        assertEq(validUntil,      proposalTimestamp + 5 days, "Execution window ending date is invalid! (id: 11)");

        (
            proposalHash,
            isUnschedulable,
            scheduledAt,
            delayedUntil,
            validUntil
        ) = tl.proposals(12);

        assertEq(proposalHash,    proposalHash_2,             "Invalid proposal hash! (id: 12)");
        assertEq(isUnschedulable, true,                       "Proposal is not unschedulable! (id: 12)");
        assertEq(scheduledAt,     proposalTimestamp,          "Proposal date is invalid! (id: 12)");
        assertEq(delayedUntil,    proposalTimestamp + 3 days, "Execution window starting date is invalid! (id: 12)");
        assertEq(validUntil,      proposalTimestamp + 5 days, "Execution window ending date is invalid! (id: 12)");

        (
            proposalHash,
            isUnschedulable,
            scheduledAt,
            delayedUntil,
            validUntil
        ) = tl.proposals(13);

        assertEq(proposalHash,    proposalHash_3,             "Invalid proposal hash! (id: 13)");
        assertEq(isUnschedulable, true,                       "Proposal is not unschedulable! (id: 13)");
        assertEq(scheduledAt,     proposalTimestamp,          "Proposal date is invalid! (id: 13)");
        assertEq(delayedUntil,    proposalTimestamp + 3 days, "Execution window starting date is invalid! (id: 13)");
        assertEq(validUntil,      proposalTimestamp + 5 days, "Execution window ending date is invalid! (id: 13)");

        assertEq(tl.latestProposalId(), 13, "Invalid latest proposal id!");
    }

}

contract ValidateSecondProposalsExecutionAndPoolActivation is SyrupBTCValidationScriptBase {

    function run() public virtual {
        assertEq(
            ICompositeToken(compositeTokenProxy).allAllowed(),
            false,
            "allAllowed is not false on composite token!"
        );

        assertEq(
            ICompositeToken(compositeTokenProxy).allowedAddresses(syrupBitcoinPool),
            true,
            "syrupBitcoinPool is not allowed to hold on composite token!"
        );

        assertEq(
            ICompositeToken(compositeTokenProxy).allowedAddresses(assetControllerProxy),
            true,
            "assetControllerProxy is not allowed to hold on composite token!"
        );

        assertEq(
            ICompositeToken(compositeTokenProxy).allowedAddresses(bitcoinRouterProxy),
            true,
            "bitcoinRouterProxy is not allowed to hold on composite token!"
        );

        assertEq(
            ICompositeToken(compositeTokenProxy).allowedAddresses(bitcoinStrategy1),
            true,
            "bitcoinStrategy1 is not allowed to hold on composite token!"
        );

        assertEq(
            ICompositeToken(compositeTokenProxy).allowedAddresses(bitcoinStrategy2),
            true,
            "bitcoinStrategy2 is not allowed to hold on composite token!"
        );

        assertEq(
            ICompositeToken(compositeTokenProxy).allowedAddresses(bitcoinStrategy3),
            true,
            "bitcoinStrategy3 is not allowed to hold on composite token!"
        );

        assertEq(IAssetController(assetControllerProxy).canWrap(wbtc),      true, "Asset controller can not wrap WBTC!");
        assertEq(IAssetController(assetControllerProxy).canUnwrap(wbtc),    true, "Asset controller can not unwrap WBTC!");
        assertEq(IAssetController(assetControllerProxy).canDeploy(wbtc),    true, "Asset controller can not deploy WBTC!");
        assertEq(IAssetController(assetControllerProxy).canReconcile(wbtc), true, "Asset controller can not reconcile WBTC!");

        assertEq(
            ICompositeToken(compositeTokenProxy).controllers(assetControllerProxy),
            true,
            "Asset controller is not a controller on composite token!"
        );

        assertTrue(IPoolManager(syrupBitcoinPoolManager).active(), "Pool manager is not active!");

    }

}
