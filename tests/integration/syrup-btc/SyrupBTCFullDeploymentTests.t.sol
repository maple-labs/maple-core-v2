// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAssetController,
    IAssetControllerOracle,
    IBitcoinStrategy,
    ICompositeToken,
    IERC20,
    IPool,
    IPoolManager,
    ISyrupBitcoinRouter,
    IWithdrawalManagerQueue as IWithdrawalManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { SyrupBitcoinTestBase } from "./SyrupBitcoinTestBase.sol";

contract SyrupBTCFullDeploymentTests is SyrupBitcoinTestBase {

    address bitcoinRouterRedeemer = makeAddr("bitcoinRouterRedeemer");
    address bitcoinStrategy1;
    address bitcoinStrategy2;
    address bitcoinStrategy3;

    uint256 delegateManagementFeeRate = 0.333e6; // 3.33%
    uint256 liquidityCap              = 100e8;

    function setUp() public override {
        start = block.timestamp;

        _createAccounts();
        _createGlobals();
        _createAssets();
        _configureGlobals();
        _createFactories();

        // Step 1: Deploy Composite Token

        compositeTokenImplementation = deployFromFile("Contracts@25", "CompositeToken");
        compositeTokenInitializer    = deployFromFile("Contracts@25", "CompositeTokenInitializer");
        compositeTokenProxy          = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                globals,
                compositeTokenImplementation,
                compositeTokenInitializer,
                abi.encodeWithSignature("initialize(string,string,uint8)", "Synthetic Bitcoin", "synthBTC", 8)
            )
        );

        // Step 2: Whitelist composite token and redeemer on globals

        vm.prank(governor);
        globals.setValidPoolAsset(compositeTokenProxy, true);

        vm.startPrank(operationalAdmin);
        globals.setValidInstanceOf("COMPOSITE_POOL_ASSET", compositeTokenProxy, true);
        globals.setValidInstanceOf("SYRUP_BTC_REDEEMER",   bitcoinRouterRedeemer,  true);
        vm.stopPrank();

        // Step 3: Deploy MaplePool

        strategyFactories       = new address[](3);
        strategyDeploymentData_ = new bytes[](3);

        strategyFactories[0]       = bitcoinStrategyFactory;
        strategyFactories[1]       = bitcoinStrategyFactory;
        strategyFactories[2]       = bitcoinStrategyFactory;
        strategyDeploymentData_[0] = new bytes(0);
        strategyDeploymentData_[1] = new bytes(0);
        strategyDeploymentData_[2] = new bytes(0);

        poolManager = IPoolManager(_deployPoolWithQueue({
            poolDelegate_:              poolDelegate,
            fundsAsset_:                compositeTokenProxy,
            strategyFactories_:         strategyFactories,
            strategyData_:    strategyDeploymentData_,
            name_:                      "Syrup Bitcoin",
            symbol_:                    "syrupBTC",
            liquidityCap_:              liquidityCap,
            delegateManagementFeeRate_: delegateManagementFeeRate
        }));

        pool             = IPool(poolManager.pool());
        bitcoinStrategy1 = poolManager.strategyList(0);
        bitcoinStrategy2 = poolManager.strategyList(1);
        bitcoinStrategy3 = poolManager.strategyList(2);

        // Step 4: Deploy AssetControllerOracle

        priceOracleImplementation = deployFromFile("Contracts@25", "AssetControllerOracle");
        priceOracleProxy          = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                priceOracleImplementation,
                address(0),
                ""
            )
        );

        // Step 5: Deploy SyrupBitcoinRouter

        bitcoinRouterImplementation = deployFromFile("Contracts@25", "SyrupBitcoinRouter");
        bitcoinRouterInitializer    = deployFromFile("Contracts@25", "SyrupBitcoinRouterInitializer");
        bitcoinRouterProxy          = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                bitcoinRouterImplementation,
                bitcoinRouterInitializer,
                abi.encodeWithSignature("initialize(address)", address(poolManager))
            )
        );

        // Step 6: Whitelist contracts on globals

        vm.startPrank(operationalAdmin);
        globals.setValidInstanceOf("CONTROLLER_ORACLE",    priceOracleProxy,    true);
        globals.setValidInstanceOf("COMPOSITE_POOL_ASSET", compositeTokenProxy, true);
        globals.setValidInstanceOf("SYRUP_BTC_ROUTER",     bitcoinRouterProxy,  true);
        globals.setValidInstanceOf("BITCOIN_STRATEGY",     bitcoinStrategy1,    true);
        globals.setValidInstanceOf("BITCOIN_STRATEGY",     bitcoinStrategy2,    true);
        globals.setValidInstanceOf("BITCOIN_STRATEGY",     bitcoinStrategy3,    true);
        vm.stopPrank();

        // Step 7: Deploy AssetController

        assetControllerImplementation = deployFromFile("Contracts@25", "AssetController");
        assetControllerInitializer    = deployFromFile("Contracts@25", "AssetControllerInitializer");
        assetControllerProxy          = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                assetControllerImplementation,
                assetControllerInitializer,
                abi.encodeWithSignature(
                    "initialize(address,address)",
                    priceOracleProxy,
                    bitcoinRouterProxy
                )
            )
        );

        // Step 8: Whitelist asset controller on globals

        vm.prank(operationalAdmin);
        globals.setValidInstanceOf("ASSET_CONTROLLER", assetControllerProxy, true);

        // Step 9: Allow composite token to be held by pool, asset controller, bitcoin router and bitcoin strategy

        address[] memory addresses = new address[](6);
        bool[]    memory allowed   = new bool[](6);

        addresses[0] = address(pool);
        addresses[1] = assetControllerProxy;
        addresses[2] = bitcoinRouterProxy;
        addresses[3] = bitcoinStrategy1;
        addresses[4] = bitcoinStrategy2;
        addresses[5] = bitcoinStrategy3;

        allowed[0] = true;
        allowed[1] = true;
        allowed[2] = true;
        allowed[3] = true;
        allowed[4] = true;
        allowed[5] = true;

        vm.prank(governor);
        ICompositeToken(compositeTokenProxy).allowAddresses(addresses, allowed);

        // Step 10: Allow deposit asset to be wrapped, unwrapped, deployed and reconciled

        addresses = new address[](1);
        allowed   = new bool[](1);

        addresses[0] = address(depositAsset);
        allowed[0]   = true;

        vm.prank(governor);
        IAssetController(assetControllerProxy).setAssets(addresses, allowed, allowed, allowed, allowed);

        // Step 11: Whitelist bitcoin strategy on asset controller

        addresses = new address[](3);
        allowed   = new bool[](3);

        addresses[0] = bitcoinStrategy1;
        addresses[1] = bitcoinStrategy2;
        addresses[2] = bitcoinStrategy3;
        allowed[0]   = true;
        allowed[1]   = true;
        allowed[2]   = true;

        vm.prank(operationalAdmin);
        IAssetController(assetControllerProxy).setStrategies(addresses, allowed);

        // Step 12: Set asset controller on composite token, bitcoin router and bitcoin strategy

        addresses = new address[](1);
        allowed   = new bool[](1);

        addresses[0] = assetControllerProxy;
        allowed[0]   = true;

        vm.prank(governor);
        ICompositeToken(compositeTokenProxy).setAssetControllers(addresses, allowed);

        vm.startPrank(operationalAdmin);
        ISyrupBitcoinRouter(bitcoinRouterProxy).setAssetController(address(depositAsset), assetControllerProxy);
        IBitcoinStrategy(bitcoinStrategy1).setAssetController(address(depositAsset), assetControllerProxy);
        IBitcoinStrategy(bitcoinStrategy2).setAssetController(address(depositAsset), assetControllerProxy);
        IBitcoinStrategy(bitcoinStrategy3).setAssetController(address(depositAsset), assetControllerProxy);

        // Step 13: Allow strategy manager to deploy, schedule and reconcile all strategies

        addresses[0] = strategyManager;
        allowed[0]   = true;

        IBitcoinStrategy(bitcoinStrategy1).setPermissions(addresses, allowed, allowed, allowed);
        IBitcoinStrategy(bitcoinStrategy2).setPermissions(addresses, allowed, allowed, allowed);
        IBitcoinStrategy(bitcoinStrategy3).setPermissions(addresses, allowed, allowed, allowed);

        vm.stopPrank();

        bytes32[] memory functionIdsToSet = new bytes32[](11);
        uint256[] memory bitmaps          = new uint256[](11);

        uint256 bitmap = 2 ** 5;

        functionIdsToSet[0]  = "P:deposit";
        functionIdsToSet[1]  = "P:depositWithPermit";
        functionIdsToSet[2]  = "P:mint";
        functionIdsToSet[3]  = "P:mintWithPermit";
        functionIdsToSet[4]  = "P:redeem";
        functionIdsToSet[5]  = "P:withdraw";
        functionIdsToSet[6]  = "P:transfer";
        functionIdsToSet[7]  = "P:transferFrom";
        functionIdsToSet[8]  = "P:removeShares";
        functionIdsToSet[9]  = "P:requestRedeem";
        functionIdsToSet[10] = "P:requestWithdraw";

        bitmaps[0]  = bitmap;
        bitmaps[1]  = bitmap;
        bitmaps[2]  = bitmap;
        bitmaps[3]  = bitmap;
        bitmaps[4]  = bitmap;
        bitmaps[5]  = bitmap;
        bitmaps[6]  = 0;
        bitmaps[7]  = 0;
        bitmaps[8]  = bitmap;
        bitmaps[9]  = bitmap + 1;  // TODO: Decide how to handle this in production 
        bitmaps[10] = bitmap;

        // Step 14: Set pool permission level to be function level, set bitmaps, set lender bitmaps and set manual withdrawal for the router

        vm.startPrank(operationalAdmin);
        poolPermissionManager.setPoolPermissionLevel(address(poolManager), 1);
        poolPermissionManager.setPoolBitmaps(address(poolManager), functionIdsToSet, bitmaps);

        addresses = new address[](1);
        bitmaps   = new uint256[](1);

        addresses[0] = bitcoinRouterProxy;
        bitmaps[0]   = bitmap;

        poolPermissionManager.setLenderBitmaps(addresses, bitmaps);

        address withdrawalManager = IPoolManager(poolManager).withdrawalManager();
        IWithdrawalManager(withdrawalManager).setManualWithdrawal(bitcoinRouterProxy, true);

        vm.stopPrank();
    }

    function test_setUp() external view {
        address pool              = poolManager.pool();
        address withdrawalManager = poolManager.withdrawalManager();

        assertEq(IPool(pool).totalSupply(),    0);
        assertEq(IPool(pool).totalAssets(),    0);
        assertEq(IPool(pool).BOOTSTRAP_MINT(), 0);
        assertEq(IPool(pool).asset(),          compositeTokenProxy);
        assertEq(IPool(pool).name(),           "Syrup Bitcoin");
        assertEq(IPool(pool).symbol(),         "syrupBTC");
        assertEq(IPool(pool).manager(),        address(poolManager));

        assertEq(poolManager.hasSufficientCover(),        true);
        assertEq(poolManager.configured(),                true);
        assertEq(poolManager.totalAssets(),               0);
        assertEq(poolManager.unrealizedLosses(),          0);
        assertEq(poolManager.strategyListLength(),        3);
        assertEq(poolManager.liquidityCap(),              liquidityCap);
        assertEq(poolManager.delegateManagementFeeRate(), delegateManagementFeeRate);
        assertEq(poolManager.governor(),                  governor);
        assertEq(poolManager.poolDelegate(),              poolDelegate);
        assertEq(poolManager.factory(),                   poolManagerFactory);
        assertEq(poolManager.implementation(),            poolManagerImplementation);
        assertEq(poolManager.pendingPoolDelegate(),       address(0));
        assertEq(poolManager.globals(),                   address(globals));
        assertEq(poolManager.poolPermissionManager(),     address(poolPermissionManager));

        assertEq(poolManager.strategyList(0), bitcoinStrategy1);
        assertEq(poolManager.strategyList(1), bitcoinStrategy2);
        assertEq(poolManager.strategyList(2), bitcoinStrategy3);

        assertNotEq(poolManager.strategyList(0),     address(0));
        assertNotEq(poolManager.strategyList(1),     address(0));
        assertNotEq(poolManager.strategyList(2),     address(0));
        assertNotEq(poolManager.withdrawalManager(), address(0));

        assertEq(IWithdrawalManager(withdrawalManager).totalShares(),                          0);
        assertEq(IWithdrawalManager(withdrawalManager).pool(),                                 pool);
        assertEq(IWithdrawalManager(withdrawalManager).governor(),                             governor);
        assertEq(IWithdrawalManager(withdrawalManager).poolDelegate(),                         poolDelegate);
        assertEq(IWithdrawalManager(withdrawalManager).factory(),                              queueWMFactory);
        assertEq(IWithdrawalManager(withdrawalManager).asset(),                                compositeTokenProxy);
        assertEq(IWithdrawalManager(withdrawalManager).implementation(),                       queueWMImplementation);
        assertEq(IWithdrawalManager(withdrawalManager).globals(),                              address(globals));
        assertEq(IWithdrawalManager(withdrawalManager).poolManager(),                          address(poolManager));
        assertEq(IWithdrawalManager(withdrawalManager).isManualWithdrawal(bitcoinRouterProxy), true);

        assertEq(IBitcoinStrategy(bitcoinStrategy1).realizedFees(),          0);
        assertEq(IBitcoinStrategy(bitcoinStrategy1).outstandingAssets(),     0);
        assertEq(IBitcoinStrategy(bitcoinStrategy1).feeRate(),               0);
        assertEq(IBitcoinStrategy(bitcoinStrategy1).impairedAssets(),        0);
        assertEq(IBitcoinStrategy(bitcoinStrategy1).accruedYield(),          0);
        assertEq(IBitcoinStrategy(bitcoinStrategy1).assetsUnderManagement(), 0);
        assertEq(IBitcoinStrategy(bitcoinStrategy1).unrealizedLosses(),      0);
        assertEq(IBitcoinStrategy(bitcoinStrategy1).yieldRate(),             0);
        assertEq(IBitcoinStrategy(bitcoinStrategy1).accruedFees(),           0);
        assertEq(IBitcoinStrategy(bitcoinStrategy1).locked(),                1);
        assertEq(IBitcoinStrategy(bitcoinStrategy1).pool(),                  pool);
        assertEq(IBitcoinStrategy(bitcoinStrategy1).factory(),               bitcoinStrategyFactory);
        assertEq(IBitcoinStrategy(bitcoinStrategy1).implementation(),        bitcoinStrategyImplementation);
        assertEq(IBitcoinStrategy(bitcoinStrategy1).poolAsset(),             compositeTokenProxy);
        assertEq(IBitcoinStrategy(bitcoinStrategy1).poolManager(),           address(poolManager));

        assertEq(IBitcoinStrategy(bitcoinStrategy2).realizedFees(),          0);
        assertEq(IBitcoinStrategy(bitcoinStrategy2).outstandingAssets(),     0);
        assertEq(IBitcoinStrategy(bitcoinStrategy2).feeRate(),               0);
        assertEq(IBitcoinStrategy(bitcoinStrategy2).impairedAssets(),        0);
        assertEq(IBitcoinStrategy(bitcoinStrategy2).accruedYield(),          0);
        assertEq(IBitcoinStrategy(bitcoinStrategy2).assetsUnderManagement(), 0);
        assertEq(IBitcoinStrategy(bitcoinStrategy2).unrealizedLosses(),      0);
        assertEq(IBitcoinStrategy(bitcoinStrategy2).yieldRate(),             0);
        assertEq(IBitcoinStrategy(bitcoinStrategy2).accruedFees(),           0);
        assertEq(IBitcoinStrategy(bitcoinStrategy2).locked(),                1);
        assertEq(IBitcoinStrategy(bitcoinStrategy2).pool(),                  pool);
        assertEq(IBitcoinStrategy(bitcoinStrategy2).factory(),               bitcoinStrategyFactory);
        assertEq(IBitcoinStrategy(bitcoinStrategy2).implementation(),        bitcoinStrategyImplementation);
        assertEq(IBitcoinStrategy(bitcoinStrategy2).poolAsset(),             compositeTokenProxy);
        assertEq(IBitcoinStrategy(bitcoinStrategy2).poolManager(),           address(poolManager));

        assertEq(IBitcoinStrategy(bitcoinStrategy3).realizedFees(),          0);
        assertEq(IBitcoinStrategy(bitcoinStrategy3).outstandingAssets(),     0);
        assertEq(IBitcoinStrategy(bitcoinStrategy3).feeRate(),               0);
        assertEq(IBitcoinStrategy(bitcoinStrategy3).impairedAssets(),        0);
        assertEq(IBitcoinStrategy(bitcoinStrategy3).accruedYield(),          0);
        assertEq(IBitcoinStrategy(bitcoinStrategy3).assetsUnderManagement(), 0);
        assertEq(IBitcoinStrategy(bitcoinStrategy3).unrealizedLosses(),      0);
        assertEq(IBitcoinStrategy(bitcoinStrategy3).yieldRate(),             0);
        assertEq(IBitcoinStrategy(bitcoinStrategy3).accruedFees(),           0);
        assertEq(IBitcoinStrategy(bitcoinStrategy3).locked(),                1);
        assertEq(IBitcoinStrategy(bitcoinStrategy3).pool(),                  pool);
        assertEq(IBitcoinStrategy(bitcoinStrategy3).poolAsset(),             compositeTokenProxy);
        assertEq(IBitcoinStrategy(bitcoinStrategy3).factory(),               bitcoinStrategyFactory);
        assertEq(IBitcoinStrategy(bitcoinStrategy3).poolManager(),           address(poolManager));
        assertEq(IBitcoinStrategy(bitcoinStrategy3).implementation(),        bitcoinStrategyImplementation);

        (
            bool canDeploy,
            bool canReconcile,
            bool canSchedule
        ) = IBitcoinStrategy(bitcoinStrategy1).permissions(strategyManager);

        assertEq(canDeploy,    true);
        assertEq(canReconcile, true);
        assertEq(canSchedule,  true);

        (
            canDeploy,
            canReconcile,
            canSchedule
        ) = IBitcoinStrategy(bitcoinStrategy2).permissions(strategyManager);

        assertEq(canDeploy,    true);
        assertEq(canReconcile, true);
        assertEq(canSchedule,  true);

        (
            canDeploy,
            canReconcile,
            canSchedule
        ) = IBitcoinStrategy(bitcoinStrategy3).permissions(strategyManager);

        assertEq(canDeploy,    true);
        assertEq(canReconcile, true);
        assertEq(canSchedule,  true);

        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).locked(),                               1);
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).mintFee(address(depositAsset)),         0);
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).redemptionFee(address(depositAsset)),   0);
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).globals(),                              address(globals));
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).implementation(),                       bitcoinRouterImplementation);
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).poolManager(),                          address(poolManager));
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).pool(),                                 poolManager.pool());
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).assetController(address(depositAsset)), assetControllerProxy);

        assertEq(IAssetControllerOracle(priceOracleProxy).globals(),        address(globals));
        assertEq(IAssetControllerOracle(priceOracleProxy).implementation(), priceOracleImplementation);

        assertEq(IAssetController(assetControllerProxy).locked(),                             1);
        assertEq(IAssetController(assetControllerProxy).poolAssets(address(depositAsset)),    0);
        assertEq(IAssetController(assetControllerProxy).depositAssets(address(depositAsset)), 0);
        assertEq(IAssetController(assetControllerProxy).globals(),                            address(globals));
        assertEq(IAssetController(assetControllerProxy).implementation(),                     assetControllerImplementation);
        assertEq(IAssetController(assetControllerProxy).oracle(),                             priceOracleProxy);
        assertEq(IAssetController(assetControllerProxy).router(),                             bitcoinRouterProxy);
        assertEq(IAssetController(assetControllerProxy).poolAsset(),                          compositeTokenProxy);

        assertEq(IAssetController(assetControllerProxy).previewDeploy(address(depositAsset),    1e8), 1e8);
        assertEq(IAssetController(assetControllerProxy).previewReconcile(address(depositAsset), 1e8), 1e8);

        assertEq(IERC20(compositeTokenProxy).name(),        "Synthetic Bitcoin");
        assertEq(IERC20(compositeTokenProxy).symbol(),      "synthBTC");
        assertEq(IERC20(compositeTokenProxy).decimals(),    8);
        assertEq(IERC20(compositeTokenProxy).totalSupply(), 0);

        assertEq(IERC20(compositeTokenProxy).allowance(bitcoinRouterProxy, pool),                 type(uint256).max);
        assertEq(IERC20(compositeTokenProxy).allowance(bitcoinRouterProxy, assetControllerProxy), type(uint256).max);
        assertEq(IERC20(compositeTokenProxy).allowance(bitcoinStrategy1,   assetControllerProxy), type(uint256).max);
        assertEq(IERC20(compositeTokenProxy).allowance(bitcoinStrategy2,   assetControllerProxy), type(uint256).max);
        assertEq(IERC20(compositeTokenProxy).allowance(bitcoinStrategy3,   assetControllerProxy), type(uint256).max);

        assertEq(IERC20(depositAsset).allowance(bitcoinRouterProxy, assetControllerProxy), type(uint256).max);
        assertEq(IERC20(depositAsset).allowance(bitcoinStrategy1,   assetControllerProxy), type(uint256).max);
        assertEq(IERC20(depositAsset).allowance(bitcoinStrategy2,   assetControllerProxy), type(uint256).max);
        assertEq(IERC20(depositAsset).allowance(bitcoinStrategy3,   assetControllerProxy), type(uint256).max);

        assertEq(ICompositeToken(compositeTokenProxy).allAllowed(),                           false);
        assertEq(ICompositeToken(compositeTokenProxy).allowedAddresses(address(pool)),        true);
        assertEq(ICompositeToken(compositeTokenProxy).allowedAddresses(assetControllerProxy), true);
        assertEq(ICompositeToken(compositeTokenProxy).allowedAddresses(bitcoinRouterProxy),   true);
        assertEq(ICompositeToken(compositeTokenProxy).allowedAddresses(bitcoinStrategy1),     true);
        assertEq(ICompositeToken(compositeTokenProxy).allowedAddresses(bitcoinStrategy2),     true);
        assertEq(ICompositeToken(compositeTokenProxy).allowedAddresses(bitcoinStrategy3),     true);
        assertEq(ICompositeToken(compositeTokenProxy).controllers(assetControllerProxy),      true);

        assertEq(IAssetController(assetControllerProxy).canWrap(address(depositAsset)),      true);
        assertEq(IAssetController(assetControllerProxy).canUnwrap(address(depositAsset)),    true);
        assertEq(IAssetController(assetControllerProxy).canDeploy(address(depositAsset)),    true);
        assertEq(IAssetController(assetControllerProxy).canReconcile(address(depositAsset)), true);
        assertEq(IAssetController(assetControllerProxy).isStrategy(bitcoinStrategy1),        true);
        assertEq(IAssetController(assetControllerProxy).isStrategy(bitcoinStrategy2),        true);
        assertEq(IAssetController(assetControllerProxy).isStrategy(bitcoinStrategy3),        true);

        uint256 bitmap = 2 ** 5;

        assertEq(poolPermissionManager.lenderAllowlist(bitcoinRouterProxy, strategyManager), false);
        assertEq(poolPermissionManager.lenderBitmaps(bitcoinRouterProxy), bitmap);
        assertEq(poolPermissionManager.permissionLevels(address(poolManager)), 1);

        assertEq(poolPermissionManager.poolBitmaps(address(poolManager), "P:transfer"),          0);
        assertEq(poolPermissionManager.poolBitmaps(address(poolManager), "P:transferFrom"),      0);
        assertEq(poolPermissionManager.poolBitmaps(address(poolManager), "P:deposit"),           bitmap);
        assertEq(poolPermissionManager.poolBitmaps(address(poolManager), "P:depositWithPermit"), bitmap);
        assertEq(poolPermissionManager.poolBitmaps(address(poolManager), "P:mint"),              bitmap);
        assertEq(poolPermissionManager.poolBitmaps(address(poolManager), "P:mintWithPermit"),    bitmap);
        assertEq(poolPermissionManager.poolBitmaps(address(poolManager), "P:redeem"),            bitmap);
        assertEq(poolPermissionManager.poolBitmaps(address(poolManager), "P:withdraw"),          bitmap);
        assertEq(poolPermissionManager.poolBitmaps(address(poolManager), "P:removeShares"),      bitmap);
        assertEq(poolPermissionManager.poolBitmaps(address(poolManager), "P:requestRedeem"),     bitmap + 1);
        assertEq(poolPermissionManager.poolBitmaps(address(poolManager), "P:requestWithdraw"),   bitmap);

        assertEq(globals.isInstanceOf("BITCOIN_STRATEGY",     bitcoinStrategy1),      true);
        assertEq(globals.isInstanceOf("BITCOIN_STRATEGY",     bitcoinStrategy2),      true);
        assertEq(globals.isInstanceOf("CONTROLLER_ORACLE",    priceOracleProxy),      true);
        assertEq(globals.isInstanceOf("SYRUP_BTC_ROUTER",     bitcoinRouterProxy),    true);
        assertEq(globals.isInstanceOf("COMPOSITE_POOL_ASSET", compositeTokenProxy),   true);
        assertEq(globals.isInstanceOf("ASSET_CONTROLLER",     assetControllerProxy),  true);
        assertEq(globals.isInstanceOf("SYRUP_BTC_REDEEMER",   bitcoinRouterRedeemer), true);
    }

}
