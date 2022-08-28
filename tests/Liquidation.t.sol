// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestBaseWithAssertions } from "../contracts/TestBaseWithAssertions.sol";

import { Address, console } from "../modules/contract-test-utils/contracts/test.sol";

import { MapleLoan as Loan } from "../modules/loan/contracts/MapleLoan.sol";

// TODO: Consider additional scenarios:
// 1. No cover and no collateral.
// 2. No cover but with collateral.
// 3. Cover covers only a portion of fees.
// 4. Collateral covers all fees and losses, and the remainder is sent to the borrower.

contract LiquidationTests is TestBaseWithAssertions {

    address borrower = address(new Address());
    address lp       = address(new Address());

    Loan loan;

    function setUp() public virtual override {
        super.setUp();

        depositCover({ cover: 100_000e6 });

        depositLiquidity({
            lp: lp,
            liquidity: 1_500_000e6
        });

        setupFees({
            delegateOriginationFee:     500e6,     // 1,000,000 * 0.20% * 3  / 12 = 500
            delegateServiceFee:         275e6,     // 1,000,000 * 0.33%      / 12 = 275
            delegateManagementFeeRate:  0.02e6,    // 1,000,000 * 7.50% * 2% / 12 = 125
            platformOriginationFeeRate: 0.001e6,   // 1,000,000 * 0.10% * 3  / 12 = 250
            platformServiceFeeRate:     0.0066e6,  // 1,000,000 * 0.66%      / 12 = 550
            platformManagementFeeRate:  0.08e6     // 1,000,000 * 7.50% * 8% / 12 = 500
        });

        /******************************/
        /*** Fund and drawdown loan ***/
        /******************************/

        loan = fundAndDrawdownLoan({
            borrower:         borrower,
            amounts:          [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            interestRate:     0.075e18,
            paymentInterval:  ONE_MONTH,
            numberOfPayments: 3
        });

        // Pool liquidity:  1,500,000 - 1,000,000  = 500,000
        // Gross interest:  1,000,000 * 7.50% / 12 =   6,250
        // Service fees:                 275 + 550 =     825
        // Management fees:              125 + 500 =     625
        // Net interest:         6,250 - 125 - 500 =   5,625

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + ONE_MONTH,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6,
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start,
            paymentDueDate:      start + ONE_MONTH
        });

        assertLoanManager({
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

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6,
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start,
            paymentDueDate:      start + ONE_MONTH
        });

        assertLoanManager({
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

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2 * ONE_MONTH,
            paymentsRemaining: 2
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6,
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start + 1 * ONE_MONTH,
            paymentDueDate:      start + 2 * ONE_MONTH
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

        assertLoanManager({
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
            [uint256(999_250e6), uint256(505_625e6), uint256(100_000e6), uint256(900e6),        uint256(1300e6)   ]
        );
    }

    function test_liqudation_noCover_noCollateral() external {
        // TODO
    }

    function test_liquidation_cover_noCollateral() external {
        // TODO
    }

    function test_liquidation_cover_collateral() external {

        /***********************************************/
        /*** Warp to end of 2nd Payment grace period ***/
        /***********************************************/

        // Since we round up days when it comes to late interest, this payment is 6 days late.
        vm.warp(start + 2 * ONE_MONTH + 5 days + 1);
        vm.prank(poolDelegate);
        poolManager.triggerCollateralLiquidation(address(loan));

        ( , , , , , address liquidator ) = loanManager.liquidationInfo(address(loan));

        assertLoanState({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           start + 1 * ONE_MONTH,
            paymentDueDate:      start + 2 * ONE_MONTH
        });

        // Interest:       5,626
        // Service fee:    550
        // Days late:      6
        // Late interest:  5,625 * 6 / 365 * 12
        // Management fee: 500 * (1 + 6 / 365 * 12)

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            5_625e6 - 1,  // -1 due to issuance rate rounding error.
            lateInterest:        5_625e6 * 6 days / ONE_MONTH - 1,
            platformFees:        550e6 + 500e6 + (500e6 * 6 days / ONE_MONTH),
            liquidatorExists:    true,
            triggeredByGovernor: false
        });

        // Lost principal:     1,000,000
        // Lost interest:      5,625
        // Lost late interest: 5,625 * (1 + 6 / 365 * 12)

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     5_625e6 - 1,  // -1 due to issuance rate rounding error.
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + 5_625e6 - 1,
            issuanceRate:          0,
            domainStart:           start + 2 * ONE_MONTH + 5 days + 1,
            domainEnd:             start + 2 * ONE_MONTH + 5 days + 1,
            unrealizedLosses:      1_000_000e6 + (5_625e6 - 1) + ((5_625e6 * 6 days / ONE_MONTH) - 1)
        });

        assertPoolManager({
            totalAssets:      1_000_000e6 + (5_625e6 - 1) + 500_000e6 + 5_625e6,
            unrealizedLosses: 1_000_000e6 + (5_625e6 - 1) + ((5_625e6 * 6 days / ONE_MONTH) - 1)
        });

        assertAssetBalances(
            [address(borrower),  address(pool),      address(poolCover), address(poolDelegate), address(treasury), address(liquidator)],
            [uint256(999_250e6), uint256(505_625e6), uint256(100_000e6), uint256(900e6),        uint256(1300e6),   uint256(0)         ]
        );

        /*******************************************/
        /*** 3rd party liquidates the collateral ***/
        /*******************************************/

        liquidateCollateral(loan);

        assertAssetBalances(
            [address(borrower),  address(pool),      address(poolCover), address(poolDelegate), address(treasury), address(liquidator)],
            [uint256(999_250e6), uint256(505_625e6), uint256(100_000e6), uint256(900e6),        uint256(1300e6),   uint256(150_000e6) ]
        );

        /*************************************/
        /*** Finish collateral liquidation ***/
        /*************************************/

        vm.prank(poolDelegate);
        poolManager.finishCollateralLiquidation(address(loan));

        assertLoanState({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertLoanInfoWasDeleted(loan);

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           start + 2 * ONE_MONTH + 5 days + 1,
            domainEnd:             start + 2 * ONE_MONTH + 5 days + 1,
            unrealizedLosses:      0
        });

        // Initial pool liquidity: 500,000
        // Interest payment:       5,625
        // Liquidated collateral:  150,000
        // Liquidated cover:       100,000
        // Service fee:            550
        // Management fee:         500 * (1 + 6 / 365 * 12)

        // Total Assets: cash      + paid interest + collateral recovered + (cover used - platfrom service fee - platform management fee)
        // Total Assets: (500,000) + (5,625)       + (150,000)            + [100,000    - 550                  - (500 * (1 + 6 / 365 * 12))]

        assertPoolManager({
            totalAssets:      754_476.369863e6 + 1,  // TODO: Temp + 1, figure out why.
            unrealizedLosses: 0
        });

        assertAssetBalances(
            [address(borrower),  address(pool),                 address(poolCover), address(poolDelegate), address(treasury),    address(liquidator)],
            [uint256(999_250e6), uint256(754_476.369863e6 + 1), uint256(0),         uint256(900e6),        uint256(2448_630136), uint256(0)         ]
        );
    }

}

