// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestBaseWithAssertions } from "../contracts/utilities/TestBaseWithAssertions.sol";

import { Address, console  } from "../modules/contract-test-utils/contracts/test.sol";
import { MapleLoan as Loan } from "../modules/loan/contracts/MapleLoan.sol";

contract ClaimTestsSingleLoanInterestOnly is TestBaseWithAssertions {

    address borrower;
    address lp;

    Loan loan;

    function setUp() public override {
        super.setUp();

        borrower = address(new Address());
        lp       = address(new Address());

        depositLiquidity({
            lp:        lp,
            liquidity: 1_500_000e6
        });

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,  // 10k after 1m seconds
            platformManagementFeeRate:  0.08e6
        });

        loan = fundAndDrawdownLoan({
            borrower:         borrower,
            termDetails:      [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:          [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:            [uint256(3.1536e18), uint256(0), uint256(0), uint256(0)]
        });

    }

    function test_claim_onTimePayment_interestOnly() public {

        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(1_500_000e6);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        // PoolDelegate and treasury get their own originationFee
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [500e6,        95_129375]);  // 1m * 0.01% * (~11.57/365) * 3 = 95.129375

        /******************************/
        /*** Pre Payment Assertions ***/
        /******************************/

        vm.warp(start + 1_000_000);

        assertTotalAssets(1_500_000e6 + 90_000e6);

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6,        // 0.1 * 1_000_000 = 100_000
            incomingFees:      10_000e6 + 300e6, // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000
        });

        assertLoanManager({
            accruedInterest:       90_000e6,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_090_000e6,     // Principal + accrued interest
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        makePayment(loan);

        assertTotalAssets(1_500_000e6 + 90_000e6);

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest : 100_000e6,
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 2
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start + 1_000_000,
            paymentDueDate:      start + 2_000_000
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start + 1_000_000,
            domainEnd:             start + 2_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 590_000e6);

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [2_300e6,      18_000e6]);
    }

    function test_claim_earlyPayment_interestOnly() public {

        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(1_500_000e6);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        // PoolDelegate and treasury get their own originationFee
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [500e6,        95_129375]);

        /******************************/
        /*** Pre Payment Assertions ***/
        /******************************/

        vm.warp(start + 500_000);

        assertTotalAssets(1_500_000e6 + 45_000e6); // 0.09e6 per second * 500_000 seconds

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6,        // 0.1 * 1_000_000 = 100_000
            incomingFees:      10_000e6 + 300e6, // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000
        });

        assertLoanManager({
            accruedInterest:       45_000e6,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_045_000e6,     // Principal + accrued interest
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        makePayment(loan);

        assertTotalAssets(1_500_000e6 + 90_000e6);

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest : 100_000e6,
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 2
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.06e6 * 1e30,
            startDate:           start + 500_000,
            paymentDueDate:      start + 2_000_000
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          0.06e6 * 1e30,
            domainStart:           start + 500_000,
            domainEnd:             start + 2_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 590_000e6);

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [2_300e6,      18_000e6]);
    }

    function test_claim_latePayment_interestOnly() public {

        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(1_500_000e6);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        // PoolDelegate and treasury get their own originationFee
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [500e6,        95_129375]);

        /******************************/
        /*** Pre Payment Assertions ***/
        /******************************/

        vm.warp(start + 1_100_000);

        assertTotalAssets(1_500_000e6 + 90_000e6);

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  117_280e6,        // 0.1 * 1_000_000 = 100_000 + late(86400 seconds * 2 * 0.1) = 17_280
            incomingFees:      10_000e6 + 300e6, // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000
        });

        assertLoanManager({
            accruedInterest:       90_000e6,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_090_000e6,     // Principal + accrued interest
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
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

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest : 100_000e6,
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 2
        });

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start + 1_000_000,
            paymentDueDate:      start + 2_000_000
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     9_000e6,          // Accounted during claim
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_009_000e6,
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start + 1_100_000,
            domainEnd:             start + 2_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 90_000e6 + 15_552e6);

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee + late interest (17_280e6 * 0.02 = 345_600000)
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee + late interest (17_280e6 * 0.08 = 1382_400000)
        assertAssetBalancesIncrease([poolDelegate,      treasury],
                                    [2_300e6 + 345.6e6, 18_000e6 + 1382.4e6]);
    }

}

