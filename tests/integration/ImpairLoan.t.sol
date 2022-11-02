// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestBase } from "../../contracts/utilities/TestBase.sol";

import { Address } from "../../modules/contract-test-utils/contracts/test.sol";

import { MapleLoan as Loan } from "../../modules/loan/contracts/MapleLoan.sol";

contract ImpairLoanFailureTests is TestBase {

    Loan loan;

    function setUp() public virtual override {
        super.setUp();

        depositLiquidity({
            lp: address(new Address()),
            liquidity: 1_500_000e6
        });

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         275e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.0066e6,
            platformManagementFeeRate:  0.08e6
        });

        loan = fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(5 days), uint256(30 days), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.075e18), uint256(0), uint256(0), uint256(0)]
        });
    }

    function test_impairLoan_notAuthorized() external {
        vm.expectRevert("PM:IL:NOT_AUTHORIZED");
        poolManager.impairLoan(address(loan));
    }

    function test_impairLoan_notPoolManager() external {
        vm.expectRevert("LM:IL:NOT_PM");
        loanManager.impairLoan(address(loan), false);
    }

    function test_impairLoan_notLender() external {
        vm.expectRevert("ML:IL:NOT_LENDER");
        loan.impairLoan();
    }

    function test_impairLoan_alreadyImpaired() external {
        vm.prank(address(poolDelegate));
        poolManager.impairLoan(address(loan));

        vm.prank(address(poolDelegate));
        vm.expectRevert("LM:IL:ALREADY_IMPAIRED");
        poolManager.impairLoan(address(loan));
    }

}
