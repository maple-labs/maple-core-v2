// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { ILoanManagerLike, IOpenTermLoan, IOpenTermLoanManager } from "../../contracts/interfaces/Interfaces.sol";

import { OpenTermLoan } from "../../contracts/Contracts.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

contract TriggerDefaultFailureTests is TestBaseWithAssertions {

    address loan;

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

        loan = fundAndDrawdownLoan({
            borrower:    makeAddr("borrower"),
            termDetails: [uint256(5 days), uint256(30 days), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.075e6), uint256(0), uint256(0), uint256(0)],
            loanManager: poolManager.loanManagerList(0)
        });
    }

    function test_triggerDefault_notAuthorized() external {
        vm.expectRevert("PM:TD:NOT_AUTHORIZED");
        poolManager.triggerDefault(loan, address(liquidatorFactory));
    }

    function test_triggerDefault_notFactory() external {
        vm.prank(poolDelegate);
        vm.expectRevert("PM:TD:NOT_FACTORY");
        poolManager.triggerDefault(loan, address(1));
    }

    function test_triggerDefault_notPoolManager() external {
        ILoanManagerLike loanManager = ILoanManagerLike(poolManager.loanManagerList(0));

        vm.expectRevert("LM:TD:NOT_PM");
        loanManager.triggerDefault(loan, address(liquidatorFactory));
    }

}

contract OpenTermLoanTriggerDefaultTestsBase is TestBaseWithAssertions {

    address borrower = makeAddr("borrower");
    address lp       = makeAddr("lp");

    uint256 constant delegateManagementFeeRate = 0.02e6;
    uint256 constant delegateServiceFeeRate    = 0.03e6;
    uint256 constant gracePeriod     = 5 days;
    uint256 constant interestRate    = 0.1e6;
    uint256 constant noticePeriod    = 5 days;
    uint256 constant paymentInterval = 30 days;
    uint256 constant platformManagementFeeRate = 0.08e6;
    uint256 constant platformServiceFeeRate    = 0.04e6;
    uint256 constant principal       = 1_500_000e6;

    IOpenTermLoan        loan;
    IOpenTermLoanManager loanManager;

    function setUp() public virtual override {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _createFactories();
        _createAndConfigurePool(1 weeks, 2 days);
        openPool(address(poolManager));

        start = block.timestamp;

        vm.startPrank(governor);
        globals.setValidBorrower(borrower, true);
        globals.setPlatformServiceFeeRate(address(poolManager)   , platformServiceFeeRate);
        globals.setPlatformManagementFeeRate(address(poolManager), platformManagementFeeRate);
        vm.stopPrank();

        setDelegateManagementFeeRate(address(poolManager), delegateManagementFeeRate);

        deposit(lp, 1_500_000e6);

        loanManager = IOpenTermLoanManager(poolManager.loanManagerList(1));

        loan = IOpenTermLoan(createOpenTermLoan(
            address(borrower),
            address(loanManager),
            address(fundsAsset),
            principal,
            [uint32(gracePeriod), uint32(noticePeriod), uint32(paymentInterval)],
            [uint64(delegateServiceFeeRate), uint64(interestRate), 0, uint64(interestRate)]
        ));
    }

}

