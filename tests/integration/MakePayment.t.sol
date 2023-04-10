// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IFixedTermLoan, IFixedTermLoanManager, IOpenTermLoan, IOpenTermLoanManager } from "../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

import { console } from "../../modules/forge-std/src/Test.sol";

contract MakePaymentFailureTests is TestBaseWithAssertions {

    address borrower;
    address loan;
    address lp;

    function setUp() public override {
        super.setUp();

        borrower = makeAddr("borrower");
        lp       = makeAddr("lp");

        deposit(lp, 1_500_000e6);

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,  // 10k after 1m seconds
            platformManagementFeeRate:  0.08e6
        });

        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e6), uint256(0), uint256(0), uint256(0)],
            loanManager: poolManager.loanManagerList(0)
        });

        vm.warp(start + 1_000_000);
    }

    function test_makePayment_failWithTransferFromFailed() external {
        (uint256 principalPortion, uint256 interestPortion, uint256 feesPortion) = IFixedTermLoan(loan).getNextPaymentBreakdown();

        uint256 fullPayment = principalPortion + interestPortion + feesPortion;

        // mint to borrower
        fundsAsset.mint(borrower, fullPayment);

        vm.prank(borrower);
        fundsAsset.approve(loan, fullPayment - 1);

        vm.expectRevert("ML:MP:TRANSFER_FROM_FAILED");
        IFixedTermLoan(loan).makePayment(fullPayment);
    }

    function test_makePayment_failWithTransferFailed() external {
        (uint256 principalPortion, uint256 interestPortion, uint256 feesPortion) = IFixedTermLoan(loan).getNextPaymentBreakdown();

        // mint to loan, not including fees
        fundsAsset.mint(loan, principalPortion + interestPortion + feesPortion - 1);

        vm.prank(borrower);
        // NOTE: When there's not enough balance, the tx fails in the ERC20 with an underflow
        //       rather than on the ERC20-helper library with the error message.
        vm.expectRevert(arithmeticError);
        IFixedTermLoan(loan).makePayment(0);
    }

    // TODO: Should this be called `test_claim_failIfNotLoan`?
    function test_makePayment_failIfNotLoan() external {
        IFixedTermLoanManager loanManager = IFixedTermLoanManager(poolManager.loanManagerList(0));

        vm.expectRevert("LM:DCF:NOT_LOAN");
        loanManager.claim(0, 10, start, start + 1_000_000);
    }

}

// NOTE: All of these feel like they should be unit tests (most of them are), and should be removed from the integration suite.
contract MakePaymentOpenTermFailureTests is TestBaseWithAssertions {

    uint32 constant gracePeriod     = 5 days;
    uint32 constant noticePeriod    = 100_000 seconds;
    uint32 constant paymentInterval = 1_000_000 seconds;

    uint64 constant interestRate = 0.031536e6;

    uint256 constant principal = 1_000_000e6;

    address borrower = makeAddr("borrower");
    address lp       = makeAddr("lp");

    IOpenTermLoan        loan;
    IOpenTermLoanManager loanManager;

    function setUp() public override {
        super.setUp();

        deposit(lp, 1_500_000e6);

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,  // 10k after 1m seconds
            platformManagementFeeRate:  0.08e6
        });

        loanManager = IOpenTermLoanManager(poolManager.loanManagerList(1));

        loan = IOpenTermLoan(createOpenTermLoan(
            address(borrower),
            address(loanManager),
            address(fundsAsset),
            principal,
            [gracePeriod, noticePeriod, paymentInterval],
            [0.031536e6, interestRate, 0, 0.15768e6]
        ));

        fundLoan(address(loan));
    }

    function test_makePayment_inactiveLoan() external {
        loan = IOpenTermLoan(createOpenTermLoan(
            address(borrower),
            address(loanManager),
            address(fundsAsset),
            principal,
            [gracePeriod, noticePeriod, paymentInterval],
            [0.031536e6, interestRate, 0, 0]
        ));

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

        (
            uint256 principal_,
            uint256 interest_,
            uint256 lateInterest_,
            uint256 delegateServiceFee_,
            uint256 platformServiceFee_
        ) = loan.getPaymentBreakdown(loan.paymentDueDate());

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
        loan = IOpenTermLoan(createOpenTermLoan(
            address(borrower),
            address(loanManager),
            address(fundsAsset),
            principal,
            [gracePeriod, noticePeriod, paymentInterval],
            [0.031536e6, interestRate, 0, 0]
        ));

        vm.prank(address(loan));
        vm.expectRevert("LM:NOT_LOAN");
        loanManager.claim(0, 100_000e6, 10_000e6, 1_000e6, uint40(start + 1_000_000));
    }

    function test_makePayment_transferToPoolBoundary() external {
        fundsAsset.mint(address(loanManager), 90_000e6 - 1);  // Net Interest

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

contract MakePaymentTestsSingleLoanInterestOnly is TestBaseWithAssertions {

    address borrower;
    address loan;
    address loanManager;
    address lp;

    function setUp() public override {
        super.setUp();

        borrower = makeAddr("borrower");
        lp       = makeAddr("lp");

        deposit(lp, 1_500_000e6);

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,  // 10k after 1m seconds
            platformManagementFeeRate:  0.08e6
        });

        loanManager = poolManager.loanManagerList(0);

        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e6), uint256(0), uint256(0), uint256(0)],
            loanManager: loanManager
        });
    }

    function test_makePayment_onTimePayment_interestOnly() public {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(1_500_000e6);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.09e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        // PoolDelegate and treasury get their own originationFee
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [500e6,        95_129375]
        );  // 1m * 0.01% * (~11.57/365) * 3 = 95.129375

        /******************************/
        /*** Pre Payment Assertions ***/
        /******************************/

        vm.warp(start + 1_000_000);

        assertTotalAssets(1_500_000e6 + 90_000e6);

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6,          // 0.1 * 1_000_000 = 100_000
            incomingFees:      10_000e6 + 300e6,   // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   90_000e6,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.09e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        makePayment(loan);

        assertTotalAssets(1_500_000e6 + 90_000e6);

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest : 100_000e6,
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start + 1_000_000,
            paymentDueDate:      start + 2_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.09e6 * 1e30,
            domainStart:       start + 1_000_000,
            domainEnd:         start + 2_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 590_000e6);

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [2_300e6,      18_000e6]
        );
    }

    function test_makePayment_earlyPayment_interestOnly() public {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(1_500_000e6);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.09e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        // PoolDelegate and treasury get their own originationFee
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [500e6,        95_129375]
        );

        /******************************/
        /*** Pre Payment Assertions ***/
        /******************************/

        vm.warp(start + 500_000);

        assertTotalAssets(1_500_000e6 + 45_000e6);  // 0.09e6 per second * 500_000 seconds

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6,          // 0.1 * 1_000_000 = 100_000
            incomingFees:      10_000e6 + 300e6,   // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   45_000e6,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.09e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        makePayment(loan);

        assertTotalAssets(1_500_000e6 + 90_000e6);

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest : 100_000e6,
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.06e6 * 1e30,
            startDate:           start + 500_000,
            paymentDueDate:      start + 2_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.06e6 * 1e30,
            domainStart:       start + 500_000,
            domainEnd:         start + 2_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 590_000e6);

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [2_300e6,      18_000e6]
        );
    }

    function test_makePayment_latePayment_interestOnly() public {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(1_500_000e6);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.09e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        // PoolDelegate and treasury get their own originationFee
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [500e6,        95_129375]
        );

        /******************************/
        /*** Pre Payment Assertions ***/
        /******************************/

        vm.warp(start + 1_100_000);

        assertTotalAssets(1_500_000e6 + 90_000e6);

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  117_280e6,          // 0.1 * 1_000_000 = 100_000 + late(86400 seconds * 2 * 0.1) = 17_280
            incomingFees:      10_000e6 + 300e6,   // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   90_000e6,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.09e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        makePayment(loan);

        // Principal:                           1_500_000e6
        // interest from period:                90_000e6
        // 2 days of late interest:             2 * 86400 seconds * 0.09 = 15_552e6
        // 100_000s of interest from 2 payment: 9_000e6
        assertTotalAssets(1_500_000e6 + 90_000e6 + 15_552e6 + 9_000e6);

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest : 100_000e6,
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start + 1_000_000,
            paymentDueDate:      start + 2_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 9_000e6,          // Accounted during claim
            principalOut:      1_000_000e6,
            issuanceRate:      0.09e6 * 1e30,
            domainStart:       start + 1_100_000,
            domainEnd:         start + 2_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 90_000e6 + 15_552e6);

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee + late interest (17_280e6 * 0.02 = 345_600000)
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee + late interest (17_280e6 * 0.08 = 1382_400000)
        assertAssetBalancesIncrease(
            [poolDelegate,      treasury],
            [2_300e6 + 345.6e6, 18_000e6 + 1382.4e6]
        );
    }

}

