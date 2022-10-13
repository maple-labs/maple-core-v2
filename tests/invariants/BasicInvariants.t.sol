// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { Address, console, InvariantTest } from "../../modules/contract-test-utils/contracts/test.sol";
import { IMapleLoan }                      from "../../modules/loan/contracts/interfaces/IMapleLoan.sol";
import { IMapleLoanFeeManager }            from "../../modules/loan/contracts/interfaces/IMapleLoanFeeManager.sol";

import { TestBaseWithAssertions } from "../../contracts/utilities/TestBaseWithAssertions.sol";

import { LoanHandler } from "./actors/LoanHandler.sol";
import { LpHander }    from "./actors/LpHandler.sol";

contract BasicInterestAccrualTest is InvariantTest, TestBaseWithAssertions {

    /******************************************************************************************************************************/
    /*** State Variables                                                                                                        ***/
    /******************************************************************************************************************************/

    uint256 constant public NUM_BORROWERS = 5;
    uint256 constant public NUM_LPS       = 10;

    LoanHandler loanHandler;
    LpHander    lpHandler;

    uint256 setTimestamps;

    address[] public borrowers;

    uint256[] timestamps;

    uint256 public currentTimestamp;

    /******************************************************************************************************************************/
    /*** Setup Function                                                                                                         ***/
    /******************************************************************************************************************************/

    function setUp() public override {
        super.setUp();

        _excludeAllContracts();

        currentTimestamp = block.timestamp;

        loanHandler = new LoanHandler({
            collateralAsset_: address(collateralAsset),
            feeManager_:      address(feeManager),
            fundsAsset_:      address(fundsAsset),
            globals_:         address(globals),
            governor_:        governor,
            loanFactory_:     loanFactory,
            poolManager_:     address(poolManager),
            testContract_:    address(this),
            numBorrowers_:    NUM_BORROWERS
        });

        lpHandler = new LpHander(address(pool), address(this), NUM_LPS);

        targetContract(address(lpHandler));
        targetContract(address(loanHandler));

        targetSender(address(0xdeed));
    }

    /******************************************************************************************************************************/
    /*** Modifiers                                                                                                              ***/
    /******************************************************************************************************************************/

    modifier useCurrentTimestamp() {
        vm.warp(currentTimestamp);
        _;
    }

    /******************************************************************************************************************************/
    /*** Invariant Tests                                                                                                        ***/
    /*******************************************************************************************************************************
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
        * Invariant K: convertToExitShares == poolManager.converToExitShares()

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
        * Invariant M: lockedLiquidity <= fundsAsset balance of pool
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
        * Treausry balance increases
        * PD balance increases if cover
        * payment management rates equal current rates
        * domainStart == block.timestamp
        * domainEnd   == paymentWithEarliestDueDate
        * issuanceRate > 0
    *******************************************************************************************************************************/

    /******************************************************************************************************************************/
    /*** Loan Invariants                                                                                                        ***/
    /******************************************************************************************************************************/

    function invariant_loan_A_collateralBalGteCollateral() external useCurrentTimestamp {
        for (uint256 i; i < loanHandler.numLoans(); ++i) {
            address loan = loanHandler.activeLoans(i);
            assertTrue(collateralAsset.balanceOf(loan) >= IMapleLoan(loan).collateral());
        }
    }

    function invariant_loan_B_fundsAssetBalGteDrawableFunds() external useCurrentTimestamp {
        for (uint256 i; i < loanHandler.numLoans(); ++i) {
            address loan = loanHandler.activeLoans(i);
            assertTrue(fundsAsset.balanceOf(loan) >= IMapleLoan(loan).drawableFunds());
        }
    }

    function invariant_loan_C_collateralRequirementsHeld() external useCurrentTimestamp {
        for (uint256 i; i < loanHandler.numLoans(); ++i) {
            IMapleLoan           loan       = IMapleLoan(loanHandler.activeLoans(i));
            IMapleLoanFeeManager feeManager = IMapleLoanFeeManager(loan.feeManager());

            uint256 platformOriginationFee = feeManager.getPlatformOriginationFee(address(loan), loan.principalRequested());
            uint256 fundedAmount = loan.principal() - feeManager.delegateOriginationFee(address(loan)) - platformOriginationFee;

            assertTrue(
                loan.drawableFunds() >= fundedAmount ||
                loan.collateral() >= loan.collateralRequired() * (fundedAmount - loan.drawableFunds()) / loan.principalRequested()
            );
        }
    }

    /******************************************************************************************************************************/
    /*** Loan Manager Invariants                                                                                                ***/
    /******************************************************************************************************************************/

    function invariant_loanManager_A_totalDSLteDE() external useCurrentTimestamp {
        assertTrue(loanManager.domainStart() <= loanManager.domainEnd());
    }

    function skip_invariant_loanManager_B_sortedList() external useCurrentTimestamp {
        uint256 next = loanManager.paymentWithEarliestDueDate();

        uint256 previousPaymentDueDate;
        uint256 nextPaymentDueDate;

        while (next != 0) {
            uint256 current = next;

            ( , next, ) = loanManager.sortedPayments(current);  // Overwrite `next` in loop

            ( , , nextPaymentDueDate ) = loanManager.sortedPayments(next);  // Get the next payment due date

            if (next == 0 && nextPaymentDueDate == 0) break;  // End of list

            assertTrue(previousPaymentDueDate <= nextPaymentDueDate);

            previousPaymentDueDate = nextPaymentDueDate;  // Set the previous payment due date
        }
    }

    function invariant_loanManager_C_outstandingInterestEqSumOutstandingInterest() external useCurrentTimestamp {
        vm.warp(currentTimestamp);

        uint256 sumOutstandingInterest = getAllOutstandingInterest();

        assertWithinDiff(loanManager.accountedInterest() + loanManager.getAccruedInterest(), sumOutstandingInterest, max(loanHandler.numPayments(), loanHandler.numLoans()) + 1);
    }

    function invariant_loanManager_D_principalOutEqSumPrincipal() external useCurrentTimestamp {
        assertTrue(loanManager.principalOut() == loanHandler.sum_loan_principal());
    }

    function invariant_loanManager_E_issuanceRateEqSumPaymentIssuanceRate() external useCurrentTimestamp {
        assertTrue(loanManager.issuanceRate() == getSumIssuanceRates());
    }

    function invariant_loanManager_F_unrealizedLossesLteAssetsUnderManagement() external useCurrentTimestamp {
        assertTrue(loanManager.unrealizedLosses() <= loanManager.assetsUnderManagement());
    }

    function invariant_loanManager_G_unrealizedLossesEqZero() external useCurrentTimestamp {
        assertTrue(loanManager.unrealizedLosses() == 0);
    }

    function invariant_loanManager_H_assetsUnderManagementEqSumPrincipalAndInterest() external useCurrentTimestamp {
        console.log("loanManager.assetsUnderManagement()", loanManager.assetsUnderManagement());
        console.log("loanHandler.sum_loan_principal()   ", loanHandler.sum_loan_principal());
        console.log("getAllOutstandingInterest()        ", getAllOutstandingInterest());

        assertWithinDiff(
            loanManager.assetsUnderManagement(),
            getAllOutstandingInterest() + loanHandler.sum_loan_principal(),
            max(loanHandler.numPayments(), loanHandler.numLoans()) + 1
        );
    }

    function invariant_loanManager_I_domainStartLteBlockTimestamp() external useCurrentTimestamp {
        assertTrue(loanManager.domainStart() <= block.timestamp);
    }

    function invariant_loanManager_J_issuanceRateGtZeroWithActiveLoanAccounting() external useCurrentTimestamp {
        assertTrue(
            loanManager.paymentWithEarliestDueDate() == 0 ||
            loanManager.issuanceRate() > 0
        );
    }

    function invariant_loanManager_K_domainStartEqEarliestPaymentWithActiveLoanAccounting() external useCurrentTimestamp {
        uint256 paymentWithEarliestDueDate = loanManager.paymentWithEarliestDueDate();

        ( , , uint256 earliestPaymentDueDate ) = loanManager.sortedPayments(paymentWithEarliestDueDate);

        assertTrue(
            paymentWithEarliestDueDate == 0 ||
            loanManager.domainEnd() == earliestPaymentDueDate
        );
    }

    function invariant_loanManager_L_refinanceInterestMatch() external useCurrentTimestamp {
        for (uint256 i; i < loanHandler.numLoans(); ++i) {
            IMapleLoan loan = IMapleLoan(loanHandler.activeLoans(i));
            ( , , , , , uint256 refinanceInterest , ) = loanManager.payments(loanManager.paymentIdOf(address(loan)));
            assertTrue(refinanceInterest == loan.refinanceInterest());
        }
    }

    function invariant_loanManager_M_paymentDueDateMatch() external useCurrentTimestamp {
        for (uint256 i; i < loanHandler.numLoans(); ++i) {
            IMapleLoan loan = IMapleLoan(loanHandler.activeLoans(i));
            ( , , , uint256 paymentDueDate , , , ) = loanManager.payments(loanManager.paymentIdOf(address(loan)));
            assertTrue(paymentDueDate == loan.nextPaymentDueDate());
        }
    }

    function invariant_loanManager_N_startDateLteLastPaymentDueDate() external useCurrentTimestamp {
        for (uint256 i; i < loanHandler.numLoans(); ++i) {
            IMapleLoan loan = IMapleLoan(loanHandler.activeLoans(i));
            ( , , uint256 startDate , , , , ) = loanManager.payments(loanManager.paymentIdOf(address(loan)));
            assertTrue(startDate <= loan.nextPaymentDueDate() - loan.paymentInterval());
        }
    }

    /******************************************************************************************************************************/
    /*** Pool Invariants                                                                                                        ***/
    /******************************************************************************************************************************/

    function invariant_pool_A_totalAssetGteCashBalance() external useCurrentTimestamp {
        assertTrue(pool.totalAssets() >= fundsAsset.balanceOf(address(pool)));
    }

    function invariant_pool_B_sumBalanceOfAssetsEqTotalAssets() external useCurrentTimestamp {
        uint256 sumBalanceOfAssets;
        for (uint256 i; i < lpHandler.numHolders(); ++i) {
            sumBalanceOfAssets += pool.balanceOfAssets(lpHandler.holders(i));
        }
        assertTrue(pool.totalAssets() >= sumBalanceOfAssets);
        assertTrue(pool.totalAssets() -  sumBalanceOfAssets <= lpHandler.numHolders());
    }

    function invariant_pool_C_totalAssetsGteTotalSupply() external useCurrentTimestamp {
        assertTrue(pool.totalAssets() >= pool.totalAssets());
    }

    function invariant_pool_D_convertToAssetsExchangeRateMatch() external useCurrentTimestamp {
        assertTrue(pool.totalAssets() >= pool.convertToAssets(pool.totalSupply()));
        assertTrue(pool.totalAssets() -  pool.convertToAssets(pool.totalSupply()) <= 1);
    }

    function invariant_pool_E_convertToSharesExchangeRateMatch() external useCurrentTimestamp {
        assertTrue(pool.convertToShares(pool.totalAssets()) >= pool.totalSupply());
        assertTrue(pool.convertToShares(pool.totalAssets()) -  pool.totalSupply() <= 1);
    }

    function invariant_pool_F_balanceOfAssetsGtBalanceOf() external useCurrentTimestamp {
        for (uint256 i; i < lpHandler.numHolders(); ++i) {
            assertTrue(pool.balanceOfAssets(lpHandler.holders(i)) >= pool.balanceOf(lpHandler.holders(i)));
        }
    }

    function invariant_pool_G_sumBalanceOfAssetsEqTotalSupply() external useCurrentTimestamp {
        uint256 sumBalanceOf;
        for (uint256 i; i < lpHandler.numHolders(); ++i) {
            sumBalanceOf += pool.balanceOf(lpHandler.holders(i));
        }
        assertTrue(pool.totalSupply() == sumBalanceOf);
    }

    function invariant_pool_H_convertToSharesEqConvertToExitShares() external useCurrentTimestamp {
        if (pool.totalAssets() > 0) {
            assertTrue(pool.convertToShares(pool.totalAssets()) == pool.convertToExitShares(pool.totalAssets()));
        }
    }

    function invariant_pool_I_totalAssetsPoolManagerMatch() external useCurrentTimestamp {
        assertTrue(pool.totalAssets() == poolManager.totalAssets());
    }

    function invariant_pool_J_unrealizedLossesPoolManagerMatch() external useCurrentTimestamp {
        assertTrue(pool.unrealizedLosses() == poolManager.unrealizedLosses());
    }

    function invariant_pool_K_convertToExitSharesPoolManagerMatch() external useCurrentTimestamp {
        if (pool.totalAssets() > 0) {
            assertTrue(pool.convertToExitShares(pool.totalAssets()) == poolManager.convertToExitShares(pool.totalAssets()));
        }
    }

    /******************************************************************************************************************************/
    /*** Pool Manager Functions                                                                                                 ***/
    /******************************************************************************************************************************/

    function invariant_poolManager_A_totalAssetsEqCashPlusAUM() external useCurrentTimestamp {
        uint256 expectedTotalAssets = loanHandler.sum_loan_principal() + getAllOutstandingInterest() + fundsAsset.balanceOf(address(pool));

        assertWithinDiff(poolManager.totalAssets(), expectedTotalAssets, max(loanHandler.numPayments(), loanHandler.numLoans()) + 1);
    }

    /******************************************************************************************************************************/
    /*** Withdrawal Manager Invariants                                                                                          ***/
    /******************************************************************************************************************************/

    function invariant_withdrawalManager_A_totalAssetsEqCashPlusAUM() external useCurrentTimestamp {
        uint256 sumLockedShares;
        for (uint256 i; i < lpHandler.numLps(); ++i) {
            sumLockedShares += withdrawalManager.lockedShares(lpHandler.lps(i));
        }
        assertTrue(pool.balanceOf(address(withdrawalManager)) == sumLockedShares);
    }

    function invariant_withdrawalManager_B_totalCycleSharesEqLockedShares() external useCurrentTimestamp {
        uint256 currentCycleId = withdrawalManager.getCurrentCycleId();

        for (uint256 cycleId = 1; cycleId <= currentCycleId; ++cycleId) {
            uint256 sumCycleShares;

            for (uint256 i; i < lpHandler.numLps(); ++i) {
                if (withdrawalManager.exitCycleId(lpHandler.lps(i)) == cycleId) {
                    sumCycleShares += withdrawalManager.lockedShares(lpHandler.lps(i));
                }
            }

            assertTrue(withdrawalManager.totalCycleShares(cycleId) == sumCycleShares);
        }
    }

    function invariant_withdrawalManager_C_currentCycleWindowStartLteBlockTimestamp() external useCurrentTimestamp {
        uint256 withdrawalWindowStart = withdrawalManager.getWindowStart(withdrawalManager.getCurrentCycleId());

        assertTrue(withdrawalWindowStart <= block.timestamp);
    }

    function invariant_withdrawalManager_D_initialCycleTimeCurrentConfigLteBlockTimestamp() external useCurrentTimestamp {
        ( , uint256 initialCycleTime , , ) = withdrawalManager.cycleConfigs(withdrawalManager.getCurrentCycleId());

        assertTrue(initialCycleTime <= block.timestamp);
    }

    function invariant_withdrawalManager_E_initialCycleIdCurrentConfigLteCurrentCycle() external useCurrentTimestamp {
        ( uint256 initialCycleId , , , ) = withdrawalManager.cycleConfigs(withdrawalManager.getCurrentCycleId());

        assertTrue(initialCycleId <= withdrawalManager.getCurrentCycleId());
    }

    function invariant_withdrawalManager_F_getRedeemableAmountsSharesLteLPBalance() external useCurrentTimestamp {
        if (pool.totalSupply() == 0 || pool.totalAssets() == 0) return;

        for (uint256 i; i < lpHandler.numLps(); ++i) {
            address lp = lpHandler.lps(i);

            ( uint256 shares , , ) = withdrawalManager.getRedeemableAmounts(withdrawalManager.lockedShares(lp), lp);

            assertTrue(shares <= pool.balanceOf(address(withdrawalManager)));
        }
    }

    function invariant_withdrawalManager_G_getRedeemableAmountsSharesLteLockedShares() external useCurrentTimestamp {
        if (pool.totalSupply() == 0 || pool.totalAssets() == 0) return;

        for (uint256 i; i < lpHandler.numLps(); ++i) {
            address lp = lpHandler.lps(i);

            ( uint256 shares , , ) = withdrawalManager.getRedeemableAmounts(withdrawalManager.lockedShares(lp), lp);

            assertTrue(shares <= withdrawalManager.lockedShares(lp));
        }
    }

    function invariant_withdrawalManager_H_getRedeemableAmountsSharesLteTotalCycleSharesInCycle() external useCurrentTimestamp {
        if (pool.totalSupply() == 0 || pool.totalAssets() == 0) return;

        for (uint256 i; i < lpHandler.numLps(); ++i) {
            address lp = lpHandler.lps(i);

            ( uint256 shares, , ) = withdrawalManager.getRedeemableAmounts(withdrawalManager.lockedShares(lp), lp);

            assertTrue(shares <= withdrawalManager.totalCycleShares(withdrawalManager.exitCycleId(lp)));
        }
    }

    function invariant_withdrawalManager_I_getRedeemableAmountsAssetsLteCashBalance() external useCurrentTimestamp {
        if (pool.totalSupply() == 0 || pool.totalAssets() == 0) return;

        for (uint256 i; i < lpHandler.numLps(); ++i) {
            address lp = lpHandler.lps(i);

            ( , uint256 assets , ) = withdrawalManager.getRedeemableAmounts(withdrawalManager.lockedShares(lp), lp);

            assertTrue(assets <= fundsAsset.balanceOf(address(pool)));
        }
    }

    function invariant_withdrawalManager_J_getRedeemableAmountsAssetsLteTotalRequestedLiquidity() external useCurrentTimestamp {
        if (pool.totalSupply() == 0 || pool.totalAssets() == 0) return;

        for (uint256 i; i < lpHandler.numLps(); ++i) {
            address lp = lpHandler.lps(i);

            ( , uint256 assets , ) = withdrawalManager.getRedeemableAmounts(withdrawalManager.lockedShares(lp), lp);

            uint256 totalRequestedLiquidity = withdrawalManager.totalCycleShares(withdrawalManager.exitCycleId(lp)) * pool.totalAssets() / pool.totalSupply();

            assertTrue(assets <= totalRequestedLiquidity);
        }
    }

    function invariant_withdrawalManager_K_getRedeemableAmountsAssetsLteLockedSharesConverted() external useCurrentTimestamp {
        if (pool.totalSupply() == 0 || pool.totalAssets() == 0) return;

        for (uint256 i; i < lpHandler.numLps(); ++i) {
            address lp = lpHandler.lps(i);

            ( , uint256 assets , ) = withdrawalManager.getRedeemableAmounts(withdrawalManager.lockedShares(lp), lp);

            uint256 lpRequestedLiquidity = withdrawalManager.lockedShares(lp) * pool.totalAssets() / pool.totalSupply();

            assertTrue(assets <= lpRequestedLiquidity);
        }
    }

    function invariant_withdrawalManager_L_getRedeemableAmountsAssetsPartialLiquidityMatch() external useCurrentTimestamp {
        if (pool.totalSupply() == 0 || pool.totalAssets() == 0) return;

        for (uint256 i; i < lpHandler.numLps(); ++i) {
            address lp = lpHandler.lps(i);

            ( , , bool partialLiquidity ) = withdrawalManager.getRedeemableAmounts(withdrawalManager.lockedShares(lp), lp);

            uint256 totalRequestedLiquidity = withdrawalManager.totalCycleShares(withdrawalManager.exitCycleId(lp)) * pool.totalAssets() / pool.totalSupply();

            assertTrue(partialLiquidity == (fundsAsset.balanceOf(address(pool)) <= totalRequestedLiquidity));
        }
    }

    function invariant_withdrawalManager_M_lockedLiquidityLteCashBalance() external useCurrentTimestamp {
        if (pool.totalSupply() == 0 || pool.totalAssets() == 0) return;

        ( uint256 windowStart, uint256 windowEnd ) = withdrawalManager.getWindowAtId(withdrawalManager.getCurrentCycleId());

        if (block.timestamp >= windowStart && block.timestamp < windowEnd) {
            assertTrue(withdrawalManager.lockedLiquidity() <= fundsAsset.balanceOf(address(pool)));
        } else {
            assertTrue(withdrawalManager.lockedLiquidity() == 0);
        }
    }

    function invariant_withdrawalManager_N_lockedLiquidityLteTotalCycleSharesConverted() external useCurrentTimestamp {
        if (pool.totalSupply() == 0 || pool.totalAssets() == 0) return;

        uint256 currentCycle = withdrawalManager.getCurrentCycleId();

        ( uint256 windowStart, uint256 windowEnd ) = withdrawalManager.getWindowAtId(currentCycle);

        if (block.timestamp >= windowStart && block.timestamp < windowEnd) {
            assertTrue(withdrawalManager.lockedLiquidity() <= withdrawalManager.totalCycleShares(currentCycle) * pool.totalAssets() / pool.totalSupply());
        } else {
            assertTrue(withdrawalManager.lockedLiquidity() == 0);
        }
    }

    /******************************************************************************************************************************/
    /*** Internal Helpers Functions                                                                                             ***/
    /******************************************************************************************************************************/

    function _getCurrentOutstandingInterest(address loan_, uint256 earliestPaymentDueDate) internal view returns (uint256 interestAccrued_) {
        IMapleLoan loan = IMapleLoan(loan_);

        if (loan.nextPaymentDueDate() == 0) return 0;

        ( , uint256[3] memory interestArray, ) = loan.getNextPaymentDetailedBreakdown();

        uint256 fundingTime      = loanHandler.fundingTime(loan_);
        uint256 paymentTimestamp = loanHandler.paymentTimestamp(loan_);

        // TODO: This will break with globals
        uint256 netInterest = interestArray[0] * (1e6 - globals.platformManagementFeeRate(address(poolManager)) - poolManager.delegateManagementFeeRate()) / 1e6;

        uint256 startDate = paymentTimestamp == 0 ? fundingTime : min(paymentTimestamp, loan.nextPaymentDueDate() - loan.paymentInterval());

        uint256 endDate = min(block.timestamp, min(earliestPaymentDueDate, loan.nextPaymentDueDate()));

        interestAccrued_ =
            endDate < startDate
                ? netInterest
                : netInterest * (endDate - startDate) / max(loan.nextPaymentDueDate() - startDate, loan.paymentInterval());  // Use longer if early payment made

        console.log("");
        console.log("paymentTimestamp         ", paymentTimestamp);
        console.log("fundingTime              ", fundingTime);
        console.log("block.timestamp          ", block.timestamp);
        console.log("earliestPaymentDueDate   ", earliestPaymentDueDate);
        console.log("loan.nextPaymentDueDate()", loan.nextPaymentDueDate());
        console.log("loan.paymentInterval()   ", loan.paymentInterval());
        console.log("netInterest              ", netInterest);
        console.log("startDate                ", startDate);
        console.log("endDate                  ", endDate);
        console.log("interestAccrued_         ", interestAccrued_);
        // console.log("lateInterest             ", loanHandler.lateIntervalInterest(loan_));
        console.log("-------------------------");
        console.log("domainStart                             ", loanManager.domainStart());
        console.log("domainEnd                               ", loanManager.domainEnd());
        console.log("block.timestamp                         ", block.timestamp);
        console.log("accruedInterest                         ", loanManager.getAccruedInterest());
        console.log("accountedInterest                       ", loanManager.accountedInterest());
        console.log("outstandingInterest                     ", loanManager.getAccruedInterest() + loanManager.accountedInterest());

        // interestAccrued_ += loanHandler.lateIntervalInterest(loan_);
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

    /******************************************************************************************************************************/
    /*** External Setter Functions                                                                                              ***/
    /******************************************************************************************************************************/

    function setCurrentTimestamp(uint256 currentTimestamp_) external {
        timestamps.push(currentTimestamp_);
        setTimestamps++;
        currentTimestamp = currentTimestamp_;
    }

    /******************************************************************************************************************************/
    /*** Public View Functions                                                                                                  ***/
    /******************************************************************************************************************************/

    function getAllOutstandingInterest() public returns (uint256 sumOutstandingInterest_) {
        for (uint256 i = 0; i < loanHandler.numLoans(); i++) {

            // console.log("loan", i);

            assertTrue(loanHandler.earliestPaymentDueDate() == loanManager.domainEnd());

            sumOutstandingInterest_ += _getCurrentOutstandingInterest(loanHandler.activeLoans(i), loanHandler.earliestPaymentDueDate());
        }
    }

    function getSumIssuanceRates() public view returns (uint256 sumIssuanceRate_) {
        for (uint256 i = 0; i < loanHandler.numLoans(); i++) {
            ( , , , , , , uint256 issuanceRate ) = loanManager.payments(loanManager.paymentIdOf(address(loanHandler.activeLoans(i))));
            sumIssuanceRate_ += issuanceRate;
        }
    }

}


