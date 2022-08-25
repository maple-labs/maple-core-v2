// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestBaseWithAssertions } from "../contracts/TestBaseWithAssertions.sol";

import { Address, console, TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

import { MapleLoan as Loan } from "../modules/loan/contracts/MapleLoan.sol";
import { LoanManager       } from "../modules/pool-v2/contracts/LoanManager.sol";
import { PoolManager       } from "../modules/pool-v2/contracts/PoolManager.sol";

contract LiquidationTests is TestBaseWithAssertions {

    // NOTE: This is a list of all the permutations of liquidation scenarios, but from the perspective of cover, there is some testing overlap, since it doesn't matter to the cover if there was collateral or not.

    // Liquidation:
    // - Natural
    // - Triggered
    // - Cancelled

    // Coverage:
    // - No Cover / No Collateral
    // - No Cover / Collateral:
    //     Case 1  - Collateral covers a portion of fees
    //     Case 2  - Collateral covers all fees and a portion of shortfall
    //     Case 3  - Collateral covers all losses (remainder sent to borrower)
    // - Cover / No Collateral:
    //     Case 4  - Cover covers a portion of fees
    //     Case 5  - Cover covers all fees and portion of shortfall
    //     Case 6  - Cover covers all fees and all shortfall
    // - Cover / With Collateral:
    //     Case 7  - Collateral covers all of fees and all of shortfall (same as 3)
    //     Case 8  - Cover covers none of fees, and some or all of shortfall
    //     Case 9  - Cover cover a portion of fees (collateral did not cover all fees, no principal/interest losses are covered by collateral nor cover, from cover perspective, this is the same as 4.)
    //     Case 10 - Cover covers all fees and portion of shortfall
    //     Case 11 - Cover covers all fees and all shortfall

    Loan loan;

    address borrower = address(new Address());
    address lp       = address(new Address());

    function setUp() public override {
        super.setUp();
    }

    /**
     *  @dev Sets up loan for liquidation scenarios: creates a address(loan), makes first payment on it.
     */
    function fastForwardLoanToMidLifecycle() internal {
        depositCover({ cover: 100_000e6 });

        depositLiquidity({
            lp: lp,
            liquidity: 1_500_000e6
        });

        setupFees({
            delegateOriginationFee:     500e6,   // 1,000,000 * 0.20% * 3  / 12 = 500
            delegateServiceFee:         275e6,   // 1,000,000 * 0.33%      / 12 = 275
            delegateManagementFeeRate:  2_0000,  // 1,000,000 * 2.00% * 2% / 12 = 125
            platformOriginationFeeRate: 1000,    // 1,000,000 * 0.10% * 3  / 12 = 250
            platformServiceFeeRate:     6600,    // 1,000,000 * 0.66%      / 12 = 550
            platformManagementFeeRate:  8_0000   // 1,000,000 * 8.50% * 8% / 12 = 500
        });

        /******************************/
        /*** Fund and Drawdown Loan ***/
        /******************************/

        loan = fundAndDrawdownLoan({
            borrower:         borrower,
            amounts:          [uint256(1_000_000e6), 100e18],
            interestRate:     0.075e18,
            paymentInterval:  ONE_MONTH,
            numberOfPayments: 3
        });

        // Pool liquidity:  1,500,000 - 1,000,000  = 500,000
        // Gross interest:  1,000,000 * 7.50% / 12 =   6,250
        // Service fees:                 275 + 550 =     825
        // Management fees:              125 + 500 =     625
        // Net interest:         6,250 - 125 - 500 =   5,625

        assertLoanState({
            loan:              address(loan),
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + ONE_MONTH,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                address(loan),
            incomingNetInterest: 5_625e6,
            refinanceInterest:   0,
            issuanceRate:        uint256(5_625e6) * 12e30 / ONE_YEAR,
            startDate:           start,
            paymentDueDate:      start + ONE_MONTH
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          uint256(5_625e6) * 12e30 / ONE_YEAR,
            domainStart:           start,
            domainEnd:             start + ONE_MONTH,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_500_000e6,
            unrealizedLosses: 0
        });

        // Origination fees: 500 + 250 = 750
        // Borrower cash:    1,000,000 - 750 = 999,250

        assertAssetBalances(
            [borrower,  address(pool), address(poolCover), poolDelegate, treasury],
            [999_250e6, 500_000e6,     100_000e6,          500e6,        250e6   ]
        );

        /************************************/
        /*** Warp to 1st Payment Due Date ***/
        /************************************/

        vm.warp(start + ONE_MONTH);

        assertLoanInfo({
            loan:                address(loan),
            incomingNetInterest: 5_625e6,
            refinanceInterest:   0,
            issuanceRate:        uint256(5_625e6) * 12e30 / ONE_YEAR,
            startDate:           start,
            paymentDueDate:      start + ONE_MONTH
        });

        assertLoanManager({
            accruedInterest:       5_625e6 - 1,  // -1 due to issuance rate rounding error.
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + 5_625e6 - 1,
            issuanceRate:          uint256(5_625e6) * 12e30 / ONE_YEAR,
            domainStart:           start,
            domainEnd:             start + ONE_MONTH,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_500_000e6 + 5_625e6 - 1,
            unrealizedLosses: 0
        });

        /************************/
        /*** Make 1st Payment ***/
        /************************/

        makePayment(loan);

        assertLoanState({
            loan:              address(loan),
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2 * ONE_MONTH,
            paymentsRemaining: 2
        });

        assertLoanInfo({
            loan:                address(loan),
            incomingNetInterest: 5_625e6,
            refinanceInterest:   0,
            issuanceRate:        uint256(5_625e6) * 12e30 / ONE_YEAR,
            startDate:           start + 1 * ONE_MONTH,
            paymentDueDate:      start + 2 * ONE_MONTH
        });

        assertLiquidationInfo({
            loan:                address(loan),
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          uint256(5_625e6) * 12e30 / ONE_YEAR,
            domainStart:           start + 1 * ONE_MONTH,
            domainEnd:             start + 2 * ONE_MONTH,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_500_000e6 + 5_625e6,
            unrealizedLosses: 0
        });

        assertAssetBalances(
            [borrower,  address(pool), address(poolCover), poolDelegate, treasury],
            [999_250e6, 505_625e6,     100_000e6,          900e6,        1300e6   ]
        );

    }

    function test_liquidation_case10() external {

        fastForwardLoanToMidLifecycle();

        /***********************************************/
        /*** Warp to end of 2nd Payment Grace Period ***/
        /***********************************************/

        // Since we round up days when it comes to late interest, this payment is 6 days late.
        vm.warp(start + 2 * ONE_MONTH + 5 days + 1 seconds);

        vm.prank(poolDelegate);
        PoolManager(poolManager).triggerCollateralLiquidation(address(loan));

        ( , , , , , address liquidator ) = LoanManager(loanManager).liquidationInfo(address(loan));

        assertLoanState({
            loan:              address(loan),
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertLoanInfo({
            loan:                address(loan),
            incomingNetInterest: 5_625e6,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           start + 1 * ONE_MONTH,
            paymentDueDate:      start + 2 * ONE_MONTH
        });

        // Interest:       5,626
        // Service fee:    550
        // Days late:      6
        // Late interest:  5,625 * 6 / 365 * 12
        // Management fee: 500 * (1 + 6 / 365 * 12)

        assertLiquidationInfo({
            loan:                address(loan),
            principal:           1_000_000e6,
            interest:            5_625e6 - 1,  // -1 due to issuance rate rounding error.
            lateInterest:        5_625e6 * 6 days / ONE_MONTH - 1,  // Loan rounds a day up for late interest
            platformFees:        550e6 + 500e6 + (500e6 * 6 days / ONE_MONTH),
            liquidatorExists:    true,
            triggeredByGovernor: false
        });

        // Lost principal:     1,000,000
        // Lost interest:      5,625
        // Lost late interest: 5,625 * (1 + 6 / 365 * 12)

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     5_625e6 - 1,  // -1 due to issuance rate rounding error.
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + 5_625e6 - 1,
            issuanceRate:          0,
            domainStart:           start + 2 * ONE_MONTH + 5 days + 1,
            domainEnd:             start + 2 * ONE_MONTH + 5 days + 1,
            unrealizedLosses:      1_000_000e6 + (5_625e6 - 1) + ((5_625e6 * 6 days / ONE_MONTH) - 1)
        });

        assertPoolManager({
            totalAssets:      1_000_000e6 + (5_625e6 - 1) + 500_000e6 + 5_625e6,
            unrealizedLosses: 1_000_000e6 + (5_625e6 - 1) + ((5_625e6 * 6 days / ONE_MONTH) - 1)
        });

        assertAssetBalances(
            [borrower,  address(pool), address(poolCover), poolDelegate, treasury, liquidator],
            [999_250e6, 505_625e6,     100_000e6,          900e6,        1300e6,   0         ]
        );

        /*******************************************/
        /*** 3rd Party Liquidates The Collateral ***/
        /*******************************************/

        liquidateCollateral(address(loan));

        assertAssetBalances(
            [borrower,  address(pool), address(poolCover), poolDelegate, treasury, liquidator],
            [999_250e6, 505_625e6,     100_000e6,          900e6,        1300e6,   150_000e6 ]
        );

        /*************************************/
        /*** Finish Collateral Liquidation ***/
        /*************************************/

        vm.prank(poolDelegate);
        PoolManager(poolManager).finishCollateralLiquidation(address(loan));

        assertLoanInfoWasDeleted(address(loan));

        assertLiquidationInfo({
            loan:                address(loan),
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           start + 2 * ONE_MONTH + 5 days + 1,
            domainEnd:             start + 2 * ONE_MONTH + 5 days + 1,
            unrealizedLosses:      0
        });

        // Initial pool liquidity: 500,000
        // Interest payment:       5,625
        // Liquidated collateral:  150,000
        // Liquidated cover:       100,000
        // Service fee:            550
        // Management fee:         500 * (1 + 6 / 365 * 12)

        // Total Assets: cash      + paid interest + collateral recovered + (cover used - platfrom service fee - platform management fee)
        // Total Assets: (500,000) + (5,625)       + (150,000)            + [100,000    - 550                  - (500 * (1 + 6 / 365 * 12))]

        assertPoolManager({
            totalAssets:      754_476.369863e6 + 1,
            unrealizedLosses: 0
        });

        assertAssetBalances(
            [borrower,  address(pool),        address(poolCover), poolDelegate, treasury,    liquidator],
            [999_250e6, 754_476.369863e6 + 1, 0,                  900e6,        2448_630136, 0         ]
        );

    }
}