contract TriggerDefaultWarningTests is TestBaseWithAssertions {

    address borrower = address(new Address());
    address lp       = address(new Address());

    Loan loan;

    function setUp() public override {
        super.setUp();

        depositCover({ cover: 100_000e6 });

        depositLiquidity({
            lp: lp,
            liquidity: 1_500_000e6
        });

        setupFees({
            delegateOriginationFee:     500e6,     // 1,000,000 * 0.20% * 3  / 12 = 500
            delegateServiceFee:         275e6,     // 1,000,000 * 0.33%      / 12 = 275
            delegateManagementFeeRate:  0.02e6,    // 1,000,000 * 7.50% * 2% / 12 = 125
            platformOriginationFeeRate: 0.001e6,   // 1,000,000 * 0.10% * 3  / 12 = 250
            platformServiceFeeRate:     0.0066e6,  // 1,000,000 * 0.66%      / 12 = 550
            platformManagementFeeRate:  0.08e6     // 1,000,000 * 7.50% * 8% / 12 = 500
        });

        /******************************/
        /*** Fund and drawdown loan ***/
        /******************************/

        loan = fundAndDrawdownLoan({
            borrower:         borrower,
            amounts:          [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            interestRate:     0.075e18,
            paymentInterval:  ONE_MONTH,
            numberOfPayments: 3
        });
    }

    function setUpTDWTest() internal {
        // Pool liquidity:  1,500,000 - 1,000,000  = 500,000
        // Gross interest:  1,000,000 * 7.50% / 12 =   6,250
        // Service fees:                 275 + 550 =     825
        // Management fees:              125 + 500 =     625
        // Net interest:         6,250 - 125 - 500 =   5,625

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + ONE_MONTH,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6,
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start,
            paymentDueDate:      start + ONE_MONTH
        });

        assertLoanManager({
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

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6,
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start,
            paymentDueDate:      start + ONE_MONTH
        });

        assertLoanManager({
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

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2 * ONE_MONTH,
            paymentsRemaining: 2
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6,
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start + 1 * ONE_MONTH,
            paymentDueDate:      start + 2 * ONE_MONTH
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

        assertLoanManager({
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

        /*******************************************************************/
        /*** Trigger default warning at 1/5 of the next payment interval ***/
        /*******************************************************************/

        vm.warp(start + ONE_MONTH + ONE_MONTH / 5);
        vm.prank(poolDelegate);
        poolManager.triggerDefaultWarning(address(loan));

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    block.timestamp,
            paymentsRemaining: 2
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6,
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start + 1 * ONE_MONTH,
            paymentDueDate:      start + 2 * ONE_MONTH
        });

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            uint256(5_625e6 - 1) / 5,  // -1 due to issuance rate rounding error.
            lateInterest:        0,
            platformFees:        1050e6 / 5,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertLoanManager({
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

    function test_liquidation_warn_cancel() external {

        setUpTDWTest();

        /******************************************************************/
        /*** Remove the default warning a day after the default warning ***/
        /******************************************************************/

        vm.warp(start + ONE_MONTH + ONE_MONTH / 5 + ONE_DAY);

        assertLoanManager({
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

        vm.prank(poolDelegate);
        poolManager.removeDefaultWarning(address(loan));

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2 * ONE_MONTH,
            paymentsRemaining: 2
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6,
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start + 1 * ONE_MONTH,
            paymentDueDate:      start + 2 * ONE_MONTH
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

        assertLoanManager({
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
        /*** Make another payment after the default warning has been removed ***/
        /***********************************************************************/

        vm.warp(start + 2 * ONE_MONTH);

        uint256 accountedInterest = 5_625e6 * (ONE_MONTH / 5 + ONE_DAY) / ONE_MONTH;  // Accounted at time of default warning removal.

        assertLoanManager({
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

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 3 * ONE_MONTH,
            paymentsRemaining: 1
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6,
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start + 2 * ONE_MONTH,
            paymentDueDate:      start + 3 * ONE_MONTH
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

        assertLoanManager({
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

    function test_liquidation_warn_liquidate() external {

        setUpTDWTest();

        /**************************************************************/
        /*** Trigger liquidation after the grace period has expired ***/
        /**************************************************************/

        vm.warp(start + ONE_MONTH + ONE_MONTH / 5 + 5 days + 1);

        assertLoanManager({
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

        vm.prank(poolDelegate);
        poolManager.triggerCollateralLiquidation(address(loan));

        ( , , , , , address liquidator ) = loanManager.liquidationInfo(address(loan));

        assertLoanState({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6,
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start + 1 * ONE_MONTH,
            paymentDueDate:      start + 2 * ONE_MONTH
        });

        assertLiquidationInfo({
            loan:                loan,
            principal:           1_000_000e6,
            interest:            uint256(5_625e6 - 1) / 5,  // -1 due to issuance rate rounding error.
            lateInterest:        0,
            platformFees:        1050e6 / 5,
            liquidatorExists:    true,
            triggeredByGovernor: false
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     (5_625e6 / 5) - 1,  // -1 due to issuance rate rounding error.
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
            [address(borrower),  address(pool),      address(poolCover), address(poolDelegate), address(treasury), address(liquidator)],
            [uint256(999_250e6), uint256(505_625e6), uint256(100_000e6), uint256(900e6),        uint256(1300e6),   uint256(0)         ]
        );

        /*******************************************/
        /*** 3rd party liquidates the collateral ***/
        /*******************************************/

        liquidateCollateral(loan);

        assertAssetBalances(
            [address(borrower),  address(pool),      address(poolCover), address(poolDelegate), address(treasury), address(liquidator)],
            [uint256(999_250e6), uint256(505_625e6), uint256(100_000e6), uint256(900e6),        uint256(1300e6),   uint256(150_000e6) ]
        );

        /*************************************/
        /*** Finish collateral liquidation ***/
        /*************************************/

        vm.prank(poolDelegate);
        poolManager.finishCollateralLiquidation(address(loan));

        assertLoanState({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertLoanInfoWasDeleted(loan);

        assertLiquidationInfo({
            loan:                loan,
            principal:           0,
            interest:            0,
            lateInterest:        0,
            platformFees:        0,
            liquidatorExists:    false,
            triggeredByGovernor: false
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           start + 6 * ONE_MONTH / 5 + 5 days + 1,
            domainEnd:             start + 6 * ONE_MONTH / 5 + 5 days + 1,
            unrealizedLosses:      0
        });

       /*
            Pool cash:             500_000e6 + 5_625e6
            Default principal:     1_000_000e6
            Default interest:      1_124.999999e6 = (5_625e6 - 1) / 5
            Default late interest: 0 (no late interest when trigger default warning is used)
            Default fees:          210e6 = 1050e6 / 5
            Total default:         1_001_334.999999e6 = 1_000_000e6 + 1_124.999999e6 + 210e6

            Collateral recovered:  150_000e6
            Cover available:       100_000e6
            All collateral and cover will be used (total default > collateral + cover)

            Total Assets (all cash): 755_415e6 = 500_000e6 + 5_625e6 + 150_000e6 + 100_000e6 - 210e6
            Treasury Balance:        1510e6    = 1300e6 + 210e6
       */

        assertPoolManager({
            totalAssets:      500_000e6 + 5_625e6 + 150_000e6 + 100_000e6 - 210e6,
            unrealizedLosses: 0
        });

        assertAssetBalances(
            [address(borrower),  address(pool),      address(poolCover), address(poolDelegate), address(treasury), address(liquidator)],
            [uint256(999_250e6), uint256(755_415e6), uint256(0),         uint256(900e6),        uint256(1510e6),   uint256(0)         ]
        );

    }

    function test_liquidation_warn_repay() external {

        setUpTDWTest();

        /******************************************************/
        /*** Make a payment a day after the default warning ***/
        /******************************************************/

        vm.warp(start + ONE_MONTH + ONE_MONTH / 5 + ONE_DAY);
        makePayment(loan);

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2 * ONE_MONTH + ONE_MONTH / 5,
            paymentsRemaining: 1
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 5_625e6,
            refinanceInterest:   0,
            issuanceRate:        5_625e6 * 1e30 / ONE_MONTH,
            startDate:           start + 1 * ONE_MONTH + ONE_MONTH / 5,
            paymentDueDate:      start + 2 * ONE_MONTH + ONE_MONTH / 5
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

        assertLoanManager({
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

        assertLoanState({
            loan:              loan,
            principal:         0,
            refinanceInterest: 0,
            paymentDueDate:    0,
            paymentsRemaining: 0
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0
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

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           block.timestamp,
            domainEnd:             0,
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
