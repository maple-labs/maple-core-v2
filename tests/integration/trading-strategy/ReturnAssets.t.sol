// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { ITradingStrategy } from "../../../contracts/interfaces/Interfaces.sol";

import { TradingStrategyTestBase } from "./TradingStrategyTestBase.sol";

contract TradingStrategyReturnAssetsTestBase is TradingStrategyTestBase {

    uint256 initialDeployment = 400_000e6;
    uint256 initialLiquidity  = 1_000_000e6;

    function setUp() public override {
        super.setUp();

        // Fund pool and strategy, then deploy assets so there is an existing position to return from.
        deposit(lp, initialLiquidity);
        fundStrategyManager(address(poolManager), tradingStrategyManager, initialLiquidity);
        deployAssets(tradingUnderlyingStrategy, trader, initialDeployment);

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
            availableToWithdraw:   initialLiquidity - initialDeployment,
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
            availableToWithdraw:   initialLiquidity - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - initialDeployment);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
    }

}

contract TradingStrategyReturnAssetsFailureTests is TradingStrategyReturnAssetsTestBase {

    function test_returnAssets_revert_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(trader);
        vm.expectRevert("MTS:PAUSED");
        ITradingStrategy(tradingUnderlyingStrategy).returnAssets(initialDeployment, trader, "");
    }

    function test_returnAssets_revert_contractPaused() external {
        vm.prank(governor);
        globals.setContractPause(tradingUnderlyingStrategy, true);

        vm.prank(trader);
        vm.expectRevert("MTS:PAUSED");
        ITradingStrategy(tradingUnderlyingStrategy).returnAssets(initialDeployment, trader, "");
    }

    function test_returnAssets_revert_notManagedWallet() external {
        address notTrader = makeAddr("notTrader");

        vm.prank(notTrader);
        vm.expectRevert("MTS:NOT_MAPLE_MANAGED_WALLET");
        ITradingStrategy(tradingUnderlyingStrategy).returnAssets(initialDeployment, trader, "");
    }

    function test_returnAssets_revert_notAllowed() external {
        setPermissions({
            strategy_:         tradingUnderlyingStrategy,
            account_:          trader,
            canDeployAssets_:  true,
            canReturnAssets_:  false,
            canRealizeYield_:  true
        });

        vm.prank(trader);
        vm.expectRevert("MTS:RA:NOT_ALLOWED");
        ITradingStrategy(tradingUnderlyingStrategy).returnAssets(1, trader, "");
    }

    function test_returnAssets_revert_zeroAssets() external {
        vm.prank(trader);
        vm.expectRevert("MTS:RA:ZERO_ASSETS");
        ITradingStrategy(tradingUnderlyingStrategy).returnAssets(0, trader, "");
    }

    function test_returnAssets_revert_exceedsAssets_boundary() external {
        vm.prank(trader);
        vm.expectRevert("MTS:RA:EXCEEDS_ASSETS");
        ITradingStrategy(tradingUnderlyingStrategy).returnAssets(initialDeployment + 1, trader, "");
    }

    function test_returnAssets_revert_exceedsAssets_afterLossRecognition() external {
        uint256 lossAmount = 100_000e6;

        recognizeLoss(tradingUnderlyingStrategy, trader, lossAmount);

        vm.prank(trader);
        vm.expectRevert("MTS:RA:EXCEEDS_ASSETS");
        ITradingStrategy(tradingUnderlyingStrategy).returnAssets(initialDeployment - lossAmount + 1, trader, "");
    }

    function test_returnAssets_revert_exceedsAssets_nothingDeployed() external {
        address idleTrader = makeAddr("idleTrader");

        setTradingAddress({
            strategy_:         tradingUnderlyingStrategy,
            tradingAddress_:   idleTrader,
            canDeployAssets_:  true,
            canReturnAssets_:  true,
            canRealizeYield_:  true,
            deploymentCap_:    0
        });

        vm.prank(idleTrader);
        vm.expectRevert("MTS:RA:EXCEEDS_ASSETS");
        ITradingStrategy(tradingUnderlyingStrategy).returnAssets(1, idleTrader, "");
    }

}