contract ClaimTestsSingleLoanAmortized is TestBaseWithAssertions {

    address borrower;
    address lp;

    Loan loan;

    function setUp() public override {
        super.setUp();

        borrower = address(new Address());
        lp       = address(new Address());

        depositLiquidity({
            lp:        lp,
            liquidity: 2_500_000e6
        });

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,
            platformManagementFeeRate:  0.08e6
        });

        loan = fundAndDrawdownLoan({
            borrower:         borrower,
            termDetails:      [uint256(5 days), uint256(1_000_000), uint256(2)],
            amounts:          [uint256(0), uint256(2_000_000e6), uint256(0)],
            rates:            [uint256(3.1536e18), 0, 0, 0]  // 0.1e6 tokens per second
        });

    }

    function test_claim_onTimePayment_amortized() public {

        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(2_500_000e6);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          2_000_000e6,
            assetsUnderManagement: 2_000_000e6,
            issuanceRate:          0.18e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertLoanState({
            loan:              loan,
            principal:         2_000_000e6,
            incomingPrincipal: 952_380_952380,   // Principal is adjusted to make equal loan payments across the term.
            incomingInterest:  200_000e6,        // 0.1 * 2_000_000 = 200_000
            incomingFees:      20_000e6 + 300e6, // 20_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 2
        });

        // PoolDelegate and treasury get their own originationFee
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [500e6,        126_839167]);

        /******************************/
        /*** Pre Payment Assertions ***/
        /******************************/

        vm.warp(start + 1_000_000);

        assertTotalAssets(2_500_000e6 + 180_000e6);

        assertLoanState({
            loan:              loan,
            principal:         2_000_000e6,
            incomingPrincipal: 952_380_952380,
            incomingInterest:  200_000e6,        // 0.1 * 1_000_000 = 100_000
            incomingFees:      20_000e6 + 300e6, // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 2
        });

        uint256 payment1Principal = 952_380_952380;
        uint256 payment1Interest  = 200_000e6;

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000
        });

        assertLoanManager({
            accruedInterest:       180_000e6,
            accountedInterest:     0,
            principalOut:          2_000_000e6,
            assetsUnderManagement: 2_180_000e6,     // Principal + accrued interest
            issuanceRate:          0.18e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        makePayment(loan);

        assertTotalAssets(2_500_000e6 + 180_000e6);

        assertLoanState({
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
        assertWithinDiff(payment1Principal + payment1Interest, payment2Principal + payment2Interest, 5);

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 94_285_714285,
            refinanceInterest:   0,
            issuanceRate:        0.094285714285e6 * 1e30,
            startDate:           start + 1_000_000,
            paymentDueDate:      start + 2_000_000
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_047_619_047620,
            assetsUnderManagement: 1_047_619_047620,
            issuanceRate:          0.094285714285e6 * 1e30,
            domainStart:           start + 1_000_000,
            domainEnd:             start + 2_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + payment1Principal + 180_000e6);

        // Pool Delegate fee: 300e6    flat from service fee + 4_000e6 from management fee
        // Treasury fee:      20_000e6 flat from service fee + 16_000e6 from management fee
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [4_300e6,      36_000e6]);
    }

    function test_claim_earlyPayment_amortized() public {

        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(2_500_000e6);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          2_000_000e6,
            assetsUnderManagement: 2_000_000e6,
            issuanceRate:          0.18e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertLoanState({
            loan:              loan,
            principal:         2_000_000e6,
            incomingPrincipal: 952_380_952380,   // Principal is adjusted to make equal loan payments across the term.
            incomingInterest:  200_000e6,        // 0.1 * 1_000_000 = 100_000
            incomingFees:      20_000e6 + 300e6, // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 2
        });

        // PoolDelegate and treasury get their own originationFee
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [500e6,        126_839167]);

        /******************************/
        /*** Pre Payment Assertions ***/
        /******************************/

        vm.warp(start + 600_000);

        assertTotalAssets(2_500_000e6 + 108_000e6);

        assertLoanState({
            loan:              loan,
            principal:         2_000_000e6,
            incomingPrincipal: 952_380_952380,
            incomingInterest:  200_000e6,        // 0.1 * 1_000_000 = 100_000
            incomingFees:      20_000e6 + 300e6, // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 2
        });

        uint256 payment1Principal = 952_380_952380;
        uint256 payment1Interest  = 200_000e6;

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000
        });

        assertLoanManager({
            accruedInterest:       108_000e6,
            accountedInterest:     0,
            principalOut:          2_000_000e6,
            assetsUnderManagement: 2_108_000e6,     // Principal + accrued interest
            issuanceRate:          0.18e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        makePayment(loan);

        assertTotalAssets(2_500_000e6 + 180_000e6);

        assertLoanState({
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
        assertWithinDiff(payment1Principal + payment1Interest, payment2Principal + payment2Interest, 5);

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 94_285_714285,
            refinanceInterest:   0,
            issuanceRate:        0.067346938775e6 * 1e30,
            startDate:           start + 600_000,
            paymentDueDate:      start + 2_000_000
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_047_619_047620,
            assetsUnderManagement: 1_047_619_047620,
            issuanceRate:          0.067346938775e6 * 1e30,
            domainStart:           start + 600_000,
            domainEnd:             start + 2_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + payment1Principal + 180_000e6);

        // Pool Delegate fee: 300e6    flat from service fee + 4_000e6 from management fee
        // Treasury fee:      20_000e6 flat from service fee + 16_000e6 from management fee
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [4_300e6,      36_000e6]);
    }

    function test_claim_latePayment_amortized() public {

        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(2_500_000e6);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          2_000_000e6,
            assetsUnderManagement: 2_000_000e6,
            issuanceRate:          0.18e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertLoanState({
            loan:              loan,
            principal:         2_000_000e6,
            incomingPrincipal: 952_380_952380,   // Principal is adjusted to make equal loan payments across the term.
            incomingInterest:  200_000e6,        // 0.1 * 1_000_000 = 100_000
            incomingFees:      20_000e6 + 300e6, // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 2
        });

        // PoolDelegate and treasury get their own originationFee
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [500e6,        126_839167]);

        /******************************/
        /*** Pre Payment Assertions ***/
        /******************************/

        vm.warp(start + 1_200_000);

        assertTotalAssets(2_500_000e6 + 180_000e6);

        assertLoanState({
            loan:              loan,
            principal:         2_000_000e6,
            incomingPrincipal: 952_380_952380,
            incomingInterest:  200_000e6 + 51_840e6, // 0.1 * 1_000_000 + late(86400 seconds * 3 * 0.2) = 51_840
            incomingFees:      20_000e6 + 300e6,     // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 2
        });

        uint256 payment1Principal = 952_380_952380;
        uint256 payment1Interest  = 200_000e6;

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000
        });

        assertLoanManager({
            accruedInterest:       180_000e6,
            accountedInterest:     0,
            principalOut:          2_000_000e6,
            assetsUnderManagement: 2_180_000e6,     // Principal + accrued interest
            issuanceRate:          0.18e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        makePayment(loan);

        // (Principal + cash) + interest + late interest + 200k seconds of interest on remaining principal
        assertTotalAssets(2_500_000e6 + 180_000e6 + 46_656e6 + 18_857_142857);

        assertLoanState({
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
        assertWithinDiff(payment1Principal + payment1Interest, payment2Principal + payment2Interest, 5);

        assertLoanInfo({
            loan:                loan,
            incomingNetInterest: 94_285_714285,
            refinanceInterest:   0,
            issuanceRate:        0.094285714285e6 * 1e30,
            startDate:           start + 1_000_000,
            paymentDueDate:      start + 2_000_000
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     18_857_142857,    // 200_000sec of the IR
            principalOut:          1_047_619_047620,
            assetsUnderManagement: 1_047_619_047620 + 18_857_142857,
            issuanceRate:          0.094285714285e6 * 1e30,
            domainStart:           start + 1_200_000,
            domainEnd:             start + 2_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + payment1Principal + 180_000e6 + 46_656e6);

        // Pool Delegate fee: 300e6    flat from service fee + 4_000e6 from management fee  + late interest (51_840e6 * 0.02 = 1036_800000)
        // Treasury fee:      20_000e6 flat from service fee + 16_000e6 from management fee + late interest (51_840e6 * 0.08 = 4147_200000)
        assertAssetBalancesIncrease([poolDelegate,        treasury],
                                    [4_300e6 + 1_036.8e6, 36_000e6 + 4_147.2e6]);
    }

}

contract ClaimTestsTwoLoans is TestBaseWithAssertions {

    address borrower1;
    address borrower2;
    address lp;

    Loan loan1;
    Loan loan2;

    function setUp() public override {
        super.setUp();

        borrower1 = address(new Address());
        borrower2 = address(new Address());
        lp        = address(new Address());

        depositLiquidity({
            lp:        lp,
            liquidity: 3_500_000e6
        });

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,  // 10k after 1m seconds
            platformManagementFeeRate:  0.08e6
        });

        loan1 = fundAndDrawdownLoan({
            borrower:         borrower1,
            termDetails:      [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:          [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:            [uint256(3.1536e18), 0, 0, 0]  // 0.1e6 tokens per second
        });

        vm.warp(start + 300_000);

        loan2 = fundAndDrawdownLoan({
            borrower:         borrower2,
            termDetails:      [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:          [uint256(0), uint256(2_000_000e6), uint256(2_000_000e6)],
            rates:            [uint256(3.1536e18), 0, 0, 0]  // 0.1e6 tokens per second
        });
    }

    function test_claim_onTimePayment_interestOnly_onTimePayment_interestOnly() external {

        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(3_500_000e6 + 27_000e6); // Already warped 300_000 seconds at 0.09 IR after start before funding loan2

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     27_000e6,
            principalOut:          3_000_000e6,
            assetsUnderManagement: 3_027_000e6,
            issuanceRate:          0.27e6 * 1e30,     // 0.09 from loan1 and 0.18 from loan2
            domainStart:           start + 300_000,   // Time of loan2 funding
            domainEnd:             start + 1_000_000, // Payment due date of loan1
            unrealizedLosses:      0
        });

        // PoolDelegate and treasury get their own originationFee for each loan
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [1_000e6,      285_388126]);

        /************************************/
        /*** Pre Loan1 Payment Assertions ***/
        /************************************/

        vm.warp(start + 1_000_000);

        assertTotalAssets(3_500_000e6 + 90_000e6 + 126_000e6); // Principal + 1_000_000s of loan1  at 0.09e6 IR + 700_000s of loan2 at 0.18e6 IR

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6,        // 0.1 * 1_000_000 = 100_000
            incomingFees:      10_000e6 + 300e6, // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000
        });

        assertLoanManager({
            accruedInterest:       90_000e6 + 126_000e6 - 27_000e6,
            accountedInterest:     27_000e6,
            principalOut:          3_000_000e6,
            assetsUnderManagement: 3_000_000e6 + 216_000e6,
            issuanceRate:          0.27e6 * 1e30,
            domainStart:           start + 300_000,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        /*************************************/
        /*** Post Loan1 Payment Assertions ***/
        /*************************************/

        makePayment(loan1);

        assertTotalAssets(3_500_000e6 + 90_000e6 + 126_000e6); // Principal + 1_000_000s of loan1 at 0.09 + 700_000s of loan2 at 0.18e6 IR

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6,        // 0.1 * 1_000_000 = 100_000
            incomingFees:      10_000e6 + 300e6, // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 2
        });

        assertLoanInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start + 1_000_000,
            paymentDueDate:      start + 2_000_000
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     126_000e6,    // 700_000s at 0.18e6
            principalOut:          3_000_000e6,
            assetsUnderManagement: 3_000_000e6 + 126_000e6,
            issuanceRate:          0.27e6 * 1e30,
            domainStart:           start + 1_000_000,
            domainEnd:             start + 1_300_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 90_000e6);

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [2_300e6,      18_000e6]);

        /************************************/
        /*** Pre Loan2 Payment Assertions ***/
        /************************************/

        vm.warp(start + 1_300_000);

        assertTotalAssets(3_500_000e6 + 117_000e6 + 180_000e6); // Principal + 1_300_000s of loan1 at 0.9e6 + 1_000_000s of loan2 at 0.18e6 IR

        assertLoanState({
            loan:              loan2,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_300_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan2,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 300_000,
            paymentDueDate:      start + 1_300_000
        });

        assertLoanManager({
            accruedInterest:       27_000e6 + 180_000e6 - 126_000e6,  // loan1 + loan2 - accounted from loan2
            accountedInterest:     126_000e6,    // 700_000s at 0.18e6
            principalOut:          3_000_000e6,
            assetsUnderManagement: 3_207_000e6,
            issuanceRate:          0.27e6 * 1e30,
            domainStart:           start + 1_000_000,
            domainEnd:             start + 1_300_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 90_000e6);

        /*************************************/
        /*** Post Loan2 Payment Assertions ***/
        /*************************************/

        makePayment(loan2);

        assertTotalAssets(3_500_000e6 + 117_000e6 + 180_000e6); // Principal + 1_300_000s of loan1 at 0.9e6 + 1_000_000s of loan2 at 0.18e6 IR

        assertLoanState({
            loan:              loan2,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2_300_000,
            paymentsRemaining: 2
        });

        assertLoanInfo({
            loan:                loan2,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 1_300_000,
            paymentDueDate:      start + 2_300_000
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     27_000e6,    // 700_000s at 0.18e6
            principalOut:          3_000_000e6,
            assetsUnderManagement: 3_027_000e6,
            issuanceRate:          0.27e6 * 1e30,
            domainStart:           start + 1_300_000,
            domainEnd:             start + 2_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 90_000e6 + 180_000e6);

        // Pool Delegate fee: 300e6    flat from service fee + 4_000e6 from management fee
        // Treasury fee:      10_000e6 flat from service fee + 16_000e6 from management fee
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [4_300e6,      36_000e6]);

        /********************************************/
        /*** Post Loan1 second Payment Assertions ***/
        /********************************************/

        vm.warp(start + 2_000_000);

        makePayment(loan1);

        assertTotalAssets(3_500_000e6 + 180_000e6 + 306_000e6); // Principal + 2_000_000s of loan1 at 0.9e6 + 1_700_000s of loan2 at 0.18e6 IR

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 180_000e6 + 180_000e6);  // Two payments of 90k plus one 180k payment

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [2_300e6,      18_000e6]);
    }

    function test_claim_earlyPayment_interestOnly_onTimePayment_interestOnly() external {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(3_527_000e6); // 300_000s of loan1 at 0.09e6 IR

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     27_000e6,
            principalOut:          3_000_000e6,
            assetsUnderManagement: 3_027_000e6,
            issuanceRate:          0.27e6 * 1e30,     // 0.09 from loan1 and 0.18 from loan2
            domainStart:           start + 300_000,   // Time of loan2 funding
            domainEnd:             start + 1_000_000, // Payment due date of loan1
            unrealizedLosses:      0
        });

        // PoolDelegate and treasury get their own originationFee for each loan
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [1_000e6,      285_388126]);

        /******************************************/
        /*** Pre Loan1 early Payment Assertions ***/
        /******************************************/

        vm.warp(start + 500_000);

        assertTotalAssets(3_500_000e6 + 45_000e6 + 36_000e6); // 500_000s of loan1 at 0.09 + 200_000s of loan2 at 0.18e6 IR

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6,        // 0.1 * 1_000_000 = 100_000
            incomingFees:      10_000e6 + 300e6, // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000
        });

        assertLoanManager({
            accruedInterest:       45_000e6 + 36_000e6 - 27_000e6,
            accountedInterest:     27_000e6,
            principalOut:          3_000_000e6,
            assetsUnderManagement: 3_081_000e6,
            issuanceRate:          0.27e6 * 1e30,
            domainStart:           start + 300_000,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        /*************************************/
        /*** Post Loan1 Payment Assertions ***/
        /*************************************/

        makePayment(loan1);

        assertTotalAssets(3_500_000e6 + 90_000e6 + 36_000e6); // Principal + 1_000_000s of loan1 at 0.09 + 700_000s of loan2 at 0.18e6 IR

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6,        // 0.1 * 1_000_000 = 100_000
            incomingFees:      10_000e6 + 300e6, // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 2
        });

        assertLoanInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.06e6 * 1e30,
            startDate:           start + 500_000,
            paymentDueDate:      start + 2_000_000
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     36_000e6,    // 200_000s at 0.18e6
            principalOut:          3_000_000e6,
            assetsUnderManagement: 3_036_000e6,
            issuanceRate:          0.24e6 * 1e30, // 0.18 from loan2 and 0.6 from loan1
            domainStart:           start + 500_000,
            domainEnd:             start + 1_300_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 90_000e6);

        /************************************/
        /*** Pre Loan2 Payment Assertions ***/
        /************************************/

        vm.warp(start + 1_300_000);

        assertTotalAssets(3_500_000e6 + 90_000e6 + 48_000e6 + 180_000e6); // Principal + loan1 payment interest + 800_000s of loan1 at 0.6e6 + 1_000_000s of loan2 at 0.18e6 IR

        assertLoanState({
            loan:              loan2,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_300_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan2,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 300_000,
            paymentDueDate:      start + 1_300_000
        });

        assertLoanManager({
            accruedInterest:       48_000e6 + 180_000e6 - 36_000e6,  // 800_000s of loan1 at 0.06 + 1_000_000s of loan2 at 0.18e6 - accounted
            accountedInterest:     36_000e6,                         // 200_000s at 0.18e6
            principalOut:          3_000_000e6,
            assetsUnderManagement: 3_228_000e6,
            issuanceRate:          0.24e6 * 1e30,
            domainStart:           start + 500_000,
            domainEnd:             start + 1_300_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 90_000e6);

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [2_300e6,      18_000e6]);

        /*************************************/
        /*** Post Loan2 Payment Assertions ***/
        /*************************************/

        makePayment(loan2);

        assertTotalAssets(3_500_000e6 + 90_000e6 + 48_000e6 + 180_000e6); // Principal + loan1 payment interest + 800_000s of loan1 at 0.6e6 + 1_000_000s of loan2 at 0.18e6 IR

        assertLoanState({
            loan:              loan2,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2_300_000,
            paymentsRemaining: 2
        });

        assertLoanInfo({
            loan:                loan2,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 1_300_000,
            paymentDueDate:      start + 2_300_000
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     48_000e6,    // 800_000s at 0.06e6
            principalOut:          3_000_000e6,
            assetsUnderManagement: 3_048_000e6,
            issuanceRate:          0.24e6 * 1e30,
            domainStart:           start + 1_300_000,
            domainEnd:             start + 2_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 90_000e6 + 180_000e6);

        // Pool Delegate fee: 300e6    flat from service fee + 4_000e6 from management fee
        // Treasury fee:      10_000e6 flat from service fee + 16_000e6 from management fee
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [4_300e6,      36_000e6]);

        /********************************************/
        /*** Post Loan1 second Payment Assertions ***/
        /********************************************/

        vm.warp(start + 2_000_000);

        makePayment(loan1);

        // Asserting this because all tests should be in sync after second loan1 payment
        assertTotalAssets(3_500_000e6 + 180_000e6 + 306_000e6); // Principal + 2_000_000s of loan1 at 0.9e6 + 1_700_000s of loan2 at 0.18e6 IR

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 180_000e6 + 180_000e6);

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [2_300e6,      18_000e6]);
    }

    function test_claim_latePayment_interestOnly_onTimePayment_interestOnly() external {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(3_527_000e6); // Already warped 300_000 seconds at 0.09 IR after start before funding loan2

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     27_000e6,
            principalOut:          3_000_000e6,
            assetsUnderManagement: 3_027_000e6,
            issuanceRate:          0.27e6 * 1e30,     // 0.09 from loan1 and 0.18 from loan2
            domainStart:           start + 300_000,   // Time of loan2 funding
            domainEnd:             start + 1_000_000, // Payment due date of loan1
            unrealizedLosses:      0
        });

        // PoolDelegate and treasury get their own originationFee for each loan
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [1_000e6,      285_388126]);

        /*****************************************/
        /*** Pre Loan1 Late Payment Assertions ***/
        /*****************************************/

        vm.warp(start + 1_100_000);

        assertTotalAssets(3_500_000e6 + 90_000e6 + 126_000e6); // Principal + 1_000_000s of loan1 at 0.09e6 IR + 700_000s of loan2 at 0.18e6 IR. The issuance stops at DomainEnd, so no accrual after second 1_000_000

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  117_280e6,        // 0.1 * 1_000_000 = 100_000 + late(86400 seconds * 2 * 0.1) = 17_280
            incomingFees:      10_000e6 + 300e6, // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000
        });

        assertLoanManager({
            accruedInterest:       90_000e6 + 126_000e6 - 27_000e6,
            accountedInterest:     27_000e6,
            principalOut:          3_000_000e6,
            assetsUnderManagement: 3_216_000e6,
            issuanceRate:          0.27e6 * 1e30,
            domainStart:           start + 300_000,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
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
        assertTotalAssets(3_500_000e6 + 90_000e6 + 9_000e6 + 15_552e6 + 144_000e6); // Principal + 1_000_000s of loan1 at 0.09 + 800_000s of loan2 at 0.18e6 IR + late fees

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6,
            incomingFees:      10_000e6 + 300e6, // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 2
        });

        assertLoanInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start + 1_000_000,
            paymentDueDate:      start + 2_000_000
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     144_000e6 + 9_000e6,    // 800_000s at 0.18e6 + 9_000e6 accrued from 100_000s at 0.9e6 from loan1
            principalOut:          3_000_000e6,
            assetsUnderManagement: 3_153_000e6,
            issuanceRate:          0.27e6 * 1e30,
            domainStart:           start + 1_100_000,
            domainEnd:             start + 1_300_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 90_000e6 + 15_552e6);

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee + late interest (17_280e6 * 0.02 = 345_600000)
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee + late interest (17_280e6 * 0.08 = 1382_400000)
        assertAssetBalancesIncrease([poolDelegate,      treasury],
                                    [2_300e6 + 345.6e6, 18_000e6 + 1382.4e6]);

        /************************************/
        /*** Pre Loan2 Payment Assertions ***/
        /************************************/

        vm.warp(start + 1_300_000);

        assertTotalAssets(3_500_000e6 + 117_000e6 + 180_000e6 + 15_552e6); // Principal + 1_300_000s of loan1 at 0.9e6 + 1_000_000s of loan2 at 0.18e6 IR + loan1 late interest

        assertLoanState({
            loan:              loan2,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_300_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan2,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 300_000,
            paymentDueDate:      start + 1_300_000
        });

        assertLoanManager({
            accruedInterest:       27_000e6 + 180_000e6 - (144_000e6 + 9_000e6),  // loan1 + loan2 - accounted from loan2
            accountedInterest:     144_000e6 + 9_000e6,    // 700_000s at 0.18e6
            principalOut:          3_000_000e6,
            assetsUnderManagement: 3_207_000e6,
            issuanceRate:          0.27e6 * 1e30,
            domainStart:           start + 1_100_000,
            domainEnd:             start + 1_300_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 90_000e6 + 15_552e6);

        /*************************************/
        /*** Post Loan2 Payment Assertions ***/
        /*************************************/

        makePayment(loan2);

        assertTotalAssets(3_500_000e6 + 117_000e6 + 180_000e6 + 15_552e6); // Principal + 1_300_000s of loan1 at 0.9e6 + 1_000_000s of loan2 at 0.18e6 IR

        assertLoanState({
            loan:              loan2,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2_300_000,
            paymentsRemaining: 2
        });

        assertLoanInfo({
            loan:                loan2,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 1_300_000,
            paymentDueDate:      start + 2_300_000
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     27_000e6,    // 700_000s at 0.18e6
            principalOut:          3_000_000e6,
            assetsUnderManagement: 3_027_000e6,
            issuanceRate:          0.27e6 * 1e30,
            domainStart:           start + 1_300_000,
            domainEnd:             start + 2_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 90_000e6 + 180_000e6 + 15_552e6);

        // Pool Delegate fee: 300e6    flat from service fee + 4_000e6 from management fee
        // Treasury fee:      10_000e6 flat from service fee + 16_000e6 from management fee
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [4_300e6,      36_000e6]);

        /********************************************/
        /*** Post Loan1 second Payment Assertions ***/
        /********************************************/

        vm.warp(start + 2_000_000);

        makePayment(loan1);

        assertTotalAssets(3_500_000e6 + 180_000e6 + 306_000e6 + 15_552e6); // Principal + 2_000_000s of loan1 at 0.9e6 + 1_700_000s of loan2 at 0.18e6 IR + late fees

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 180_000e6 + 180_000e6 + 15_552e6);

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [2_300e6,      18_000e6]);
    }

}

