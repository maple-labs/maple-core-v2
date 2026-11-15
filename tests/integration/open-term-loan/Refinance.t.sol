// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console } from "../../../modules/forge-std/src/Test.sol";

import { IOpenTermLoan, IOpenTermLoanManager } from "../../../contracts/interfaces/Interfaces.sol";

import { EmptyContract } from "../../../contracts/Runner.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

// TODO: Add test for impairment and refi
// TODO: Add tests with wraps for principal increase covering fees
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

    IOpenTermLoan loan;
    IOpenTermLoanManager loanManager;

    function setUp() public override {
        super.setUp();

        deposit(lp, 3_500_000e6);

        setupFees({
            delegateOriginationFee: 500e6,
            delegateServiceFee: 300e6,
            delegateManagementFeeRate: 0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate: 0.031536e6, // 10k after 1m seconds
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
                [0.015768e6, interestRate, 0.01e6, 0.015768e6]
            )
        );

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

        // Borrower must send enough to cover the interest + fees
        fundsAsset.mint(address(borrower), 4_000e6 + 400e6 + 200e6);

        vm.prank(borrower);
        fundsAsset.approve(address(loan), 4_000e6 + 400e6 + 200e6);

        bytes[] memory calls = new bytes[](1);
        calls[0]             = abi.encodeWithSignature("increasePrincipal(uint256)", 2_000_000e6);

        proposeRefinanceOT(address(loan), openTermRefinancer, block.timestamp + 1, calls);

        acceptRefinanceOT(address(loan), openTermRefinancer, block.timestamp + 1, calls);

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
            loan: address(loan),
            paymentTimestamp: uint40(start + 1_400_000),
            principal: 0,
            interest: 30_000e6, // 30k per 1m seconds
            lateInterest: 0,
            delegateServiceFee: 1_500e6,
            platformServiceFee: 3_000e6,
            paymentDueDate: start + 1_400_000,
            defaultDate: start + 1_600_000
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
            [address(poolDelegate), address(treasury)],
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
            loan: address(loan),
            paymentTimestamp: uint40(block.timestamp),
            principal: 0,
            interest: 14_000e6,
            lateInterest: 200e6 + 10_000e6, // Flat late fee + 1k per 1m seconds
            delegateServiceFee: 700e6,
            platformServiceFee: 1_400e6,
            paymentDueDate: start + 1_000_000,
            defaultDate: start + 1_200_000
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
        calls[0]             = abi.encodeWithSignature("decreasePrincipal(uint256)", 500_000e6);

        // Borrower must send enough to cover the principal + interest + fees
        fundsAsset.mint(address(borrower), 26_300e6); // 41_400e6 = interest (14_000e6) + late interest (10_200e6) + serviceFees (2_100e6)

        vm.prank(borrower);
        fundsAsset.approve(address(loan), 500_000e6 + 26_300e6);

        proposeRefinanceOT(address(loan), openTermRefinancer, block.timestamp + 1, calls);

        acceptRefinanceOT(address(loan), openTermRefinancer, block.timestamp + 1, calls);

        /*********************************/
        /*** Post Refinance Assertions ***/
        /*********************************/

        expectedTotalAssets += 9_180e6; // 10_200e6 of late interest net of management fees
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
            [address(poolDelegate), address(treasury)],
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
            loan: address(loan),
            paymentTimestamp: uint40(block.timestamp),
            principal: 1_000_000e6,
            interest: 5_000e6,
            lateInterest: 0,
            delegateServiceFee: 250e6,
            platformServiceFee: 500e6,
            paymentDueDate: start + 500_000,
            defaultDate: start + 500_000 // No grace period on called loan.
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
        calls[0]             = abi.encodeWithSignature("setGracePeriod(uint32)", 500_000);
        calls[1]             = abi.encodeWithSignature("setInterestRate(uint64)", 0.63072e6);
        calls[2]             = abi.encodeWithSignature("setLateInterestPremiumRate(uint64)", 0.031536e6);
        calls[3]             = abi.encodeWithSignature("setNoticePeriod(uint32)", 50_000);
        calls[4]             = abi.encodeWithSignature("setPaymentInterval(uint32)", 500_000);

        assertEq(loan.gracePeriod(),             200_000);
        assertEq(loan.interestRate(),            0.31536e6);
        assertEq(loan.lateInterestPremiumRate(), 0.015768e6);
        assertEq(loan.noticePeriod(),            100_000);
        assertEq(loan.paymentInterval(),         1_000_000);
        assertEq(loan.dateCalled(),              start + 400_000);

        proposeRefinanceOT(address(loan), openTermRefinancer, block.timestamp + 1, calls);

        acceptRefinanceOT(address(loan), openTermRefinancer, block.timestamp + 1, calls);

        /*********************************/
        /*** Post Refinance Assertions ***/
        /*********************************/

        assertEq(loan.gracePeriod(),             500_000);
        assertEq(loan.interestRate(),            0.63072e6);
        assertEq(loan.lateInterestPremiumRate(), 0.031536e6);
        assertEq(loan.noticePeriod(),            50_000);
        assertEq(loan.paymentInterval(),         500_000);
        assertEq(loan.dateCalled(),              0); // Resets regardless of principal change.

        expectedCash += 4_500e6;

        assertPoolState({
            pool:               address(pool),
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanPaymentState({
            loan: address(loan),
            paymentTimestamp: uint40(start + 1_000_000),
            principal: 0,
            interest: 10_000e6, // 20k interest in 1m seconds
            lateInterest: 0,
            delegateServiceFee: 250e6,
            platformServiceFee: 500e6,
            paymentDueDate: start + 1_000_000,
            defaultDate: start + 1_500_000
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
            [address(poolDelegate), address(treasury)],
            [uint256(250e6) + uint256(100e6), uint256(500e6) + uint256(400e6)]
        );
    }

}

