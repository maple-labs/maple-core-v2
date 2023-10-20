// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

contract UnrealizedLossesTests is TestBaseWithAssertions {

    address borrower = makeAddr("borrower");
    address lp1      = makeAddr("lp1");
    address lp2      = makeAddr("lp2");
    address lp3      = makeAddr("lp3");

    address loan;

    function setUp() public virtual override {
        super.setUp();

        deposit(lp1, 1_500_000e6);
        deposit(lp2, 3_500_000e6);
        deposit(lp3, 5_000_000e6);

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         275e6,
            delegateManagementFeeRate:  0.02e6,    // 1,000,000 * 3.1536% * 2% * 1,000,000 / (365 * 86400) = 20
            platformOriginationFeeRate: 0.001e6,   // 1,000,000 * 0.10%   * 3  * 1,000,000 / (365 * 86400) = 95.129375e6
            platformServiceFeeRate:     0.0066e6,  // 1,000,000 * 0.66%        * 1,000,000 / (365 * 86400) = 209.2846270e6
            platformManagementFeeRate:  0.08e6     // 1,000,000 * 3.1536% * 8% * 1,000,000 / (365 * 86400) = 80
        });

        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(1_000e6), uint256(4_000_000e6), uint256(4_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0), uint256(0), uint256(0)],
            loanManager: poolManager.loanManagerList(0)
        });
    }

    function test_unrealizedLosses_redeemWithUnrealizedLosses_fullLiquidity() external {
        vm.warp(start + 1_000_000);

        impairLoan(loan);

        assertLiquidationInfo({
            loan:                loan,
            principal:           4_000_000e6,
            interest:            3_600e6,        // 1_000_000s of 0.36e6 IR
            lateInterest:        0,
            platformFees:        1157.138508e6,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 3_600e6,
            refinanceInterest:   0,
            issuanceRate:        0.0036e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,  // Keep original date in case impair loan reverted
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertEq(poolManager.unrealizedLosses(), 4_003_600e6);

        // LP1 requests to withdraw
        vm.prank(lp1);
        pool.requestRedeem(1_500_000e6, lp1);

        vm.warp(start + 3 weeks);

        assertEq(cyclicalWM.lockedShares(lp1),   1_500_000e6);
        assertEq(cyclicalWM.totalCycleShares(4), 1_500_000e6);
        assertEq(cyclicalWM.exitCycleId(lp1),    4);

        assertEq(pool.balanceOf(address(cyclicalWM)), 1_500_000e6);
        assertEq(fundsAsset.balanceOf(address(pool)), 6_000_000e6);
        assertEq(fundsAsset.balanceOf(address(lp1)),  0);

        uint256 fullAssets  = pool.convertToAssets(1_500_000e6);
        uint256 totalAssets = poolManager.totalAssets();

        // The whole amount for LP1, without unrealized losses.
        assertEq(fullAssets,  1_500_540e6);
        assertEq(totalAssets, 10_003_600e6);

        vm.prank(lp1);
        uint256 withdrawnAssets = pool.redeem(1_500_000e6, lp1, lp1);

        // Total assets (10_003_600e6) - unrealized losses (4_003_600e6) = 6_000_000e6 * lp1 pool share (0.15) = 900_000e6.
        assertEq(withdrawnAssets, 900_000e6);

        assertEq(pool.balanceOf(address(cyclicalWM)), 0);
        assertEq(pool.balanceOf(address(lp1)),        0);
        assertEq(fundsAsset.balanceOf(address(pool)), 5_100_000e6);
        assertEq(fundsAsset.balanceOf(address(lp1)),  900_000e6);
    }

    function test_unrealizedLosses_redeemWithUnrealizedLosses_partialLiquidity() external {
        // Fund another loan for 5_200_000e6.
        fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(1_000e6), uint256(5_200_000e6), uint256(4_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0), uint256(0), uint256(0)],
            loanManager: poolManager.loanManagerList(0)
        });

        vm.warp(start + 1_000_000);

        impairLoan(loan);

        assertLiquidationInfo({
            loan:                loan,
            principal:           4_000_000e6,
            interest:            3_600e6,        // 1_000_000s of 0.36e6 IR
            lateInterest:        0,
            platformFees:        1157.138508e6,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 3_600e6,
            refinanceInterest:   0,
            issuanceRate:        0.0036e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,  // Keep original date in case impair loan reverted
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertEq(poolManager.unrealizedLosses(), 4_003_600e6);

        // LP1 requests to withdraw
        vm.prank(lp1);
        pool.requestRedeem(1_500_000e6, lp1);

        vm.warp(start + 3 weeks);

        assertEq(cyclicalWM.lockedShares(lp1),   1_500_000e6);
        assertEq(cyclicalWM.totalCycleShares(4), 1_500_000e6);
        assertEq(cyclicalWM.exitCycleId(lp1),    4);

        assertEq(pool.balanceOf(address(cyclicalWM)), 1_500_000e6);
        assertEq(fundsAsset.balanceOf(address(pool)), 800_000e6);
        assertEq(fundsAsset.balanceOf(address(lp1)),  0);

        uint256 fullAssets  = pool.convertToAssets(1_500_000e6);
        uint256 totalAssets = poolManager.totalAssets();

        // The whole amount for LP1, without unrealized losses.
        assertEq(fullAssets,  1_501_242e6);
        assertEq(totalAssets, 10_008_280e6);

        vm.prank(lp1);
        uint256 withdrawnAssets = pool.redeem(1_500_000e6, lp1, lp1);

        // Total assets (10_008_280e6) - unrealized losses (4_003_600e6) = 6_004_680e6 * lp1 pool share (0.15) = 900_702e6.
        // But since there's not enough liquidity, lp1 gets 800_000e6
        // Total Requested:  900_702e6
        // Total Available:  800_000e6
        // Total Shares:     1_500_000e6 * 800_000e6 / 900_702e6 = 1_332_294.143901 shares
        // Remaining Shares: 1_500_000e6 - 1_332_294.143901      = 167_705.856099 shares
        assertEq(withdrawnAssets, 800_000e6 - 1);

        assertEq(pool.balanceOf(address(cyclicalWM)), 1_500_000e6 - (1_500_000e6 * uint256(800_000e6) / 900_702e6));
        assertEq(pool.balanceOf(address(cyclicalWM)), 167_705.856099e6);
        assertEq(pool.balanceOf(address(lp1)),        0);
        assertEq(fundsAsset.balanceOf(address(pool)), 1);              // Rounding error
        assertEq(fundsAsset.balanceOf(address(lp1)),  800_000e6 - 1);  // Rounding error
    }

    function test_unrealizedLosses_depositWithUnrealizedLosses() external {
        vm.warp(start + 1_000_000);

        impairLoan(loan);

        assertLiquidationInfo({
            loan:                loan,
            principal:           4_000_000e6,
            interest:            3_600e6,        // 1_000_000s of 0.36e6 IR
            lateInterest:        0,
            platformFees:        1157.138508e6,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 3_600e6,
            refinanceInterest:   0,
            issuanceRate:        0.0036e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,  // Keep original date in case impair loan reverted
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertEq(poolManager.unrealizedLosses(), 4_003_600e6);

        // Create a new LP to deposit.
        address lp4 = makeAddr("lp4");

        // The amount of exit shares won't equal the amount of join shares due to the unrealized losses.
        uint256 exitShares      = pool.convertToExitShares(2_000_000e6);
        uint256 depositedShares = deposit(lp4, 2_000_000e6);

        // totalSupply / (totalAssets - unrealizedLosses) + 1
        assertEq(exitShares, (2_000_000e6 * 10_000_000e6 / uint256(6_000_000e6)) + 1);
        assertEq(exitShares, 3_333_333.333334e6);

        // totalSupply / totalAssets (rounding not necessary)
        assertEq(depositedShares, (2_000_000e6 * 10_000_000e6 / uint256(10_003_600e6)));
        assertEq(depositedShares, 1_999_280.259106e6);
    }

}
