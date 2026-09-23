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

        // Borrower will be deducted interest + fees
        uint256 principalInterestAndFees = 4_000e6 + 400e6 + 200e6;

        // Burn any amount of fundsAsset to simulate an empty wallet
        fundsAsset.burn(address(borrower), 1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(borrower)), 0);

        bytes[] memory calls = new bytes[](1);
        calls[0]             = abi.encodeWithSignature("increasePrincipal(uint256)", 2_000_000e6);

        proposeRefinanceOT(address(loan), openTermRefinancer, block.timestamp + 1, calls);

        assertEq(fundsAsset.allowance(address(loanManager), address(loan)), 0);

        assertEq(fundsAsset.balanceOf(address(loanManager)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)),        0);

        acceptRefinanceOT(address(loan), openTermRefinancer, block.timestamp + 1, calls);

        assertEq(fundsAsset.allowance(address(loanManager), address(loan)), 0);

        assertEq(fundsAsset.balanceOf(address(loanManager)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)),        0);

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

        assertEq(fundsAsset.balanceOf(address(borrower)), 2_000_000e6 - principalInterestAndFees);

        // PD:       service fees (400e6)  + management fees (4000 * 0.02)
        // Treasury: service fees (4000e6) + management fees (4000 * 0.08)
        assertAssetBalancesIncrease(
            address(fundsAsset),
            [address(poolDelegate), address(treasury)],
            [uint256(200e6) + uint256(80e6), uint256(400e6) + uint256(320e6)]
        );
    }

    function test_refinance_early_increasePrincipalWithCalledLoan() external {
        /********************************/
        /*** Pre Refinance Assertions ***/
        /********************************/

        vm.warp(start + 400_000);

        callLoan(address(loan), 1_000_000e6);

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
            principal:          1_000_000e6,
            interest:           4000e6,
            lateInterest:       0,
            delegateServiceFee: 200e6,
            platformServiceFee: 400e6,
            paymentDueDate:     start + 400_000 + noticePeriod,
            defaultDate:        start + 400_000 + noticePeriod
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

        // Borrower will be deducted the principal + interest + fees
        // Unreal scenario, as the loan is both called and refinanced to increase principal, but test showcases that this works.
        uint256 principalInterestAndFees = 1_000_000e6 + 4_000e6 + 400e6 + 200e6;

        // Burn any amount of fundsAsset to simulate an empty wallet
        fundsAsset.burn(address(borrower), 1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(borrower)), 0);

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

        assertEq(fundsAsset.balanceOf(address(borrower)), 3_000_000e6 - principalInterestAndFees);

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

    function test_refinance_increasePrincipalMatchingPayment() external {
        /********************************/
        /*** Pre Refinance Assertions ***/
        /********************************/
        vm.warp(start + 100_000);

        expectedTotalAssets += 900e6;

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
            interest:           1_000e6,
            lateInterest:       0,
            delegateServiceFee: 50e6,
            platformServiceFee: 100e6,
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
            accruedInterest:   900e6,
            principalOut:      1_000_000e6,
            issuanceRate:      0.009e6 * 1e27,
            domainStart:       start,
            unrealizedLosses:  0
        });

        // Borrower will be deducted the principal + interest + fees
        uint256 dueInterestAndFees = 1000e6 + 50e6 + 100e6;

        // Burn any amount of fundsAsset to simulate an empty wallet
        fundsAsset.burn(address(borrower), 1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(borrower)), 0);

        bytes[] memory calls = new bytes[](1);
        calls[0]             = abi.encodeWithSignature("increasePrincipal(uint256)", dueInterestAndFees);

        proposeRefinanceOT(address(loan), openTermRefinancer, block.timestamp + 1, calls);

        assertEq(fundsAsset.allowance(address(loanManager), address(loan)), 0);

        assertEq(fundsAsset.balanceOf(address(loanManager)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)),        0);

        acceptRefinanceOT(address(loan), openTermRefinancer, block.timestamp + 1, calls);

        assertEq(fundsAsset.allowance(address(loanManager), address(loan)), 0);

        assertEq(fundsAsset.balanceOf(address(loanManager)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)),        0);

        /*********************************/
        /*** Post Refinance Assertions ***/
        /*********************************/

        expectedCash = expectedCash - dueInterestAndFees + 900e6;

        uint256 scaler       = 1e18;
        uint256 newPrincipal = principal + dueInterestAndFees;
        uint256 newInterest  = newPrincipal * scaler * interestRate / (scaler * 365 days);

        // Take gross interest, remove 10% of fees, then multiply the scaler and divide by number of seconds.
        uint256 newIssuanceRate = (newInterest - (newInterest * 0.1e6 / 1e6)) * 1e27 / 1_000_000;

        assertPoolState({
            pool:               address(pool),
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanPaymentState({
            loan: address(loan),
            paymentTimestamp: uint40(start + 1_100_000),
            principal: 0,
            interest: newInterest, // 30k per 1m seconds
            lateInterest: 0,
            delegateServiceFee: newInterest * 0.015768e6 * scaler * 100 / (365 days * scaler),
            platformServiceFee: newInterest * 0.031536e6 * scaler * 100 / (365 days * scaler),
            paymentDueDate: start + 1_100_000,
            defaultDate: start + 1_300_000
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            issuanceRate:    newIssuanceRate,
            startDate:       start + 100_000,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.02e6
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: 0,
            accruedInterest:   0,
            principalOut:      newPrincipal,
            issuanceRate:      newIssuanceRate,
            domainStart:       start + 100_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(borrower)), 0); // Borrower balance is still s0

        // PD:       service fees (50e6)  + management fees (1000 * 0.02)
        // Treasury: service fees (100e6) + management fees (1000 * 0.08)
        assertAssetBalancesIncrease(
            address(fundsAsset), [address(poolDelegate), address(treasury)], [uint256(50e6) + uint256(20e6), uint256(100e6) + uint256(80e6)]
        );
    }

    function test_refinance_increasePrincipalToDesiredAmount() external {
        /********************************/
        /*** Pre Refinance Assertions ***/
        /********************************/
        vm.warp(start + 100_000);

        expectedTotalAssets += 900e6;

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
            interest:           1_000e6,
            lateInterest:       0,
            delegateServiceFee: 50e6,
            platformServiceFee: 100e6,
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
            accruedInterest:   900e6,
            principalOut:      1_000_000e6,
            issuanceRate:      0.009e6 * 1e27,
            domainStart:       start,
            unrealizedLosses:  0
        });

        uint256 desiredPrincipal = 2_000_000e6;

        // Borrower will be deducted the interest + fees
        uint256 dueInterestAndFees = 1000e6 + 50e6 + 100e6;

        // Burn any amount of fundsAsset to simulate an empty wallet
        fundsAsset.burn(address(borrower), 1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(borrower)), 0);

        bytes[] memory calls = new bytes[](1);
        calls[0]             = abi.encodeWithSignature("increasePrincipal(uint256)", desiredPrincipal + dueInterestAndFees);

        proposeRefinanceOT(address(loan), openTermRefinancer, block.timestamp + 1, calls);

        assertEq(fundsAsset.allowance(address(loanManager), address(loan)), 0);

        assertEq(fundsAsset.balanceOf(address(loanManager)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)),        0);

        acceptRefinanceOT(address(loan), openTermRefinancer, block.timestamp + 1, calls);

        assertEq(fundsAsset.allowance(address(loanManager), address(loan)), 0);

        assertEq(fundsAsset.balanceOf(address(loanManager)), 0);
        assertEq(fundsAsset.balanceOf(address(loan)),        0);

        /*********************************/
        /*** Post Refinance Assertions ***/
        /*********************************/

        expectedCash = expectedCash - desiredPrincipal - dueInterestAndFees + 900e6;

        uint256 scaler       = 1e18;
        uint256 newPrincipal = principal + desiredPrincipal + dueInterestAndFees;
        uint256 newInterest  = newPrincipal * scaler * interestRate / (scaler * 365 days);

        // Take gross interest, remove 10% of fees, then multiply the scaler and divide by number of seconds.
        uint256 newIssuanceRate = (newInterest - (newInterest * 0.1e6 / 1e6)) * 1e27 / 1_000_000;

        assertPoolState({
            pool:               address(pool),
            totalSupply:        expectedTotalSupply,
            totalAssets:        expectedTotalAssets,
            unrealizedLosses:   0,
            availableLiquidity: expectedCash
        });

        assertOpenTermLoanPaymentState({
            loan: address(loan),
            paymentTimestamp: uint40(start + 1_100_000),
            principal: 0,
            interest: newInterest, // 30k per 1m seconds
            lateInterest: 0,
            delegateServiceFee: newInterest * 0.015768e6 * scaler * 100 / (365 days * scaler),
            platformServiceFee: newInterest * 0.031536e6 * scaler * 100 / (365 days * scaler),
            paymentDueDate: start + 1_100_000,
            defaultDate: start + 1_300_000
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            issuanceRate:    newIssuanceRate,
            startDate:       start + 100_000,
            platformFeeRate: 0.08e6,
            delegateFeeRate: 0.02e6
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: 0,
            accruedInterest:   0,
            principalOut:      newPrincipal,
            issuanceRate:      newIssuanceRate,
            domainStart:       start + 100_000,
            unrealizedLosses:  0
        });

        assertEq(fundsAsset.balanceOf(address(borrower)), desiredPrincipal); // Borrower got exactly the desired principal

        // PD:       service fees (50e6)  + management fees (1000 * 0.02)
        // Treasury: service fees (100e6) + management fees (1000 * 0.08)
        assertAssetBalancesIncrease(
            address(fundsAsset), [address(poolDelegate), address(treasury)], [uint256(50e6) + uint256(20e6), uint256(100e6) + uint256(80e6)]
        );
    }

}

