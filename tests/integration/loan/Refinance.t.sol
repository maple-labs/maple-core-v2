// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IFixedTermLoan, IFixedTermLoanManager, IOpenTermLoan, IOpenTermLoanManager } from "../../../contracts/interfaces/Interfaces.sol";

import { EmptyContract } from "../../../contracts/Runner.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract RefinanceTestsSingleLoan is TestBaseWithAssertions {

    address borrower;
    address lp;

    IFixedTermLoan        loan;
    IFixedTermLoanManager loanManager;

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

        loanManager = IFixedTermLoanManager(poolManager.strategyList(0));

        loan = IFixedTermLoan(fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(12 hours), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e6), 0, 0, 0],  // 0.1e6 tokens per second
            loanManager: address(loanManager)
        }));

    }

    function test_refinance_onLoanPaymentDueDate_changePaymentInterval() external {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertEq(poolManager.totalAssets(), 2_500_000e6);

        assertFixedTermLoanManager({
            loanManager:       address(loanManager),
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
            address(fundsAsset),
            [poolDelegate, treasury],
            [500e6,        95_129375]
        );

        /********************************/
        /*** Pre Refinance Assertions ***/
        /********************************/

        vm.warp(start + 1_000_000);

        assertEq(poolManager.totalAssets(), 2_500_000e6 + 90_000e6);

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
            loanManager:       address(loanManager),
            accruedInterest:   90_000e6,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.09e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6);

        /****************************/
        /*** Refinance Assertions ***/
        /****************************/

        bytes[] memory data = encodeWithSignatureAndUint("setPaymentInterval(uint256)", 2_000_000);

        proposeRefinance(address(loan), address(fixedTermRefinancer), block.timestamp + 1, data);

        returnFunds(address(loan), 10_000e6);  // Return funds to pay origination fees.

        acceptRefinance(address(loan), address(fixedTermRefinancer), block.timestamp + 1, data, 0);

        assertEq(poolManager.totalAssets(), 2_500_000e6 + 90_000e6);

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
            loanManager:       address(loanManager),
            accruedInterest:   0,
            accountedInterest: 90_000e6,
            principalOut:      1_000_000e6,
            issuanceRate:      0.09e6 * 1e30,
            domainStart:       start + 1_000_000,
            domainEnd:         start + 3_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6);

        // During refinance, origination fees are paid again
        assertAssetBalancesIncrease(
            address(fundsAsset),
            [poolDelegate, treasury],
            [500e6,        190_258751]
        );

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        vm.warp(start + 3_000_000);

        makePayment(address(loan));

        assertEq(poolManager.totalAssets(), 2_500_000e6 + 270_000e6);

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
            loanManager:       address(loanManager),
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.09e6 * 1e30,
            domainStart:       start + 3_000_000,
            domainEnd:         start + 5_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6 + 270_000e6);

        // Pool Delegate fee: 1st period (300e6 flat + 2_000e6)   + 2nd period (300e6 flat + 4_000e6)
        // Treasury fee:      1st period (10_00e6 flat + 8_000e6) + 2nd period (20_00e6 flat + 16_000e6)
        assertAssetBalancesIncrease(
            address(fundsAsset),
            [poolDelegate, treasury],
            [6_600e6,      54_000e6]
        );
    }

    function test_refinance_onLoanPaymentDueDate_increasePrincipal() external {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertEq(poolManager.totalAssets(), 2_500_000e6);

        assertFixedTermLoanManager({
            loanManager:       address(loanManager),
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
            address(fundsAsset),
            [poolDelegate, treasury],
            [500e6,        95_129375]
        );

        /********************************/
        /*** Pre Refinance Assertions ***/
        /********************************/

        vm.warp(start + 1_000_000);

        assertEq(poolManager.totalAssets(), 2_500_000e6 + 90_000e6);

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
            loanManager:       address(loanManager),
            accruedInterest:   90_000e6,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.09e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6);

        /****************************/
        /*** Refinance Assertions ***/
        /****************************/

        bytes[] memory calls = new bytes[](2);
        calls[0] = abi.encodeWithSignature("increasePrincipal(uint256)",  1_000_000e6);
        calls[1] = abi.encodeWithSignature("setEndingPrincipal(uint256)", 2_000_000e6);

        proposeRefinance(address(loan), address(fixedTermRefinancer), block.timestamp + 1, calls);

        acceptRefinance(address(loan), address(fixedTermRefinancer), block.timestamp + 1, calls, 1_000_000e6);

        assertEq(poolManager.totalAssets(), 2_500_000e6 + 90_000e6);

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
            loanManager:       address(loanManager),
            accruedInterest:   0,
            accountedInterest: 90_000e6,
            principalOut:      2_000_000e6,
            issuanceRate:      0.18e6 * 1e30,
            domainStart:       start + 1_000_000,
            domainEnd:         start + 2_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        // During refinance, origination fees are paid again
        assertAssetBalancesIncrease(
            address(fundsAsset),
            [poolDelegate, treasury],
            [500e6,        190_258751]
        );

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        vm.warp(start + 2_000_000);

        makePayment(address(loan));

        assertEq(poolManager.totalAssets(), 2_500_000e6 + 270_000e6);

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
            loanManager:       address(loanManager),
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      2_000_000e6,
            issuanceRate:      0.18e6 * 1e30,
            domainStart:       start + 2_000_000,
            domainEnd:         start + 3_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 270_000e6);  // Interest + refinance interest

        // Pool Delegate fee: 1st period (300e6 flat + 2_000e6)   + 2nd period (300e6 flat + 4_000e6)
        // Treasury fee:      1st period (10_00e6 flat + 8_000e6) + 2nd period (20_00e6 flat + 16_000e6)
        assertAssetBalancesIncrease(
            address(fundsAsset),
            [poolDelegate, treasury],
            [6_600e6,      54_000e6]
        );
    }

    function test_refinance_onLoanPaymentDueDate_changeInterestRate() external {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertEq(poolManager.totalAssets(), 2_500_000e6);

        assertFixedTermLoanManager({
            loanManager:       address(loanManager),
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
            address(fundsAsset),
            [poolDelegate, treasury],
            [500e6,        95_129375]
        );

        /********************************/
        /*** Pre Refinance Assertions ***/
        /********************************/

        vm.warp(start + 1_000_000);

        assertEq(poolManager.totalAssets(), 2_500_000e6 + 90_000e6);

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
            loanManager:       address(loanManager),
            accruedInterest:   90_000e6,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.09e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6);

        /****************************/
        /*** Refinance Assertions ***/
        /****************************/

        bytes[] memory data = encodeWithSignatureAndUint("setInterestRate(uint256)", 6.3072e6);  // 2x

        proposeRefinance(address(loan), address(fixedTermRefinancer), block.timestamp + 1, data);

        returnFunds(address(loan), 10_000e6);  // Return funds to pay origination fees.

        acceptRefinance(address(loan), address(fixedTermRefinancer), block.timestamp + 1, data, 0);

        assertEq(poolManager.totalAssets(), 2_500_000e6 + 90_000e6);

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
            loanManager:       address(loanManager),
            accruedInterest:   0,
            accountedInterest: 90_000e6,
            principalOut:      1_000_000e6,
            issuanceRate:      0.18e6 * 1e30,
            domainStart:       start + 1_000_000,
            domainEnd:         start + 2_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6);

        assertAssetBalancesIncrease(
            address(fundsAsset),
            [poolDelegate, treasury],
            [500e6,        95_129375]
        );

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        vm.warp(start + 2_000_000);

        makePayment(address(loan));

        assertEq(poolManager.totalAssets(), 2_500_000e6 + 270_000e6);

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
            loanManager:       address(loanManager),
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.18e6 * 1e30,
            domainStart:       start + 2_000_000,
            domainEnd:         start + 3_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6 + 270_000e6);

        // Pool Delegate fee: 1st period (300e6 flat + 2_000e6)   + 2nd period (300e6 flat + 4_000e6)
        // Treasury fee:      1st period (10_00e6 flat + 8_000e6) + 2nd period (10_00e6 flat + 16_000e6)
        assertAssetBalancesIncrease(
            address(fundsAsset),
            [poolDelegate, treasury],
            [6_600e6,      44_000e6]
        );
    }

    function test_refinance_onLoanPaymentDueDate_changeToAmortized() external {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertEq(poolManager.totalAssets(), 2_500_000e6);

        assertFixedTermLoanManager({
            loanManager:       address(loanManager),
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
            address(fundsAsset),
            [poolDelegate, treasury],
            [500e6,        95_129375]
        );

        /********************************/
        /*** Pre Refinance Assertions ***/
        /********************************/

        vm.warp(start + 1_000_000);

        assertEq(poolManager.totalAssets(), 2_500_000e6 + 90_000e6);

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
            loanManager:       address(loanManager),
            accruedInterest:   90_000e6,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.09e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6);

        /****************************/
        /*** Refinance Assertions ***/
        /****************************/

        bytes[] memory data = encodeWithSignatureAndUint("setEndingPrincipal(uint256)", 0);

        proposeRefinance(address(loan), address(fixedTermRefinancer), block.timestamp + 1, data);

        returnFunds(address(loan), 10_000e6);  // Return funds to pay origination fees.

        acceptRefinance(address(loan), address(fixedTermRefinancer), block.timestamp + 1, data, 0);

        assertEq(poolManager.totalAssets(), 2_500_000e6 + 90_000e6);

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
            loanManager:       address(loanManager),
            accruedInterest:   0,
            accountedInterest: 90_000e6,
            principalOut:      1_000_000e6,
            issuanceRate:      0.09e6 * 1e30,
            domainStart:       start + 1_000_000,
            domainEnd:         start + 2_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6);

        assertAssetBalancesIncrease(
            address(fundsAsset),
            [poolDelegate, treasury],
            [500e6,        95_129375]
        );

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        vm.warp(start + 2_000_000);

        makePayment(address(loan));

        assertEq(poolManager.totalAssets(), 2_500_000e6 + 180_000e6);

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
            loanManager:       address(loanManager),
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      697_885_196375,
            issuanceRate:      0.062809667673e6 * 1e30,
            domainStart:       start + 2_000_000,
            domainEnd:         start + 3_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6 + 180_000e6 + 302_114_803625);

        // Pool Delegate fee: 1st period (300e6 flat + 2_000e6)   + 2nd period (300e6 flat + 2_000e6)
        // Treasury fee:      1st period (10_00e6 flat + 8_000e6) + (10_00e6 flat + 8_000e6)
        assertAssetBalancesIncrease(
            address(fundsAsset),
            [poolDelegate, treasury],
            [4_600e6,      36_000e6]
        );
    }

    function test_refinance_onLateLoan_changePaymentInterval() external {
        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertEq(poolManager.totalAssets(), 2_500_000e6);

        assertFixedTermLoanManager({
            loanManager:       address(loanManager),
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
            address(fundsAsset),
            [poolDelegate, treasury],
            [500e6,        95_129375]
        );

        /********************************/
        /*** Pre Refinance Assertions ***/
        /********************************/

        vm.warp(start + 1_500_000);

        assertEq(poolManager.totalAssets(), 2_500_000e6 + 90_000e6);

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
            loanManager:       address(loanManager),
            accruedInterest:   90_000e6,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.09e6 * 1e30,
            domainStart:       start,
            domainEnd:         start + 1_000_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6);

        /****************************/
        /*** Refinance Assertions ***/
        /****************************/

        bytes[] memory data = encodeWithSignatureAndUint("setPaymentInterval(uint256)", 2_000_000);

        proposeRefinance(address(loan), address(fixedTermRefinancer), block.timestamp + 1, data);

        returnFunds(address(loan), 10_000e6);  // Return funds to pay origination fees.

        acceptRefinance(address(loan), address(fixedTermRefinancer), block.timestamp + 1, data, 0);

        // Principal + interest owed at refinance time (151_840e6 * 0.9 to discount service fees)
        assertEq(poolManager.totalAssets(), 2_500_000e6 + 136_656e6);

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
            loanManager:       address(loanManager),
            accruedInterest:   0,
            accountedInterest: 136_656e6,
            principalOut:      1_000_000e6,
            issuanceRate:      0.09e6 * 1e30,
            domainStart:       start + 1_500_000,
            domainEnd:         start + 3_500_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6);

        // During refinance, origination fees are paid again
        assertAssetBalancesIncrease(
            address(fundsAsset),
            [poolDelegate, treasury],
            [500e6,        190_258751]
        );

        /*******************************/
        /*** Post Payment Assertions ***/
        /*******************************/

        vm.warp(start + 3_500_000);

        makePayment(address(loan));

        assertEq(poolManager.totalAssets(), 2_500_000e6 + 136_656e6 + 180_000e6);

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
            loanManager:       address(loanManager),
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.09e6 * 1e30,
            domainStart:       start + 3_500_000,
            domainEnd:         start + 5_500_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 1_500_000e6 + 180_000e6 + 136_656e6);

        // Pool Delegate fee: 1st period (450e6    + 3_000e6)  + 2nd period after refinance (300e6 flat + 3_000e6)
        //                    + late interest from 1st period (51_840e6 * 0.02 = 1036_800000)
        // Treasury fee:      1st period (15_000e6 + 12_000e6) + 2nd period after refinance (20_00e6   + 12_000e6)
        //                    + late interest from 1st period (51_840e6 * 0.08 = 4147_200000)
        assertAssetBalancesIncrease(
            address(fundsAsset),
            [poolDelegate,        treasury],
            [6_750e6 + 1_036.8e6, 59_000e6 + 4_147.2e6]
        );
    }

}

