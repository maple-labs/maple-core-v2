// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestBaseWithAssertions } from "../../contracts/utilities/TestBaseWithAssertions.sol";

import { Address, console } from "../../modules/contract-test-utils/contracts/test.sol";

import { Refinancer }        from "../../modules/loan/contracts/Refinancer.sol";
import { MapleLoan as Loan } from "../../modules/loan/contracts/MapleLoan.sol";

contract PoolScenarioTests is TestBaseWithAssertions {

    function setUp() public override {
        super.setUp();

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,
            platformManagementFeeRate:  0.08e6
        });
    }

    // Test 12
    function test_poolScenario_loanWithVeryHighInterestRate() external {
        address lp1 = address(new Address());

        depositLiquidity(lp1, 4_000_000e6);

        assertTotalAssets(4_000_000e6);
        assertEq(pool.balanceOf(lp1), 4_000_000e6);

        // This loan will be funded and then never interacted with again.
        Loan loan1 = fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e30), uint256(0.1e18), uint256(0), uint256(0)]
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          90_000_000_000e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 90_000_000_000_000_000e6,
            refinanceInterest:   0,
            issuanceRate:        90_000_000_000e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000_000_000_000_000e6,
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertTotalAssets(4_000_000e6);

        vm.warp(start + 800_000);

        assertTotalAssets(4_000_000e6 + 72_000_000_000_000_000e6);

        // Although the values here don't revert, if they were a bit higher, they would in the `getNextPaymentBreakdown` function
        // Currently, the way out of the situation would be to either:
        // 1. Refinance using a custom refinancer that can manually alter the storage of the interest rate.
        // 2. Close the loan, paying only the closing interest.

        closeLoan(loan1);

        // TotalAssets went down due to the loan closure.
        assertTotalAssets(4_000_000e6 + 90_000e6); // 1% of 1_000_000e6, removing management fees

        // Loan Manager should be in a coherent state
        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           start + 800_000,
            domainEnd:             start + 800_000,
            unrealizedLosses:      0
        });

        assertLoanInfoWasDeleted(loan1);
    }

    // Test 13
    function test_poolScenario_loanWithZeroInterestRate() external {
        address lp1 = address(new Address());

        depositLiquidity(lp1, 4_000_000e6);

        assertTotalAssets(4_000_000e6);
        assertEq(pool.balanceOf(lp1), 4_000_000e6);

        // This loan will be funded and then never interacted with again.
        Loan loan1 = fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0), uint256(0.1e18), uint256(0.01e18), uint256(0)]
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          0,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  0,
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertTotalAssets(4_000_000e6);

        // Perform early payment
        vm.warp(start + 800_000);

        assertTotalAssets(4_000_000e6);

        makePayment(loan1);

        assertTotalAssets(4_000_000e6);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          0,
            domainStart:           start + 800_000,
            domainEnd:             start + 2_000_000,
            unrealizedLosses:      0
        });

        assertPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           start + 800_000,
            paymentDueDate:      start + 2_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  0,
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 2
        });

        // Second payment will be made late
        vm.warp(start + 2_100_000);

        assertTotalAssets(4_000_000e6);

        makePayment(loan1);

        assertTotalAssets(4_000_000e6 + 9_000e6); // 1 day worth of late interest

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          0,
            domainStart:           start + 2_100_000,
            domainEnd:             start + 3_000_000,
            unrealizedLosses:      0
        });

        assertPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           start + 2_000_000,
            paymentDueDate:      start + 3_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 1_000_000e6,
            incomingInterest:  0,
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 3_000_000,
            paymentsRemaining: 1
        });

        vm.warp(start + 2_900_000);

        makePayment(loan1);

        assertTotalAssets(4_000_000e6 + 9_000e6); // 1 day worth of late interest

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           start + 2_900_000,
            domainEnd:             start + 2_900_000,
            unrealizedLosses:      0
        });
    }

}
