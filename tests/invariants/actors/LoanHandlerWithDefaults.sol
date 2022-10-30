// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { console }       from "../../../modules/contract-test-utils/contracts/test.sol";
import { IMapleGlobals } from "../../../modules/globals-v2/contracts/interfaces/IMapleGlobals.sol";
import { IMapleLoan }    from "../../../modules/loan/contracts/interfaces/IMapleLoan.sol";
import { ILiquidator }   from "../../../modules/liquidations/contracts/interfaces/ILiquidator.sol";

import { LoanHandler } from "./LoanHandler.sol";

contract LoanHandlerWithDefaults is LoanHandler {

    address liquidatorFactory;

    // Losses value
    uint256 public numDefaults;
    uint256 public unrealizedLosses;

    mapping (address => bool) public loanDefaulted;

    constructor (
        address collateralAsset_,
        address feeManager_,
        address fundsAsset_,
        address globals_,
        address governor_,
        address loanFactory_,
        address liquidatorFactory_,
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
    ) {
        liquidatorFactory = liquidatorFactory_;
    }

    function makePayment(uint256 borrowerIndexSeed_, uint256 loanIndexSeed_) public override useTimestamps {
        if (activeLoans.length == 0) return;

        uint256 loanIndex_ = constrictToRange(loanIndexSeed_, 0, activeLoans.length - 1);

        if (loanDefaulted[activeLoans[loanIndex_]]) return; // Loan defaulted

        super.makePayment(borrowerIndexSeed_, loanIndexSeed_);
    }

    function triggerDefault(uint256 loanIndexSeed_) external useTimestamps {
        numCalls++;

        if (activeLoans.length == 0) return;

        uint256 loanIndex_  = constrictToRange(loanIndexSeed_, 0, activeLoans.length - 1);
        address loanAddress = activeLoans[loanIndex_];

        if (loanDefaulted[loanAddress]) return; // Loan already defaulted

        // Check loan can be defaulted
        uint256 nextPaymentDueDate_ = IMapleLoan(loanAddress).nextPaymentDueDate();
        uint256 gracePeriod_        = IMapleLoan(loanAddress).gracePeriod();

        if (block.timestamp <= nextPaymentDueDate_ + gracePeriod_) {
            vm.warp(nextPaymentDueDate_ + gracePeriod_ + 1);
        }

        // If loan isn't impaired account for update to issuance rate
        if (!IMapleLoan(loanAddress).isImpaired()) {
            ( , , , , , , uint256 issuanceRate ) = loanManager.payments(loanManager.paymentIdOf(address(loanAddress)));
            sum_loanManager_paymentIssuanceRate -= issuanceRate;
        }

        // Non-liquidating therefore update principal
        if (IMapleLoan(loanAddress).collateral() == 0 || IMapleLoan(loanAddress).collateralAsset() == address(fundsAsset)) {
            sum_loan_principal -= IMapleLoan(loanAddress).principal();
        }

        vm.prank(poolManager.poolDelegate());
        poolManager.triggerDefault(loanAddress, liquidatorFactory);

        numDefaults++;

        loanDefaulted[loanAddress] = true;

        unrealizedLosses = poolManager.unrealizedLosses();

        uint256 paymentWithEarliestDueDate = loanManager.paymentWithEarliestDueDate();

        if (paymentWithEarliestDueDate != 0) {
            ( , , earliestPaymentDueDate ) = loanManager.sortedPayments(loanManager.paymentWithEarliestDueDate());
        } else {
            earliestPaymentDueDate = block.timestamp;
        }

        numberOfCalls["triggerDefault"]++;
    }

    function finishCollateralLiquidation(uint256 loanIndexSeed_) external useTimestamps {
        numCalls++;

        if (activeLoans.length == 0) return;

        uint256 loanIndex_  = constrictToRange(loanIndexSeed_, 0, activeLoans.length - 1);
        address loanAddress = activeLoans[loanIndex_];

        // Check loan needs liquidation
        if(!loanManager.isLiquidationActive(loanAddress)) return;

        ( , uint256 principal_ , , , , address liquidator_ ) = loanManager.liquidationInfo(loanAddress);

        uint256 collateralAmount_ = collateralAsset.balanceOf(liquidator_);
        uint256 expectedAmount_   = ILiquidator(liquidator_).getExpectedAmount(collateralAmount_);

        // Mint fund asset to liquidator to mock strategy
        fundsAsset.mint(liquidator_, expectedAmount_);

        ILiquidator(liquidator_).liquidatePortion(collateralAmount_, expectedAmount_, bytes(""));

        vm.prank(poolManager.poolDelegate());
        poolManager.finishCollateralLiquidation(loanAddress);

        sum_loan_principal -= principal_; // Note: principalOut is updated during finishCollateralLiquidation
        unrealizedLosses    = poolManager.unrealizedLosses();

        uint256 paymentWithEarliestDueDate = loanManager.paymentWithEarliestDueDate();

        if (paymentWithEarliestDueDate != 0) {
            ( , , earliestPaymentDueDate ) = loanManager.sortedPayments(loanManager.paymentWithEarliestDueDate());
        } else {
            earliestPaymentDueDate = block.timestamp;
        }

        numberOfCalls["finishCollateralLiquidation"]++;
    }

}