// TODO: Add closeLoan coverage

contract ClaimTestsDomainStartGtDomainEnd is TestBaseWithAssertions {

    address borrower1;
    address borrower2;
    address lp;

    Loan loan1;
    Loan loan2;

    function setUp() public override {
        super.setUp();

        borrower1 = address(new Address());
        borrower2 = address(new Address());
        lp        = address(new Address());

        depositLiquidity({
            lp:        lp,
            liquidity: 3_500_000e6
        });

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,
            platformManagementFeeRate:  0.08e6
        });
    }

    function test_claim_domainStart_gt_domainEnd() external {
        // Loan1 is funded at start
        loan1 = fundAndDrawdownLoan({
            borrower:         borrower1,
            termDetails:      [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:          [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:            [uint256(3.1536e18), 0, 0, 0]  // 0.1e6 tokens per second
        });

        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(3_500_000e6);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000, // Payment due date of loan1.
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 2_500_000e6);

        // PoolDelegate and treasury get their own originationFee for each loan
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [500e6,        95_129375]);

        /*********************************/
        /*** Pre loan2 fund Assertions ***/
        /*********************************/

        vm.warp(start + 2_200_000);

        assertTotalAssets(3_500_000e6 + 90_000e6);

        assertLoanManager({
            accruedInterest:       90_000e6,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_090_000e6,
            issuanceRate:          0.09e6 * 1e30,     // Although it's past the domainEnd, the loanManager haven't been pinged, so it's considering the old issuance rate.
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  220_960e6,         // Includes late interest.
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 2_500_000e6);

        /**********************************/
        /*** Post loan2 fund Assertions ***/
        /**********************************/

        loan2 = fundAndDrawdownLoan({
            borrower:         borrower2,
            termDetails:      [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:          [uint256(0), uint256(2_000_000e6), uint256(2_000_000e6)],
            rates:            [uint256(3.1536e18), 0, 0, 0]  // 0.1e6 tokens per second
        });

        assertTotalAssets(3_500_000e6 + 90_000e6);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     90_000e6,
            principalOut:          3_000_000e6,
            assetsUnderManagement: 3_090_000e6,
            issuanceRate:          0.18e6 * 1e30,     // Only loan2 is accruing.
            domainStart:           start + 2_200_000,
            domainEnd:             start + 3_200_000,
            unrealizedLosses:      0
        });

        assertLoanState({
            loan:              loan2,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 3_200_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan2,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 2_200_000,
            paymentDueDate:      start + 3_200_000
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        // PoolDelegate and treasury get their own originationFee
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [500e6,        190_258751]);

        /*****************************/
        /*** Pre loan2 1st Payment ***/
        /*****************************/

        vm.warp(start + 3_200_000);

        assertTotalAssets(3_500_000e6 + 90_000e6 + 180_000e6); // 90_000e6 accounted for loan1 and and 180_000e6 for loan2.

        assertLoanManager({
            accruedInterest:       180_000e6,
            accountedInterest:     90_000e6,
            principalOut:          3_000_000e6,
            assetsUnderManagement: 3_270_000e6,
            issuanceRate:          0.18e6 * 1e30,     // Only loan2 is accruing.
            domainStart:           start + 2_200_000,
            domainEnd:             start + 3_200_000,
            unrealizedLosses:      0
        });

        // Loan1 Assertions.
        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6 + 224_640e6,         // Includes late interest.
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0,             // IR has been updated for loan 1.
            startDate:           start,
            paymentDueDate:      start + 1_000_000
        });

        // Loan2 Assertions.
        assertLoanState({
            loan:              loan2,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 3_200_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan2,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 2_200_000,
            paymentDueDate:      start + 3_200_000
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        /******************************/
        /*** Post loan2 1st Payment ***/
        /******************************/

        makePayment(loan2);

        assertTotalAssets(3_500_000e6 + 90_000e6 + 180_000e6); // 90_000e6 accounted for loan1 and and 180_000e6 for loan2.

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     90_000e6,
            principalOut:          3_000_000e6,
            assetsUnderManagement: 3_090_000e6,
            issuanceRate:          0.18e6 * 1e30,     // Only loan2 is accruing.
            domainStart:           start + 3_200_000,
            domainEnd:             start + 4_200_000,
            unrealizedLosses:      0
        });

        assertLoanState({
            loan:              loan2,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 4_200_000,
            paymentsRemaining: 2
        });

        assertLoanInfo({
            loan:                loan2,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 3_200_000,
            paymentDueDate:      start + 4_200_000
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 180_000e6);

        // Pool Delegate fee: 300e6    flat from service fee + 4_000e6 from management fee
        // Treasury fee:      10_000e6 flat from service fee + 16_000e6 from management fee
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [4_300e6,      36_000e6]);

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

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  220_960e6,         // Includes late interest.
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 2
        });

        assertLoanInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,         // Includes late interest.
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           start + 1_000_000,
            paymentDueDate:      start + 2_000_000  // Already in the past.
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     90_000e6,
            principalOut:          3_000_000e6,
            assetsUnderManagement: 3_090_000e6,
            issuanceRate:          0.18e6 * 1e30,     // Only loan2 is accruing.
            domainStart:           start + 3_200_000,
            domainEnd:             start + 4_200_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 90_000e6 + 180_000e6 + 202_176e6);

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee + late interest (224_640e6 * 0.02 = 4492_800000)
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee + late interest (224_640e6 * 0.08 = 17971_200000)
        assertAssetBalancesIncrease([poolDelegate,        treasury],
                                    [2_300e6 + 4_492.8e6, 18_000e6 + 17_971.2e6]);

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

        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 1_000_000e6,
            incomingInterest:  125_920e6,         // Includes late interest.
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 3_000_000,
            paymentsRemaining: 1
        });

        assertLoanInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           start + 2_000_000,
            paymentDueDate:      start + 3_000_000  // Already in the past.
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     90_000e6,
            principalOut:          3_000_000e6,
            assetsUnderManagement: 3_090_000e6,
            issuanceRate:          0.18e6 * 1e30,     // Only loan2 is accruing.
            domainStart:           start + 3_200_000,
            domainEnd:             start + 4_200_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 180_000e6 + 90_000e6 + 202_176e6 + 90_000e6 + 108_864e6);

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee + late interest (120_960e6 * 0.02 = 2419_200000)
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee + late interest (120_960e6 * 0.08 = 9676_800000)
        assertAssetBalancesIncrease([poolDelegate,        treasury],
                                    [2_300e6 + 2_419.2e6, 18_000e6 + 9_676.8e6]);

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
        assertLoanInfo({
            loan:                loan1,
            incomingNetInterest: 0,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           0,
            paymentDueDate:      0
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          2_000_000e6,
            assetsUnderManagement: 2_000_000e6,
            issuanceRate:          0.18e6 * 1e30,     // Only loan2 is accruing.
            domainStart:           start + 3_200_000,
            domainEnd:             start + 4_200_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6 + 180_000e6 + 90_000e6 + 202_176e6 + 90_000e6 + 108_864e6 + 90_000e6 + 23_328e6);

        // Pool Delegate fee: 300e6    flat from service fee + 2_000e6 from management fee + late interest (25_920e6 * 0.02 = 518_400000)
        // Treasury fee:      10_000e6 flat from service fee + 8_000e6 from management fee + late interest (25_920e6 * 0.08 = 2073_600000)
        assertAssetBalancesIncrease([poolDelegate,      treasury],
                                    [2_300e6 + 518.4e6, 18_000e6 + 2_073.6e6]);
    }
}

