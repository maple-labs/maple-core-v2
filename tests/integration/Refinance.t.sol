// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IFixedTermLoan, IFixedTermLoanManager } from "../../contracts/interfaces/Interfaces.sol";

import { Address } from "../../contracts/Contracts.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

contract RefinanceTestsSingleLoan is TestBaseWithAssertions {

    address borrower;
    address lp;

    IFixedTermLoan        loan;
    IFixedTermLoanManager loanManager;

    function setUp() public override {
        super.setUp();

        borrower = address(new Address());
        lp       = address(new Address());

        depositLiquidity(lp, 2_500_000e6);

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,
            platformManagementFeeRate:  0.08e6
        });

        loanManager = IFixedTermLoanManager(poolManager.loanManagerList(0));

        loan = IFixedTermLoan(fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e18), 0, 0, 0],  // 0.1e6 tokens per second
            loanManager: address(loanManager)
        }));

    }

    function test_refinance_onLoanPaymentDueDate_changePaymentInterval() external {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(2_500_000e6);

        assertFixedTermLoanManager({
            loanManager:           address(loanManager),
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
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [500e6,        95_129375]
        );

        /********************************/
        /*** Pre Refinance Assertions ***/
        /********************************/

        vm.warp(start + 1_000_000);

        assertTotalAssets(2_500_000e6 + 90_000e6);

        assertFixedTermLoan({
            loan:              address(loan),
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6,          // 0.1 * 1_000_000 = 100_000
            incomingFees:      10_000e6 + 300e6,   // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                address(loan),
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:           address(loanManager),
            accruedInterest:       90_000e6,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_090_000e6,        // principal + accrued interest
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

        proposeRefinance(address(loan), address(refinancer), block.timestamp + 1, data);

        returnFunds(address(loan), 10_000e6);  // Return funds to pay origination fees. TODO: determine exact amount.

        acceptRefinance(address(loan), address(refinancer), block.timestamp + 1, data, 0);

        assertTotalAssets(2_500_000e6 + 90_000e6);

        assertFixedTermLoan({
            loan:              address(loan),
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            // 200_000e6 from second payment period + 100_000e6 from first period (refinanced)
            incomingInterest:  300_000e6,
            // 10_000e6 of platform service fees + 300e6 of delegate service fees of 1st period
            // + 20_000e6 of platform service fees of 2nd period (delegate fees are constant)
            incomingFees:      10_000e6 + 300e6 + 20_000e6 + 300e6,
            refinanceInterest: 100_000e6,
            paymentDueDate:    start + 3_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                address(loan),
            incomingNetInterest: 180_000e6,
            refinanceInterest:   90_000e6,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start + 1_000_000,
            paymentDueDate:      start + 3_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:           address(loanManager),
            accruedInterest:       0,
            accountedInterest:     90_000e6,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_090_000e6,        // principal + accrued interest
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start + 1_000_000,
            domainEnd:             start + 3_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6);

        // During refinance, origination fees are paid again
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [500e6,        190_258751]
        );

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        vm.warp(start + 3_000_000);

        makePayment(address(loan));

        assertTotalAssets(2_500_000e6 + 270_000e6);

        assertFixedTermLoan({
            loan:              address(loan),
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,          // 200_000e6 from second payment period + 100_000e6 from first period (refinanced)
            incomingFees:      20_000e6 + 300e6,   // 20_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 5_000_000,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                address(loan),
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start + 3_000_000,
            paymentDueDate:      start + 5_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:           address(loanManager),
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,        // Principal + accrued interest
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start + 3_000_000,
            domainEnd:             start + 5_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6 + 270_000e6);

        // Pool Delegate fee: 1st period (300e6 flat + 2_000e6)   + 2nd period (300e6 flat + 4_000e6)
        // Treasury fee:      1st period (10_00e6 flat + 8_000e6) + 2nd period (20_00e6 flat + 16_000e6)
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [6_600e6,      54_000e6]
        );
    }

    function test_refinance_onLoanPaymentDueDate_increasePrincipal() external {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(2_500_000e6);

        assertFixedTermLoanManager({
            loanManager:           address(loanManager),
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
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [500e6,        95_129375]
        );

        /********************************/
        /*** Pre Refinance Assertions ***/
        /********************************/

        vm.warp(start + 1_000_000);

        assertTotalAssets(2_500_000e6 + 90_000e6);

        assertFixedTermLoan({
            loan:              address(loan),
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6,          // 0.1 * 1_000_000 = 100_000
            incomingFees:      10_000e6 + 300e6,   // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                address(loan),
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:           address(loanManager),
            accruedInterest:       90_000e6,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_090_000e6,        // principal + accrued interest
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

        proposeRefinance(address(loan), address(refinancer), block.timestamp + 1, calls);

        acceptRefinance(address(loan), address(refinancer), block.timestamp + 1, calls, 1_000_000e6);

        assertTotalAssets(2_500_000e6 + 90_000e6);

        assertFixedTermLoan({
            loan:              address(loan),
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  300_000e6,                            // 200_000e6 from second payment period + 100_000e6 from first period (refinanced)
            incomingFees:      10_000e6 + 20_000e6 + 300e6 + 300e6,
            refinanceInterest: 100_000e6,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                address(loan),
            incomingNetInterest: 180_000e6,
            refinanceInterest:   90_000e6,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 1_000_000,
            paymentDueDate:      start + 2_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:           address(loanManager),
            accruedInterest:       0,
            accountedInterest:     90_000e6,
            principalOut:          2_000_000e6,
            assetsUnderManagement: 2_090_000e6,        // principal + accrued interest
            issuanceRate:          0.18e6 * 1e30,
            domainStart:           start + 1_000_000,
            domainEnd:             start + 2_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        // During refinance, origination fees are paid again
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [500e6,        190_258751]
        );

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        vm.warp(start + 2_000_000);

        makePayment(address(loan));

        assertTotalAssets(2_500_000e6 + 270_000e6);

        assertFixedTermLoan({
            loan:              address(loan),
            principal:         2_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,          // 200_000e6 from second payment period + 100_000e6 from first period (refinanced)
            incomingFees:      20_000e6 + 300e6,   // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 3_000_000,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                address(loan),
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 2_000_000,
            paymentDueDate:      start + 3_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:           address(loanManager),
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          2_000_000e6,
            assetsUnderManagement: 2_000_000e6,        // principal + accrued interest
            issuanceRate:          0.18e6 * 1e30,
            domainStart:           start + 2_000_000,
            domainEnd:             start + 3_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 270_000e6);  // Interest + refinance interest

        // Pool Delegate fee: 1st period (300e6 flat + 2_000e6)   + 2nd period (300e6 flat + 4_000e6)
        // Treasury fee:      1st period (10_00e6 flat + 8_000e6) + 2nd period (20_00e6 flat + 16_000e6)
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [6_600e6,      54_000e6]
        );
    }

    function test_refinance_onLoanPaymentDueDate_changeInterestRate() external {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(2_500_000e6);

        assertFixedTermLoanManager({
            loanManager:           address(loanManager),
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
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [500e6,        95_129375]
        );

        /********************************/
        /*** Pre Refinance Assertions ***/
        /********************************/

        vm.warp(start + 1_000_000);

        assertTotalAssets(2_500_000e6 + 90_000e6);

        assertFixedTermLoan({
            loan:              address(loan),
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6,          // 0.1 * 1_000_000 = 100_000
            incomingFees:      10_000e6 + 300e6,   // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                address(loan),
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:           address(loanManager),
            accruedInterest:       90_000e6,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_090_000e6,        // principal + accrued interest
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

        proposeRefinance(address(loan), address(refinancer), block.timestamp + 1, data);

        returnFunds(address(loan), 10_000e6);  // Return funds to pay origination fees. TODO: determine exact amount.

        acceptRefinance(address(loan), address(refinancer), block.timestamp + 1, data, 0);

        assertTotalAssets(2_500_000e6 + 90_000e6);

        assertFixedTermLoan({
            loan:              address(loan),
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  300_000e6,               // 200_000e6 from second payment period + 100_000e6 from first period (refinanced)
            incomingFees:      (10_000e6 + 300e6) * 2,  // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 100_000e6,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                address(loan),
            incomingNetInterest: 180_000e6,
            refinanceInterest:   90_000e6,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 1_000_000,
            paymentDueDate:      start + 2_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:           address(loanManager),
            accruedInterest:       0,
            accountedInterest:     90_000e6,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_090_000e6,        // principal + accrued interest
            issuanceRate:          0.18e6 * 1e30,
            domainStart:           start + 1_000_000,
            domainEnd:             start + 2_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6);

        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [500e6,        95_129375]
        );

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        vm.warp(start + 2_000_000);

        makePayment(address(loan));

        assertTotalAssets(2_500_000e6 + 270_000e6);

        assertFixedTermLoan({
            loan:              address(loan),
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,          // 200_000e6 from second payment period + 100_000e6 from first period (refinanced)
            incomingFees:      10_000e6 + 300e6,   // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 3_000_000,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                address(loan),
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.18e6 * 1e30,
            startDate:           start + 2_000_000,
            paymentDueDate:      start + 3_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:           address(loanManager),
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,        // principal + accrued interest
            issuanceRate:          0.18e6 * 1e30,
            domainStart:           start + 2_000_000,
            domainEnd:             start + 3_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6 + 270_000e6);

        // Pool Delegate fee: 1st period (300e6 flat + 2_000e6)   + 2nd period (300e6 flat + 4_000e6)
        // Treasury fee:      1st period (10_00e6 flat + 8_000e6) + 2nd period (10_00e6 flat + 16_000e6)
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [6_600e6,      44_000e6]
        );
    }

    function test_refinance_onLoanPaymentDueDate_changeToAmortized() external {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(2_500_000e6);

        assertFixedTermLoanManager({
            loanManager:           address(loanManager),
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
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [500e6,        95_129375]
        );

        /********************************/
        /*** Pre Refinance Assertions ***/
        /********************************/

        vm.warp(start + 1_000_000);

        assertTotalAssets(2_500_000e6 + 90_000e6);

        assertFixedTermLoan({
            loan:              address(loan),
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  100_000e6,          // 0.1 * 1_000_000 = 100_000
            incomingFees:      10_000e6 + 300e6,   // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                address(loan),
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:           address(loanManager),
            accruedInterest:       90_000e6,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_090_000e6,        // principal + accrued interest
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

        proposeRefinance(address(loan), address(refinancer), block.timestamp + 1, data);

        returnFunds(address(loan), 10_000e6);  // Return funds to pay origination fees. TODO: determine exact amount.

        acceptRefinance(address(loan), address(refinancer), block.timestamp + 1, data, 0);

        assertTotalAssets(2_500_000e6 + 90_000e6);

        assertFixedTermLoan({
            loan:              address(loan),
            principal:         1_000_000e6,
            incomingPrincipal: 302_114_803625,
            incomingInterest:  200_000e6,               // 100_000e6 from second payment period + 100_000e6 from first period (refinanced)
            incomingFees:      (10_000e6 + 300e6) * 2,  // 2 full periods of fees
            refinanceInterest: 100_000e6,
            paymentDueDate:    start + 2_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                address(loan),
            incomingNetInterest: 90_000e6,
            refinanceInterest:   90_000e6,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start + 1_000_000,
            paymentDueDate:      start + 2_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:           address(loanManager),
            accruedInterest:       0,
            accountedInterest:     90_000e6,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_090_000e6,        // principal + accrued interest
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start + 1_000_000,
            domainEnd:             start + 2_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6);

        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [500e6,        95_129375]
        );

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        vm.warp(start + 2_000_000);

        makePayment(address(loan));

        assertTotalAssets(2_500_000e6 + 180_000e6);

        assertFixedTermLoan({
            loan:              address(loan),
            principal:         697_885_196375,
            incomingPrincipal: 332_326_283988,
            incomingInterest:  69_788_519637,
            incomingFees:      10_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 3_000_000,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                address(loan),
            incomingNetInterest: 62_809_667673,
            refinanceInterest:   0,
            issuanceRate:        0.062809667673e6 * 1e30,
            startDate:           start + 2_000_000,
            paymentDueDate:      start + 3_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:           address(loanManager),
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          697_885_196375,
            assetsUnderManagement: 697_885_196375,           // principal + accrued interest
            issuanceRate:          0.062809667673e6 * 1e30,
            domainStart:           start + 2_000_000,
            domainEnd:             start + 3_000_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6 + 180_000e6 + 302_114_803625);

        // Pool Delegate fee: 1st period (300e6 flat + 2_000e6)   + 2nd period (300e6 flat + 2_000e6)
        // Treasury fee:      1st period (10_00e6 flat + 8_000e6) + (10_00e6 flat + 8_000e6)
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [4_600e6,      36_000e6]
        );
    }

    function test_refinance_onLateLoan_changePaymentInterval() external {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertTotalAssets(2_500_000e6);

        assertFixedTermLoanManager({
            loanManager:           address(loanManager),
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
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [500e6,        95_129375]
        );

        /********************************/
        /*** Pre Refinance Assertions ***/
        /********************************/

        vm.warp(start + 1_500_000);

        assertTotalAssets(2_500_000e6 + 90_000e6);

        assertFixedTermLoan({
            loan:              address(loan),
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  151_840e6,          // Late interest: 6 days: 86400 * 6 * 0.1e6 = 51_840e6
            incomingFees:      10_000e6 + 300e6,   // 10_000e6 of platform service fees + 300e6 of delegate service fees
            refinanceInterest: 0,
            paymentDueDate:    start + 1_000_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                address(loan),
            incomingNetInterest: 90_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start,
            paymentDueDate:      start + 1_000_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:           address(loanManager),
            accruedInterest:       90_000e6,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_090_000e6,        // principal + accrued interest
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

        proposeRefinance(address(loan), address(refinancer), block.timestamp + 1, data);

        returnFunds(address(loan), 10_000e6);  // Return funds to pay origination fees. TODO: determine exact amount.

        acceptRefinance(address(loan), address(refinancer), block.timestamp + 1, data, 0);

        // Principal + interest owed at refinance time (151_840e6 * 0.9 to discount service fees)
        assertTotalAssets(2_500_000e6 + 136_656e6);

        assertFixedTermLoan({
            loan:              address(loan),
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            // first period (100_000e6) + late fees for first period (151_840e6)  + refinanced period incoming (200_000e6)
            incomingInterest:  351_840e6,
            incomingFees:      15_000e6 + 450e6 + 20_000e6 + 300e6,  // 10_000e6 of platform service fees + 300e6 of delegate service fees.
            // first period (100_000e6) + late fees for first period (151_840e6) + second period before refinance (50_000e6)
            refinanceInterest: 151_840e6,
            paymentDueDate:    start + 3_500_000,
            paymentsRemaining: 3
        });

        assertFixedTermPaymentInfo({
            loan:                address(loan),
            incomingNetInterest: 180_000e6,
            refinanceInterest:   136_656e6,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start + 1_500_000,
            paymentDueDate:      start + 3_500_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:           address(loanManager),
            accruedInterest:       0,
            accountedInterest:     136_656e6,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_136_656e6,        // principal + accrued interest
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start + 1_500_000,
            domainEnd:             start + 3_500_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6);

        // During refinance, origination fees are paid again
        assertAssetBalancesIncrease(
            [poolDelegate, treasury],
            [500e6,        190_258751]
        );

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        vm.warp(start + 3_500_000);

        makePayment(address(loan));

        assertTotalAssets(2_500_000e6 + 136_656e6 + 180_000e6);

        assertFixedTermLoan({
            loan:              address(loan),
            principal:         1_000_000e6,
            incomingPrincipal: 0,
            incomingInterest:  200_000e6,
            incomingFees:      20_000e6 + 300e6,
            refinanceInterest: 0,
            paymentDueDate:    start + 5_500_000,
            paymentsRemaining: 2
        });

        assertFixedTermPaymentInfo({
            loan:                address(loan),
            incomingNetInterest: 180_000e6,
            refinanceInterest:   0,
            issuanceRate:        0.09e6 * 1e30,
            startDate:           start + 3_500_000,
            paymentDueDate:      start + 5_500_000,
            platformFeeRate:     0.08e6,
            delegateFeeRate:     0.02e6
        });

        assertFixedTermLoanManager({
            loanManager:           address(loanManager),
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,        // principal + accrued interest
            issuanceRate:          0.09e6 * 1e30,
            domainStart:           start + 3_500_000,
            domainEnd:             start + 5_500_000,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6 + 180_000e6 + 136_656e6);

        // Pool Delegate fee: 1st period (450e6    + 3_000e6)  + 2nd period after refinance (300e6 flat + 3_000e6)
        //                    + late interest from 1st period (51_840e6 * 0.02 = 1036_800000)
        // Treasury fee:      1st period (15_000e6 + 12_000e6) + 2nd period after refinance (20_00e6   + 12_000e6)
        //                    + late interest from 1st period (51_840e6 * 0.08 = 4147_200000)
        assertAssetBalancesIncrease(
            [poolDelegate,        treasury],
            [6_750e6 + 1_036.8e6, 59_000e6 + 4_147.2e6]
        );
    }

}

contract AcceptNewTermsFailureTests is TestBaseWithAssertions {

    address borrower;
    address lp;

    IFixedTermLoan        loan;
    IFixedTermLoanManager loanManager;

    function setUp() public override {
        super.setUp();

        borrower = address(new Address());
        lp       = address(new Address());

        depositLiquidity(lp, 2_500_000e6);

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,
            platformManagementFeeRate:  0.08e6
        });

        loanManager = IFixedTermLoanManager(poolManager.loanManagerList(0));

        loan = IFixedTermLoan(fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e18), 0, 0, 0],
            loanManager: address(loanManager)
        }));
    }

    function test_acceptNewTerms_failIfProtocolIsPaused() external {
        vm.prank(globals.securityAdmin());
        globals.setProtocolPause(true);

        vm.prank(poolDelegate);
        vm.expectRevert("LM:PAUSED");
        loanManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, new bytes[](0), 0);
    }

    function testFail_acceptNewTerms_failIfNotValidLoanManager() external {
        address fakeLoan = address(new Address());

        // NOTE: EVM reverts on factory call.
        vm.prank(poolDelegate);
        loanManager.acceptNewTerms(fakeLoan, address(refinancer), block.timestamp + 1, new bytes[](0), 0);
    }

    function test_acceptNewTerms_failIfInsufficientCover() external {
        vm.prank(governor);
        globals.setMinCoverAmount(address(poolManager), 1e6);

        fundsAsset.mint(address(poolManager.poolDelegateCover()), 1e6 - 1);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:RF:INSUFFICIENT_COVER");
        loanManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, new bytes[](0), 1);
    }

    function test_acceptNewTerms_failWithFailedTransfer() external {
        vm.prank(poolDelegate);
        vm.expectRevert("PM:RF:TRANSFER_FAIL");
        loanManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, new bytes[](0), 100_000_000e6);
    }

    function test_acceptNewTerms_failIfLockedLiquidity() external {
        // Lock the liquidity
        vm.prank(lp);
        pool.requestRedeem(1_500_000e6, lp);

        vm.warp(start + 2 weeks);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:RF:LOCKED_LIQUIDITY");
        loanManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, new bytes[](0), 1);
    }

    function test_acceptNewTerms_failIfNotPoolDelegate() external {
        vm.expectRevert("LM:ANT:NOT_PD");
        loanManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, new bytes[](0), 0);
    }

    function test_acceptNewTerms_failIfNotLender() external {
        vm.expectRevert("ML:ANT:NOT_LENDER");
        loan.acceptNewTerms(address(refinancer), block.timestamp + 1, new bytes[](0));
    }

    function test_acceptNewTerms_failIfRefinanceMismatch() external {
        vm.prank(poolDelegate);
        vm.expectRevert("ML:ANT:COMMITMENT_MISMATCH");
        loanManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, new bytes[](0), 0);
    }

    function test_acceptNewTerms_failWithInvalidRefinancer() external {
        address fakeRefinancer = address(2);

        vm.prank(governor);
        globals.setValidInstanceOf("FT_REFINANCER", fakeRefinancer, true);

        bytes[] memory data = encodeWithSignatureAndUint("setPaymentInterval(uint256)", 2_000_000);

        // Make commitment
        proposeRefinance(address(loan), fakeRefinancer, block.timestamp + 1, data);

        vm.prank(poolDelegate);
        vm.expectRevert("ML:ANT:INVALID_REFINANCER");
        loanManager.acceptNewTerms(address(loan), fakeRefinancer, block.timestamp + 1, data, 0);
    }

    function test_acceptNewTerms_failIfDeadlineExpired() external {
        bytes[] memory data = encodeWithSignatureAndUint("setPaymentInterval(uint256)", 2_000_000);

        uint256 deadline = block.timestamp + 1;

        // Make commitment
        proposeRefinance(address(loan), address(refinancer), deadline, data);

        vm.warp(deadline + 1);

        vm.prank(poolDelegate);
        vm.expectRevert("ML:ANT:EXPIRED_COMMITMENT");
        loanManager.acceptNewTerms(address(loan), address(refinancer), deadline, data, 0);
    }

    function test_acceptNewTerms_failIfRefinanceCallFails() external {
        address fakeRefinancer = address(new Address());

        vm.prank(governor);
        globals.setValidInstanceOf("FT_REFINANCER", fakeRefinancer, true);

        bytes[] memory data = encodeWithSignatureAndUint("setPaymentInterval(uint256)", 2_000_000);

        // Make commitment
        proposeRefinance(address(loan), fakeRefinancer, block.timestamp + 1, data);

        vm.prank(poolDelegate);
        vm.expectRevert("ML:ANT:FAILED");
        loanManager.acceptNewTerms(address(loan), fakeRefinancer, block.timestamp + 1, data, 0);
    }

    function test_acceptNewTerms_failWithInsufficientCollateral() external {
        bytes[] memory data = encodeWithSignatureAndUint("setCollateralRequired(uint256)", 1);

        // Make commitment
        proposeRefinance(address(loan), address(refinancer), block.timestamp + 1, data);

        // Mint fees to cover origination fees
        returnFunds(address(loan), 1_000e6);

        vm.prank(poolDelegate);
        vm.expectRevert("ML:ANT:INSUFFICIENT_COLLATERAL");
        loanManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, data, 1);
    }

    function test_acceptNewTerms_failWithUnexpectedFunds() external {
        bytes[] memory data = encodeWithSignatureAndUint("setPaymentInterval(uint256)", 2_000_000);

        // Make commitment
        proposeRefinance(address(loan), address(refinancer), block.timestamp + 1, data);

        // // Mint fees to cover origination fee
        returnFunds(address(loan), 1_000e6);

        vm.prank(poolDelegate);
        vm.expectRevert("ML:ANT:UNEXPECTED_FUNDS");
        loanManager.acceptNewTerms(address(loan), address(refinancer), block.timestamp + 1, data, 1);
    }

}