contract MakePaymentTestsSingleLoanAmortized is TestBaseWithAssertions {

    address borrower;
    address loan;
    address loanManager;
    address lp;

    function setUp() public override {
        super.setUp();

        borrower = makeAddr("borrower");
        lp       = makeAddr("lp");

        deposit(lp, 2_500_000e6);

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,
            platformManagementFeeRate:  0.08e6
        });

        loanManager = poolManager.loanManagerList(0);

        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(2)],
            amounts:     [uint256(0), uint256(2_000_000e6), uint256(0)],
            rates:       [uint256(3.1536e6), 0, 0, 0],  // 0.1e6 tokens per second
            loanManager: loanManager
        });

    }

    function test_makePayment_onTimePayment_amortized() public {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(2_500_000e6);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      2_000_000e6,
            issuanceRate:      0.18e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertFixedTermLoan({
            loan:              loan,
            principal:         2_000_000e6,
            incomingPrincipal: 952_380_952380,     // Principal is adjusted to make equal loan payments across the term.
            incomingInterest:  200_000e6,          // 0.1 * 2_000_000 = 200_000
            incomingFees:      20_000e6 + 300e6,   // 20_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 2
        });

        // PoolDelegate and treasury get their own originationFee
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [500e6,        126_839167]
        );

        /******************************/
        /*** Pre Payment Assertions ***/
        /******************************/

        vm.warp(start + 1_000_000);

        assertTotalAssets(2_500_000e6 + 180_000e6);

        assertFixedTermLoan({
            loan:              loan,
            principal:         2_000_000e6,
            incomingPrincipal: 952_380_952380,
            incomingInterest:  200_000e6,          // 0.1 * 1_000_000 = 100_000
            incomingFees:      20_000e6 + 300e6,   // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 2
        });

        uint256 payment1Principal = 952_380_952380;
        uint256 payment1Interest  = 200_000e6;

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   180_000e6,
            accountedInterest: 0,
            principalOut:      2_000_000e6,
            issuanceRate:      0.18e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        makePayment(loan);

        assertTotalAssets(2_500_000e6 + 180_000e6);

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_047_619_047620,
            incomingPrincipal: 1_047_619_047620,
            incomingInterest : 104_761_904762,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 1
        });

        uint256 payment2Principal = 1_047_619_047620;
        uint256 payment2Interest  = 104_761_904762;

        // Assert that payments are equal
        assertApproxEqAbs(payment1Principal + payment1Interest, payment2Principal + payment2Interest, 5);

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 94_285_714285,
            refinanceInterest:   0,
            issuanceRate:        0.094285714285e6 * 1e30,
            startDate:           start + 1_000_000,
            paymentDueDate:      start + 2_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      1_047_619_047620,
            issuanceRate:      0.094285714285e6 * 1e30,
            domainStart:       start + 1_000_000,
            domainEnd:         start + 2_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + payment1Principal + 180_000e6);

        // Pool Delegate fee: 300e6    flat from service fee + 4_000e6 from management fee
        // Treasury fee:      20_000e6 flat from service fee + 16_000e6 from management fee
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [4_300e6,      36_000e6]
        );
    }

    function test_makePayment_earlyPayment_amortized() public {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(2_500_000e6);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      2_000_000e6,
            issuanceRate:      0.18e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertFixedTermLoan({
            loan:              loan,
            principal:         2_000_000e6,
            incomingPrincipal: 952_380_952380,     // Principal is adjusted to make equal loan payments across the term.
            incomingInterest:  200_000e6,          // 0.1 * 1_000_000 = 100_000
            incomingFees:      20_000e6 + 300e6,   // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 2
        });

        // PoolDelegate and treasury get their own originationFee
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [500e6,        126_839167]
        );

        /******************************/
        /*** Pre Payment Assertions ***/
        /******************************/

        vm.warp(start + 600_000);

        assertTotalAssets(2_500_000e6 + 108_000e6);

        assertFixedTermLoan({
            loan:              loan,
            principal:         2_000_000e6,
            incomingPrincipal: 952_380_952380,
            incomingInterest:  200_000e6,          // 0.1 * 1_000_000 = 100_000
            incomingFees:      20_000e6 + 300e6,   // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 2
        });

        uint256 payment1Principal = 952_380_952380;
        uint256 payment1Interest  = 200_000e6;

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   108_000e6,
            accountedInterest: 0,
            principalOut:      2_000_000e6,
            issuanceRate:      0.18e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        makePayment(loan);

        assertTotalAssets(2_500_000e6 + 180_000e6);

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_047_619_047620,
            incomingPrincipal: 1_047_619_047620,
            incomingInterest : 104_761_904762,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 1
        });

        uint256 payment2Principal = 1_047_619_047620;
        uint256 payment2Interest  = 104_761_904762;

        // Assert that payments are equal
        assertApproxEqAbs(payment1Principal + payment1Interest, payment2Principal + payment2Interest, 5);

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 94_285_714285,
            refinanceInterest:   0,
            issuanceRate:        0.067346938775e6 * 1e30,
            startDate:           start + 600_000,
            paymentDueDate:      start + 2_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      1_047_619_047620,
            issuanceRate:      0.067346938775e6 * 1e30,
            domainStart:       start + 600_000,
            domainEnd:         start + 2_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + payment1Principal + 180_000e6);

        // Pool Delegate fee: 300e6    flat from service fee + 4_000e6 from management fee
        // Treasury fee:      20_000e6 flat from service fee + 16_000e6 from management fee
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [4_300e6,      36_000e6]
        );
    }

    function test_makePayment_latePayment_amortized() public {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(2_500_000e6);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      2_000_000e6,
            issuanceRate:      0.18e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertFixedTermLoan({
            loan:              loan,
            principal:         2_000_000e6,
            incomingPrincipal: 952_380_952380,     // Principal is adjusted to make equal loan payments across the term.
            incomingInterest:  200_000e6,          // 0.1 * 1_000_000 = 100_000
            incomingFees:      20_000e6 + 300e6,   // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 2
        });

        // PoolDelegate and treasury get their own originationFee
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [500e6,        126_839167]
        );

        /******************************/
        /*** Pre Payment Assertions ***/
        /******************************/

        vm.warp(start + 1_200_000);

        assertTotalAssets(2_500_000e6 + 180_000e6);

        assertFixedTermLoan({
            loan:              loan,
            principal:         2_000_000e6,
            incomingPrincipal: 952_380_952380,
            incomingInterest:  200_000e6 + 51_840e6,  // 0.1 * 1_000_000 + late(86400 seconds * 3 * 0.2) = 51_840
            incomingFees:      20_000e6 + 300e6,      // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 2
        });

        uint256 payment1Principal = 952_380_952380;
        uint256 payment1Interest  = 200_000e6;

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   180_000e6,
            accountedInterest: 0,
            principalOut:      2_000_000e6,
            issuanceRate:      0.18e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        makePayment(loan);

        // (Principal + cash) + interest + late interest + 200k seconds of interest on remaining principal
        assertTotalAssets(2_500_000e6 + 180_000e6 + 46_656e6 + 18_857_142857);

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_047_619_047620,
            incomingPrincipal: 1_047_619_047620,
            incomingInterest : 104_761_904762,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 1
        });

        uint256 payment2Principal = 1_047_619_047620;
        uint256 payment2Interest  = 104_761_904762;

        // Assert that payments are equal
        assertApproxEqAbs(payment1Principal + payment1Interest, payment2Principal + payment2Interest, 5);

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 94_285_714285,
            refinanceInterest:   0,
            issuanceRate:        0.094285714285e6 * 1e30,
            startDate:           start + 1_000_000,
            paymentDueDate:      start + 2_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 18_857_142857,    // 200_000sec of the IR
            principalOut:      1_047_619_047620,
            issuanceRate:      0.094285714285e6 * 1e30,
            domainStart:       start + 1_200_000,
            domainEnd:         start + 2_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + payment1Principal + 180_000e6 + 46_656e6);

        // Pool Delegate fee: 300e6    flat from service fee + 4_000e6 from management fee  + late interest (51_840e6 * 0.02 = 1036_800000)
        // Treasury fee:      20_000e6 flat from service fee + 16_000e6 from management fee + late interest (51_840e6 * 0.08 = 4147_200000)
        assertAssetBalancesIncrease(
            [poolDelegate,        treasury],
            [4_300e6 + 1_036.8e6, 36_000e6 + 4_147.2e6]
        );
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

    IOpenTermLoan        loan;
    IOpenTermLoanManager loanManager;

    function setUp() public override {
        super.setUp();

        deposit(lp, 1_500_000e6);

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.031536e6,  // 1k after 1m seconds
            platformManagementFeeRate:  0.08e6
        });

        loanManager = IOpenTermLoanManager(poolManager.loanManagerList(1));

        loan = IOpenTermLoan(createOpenTermLoan(
            address(borrower),
            address(loanManager),
            address(fundsAsset),
            principal,
            [gracePeriod, noticePeriod, paymentInterval],
            [0.015768e6, interestRate, 0, 0.015768e6]
        ));

        fundLoan(address(loan));
    }

    function test_makePayment_OT_onTimePayment() public {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertPoolState({
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
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [500e6 + 20e6, 1_000e6 + 80e6]
        );
    }

    function test_makePayment_OT_latePayment() public {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertPoolState({
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
            totalSupply:        1_500_000e6,
            totalAssets:        1_500_000e6 + 990e6,
            unrealizedLosses:   0,
            availableLiquidity: 500_000e6
        });

        assertOpenTermLoanPaymentState({
            loan:               address(loan),
            paymentTimestamp:   uint40(block.timestamp),
            principal:          0,
            interest:           1_100e6,
            lateInterest:       50e6, // 100_000s at interest premium.
            delegateServiceFee: 550e6,
            platformServiceFee: 1_100e6,
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
            loanManager:       address(loanManager),
            accountedInterest: 0,          // Accounted during claim
            principalOut:      1_000_000e6,
            accruedInterest:   0,
            issuanceRate:      0.0009e6 * 1e27,
            domainStart:       start + 1_100_000,
            unrealizedLosses:  0
        });

        // Pool Delegate fee: 550e6   (1_100_000s of service fee) + 0.02 * 1_150e6 (management fee)
        // Treasury fee:      1_100e6 (1_100_000s of service fee) + 0.08 * 1_150e6
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [550e6 + 23e6, 1_100e6 + 92e6]
        );
    }

    function test_makePayment_OT_withCall() public {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertPoolState({
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
            loanManager:       address(loanManager),
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            accruedInterest:   540e6,  // 90% of 600e6
            issuanceRate:      0.0009e6 * 1e27,
            domainStart:       start,
            unrealizedLosses:  0
        });

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        makePayment(address(loan));

        assertPoolState({
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
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [300e6 + 12e6, 600e6 + 48e6]
        );
    }

    function test_makePayment_OT_withImpairment() public {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertPoolState({
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
            totalSupply:        1_500_000e6,
            totalAssets:        1_500_000e6 + 720e6,
            unrealizedLosses:   1_000_000e6 + 720e6,
            availableLiquidity: 500_000e6
        });

        assertOpenTermLoanPaymentState({
            loan:               address(loan),
            paymentTimestamp:   uint40(start + 1_200_000),
            principal:          0,
            interest:           1200e6,  // Accruing for 1.2m seconds
            lateInterest:       200e6,   // Accruing for 400k seconds since impaired at 800k
            delegateServiceFee: 600e6,
            platformServiceFee: 1200e6,
            paymentDueDate:     uint40(start + 800_000),
            defaultDate:        start + 1_000_000
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
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [600e6 + 28e6, 1_200e6 + 112e6]
        );
    }

}

contract MakePaymentTestsTwoLoans is TestBaseWithAssertions {

    address borrower1;
    address borrower2;
    address loan1;
    address loan2;
    address loanManager;
    address lp;

    function setUp() public override {
        super.setUp();

        borrower1 = makeAddr("borrower1");
        borrower2 = makeAddr("borrower2");
        lp        = makeAddr("lp");

        deposit(lp, 3_500_000e6);

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,  // 10k after 1m seconds
            platformManagementFeeRate:  0.08e6
        });

        loanManager = poolManager.loanManagerList(0);

        loan1 = fundAndDrawdownLoan({
            borrower:    borrower1,
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e6), 0, 0, 0],  // 0.1e6 tokens per second
            loanManager: loanManager
        });

        vm.warp(start + 300_000);

        loan2 = fundAndDrawdownLoan({
            borrower:    borrower2,
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(2_000_000e6), uint256(2_000_000e6)],
            rates:       [uint256(3.1536e6), 0, 0, 0],  // 0.1e6 tokens per second
            loanManager: loanManager
        });
    }

    function test_makePayment_onTimePayment_interestOnly_onTimePayment_interestOnly() external {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(3_500_000e6 + 27_000e6);  // Already warped 300_000 seconds at 0.09 IR after start before funding loan2

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 27_000e6,
            principalOut:      3_000_000e6,
            issuanceRate:      0.27e6 * 1e30,      // 0.09 from loan1 and 0.18 from loan2
            domainStart:       start + 300_000,    // Time of loan2 funding
            domainEnd:         start + 1_000_000,  // Payment due date of loan1
            unrealizedLosses:  0
        });

        // PoolDelegate and treasury get their own originationFee for each loan
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [1_000e6,      285_388126]
        );

        /************************************/
        /*** Pre Loan1 Payment Assertions ***/
        /************************************/

        vm.warp(start + 1_000_000);

        // Principal + 1_000_000s of loan1  at 0.09e6 IR + 700_000s of loan2 at 0.18e6 IR
        assertTotalAssets(3_500_000e6 + 90_000e6 + 126_000e6);

        assertFixedTermLoan({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6,          // 0.1 * 1_000_000 = 100_000
            incomingFees:      10_000e6 + 300e6,   // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   90_000e6 + 126_000e6 - 27_000e6,
            accountedInterest: 27_000e6,
            principalOut:      3_000_000e6,
            issuanceRate:      0.27e6 * 1e30,
            domainStart:       start + 300_000,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        /*************************************/
        /*** Post Loan1 Payment Assertions ***/
        /*************************************/

        makePayment(loan1);

        assertTotalAssets(3_500_000e6 + 90_000e6 + 126_000e6);  // Principal + 1_000_000s of loan1 at 0.09 + 700_000s of loan2 at 0.18e6 IR

        assertFixedTermLoan({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6,          // 0.1 * 1_000_000 = 100_000
            incomingFees:      10_000e6 + 300e6,   // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start + 1_000_000,
            paymentDueDate:      start + 2_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 126_000e6,    // 700_000s at 0.18e6
            principalOut:      3_000_000e6,
            issuanceRate:      0.27e6 * 1e30,
            domainStart:       start + 1_000_000,
            domainEnd:         start + 1_300_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 90_000e6);

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [2_300e6,      18_000e6]
        );

        /************************************/
        /*** Pre Loan2 Payment Assertions ***/
        /************************************/

        vm.warp(start + 1_300_000);

        // Principal + 1_300_000s of loan1 at 0.9e6 + 1_000_000s of loan2 at 0.18e6 IR
        assertTotalAssets(3_500_000e6 + 117_000e6 + 180_000e6);

        assertFixedTermLoan({
            loan:              loan2,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_300_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan2,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 300_000,
            paymentDueDate:      start + 1_300_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   27_000e6 + 180_000e6 - 126_000e6,  // loan1 + loan2 - accounted from loan2
            accountedInterest: 126_000e6,    // 700_000s at 0.18e6
            principalOut:      3_000_000e6,
            issuanceRate:      0.27e6 * 1e30,
            domainStart:       start + 1_000_000,
            domainEnd:         start + 1_300_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 90_000e6);

        /*************************************/
        /*** Post Loan2 Payment Assertions ***/
        /*************************************/

        makePayment(loan2);

        // Principal + 1_300_000s of loan1 at 0.9e6 + 1_000_000s of loan2 at 0.18e6 IR
        assertTotalAssets(3_500_000e6 + 117_000e6 + 180_000e6);

        assertFixedTermLoan({
            loan:              loan2,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2_300_000,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                loan2,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 1_300_000,
            paymentDueDate:      start + 2_300_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 27_000e6,    // 700_000s at 0.18e6
            principalOut:      3_000_000e6,
            issuanceRate:      0.27e6 * 1e30,
            domainStart:       start + 1_300_000,
            domainEnd:         start + 2_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 90_000e6 + 180_000e6);

        // Pool Delegate fee: 300e6    flat from service fee + 4_000e6 from management fee
        // Treasury fee:      10_000e6 flat from service fee + 16_000e6 from management fee
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [4_300e6,      36_000e6]
        );

        /********************************************/
        /*** Post Loan1 second Payment Assertions ***/
        /********************************************/

        vm.warp(start + 2_000_000);

        makePayment(loan1);

        // Principal + 2_000_000s of loan1 at 0.9e6 + 1_700_000s of loan2 at 0.18e6 IR
        assertTotalAssets(3_500_000e6 + 180_000e6 + 306_000e6);

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 180_000e6 + 180_000e6);  // Two payments of 90k plus one 180k payment

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [2_300e6,      18_000e6]
        );
    }

    function test_makePayment_earlyPayment_interestOnly_onTimePayment_interestOnly() external {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(3_527_000e6);  // 300_000s of loan1 at 0.09e6 IR

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 27_000e6,
            principalOut:      3_000_000e6,
            issuanceRate:      0.27e6 * 1e30,      // 0.09 from loan1 and 0.18 from loan2
            domainStart:       start + 300_000,    // Time of loan2 funding
            domainEnd:         start + 1_000_000,  // Payment due date of loan1
            unrealizedLosses:  0
        });

        // PoolDelegate and treasury get their own originationFee for each loan
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [1_000e6,      285_388126]
        );

        /******************************************/
        /*** Pre Loan1 early Payment Assertions ***/
        /******************************************/

        vm.warp(start + 500_000);

        assertTotalAssets(3_500_000e6 + 45_000e6 + 36_000e6);  // 500_000s of loan1 at 0.09 + 200_000s of loan2 at 0.18e6 IR

        assertFixedTermLoan({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6,         // 0.1 * 1_000_000 = 100_000
            incomingFees:      10_000e6 + 300e6,  // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   45_000e6 + 36_000e6 - 27_000e6,
            accountedInterest: 27_000e6,
            principalOut:      3_000_000e6,
            issuanceRate:      0.27e6 * 1e30,
            domainStart:       start + 300_000,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        /*************************************/
        /*** Post Loan1 Payment Assertions ***/
        /*************************************/

        makePayment(loan1);

        assertTotalAssets(3_500_000e6 + 90_000e6 + 36_000e6);  // Principal + 1_000_000s of loan1 at 0.09 + 700_000s of loan2 at 0.18e6 IR

        assertFixedTermLoan({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6,          // 0.1 * 1_000_000 = 100_000
            incomingFees:      10_000e6 + 300e6,   // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.06e6 * 1e30,
            startDate:           start + 500_000,
            paymentDueDate:      start + 2_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 36_000e6,           // 200_000s at 0.18e6
            principalOut:      3_000_000e6,
            issuanceRate:      0.24e6 * 1e30,      // 0.18 from loan2 and 0.6 from loan1
            domainStart:       start + 500_000,
            domainEnd:         start + 1_300_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 90_000e6);

        /************************************/
        /*** Pre Loan2 Payment Assertions ***/
        /************************************/

        vm.warp(start + 1_300_000);

        // Principal + loan1 payment interest + 800_000s of loan1 at 0.6e6 + 1_000_000s of loan2 at 0.18e6 IR
        assertTotalAssets(3_500_000e6 + 90_000e6 + 48_000e6 + 180_000e6);

        assertFixedTermLoan({
            loan:              loan2,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_300_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan2,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 300_000,
            paymentDueDate:      start + 1_300_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            // 800_000s of loan1 at 0.06 + 1_000_000s of loan2 at 0.18e6 - accounted
            loanManager:       loanManager,
            accruedInterest:   48_000e6 + 180_000e6 - 36_000e6,
            accountedInterest: 36_000e6,                         // 200_000s at 0.18e6
            principalOut:      3_000_000e6,
            issuanceRate:      0.24e6 * 1e30,
            domainStart:       start + 500_000,
            domainEnd:         start + 1_300_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 90_000e6);

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [2_300e6,      18_000e6]
        );

        /*************************************/
        /*** Post Loan2 Payment Assertions ***/
        /*************************************/

        makePayment(loan2);

        // Principal + loan1 payment interest + 800_000s of loan1 at 0.6e6 + 1_000_000s of loan2 at 0.18e6 IR
        assertTotalAssets(3_500_000e6 + 90_000e6 + 48_000e6 + 180_000e6);

        assertFixedTermLoan({
            loan:              loan2,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2_300_000,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                loan2,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 1_300_000,
            paymentDueDate:      start + 2_300_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 48_000e6,           // 800_000s at 0.06e6
            principalOut:      3_000_000e6,
            issuanceRate:      0.24e6 * 1e30,
            domainStart:       start + 1_300_000,
            domainEnd:         start + 2_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 90_000e6 + 180_000e6);

        // Pool Delegate fee: 300e6    flat from service fee + 4_000e6 from management fee
        // Treasury fee:      10_000e6 flat from service fee + 16_000e6 from management fee
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [4_300e6,      36_000e6]
        );

        /********************************************/
        /*** Post Loan1 second Payment Assertions ***/
        /********************************************/

        vm.warp(start + 2_000_000);

        makePayment(loan1);

        // Asserting this because all tests should be in sync after second loan1 payment
        // Principal + 2_000_000s of loan1 at 0.9e6 + 1_700_000s of loan2 at 0.18e6 IR
        assertTotalAssets(3_500_000e6 + 180_000e6 + 306_000e6);

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 180_000e6 + 180_000e6);

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [2_300e6,      18_000e6]
        );
    }

    function test_makePayment_latePayment_interestOnly_onTimePayment_interestOnly() external {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(3_527_000e6);  // Already warped 300_000 seconds at 0.09 IR after start before funding loan2

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 27_000e6,
            principalOut:      3_000_000e6,
            issuanceRate:      0.27e6 * 1e30,      // 0.09 from loan1 and 0.18 from loan2
            domainStart:       start + 300_000,    // Time of loan2 funding
            domainEnd:         start + 1_000_000,  // Payment due date of loan1
            unrealizedLosses:  0
        });

        // PoolDelegate and treasury get their own originationFee for each loan
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [1_000e6,      285_388126]
        );

        /*****************************************/
        /*** Pre Loan1 Late Payment Assertions ***/
        /*****************************************/

        vm.warp(start + 1_100_000);

        // Principal + 1_000_000s of loan1 at 0.09e6 IR + 700_000s of loan2 at 0.18e6 IR.
        // The issuance stops at DomainEnd, so no accrual after second 1_000_000
        assertTotalAssets(3_500_000e6 + 90_000e6 + 126_000e6);

        assertFixedTermLoan({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  117_280e6,          // 0.1 * 1_000_000 = 100_000 + late(86400 seconds * 2 * 0.1) = 17_280
            incomingFees:      10_000e6 + 300e6,   // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   90_000e6 + 126_000e6 - 27_000e6,
            accountedInterest: 27_000e6,
            principalOut:      3_000_000e6,
            issuanceRate:      0.27e6 * 1e30,
            domainStart:       start + 300_000,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        /*************************************/
        /*** Post Loan1 Payment Assertions ***/
        /*************************************/

        makePayment(loan1);

        // Principal:                           3_500_000e6
        // interest from period:                90_000e6
        // 2 days of late interest:             2 * 86400 seconds * 0.09 = 15_552e6
        // 100_000s of interest from 2 payment: 9_000e6
        // Principal + 1_000_000s of loan1 at 0.09 + 800_000s of loan2 at 0.18e6 IR + late fees
        assertTotalAssets(3_500_000e6 + 90_000e6 + 9_000e6 + 15_552e6 + 144_000e6);

        assertFixedTermLoan({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6,
            incomingFees:      10_000e6 + 300e6,   // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start + 1_000_000,
            paymentDueDate:      start + 2_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 144_000e6 + 9_000e6,  // 800_000s at 0.18e6 + 9_000e6 accrued from 100_000s at 0.9e6 from loan1
            principalOut:      3_000_000e6,
            issuanceRate:      0.27e6 * 1e30,
            domainStart:       start + 1_100_000,
            domainEnd:         start + 1_300_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 90_000e6 + 15_552e6);

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee + late interest (17_280e6 * 0.02 = 345_600000)
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee + late interest (17_280e6 * 0.08 = 1382_400000)
        assertAssetBalancesIncrease(
            [poolDelegate,      treasury],
            [2_300e6 + 345.6e6, 18_000e6 + 1382.4e6]
        );

        /************************************/
        /*** Pre Loan2 Payment Assertions ***/
        /************************************/

        vm.warp(start + 1_300_000);

        // Principal + 1_300_000s of loan1 at 0.9e6 + 1_000_000s of loan2 at 0.18e6 IR + loan1 late interest
        assertTotalAssets(3_500_000e6 + 117_000e6 + 180_000e6 + 15_552e6);

        assertFixedTermLoan({
            loan:              loan2,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_300_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan2,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 300_000,
            paymentDueDate:      start + 1_300_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   27_000e6 + 180_000e6 - (144_000e6 + 9_000e6),  // loan1 + loan2 - accounted from loan2
            accountedInterest: 144_000e6 + 9_000e6,                           // 700_000s at 0.18e6
            principalOut:      3_000_000e6,
            issuanceRate:      0.27e6 * 1e30,
            domainStart:       start + 1_100_000,
            domainEnd:         start + 1_300_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 90_000e6 + 15_552e6);

        /*************************************/
        /*** Post Loan2 Payment Assertions ***/
        /*************************************/

        makePayment(loan2);

        // Principal + 1_300_000s of loan1 at 0.9e6 + 1_000_000s of loan2 at 0.18e6 IR
        assertTotalAssets(3_500_000e6 + 117_000e6 + 180_000e6 + 15_552e6);

        assertFixedTermLoan({
            loan:              loan2,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2_300_000,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                loan2,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 1_300_000,
            paymentDueDate:      start + 2_300_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 27_000e6,           // 700_000s at 0.18e6
            principalOut:      3_000_000e6,
            issuanceRate:      0.27e6 * 1e30,
            domainStart:       start + 1_300_000,
            domainEnd:         start + 2_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 90_000e6 + 180_000e6 + 15_552e6);

        // Pool Delegate fee: 300e6    flat from service fee + 4_000e6 from management fee
        // Treasury fee:      10_000e6 flat from service fee + 16_000e6 from management fee
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [4_300e6, 36_000e6]
        );

        /********************************************/
        /*** Post Loan1 second Payment Assertions ***/
        /********************************************/

        vm.warp(start + 2_000_000);

        makePayment(loan1);

        // Principal + 2_000_000s of loan1 at 0.9e6 + 1_700_000s of loan2 at 0.18e6 IR + late fees
        assertTotalAssets(3_500_000e6 + 180_000e6 + 306_000e6 + 15_552e6);

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 180_000e6 + 180_000e6 + 15_552e6);

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [2_300e6,      18_000e6]
        );
    }

}

