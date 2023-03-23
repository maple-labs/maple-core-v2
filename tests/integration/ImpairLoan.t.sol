// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IFixedTermLoan,
    IFixedTermLoanManager,
    ILoanLike,
    ILoanManagerLike,
    IOpenTermLoan,
    IOpenTermLoanManager
} from "../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

contract ImpairLoanFailureTests is TestBaseWithAssertions {

    address borrower;
    address lp;

    IFixedTermLoan        loan;
    IFixedTermLoanManager loanManager;

    function setUp() public virtual override {
        super.setUp();

        borrower = makeAddr("borrower");
        lp       = makeAddr("lp");

        depositCover(100_000e6);

        depositLiquidity(lp, 1_500_000e6);

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
            borrower:    borrower,
            termDetails: [uint256(5_000), uint256(ONE_MONTH), uint256(3)],
            amounts:     [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.075e18), 0, 0, 0],
            loanManager: address(loanManager)
        }));
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

    function test_impairLoan_notLender() external {
        vm.expectRevert("ML:IL:NOT_LENDER");
        loan.impairLoan();
    }

    // TODO: Check if impairing an impaired loan should be a valid use case.
    function test_impairLoan_alreadyImpaired() external {
        vm.prank(poolDelegate);
        loanManager.impairLoan(address(loan));

        vm.prank(poolDelegate);
        vm.expectRevert("LM:IL:IMPAIRED");
        loanManager.impairLoan(address(loan));
    }

}

