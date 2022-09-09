// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestBaseWithAssertions } from "../contracts/utilities/TestBaseWithAssertions.sol";

import { Address, console } from "../modules/contract-test-utils/contracts/test.sol";

import { MapleLoan as Loan } from "../modules/loan/contracts/MapleLoan.sol";

contract CloseLoanFailureTest is TestBaseWithAssertions {

    address borrower;
    address lp;

    Loan loan;

    function setUp() public override {
        super.setUp();

        borrower = address(new Address());
        lp       = address(new Address());

        depositLiquidity({
            lp:        lp,
            liquidity: 1_500_000e6
        });

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,  // 10k after 1m seconds
            platformManagementFeeRate:  0.08e6
        });

        loan = fundAndDrawdownLoan({
            borrower:         borrower,
            termDetails:      [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:          [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:            [uint256(3.1536e18), uint256(0), uint256(0), uint256(0)]
        });
    }

    function test_closeLoan_failWithInsuficcientApproval() external {
        ( uint256 principal_, uint256 interest_, uint256 fees_ ) = loan.getClosingPaymentBreakdown();

        uint256 fullPayment = principal_ + interest_ + fees_;

        // mint to borrower
        fundsAsset.mint(borrower, fullPayment);

        // Approve only 1 wei less than the full payment
        vm.prank(borrower);
        fundsAsset.approve(address(loan), fullPayment - 1);

        vm.prank(borrower);
        vm.expectRevert("ML:CL:TRANSFER_FROM_FAILED");
        loan.closeLoan(fullPayment);
    }

    function test_closeLoan_failIfLoanIsLate() external {
        vm.warp(start + loan.nextPaymentDueDate() + 1);

        ( uint256 principal_, uint256 interest_, uint256 fees_ ) = loan.getClosingPaymentBreakdown();

        uint256 fullPayment = principal_ + interest_ + fees_;

        // mint to loan
        fundsAsset.mint(address(loan), fullPayment);

        vm.prank(borrower);
        vm.expectRevert("ML:CL:PAYMENT_IS_LATE");
        loan.closeLoan(0);
    }

    function test_closeLoan_failIfNotEnoughFundsSent() external {
        ( uint256 principal_, uint256 interest_, uint256 fees_ ) = loan.getClosingPaymentBreakdown();

        uint256 fullPayment = principal_ + interest_ + fees_;

        fundsAsset.mint(address(loan), fullPayment - 1);

        vm.prank(borrower);
        vm.expectRevert(ARITHMETIC_ERROR);
        loan.closeLoan(0);
    }

    function test_closeLoan_failIfNotLoan() external {
        vm.expectRevert("LM:C:NOT_LOAN");
        loanManager.claim(0, 10, start, start + 1_000_000);
    }

}
