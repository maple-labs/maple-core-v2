// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IOpenTermLoan, IOpenTermLoanManager } from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract MakePaymentOpenTermFailureTests is TestBaseWithAssertions {

    uint32 constant gracePeriod     = 5 days;
    uint32 constant noticePeriod    = 100_000 seconds;
    uint32 constant paymentInterval = 1_000_000 seconds;

    uint64 constant interestRate = 0.031536e6;

    uint256 constant principal = 1_000_000e6;

    address borrower = makeAddr("borrower");
    address lp       = makeAddr("lp");

    IOpenTermLoan loan;
    IOpenTermLoanManager loanManager;

    function setUp() public override {
        super.setUp();

        deposit(lp, 1_500_000e6);

        setupFees({
            delegateOriginationFee: 500e6,
            delegateServiceFee: 300e6,
            delegateManagementFeeRate: 0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate: 0.31536e6, // 10k after 1m seconds
            platformManagementFeeRate: 0.08e6
        });

        loanManager = IOpenTermLoanManager(poolManager.strategyList(0));

        loan = IOpenTermLoan(
            createOpenTermLoan(
                address(borrower),
                address(loanManager),
                address(fundsAsset),
                principal,
                [gracePeriod, noticePeriod, paymentInterval],
                [0.031536e6, interestRate, 0, 0.15768e6]
            )
        );

        fundLoan(address(loan));
    }

    function test_makePayment_inactiveLoan() external {
        loan = IOpenTermLoan(
            createOpenTermLoan(
                address(borrower),
                address(loanManager),
                address(fundsAsset),
                principal,
                [gracePeriod, noticePeriod, paymentInterval],
                [0.031536e6, interestRate, 0, 0]
            )
        );

        vm.expectRevert("ML:MP:LOAN_INACTIVE");
        loan.makePayment(0);
    }

    function test_makePayment_tooMuchPrincipal() external {
        vm.expectRevert("ML:MP:RETURNING_TOO_MUCH");
        loan.makePayment(1_000_000e6 + 1);
    }

    function test_makePayment_tooLittlePrincipal() external {
        vm.prank(poolDelegate);
        loanManager.callPrincipal(address(loan), 1);

        vm.warp(start + 1);

        vm.expectRevert("ML:MP:INSUFFICIENT_FOR_CALL");
        loan.makePayment(0);
    }

    function test_makePayment_transferFailed() external {
        vm.warp(start + 100);

        vm.expectRevert("ML:MP:TRANSFER_FROM_FAILED");
        loan.makePayment(0);
    }

    function test_makePayment_invalidPrincipalIncrease() external {
        vm.prank(address(loan));
        vm.expectRevert("LM:C:INVALID");
        loanManager.claim(-1, 100_000e6, 10_000e6, 1_000e6, 0);
    }

    function test_makePayment_notLoan() external {
        fundsAsset.mint(address(loanManager), 111_000e6);

        // Create a loan that's not in the LM and call claim from it.
        loan = IOpenTermLoan(
            createOpenTermLoan(
                address(borrower),
                address(loanManager),
                address(fundsAsset),
                principal,
                [gracePeriod, noticePeriod, paymentInterval],
                [0.031536e6, interestRate, 0, 0]
            )
        );

        vm.prank(address(loan));
        vm.expectRevert("LM:NOT_LOAN");
        loanManager.claim(0, 100_000e6, 10_000e6, 1_000e6, uint40(start + 1_000_000));
    }

    function test_makePayment_transferToPoolBoundary() external {
        fundsAsset.mint(address(loanManager), 90_000e6 - 1); // Net Interest

        vm.prank(address(loan));
        vm.expectRevert("LM:DCF:TRANSFER_P");
        loanManager.claim(0, 100_000e6, 10_000e6, 1_000e6, uint40(start + 1_000_000));

        fundsAsset.mint(address(loanManager), 1);

        vm.prank(address(loan));
        vm.expectRevert("LM:DCF:TRANSFER_PD");
        loanManager.claim(0, 100_000e6, 10_000e6, 1_000e6, uint40(start + 1_000_000));
    }

    function test_makePayment_transferToPoolDelegateBoundary() external {
        // Net interest + platform management fee + platform service fee
        fundsAsset.mint(address(loanManager), 90_000e6 + 2_000e6 + 10_000e6 - 1);

        vm.prank(address(loan));
        vm.expectRevert("LM:DCF:TRANSFER_PD");
        loanManager.claim(0, 100_000e6, 10_000e6, 1_000e6, uint40(start + 1_000_000));

        fundsAsset.mint(address(loanManager), 1);

        vm.prank(address(loan));
        vm.expectRevert("LM:DCF:TRANSFER_MT");
        loanManager.claim(0, 100_000e6, 10_000e6, 1_000e6, uint40(start + 1_000_000));
    }

    function test_makePayment_transferToTreasuryBoundary() external {
        // Net interest + platform management fee + platform service fee
        fundsAsset.mint(address(loanManager), 90_000e6 + 2_000e6 + 10_000e6 + 8_000e6 + 1_000e6 - 1);

        vm.prank(address(loan));
        vm.expectRevert("LM:DCF:TRANSFER_MT");
        loanManager.claim(0, 100_000e6, 10_000e6, 1_000e6, uint40(start + 1_000_000));

        fundsAsset.mint(address(loanManager), 1);

        vm.prank(address(loan));
        loanManager.claim(0, 100_000e6, 10_000e6, 1_000e6, uint40(start + 1_000_000));
    }

}

