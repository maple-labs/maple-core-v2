// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAaveV3Strategy,
    IERC20,
    IStrategyManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { AaveV3StrategyTestBase } from "./AaveV3StrategyTestBase.sol";

contract AaveV3StrategyRemoveImpairmentFailureTests is AaveV3StrategyTestBase {

    uint256 impairment = 100_000e6;

    function testFork_removeImpairment_failWhenProtocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:PAUSED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).removeImpairment(impairment);
    }

    function testFork_removeImpairment_failWhenStrategyPaused() external {
        vm.prank(governor);
        globals.setContractPause(aaveV3UnderlyingStrategy, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:PAUSED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).removeImpairment(impairment);
    }

    function testFork_removeImpairment_failWhenNotProtocolAdmin() external {
        vm.prank(governor);
        vm.expectRevert("MAV3S:NOT_AUTHORIZED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).removeImpairment(impairment);
    }

    function testFork_removeImpairment_failWhenLossRecognized() external {
        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:LOSS_RECOGNIZED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).removeImpairment(impairment);
    }

    function testFork_removeImpairment_failWithZeroAssets() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:RI:ZERO");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).removeImpairment(0);
    }

    function testFork_removeImpairment_failWhenExceedingImpairment() external {
        impairStrategy(aaveV3UnderlyingStrategy, impairment);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:RI:EXCEEDS_IMPAIRMENT");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).removeImpairment(impairment + 1);
    }

}

contract SparkLendStrategyRemoveImpairmentFailureTests is AaveV3StrategyRemoveImpairmentFailureTests {

    function setUp() public override {
        aaveToken                   = SPARK_USDC;
        useVirtualUnderlyingBalance = false;

        super.setUp();
    }

}

