// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAaveV3Strategy,
    IERC20
} from "../../../contracts/interfaces/Interfaces.sol";

import { AaveV3StrategyTestBase } from "./AaveV3StrategyTestBase.sol";

contract AaveV3StrategyImpairFailureTests is AaveV3StrategyTestBase {

    uint256 impairment = 100_000e6;

    function testFork_impair_failWhenProtocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:PAUSED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).impair(impairment);
    }

    function testFork_impair_failWhenStrategyPaused() external {
        vm.prank(governor);
        globals.setContractPause(aaveV3UnderlyingStrategy, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:PAUSED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).impair(impairment);
    }

    function testFork_impair_failWhenNotProtocolAdmin() external {
        vm.prank(governor);
        vm.expectRevert("MAV3S:NOT_AUTHORIZED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).impair(impairment);
    }

    function testFork_impair_failWhenLossRecognized() external {
        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:LOSS_RECOGNIZED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).impair(impairment);
    }

    function testFork_impair_failWithZeroAssets() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:I:ZERO");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).impair(0);
    }

}

contract SparkLendStrategyImpairFailureTests is AaveV3StrategyImpairFailureTests {

    function setUp() public override {
        aaveToken                   = SPARK_USDC;
        useVirtualUnderlyingBalance = false;

        super.setUp();
    }

}

