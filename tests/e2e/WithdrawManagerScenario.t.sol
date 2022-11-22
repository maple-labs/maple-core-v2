// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestBaseWithAssertions } from "../../contracts/utilities/TestBaseWithAssertions.sol";

import { Address, console } from "../../modules/contract-test-utils/contracts/test.sol";

import { MapleLoan as Loan } from "../../modules/loan-v401/contracts/MapleLoan.sol";
import { Refinancer }        from "../../modules/loan-v401/contracts/Refinancer.sol";

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

}