contract AaveV3StrategyRemoveImpairmentTests is AaveV3StrategyTestBase {

    uint256 bootstrapMint = 100_000e6;

    uint256 expectedBootstrapAssets;
    uint256 expectedBootstrapShares;
    uint256 expectedRoundingError = 1;
    uint256 expectedSecondPoolAssets;
    uint256 expectedSecondPoolShares;

    uint256 fundAmount        = 500_000e6;
    uint256 impairment        = 250_000e6;
    uint256 impairmentRemoval = 100_000e6;
    uint256 poolLiquidity     = 1_000_000e6;
    uint256 strategyAssets;
    uint256 secondFundAmount  = 450_000e6;
    uint256 strategyShares;

    function setUp() public virtual override {
        super.setUp();

        deposit(lp, poolLiquidity);
        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        expectedBootstrapAssets  = bootstrapMint - expectedRoundingError;
        expectedBootstrapShares  = expectedBootstrapAssets;
        expectedSecondPoolAssets = secondFundAmount;
        expectedSecondPoolShares = secondFundAmount;

        strategyAssets = fundAmount - expectedRoundingError;  // 500k - 1 on Aave, 500k on SparkLend.
        strategyShares = strategyAssets;
    }

    function testFork_removeImpairment_acrossAllAdmins() external {
        uint256 operationalRemoval = impairment - impairmentRemoval;  // 150k.

        impairStrategy(aaveV3UnderlyingStrategy, impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), impairment);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     strategyAssets,
            aTokenBalance:           strategyAssets,
            lastRecordedTotalAssets: strategyAssets,
            unrealizedLosses:        impairment
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: strategyAssets,
            availableToWithdraw:   strategyAssets,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssets,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        vm.prank(operationalAdmin);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).removeImpairment(impairmentRemoval);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   operationalRemoval,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), operationalRemoval);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     strategyAssets,
            aTokenBalance:           strategyAssets,
            lastRecordedTotalAssets: strategyAssets,
            unrealizedLosses:        operationalRemoval
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: strategyAssets,
            availableToWithdraw:   strategyAssets,
            unrealizedLosses:      operationalRemoval
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssets,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: operationalRemoval
        });

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).removeImpairment(operationalRemoval);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), 0);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     strategyAssets,
            aTokenBalance:           strategyAssets,
            lastRecordedTotalAssets: strategyAssets,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: strategyAssets,
            availableToWithdraw:   strategyAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssets,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_removeImpairment_restoresStrategyManagerExitAssets() external {
        uint256 expectedInitialExitAssets  = strategyAssets;
        uint256 expectedImpairedExitAssets = strategyAssets - impairment;  // 250k - 1 on Aave, 250k on SparkLend.

        uint256 initialExitAssets = IStrategyManager(aaveV3StrategyManager).convertToExitAssets(strategyShares);

        assertEq(initialExitAssets, expectedInitialExitAssets);

        impairStrategy(aaveV3UnderlyingStrategy, impairment);

        uint256 impairedExitAssets = IStrategyManager(aaveV3StrategyManager).convertToExitAssets(strategyShares);

        assertEq(impairedExitAssets, expectedImpairedExitAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), impairment);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     strategyAssets,
            aTokenBalance:           strategyAssets,
            lastRecordedTotalAssets: strategyAssets,
            unrealizedLosses:        impairment
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: strategyAssets,
            availableToWithdraw:   strategyAssets,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssets,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        removeStrategyImpairment(aaveV3UnderlyingStrategy, impairment);

        uint256 restoredExitAssets = IStrategyManager(aaveV3StrategyManager).convertToExitAssets(strategyShares);

        assertEq(restoredExitAssets, initialExitAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), 0);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     strategyAssets,
            aTokenBalance:           strategyAssets,
            lastRecordedTotalAssets: strategyAssets,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: strategyAssets,
            availableToWithdraw:   strategyAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssets,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_removeImpairment_restoresPendingRedemptionExitAssets() external {
        uint256 expectedInitialExitAssets = 100_000e6;
        uint256 redemptionShares          = 100_000e6;

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, redemptionShares);

        uint256 initialExitAssets = IStrategyManager(aaveV3StrategyManager).convertToExitAssets(redemptionShares);

        assertEq(initialExitAssets, expectedInitialExitAssets);

        impairStrategy(aaveV3UnderlyingStrategy, impairment);

        uint256 impairedExitAssets = IStrategyManager(aaveV3StrategyManager).convertToExitAssets(redemptionShares);

        uint256 expectedImpairedExitAssets = redemptionShares * (strategyAssets - impairment) / strategyAssets;

        assertEq(impairedExitAssets, expectedImpairedExitAssets);  // 50k - 1 on Aave, 50k on SparkLend.

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), impairment);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     strategyAssets,
            aTokenBalance:           strategyAssets,
            lastRecordedTotalAssets: strategyAssets,
            unrealizedLosses:        impairment
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: strategyAssets,
            availableToWithdraw:   strategyAssets,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssets,
            shares:           strategyShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: impairment
        });

        removeStrategyImpairment(aaveV3UnderlyingStrategy, impairment);

        uint256 restoredExitAssets = IStrategyManager(aaveV3StrategyManager).convertToExitAssets(redemptionShares);

        assertEq(restoredExitAssets, initialExitAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), 0);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     strategyAssets,
            aTokenBalance:           strategyAssets,
            lastRecordedTotalAssets: strategyAssets,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: strategyAssets,
            availableToWithdraw:   strategyAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssets,
            shares:           strategyShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        uint256 poolBalanceBefore = fundsAsset.balanceOf(address(pool));

        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, redemptionShares);

        uint256 poolBalanceAfter = fundsAsset.balanceOf(address(pool));

        assertEq(poolBalanceAfter - poolBalanceBefore, restoredExitAssets);
    }

    function testFork_removeImpairment_aboveAndBelowAumClamp() external {
        uint256 removalBelowClamp = impairmentRemoval;                  // 100k.
        uint256 storedImpairment  = fundAmount + impairment;            // 750k.
        uint256 removalAboveClamp = storedImpairment - strategyAssets;  // 250k + 1 on Aave, 250k on SparkLend.

        impairStrategy(aaveV3UnderlyingStrategy, storedImpairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   strategyAssets,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), storedImpairment);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     strategyAssets,
            aTokenBalance:           strategyAssets,
            lastRecordedTotalAssets: strategyAssets,
            unrealizedLosses:        strategyAssets
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: strategyAssets,
            availableToWithdraw:   strategyAssets,
            unrealizedLosses:      strategyAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssets,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: strategyAssets
        });

        removeStrategyImpairment(aaveV3UnderlyingStrategy, removalAboveClamp);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   strategyAssets,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), strategyAssets);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     strategyAssets,
            aTokenBalance:           strategyAssets,
            lastRecordedTotalAssets: strategyAssets,
            unrealizedLosses:        strategyAssets
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: strategyAssets,
            availableToWithdraw:   strategyAssets,
            unrealizedLosses:      strategyAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssets,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: strategyAssets
        });

        removeStrategyImpairment(aaveV3UnderlyingStrategy, removalBelowClamp);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   strategyAssets - removalBelowClamp,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), strategyAssets - removalBelowClamp);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     strategyAssets,
            aTokenBalance:           strategyAssets,
            lastRecordedTotalAssets: strategyAssets,
            unrealizedLosses:        strategyAssets - removalBelowClamp
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: strategyAssets,
            availableToWithdraw:   strategyAssets,
            unrealizedLosses:      strategyAssets - removalBelowClamp
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssets,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: strategyAssets - removalBelowClamp
        });
    }

    function testFork_removeImpairment_splitsAcrossPoolManagers() external {
        address firstPool        = address(pool);
        address firstPoolManager = address(poolManager);

        ( address secondPool, address secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", aaveV3StrategyManager);

        deposit(secondPool, lp, poolLiquidity);
        fundStrategyManager(secondPoolManager, aaveV3StrategyManager, secondFundAmount);

        uint256 firstAssets  = strategyAssets;
        uint256 secondAssets = secondFundAmount - expectedRoundingError;  // 450k - 1 on Aave, 450k on SparkLend.
        uint256 totalAssets  = firstAssets + secondAssets;                // 950k - 2 on Aave, 950k on SparkLend.

        uint256 firstShares  = firstAssets;
        uint256 secondShares = secondAssets;
        uint256 totalShares  = firstShares + secondShares;

        uint256 firstLoss  = divRoundUp(firstShares  * impairment, totalShares);
        uint256 secondLoss = divRoundUp(secondShares * impairment, totalShares);

        impairStrategy(aaveV3UnderlyingStrategy, impairment);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   firstLoss,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   secondLoss,
            availableLiquidity: poolLiquidity - secondFundAmount
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), impairment);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     totalAssets,
            aTokenBalance:           totalAssets,
            lastRecordedTotalAssets: totalAssets,
            unrealizedLosses:        impairment
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstAssets,
            shares:           firstShares,
            pendingShares:    0,
            unrealizedLosses: firstLoss
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondAssets,
            shares:           secondShares,
            pendingShares:    0,
            unrealizedLosses: secondLoss
        });

        removeStrategyImpairment(aaveV3UnderlyingStrategy, impairmentRemoval);

        uint256 remainingImpairment = impairment - impairmentRemoval;  // 150k.

        firstLoss  = divRoundUp(firstShares  * remainingImpairment, totalShares);
        secondLoss = divRoundUp(secondShares * remainingImpairment, totalShares);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   firstLoss,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   secondLoss,
            availableLiquidity: poolLiquidity - secondFundAmount
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), remainingImpairment);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     totalAssets,
            aTokenBalance:           totalAssets,
            lastRecordedTotalAssets: totalAssets,
            unrealizedLosses:        remainingImpairment
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets,
            unrealizedLosses:      remainingImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstAssets,
            shares:           firstShares,
            pendingShares:    0,
            unrealizedLosses: firstLoss
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondAssets,
            shares:           secondShares,
            pendingShares:    0,
            unrealizedLosses: secondLoss
        });
    }

    function testFork_removeImpairment_doesNotCollectAccruedFees() external {
        uint32 delegateFeeRate = 0.1e6;   // 10% of accrued yield.
        uint32 protocolFeeRate = 0.05e6;  // 5% of accrued yield.

        setStrategyDelegateFeeRate(aaveV3UnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(aaveV3UnderlyingStrategy, protocolFeeRate);

        vm.warp(start + 365 days);

        uint256 fundedAssets        = strategyAssets;
        uint256 grossAum            = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy);
        uint256 expectedDelegateFee = (grossAum - fundedAssets) * delegateFeeRate / HUNDRED_PERCENT;
        uint256 expectedProtocolFee = (grossAum - fundedAssets) * protocolFeeRate / HUNDRED_PERCENT;
        uint256 netAum              = grossAum - expectedDelegateFee - expectedProtocolFee;

        assertGt(grossAum,            fundedAssets);
        assertGt(expectedDelegateFee, 0);
        assertGt(expectedProtocolFee, 0);
        assertGt(netAum,              impairment);

        impairStrategy(aaveV3UnderlyingStrategy, impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), impairment);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     netAum,
            aTokenBalance:           grossAum,
            lastRecordedTotalAssets: fundedAssets,
            unrealizedLosses:        impairment
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: netAum,
            availableToWithdraw:   netAum,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           netAum,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);

        removeStrategyImpairment(aaveV3UnderlyingStrategy, impairmentRemoval);

        uint256 remainingImpairment = impairment - impairmentRemoval;  // 150k.

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   remainingImpairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), remainingImpairment);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     netAum,
            aTokenBalance:           grossAum,
            lastRecordedTotalAssets: fundedAssets,
            unrealizedLosses:        remainingImpairment
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: netAum,
            availableToWithdraw:   netAum,
            unrealizedLosses:      remainingImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           netAum,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: remainingImpairment
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);
    }

    function testFork_removeImpairment_withFullyExitedPoolManager() external {
        address firstPool        = address(pool);
        address firstPoolManager = address(poolManager);

        ( address secondPool, address secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", aaveV3StrategyManager);

        deposit(secondPool, lp, poolLiquidity);
        fundStrategyManager(secondPoolManager, aaveV3StrategyManager, secondFundAmount);
        requestRedeemFromStrategyManager(firstPoolManager, aaveV3StrategyManager, strategyShares);
        processRedemptionFromStrategyManager(firstPoolManager, aaveV3StrategyManager, strategyShares);

        uint256 firstPoolAssets  = fundsAsset.balanceOf(firstPool);
        uint256 positionValue    = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy);
        uint256 secondPoolShares = secondFundAmount - expectedRoundingError;

        impairStrategy(aaveV3UnderlyingStrategy, impairment);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        firstPoolAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: firstPoolAssets
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity - secondFundAmount + positionValue,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - secondFundAmount
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), impairment);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     positionValue,
            aTokenBalance:           positionValue,
            lastRecordedTotalAssets: positionValue,
            unrealizedLosses:        impairment
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           secondPoolShares,
            totalPendingShares:    0,
            assetsUnderManagement: positionValue,
            availableToWithdraw:   positionValue,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      secondPoolManager,
            assets:           positionValue,
            shares:           secondPoolShares,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        removeStrategyImpairment(aaveV3UnderlyingStrategy, impairmentRemoval);

        uint256 remainingImpairment = impairment - impairmentRemoval;  // 150k.

        assertPoolState({
            pool:               firstPool,
            totalAssets:        firstPoolAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: firstPoolAssets
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity - secondFundAmount + positionValue,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   remainingImpairment,
            availableLiquidity: poolLiquidity - secondFundAmount
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), remainingImpairment);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     positionValue,
            aTokenBalance:           positionValue,
            lastRecordedTotalAssets: positionValue,
            unrealizedLosses:        remainingImpairment
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           secondPoolShares,
            totalPendingShares:    0,
            assetsUnderManagement: positionValue,
            availableToWithdraw:   positionValue,
            unrealizedLosses:      remainingImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      secondPoolManager,
            assets:           positionValue,
            shares:           secondPoolShares,
            pendingShares:    0,
            unrealizedLosses: remainingImpairment
        });
    }

    function testFork_removeImpairment_withFullyExitedPoolManagerAndBootstrapMint() external {
        ( aaveV3StrategyManager, aaveV3UnderlyingStrategy ) = _deployAaveV3Strategy({
            strategyDelegate_:            makeAddr("bootstrapStrategyDelegate"),
            aaveToken_:                   aaveToken,
            useVirtualUnderlyingBalance_: useVirtualUnderlyingBalance,
            strategyDelegateFeeRate_:     0,
            strategyProtocolFeeRate_:     0,
            strategyLiquidityCap_:        bootstrapMint + fundAmount + secondFundAmount,
            bootstrapMint_:               bootstrapMint
        });

        assertEq(IStrategyManager(aaveV3StrategyManager).sharesOf(address(0)), expectedBootstrapShares);

        ( address firstPool, address firstPoolManager ) = _createPoolSharingStrategy("bootstrapPoolDelegate", aaveV3StrategyManager);
        ( address secondPool, address secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", aaveV3StrategyManager);

        deposit(firstPool, lp, poolLiquidity);
        deposit(secondPool, lp, poolLiquidity);
        fundStrategyManager(firstPoolManager, aaveV3StrategyManager, fundAmount);
        fundStrategyManager(secondPoolManager, aaveV3StrategyManager, secondFundAmount);
        requestRedeemFromStrategyManager(firstPoolManager, aaveV3StrategyManager, strategyShares);
        processRedemptionFromStrategyManager(firstPoolManager, aaveV3StrategyManager, strategyShares);

        uint256 firstPoolAssets = poolLiquidity - expectedRoundingError;                     // 1m - 1 on Aave, 1m on SparkLend.
        uint256 positionValue   = bootstrapMint + secondFundAmount - expectedRoundingError;  // 550k - 1 on Aave, 550k on SparkLend.
        uint256 totalShares     = expectedBootstrapShares + expectedSecondPoolShares;        // 550k - 1 on Aave, 550k on SparkLend.

        uint256 bootstrapImpairment  = divRoundUp(expectedBootstrapShares  * impairment, totalShares);
        uint256 secondPoolImpairment = divRoundUp(expectedSecondPoolShares * impairment, totalShares);

        impairStrategy(aaveV3UnderlyingStrategy, impairment);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        firstPoolAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: firstPoolAssets
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity - secondFundAmount + expectedSecondPoolAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   secondPoolImpairment,
            availableLiquidity: poolLiquidity - secondFundAmount
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), impairment);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     positionValue,
            aTokenBalance:           positionValue,
            lastRecordedTotalAssets: positionValue,
            unrealizedLosses:        impairment
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: positionValue,
            availableToWithdraw:   positionValue,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(0),
            assets:           expectedBootstrapAssets,
            shares:           expectedBootstrapShares,
            pendingShares:    0,
            unrealizedLosses: bootstrapImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      secondPoolManager,
            assets:           expectedSecondPoolAssets,
            shares:           expectedSecondPoolShares,
            pendingShares:    0,
            unrealizedLosses: secondPoolImpairment
        });

        removeStrategyImpairment(aaveV3UnderlyingStrategy, impairmentRemoval);

        uint256 remainingImpairment           = impairment - impairmentRemoval;  // 150k.
        uint256 bootstrapRemainingImpairment  = divRoundUp(expectedBootstrapShares  * remainingImpairment, totalShares);
        uint256 secondPoolRemainingImpairment = divRoundUp(expectedSecondPoolShares * remainingImpairment, totalShares);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        firstPoolAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: firstPoolAssets
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity - secondFundAmount + expectedSecondPoolAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   secondPoolRemainingImpairment,
            availableLiquidity: poolLiquidity - secondFundAmount
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(), remainingImpairment);

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     positionValue,
            aTokenBalance:           positionValue,
            lastRecordedTotalAssets: positionValue,
            unrealizedLosses:        remainingImpairment
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: positionValue,
            availableToWithdraw:   positionValue,
            unrealizedLosses:      remainingImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(0),
            assets:           expectedBootstrapAssets,
            shares:           expectedBootstrapShares,
            pendingShares:    0,
            unrealizedLosses: bootstrapRemainingImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      secondPoolManager,
            assets:           expectedSecondPoolAssets,
            shares:           expectedSecondPoolShares,
            pendingShares:    0,
            unrealizedLosses: secondPoolRemainingImpairment
        });
    }

}

contract SparkLendStrategyRemoveImpairmentTests is AaveV3StrategyRemoveImpairmentTests {

    function setUp() public override {
        aaveToken                   = SPARK_USDC;
        useVirtualUnderlyingBalance = false;
        expectedRoundingError       = 0;

        super.setUp();

        expectedBootstrapAssets     = bootstrapMint + 1;
        expectedBootstrapShares     = expectedBootstrapAssets;
        expectedSecondPoolAssets    = secondFundAmount - 1;
        expectedSecondPoolShares    = expectedSecondPoolAssets;
    }

}