// TODO: To consider if transfer fails are possible/worth doing.
contract OpenTermLoanTriggerDefaultFailureTests is OpenTermLoanTriggerDefaultTestsBase {

    function test_triggerDefault_protocolPaused_poolManager() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("PM:PAUSED");
        poolManager.triggerDefault(address(loan), address(liquidatorFactory));
    }

    function test_triggerDefault_notAuthorized() external {
        vm.expectRevert("PM:TD:NOT_AUTHORIZED");
        poolManager.triggerDefault(address(loan), address(liquidatorFactory));
    }

    function test_triggerDefault_notFactory() external {
        vm.prank(address(poolDelegate));
        vm.expectRevert("PM:TD:NOT_FACTORY");
        poolManager.triggerDefault(address(loan), address(1));
    }

    function test_triggerDefault_invalidLoanManager() external {
        address invalidLoan = address(new OpenTermLoan());

        vm.prank(address(poolDelegate));
        vm.expectRevert("PM:GLM:INVALID_LOAN_MANAGER");
        poolManager.triggerDefault(invalidLoan, address(liquidatorFactory));
    }

    function test_triggerDefault_protocolPaused_loanManager() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("LM:PAUSED");
        loanManager.triggerDefault(address(loan), address(liquidatorFactory));
    }

    function test_triggerDefault_notPM() external {
        vm.prank(address(poolDelegate));
        loanManager.fund(address(loan));

        vm.expectRevert("LM:TD:NOT_PM");
        loanManager.triggerDefault(address(loan), address(liquidatorFactory));
    }

    function test_triggerDefault_notLoan() external {
        vm.prank(address(poolDelegate));
        vm.expectRevert("LM:NOT_LOAN");
        poolManager.triggerDefault(address(loan), address(liquidatorFactory));
    }

    function test_triggerDefault_notInDefault_boundary() external {
        _setTreasury();

        vm.prank(address(poolDelegate));
        loanManager.fund(address(loan));

        vm.warp(start + paymentInterval + gracePeriod);

        vm.startPrank(address(poolDelegate));
        vm.expectRevert('ML:R:NOT_IN_DEFAULT');
        poolManager.triggerDefault(address(loan), address(liquidatorFactory));

        vm.warp(start + paymentInterval + gracePeriod + 1);

        poolManager.triggerDefault(address(loan), address(liquidatorFactory));
    }

    function test_triggerDefault_repossess_notLender() external {
        vm.expectRevert("ML:R:NOT_LENDER");
        loan.repossess(address(loanManager));
    }

    function test_triggerDefault_treasuryZeroAddress() external {
        vm.prank(address(poolDelegate));
        loanManager.fund(address(loan));

        vm.warp(start + paymentInterval + gracePeriod + 1);

        vm.startPrank(address(poolDelegate));
        vm.expectRevert("LM:DLF:TRANSFER_MT");
        poolManager.triggerDefault(address(loan), address(liquidatorFactory));
    }

    // TODO: Add transfer failure and other zero address tests.

}

