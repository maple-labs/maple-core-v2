// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { ITradingStrategy } from "../../../contracts/interfaces/Interfaces.sol";

import { TradingStrategyTestBase } from "./TradingStrategyTestBase.sol";

contract TradingStrategyRealizeYieldTestBase is TradingStrategyTestBase {

    uint256 delegateFee       = 1_000e6;
    uint256 initialDeployment = 400_000e6;
    uint256 initialAssets     = 1_000_000e6;
    uint256 initialShares     = 1_000_000e6;
    uint256 netYield          = 47_500e6;
    uint256 protocolFee       = 1_500e6;
    uint256 yieldAssets       = 50_000e6;

    uint32 delegateFeeRate = 0.02e6;  // 2%
    uint32 protocolFeeRate = 0.03e6;  // 3%
    uint32 yieldCooldown   = 1 hours;
    uint32 yieldDuration   = 31 days;

    function setUp() public virtual override {
        super.setUp();

        // Fund pool and strategy, then deploy assets so a realized position co-exists with the yield being realized.
        deposit(lp, initialAssets);
        fundStrategyManager(address(poolManager), tradingStrategyManager, initialAssets);
        deployAssets(tradingUnderlyingStrategy, trader, initialDeployment);

        // Set strategy fees.
        setStrategyDelegateFeeRate(tradingUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(tradingUnderlyingStrategy, protocolFeeRate);

        // Initial assertions.
        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            yieldLastRealized:    0,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
    }

}

contract TradingStrategyRealizeYieldFailureTests is TradingStrategyRealizeYieldTestBase {

    function test_realizeYield_revert_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(trader);
        vm.expectRevert("MTS:PAUSED");
        ITradingStrategy(tradingUnderlyingStrategy).realizeYield(yieldAssets, yieldDuration, "");
    }

    function test_realizeYield_revert_contractPaused() external {
        vm.prank(governor);
        globals.setContractPause(tradingUnderlyingStrategy, true);

        vm.prank(trader);
        vm.expectRevert("MTS:PAUSED");
        ITradingStrategy(tradingUnderlyingStrategy).realizeYield(yieldAssets, yieldDuration, "");
    }

    function test_realizeYield_revert_notManagedWallet() external {
        address notTrader = makeAddr("notTrader");

        vm.prank(notTrader);
        vm.expectRevert("MTS:NOT_MAPLE_MANAGED_WALLET");
        ITradingStrategy(tradingUnderlyingStrategy).realizeYield(yieldAssets, yieldDuration, "");
    }

    function test_realizeYield_revert_notAllowed() external {
        setPermissions({
            strategy_:        tradingUnderlyingStrategy,
            account_:         trader,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: false
        });

        vm.prank(trader);
        vm.expectRevert("MTS:RY:NOT_ALLOWED");
        ITradingStrategy(tradingUnderlyingStrategy).realizeYield(yieldAssets, yieldDuration, "");
    }

    function test_realizeYield_revert_yieldCap() external {
        vm.prank(strategyDelegate);
        ITradingStrategy(tradingUnderlyingStrategy).setYieldCap(yieldAssets);

        vm.prank(trader);
        vm.expectRevert("MTS:RY:CAP_EXCEEDED");
        ITradingStrategy(tradingUnderlyingStrategy).realizeYield(yieldAssets + 1, yieldDuration, "");
    }

    function test_realizeYield_revert_yieldCooldown() external {
        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, yieldDuration);

        vm.warp(startingTime + yieldCooldown - 1 seconds);
        vm.prank(trader);
        vm.expectRevert("MTS:RY:COOLDOWN");
        ITradingStrategy(tradingUnderlyingStrategy).realizeYield(yieldAssets, yieldDuration, "");
    }

    function test_realizeYield_revert_sharedYieldCooldown() external {
        address trader2 = makeAddr("trader2");

        setTradingAddress({
            strategy_:        tradingUnderlyingStrategy,
            tradingAddress_:  trader2,
            canDeployAssets_: false,
            canReturnAssets_: false,
            canRealizeYield_: true,
            deploymentCap_:   0
        });

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, yieldDuration);

        vm.warp(startingTime + yieldCooldown - 1 seconds);
        vm.prank(trader2);
        vm.expectRevert("MTS:RY:COOLDOWN");
        ITradingStrategy(tradingUnderlyingStrategy).realizeYield(yieldAssets, yieldDuration, "");
    }

    function test_realizeYield_revert_insufficientApproval() external {
        erc20_approve(address(fundsAsset), trader, tradingUnderlyingStrategy, yieldAssets - 1);

        vm.prank(trader);
        vm.expectRevert("MTS:RY:TRANSFER_FROM_FAILED");
        ITradingStrategy(tradingUnderlyingStrategy).realizeYield(yieldAssets, yieldDuration, "");
    }

    function test_realizeYield_revert_insufficientBalance() external {
        erc20_approve(address(fundsAsset), trader, tradingUnderlyingStrategy, initialDeployment + 1);

        vm.prank(trader);
        vm.expectRevert("MTS:RY:TRANSFER_FROM_FAILED");
        ITradingStrategy(tradingUnderlyingStrategy).realizeYield(initialDeployment + 1, yieldDuration, "");
    }

}

