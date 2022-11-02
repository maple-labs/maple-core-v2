// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestBaseWithAssertions } from "../../contracts/utilities/TestBaseWithAssertions.sol";

import { Address, console  } from "../../modules/contract-test-utils/contracts/test.sol";
import { MapleLoan as Loan } from "../../modules/loan/contracts/MapleLoan.sol";
import { Refinancer        } from "../../modules/loan/contracts/Refinancer.sol";

contract RefinanceTestsSingleLoan is TestBaseWithAssertions {

    address borrower;
    address lp;

    Loan       loan;
    Refinancer refinancer;

    function setUp() public override {
        super.setUp();

        borrower   = address(new Address());
        lp         = address(new Address());
        refinancer = new Refinancer();

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
            termDetails:      [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:          [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:            [uint256(3.1536e18), 0, 0, 0]  // 0.1e6 tokens per second
        });

    }

    function test_refinance_onLoanPaymentDueDate_changePaymentInterval() external {

        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(2_500_000e6);

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

        /********************************/
        /*** Pre Refinance Assertions ***/
        /********************************/

        vm.warp(start + 1_000_000);

        assertTotalAssets(2_500_000e6 + 90_000e6);

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

        assertPaymentInfo({
            loan:                loan,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanManager({
            accruedInterest:       90_000e6,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_090_000e6,     // principal + accrued interest
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6);

        /****************************/
        /*** Refinance Assertions ***/
        /****************************/

        bytes[] memory data = encodeWithSignatureAndUint("setPaymentInterval(uint256)", 2_000_000);

        vm.startPrank(borrower);
        loan.proposeNewTerms(address(refinancer), block.timestamp + 1, data);
        fundsAsset.mint(borrower, 10_000e6);
        fundsAsset.approve(address(loan), 10_000e6);
        loan.returnFunds(10_000e6);  // Return funds to pay origination fees.
        vm.stopPrank();

        vm.prank(poolDelegate);
        poolManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, data, 0);

        assertTotalAssets(2_500_000e6 + 90_000e6);

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  300_000e6,                           // 200_000e6 from second payment period + 100_000e6 from first period (refinanced)
            incomingFees:      10_000e6 + 300e6 + 20_000e6 + 300e6, // 10_000e6 of platform service fees + 300e6 of delegate service fees of 1st period + 20_000e6 of platform service fees of 2nd period (delegate fees are constant)
            refinanceInterest: 100_000e6,
            paymentDueDate:    start + 3_000_000,
            paymentsRemaining: 3
        });

        assertPaymentInfo({
            loan:                loan,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   90_000e6,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start + 1_000_000,
            paymentDueDate:      start + 3_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     90_000e6,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_090_000e6,     // principal + accrued interest
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start + 1_000_000,
            domainEnd:             start + 3_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6);

        // During refinance, origination fees are paid again
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [500e6,        190_258751]);

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        vm.warp(start + 3_000_000);

        makePayment(loan);

        assertTotalAssets(2_500_000e6 + 270_000e6);

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,        // 200_000e6 from second payment period + 100_000e6 from first period (refinanced)
            incomingFees:      20_000e6 + 300e6, // 20_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 5_000_000,
            paymentsRemaining: 2
        });

        assertPaymentInfo({
            loan:                loan,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start + 3_000_000,
            paymentDueDate:      start + 5_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,     // Principal + accrued interest
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start + 3_000_000,
            domainEnd:             start + 5_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6 + 270_000e6);

        // Pool Delegate fee: 1st period (300e6 flat + 2_000e6)   + 2nd period (300e6 flat + 4_000e6)
        // Treasury fee:      1st period (10_00e6 flat + 8_000e6) + 2nd period (20_00e6 flat + 16_000e6)
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [6_600e6,      54_000e6]);
    }

    function test_refinance_onLoanPaymentDueDate_increasePrincipal() external {

        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(2_500_000e6);

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

        /********************************/
        /*** Pre Refinance Assertions ***/
        /********************************/

        vm.warp(start + 1_000_000);

        assertTotalAssets(2_500_000e6 + 90_000e6);

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

        assertPaymentInfo({
            loan:                loan,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanManager({
            accruedInterest:       90_000e6,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_090_000e6,     // principal + accrued interest
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6);

        /****************************/
        /*** Refinance Assertions ***/
        /****************************/

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSignature("increasePrincipal(uint256)",  1_000_000e6);
        calls[1] = abi.encodeWithSignature("setEndingPrincipal(uint256)", 2_000_000e6);

        vm.startPrank(borrower);
        loan.proposeNewTerms(address(refinancer), block.timestamp + 1, calls);
        fundsAsset.mint(address(borrower), 20_000e6); // Amount for origination fees
        fundsAsset.approve(address(loan), 20_000e6);
        loan.returnFunds(20_000e6);
        vm.stopPrank();

        vm.prank(poolDelegate);
        poolManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, calls, 1_000_000e6);

        assertTotalAssets(2_500_000e6 + 90_000e6);

        assertLoanState({
            loan:              loan,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  300_000e6,                           // 200_000e6 from second payment period + 100_000e6 from first period (refinanced)
            incomingFees:      10_000e6 + 20_000e6 + 300e6 + 300e6,
            refinanceInterest: 100_000e6,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 3
        });

        assertPaymentInfo({
            loan:                loan,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   90_000e6,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 1_000_000,
            paymentDueDate:      start + 2_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     90_000e6,
            principalOut:          2_000_000e6,
            assetsUnderManagement: 2_090_000e6,     // principal + accrued interest
            issuanceRate:          0.18e6 * 1e30,
            domainStart:           start + 1_000_000,
            domainEnd:             start + 2_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        // During refinance, origination fees are paid again
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [500e6,        190_258751]);

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        vm.warp(start + 2_000_000);

        makePayment(loan);

        assertTotalAssets(2_500_000e6 + 270_000e6);

        assertLoanState({
            loan:              loan,
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,        // 200_000e6 from second payment period + 100_000e6 from first period (refinanced)
            incomingFees:      20_000e6 + 300e6, // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 3_000_000,
            paymentsRemaining: 2
        });

        assertPaymentInfo({
            loan:                loan,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 2_000_000,
            paymentDueDate:      start + 3_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          2_000_000e6,
            assetsUnderManagement: 2_000_000e6,     // principal + accrued interest
            issuanceRate:          0.18e6 * 1e30,
            domainStart:           start + 2_000_000,
            domainEnd:             start + 3_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 270_000e6);  // Interest + refinance interest

        // Pool Delegate fee: 1st period (300e6 flat + 2_000e6)   + 2nd period (300e6 flat + 4_000e6)
        // Treasury fee:      1st period (10_00e6 flat + 8_000e6) + 2nd period (20_00e6 flat + 16_000e6)
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [6_600e6,      54_000e6]);
    }

    function test_refinance_onLoanPaymentDueDate_changeInterestRate() external {

        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(2_500_000e6);

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

        /********************************/
        /*** Pre Refinance Assertions ***/
        /********************************/

        vm.warp(start + 1_000_000);

        assertTotalAssets(2_500_000e6 + 90_000e6);

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

        assertPaymentInfo({
            loan:                loan,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanManager({
            accruedInterest:       90_000e6,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_090_000e6,     // principal + accrued interest
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6);

        /****************************/
        /*** Refinance Assertions ***/
        /****************************/

        bytes[] memory data = encodeWithSignatureAndUint("setInterestRate(uint256)", 6.3072e18);  // 2x

        vm.startPrank(borrower);
        loan.proposeNewTerms(address(refinancer), block.timestamp + 1, data);
        fundsAsset.mint(borrower, 10_000e6);
        fundsAsset.approve(address(loan), 10_000e6);
        loan.returnFunds(10_000e6);
        vm.stopPrank();

        vm.prank(poolDelegate);
        poolManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, data, 0);

        assertTotalAssets(2_500_000e6 + 90_000e6);

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  300_000e6,              // 200_000e6 from second payment period + 100_000e6 from first period (refinanced)
            incomingFees:      (10_000e6 + 300e6) * 2, // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 100_000e6,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 3
        });

        assertPaymentInfo({
            loan:                loan,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   90_000e6,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 1_000_000,
            paymentDueDate:      start + 2_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     90_000e6,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_090_000e6,     // principal + accrued interest
            issuanceRate:          0.18e6 * 1e30,
            domainStart:           start + 1_000_000,
            domainEnd:             start + 2_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6);

        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [500e6,        95_129375]);

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        vm.warp(start + 2_000_000);

        makePayment(loan);

        assertTotalAssets(2_500_000e6 + 270_000e6);

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,        // 200_000e6 from second payment period + 100_000e6 from first period (refinanced)
            incomingFees:      10_000e6 + 300e6, // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 3_000_000,
            paymentsRemaining: 2
        });

        assertPaymentInfo({
            loan:                loan,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 2_000_000,
            paymentDueDate:      start + 3_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,     // principal + accrued interest
            issuanceRate:          0.18e6 * 1e30,
            domainStart:           start + 2_000_000,
            domainEnd:             start + 3_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6 + 270_000e6);

        // Pool Delegate fee: 1st period (300e6 flat + 2_000e6)   + 2nd period (300e6 flat + 4_000e6)
        // Treasury fee:      1st period (10_00e6 flat + 8_000e6) + 2nd period (10_00e6 flat + 16_000e6)
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [6_600e6,      44_000e6]);
    }

    function test_refinance_onLoanPaymentDueDate_changeToAmortized() external {

        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(2_500_000e6);

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

        /********************************/
        /*** Pre Refinance Assertions ***/
        /********************************/

        vm.warp(start + 1_000_000);

        assertTotalAssets(2_500_000e6 + 90_000e6);

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

        assertPaymentInfo({
            loan:                loan,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanManager({
            accruedInterest:       90_000e6,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_090_000e6,     // principal + accrued interest
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6);

        /****************************/
        /*** Refinance Assertions ***/
        /****************************/

        bytes[] memory data = encodeWithSignatureAndUint("setEndingPrincipal(uint256)", 0);

        vm.startPrank(borrower);
        loan.proposeNewTerms(address(refinancer), block.timestamp + 1, data);
        fundsAsset.mint(borrower, 10_000e6);
        fundsAsset.approve(address(loan), 10_000e6);
        loan.returnFunds(10_000e6);
        vm.stopPrank();

        vm.prank(poolDelegate);
        poolManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, data, 0);

        assertTotalAssets(2_500_000e6 + 90_000e6);

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            incomingPrincipal: 302_114_803625,
            incomingInterest:  200_000e6,              // 100_000e6 from second payment period + 100_000e6 from first period (refinanced)
            incomingFees:      (10_000e6 + 300e6) * 2, // 2 full periods of fees
            refinanceInterest: 100_000e6,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 3
        });

        assertPaymentInfo({
            loan:                loan,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   90_000e6,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start + 1_000_000,
            paymentDueDate:      start + 2_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     90_000e6,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_090_000e6,     // principal + accrued interest
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start + 1_000_000,
            domainEnd:             start + 2_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6);

        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [500e6,        95_129375]);

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        vm.warp(start + 2_000_000);

        makePayment(loan);

        assertTotalAssets(2_500_000e6 + 180_000e6);

        assertLoanState({
            loan:              loan,
            principal:         697_885_196375,
            incomingPrincipal: 332_326_283988,
            incomingInterest:  69_788_519637,
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 3_000_000,
            paymentsRemaining: 2
        });

        assertPaymentInfo({
            loan:                loan,
            incomingNetInterest: 62_809_667673,
            refinanceInterest:   0,
            issuanceRate:        0.062809667673e6 * 1e30,
            startDate:           start + 2_000_000,
            paymentDueDate:      start + 3_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          697_885_196375,
            assetsUnderManagement: 697_885_196375,     // principal + accrued interest
            issuanceRate:          0.062809667673e6 * 1e30,
            domainStart:           start + 2_000_000,
            domainEnd:             start + 3_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6 + 180_000e6 + 302_114_803625);

        // Pool Delegate fee: 1st period (300e6 flat + 2_000e6)   + 2nd period (300e6 flat + 2_000e6)
        // Treasury fee:      1st period (10_00e6 flat + 8_000e6) + (10_00e6 flat + 8_000e6)
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [4_600e6,      36_000e6]);
    }

    function test_refinance_onLateLoan_changePaymentInterval() external {

        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(2_500_000e6);

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

        /********************************/
        /*** Pre Refinance Assertions ***/
        /********************************/

        vm.warp(start + 1_500_000);

        assertTotalAssets(2_500_000e6 + 90_000e6);

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  151_840e6,        // Late interest: 6 days: 86400 * 6 * 0.1e6 = 51_840e6
            incomingFees:      10_000e6 + 300e6, // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertPaymentInfo({
            loan:                loan,
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanManager({
            accruedInterest:       90_000e6,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_090_000e6,     // principal + accrued interest
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start,
            domainEnd:             start + 1_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6);

        /****************************/
        /*** Refinance Assertions ***/
        /****************************/

        bytes[] memory data = encodeWithSignatureAndUint("setPaymentInterval(uint256)", 2_000_000);

        vm.startPrank(borrower);
        loan.proposeNewTerms(address(refinancer), block.timestamp + 1, data);
        fundsAsset.mint(borrower, 10_000e6);
        fundsAsset.approve(address(loan), 10_000e6);
        loan.returnFunds(10_000e6);
        vm.stopPrank();

        vm.prank(poolDelegate);
        poolManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, data, 0);

        assertTotalAssets(2_500_000e6 + 181_656e6); // Principal + interest owed at refinance time (201_840e6 * 0.9 to discount service fees)

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  401_840e6,                           // first period (100_000e6) + late fees for first period (151_840e6) + second period before refinance (50_000e6) + refinanced period incoming (200_000e6)
            incomingFees:      15_000e6 + 450e6 + 20_000e6 + 300e6, // 10_000e6 of platform service fees + 300e6 of delegate service fees.
            refinanceInterest: 201_840e6,                           // first period (100_000e6) + late fees for first period (151_840e6) + second period before refinance (50_000e6)
            paymentDueDate:    start + 3_500_000,
            paymentsRemaining: 3
        });

        assertPaymentInfo({
            loan:                loan,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   181_656e6,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start + 1_500_000,
            paymentDueDate:      start + 3_500_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     181_656e6,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_181_656e6,     // principal + accrued interest
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start + 1_500_000,
            domainEnd:             start + 3_500_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6);

        // During refinance, origination fees are paid again
        assertAssetBalancesIncrease([poolDelegate, treasury],
                                    [500e6,        190_258751]);

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        vm.warp(start + 3_500_000);

        makePayment(loan);

        assertTotalAssets(2_500_000e6 + 181_656e6 + 180_000e6);

        assertLoanState({
            loan:              loan,
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 5_500_000,
            paymentsRemaining: 2
        });

        assertPaymentInfo({
            loan:                loan,
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start + 3_500_000,
            paymentDueDate:      start + 5_500_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,     // principal + accrued interest
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start + 3_500_000,
            domainEnd:             start + 5_500_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6 + 180_000e6 + 181_656e6);

        // Pool Delegate fee: 1st period (450e6    + 3_000e6)  + 2nd period after refinance (300e6 flat + 4_000e6)  + late interest from 1st period (51_840e6 * 0.02 = 1036_800000)
        // Treasury fee:      1st period (15_000e6 + 12_000e6) + 2nd period after refinance (20_00e6   + 16_000e6) + late interest from 1st period (51_840e6 * 0.08 = 4147_200000)
        assertAssetBalancesIncrease([poolDelegate,        treasury],
                                    [7_750e6 + 1_036.8e6, 63_000e6 + 4_147.2e6]);
    }

    function test_refinance_skimFundAsset() external {
        bytes[] memory data = encodeWithSignatureAndUint("setPaymentInterval(uint256)", 2_000_000);

        vm.startPrank(borrower);
        loan.proposeNewTerms(address(refinancer), block.timestamp + 1, data);
        fundsAsset.mint(borrower, 10_000e6);
        fundsAsset.approve(address(loan), 10_000e6);
        loan.returnFunds(10_000e6);  // Return funds to pay origination fees.
        vm.stopPrank();

        fundsAsset.mint(address(loan), 1_000e6);  // Fund asset to skim

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6);

        vm.prank(poolDelegate);
        poolManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, data, 0);

        assertEq(fundsAsset.balanceOf(address(pool)), 1_501_000e6);
    }

}

