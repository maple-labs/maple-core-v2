// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IFixedTermLoan, IFixedTermLoanManager } from "../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../TestBase.sol";

contract RemoveLoanImpairmentFailureTests is TestBase {

    IFixedTermLoan        loan;
    IFixedTermLoanManager loanManager;

    function setUp() public virtual override {
        super.setUp();

        deposit(makeAddr("depositor"), 1_500_000e6);

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         275e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.0066e6,
            platformManagementFeeRate:  0.08e6
        });

        loanManager = IFixedTermLoanManager(poolManager.loanManagerList(0));

        loan = IFixedTermLoan(fundAndDrawdownLoan({
            borrower:    makeAddr("borrower"),
            termDetails: [uint256(5 days), uint256(30 days), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.075e6), uint256(0), uint256(0), uint256(0)],
            loanManager: address(loanManager)
        }));
    }

    function test_removeLoanImpairment_notAuthorized() external {
        vm.expectRevert("LM:RLI:NO_AUTH");
        loanManager.removeLoanImpairment(address(loan));
    }

    function test_removeLoanImpairment_notGovernor() external {
        vm.prank(governor);
        loanManager.impairLoan(address(loan));

        vm.prank(poolDelegate);
        vm.expectRevert("LM:RLI:NO_AUTH");
        loanManager.removeLoanImpairment(address(loan));
    }

    function test_removeLoanImpairment_notLender() external {
        vm.expectRevert("ML:RLI:NOT_LENDER");
        loan.removeLoanImpairment();
    }

    function test_removeLoanImpairment_notImpaired() external {
        vm.prank(poolDelegate);
        vm.expectRevert("LM:RLI:PAST_DATE");
        loanManager.removeLoanImpairment(address(loan));
    }

    function test_removeLoanImpairment_pastDate() external {
        vm.prank(poolDelegate);
        loanManager.impairLoan(address(loan));

        vm.warp(start + 30 days + 1);
        vm.prank(poolDelegate);
        vm.expectRevert("LM:RLI:PAST_DATE");
        loanManager.removeLoanImpairment(address(loan));

        vm.warp(start + 30 days);
        vm.prank(poolDelegate);
        loanManager.removeLoanImpairment(address(loan));
    }

}
