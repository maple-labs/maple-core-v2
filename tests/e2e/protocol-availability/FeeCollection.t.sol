// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IAavePoolLike,
    IAaveV3Strategy,
    IERC20,
    IPSMLike,
    IStrategyManager,
    ISkyStrategy
} from "../../../contracts/interfaces/Interfaces.sol";

import { AaveV3StrategyTestBase } from "../../integration/aave-v3-strategy/AaveV3StrategyTestBase.sol";
import { SkyStrategyTestBase } from "../../integration/sky-strategy/SkyStrategyTestBase.sol";

contract AaveV3StrategyFeeCollectionTests is AaveV3StrategyTestBase {

    uint32 delegateFeeRate    = 0.1e6; // 10% of accrued yield.
    uint32 newDelegateFeeRate = 0.2e6; // 20% of future accrued yield.
    uint32 newProtocolFeeRate = 0.1e6; // 10% of future accrued yield.
    uint32 protocolFeeRate    = 0.05e6; // 5% of accrued yield.

    uint256 additionalFunding                      = 100_000e6;
    uint256 expectedAdditionalFundingRoundingError = 2; // The restored follow-up supply leaves two fewer aToken units.
    uint256 expectedFeeCollectionRoundingError     = 1; // Aave rounds a fee-only withdrawal down one unit after repayment.
    uint256 expectedRoundingError                  = 1; // Aave supply rounds down one unit at this fork block.
    uint256 expectedWithdrawalRoundingAdjustment   = 0; // Aave has no combined-withdrawal rounding adjustment after repayment.
    uint256 fundAmount                             = 500_000e6;
    uint256 poolLiquidity                          = 1_000_000e6;

    uint256 expectedAdditionalShares;
    uint256 expectedDelegateFee;
    uint256 expectedFundedAum;
    uint256 expectedFundedShares;
    uint256 expectedProtocolFee;
    uint256 expectedRateChangeAum;
    uint256 expectedTotalFees;
    uint256 fundedAssets;
    uint256 grossAum;
    uint256 grossYield;
    uint256 netAum;
    uint256 redemptionAssets;
    uint256 redemptionShares;
    uint256 remainingAssets;
    uint256 remainingShares;
    uint256 totalShares;

    function setUp() public virtual override {
        super.setUp();

        deposit(lp, poolLiquidity);
    }

    function test_feeCollection_insufficientExternalLiquidity() external {
        /**********************************************************************************************************************************/
        /*** Set the old fee rates, fund the strategy and request a partial redemption                                                  ***/
        /**********************************************************************************************************************************/

        setStrategyDelegateFeeRate(aaveV3UnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(aaveV3UnderlyingStrategy, protocolFeeRate);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        fundedAssets     = fundAmount - expectedRoundingError;
        totalShares      = fundedAssets;
        redemptionShares = totalShares / 4;

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, redemptionShares);

        /**********************************************************************************************************************************/
        /*** Borrow all but one unit of lending-market liquidity before accruing yield                                                  ***/
        /**********************************************************************************************************************************/

        // SparkLend's collateral oracle is stale after the one-year warp, so the borrow must happen before yield accrual.
        (address aavePool, address borrower, uint256 borrowAmount) = borrowOnAave();

        assertEq(
            useVirtualUnderlyingBalance
                ? IAavePoolLike(aavePool).getVirtualUnderlyingBalance(address(fundsAsset))
                : fundsAsset.balanceOf(aaveToken),
            1
        );

        /**********************************************************************************************************************************/
        /*** Accrue one year of yield and calculate the fees owed at the old rates                                                      ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + 365 days);

        // The aToken balance is gross, while strategy AUM is reduced by accrued fees before they are collected.
        grossAum            = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy);
        grossYield          = grossAum - fundedAssets;
        expectedDelegateFee = grossYield * delegateFeeRate / HUNDRED_PERCENT;
        expectedProtocolFee = grossYield * protocolFeeRate / HUNDRED_PERCENT;
        expectedTotalFees   = expectedDelegateFee + expectedProtocolFee;
        netAum              = grossAum - expectedTotalFees;
        redemptionAssets    = redemptionShares * netAum / totalShares;

        assertGt(grossAum, fundedAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     netAum,
            aTokenBalance:           grossAum,
            lastRecordedTotalAssets: fundedAssets,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: netAum,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           netAum,
            shares:           totalShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyDelegateFeeRate(), delegateFeeRate);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyProtocolFeeRate(), protocolFeeRate);
        assertEq(fundsAsset.balanceOf(strategyDelegate),                              0);
        assertEq(fundsAsset.balanceOf(treasury),                                      0);

        /**********************************************************************************************************************************/
        /*** Snapshot the accrued strategy with lending-market liquidity below the fees                                                 ***/
        /**********************************************************************************************************************************/

        assertEq(
            useVirtualUnderlyingBalance
                ? IAavePoolLike(aavePool).getVirtualUnderlyingBalance(address(fundsAsset))
                : fundsAsset.balanceOf(aaveToken),
            1
        );

        /**********************************************************************************************************************************/
        /*** Confirm additional funding reverts atomically                                                                              ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(address(poolManager), additionalFunding, "");

        /**********************************************************************************************************************************/
        /*** Confirm both fee-rate changes revert atomically                                                                            ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        IAaveV3Strategy(aaveV3UnderlyingStrategy).setStrategyDelegateFeeRate(newDelegateFeeRate);

        vm.prank(governor);
        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x11));
        IAaveV3Strategy(aaveV3UnderlyingStrategy).setStrategyProtocolFeeRate(newProtocolFeeRate);

        /**********************************************************************************************************************************/
        /*** Confirm redemption reverts atomically                                                                                      ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:NOT_ENOUGH_LIQUIDITY");
        IStrategyManager(aaveV3StrategyManager).processRedemption(address(poolManager), redemptionShares, "");

        /**********************************************************************************************************************************/
        /*** Repay the borrowed principal and snapshot sufficient lending-market liquidity                                              ***/
        /**********************************************************************************************************************************/

        vm.startPrank(borrower);
        fundsAsset.approve(aavePool, borrowAmount);
        IAavePoolLike(aavePool).repay(address(fundsAsset), borrowAmount, 2, borrower);
        vm.stopPrank();

        assertGt(
            useVirtualUnderlyingBalance
                ? IAavePoolLike(aavePool).getVirtualUnderlyingBalance(address(fundsAsset))
                : fundsAsset.balanceOf(aaveToken),
            expectedTotalFees + redemptionAssets
        );

        uint256 highLiquiditySnapshot = vm.snapshotState();

        /**********************************************************************************************************************************/
        /*** Confirm additional funding charges the old fees once                                                                       ***/
        /**********************************************************************************************************************************/

        expectedAdditionalShares = (additionalFunding - expectedRoundingError) * totalShares / netAum;
        expectedFundedAum        = netAum + additionalFunding - expectedAdditionalFundingRoundingError;
        expectedFundedShares     = totalShares + expectedAdditionalShares;

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, additionalFunding);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount - additionalFunding + expectedFundedAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount - additionalFunding
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     expectedFundedAum,
            aTokenBalance:           expectedFundedAum,
            lastRecordedTotalAssets: expectedFundedAum,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           expectedFundedShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: expectedFundedAum,
            availableToWithdraw:   expectedFundedAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           expectedFundedAum,
            shares:           expectedFundedShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyDelegateFeeRate(), delegateFeeRate);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyProtocolFeeRate(), protocolFeeRate);
        assertEq(fundsAsset.balanceOf(strategyDelegate),                              expectedDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                                      expectedProtocolFee);

        /**********************************************************************************************************************************/
        /*** Restore the accrued snapshot and confirm the delegate fee-rate change charges the old fees once                            ***/
        /**********************************************************************************************************************************/

        vm.revertToState(highLiquiditySnapshot);

        expectedRateChangeAum = netAum - expectedFeeCollectionRoundingError;

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).setStrategyDelegateFeeRate(newDelegateFeeRate);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + expectedRateChangeAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     expectedRateChangeAum,
            aTokenBalance:           expectedRateChangeAum,
            lastRecordedTotalAssets: expectedRateChangeAum,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: expectedRateChangeAum,
            availableToWithdraw:   expectedRateChangeAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           expectedRateChangeAum,
            shares:           totalShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyDelegateFeeRate(), newDelegateFeeRate);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyProtocolFeeRate(), protocolFeeRate);
        assertEq(fundsAsset.balanceOf(strategyDelegate),                              expectedDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                                      expectedProtocolFee);

        /**********************************************************************************************************************************/
        /*** Restore the accrued snapshot and confirm the protocol fee-rate change charges the old fees once                            ***/
        /**********************************************************************************************************************************/

        vm.revertToState(highLiquiditySnapshot);

        expectedRateChangeAum = netAum - expectedFeeCollectionRoundingError;

        vm.prank(governor);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).setStrategyProtocolFeeRate(newProtocolFeeRate);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + expectedRateChangeAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     expectedRateChangeAum,
            aTokenBalance:           expectedRateChangeAum,
            lastRecordedTotalAssets: expectedRateChangeAum,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: expectedRateChangeAum,
            availableToWithdraw:   expectedRateChangeAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           expectedRateChangeAum,
            shares:           totalShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyDelegateFeeRate(), delegateFeeRate);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyProtocolFeeRate(), newProtocolFeeRate);
        assertEq(fundsAsset.balanceOf(strategyDelegate),                              expectedDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                                      expectedProtocolFee);

        /**********************************************************************************************************************************/
        /*** Restore the accrued snapshot and confirm redemption charges the old fees once                                              ***/
        /**********************************************************************************************************************************/

        vm.revertToState(highLiquiditySnapshot);

        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, redemptionShares);

        remainingAssets = netAum - redemptionAssets + expectedWithdrawalRoundingAdjustment;
        remainingShares = totalShares - redemptionShares;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum + expectedWithdrawalRoundingAdjustment,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + redemptionAssets
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     remainingAssets,
            aTokenBalance:           remainingAssets,
            lastRecordedTotalAssets: remainingAssets,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           remainingShares,
            totalPendingShares:    0,
            assetsUnderManagement: remainingAssets,
            availableToWithdraw:   remainingAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           remainingShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyDelegateFeeRate(), delegateFeeRate);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyProtocolFeeRate(), protocolFeeRate);
        assertEq(fundsAsset.balanceOf(strategyDelegate),                              expectedDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                                      expectedProtocolFee);
    }

}

