// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IFixedTermLoan,
    IFixedTermLoanManagerStructs,
    ILoanLike,
    ILoanManagerLike,
    IOpenTermLoan,
    IOpenTermLoanManager
} from "../contracts/interfaces/Interfaces.sol";

import { BalanceAssertions } from "./BalanceAssertions.sol";
import { TestBase }          from "./TestBase.sol";

contract TestBaseWithAssertions is TestBase, BalanceAssertions {

    /**************************************************************************************************************************************/
    /*** State Assertion Functions                                                                                                      ***/
    /**************************************************************************************************************************************/

    function assertLoanState(
        address loan,
        uint256 principal,
        uint256 refinanceInterest,
        uint256 paymentDueDate,
        uint256 paymentsRemaining
    ) internal {
        assertEq(IFixedTermLoan(loan).principal(),          principal,         "principal");
        assertEq(IFixedTermLoan(loan).refinanceInterest(),  refinanceInterest, "refinanceInterest");
        assertEq(IFixedTermLoan(loan).nextPaymentDueDate(), paymentDueDate,    "nextPaymentDueDate");
        assertEq(IFixedTermLoan(loan).paymentsRemaining(),  paymentsRemaining, "paymentsRemaining");
    }

    function assertLoanState(
        address loan,
        uint256 principal,
        uint256 incomingPrincipal,
        uint256 incomingInterest,
        uint256 incomingFees,
        uint256 refinanceInterest,
        uint256 paymentDueDate,
        uint256 paymentsRemaining
    ) internal {
        ( uint256 principalPayment, uint256 interest, uint256 fees ) = IFixedTermLoan(loan).getNextPaymentBreakdown();

        assertEq(interest,         incomingInterest,  "interest");
        assertEq(fees,             incomingFees,      "fees");
        assertEq(principalPayment, incomingPrincipal, "incoming principal");

        assertEq(IFixedTermLoan(loan).principal(),          principal,         "principal");
        assertEq(IFixedTermLoan(loan).refinanceInterest(),  refinanceInterest, "refinanceInterest");
        assertEq(IFixedTermLoan(loan).nextPaymentDueDate(), paymentDueDate,    "nextPaymentDueDate");
        assertEq(IFixedTermLoan(loan).paymentsRemaining(),  paymentsRemaining, "paymentsRemaining");
    }

    function assertLoan(
        address loan,
        uint256 dateCalled,
        uint256 dateFunded,
        uint256 dateImpaired,
        uint256 datePaid,
        uint256 calledPrincipal,
        uint256 principal
    ) internal {
        IOpenTermLoan otl = IOpenTermLoan(loan);

        assertEq(otl.dateCalled(),   dateCalled);
        assertEq(otl.dateFunded(),   dateFunded);
        assertEq(otl.dateImpaired(), dateImpaired);
        assertEq(otl.datePaid(),     datePaid);

        assertEq(otl.calledPrincipal(), calledPrincipal);
        assertEq(otl.principal(),       principal);
    }

    function assertLoanInfoWasDeleted(address loan) internal {
        ILoanManagerLike loanManager = ILoanManagerLike(ILoanLike(loan).lender());

        assertEq(loanManager.paymentIdOf(loan), 0);
    }

    // TODO: Investigate reverting back to tuples to expose changes easier.
    function assertPaymentInfo(
        address loan,
        uint256 incomingNetInterest,
        uint256 refinanceInterest,
        uint256 issuanceRate,
        uint256 startDate,
        uint256 paymentDueDate,
        uint256 platformFeeRate,
        uint256 delegateFeeRate
    )
        internal
    {
        ILoanManagerLike loanManager = ILoanManagerLike(ILoanLike(loan).lender());

        IFixedTermLoanManagerStructs.PaymentInfo memory loanInfo =
            IFixedTermLoanManagerStructs(ILoanLike(loan).lender()).payments(loanManager.paymentIdOf(loan));

        assertEq(loanInfo.incomingNetInterest,       incomingNetInterest, "loanInfo.incomingNetInterest");
        assertEq(loanInfo.refinanceInterest,         refinanceInterest,   "loanInfo.refinanceInterest");
        assertEq(loanInfo.issuanceRate,              issuanceRate,        "loanInfo.issuanceRate");
        assertEq(loanInfo.startDate,                 startDate,           "loanInfo.startDate");
        assertEq(loanInfo.paymentDueDate,            paymentDueDate,      "loanInfo.paymentDueDate");
        assertEq(loanInfo.platformManagementFeeRate, platformFeeRate,     "loanInfo.platformManagementFeeRate");
        assertEq(loanInfo.delegateManagementFeeRate, delegateFeeRate,     "loanInfo.delegateFeeRate");
    }

    function assertLoanManager(
        address loanManager,
        uint256 accruedInterest,
        uint256 accountedInterest,
        uint256 principalOut,
        uint256 assetsUnderManagement,
        uint256 issuanceRate,
        uint256 domainStart,
        uint256 domainEnd,
        uint256 unrealizedLosses
    ) internal {
        ILoanManagerLike loanManager_ = ILoanManagerLike(loanManager);

        assertEq(loanManager_.getAccruedInterest(),    accruedInterest,       "getAccruedInterest");
        assertEq(loanManager_.accountedInterest(),     accountedInterest,     "accountedInterest");
        assertEq(loanManager_.principalOut(),          principalOut,          "principalOut");
        assertEq(loanManager_.assetsUnderManagement(), assetsUnderManagement, "assetsUnderManagement");
        assertEq(loanManager_.issuanceRate(),          issuanceRate,          "issuanceRate");
        assertEq(loanManager_.domainStart(),           domainStart,           "domainStart");
        assertEq(loanManager_.domainEnd(),             domainEnd,             "domainEnd");
        assertEq(loanManager_.unrealizedLosses(),      unrealizedLosses,      "unrealizedLosses");
    }

    function assertLoanManager(
        address loanManager,
        uint256 domainStart,
        uint256 issuanceRate,
        uint256 accountedInterest,
        uint256 principalOut,
        uint256 unrealizedLosses
    ) internal {
        IOpenTermLoanManager otlm = IOpenTermLoanManager(loanManager);

        assertEq(otlm.domainStart(),       domainStart);
        assertEq(otlm.issuanceRate(),      issuanceRate);
        assertEq(otlm.accountedInterest(), accountedInterest);
        assertEq(otlm.principalOut(),      principalOut);
        assertEq(otlm.unrealizedLosses(),  unrealizedLosses);
    }

    function assertImpairment(
        address loan,
        address loanManager,
        uint256 impairedDate,
        bool    impairedByGovernor
    ) internal {
        IOpenTermLoanManager otlm = IOpenTermLoanManager(loanManager);

        ( uint40 impairedDate_, bool impairedByGovernor_ ) = otlm.impairmentFor(loan);

        assertEq(impairedDate_, impairedDate);
        assertTrue(impairedByGovernor_ == impairedByGovernor);
    }

    function assertPayment(
        address loan,
        address loanManager,
        uint256 startDate,
        uint256 issuanceRate,
        uint256 delegateManagementFeeRate,
        uint256 platformManagementFeeRate
    ) internal {
        IOpenTermLoanManager otlm = IOpenTermLoanManager(loanManager);

        (
            uint24 platformManagementFeeRate_,
            uint24 delegateManagementFeeRate_,
            uint40 startDate_,
            uint168 issuanceRate_
        ) = otlm.paymentFor(loan);

        assertEq(startDate_,                 startDate);
        assertEq(issuanceRate_,              issuanceRate);
        assertEq(delegateManagementFeeRate_, delegateManagementFeeRate);
        assertEq(platformManagementFeeRate_, platformManagementFeeRate);
    }

    function assertLiquidationInfo(
        address loan,
        uint256 principal,
        uint256 interest,
        uint256 lateInterest,
        uint256 platformFees,
        bool    liquidatorExists,
        bool    triggeredByGovernor
    ) internal {
        IFixedTermLoanManagerStructs.LiquidationInfo memory liquidationInfo =
            IFixedTermLoanManagerStructs(ILoanLike(loan).lender()).liquidationInfo(loan);

        assertEq(liquidationInfo.principal,    principal,    "liquidationInfo.principal");
        assertEq(liquidationInfo.interest,     interest,     "liquidationInfo.interest");
        assertEq(liquidationInfo.lateInterest, lateInterest, "liquidationInfo.lateInterest");
        assertEq(liquidationInfo.platformFees, platformFees, "liquidationInfo.platformFees");

        assertTrue(liquidatorExists ? liquidationInfo.liquidator != address(0) : liquidationInfo.liquidator == address(0), "liquidator exists");
        assertTrue(liquidationInfo.triggeredByGovernor == triggeredByGovernor, "triggeredByGovernor");
    }

    function assertPoolState(uint256 totalAssets, uint256 totalSupply, uint256 unrealizedLosses, uint256 availableLiquidity) internal {
        assertEq(pool.totalAssets(),                  totalAssets,        "totalAssets");
        assertEq(pool.totalSupply(),                  totalSupply,        "totalSupply");
        assertEq(pool.unrealizedLosses(),             unrealizedLosses,   "unrealizedLosses");
        assertEq(fundsAsset.balanceOf(address(pool)), availableLiquidity, "availableLiquidity");
    }

    function assertPoolManager(uint256 totalAssets, uint256 unrealizedLosses) internal {
        assertEq(poolManager.totalAssets(),      totalAssets,      "totalAssets");
        assertEq(poolManager.unrealizedLosses(), unrealizedLosses, "unrealizedLosses");
    }

    function assertTotalAssets(uint256 totalAssets) internal {
        assertEq(poolManager.totalAssets(), totalAssets);
    }

    function assertWithdrawalManagerState(
        address lp,
        uint256 lockedShares,
        uint256 previousExitCycleId,
        uint256 previousCycleTotalShares,
        uint256 currentExitCycleId,
        uint256 currentCycleTotalShares,
        uint256 withdrawalManagerTotalShares
    ) internal {
        assertEq(withdrawalManager.lockedShares(lp), lockedShares);
        assertEq(withdrawalManager.exitCycleId(lp),  currentExitCycleId);

        assertEq(withdrawalManager.totalCycleShares(previousExitCycleId), previousCycleTotalShares);
        assertEq(withdrawalManager.totalCycleShares(currentExitCycleId),  currentCycleTotalShares);

        assertEq(pool.balanceOf(address(withdrawalManager)), withdrawalManagerTotalShares);
    }

}