contract AcceptNewTermsFailureTests is TestBaseWithAssertions {

    address borrower;
    address lp;

    Loan       loan;
    Refinancer refinancer;

    function setUp() public override {
        super.setUp();

        borrower   = address(new Address());
        lp         = address(new Address());
        refinancer = new Refinancer();

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
            borrower:    borrower,
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e18), 0, 0, 0]  // 0.1e6 tokens per second
        });
    }

    function test_acceptNewTerms_failIfProtocolIsPaused() external {
        vm.prank(globals.securityAdmin());
        globals.setProtocolPause(true);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, new bytes[](0), 0);
    }

    function test_acceptNewTerms_failIfNotPoolDelegate() external {
        vm.expectRevert("PM:VAFL:NOT_PD");
        poolManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, new bytes[](0), 0);
    }

    function test_acceptNewTerms_failIfNotValidLoanManager() external {
        address fakeLoan = address(new Address());

        vm.prank(poolDelegate);
        vm.expectRevert("PM:VAFL:INVALID_LOAN_MANAGER");
        poolManager.acceptNewTerms(fakeLoan, address(refinancer), block.timestamp + 1, new bytes[](0), 0);
    }

    function test_acceptNewTerms_failIfInvalidBorrower() external {
        vm.prank(governor);
        globals.setValidBorrower(borrower, false);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:VAFL:INVALID_BORROWER");
        poolManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, new bytes[](0), 0);
    }

    function test_acceptNewTerms_failIfTotalSupplyIsZero() external {
        uint256 fullBalance = pool.balanceOf(lp);

        // Close loan so lp can burn full supply. Impossible scenario because refinance would fail on loan.
        ( uint256 principal, uint256 interest, uint256 fees ) = loan.getClosingPaymentBreakdown();

        fundsAsset.mint(address(loan), principal + interest + fees);
        loan.closeLoan(0);

        // Burn the supply
        vm.startPrank(lp);
        pool.requestRedeem(fullBalance, lp);

        vm.warp(start + 2 weeks);

        pool.redeem(fullBalance, address(lp), address(lp));
        vm.stopPrank();

        vm.prank(poolDelegate);
        vm.expectRevert("PM:VAFL:ZERO_SUPPLY");
        poolManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, new bytes[](0), 0);
    }

    function test_acceptNewTerms_failIfInsufficientCover() external {
        vm.prank(governor);
        globals.setMinCoverAmount(address(poolManager), 1e6);

        fundsAsset.mint(address(poolManager.poolDelegateCover()), 1e6 - 1);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:VAFL:INSUFFICIENT_COVER");
        poolManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, new bytes[](0), 0);
    }

    function test_acceptNewTerms_failWithFailedTransfer() external {
        vm.prank(poolDelegate);
        vm.expectRevert("PM:VAFL:TRANSFER_FAIL");
        poolManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, new bytes[](0), 1_500_000e6 + 1);
    }

    function test_acceptNewTerms_failIfLockedLiquidity() external {
        // Lock the liquidity
        vm.prank(lp);
        pool.requestRedeem(500_000e6 + 1, lp);

        vm.warp(start + 2 weeks);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:VAFL:LOCKED_LIQUIDITY");
        poolManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, new bytes[](0), 1_500_000e6);
    }

    function test_acceptNewTerms_failifNotPoolManager() external {
        vm.expectRevert("LM:ANT:NOT_ADMIN");
        loanManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, new bytes[](0));
    }

    function test_acceptNewTerms_failIfNotLender() external {
        vm.expectRevert("ML:ANT:NOT_LENDER");
        loan.acceptNewTerms(address(refinancer), block.timestamp + 1, new bytes[](0));
    }

    function test_acceptNewTerms_failIfRefinanceMismatch() external {
        vm.prank(poolDelegate);
        vm.expectRevert("ML:ANT:COMMITMENT_MISMATCH");
        poolManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, new bytes[](0), 0);
    }

    function test_acceptNewTerms_failWithInvalidRefinancer() external {
        address fakeRefinancer = address(2);

        bytes[] memory data = encodeWithSignatureAndUint("setPaymentInterval(uint256)", 2_000_000);

        // Make commitment
        vm.prank(borrower);
        loan.proposeNewTerms(fakeRefinancer, block.timestamp + 1, data);

        vm.prank(poolDelegate);
        vm.expectRevert("ML:ANT:INVALID_REFINANCER");
        poolManager.acceptNewTerms(address(loan), fakeRefinancer, block.timestamp + 1, data, 0);
    }

    function test_acceptNewTerms_failIfDeadlineExpired() external {
        bytes[] memory data = encodeWithSignatureAndUint("setPaymentInterval(uint256)", 2_000_000);

        uint256 deadline = block.timestamp + 1;

        // Make commitment
        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), deadline, data);

        vm.warp(deadline + 1);

        vm.prank(poolDelegate);
        vm.expectRevert("ML:ANT:EXPIRED_COMMITMENT");
        poolManager.acceptNewTerms(address(loan), address(refinancer), deadline, data, 0);
    }

    function test_acceptNewTerms_failIfRefinanceCallFails() external {
        address fakeRefinancer = address(new Address());

        bytes[] memory data = encodeWithSignatureAndUint("setPaymentInterval(uint256)", 2_000_000);

        // Make commitment
        vm.prank(borrower);
        loan.proposeNewTerms(fakeRefinancer, block.timestamp + 1, data);

        vm.prank(poolDelegate);
        vm.expectRevert("ML:ANT:FAILED");
        poolManager.acceptNewTerms(address(loan), fakeRefinancer, block.timestamp + 1, data, 0);
    }

    function test_acceptNewTerms_failWithInsufficientCollateral() external {
        bytes[] memory data = encodeWithSignatureAndUint("setCollateralRequired(uint256)", 1);

        // Make commitment
        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), block.timestamp + 1, data);

        // Mint fees to cover origination fees
        fundsAsset.mint(address(loan), 1_000e6);

        vm.prank(poolDelegate);
        vm.expectRevert("MLFM:POF:PD_TRANSFER");
        poolManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, data, 0);
    }

    function test_acceptNewTerms_failWithUnexpectedFunds() external {
        bytes[] memory data = encodeWithSignatureAndUint("setPaymentInterval(uint256)", 2_000_000);

        // Make commitment
        vm.prank(borrower);
        loan.proposeNewTerms(address(refinancer), block.timestamp + 1, data);

        // Mint fees to cover origination fees
        fundsAsset.mint(address(loan), 1_000e6);
        loan.returnFunds(0);

        vm.prank(poolDelegate);
        vm.expectRevert("ML:ANT:UNEXPECTED_FUNDS");
        poolManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, data, 1);
    }

}