contract SparkLendStrategyFeeCollectionTests is AaveV3StrategyFeeCollectionTests {

    function setUp() public override {
        aaveToken                              = SPARK_USDC;
        expectedAdditionalFundingRoundingError = 0; // The restored follow-up supply retains the full nominal amount.
        expectedFeeCollectionRoundingError     = 0; // Spark retains the full net AUM after fee-only withdrawal and repayment.
        expectedRoundingError                  = 0; // Spark reports the full nominal supply at this fork block.
        expectedWithdrawalRoundingAdjustment   = 1; // Spark retains one additional aToken unit after the combined withdrawal.
        useVirtualUnderlyingBalance            = false;

        super.setUp();
    }

}

contract SkyStrategyFeeCollectionTests is SkyStrategyTestBase {

    uint32 delegateFeeRate    = 0.1e6; // 10% of accrued yield.
    uint32 newDelegateFeeRate = 0.2e6; // 20% of future accrued yield.
    uint32 newProtocolFeeRate = 0.1e6; // 10% of future accrued yield.
    uint32 protocolFeeRate    = 0.05e6; // 5% of accrued yield.

    uint256 additionalFunding = 100_000e6;
    uint256 fundAmount        = 500_000e6;
    uint256 poolLiquidity     = 1_000_000e6;
    uint256 roundingLoss      = 1;

    uint256 expectedAdditionalShares;
    uint256 expectedDelegateFee;
    uint256 expectedFundedAum;
    uint256 expectedFundedShares;
    uint256 expectedProtocolFee;
    uint256 expectedTotalFees;
    uint256 fundedAssets;
    uint256 grossAum;
    uint256 grossYield;
    uint256 netAum;
    uint256 redemptionAssets;
    uint256 redemptionShares;
    uint256 remainingAssets;
    uint256 remainingShares;
    uint256 totalShares;

    function setUp() public override {
        super.setUp();

        deposit(lp, poolLiquidity);
    }

    function test_feeCollection_insufficientExternalLiquidity() external {
        /**********************************************************************************************************************************/
        /*** Set the old fee rates, fund the strategy and request a partial redemption                                                  ***/
        /**********************************************************************************************************************************/

        setStrategyDelegateFeeRate(skyUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(skyUnderlyingStrategy, protocolFeeRate);

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        fundedAssets     = fundAmount - roundingLoss;
        totalShares      = fundedAssets;
        redemptionShares = totalShares / 4;

        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, redemptionShares);

        /**********************************************************************************************************************************/
        /*** Accrue one year of yield and calculate the fees owed at the old rates                                                      ***/
        /**********************************************************************************************************************************/

        vm.warp(block.timestamp + 365 days);

        grossAum = fundAmount * (HUNDRED_PERCENT + SKY_ANNUAL_APY) / HUNDRED_PERCENT - roundingLoss;

        grossYield          = grossAum - fundedAssets; // 18_000_000_000.
        expectedDelegateFee = grossYield * delegateFeeRate / HUNDRED_PERCENT; // 1_800_000_000.
        expectedProtocolFee = grossYield * protocolFeeRate / HUNDRED_PERCENT; // 900_000_000.
        expectedTotalFees   = expectedDelegateFee + expectedProtocolFee; // 2_700_000_000.
        netAum              = grossAum - expectedTotalFees;
        redemptionAssets    = redemptionShares * netAum / totalShares;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              netAum,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: fundedAssets
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: netAum,
            availableToWithdraw:   netAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           netAum,
            shares:           totalShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyDelegateFeeRate(), delegateFeeRate);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyProtocolFeeRate(), protocolFeeRate);
        assertEq(fundsAsset.balanceOf(strategyDelegate),                        0);
        assertEq(fundsAsset.balanceOf(treasury),                                0);

        /**********************************************************************************************************************************/
        /*** Reduce PSM-pocket liquidity below the accrued fees                                                                         ***/
        /**********************************************************************************************************************************/

        uint256 highLiquiditySnapshot = vm.snapshotState();
        address pocket                = IPSMLike(USDS_LITE_PSM).pocket();

        deal(address(fundsAsset), pocket, expectedTotalFees - 1);

        /**********************************************************************************************************************************/
        /*** Confirm additional funding reverts atomically                                                                              ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        IStrategyManager(skyStrategyManager).fundStrategyManager(address(poolManager), additionalFunding, "");

        /**********************************************************************************************************************************/
        /*** Confirm both fee-rate changes revert atomically                                                                            ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        ISkyStrategy(skyUnderlyingStrategy).setStrategyDelegateFeeRate(newDelegateFeeRate);

        vm.prank(governor);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        ISkyStrategy(skyUnderlyingStrategy).setStrategyProtocolFeeRate(newProtocolFeeRate);

        /**********************************************************************************************************************************/
        /*** Confirm redemption reverts atomically                                                                                      ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:NOT_ENOUGH_LIQUIDITY");
        IStrategyManager(skyStrategyManager).processRedemption(address(poolManager), redemptionShares, "");

        /**********************************************************************************************************************************/
        /*** Restore liquidity and confirm additional funding charges the old fees once                                                 ***/
        /**********************************************************************************************************************************/

        vm.revertToState(highLiquiditySnapshot);

        expectedAdditionalShares = additionalFunding * totalShares / netAum;
        expectedFundedAum        = netAum + additionalFunding;
        expectedFundedShares     = totalShares + expectedAdditionalShares;

        fundStrategyManager(address(poolManager), skyStrategyManager, additionalFunding);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount - additionalFunding + expectedFundedAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount - additionalFunding
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              expectedFundedAum,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: expectedFundedAum
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           expectedFundedShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: expectedFundedAum,
            availableToWithdraw:   expectedFundedAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           expectedFundedAum,
            shares:           expectedFundedShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyDelegateFeeRate(), delegateFeeRate);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyProtocolFeeRate(), protocolFeeRate);
        assertEq(fundsAsset.balanceOf(strategyDelegate),                        expectedDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                                expectedProtocolFee);

        /**********************************************************************************************************************************/
        /*** Restore the accrued snapshot and confirm the delegate fee-rate change charges the old fees once                            ***/
        /**********************************************************************************************************************************/

        vm.revertToState(highLiquiditySnapshot);

        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).setStrategyDelegateFeeRate(newDelegateFeeRate);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              netAum,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: netAum
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: netAum,
            availableToWithdraw:   netAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           netAum,
            shares:           totalShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyDelegateFeeRate(), newDelegateFeeRate);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyProtocolFeeRate(), protocolFeeRate);
        assertEq(fundsAsset.balanceOf(strategyDelegate),                        expectedDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                                expectedProtocolFee);

        /**********************************************************************************************************************************/
        /*** Restore the accrued snapshot and confirm the protocol fee-rate change charges the old fees once                            ***/
        /**********************************************************************************************************************************/

        vm.revertToState(highLiquiditySnapshot);

        vm.prank(governor);
        ISkyStrategy(skyUnderlyingStrategy).setStrategyProtocolFeeRate(newProtocolFeeRate);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              netAum,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: netAum
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: netAum,
            availableToWithdraw:   netAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           netAum,
            shares:           totalShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyDelegateFeeRate(), delegateFeeRate);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyProtocolFeeRate(), newProtocolFeeRate);
        assertEq(fundsAsset.balanceOf(strategyDelegate),                        expectedDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                                expectedProtocolFee);

        /**********************************************************************************************************************************/
        /*** Restore the accrued snapshot and confirm redemption charges the old fees once                                              ***/
        /**********************************************************************************************************************************/

        vm.revertToState(highLiquiditySnapshot);

        processRedemptionFromStrategyManager(address(poolManager), skyStrategyManager, redemptionShares);

        remainingAssets = netAum - redemptionAssets;
        remainingShares = totalShares - redemptionShares;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + redemptionAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              remainingAssets,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: remainingAssets
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           remainingShares,
            totalPendingShares:    0,
            assetsUnderManagement: remainingAssets,
            availableToWithdraw:   remainingAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           remainingShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyDelegateFeeRate(), delegateFeeRate);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyProtocolFeeRate(), protocolFeeRate);
        assertEq(fundsAsset.balanceOf(strategyDelegate),                        expectedDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                                expectedProtocolFee);
    }

}
