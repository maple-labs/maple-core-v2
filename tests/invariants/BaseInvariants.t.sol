// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { InvariantTest } from "../../modules/contract-test-utils/contracts/test.sol";

import { IMapleLoan, IMapleLoanFeeManager } from "../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

import { LoanHandler } from "./actors/LoanHandler.sol";
import { LpHandler }   from "./actors/LpHandler.sol";

contract BaseInvariants is InvariantTest, TestBaseWithAssertions {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    LoanHandler internal loanHandler;
    LpHandler   internal lpHandler;

    uint256 internal setTimestamps;

    address[] public borrowers;

    uint256[] internal timestamps;

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
     * Loan
        * Invariant A: collateral balance >= _collateral`
        * Invariant B: fundsAsset >= _drawableFunds`
        * Invariant C: `_collateral >= collateralRequired_ * (principal_ - drawableFunds_) / principalRequested_`

     * Loan Manager (non-liquidating)
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

    LoanHandler requires (WIP)
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
    /*** Loan Invariants                                                                                                                ***/
    /**************************************************************************************************************************************/

    function assert_loan_invariant_A(address loan) internal {
        assertGe(collateralAsset.balanceOf(loan), IMapleLoan(loan).collateral(), "Loan Invariant A");
    }

    function assert_loan_invariant_B(address loan) internal {
        assertGe(fundsAsset.balanceOf(loan), IMapleLoan(loan).drawableFunds(), "Loan Invariant B");
    }

    // NOTE: Commented out as `makePayment` does not include a `_isCollateralMaintained` check. This will be added in a subsequent loan release.
    // TODO: Add `_isCollateralMaintained` to loan v4.0.2 (consider adding to v4.0.1)
    function assert_loan_invariant_C(address loan_) internal {
        // IMapleLoan           loan       = IMapleLoan(loan_);
        // IMapleLoanFeeManager feeManager = IMapleLoanFeeManager(loan.feeManager());

        // console.log("loan.paymentsRemaining()", loan.paymentsRemaining());

        // // The loan is matured or repossessed, the invariant will underflow because delegateOriginationFee > 0
        // if (loan.nextPaymentDueDate() == 0) return;

        // // If the drawableFunds is greater than the current principal, no collateral is required.
        // if (loan.drawableFunds() > loan.principal()) return;

        // uint256 platformOriginationFee = feeManager.getPlatformOriginationFee(address(loan), loan.principalRequested());

        // uint256 fundedAmount = loan.principalRequested() - (feeManager.delegateOriginationFee(address(loan)) + platformOriginationFee);

        // // If drawableFunds exactly equals the funded amount, assume funds haven't been drawn down.
        // if (loan.drawableFunds() == fundedAmount) return;

        // assertGe(
        //     loan.collateral(),
        //     loan.collateralRequired() * ((loan.principal() - loan.drawableFunds()) + loan.principalRequested() - 1) / loan.principalRequested(),
        //     "Loan Invariant C"
        // );
    }

    /**************************************************************************************************************************************/
    /*** Loan Manager Invariants                                                                                                        ***/
    /**************************************************************************************************************************************/

    function assert_loanManager_invariant_A() internal {
        assertLe(loanManager.domainStart(), loanManager.domainEnd(), "LoanManager Invariant A");
    }

    function assert_loanManager_invariant_B() internal {
        uint256 next = loanManager.paymentWithEarliestDueDate();

        uint256 previousPaymentDueDate;
        uint256 nextPaymentDueDate;

        while (next != 0) {
            uint256 current = next;

            ( , next, ) = loanManager.sortedPayments(current);  // Overwrite `next` in loop

            ( , , nextPaymentDueDate ) = loanManager.sortedPayments(next);  // Get the next payment due date

            if (next == 0 && nextPaymentDueDate == 0) break;  // End of list

            assertLe(previousPaymentDueDate, nextPaymentDueDate, "LoanManager Invariant B");

            previousPaymentDueDate = nextPaymentDueDate;  // Set the previous payment due date
        }
    }

    function assert_loanManager_invariant_C() internal {
        vm.warp(currentTimestamp);

        uint256 sumOutstandingInterest = getAllOutstandingInterest();

        assertWithinDiff(
            loanManager.accountedInterest() + loanManager.getAccruedInterest(),
            sumOutstandingInterest,
            max(loanHandler.numPayments(), loanHandler.numLoans()) + 1,
            "LoanManager Invariant C"
        );
    }

    function assert_loanManager_invariant_D() internal {
        assertEq(loanManager.principalOut(), loanHandler.sum_loan_principal(), "LoanManager Invariant D");
    }

    function assert_loanManager_invariant_E() internal {
        assertEq(loanManager.issuanceRate(), getSumIssuanceRates(), "LoanManager Invariant E");
    }

    function assert_loanManager_invariant_F() internal {
        // NOTE: To account for precision errors for unrealizedLosses(), we add 1 to the AUM
        uint256 losses   = loanManager.unrealizedLosses();
        uint256 aum      = loanManager.assetsUnderManagement();
        uint256 payments = loanHandler.numPayments();

        if (losses > aum) {
            assertWithinDiff(losses, aum, payments + 1);
        } else {
            assertLe(losses, aum + 1, "LoanManager Invariant F");

        }
    }

    function assert_loanManager_invariant_G() internal {
        assertEq(loanManager.unrealizedLosses(), 0, "LoanManager Invariant G");
    }

    function assert_loanManager_invariant_H() internal {
        assertWithinDiff(
            loanManager.assetsUnderManagement(),
            getAllOutstandingInterest() + loanHandler.sum_loan_principal(),
            max(loanHandler.numPayments(), loanHandler.numLoans()) + 1,
            "LoanManager Invariant H"
        );
    }

    function assert_loanManager_invariant_I() internal {
        assertLe(loanManager.domainStart(), block.timestamp, "LoanManager Invariant I");
    }

    function assert_loanManager_invariant_J() internal {
        if (loanManager.paymentWithEarliestDueDate() != 0) {
            assertGt(loanManager.issuanceRate(), 0, "LoanManager Invariant J");
        }
    }

    function assert_loanManager_invariant_K() internal {
        uint256 paymentWithEarliestDueDate = loanManager.paymentWithEarliestDueDate();

        ( , , uint256 earliestPaymentDueDate ) = loanManager.sortedPayments(paymentWithEarliestDueDate);

        if (paymentWithEarliestDueDate != 0) {
            assertEq(loanManager.domainEnd(), earliestPaymentDueDate, "LoanManager Invariant K");
        }
    }

    function assert_loanManager_invariant_L(address loan, uint256 refinanceInterest) internal {
        uint256 platformManagementFeeRate_ = globals.platformManagementFeeRate(address(poolManager));
        uint256 delegateManagementFeeRate_ = poolManager.delegateManagementFeeRate();
        uint256 managementFeeRate_         = platformManagementFeeRate_ + delegateManagementFeeRate_;

        assertEq(refinanceInterest, _getNetInterest(IMapleLoan(loan).refinanceInterest(), managementFeeRate_), "LoanManager Invariant L");
    }

    function assert_loanManager_invariant_M(address loan, uint256 paymentDueDate) internal {
        assertEq(paymentDueDate, IMapleLoan(loan).nextPaymentDueDate(), "LoanManager Invariant M");
    }

    function assert_loanManager_invariant_N(address loan, uint256 startDate) internal {
        assertLe(startDate, IMapleLoan(loan).nextPaymentDueDate() - IMapleLoan(loan).paymentInterval(), "LoanManager Invariant N");
    }

    /**************************************************************************************************************************************/
    /*** Pool Invariants                                                                                                                ***/
    /**************************************************************************************************************************************/

    function assert_pool_invariant_A() internal {
        assertGe(pool.totalAssets(), fundsAsset.balanceOf(address(pool)), "Pool Invariant A");
    }

    function assert_pool_invariant_B(uint256 sumBalanceOfAssets) internal {
        assertGe(pool.totalAssets(), sumBalanceOfAssets, "Pool Invariant B1");

        assertWithinDiff(pool.totalAssets(), sumBalanceOfAssets, lpHandler.numHolders(), "Pool Invariant B2");
    }

    function assert_pool_invariant_C() internal {
        assertGe(pool.totalAssets(), pool.totalSupply(), "Pool Invariant C");
    }

    function assert_pool_invariant_D() internal {
        assertGe(pool.totalAssets(), pool.convertToAssets(pool.totalSupply()), "Pool Invariant D1");

        assertWithinDiff(pool.totalAssets(), pool.convertToAssets(pool.totalSupply()), 1, "Pool Invariant D2");
    }

    function assert_pool_invariant_E() internal {
        assertGe(pool.convertToShares(pool.totalAssets()), pool.totalSupply(), "Pool Invariant E1");

        assertWithinDiff(pool.convertToShares(pool.totalAssets()), pool.totalSupply(), 1, "Pool Invariant E2");
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
        if (pool.totalAssets() > 0) {
            assertEq(pool.convertToExitShares(pool.totalAssets()), poolManager.convertToExitShares(pool.totalAssets()), "Pool Invariant K");
        }
    }

    /**************************************************************************************************************************************/
    /*** Pool Manager Functions                                                                                                         ***/
    /**************************************************************************************************************************************/

    function assert_poolManager_invariant_A() internal {
        uint256 expectedTotalAssets = loanHandler.sum_loan_principal() + getAllOutstandingInterest() + fundsAsset.balanceOf(address(pool));

        assertWithinDiff(
            poolManager.totalAssets(),
            expectedTotalAssets,
            max(loanHandler.numPayments(), loanHandler.numLoans()) + 1,
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
    /*** Internal Helpers Functions                                                                                                     ***/
    /**************************************************************************************************************************************/

    function _getCurrentOutstandingInterest(address loan_, uint256 earliestPaymentDueDate)
        internal view
        returns (uint256 interestAccrued_)
    {
        IMapleLoan loan = IMapleLoan(loan_);

        if (loan.nextPaymentDueDate() == 0) {
            ( , , uint256 liquidationInterest , , , ) = loanManager.liquidationInfo(loan_);
            return liquidationInterest;
        }

        if (loan.isImpaired()) {
            ( , , uint256 regularInterest , , , ) = loanManager.liquidationInfo(loan_);
            return regularInterest;
        }

        ( , uint256[3] memory interestArray, ) = loan.getNextPaymentDetailedBreakdown();

        uint256 fundingTime      = loanHandler.fundingTime(loan_);
        uint256 paymentTimestamp = loanHandler.paymentTimestamp(loan_);

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

    function _getNetInterest(uint256 interest_, uint256 feeRate_) internal pure returns (uint256 netInterest_) {
        netInterest_ = interest_ * (1e6 - feeRate_) / 1e6;
    }

    function _excludeAllContracts() internal {
        excludeContract(governor);
        excludeContract(poolDelegate);
        excludeContract(treasury);

        excludeContract(liquidatorFactory);
        excludeContract(liquidatorInitializer);
        excludeContract(liquidatorImplementation);

        excludeContract(loanFactory);
        excludeContract(loanImplementation);
        excludeContract(loanInitializer);

        excludeContract(loanManagerFactory);
        excludeContract(loanManagerInitializer);
        excludeContract(loanManagerImplementation);

        excludeContract(poolManagerFactory);
        excludeContract(poolManagerImplementation);
        excludeContract(poolManagerInitializer);

        excludeContract(withdrawalManagerFactory);
        excludeContract(withdrawalManagerImplementation);
        excludeContract(withdrawalManagerInitializer);

        excludeContract(address(collateralAsset));
        excludeContract(address(deployer));
        excludeContract(address(globals));
        excludeContract(address(feeManager));
        excludeContract(address(fundsAsset));
        excludeContract(address(loanManager));
        excludeContract(address(pool));
        excludeContract(address(poolCover));
        excludeContract(address(poolManager));
        excludeContract(address(withdrawalManager));

        excludeContract(globals.implementation());
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
        for (uint256 i; i < loanHandler.numLoans(); ++i) {

            assertTrue(loanHandler.earliestPaymentDueDate() == loanManager.domainEnd());

            sumOutstandingInterest_ += _getCurrentOutstandingInterest(loanHandler.activeLoans(i), loanHandler.earliestPaymentDueDate());
        }
    }

    function getSumIssuanceRates() public view returns (uint256 sumIssuanceRate_) {
        for (uint256 i; i < loanHandler.numLoans(); ++i) {
            address loan_ = loanHandler.activeLoans(i);
            ( , , , , , , uint256 issuanceRate ) = loanManager.payments(loanManager.paymentIdOf(loan_));
            sumIssuanceRate_ += issuanceRate;

            if (IMapleLoan(loan_).isImpaired()) {
                sumIssuanceRate_ -= issuanceRate;  // If the loan is impaired the issuance rate is 0
            }
        }
    }

}