contract TradingStrategyRealizeYieldSuccessTests is TradingStrategyRealizeYieldTestBase {

    uint256 poolAssets1;
    uint256 poolShares1;
    uint256 strategyShares1;

    uint256 poolAssets2;
    uint256 poolShares2;
    uint256 strategyShares2;

    function test_realizeYield_success_yieldCap() external {

        /**********************************************************************************************************************************/
        /*** Set the yield cap to match the amount that will be realized                                                                ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        ITradingStrategy(tradingUnderlyingStrategy).setYieldCap(yieldAssets);

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).yieldCap(), yieldAssets);

        /**********************************************************************************************************************************/
        /*** Realize yield exactly at the cap                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);
    }

    function test_realizeYield_success_yieldCooldown() external {

        /**********************************************************************************************************************************/
        /*** Realize yield instantly, starting the cooldown                                                                             ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, 0);

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).yieldLastRealized(), startingTime);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy).yieldCooldown(),     yieldCooldown);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp past the cooldown and realize yield again                                                                             ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldCooldown);

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).yieldCooldown(), 0);

        realizeYield(tradingUnderlyingStrategy, trader, 0, 0);

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).yieldLastRealized(), startingTime + yieldCooldown);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy).yieldCooldown(),     yieldCooldown);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           startingTime + yieldCooldown,
            yieldDeadline:        startingTime + yieldCooldown,
            yieldLastRealized:    startingTime + yieldCooldown,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);
    }

    function test_realizeYield_success_yieldAccrual() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield                                                                                                             ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp forwards in time                                                                                                      ***/
        /**********************************************************************************************************************************/

        uint32  elapsedDuration = yieldDuration / 3;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the exact deadline                                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp past the deadline                                                                                                     ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration + 5 days);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);
    }

    function test_realizeYield_success_yieldAccrual_withBootstrapMint() external {

        /**********************************************************************************************************************************/
        /*** Fully unwind the existing (non-bootstrap) strategy so the pool starts clean                                                ***/
        /**********************************************************************************************************************************/

        vm.prank(trader);
        fundsAsset.transfer(address(0xdead), initialDeployment);

        returnAssets(tradingUnderlyingStrategy, trader, trader, initialDeployment);
        requestRedeemFromStrategyManager(address(poolManager), tradingStrategyManager, initialShares);
        processRedemptionFromStrategyManager(address(poolManager), tradingStrategyManager, initialShares);

        vm.prank(governor);
        poolManager.removeStrategyManager(tradingStrategyManager);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: initialAssets
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

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            yieldLastRealized:    0,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), 0);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(trader),                    0);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          0);
        assertEq(fundsAsset.balanceOf(treasury),                  0);

        /**********************************************************************************************************************************/
        /*** Deploy a bootstrap-minted strategy in its place and attach the existing pool to it                                         ***/
        /**********************************************************************************************************************************/

        strategyDelegate = makeAddr("bootstrapDelegate");

        uint256 bootstrapAssets = 10e6;
        uint256 bootstrapShares = 10e6;

        ( tradingStrategyManager, tradingUnderlyingStrategy ) = _deployAllocationStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: delegateFeeRate,
            strategyProtocolFeeRate_: protocolFeeRate,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           bootstrapAssets
        });

        setTradingAddress({
            strategy_:        tradingUnderlyingStrategy,
            tradingAddress_:  trader,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   type(uint256).max
        });

        addStrategyManagerToPool(address(poolManager), tradingStrategyManager);
        fundStrategyManager(address(poolManager), tradingStrategyManager, initialAssets);
        deployAssets(tradingUnderlyingStrategy, trader, initialDeployment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           bootstrapShares + initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapAssets + initialAssets,
            availableToWithdraw:   bootstrapAssets + initialAssets - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(0),
            assets:           bootstrapAssets,
            shares:           bootstrapShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: bootstrapAssets + initialAssets,
            availableToWithdraw:   bootstrapAssets + initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            yieldLastRealized:    0,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), bootstrapAssets + initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          0);
        assertEq(fundsAsset.balanceOf(treasury),                  0);

        /**********************************************************************************************************************************/
        /*** Schedule yield                                                                                                             ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           bootstrapShares + initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapAssets + initialAssets,
            availableToWithdraw:   bootstrapAssets + initialAssets - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(0),
            assets:           bootstrapAssets,
            shares:           bootstrapShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: bootstrapAssets + initialAssets,
            availableToWithdraw:   bootstrapAssets + initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), bootstrapAssets + initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp forwards in time                                                                                                      ***/
        /**********************************************************************************************************************************/

        uint32  elapsedDuration = yieldDuration / 3;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;

        vm.warp(startingTime + elapsedDuration);

        uint256 poolAssets = initialShares * (bootstrapAssets + initialAssets + realizedYield) / (bootstrapShares + initialShares);
        uint256 deadAssets = bootstrapShares * (bootstrapAssets + initialAssets + realizedYield) / (bootstrapShares + initialShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           bootstrapShares + initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapAssets + initialAssets + realizedYield,
            availableToWithdraw:   bootstrapAssets + initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           poolAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(0),
            assets:           deadAssets,
            shares:           bootstrapShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: bootstrapAssets + initialAssets + realizedYield,
            availableToWithdraw:   bootstrapAssets + initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), bootstrapAssets + initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the exact deadline                                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        poolAssets = initialShares * (bootstrapAssets + initialAssets + netYield) / (bootstrapShares + initialShares);
        deadAssets = bootstrapShares * (bootstrapAssets + initialAssets + netYield) / (bootstrapShares + initialShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           bootstrapShares + initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapAssets + initialAssets + netYield,
            availableToWithdraw:   bootstrapAssets + initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           poolAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(0),
            assets:           deadAssets,
            shares:           bootstrapShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: bootstrapAssets + initialAssets + netYield,
            availableToWithdraw:   bootstrapAssets + initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), bootstrapAssets + initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp past the deadline                                                                                                     ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration + 5 days);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           bootstrapShares + initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapAssets + initialAssets + netYield,
            availableToWithdraw:   bootstrapAssets + initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           poolAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(0),
            assets:           deadAssets,
            shares:           bootstrapShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: bootstrapAssets + initialAssets + netYield,
            availableToWithdraw:   bootstrapAssets + initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), bootstrapAssets + initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);
    }

    function test_realizeYield_success_instantYield() external {

        /**********************************************************************************************************************************/
        /*** Realize yield instantly                                                                                                    ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, 0);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);
    }

    function test_realizeYield_success_scheduleExtended() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards in time                                                                                   ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 10 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;
        uint256 unrealizedYield = netYield - realizedYield;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Extend the schedule with a longer duration                                                                                 ***/
        /**********************************************************************************************************************************/

        uint32 extendedDuration = 40 days;

        realizeYield(tradingUnderlyingStrategy, trader, 0, extendedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: unrealizedYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + elapsedDuration + extendedDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the extended deadline                                                                                              ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + elapsedDuration + extendedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: unrealizedYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + elapsedDuration + extendedDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        unrealizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);
    }

    function test_realizeYield_success_scheduleShortened() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 3 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;
        uint256 unrealizedYield = netYield - realizedYield;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Shorten the schedule to a duration shorter than the time remaining                                                         ***/
        /**********************************************************************************************************************************/

        uint32 shortenedDuration = 10 days;

        realizeYield(tradingUnderlyingStrategy, trader, 0, shortenedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: unrealizedYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + elapsedDuration + shortenedDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the shortened deadline                                                                                             ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + elapsedDuration + shortenedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: unrealizedYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + elapsedDuration + shortenedDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        unrealizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);
    }

    function test_realizeYield_success_scheduledUnchanged() external {

        /**********************************************************************************************************************************/
        /*** Realize yield normally and warp forwards                                                                                   ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 7 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;
        uint256 unrealizedYield = netYield - realizedYield;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Realize yield again with a zero amount while the duration stays the same                                                   ***/
        /**********************************************************************************************************************************/

        uint32 remainingDuration = yieldDuration - elapsedDuration;

        realizeYield(tradingUnderlyingStrategy, trader, 0, remainingDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: unrealizedYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the original deadline                                                                                              ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: unrealizedYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        unrealizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);
    }

    function test_realizeYield_success_flushYield() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 23 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;
        uint256 unrealizedYield = netYield - realizedYield;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Set the duration to zero and flush all remaining yield                                                                     ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, 0, 0);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: unrealizedYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + elapsedDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        unrealizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);
    }

    function test_realizeYield_success_topUpYield() external {

        /**********************************************************************************************************************************/
        /*** Schedule an initial batch of yield and warp forwards                                                                       ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 25 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;
        uint256 unrealizedYield = netYield - realizedYield;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Realize a second batch of yield with a new duration                                                                        ***/
        /**********************************************************************************************************************************/

        uint256 extraYieldAssets = 30_000e6;
        uint32  extraDuration    = 35 days;

        uint256 extraDelegateFee = 600e6;
        uint256 extraProtocolFee = 900e6;
        uint256 extraNetYield    = 28_500e6;

        uint256 combinedScheduledYield = unrealizedYield + extraNetYield;

        realizeYield(tradingUnderlyingStrategy, trader, extraYieldAssets, extraDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: combinedScheduledYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + elapsedDuration + extraDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield + extraNetYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee + extraDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee + extraProtocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the new deadline                                                                                                   ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + elapsedDuration + extraDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield + extraNetYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield + extraNetYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield + extraNetYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield + extraNetYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield + extraNetYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield + extraNetYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: combinedScheduledYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + elapsedDuration + extraDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        combinedScheduledYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield + extraNetYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee + extraDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee + extraProtocolFee);
    }

    function test_realizeYield_success_yieldIncreased() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 12 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;
        uint256 unrealizedYield = netYield - realizedYield;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Increase the scheduled yield while keeping the same deadline                                                               ***/
        /**********************************************************************************************************************************/

        uint32  remainingDuration = yieldDuration - elapsedDuration;
        uint256 extraYieldAssets  = 20_000e6;
        uint256 extraDelegateFee  = 400e6;
        uint256 extraProtocolFee  = 600e6;
        uint256 extraNetYield     = 19_000e6;

        uint256 combinedScheduledYield = unrealizedYield + extraNetYield;

        realizeYield(tradingUnderlyingStrategy, trader, extraYieldAssets, remainingDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: combinedScheduledYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield + extraNetYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee + extraDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee + extraProtocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the unchanged deadline and assert the combined yield fully vests                                                   ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield + extraNetYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield + extraNetYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield + extraNetYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield + extraNetYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield + extraNetYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield + extraNetYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: combinedScheduledYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        combinedScheduledYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield + extraNetYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee + extraDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee + extraProtocolFee);
    }

    function test_realizeYield_success_yieldReduced() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 17 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;
        uint256 unrealizedYield = netYield - realizedYield;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Cancel part of the unrealized yield                                                                                        ***/
        /**********************************************************************************************************************************/

        uint256 cancelledAssets = 10_000e6;
        uint256 remainingYield  = unrealizedYield - cancelledAssets;

        vm.prank(strategyDelegate);
        ITradingStrategy(tradingUnderlyingStrategy).cancelYield(cancelledAssets, trader);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: remainingYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield - cancelledAssets);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment + cancelledAssets);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the original deadline                                                                                              ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield + remainingYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield + remainingYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield + remainingYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield + remainingYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield + remainingYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield + remainingYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: remainingYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        remainingYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield - cancelledAssets);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment + cancelledAssets);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);
    }

    function test_realizeYield_success_yieldCancelled() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 22 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;
        uint256 unrealizedYield = netYield - realizedYield;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Cancel the entire remaining amount of unrealized yield                                                                     ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        ITradingStrategy(tradingUnderlyingStrategy).cancelYield(type(uint256).max, trader);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + realizedYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment + unrealizedYield);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the original deadline                                                                                              ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + realizedYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment + unrealizedYield);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);
    }

    function test_realizeYield_success_lossRealized() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 17 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Recognize a loss on the trader's deployed assets                                                                           ***/
        /**********************************************************************************************************************************/

        uint256 lostAssets = 50_000e6;

        recognizeLoss(tradingUnderlyingStrategy, trader, lostAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets - lostAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets - lostAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets - lostAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets - lostAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment - lostAssets,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment - lostAssets);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the deadline                                                                                                       ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets - lostAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets - lostAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets - lostAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets - lostAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment - lostAssets,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment - lostAssets);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);
    }

    function test_realizeYield_success_impairedBeforeSchedule() external {

        /**********************************************************************************************************************************/
        /*** Impair part of the strategy before any yield has been scheduled                                                            ***/
        /**********************************************************************************************************************************/

        uint256 impairedAssets = 100_000e6;

        impairTradingStrategy(tradingUnderlyingStrategy, impairedAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   impairedAssets,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      impairedAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairedAssets
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairedAssets
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            yieldLastRealized:    0,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          0);
        assertEq(fundsAsset.balanceOf(treasury),                  0);

        /**********************************************************************************************************************************/
        /*** Schedule yield on top of the pre-existing impairment                                                                       ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   impairedAssets,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      impairedAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairedAssets
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairedAssets
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the deadline and assert the yield fully vests despite the impairment                                               ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   impairedAssets,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      impairedAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairedAssets
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairedAssets
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);
    }

    function test_realizeYield_success_impairedDuringSchedule() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 11 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Impair part of the strategy                                                                                                ***/
        /**********************************************************************************************************************************/

        uint256 impairedAssets = 150_000e6;

        impairTradingStrategy(tradingUnderlyingStrategy, impairedAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   impairedAssets,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      impairedAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairedAssets
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairedAssets
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the deadline and assert the yield still fully vests                                                                ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   impairedAssets,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      impairedAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairedAssets
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairedAssets
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);
    }

    function test_realizeYield_success_yieldRedeployed() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, yieldDuration);

        uint32  elapsedDuration   = 15 days;
        uint256 realizedYield     = netYield * elapsedDuration / yieldDuration;
        uint256 unrealizedYield   = netYield - realizedYield;
        uint256 strategyLiquidity = initialAssets - initialDeployment + realizedYield;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   strategyLiquidity,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   strategyLiquidity,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Deploy all assets, including the realized yield                                                                            ***/
        /**********************************************************************************************************************************/

        deployAssets(tradingUnderlyingStrategy, trader, strategyLiquidity);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   0,
            totalDeployedAssets:   initialDeployment + strategyLiquidity,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment + strategyLiquidity);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), unrealizedYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment + strategyLiquidity);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the deadline and assert the full net yield still vests correctly                                                   ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   netYield - realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   netYield - realizedYield,
            totalDeployedAssets:   initialDeployment + strategyLiquidity,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment + strategyLiquidity);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), unrealizedYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment + strategyLiquidity);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);
    }

    function test_realizeYield_success_assetsReturned() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 11 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Return part of the originally deployed principal                                                                           ***/
        /**********************************************************************************************************************************/

        uint256 returnedAssets = 100_000e6;

        returnAssets(tradingUnderlyingStrategy, trader, trader, returnedAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield + returnedAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield + returnedAssets,
            totalDeployedAssets:   initialDeployment - returnedAssets,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment - returnedAssets);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield + returnedAssets);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the deadline                                                                                                       ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield + returnedAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield + returnedAssets,
            totalDeployedAssets:   initialDeployment - returnedAssets,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment - returnedAssets);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield + returnedAssets);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);
    }

    function test_realizeYield_success_strategyFunded() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 16 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Fund the strategy                                                                                                          ***/
        /**********************************************************************************************************************************/

        uint256 fundAssets = 100_000e6;

        deposit(lp, fundAssets);
        fundStrategyManager(address(poolManager), tradingStrategyManager, fundAssets);

        uint256 mintedShares = fundAssets * initialShares / (initialAssets + realizedYield);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield + fundAssets,
            totalSupply:        initialShares + mintedShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares + mintedShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield + fundAssets,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield + fundAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield + fundAssets,
            shares:           initialShares + mintedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield + fundAssets,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield + fundAssets,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield + fundAssets);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the deadline                                                                                                       ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield + fundAssets,
            totalSupply:        initialShares + mintedShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares + mintedShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield + fundAssets,
            availableToWithdraw:   initialAssets - initialDeployment + netYield + fundAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield + fundAssets,
            shares:           initialShares + mintedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield + fundAssets,
            availableToWithdraw:   initialAssets - initialDeployment + netYield + fundAssets,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield + fundAssets);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);
    }

    function test_realizeYield_success_yieldWithdrawn() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 20 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Redeem as many shares as possible                                                                                          ***/
        /**********************************************************************************************************************************/

        uint256 strategyLiquidity  = initialAssets - initialDeployment + realizedYield;
        uint256 redeemableShares   = strategyLiquidity * initialShares / (initialAssets + realizedYield);
        uint256 withdrawableAssets = redeemableShares * (initialAssets + realizedYield) / initialShares;

        assertApproxEqAbs(strategyLiquidity, withdrawableAssets, 1);

        requestRedeemFromStrategyManager(address(poolManager), tradingStrategyManager, redeemableShares);
        processRedemptionFromStrategyManager(address(poolManager), tradingStrategyManager, redeemableShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: withdrawableAssets
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares - redeemableShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield - withdrawableAssets,
            availableToWithdraw:   strategyLiquidity - withdrawableAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield - withdrawableAssets,
            shares:           initialShares - redeemableShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield - withdrawableAssets,
            availableToWithdraw:   strategyLiquidity - withdrawableAssets,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield - withdrawableAssets);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the deadline                                                                                                       ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: withdrawableAssets
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares - redeemableShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield - withdrawableAssets,
            availableToWithdraw:   initialAssets - initialDeployment + netYield - withdrawableAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield - withdrawableAssets,
            shares:           initialShares - redeemableShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield - withdrawableAssets,
            availableToWithdraw:   initialAssets - initialDeployment + netYield - withdrawableAssets,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield - withdrawableAssets);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);
    }

    function test_realizeYield_success_feesUpdated() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards                                                                                           ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 9 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;
        uint256 unrealizedYield = netYield - realizedYield;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Update the fee rates mid vesting, which has no effect on the already-scheduled yield                                       ***/
        /**********************************************************************************************************************************/

        uint32 newDelegateFeeRate = 0.05e6;  // 5%
        uint32 newProtocolFeeRate = 0.07e6;  // 7%

        setStrategyDelegateFeeRate(tradingUnderlyingStrategy, newDelegateFeeRate);
        setStrategyProtocolFeeRate(tradingUnderlyingStrategy, newProtocolFeeRate);

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).strategyDelegateFeeRate(), newDelegateFeeRate);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy).strategyProtocolFeeRate(), newProtocolFeeRate);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + realizedYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + realizedYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + realizedYield,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Flush the remaining schedule before its natural deadline, proving the flushed amount is unaffected by the new fee rates    ***/
        /**********************************************************************************************************************************/

        realizeYield(tradingUnderlyingStrategy, trader, 0, 0);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: unrealizedYield,
            yieldStart:           startingTime + elapsedDuration,
            yieldDeadline:        startingTime + elapsedDuration,
            yieldLastRealized:    startingTime + elapsedDuration,
            realizedYield:        unrealizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Realize brand new yield, proving the new fee rates apply going forward                                                     ***/
        /**********************************************************************************************************************************/

        uint256 extraYieldAssets = 40_000e6;
        uint256 extraDelegateFee = 2_000e6;
        uint256 extraProtocolFee = 2_800e6;
        uint256 extraNetYield    = 35_200e6;

        vm.warp(startingTime + elapsedDuration + yieldCooldown);

        realizeYield(tradingUnderlyingStrategy, trader, extraYieldAssets, 0);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets + netYield + extraNetYield,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + netYield + extraNetYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield + extraNetYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets + netYield + extraNetYield,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: initialAssets + netYield + extraNetYield,
            availableToWithdraw:   initialAssets - initialDeployment + netYield + extraNetYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: extraNetYield,
            yieldStart:           startingTime + elapsedDuration + yieldCooldown,
            yieldDeadline:        startingTime + elapsedDuration + yieldCooldown,
            yieldLastRealized:    startingTime + elapsedDuration + yieldCooldown,
            realizedYield:        extraNetYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), initialAssets - initialDeployment + netYield + extraNetYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee + extraDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee + extraProtocolFee);
    }

    function test_realizeYield_success_poolsVestTogether() external {

        /**********************************************************************************************************************************/
        /*** Fund a second pool into the same strategy manager, so both pools share the same underlying trading strategy                ***/
        /**********************************************************************************************************************************/

        address pool1        = address(pool);
        address poolManager1 = address(poolManager);

        ( address pool2, address poolManager2 ) = _createPoolSharingStrategy("secondPoolDelegate", tradingStrategyManager);

        uint256 initialAssets1 = initialAssets;
        uint256 initialShares1 = initialShares;
        uint256 initialAssets2 = 500_000e6;
        uint256 initialShares2 = 500_000e6;

        uint256 totalAssets = initialAssets1 + initialAssets2;
        uint256 totalShares = initialShares1 + initialShares2;

        deposit(pool2, makeAddr("lp2"), initialAssets2);
        fundStrategyManager(poolManager2, tradingStrategyManager, initialAssets2);
        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, yieldDuration);

        assertPoolState({
            pool:               pool1,
            totalAssets:        initialAssets1,
            totalSupply:        initialShares1,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               pool2,
            totalAssets:        initialAssets2,
            totalSupply:        initialShares2,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      poolManager1,
            assets:           initialAssets1,
            shares:           initialShares1,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      poolManager2,
            assets:           initialAssets2,
            shares:           initialShares2,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), totalAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the deadline and assert the vested yield splits between both pools in proportion to their shares                   ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        uint256 finalAum         = totalAssets + netYield;
        uint256 firstPoolAssets  = initialShares1 * finalAum / totalShares;
        uint256 secondPoolAssets = initialShares2 * finalAum / totalShares;

        assertPoolState({
            pool:               pool1,
            totalAssets:        firstPoolAssets,
            totalSupply:        initialShares1,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               pool2,
            totalAssets:        secondPoolAssets,
            totalSupply:        initialShares2,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: finalAum,
            availableToWithdraw:   finalAum - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      poolManager1,
            assets:           firstPoolAssets,
            shares:           initialShares1,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      poolManager2,
            assets:           secondPoolAssets,
            shares:           initialShares2,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: finalAum,
            availableToWithdraw:   finalAum - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), totalAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);
    }

    function test_realizeYield_success_poolJoinsMidVesting() external {

        /**********************************************************************************************************************************/
        /*** Schedule yield and warp forwards, before the 2nd pool exists                                                               ***/
        /**********************************************************************************************************************************/

        address pool1        = address(pool);
        address poolManager1 = address(poolManager);

        poolAssets1     = initialAssets;
        poolShares1     = initialShares;
        strategyShares1 = initialShares;

        realizeYield(tradingUnderlyingStrategy, trader, yieldAssets, yieldDuration);

        uint32  elapsedDuration = 13 days;
        uint256 realizedYield   = netYield * elapsedDuration / yieldDuration;

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               pool1,
            totalAssets:        poolAssets1 + realizedYield,
            totalSupply:        poolShares1,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           strategyShares1,
            totalPendingShares:    0,
            assetsUnderManagement: poolAssets1 + realizedYield,
            availableToWithdraw:   poolAssets1 - initialDeployment + realizedYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      poolManager1,
            assets:           poolAssets1 + realizedYield,
            shares:           strategyShares1,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: poolAssets1 + realizedYield,
            availableToWithdraw:   poolAssets1 - initialDeployment + realizedYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), poolAssets1 - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Fund a 2nd pool into the same strategy manager mid vesting                                                                 ***/
        /**********************************************************************************************************************************/

        ( address pool2, address poolManager2 ) = _createPoolSharingStrategy("secondPoolDelegate", tradingStrategyManager);

        poolAssets2     = 500_000e6;
        poolShares2     = poolAssets2;
        strategyShares2 = poolAssets2 * strategyShares1 / (poolAssets1 + realizedYield);

        deposit(pool2, makeAddr("lp2"), poolAssets2);
        fundStrategyManager(poolManager2, tradingStrategyManager, poolAssets2);

        assertPoolState({
            pool:               pool1,
            totalAssets:        poolAssets1 + realizedYield,
            totalSupply:        poolShares1,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               pool2,
            totalAssets:        poolAssets2 - 1,  // Rounding error
            totalSupply:        poolShares2,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           strategyShares1 + strategyShares2,
            totalPendingShares:    0,
            assetsUnderManagement: poolAssets1 + realizedYield + poolAssets2,
            availableToWithdraw:   poolAssets1 - initialDeployment + realizedYield + poolAssets2,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      poolManager1,
            assets:           poolAssets1 + realizedYield,
            shares:           strategyShares1,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      poolManager2,
            assets:           poolAssets2 - 1,  // Rounding error
            shares:           strategyShares2,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: poolAssets1 + realizedYield + poolAssets2,
            availableToWithdraw:   poolAssets1 - initialDeployment + realizedYield + poolAssets2,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), poolAssets1 - initialDeployment + netYield + poolAssets2);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);

        /**********************************************************************************************************************************/
        /*** Warp to the deadline and assert the remaining yield splits by shares held from the moment the 2nd pool joined              ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        uint256 aum = poolAssets1 + netYield + poolAssets2;

        poolAssets1 = strategyShares1 * aum / (strategyShares1 + strategyShares2);
        poolAssets2 = strategyShares2 * aum / (strategyShares1 + strategyShares2);

        assertPoolState({
            pool:               pool1,
            totalAssets:        poolAssets1,
            totalSupply:        poolShares1,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               pool2,
            totalAssets:        poolAssets2,
            totalSupply:        poolShares2,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       tradingStrategyManager,
            totalShares:           strategyShares1 + strategyShares2,
            totalPendingShares:    0,
            assetsUnderManagement: aum,
            availableToWithdraw:   aum - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      poolManager1,
            assets:           poolAssets1,
            shares:           strategyShares1,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  tradingStrategyManager,
            poolManager:      poolManager2,
            assets:           poolAssets2,
            shares:           strategyShares2,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            tradingStrategy:       tradingUnderlyingStrategy,
            assetsUnderManagement: aum,
            availableToWithdraw:   aum - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(ITradingStrategy(tradingUnderlyingStrategy).deployedAssetsOf(trader), initialDeployment);

        assertEq(fundsAsset.balanceOf(tradingUnderlyingStrategy), aum - initialDeployment);
        assertEq(fundsAsset.balanceOf(trader),                    initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),          delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                  protocolFee);
    }

}