contract AaveV3StrategyImpairTests is AaveV3StrategyTestBase {

    uint256 expectedRoundingError = 1;
    uint256 fundAmount            = 500_000e6;
    uint256 poolLiquidity         = 1_000_000e6;

    function setUp() public virtual override {
        super.setUp();

        deposit(lp, poolLiquidity);
        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     fundAmount - expectedRoundingError,
            aTokenBalance:           fundAmount - expectedRoundingError,
            lastRecordedTotalAssets: fundAmount - expectedRoundingError,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           fundAmount - expectedRoundingError,
            totalPendingShares:    0,
            assetsUnderManagement: fundAmount - expectedRoundingError,
            availableToWithdraw:   fundAmount - expectedRoundingError,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           fundAmount - expectedRoundingError,
            shares:           fundAmount - expectedRoundingError,
            pendingShares:    0,
            unrealizedLosses: 0
        });

    }

    function testFork_impair_accumulatesAcrossAllAdmins() external {
        uint256 strategyDelegateImpairment = 100_000e6;
        uint256 opAdminImpairment          = 150_000e6;

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).impair(strategyDelegateImpairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   strategyDelegateImpairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     fundAmount - expectedRoundingError,
            aTokenBalance:           fundAmount - expectedRoundingError,
            lastRecordedTotalAssets: fundAmount - expectedRoundingError,
            unrealizedLosses:        strategyDelegateImpairment
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           fundAmount - expectedRoundingError,
            totalPendingShares:    0,
            assetsUnderManagement: fundAmount - expectedRoundingError,
            availableToWithdraw:   fundAmount - expectedRoundingError,
            unrealizedLosses:      strategyDelegateImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           fundAmount - expectedRoundingError,
            shares:           fundAmount - expectedRoundingError,
            pendingShares:    0,
            unrealizedLosses: strategyDelegateImpairment
        });

        vm.prank(operationalAdmin);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).impair(opAdminImpairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   strategyDelegateImpairment + opAdminImpairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     fundAmount - expectedRoundingError,
            aTokenBalance:           fundAmount - expectedRoundingError,
            lastRecordedTotalAssets: fundAmount - expectedRoundingError,
            unrealizedLosses:        strategyDelegateImpairment + opAdminImpairment
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           fundAmount - expectedRoundingError,
            totalPendingShares:    0,
            assetsUnderManagement: fundAmount - expectedRoundingError,
            availableToWithdraw:   fundAmount - expectedRoundingError,
            unrealizedLosses:      strategyDelegateImpairment + opAdminImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           fundAmount - expectedRoundingError,
            shares:           fundAmount - expectedRoundingError,
            pendingShares:    0,
            unrealizedLosses: strategyDelegateImpairment + opAdminImpairment
        });
    }

    function testFork_impair_clampsToAssetsUnderManagement() external {
        uint256 impairment = fundAmount + 250_000e6;

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).impair(impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   fundAmount - expectedRoundingError,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     fundAmount - expectedRoundingError,
            aTokenBalance:           fundAmount - expectedRoundingError,
            lastRecordedTotalAssets: fundAmount - expectedRoundingError,
            unrealizedLosses:        fundAmount - expectedRoundingError
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           fundAmount - expectedRoundingError,
            totalPendingShares:    0,
            assetsUnderManagement: fundAmount - expectedRoundingError,
            availableToWithdraw:   fundAmount - expectedRoundingError,
            unrealizedLosses:      fundAmount - expectedRoundingError
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           fundAmount - expectedRoundingError,
            shares:           fundAmount - expectedRoundingError,
            pendingShares:    0,
            unrealizedLosses: fundAmount - expectedRoundingError
        });

        vm.warp(block.timestamp + 365 days);

        uint256 positionValue = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy);

        assertGt(positionValue, fundAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + positionValue,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   positionValue,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     positionValue,
            aTokenBalance:           positionValue,
            lastRecordedTotalAssets: fundAmount - expectedRoundingError,
            unrealizedLosses:        positionValue
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           fundAmount - expectedRoundingError,
            totalPendingShares:    0,
            assetsUnderManagement: positionValue,
            availableToWithdraw:   positionValue,
            unrealizedLosses:      positionValue
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           positionValue,
            shares:           fundAmount - expectedRoundingError,
            pendingShares:    0,
            unrealizedLosses: positionValue
        });
    }

    function testFork_impair_unrealizedLossGrowsToImpairmentAsAumIncreases() external {
        uint256 impairment = fundAmount + 100e6;

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).impair(impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   fundAmount - expectedRoundingError,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     fundAmount - expectedRoundingError,
            aTokenBalance:           fundAmount - expectedRoundingError,
            lastRecordedTotalAssets: fundAmount - expectedRoundingError,
            unrealizedLosses:        fundAmount - expectedRoundingError
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           fundAmount - expectedRoundingError,
            totalPendingShares:    0,
            assetsUnderManagement: fundAmount - expectedRoundingError,
            availableToWithdraw:   fundAmount - expectedRoundingError,
            unrealizedLosses:      fundAmount - expectedRoundingError
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           fundAmount - expectedRoundingError,
            shares:           fundAmount - expectedRoundingError,
            pendingShares:    0,
            unrealizedLosses: fundAmount - expectedRoundingError
        });

        vm.warp(block.timestamp + 365 days);

        uint256 positionValue = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy);

        assertGt(positionValue, impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + positionValue,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     positionValue,
            aTokenBalance:           positionValue,
            lastRecordedTotalAssets: fundAmount - expectedRoundingError,
            unrealizedLosses:        impairment
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           fundAmount - expectedRoundingError,
            totalPendingShares:    0,
            assetsUnderManagement: positionValue,
            availableToWithdraw:   positionValue,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           positionValue,
            shares:           fundAmount - expectedRoundingError,
            pendingShares:    0,
            unrealizedLosses: impairment
        });
    }

    function testFork_impair_splitsAcrossPoolManagers() external {
        uint256 secondFund = 450_000e6;
        uint256 impairment = 100_000e6;

        address firstPool        = address(pool);
        address firstPoolManager = address(poolManager);

        ( address secondPool, address secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", aaveV3StrategyManager);

        deposit(secondPool, lp, poolLiquidity);
        fundStrategyManager(secondPoolManager, aaveV3StrategyManager, secondFund);

        uint256 firstShares  = fundAmount - expectedRoundingError;
        uint256 secondShares = secondFund - expectedRoundingError;
        uint256 totalShares  = firstShares + secondShares;

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - secondFund
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     totalShares,
            aTokenBalance:           totalShares,
            lastRecordedTotalAssets: totalShares,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalShares,
            availableToWithdraw:   totalShares,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstShares,
            shares:           firstShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondShares,
            shares:           secondShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        uint256 firstLoss  = divRoundUp(firstShares  * impairment, totalShares);
        uint256 secondLoss = divRoundUp(secondShares * impairment, totalShares);

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).impair(impairment);

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
            availableLiquidity: poolLiquidity - secondFund
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     totalShares,
            aTokenBalance:           totalShares,
            lastRecordedTotalAssets: totalShares,
            unrealizedLosses:        impairment
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalShares,
            availableToWithdraw:   totalShares,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstShares,
            shares:           firstShares,
            pendingShares:    0,
            unrealizedLosses: firstLoss
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondShares,
            shares:           secondShares,
            pendingShares:    0,
            unrealizedLosses: secondLoss
        });
    }

    function testFork_impair_withFeesAndYield() external {
        uint32 delegateFeeRate = 0.1e6;   // 10% of accrued yield.
        uint32 protocolFeeRate = 0.05e6;  // 5% of accrued yield.

        uint256 fundedAssets = fundAmount - expectedRoundingError;
        uint256 impairment   = 100_000e6;

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).setStrategyDelegateFeeRate(delegateFeeRate);

        vm.prank(governor);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).setStrategyProtocolFeeRate(protocolFeeRate);

        vm.warp(block.timestamp + 365 days);

        uint256 grossAum            = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy);
        uint256 expectedDelegateFee = (grossAum - fundedAssets) * delegateFeeRate / HUNDRED_PERCENT;
        uint256 expectedProtocolFee = (grossAum - fundedAssets) * protocolFeeRate / HUNDRED_PERCENT;
        uint256 netAum              = grossAum - expectedDelegateFee - expectedProtocolFee;

        assertGt(grossAum,            fundedAssets);
        assertGt(expectedDelegateFee, 0);
        assertGt(expectedProtocolFee, 0);
        assertGt(netAum,              impairment);

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).impair(impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     netAum,
            aTokenBalance:           grossAum,
            lastRecordedTotalAssets: fundedAssets,
            unrealizedLosses:        impairment
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           fundedAssets,
            totalPendingShares:    0,
            assetsUnderManagement: netAum,
            availableToWithdraw:   netAum,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           netAum,
            shares:           fundedAssets,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);
    }

    function testFork_impair_withFullyExitedPoolManager() external {
        uint256 impairment = 100_000e6;
        uint256 secondFund = 450_000e6;

        address firstPool        = address(pool);
        address firstPoolManager = address(poolManager);

        ( address secondPool, address secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", aaveV3StrategyManager);

        deposit(secondPool, lp, poolLiquidity);
        fundStrategyManager(secondPoolManager, aaveV3StrategyManager, secondFund);

        uint256 firstShares  = fundAmount - expectedRoundingError;
        uint256 secondShares = secondFund - expectedRoundingError;

        requestRedeemFromStrategyManager(firstPoolManager, aaveV3StrategyManager, firstShares);
        processRedemptionFromStrategyManager(firstPoolManager, aaveV3StrategyManager, firstShares);

        uint256 firstPoolAssets = fundsAsset.balanceOf(firstPool);
        uint256 positionValue   = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy);

        assertGt(positionValue, impairment);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        firstPoolAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: firstPoolAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).impair(impairment);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        firstPoolAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: firstPoolAssets
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity - secondFund + positionValue,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - secondFund
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     positionValue,
            aTokenBalance:           positionValue,
            lastRecordedTotalAssets: positionValue,
            unrealizedLosses:        impairment
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           secondShares,
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
            shares:           secondShares,
            pendingShares:    0,
            unrealizedLosses: impairment
        });
    }

}

contract SparkLendStrategyImpairTests is AaveV3StrategyImpairTests {

    function setUp() public override {
        aaveToken                   = SPARK_USDC;
        useVirtualUnderlyingBalance = false;
        expectedRoundingError       = 0;

        super.setUp();
    }

}
