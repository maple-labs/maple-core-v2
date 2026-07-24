// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { ITradingStrategy } from "../../../contracts/interfaces/Interfaces.sol";

import { TradingStrategyTestBase } from "./TradingStrategyTestBase.sol";

contract TradingStrategyDeployAssetsFailureTests is TradingStrategyTestBase {

    uint256 deployAmount     = 400_000e6;
    uint256 initialLiquidity = INITIAL_LIQUIDITY;

    function setUp() public override {
        super.setUp();

        deposit(lp, initialLiquidity);
        fundStrategyManager(address(poolManager), tradingStrategyManager, initialLiquidity);
    }

    function test_deployAssets_revert_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(trader);
        vm.expectRevert("MTS:PAUSED");
        ITradingStrategy(tradingUnderlyingStrategy).deployAssets(deployAmount, "");
    }

    function test_deployAssets_revert_contractPaused() external {
        vm.prank(governor);
        globals.setContractPause(tradingUnderlyingStrategy, true);

        vm.prank(trader);
        vm.expectRevert("MTS:PAUSED");
        ITradingStrategy(tradingUnderlyingStrategy).deployAssets(deployAmount, "");
    }

    function test_deployAssets_revert_notTradingAddress() external {
        address notTrader = makeAddr("notTrader");

        vm.prank(notTrader);
        vm.expectRevert("MTS:NOT_MAPLE_MANAGED_WALLET");
        ITradingStrategy(tradingUnderlyingStrategy).deployAssets(deployAmount, "");
    }

    function test_deployAssets_revert_notAllowed() external {
        address restrictedTrader = makeAddr("restrictedTrader");

        setTradingAddress({
            strategy_:        tradingUnderlyingStrategy,
            tradingAddress_:  restrictedTrader,
            canDeployAssets_: false,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   type(uint256).max
        });

        vm.prank(restrictedTrader);
        vm.expectRevert("MTS:DA:NOT_ALLOWED");
        ITradingStrategy(tradingUnderlyingStrategy).deployAssets(deployAmount, "");
    }

    function test_deployAssets_revert_zeroAssets() external {
        vm.prank(trader);
        vm.expectRevert("MTS:DA:ZERO_ASSETS");
        ITradingStrategy(tradingUnderlyingStrategy).deployAssets(0, "");
    }

    function test_deployAssets_revert_insufficientAssets_boundary() external {
        vm.prank(trader);
        vm.expectRevert("MTS:DA:INSUFFICIENT_ASSETS");
        ITradingStrategy(tradingUnderlyingStrategy).deployAssets(initialLiquidity + 1, "");
    }

    function test_deployAssets_revert_insufficientAssets_unvestedYield() external {
        uint32 elapsedDuration = 7 days;
        uint32 totalDuration   = 10 days;

        uint256 yieldAssets   = 100_000e6;
        uint256 realizedYield = yieldAssets * elapsedDuration / totalDuration;

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, totalDuration);

        vm.warp(startingTime + elapsedDuration);
        vm.prank(trader);
        vm.expectRevert("MTS:DA:INSUFFICIENT_ASSETS");
        ITradingStrategy(tradingUnderlyingStrategy).deployAssets(initialLiquidity + realizedYield + 1, "");
    }

    function test_deployAssets_revert_capExceeded_zeroCap() external {
        address zeroCapTrader = makeAddr("zeroCapTrader");

        setTradingAddress({
            strategy_:        tradingUnderlyingStrategy,
            tradingAddress_:  zeroCapTrader,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   0
        });

        vm.prank(zeroCapTrader);
        vm.expectRevert("MTS:DA:CAP_EXCEEDED");
        ITradingStrategy(tradingUnderlyingStrategy).deployAssets(1, "");
    }

    function test_deployAssets_revert_capExceeded_boundary() external {
        address cappedTrader = makeAddr("cappedTrader");

        setTradingAddress({
            strategy_:        tradingUnderlyingStrategy,
            tradingAddress_:  cappedTrader,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   deployAmount - 1
        });

        vm.prank(cappedTrader);
        vm.expectRevert("MTS:DA:CAP_EXCEEDED");
        ITradingStrategy(tradingUnderlyingStrategy).deployAssets(deployAmount, "");
    }

    function test_deployAssets_revert_capExceeded_withPriorDeployment() external {
        address cappedTrader = makeAddr("cappedTrader");

        setTradingAddress({
            strategy_:        tradingUnderlyingStrategy,
            tradingAddress_:  cappedTrader,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   deployAmount
        });

        vm.prank(cappedTrader);
        ITradingStrategy(tradingUnderlyingStrategy).deployAssets(deployAmount - 1, "");

        vm.prank(cappedTrader);
        vm.expectRevert("MTS:DA:CAP_EXCEEDED");
        ITradingStrategy(tradingUnderlyingStrategy).deployAssets(2, "");
    }

    function test_deployAssets_revert_transferFailed() external {
        fundsAsset.__failWhenCalledBy(tradingUnderlyingStrategy);

        vm.prank(trader);
        vm.expectRevert("MTS:DA:TRANSFER_FAILED");
        ITradingStrategy(tradingUnderlyingStrategy).deployAssets(deployAmount, "");
    }

}