contract TradingStrategyReturnAssetsSuccessTests is TradingStrategyReturnAssetsTestBase {

    function test_returnAssets_success_partialAmount() external {

        /**********************************************************************************************************************************/
        /*** Return a portion of the deployed assets                                                                                    ***/
        /**********************************************************************************************************************************/

        uint256 returnAmount = 150_000e6;

        returnAssets(tradingUnderlyingStrategy, trader, trader, returnAmount);

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
            availableToWithdraw:   initialLiquidity - initialDeployment + returnAmount,
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
            availableToWithdraw:   initialLiquidity - initialDeployment + returnAmount,
            totalDeployedAssets:   initialDeployment - returnAmount,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment - returnAmount);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - initialDeployment + returnAmount);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
    }

    function test_returnAssets_success_fullAmount() external {

        /**********************************************************************************************************************************/
        /*** Return all of the deployed assets                                                                                          ***/
        /**********************************************************************************************************************************/

        returnAssets(tradingUnderlyingStrategy, trader, trader, initialDeployment);

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

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), 0);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
    }

    function test_returnAssets_success_freesDeploymentCapForRedeploy() external {

        /**********************************************************************************************************************************/
        /*** Return part of the deployed assets, freeing up cap headroom                                                                ***/
        /**********************************************************************************************************************************/

        uint256 returnAmount = 200_000e6;

        setDeploymentCap(tradingUnderlyingStrategy, trader, initialDeployment);
        returnAssets(tradingUnderlyingStrategy, trader, trader, returnAmount);

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
            availableToWithdraw:   initialLiquidity - initialDeployment + returnAmount,
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
            availableToWithdraw:   initialLiquidity - initialDeployment + returnAmount,
            totalDeployedAssets:   initialDeployment - returnAmount,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment - returnAmount);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - initialDeployment + returnAmount);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);

        /**********************************************************************************************************************************/
        /*** Redeploy the freed amount, proving the cap headroom was freed                                                              ***/
        /**********************************************************************************************************************************/

        deployAssets(tradingUnderlyingStrategy, trader, returnAmount);

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
            availableToWithdraw:   initialLiquidity - initialDeployment,
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
            availableToWithdraw:   initialLiquidity - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - initialDeployment);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment + returnAmount);
    }

    function test_returnAssets_success_freesLiquidityForWithdrawal() external {

        /**********************************************************************************************************************************/
        /*** Request and process redemption of the assets that were never deployed                                                      ***/
        /**********************************************************************************************************************************/

        uint256 idleLiquidity = initialLiquidity - initialDeployment;

        requestRedeemFromStrategyManager(address(poolManager), tradingStrategyManager, idleLiquidity);
        processRedemptionFromStrategyManager(address(poolManager), tradingStrategyManager, idleLiquidity);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: idleLiquidity
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialDeployment,
            totalPendingShares:    0,
            assetsUnderManagement: initialDeployment,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialDeployment,
            shares:           initialDeployment,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialDeployment,
            availableToWithdraw:   0,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(address(pool)),             idleLiquidity);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);

        /**********************************************************************************************************************************/
        /*** Return the deployed assets, making them available to withdraw again                                                        ***/
        /**********************************************************************************************************************************/

        returnAssets(tradingUnderlyingStrategy, trader, trader, initialDeployment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: idleLiquidity
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialDeployment,
            totalPendingShares:    0,
            assetsUnderManagement: initialDeployment,
            availableToWithdraw:   initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialDeployment,
            shares:           initialDeployment,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialDeployment,
            availableToWithdraw:   initialDeployment,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), 0);

        assertEq(fundsAsset.balanceOf(address(pool)),             idleLiquidity);
        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialDeployment);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);

        /**********************************************************************************************************************************/
        /*** Request and process redemption of the newly returned assets                                                                ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), tradingStrategyManager, initialDeployment);
        processRedemptionFromStrategyManager(address(poolManager), tradingStrategyManager, initialDeployment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: initialLiquidity
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), 0);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(address(pool)),             initialLiquidity);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
    }

    function test_returnAssets_success_onBehalfOfDifferentCaller() external {

        /**********************************************************************************************************************************/
        /*** Return assets on behalf of another trading address                                                                         ***/
        /**********************************************************************************************************************************/

        address trader2      = makeAddr("trader2");
        uint256 returnAmount = 150_000e6;

        setTradingAddress({
            strategy_:         tradingUnderlyingStrategy,
            tradingAddress_:   trader2,
            canDeployAssets_:  true,
            canReturnAssets_:  true,
            canRealizeYield_:  true,
            deploymentCap_:    type(uint256).max
        });
        returnAssets(tradingUnderlyingStrategy, trader2, trader, returnAmount);

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
            availableToWithdraw:   initialLiquidity - initialDeployment + returnAmount,
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
            availableToWithdraw:   initialLiquidity - initialDeployment + returnAmount,
            totalDeployedAssets:   initialDeployment - returnAmount,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader),  initialDeployment - returnAmount);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader2), 0);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - initialDeployment + returnAmount);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(trader2),                   0);
    }

    function test_returnAssets_success_afterOnBehalfOfPermissionRevoked() external {

        /**********************************************************************************************************************************/
        /*** Return the assets with another trading address                                                                             ***/
        /**********************************************************************************************************************************/

        address trader2 = makeAddr("trader2");

        setPermissions({
            strategy_:         tradingUnderlyingStrategy,
            account_:          trader,
            canDeployAssets_:  false,
            canReturnAssets_:  false,
            canRealizeYield_:  false
        });
        setTradingAddress({
            strategy_:         tradingUnderlyingStrategy,
            tradingAddress_:   trader2,
            canDeployAssets_:  true,
            canReturnAssets_:  true,
            canRealizeYield_:  true,
            deploymentCap_:    type(uint256).max
        });
        returnAssets(tradingUnderlyingStrategy, trader2, trader, initialDeployment);

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

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader),  0);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader2), 0);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(trader2),                   0);
    }

    function test_returnAssets_success_withYield() external {

        /**********************************************************************************************************************************/
        /*** Warp some time during the vesting period                                                                                   ***/
        /**********************************************************************************************************************************/

        uint256 yieldAssets = 100_000e6;

        uint32 totalDuration   = 10 days;
        uint32 elapsedDuration = 6 days;

        uint256 realizedYield = yieldAssets * elapsedDuration / totalDuration;

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, totalDuration);

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
            availableToWithdraw:   initialLiquidity - initialDeployment + realizedYield,
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
            availableToWithdraw:   initialLiquidity - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: yieldAssets,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity + yieldAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);

        /**********************************************************************************************************************************/
        /*** Return the deployed principal while yield is still mid-vesting                                                             ***/
        /**********************************************************************************************************************************/

        returnAssets(tradingUnderlyingStrategy, trader, trader, initialDeployment);

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
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
    }

    function test_returnAssets_success_withYieldAndFees() external {

        /**********************************************************************************************************************************/
        /*** Set the strategy fee rates and realize yield, paying the delegate and protocol fees upfront                                ***/
        /**********************************************************************************************************************************/

        uint32 delegateFeeRate = 0.1e6;   // 10% of yield
        uint32 protocolFeeRate = 0.05e6;  // 5% of yield

        uint256 yieldAssets = 200_000e6;

        uint32 totalDuration   = 10 days;
        uint32 elapsedDuration = 6 days;

        uint256 delegateFee = 20_000e6;   // 200_000e6 * 0.1e6  / 1e6
        uint256 protocolFee = 10_000e6;   // 200_000e6 * 0.05e6 / 1e6
        uint256 netYield    = 170_000e6;  // 200_000e6 - 20_000e6 - 10_000e6

        uint256 realizedYield = netYield * elapsedDuration / totalDuration;

        setStrategyDelegateFeeRate(tradingUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(tradingUnderlyingStrategy, protocolFeeRate);
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
            availableToWithdraw:   initialLiquidity - initialDeployment,
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
            availableToWithdraw:   initialLiquidity - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp partway through vesting so only part of the net yield is realized                                                     ***/
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
            availableToWithdraw:   initialLiquidity - initialDeployment + realizedYield,
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
            availableToWithdraw:   initialLiquidity - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Return the deployed principal while the net yield is still mid-vesting                                                     ***/
        /**********************************************************************************************************************************/

        returnAssets(tradingUnderlyingStrategy, trader, trader, initialDeployment);

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
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + totalDuration,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), 0);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);
    }

    function test_returnAssets_success_withImpairment() external {

        /**********************************************************************************************************************************/
        /*** Impair the strategy                                                                                                        ***/
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
            availableToWithdraw:   initialLiquidity - initialDeployment,
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
            availableToWithdraw:   initialLiquidity - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairAmount
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - initialDeployment);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);

        /**********************************************************************************************************************************/
        /*** Return the deployed assets while the strategy remains impaired                                                             ***/
        /**********************************************************************************************************************************/

        returnAssets(tradingUnderlyingStrategy, trader, trader, initialDeployment);

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

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), 0);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
    }

    function test_returnAssets_success_afterLossRecognition() external {

        /**********************************************************************************************************************************/
        /*** Recognize a loss on part of the deployed assets                                                                            ***/
        /**********************************************************************************************************************************/

        uint256 lossAmount = 100_000e6;

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
            availableToWithdraw:   initialLiquidity - initialDeployment,
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
            availableToWithdraw:   initialLiquidity - initialDeployment,
            totalDeployedAssets:   initialDeployment - lossAmount,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment - lossAmount);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - initialDeployment);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);

        /**********************************************************************************************************************************/
        /*** Return the remaining deployed assets, net of the recognized loss                                                           ***/
        /**********************************************************************************************************************************/

        uint256 returnAmount = initialDeployment - lossAmount;

        returnAssets(tradingUnderlyingStrategy, trader, trader, returnAmount);

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
            availableToWithdraw:   initialLiquidity - lossAmount,
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
            availableToWithdraw:   initialLiquidity - lossAmount,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), 0);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - lossAmount);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
    }

    function test_returnAssets_success_multipleReturnsAccumulate() external {

        /**********************************************************************************************************************************/
        /*** First partial return                                                                                                       ***/
        /**********************************************************************************************************************************/

        uint256 firstReturn = 100_000e6;

        returnAssets(tradingUnderlyingStrategy, trader, trader, firstReturn);

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
            availableToWithdraw:   initialLiquidity - initialDeployment + firstReturn,
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
            availableToWithdraw:   initialLiquidity - initialDeployment + firstReturn,
            totalDeployedAssets:   initialDeployment - firstReturn,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment - firstReturn);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - initialDeployment + firstReturn);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);

        /**********************************************************************************************************************************/
        /*** Second partial return accumulates on top of the first                                                                      ***/
        /**********************************************************************************************************************************/

        uint256 secondReturn = 75_000e6;

        returnAssets(tradingUnderlyingStrategy, trader, trader, secondReturn);

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
            availableToWithdraw:   initialLiquidity - initialDeployment + firstReturn + secondReturn,
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
            availableToWithdraw:   initialLiquidity - initialDeployment + firstReturn + secondReturn,
            totalDeployedAssets:   initialDeployment - firstReturn - secondReturn,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment - firstReturn - secondReturn);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - initialDeployment + firstReturn + secondReturn);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
    }

    function test_returnAssets_success_multipleTradingAddresses() external {

        /**********************************************************************************************************************************/
        /*** Deploy assets from another trading address                                                                                 ***/
        /**********************************************************************************************************************************/

        address trader2          = makeAddr("trader2");
        uint256 secondDeployment = 250_000e6;

        setTradingAddress({
            strategy_:         tradingUnderlyingStrategy,
            tradingAddress_:   trader2,
            canDeployAssets_:  true,
            canReturnAssets_:  true,
            canRealizeYield_:  true,
            deploymentCap_:    type(uint256).max
        });
        deployAssets(tradingUnderlyingStrategy, trader2, secondDeployment);

        /**********************************************************************************************************************************/
        /*** First trading address returns its share, second trading address's position is untouched                                    ***/
        /**********************************************************************************************************************************/

        uint256 firstReturn = 100_000e6;

        returnAssets(tradingUnderlyingStrategy, trader, trader, firstReturn);

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
            availableToWithdraw:   initialLiquidity - initialDeployment - secondDeployment + firstReturn,
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
            availableToWithdraw:   initialLiquidity - initialDeployment - secondDeployment + firstReturn,
            totalDeployedAssets:   initialDeployment + secondDeployment - firstReturn,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader),  initialDeployment - firstReturn);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader2), secondDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialLiquidity - initialDeployment - secondDeployment + firstReturn);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(trader2),                   secondDeployment);

        /**********************************************************************************************************************************/
        /*** Second trading address returns its share independently, accounted for separately from the first                            ***/
        /**********************************************************************************************************************************/

        uint256 secondReturn = 200_000e6;

        returnAssets(tradingUnderlyingStrategy, trader2, trader2, secondReturn);

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
            availableToWithdraw:   initialLiquidity - initialDeployment - secondDeployment + firstReturn + secondReturn,
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
            availableToWithdraw:   initialLiquidity - initialDeployment - secondDeployment + firstReturn + secondReturn,
            totalDeployedAssets:   initialDeployment + secondDeployment - firstReturn - secondReturn,
            unrealizedLosses:      0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader),  initialDeployment - firstReturn);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader2), secondDeployment - secondReturn);

        assertEq(
            fundsAsset.balanceOf(tradingUnderlyingStrategy),
            initialLiquidity - initialDeployment - secondDeployment + firstReturn + secondReturn
        );

        assertEq(fundsAsset.balanceOf(trader),  initialDeployment);
        assertEq(fundsAsset.balanceOf(trader2), secondDeployment);
    }

}
