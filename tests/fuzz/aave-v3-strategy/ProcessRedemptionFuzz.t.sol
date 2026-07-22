// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAaveV3Strategy,
    IERC20,
    IStrategyManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { AaveV3StrategyTestBase } from "../../integration/aave-v3-strategy/AaveV3StrategyTestBase.sol";

abstract contract AaveV3StrategyProcessRedemptionFuzzTestBase is AaveV3StrategyTestBase {

    event RedemptionProcessed(address indexed poolManager, uint256 sharesProcessed, uint256 assetsWithdrawn);

    // Balance snapshots stored to avoid stack-too-deep errors.
    uint256 delegateBalanceBefore;
    uint256 poolBalanceBefore;
    uint256 treasuryBalanceBefore;

    function setUp() public virtual override {
        super.setUp();

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).setStrategyDelegateFeeRate(0.1e6);   // 10% of accrued yield.

        vm.prank(governor);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).setStrategyProtocolFeeRate(0.05e6);  // 5% of accrued yield.
    }

    function testFuzz_processRedemption_partial(uint256 fundAmount_, uint256 shares_, uint256 duration_) external {
        fundAmount_ = bound(fundAmount_, 1e6, 1_000_000e6);
        duration_   = bound(duration_, 1 days, 365 days);

        uint256 poolShares_ = deposit(lp, fundAmount_);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount_);

        uint256 fundedAssets_ = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy);
        uint256 totalShares_  = IStrategyManager(aaveV3StrategyManager).sharesOf(address(poolManager));

        shares_ = bound(shares_, 1, totalShares_ - 1);

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares_);

        vm.warp(block.timestamp + duration_);

        uint256 grossAssets_  = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy);
        uint256 accruedYield_ = grossAssets_ - fundedAssets_;

        uint256 expectedDelegateFee_ =
            accruedYield_ * IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyDelegateFeeRate() / HUNDRED_PERCENT;
        uint256 expectedProtocolFee_ =
            accruedYield_ * IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyProtocolFeeRate() / HUNDRED_PERCENT;

        uint256 netAssets_      = grossAssets_ - expectedDelegateFee_ - expectedProtocolFee_;
        uint256 expectedAssets_ = shares_ * netAssets_ / totalShares_;

        assertGt(netAssets_, fundedAssets_);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        netAssets_,
            totalSupply:        poolShares_,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        // Cannot use assertAaveV3Strategy because the aToken balance includes uncollected fees while AUM is net of fees.

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        totalShares_,
            totalPendingShares: shares_
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           netAssets_,
            shares:           totalShares_,
            pendingShares:    shares_,
            unrealizedLosses: 0
        });

        delegateBalanceBefore = fundsAsset.balanceOf(strategyDelegate);
        treasuryBalanceBefore = fundsAsset.balanceOf(treasury);
        poolBalanceBefore     = fundsAsset.balanceOf(address(pool));

        vm.expectEmit(aaveV3StrategyManager);
        emit RedemptionProcessed(address(poolManager), shares_, expectedAssets_);

        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, shares_);

        assertEq(fundsAsset.balanceOf(strategyDelegate) - delegateBalanceBefore, expectedDelegateFee_);
        assertEq(fundsAsset.balanceOf(treasury) - treasuryBalanceBefore,         expectedProtocolFee_);
        assertEq(fundsAsset.balanceOf(address(pool)) - poolBalanceBefore,        expectedAssets_);

        uint256 remainingAssets_ = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy);
        uint256 remainingShares_ = totalShares_ - shares_;

        assertGt(remainingAssets_, 0);

        // Aave and Spark aToken scaled-balance conversions can leave up to two base units of rounding after withdrawal.
        assertApproxEqAbs(netAssets_ - expectedAssets_, remainingAssets_, 2);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        expectedAssets_ + remainingAssets_,
            totalSupply:        poolShares_,
            unrealizedLosses:   0,
            availableLiquidity: expectedAssets_
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     remainingAssets_,
            aTokenBalance:           remainingAssets_,
            lastRecordedTotalAssets: remainingAssets_,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        remainingShares_,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets_,
            shares:           remainingShares_,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFuzz_processRedemption_full(uint256 fundAmount_, uint256 duration_) external {
        fundAmount_ = bound(fundAmount_, 1e6, 1_000_000e6);
        duration_   = bound(duration_, 1 days, 365 days);

        uint256 poolShares_ = deposit(lp, fundAmount_);

        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount_);

        uint256 fundedAssets_ = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy);
        uint256 totalShares_  = IStrategyManager(aaveV3StrategyManager).sharesOf(address(poolManager));

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, totalShares_);

        vm.warp(block.timestamp + duration_);

        uint256 grossAssets_  = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy);
        uint256 accruedYield_ = grossAssets_ - fundedAssets_;

        uint256 expectedDelegateFee_ =
            accruedYield_ * IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyDelegateFeeRate() / HUNDRED_PERCENT;
        uint256 expectedProtocolFee_ =
            accruedYield_ * IAaveV3Strategy(aaveV3UnderlyingStrategy).strategyProtocolFeeRate() / HUNDRED_PERCENT;

        uint256 netAssets_      = grossAssets_ - expectedDelegateFee_ - expectedProtocolFee_;
        uint256 expectedAssets_ = netAssets_;

        assertGt(netAssets_, fundedAssets_);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        netAssets_,
            totalSupply:        poolShares_,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        // Cannot use assertAaveV3Strategy because the aToken balance includes uncollected fees while AUM is net of fees.

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        totalShares_,
            totalPendingShares: totalShares_
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           netAssets_,
            shares:           totalShares_,
            pendingShares:    totalShares_,
            unrealizedLosses: 0
        });

        delegateBalanceBefore = fundsAsset.balanceOf(strategyDelegate);
        treasuryBalanceBefore = fundsAsset.balanceOf(treasury);
        poolBalanceBefore     = fundsAsset.balanceOf(address(pool));

        vm.expectEmit(aaveV3StrategyManager);
        emit RedemptionProcessed(address(poolManager), totalShares_, expectedAssets_);

        processRedemptionFromStrategyManager(address(poolManager), aaveV3StrategyManager, totalShares_);

        assertEq(fundsAsset.balanceOf(strategyDelegate) - delegateBalanceBefore, expectedDelegateFee_);
        assertEq(fundsAsset.balanceOf(treasury) - treasuryBalanceBefore,         expectedProtocolFee_);
        assertEq(fundsAsset.balanceOf(address(pool)) - poolBalanceBefore,        expectedAssets_);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        expectedAssets_,
            totalSupply:        poolShares_,
            unrealizedLosses:   0,
            availableLiquidity: expectedAssets_
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            aTokenBalance:           0,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManagerShares({
            strategyManager:    aaveV3StrategyManager,
            totalShares:        0,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

}

contract AaveV3StrategyProcessRedemptionFuzzTestsBlock_25_123_119 is AaveV3StrategyProcessRedemptionFuzzTestBase {

    function setUp() public override {
        forkBlock = 25_123_119;
        super.setUp();
    }

}

contract AaveV3StrategyProcessRedemptionFuzzTestsBlock_25_223_119 is AaveV3StrategyProcessRedemptionFuzzTestBase {

    function setUp() public override {
        forkBlock = 25_223_119;
        super.setUp();
    }

}

contract AaveV3StrategyProcessRedemptionFuzzTestsBlock_25_323_119 is AaveV3StrategyProcessRedemptionFuzzTestBase {

    function setUp() public override {
        forkBlock = 25_323_119;
        super.setUp();
    }

}

contract AaveV3StrategyProcessRedemptionFuzzTestsBlock_25_423_119 is AaveV3StrategyProcessRedemptionFuzzTestBase {

    function setUp() public override {
        forkBlock = 25_423_119;
        super.setUp();
    }

}

contract AaveV3StrategyProcessRedemptionFuzzTestsBlock_25_523_119 is AaveV3StrategyProcessRedemptionFuzzTestBase {

    function setUp() public override {
        forkBlock = 25_523_119;
        super.setUp();
    }

}

abstract contract SparkLendStrategyProcessRedemptionFuzzTestBase is AaveV3StrategyProcessRedemptionFuzzTestBase {

    function setUp() public virtual override {
        aaveToken                   = SPARK_USDC;
        useVirtualUnderlyingBalance = false;

        super.setUp();
    }

}

contract SparkLendStrategyProcessRedemptionFuzzTestsBlock_25_123_119 is SparkLendStrategyProcessRedemptionFuzzTestBase {

    function setUp() public override {
        forkBlock = 25_123_119;
        super.setUp();
    }

}

contract SparkLendStrategyProcessRedemptionFuzzTestsBlock_25_223_119 is SparkLendStrategyProcessRedemptionFuzzTestBase {

    function setUp() public override {
        forkBlock = 25_223_119;
        super.setUp();
    }

}

contract SparkLendStrategyProcessRedemptionFuzzTestsBlock_25_323_119 is SparkLendStrategyProcessRedemptionFuzzTestBase {

    function setUp() public override {
        forkBlock = 25_323_119;
        super.setUp();
    }

}

contract SparkLendStrategyProcessRedemptionFuzzTestsBlock_25_423_119 is SparkLendStrategyProcessRedemptionFuzzTestBase {

    function setUp() public override {
        forkBlock = 25_423_119;
        super.setUp();
    }

}

contract SparkLendStrategyProcessRedemptionFuzzTestsBlock_25_523_119 is SparkLendStrategyProcessRedemptionFuzzTestBase {

    function setUp() public override {
        forkBlock = 25_523_119;
        super.setUp();
    }

}
