// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IOpenTermLoan,
    IOpenTermLoanManager,
    IProxyFactoryLike
} from "../../../contracts/interfaces/Interfaces.sol";

import { FakeLoan } from "../../mocks/Mocks.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract OpenTermLoanManagerFundTests is TestBaseWithAssertions {

    address borrower = makeAddr("borrower");
    address lp       = makeAddr("lp");

    uint256 gracePeriod     = 5 days;
    uint256 noticePeriod    = 5 days;
    uint256 paymentInterval = 30 days;

    uint256 cover        = 100_000e6;
    uint256 interestRate = 0.1e6;
    uint256 principal    = 1_500_000e6;

    uint256 delegateServiceFeeRate    = 0.03e6;
    uint256 delegateManagementFeeRate = 0.02e6;
    uint256 platformServiceFeeRate    = 0.04e6;
    uint256 platformManagementFeeRate = 0.08e6;

    IOpenTermLoan        loan;
    IOpenTermLoanManager loanManager;

    function setUp() public override {
        _setupPoolWithCyclicalWM();

        vm.startPrank(governor);
        globals.setPlatformServiceFeeRate(address(poolManager), platformServiceFeeRate);
        globals.setPlatformManagementFeeRate(address(poolManager), platformManagementFeeRate);
        vm.stopPrank();

        setDelegateManagementFeeRate(address(poolManager), delegateManagementFeeRate);

        loanManager = IOpenTermLoanManager(poolManager.strategyList(0));
        loan = IOpenTermLoan(createOpenTermLoan(
            openTermLoanFactory,
            borrower,
            address(loanManager),
            address(fundsAsset),
            principal,
            [uint256(gracePeriod), uint256(noticePeriod), uint256(paymentInterval)],
            [uint256(delegateServiceFeeRate), uint256(interestRate), 0, 0]
        ));
    }

    function test_fund_protocolPause() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("LM:PAUSED");
        loanManager.fund(address(loan));
    }

    function test_fund_notPoolDelegate() external {
        vm.expectRevert("LM:NOT_PD");
        loanManager.fund(address(loan));
    }

    function test_fund_invalidLoanFactory() external {
        vm.prank(governor);
        globals.setValidInstanceOf("OT_LOAN_FACTORY", openTermLoanFactory, false);

        vm.prank(poolDelegate);
        vm.expectRevert("LM:F:INVALID_LOAN_FACTORY");
        loanManager.fund(address(loan));
    }

    function test_fund_invalidLoanInstance() external {
        FakeLoan fakeLoan = new FakeLoan();

        fakeLoan.__setFactory(address(openTermLoanFactory));

        vm.prank(poolDelegate);
        vm.expectRevert("LM:F:INVALID_LOAN_INSTANCE");
        loanManager.fund(address(fakeLoan));
    }

    function test_fund_invalidBorrower() external {
        vm.prank(governor);
        globals.setValidBorrower(borrower, false);

        vm.prank(poolDelegate);
        vm.expectRevert("LM:F:INVALID_BORROWER");
        loanManager.fund(address(loan));
    }

    function test_fund_loanNotActive() external {
        deposit(address(pool), lp, 2 * principal);

        vm.prank(borrower);
        loan.acceptLoanTerms();

        vm.prank(poolDelegate);
        loanManager.fund(address(loan));

        vm.warp(start + paymentInterval + gracePeriod + 1 seconds);

        vm.prank(poolDelegate);
        poolManager.triggerDefault(address(loan), address(liquidatorFactory));

        vm.prank(poolDelegate);
        vm.expectRevert("LM:F:LOAN_NOT_ACTIVE");
        loanManager.fund(address(loan));
    }

    function test_fund_invalidLoanManagerFactory() external {
        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_FACTORY", openTermLoanManagerFactory, false);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:RF:INVALID_FACTORY");
        loanManager.fund(address(loan));
    }

    function test_fund_notLoanManager() external {
        vm.prank(address(poolManager));
        IOpenTermLoanManager fakeLoanManager = IOpenTermLoanManager(
            IProxyFactoryLike(openTermLoanManagerFactory).createInstance(
                abi.encode(address(poolManager)),
                "SALT"
            )
        );

        vm.prank(poolDelegate);
        vm.expectRevert("PM:RF:NOT_STRATEGY");
        fakeLoanManager.fund(address(loan));
    }

    function test_fund_zeroSupply() external {
        deposit(address(pool), lp, principal);
        requestRedeem(address(pool), lp, pool.balanceOf(lp));

        vm.warp(start + 2 weeks);

        redeem(address(pool), lp, cyclicalWM.lockedShares(lp));

        vm.prank(poolDelegate);
        vm.expectRevert("PM:RF:ZERO_SUPPLY");
        loanManager.fund(address(loan));
    }

    function test_fund_insufficientCover() external {
        deposit(address(pool), lp, principal);

        vm.prank(governor);
        globals.setMinCoverAmount(address(poolManager), cover);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:RF:INSUFFICIENT_COVER");
        loanManager.fund(address(loan));
    }

    function test_fund_poolManagerTransferFailure() external {
        deposit(address(pool), lp, principal / 2);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:RF:TRANSFER_FAIL");
        loanManager.fund(address(loan));
    }

    function test_fund_lockedLiquidity() external {
        deposit(address(pool), lp, principal);

        requestRedeem(address(pool), lp, pool.balanceOf(lp));

        vm.warp(start + 2 weeks);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:RF:LOCKED_LIQUIDITY");
        loanManager.fund(address(loan));
    }

    function test_fund_loanManagerApproveFailure() external {
        deposit(address(pool), lp, principal);

        fundsAsset.__failWhenCalledBy(address(loanManager));

        vm.prank(poolDelegate);
        vm.expectRevert("LM:PFFL:APPROVE_FAILED");
        loanManager.fund(address(loan));
    }

    function test_fund_notLender() external {
        vm.expectRevert("ML:NOT_LENDER");
        loan.fund();
    }

    function test_fund_failIfTermsNotAccepted() external {
        deposit(address(pool), lp, principal);

        vm.prank(poolDelegate);
        vm.expectRevert("ML:F:TERMS_NOT_ACCEPTED");
        loanManager.fund(address(loan));
    }

    function test_fund_loanActive() external {
        deposit(address(pool), lp, 2 * principal);

        vm.prank(borrower);
        loan.acceptLoanTerms();

        vm.prank(poolDelegate);
        loanManager.fund(address(loan));

        vm.prank(poolDelegate);
        vm.expectRevert("ML:F:LOAN_ACTIVE");
        loanManager.fund(address(loan));
    }

    function test_fund_loanTransferFailure() external {
        deposit(address(pool), lp, principal);

        vm.prank(borrower);
        loan.acceptLoanTerms();

        fundsAsset.__failWhenCalledBy(address(loan));

        vm.prank(poolDelegate);
        vm.expectRevert("ML:F:TRANSFER_FROM_FAILED");
        loanManager.fund(address(loan));
    }

    function test_fund_success() external {
        uint256 interest       = principal * interestRate * paymentInterval / 365 days / 1e6;
        uint256 managementFees = interest * (delegateManagementFeeRate + platformManagementFeeRate) / 1e6;
        uint256 issuanceRate   = (interest - managementFees) * 1e27 / paymentInterval;

        deposit(address(pool), lp, principal);

        vm.prank(borrower);
        loan.acceptLoanTerms();

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       0,
            issuanceRate:      0,
            accountedInterest: 0,
            accruedInterest:   0,
            principalOut:      0,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            delegateFeeRate: 0,
            platformFeeRate: 0,
            startDate:       0,
            issuanceRate:    0
        });

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      0,
            dateFunded:      0,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal
        });

        vm.prank(poolDelegate);
        loanManager.fund(address(loan));

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       block.timestamp,
            issuanceRate:      issuanceRate,
            accountedInterest: 0,
            accruedInterest:   0,
            principalOut:      principal,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            delegateFeeRate: delegateManagementFeeRate,
            platformFeeRate: platformManagementFeeRate,
            startDate:       block.timestamp,
            issuanceRate:    issuanceRate
        });

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      0,
            dateFunded:      block.timestamp,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal
        });
    }

}