contract MakePaymentTestsSingleLoanOpenTerm is TestBaseWithAssertions {

    uint32 constant gracePeriod     = 200_000;
    uint32 constant noticePeriod    = 100_000;
    uint32 constant paymentInterval = 1_000_000;

    uint64 constant interestRate = 0.031536e6;

    uint256 constant principal = 1_000_000e6;

    address borrower = makeAddr("borrower");
    address lp       = makeAddr("lp");

    IOpenTermLoan loan;
    IOpenTermLoanManager loanManager;

    function setUp() public override {
        super.setUp();

        deposit(lp, 1_500_000e6);

        setupFees({
            delegateOriginationFee: 500e6,
            delegateServiceFee: 300e6,
            delegateManagementFeeRate: 0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate: 0.031536e6, // 1k after 1m seconds
            platformManagementFeeRate: 0.08e6
        });

        loanManager = IOpenTermLoanManager(poolManager.strategyList(0));

        loan = IOpenTermLoan(
            createOpenTermLoan(
                address(borrower),
                address(loanManager),
                address(fundsAsset),
                principal,
                [gracePeriod, noticePeriod, paymentInterval],
                [0.015768e6, interestRate, 0, 0.015768e6]
            )
        );

        fundLoan(address(loan));
    }

    function test_makePayment_OT_onTimePayment() public {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertPoolState({
            pool:               address(pool),
            totalSupply:        1_500_000e6,
            totalAssets:        1_500_000e6,
            unrealizedLosses:   0,
            availableLiquidity: 500_000e6
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            accruedInterest:   0,
            issuanceRate:      0.0009e6 * 1e27,
            domainStart:       start,
            unrealizedLosses:  0
        });

        /******************************/
        /*** Pre Payment Assertions ***/
        /******************************/

        vm.warp(start + 1_000_000);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        1_500_000e6,
            totalAssets:        1_500_000e6 + 900e6,
            unrealizedLosses:   0,
            availableLiquidity: 500_000e6
        });

        assertOpenTermLoanPaymentState({
            loan:               address(loan),
            paymentTimestamp:   uint40(start + 1_000_000),
            principal:          0,
            interest:           1_000e6,
            lateInterest:       0,
            delegateServiceFee: 500e6,
            platformServiceFee: 1_000e6,
            paymentDueDate:     start + 1_000_000,
            defaultDate:        start + 1_200_000
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            issuanceRate:    0.0009e6 * 1e27,
            startDate:       start,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.02e6
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            accruedInterest:   900e6,
            issuanceRate:      0.0009e6 * 1e27,
            domainStart:       start,
            unrealizedLosses:  0
        });

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        makePayment(address(loan));

        assertPoolState({
            pool:               address(pool),
            totalSupply:        1_500_000e6,
            totalAssets:        1_500_000e6 + 900e6,
            unrealizedLosses:   0,
            availableLiquidity: 500_900e6
        });

        assertOpenTermLoanPaymentState({
            loan:               address(loan),
            principal:          0,
            paymentTimestamp:   uint40(start + 2_000_000),
            interest:           1_000e6,
            lateInterest:       0,
            delegateServiceFee: 500e6,
            platformServiceFee: 1_000e6,
            paymentDueDate:     start + 2_000_000,
            defaultDate:        start + 2_200_000
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            issuanceRate:    0.0009e6 * 1e27,
            startDate:       start + 1_000_000,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.02e6
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            accruedInterest:   0,
            issuanceRate:      0.0009e6 * 1e27,
            domainStart:       start + 1_000_000,
            unrealizedLosses:  0
        });

        // Pool Delegate fee: 500e6   (1_000_000s of service fees) + 0.02 * 1_000 (management fee)
        // Treasury fee:      1_000e6 (1_000_000s of service fees) + 0.08 * 1_000 (management fee)
        assertAssetBalancesIncrease(address(fundsAsset), [poolDelegate, treasury], [500e6 + 20e6, 1_000e6 + 80e6]);
    }

    function test_makePayment_OT_latePayment() public {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertPoolState({
            pool:               address(pool),
            totalSupply:        1_500_000e6,
            totalAssets:        1_500_000e6,
            unrealizedLosses:   0,
            availableLiquidity: 500_000e6
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            accruedInterest:   0,
            issuanceRate:      0.0009e6 * 1e27,
            domainStart:       start,
            unrealizedLosses:  0
        });

        /******************************/
        /*** Pre Payment Assertions ***/
        /******************************/

        vm.warp(start + 1_100_000);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        1_500_000e6,
            totalAssets:        1_500_000e6 + 990e6,
            unrealizedLosses:   0,
            availableLiquidity: 500_000e6
        });

        assertOpenTermLoanPaymentState({
            loan: address(loan),
            paymentTimestamp: uint40(block.timestamp),
            principal: 0,
            interest: 1_100e6,
            lateInterest: 50e6, // 100_000s at interest premium.
            delegateServiceFee: 550e6,
            platformServiceFee: 1_100e6,
            paymentDueDate: start + 1_000_000,
            defaultDate: start + 1_200_000
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            issuanceRate:    0.0009e6 * 1e27,
            startDate:       start,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.02e6
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            accruedInterest:   990e6,
            issuanceRate:      0.0009e6 * 1e27,
            domainStart:       start,
            unrealizedLosses:  0
        });

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        makePayment(address(loan));

        // Principal:            1_500_000e6
        // Interest from period: 900e6
        // Late interest:        50e6 * 0.9
        assertPoolState({
            pool:               address(pool),
            totalSupply:        1_500_000e6,
            totalAssets:        1_500_000e6 + 990e6 + 45e6,
            unrealizedLosses:   0,
            availableLiquidity: 500_000e6 + 990e6 + 45e6
        });

        assertOpenTermLoanPaymentState({
            loan:               address(loan),
            paymentTimestamp:   uint40(loan.paymentDueDate()),
            principal:          0,
            interest:           1_000e6,
            lateInterest:       0,
            delegateServiceFee: 500e6,
            platformServiceFee: 1_000e6,
            paymentDueDate:     start + 2_100_000,
            defaultDate:        start + 2_300_000
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            issuanceRate:    0.0009e6 * 1e27,
            startDate:       start + 1_100_000,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.02e6
        });

        assertOpenTermLoanManager({
            loanManager: address(loanManager),
            accountedInterest: 0, // Accounted during claim
            principalOut: 1_000_000e6,
            accruedInterest: 0,
            issuanceRate: 0.0009e6 * 1e27,
            domainStart: start + 1_100_000,
            unrealizedLosses: 0
        });

        // Pool Delegate fee: 550e6   (1_100_000s of service fee) + 0.02 * 1_150e6 (management fee)
        // Treasury fee:      1_100e6 (1_100_000s of service fee) + 0.08 * 1_150e6
        assertAssetBalancesIncrease(address(fundsAsset), [poolDelegate, treasury], [550e6 + 23e6, 1_100e6 + 92e6]);
    }

    function test_makePayment_OT_withCall() public {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertPoolState({
            pool:               address(pool),
            totalSupply:        1_500_000e6,
            totalAssets:        1_500_000e6,
            unrealizedLosses:   0,
            availableLiquidity: 500_000e6
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            accruedInterest:   0,
            issuanceRate:      0.0009e6 * 1e27,
            domainStart:       start,
            unrealizedLosses:  0
        });

        // Call the loan early
        vm.warp(start + 500_000);

        vm.prank(poolDelegate);
        loanManager.callPrincipal(address(loan), 1_000_000e6);

        /******************************/
        /*** Pre Payment Assertions ***/
        /******************************/

        vm.warp(start + 600_000);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        1_500_000e6,
            totalAssets:        1_500_000e6 + 540e6,
            unrealizedLosses:   0,
            availableLiquidity: 500_000e6
        });

        assertOpenTermLoanPaymentState({
            loan:               address(loan),
            paymentTimestamp:   uint40(start + 600_000),
            principal:          1_000_000e6,
            interest:           600e6,
            lateInterest:       0,
            delegateServiceFee: 300e6,
            platformServiceFee: 600e6,
            paymentDueDate:     uint40(start + 600_000),
            defaultDate:        start + 600_000
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            issuanceRate:    0.0009e6 * 1e27,
            startDate:       start,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.02e6
        });

        assertOpenTermLoanManager({
            loanManager: address(loanManager),
            accountedInterest: 0,
            principalOut: 1_000_000e6,
            accruedInterest: 540e6, // 90% of 600e6
            issuanceRate: 0.0009e6 * 1e27,
            domainStart: start,
            unrealizedLosses: 0
        });

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        makePayment(address(loan));

        assertPoolState({
            pool:               address(pool),
            totalSupply:        1_500_000e6,
            totalAssets:        1_500_000e6 + 540e6,
            unrealizedLosses:   0,
            availableLiquidity: 1_500_000e6 + 540e6
        });

        assertOpenTermLoanPaymentState({
            loan:               address(loan),
            principal:          0,
            paymentTimestamp:   uint40(start + 600_000),
            interest:           0,
            lateInterest:       0,
            delegateServiceFee: 0,
            platformServiceFee: 0,
            paymentDueDate:     0,
            defaultDate:        0
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            issuanceRate:    0,
            startDate:       0,
            platformFeeRate: 0,
            delegateFeeRate: 0
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: 0,
            principalOut:      0,
            accruedInterest:   0,
            issuanceRate:      0,
            domainStart:       start + 600_000,
            unrealizedLosses:  0
        });

        // Pool Delegate fee: 600e6   (600_000s of service fees) + 0.02 * 600 (management fee)
        // Treasury fee:      6_000e6 (600_000s of service fees) + 0.08 * 600 (management fee)
        assertAssetBalancesIncrease(address(fundsAsset), [poolDelegate, treasury], [300e6 + 12e6, 600e6 + 48e6]);
    }

    function test_makePayment_OT_withImpairment() public {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertPoolState({
            pool:               address(pool),
            totalSupply:        1_500_000e6,
            totalAssets:        1_500_000e6,
            unrealizedLosses:   0,
            availableLiquidity: 500_000e6
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            accruedInterest:   0,
            issuanceRate:      0.0009e6 * 1e27,
            domainStart:       start,
            unrealizedLosses:  0
        });

        // Impair the loan early
        vm.warp(start + 800_000);

        vm.prank(poolDelegate);
        loanManager.impairLoan(address(loan));

        /******************************/
        /*** Pre Payment Assertions ***/
        /******************************/

        vm.warp(start + 1_200_000);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        1_500_000e6,
            totalAssets:        1_500_000e6 + 720e6,
            unrealizedLosses:   1_000_000e6 + 720e6,
            availableLiquidity: 500_000e6
        });

        assertOpenTermLoanPaymentState({
            loan: address(loan),
            paymentTimestamp: uint40(start + 1_200_000),
            principal: 0,
            interest: 1200e6, // Accruing for 1.2m seconds
            lateInterest: 200e6, // Accruing for 400k seconds since impaired at 800k
            delegateServiceFee: 600e6,
            platformServiceFee: 1200e6,
            paymentDueDate: uint40(start + 800_000),
            defaultDate: start + 1_000_000
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            issuanceRate:    0.0009e6 * 1e27,
            startDate:       start,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.02e6
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: 720e6,
            principalOut:      1_000_000e6,
            accruedInterest:   0,
            issuanceRate:      0,
            domainStart:       start + 800_000,
            unrealizedLosses:  1_000_000e6 + 720e6
        });

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        makePayment(address(loan));

        // 1_200_000s of the interest rate + the late interest 200s
        assertPoolState({
            pool:               address(pool),
            totalSupply:        1_500_000e6,
            totalAssets:        1_500_000e6 + 1_260e6,
            unrealizedLosses:   0,
            availableLiquidity: 500_000e6 + 1_260e6
        });

        assertOpenTermLoanPaymentState({
            loan:               address(loan),
            principal:          0,
            paymentTimestamp:   uint40(start + 2_200_000),
            interest:           1_000e6,
            lateInterest:       0,
            delegateServiceFee: 500e6,
            platformServiceFee: 1_000e6,
            paymentDueDate:     start + 2_200_000,
            defaultDate:        start + 2_400_000
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            issuanceRate:    0.0009e6 * 1e27,
            startDate:       start + 1_200_000,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.02e6
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            accruedInterest:   0,
            issuanceRate:      0.0009e6 * 1e27,
            domainStart:       start + 1_200_000,
            unrealizedLosses:  0
        });

        // Pool Delegate fee:  1_200e6 (1_200_000s of service fees) + 0.02 * 1400 (management fee)
        // Treasury fee:      12_000e6 (1_200_000s of service fees) + 0.08 * 1_260 (management fee)
        assertAssetBalancesIncrease(address(fundsAsset), [poolDelegate, treasury], [600e6 + 28e6, 1_200e6 + 112e6]);
    }

}

