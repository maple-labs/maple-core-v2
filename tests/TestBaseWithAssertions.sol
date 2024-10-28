// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC20,
    IFixedTermLoan,
    IFixedTermLoanManager,
    IFixedTermLoanManagerStructs,
    ILoanLike,
    ILoanManagerLike,
    IOpenTermLoan,
    IOpenTermLoanManager,
    IOpenTermLoanManagerStructs,
    IPool,
    IPoolManager,
    IWithdrawalManagerCyclical,
    IWithdrawalManagerQueue
} from "../contracts/interfaces/Interfaces.sol";

import { BalanceAssertions } from "./BalanceAssertions.sol";
import { TestBase }          from "./TestBase.sol";

contract TestBaseWithAssertions is TestBase, BalanceAssertions {

    /**************************************************************************************************************************************/
    /*** State Assertion Functions                                                                                                      ***/
    /**************************************************************************************************************************************/

    function assertFixedTermLoan(
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

    function assertFixedTermLoan(
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

        assertEq(ILoanLike(loan).principal(),               principal,         "principal");
        assertEq(IFixedTermLoan(loan).refinanceInterest(),  refinanceInterest, "refinanceInterest");
        assertEq(IFixedTermLoan(loan).nextPaymentDueDate(), paymentDueDate,    "nextPaymentDueDate");
        assertEq(IFixedTermLoan(loan).paymentsRemaining(),  paymentsRemaining, "paymentsRemaining");
    }

    function assertOpenTermLoan(
        address loan,
        uint256 dateCalled,
        uint256 dateFunded,
        uint256 dateImpaired,
        uint256 datePaid,
        uint256 calledPrincipal,
        uint256 principal
    ) internal {
        assertEq(IOpenTermLoan(loan).calledPrincipal(), calledPrincipal);
        assertEq(IOpenTermLoan(loan).dateCalled(),      dateCalled);
        assertEq(IOpenTermLoan(loan).dateFunded(),      dateFunded);
        assertEq(IOpenTermLoan(loan).dateImpaired(),    dateImpaired);
        assertEq(IOpenTermLoan(loan).datePaid(),        datePaid);
        assertEq(ILoanLike(loan).principal(),           principal);
    }

    function assertOpenTermLoanPaymentState(
        address loan,
        uint256 paymentTimestamp,
        uint256 principal,
        uint256 interest,
        uint256 lateInterest,
        uint256 delegateServiceFee,
        uint256 platformServiceFee,
        uint256 paymentDueDate,
        uint256 defaultDate
    ) internal {
        ( uint256 principal_, uint256 interest_, uint256 lateInterest_, uint256 delegateServiceFee_, uint256 platformServiceFee_ )
            = IOpenTermLoan(loan).getPaymentBreakdown(uint40(paymentTimestamp));

        assertEq(principal_,          principal,          "principal");
        assertEq(interest_,           interest,           "interest");
        assertEq(lateInterest_,       lateInterest,       "lateInterest");
        assertEq(delegateServiceFee_, delegateServiceFee, "delegateServiceFee");
        assertEq(platformServiceFee_, platformServiceFee, "platformServiceFee");

        assertEq(IOpenTermLoan(loan).paymentDueDate(), paymentDueDate, "paymentDueDate");
        assertEq(IOpenTermLoan(loan).defaultDate(),    defaultDate,    "defaultDate");
    }

    function assertLoanInfoWasDeleted(address loan) internal {
        IFixedTermLoanManager loanManager = IFixedTermLoanManager(ILoanLike(loan).lender());

        assertEq(loanManager.paymentIdOf(loan), 0);
    }

    function assertFixedTermPaymentInfo(
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
        address loanManager = ILoanLike(loan).lender();

        IFixedTermLoanManagerStructs.PaymentInfo memory loanInfo =
            IFixedTermLoanManagerStructs(loanManager).payments(IFixedTermLoanManager(loanManager).paymentIdOf(loan));

        assertEq(loanInfo.incomingNetInterest,       incomingNetInterest, "loanInfo.incomingNetInterest");
        assertEq(loanInfo.refinanceInterest,         refinanceInterest,   "loanInfo.refinanceInterest");
        assertEq(loanInfo.issuanceRate,              issuanceRate,        "loanInfo.issuanceRate");
        assertEq(loanInfo.startDate,                 startDate,           "loanInfo.startDate");
        assertEq(loanInfo.paymentDueDate,            paymentDueDate,      "loanInfo.paymentDueDate");
        assertEq(loanInfo.platformManagementFeeRate, platformFeeRate,     "loanInfo.platformManagementFeeRate");
        assertEq(loanInfo.delegateManagementFeeRate, delegateFeeRate,     "loanInfo.delegateFeeRate");
    }

    function assertOpenTermPaymentInfo(
        address loan,
        uint256 platformFeeRate,
        uint256 delegateFeeRate,
        uint256 startDate,
        uint256 issuanceRate
    )
        internal
    {
        IOpenTermLoanManagerStructs.Payment memory loanInfo =
            IOpenTermLoanManagerStructs(ILoanLike(loan).lender()).paymentFor(loan);

        assertEq(loanInfo.platformManagementFeeRate, platformFeeRate, "loanInfo.platformManagementFeeRate");
        assertEq(loanInfo.delegateManagementFeeRate, delegateFeeRate, "loanInfo.delegateManagementFeeRate");
        assertEq(loanInfo.startDate,                 startDate,       "loanInfo.startDate");
        assertEq(loanInfo.issuanceRate,              issuanceRate,    "loanInfo.issuanceRate");
    }

    function assertOpenTermPaymentInfo(address loan, uint256 startDate, uint256 issuanceRate) internal {
        IOpenTermLoanManager loanManager = IOpenTermLoanManager(ILoanLike(loan).lender());

        ( , , uint40 startDate_, uint168 issuanceRate_ ) = loanManager.paymentFor(loan);

        assertEq(startDate_,    startDate);
        assertEq(issuanceRate_, issuanceRate);
    }

    function assertFixedTermLoanManager(
        address loanManager,
        uint256 accountedInterest,
        uint256 accruedInterest,
        uint256 domainEnd,
        uint256 domainStart,
        uint256 issuanceRate,
        uint256 principalOut,
        uint256 unrealizedLosses
    ) internal {
        assertEq(ILoanManagerLike(loanManager).accountedInterest(), accountedInterest, "accountedInterest");
        assertEq(ILoanManagerLike(loanManager).accruedInterest(),   accruedInterest,   "accruedInterest");
        assertEq(IFixedTermLoanManager(loanManager).domainEnd(),    domainEnd,         "domainEnd");
        assertEq(ILoanManagerLike(loanManager).domainStart(),       domainStart,       "domainStart");
        assertEq(ILoanManagerLike(loanManager).issuanceRate(),      issuanceRate,      "issuanceRate");
        assertEq(ILoanManagerLike(loanManager).principalOut(),      principalOut,      "principalOut");
        assertEq(ILoanManagerLike(loanManager).unrealizedLosses(),  unrealizedLosses,  "unrealizedLosses");

        assertEq(
            ILoanManagerLike(loanManager).assetsUnderManagement(),
            principalOut + accountedInterest + accruedInterest,
            "assetsUnderManagement"
        );
    }

    function assertOpenTermLoanManager(
        address loanManager,
        uint256 accountedInterest,
        uint256 accruedInterest,
        uint256 domainStart,
        uint256 issuanceRate,
        uint256 principalOut,
        uint256 unrealizedLosses
    ) internal {
        assertEq(ILoanManagerLike(loanManager).accountedInterest(), accountedInterest, "accountedInterest");
        assertEq(ILoanManagerLike(loanManager).accruedInterest(),   accruedInterest,   "accruedInterest");
        assertEq(ILoanManagerLike(loanManager).domainStart(),       domainStart,       "domainStart");
        assertEq(ILoanManagerLike(loanManager).issuanceRate(),      issuanceRate,      "issuanceRate");
        assertEq(ILoanManagerLike(loanManager).principalOut(),      principalOut,      "principalOut");
        assertEq(ILoanManagerLike(loanManager).unrealizedLosses(),  unrealizedLosses,  "unrealizedLosses");

        assertEq(
            ILoanManagerLike(loanManager).assetsUnderManagement(),
            principalOut + accountedInterest + accruedInterest,
            "assetsUnderManagement"
        );
    }

    function assertFixedTermLoanManagerWithDiff(
        address loanManager,
        uint256 accountedInterest,
        uint256 accruedInterest,
        uint256 domainEnd,
        uint256 domainStart,
        uint256 issuanceRate,
        uint256 principalOut,
        uint256 unrealizedLosses,
        uint256 diff
    ) internal {
        assertApproxEqAbs(ILoanManagerLike(loanManager).accountedInterest(), accountedInterest, diff, "accountedInterest");
        assertApproxEqAbs(ILoanManagerLike(loanManager).accruedInterest(),   accruedInterest,   diff, "accruedInterest");
        assertApproxEqAbs(IFixedTermLoanManager(loanManager).domainEnd(),    domainEnd,         diff, "domainEnd");
        assertApproxEqAbs(ILoanManagerLike(loanManager).domainStart(),       domainStart,       diff, "domainStart");
        assertApproxEqAbs(ILoanManagerLike(loanManager).issuanceRate(),      issuanceRate,      diff, "issuanceRate");
        assertApproxEqAbs(ILoanManagerLike(loanManager).principalOut(),      principalOut,      diff, "principalOut");
        assertApproxEqAbs(ILoanManagerLike(loanManager).unrealizedLosses(),  unrealizedLosses,  diff, "unrealizedLosses");

        assertApproxEqAbs(
            ILoanManagerLike(loanManager).assetsUnderManagement(),
            principalOut + accountedInterest + accruedInterest,
            diff,
            "assetsUnderManagement"
        );
    }

    function assertOpenTermLoanManagerWithDiff(
        address loanManager,
        uint256 accountedInterest,
        uint256 accruedInterest,
        uint256 domainStart,
        uint256 issuanceRate,
        uint256 principalOut,
        uint256 unrealizedLosses,
        uint256 diff
    ) internal {
        assertApproxEqAbs(ILoanManagerLike(loanManager).accountedInterest(), accountedInterest, diff, "accountedInterest");
        assertApproxEqAbs(ILoanManagerLike(loanManager).accruedInterest(),   accruedInterest,   diff, "accruedInterest");
        assertApproxEqAbs(ILoanManagerLike(loanManager).domainStart(),       domainStart,       diff, "domainStart");
        assertApproxEqAbs(ILoanManagerLike(loanManager).issuanceRate(),      issuanceRate,      diff, "issuanceRate");
        assertApproxEqAbs(ILoanManagerLike(loanManager).principalOut(),      principalOut,      diff, "principalOut");
        assertApproxEqAbs(ILoanManagerLike(loanManager).unrealizedLosses(),  unrealizedLosses,  diff, "unrealizedLosses");

        assertApproxEqAbs(
            ILoanManagerLike(loanManager).assetsUnderManagement(),
            principalOut + accountedInterest + accruedInterest,
            diff,
            "assetsUnderManagement"
        );
    }

    function assertImpairment(address loan, uint256 impairedDate, bool impairedByGovernor) internal {
        IOpenTermLoanManager loanManager = IOpenTermLoanManager(ILoanLike(loan).lender());

        ( uint40 impairedDate_, bool impairedByGovernor_ ) = loanManager.impairmentFor(loan);

        assertEq(impairedDate_, impairedDate);

        assertTrue(impairedByGovernor_ == impairedByGovernor);
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

        assertTrue(liquidatorExists == (liquidationInfo.liquidator != address(0)), "liquidator exists");
        assertTrue(liquidationInfo.triggeredByGovernor == triggeredByGovernor,     "triggeredByGovernor");
    }

    function assertPoolState(
        address pool,
        uint256 totalAssets,
        uint256 totalSupply,
        uint256 unrealizedLosses,
        uint256 availableLiquidity
    ) internal {
        IPoolManager poolManager = IPoolManager(IPool(pool).manager());
        IERC20       asset       = IERC20(IPool(pool).asset());

        assertEq(IPool(pool).totalAssets(),      totalAssets,        "totalAssets");
        assertEq(IPool(pool).totalSupply(),      totalSupply,        "totalSupply");
        assertEq(IPool(pool).unrealizedLosses(), unrealizedLosses,   "unrealizedLosses");
        assertEq(poolManager.totalAssets(),      totalAssets,        "totalAssets");
        assertEq(poolManager.unrealizedLosses(), unrealizedLosses,   "unrealizedLosses");
        assertEq(asset.balanceOf(pool),          availableLiquidity, "availableLiquidity");
    }

    function assertPoolStateWithDiff(
        address pool,
        uint256 totalAssets,
        uint256 totalSupply,
        uint256 unrealizedLosses,
        uint256 availableLiquidity,
        uint256 diff
    )
        internal
    {
        IPoolManager poolManager = IPoolManager(IPool(pool).manager());
        IERC20       asset       = IERC20(IPool(pool).asset());

        assertApproxEqAbs(IPool(pool).totalAssets(),      totalAssets,        diff, "totalAssets");
        assertApproxEqAbs(IPool(pool).totalSupply(),      totalSupply,        diff, "totalSupply");
        assertApproxEqAbs(IPool(pool).unrealizedLosses(), unrealizedLosses,   diff, "unrealizedLosses");
        assertApproxEqAbs(poolManager.totalAssets(),      totalAssets,        diff, "totalAssets");
        assertApproxEqAbs(poolManager.unrealizedLosses(), unrealizedLosses,   diff, "unrealizedLosses");
        assertApproxEqAbs(asset.balanceOf(pool),          availableLiquidity, diff, "availableLiquidity");
    }

    function assertPoolManager(address poolManager, uint256 totalAssets, uint256 unrealizedLosses) internal {
        assertEq(IPoolManager(poolManager).totalAssets(),      totalAssets,      "totalAssets");
        assertEq(IPoolManager(poolManager).unrealizedLosses(), unrealizedLosses, "unrealizedLosses");
    }

    function assertQueue(address poolManager, uint128 nextRequestId, uint128 lastRequestId) internal {
        address wm = IPoolManager(poolManager).withdrawalManager();

        ( uint128 nextRequestId_, uint128 lastRequestId_ ) = IWithdrawalManagerQueue(wm).queue();

        assertEq(nextRequestId_, nextRequestId);
        assertEq(lastRequestId_, lastRequestId);
    }

    function assertRequest(address poolManager, uint128 requestId, address owner, uint256 shares) internal {
        address wm = IPoolManager(poolManager).withdrawalManager();

        ( address owner_, uint256 shares_ ) = IWithdrawalManagerQueue(wm).requests(requestId);

        assertEq(owner_,  owner);
        assertEq(shares_, shares);
    }

    function assertWithdrawalManagerState(
        address pool,
        address lp,
        uint256 lockedShares,
        uint256 previousExitCycleId,
        uint256 previousCycleTotalShares,
        uint256 currentExitCycleId,
        uint256 currentCycleTotalShares,
        uint256 withdrawalManagerTotalShares
    ) internal {
        IWithdrawalManagerCyclical withdrawalManager = IWithdrawalManagerCyclical(IPoolManager(IPool(pool).manager()).withdrawalManager());

        assertEq(withdrawalManager.lockedShares(lp), lockedShares);
        assertEq(withdrawalManager.exitCycleId(lp),  currentExitCycleId);

        assertEq(withdrawalManager.totalCycleShares(previousExitCycleId), previousCycleTotalShares);
        assertEq(withdrawalManager.totalCycleShares(currentExitCycleId),  currentCycleTotalShares);

        assertEq(IPool(pool).balanceOf(address(withdrawalManager)), withdrawalManagerTotalShares);
    }

}
