// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IOpenTermLoan, IOpenTermLoanManager } from "../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

contract RemoveCallTestsBase is TestBaseWithAssertions {

    address borrower = makeAddr("borrower");
    address lp       = makeAddr("lp");

    uint256 constant delegateServiceFeeRate    = 0.03e6;
    uint256 constant delegateManagementFeeRate = 0.02e6;
    uint256 constant gracePeriod               = 5 days;
    uint256 constant interestRate              = 0.1e6;
    uint256 constant noticePeriod              = 5 days;
    uint256 constant paymentInterval           = 30 days;
    uint256 constant platformManagementFeeRate = 0.08e6;
    uint256 constant platformServiceFeeRate    = 0.04e6;
    uint256 constant principal                 = 1_500_000e6;

    IOpenTermLoan        loan;
    IOpenTermLoanManager loanManager;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(governor);
        globals.setValidBorrower(borrower, true);
        globals.setPlatformServiceFeeRate(address(poolManager)   , platformServiceFeeRate);
        globals.setPlatformManagementFeeRate(address(poolManager), platformManagementFeeRate);
        vm.stopPrank();

        setDelegateManagementFeeRate(address(poolManager), delegateManagementFeeRate);

        deposit(lp, 1_500_000e6);

        loanManager = IOpenTermLoanManager(poolManager.loanManagerList(1));

        loan = IOpenTermLoan(createOpenTermLoan(
            borrower,
            address(loanManager),
            address(fundsAsset),
            principal,
            [uint32(gracePeriod), uint32(noticePeriod), uint32(paymentInterval)],
            [uint64(delegateServiceFeeRate), uint64(interestRate), 0, uint64(interestRate)]
        ));

        fundLoan(address(loan));
    }

}

contract RemoveCallFailureTests is RemoveCallTestsBase {

    function setUp() public virtual override {
        super.setUp();
    }

    function test_callPrincipal_paused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("LM:PAUSED");
        loanManager.removeCall(address(loan));
    }

    function test_callPrincipal_notPoolDelegate() external {
        vm.expectRevert("LM:RC:NOT_PD");
        loanManager.removeCall(address(loan));
    }

    function test_callPrincipal_notLender() external {
        vm.expectRevert("ML:RC:NOT_LENDER");
        loan.removeCall();
    }

    function test_callPrincipal_notCalled() external {
        vm.prank(poolDelegate);
        vm.expectRevert("ML:RC:NOT_CALLED");
        loanManager.removeCall(address(loan));
    }

}

contract RemoveCallTests is RemoveCallTestsBase {

    uint256 constant interest       = principal * interestRate * paymentInterval / 365 days / 1e6;
    uint256 constant managementFees = interest * (delegateManagementFeeRate + platformManagementFeeRate) / 1e6;
    uint256 constant issuanceRate   = (interest - managementFees) * 1e27 / paymentInterval;

    uint256 callTimestamp;

    function setUp() public virtual override {
        super.setUp();

        callTimestamp  = start + paymentInterval / 2;

        vm.warp(callTimestamp);

        callLoan(address(loan), principal);

        uint256 accruedInterest = (issuanceRate * (block.timestamp - start)) / 1e27;

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       start,
            issuanceRate:      issuanceRate,
            accountedInterest: 0,
            accruedInterest:   accruedInterest,
            principalOut:      principal,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            platformFeeRate: platformManagementFeeRate,
            delegateFeeRate: delegateManagementFeeRate,
            startDate:       start,
            issuanceRate:    issuanceRate
        });

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      callTimestamp,
            dateFunded:      start,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: principal,
            principal:       principal
        });

        assertEq(loan.paymentDueDate(), callTimestamp + noticePeriod);
    }

    function test_removeCall_paymentOnTime() external {
        uint256 removeCallTimestamp = callTimestamp + 1 days;
        vm.warp(removeCallTimestamp);

        removeLoanCall(address(loan));

        uint256 accruedInterest = (issuanceRate * (block.timestamp - start)) / 1e27;

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       start,
            issuanceRate:      issuanceRate,
            accountedInterest: 0,
            accruedInterest:   accruedInterest,
            principalOut:      principal,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            platformFeeRate: platformManagementFeeRate,
            delegateFeeRate: delegateManagementFeeRate,
            startDate:       start,
            issuanceRate:    issuanceRate
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

        assertEq(loan.paymentDueDate(), start + paymentInterval);
    }

    function test_removeCall_latePayment() external {
        uint256 removeCallTimestamp = start + paymentInterval + gracePeriod + 1 days;
        vm.warp(removeCallTimestamp);

        removeLoanCall(address(loan));

        uint256 accruedInterest = (issuanceRate * (block.timestamp - start)) / 1e27;

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       start,
            issuanceRate:      issuanceRate,
            accountedInterest: 0,
            accruedInterest:   accruedInterest,
            principalOut:      principal,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            platformFeeRate: platformManagementFeeRate,
            delegateFeeRate: delegateManagementFeeRate,
            startDate:       start,
            issuanceRate:    issuanceRate
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

        assertEq(loan.paymentDueDate(), start + paymentInterval);
    }

    function test_removeCall_impaired() external {
        uint256 impairmentTimestamp = callTimestamp + 1 days;

        vm.warp(impairmentTimestamp);

        impairLoan(address(loan));

        uint256 accruedInterest = (issuanceRate * (block.timestamp - start)) / 1e27;

        assertPoolState({
            totalSupply:        1_500_000e6,  // Same as initial deposit
            totalAssets:        principal + accruedInterest,
            unrealizedLosses:   principal + accruedInterest,
            availableLiquidity: 0
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       impairmentTimestamp,
            issuanceRate:      0,
            accountedInterest: accruedInterest,
            accruedInterest:   0,
            principalOut:      principal,
            unrealizedLosses:  principal + accruedInterest
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            platformFeeRate: platformManagementFeeRate,
            delegateFeeRate: delegateManagementFeeRate,
            startDate:       start,
            issuanceRate:    issuanceRate
        });

        assertImpairment({
            loan:               address(loan),
            impairedDate:       impairmentTimestamp,
            impairedByGovernor: false
        });

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      callTimestamp,
            dateFunded:      start,
            dateImpaired:    impairmentTimestamp,
            datePaid:        0,
            calledPrincipal: principal,
            principal:       principal
        });

        assertEq(loan.paymentDueDate(), impairmentTimestamp);

        uint256 removeCallTimestamp = impairmentTimestamp + 1 days;

        vm.warp(removeCallTimestamp);

        removeLoanCall(address(loan));

        assertPoolState({
            totalSupply:        1_500_000e6,  // Same as initial deposit
            totalAssets:        principal + accruedInterest,
            unrealizedLosses:   principal + accruedInterest,
            availableLiquidity: 0
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       impairmentTimestamp,
            issuanceRate:      0,
            accountedInterest: accruedInterest,
            accruedInterest:   0,
            principalOut:      principal,
            unrealizedLosses:  principal + accruedInterest
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            platformFeeRate: platformManagementFeeRate,
            delegateFeeRate: delegateManagementFeeRate,
            startDate:       start,
            issuanceRate:    issuanceRate
        });

        assertImpairment({
            loan:               address(loan),
            impairedDate:       impairmentTimestamp,
            impairedByGovernor: false
        });

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    impairmentTimestamp,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal
        });
    }

}
