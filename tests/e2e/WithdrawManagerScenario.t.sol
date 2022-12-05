// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestBaseWithAssertions } from "../../contracts/utilities/TestBaseWithAssertions.sol";

import { Address, console } from "../../modules/contract-test-utils/contracts/test.sol";

import { MapleLoan as Loan } from "../../modules/loan-v401/contracts/MapleLoan.sol";
import { Refinancer }        from "../../modules/loan-v401/contracts/Refinancer.sol";

// TODO: Add Pool Delegate cover for liquidation related test cases

contract WithdrawalManagerScenarioTests is TestBaseWithAssertions {

    address borrower;
    address lp1;
    address lp2;
    address lp3;

    Loan loan;

    function setUp() public override {
        super.setUp();

        borrower = address(new Address());
        lp1      = address(new Address());
        lp2      = address(new Address());
        lp3      = address(new Address());

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
        depositLiquidity(lp1, 1_000_000e6);
        depositLiquidity(lp2, 1_000_000e6);

        assertEq(pool.balanceOf(lp1), 1_000_000e6);
        assertEq(pool.balanceOf(lp2), 1_000_000e6);

        // Fund a new loan
        loan = fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(5 days), uint256(30 days), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e18), uint256(0.05e18), uint256(0), uint256(0)]
        });

        uint256 annualLoanInterest = 1_000_000e6 * 0.031536e18 * 0.9e6 / 1e6 / 1e18 ;  // Note: 10% of interest is paid in fees

        uint256 dailyLoanInterest = annualLoanInterest * 1 days / 365 days;

        uint256 issuanceRate = (dailyLoanInterest * 30) * 1e30 / 30 days;

        assertEq(annualLoanInterest, 28382.4e6);
        assertEq(dailyLoanInterest,  77.76e6);
        assertEq(issuanceRate,       900e30);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          issuanceRate,
            domainStart:           start,
            domainEnd:             start + 30 days,
            unrealizedLosses:      0
        });

        assertWithdrawalManagerState({
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

        vm.prank(lp1);
        pool.requestRedeem(1_000_000e6, lp1);

        assertEq(pool.balanceOf(lp1), 0);

        assertWithdrawalManagerState({
            lp:                           lp1,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      1_000_000e6,
            withdrawalManagerTotalShares: 1_000_000e6
        });

        assertWithdrawalManagerState({
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

        vm.prank(lp2);
        pool.requestRedeem(1_000_000e6, lp2);

        assertEq(pool.balanceOf(lp2), 0);

        assertWithdrawalManagerState({
            lp:                           lp2,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      2_000_000e6,
            withdrawalManagerTotalShares: 2_000_000e6
        });

        // Update the WM config
        vm.prank(poolDelegate);
        withdrawalManager.setExitConfig(3 days, 1 days);

        // Warp to withdraw window
        vm.warp(start + 2 weeks + 1 days);

        uint256 loanInterestAccrued = 15 * dailyLoanInterest;

        assertPoolState({
            totalSupply:        2_000_000e6,
            totalAssets:        2_000_000e6 + loanInterestAccrued,
            unrealizedLosses:   0,
            availableLiquidity: 1_000_000e6
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 1.000583e6);

        // Impair the loan
        vm.prank(poolDelegate);
        poolManager.impairLoan(address(loan));

        assertPoolState({
            totalSupply:        2_000_000e6,
            totalAssets:        2_000_000e6 + loanInterestAccrued,
            unrealizedLosses:   1_000_000e6 + loanInterestAccrued,
            availableLiquidity: 1_000_000e6
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 0.5e6);

        vm.prank(lp1);
        pool.redeem(1_000_000e6, lp1, lp1);

        assertEq(pool.balanceOf(lp1), 0);

        assertWithdrawalManagerState({
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
        closeLoan(loan);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           block.timestamp,
            domainEnd:             block.timestamp,
            unrealizedLosses:      0
        });

        uint256 loanPrincipal     = 1_000_000e6;
        uint256 closeLoanInterest = loanPrincipal * 0.05e18 * 0.9e6 / 1e6 / 1e18;  // 45_000e6

        assertEq(closeLoanInterest, 45_000e6);

        assertPoolState({
            totalSupply:        1_000_000e6,
            totalAssets:        500_000e6 + loanPrincipal + closeLoanInterest,
            unrealizedLosses:   0,
            availableLiquidity: 500_000e6 + loanPrincipal + closeLoanInterest
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 1.545e6);

        // Forward further into the withdraw window
        vm.warp(start + 2 weeks + 2 days - 1 seconds);

        vm.prank(lp2);
        pool.redeem(1_000_000e6, lp2, lp2);

        assertEq(pool.balanceOf(lp2), 0);

        assertWithdrawalManagerState({
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
            totalSupply:        0,
            totalAssets:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });
    }

    function test_scenario_impairLoanAndRedeem_defaultLoanAndWithdraw() external {
        // 2 LPs deposit
        depositLiquidity(lp1, 1_000_000e6);
        depositLiquidity(lp2, 1_000_000e6);

        assertEq(pool.balanceOf(lp1), 1_000_000e6);
        assertEq(pool.balanceOf(lp2), 1_000_000e6);

        // Fund a new loan
        loan = fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(0), uint256(30 days), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e18), uint256(0.05e18), uint256(0), uint256(0)]
        });

        uint256 annualLoanInterest = 1_000_000e6 * 0.031536e18 * 0.9e6 / 1e6 / 1e18 ;  // Note: 10% of interest is paid in fees

        uint256 dailyLoanInterest = annualLoanInterest * 1 days / 365 days;

        uint256 issuanceRate = (dailyLoanInterest * 30) * 1e30 / 30 days;

        assertEq(annualLoanInterest, 28382.4e6);
        assertEq(dailyLoanInterest,  77.76e6);
        assertEq(issuanceRate,       900e30);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          issuanceRate,
            domainStart:           start,
            domainEnd:             start + 30 days,
            unrealizedLosses:      0
        });

        assertWithdrawalManagerState({
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

        vm.prank(lp1);
        pool.requestRedeem(1_000_000e6, lp1);

        assertEq(pool.balanceOf(lp1), 0);

        assertWithdrawalManagerState({
            lp:                           lp1,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      1_000_000e6,
            withdrawalManagerTotalShares: 1_000_000e6
        });

        assertWithdrawalManagerState({
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

        vm.prank(lp2);
        pool.requestRedeem(1_000_000e6, lp2);

        assertEq(pool.balanceOf(lp1), 0);

        assertWithdrawalManagerState({
            lp:                           lp2,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      2_000_000e6,
            withdrawalManagerTotalShares: 2_000_000e6
        });

        // Update the WM config
        vm.prank(poolDelegate);
        withdrawalManager.setExitConfig(3 days, 1 days);

        // Warp to withdraw window
        vm.warp(start + 2 weeks + 1 days);

        uint256 loanInterestAccrued = 15 * dailyLoanInterest;

        assertPoolState({
            totalSupply:        2_000_000e6,
            totalAssets:        2_000_000e6 + loanInterestAccrued,
            unrealizedLosses:   0,
            availableLiquidity: 1_000_000e6
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 1.000583e6);

        // Impair the loan
        vm.prank(poolDelegate);
        poolManager.impairLoan(address(loan));

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     loanInterestAccrued,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + loanInterestAccrued,
            issuanceRate:          0,
            domainStart:           block.timestamp,
            domainEnd:             block.timestamp,
            unrealizedLosses:      1_000_000e6 + loanInterestAccrued
        });

        assertPoolState({
            totalSupply:        2_000_000e6,
            totalAssets:        2_000_000e6 + loanInterestAccrued,
            unrealizedLosses:   1_000_000e6 + loanInterestAccrued,
            availableLiquidity: 1_000_000e6
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 0.5e6);

        vm.prank(lp1);
        pool.redeem(1_000_000e6, lp1, lp1);

        assertEq(pool.balanceOf(lp1), 0);

        assertWithdrawalManagerState({
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

        vm.prank(poolDelegate);
        poolManager.triggerDefault(address(loan), address(liquidatorFactory));

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           block.timestamp,
            domainEnd:             block.timestamp,
            unrealizedLosses:      0
        });

        assertPoolState({
            totalSupply:        1_000_000e6,
            totalAssets:        500_000e6,
            unrealizedLosses:   0,
            availableLiquidity: 500_000e6
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 0.5e6);

        // Forward further into the withdraw window
        vm.warp(start + 2 weeks + 2 days - 1 seconds);

        vm.prank(lp2);
        pool.redeem(1_000_000e6, lp2, lp2);

        assertEq(pool.balanceOf(lp2), 0);

        assertWithdrawalManagerState({
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
            totalSupply:        0,
            totalAssets:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });
    }

    function test_scenario_impairLoanAndRedeem_removeImpairAndRedeem() external {
        // 2 LPs deposit
        depositLiquidity(lp1, 1_000_000e6);
        depositLiquidity(lp2, 1_000_000e6);

        assertEq(pool.balanceOf(lp1), 1_000_000e6);
        assertEq(pool.balanceOf(lp2), 1_000_000e6);

        // Fund a new loan
        loan = fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(5 days), uint256(30 days), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e18), uint256(0.05e18), uint256(0), uint256(0)]
        });

        uint256 annualLoanInterest = 1_000_000e6 * 0.031536e18 * 0.9e6 / 1e6 / 1e18 ;  // Note: 10% of interest is paid in fees

        uint256 dailyLoanInterest = annualLoanInterest * 1 days / 365 days;

        uint256 issuanceRate = (dailyLoanInterest * 30) * 1e30 / 30 days;

        assertEq(annualLoanInterest, 28382.4e6);
        assertEq(dailyLoanInterest,  77.76e6);
        assertEq(issuanceRate,       900e30);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          issuanceRate,
            domainStart:           start,
            domainEnd:             start + 30 days,
            unrealizedLosses:      0
        });

        assertWithdrawalManagerState({
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

        vm.prank(lp1);
        pool.requestRedeem(1_000_000e6, lp1);

        assertEq(pool.balanceOf(lp1), 0);

        assertWithdrawalManagerState({
            lp:                           lp1,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      1_000_000e6,
            withdrawalManagerTotalShares: 1_000_000e6
        });

        assertWithdrawalManagerState({
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

        vm.prank(lp2);
        pool.requestRedeem(1_000_000e6, lp2);

        assertEq(pool.balanceOf(lp2), 0);

        assertWithdrawalManagerState({
            lp:                           lp2,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      2_000_000e6,
            withdrawalManagerTotalShares: 2_000_000e6
        });

        // Update the WM config
        vm.prank(poolDelegate);
        withdrawalManager.setExitConfig(3 days, 1 days);

        // Warp to withdraw window
        vm.warp(start + 2 weeks + 1 days);

        uint256 loanInterestAccrued = 15 * dailyLoanInterest;

        assertPoolState({
            totalSupply:        2_000_000e6,
            totalAssets:        2_000_000e6 + loanInterestAccrued,
            unrealizedLosses:   0,
            availableLiquidity: 1_000_000e6
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 1.000583e6);

        // Impair the loan
        vm.prank(poolDelegate);
        poolManager.impairLoan(address(loan));

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     loanInterestAccrued,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + loanInterestAccrued,
            issuanceRate:          0,
            domainStart:           block.timestamp,
            domainEnd:             block.timestamp,
            unrealizedLosses:      1_000_000e6 + loanInterestAccrued
        });

        assertPoolState({
            totalSupply:        2_000_000e6,
            totalAssets:        2_000_000e6 + loanInterestAccrued,
            unrealizedLosses:   1_000_000e6 + loanInterestAccrued,
            availableLiquidity: 1_000_000e6
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 0.5e6);

        vm.prank(lp1);
        pool.redeem(1_000_000e6, lp1, lp1);

        assertEq(pool.balanceOf(lp1), 0);

        assertWithdrawalManagerState({
            lp:                           lp2,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      1_000_000e6,
            withdrawalManagerTotalShares: 1_000_000e6
        });

        assertEq(fundsAsset.balanceOf(lp1), 500_000e6);

        // Remove Impairment
        vm.prank(poolDelegate);
        poolManager.removeLoanImpairment(address(loan));

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     loanInterestAccrued,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + loanInterestAccrued,
            issuanceRate:          issuanceRate,
            domainStart:           block.timestamp,
            domainEnd:             start + 30 days,
            unrealizedLosses:      0
        });

        assertPoolState({
            totalSupply:        1_000_000e6,
            totalAssets:        1_500_000e6 + loanInterestAccrued,
            unrealizedLosses:   0,
            availableLiquidity: 500_000e6
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 1.501166e6);

        // Forward further into the withdraw window
        vm.warp(start + 2 weeks + 2 days - 1 seconds);

        vm.prank(lp2);
        pool.redeem(1_000_000e6, lp2, lp2);

        assertEq(pool.balanceOf(lp2), 0);

        loanInterestAccrued = (16 days - 1 seconds) * annualLoanInterest / 365 days;

        assertEq(loanInterestAccrued, 1_244.159100e6);

        // LP2 gets pro rata amount due to partial liquidity
        // Liquidity in pool: 500_000e6
        // Accrued Interest: 1_244.159100e6
        // Proportion LP2 entitled to: 500_000e6 / (1_500_000e6 + 1_244.159100e6) = ~0.33
        // Shares remaining after pro rata burn: 1_000_000e6 - (1_000_000e6 * (500_000e6 / (1_500_000e6 + 1_244.159100e6))) = 666_942.917333e6

        uint256 lp2RemainingShares = 1_000_000e6 - (uint256(1_000_000e6) * (500_000e6 * 1e18 / (uint256(1_500_000e6) + loanInterestAccrued)) / 1e18);

        assertWithinDiff(lp2RemainingShares, 666_942.917333e6, 1);

        assertWithdrawalManagerState({
            lp:                           lp2,
            lockedShares:                 666_942.917334e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           4,
            currentCycleTotalShares:      666_942.917334e6,
            withdrawalManagerTotalShares: 666_942.917334e6
        });

        assertEq(fundsAsset.balanceOf(lp1), 500_000e6);

        assertWithinDiff(fundsAsset.balanceOf(lp2), 500_000e6, 1);

        assertPoolState({
            totalSupply:        666_942.917334e6,
            totalAssets:        1_000_000e6 + loanInterestAccrued + 1,
            unrealizedLosses:   0,
            availableLiquidity: 1  // NOTE: Dust due to rounding above
        });
    }

    function test_scenario_impairLoanAndRedeem_startLiquidationAndRedeem_finishLiquidationAndRedeem() external {
        // 3 LPs deposit
        depositLiquidity(lp1, 1_000_000e6);
        depositLiquidity(lp2, 1_000_000e6);
        depositLiquidity(lp3, 1_000_000e6);

        assertEq(pool.balanceOf(lp1), 1_000_000e6);
        assertEq(pool.balanceOf(lp2), 1_000_000e6);
        assertEq(pool.balanceOf(lp3), 1_000_000e6);

        // Fund a new loan
        loan = fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(0), uint256(30 days), uint256(3)],
            amounts:     [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e18), uint256(0.05e18), uint256(0), uint256(0)]
        });

        uint256 annualLoanInterest = 1_000_000e6 * 0.031536e18 * 0.9e6 / 1e6 / 1e18 ;  // Note: 10% of interest is paid in fees

        uint256 dailyLoanInterest = annualLoanInterest * 1 days / 365 days;

        uint256 issuanceRate = (dailyLoanInterest * 30) * 1e30 / 30 days;

        assertEq(annualLoanInterest, 28382.4e6);
        assertEq(dailyLoanInterest,  77.76e6);
        assertEq(issuanceRate,       900e30);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6,
            issuanceRate:          issuanceRate,
            domainStart:           start,
            domainEnd:             start + 30 days,
            unrealizedLosses:      0
        });

        assertWithdrawalManagerState({
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

        vm.prank(lp1);
        pool.requestRedeem(1_000_000e6, lp1);

        assertEq(pool.balanceOf(lp1), 0);

        assertWithdrawalManagerState({
            lp:                           lp1,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      1_000_000e6,
            withdrawalManagerTotalShares: 1_000_000e6
        });

        assertWithdrawalManagerState({
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

        vm.prank(lp2);
        pool.requestRedeem(1_000_000e6, lp2);

        assertEq(pool.balanceOf(lp2), 0);

        assertWithdrawalManagerState({
            lp:                           lp2,
            lockedShares:                 1_000_000e6,
            previousExitCycleId:          0,
            previousCycleTotalShares:     0,
            currentExitCycleId:           3,
            currentCycleTotalShares:      2_000_000e6,
            withdrawalManagerTotalShares: 2_000_000e6
        });

        assertWithdrawalManagerState({
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

        vm.prank(lp3);
        pool.requestRedeem(1_000_000e6, lp3);

        assertEq(pool.balanceOf(lp3), 0);

        assertWithdrawalManagerState({
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
            totalSupply:        3_000_000e6,
            totalAssets:        3_000_000e6 + loanInterestAccrued,
            unrealizedLosses:   0,
            availableLiquidity: 2_000_000e6
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 1.000388e6);

        // Impair the loan
        vm.prank(poolDelegate);
        poolManager.impairLoan(address(loan));

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     loanInterestAccrued,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + loanInterestAccrued,
            issuanceRate:          0,
            domainStart:           block.timestamp,
            domainEnd:             block.timestamp,
            unrealizedLosses:      1_000_000e6 + loanInterestAccrued
        });

        assertPoolState({
            totalSupply:        3_000_000e6,
            totalAssets:        3_000_000e6 + loanInterestAccrued,
            unrealizedLosses:   1_000_000e6 + loanInterestAccrued,
            availableLiquidity: 2_000_000e6
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 0.666666e6);

        // Withdraw LP1
        vm.warp(start + 2 weeks + 1 days);

        vm.prank(lp1);
        pool.redeem(1_000_000e6, lp1, lp1);

        assertEq(pool.balanceOf(lp1), 0);

        assertWithdrawalManagerState({
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
            totalSupply:        2_000_000e6,
            totalAssets:        3_000_000e6 + loanInterestAccrued - fundsAsset.balanceOf(lp1),
            unrealizedLosses:   1_000_000e6 + loanInterestAccrued,
            availableLiquidity: 2_000_000e6 - fundsAsset.balanceOf(lp1)
        });

        // Warp 12 hours and default
        vm.warp(start + 2 weeks + 1 days + 12 hours);

        vm.prank(poolDelegate);
        poolManager.triggerDefault(address(loan), address(liquidatorFactory));

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     loanInterestAccrued,
            principalOut:          1_000_000e6,
            assetsUnderManagement: 1_000_000e6 + loanInterestAccrued,
            issuanceRate:          0,
            domainStart:           block.timestamp,
            domainEnd:             block.timestamp,
            unrealizedLosses:      1_000_000e6 + loanInterestAccrued
        });

        assertPoolState({
            totalSupply:        2_000_000e6,
            totalAssets:        3_000_000e6 + loanInterestAccrued - fundsAsset.balanceOf(lp1),
            unrealizedLosses:   1_000_000e6 + loanInterestAccrued,
            availableLiquidity: 2_000_000e6 - fundsAsset.balanceOf(lp1)
        });

        assertEq((pool.totalAssets() - pool.unrealizedLosses()) * 1e6 / pool.totalSupply(), 0.666666e6);

        // LP2 to redeem
        vm.prank(lp2);
        pool.redeem(1_000_000e6, lp2, lp2);

        assertEq(pool.balanceOf(lp2), 0);

        assertWithdrawalManagerState({
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
        // Platform management fees pro rata: 207.36e6 ~ (15 days / 30 days) = 103.68e6 (If no late interest then just pro rata based on payment)
        // Platform service fees: 0.31536 * 1_000_000 * ( 30 / 365 days )= 25_920e6
        // Platform fees from liquidation: 25_920e6 + 103.68e6 = 26_023.68e6
        // Funds added to pool from liquidation: 150_000e6 - 26_023.68e6 = 123_976.32e6

        uint256 grossInterestPerInstallment = (1_000_000e6 * 0.031536e18 / 1e18) * (30 days / 365 days);
        uint256 platformManagementFee       = (2592e6 * 0.08e6 / 1e6) * (15 days / 30 days);  // Loan impaired 15 days in
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

        vm.prank(poolDelegate);
        poolManager.finishCollateralLiquidation(address(loan));

        uint256 poolBalanceAfterLiquidation           = fundsAsset.balanceOf(address(pool));
        uint256 expectedAssetsReturnedFromLiquidation = 123_976.32e6;

        assertEq(poolBalanceAfterLiquidation - poolBalanceBeforeLiquidation, expectedAssetsReturnedFromLiquidation);

        assertLoanManager({
            accruedInterest:       0,
            accountedInterest:     0,
            principalOut:          0,
            assetsUnderManagement: 0,
            issuanceRate:          0,
            domainStart:           block.timestamp,
            domainEnd:             block.timestamp,
            unrealizedLosses:      0
        });

        assertPoolState({
            totalSupply:        1_000_000e6,
            totalAssets:        2_000_000e6 - fundsAsset.balanceOf(lp1) - fundsAsset.balanceOf(lp2) + expectedAssetsReturnedFromLiquidation,
            unrealizedLosses:   0,
            availableLiquidity: 2_000_000e6 - fundsAsset.balanceOf(lp1) - fundsAsset.balanceOf(lp2) + expectedAssetsReturnedFromLiquidation
        });

        // Expected totalAssets: 666_666.666667e6 + 123_976.32e6 = 790_642.986667e6
        assertEq(fundsAsset.balanceOf(address(pool)), 790_642.986667e6);

        vm.prank(lp3);
        pool.redeem(1_000_000e6, lp3, lp3);

        assertEq(pool.balanceOf(lp3), 0);

        assertWithdrawalManagerState({
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
            totalSupply:        0,
            totalAssets:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });
    }

}
