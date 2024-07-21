// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IFixedTermLoan, IOpenTermLoan } from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract AcceptLoanTermsTestBase is TestBaseWithAssertions {
    
    uint32 constant gracePeriod     = 5 days;
    uint32 constant noticePeriod    = 100_000 seconds;
    uint32 constant paymentInterval = 1_000_000 seconds;

    uint64 constant interestRate = 0.031536e6;

    uint256 constant principal = 1_000_000e6;

    address borrower;
    address loan;
    address lp;

    function setUp() public virtual override {
        super.setUp();

        borrower = makeAddr("borrower");
        lp       = makeAddr("lp");

        deposit(lp, 1_500_000e6);
    }

}

contract AcceptLoanTermsOTLTests is AcceptLoanTermsTestBase {

    function setUp() public override {
        super.setUp();

        address loanManager = poolManager.loanManagerList(1);

        loan = createOpenTermLoan(
            address(borrower),
            address(loanManager),
            address(fundsAsset),
            principal,
            [gracePeriod, noticePeriod, paymentInterval],
            [0.031536e6, interestRate, 0, 0.15768e6]
        );

    }

    function test_acceptLoanTerms_OTL_failIfPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);
        
        vm.expectRevert("ML:PAUSED");
        vm.prank(borrower);
        IOpenTermLoan(loan).acceptLoanTerms();
    }

    function test_acceptLoanTerms_OTL_failIfNotBorrower() external {
        vm.expectRevert("ML:NOT_BORROWER");
        IOpenTermLoan(loan).acceptLoanTerms();
    }

    function test_acceptLoanTerms_OTL_failIfAlreadyAccepted() external {
        vm.prank(borrower);
        IOpenTermLoan(loan).acceptLoanTerms();

        vm.expectRevert("ML:ALT:ALREADY_ACCEPTED");
        vm.prank(borrower);
        IOpenTermLoan(loan).acceptLoanTerms();
    }

    function test_acceptLoanTerms_OTL_success() external {
        assertTrue(!IOpenTermLoan(loan).loanTermsAccepted());

        vm.prank(borrower);
        IOpenTermLoan(loan).acceptLoanTerms();

        assertTrue(IOpenTermLoan(loan).loanTermsAccepted());
    }

}

contract AcceptLoanTermsFTLTests is AcceptLoanTermsTestBase {

    function setUp() public override {
        super.setUp();

        address loanManager = poolManager.loanManagerList(0);

        loan = createFixedTermLoan({
            borrower:   address(borrower),
            lender:     address(loanManager),
            feeManager: address(fixedTermFeeManager),
            assets:     [address(collateralAsset), address(fundsAsset)],
            terms:      [uint256(gracePeriod), uint256(paymentInterval), uint256(3)],
            amounts:    [uint256(0), uint256(principal), uint256(principal)],
            rates:      [uint256(interestRate), uint256(0), uint256(0), uint256(0)],
            fees:       [uint256(0), uint256(0)]
        });

    }

    function test_acceptLoanTerms_FTL_failIfPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);
        
        vm.expectRevert("L:PAUSED");
        vm.prank(borrower);
        IFixedTermLoan(loan).acceptLoanTerms();
    }

    function test_acceptLoanTerms_FTL_failIfNotBorrower() external {
        vm.expectRevert("ML:NOT_BORROWER");
        IFixedTermLoan(loan).acceptLoanTerms();
    }

    function test_acceptLoanTerms_FTL_failIfAlreadyAccepted() external {
        vm.prank(borrower);
        IOpenTermLoan(loan).acceptLoanTerms();

        vm.expectRevert("ML:ALT:ALREADY_ACCEPTED");
        vm.prank(borrower);
        IOpenTermLoan(loan).acceptLoanTerms();
    }

    function test_acceptLoanTerms_FTL_success() external {
        assertTrue(!IFixedTermLoan(loan).loanTermsAccepted());

        vm.prank(borrower);
        IFixedTermLoan(loan).acceptLoanTerms();

        assertTrue(IFixedTermLoan(loan).loanTermsAccepted());
    }

}