contract ImpairLoanSuccessTests is TestBaseWithAssertions {

    address borrower;
    address loan;
    address loanManager;
    address lp;

    function setUp() public override {
        super.setUp();

        borrower    = makeAddr("borrower");
        loanManager = poolManager.loanManagerList(0);
        lp          = makeAddr("lp");

        depositCover(100_000e6);

        depositLiquidity(lp, 1_500_000e6);

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         275e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.0066e6,
            platformManagementFeeRate:  0.08e6
        });

        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5_000), uint256(ONE_MONTH), uint256(3)],
            amounts:     [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.075e18), 0, 0, 0],
            loanManager: loanManager
        });

        // Pool liquidity:  1,500,000 - 1,000,000  = 500,000
        // Gross interest:  1,000,000 * 7.50% / 12 =   6,250
        // Service fees:                 275 + 550 =     825
        // Management fees:              125 + 500 =     625
        // Net interest:         6,250 - 125 - 500 =   5,625

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + ONE_MONTH,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6 - 1,  // -1 due to rounding error.
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start,
            paymentDueDate:      start + ONE_MONTH,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:           loanManager,
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          5_625e6 * 1e30 / ONE_MONTH,
            domainStart:           start,
            domainEnd:             start + ONE_MONTH,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_500_000e6,
            unrealizedLosses: 0
        });

        // Origination fees: 500 + 250 = 750
        // Borrower cash:    1,000,000 - 750 = 999,250

        assertAssetBalances(
            [address(borrower),  address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(999_250e6), uint256(500_000e6), uint256(100_000e6), uint256(500e6),        uint256(250e6)   ]
        );

        /************************************/
        /*** Warp to 1st payment due date ***/
        /************************************/

        vm.warp(start + ONE_MONTH);

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6 - 1,  // -1 due to rounding error.
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start,
            paymentDueDate:      start + ONE_MONTH,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:           loanManager,
            accruedInterest:       5_625e6 - 1,  // -1 due to issuance rate rounding error.
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + 5_625e6 - 1,
            issuanceRate:          5_625e6 * 1e30 / ONE_MONTH,
            domainStart:           start,
            domainEnd:             start + ONE_MONTH,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_500_000e6 + 5_625e6 - 1,
            unrealizedLosses: 0
        });

        /************************/
        /*** Make 1st payment ***/
        /************************/

        makePayment(loan);

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2 * ONE_MONTH,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6 - 1,  // -1 due to rounding error.
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start + 1 * ONE_MONTH,
            paymentDueDate:      start + 2 * ONE_MONTH,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:           loanManager,
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          5_625e6 * 1e30 / ONE_MONTH,
            domainStart:           start + 1 * ONE_MONTH,
            domainEnd:             start + 2 * ONE_MONTH,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_500_000e6 + 5_625e6,
            unrealizedLosses: 0
        });

        assertAssetBalances(
            [address(borrower),  address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(999_250e6), uint256(505_625e6), uint256(100_000e6), uint256(900e6),        uint256(1300e6)  ]
        );

        /*******************************************************/
        /*** Impair loan at 1/5 of the next payment interval ***/
        /*******************************************************/

        vm.warp(start + ONE_MONTH + ONE_MONTH / 5);
        impairLoan(loan);

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    block.timestamp,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6 - 1,  // -1 due to rounding error.
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start + 1 * ONE_MONTH,
            paymentDueDate:      start + 2 * ONE_MONTH,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            uint256(5_625e6 - 1) / 5,  // -1 due to issuance rate rounding error.
            lateInterest:        0,
            platformFees:        550e6 + 500e6 / 5,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:           loanManager,
            accruedInterest:       0,
            accountedInterest:     uint256(5_625e6 - 1) / 5,  // -1 due to issuance rate rounding error.
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + uint256(5_625e6 - 1) / 5,
            issuanceRate:          0,
            domainStart:           block.timestamp,
            domainEnd:             block.timestamp,
            unrealizedLosses:      1_000_000e6 + uint256(5_625e6 - 1) / 5
        });

        assertPoolManager({
            totalAssets:      1_000_000e6 + (5_625e6 / 5 - 1) + 500_000e6 + 5_625e6,
            unrealizedLosses: 1_000_000e6 + (5_625e6 / 5 - 1)
        });

        assertAssetBalances(
            [address(borrower),  address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(999_250e6), uint256(505_625e6), uint256(100_000e6), uint256(900e6),        uint256(1300e6)  ]
        );
    }

    function test_impairLoan_thenCancel() external {
        /**********************************************/
        /*** Remove the loan impairment a day later ***/
        /**********************************************/

        vm.warp(start + ONE_MONTH + ONE_MONTH / 5 + ONE_DAY);

        assertFixedTermLoanManager({
            loanManager:           loanManager,
            accruedInterest:       0,
            accountedInterest:     uint256(5_625e6 - 1) / 5,  // No change, value no longer accruing
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + uint256(5_625e6 - 1) / 5,  // No change, value no longer accruing
            issuanceRate:          0,
            domainStart:           start + ONE_MONTH + ONE_MONTH / 5,
            domainEnd:             start + ONE_MONTH + ONE_MONTH / 5,
            unrealizedLosses:      1_000_000e6 + uint256(5_625e6 - 1) / 5
        });

        assertPoolManager({
            totalAssets:      1_000_000e6 + (5_625e6 / 5 - 1) + 500_000e6 + 5_625e6,
            unrealizedLosses: 1_000_000e6 + (5_625e6 / 5 - 1)
        });

        removeLoanImpairment(loan);

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2 * ONE_MONTH,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6 - 1,  // -1 due to rounding error.
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start + 1 * ONE_MONTH,
            paymentDueDate:      start + 2 * ONE_MONTH,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:           loanManager,
            accruedInterest:       0,
            accountedInterest:     5_625e6 * (ONE_MONTH / 5 + ONE_DAY) / ONE_MONTH,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + 5_625e6 * (ONE_MONTH / 5 + ONE_DAY) / ONE_MONTH,
            issuanceRate:          5_625e6 * 1e30 / ONE_MONTH,
            domainStart:           block.timestamp,
            domainEnd:             start + 2 * ONE_MONTH,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_000_000e6 + 500_000e6 + 5_625e6 + 5_625e6 * (ONE_MONTH / 5 + ONE_DAY) / ONE_MONTH,
            unrealizedLosses: 0
        });

        assertAssetBalances(
            [address(borrower),  address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(999_250e6), uint256(505_625e6), uint256(100_000e6), uint256(900e6),        uint256(1300e6)  ]
        );

        /***********************************************************************/
        /*** Make another payment after the loan impairment has been removed ***/
        /***********************************************************************/

        vm.warp(start + 2 * ONE_MONTH);

        uint256 accountedInterest = 5_625e6 * (ONE_MONTH / 5 + ONE_DAY) / ONE_MONTH;  // Accounted at time of loan impairment removal.

        assertFixedTermLoanManager({
            loanManager:           loanManager,
            accruedInterest:       5_625e6 - accountedInterest - 1,
            accountedInterest:     accountedInterest,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + uint256(5_625e6 - 1),
            issuanceRate:          5_625e6 * 1e30 / ONE_MONTH,
            domainStart:           start + ONE_MONTH + ONE_MONTH / 5 + ONE_DAY,
            domainEnd:             start + 2 * ONE_MONTH,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_000_000e6 + (5_625e6 - 1) + 500_000e6 + 5_625e6,
            unrealizedLosses: 0
        });

        makePayment(loan);

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 3 * ONE_MONTH,
            paymentsRemaining: 1
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6 - 1,  // -1 due to rounding error.
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start + 2 * ONE_MONTH,
            paymentDueDate:      start + 3 * ONE_MONTH,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:           loanManager,
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          5_625e6 * 1e30 / ONE_MONTH,
            domainStart:           block.timestamp,
            domainEnd:             start + 3 * ONE_MONTH,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_000_000e6 + 500_000e6 + 2 * 5_625e6,
            unrealizedLosses: 0
        });

        assertAssetBalances(
            [address(borrower),  address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(999_250e6), uint256(511_250e6), uint256(100_000e6), uint256(1300e6),       uint256(2350e6)  ]
        );
    }

    function test_impairLoan_thenRepay() external {
        /******************************************************/
        /*** Make a payment a day after the loan impairment ***/
        /******************************************************/

        vm.warp(start + ONE_MONTH + ONE_MONTH / 5 + ONE_DAY);
        makePayment(loan);

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2 * ONE_MONTH + ONE_MONTH / 5,
            paymentsRemaining: 1
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6 - 1,  // -1 due to rounding error.
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start + 1 * ONE_MONTH + ONE_MONTH / 5,
            paymentDueDate:      start + 2 * ONE_MONTH + ONE_MONTH / 5,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:           loanManager,
            accruedInterest:       0,
            accountedInterest:     uint256(5_625e6) * 12 / 365,  // one day of interest: 5,625 * 12 / 365
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + uint256(5_625e6) * 12 / 365,
            issuanceRate:          5_625e6 * 1e30 / ONE_MONTH,
            domainStart:           start + ONE_MONTH + ONE_MONTH / 5 + ONE_DAY,
            domainEnd:             start + ONE_MONTH + ONE_MONTH / 5 + ONE_MONTH,
            unrealizedLosses:      0
        });

        // TODO: Add a late interest premium to illustrate difference in late interest.
        assertPoolManager({
            totalAssets:      500_000e6 + 1_000_000e6 + 2 * 5_625e6 + 2 * uint256(5_625e6) * 12 / 365,  // 5_625e6 * 12 / 365 accounted for twice as part is from late interest and part is from the next interval
            unrealizedLosses: 0
        });

        // Pool balance:          500,000       + 5,625 * (2 + 12 / 365)
        // Pool delegate balance: 900     + 275 +   125 * (1 + 12 / 365)
        // Treasury balance:      1,300   + 550 +   500 * (1 + 12 / 365)

        assertAssetBalances(
            [address(borrower),  address(pool),             address(poolCover), address(poolDelegate),   address(treasury)      ],
            [uint256(999_250e6), uint256(511_434.931507e6), uint256(100_000e6), uint256(1_304.109589e6), uint256(2_366.438356e6)]
        );

        /*****************************/
        /*** Make the last payment ***/
        /*****************************/

        vm.warp(start + 2 * ONE_MONTH + ONE_MONTH / 5);
        makePayment(loan);

        assertFixedTermLoan({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0,
            platformFeeRate:     0,
            delegateFeeRate:     0
        });

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:           loanManager,
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           block.timestamp,
            domainEnd:             block.timestamp,
            unrealizedLosses:      0
        });

        // pool balance:          1,000,000 + 500,000 + 5,625 * (3 + 12 / 365)  // Three payments plus one day of late interest.
        // pool delegate balance: 900       + 2 * 275 +   125 * (2 + 12 / 365)
        // treasury balance:      1,300     + 2 * 550 +   500 * (2 + 12 / 365)

        assertPoolManager({
            totalAssets:      1_517_059.931507e6,
            unrealizedLosses: 0
        });

        assertAssetBalances(
            [address(borrower),  address(pool),               address(poolCover), address(poolDelegate),   address(treasury)      ],
            [uint256(999_250e6), uint256(1_517_059.931507e6), uint256(100_000e6), uint256(1_704.109589e6), uint256(3_416.438356e6)]
        );
    }

}

