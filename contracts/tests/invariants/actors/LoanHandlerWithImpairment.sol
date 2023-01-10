// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IMapleGlobals } from "../../../../modules/globals-v2/contracts/interfaces/IMapleGlobals.sol";
import { IMapleLoan }    from "../../../../modules/loan-v400/contracts/interfaces/IMapleLoan.sol";
import { ILiquidator }   from "../../../../modules/liquidations/contracts/interfaces/ILiquidator.sol";

import { LoanHandler } from "./LoanHandler.sol";

contract LoanHandlerWithImpairment is LoanHandler {

    uint256 public unrealizedLosses;

    mapping (address => bool) public loanImpaired;

    constructor (
        address collateralAsset_,
        address feeManager_,
        address fundsAsset_,
        address globals_,
        address governor_,
        address loanFactory_,
        address poolManager_,
        address testContract_,
        uint256 numBorrowers_,
        uint256 maxLoans_
    ) LoanHandler(
        collateralAsset_,
        feeManager_,
        fundsAsset_,
        globals_,
        governor_,
        loanFactory_,
        poolManager_,
        testContract_,
        numBorrowers_,
        maxLoans_
    ) {}

    function makePayment(uint256 borrowerIndexSeed_, uint256 loanIndexSeed_) public override useTimestamps {
        numCalls++;

        if (activeLoans.length == 0) return;

        uint256 loanIndex_ = constrictToRange(loanIndexSeed_, 0, activeLoans.length - 1);

        address borrower_ = borrowers[constrictToRange(borrowerIndexSeed_, 0, numBorrowers - 1)];

        vm.startPrank(borrower_);

        IMapleLoan loan_ = IMapleLoan(activeLoans[loanIndex_]);

        uint256 previousPaymentDueDate = loan_.nextPaymentDueDate();

        ( uint256 principal_, uint256 interest_, uint256 fees_ ) = loan_.getNextPaymentBreakdown();

        uint256 amount_ = principal_ + interest_ + fees_;

        fundsAsset.mint(borrower_, amount_);
        fundsAsset.approve(address(loan_), amount_);

        if (!loan_.isImpaired()) {
            ( , , , , , , uint256 issuanceRate_ ) = loanManager.payments(loanManager.paymentIdOf(address(loan_)));
            sum_loanManager_paymentIssuanceRate -= issuanceRate_;
        }

        sum_loan_principal -= loan_.principal();

        loan_.makePayment(amount_);

        numPayments++;

        vm.stopPrank();

        uint256 paymentWithEarliestDueDate = loanManager.paymentWithEarliestDueDate();

        if (paymentWithEarliestDueDate != 0) {
            ( , , earliestPaymentDueDate ) = loanManager.sortedPayments(loanManager.paymentWithEarliestDueDate());
        } else {
            earliestPaymentDueDate = block.timestamp;
        }

        require(earliestPaymentDueDate == loanManager.domainEnd(), "Not equal");

        if (loan_.paymentsRemaining() == 0) {
            activeLoans[loanIndex_] = activeLoans[activeLoans.length - 1];
            activeLoans.pop();
            numLoans--;
            numMatures++;
            return;
        }

        if (block.timestamp > previousPaymentDueDate) {
            numLatePayments++;
        }

        paymentTimestamp[address(loan_)] = block.timestamp;

        ( , interest_, ) = loan_.getNextPaymentBreakdown();

        uint256 issuanceRate;

        ( , , , , , , issuanceRate ) = loanManager.payments(loanManager.paymentIdOf(address(loan_)));

        sum_loan_principal                  += loan_.principal();
        sum_loanManager_paymentIssuanceRate += issuanceRate;

        unrealizedLosses = poolManager.unrealizedLosses();

        numberOfCalls["makePayment"]++;
    }

    function impairLoan(uint256 loanIndexSeed_) external useTimestamps {
        numCalls++;

        if (activeLoans.length == 0) return;

        uint256 loanIndex_ = constrictToRange(loanIndexSeed_, 0, activeLoans.length - 1);
        address loanAddress = activeLoans[loanIndex_];

        if (loanImpaired[loanAddress]) return;

        ( , , , , , , uint256 issuanceRate ) = loanManager.payments(loanManager.paymentIdOf(address(loanAddress)));

        sum_loanManager_paymentIssuanceRate -= issuanceRate;

        vm.prank(poolManager.poolDelegate());
        poolManager.impairLoan(loanAddress);

        unrealizedLosses       = poolManager.unrealizedLosses();
        earliestPaymentDueDate = block.timestamp;

        uint256 paymentWithEarliestDueDate = loanManager.paymentWithEarliestDueDate();

        if (paymentWithEarliestDueDate != 0) {
            ( , , earliestPaymentDueDate ) = loanManager.sortedPayments(loanManager.paymentWithEarliestDueDate());
        } else {
            earliestPaymentDueDate = block.timestamp;
        }

        loanImpaired[loanAddress] = true;

        numberOfCalls["impairLoan"]++;
    }

}