contract OpenTermLoanTriggerDefaultTests is OpenTermLoanTriggerDefaultTestsBase {

    event CollateralLiquidationFinished(address indexed loan_, uint256 unrealizedLosses_);

    uint256 interest       = principal * interestRate * paymentInterval / 365 days / 1e6;
    uint256 managementFees = interest * (delegateManagementFeeRate + platformManagementFeeRate) / 1e6;
    uint256 issuanceRate   = (interest - managementFees) * 1e27 / paymentInterval;

    function setUp() public override {
        super.setUp();

        _setTreasury();

        vm.prank(address(poolDelegate));
        loanManager.fund(address(loan));

        vm.prank(governor);
        globals.setMaxCoverLiquidationPercent(address(poolManager), 50_0000);

        fundsAsset.mint(address(poolDelegate), 1_000_000e6);

        vm.startPrank(poolDelegate);
        fundsAsset.approve(address(poolManager), 1_000_000e6);
        poolManager.depositCover(1_000_000e6);
        vm.stopPrank();
    }

    function test_triggerDefault_latePayment() external {
        uint256 defaultTime = start + paymentInterval + gracePeriod + 1;

        vm.warp(defaultTime);

        uint256 accruedInterest = (issuanceRate * (defaultTime - start)) / 1e27;

        assertPoolState({
            totalSupply:        1_500_000e6,                  // Same as initial deposit
            totalAssets:        principal + accruedInterest,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

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

        assertEq(fundsAsset.balanceOf(address(poolCover)), 1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(treasury)),  0);

        vm.prank(address(poolDelegate));
        poolManager.triggerDefault(address(loan), address(liquidatorFactory));

        uint256 platformServiceFee = (principal * 0.04e6       * (defaultTime - start))                     / (365 days * 1e6);
        uint256 normalInterest     = (principal * interestRate * (defaultTime - start))                     / (365 days * 1e6);
        uint256 lateInterest       = (principal * interestRate * (defaultTime - (start + paymentInterval))) / (365 days * 1e6);

        uint256 platformManagementFee = (normalInterest + lateInterest) * 0.08e6 / 1e6;

        uint256 totalAssets = 500_000e6 - platformServiceFee - platformManagementFee;  // poolCover - platformFees

        assertEq(fundsAsset.balanceOf(address(poolCover)), 500_000e6);
        assertEq(fundsAsset.balanceOf(address(treasury)),  platformServiceFee + platformManagementFee);

        assertPoolState({
            totalSupply:        1_500_000e6,
            totalAssets:        totalAssets,
            unrealizedLosses:   0,
            availableLiquidity: totalAssets
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       defaultTime,
            issuanceRate:      0,
            accountedInterest: 0,
            accruedInterest:   0,
            principalOut:      0,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            platformFeeRate: 0,
            delegateFeeRate: 0,
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
            principal:       0
        });
    }

    function test_triggerDefault_impaired() external {
        uint256 impairmentDate = start + paymentInterval / 2;

        vm.warp(impairmentDate);

        uint256 accruedInterest = (issuanceRate * (impairmentDate - start)) / 1e27;

        vm.prank(address(poolDelegate));
        loanManager.impairLoan(address(loan));

        assertPoolState({
            totalSupply:        1_500_000e6,                  // Same as initial deposit
            totalAssets:        principal + accruedInterest,
            unrealizedLosses:   principal + accruedInterest,
            availableLiquidity: 0
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       impairmentDate,
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
            impairedDate:       impairmentDate,
            impairedByGovernor: false
        });

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    impairmentDate,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal
        });

        uint256 defaultTime = impairmentDate + gracePeriod + 1;

        vm.warp(defaultTime);

        assertPoolState({
            totalSupply:        1_500_000e6,                  // Same as initial deposit
            totalAssets:        principal + accruedInterest,
            unrealizedLosses:   principal + accruedInterest,
            availableLiquidity: 0
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       impairmentDate,
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

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    impairmentDate,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal
        });

        assertEq(fundsAsset.balanceOf(address(poolCover)), 1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(treasury)),  0);

        vm.prank(address(poolDelegate));
        poolManager.triggerDefault(address(loan), address(liquidatorFactory));

        uint256 platformServiceFee = (principal * 0.04e6       * (impairmentDate - start)) / (365 days * 1e6);
        uint256 normalInterest     = (principal * interestRate * (impairmentDate - start)) / (365 days * 1e6);

        uint256 platformManagementFee = normalInterest  * 0.08e6 / 1e6;

        uint256 totalAssets = 500_000e6 - platformServiceFee - platformManagementFee;  // poolCover - platformFees

        assertEq(fundsAsset.balanceOf(address(poolCover)), 500_000e6);
        assertEq(fundsAsset.balanceOf(address(treasury)),  platformServiceFee + platformManagementFee);

        assertPoolState({
            totalSupply:        1_500_000e6,
            totalAssets:        totalAssets,
            unrealizedLosses:   0,
            availableLiquidity: totalAssets
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       defaultTime,
            issuanceRate:      0,
            accountedInterest: 0,
            accruedInterest:   0,
            principalOut:      0,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            platformFeeRate: 0,
            delegateFeeRate: 0,
            startDate:       0,
            issuanceRate:    0
        });

        assertImpairment({
            loan:               address(loan),
            impairedDate:       0,
            impairedByGovernor: false
        });

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      0,
            dateFunded:      0,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       0
        });
    }

    function test_triggerDefault_called() external {
        uint256 callDate = start + paymentInterval / 2;

        vm.warp(callDate);

        uint256 accruedInterest = (issuanceRate * (callDate - start)) / 1e27;

        vm.prank(address(poolDelegate));
        loanManager.callPrincipal(address(loan), principal);

        assertPoolState({
            totalSupply:        1_500_000e6,                  // Same as initial deposit
            totalAssets:        principal + accruedInterest,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

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
            dateCalled:      callDate,
            dateFunded:      start,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: principal,
            principal:       principal
        });

        uint256 defaultTime = callDate + noticePeriod + 1;

        vm.warp(defaultTime);

        accruedInterest = (issuanceRate * (defaultTime - start)) / 1e27;

        assertPoolState({
            totalSupply:        1_500_000e6,                  // Same as initial deposit
            totalAssets:        principal + accruedInterest,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       start,
            issuanceRate:      issuanceRate,
            accountedInterest: 0,
            accruedInterest:   accruedInterest,
            principalOut:      principal,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(poolCover)), 1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(treasury)),  0);

        vm.prank(address(poolDelegate));
        poolManager.triggerDefault(address(loan), address(liquidatorFactory));

        uint256 platformServiceFee = (principal * 0.04e6       * (defaultTime - start))                     / (365 days * 1e6);
        uint256 normalInterest     = (principal * interestRate * (defaultTime - start))                     / (365 days * 1e6);
        uint256 lateInterest       = (principal * interestRate * (defaultTime - (callDate + noticePeriod))) / (365 days * 1e6);

        uint256 platformManagementFee = (normalInterest + lateInterest) * 0.08e6 / 1e6;

        uint256 totalAssets = 500_000e6 - platformServiceFee - platformManagementFee;  // poolCover - platformFees

        assertEq(fundsAsset.balanceOf(address(poolCover)), 500_000e6);
        assertEq(fundsAsset.balanceOf(address(treasury)),  platformServiceFee + platformManagementFee);

        assertPoolState({
            totalSupply:        1_500_000e6,
            totalAssets:        totalAssets,
            unrealizedLosses:   0,
            availableLiquidity: totalAssets
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            domainStart:       defaultTime,
            issuanceRate:      0,
            accountedInterest: 0,
            accruedInterest:   0,
            principalOut:      0,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            platformFeeRate: 0,
            delegateFeeRate: 0,
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
            principal:       0
        });
    }

    // TODO: Add test to demo partial fee recovery from Loan.

    function test_triggerDefault_onlyFeesRecovered() external {
        uint256 defaultTime = start + paymentInterval + gracePeriod + 1;

        vm.warp(defaultTime);

        uint256 platformServiceFee = (principal * 0.04e6       * (defaultTime - start))                     / (365 days * 1e6);
        uint256 normalInterest     = (principal * interestRate * (defaultTime - start))                     / (365 days * 1e6);
        uint256 lateInterest       = (principal * interestRate * (defaultTime - (start + paymentInterval))) / (365 days * 1e6);

        uint256 platformManagementFee = (normalInterest + lateInterest) * 0.08e6 / 1e6;

        fundsAsset.burn(address(poolCover), 1_000_000e6);
        fundsAsset.mint(address(poolCover), (platformServiceFee + platformManagementFee) * 2);  // Mint so 50% = amount needed for fees.

        assertEq(fundsAsset.balanceOf(address(poolCover)), (platformServiceFee + platformManagementFee) * 2);
        assertEq(fundsAsset.balanceOf(address(treasury)),  0);
        assertEq(fundsAsset.balanceOf(address(pool)),      0);

        vm.prank(address(poolDelegate));
        poolManager.triggerDefault(address(loan), address(liquidatorFactory));

        assertEq(fundsAsset.balanceOf(address(poolCover)), platformServiceFee + platformManagementFee);
        assertEq(fundsAsset.balanceOf(address(treasury)),  platformServiceFee + platformManagementFee);
        assertEq(fundsAsset.balanceOf(address(pool)),      0);
    }

    function test_triggerDefault_feesAndPartialRecovery() external {
        uint256 defaultTime = start + paymentInterval + gracePeriod + 1;

        vm.warp(defaultTime);

        uint256 platformServiceFee = (principal * 0.04e6       * (defaultTime - start))                     / (365 days * 1e6);
        uint256 normalInterest     = (principal * interestRate * (defaultTime - start))                     / (365 days * 1e6);
        uint256 lateInterest       = (principal * interestRate * (defaultTime - (start + paymentInterval))) / (365 days * 1e6);

        uint256 platformManagementFee = (normalInterest + lateInterest) * 0.08e6 / 1e6;

        assertEq(fundsAsset.balanceOf(address(poolCover)), 1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(treasury)),  0);
        assertEq(fundsAsset.balanceOf(address(pool)),      0);

        vm.prank(address(poolDelegate));
        poolManager.triggerDefault(address(loan), address(liquidatorFactory));

        assertEq(fundsAsset.balanceOf(address(poolCover)), 500_000e6);
        assertEq(fundsAsset.balanceOf(address(treasury)),  platformServiceFee + platformManagementFee);
        assertEq(fundsAsset.balanceOf(address(pool)),      500_000e6 - (platformServiceFee + platformManagementFee));
    }

    function test_triggerDefault_feesAndFullRecovery() external {
        uint256 defaultTime = start + paymentInterval + gracePeriod + 1;

        vm.warp(defaultTime);

        uint256 normalInterest        = (principal * interestRate * (defaultTime - start))                     / (365 days * 1e6);
        uint256 lateInterest          = (principal * interestRate * (defaultTime - (start + paymentInterval))) / (365 days * 1e6);
        uint256 platformServiceFee    = (principal * 0.04e6       * (defaultTime - start))                     / (365 days * 1e6);
        uint256 platformManagementFee = (normalInterest + lateInterest) * 0.08e6 / 1e6;

        uint256 grossInterest = normalInterest + lateInterest;
        uint256 netInterest   = grossInterest - grossInterest * 0.1e6 / 1e6;
        uint256 platformFees  = platformServiceFee + platformManagementFee;

        fundsAsset.mint(address(poolCover), 3_000_000e6);

        assertEq(fundsAsset.balanceOf(address(poolCover)), 4_000_000e6);
        assertEq(fundsAsset.balanceOf(address(treasury)),  0);
        assertEq(fundsAsset.balanceOf(address(pool)),      0);

        vm.prank(address(poolDelegate));
        poolManager.triggerDefault(address(loan), address(liquidatorFactory));

        assertEq(fundsAsset.balanceOf(address(poolCover)), 4_000_000e6 - principal - netInterest - platformFees);
        assertEq(fundsAsset.balanceOf(address(treasury)),  platformFees);
        assertEq(fundsAsset.balanceOf(address(pool)),      principal + netInterest);
    }

    function test_triggerDefault_impaired_onlyFeesRecovered() external {
        uint256 impairmentTime = start + paymentInterval / 2;

        vm.warp(impairmentTime);
        impairLoan(address(loan));

        uint256 defaultTime = start + paymentInterval + gracePeriod + 1;

        vm.warp(defaultTime);

        uint256 platformServiceFee = (principal * 0.04e6       * (impairmentTime - start)) / (365 days * 1e6);
        uint256 normalInterest     = (principal * interestRate * (impairmentTime - start)) / (365 days * 1e6);
        uint256 lateInterest       = 0;

        uint256 platformManagementFee = (normalInterest + lateInterest) * 0.08e6 / 1e6;
        uint256 delegateManagementFee = (normalInterest + lateInterest) * 0.02e6 / 1e6;

        uint256 netInterest = normalInterest + lateInterest - platformManagementFee - delegateManagementFee;

        uint256 expectedLosses = principal + netInterest;

        // Burn so recovered amount only from loan repossession.
        fundsAsset.burn(address(poolCover), 1_000_000e6);
        fundsAsset.mint(address(loan), (platformServiceFee + platformManagementFee));

        assertEq(fundsAsset.balanceOf(address(poolCover)), 0);
        assertEq(fundsAsset.balanceOf(address(treasury)),  0);
        assertEq(fundsAsset.balanceOf(address(pool)),      0);

        vm.expectEmit();
        emit CollateralLiquidationFinished(address(loan), expectedLosses);

        vm.prank(address(poolDelegate));
        poolManager.triggerDefault(address(loan), address(liquidatorFactory));

        assertEq(fundsAsset.balanceOf(address(poolCover)), 0);
        assertEq(fundsAsset.balanceOf(address(treasury)),  platformServiceFee + platformManagementFee);
        assertEq(fundsAsset.balanceOf(address(pool)),      0);
    }

    function test_triggerDefault_impaired_feesAndFullRecovery() external {
        uint256 impairmentTime = start + paymentInterval / 2;

        vm.warp(impairmentTime);
        impairLoan(address(loan));

        uint256 defaultTime = start + paymentInterval + gracePeriod + 1;

        vm.warp(defaultTime);

        uint256 normalInterest     = (principal * interestRate * (impairmentTime - start)) / (365 days * 1e6);
        uint256 platformServiceFee = (principal * 0.04e6       * (impairmentTime - start)) / (365 days * 1e6);
        uint256 lateInterest       = 0;

        uint256 platformManagementFee = (normalInterest + lateInterest) * 0.08e6 / 1e6;
        uint256 delegateManagementFee = (normalInterest + lateInterest) * 0.02e6 / 1e6;
        uint256 platformFees          = platformServiceFee + platformManagementFee;

        uint256 netInterest = normalInterest + lateInterest - platformManagementFee - delegateManagementFee;

        uint256 expectedLosses = principal + netInterest;

        fundsAsset.mint(address(poolCover), 3_000_000e6);

        assertEq(fundsAsset.balanceOf(address(poolCover)), 4_000_000e6);
        assertEq(fundsAsset.balanceOf(address(treasury)),  0);
        assertEq(fundsAsset.balanceOf(address(pool)),      0);

        vm.expectEmit();
        emit CollateralLiquidationFinished(address(loan), expectedLosses);

        vm.prank(address(poolDelegate));
        poolManager.triggerDefault(address(loan), address(liquidatorFactory));

        assertEq(fundsAsset.balanceOf(address(poolCover)), 4_000_000e6 - principal - netInterest - platformFees);
        assertEq(fundsAsset.balanceOf(address(treasury)),  platformFees);
        assertEq(fundsAsset.balanceOf(address(pool)),      principal + netInterest);
    }

}