contract ImpairAndRefinanceTests is TestBaseWithAssertions {

    address borrower;
    address loan;
    address loanManager;
    address lp;

    // Principal * 1 month in seconds * annual interest rate * 0.9 to discount fees / 365 days / 1e18 rate precision / 1e6 (0.9) precision.
    uint256 constant GROSS_MONTHLY_INTEREST      = 1_000_000e6 * ONE_MONTH * 0.075e18 / 365 days / 1e18;
    uint256 constant MONTHLY_INTEREST            = GROSS_MONTHLY_INTEREST * 0.9e6 / 1e6;
    uint256 constant GROSS_MONTHLY_LATE_INTEREST = 1_000_000e6 * ONE_MONTH * 0.085e18 / 365 days / 1e18;
    uint256 constant MONTHLY_LATE_INTEREST       = GROSS_MONTHLY_LATE_INTEREST * 0.9e6 / 1e6;

    uint256 platformServiceFee = uint256(1_000_000e6) * 0.0066e6 * ONE_MONTH / 365 days / 1e6;

    function setUp() public override {
        super.setUp();

        borrower    = makeAddr("borrower");
        loanManager = poolManager.loanManagerList(0);
        lp          = makeAddr("lp");

        depositCover(100_000e6);

        depositLiquidity(lp, 1_500_000e6);

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         275e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.0066e6,
            platformManagementFeeRate:  0.08e6
        });

        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5_000), uint256(ONE_MONTH), uint256(3)],
            amounts:     [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.075e18), 0, 0, 0.01e18],
            loanManager: loanManager
        });

        /************************************/
        /*** Warp to 1st payment due date ***/
        /************************************/

        vm.warp(start + ONE_MONTH);

        /************************/
        /*** Make 1st payment ***/
        /************************/

        makePayment(loan);
    }

    function test_impairLoan_earlyThenRefinance() external {
        // Warp 5 days into second payment cycle
        vm.warp(start + ONE_MONTH + 5 days);
        impairLoan(loan);

        uint256 periodInterest = MONTHLY_INTEREST * 5 days / ONE_MONTH;  // 5 days worth of interest

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + ONE_MONTH + 5 days,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: MONTHLY_INTEREST - 1,  // -1 due to rounding error.
            refinanceInterest:   0,
            issuanceRate:        MONTHLY_INTEREST * 1e30 / ONE_MONTH,
            startDate:           start + 1 * ONE_MONTH,
            paymentDueDate:      start + 2 * ONE_MONTH,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            periodInterest,
            lateInterest:        0,
            // During an impairment, platform service fees are paid in full
            // + the time adjust platformManagementFees on top of gross interest
            platformFees:        platformServiceFee + GROSS_MONTHLY_INTEREST * (5 days) / ONE_MONTH * 0.08e6 / 1e6,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:           loanManager,
            accruedInterest:       0,
            accountedInterest:     periodInterest,  // -1 due to issuance rate rounding error.
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + periodInterest,
            issuanceRate:          0,
            domainStart:           block.timestamp,
            domainEnd:             block.timestamp,
            unrealizedLosses:      1_000_000e6 + periodInterest
        });

        assertPoolManager({
            totalAssets:      1_000_000e6 + periodInterest + 500_000e6 + 5_625e6,  // Period interest + previous payment cycle interest
            unrealizedLosses: 1_000_000e6 + periodInterest
        });

        assertAssetBalances(
            [address(borrower),  address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(999_250e6), uint256(505_625e6), uint256(100_000e6), uint256(900e6),        uint256(1300e6)  ]
        );

        // Warp another 5 days
        vm.warp(start + ONE_MONTH + 10 days);

        // Refinance - setting the payment interval will reset the payment due date.
        bytes[] memory data = encodeWithSignatureAndUint("setPaymentInterval(uint256)", ONE_MONTH);

        proposeRefinance(loan, address(refinancer), block.timestamp + 1, data);

        returnFunds(loan, 10_000e6);  // Return funds to pay origination fees. TODO: determine exact amount.

        acceptRefinance(loan, address(refinancer), block.timestamp + 1, data, 0);

        // Impairment was removed
        assertTrue(!ILoanLike(loan).isImpaired());

        // Refinance interest is:
        // 1. A full installment
        // 2. Late interest
        uint256 expectedRefinanceInterest =
            GROSS_MONTHLY_INTEREST +
            GROSS_MONTHLY_LATE_INTEREST * 5 days / ONE_MONTH;

        uint256 expectedNetRefinanceInterest = expectedRefinanceInterest * 0.9e6 / 1e6;

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: expectedRefinanceInterest,
            paymentDueDate:    start + 2 * ONE_MONTH + 10 days,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: MONTHLY_INTEREST - 1,
            refinanceInterest:   expectedNetRefinanceInterest,
            issuanceRate:        MONTHLY_INTEREST * 1e30 / ONE_MONTH,
            startDate:           start + 1 * ONE_MONTH + 10 days,
            paymentDueDate:      start + 2 * ONE_MONTH + 10 days,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:           loanManager,
            accruedInterest:       0,
            accountedInterest:     expectedNetRefinanceInterest,  // Accounting gets updated to reflect the resulting refinance interest.
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + expectedNetRefinanceInterest,
            issuanceRate:          MONTHLY_INTEREST * 1e30 / ONE_MONTH,
            domainStart:           start + 1 * ONE_MONTH + 10 days,
            domainEnd:             start + 2 * ONE_MONTH + 10 days,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_000_000e6 + 500_000e6 + MONTHLY_INTEREST + expectedNetRefinanceInterest,
            unrealizedLosses: 0
        });

        assertAssetBalances(
            [address(borrower),  address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(999_250e6), uint256(505_625e6), uint256(100_000e6), uint256(1_400e6),      uint256(1_466.666666e6)]
        );

        // Warp to next payment due date
        vm.warp(start + 2 * ONE_MONTH + 10 days);

        makePayment(loan);

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 3 * ONE_MONTH + 10 days,
            paymentsRemaining: 1
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: MONTHLY_INTEREST - 1,
            refinanceInterest:   0,
            issuanceRate:        MONTHLY_INTEREST * 1e30 / ONE_MONTH,
            startDate:           start + 2 * ONE_MONTH + 10 days,
            paymentDueDate:      start + 3 * ONE_MONTH + 10 days,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:           loanManager,
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          MONTHLY_INTEREST * 1e30 / ONE_MONTH,
            domainStart:           start + 2 * ONE_MONTH + 10 days,
            domainEnd:             start + 3 * ONE_MONTH + 10 days,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_000_000e6 + 500_000e6 + expectedNetRefinanceInterest + 2 * MONTHLY_INTEREST + 2,
            unrealizedLosses: 0
        });

        assertAssetBalances(
            [address(borrower),  address(pool),             address(poolCover), address(poolDelegate),   address(treasury)],
            [uint256(999_250e6), uint256(517_922.945206e6), uint256(100_000e6), uint256(2_268.493150e6), uint256(3_750.228308e6)]
        );
    }

    function test_impairLoan_lateThenRefinance() external {
        /**********************************/
        /*** Impair loan when it's late ***/
        /**********************************/

        vm.warp(start + 2 * ONE_MONTH + 1 days);
        impairLoan(loan);

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2 * ONE_MONTH,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: MONTHLY_INTEREST - 1,  // -1 due to rounding error.
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           start + 1 * ONE_MONTH,
            paymentDueDate:      start + 2 * ONE_MONTH,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            MONTHLY_INTEREST - 1,
            lateInterest:        MONTHLY_LATE_INTEREST * 1 days / ONE_MONTH - 1,
            platformFees:        platformServiceFee +
                                 (GROSS_MONTHLY_INTEREST + GROSS_MONTHLY_LATE_INTEREST * 1 days / ONE_MONTH) * 0.08e6 / 1e6,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:           loanManager,
            accruedInterest:       0,
            accountedInterest:     MONTHLY_INTEREST - 1,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + MONTHLY_INTEREST - 1,
            issuanceRate:          0,
            domainStart:           block.timestamp,
            domainEnd:             block.timestamp,
            unrealizedLosses:      1_000_000e6 + MONTHLY_INTEREST - 1
        });

        assertPoolManager({
            totalAssets:      1_000_000e6 + (MONTHLY_INTEREST - 1) + 500_000e6 + 5_625e6,
            unrealizedLosses: 1_000_000e6 + (MONTHLY_INTEREST - 1)
        });

        assertAssetBalances(
            [address(borrower),  address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(999_250e6), uint256(505_625e6), uint256(100_000e6), uint256(900e6),        uint256(1300e6)  ]
        );

        vm.warp(start + 2 * ONE_MONTH + 3 days);  // Warp two more days.

        // Revert a late impairment fails
        vm.prank(governor);
        vm.expectRevert("LM:RLI:PAST_DATE");
        ILoanManagerLike(loanManager).removeLoanImpairment(loan);

        // Refinance - setting the payment interval will reset the payment due date.
        bytes[] memory data = encodeWithSignatureAndUint("setPaymentInterval(uint256)", ONE_MONTH);

        proposeRefinance(loan, address(refinancer), block.timestamp + 1, data);

        returnFunds(loan, 10_000e6);  // Return funds to pay origination fees. TODO: determine exact amount.

        acceptRefinance(loan, address(refinancer), block.timestamp + 1, data, 0);

        // Impairment was removed
        assertTrue(!ILoanLike(loan).isImpaired());

        uint256 expectedRefinanceInterest =
            GROSS_MONTHLY_INTEREST +
            GROSS_MONTHLY_LATE_INTEREST * 3 days / ONE_MONTH;

        uint256 expectedNetRefinanceInterest = expectedRefinanceInterest * 0.9e6 / 1e6;

        assertFixedTermLoan({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: expectedRefinanceInterest,
            paymentDueDate:    start + 3 * ONE_MONTH + 3 days,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                loan,
            incomingNetInterest: MONTHLY_INTEREST - 1,
            refinanceInterest:   expectedNetRefinanceInterest,
            issuanceRate:        MONTHLY_INTEREST * 1e30 / ONE_MONTH,
            startDate:           start + 2 * ONE_MONTH + 3 days,
            paymentDueDate:      start + 3 * ONE_MONTH + 3 days,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertFixedTermLoanManager({
            loanManager:           loanManager,
            accruedInterest:       0,
            accountedInterest:     expectedNetRefinanceInterest,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + expectedNetRefinanceInterest,
            issuanceRate:          MONTHLY_INTEREST * 1e30 / ONE_MONTH,
            domainStart:           start + 2 * ONE_MONTH + 3 days,
            domainEnd:             start + 3 * ONE_MONTH + 3 days,
            unrealizedLosses:      0
        });

        assertPoolManager({
            totalAssets:      1_000_000e6 + 500_000e6 + expectedNetRefinanceInterest + MONTHLY_INTEREST,
            unrealizedLosses: 0
        });

        assertAssetBalances(
            [address(borrower),  address(pool),      address(poolCover), address(poolDelegate), address(treasury)],
            [uint256(999_250e6), uint256(505_625e6), uint256(100_000e6), uint256(1_400e6),      uint256(1_466.666666e6)]
        );
    }

}

