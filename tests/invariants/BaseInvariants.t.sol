// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IFeeManager,
    IFixedTermLoan,
    IFixedTermLoanManager,
    ILoanLike,
    ILoanManagerLike,
    IOpenTermLoan,
    IOpenTermLoanManager
} from "../../contracts/interfaces/Interfaces.sol";

import { StdInvariant } from "../../contracts/Contracts.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

import { FixedTermLoanHandler } from "./actors/FixedTermLoanHandler.sol";
import { LpHandler }            from "./actors/LpHandler.sol";
import { OpenTermLoanHandler }  from "./actors/OpenTermLoanHandler.sol";


contract BaseInvariants is StdInvariant, TestBaseWithAssertions {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    FixedTermLoanHandler ftlHandler;
    LpHandler            lpHandler;
    OpenTermLoanHandler  otlHandler;

    uint256 setTimestamps;

    address[] public borrowers;

    uint256[] timestamps;

    uint256 public currentTimestamp;

    /**************************************************************************************************************************************/
    /*** Modifiers                                                                                                                      ***/
    /**************************************************************************************************************************************/

    modifier useCurrentTimestamp {
        vm.warp(currentTimestamp);
        _;
    }

    /**************************************************************************************************************************************/
    /*** Invariant Tests                                                                                                                ***/
    /***************************************************************************************************************************************

     * Fixed Term Loan
        * Invariant A: collateral balance >= _collateral`
        * Invariant B: fundsAsset >= _drawableFunds`
        * Invariant C: `_collateral >= collateralRequired_ * (principal_ - drawableFunds_) / principalRequested_`

     * Fixed Term Loan Manager (non-liquidating)
        * Invariant A: domainStart <= domainEnd
        * Invariant B: sortedPayments is always sorted
        * Invariant C: outstandingInterest = ∑outstandingInterest(loan) (theoretical)
        * Invariant D: totalPrincipal = ∑loan.principal()
        * Invariant E: issuanceRate = ∑issuanceRate(payment)
        * Invariant F: unrealizedLosses <= assetsUnderManagement()
        * Invariant G: unrealizedLosses == 0
        * Invariant H: assetsUnderManagement == ∑loan.principal() + ∑outstandingInterest(loan)
        * Invariant I: domainStart <= block.timestamp
        * Invariant J: if (loanManager.paymentWithEarliestDueDate != 0) then issuanceRate > 0
        * Invariant K: if (loanManager.paymentWithEarliestDueDate != 0) then domainEnd == paymentWithEarliestDueDate
        * Invariant L: refinanceInterest[payment] = loan.refinanceInterest()
        * Invariant M: paymentDueDate[payment] = loan.paymentDueDate()
        * Invariant N: startDate[payment] <= loan.paymentDueDate() - loan.paymentInterval()

     * Open Term Loan
        * Invariant A: dateFunded <= datePaid, dateCalled, dateImpaired (if not zero)
        * Invariant B: datePaid <= dateImpaired (if not zero)
        * Invariant C: datePaid <= dateCalled (if not zero)
        * Invariant D: calledPrincipal <= principal
        * Invariant E: dateCalled != 0 -> calledPrincipal != 0
        * Invariant F: paymentDueDate() <= defaultDate()
        * Invariant G: getPaymentBreakdown == theoretical calculation

     * Open Term Loan Manager
        * Invariant A: accountedInterest + accruedInterest() == ∑loan.getPaymentBreakdown(block.timestamp) (regular interest minus fees)
        * Invariant B: if no payments exist: accountedInterest == 0
        * Invariant C: principalOut = ∑loan.principal()
        * Invariant D: issuanceRate = ∑payment.issuanceRate
        * Invariant E: unrealizedLosses <= assetsUnderManagement()
        * Invariant F: if no impairments exist: unrealizedLosses == 0
        * Invariant G: assetsUnderManagement() == ∑loan.principal() + ∑loan.getPaymentBreakdown(block.timestamp) (regular interest minus fees)
        * Invariant H: block.timestamp >= domainStart
        * Invariant I: payment.startDate == loan.dateFunded() || loan.datePaid()
        * Invariant J: payment.issuanceRate == theoretical calculation (regular interest minus management fees)
        * Invariant K: ∑payment.impairedDate >= ∑payment.startDate

     * Pool (non-liquidating)
        * Invariant A: totalAssets > fundsAsset balance of pool
        * Invariant B: ∑balanceOfAssets == totalAssets (with rounding)
        * Invariant C: totalAssets >= totalSupply (in non-liquidating scenario)
        * Invariant D: convertToAssets(totalSupply) == totalAssets (with rounding)
        * Invariant E: convertToShares(totalAssets) == totalSupply (with rounding)
        * Invariant F: balanceOfAssets[user] >= balanceOf[user]
        * Invariant G: ∑balanceOf[user] == totalSupply
        * Invariant H: convertToExitShares == convertToShares
        * Invariant I: totalAssets == poolManager.totalAssets()
        * Invariant J: unrealizedLosses == poolManager.unrealizedLosses()
        * Invariant K: convertToExitShares == poolManager.convertToExitShares()

     PoolManager (non-liquidating)
        * Invariant A: totalAssets == cash + ∑assetsUnderManagement[loanManager]
        * Invariant B: hasSufficientCover == fundsAsset balance of cover > globals.minCoverAmount

     Withdrawal Manager
        * Invariant A: WM LP balance == ∑lockedShares(user)
        * Invariant B: totalCycleShares == ∑lockedShares(user)[cycle] (for all cycles)
        * Invariant C: windowStart[currentCycle] <= block.timestamp
        * Invariant D: initialCycleTime[currentConfig] <= block.timestamp
        * Invariant E: initialCycleId[currentConfig] <= currentCycle
        * Invariant F: getRedeemableAmounts.shares[owner] <= WM LP balance
        * Invariant G: getRedeemableAmounts.shares[owner] <= lockedShares[user]
        * Invariant H: getRedeemableAmounts.shares[owner] <= totalCycleShares[exitCycleId[user]]
        * Invariant I: getRedeemableAmounts.assets[owner] <= fundsAsset balance of pool
        * Invariant J: getRedeemableAmounts.assets[owner] <= totalCycleShares[exitCycleId[user]] * exchangeRate
        * Invariant K: getRedeemableAmounts.assets[owner] <= lockedShares[user] * exchangeRate
        * Invariant L: getRedeemableAmounts.partialLiquidity == (lockedShares[user] * exchangeRate < fundsAsset balance of pool)
        * Invariant M: lockedLiquidity <= pool.totalAssets()
        * Invariant N: lockedLiquidity <= totalCycleShares[exitCycleId[user]] * exchangeRate

    ftlHandler requires (WIP)
        makePayment
        * totalAssets increases
        * Treasury balance increases
        * PD balance increases if cover
        * payment management rates equal current rates
        * domainStart == block.timestamp
        * domainEnd   == paymentWithEarliestDueDate
        * loan balance == 0
        * loan PDD increases by paymentInterval if not last payment
        * refinanceInterest

        fund
        * Treasury balance increases
        * PD balance increases if cover
        * payment management rates equal current rates
        * domainStart == block.timestamp
        * domainEnd   == paymentWithEarliestDueDate
        * issuanceRate > 0

    ***************************************************************************************************************************************/

    /**************************************************************************************************************************************/
    /*** Fixed Term Loan Invariants                                                                                                     ***/
    /**************************************************************************************************************************************/

    function assert_ftl_invariant_A(address loan) internal {
        assertGe(collateralAsset.balanceOf(loan), IFixedTermLoan(loan).collateral(), "Loan Invariant A");
    }

    function assert_ftl_invariant_B(address loan) internal {
        assertGe(fundsAsset.balanceOf(loan), IFixedTermLoan(loan).drawableFunds(), "Loan Invariant B");
    }

    function assert_ftl_invariant_C(address loan_, uint256 platformOriginationFee_) internal {
        IFixedTermLoan loan       = IFixedTermLoan(loan_);
        IFeeManager    feeManager = IFeeManager(loan.feeManager());

        // The loan is matured or repossessed, the invariant will underflow because delegateOriginationFee > 0
        if (loan.nextPaymentDueDate() == 0) return;

        // If the drawableFunds is greater than the current principal, no collateral is required.
        if (loan.drawableFunds() >= loan.principal()) return;

        uint256 delegateOriginationFee = feeManager.delegateOriginationFee(address(loan));

        uint256 fundedAmount = loan.principalRequested() - delegateOriginationFee - platformOriginationFee_;

        // If drawableFunds exactly equals the funded amount, assume funds haven't been drawn down.
        if (loan.drawableFunds() == fundedAmount) return;

        assertGe(
            loan.collateral(),
            (
                loan.collateralRequired() * (loan.principal() - loan.drawableFunds()) + loan.principalRequested() - 1
            ) / loan.principalRequested(),
            "Loan Invariant C"
        );
    }

    /**************************************************************************************************************************************/
    /*** Fixed Term Loan Manager Invariants                                                                                             ***/
    /**************************************************************************************************************************************/

    function assert_ftlm_invariant_A(address loanManager) internal {
        assertLe(ILoanManagerLike(loanManager).domainStart(), IFixedTermLoanManager(loanManager).domainEnd(), "LoanManager Invariant A");
    }

    function assert_ftlm_invariant_B(address loanManager) internal {
        uint256 next = IFixedTermLoanManager(loanManager).paymentWithEarliestDueDate();

        uint256 previousPaymentDueDate;
        uint256 nextPaymentDueDate;

        while (next != 0) {
            uint256 current = next;

            ( , next, ) = IFixedTermLoanManager(loanManager).sortedPayments(current);  // Overwrite `next` in loop

            ( , , nextPaymentDueDate ) = IFixedTermLoanManager(loanManager).sortedPayments(next);  // Get the next payment due date

            if (next == 0 && nextPaymentDueDate == 0) break;  // End of list

            assertLe(previousPaymentDueDate, nextPaymentDueDate, "LoanManager Invariant B");

            previousPaymentDueDate = nextPaymentDueDate;  // Set the previous payment due date
        }
    }

    function assert_ftlm_invariant_C(address loanManager) internal {
        vm.warp(currentTimestamp);

        uint256 sumOutstandingInterest = getAllOutstandingInterest();

        assertApproxEqAbs(
            ILoanManagerLike(loanManager).accountedInterest() + ILoanManagerLike(loanManager).accruedInterest(),
            sumOutstandingInterest,
            max(ftlHandler.numPayments(), ftlHandler.numLoans()) + 1,
            "LoanManager Invariant C"
        );
    }

    function assert_ftlm_invariant_D(address loanManager) internal {
        assertEq(ILoanManagerLike(loanManager).principalOut(), ftlHandler.sum_loan_principal(), "LoanManager Invariant D");
    }

    function assert_ftlm_invariant_E(address loanManager) internal {
        assertEq(ILoanManagerLike(loanManager).issuanceRate(), getSumIssuanceRates(), "LoanManager Invariant E");
    }

    function assert_ftlm_invariant_F(address loanManager) internal {
        // NOTE: To account for precision errors for unrealizedLosses(), we add 1 to the AUM
        uint256 losses   = ILoanManagerLike(loanManager).unrealizedLosses();
        uint256 aum      = ILoanManagerLike(loanManager).assetsUnderManagement();

        if (losses > aum) {
            assertApproxEqAbs(losses, aum, ftlHandler.numPayments() + 1);
        } else {
            assertLe(losses, aum + 1, "LoanManager Invariant F");
        }
    }

    function assert_ftlm_invariant_G(address loanManager) internal {
        assertEq(ILoanManagerLike(loanManager).unrealizedLosses(), 0, "LoanManager Invariant G");
    }

    function assert_ftlm_invariant_H(address loanManager) internal {
        assertApproxEqAbs(
            ILoanManagerLike(loanManager).assetsUnderManagement(),
            getAllOutstandingInterest() + ftlHandler.sum_loan_principal(),
            max(ftlHandler.numPayments(), ftlHandler.numLoans()) + 1,
            "LoanManager Invariant H"
        );
    }

    function assert_ftlm_invariant_I(address loanManager) internal {
        assertLe(ILoanManagerLike(loanManager).domainStart(), block.timestamp, "LoanManager Invariant I");
    }

    function assert_ftlm_invariant_J(address loanManager) internal {
        if (IFixedTermLoanManager(loanManager).paymentWithEarliestDueDate() != 0) {
            assertGt(ILoanManagerLike(loanManager).issuanceRate(), 0, "LoanManager Invariant J");
        }
    }

    function assert_ftlm_invariant_K(address loanManager) internal {
        uint256 paymentWithEarliestDueDate = IFixedTermLoanManager(loanManager).paymentWithEarliestDueDate();

        ( , , uint256 earliestPaymentDueDate ) = IFixedTermLoanManager(loanManager).sortedPayments(paymentWithEarliestDueDate);

        if (paymentWithEarliestDueDate != 0) {
            assertEq(IFixedTermLoanManager(loanManager).domainEnd(), earliestPaymentDueDate, "LoanManager Invariant K");
        }
    }

    function assert_ftlm_invariant_L(address loan, uint256 refinanceInterest) internal {
        uint256 platformManagementFeeRate_ = globals.platformManagementFeeRate(address(poolManager));
        uint256 delegateManagementFeeRate_ = poolManager.delegateManagementFeeRate();
        uint256 managementFeeRate_         = platformManagementFeeRate_ + delegateManagementFeeRate_;

        assertEq(
            refinanceInterest,
            _getNetInterest(IFixedTermLoan(loan).refinanceInterest(), managementFeeRate_),
            "LoanManager Invariant L"
        );
    }

    function assert_ftlm_invariant_M(address loan, uint256 paymentDueDate) internal {
        assertEq(paymentDueDate, IFixedTermLoan(loan).nextPaymentDueDate(), "LoanManager Invariant M");
    }

    function assert_ftlm_invariant_N(address loan, uint256 startDate) internal {
        assertLe(startDate, IFixedTermLoan(loan).nextPaymentDueDate() - ILoanLike(loan).paymentInterval(), "LoanManager Invariant N");
    }

    /**************************************************************************************************************************************/
    /*** Pool Invariants                                                                                                                ***/
    /**************************************************************************************************************************************/

    function assert_pool_invariant_A() internal {
        assertGe(pool.totalAssets(), fundsAsset.balanceOf(address(pool)), "Pool Invariant A");
    }

    function assert_pool_invariant_B(uint256 sumBalanceOfAssets) internal {
        assertGe(pool.totalAssets(), sumBalanceOfAssets, "Pool Invariant B1");

        assertApproxEqAbs(pool.totalAssets(), sumBalanceOfAssets, lpHandler.numHolders(), "Pool Invariant B2");
    }

    function assert_pool_invariant_C() internal {
        assertGe(pool.totalAssets(), pool.totalSupply(), "Pool Invariant C");
    }

    function assert_pool_invariant_D() internal {
        assertGe(pool.totalAssets(), pool.convertToAssets(pool.totalSupply()), "Pool Invariant D1");

        assertApproxEqAbs(pool.totalAssets(), pool.convertToAssets(pool.totalSupply()), 1, "Pool Invariant D2");
    }

    function assert_pool_invariant_E() internal {
        assertGe(pool.convertToShares(pool.totalAssets()), pool.totalSupply(), "Pool Invariant E1");

        assertApproxEqAbs(pool.convertToShares(pool.totalAssets()), pool.totalSupply(), 1, "Pool Invariant E2");
    }

    function assert_pool_invariant_F(address holder) internal {
        assertGe(pool.balanceOfAssets(holder), pool.balanceOf(holder), "Pool Invariant F");
    }

    function assert_pool_invariant_G(uint256 sumBalanceOf) internal {
        assertEq(pool.totalSupply(), sumBalanceOf, "Pool Invariant G");
    }

    function assert_pool_invariant_H() internal {
        if (pool.totalAssets() > 0) {
            assertEq(pool.convertToShares(pool.totalAssets()), pool.convertToExitShares(pool.totalAssets()), "Pool Invariant H");
        }
    }

    function assert_pool_invariant_I() internal {
        assertEq(pool.totalAssets(), poolManager.totalAssets(), "Pool Invariant I");
    }

    function assert_pool_invariant_J() internal {
        assertEq(pool.unrealizedLosses(), poolManager.unrealizedLosses(), "Pool Invariant J");
    }

    function assert_pool_invariant_K() internal {
        if (pool.totalAssets() - pool.unrealizedLosses() > 0) {
            assertEq(pool.convertToExitShares(pool.totalAssets()), poolManager.convertToExitShares(pool.totalAssets()), "Pool Invariant K");
        }
    }

    /**************************************************************************************************************************************/
    /*** Pool Manager Functions                                                                                                         ***/
    /**************************************************************************************************************************************/

    function assert_poolManager_invariant_A() internal {
        uint256 expectedTotalAssets = ftlHandler.sum_loan_principal() + getAllOutstandingInterest() + fundsAsset.balanceOf(address(pool));

        assertApproxEqAbs(
            poolManager.totalAssets(),
            expectedTotalAssets,
            max(ftlHandler.numPayments(), ftlHandler.numLoans()) + 1,
            "PoolManager Invariant A"
        );
    }

    function assert_poolManager_invariant_B() internal {
        assertTrue(poolManager.unrealizedLosses() <= poolManager.totalAssets(), "PoolManager Invariant B");
    }

    /**************************************************************************************************************************************/
    /*** Withdrawal Manager Invariants                                                                                                  ***/
    /**************************************************************************************************************************************/

    function assert_withdrawalManager_invariant_A(uint256 sumLockedShares) internal {
        assertEq(pool.balanceOf(address(withdrawalManager)), sumLockedShares, "WithdrawalManager Invariant A1");
    }

    function assert_withdrawalManager_invariant_B() internal {
        uint256 currentCycleId = withdrawalManager.getCurrentCycleId();

        for (uint256 cycleId = 1; cycleId <= currentCycleId; ++cycleId) {
            uint256 sumCycleShares;

            for (uint256 i; i < lpHandler.numLps(); ++i) {
                if (withdrawalManager.exitCycleId(lpHandler.lps(i)) == cycleId) {
                    sumCycleShares += withdrawalManager.lockedShares(lpHandler.lps(i));
                }
            }

            assertEq(withdrawalManager.totalCycleShares(cycleId), sumCycleShares, "WithdrawalManager Invariant B");
        }
    }

    function assert_withdrawalManager_invariant_C() internal {
        uint256 withdrawalWindowStart = withdrawalManager.getWindowStart(withdrawalManager.getCurrentCycleId());

        assertLe(withdrawalWindowStart, block.timestamp, "WithdrawalManager Invariant C");
    }

    function assert_withdrawalManager_invariant_D() internal {
        ( , uint256 initialCycleTime , , ) = withdrawalManager.cycleConfigs(withdrawalManager.getCurrentCycleId());

        assertLe(initialCycleTime, block.timestamp, "WithdrawalManager Invariant D");
    }

    function assert_withdrawalManager_invariant_E() internal {
        ( uint256 initialCycleId , , , ) = withdrawalManager.cycleConfigs(withdrawalManager.getCurrentCycleId());

        assertLe(initialCycleId, withdrawalManager.getCurrentCycleId(), "WithdrawalManager Invariant e");
    }

    function assert_withdrawalManager_invariant_F(uint256 shares) internal {
        assertLe(shares, pool.balanceOf(address(withdrawalManager)), "WithdrawalManager Invariant F");
    }

    function assert_withdrawalManager_invariant_G(address lp, uint256 shares) internal {
        assertLe(shares, withdrawalManager.lockedShares(lp), "WithdrawalManager Invariant G");
    }

    function assert_withdrawalManager_invariant_H(address lp, uint256 shares) internal {
        assertLe(shares, withdrawalManager.totalCycleShares(withdrawalManager.exitCycleId(lp)), "WithdrawalManager Invariant H");
    }

    function assert_withdrawalManager_invariant_I(uint256 assets) internal {
        assertLe(assets, fundsAsset.balanceOf(address(pool)), "WithdrawalManager Invariant I");
    }

    function assert_withdrawalManager_invariant_J(uint256 assets, uint256 totalRequestedLiquidity) internal {
        assertLe(assets, totalRequestedLiquidity, "WithdrawalManager Invariant J");
    }

    function assert_withdrawalManager_invariant_K(address lp, uint256 assets) internal {
        uint256 lpRequestedLiquidity =
            withdrawalManager.lockedShares(lp) * (pool.totalAssets() - pool.unrealizedLosses()) / pool.totalSupply();

        assertLe(assets, lpRequestedLiquidity, "WithdrawalManager Invariant K");
    }

    function assert_withdrawalManager_invariant_L(bool partialLiquidity, uint256 totalRequestedLiquidity) internal {
        assertTrue(partialLiquidity == (fundsAsset.balanceOf(address(pool)) < totalRequestedLiquidity), "WithdrawalManager Invariant L");
    }

    function assert_withdrawalManager_invariant_M() internal {
        if (pool.totalSupply() == 0 || pool.totalAssets() == 0) return;

        uint256 cycleId = withdrawalManager.getCurrentCycleId();

        ( uint256 windowStart, uint256 windowEnd ) = withdrawalManager.getWindowAtId(cycleId);

        if (block.timestamp >= windowStart && block.timestamp < windowEnd) {
            assertLe(withdrawalManager.lockedLiquidity(), pool.totalAssets(), "WithdrawalManager Invariant M1");
        } else {
            assertEq(withdrawalManager.lockedLiquidity(), 0, "WithdrawalManager Invariant M2");
        }
    }

    function assert_withdrawalManager_invariant_N() internal {
        if (pool.totalSupply() == 0 || pool.totalAssets() == 0) return;

        uint256 currentCycle = withdrawalManager.getCurrentCycleId();

        ( uint256 windowStart, uint256 windowEnd ) = withdrawalManager.getWindowAtId(currentCycle);

        if (block.timestamp >= windowStart && block.timestamp < windowEnd) {
            assertLe(
                withdrawalManager.lockedLiquidity(),
                withdrawalManager.totalCycleShares(currentCycle) * (pool.totalAssets() - pool.unrealizedLosses()) / pool.totalSupply(),
                "WithdrawalManager Invariant N1"
            );
        } else {
            assertEq(withdrawalManager.lockedLiquidity(), 0, "WithdrawalManager Invariant N2");
        }
    }

    /**************************************************************************************************************************************/
    /*** Open Term Loan Invariants                                                                                                      ***/
    /**************************************************************************************************************************************/

    function assert_otl_invariant_A(address loan_) internal {
        IOpenTermLoan loan = IOpenTermLoan(loan_);

        if (loan.datePaid() != 0) {
            assertLe(loan.dateFunded(), loan.datePaid(), "OTL Invariant A");
        }
    }

    function assert_otl_invariant_B(address loan_) internal {
        IOpenTermLoan loan = IOpenTermLoan(loan_);

        if (loan.dateImpaired() != 0) {
            assertLe(loan.dateFunded(), loan.dateImpaired(), "OTL Invariant B");
        }
    }

    function assert_otl_invariant_C(address loan_) internal {
        IOpenTermLoan loan = IOpenTermLoan(loan_);

        if (loan.dateCalled() != 0) {
            assertLe(loan.dateFunded(), loan.dateCalled(), "OTL Invariant C");
        }
    }

    function assert_otl_invariant_D(address loan_) internal {
        IOpenTermLoan loan = IOpenTermLoan(loan_);

        if (loan.datePaid() != 0 && loan.dateImpaired() != 0) {
            assertLe(loan.datePaid(), loan.dateImpaired(), "OTL Invariant D");
        }
    }

    function assert_otl_invariant_E(address loan_) internal {
        IOpenTermLoan loan = IOpenTermLoan(loan_);

        if (loan.datePaid() != 0 && loan.dateCalled() != 0) {
            assertLe(loan.datePaid(), loan.dateCalled(), "OTL Invariant E");
        }
    }

    function assert_otl_invariant_F (address loan_) internal {
        IOpenTermLoan loan = IOpenTermLoan(loan_);

        assertLe(loan.calledPrincipal(), loan.principal(), "OTL Invariant F");
    }

    function assert_otl_invariant_G (address loan_) internal {
        IOpenTermLoan loan = IOpenTermLoan(loan_);

        assertTrue(
            loan.dateCalled() == 0 && loan.calledPrincipal() == 0 ||
            loan.dateCalled() != 0 && loan.calledPrincipal() != 0,
            "OTL Invariant G"
        );
    }

    function assert_otl_invariant_H(address loan_) internal {
        IOpenTermLoan loan = IOpenTermLoan(loan_);

        assertLe(loan.paymentDueDate(), loan.defaultDate(), "OTL Invariant H");
    }

    function assert_otl_invariant_I(address loan_) internal {
        IOpenTermLoan loan = IOpenTermLoan(loan_);

        (
            uint256 principal,
            uint256 interest,
            uint256 lateInterest,
            uint256 delegateServiceFee,
            uint256 platformServiceFee
        ) = loan.getPaymentBreakdown(block.timestamp);

        (
            uint256 expectedPrincipal,
            uint256 expectedInterest,
            uint256 expectedLateInterest,
            uint256 expectedDelegateServiceFee,
            uint256 expectedPlatformServiceFee
        ) = _getExpectedPaymentBreakdown(loan);

        assertEq(principal,          expectedPrincipal,          "OTL Invariant I (principal)");
        assertEq(interest,           expectedInterest,           "OTL Invariant I (interest)");
        assertEq(lateInterest,       expectedLateInterest,       "OTL Invariant I (lateInterest)");
        assertEq(delegateServiceFee, expectedDelegateServiceFee, "OTL Invariant I (delegateServiceFee)");
        assertEq(platformServiceFee, expectedPlatformServiceFee, "OTL Invariant I (platformServiceFee)");
    }

    /**************************************************************************************************************************************/
    /*** Open Term Loan Manager Invariants                                                                                              ***/
    /**************************************************************************************************************************************/

    function assert_otlm_invariant_A(address openTermLoanManager_, IOpenTermLoan[] memory loans_) internal {
        uint256 assetsUnderManagement = IOpenTermLoanManager(openTermLoanManager_).assetsUnderManagement();
        uint256 expectedAssetsUnderManagement;

        for (uint256 i; i < loans_.length; ++i) {
            expectedAssetsUnderManagement += loans_[i].principal() + _getExpectedNetInterest(loans_[i]);
        }

        // TODO: Checkout difference in real and expected AUM.
        assertApproxEqAbs(assetsUnderManagement, expectedAssetsUnderManagement, 200, "OTLM Invariant A");
    }

    function assert_otlm_invariant_B(address openTermLoanManager_, IOpenTermLoan[] memory loans_) internal {
        IOpenTermLoanManager openTermLoanManager = IOpenTermLoanManager(openTermLoanManager_);

        uint256 assetsUnderManagement = openTermLoanManager.assetsUnderManagement();

        for (uint256 i; i < loans_.length; ++i) {
            ( , , uint40 startDate, ) = openTermLoanManager.paymentFor(address(loans_[i]));

            if (startDate != 0) return;
        }

        assertApproxEqAbs(assetsUnderManagement, 0, otlHandler.numLoans(), "OTLM Invariant B");
    }

    function assert_otlm_invariant_C(address openTermLoanManager_, IOpenTermLoan[] memory loans_) internal {
        uint256 principalOut = IOpenTermLoanManager(openTermLoanManager_).principalOut();
        uint256 expectedPrincipalOut;

        for (uint256 i; i < loans_.length; ++i) {
            expectedPrincipalOut += loans_[i].principal();
        }

        assertEq(principalOut, expectedPrincipalOut, "OTLM Invariant C");
    }

    function assert_otlm_invariant_D(address openTermLoanManager_, IOpenTermLoan[] memory loans_) internal {
        IOpenTermLoanManager openTermLoanManager = IOpenTermLoanManager(openTermLoanManager_);

        uint256 issuanceRate = openTermLoanManager.issuanceRate();
        uint256 expectedIssuanceRate;

        for (uint256 i; i < loans_.length; ++i) {
            ( , , , uint168 issuanceRate_ ) = openTermLoanManager.paymentFor(address(loans_[i]));
            expectedIssuanceRate += issuanceRate_;
        }

        assertEq(issuanceRate, expectedIssuanceRate, "OTLM Invariant D");
    }

    function assert_otlm_invariant_E(address openTermLoanManager_) internal {
        IOpenTermLoanManager openTermLoanManager = IOpenTermLoanManager(openTermLoanManager_);

        uint256 unrealizedLosses      = openTermLoanManager.unrealizedLosses();
        uint256 assetsUnderManagement = openTermLoanManager.assetsUnderManagement();

        assertLe(unrealizedLosses, assetsUnderManagement, "OTLM Invariant E");
    }

    function assert_otlm_invariant_F(address openTermLoanManager_, IOpenTermLoan[] memory loans_) internal {
        IOpenTermLoanManager openTermLoanManager = IOpenTermLoanManager(openTermLoanManager_);

        uint256 unrealizedLosses = openTermLoanManager.unrealizedLosses();

        for (uint256 i; i < loans_.length; ++i) {
            ( uint40 impairmentDate, ) = openTermLoanManager.impairmentFor(address(loans_[i]));

            if (impairmentDate != 0) return;
        }

        assertEq(unrealizedLosses, 0, "OTLM Invariant F");
    }

    function assert_otlm_invariant_G(address openTermLoanManager_) internal {
        uint256 domainStart = IOpenTermLoanManager(openTermLoanManager_).domainStart();

        assertGe(block.timestamp, domainStart, "OTLM Invariant G");
    }

    function assert_otlm_invariant_H(address loan_, address openTermLoanManager_) internal {
        IOpenTermLoan loan = IOpenTermLoan(loan_);

        ( , , uint40 paymentStartDate, ) = IOpenTermLoanManager(openTermLoanManager_).paymentFor(address(loan));

        assertTrue(
            paymentStartDate == loan.dateFunded() ||
            paymentStartDate == loan.datePaid(),
            "OTLM Invariant H"
        );
    }

    function assert_otlm_invariant_I(address loan_, address openTermLoanManager_) internal {
        IOpenTermLoan loan = IOpenTermLoan(loan_);

        ( , , , uint168 issuanceRate ) = IOpenTermLoanManager(openTermLoanManager_).paymentFor(address(loan));
        uint256 expectedIssuanceRate   = _getExpectedIssuanceRate(loan);

        assertEq(issuanceRate, expectedIssuanceRate, "OTLM Invariant I");
    }

    function assert_otlm_invariant_J(address loan_, address openTermLoanManager_) internal {
        IOpenTermLoanManager openTermLoanManager = IOpenTermLoanManager(openTermLoanManager_);

        ( uint40 impairmentDate, ) = openTermLoanManager.impairmentFor(loan_);
        ( , , uint40 startDate, )  = openTermLoanManager.paymentFor(loan_);

        if (impairmentDate != 0) {
            assertGe(impairmentDate, startDate, "OTLM Invariant J");
        }
    }

    /**************************************************************************************************************************************/
    /*** Internal Helpers Functions                                                                                                     ***/
    /**************************************************************************************************************************************/

    function _getActiveLoans() internal view returns (IOpenTermLoan[] memory loans) {
        uint256 index;
        uint256 length;

        for (uint256 i; i < otlHandler.numLoans(); ++i) {
            if (IOpenTermLoan(otlHandler.loans(i)).dateFunded() != 0) length++;
        }

        loans = new IOpenTermLoan[](length);

        for (uint256 i; i < otlHandler.numLoans(); ++i) {
            IOpenTermLoan loan = IOpenTermLoan(otlHandler.loans(i));
            if (loan.dateFunded() != 0) {
                loans[index++] = loan;
            }
        }
    }

    function _getCurrentOutstandingInterest(address loan_, uint256 earliestPaymentDueDate)
        internal view
        returns (uint256 interestAccrued_)
    {
        IFixedTermLoan        loan        = IFixedTermLoan(loan_);
        IFixedTermLoanManager loanManager = IFixedTermLoanManager(loan.lender());

        if (loan.nextPaymentDueDate() == 0) {
            ( , , uint256 liquidationInterest , , , ) = loanManager.liquidationInfo(loan_);
            return liquidationInterest;
        }

        if (loan.isImpaired()) {
            ( , , uint256 regularInterest , , , ) = loanManager.liquidationInfo(loan_);
            return regularInterest;
        }

        ( , uint256[3] memory interestArray, ) = loan.getNextPaymentDetailedBreakdown();

        uint256 fundingTime      = ftlHandler.fundingTime(loan_);
        uint256 paymentTimestamp = ftlHandler.paymentTimestamp(loan_);

        // TODO: This will break with globals
        uint256 netInterest =
            interestArray[0] *
            (1e6 - globals.platformManagementFeeRate(address(poolManager)) - poolManager.delegateManagementFeeRate())
            / 1e6;

        uint256 startDate = paymentTimestamp == 0 ? fundingTime : min(paymentTimestamp, loan.nextPaymentDueDate() - loan.paymentInterval());

        uint256 endDate = min(block.timestamp, min(earliestPaymentDueDate, loan.nextPaymentDueDate()));

        interestAccrued_ =
            endDate < startDate
                ? netInterest
                // Use longer if early payment made
                : netInterest * (endDate - startDate) / max(loan.nextPaymentDueDate() - startDate, loan.paymentInterval());
    }

    function _getExpectedIssuanceRate(IOpenTermLoan loan) internal view returns (uint256 expectedIssuanceRate) {
        (
            uint24 platformManagementFeeRate,
            uint24 delegateManagementFeeRate,
            ,
        ) = IOpenTermLoanManager(otlHandler.loanManager()).paymentFor(address(loan));

        uint256 grossInterest  = _getProRatedAmount(loan.principal(), loan.interestRate(), loan.paymentInterval());
        uint256 managementFees = grossInterest * (delegateManagementFeeRate + platformManagementFeeRate) / 1e6;

        expectedIssuanceRate = (grossInterest - managementFees) * 1e27 / loan.paymentInterval();
    }

    function _getExpectedNetInterest(IOpenTermLoan loan) internal view returns (uint256 netInterest) {
        ( , uint256 grossInterest, , , ) = loan.getPaymentBreakdown(block.timestamp);
        (
            uint24 platformManagementFeeRate,
            uint24 delegateManagementFeeRate,
            ,
        ) = IOpenTermLoanManager(otlHandler.loanManager()).paymentFor(address(loan));

        uint256 managementFees = grossInterest * (delegateManagementFeeRate + platformManagementFeeRate) / 1e6;

        netInterest = grossInterest - managementFees;
    }

    function _getExpectedPaymentBreakdown(IOpenTermLoan loan) internal view
        returns (
            uint256 expectedPrincipal,
            uint256 expectedInterest,
            uint256 expectedLateInterest,
            uint256 expectedDelegateServiceFee,
            uint256 expectedPlatformServiceFee
        )
    {
        uint256 startTime    = loan.datePaid() == 0 ? loan.dateFunded() : loan.datePaid();
        uint256 interval     = block.timestamp - startTime;
        uint256 lateInterval = interval > loan.paymentInterval() ? interval - loan.paymentInterval() : 0;

        expectedPrincipal          = loan.dateCalled() == 0 ? 0 : loan.calledPrincipal();
        expectedInterest           = _getProRatedAmount(loan.principal(), loan.interestRate(), interval);
        expectedLateInterest       = 0;
        expectedDelegateServiceFee = _getProRatedAmount(loan.principal(), loan.delegateServiceFeeRate(), interval);
        expectedPlatformServiceFee = _getProRatedAmount(loan.principal(), loan.platformServiceFeeRate(), interval);

        if (lateInterval > 0) {
            expectedLateInterest += _getProRatedAmount(loan.principal(), loan.lateInterestPremiumRate(), lateInterval);
            expectedLateInterest += loan.principal() * loan.lateFeeRate() / 1e6;
        }
    }

    function _getNetInterest(uint256 interest_, uint256 feeRate_) internal pure returns (uint256 netInterest_) {
        netInterest_ = interest_ * (1e6 - feeRate_) / 1e6;
    }

    function _getProRatedAmount(uint256 amount_, uint256 rate_, uint256 interval_) internal pure returns (uint256 proRatedAmount_) {
        proRatedAmount_ = (amount_ * rate_ * interval_) / (365 days * 1e6);
    }

    function max(uint256 a_, uint256 b_) internal pure returns (uint256 maximum_) {
        maximum_ = a_ > b_ ? a_ : b_;
    }

    function min(uint256 a_, uint256 b_) internal pure returns (uint256 minimum_) {
        minimum_ = a_ < b_ ? a_ : b_;
    }

    /**************************************************************************************************************************************/
    /*** External Setter Functions                                                                                                      ***/
    /**************************************************************************************************************************************/

    function setCurrentTimestamp(uint256 currentTimestamp_) external {
        timestamps.push(currentTimestamp_);
        setTimestamps++;
        currentTimestamp = currentTimestamp_;
    }

    /**************************************************************************************************************************************/
    /*** Public View Functions                                                                                                          ***/
    /**************************************************************************************************************************************/

    function getAllOutstandingInterest() public returns (uint256 sumOutstandingInterest_) {
        for (uint256 i; i < ftlHandler.numLoans(); ++i) {
            ILoanLike loan_ = ILoanLike(ftlHandler.activeLoans(i));

            assertTrue(ftlHandler.earliestPaymentDueDate() == IFixedTermLoanManager(loan_.lender()).domainEnd());

            sumOutstandingInterest_ += _getCurrentOutstandingInterest(ftlHandler.activeLoans(i), ftlHandler.earliestPaymentDueDate());
        }
    }

    function getSumIssuanceRates() public view returns (uint256 sumIssuanceRate_) {
        for (uint256 i; i < ftlHandler.numLoans(); ++i) {
            ILoanLike             loan_        = ILoanLike(ftlHandler.activeLoans(i));
            IFixedTermLoanManager loanManager_ = IFixedTermLoanManager(loan_.lender());

            ( , , , , , , uint256 issuanceRate ) = loanManager_.payments(loanManager_.paymentIdOf(address(loan_)));

            sumIssuanceRate_ += issuanceRate;

            if (loan_.isImpaired()) {
                sumIssuanceRate_ -= issuanceRate;  // If the loan is impaired the issuance rate is 0
            }
        }
    }

}
