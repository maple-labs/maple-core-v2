// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IOpenTermLoan, IOpenTermLoanManager } from "../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

contract CallPrincipalTestsBase is TestBaseWithAssertions {

    address borrower = makeAddr("borrower");
    address lp       = makeAddr("lp");

    uint256 constant delegateServiceFeeRate    = 0.03e6;
    uint256 constant delegateManagementFeeRate = 0.02e6;
    uint256 constant gracePeriod               = 5 days;
    uint256 constant interestRate              = 0.1e6;
    uint256 constant lateInterestPremiumRate   = 0.05e6;
    uint256 constant noticePeriod              = 5 days;
    uint256 constant paymentInterval           = 30 days;
    uint256 constant platformManagementFeeRate = 0.08e6;
    uint256 constant platformServiceFeeRate    = 0.04e6;
    uint256 constant principal                 = 1_500_000e6;

    uint256 constant interest       = principal * interestRate * paymentInterval / 365 days / 1e6;
    uint256 constant managementFees = interest * (delegateManagementFeeRate + platformManagementFeeRate) / 1e6;
    uint256 constant issuanceRate   = (interest - managementFees) * 1e27 / paymentInterval;

    IOpenTermLoan        loan;
    IOpenTermLoanManager loanManager;

    function setUp() public virtual override {
        super.setUp();

        vm.startPrank(governor);
        globals.setPlatformServiceFeeRate(address(poolManager), platformServiceFeeRate);
        globals.setPlatformManagementFeeRate(address(poolManager), platformManagementFeeRate);
        vm.stopPrank();

        setDelegateManagementFeeRate(address(poolManager), delegateManagementFeeRate);

        deposit(lp, 1_500_000e6);

        loanManager = IOpenTermLoanManager(poolManager.loanManagerList(1));

        loan = IOpenTermLoan(createOpenTermLoan(
            openTermLoanFactory,
            borrower,
            address(loanManager),
            address(fundsAsset),
            principal,
            [uint256(gracePeriod), uint256(noticePeriod), uint256(paymentInterval)],
            [uint256(delegateServiceFeeRate), uint256(interestRate), 0, uint256(lateInterestPremiumRate)]
        ));
    }

}

contract CallPrincipalFailureTests is CallPrincipalTestsBase {

    function test_callPrincipal_paused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("LM:PAUSED");
        loanManager.callPrincipal(address(loan), principal);
    }

    function test_callPrincipal_notPoolDelegate() external {
        vm.expectRevert("LM:NOT_PD");
        loanManager.callPrincipal(address(loan), principal);
    }

    function test_callPrincipal_notLender() external {
        vm.expectRevert("ML:NOT_LENDER");
        loan.callPrincipal(principal);
    }

    function test_callPrincipal_loanActive() external {
        vm.prank(poolDelegate);
        vm.expectRevert("ML:C:LOAN_INACTIVE");
        loanManager.callPrincipal(address(loan), principal);
    }

    function test_callPrincipal_invalidAmount_boundary() external {
        fundLoan(address(loan));

        vm.expectRevert("ML:C:INVALID_AMOUNT");
        vm.prank(poolDelegate);
        loanManager.callPrincipal(address(loan), principal + 1);

        vm.expectRevert("ML:C:INVALID_AMOUNT");
        vm.prank(poolDelegate);
        loanManager.callPrincipal(address(loan), 0);

        vm.prank(poolDelegate);
        loanManager.callPrincipal(address(loan), principal);
    }

}

contract CallPrincipalTests is CallPrincipalTestsBase {

    function setUp() public override {
        super.setUp();

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
        assertEq(loan.defaultDate(),    start + paymentInterval + gracePeriod);
    }

    function test_callPrincipal_paymentOnTime() external {
        uint256 callTimestamp = start + paymentInterval / 2;

        /*****************************************/
        /*** Call Principal mid paymentDueDate ***/
        /*****************************************/

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
        assertEq(loan.defaultDate(),    callTimestamp + noticePeriod);
    }

    function test_callPrincipal_latePayment() external {
        uint256 callTimestamp = start + paymentInterval * 2;

        /******************************************/
        /*** Call Principal 2x payment Interval ***/
        /******************************************/

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

        // NOTE: Payment due date is the shortest timestamp in this case the original payment due date
        assertEq(loan.paymentDueDate(), start + paymentInterval);
        assertEq(loan.defaultDate(),    start + paymentInterval + gracePeriod);
    }

    function test_callPrincipal_impaired() external {
        /***************************************/
        /*** Impair loan mid paymentDueDate ***/
        /**************************************/

        uint256 impairmentTimestamp = start + paymentInterval / 2;

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
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    impairmentTimestamp,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal
        });

        /****************************************/
        /*** Call loan 1 day after impairment ***/
        /****************************************/

        uint256 callTimestamp = start + paymentInterval / 2 + 1 days;

        vm.warp(callTimestamp);

        callLoan(address(loan), principal);

        assertPoolState({
            totalSupply:        1_500_000e6,  // Same as initial deposit
            totalAssets:        principal + accruedInterest,  // Interest has stopped accruing because of impairment
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

        // NOTE: Payment due date is the shortest timestamp in this case the impairment date
        assertEq(loan.paymentDueDate(), impairmentTimestamp);
        assertEq(loan.defaultDate(),    impairmentTimestamp + gracePeriod);
    }

    function test_callPrincipal_notFullPrincipal() external {
        uint256 callTimestamp = start + paymentInterval / 2;

        /**********************************************/
        /*** Call half Principal mid paymentDueDate ***/
        /**********************************************/

        vm.warp(callTimestamp);

        callLoan(address(loan), principal / 2);

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
            calledPrincipal: principal / 2,
            principal:       principal
        });

        assertEq(loan.paymentDueDate(), callTimestamp + noticePeriod);
        assertEq(loan.defaultDate(),    callTimestamp + noticePeriod);
    }

}