contract TradingStrategyDeployAssetsSuccessTests is TradingStrategyTestBase {

    uint256 initialLiquidity = INITIAL_LIQUIDITY;

    function setUp() public override {
        super.setUp();

        // Fund pool and strategy.
        deposit(lp, initialLiquidity);
        fundStrategyManager(address(poolManager), tradingStrategyManager, initialLiquidity);

        // Initial assertions.
        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), 0);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity);
        assertEq(fundsAsset.balanceOf(trader),                    0);
    }

    function test_deployAssets_success_partialAmount() external {
        uint256 deployAmount = 400_000e6;

        deployAssets(tradingUnderlyingStrategy, trader, deployAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            totalDeployedAssets:   deployAmount,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), deployAmount);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - deployAmount);
        assertEq(fundsAsset.balanceOf(trader),                    deployAmount);
    }

    function test_deployAssets_success_fullAvailableAmount() external {
        deployAssets(tradingUnderlyingStrategy, trader, initialLiquidity);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   0,
            totalDeployedAssets:   initialLiquidity,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialLiquidity);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(trader),                    initialLiquidity);
    }

    function test_deployAssets_success_exactDeploymentCapBoundary() external {
        address cappedTrader = makeAddr("cappedTrader");
        uint256 deployAmount = 400_000e6;

        setTradingAddress({
            strategy_:        tradingUnderlyingStrategy,
            tradingAddress_:  cappedTrader,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   deployAmount
        });

        /**********************************************************************************************************************************/
        /*** Deploy exactly up to the deployment cap                                                                                    ***/
        /**********************************************************************************************************************************/

        deployAssets(tradingUnderlyingStrategy, cappedTrader, deployAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            totalDeployedAssets:   deployAmount,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(cappedTrader), deployAmount);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - deployAmount);
        assertEq(fundsAsset.balanceOf(cappedTrader),              deployAmount);
    }

    function test_deployAssets_success_multipleDeploymentsAccumulate() external {

        /**********************************************************************************************************************************/
        /*** Step 1: First deployment                                                                                                   ***/
        /**********************************************************************************************************************************/

        uint256 firstAmount = 250_000e6;

        deployAssets(tradingUnderlyingStrategy, trader, firstAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - firstAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - firstAmount,
            totalDeployedAssets:   firstAmount,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), firstAmount);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - firstAmount);
        assertEq(fundsAsset.balanceOf(trader),                    firstAmount);

        /**********************************************************************************************************************************/
        /*** Step 2: Second deployment accumulates on top of the first                                                                  ***/
        /**********************************************************************************************************************************/

        uint256 secondAmount = 150_000e6;

        deployAssets(tradingUnderlyingStrategy, trader, secondAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - firstAmount - secondAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - firstAmount - secondAmount,
            totalDeployedAssets:   firstAmount + secondAmount,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), firstAmount + secondAmount);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - firstAmount - secondAmount);
        assertEq(fundsAsset.balanceOf(trader),                    firstAmount + secondAmount);
    }

    function test_deployAssets_success_multipleTradingAddresses() external {
        address trader2 = makeAddr("trader2");

        setTradingAddress({
            strategy_:        tradingUnderlyingStrategy,
            tradingAddress_:  trader2,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   type(uint256).max
        });

        /**********************************************************************************************************************************/
        /*** Step 1: First trading address deploys its share                                                                            ***/
        /**********************************************************************************************************************************/

        uint256 firstAmount = 300_000e6;

        deployAssets(tradingUnderlyingStrategy, trader, firstAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - firstAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - firstAmount,
            totalDeployedAssets:   firstAmount,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader),  firstAmount);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader2), 0);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - firstAmount);
        assertEq(fundsAsset.balanceOf(trader),                    firstAmount);
        assertEq(fundsAsset.balanceOf(trader2),                   0);

        /**********************************************************************************************************************************/
        /*** Step 2: Second trading address deploys independently, accounted for separately from the first                              ***/
        /**********************************************************************************************************************************/

        uint256 secondAmount = 120_000e6;

        deployAssets(tradingUnderlyingStrategy, trader2, secondAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - firstAmount - secondAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - firstAmount - secondAmount,
            totalDeployedAssets:   firstAmount + secondAmount,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader),  firstAmount);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader2), secondAmount);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - firstAmount - secondAmount);
        assertEq(fundsAsset.balanceOf(trader),                    firstAmount);
        assertEq(fundsAsset.balanceOf(trader2),                   secondAmount);
    }

    function test_deployAssets_success_afterReturnAssetsFreesCap() external {
        address cappedTrader = makeAddr("cappedTrader");
        uint256 deployAmount = 400_000e6;

        setTradingAddress({
            strategy_:        tradingUnderlyingStrategy,
            tradingAddress_:  cappedTrader,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   deployAmount
        });

        /**********************************************************************************************************************************/
        /*** Step 1: Deploy up to the full deployment cap                                                                               ***/
        /**********************************************************************************************************************************/

        deployAssets(tradingUnderlyingStrategy, cappedTrader, deployAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            totalDeployedAssets:   deployAmount,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(cappedTrader), deployAmount);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - deployAmount);
        assertEq(fundsAsset.balanceOf(cappedTrader),              deployAmount);

        /**********************************************************************************************************************************/
        /*** Step 2: Return part of the deployed assets, freeing up cap headroom                                                        ***/
        /**********************************************************************************************************************************/

        uint256 returnAmount = 100_000e6;

        returnAssets(tradingUnderlyingStrategy, cappedTrader, cappedTrader, returnAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount + returnAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount + returnAmount,
            totalDeployedAssets:   deployAmount - returnAmount,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(cappedTrader), deployAmount - returnAmount);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - deployAmount + returnAmount);
        assertEq(fundsAsset.balanceOf(cappedTrader),              deployAmount);

        /**********************************************************************************************************************************/
        /*** Step 3: Deploy again, reusing the freed-up cap headroom                                                                    ***/
        /**********************************************************************************************************************************/

        deployAssets(tradingUnderlyingStrategy, cappedTrader, returnAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            totalDeployedAssets:   deployAmount,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(cappedTrader), deployAmount);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - deployAmount);
        assertEq(fundsAsset.balanceOf(cappedTrader),              deployAmount + returnAmount);
    }

    function test_deployAssets_success_afterLossRecognitionFreesCap() external {
        address cappedTrader = makeAddr("cappedTrader");
        uint256 deployAmount = 400_000e6;

        setTradingAddress({
            strategy_:        tradingUnderlyingStrategy,
            tradingAddress_:  cappedTrader,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   deployAmount
        });

        /**********************************************************************************************************************************/
        /*** Step 1: Deploy up to the full deployment cap                                                                               ***/
        /**********************************************************************************************************************************/

        deployAssets(tradingUnderlyingStrategy, cappedTrader, deployAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            totalDeployedAssets:   deployAmount,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(cappedTrader), deployAmount);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - deployAmount);
        assertEq(fundsAsset.balanceOf(cappedTrader),              deployAmount);

        /**********************************************************************************************************************************/
        /*** Step 2: Recognize a loss on the deployed assets, freeing up cap headroom                                                   ***/
        /**********************************************************************************************************************************/

        uint256 lossAmount = 100_000e6;

        recognizeLoss(tradingUnderlyingStrategy, cappedTrader, lossAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity - lossAmount,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity - lossAmount,
            availableToWithdraw:   initialLiquidity - deployAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity - lossAmount,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity - lossAmount,
            availableToWithdraw:   initialLiquidity - deployAmount,
            totalDeployedAssets:   deployAmount - lossAmount,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(cappedTrader), deployAmount - lossAmount);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - deployAmount);
        assertEq(fundsAsset.balanceOf(cappedTrader),              deployAmount);

        /**********************************************************************************************************************************/
        /*** Step 3: Deploy again, reusing the freed-up cap headroom                                                                    ***/
        /**********************************************************************************************************************************/

        deployAssets(tradingUnderlyingStrategy, cappedTrader, lossAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity - lossAmount,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity - lossAmount,
            availableToWithdraw:   initialLiquidity - deployAmount - lossAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity - lossAmount,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity - lossAmount,
            availableToWithdraw:   initialLiquidity - deployAmount - lossAmount,
            totalDeployedAssets:   deployAmount,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(cappedTrader), deployAmount - lossAmount + lossAmount);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - deployAmount - lossAmount);
        assertEq(fundsAsset.balanceOf(cappedTrader),              deployAmount + lossAmount);
    }

    function test_deployAssets_success_scheduledYield() external {

        /**********************************************************************************************************************************/
        /*** Step 1: Schedule yield                                                                                                     ***/
        /**********************************************************************************************************************************/

        uint256 yieldAssets = 100_000e6;

        uint32 duration = 10 days;

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, duration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), 0);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity + yieldAssets);
        assertEq(fundsAsset.balanceOf(trader),                    0);

        /**********************************************************************************************************************************/
        /*** Step 2: Deploy assets                                                                                                      ***/
        /**********************************************************************************************************************************/

        uint256 deployAmount = 400_000e6;

        deployAssets(tradingUnderlyingStrategy, trader, deployAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            totalDeployedAssets:   deployAmount,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + duration,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), deployAmount);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity + yieldAssets - deployAmount);
        assertEq(fundsAsset.balanceOf(trader),                    deployAmount);
    }

    function test_deployAssets_success_partiallyRealizedYield() external {

        /**********************************************************************************************************************************/
        /*** Step 1: Schedule yield                                                                                                     ***/
        /**********************************************************************************************************************************/

        uint256 yieldAssets  = 100_000e6;

        uint32 totalDuration   = 10 days;
        uint32 elapsedDuration = 7 days;

        uint256 realizedYield = yieldAssets * elapsedDuration / totalDuration;

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, totalDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), 0);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity + yieldAssets);
        assertEq(fundsAsset.balanceOf(trader),                    0);

        /**********************************************************************************************************************************/
        /*** Step 2: Wait for partial accrual                                                                                           ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity + realizedYield,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity + realizedYield,
            availableToWithdraw:   initialLiquidity + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity + realizedYield,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity + realizedYield,
            availableToWithdraw:   initialLiquidity + realizedYield,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), 0);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity + yieldAssets);
        assertEq(fundsAsset.balanceOf(trader),                    0);

        /**********************************************************************************************************************************/
        /*** Step 3: Deploy assets                                                                                                      ***/
        /**********************************************************************************************************************************/

        uint256 deployAmount = 400_000e6;

        deployAssets(tradingUnderlyingStrategy, trader, deployAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity + realizedYield,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity + realizedYield,
            availableToWithdraw:   initialLiquidity + realizedYield - deployAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity + realizedYield,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity + realizedYield,
            availableToWithdraw:   initialLiquidity + realizedYield - deployAmount,
            totalDeployedAssets:   deployAmount,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), deployAmount);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity + yieldAssets - deployAmount);
        assertEq(fundsAsset.balanceOf(trader),                    deployAmount);
    }

    function test_deployAssets_success_fullyRealizedYield() external {

        /**********************************************************************************************************************************/
        /*** Step 1: Schedule yield                                                                                                     ***/
        /**********************************************************************************************************************************/

        uint256 yieldAssets = 100_000e6;

        uint32 totalDuration = 10 days;

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, totalDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), 0);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity + yieldAssets);
        assertEq(fundsAsset.balanceOf(trader),                    0);

        /**********************************************************************************************************************************/
        /*** Step 2: Wait until full accrual                                                                                            ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + totalDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity + yieldAssets,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity + yieldAssets,
            availableToWithdraw:   initialLiquidity + yieldAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity + yieldAssets,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity + yieldAssets,
            availableToWithdraw:   initialLiquidity + yieldAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            realizedYield:        yieldAssets
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), 0);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity + yieldAssets);
        assertEq(fundsAsset.balanceOf(trader),                    0);

        /**********************************************************************************************************************************/
        /*** Step 3: Deploy assets                                                                                                      ***/
        /**********************************************************************************************************************************/

        uint256 deployAmount = 400_000e6;

        deployAssets(tradingUnderlyingStrategy, trader, deployAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity + yieldAssets,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity + yieldAssets,
            availableToWithdraw:   initialLiquidity + yieldAssets - deployAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity + yieldAssets,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity + yieldAssets,
            availableToWithdraw:   initialLiquidity + yieldAssets - deployAmount,
            totalDeployedAssets:   deployAmount,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            realizedYield:        yieldAssets
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), deployAmount);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity + yieldAssets - deployAmount);
        assertEq(fundsAsset.balanceOf(trader),                    deployAmount);
    }

    function test_deployAssets_success_pastYieldDeadline() external {

        /**********************************************************************************************************************************/
        /*** Step 1: Schedule yield                                                                                                     ***/
        /**********************************************************************************************************************************/

        uint256 yieldAssets = 100_000e6;

        uint32 totalDuration    = 10 days;
        uint32 timePastDeadline = 3 days;

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, totalDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), 0);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity + yieldAssets);
        assertEq(fundsAsset.balanceOf(trader),                    0);

        /**********************************************************************************************************************************/
        /*** Step 2: Wait past full accrual                                                                                             ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + totalDuration + timePastDeadline);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity + yieldAssets,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity + yieldAssets,
            availableToWithdraw:   initialLiquidity + yieldAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity + yieldAssets,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity + yieldAssets,
            availableToWithdraw:   initialLiquidity + yieldAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            realizedYield:        yieldAssets
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), 0);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity + yieldAssets);
        assertEq(fundsAsset.balanceOf(trader),                    0);

        /**********************************************************************************************************************************/
        /*** Step 3: Deploy assets                                                                                                      ***/
        /**********************************************************************************************************************************/

        uint256 deployAmount = 400_000e6;

        deployAssets(tradingUnderlyingStrategy, trader, deployAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity + yieldAssets,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity + yieldAssets,
            availableToWithdraw:   initialLiquidity + yieldAssets - deployAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity + yieldAssets,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity + yieldAssets,
            availableToWithdraw:   initialLiquidity + yieldAssets - deployAmount,
            totalDeployedAssets:   deployAmount,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            realizedYield:        yieldAssets
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), deployAmount);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity + yieldAssets - deployAmount);
        assertEq(fundsAsset.balanceOf(trader),                    deployAmount);
    }

    function test_deployAssets_success_impairment() external {

        /**********************************************************************************************************************************/
        /*** Step 1: Impair assets                                                                                                      ***/
        /**********************************************************************************************************************************/

        uint256 impairAmount = 250_000e6;

        impairTradingStrategy(tradingUnderlyingStrategy, impairAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   impairAmount,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
            unrealizedLosses:      impairAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: impairAmount
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairAmount
        });

        /**********************************************************************************************************************************/
        /*** Step 2: Deploy assets                                                                                                      ***/
        /**********************************************************************************************************************************/

        uint256 deployAmount = 400_000e6;

        deployAssets(tradingUnderlyingStrategy, trader, deployAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   impairAmount,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            unrealizedLosses:      impairAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: impairAmount
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - deployAmount,
            totalDeployedAssets:   deployAmount,
            unrealizedLosses:      impairAmount
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), deployAmount);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - deployAmount);
        assertEq(fundsAsset.balanceOf(trader),                    deployAmount);
    }

    function test_deployAssets_success_afterLossRecognition() external {

        /**********************************************************************************************************************************/
        /*** Step 1: Deploy assets                                                                                                      ***/
        /**********************************************************************************************************************************/

        uint256 firstAmount = 400_000e6;

        deployAssets(tradingUnderlyingStrategy, trader, firstAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - firstAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity,
            availableToWithdraw:   initialLiquidity - firstAmount,
            totalDeployedAssets:   firstAmount,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), firstAmount);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - firstAmount);
        assertEq(fundsAsset.balanceOf(trader),                    firstAmount);

        /**********************************************************************************************************************************/
        /*** Step 2: Recognize a loss on the deployed assets                                                                            ***/
        /**********************************************************************************************************************************/

        uint256 lossAmount = 150_000e6;

        recognizeLoss(tradingUnderlyingStrategy, trader, lossAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity - lossAmount,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity - lossAmount,
            availableToWithdraw:   initialLiquidity - firstAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity - lossAmount,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity - lossAmount,
            availableToWithdraw:   initialLiquidity - firstAmount,
            totalDeployedAssets:   firstAmount - lossAmount,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), firstAmount - lossAmount);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - firstAmount);
        assertEq(fundsAsset.balanceOf(trader),                    firstAmount);

        /**********************************************************************************************************************************/
        /*** Step 3: Deploy again after the loss has been recognized                                                                    ***/
        /**********************************************************************************************************************************/

        uint256 secondAmount = 100_000e6;

        deployAssets(tradingUnderlyingStrategy, trader, secondAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity - lossAmount,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: initialLiquidity - lossAmount,
            availableToWithdraw:   initialLiquidity - firstAmount - secondAmount,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialLiquidity - lossAmount,
            shares:           initialLiquidity,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialLiquidity - lossAmount,
            availableToWithdraw:   initialLiquidity - firstAmount - secondAmount,
            totalDeployedAssets:   firstAmount - lossAmount + secondAmount,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), firstAmount - lossAmount + secondAmount);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - firstAmount - secondAmount);
        assertEq(fundsAsset.balanceOf(trader),                    firstAmount + secondAmount);
    }

}
