// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IOpenTermLoan, IOpenTermLoanManager } from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract OpenTermLoanManagerImpairTests is TestBaseWithAssertions {

    address borrower = makeAddr("borrower");
    address lp       = makeAddr("lp");

    uint256 constant gracePeriod     = 5 days;
    uint256 constant noticePeriod    = 5 days;
    uint256 constant paymentInterval = 30 days;

    uint256 constant principal = 2_500_000e6;

    uint256 constant interestRate        = 0.115e6; // 11.5%
    uint256 constant lateFeeRate         = 0.02e6; // 2%
    uint256 constant lateInterestPremium = 0.045e6; // 4.5%

    uint256 constant delegateServiceFeeRate    = 0.03e6; // 3%
    uint256 constant delegateManagementFeeRate = 0.02e6; // 2%
    uint256 constant platformServiceFeeRate    = 0.043e6; // 4.3%
    uint256 constant platformManagementFeeRate = 0.057e6; // 5.7%

    uint256 constant interest       = principal * interestRate * paymentInterval / 365 days / 1e6;
    uint256 constant managementFees = interest * (delegateManagementFeeRate + platformManagementFeeRate) / 1e6;
    uint256 constant issuanceRate   = (interest - managementFees) * 1e27 / paymentInterval;

    IOpenTermLoan loan;
    IOpenTermLoanManager loanManager;

    function setUp() public override {
        super.setUp();

        vm.startPrank(governor);
        globals.setPlatformServiceFeeRate(address(poolManager), platformServiceFeeRate);
        globals.setPlatformManagementFeeRate(address(poolManager), platformManagementFeeRate);
        vm.stopPrank();

        setDelegateManagementFeeRate(address(poolManager), delegateManagementFeeRate);

        loanManager = IOpenTermLoanManager(poolManager.strategyList(0));
        loan = IOpenTermLoan(
            createOpenTermLoan(
                openTermLoanFactory,
                borrower,
                address(loanManager),
                address(fundsAsset),
                principal,
                [uint256(gracePeriod), uint256(noticePeriod), uint256(paymentInterval)],
                [uint256(delegateServiceFeeRate), uint256(interestRate), uint256(lateFeeRate), uint256(lateInterestPremium)]
            )
        );

        deposit(address(pool), lp, principal);
        fundLoan(address(loan));
    }

    function test_impairLoan_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("LM:PAUSED");
        loanManager.impairLoan(address(loan));
    }

    function test_impairLoan_notAuthorized() external {
        vm.expectRevert("LM:IL:NO_AUTH");
        loanManager.impairLoan(address(loan));
    }

    function test_impairLoan_loanInactive() external {
        vm.warp(start + paymentInterval + gracePeriod + 1 seconds);
        vm.prank(poolDelegate);
        poolManager.triggerDefault(address(loan));

        vm.expectRevert("LM:NOT_LOAN");
        vm.prank(poolDelegate);
        loanManager.impairLoan(address(loan));
    }

    function test_impairLoan_notLoanContract() external {
        vm.expectRevert();
        vm.prank(poolDelegate);
        loanManager.impairLoan(address(1));
    }

    function test_impairLoan_notLoanInLoanManager() external {
        address unfundedLoan = createOpenTermLoan(
            address(borrower),
            address(loanManager),
            address(fundsAsset),
            principal + 1, // Different salt
            [uint32(gracePeriod), uint32(noticePeriod), uint32(paymentInterval)],
            [uint64(delegateServiceFeeRate), uint64(interestRate), uint64(lateFeeRate), uint64(lateInterestPremium)]
        );

        vm.expectRevert("LM:NOT_LOAN");
        vm.prank(poolDelegate);
        loanManager.impairLoan(unfundedLoan);
    }

    function test_impairLoan_notLender() external {
        vm.expectRevert("ML:NOT_LENDER");
        loan.impair();
    }

    function test_impairLoan_governorAcl() external {
        vm.prank(governor);
        loanManager.impairLoan(address(loan));
    }

    function test_impairLoan_early() external {
        vm.warp(start + paymentInterval / 4);

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       start,
            issuanceRate:      issuanceRate,
            accountedInterest: 0,
            accruedInterest:   issuanceRate * paymentInterval / 4 / 1e27,
            principalOut:      principal,
            unrealizedLosses:  0
        });

        assertImpairment({
            loan:               address(loan),
            impairedDate:       0,
            impairedByGovernor: false
        });

        assertOpenTermPaymentInfo({
            loan:         address(loan),
            startDate:    start,
            issuanceRate: issuanceRate
        });

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal
        });

        vm.prank(poolDelegate);
        loanManager.impairLoan(address(loan));

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       start + paymentInterval / 4,
            issuanceRate:      0,
            accountedInterest: issuanceRate * paymentInterval / 4 / 1e27,
            accruedInterest:   0,
            principalOut:      principal,
            unrealizedLosses:  principal + issuanceRate * paymentInterval / 4 / 1e27
        });

        assertImpairment({
            loan:               address(loan),
            impairedDate:       start + paymentInterval / 4,
            impairedByGovernor: false
        });

        assertOpenTermPaymentInfo({
            loan:         address(loan),
            startDate:    start,
            issuanceRate: issuanceRate
        });

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    start + paymentInterval / 4,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal
        });
    }

    function test_impairLoan_late() external {
        vm.warp(start + paymentInterval * 5 / 4);

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       start,
            issuanceRate:      issuanceRate,
            accountedInterest: 0,
            accruedInterest:   issuanceRate * paymentInterval * 5 / 4 / 1e27,
            principalOut:      principal,
            unrealizedLosses:  0
        });

        assertImpairment({
            loan:               address(loan),
            impairedDate:       0,
            impairedByGovernor: false
        });

        assertOpenTermPaymentInfo({
            loan:         address(loan),
            startDate:    start,
            issuanceRate: issuanceRate
        });

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal
        });

        vm.prank(poolDelegate);
        loanManager.impairLoan(address(loan));

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       start + paymentInterval * 5 / 4,
            issuanceRate:      0,
            accountedInterest: issuanceRate * paymentInterval * 5 / 4 / 1e27,
            accruedInterest:   0,
            principalOut:      principal,
            unrealizedLosses:  principal + issuanceRate * paymentInterval * 5 / 4 / 1e27
        });

        assertImpairment({
            loan:               address(loan),
            impairedDate:       start + paymentInterval * 5 / 4,
            impairedByGovernor: false
        });

        assertOpenTermPaymentInfo({
            loan:         address(loan),
            startDate:    start,
            issuanceRate: issuanceRate
        });

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    start + paymentInterval * 5 / 4,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal
        });
    }

}

