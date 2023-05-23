// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console2 } from "../../modules/forge-std/src/console2.sol";

import { IOpenTermLoan, IOpenTermLoanManager, IOpenTermLoanManagerStructs } from "../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

import { FuzzedSetup }     from "./FuzzedSetup.sol";
import { StorageSnapshot } from "./StorageSnapshot.sol";

contract OpenTermLoanFuzz is FuzzedSetup, StorageSnapshot {

    uint256 constant ACTION_COUNT   = 10;
    uint256 constant FTL_LOAN_COUNT = 1;
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
    uint256 delegateServiceFee_;
    uint256 interest_;
    uint256 lateInterest_;
    uint256 platformServiceFee_;
    uint256 principal_;

    // The fuzzed setup should set this at the end.
    IOpenTermLoan        loan;
    IOpenTermLoanManager loanManager;

    // Saving snapshots to storage to avoid stack too deep errors.
    OpenTermLoanManagerStorage loanManagerStorage;
    OpenTermLoanStorage        loanStorage;
    OpenTermPaymentStorage     paymentStorage;
    PoolManagerStorage         poolManagerStorage;

    function testFuzz_otlFuzzedSetup_makePayment(uint256 seed_) external {
        fuzzedSetup(FTL_LOAN_COUNT, OTL_LOAN_COUNT, ACTION_COUNT, seed_);

        loan        = IOpenTermLoan(getSomeActiveOpenTermLoan());
        loanManager = IOpenTermLoanManager(loan.lender());

        // Save to storage before change
        loanManagerStorage = _snapshotOpenTermLoanManager(loanManager);
        loanStorage        = _snapshotOpenTermLoan(loan);
        paymentStorage     = _snapshotOpenTermPayment(loan);
        poolManagerStorage = _snapshotPoolManager(poolManager);

        // Save Balances
        borrowerBalance = fundsAsset.balanceOf(loan.borrower());
        pdBalance       = fundsAsset.balanceOf(address(poolManager.poolDelegate()));
        poolBalance     = fundsAsset.balanceOf(address(pool));
        treasuryBalance = fundsAsset.balanceOf(address(treasury));

        ( principal_, interest_, lateInterest_, delegateServiceFee_, platformServiceFee_ ) = loan.getPaymentBreakdown(block.timestamp);

        uint256 totalPayment = principal_ + interest_ + lateInterest_ + delegateServiceFee_ + platformServiceFee_;
        uint256 datePaid     = loan.datePaid();
        uint256 dateFunded   = loan.dateFunded();

        ( uint256 dateImpaired, ) = loanManager.impairmentFor(address(loan));

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

        uint256 managementFeeRate = loanInfo.delegateManagementFeeRate + loanInfo.platformManagementFeeRate;
        uint256 netInterest       = (interest_ + lateInterest_) - ((interest_ + lateInterest_) * managementFeeRate / 1e6);

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
                totalAssets:        poolManagerStorage.previousTotalAssets + netInterest - accruedUpToImpairment,
                totalSupply:        poolManagerStorage.previousTotalSupply,
                unrealizedLosses:   poolManagerStorage.previousUnrealizedLosses - (loanStorage.previousPrincipal + accruedUpToImpairment),
                availableLiquidity: poolManagerStorage.previousFundsAssetBalance + netInterest + principal_,
                diff:               3
            });
        } else {
            uint256 netOnTimeInterest = interest_ - (interest_ * (managementFeeRate)) / 1e6;

            uint256 accountedInterest = _subtractWithDiff(
                loanManagerStorage.previousAccountedInterest + loanManagerStorage.previousAccruedInterest,
                netOnTimeInterest,
                5
            );

            assertOpenTermLoanManagerWithDiff({
                loanManager:       address(loanManager),
                accountedInterest: accountedInterest,
                accruedInterest:   0,
                domainStart:       block.timestamp,
                issuanceRate:      loanManagerStorage.previousIssuanceRate + loanInfo.issuanceRate - paymentStorage.previousIssuanceRate,
                principalOut:      loanManagerStorage.previousPrincipalOut - principal_,
                unrealizedLosses:  loanManagerStorage.previousUnrealizedLosses,
                diff:              3
            });

            assertPoolStateWithDiff({
                totalAssets:        poolManagerStorage.previousTotalAssets + (netInterest - netOnTimeInterest),
                totalSupply:        poolManagerStorage.previousTotalSupply,
                unrealizedLosses:   poolManagerStorage.previousUnrealizedLosses,
                availableLiquidity: poolManagerStorage.previousFundsAssetBalance + netInterest + principal_,
                diff:               3
            });
        }

        uint256 delegateManagementFee = interest_ * loanInfo.platformManagementFeeRate / 1e6;
        uint256 treasuryManagementFee = interest_ * loanInfo.delegateManagementFeeRate / 1e6;

        assertEq(fundsAsset.balanceOf(loan.borrower()),                     borrowerBalance - totalPayment);
        assertEq(fundsAsset.balanceOf(address(pool)),                       poolBalance + netInterest + principal_);
        assertEq(fundsAsset.balanceOf(address(treasury)),                   treasuryBalance + treasuryManagementFee + platformServiceFee_);
        assertEq(fundsAsset.balanceOf(address(poolManager.poolDelegate())), pdBalance + delegateManagementFee + delegateServiceFee_);
    }

    function testFuzz_otlFuzzedSetup_triggerDefault(uint256 seed_) external {
        fuzzedSetup(FTL_LOAN_COUNT, OTL_LOAN_COUNT, ACTION_COUNT, seed_);

        loan        = IOpenTermLoan(getSomeActiveOpenTermLoan());
        loanManager = IOpenTermLoanManager(loan.lender());

        if (loan.dateFunded() == 0) return;  // Loan not funded or repossessed in which case we can't trigger default

        // No assumption on what block.timestamp is after fuzz setup
        if (block.timestamp <= loan.defaultDate()) vm.warp(loan.defaultDate() + 1);  // Warp to default date

        // Save to storage before change
        loanManagerStorage = _snapshotOpenTermLoanManager(loanManager);
        loanStorage        = _snapshotOpenTermLoan(loan);
        paymentStorage     = _snapshotOpenTermPayment(loan);
        poolManagerStorage = _snapshotPoolManager(poolManager);

        ( uint256 impairDate , ) = IOpenTermLoanManager(loan.lender()).impairmentFor(address(loan));

        bool isImpaired = impairDate > 0;

        (
            ,  // Unused
            interest_,
            lateInterest_,
            ,  // Unused
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
        poolManager.triggerDefault(address(loan), liquidatorFactory);

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
        ( toBorrower, toTreasury, toPool ) = _calculateLiquidationDistribution(
            loanStorage.previousPrincipal,
            interest_ + lateInterest_,
            platformServiceFee_,
            loanStorage.previousFundsAssetBalance,
            loanInfo.platformManagementFeeRate,
            loanInfo.delegateManagementFeeRate
        );

        assertOpenTermLoanManagerWithDiff({
            loanManager:       address(loanManager),
            accountedInterest: _subtractWithDiff(
                                   loanManagerStorage.previousAccountedInterest + loanManagerStorage.previousAccruedInterest,
                                   netInterest,
                                   3
                               ),
            accruedInterest:   0,
            domainStart:       block.timestamp,
            issuanceRate:      isImpaired  // If a loan has previously been impaired, the issuance rate should not change
                                    ? loanManagerStorage.previousIssuanceRate
                                    : loanManagerStorage.previousIssuanceRate - paymentStorage.previousIssuanceRate,
            principalOut:      loanManagerStorage.previousPrincipalOut - loanStorage.previousPrincipal,
            unrealizedLosses:  isImpaired  // To account for multiple loans being impaired in the system including the main loan
                                    ? _subtractWithDiff(
                                          loanManagerStorage.previousUnrealizedLosses,
                                          loanStorage.previousPrincipal + netInterest,
                                          3
                                      )
                                    : loanManagerStorage.previousUnrealizedLosses,
            diff:               3
        });

        assertPoolStateWithDiff({
            totalAssets:        _subtractWithDiff(
                                    poolManagerStorage.previousTotalAssets + toPool,
                                    loanStorage.previousPrincipal + netInterest,
                                    3
                                ),
            totalSupply:        poolManagerStorage.previousTotalSupply,
            unrealizedLosses:   isImpaired  // To account for multiple loans being impaired in the system including the main loan
                                    ? _subtractWithDiff(
                                          poolManagerStorage.previousUnrealizedLosses,
                                          loanStorage.previousPrincipal + netInterest,
                                          3
                                      )
                                    : poolManagerStorage.previousUnrealizedLosses,
            availableLiquidity: poolManagerStorage.previousFundsAssetBalance + toPool,
            diff:               3
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
        internal pure returns (uint256 toBorrower_, uint256 toTreasury_, uint256 toPool_)
    {
        uint256 delegateManagementFee_ = _getRatedAmount(interest, delegateManagementFeeRate);
        uint256 platformManagementFee_ = _getRatedAmount(interest, platformManagementFeeRate);

        uint256 netInterest_ = interest - (platformManagementFee_ + delegateManagementFee_);
        uint256 platformFee_ = platformServiceFee + platformManagementFee_;

        toTreasury_ = _min(recoveredFunds,               platformFee_);
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

        if (result_ <= diff_) {
            console2.log("left ", a_);
            console2.log("right", b_);
        }

        require(result_ <= diff_, "SWD: Diff exceeded");
    }

}
