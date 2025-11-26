// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAssetController,
    IAssetControllerOracle,
    IBitcoinStrategy,
    ICompositeToken,
    IERC20,
    IGlobals,
    IMapleProxyFactory,
    IPool,
    IPoolManager,
    IPoolPermissionManager,
    ISyrupBitcoinRouter,
    IWithdrawalManagerQueue as IWithdrawalManager,
    Permit
} from "../../../contracts/interfaces/Interfaces.sol";

import { SyrupBTCProtocolUpgradeBase } from "./SyrupBTCProtocolUpgradeBase.t.sol";

contract SyrupBTCFullDeploymentTests is SyrupBTCProtocolUpgradeBase {

    function testFork_syrupBTCFullDeployment() public view {
        assertEq(block.timestamp, startingTime + 6 days);

        address pool              = IPoolManager(syrupBitcoinPoolManager).pool();
        address withdrawalManager = IPoolManager(syrupBitcoinPoolManager).withdrawalManager();

        assertEq(IMapleProxyFactory(withdrawalManagerQueueFactory).defaultVersion(),          200);
        assertEq(IMapleProxyFactory(withdrawalManagerQueueFactory).migratorForPath(100, 200), mapleWithdrawalManagerV200Migrator);

        assertEq(IPool(pool).totalSupply(),    0);
        assertEq(IPool(pool).totalAssets(),    0);
        assertEq(IPool(pool).BOOTSTRAP_MINT(), 0);
        assertEq(IPool(pool).asset(),          compositeTokenProxy);
        assertEq(IPool(pool).name(),           "Syrup Bitcoin");
        assertEq(IPool(pool).symbol(),         "syrupBTC");
        assertEq(IPool(pool).manager(),        syrupBitcoinPoolManager);

        assertEq(IPoolManager(syrupBitcoinPoolManager).hasSufficientCover(),        true);
        assertEq(IPoolManager(syrupBitcoinPoolManager).configured(),                true);
        assertEq(IPoolManager(syrupBitcoinPoolManager).totalAssets(),               0);
        assertEq(IPoolManager(syrupBitcoinPoolManager).unrealizedLosses(),          0);
        assertEq(IPoolManager(syrupBitcoinPoolManager).strategyListLength(),        3);
        assertEq(IPoolManager(syrupBitcoinPoolManager).pendingPoolDelegate(),       address(0));
        assertEq(IPoolManager(syrupBitcoinPoolManager).globals(),                   globals);
        assertEq(IPoolManager(syrupBitcoinPoolManager).governor(),                  timelock);
        assertEq(IPoolManager(syrupBitcoinPoolManager).liquidityCap(),              liquidityCap);
        assertEq(IPoolManager(syrupBitcoinPoolManager).poolDelegate(),              syrupBitcoinPoolDelegate);
        assertEq(IPoolManager(syrupBitcoinPoolManager).factory(),                   poolManagerFactory);
        assertEq(IPoolManager(syrupBitcoinPoolManager).poolPermissionManager(),     poolPermissionManager);
        assertEq(IPoolManager(syrupBitcoinPoolManager).delegateManagementFeeRate(), delegateManagementFeeRate);
        assertEq(IPoolManager(syrupBitcoinPoolManager).implementation(),            PoolManagerV400Implementation);

        assertEq(IPoolManager(syrupBitcoinPoolManager).strategyList(0), bitcoinStrategy1);
        assertEq(IPoolManager(syrupBitcoinPoolManager).strategyList(1), bitcoinStrategy2);
        assertEq(IPoolManager(syrupBitcoinPoolManager).strategyList(2), bitcoinStrategy3);

        assertNotEq(IPoolManager(syrupBitcoinPoolManager).strategyList(0),     address(0));
        assertNotEq(IPoolManager(syrupBitcoinPoolManager).strategyList(1),     address(0));
        assertNotEq(IPoolManager(syrupBitcoinPoolManager).strategyList(2),     address(0));
        assertNotEq(IPoolManager(syrupBitcoinPoolManager).withdrawalManager(), address(0));
        assertNotEq(IPoolManager(syrupBitcoinPoolManager).poolDelegateCover(), address(0));

        assertEq(IWithdrawalManager(withdrawalManager).totalShares(),                          0);
        assertEq(IWithdrawalManager(withdrawalManager).pool(),                                 pool);
        assertEq(IWithdrawalManager(withdrawalManager).globals(),                              globals);
        assertEq(IWithdrawalManager(withdrawalManager).governor(),                             timelock);
        assertEq(IWithdrawalManager(withdrawalManager).poolDelegate(),                         syrupBitcoinPoolDelegate);
        assertEq(IWithdrawalManager(withdrawalManager).asset(),                                compositeTokenProxy);
        assertEq(IWithdrawalManager(withdrawalManager).poolManager(),                          syrupBitcoinPoolManager);
        assertEq(IWithdrawalManager(withdrawalManager).factory(),                              withdrawalManagerQueueFactory);
        assertEq(IWithdrawalManager(withdrawalManager).implementation(),                       mapleWithdrawalManagerV200Implementation);
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
        assertEq(IBitcoinStrategy(bitcoinStrategy1).poolAsset(),             compositeTokenProxy);
        assertEq(IBitcoinStrategy(bitcoinStrategy1).factory(),               bitcoinStrategyFactory);
        assertEq(IBitcoinStrategy(bitcoinStrategy1).poolManager(),           syrupBitcoinPoolManager);
        assertEq(IBitcoinStrategy(bitcoinStrategy1).implementation(),        bitcoinStrategyV100Implementation);

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
        assertEq(IBitcoinStrategy(bitcoinStrategy2).poolAsset(),             compositeTokenProxy);
        assertEq(IBitcoinStrategy(bitcoinStrategy2).factory(),               bitcoinStrategyFactory);
        assertEq(IBitcoinStrategy(bitcoinStrategy2).poolManager(),           syrupBitcoinPoolManager);
        assertEq(IBitcoinStrategy(bitcoinStrategy2).implementation(),        bitcoinStrategyV100Implementation);

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
        assertEq(IBitcoinStrategy(bitcoinStrategy3).poolManager(),           syrupBitcoinPoolManager);
        assertEq(IBitcoinStrategy(bitcoinStrategy3).implementation(),        bitcoinStrategyV100Implementation);

        (
            bool canDeploy,
            bool canReconcile,
            bool canSchedule
        ) = IBitcoinStrategy(bitcoinStrategy1).permissions(bitcoinStrategy1Manager);

        assertEq(canDeploy,    true);
        assertEq(canReconcile, true);
        assertEq(canSchedule,  true);

        (
            canDeploy,
            canReconcile,
            canSchedule
        ) = IBitcoinStrategy(bitcoinStrategy2).permissions(bitcoinStrategy2Manager);

        assertEq(canDeploy,    true);
        assertEq(canReconcile, true);
        assertEq(canSchedule,  true);

        (
            canDeploy,
            canReconcile,
            canSchedule
        ) = IBitcoinStrategy(bitcoinStrategy3).permissions(bitcoinStrategy3Manager);

        assertEq(canDeploy,    true);
        assertEq(canReconcile, true);
        assertEq(canSchedule,  true);

        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).locked(),              1);
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).mintFee(wbtc),         0);
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).redemptionFee(wbtc),   0);
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).globals(),             globals);
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).pool(),                syrupBitcoinPool);
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).assetController(wbtc), assetControllerProxy);
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).poolManager(),         syrupBitcoinPoolManager);
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).implementation(),      bitcoinRouterV100Implementation);

        assertEq(IAssetControllerOracle(assetPriceOracleProxy).globals(),        globals);
        assertEq(IAssetControllerOracle(assetPriceOracleProxy).implementation(), assetPriceOracleV100Implementation);

        assertEq(IAssetController(assetControllerProxy).locked(),            1);
        assertEq(IAssetController(assetControllerProxy).poolAssets(wbtc),    0);
        assertEq(IAssetController(assetControllerProxy).depositAssets(wbtc), 0);
        assertEq(IAssetController(assetControllerProxy).globals(),           globals);
        assertEq(IAssetController(assetControllerProxy).oracle(),            assetPriceOracleProxy);
        assertEq(IAssetController(assetControllerProxy).router(),            bitcoinRouterProxy);
        assertEq(IAssetController(assetControllerProxy).poolAsset(),         compositeTokenProxy);
        assertEq(IAssetController(assetControllerProxy).implementation(),    assetControllerV100Implementation);

        assertEq(IAssetController(assetControllerProxy).previewDeploy(wbtc,    1e8), 1e8);
        assertEq(IAssetController(assetControllerProxy).previewReconcile(wbtc, 1e8), 1e8);

        assertEq(IERC20(compositeTokenProxy).name(),        "Synthetic Bitcoin");
        assertEq(IERC20(compositeTokenProxy).symbol(),      "synthBTC");
        assertEq(IERC20(compositeTokenProxy).decimals(),    8);
        assertEq(IERC20(compositeTokenProxy).totalSupply(), 0);

        assertEq(IERC20(compositeTokenProxy).allowance(bitcoinRouterProxy, syrupBitcoinPool),     type(uint256).max);
        assertEq(IERC20(compositeTokenProxy).allowance(bitcoinRouterProxy, assetControllerProxy), type(uint256).max);
        assertEq(IERC20(compositeTokenProxy).allowance(bitcoinStrategy1,   assetControllerProxy), type(uint256).max);
        assertEq(IERC20(compositeTokenProxy).allowance(bitcoinStrategy2,   assetControllerProxy), type(uint256).max);

        assertEq(IERC20(wbtc).allowance(bitcoinRouterProxy, assetControllerProxy), type(uint256).max);
        assertEq(IERC20(wbtc).allowance(bitcoinStrategy1,   assetControllerProxy), type(uint256).max);
        assertEq(IERC20(wbtc).allowance(bitcoinStrategy2,   assetControllerProxy), type(uint256).max);

        assertEq(ICompositeToken(compositeTokenProxy).allAllowed(),                           false);
        assertEq(ICompositeToken(compositeTokenProxy).allowedAddresses(syrupBitcoinPool),     true);
        assertEq(ICompositeToken(compositeTokenProxy).allowedAddresses(assetControllerProxy), true);
        assertEq(ICompositeToken(compositeTokenProxy).allowedAddresses(bitcoinRouterProxy),   true);
        assertEq(ICompositeToken(compositeTokenProxy).allowedAddresses(bitcoinStrategy1),     true);
        assertEq(ICompositeToken(compositeTokenProxy).allowedAddresses(bitcoinStrategy2),     true);
        assertEq(ICompositeToken(compositeTokenProxy).allowedAddresses(bitcoinStrategy3),     true);
        assertEq(ICompositeToken(compositeTokenProxy).controllers(assetControllerProxy),      true);

        assertEq(IAssetController(assetControllerProxy).canWrap(wbtc),                true);
        assertEq(IAssetController(assetControllerProxy).canUnwrap(wbtc),              true);
        assertEq(IAssetController(assetControllerProxy).canDeploy(wbtc),              true);
        assertEq(IAssetController(assetControllerProxy).canReconcile(wbtc),           true);
        assertEq(IAssetController(assetControllerProxy).isStrategy(bitcoinStrategy1), true);
        assertEq(IAssetController(assetControllerProxy).isStrategy(bitcoinStrategy2), true);
        assertEq(IAssetController(assetControllerProxy).isStrategy(bitcoinStrategy3), true);

        assertEq(IPoolPermissionManager(poolPermissionManager).permissionLevels(syrupBitcoinPoolManager), 1);

        uint256 bitmap        = 2 ** 5;
        uint256 requestBitmap = 2 ** 6;

        assertEq(IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:transfer"),          0);
        assertEq(IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:transferFrom"),      0);
        assertEq(IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:deposit"),           bitmap);
        assertEq(IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:depositWithPermit"), bitmap);
        assertEq(IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:mint"),              bitmap);
        assertEq(IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:mintWithPermit"),    bitmap);
        assertEq(IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:redeem"),            bitmap);
        assertEq(IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:withdraw"),          bitmap);
        assertEq(IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:removeShares"),      bitmap);
        assertEq(IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:requestRedeem"),     requestBitmap);
        assertEq(IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:requestWithdraw"),   bitmap);

        assertEq(IPoolPermissionManager(poolPermissionManager).lenderBitmaps(bitcoinRouterProxy), bitmap);

        assertEq(IGlobals(globals).isInstanceOf("BITCOIN_STRATEGY",     bitcoinStrategy1),      true);
        assertEq(IGlobals(globals).isInstanceOf("BITCOIN_STRATEGY",     bitcoinStrategy2),      true);
        assertEq(IGlobals(globals).isInstanceOf("SYRUP_BTC_ROUTER",     bitcoinRouterProxy),    true);
        assertEq(IGlobals(globals).isInstanceOf("COMPOSITE_POOL_ASSET", compositeTokenProxy),   true);
        assertEq(IGlobals(globals).isInstanceOf("ASSET_CONTROLLER",     assetControllerProxy),  true);
        assertEq(IGlobals(globals).isInstanceOf("CONTROLLER_ORACLE",    assetPriceOracleProxy), true);
    }

    function testFork_syrupBTCFullDeployment_requestRedeem_revert() public {
        address pool          = IPoolManager(syrupBitcoinPoolManager).pool();
        address user          = makeAddr("user");
        uint256 depositAmount = 1e8;
        uint256 requestAmount = 1e6;
        bytes32 metadata      = "Some random metadata";

        vm.prank(operationalAdmin);
        IGlobals(globals).activatePoolManager(syrupBitcoinPoolManager);

        deal(wbtc, user, depositAmount);

        vm.startPrank(user);

        IERC20(wbtc).approve(address(bitcoinRouterProxy), depositAmount);
        ISyrupBitcoinRouter(bitcoinRouterProxy).deposit(address(wbtc), depositAmount, metadata, Permit(false, 0, 0, 0, 0));

        IPool(pool).approve(address(bitcoinRouterProxy), requestAmount);

        vm.expectRevert("PM:CC:NOT_ALLOWED");
        ISyrupBitcoinRouter(bitcoinRouterProxy).requestRedeem(address(wbtc), requestAmount, metadata, Permit(false, 0, 0, 0, 0));

        vm.stopPrank();
    }

    function testFork_syrupBTCFullDeployment_deposit_success() public {
        address pool          = IPoolManager(syrupBitcoinPoolManager).pool();
        address user          = makeAddr("user");
        uint256 depositAmount = 1e8;
        bytes32 metadata      = "Some random metadata";

        vm.prank(operationalAdmin);
        IGlobals(globals).activatePoolManager(syrupBitcoinPoolManager);

        assertEq(IPool(pool).totalSupply(), 0);
        assertEq(IPool(pool).totalAssets(), 0);

        deal(wbtc, user, depositAmount);

        vm.startPrank(user);

        IERC20(wbtc).approve(address(bitcoinRouterProxy), depositAmount);
        ISyrupBitcoinRouter(bitcoinRouterProxy).deposit(address(wbtc), depositAmount, metadata, Permit(false, 0, 0, 0, 0));

        vm.stopPrank();

        assertEq(IPool(pool).totalSupply(),   depositAmount);
        assertEq(IPool(pool).totalAssets(),   depositAmount);
        assertEq(IPool(pool).balanceOf(user), depositAmount);
    }

    function testFork_syrupBTCFullDeployment_fullRedeemProcess_success() public {
        address pool              = IPoolManager(syrupBitcoinPoolManager).pool();
        address withdrawalManager = IPoolManager(syrupBitcoinPoolManager).withdrawalManager();
        address user              = makeAddr("user");
        uint256 depositAmount     = 1e8;
        uint256 requestAmount     = 1e6;
        bytes32 metadata          = "Some random metadata";

        /**********************************************************************************************************************************/
        /*** Step 1: Activate the pool manager                                                                                          ***/
        /**********************************************************************************************************************************/

        vm.startPrank(operationalAdmin);
        IGlobals(globals).activatePoolManager(syrupBitcoinPoolManager);
        IGlobals(globals).setValidInstanceOf("SYRUP_BTC_REDEEMER", bitcoinRouterRedeemer, true);
        vm.stopPrank();

        /**********************************************************************************************************************************/
        /*** Step 2: Allow requestRedeem for the router                                                                                 ***/
        /**********************************************************************************************************************************/

        uint256 bitmap = 2 ** 5;

        bytes32[] memory functionIdsToSet = new bytes32[](1);
        uint256[] memory bitmaps          = new uint256[](1);

        functionIdsToSet[0] = "P:requestRedeem";
        bitmaps[0]          = bitmap;

        vm.prank(operationalAdmin);
        IPoolPermissionManager(poolPermissionManager).setPoolBitmaps(syrupBitcoinPoolManager, functionIdsToSet, bitmaps);

        /**********************************************************************************************************************************/
        /*** Step 3: Deposit the assets                                                                                                 ***/
        /**********************************************************************************************************************************/

        deal(wbtc, user, depositAmount);

        vm.startPrank(user);
        IERC20(wbtc).approve(address(bitcoinRouterProxy), depositAmount);
        ISyrupBitcoinRouter(bitcoinRouterProxy).deposit(address(wbtc), depositAmount, metadata, Permit(false, 0, 0, 0, 0));
        vm.stopPrank();

        /**********************************************************************************************************************************/
        /*** Step 4: Request redeem the assets                                                                                         ***/
        /**********************************************************************************************************************************/

        vm.startPrank(user);
        IPool(pool).approve(address(bitcoinRouterProxy), requestAmount);
        ISyrupBitcoinRouter(bitcoinRouterProxy).requestRedeem(address(wbtc), requestAmount, metadata, Permit(false, 0, 0, 0, 0));
        vm.stopPrank();

        /**********************************************************************************************************************************/
        /*** Step 5: Process the redeem requests                                                                                        ***/
        /**********************************************************************************************************************************/

        uint256[] memory requestIds = new uint256[](1);
        requestIds[0]               = 1;

        vm.prank(syrupBitcoinPoolDelegate);
        IWithdrawalManager(withdrawalManager).processRedemptions(requestAmount);

        vm.prank(bitcoinRouterRedeemer);
        ISyrupBitcoinRouter(bitcoinRouterProxy).processRedemptions(requestIds);

        /**********************************************************************************************************************************/
        /*** Step 6: Assert the results                                                                                                 ***/
        /**********************************************************************************************************************************/

        assertEq(IPool(pool).balanceOf(address(withdrawalManager)), 0);
        assertEq(IPool(pool).balanceOf(user),                       depositAmount - requestAmount);
        assertEq(IERC20(wbtc).balanceOf(user),                      requestAmount);
    }

}
