// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { console } from "../modules/contract-test-utils/contracts/log.sol";

import { MockERC20 as Asset  } from "../modules/erc20/contracts/test/mocks/MockERC20.sol";
import { MapleLoan as Loan   } from "../modules/loan/contracts/MapleLoan.sol";
import { LoanManager         } from "../modules/pool-v2/contracts/LoanManager.sol";
import { PoolManager         } from "../modules/pool-v2/contracts/PoolManager.sol";
import { ILoanManagerStructs } from "../modules/pool-v2/tests/interfaces/ILoanManagerStructs.sol";

import { TestBase          } from "./TestBase.sol";
import { BalanceAssertions } from "./BalanceAssertions.sol";

contract TestBaseWithAssertions is TestBase, BalanceAssertions {

    /*********************************/
    /*** State Assertion Functions ***/
    /*********************************/

    function assertLoanState(
        address loan,
        uint256 principal,
        uint256 refinanceInterest,
        uint256 paymentDueDate,
        uint256 paymentsRemaining
    ) internal {
        assertEq(Loan(loan).refinanceInterest(),  refinanceInterest, "refinanceInterest");
        assertEq(Loan(loan).nextPaymentDueDate(), paymentDueDate,    "nextPaymentDueDate");
        assertEq(Loan(loan).paymentsRemaining(),  paymentsRemaining, "paymentsRemaining");
    }

    function assertLoanInfoWasDeleted(address loan) internal {
        uint256 loanId = LoanManager(loanManager).loanIdOf(loan);
        assertEq(loanId, 0);
    }

    // TODO: Investigate reverting back to tuples to expose changes easier.
    function assertLoanInfo(
        address loan,
        uint256 incomingNetInterest,
        uint256 refinanceInterest,
        uint256 issuanceRate,
        uint256 startDate,
        uint256 paymentDueDate
    )
        internal
    {
        ILoanManagerStructs.LoanInfo memory loanInfo = ILoanManagerStructs(address(loanManager)).loans(loanManager.loanIdOf(loan));

        assertEq(loanInfo.incomingNetInterest, incomingNetInterest, "loanInfo.incomingNetInterest");
        assertEq(loanInfo.refinanceInterest,   refinanceInterest,   "loanInfo.refinanceInterest");
        assertEq(loanInfo.issuanceRate,        issuanceRate,        "loanInfo.issuanceRate");
        assertEq(loanInfo.startDate,           startDate,           "loanInfo.startDate");
        assertEq(loanInfo.paymentDueDate,      paymentDueDate,      "loanInfo.paymentDueDate");
    }

    function assertLoanManager(
        uint256 accruedInterest,
        uint256 accountedInterest,
        uint256 principalOut,
        uint256 assetsUnderManagement,
        uint256 issuanceRate,
        uint256 domainStart,
        uint256 domainEnd,
        uint256 unrealizedLosses
    ) internal {
        assertEq(loanManager.getAccruedInterest(),    accruedInterest,       "getAccruedInterest");
        assertEq(loanManager.accountedInterest(),     accountedInterest,     "accountedInterest");
        assertEq(loanManager.principalOut(),          principalOut,          "principalOut");
        assertEq(loanManager.assetsUnderManagement(), assetsUnderManagement, "assetsUnderManagement");
        assertEq(loanManager.issuanceRate(),          issuanceRate,          "issuanceRate");
        assertEq(loanManager.domainStart(),           domainStart,           "domainStart");
        assertEq(loanManager.domainEnd(),             domainEnd,             "domainEnd");
        assertEq(loanManager.unrealizedLosses(),      unrealizedLosses,      "unrealizedLosses");
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
        ILoanManagerStructs.LiquidationInfo memory liquidationInfo = ILoanManagerStructs(address(loanManager)).liquidationInfo(loan);

        assertEq(liquidationInfo.principal,    principal,    "liquidationInfo.principal");
        assertEq(liquidationInfo.interest,     interest,     "liquidationInfo.interest");
        assertEq(liquidationInfo.lateInterest, lateInterest, "liquidationInfo.lateInterest");
        assertEq(liquidationInfo.platformFees, platformFees, "liquidationInfo.platformFees");

        assertTrue(liquidatorExists ? liquidationInfo.liquidator != address(0) : liquidationInfo.liquidator == address(0), "liquidator exists");
        assertTrue(liquidationInfo.triggeredByGovernor == triggeredByGovernor, "triggeredByGovernor");
    }

    function assertPoolManager(uint256 totalAssets, uint256 unrealizedLosses) internal {
        assertEq(poolManager.totalAssets(),      totalAssets,      "totalAssets");
        assertEq(poolManager.unrealizedLosses(), unrealizedLosses, "unrealizedLosses");
    }

    function assertWithdrawalManager() internal {
        // TODO
    }

}
