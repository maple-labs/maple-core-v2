// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestBaseWithAssertions } from "../../contracts/utilities/TestBaseWithAssertions.sol";

import { Address, console } from "../../modules/contract-test-utils/contracts/test.sol";

import { MapleLoan as Loan } from "../../modules/loan/contracts/MapleLoan.sol";

contract MakePaymentFailureTests is TestBaseWithAssertions {

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

        vm.warp(start + 1_000_000);
    }

    function test_makePayment_failWithTransferFromFailed() external {
        (uint256 principalPortion, uint256 interestPortion, uint256 feesPortion) = loan.getNextPaymentBreakdown();

        uint256 fullPayment = principalPortion + interestPortion + feesPortion;

        // mint to borrower
        fundsAsset.mint(borrower, fullPayment);

        vm.prank(borrower);
        fundsAsset.approve(address(loan), fullPayment - 1);

        vm.expectRevert("ML:MP:TRANSFER_FROM_FAILED");
        loan.makePayment(fullPayment);
    }

    function test_makePayment_failWithTransferFailed() external {
        (uint256 principalPortion, uint256 interestPortion, uint256 feesPortion) = loan.getNextPaymentBreakdown();

        // mint to loan, not including fees
        fundsAsset.mint(address(loan), principalPortion + interestPortion + feesPortion - 1);

        vm.prank(borrower);
        vm.expectRevert(ARITHMETIC_ERROR);  // NOTE: When there's not enough balance, the tx fails in the ERC20 with an underflow rather than on the ERC20-helper library with the error message.
        loan.makePayment(0);
    }

    // TODO: Should I call this test_claim_failIfNotLoan?
    function test_makePayment_failIfNotLoan() external {
        vm.expectRevert("LM:C:NOT_LOAN");
        loanManager.claim(0, 10, start, start + 1_000_000);
    }

}