// TODO: Add closeLoan coverage

contract MakePaymentTestsDomainStartGtDomainEnd is TestBaseWithAssertions {

    address borrower1;
    address borrower2;
    address loan1;
    address loan2;
    address loanManager;
    address lp;

    function setUp() public override {
        super.setUp();

        borrower1 = makeAddr("borrower1");
        borrower2 = makeAddr("borrower2");
        lp        = makeAddr("lp");

        loanManager = poolManager.loanManagerList(0);

        deposit(lp, 3_500_000e6);

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,
            platformManagementFeeRate:  0.08e6
        });
    }

    function test_makePayment_domainStart_gt_domainEnd() external {
        // Loan1 is funded at start
        loan1 = fundAndDrawdownLoan({
            borrower:    borrower1,
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e6), 0, 0, 0],  // 0.1e6 tokens per second
            loanManager: loanManager
        });

        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(3_500_000e6);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.09e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,  // Payment due date of loan1.
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 2_500_000e6);

        // PoolDelegate and treasury get their own originationFee for each loan
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [500e6,        95_129375]
        );

        /*********************************/
        /*** Pre loan2 fund Assertions ***/
        /*********************************/

        vm.warp(start + 2_200_000);

        assertTotalAssets(3_500_000e6 + 90_000e6);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   90_000e6,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            // Although it's past the domainEnd, the loanManager haven't been pinged, so it's considering the old issuance rate.
            issuanceRate:      0.09e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertFixedTermLoan({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  220_960e6,          // Includes late interest.
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 2_500_000e6);

        /**********************************/
        /*** Post loan2 fund Assertions ***/
        /**********************************/

        loan2 = fundAndDrawdownLoan({
            borrower:    borrower2,
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(2_000_000e6), uint256(2_000_000e6)],
            rates:       [uint256(3.1536e6), 0, 0, 0],  // 0.1e6 tokens per second
            loanManager: loanManager
        });

        assertTotalAssets(3_500_000e6 + 90_000e6);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 90_000e6,
            principalOut:      3_000_000e6,
            issuanceRate:      0.18e6 * 1e30,      // Only loan2 is accruing.
            domainStart:       start + 2_200_000,
            domainEnd:         start + 3_200_000,
            unrealizedLosses:  0
        });

        assertFixedTermLoan({
            loan:              loan2,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 3_200_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan2,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 2_200_000,
            paymentDueDate:      start + 3_200_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        // PoolDelegate and treasury get their own originationFee
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [500e6,        190_258751]
        );

        /*****************************/
        /*** Pre loan2 1st Payment ***/
        /*****************************/

        vm.warp(start + 3_200_000);

        assertTotalAssets(3_500_000e6 + 90_000e6 + 180_000e6);  // 90_000e6 accounted for loan1 and and 180_000e6 for loan2.

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   180_000e6,
            accountedInterest: 90_000e6,
            principalOut:      3_000_000e6,
            issuanceRate:      0.18e6 * 1e30,      // Only loan2 is accruing.
            domainStart:       start + 2_200_000,
            domainEnd:         start + 3_200_000,
            unrealizedLosses:  0
        });

        // Loan1 Assertions.
        assertFixedTermLoan({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6 + 224_640e6,  // Includes late interest.
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0,                  // IR has been updated for loan 1.
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        // Loan2 Assertions.
        assertFixedTermLoan({
            loan:              loan2,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 3_200_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan2,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 2_200_000,
            paymentDueDate:      start + 3_200_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        /******************************/
        /*** Post loan2 1st Payment ***/
        /******************************/

        makePayment(loan2);

        assertTotalAssets(3_500_000e6 + 90_000e6 + 180_000e6);  // 90_000e6 accounted for loan1 and and 180_000e6 for loan2.

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 90_000e6,
            principalOut:      3_000_000e6,
            issuanceRate:      0.18e6 * 1e30,      // Only loan2 is accruing.
            domainStart:       start + 3_200_000,
            domainEnd:         start + 4_200_000,
            unrealizedLosses:  0
        });

        assertFixedTermLoan({
            loan:              loan2,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 4_200_000,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                loan2,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 3_200_000,
            paymentDueDate:      start + 4_200_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 180_000e6);

        // Pool Delegate fee: 300e6    flat from service fee + 4_000e6 from management fee
        // Treasury fee:      10_000e6 flat from service fee + 16_000e6 from management fee
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [4_300e6,      36_000e6]
        );

        /******************************/
        /*** Make loan1 1st Payment ***/
        /******************************/

        makePayment(loan1);

        // Principal:                            3_000_000e6
        // Cash:                                 500_000e6
        // loan2 1st payment cash:               180_000e6
        // loan1 1st payment cash:               90_000e6
        // loan1 1st payment late interest cash: 202_176e6
        // loan1 2nd payment accounted interest: 90_000e6
        assertTotalAssets(3_500_000e6 + 90_000e6 + 180_000e6 + 202_176e6 + 90_000e6);

        assertFixedTermLoan({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  220_960e6,          // Includes late interest.
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,           // Includes late interest.
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           start + 1_000_000,
            paymentDueDate:      start + 2_000_000,  // Already in the past.
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 90_000e6,
            principalOut:      3_000_000e6,
            issuanceRate:      0.18e6 * 1e30,      // Only loan2 is accruing.
            domainStart:       start + 3_200_000,
            domainEnd:         start + 4_200_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 90_000e6 + 180_000e6 + 202_176e6);

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee + late interest (224_640e6 * 0.02 = 4492_800000)
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee + late interest (224_640e6 * 0.08 = 17971_200000)
        assertAssetBalancesIncrease(
            [poolDelegate,        treasury],
            [2_300e6 + 4_492.8e6, 18_000e6 + 17_971.2e6]
        );

        /******************************/
        /*** Make loan1 2nd Payment ***/
        /******************************/

        makePayment(loan1);

        // Principal:                            3_000_000e6
        // Cash:                                 500_000e6
        // loan2 1st payment cash:               180_000e6
        // loan1 1st payment cash:               90_000e6
        // loan1 1st payment late interest cash: 202_176e6 (26 * 86400 seconds * 0.09 = 202_176e6)
        // loan1 2nd payment cash:               90_000e6
        // loan1 2nd payment late interest cash: 108_864e6 (14 * 86400 seconds * 0.09 = 108_864e6)
        // loan1 3rd payment accounted interest: 90_000e6

        assertTotalAssets(3_500_000e6 + 180_000e6 + 90_000e6 + 202_176e6 + 90_000e6 + 108_864e6 + 90_000e6);

        assertFixedTermLoan({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 1_000_000e6,
            incomingInterest:  125_920e6,          // Includes late interest.
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 3_000_000,
            paymentsRemaining: 1
        });

        assertFixedTermPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           start + 2_000_000,
            paymentDueDate:      start + 3_000_000,  // Already in the past.
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 90_000e6,
            principalOut:      3_000_000e6,
            issuanceRate:      0.18e6 * 1e30,      // Only loan2 is accruing.
            domainStart:       start + 3_200_000,
            domainEnd:         start + 4_200_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 180_000e6 + 90_000e6 + 202_176e6 + 90_000e6 + 108_864e6);

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee + late interest (120_960e6 * 0.02 = 2419_200000)
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee + late interest (120_960e6 * 0.08 = 9676_800000)
        assertAssetBalancesIncrease(
            [poolDelegate,        treasury],
            [2_300e6 + 2_419.2e6, 18_000e6 + 9_676.8e6]
        );

        /*******************************/
        /*** Make loan1 last Payment ***/
        /*******************************/

        makePayment(loan1);

        // Principal:                            3_000_000e6
        // Cash:                                 500_000e6
        // loan2 1st payment cash:               180_000e6
        // loan1 1st payment cash:               90_000e6
        // loan1 1st payment late interest cash: 202_176e6 (26 * 86400 seconds * 0.09 = 202_176e6)
        // loan1 2nd payment cash:               90_000e6
        // loan1 2nd payment late interest cash: 108_864e6 (14 * 86400 seconds * 0.09 = 108_864e6)
        // loan1 3rd payment cash:               90_000e6
        // loan1 3rd payment late interest cash: 23_328e6 (3 * 86400 seconds * 0.09 = 23_328e6)
        assertTotalAssets(3_500_000e6 + 180_000e6 + 90_000e6 + 202_176e6 + 90_000e6 + 108_864e6 + 90_000e6 + 23_328e6);

        // Loan has be removed from storage.
        assertFixedTermPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0,
            platformFeeRate:     0,
            delegateFeeRate:     0
        });

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      2_000_000e6,
            issuanceRate:      0.18e6 * 1e30,      // Only loan2 is accruing.
            domainStart:       start + 3_200_000,
            domainEnd:         start + 4_200_000,
            unrealizedLosses:  0
        });

        assertEq(
            fundsAsset.balanceOf(address(pool)),
            1_500_000e6 + 180_000e6 + 90_000e6 + 202_176e6 + 90_000e6 + 108_864e6 + 90_000e6 + 23_328e6
        );

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee + late interest (25_920e6 * 0.02 = 518_400000)
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee + late interest (25_920e6 * 0.08 = 2073_600000)
        assertAssetBalancesIncrease(
            [poolDelegate,      treasury],
            [2_300e6 + 518.4e6, 18_000e6 + 2_073.6e6]
        );
    }
}

