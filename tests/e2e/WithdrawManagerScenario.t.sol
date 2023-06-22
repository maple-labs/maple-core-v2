// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

// TODO: Add Pool Delegate cover for liquidation related test cases

contract WithdrawalManagerScenarioTests is TestBaseWithAssertions {

    address borrower;
    address loan;
    address lp1;
    address lp2;
    address lp3;

    address[] lps;

    function setUp() public override {
        super.setUp();

        borrower = makeAddr("borrower");
        lp1      = makeAddr("lp1");
        lp2      = makeAddr("lp2");
        lp3      = makeAddr("lp3");

        // Setup 50 random Addresses for LPs
        for (uint256 i; i < 50; ++i) {
            lps.push(makeAddr(string(abi.encode("lps", i))));
        }

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,  // 10k after 1m seconds
            platformManagementFeeRate:  0.08e6
        });
    }

    function test_scenario_impairLoanAndRedeem_repayLoanAndWithdraw() external {
        // 2 LPs deposit
        deposit(lp1, 1_000_000e6);
        deposit(lp2, 1_000_000e6);

        assertEq(pool.balanceOf(lp1), 1_000_000e6);
        assertEq(pool.balanceOf(lp2), 1_000_000e6);

        address loanManager = poolManager.loanManagerList(0);

        // Fund a new loan
        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(30 days), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0.05e6), uint256(0), uint256(0)],
            loanManager: loanManager
        });

        uint256 annualLoanInterest = 1_000_000e6 * 0.031536e6 * 0.9e6 / 1e6 / 1e6;  // Note: 10% of interest is paid in fees

        uint256 dailyLoanInterest = annualLoanInterest * 1 days / 365 days;

        uint256 issuanceRate = (dailyLoanInterest * 30) * 1e30 / 30 days;

        assertEq(annualLoanInterest, 28382.4e6);
        assertEq(dailyLoanInterest,  77.76e6);
        assertEq(issuanceRate,       900e30);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      issuanceRate,
            domainStart:       start,
            domainEnd:         start + 30 days,
            unrealizedLosses:  0
        });

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp1,
            lockedShares:                 0,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           0,
            currentCycleTotalShares:      0,
            withdrawalManagerTotalShares: 0
        });

        // LP1 requests to redeem
        vm.warp(start + 1 days);

        requestRedeem(address(pool), lp1, 1_000_000e6);

        assertEq(pool.balanceOf(lp1), 0);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp1,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      1_000_000e6,
            withdrawalManagerTotalShares: 1_000_000e6
        });

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp2,
            lockedShares:                 0,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           0,
            currentCycleTotalShares:      0,
            withdrawalManagerTotalShares: 1_000_000e6
        });

        // LP2 requests to redeem
        vm.warp(start + 2 days);

        requestRedeem(address(pool), lp2, 1_000_000e6);

        assertEq(pool.balanceOf(lp2), 0);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp2,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      2_000_000e6,
            withdrawalManagerTotalShares: 2_000_000e6
        });

        // Update the WM config
        setExitConfig(address(withdrawalManager), 3 days, 1 days);

        // Warp to withdraw window
        vm.warp(start + 2 weeks + 1 days);

        uint256 loanInterestAccrued = 15 * dailyLoanInterest;

        assertPoolState({
            pool:               address(pool),
            totalSupply:        2_000_000e6,
            totalAssets:        2_000_000e6 + loanInterestAccrued,
            unrealizedLosses:   0,
            availableLiquidity: 1_000_000e6
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 1.000583e6);

        impairLoan(loan);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        2_000_000e6,
            totalAssets:        2_000_000e6 + loanInterestAccrued,
            unrealizedLosses:   1_000_000e6 + loanInterestAccrued,
            availableLiquidity: 1_000_000e6
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 0.5e6);

        redeem(address(pool), lp1, 1_000_000e6);

        assertEq(pool.balanceOf(lp1), 0);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp2,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      1_000_000e6,
            withdrawalManagerTotalShares: 1_000_000e6
        });

        assertEq(fundsAsset.balanceOf(lp1), 500_000e6);

        // Repay loan in full
        close(loan);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      0,
            issuanceRate:      0,
            domainStart:       block.timestamp,
            domainEnd:         block.timestamp,
            unrealizedLosses:  0
        });

        uint256 loanPrincipal     = 1_000_000e6;
        uint256 closeLoanInterest = loanPrincipal * 0.05e6 * 0.9e6 / 1e6 / 1e6;  // 45_000e6

        assertEq(closeLoanInterest, 45_000e6);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        1_000_000e6,
            totalAssets:        500_000e6 + loanPrincipal + closeLoanInterest,
            unrealizedLosses:   0,
            availableLiquidity: 500_000e6 + loanPrincipal + closeLoanInterest
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 1.545e6);

        // Forward further into the withdraw window
        vm.warp(start + 2 weeks + 2 days - 1 seconds);

        redeem(address(pool), lp2, 1_000_000e6);

        assertEq(pool.balanceOf(lp2), 0);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp2,
            lockedShares:                 0,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           0,
            currentCycleTotalShares:      0,
            withdrawalManagerTotalShares: 0
        });

        assertEq(fundsAsset.balanceOf(lp1), 500_000e6);
        assertEq(fundsAsset.balanceOf(lp2), 1_545_000e6);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        0,
            totalAssets:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });
    }

    function test_scenario_impairLoanAndRedeem_defaultLoanAndWithdraw() external {
        // 2 LPs deposit
        deposit(lp1, 1_000_000e6);
        deposit(lp2, 1_000_000e6);

        assertEq(pool.balanceOf(lp1), 1_000_000e6);
        assertEq(pool.balanceOf(lp2), 1_000_000e6);

        address loanManager = poolManager.loanManagerList(0);

        // Fund a new loan
        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(12 hours), uint256(30 days), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0.05e6), uint256(0), uint256(0)],
            loanManager: loanManager
        });

        uint256 annualLoanInterest = 1_000_000e6 * 0.031536e6 * 0.9e6 / 1e6 / 1e6;  // Note: 10% of interest is paid in fees

        uint256 dailyLoanInterest = annualLoanInterest * 1 days / 365 days;

        uint256 issuanceRate = (dailyLoanInterest * 30) * 1e30 / 30 days;

        assertEq(annualLoanInterest, 28382.4e6);
        assertEq(dailyLoanInterest,  77.76e6);
        assertEq(issuanceRate,       900e30);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      issuanceRate,
            domainStart:       start,
            domainEnd:         start + 30 days,
            unrealizedLosses:  0
        });

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp1,
            lockedShares:                 0,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           0,
            currentCycleTotalShares:      0,
            withdrawalManagerTotalShares: 0
        });

        // LP1 requests to redeem
        vm.warp(start + 1 days);

        requestRedeem(address(pool), lp1, 1_000_000e6);

        assertEq(pool.balanceOf(lp1), 0);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp1,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      1_000_000e6,
            withdrawalManagerTotalShares: 1_000_000e6
        });

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp2,
            lockedShares:                 0,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           0,
            currentCycleTotalShares:      0,
            withdrawalManagerTotalShares: 1_000_000e6
        });

        // LP2 requests to redeem
        vm.warp(start + 2 days);

        requestRedeem(address(pool), lp2, 1_000_000e6);

        assertEq(pool.balanceOf(lp1), 0);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp2,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      2_000_000e6,
            withdrawalManagerTotalShares: 2_000_000e6
        });

        // Update the WM config
        setExitConfig(address(withdrawalManager), 3 days, 1 days);

        // Warp to withdraw window
        vm.warp(start + 2 weeks + 1 days);

        uint256 loanInterestAccrued = 15 * dailyLoanInterest;

        assertPoolState({
            pool:               address(pool),
            totalSupply:        2_000_000e6,
            totalAssets:        2_000_000e6 + loanInterestAccrued,
            unrealizedLosses:   0,
            availableLiquidity: 1_000_000e6
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 1.000583e6);

        impairLoan(loan);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: loanInterestAccrued,
            principalOut:      1_000_000e6,
            issuanceRate:      0,
            domainStart:       block.timestamp,
            domainEnd:         block.timestamp,
            unrealizedLosses:  1_000_000e6 + loanInterestAccrued
        });

        assertPoolState({
            pool:               address(pool),
            totalSupply:        2_000_000e6,
            totalAssets:        2_000_000e6 + loanInterestAccrued,
            unrealizedLosses:   1_000_000e6 + loanInterestAccrued,
            availableLiquidity: 1_000_000e6
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 0.5e6);

        redeem(address(pool), lp1, 1_000_000e6);

        assertEq(pool.balanceOf(lp1), 0);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp2,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      1_000_000e6,
            withdrawalManagerTotalShares: 1_000_000e6
        });

        assertEq(fundsAsset.balanceOf(lp1), 500_000e6);

        // Forward to trigger default
        vm.warp(start + 2 weeks + 2 days - 2 seconds);

        triggerDefault(loan, address(liquidatorFactory));

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      0,
            issuanceRate:      0,
            domainStart:       block.timestamp,
            domainEnd:         block.timestamp,
            unrealizedLosses:  0
        });

        assertPoolState({
            pool:               address(pool),
            totalSupply:        1_000_000e6,
            totalAssets:        500_000e6,
            unrealizedLosses:   0,
            availableLiquidity: 500_000e6
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 0.5e6);

        // Forward further into the withdraw window
        vm.warp(start + 2 weeks + 2 days - 1 seconds);

        redeem(address(pool), lp2, 1_000_000e6);

        assertEq(pool.balanceOf(lp2), 0);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp2,
            lockedShares:                 0,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           0,
            currentCycleTotalShares:      0,
            withdrawalManagerTotalShares: 0
        });

        assertEq(fundsAsset.balanceOf(lp1), 500_000e6);
        assertEq(fundsAsset.balanceOf(lp2), 500_000e6);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        0,
            totalAssets:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });
    }

    function test_scenario_impairLoanAndRedeem_removeImpairAndRedeem() external {
        // 2 LPs deposit
        deposit(lp1, 1_000_000e6);
        deposit(lp2, 1_000_000e6);

        assertEq(pool.balanceOf(lp1), 1_000_000e6);
        assertEq(pool.balanceOf(lp2), 1_000_000e6);

        address loanManager = poolManager.loanManagerList(0);

        // Fund a new loan
        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(30 days), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0.05e6), uint256(0), uint256(0)],
            loanManager: loanManager
        });

        uint256 annualLoanInterest = 1_000_000e6 * 0.031536e6 * 0.9e6 / 1e6 / 1e6;  // Note: 10% of interest is paid in fees

        uint256 dailyLoanInterest = annualLoanInterest * 1 days / 365 days;

        uint256 issuanceRate = (dailyLoanInterest * 30) * 1e30 / 30 days;

        assertEq(annualLoanInterest, 28382.4e6);
        assertEq(dailyLoanInterest,  77.76e6);
        assertEq(issuanceRate,       900e30);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      issuanceRate,
            domainStart:       start,
            domainEnd:         start + 30 days,
            unrealizedLosses:  0
        });

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp1,
            lockedShares:                 0,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           0,
            currentCycleTotalShares:      0,
            withdrawalManagerTotalShares: 0
        });

        // LP1 requests to redeem
        vm.warp(start + 1 days);

        requestRedeem(address(pool), lp1, 1_000_000e6);

        assertEq(pool.balanceOf(lp1), 0);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp1,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      1_000_000e6,
            withdrawalManagerTotalShares: 1_000_000e6
        });

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp2,
            lockedShares:                 0,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           0,
            currentCycleTotalShares:      0,
            withdrawalManagerTotalShares: 1_000_000e6
        });

        // LP2 requests to redeem
        vm.warp(start + 2 days);

        requestRedeem(address(pool), lp2, 1_000_000e6);

        assertEq(pool.balanceOf(lp2), 0);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp2,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      2_000_000e6,
            withdrawalManagerTotalShares: 2_000_000e6
        });

        // Update the WM config
        setExitConfig(address(withdrawalManager), 3 days, 1 days);

        // Warp to withdraw window
        vm.warp(start + 2 weeks + 1 days);

        uint256 loanInterestAccrued = 15 * dailyLoanInterest;

        assertPoolState({
            pool:               address(pool),
            totalSupply:        2_000_000e6,
            totalAssets:        2_000_000e6 + loanInterestAccrued,
            unrealizedLosses:   0,
            availableLiquidity: 1_000_000e6
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 1.000583e6);

        impairLoan(loan);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: loanInterestAccrued,
            principalOut:      1_000_000e6,
            issuanceRate:      0,
            domainStart:       block.timestamp,
            domainEnd:         block.timestamp,
            unrealizedLosses:  1_000_000e6 + loanInterestAccrued
        });

        assertPoolState({
            pool:               address(pool),
            totalSupply:        2_000_000e6,
            totalAssets:        2_000_000e6 + loanInterestAccrued,
            unrealizedLosses:   1_000_000e6 + loanInterestAccrued,
            availableLiquidity: 1_000_000e6
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 0.5e6);

        redeem(address(pool), lp1, 1_000_000e6);

        assertEq(pool.balanceOf(lp1), 0);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp2,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      1_000_000e6,
            withdrawalManagerTotalShares: 1_000_000e6
        });

        assertEq(fundsAsset.balanceOf(lp1), 500_000e6);

        removeLoanImpairment(loan);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: loanInterestAccrued,
            principalOut:      1_000_000e6,
            issuanceRate:      issuanceRate,
            domainStart:       block.timestamp,
            domainEnd:         start + 30 days,
            unrealizedLosses:  0
        });

        assertPoolState({
            pool:               address(pool),
            totalSupply:        1_000_000e6,
            totalAssets:        1_500_000e6 + loanInterestAccrued,
            unrealizedLosses:   0,
            availableLiquidity: 500_000e6
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 1.501166e6);

        // Forward further into the withdraw window
        vm.warp(start + 2 weeks + 2 days - 1 seconds);

        redeem(address(pool), lp2, 1_000_000e6);

        assertEq(pool.balanceOf(lp2), 0);

        loanInterestAccrued = (16 days - 1 seconds) * annualLoanInterest / 365 days;

        assertEq(loanInterestAccrued, 1_244.159100e6);

        // LP2 gets pro rata amount due to partial liquidity
        // Liquidity in pool: 500_000e6
        // Accrued Interest: 1_244.159100e6
        // Proportion LP2 entitled to: 500_000e6 / (1_500_000e6 + 1_244.159100e6) = ~0.33
        // Shares remaining after pro rata burn:
        //   1_000_000e6 - (1_000_000e6 * (500_000e6 / (1_500_000e6 + 1_244.159100e6))) = 666_942.917333e6

        uint256 lp2RemainingShares =
            1_000_000e6 - (uint256(1_000_000e6) * (500_000e6 * 1e18 / (uint256(1_500_000e6) + loanInterestAccrued)) / 1e18);

        assertApproxEqAbs(lp2RemainingShares, 666_942.917333e6, 1);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp2,
            lockedShares:                 666_942.917334e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           4,
            currentCycleTotalShares:      666_942.917334e6,
            withdrawalManagerTotalShares: 666_942.917334e6
        });

        assertEq(fundsAsset.balanceOf(lp1), 500_000e6);

        assertApproxEqAbs(fundsAsset.balanceOf(lp2), 500_000e6, 1);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        666_942.917334e6,
            totalAssets:        1_000_000e6 + loanInterestAccrued + 1,
            unrealizedLosses:   0,
            availableLiquidity: 1                                       // NOTE: Dust due to rounding above
        });
    }

    function test_scenario_impairLoanAndRedeem_startLiquidationAndRedeem_finishLiquidationAndRedeem() external {
        // 3 LPs deposit
        deposit(lp1, 1_000_000e6);
        deposit(lp2, 1_000_000e6);
        deposit(lp3, 1_000_000e6);

        assertEq(pool.balanceOf(lp1), 1_000_000e6);
        assertEq(pool.balanceOf(lp2), 1_000_000e6);
        assertEq(pool.balanceOf(lp3), 1_000_000e6);

        address loanManager = poolManager.loanManagerList(0);

        // Fund a new loan
        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(12 hours), uint256(30 days), uint256(3)],
            amounts:     [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0.05e6), uint256(0), uint256(0)],
            loanManager: loanManager
        });

        uint256 annualLoanInterest = 1_000_000e6 * 0.031536e6 * 0.9e6 / 1e6 / 1e6;  // Note: 10% of interest is paid in fees

        uint256 dailyLoanInterest = annualLoanInterest * 1 days / 365 days;

        uint256 issuanceRate = (dailyLoanInterest * 30) * 1e30 / 30 days;

        assertEq(annualLoanInterest, 28382.4e6);
        assertEq(dailyLoanInterest,  77.76e6);
        assertEq(issuanceRate,       900e30);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      issuanceRate,
            domainStart:       start,
            domainEnd:         start + 30 days,
            unrealizedLosses:  0
        });

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp1,
            lockedShares:                 0,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           0,
            currentCycleTotalShares:      0,
            withdrawalManagerTotalShares: 0
        });

        // LP1 requests to redeem
        vm.warp(start + 1 days);

        requestRedeem(address(pool), lp1, 1_000_000e6);

        assertEq(pool.balanceOf(lp1), 0);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp1,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      1_000_000e6,
            withdrawalManagerTotalShares: 1_000_000e6
        });

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp2,
            lockedShares:                 0,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           0,
            currentCycleTotalShares:      0,
            withdrawalManagerTotalShares: 1_000_000e6
        });

        // LP2 requests to redeem
        vm.warp(start + 2 days);

        requestRedeem(address(pool), lp2, 1_000_000e6);

        assertEq(pool.balanceOf(lp2), 0);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp2,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      2_000_000e6,
            withdrawalManagerTotalShares: 2_000_000e6
        });

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp3,
            lockedShares:                 0,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           0,
            currentCycleTotalShares:      0,
            withdrawalManagerTotalShares: 2_000_000e6
        });

        // LP3 requests to redeem
        vm.warp(start + 3 days);

        requestRedeem(address(pool), lp3, 1_000_000e6);

        assertEq(pool.balanceOf(lp3), 0);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp3,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      3_000_000e6,
            withdrawalManagerTotalShares: 3_000_000e6
        });

        // Warp to withdraw window
        vm.warp(start + 2 weeks + 1 days);

        uint256 loanInterestAccrued = 15 * dailyLoanInterest;

        assertPoolState({
            pool:               address(pool),
            totalSupply:        3_000_000e6,
            totalAssets:        3_000_000e6 + loanInterestAccrued,
            unrealizedLosses:   0,
            availableLiquidity: 2_000_000e6
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 1.000388e6);

        impairLoan(loan);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: loanInterestAccrued,
            principalOut:      1_000_000e6,
            issuanceRate:      0,
            domainStart:       block.timestamp,
            domainEnd:         block.timestamp,
            unrealizedLosses:  1_000_000e6 + loanInterestAccrued
        });

        assertPoolState({
            pool:               address(pool),
            totalSupply:        3_000_000e6,
            totalAssets:        3_000_000e6 + loanInterestAccrued,
            unrealizedLosses:   1_000_000e6 + loanInterestAccrued,
            availableLiquidity: 2_000_000e6
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 0.666666e6);

        // Withdraw LP1
        vm.warp(start + 2 weeks + 1 days);

        redeem(address(pool), lp1, 1_000_000e6);

        assertEq(pool.balanceOf(lp1), 0);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp2,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      2_000_000e6,
            withdrawalManagerTotalShares: 2_000_000e6
        });

        assertEq(fundsAsset.balanceOf(lp1), 666_666.666666e6);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        2_000_000e6,
            totalAssets:        3_000_000e6 + loanInterestAccrued - fundsAsset.balanceOf(lp1),
            unrealizedLosses:   1_000_000e6 + loanInterestAccrued,
            availableLiquidity: 2_000_000e6 - fundsAsset.balanceOf(lp1)
        });

        // Warp 12 hours and default
        vm.warp(start + 2 weeks + 1 days + 12 hours + 1);

        triggerDefault(loan, address(liquidatorFactory));

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: loanInterestAccrued,
            principalOut:      1_000_000e6,
            issuanceRate:      0,
            domainStart:       block.timestamp,
            domainEnd:         block.timestamp,
            unrealizedLosses:  1_000_000e6 + loanInterestAccrued
        });

        assertPoolState({
            pool:               address(pool),
            totalSupply:        2_000_000e6,
            totalAssets:        3_000_000e6 + loanInterestAccrued - fundsAsset.balanceOf(lp1),
            unrealizedLosses:   1_000_000e6 + loanInterestAccrued,
            availableLiquidity: 2_000_000e6 - fundsAsset.balanceOf(lp1)
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 0.666666e6);

        // LP2 to redeem
        redeem(address(pool), lp2, 1_000_000e6);

        assertEq(pool.balanceOf(lp2), 0);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp3,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      1_000_000e6,
            withdrawalManagerTotalShares: 1_000_000e6
        });

        assertEq(fundsAsset.balanceOf(lp2), 666_666.666667e6);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        1_000_000e6,
            totalAssets:        3_000_000e6 + loanInterestAccrued - fundsAsset.balanceOf(lp1) - fundsAsset.balanceOf(lp2),
            unrealizedLosses:   1_000_000e6 + loanInterestAccrued,
            availableLiquidity: 2_000_000e6 - fundsAsset.balanceOf(lp1) - fundsAsset.balanceOf(lp2)
        });

        // Liquidate collateral
        liquidateCollateral(loan);

        // Warp and LP3 to redeem
        vm.warp(start + 2 weeks + 2 days - 1 seconds);

        // Assets in pool prior to collateral liquidation: 666_666e6
        // Collateral of 100 eth priced at 1500 usd
        // Collateral liquidated to fundAsset: 150_000e6
        // Platform management fees not pro rata: 0.08e6 * 2592e6 (gross installment interest) = 207.36e6
        // Platform management fees pro rata:
        //   207.36e6 ~ (15 days / 30 days) = 103.68e6 (If no late interest then just pro rata based on payment)
        // Platform service fees: 0.31536 * 1_000_000 * ( 30 / 365 days )= 25_920e6
        // Platform fees from liquidation: 25_920e6 + 103.68e6 = 26_023.68e6
        // Funds added to pool from liquidation: 150_000e6 - 26_023.68e6 = 123_976.32e6

        uint256 grossInterestPerInstallment = (1_000_000e6 * 0.031536e6 / 1e6) * (30 days / 365 days);
        uint256 platformManagementFee       = (2592e6 * 0.08e6 / 1e6) * (15 days / 30 days);              // Loan impaired 15 days in
        uint256 platformServiceFee          = (0.31536e6 * 1_000_000e6 / 1e6) * (30 days / 365 days);
        uint256 platformFeesFromLiquidation = platformManagementFee + platformServiceFee;
        uint256 fundsAssetFromLiquidation   = 100 * 1_500e6;
        uint256 fundsAssetAddedToPool       = fundsAssetFromLiquidation - platformFeesFromLiquidation;

        assertEq(grossInterestPerInstallment, 2592e6);
        assertEq(platformManagementFee,       103.68e6);
        assertEq(platformServiceFee,          25_920e6);
        assertEq(platformFeesFromLiquidation, 26_023.68e6);
        assertEq(fundsAssetFromLiquidation,   150_000e6);
        assertEq(fundsAssetAddedToPool,       123_976.32e6);

        uint256 poolBalanceBeforeLiquidation = fundsAsset.balanceOf(address(pool));

        finishCollateralLiquidation(loan);

        uint256 poolBalanceAfterLiquidation           = fundsAsset.balanceOf(address(pool));
        uint256 expectedAssetsReturnedFromLiquidation = 123_976.32e6;

        assertEq(poolBalanceAfterLiquidation - poolBalanceBeforeLiquidation, expectedAssetsReturnedFromLiquidation);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      0,
            issuanceRate:      0,
            domainStart:       block.timestamp,
            domainEnd:         block.timestamp,
            unrealizedLosses:  0
        });

        assertPoolState({
            pool:               address(pool),
            totalSupply:        1_000_000e6,
            totalAssets:        2_000_000e6 - fundsAsset.balanceOf(lp1) - fundsAsset.balanceOf(lp2) + expectedAssetsReturnedFromLiquidation,
            unrealizedLosses:   0,
            availableLiquidity: 2_000_000e6 - fundsAsset.balanceOf(lp1) - fundsAsset.balanceOf(lp2) + expectedAssetsReturnedFromLiquidation
        });

        // Expected totalAssets: 666_666.666667e6 + 123_976.32e6 = 790_642.986667e6
        assertEq(fundsAsset.balanceOf(address(pool)), 790_642.986667e6);

        redeem(address(pool), lp3, 1_000_000e6);

        assertEq(pool.balanceOf(lp3), 0);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp3,
            lockedShares:                 0,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           0,
            currentCycleTotalShares:      0,
            withdrawalManagerTotalShares: 0
        });

        // LP3 gets more fundsAsset as a result of liquidation of the collateral and all the remaining liquidity
        assertEq(fundsAsset.balanceOf(lp3), 790_642.986667e6);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        0,
            totalAssets:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });
    }

    function test_scenario_impairLoanAndRedeem_removeSharesRepayLoanAndRedeem() external {
        // 2 LPs deposit
        deposit(lp1, 1_000_000e6);
        deposit(lp2, 1_000_000e6);

        assertEq(pool.balanceOf(lp1), 1_000_000e6);
        assertEq(pool.balanceOf(lp2), 1_000_000e6);

        address loanManager = poolManager.loanManagerList(0);

        // Fund a new loan
        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(30 days), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0.05e6), uint256(0), uint256(0)],
            loanManager: loanManager
        });

        uint256 annualLoanInterest = 1_000_000e6 * 0.031536e6 * 0.9e6 / 1e6 / 1e6;  // Note: 10% of interest is paid in fees

        uint256 dailyLoanInterest = annualLoanInterest * 1 days / 365 days;

        uint256 issuanceRate = (dailyLoanInterest * 30) * 1e30 / 30 days;

        assertEq(annualLoanInterest, 28382.4e6);
        assertEq(dailyLoanInterest,  77.76e6);
        assertEq(issuanceRate,       900e30);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      issuanceRate,
            domainStart:       start,
            domainEnd:         start + 30 days,
            unrealizedLosses:  0
        });

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp1,
            lockedShares:                 0,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           0,
            currentCycleTotalShares:      0,
            withdrawalManagerTotalShares: 0
        });

        // LP1 requests to redeem
        vm.warp(start + 1 days);

        requestRedeem(address(pool), lp1, 1_000_000e6);

        assertEq(pool.balanceOf(lp1), 0);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp1,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      1_000_000e6,
            withdrawalManagerTotalShares: 1_000_000e6
        });

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp2,
            lockedShares:                 0,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           0,
            currentCycleTotalShares:      0,
            withdrawalManagerTotalShares: 1_000_000e6
        });

        // LP2 requests to redeem
        vm.warp(start + 2 days);

        requestRedeem(address(pool), lp2, 1_000_000e6);

        assertEq(pool.balanceOf(lp2), 0);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp2,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      2_000_000e6,
            withdrawalManagerTotalShares: 2_000_000e6
        });

        // Warp to withdraw window
        vm.warp(start + 2 weeks + 1 days);

        uint256 loanInterestAccrued = 15 * dailyLoanInterest;

        assertPoolState({
            pool:               address(pool),
            totalSupply:        2_000_000e6,
            totalAssets:        2_000_000e6 + loanInterestAccrued,
            unrealizedLosses:   0,
            availableLiquidity: 1_000_000e6
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 1.000583e6);

        impairLoan(loan);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: loanInterestAccrued,
            principalOut:      1_000_000e6,
            issuanceRate:      0,
            domainStart:       block.timestamp,
            domainEnd:         block.timestamp,
            unrealizedLosses:  1_000_000e6 + loanInterestAccrued
        });

        assertPoolState({
            pool:               address(pool),
            totalSupply:        2_000_000e6,
            totalAssets:        2_000_000e6 + loanInterestAccrued,
            unrealizedLosses:   1_000_000e6 + loanInterestAccrued,
            availableLiquidity: 1_000_000e6
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 0.5e6);

        // LP1 removes shares from withdraw queue
        removeShares(address(pool), lp1, 1_000_000e6);

        assertEq(pool.balanceOf(lp1), 1_000_000e6);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp1,
            lockedShares:                 0,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           0,
            currentCycleTotalShares:      0,
            withdrawalManagerTotalShares: 1_000_000e6
        });

        assertEq(fundsAsset.balanceOf(lp1), 0);

        // Repay loan in full
        close(loan);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      0,
            issuanceRate:      0,
            domainStart:       block.timestamp,
            domainEnd:         block.timestamp,
            unrealizedLosses:  0
        });

        uint256 loanPrincipal     = 1_000_000e6;
        uint256 closeLoanInterest = loanPrincipal * 0.05e6 * 0.9e6 / 1e6 / 1e6;  // 45_000e6

        assertEq(closeLoanInterest, 45_000e6);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        2_000_000e6,
            totalAssets:        2_000_000e6 + closeLoanInterest,
            unrealizedLosses:   0,
            availableLiquidity: 2_000_000e6 + closeLoanInterest
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 1.0225e6);

        // Forward further into the withdraw window
        vm.warp(start + 2 weeks + 2 days - 1 seconds);

        redeem(address(pool), lp2, 1_000_000e6);

        assertEq(pool.balanceOf(lp2), 0);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp2,
            lockedShares:                 0,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           0,
            currentCycleTotalShares:      0,
            withdrawalManagerTotalShares: 0
        });

        assertEq(fundsAsset.balanceOf(lp2), 1_000_000e6 + (closeLoanInterest / 2));
        assertEq(fundsAsset.balanceOf(lp2), 1_022_500e6);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        1_000_000e6,
            totalAssets:        1_000_000e6 + 22_500e6,
            unrealizedLosses:   0,
            availableLiquidity: 1_000_000e6 + 22_500e6
        });
    }

    function test_scenario_multipleUsers_impairLoanAndRedeem_repayLoanAndRedeem() external {
        // Deposit liquidity from 50 LPs
        for (uint256 i; i < 50; ++i) {
            deposit(lps[i], 1_000_000e6);
            assertEq(pool.balanceOf(lps[i]), 1_000_000e6);
        }

        address loanManager = poolManager.loanManagerList(0);

        // Fund a new loan at 50% of pool liquidity
        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(30 days), uint256(3)],
            amounts:     [uint256(0), uint256(25_000_000e6), uint256(25_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0.05e6), uint256(0), uint256(0)],
            loanManager: loanManager
        });

        uint256 annualLoanInterest = 25_000_000e6 * 0.031536e6 * 0.9e6 / 1e6 / 1e6;  // Note: 10% of interest is paid in fees

        uint256 dailyLoanInterest = annualLoanInterest * 1 days / 365 days;

        uint256 issuanceRate = (dailyLoanInterest * 30) * 1e30 / 30 days;

        assertEq(annualLoanInterest, 709_560e6);
        assertEq(dailyLoanInterest,  1944e6);
        assertEq(issuanceRate,       22_500e30);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      25_000_000e6,
            issuanceRate:      issuanceRate,
            domainStart:       start,
            domainEnd:         start + 30 days,
            unrealizedLosses:  0
        });

        uint256 totalLpTokenAmount;

        // All LPs request to redeem
        for (uint256 i; i < 50; ++i) {
            uint256 lpTokenAmount = pool.balanceOf(lps[i]);

            assertWithdrawalManagerState({
                pool:                         address(pool),
                lp:                           lps[i],
                lockedShares:                 0,
                previousExitCycleId:          0,
                previousCycleTotalShares:     0,
                currentExitCycleId:           0,
                currentCycleTotalShares:      0,
                withdrawalManagerTotalShares: totalLpTokenAmount == 0 ? 0 : totalLpTokenAmount
            });

            vm.warp(start + 1 days + (i * 12 seconds));

            requestRedeem(address(pool), lps[i], lpTokenAmount);

            assertEq(pool.balanceOf(lps[i]), 0);

            totalLpTokenAmount += lpTokenAmount;

            assertWithdrawalManagerState({
                pool:                         address(pool),
                lp:                           lps[i],
                lockedShares:                 lpTokenAmount,
                previousExitCycleId:          0,
                previousCycleTotalShares:     0,
                currentExitCycleId:           3,
                currentCycleTotalShares:      totalLpTokenAmount,
                withdrawalManagerTotalShares: totalLpTokenAmount
            });
        }

        // Warp to WW
        vm.warp(start + 2 weeks + 1 days);

        uint256 loanInterestAccrued = 15 * dailyLoanInterest;

        assertPoolState({
            pool:               address(pool),
            totalSupply:        50_000_000e6,
            totalAssets:        50_000_000e6 + loanInterestAccrued,
            unrealizedLosses:   0,
            availableLiquidity: 25_000_000e6
        });

        impairLoan(loan);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: loanInterestAccrued,
            principalOut:      25_000_000e6,
            issuanceRate:      0,
            domainStart:       block.timestamp,
            domainEnd:         block.timestamp,
            unrealizedLosses:  25_000_000e6 + loanInterestAccrued
        });

        assertPoolState({
            pool:               address(pool),
            totalSupply:        50_000_000e6,
            totalAssets:        50_000_000e6 + loanInterestAccrued,
            unrealizedLosses:   25_000_000e6 + loanInterestAccrued,
            availableLiquidity: 25_000_000e6
        });

        uint256 totalAssetRedemptionsFirst30Lps;

        // Redeem 30 LPs
        for (uint256 i; i < 30; ++i) {
            uint256 userLockedShares = withdrawalManager.lockedShares(lps[i]);

            totalLpTokenAmount -= userLockedShares;

            redeem(address(pool), lps[i], userLockedShares);

            assertEq(pool.balanceOf(lps[i]), 0);

            assertWithdrawalManagerState({
                pool:                         address(pool),
                lp:                           lps[i],
                lockedShares:                 0,
                previousExitCycleId:          0,
                previousCycleTotalShares:     0,
                currentExitCycleId:           0,
                currentCycleTotalShares:      0,
                withdrawalManagerTotalShares: totalLpTokenAmount
            });

            assertEq(fundsAsset.balanceOf(lps[i]), 500_000e6);

            totalAssetRedemptionsFirst30Lps += fundsAsset.balanceOf(lps[i]);
        }

        assertEq(totalAssetRedemptionsFirst30Lps, 15_000_000e6);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        20_000_000e6,
            totalAssets:        50_000_000e6 + loanInterestAccrued - totalAssetRedemptionsFirst30Lps,
            unrealizedLosses:   25_000_000e6 + loanInterestAccrued,
            availableLiquidity: 10_000_000e6
        });

        // Repay the loan
        vm.warp(start + 2 weeks + 1 days);

        close(loan);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      0,
            issuanceRate:      0,
            domainStart:       block.timestamp,
            domainEnd:         block.timestamp,
            unrealizedLosses:  0
        });

        uint256 loanPrincipal     = 25_000_000e6;
        uint256 closeLoanInterest = loanPrincipal * 0.05e6 * 0.9e6 / 1e6 / 1e6;  // 1_125_000e6

        assertEq(closeLoanInterest, 1_125_000e6);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        20_000_000e6,
            totalAssets:        50_000_000e6 + closeLoanInterest - totalAssetRedemptionsFirst30Lps,
            unrealizedLosses:   0,
            availableLiquidity: 50_000_000e6 + closeLoanInterest - totalAssetRedemptionsFirst30Lps
        });

        // Expected fundsAsset amount per LP
        // TotalAssets / TotalSupply = 36_125_000e6 / 20_000_000e6 = 1_806_250e6
        assertEq(pool.totalAssets() * 1e6 / pool.totalSupply() * 1e6, 1_806_250e6);

        // Redeem the remaining LPs
        for (uint256 i = 30; i < 50; ++i) {
            uint256 userLockedShares = withdrawalManager.lockedShares(lps[i]);

            totalLpTokenAmount -= userLockedShares;

            vm.warp(start + 2 weeks + 1.5 days + (i * 12 seconds));

            redeem(address(pool), lps[i], userLockedShares);

            assertEq(pool.balanceOf(lps[i]), 0);

            assertWithdrawalManagerState({
                pool:                         address(pool),
                lp:                           lps[i],
                lockedShares:                 0,
                previousExitCycleId:          0,
                previousCycleTotalShares:     0,
                currentExitCycleId:           0,
                currentCycleTotalShares:      0,
                withdrawalManagerTotalShares: totalLpTokenAmount
            });

            assertEq(fundsAsset.balanceOf(lps[i]), 1_806_250e6);
        }

        assertPoolState({
            pool:               address(pool),
            totalSupply:        0,
            totalAssets:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });
    }

    function test_scenario_fundPayAndRefinanceLoanWithPartialRedemptions_removeSharesAndCloseLoan() external {
        // 3 LPs deposit
        deposit(lp1, 1_000_000e6);
        deposit(lp2, 1_000_000e6);
        deposit(lp3, 1_000_000e6);

        assertEq(pool.balanceOf(lp1), 1_000_000e6);
        assertEq(pool.balanceOf(lp2), 1_000_000e6);
        assertEq(pool.balanceOf(lp3), 1_000_000e6);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp1,
            lockedShares:                 0,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           0,
            currentCycleTotalShares:      0,
            withdrawalManagerTotalShares: 0
        });

        // LP1 requests to redeem
        vm.warp(start + 1 seconds);

        requestRedeem(address(pool), lp1, 500_000e6);

        assertEq(pool.balanceOf(lp1), 500_000e6);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp1,
            lockedShares:                 500_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      500_000e6,
            withdrawalManagerTotalShares: 500_000e6
        });

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp2,
            lockedShares:                 0,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           0,
            currentCycleTotalShares:      0,
            withdrawalManagerTotalShares: 500_000e6
        });

        // LP2 requests to redeem
        vm.warp(start + 2 seconds);

        requestRedeem(address(pool), lp2, 500_000e6);

        assertEq(pool.balanceOf(lp2), 500_000e6);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp2,
            lockedShares:                 500_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      1_000_000e6,
            withdrawalManagerTotalShares: 1_000_000e6
        });

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp3,
            lockedShares:                 0,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           0,
            currentCycleTotalShares:      0,
            withdrawalManagerTotalShares: 1_000_000e6
        });

        requestRedeem(address(pool), lp3, 1_000_000e6);

        assertEq(pool.balanceOf(lp3), 0);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp3,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      2_000_000e6,
            withdrawalManagerTotalShares: 2_000_000e6
        });

        assertPoolState({
            pool:               address(pool),
            totalSupply:        3_000_000e6,
            totalAssets:        3_000_000e6,
            unrealizedLosses:   0,
            availableLiquidity: 3_000_000e6
        });

        // Warp to fund new loan a day after initial redemption requests
        vm.warp(start + 1 days);

        address loanManager = poolManager.loanManagerList(0);

        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(12 hours), uint256(30 days), uint256(3)],
            amounts:     [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0.05e6), uint256(0), uint256(0)],
            loanManager: loanManager
        });

        uint256 annualLoanInterest = 1_000_000e6 * 0.031536e6 * 0.9e6 / 1e6 / 1e6;  // Note: 10% of interest is paid in fees

        uint256 dailyLoanInterest = annualLoanInterest * 1 days / 365 days;

        uint256 issuanceRate = (dailyLoanInterest * 30) * 1e30 / 30 days;

        assertEq(annualLoanInterest, 28382.4e6);
        assertEq(dailyLoanInterest,  77.76e6);
        assertEq(issuanceRate,       900e30);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      issuanceRate,
            domainStart:       start + 1 days,
            domainEnd:         start + 1 days + 30 days,
            unrealizedLosses:  0
        });

        assertPoolState({
            pool:               address(pool),
            totalSupply:        3_000_000e6,
            totalAssets:        3_000_000e6,
            unrealizedLosses:   0,
            availableLiquidity: 2_000_000e6
        });

        // Make payment to get interest in the pool
        makePayment(loan);

        // Issuance domain over 60 days due to early payment
        issuanceRate = (dailyLoanInterest * 30) * 1e30 / 60 days;

        assertEq(issuanceRate, 450e30);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      issuanceRate,
            domainStart:       start + 1 days,
            domainEnd:         start + 1 days + 60 days,
            unrealizedLosses:  0
        });

        uint256 interestInPool = 30 * dailyLoanInterest;

        assertEq(interestInPool, 2_332.8e6);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        3_000_000e6,
            totalAssets:        3_000_000e6 + interestInPool,
            unrealizedLosses:   0,
            availableLiquidity: 2_000_000e6 + interestInPool
        });

        // Warp to WW
        vm.warp(start + 2 weeks);

        uint256 loanInterestAccrued = 13 * dailyLoanInterest / 2;  // Note: Half as much accrued due to domain doubling

        assertEq(loanInterestAccrued, 505.44e6);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        3_000_000e6,
            totalAssets:        3_000_000e6 + interestInPool + loanInterestAccrued,
            unrealizedLosses:   0,
            availableLiquidity: 2_000_000e6 + interestInPool
        });

        // Redeem LP1
        redeem(address(pool), lp1, 500_000e6);

        assertEq(pool.balanceOf(lp1), 500_000e6);

        // Expected fundsAsset amount from 500_000e6 shares
        assertEq(500_000e6 * (3_000_000e6 + interestInPool + loanInterestAccrued) / 3_000_000e6, 500_473.04e6);

        assertEq(fundsAsset.balanceOf(lp1), 500_473.04e6);

        uint256 interestWithdrawn = 473.04e6;

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp1,
            lockedShares:                 0,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           0,
            currentCycleTotalShares:      0,
            withdrawalManagerTotalShares: 1_500_000e6
        });

        assertPoolState({
            pool:               address(pool),
            totalSupply:        2_500_000e6,
            totalAssets:        2_500_000e6 + interestInPool + loanInterestAccrued - interestWithdrawn,
            unrealizedLosses:   0,
            availableLiquidity: 1_500_000e6 + interestInPool - interestWithdrawn
        });

        // Refinance Loan
        bytes[] memory data = encodeWithSignatureAndUint("setPaymentInterval(uint256)", 60 days);

        proposeRefinance(loan, address(fixedTermRefinancer), block.timestamp + 1, data);

        returnFunds(loan, 30_000e6);  // Return funds to pay origination fees. TODO: determine exact amount.

        acceptRefinance(loan, address(fixedTermRefinancer), block.timestamp + 1, data, 0);

        issuanceRate = (dailyLoanInterest * 30) * 1e30 / 30 days;

        assertEq(issuanceRate, 900e30);

        assertFixedTermLoanManager({
            loanManager:       loanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      1_000_000e6,
            issuanceRate:      issuanceRate,
            domainStart:       start + 2 weeks,
            domainEnd:         start + 2 weeks + 60 days,
            unrealizedLosses:  0
        });

        assertPoolState({
            pool:               address(pool),
            totalSupply:        2_500_000e6,
            totalAssets:        2_500_000e6 + interestInPool - interestWithdrawn,
            unrealizedLosses:   0,
            availableLiquidity: 1_500_000e6 + interestInPool - interestWithdrawn
        });

        // LP2 removes shares
        removeShares(address(pool), lp2, 500_000e6);

        assertEq(pool.balanceOf(lp2), 1_000_000e6);

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp2,
            lockedShares:                 0,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           0,
            currentCycleTotalShares:      0,
            withdrawalManagerTotalShares: 1_000_000e6
        });

        assertPoolState({
            pool:               address(pool),
            totalSupply:        2_500_000e6,
            totalAssets:        2_500_000e6 + interestInPool - interestWithdrawn,
            unrealizedLosses:   0,
            availableLiquidity: 1_500_000e6 + interestInPool - interestWithdrawn
        });

        // Warp to WW
        vm.warp(start + 2 weeks + 1 days);

        // Repay Loan in full
        close(loan);

        uint256 loanPrincipal     = 1_000_000e6;
        uint256 closeLoanInterest = loanPrincipal * 0.05e6 * 0.9e6 / 1e6 / 1e6;  // 45_000e6

        assertEq(closeLoanInterest, 45_000e6);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        2_500_000e6,
            totalAssets:        2_500_000e6 + interestInPool - interestWithdrawn + closeLoanInterest,
            unrealizedLosses:   0,
            availableLiquidity: 2_500_000e6 + interestInPool - interestWithdrawn + closeLoanInterest
        });

        // Redeem LP3
        redeem(address(pool), lp3, 1_000_000e6);

        uint256 lp3FullWithdrawal = 1_000_000e6 + 18_743.904e6;

        // Expected fundsAsset amount from 1_000_000e6 shares
        assertEq(1_000_000e6 * (2_500_000e6 + interestInPool - interestWithdrawn + closeLoanInterest) / 2_500_000e6, lp3FullWithdrawal);

        assertEq(pool.balanceOf(lp3),       0);
        assertEq(fundsAsset.balanceOf(lp3), lp3FullWithdrawal);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        1_500_000e6,
            totalAssets:        2_500_000e6 + interestInPool - interestWithdrawn + closeLoanInterest - lp3FullWithdrawal,
            unrealizedLosses:   0,
            availableLiquidity: 2_500_000e6 + interestInPool - interestWithdrawn + closeLoanInterest - lp3FullWithdrawal
        });

        assertWithdrawalManagerState({
            pool:                         address(pool),
            lp:                           lp3,
            lockedShares:                 0,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           0,
            currentCycleTotalShares:      0,
            withdrawalManagerTotalShares: 0
        });
    }

}
