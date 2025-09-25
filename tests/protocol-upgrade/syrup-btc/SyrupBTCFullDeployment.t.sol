// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAssetController,
    IAssetControllerOracle,
    IBitcoinStrategy,
    ICompositeToken,
    IERC20,
    IGlobals,
    IPool,
    IPoolManager,
    IPoolPermissionManager,
    ISyrupBitcoinRouter,
    IWithdrawalManagerQueue as IWithdrawalManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { SyrupBTCProtocolUpgradeBase } from "./SyrupBTCProtocolUpgradeBase.t.sol";

contract SyrupBTCFullDeploymentTests is SyrupBTCProtocolUpgradeBase {

    function testFork_syrupBTCFullDeployment() public {
        address pool              = IPoolManager(syrupBitcoinPoolManager).pool();
        address withdrawalManager = IPoolManager(syrupBitcoinPoolManager).withdrawalManager();

        assertEq(IPool(pool).totalSupply(),    0);
        assertEq(IPool(pool).totalAssets(),    0);
        assertEq(IPool(pool).BOOTSTRAP_MINT(), bootstrapMint);
        assertEq(IPool(pool).asset(),          compositeTokenProxy);
        assertEq(IPool(pool).name(),           "Syrup Bitcoin");
        assertEq(IPool(pool).symbol(),         "syrupBTC");
        assertEq(IPool(pool).manager(),        syrupBitcoinPoolManager);

        assertEq(IPoolManager(syrupBitcoinPoolManager).hasSufficientCover(),        true);
        assertEq(IPoolManager(syrupBitcoinPoolManager).configured(),                true);
        assertEq(IPoolManager(syrupBitcoinPoolManager).totalAssets(),               0);
        assertEq(IPoolManager(syrupBitcoinPoolManager).unrealizedLosses(),          0);
        assertEq(IPoolManager(syrupBitcoinPoolManager).strategyListLength(),        2);
        assertEq(IPoolManager(syrupBitcoinPoolManager).pendingPoolDelegate(),       address(0));
        assertEq(IPoolManager(syrupBitcoinPoolManager).globals(),                   globals);
        assertEq(IPoolManager(syrupBitcoinPoolManager).governor(),                  governor);
        assertEq(IPoolManager(syrupBitcoinPoolManager).liquidityCap(),              liquidityCap);
        assertEq(IPoolManager(syrupBitcoinPoolManager).poolDelegate(),              poolDelegate);
        assertEq(IPoolManager(syrupBitcoinPoolManager).factory(),                   poolManagerFactory);
        assertEq(IPoolManager(syrupBitcoinPoolManager).poolPermissionManager(),     poolPermissionManager);
        assertEq(IPoolManager(syrupBitcoinPoolManager).delegateManagementFeeRate(), delegateManagementFeeRate);
        assertEq(IPoolManager(syrupBitcoinPoolManager).implementation(),            PoolManagerV400Implementation);

        assertEq(IPoolManager(syrupBitcoinPoolManager).strategyList(0), bitcoinStrategy1);
        assertEq(IPoolManager(syrupBitcoinPoolManager).strategyList(1), bitcoinStrategy2);

        assertNotEq(IPoolManager(syrupBitcoinPoolManager).strategyList(0),     address(0));
        assertNotEq(IPoolManager(syrupBitcoinPoolManager).strategyList(1),     address(0));
        assertNotEq(IPoolManager(syrupBitcoinPoolManager).withdrawalManager(), address(0));
        assertNotEq(IPoolManager(syrupBitcoinPoolManager).poolDelegateCover(), address(0));

        assertEq(IWithdrawalManager(withdrawalManager).totalShares(),    0);
        assertEq(IWithdrawalManager(withdrawalManager).pool(),           pool);
        assertEq(IWithdrawalManager(withdrawalManager).globals(),        globals);
        assertEq(IWithdrawalManager(withdrawalManager).governor(),       governor);
        assertEq(IWithdrawalManager(withdrawalManager).poolDelegate(),   poolDelegate);
        assertEq(IWithdrawalManager(withdrawalManager).asset(),          compositeTokenProxy);
        assertEq(IWithdrawalManager(withdrawalManager).poolManager(),    syrupBitcoinPoolManager);
        assertEq(IWithdrawalManager(withdrawalManager).factory(),        withdrawalManagerQueueFactory);
        assertEq(IWithdrawalManager(withdrawalManager).implementation(), mapleWithdrawalManagerV200Implementation);

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
        assertEq(IBitcoinStrategy(bitcoinStrategy1).implementation(),        bitcoinStrategyImplementation);

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
        assertEq(IBitcoinStrategy(bitcoinStrategy2).implementation(),        bitcoinStrategyImplementation);

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

        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).locked(),              1);
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).mintFee(wbtc),         0);
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).redemptionFee(wbtc),   0);
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).globals(),             globals);
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).pool(),                syrupBitcoinPool);
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).assetController(wbtc), assetControllerProxy);
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).poolManager(),         syrupBitcoinPoolManager);
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).implementation(),      bitcoinRouterImplementation);

        assertEq(IAssetControllerOracle(assetPriceOracleProxy).globals(),        globals);
        assertEq(IAssetControllerOracle(assetPriceOracleProxy).implementation(), assetPriceOracleImplementation);

        assertEq(IAssetController(assetControllerProxy).locked(),            1);
        assertEq(IAssetController(assetControllerProxy).poolAssets(wbtc),    0);
        assertEq(IAssetController(assetControllerProxy).depositAssets(wbtc), 0);
        assertEq(IAssetController(assetControllerProxy).globals(),           globals);
        assertEq(IAssetController(assetControllerProxy).oracle(),            assetPriceOracleProxy);
        assertEq(IAssetController(assetControllerProxy).router(),            bitcoinRouterProxy);
        assertEq(IAssetController(assetControllerProxy).poolAsset(),         compositeTokenProxy);
        assertEq(IAssetController(assetControllerProxy).implementation(),    assetControllerImplementation);

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
        assertEq(ICompositeToken(compositeTokenProxy).controllers(assetControllerProxy),      true);

        assertEq(IAssetController(assetControllerProxy).canWrap(wbtc),                true);
        assertEq(IAssetController(assetControllerProxy).canUnwrap(wbtc),              true);
        assertEq(IAssetController(assetControllerProxy).canDeploy(wbtc),              true);
        assertEq(IAssetController(assetControllerProxy).canReconcile(wbtc),           true);
        assertEq(IAssetController(assetControllerProxy).isStrategy(bitcoinStrategy1), true);
        assertEq(IAssetController(assetControllerProxy).isStrategy(bitcoinStrategy2), true);

        assertEq(IPoolPermissionManager(poolPermissionManager).lenderAllowlist(bitcoinRouterProxy, strategyManager), true);
        assertEq(IPoolPermissionManager(poolPermissionManager).permissionLevels(syrupBitcoinPoolManager), 1);

        uint256 bitmap = 2 ** 5;

        assertEq(IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:transfer"),          0);
        assertEq(IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:transferFrom"),      0);
        assertEq(IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:deposit"),           bitmap);
        assertEq(IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:depositWithPermit"), bitmap);
        assertEq(IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:mint"),              bitmap);
        assertEq(IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:mintWithPermit"),    bitmap);
        assertEq(IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:redeem"),            bitmap);
        assertEq(IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:withdraw"),          bitmap);
        assertEq(IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:removeShares"),      bitmap);
        assertEq(IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:requestRedeem"),     bitmap);
        assertEq(IPoolPermissionManager(poolPermissionManager).poolBitmaps(syrupBitcoinPoolManager, "P:requestWithdraw"),   bitmap);

        assertEq(IGlobals(globals).isInstanceOf("BITCOIN_STRATEGY",     bitcoinStrategy1),      true);
        assertEq(IGlobals(globals).isInstanceOf("BITCOIN_STRATEGY",     bitcoinStrategy2),      true);
        assertEq(IGlobals(globals).isInstanceOf("SYRUP_BTC_ROUTER",     bitcoinRouterProxy),    true);
        assertEq(IGlobals(globals).isInstanceOf("COMPOSITE_POOL_ASSET", compositeTokenProxy),   true);
        assertEq(IGlobals(globals).isInstanceOf("ASSET_CONTROLLER",     assetControllerProxy),  true);
        assertEq(IGlobals(globals).isInstanceOf("SYRUP_BTC_REDEEMER",   bitcoinRouterRedeemer), true);
        assertEq(IGlobals(globals).isInstanceOf("CONTROLLER_ORACLE",    assetPriceOracleProxy), true);
    }

}