contract OpenTermLoanManagerRemoveImpairmentTests is TestBaseWithAssertions {

    address borrower = makeAddr("borrower");
    address lp       = makeAddr("lp");

    uint256 constant gracePeriod     = 5 days;
    uint256 constant noticePeriod    = 5 days;
    uint256 constant paymentInterval = 30 days;

    uint256 constant principal = 2_500_000e6;

    uint256 constant interestRate        = 0.115e6; // 11.5%
    uint256 constant lateFeeRate         = 0.02e6; // 2%
    uint256 constant lateInterestPremium = 0.045e6; // 4.5%

    uint256 constant delegateServiceFeeRate    = 0.03e6; // 3%
    uint256 constant delegateManagementFeeRate = 0.02e6; // 2%
    uint256 constant platformServiceFeeRate    = 0.043e6; // 4.3%
    uint256 constant platformManagementFeeRate = 0.057e6; // 5.7%

    uint256 constant interest       = principal * interestRate * paymentInterval / 365 days / 1e6;
    uint256 constant managementFees = interest * (delegateManagementFeeRate + platformManagementFeeRate) / 1e6;
    uint256 constant issuanceRate   = (interest - managementFees) * 1e27 / paymentInterval;

    IOpenTermLoan loan;
    IOpenTermLoanManager loanManager;

    function setUp() public override {
        super.setUp();

        vm.startPrank(governor);
        globals.setPlatformServiceFeeRate(address(poolManager), platformServiceFeeRate);
        globals.setPlatformManagementFeeRate(address(poolManager), platformManagementFeeRate);
        vm.stopPrank();

        setDelegateManagementFeeRate(address(poolManager), delegateManagementFeeRate);

        loanManager = IOpenTermLoanManager(poolManager.strategyList(0));
        loan = IOpenTermLoan(
            createOpenTermLoan(
                openTermLoanFactory,
                borrower,
                address(loanManager),
                address(fundsAsset),
                principal,
                [uint256(gracePeriod), uint256(noticePeriod), uint256(paymentInterval)],
                [uint256(delegateServiceFeeRate), uint256(interestRate), uint256(lateFeeRate), uint256(lateInterestPremium)]
            )
        );

        deposit(address(pool), lp, principal);
        fundLoan(address(loan));

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       start,
            issuanceRate:      issuanceRate,
            accountedInterest: 0,
            accruedInterest:   0,
            principalOut:      principal,
            unrealizedLosses:  0
        });

        assertImpairment({
            loan:               address(loan),
            impairedDate:       0,
            impairedByGovernor: false
        });

        assertOpenTermPaymentInfo({
            loan:         address(loan),
            startDate:    start,
            issuanceRate: issuanceRate
        });

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal
        });
    }

    function test_removeLoanImpairment_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("LM:PAUSED");
        loanManager.removeLoanImpairment(address(loan));
    }

    function test_removeLoanImpairment_notLoan() external {
        vm.prank(poolDelegate);
        vm.expectRevert("LM:NOT_LOAN");
        loanManager.removeLoanImpairment(address(1));
    }

    function test_removeLoanImpairment_notAuthorized() external {
        vm.expectRevert("LM:RLI:NO_AUTH");
        loanManager.removeLoanImpairment(address(loan));
    }

    function test_removeLoanImpairment_poolDelegateAfterGovernor() external {
        vm.prank(governor);
        loanManager.impairLoan(address(loan));

        vm.prank(poolDelegate);
        vm.expectRevert("LM:RLI:NO_AUTH");
        loanManager.removeLoanImpairment(address(loan));
    }

    function test_removeLoanImpairment_notLender() external {
        vm.expectRevert("ML:NOT_LENDER");
        loan.removeImpairment();
    }

    function test_removeLoanImpairment_notImpaired() external {
        vm.prank(poolDelegate);
        vm.expectRevert("ML:RI:NOT_IMPAIRED");
        loanManager.removeLoanImpairment(address(loan));
    }

    function test_removeLoanImpairment_early() external {
        vm.warp(start + paymentInterval / 3);
        vm.prank(poolDelegate);
        loanManager.impairLoan(address(loan));

        vm.warp(start + paymentInterval * 2 / 3);

        assertOpenTermLoanManager({
            loanManager: address(loanManager),
            domainStart: start + paymentInterval / 3,
            issuanceRate: 0,
            accountedInterest: issuanceRate * paymentInterval / 3 / 1e27,
            accruedInterest: 0, // No interest accrued because of IR == 0
            principalOut: principal,
            unrealizedLosses: principal + issuanceRate * paymentInterval / 3 / 1e27
        });

        assertImpairment({
            loan:               address(loan),
            impairedDate:       start + paymentInterval / 3,
            impairedByGovernor: false
        });

        assertOpenTermPaymentInfo({
            loan:         address(loan),
            startDate:    start,
            issuanceRate: issuanceRate
        });

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    start + paymentInterval / 3,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal
        });

        vm.prank(poolDelegate);
        loanManager.removeLoanImpairment(address(loan));

        assertOpenTermLoanManager({
            loanManager: address(loanManager),
            domainStart: start + paymentInterval * 2 / 3,
            issuanceRate: issuanceRate,
            accountedInterest: issuanceRate * paymentInterval * 2 / 3 / 1e27 - 1, // -1 due to rounding error.
            accruedInterest: 0,
            principalOut: principal,
            unrealizedLosses: 0
        });

        assertImpairment({
            loan:               address(loan),
            impairedDate:       0,
            impairedByGovernor: false
        });

        assertOpenTermPaymentInfo({
            loan:         address(loan),
            startDate:    start,
            issuanceRate: issuanceRate
        });

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal
        });
    }

    function test_removeLoanImpairment_late() external {
        vm.warp(start + paymentInterval * 2 / 3);
        vm.prank(poolDelegate);
        loanManager.impairLoan(address(loan));

        vm.warp(start + paymentInterval * 4 / 3);

        assertOpenTermLoanManager({
            loanManager: address(loanManager),
            domainStart: start + paymentInterval * 2 / 3,
            issuanceRate: 0,
            accountedInterest: issuanceRate * paymentInterval * 2 / 3 / 1e27,
            accruedInterest: 0, // No interest accrued because of IR == 0
            principalOut: principal,
            unrealizedLosses: principal + issuanceRate * paymentInterval * 2 / 3 / 1e27
        });

        assertImpairment({
            loan:               address(loan),
            impairedDate:       start + paymentInterval * 2 / 3,
            impairedByGovernor: false
        });

        assertOpenTermPaymentInfo({
            loan:         address(loan),
            startDate:    start,
            issuanceRate: issuanceRate
        });

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    start + paymentInterval * 2 / 3,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal
        });

        vm.prank(poolDelegate);
        loanManager.removeLoanImpairment(address(loan));

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       start + paymentInterval * 4 / 3,
            issuanceRate:      issuanceRate,
            accountedInterest: issuanceRate * paymentInterval * 4 / 3 / 1e27,
            accruedInterest:   0,
            principalOut:      principal,
            unrealizedLosses:  0
        });

        assertImpairment({
            loan:               address(loan),
            impairedDate:       0,
            impairedByGovernor: false
        });

        assertOpenTermPaymentInfo({
            loan:         address(loan),
            startDate:    start,
            issuanceRate: issuanceRate
        });

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal
        });
    }

    function test_removeLoanImpairment_late_withLateImpairment() external {
        vm.warp(start + paymentInterval * 4 / 3);
        vm.prank(poolDelegate);
        loanManager.impairLoan(address(loan));

        vm.warp(start + paymentInterval * 5 / 3);

        assertOpenTermLoanManager({
            loanManager: address(loanManager),
            domainStart: start + paymentInterval * 4 / 3,
            issuanceRate: 0,
            accountedInterest: issuanceRate * paymentInterval * 4 / 3 / 1e27,
            accruedInterest: 0, // No interest accrued because of IR == 0
            principalOut: principal,
            unrealizedLosses: principal + issuanceRate * paymentInterval * 4 / 3 / 1e27
        });

        assertImpairment({
            loan:               address(loan),
            impairedDate:       start + paymentInterval * 4 / 3,
            impairedByGovernor: false
        });

        assertOpenTermPaymentInfo({
            loan:         address(loan),
            startDate:    start,
            issuanceRate: issuanceRate
        });

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    start + paymentInterval * 4 / 3,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal
        });

        vm.prank(poolDelegate);
        loanManager.removeLoanImpairment(address(loan));

        assertOpenTermLoanManager({
            loanManager: address(loanManager),
            domainStart: start + paymentInterval * 5 / 3,
            issuanceRate: issuanceRate,
            accountedInterest: issuanceRate * paymentInterval * 5 / 3 / 1e27 - 1, // -1 due to rounding error.
            accruedInterest: 0,
            principalOut: principal,
            unrealizedLosses: 0
        });

        assertImpairment({
            loan:               address(loan),
            impairedDate:       0,
            impairedByGovernor: false
        });

        assertOpenTermPaymentInfo({
            loan:         address(loan),
            startDate:    start,
            issuanceRate: issuanceRate
        });

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal
        });
    }

}