contract OpenTermLoanManagerImpairLoanTests is TestBaseWithAssertions {

    address borrower = makeAddr("borrower");
    address lp       = makeAddr("lp");

    uint256 constant gracePeriod     = 5 days;
    uint256 constant noticePeriod    = 5 days;
    uint256 constant paymentInterval = 30 days;

    uint256 constant principal = 2_500_000e6;

    uint256 constant interestRate        = 0.115e18;  // 11.5%
    uint256 constant lateFeeRate         = 0.02e18;   // 2%
    uint256 constant lateInterestPremium = 0.045e18;  // 4.5%

    uint256 constant delegateServiceFeeRate    = 0.03e18;  // 3%
    uint256 constant delegateManagementFeeRate = 0.02e6;   // 2%
    uint256 constant platformServiceFeeRate    = 0.043e6;  // 4.3%
    uint256 constant platformManagementFeeRate = 0.057e6;  // 5.7%

    uint256 constant interest       = principal * interestRate * paymentInterval / 365 days / 1e18;
    uint256 constant managementFees = interest * (delegateManagementFeeRate + platformManagementFeeRate) / 1e6;
    uint256 constant issuanceRate   = (interest - managementFees) * 1e27 / paymentInterval;

    IOpenTermLoan        loan;
    IOpenTermLoanManager loanManager;

    function setUp() public override {
        super.setUp();

        vm.startPrank(governor);
        globals.setValidBorrower(borrower, true);
        globals.setPlatformServiceFeeRate(address(poolManager), platformServiceFeeRate);
        globals.setPlatformManagementFeeRate(address(poolManager), platformManagementFeeRate);
        vm.stopPrank();

        vm.prank(poolDelegate);
        poolManager.setDelegateManagementFeeRate(delegateManagementFeeRate);

        loanManager = IOpenTermLoanManager(poolManager.loanManagerList(1));
        loan = IOpenTermLoan(createOpenTermLoan(
            address(borrower),
            address(loanManager),
            address(fundsAsset),
            principal,
            [uint32(gracePeriod), uint32(noticePeriod), uint32(paymentInterval)],
            [uint64(delegateServiceFeeRate), uint64(interestRate), uint64(lateFeeRate), uint64(lateInterestPremium)]
        ));

        depositLiquidity(address(pool), lp, principal);
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
        poolManager.triggerDefault(address(loan), liquidatorFactory);

        vm.expectRevert("ML:I:LOAN_INACTIVE");
        vm.prank(poolDelegate);
        loanManager.impairLoan(address(loan));
    }

    function testFail_impairLoan_notLoanContract() external {
        // vm.expectRevert();  TODO: Update to use forge-std
        vm.prank(poolDelegate);
        loanManager.impairLoan(address(1));
    }

    function test_impairLoan_notLoanInLoanManager() external {
        address unfundedLoan = createOpenTermLoan(
            address(borrower),
            address(loanManager),
            address(fundsAsset),
            principal + 1,  // Different salt
            [uint32(gracePeriod), uint32(noticePeriod), uint32(paymentInterval)],
            [uint64(delegateServiceFeeRate), uint64(interestRate), uint64(lateFeeRate), uint64(lateInterestPremium)]
        );

        // vm.expectRevert("LM:AFLI:NOT_LOAN");  // NOTE: Code is not reachable but should still be kept for extra safety.
        vm.expectRevert("ML:I:LOAN_INACTIVE");
        vm.prank(poolDelegate);
        loanManager.impairLoan(unfundedLoan);
    }

    function test_impairLoan_notLender() external {
        vm.expectRevert("ML:I:NOT_LENDER");
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

contract OpenTermLoanManagerRemoveLoanImpairmentTests is TestBaseWithAssertions {

    address borrower = makeAddr("borrower");
    address lp       = makeAddr("lp");

    uint256 constant gracePeriod     = 5 days;
    uint256 constant noticePeriod    = 5 days;
    uint256 constant paymentInterval = 30 days;

    uint256 constant principal = 2_500_000e6;

    uint256 constant interestRate        = 0.115e18;  // 11.5%
    uint256 constant lateFeeRate         = 0.02e18;   // 2%
    uint256 constant lateInterestPremium = 0.045e18;  // 4.5%

    uint256 constant delegateServiceFeeRate    = 0.03e6;   // 3%
    uint256 constant delegateManagementFeeRate = 0.02e6;   // 2%
    uint256 constant platformServiceFeeRate    = 0.043e6;  // 4.3%
    uint256 constant platformManagementFeeRate = 0.057e6;  // 5.7%

    uint256 constant interest       = principal * interestRate * paymentInterval / 365 days / 1e18;
    uint256 constant managementFees = interest * (delegateManagementFeeRate + platformManagementFeeRate) / 1e6;
    uint256 constant issuanceRate   = (interest - managementFees) * 1e27 / paymentInterval;

    IOpenTermLoan        loan;
    IOpenTermLoanManager loanManager;

    function setUp() public override {
        super.setUp();

        vm.startPrank(governor);
        globals.setValidBorrower(borrower, true);
        globals.setPlatformServiceFeeRate(address(poolManager), platformServiceFeeRate);
        globals.setPlatformManagementFeeRate(address(poolManager), platformManagementFeeRate);
        vm.stopPrank();

        vm.prank(poolDelegate);
        poolManager.setDelegateManagementFeeRate(delegateManagementFeeRate);

        loanManager = IOpenTermLoanManager(poolManager.loanManagerList(1));
        loan = IOpenTermLoan(createOpenTermLoan(
            address(borrower),
            address(loanManager),
            address(fundsAsset),
            principal,
            [uint32(gracePeriod), uint32(noticePeriod), uint32(paymentInterval)],
            [uint64(delegateServiceFeeRate), uint64(interestRate), uint64(lateFeeRate), uint64(lateInterestPremium)]
        ));

        depositLiquidity(address(pool), lp, principal);
        fundLoan(address(loan));

        assertOpenTermLoanManager({
            loanManager:           address(loanManager),
            domainStart:           start,
            issuanceRate:          issuanceRate,
            accountedInterest:     0,
            accruedInterest:       0,
            principalOut:          principal,
            unrealizedLosses:      0
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
        vm.expectRevert("LM:AFLIR:NOT_LOAN");
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
        vm.expectRevert("ML:RI:NOT_LENDER");
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
            loanManager:           address(loanManager),
            domainStart:           start + paymentInterval / 3,
            issuanceRate:          0,
            accountedInterest:     issuanceRate * paymentInterval / 3 / 1e27,
            accruedInterest:       0,  // No interest accrued because of IR == 0
            principalOut:          principal,
            unrealizedLosses:      principal + issuanceRate * paymentInterval / 3 / 1e27
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
            loanManager:           address(loanManager),
            domainStart:           start + paymentInterval * 2 / 3,
            issuanceRate:          issuanceRate,
            accountedInterest:     issuanceRate * paymentInterval * 2 / 3 / 1e27 - 1,  // -1 due to rounding error.
            accruedInterest:       0,
            principalOut:          principal,
            unrealizedLosses:      0
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
            loanManager:           address(loanManager),
            domainStart:           start + paymentInterval * 2 / 3,
            issuanceRate:          0,
            accountedInterest:     issuanceRate * paymentInterval * 2 / 3 / 1e27,
            accruedInterest:       0,  // No interest accrued because of IR == 0
            principalOut:          principal,
            unrealizedLosses:      principal + issuanceRate * paymentInterval * 2 / 3 / 1e27
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
            loanManager:           address(loanManager),
            domainStart:           start + paymentInterval * 4 / 3,
            issuanceRate:          issuanceRate,
            accountedInterest:     issuanceRate * paymentInterval * 4 / 3 / 1e27,
            accruedInterest:       0,
            principalOut:          principal,
            unrealizedLosses:      0
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
            loanManager:           address(loanManager),
            domainStart:           start + paymentInterval * 4 / 3,
            issuanceRate:          0,
            accountedInterest:     issuanceRate * paymentInterval * 4 / 3 / 1e27,
            accruedInterest:       0,  // No interest accrued because of IR == 0
            principalOut:          principal,
            unrealizedLosses:      principal + issuanceRate * paymentInterval * 4 / 3 / 1e27
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
            loanManager:           address(loanManager),
            domainStart:           start + paymentInterval * 5 / 3,
            issuanceRate:          issuanceRate,
            accountedInterest:     issuanceRate * paymentInterval * 5 / 3 / 1e27 - 1,  // -1 due to rounding error.
            accruedInterest:       0,
            principalOut:          principal,
            unrealizedLosses:      0
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
