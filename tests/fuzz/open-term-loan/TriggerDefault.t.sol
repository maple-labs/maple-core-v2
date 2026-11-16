// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IOpenTermLoan,
    IOpenTermLoanManager,
    IOpenTermLoanManagerStructs,
    IPool,
    IPoolManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { FuzzedSetup } from "../FuzzedSetup.sol";
import { StorageSnapshot } from "../StorageSnapshot.sol";

contract TriggerDefaultFuzzTests is FuzzedSetup, StorageSnapshot {

    uint256 constant ACTION_COUNT   = 10;
    uint256 constant OTL_LOAN_COUNT = 10;

    // Saving balances to storage to avoid stack too deep.
    uint256 borrowerBalance;
    uint256 pdBalance;
    uint256 poolBalance;
    uint256 treasuryBalance;

    // Transfer Amounts
    uint256 toBorrower;
    uint256 toPool;
    uint256 toTreasury;

    // Payment information
    uint256 interest_;
    uint256 lateInterest_;
    uint256 platformServiceFee_;

    // The fuzzed setup should set this at the end.
    IOpenTermLoan loan;
    IOpenTermLoanManager loanManager;

    // Saving snapshots to storage to avoid stack too deep errors.
    OpenTermLoanManagerStorage loanManagerStorage;
    OpenTermLoanStorage loanStorage;
    OpenTermPaymentStorage paymentStorage;
    PoolManagerStorage poolManagerStorage;

    function testFuzz_otlFuzzedSetup_triggerDefault(uint256 seed_) external {
        fuzzedSetup(OTL_LOAN_COUNT, ACTION_COUNT, 0, 0, 0, seed_);

        loan = IOpenTermLoan(getSomeActiveOpenTermLoan());

        // Do nothing if no loan is available.
        if (address(loan) == address(0)) return;

        loanManager = IOpenTermLoanManager(loan.lender());

        // Assertions are performed against the pool that funded the loan.
        poolManager = IPoolManager(loanManager.poolManager());
        pool        = IPool(poolManager.pool());

        if (loan.dateFunded() == 0) return; // Loan not funded or repossessed in which case we can't trigger default

        // No assumption on what block.timestamp is after fuzz setup
        if (block.timestamp <= loan.defaultDate()) vm.warp(loan.defaultDate() + 1); // Warp to default date

        // Save to storage before change
        loanManagerStorage = _snapshotOpenTermLoanManager(address(loanManager));
        loanStorage        = _snapshotOpenTermLoan(address(loan));
        paymentStorage     = _snapshotOpenTermPayment(address(loan));
        poolManagerStorage = _snapshotPoolManager(address(poolManager));

        (uint256 impairDate,) = IOpenTermLoanManager(loan.lender()).impairmentFor(address(loan));

        bool isImpaired = impairDate > 0;

        (, // Unused
            interest_,
            lateInterest_,, // Unused
            platformServiceFee_
        ) = loan.getPaymentBreakdown(isImpaired ? impairDate : block.timestamp);

        // Save Balances
        borrowerBalance = fundsAsset.balanceOf(loan.borrower());
        pdBalance       = fundsAsset.balanceOf(address(poolManager.poolDelegate()));
        poolBalance     = fundsAsset.balanceOf(address(pool));
        treasuryBalance = fundsAsset.balanceOf(address(treasury));

        // Save Loan info as this gets cleared on default
        IOpenTermLoanManagerStructs.Payment memory loanInfo = IOpenTermLoanManagerStructs(loan.lender()).paymentFor(address(loan));

        // Perform the action
        vm.prank(poolManager.poolDelegate());
        poolManager.triggerDefault(address(loan));

        // Assert Values
        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      0,
            dateFunded:      0,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       0
        });

        uint256 netInterest = interest_ - (interest_ * (loanInfo.delegateManagementFeeRate + loanInfo.platformManagementFeeRate)) / 1e6;

        // If loan contains funds these get repossessed
        (toBorrower, toTreasury, toPool) = _calculateLiquidationDistribution(
            loanStorage.previousPrincipal,
            interest_ + lateInterest_,
            platformServiceFee_,
            loanStorage.previousFundsAssetBalance,
            loanInfo.platformManagementFeeRate,
            loanInfo.delegateManagementFeeRate
        );

        assertOpenTermLoanManagerWithDiff({
            loanManager: address(loanManager),
            accountedInterest: _subtractWithDiff(
                loanManagerStorage.previousAccountedInterest + loanManagerStorage.previousAccruedInterest, netInterest, 3
            ),
            accruedInterest: 0,
            domainStart: block.timestamp,
            issuanceRate: // If a loan has previously been impaired, the issuance rate should not change
            isImpaired
                ? loanManagerStorage.previousIssuanceRate
                : loanManagerStorage.previousIssuanceRate - paymentStorage.previousIssuanceRate,
            principalOut: loanManagerStorage.previousPrincipalOut - loanStorage.previousPrincipal,
            unrealizedLosses: // To account for multiple loans being impaired in the system including the main loan
            isImpaired
                ? _subtractWithDiff(loanManagerStorage.previousUnrealizedLosses, loanStorage.previousPrincipal + netInterest, 3)
                : loanManagerStorage.previousUnrealizedLosses,
            diff: 3
        });

        assertPoolStateWithDiff({
            pool: address(pool),
            totalAssets: _subtractWithDiff(poolManagerStorage.previousTotalAssets + toPool, loanStorage.previousPrincipal + netInterest, 3),
            totalSupply: poolManagerStorage.previousTotalSupply,
            unrealizedLosses: // To account for multiple loans being impaired in the system including the main loan
            isImpaired
                ? _subtractWithDiff(poolManagerStorage.previousUnrealizedLosses, loanStorage.previousPrincipal + netInterest, 3)
                : poolManagerStorage.previousUnrealizedLosses,
            availableLiquidity: poolManagerStorage.previousFundsAssetBalance + toPool,
            diff: 3
        });

        assertEq(fundsAsset.balanceOf(loan.borrower()),                     borrowerBalance + toBorrower);
        assertEq(fundsAsset.balanceOf(address(pool)),                       poolBalance + toPool);
        assertEq(fundsAsset.balanceOf(address(treasury)),                   treasuryBalance + toTreasury);
        assertEq(fundsAsset.balanceOf(address(poolManager.poolDelegate())), pdBalance);
    }

    function _calculateLiquidationDistribution(
        uint256 principal,
        uint256 interest,
        uint256 platformServiceFee,
        uint256 recoveredFunds,
        uint256 platformManagementFeeRate,
        uint256 delegateManagementFeeRate
    )
        internal
        pure
        returns (uint256 toBorrower_, uint256 toTreasury_, uint256 toPool_)
    {
        uint256 delegateManagementFee_ = _getRatedAmount(interest, delegateManagementFeeRate);
        uint256 platformManagementFee_ = _getRatedAmount(interest, platformManagementFeeRate);

        uint256 netInterest_ = interest - (platformManagementFee_ + delegateManagementFee_);
        uint256 platformFee_ = platformServiceFee + platformManagementFee_;

        toTreasury_ = _min(recoveredFunds, platformFee_);
        toPool_     = _min(recoveredFunds - toTreasury_, principal + netInterest_);

        toBorrower_ = recoveredFunds - toTreasury_ - toPool_;
    }

    function _getRatedAmount(uint256 amount_, uint256 rate_) internal pure returns (uint256 ratedAmount_) {
        ratedAmount_ = (amount_ * rate_) / 1e6;
    }

    function _min(uint256 a_, uint256 b_) internal pure returns (uint256 minimum_) {
        minimum_ = a_ < b_ ? a_ : b_;
    }

    function _subtractWithDiff(uint256 a_, uint256 b_, uint256 diff_) internal pure returns (uint256 result_) {
        result_ = a_ >= b_ ? a_ - b_ : b_ - a_;

        if (a_ >= b_) return result_;

        require(result_ <= diff_, "SWD: Diff exceeded");
    }

}
