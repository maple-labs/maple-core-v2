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

contract MakePaymentFuzzTests is FuzzedSetup, StorageSnapshot {

    uint256 constant ACTION_COUNT   = 10;
    uint256 constant OTL_LOAN_COUNT = 10;

    // Saving balances to storage to avoid stack too deep.
    uint256 borrowerBalance;
    uint256 pdBalance;
    uint256 poolBalance;
    uint256 treasuryBalance;

    // Payment information
    uint256 delegateServiceFee_;
    uint256 interest_;
    uint256 lateInterest_;
    uint256 platformServiceFee_;
    uint256 principal_;

    // The fuzzed setup should set this at the end.
    IOpenTermLoan loan;
    IOpenTermLoanManager loanManager;

    // Saving snapshots to storage to avoid stack too deep errors.
    OpenTermLoanManagerStorage loanManagerStorage;
    OpenTermLoanStorage loanStorage;
    OpenTermPaymentStorage paymentStorage;
    PoolManagerStorage poolManagerStorage;

    function testFuzz_otlFuzzedSetup_makePayment(uint256 seed_) external {
        fuzzedSetup(OTL_LOAN_COUNT, ACTION_COUNT, 0, 0, 0, seed_);

        loan = IOpenTermLoan(getSomeActiveOpenTermLoan());

        // Do nothing if no loan is available.
        if (address(loan) == address(0)) return;

        loanManager = IOpenTermLoanManager(loan.lender());

        // Assertions are performed against the pool that funded the loan.
        poolManager = IPoolManager(loanManager.poolManager());
        pool        = IPool(poolManager.pool());

        // Save to storage before change
        loanManagerStorage = _snapshotOpenTermLoanManager(address(loanManager));
        loanStorage        = _snapshotOpenTermLoan(address(loan));
        paymentStorage     = _snapshotOpenTermPayment(address(loan));
        poolManagerStorage = _snapshotPoolManager(address(poolManager));

        // Save Balances
        borrowerBalance = fundsAsset.balanceOf(loan.borrower());
        pdBalance       = fundsAsset.balanceOf(address(poolManager.poolDelegate()));
        poolBalance     = fundsAsset.balanceOf(address(pool));
        treasuryBalance = fundsAsset.balanceOf(address(treasury));

        (principal_, interest_, lateInterest_, delegateServiceFee_, platformServiceFee_) = loan.getPaymentBreakdown(block.timestamp);

        uint256 totalPayment = principal_ + interest_ + lateInterest_ + delegateServiceFee_ + platformServiceFee_;
        uint256 datePaid     = loan.datePaid();
        uint256 dateFunded   = loan.dateFunded();

        (uint256 dateImpaired,) = loanManager.impairmentFor(address(loan));

        erc20_approve(address(fundsAsset), loan.borrower(), address(loan), totalPayment);

        vm.prank(loan.borrower());
        IOpenTermLoan(loan).makePayment(principal_);

        // Assert Values
        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      0,
            dateFunded:      loanStorage.previousDateFunded,
            dateImpaired:    0,
            datePaid:        block.timestamp,
            calledPrincipal: 0,
            principal:       loanStorage.previousPrincipal - loanStorage.previousCalledPrincipal
        });

        IOpenTermLoanManagerStructs.Payment memory loanInfo = IOpenTermLoanManagerStructs(loan.lender()).paymentFor(address(loan));

        uint256 totalInterest = interest_ + lateInterest_;

        uint256 delegateManagementFee = totalInterest * loanInfo.delegateManagementFeeRate / 1e6;
        uint256 platformManagementFee = totalInterest * loanInfo.platformManagementFeeRate / 1e6;

        uint256 netInterest = totalInterest - delegateManagementFee - platformManagementFee;

        if (dateImpaired > 0) {
            uint256 accruedUpToImpairment =
                paymentStorage.previousIssuanceRate * (dateImpaired - (datePaid == 0 ? dateFunded : datePaid)) / 1e27;

            uint256 totalAccruedInterest =
                loanManagerStorage.previousIssuanceRate * (block.timestamp - loanManagerStorage.previousDomainStart) / 1e27;

            assertOpenTermLoanManagerWithDiff({
                loanManager:       address(loanManager),
                accountedInterest: loanManagerStorage.previousAccountedInterest + totalAccruedInterest - accruedUpToImpairment,
                accruedInterest:   0,
                domainStart:       block.timestamp,
                issuanceRate:      loanManagerStorage.previousIssuanceRate + loanInfo.issuanceRate,
                principalOut:      loanManagerStorage.previousPrincipalOut - principal_,
                unrealizedLosses:  loanManagerStorage.previousUnrealizedLosses - (loanStorage.previousPrincipal + accruedUpToImpairment),
                diff:              3
            });

            assertPoolStateWithDiff({
                pool:               address(pool),
                totalAssets:        poolManagerStorage.previousTotalAssets + netInterest - accruedUpToImpairment,
                totalSupply:        poolManagerStorage.previousTotalSupply,
                unrealizedLosses:   poolManagerStorage.previousUnrealizedLosses - (loanStorage.previousPrincipal + accruedUpToImpairment),
                availableLiquidity: poolManagerStorage.previousFundsAssetBalance + netInterest + principal_,
                diff:               3
            });
        } else {
            uint256 netOnTimeInterest =
                interest_ - (interest_ * loanInfo.delegateManagementFeeRate / 1e6) - (interest_ * loanInfo.platformManagementFeeRate / 1e6);

            uint256 accountedInterest = _subtractWithDiff(
                loanManagerStorage.previousAccountedInterest + loanManagerStorage.previousAccruedInterest, netOnTimeInterest, 5
            );

            // TODO: try to find out whether is is possible to come up with more narrow diff programmatically
            assertOpenTermLoanManagerWithDiff({
                loanManager:       address(loanManager),
                accountedInterest: accountedInterest,
                accruedInterest:   0,
                domainStart:       block.timestamp,
                issuanceRate:      loanManagerStorage.previousIssuanceRate + loanInfo.issuanceRate - paymentStorage.previousIssuanceRate,
                principalOut:      loanManagerStorage.previousPrincipalOut - principal_,
                unrealizedLosses:  loanManagerStorage.previousUnrealizedLosses,
                diff:              4
            });

            assertPoolStateWithDiff({
                pool:               address(pool),
                totalAssets:        poolManagerStorage.previousTotalAssets + (netInterest - netOnTimeInterest),
                totalSupply:        poolManagerStorage.previousTotalSupply,
                unrealizedLosses:   poolManagerStorage.previousUnrealizedLosses,
                availableLiquidity: poolManagerStorage.previousFundsAssetBalance + netInterest + principal_,
                diff:               4
            });
        }

        assertEq(fundsAsset.balanceOf(loan.borrower()),                     borrowerBalance - totalPayment);
        assertEq(fundsAsset.balanceOf(address(pool)),                       poolBalance + netInterest + principal_);
        assertEq(fundsAsset.balanceOf(address(treasury)),                   treasuryBalance + platformManagementFee + platformServiceFee_);
        assertEq(fundsAsset.balanceOf(address(poolManager.poolDelegate())), pdBalance + delegateManagementFee + delegateServiceFee_);
    }

    function _subtractWithDiff(uint256 a_, uint256 b_, uint256 diff_) internal pure returns (uint256 result_) {
        result_ = a_ >= b_ ? a_ - b_ : b_ - a_;

        if (a_ >= b_) return result_;

        require(result_ <= diff_, "SWD: Diff exceeded");
    }

}
