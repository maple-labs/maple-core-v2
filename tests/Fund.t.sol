pragma solidity 0.8.7;

import { TestBaseWithAssertions } from "../contracts/utilities/TestBaseWithAssertions.sol";

import { Address, console } from "../modules/contract-test-utils/contracts/test.sol";

import { MapleLoan as Loan } from "../modules/loan/contracts/MapleLoan.sol";

contract FundFailureTests is TestBaseWithAssertions {

    address borrower;
    address lp;

    Loan loan;

    function setUp() public override {
        super.setUp();

        borrower = address(new Address());
        lp       = address(new Address());

        depositLiquidity(lp, 1_500_000e6);

        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,  // 10k after 1m seconds
            platformManagementFeeRate:  0.08e6
        });

        loan = createLoan({
            borrower:    borrower,
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_500_000e6), uint256(1_500_000e6)],
            rates:       [uint256(3.1536e18), uint256(0), uint256(0), uint256(0)]
        });
    }

    function test_fund_failIfProtocolIsPaused() external {
        vm.prank(globals.securityAdmin());
        globals.setProtocolPause(true);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.fund(uint256(1_500_000e6), address(loan), address(loanManager));
    }

    function test_fund_failIfNotPoolDelegate() external {
        vm.expectRevert("PM:F:NOT_PD");
        poolManager.fund(uint256(1_500_000e6), address(loan), address(loanManager));
    }

    function test_fund_failIfInvalidLoanManager() external {
        vm.prank(poolDelegate);
        vm.expectRevert("PM:F:INVALID_LOAN_MANAGER");
        poolManager.fund(uint256(1_500_000e6), address(loan), address(1));
    }

    function test_fund_failIfInvalidBorrower() external {
        vm.prank(governor);
        globals.setValidBorrower(borrower, false);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:F:INVALID_BORROWER");
        poolManager.fund(uint256(1_500_000e6), address(loan), address(loanManager));
    }

    function test_fund_failIfTotalSupplyIsZero() external {
        // Burn the supply
        vm.startPrank(lp);
        pool.requestRedeem(1_500_000e6);

        vm.warp(start + 2 weeks);

        pool.redeem(1_500_000e6, address(lp), address(lp));
        vm.stopPrank();

        vm.prank(poolDelegate);
        vm.expectRevert("PM:F:ZERO_SUPPLY");
        poolManager.fund(uint256(1_500_000e6), address(loan), address(loanManager));
    }

    function test_fund_failIfInssuficientCover() external {
        vm.prank(governor);
        globals.setMinCoverAmount(address(poolManager), 1e6);

        fundsAsset.mint(address(poolManager.poolDelegateCover()), 1e6 - 1);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:F:INSUFFICIENT_COVER");
        poolManager.fund(uint256(1_500_000e6), address(loan), address(loanManager));
    }

    function test_fund_failIfPrincipalIsGreaterThanAssetBalance() external {
        vm.prank(poolDelegate);
        vm.expectRevert("PM:F:TRANSFER_FAIL");
        poolManager.fund(uint256(1_500_000e6 + 1), address(loan), address(loanManager));
    }

    function test_fund_failIfPoolDoesNotApprovePM() external {
        // It's impossible to happen with current contracts, but testing here for completeness
        vm.prank(address(pool));
        fundsAsset.approve(address(poolManager), 0);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:F:TRANSFER_FAIL");
        poolManager.fund(uint256(1_000_000e6), address(loan), address(loanManager));
    }

    function test_fund_failIfAmountGreaterThanLockedLiquidity() external {
        loan = createLoan({
            borrower:    borrower,
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e18), uint256(0), uint256(0), uint256(0)]
        });

        // Lock the liquidity
        vm.prank(lp);
        pool.requestRedeem(500_000e6 + 1);

        vm.warp(start + 2 weeks);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:F:LOCKED_LIQUIDITY");
        poolManager.fund(uint256(1_000_000e6), address(loan), address(loanManager));

        vm.prank(lp);
        pool.removeShares(1);  // Remove so exactly 500k is locked.

        vm.warp(start + 4 weeks);

        vm.prank(poolDelegate);
        poolManager.fund(uint256(1_000_000e6), address(loan), address(loanManager));
    }

    function test_fund_failIfNotPoolManager() external {
        vm.expectRevert("LM:F:NOT_POOL_MANAGER");
        loanManager.fund(address(loan));
    }

    function test_fund_failIfLoanActive() external {
        depositLiquidity(lp, 1_500_000e6);  // Deposit again

        vm.prank(poolDelegate);
        poolManager.fund(uint256(1_500_000e6), address(loan), address(loanManager));

        vm.prank(poolDelegate);
        vm.expectRevert("ML:FL:LOAN_ACTIVE");
        poolManager.fund(uint256(1_500_000e6), address(loan), address(loanManager));
    }

    function test_fund_failWithExcessFunds() external {
        depositLiquidity(lp, 1);  // Deposit again

        vm.prank(poolDelegate);
        vm.expectRevert("ML:FL:UNEXPECTED_FUNDS");
        poolManager.fund(uint256(1_500_000e6 + 1), address(loan), address(loanManager));
    }

    function test_fund_failWithLessFundsThanRequested() external {
        vm.prank(poolDelegate);
        vm.expectRevert(ARITHMETIC_ERROR);
        poolManager.fund(uint256(1_500_000e6 - 1), address(loan), address(loanManager));
    }

}