contract ClaimTestsPastDomainEnd is TestBaseWithAssertions {

    address borrower1;
    address borrower2;
    address borrower3;
    address lp;

    Loan loan1;
    Loan loan2;
    Loan loan3;

    function setUp() public override {
        super.setUp();

        borrower1 = address(new Address());
        borrower2 = address(new Address());
        borrower3 = address(new Address());
        lp        = address(new Address());

        depositLiquidity({
            lp:        lp,
            liquidity: 6_500_000e6
        });

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,
            platformManagementFeeRate:  0.08e6
        });

        loan1 = fundAndDrawdownLoan({
            borrower:    borrower1,
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e18), uint256(0), uint256(0), uint256(0)]  // 0.1e6 tokens per second
        });

        vm.warp(start + 400_000);

        loan2 = fundAndDrawdownLoan({
            borrower:    borrower2,
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(2_000_000e6), uint256(2_000_000e6)],
            rates:       [uint256(3.1536e18), uint256(0), uint256(0), uint256(0)]  // 0.1e6 tokens per second
        });

        vm.warp(start + 600_000);

        loan3 = fundAndDrawdownLoan({
            borrower:    borrower3,
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(3_000_000e6), uint256(3_000_000e6)],
            rates:       [uint256(3.1536e18), uint256(0), uint256(0), uint256(0)]  // 0.1e6 tokens per second
        });
    }

    function test_claim_lateLoan3_loan1NotPaid_loan2NotPaid() external {

        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        // loan1
        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6,
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000
        });

        // loan2
        assertLoanState({
            loan:              loan2,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_400_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan2,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 400_000,
            paymentDueDate:      start + 1_400_000
        });

        // loan3
        assertLoanState({
            loan:              loan3,
            principal:         3_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  300_000e6,
            incomingFees:      30_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_600_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan3,
            incomingNetInterest: 270_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.27e6 * 1e30,
            startDate:           start + 600_000,
            paymentDueDate:      start + 1_600_000
        });

        // Principal:      6_500_000e6
        // loan1 interest: 600_000s * 0.09e6 = 54_000e6
        // loan2 interest: 200_000s * 0.18e6 = 36_000e6
        assertTotalAssets(6_500_000e6 + 54_000e6 + 36_000e6);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     54_000e6 + 36_000e6,
            principalOut:          6_000_000e6,
            assetsUnderManagement: 6_090_000e6,
            issuanceRate:          0.54e6 * 1e30,
            domainStart:           start + 600_000,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        // PoolDelegate and treasury get their own originationFee for each loan
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [1_500e6,      570_776253]);

        /******************************/
        /*** Loan3 pre late Payment ***/
        /******************************/

        vm.warp(start + 1_700_000);

        // loan3
        assertLoanState({
            loan:              loan3,
            principal:         3_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  351_840e6,         // 2 days of late interest (86400 * 2 * 0.3)
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

        assertLoanManager({
            accruedInterest:       (90_000e6 - 54_000e6) + (108_000e6 - 36_000e6) + 108_000e6,
            accountedInterest:     54_000e6 + 36_000e6,
            principalOut:          6_000_000e6,
            assetsUnderManagement: 6_306_000e6,
            issuanceRate:          0.54e6 * 1e30,
            domainStart:           start + 600_000,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        /*******************************/
        /*** Loan3 post late Payment ***/
        /*******************************/

        makePayment(loan3);

        // loan1
        assertLoanState({
            loan:              loan1,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  177_760e6,         // 700_000s (9 days rounded up) of interest: (86400 * 9 * 0.1) = 77_760
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan1,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           start,
            paymentDueDate:      start + 1_000_000
        });

        // loan2
        assertLoanState({
            loan:              loan2,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  269_120e6,         // 300_000s (4 days rounded up) of interest: (86400 * 4 * 0.2) = 69_120
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 1_400_000,
            paymentsRemaining: 3
        });

        assertLoanInfo({
            loan:                loan2,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0,
            startDate:           start + 400_000,
            paymentDueDate:      start + 1_400_000
        });

        assertLoanState({
            loan:              loan3,
            principal:         3_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  300_000e6,         // 2 days of late interest (86400 * 2 * 0.3)
            incomingFees:      30_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 2_600_000,
            paymentsRemaining: 2
        });

        assertLoanInfo({
            loan:                loan3,
            incomingNetInterest: 270_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.27e6 * 1e30,
            startDate:           start + 1_600_000,
            paymentDueDate:      start + 2_600_000
        });

        // Principal:        6_500_000e6
        // loan1 interest (1st payment): 1_000_000s * 0.09e6 = 90_000e6
        // loan2 interest (1st payment): 1_000_000s * 0.18e6 = 180_000e6
        // loan3 interest (1st payment): 1_000_000s * 0.27e6 = 270_000e6
        // loan3 interest (2nd payment): 100_000s * 0.27e6 = 27_000e6
        // loan3 late interest:          86400s * 2 * 0.27 = 46_656e6
        assertTotalAssets(6_500_000e6 + 90_000e6 + 180_000e6 + 270_000e6 + 27_000e6 + 46_656e6);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     90_000e6 + 180_000e6 + 27_000e6,
            principalOut:          6_000_000e6,
            assetsUnderManagement: 6_297_000e6,
            issuanceRate:          0.27e6 * 1e30,
            domainStart:           start + 1_700_000,
            domainEnd:             start + 2_600_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 270_000e6 + 46_656e6);

        // Pool Delegate fee: 300e6    flat from service fee + 6_000e6 from management fee  + late interest (51_840e6 * 0.02 = 345_600000)
        // Treasury fee:      30_000e6 flat from service fee + 24_000e6 from management fee + late interest (51_840e6 * 0.08 = 1382_400000)
        assertAssetBalancesIncrease([poolDelegate,        treasury],
                                    [6_300e6 + 1_036.8e6, 54_000e6 + 4_147.2e6]);
    }

}