contract MakePaymentTestsPastDomainEnd is TestBaseWithAssertions {

    address borrower1;
    address borrower2;
    address borrower3;
    address loan1;
    address loan2;
    address loan3;
    address loanManager;
    address lp;

    function setUp() public override {
        super.setUp();

        borrower1 = makeAddr("borrower1");
        borrower2 = makeAddr("borrower2");
        borrower3 = makeAddr("borrower3");
        lp        = makeAddr("lp");

        deposit(lp, 6_500_000e6);

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,
            platformManagementFeeRate:  0.08e6
        });

        loanManager = poolManager.loanManagerList(0);

        loan1 = fundAndDrawdownLoan({
            borrower:    borrower1,
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e6), uint256(0), uint256(0), uint256(0)],   // 0.1e6 tokens per second
            loanManager: loanManager
        });

        vm.warp(start + 400_000);

        loan2 = fundAndDrawdownLoan({
            borrower:    borrower2,
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(2_000_000e6), uint256(2_000_000e6)],
            rates:       [uint256(3.1536e6), uint256(0), uint256(0), uint256(0)],   // 0.1e6 tokens per second
            loanManager: loanManager
        });

        vm.warp(start + 600_000);

        loan3 = fundAndDrawdownLoan({
            borrower:    borrower3,
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(3_000_000e6), uint256(3_000_000e6)],
            rates:       [uint256(3.1536e6), uint256(0), uint256(0), uint256(0)],   // 0.1e6 tokens per second
            loanManager: loanManager
        });
    }

    function test_makePayment_lateLoan3_loan1NotPaid_loan2NotPaid() external {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        // loan1
        assertFixedTermLoan({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6,
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        // loan2
        assertFixedTermLoan({
            loan:              loan2,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_400_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan2,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 400_000,
            paymentDueDate:      start + 1_400_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        // loan3
        assertFixedTermLoan({
            loan:              loan3,
            principal:         3_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  300_000e6,
            incomingFees:      30_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_600_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan3,
            incomingNetInterest: 270_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.27e6 * 1e30,
            startDate:           start + 600_000,
            paymentDueDate:      start + 1_600_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        // Principal:      6_500_000e6
        // loan1 interest: 600_000s * 0.09e6 = 54_000e6
        // loan2 interest: 200_000s * 0.18e6 = 36_000e6
        assertTotalAssets(6_500_000e6 + 54_000e6 + 36_000e6);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 54_000e6 + 36_000e6,
            principalOut:      6_000_000e6,
            issuanceRate:      0.54e6 * 1e30,
            domainStart:       start + 600_000,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        // PoolDelegate and treasury get their own originationFee for each loan
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [1_500e6,      570_776253]
        );

        /******************************/
        /*** Loan3 pre late Payment ***/
        /******************************/

        vm.warp(start + 1_700_000);

        // loan3
        assertFixedTermLoan({
            loan:              loan3,
            principal:         3_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  351_840e6,          // 2 days of late interest (86400 * 2 * 0.3)
            incomingFees:      30_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_600_000,
            paymentsRemaining: 3
        });

        // Principal:      6_500_000e6
        // loan1 interest: 1_000_000s * 0.09e6 = 90_000e6
        // loan2 interest: 600_000s * 0.18e6 = 108_000e6
        // loan3 interest: 400_000s * 0.27e6 = 108_000e6
        assertTotalAssets(6_500_000e6 + 90_000e6 + 108_000e6 + 108_000e6);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   (90_000e6 - 54_000e6) + (108_000e6 - 36_000e6) + 108_000e6,
            accountedInterest: 54_000e6 + 36_000e6,
            principalOut:      6_000_000e6,
            issuanceRate:      0.54e6 * 1e30,
            domainStart:       start + 600_000,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        /*******************************/
        /*** Loan3 post late Payment ***/
        /*******************************/

        makePayment(loan3);

        // loan1
        assertFixedTermLoan({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  177_760e6,          // 700_000s (9 days rounded up) of interest: (86400 * 9 * 0.1) = 77_760
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        // loan2
        assertFixedTermLoan({
            loan:              loan2,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  269_120e6,          // 300_000s (4 days rounded up) of interest: (86400 * 4 * 0.2) = 69_120
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_400_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan2,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           start + 400_000,
            paymentDueDate:      start + 1_400_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoan({
            loan:              loan3,
            principal:         3_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  300_000e6,          // 2 days of late interest (86400 * 2 * 0.3)
            incomingFees:      30_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2_600_000,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                loan3,
            incomingNetInterest: 270_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.27e6 * 1e30,
            startDate:           start + 1_600_000,
            paymentDueDate:      start + 2_600_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        // Principal:        6_500_000e6
        // loan1 interest (1st payment): 1_000_000s * 0.09e6 = 90_000e6
        // loan2 interest (1st payment): 1_000_000s * 0.18e6 = 180_000e6
        // loan3 interest (1st payment): 1_000_000s * 0.27e6 = 270_000e6
        // loan3 interest (2nd payment): 100_000s * 0.27e6 = 27_000e6
        // loan3 late interest:          86400s * 2 * 0.27 = 46_656e6
        assertTotalAssets(6_500_000e6 + 90_000e6 + 180_000e6 + 270_000e6 + 27_000e6 + 46_656e6);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 90_000e6 + 180_000e6 + 27_000e6,
            principalOut:      6_000_000e6,
            issuanceRate:      0.27e6 * 1e30,
            domainStart:       start + 1_700_000,
            domainEnd:         start + 2_600_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 270_000e6 + 46_656e6);

        // Pool Delegate fee: 300e6    flat from service fee + 6_000e6 from management fee  + late interest (51_840e6 * 0.02 = 345_600000)
        // Treasury fee:      30_000e6 flat from service fee + 24_000e6 from management fee + late interest (51_840e6 * 0.08 = 1382_400000)
        assertAssetBalancesIncrease(
            [poolDelegate,        treasury],
            [6_300e6 + 1_036.8e6, 54_000e6 + 4_147.2e6]
        );
    }

}