contract RefinanceOpenTermLoan is TestBaseWithAssertions {

    address borrower = makeAddr("borrower");
    address lp       = makeAddr("lp");

    uint32 gracePeriod     = 200_000;
    uint32 noticePeriod    = 100_000;
    uint32 paymentInterval = 1_000_000;

    uint64 interestRate = 0.31536e6;

    uint256 principal = 1_000_000e6;

    // Pool Manager state assertions
    uint256 expectedCash;
    uint256 expectedTotalAssets;
    uint256 expectedTotalSupply;

    IOpenTermLoan        loan;
    IOpenTermLoanManager loanManager;

    function setUp() public override {
        super.setUp();

        deposit(lp, 3_500_000e6);

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.031536e6,  // 10k after 1m seconds
            platformManagementFeeRate:  0.08e6
        });

        loanManager = IOpenTermLoanManager(poolManager.strategyList(1));

        loan = IOpenTermLoan(createOpenTermLoan(
            address(borrower),
            address(loanManager),
            address(fundsAsset),
            principal,
            [gracePeriod, noticePeriod, paymentInterval],
            [0.015768e6, interestRate, 0.01e6, 0.015768e6]
        ));

        fundLoan(address(loan));

        expectedCash        = 2_500_000e6;
        expectedTotalAssets = 3_500_000e6;
        expectedTotalSupply = 3_500_000e6;

        /**************************/
        /*** Initial Assertions ***/
        /**************************/

        assertPoolState({
            pool:               address(pool),
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: 0,
            accruedInterest:   0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.009e6 * 1e27,
            domainStart:       start,
            unrealizedLosses:  0
        });
    }

    function test_refinance_early_increasePrincipal() external {
        /********************************/
        /*** Pre Refinance Assertions ***/
        /********************************/

        vm.warp(start + 400_000);

        expectedTotalAssets += 3_600e6;

        assertPoolState({
            pool:               address(pool),
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanPaymentState({
            loan:               address(loan),
            paymentTimestamp:   uint40(block.timestamp),
            principal:          0,
            interest:           4000e6,
            lateInterest:       0,
            delegateServiceFee: 200e6,
            platformServiceFee: 400e6,
            paymentDueDate:     start + 1_000_000,
            defaultDate:        start + 1_200_000
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            issuanceRate:    0.009e6 * 1e27,
            startDate:       start,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.02e6
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: 0,
            accruedInterest:   3_600e6,
            principalOut:      1_000_000e6,
            issuanceRate:      0.009e6 * 1e27,
            domainStart:       start,
            unrealizedLosses:  0
        });

        // Borrower must send enough to cover the principal + interest + fees
        fundsAsset.mint(address(borrower), 4_000e6 + 400e6 + 200e6);

        vm.prank(borrower);
        fundsAsset.approve(address(loan), 4_000e6 + 400e6 + 200e6);

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("increasePrincipal(uint256)",  2_000_000e6);

        proposeRefinanceOT(address(loan), address(openTermRefinancer), block.timestamp + 1, calls);

        acceptRefinanceOT(address(loan), address(openTermRefinancer), block.timestamp + 1, calls);

        /*********************************/
        /*** Post Refinance Assertions ***/
        /*********************************/

        expectedCash = expectedCash - 2_000_000e6 + 3_600e6;

        assertPoolState({
            pool:               address(pool),
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanPaymentState({
            loan:               address(loan),
            paymentTimestamp:   uint40(start + 1_400_000),
            principal:          0,
            interest:           30_000e6,  // 30k per 1m seconds
            lateInterest:       0,
            delegateServiceFee: 1_500e6,
            platformServiceFee: 3_000e6,
            paymentDueDate:     start + 1_400_000,
            defaultDate:        start + 1_600_000
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            issuanceRate:    0.027e6 * 1e27,
            startDate:       start + 400_000,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.02e6
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: 0,
            accruedInterest:   0,
            principalOut:      3_000_000e6,
            issuanceRate:      0.027e6 * 1e27,
            domainStart:       start + 400_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(borrower)), 3_000_000e6);

        // PD:       service fees (400e6)  + management fees (4000 * 0.02)
        // Treasury: service fees (4000e6) + management fees (4000 * 0.08)
        assertAssetBalancesIncrease(
            address(fundsAsset),
            [address(poolDelegate),          address(treasury)],
            [uint256(200e6) + uint256(80e6), uint256(400e6) + uint256(320e6)]
        );
    }

    function test_refinance_late_decreasePrincipal() external {
        /********************************/
        /*** Pre Refinance Assertions ***/
        /********************************/

        vm.warp(start + 1_400_000);

        expectedTotalAssets += 12_600e6;

        assertPoolState({
            pool:               address(pool),
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanPaymentState({
            loan:               address(loan),
            paymentTimestamp:   uint40(block.timestamp),
            principal:          0,
            interest:           14_000e6,
            lateInterest:       200e6 + 10_000e6, // Flat late fee + 1k per 1m seconds
            delegateServiceFee: 700e6,
            platformServiceFee: 1_400e6,
            paymentDueDate:     start + 1_000_000,
            defaultDate:        start + 1_200_000
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            issuanceRate:    0.009e6 * 1e27,
            startDate:       start,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.02e6
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: 0,
            accruedInterest:   12_600e6,
            principalOut:      1_000_000e6,
            issuanceRate:      0.009e6 * 1e27,
            domainStart:       start,
            unrealizedLosses:  0
        });

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("decreasePrincipal(uint256)",  500_000e6);

        // Borrower must send enough to cover the principal + interest + fees
        fundsAsset.mint(address(borrower), 26_300e6); // 41_400e6 = interest (14_000e6) + late interest (10_200e6) + serviceFees (2_100e6)

        vm.prank(borrower);
        fundsAsset.approve(address(loan), 500_000e6 + 26_300e6);

        proposeRefinanceOT(address(loan), address(openTermRefinancer), block.timestamp + 1, calls);

        acceptRefinanceOT(address(loan), address(openTermRefinancer), block.timestamp + 1, calls);

        /*********************************/
        /*** Post Refinance Assertions ***/
        /*********************************/

        expectedTotalAssets += 9_180e6;  // 10_200e6 of late interest net of management fees
        expectedCash        += 500_000e6 + 12_600e6 + 9_180e6;

        assertPoolState({
            pool:               address(pool),
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanPaymentState({
            loan:               address(loan),
            paymentTimestamp:   uint40(start + 2_400_000),
            principal:          0,
            interest:           5_000e6,
            lateInterest:       0,
            delegateServiceFee: 250e6,
            platformServiceFee: 500e6,
            paymentDueDate:     start + 2_400_000,
            defaultDate:        start + 2_600_000
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            issuanceRate:    0.0045e6 * 1e27,
            startDate:       start + 1_400_000,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.02e6
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: 0,
            accruedInterest:   0,
            principalOut:      500_000e6,
            issuanceRate:      0.0045e6 * 1e27,
            domainStart:       start + 1_400_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(borrower)), 500_000e6);

        // PD:       service fees (1_400e6)  + management fees (26_000 * 0.02)
        // Treasury: service fees (14_000e6) + management fees (26_000 * 0.08)
        assertAssetBalancesIncrease(
            address(fundsAsset),
            [address(poolDelegate),           address(treasury)],
            [uint256(700e6) + uint256(484e6), uint256(1_400e6) + uint256(1_936e6)]
        );
    }

    function test_refinance_calledLoan_withoutPrincipalChange() external {
        /**********************************/
        /*** Call Loan early and assert ***/
        /**********************************/

        vm.warp(start + 400_000);

        callLoan(address(loan), 1_000_000e6);

        /********************************/
        /*** Pre Refinance Assertions ***/
        /********************************/

        vm.warp(start + 500_000);

        expectedTotalAssets += 4_500e6;

        assertPoolState({
            pool:               address(pool),
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanPaymentState({
            loan:               address(loan),
            paymentTimestamp:   uint40(block.timestamp),
            principal:          1_000_000e6,
            interest:           5_000e6,
            lateInterest:       0,
            delegateServiceFee: 250e6,
            platformServiceFee: 500e6,
            paymentDueDate:     start + 500_000,
            defaultDate:        start + 500_000  // No grace period on called loan.
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            issuanceRate:    0.009e6 * 1e27,
            startDate:       start,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.02e6
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: 0,
            accruedInterest:   4_500e6,
            principalOut:      1_000_000e6,
            issuanceRate:      0.009e6 * 1e27,
            domainStart:       start,
            unrealizedLosses:  0
        });

        // Borrower must send enough to cover the interest + fees
        fundsAsset.mint(address(borrower), 5_000e6 + 750e6);

        vm.prank(borrower);
        fundsAsset.approve(address(loan), 5_000e6 + 750e6);

        // Perform multiple actions, but none changes principal
        bytes[] memory calls = new bytes[](5);
        calls[0] = abi.encodeWithSignature("setGracePeriod(uint32)",             500_000);
        calls[1] = abi.encodeWithSignature("setInterestRate(uint64)",            0.63072e6);
        calls[2] = abi.encodeWithSignature("setLateInterestPremiumRate(uint64)", 0.031536e6);
        calls[3] = abi.encodeWithSignature("setNoticePeriod(uint32)",            50_000);
        calls[4] = abi.encodeWithSignature("setPaymentInterval(uint32)",         500_000);

        assertEq(loan.gracePeriod(),             200_000);
        assertEq(loan.interestRate(),            0.31536e6);
        assertEq(loan.lateInterestPremiumRate(), 0.015768e6);
        assertEq(loan.noticePeriod(),            100_000);
        assertEq(loan.paymentInterval(),         1_000_000);
        assertEq(loan.dateCalled(),              start + 400_000);

        proposeRefinanceOT(address(loan), address(openTermRefinancer), block.timestamp + 1, calls);

        acceptRefinanceOT(address(loan), address(openTermRefinancer), block.timestamp + 1, calls);

        /*********************************/
        /*** Post Refinance Assertions ***/
        /*********************************/

        assertEq(loan.gracePeriod(),             500_000);
        assertEq(loan.interestRate(),            0.63072e6);
        assertEq(loan.lateInterestPremiumRate(), 0.031536e6);
        assertEq(loan.noticePeriod(),            50_000);
        assertEq(loan.paymentInterval(),         500_000);
        assertEq(loan.dateCalled(),              0);           // Resets regardless of principal change.

        expectedCash += 4_500e6;

        assertPoolState({
            pool:               address(pool),
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanPaymentState({
            loan:               address(loan),
            paymentTimestamp:   uint40(start + 1_000_000),
            principal:          0,
            interest:           10_000e6,  // 20k interest in 1m seconds
            lateInterest:       0,
            delegateServiceFee: 250e6,
            platformServiceFee: 500e6,
            paymentDueDate:     start + 1_000_000,
            defaultDate:        start + 1_500_000
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            issuanceRate:    0.018e6 * 1e27,
            startDate:       start + 500_000,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.02e6
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: 0,
            accruedInterest:   0,
            principalOut:      1_000_000e6,
            issuanceRate:      0.018e6 * 1e27,
            domainStart:       start + 500_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(borrower)), 1_000_000e6);

        // PD:       service fees (400e6)  + management fees (5000 * 0.02)
        // Treasury: service fees (4000e6) + management fees (5000 * 0.08)
        assertAssetBalancesIncrease(
            address(fundsAsset),
            [address(poolDelegate),          address(treasury)],
            [uint256(250e6) + uint256(100e6), uint256(500e6) + uint256(400e6)]
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

        loanManager = IFixedTermLoanManager(poolManager.strategyList(0));

        loan = IFixedTermLoan(fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(12 hours), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e6), 0, 0, 0],
            loanManager: address(loanManager)
        }));
    }

    function test_acceptNewTerms_failIfProtocolIsPaused() external {
        vm.prank(globals.securityAdmin());
        globals.setProtocolPause(true);

        vm.prank(poolDelegate);
        vm.expectRevert("LM:PAUSED");
        loanManager.acceptNewTerms(address(loan), address(fixedTermRefinancer), block.timestamp + 1, new bytes[](0), 0);
    }

    function test_acceptNewTerms_failIfNotValidLoanManager() external {
        address fakeLoan = makeAddr("fakeLoan");

        vm.expectRevert();
        // NOTE: EVM reverts on factory call.
        vm.prank(poolDelegate);
        loanManager.acceptNewTerms(fakeLoan, address(fixedTermRefinancer), block.timestamp + 1, new bytes[](0), 0);
    }

    function test_acceptNewTerms_failIfInsufficientCover() external {
        vm.prank(governor);
        globals.setMinCoverAmount(address(poolManager), 1e6);

        fundsAsset.mint(address(poolManager.poolDelegateCover()), 1e6 - 1);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:RF:INSUFFICIENT_COVER");
        loanManager.acceptNewTerms(address(loan), address(fixedTermRefinancer), block.timestamp + 1, new bytes[](0), 1);
    }

    function test_acceptNewTerms_failWithFailedTransfer() external {
        vm.prank(poolDelegate);
        vm.expectRevert("PM:RF:TRANSFER_FAIL");
        loanManager.acceptNewTerms(address(loan), address(fixedTermRefinancer), block.timestamp + 1, new bytes[](0), 100_000_000e6);
    }

    function test_acceptNewTerms_failIfLockedLiquidity() external {
        // Lock the liquidity
        vm.prank(lp);
        pool.requestRedeem(1_500_000e6, lp);

        vm.warp(start + 2 weeks);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:RF:LOCKED_LIQUIDITY");
        loanManager.acceptNewTerms(address(loan), address(fixedTermRefinancer), block.timestamp + 1, new bytes[](0), 1);
    }

    function test_acceptNewTerms_failIfNotPoolDelegate() external {
        vm.expectRevert("LM:NOT_PD");
        loanManager.acceptNewTerms(address(loan), address(fixedTermRefinancer), block.timestamp + 1, new bytes[](0), 0);
    }

    function test_acceptNewTerms_failIfNotLender() external {
        vm.expectRevert("ML:NOT_LENDER");
        loan.acceptNewTerms(address(fixedTermRefinancer), block.timestamp + 1, new bytes[](0));
    }

    function test_acceptNewTerms_failIfRefinanceMismatch() external {
        vm.prank(poolDelegate);
        vm.expectRevert("ML:ANT:COMMITMENT_MISMATCH");
        loanManager.acceptNewTerms(address(loan), address(fixedTermRefinancer), block.timestamp + 1, new bytes[](0), 0);
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
        proposeRefinance(address(loan), address(fixedTermRefinancer), deadline, data);

        vm.warp(deadline + 1);

        vm.prank(poolDelegate);
        vm.expectRevert("ML:ANT:EXPIRED_COMMITMENT");
        loanManager.acceptNewTerms(address(loan), address(fixedTermRefinancer), deadline, data, 0);
    }

    function test_acceptNewTerms_failIfRefinanceCallFails() external {
        address fakeRefinancer = address(new EmptyContract());

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
        proposeRefinance(address(loan), address(fixedTermRefinancer), block.timestamp + 1, data);

        // Mint fees to cover origination fees
        returnFunds(address(loan), 1_000e6);

        vm.prank(poolDelegate);
        vm.expectRevert("ML:ANT:INSUFFICIENT_COLLATERAL");
        loanManager.acceptNewTerms(address(loan), address(fixedTermRefinancer), block.timestamp + 1, data, 1);
    }

    function test_acceptNewTerms_failWithUnexpectedFunds() external {
        bytes[] memory data = encodeWithSignatureAndUint("setPaymentInterval(uint256)", 2_000_000);

        // Make commitment
        proposeRefinance(address(loan), address(fixedTermRefinancer), block.timestamp + 1, data);

        // Mint fees to cover origination fee
        returnFunds(address(loan), 1_000e6);

        vm.prank(poolDelegate);
        vm.expectRevert("ML:ANT:UNEXPECTED_FUNDS");
        loanManager.acceptNewTerms(address(loan), address(fixedTermRefinancer), block.timestamp + 1, data, 1);
    }

}
