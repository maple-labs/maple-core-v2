// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { StdInvariant } from "../../modules/forge-std/src/Test.sol";

import {
    IAavePoolLike,
    IAaveV3Strategy,
    IAllocationStrategy,
    IERC20,
    IERC4626Like,
    IOpenTermLoan,
    IOpenTermLoanManager,
    IPool,
    IPoolManager,
    IPoolPermissionManager,
    IPSMLike,
    ISkyStrategy,
    IStrategyLike,
    IStrategyManager,
    IUnderlyingStrategyLike,
    IWithdrawalManagerQueue
} from "../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

import { AaveV3StrategyHandler }     from "./handlers/AaveV3StrategyHandler.sol";
import { AllocationStrategyHandler } from "./handlers/AllocationStrategyHandler.sol";
import { DepositHandler }            from "./handlers/DepositHandler.sol";
import { OpenTermLoanHandler }       from "./handlers/OpenTermLoanHandler.sol";
import { PermissionHandler }         from "./handlers/PermissionHandler.sol";
import { SkyStrategyHandler }        from "./handlers/SkyStrategyHandler.sol";
import { StrategyManagerHandler }    from "./handlers/StrategyManagerHandler.sol";
import { TransferHandler }           from "./handlers/TransferHandler.sol";
import { WithdrawalHandler }         from "./handlers/WithdrawalHandler.sol";

contract BaseInvariants is StdInvariant, TestBaseWithAssertions {

    /**************************************************************************************************************************************/
    /*** Constants                                                                                                                      ***/
    /**************************************************************************************************************************************/

    uint256 constant ALLOWED_OTL_AUM_DIFF = 1e6;

    // NOTE: OTLM invariant K accumulates ~1 wei of rounding per interest-accounting event (fund/payment/refinance/impair).
    //       This bound assumes `invariant.depth` stays capped at 250 in foundry.toml; raising it may require revisiting this.
    uint256 constant ALLOWED_OTLM_DIFF = 5_000;

    // NOTE: Aave's scaled-balance rounding can move aToken.balanceOf() by a few wei per each supply/withdraw call.
    uint256 constant AAVE_ROUNDING_TOLERANCE = 100;

    uint256 constant MAXIMUM_BITMAP          = 2 ** 16 - 1;
    uint256 constant PUBLIC_PERMISSION_LEVEL = 3;

    // NOTE: Sky's PSM/savingsUsds conversions can move assetsUnderManagement() by a few wei per each supply/withdraw call.
    uint256 constant SKY_ROUNDING_TOLERANCE = 100;

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    AaveV3StrategyHandler     aaveV3StrategyHandler;
    AllocationStrategyHandler allocationStrategyHandler;
    DepositHandler            depositHandler;
    OpenTermLoanHandler       otlHandler;
    PermissionHandler         permissionHandler;
    SkyStrategyHandler        skyStrategyHandler;
    StrategyManagerHandler    strategyManagerHandler;
    TransferHandler           transferHandler;
    WithdrawalHandler         withdrawalHandler;

    address[] lps;

    mapping(uint256 => bool) existingRequestIds;

    /**************************************************************************************************************************************/
    /*** Invariant Tests                                                                                                                ***/
    /***************************************************************************************************************************************

     * Open Term Loan
        * Invariant A: dateFunded <= datePaid, dateCalled, dateImpaired (if not zero)
        * Invariant B: datePaid <= dateImpaired (if not zero)
        * Invariant C: datePaid <= dateCalled (if not zero)
        * Invariant D: calledPrincipal <= principal
        * Invariant E: dateCalled != 0 -> calledPrincipal != 0
        * Invariant F: paymentDueDate() <= defaultDate()
        * Invariant G: getPaymentBreakdown == theoretical calculation

     * Open Term Loan Manager
        * Invariant A: accountedInterest + accruedInterest() == ∑loan.getPaymentBreakdown(block.timestamp) (minus fees)
        * Invariant B: if no payments exist: accountedInterest == 0
        * Invariant C: principalOut = ∑loan.principal()
        * Invariant D: issuanceRate = ∑payment.issuanceRate
        * Invariant E: unrealizedLosses <= assetsUnderManagement()
        * Invariant F: if no impairments exist: unrealizedLosses == 0
        * Invariant G: block.timestamp >= domainStart
        * Invariant H: payment.startDate == loan.dateFunded() || loan.datePaid()
        * Invariant I: payment.issuanceRate == theoretical calculation (minus management fees)
        * Invariant J: payment.impairedDate >= payment.startDate
        * Invariant K: assetsUnderManagement - unrealizedLosses - ∑outstandingValue(loan) ~= 0
        * Invariant L: fundsAsset.balanceOf(OTLM) == 0
        * Invariant M: fundsAsset.allowance(OTLM, address(loan)) == 0

     * Pool
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

     * PoolManager
        * Invariant A: totalAssets == cash + ∑assetsUnderManagement[strategy]
        * Invariant B: unrealizedLosses() <= totalAssets()
        * Invariant C: totalAssets() and unrealizedLosses() never revert
        * Invariant D: isStrategy XOR isStrategyManager
        * Invariant E: every strategyList address is unique

     * Strategy Manager
        * Invariant A: assetsUnderManagement() == underlyingStrategy.assetsUnderManagement()
        * Invariant B: unrealizedLosses() <= assetsUnderManagement()
        * Invariant C: totalShares == ∑sharesOf(poolManager)
        * Invariant D: totalPendingShares == ∑pendingSharesOf(poolManager)
        * Invariant E: pendingSharesOf(poolManager) <= sharesOf(poolManager)
        * Invariant F: totalShares() >= sharesOf(address(0))
        * Invariant G: convertToExitAssets(totalShares) <= convertToAssets(totalShares)
        * Invariant H: ∑assetsOf(poolManager) <= assetsUnderManagement()
        * Invariant I: ∑unrealizedLossesOf(poolManager) >= unrealizedLosses()

     * Aave V3 Strategy
        * Invariant A: assetsUnderManagement() == Σfundings + Σyield - Σwithdrawals - Σfees
        * Invariant B: aToken.balanceOf(strategy) >= Σfundings - Σwithdrawals - Σfees
        * Invariant C: fundsAsset.balanceOf(strategy) == 0
        * Invariant D: fundsAsset.allowance(strategy, aavePool) == 0
        * Invariant E: aToken.balanceOf(strategy) >= lastRecordedTotalAssets
        * Invariant F: assetsUnderManagement() >= lastRecordedTotalAssets
        * Invariant G: availableToWithdraw() <= assetsUnderManagement()
        * Invariant H: availableToWithdraw() <= aaveLiquidity
        * Invariant I: unrealizedLosses() <= assetsUnderManagement()
        * Invariant J: strategyDelegateFeeRate + strategyProtocolFeeRate <= 1e6

     * Sky Strategy
        * Invariant A: assetsUnderManagement() == Σfundings + Σyield - Σwithdrawals - Σfees
        * Invariant B: usds.balanceOf(strategy) == fundsAsset.balanceOf(strategy) == 0
        * Invariant C: allowance(strategy, psm) == allowance(strategy, savingsUsds) == 0
        * Invariant D: gemForUsds(usdsForGem(x)) ~= x
        * Invariant E: assetsUnderManagement() >= lastRecordedTotalAssets
        * Invariant F: availableToWithdraw() <= assetsUnderManagement()
        * Invariant G: availableToWithdraw() <= fundsAsset.balanceOf(psm.pocket())
        * Invariant H: unrealizedLosses() <= assetsUnderManagement()
        * Invariant I: strategyDelegateFeeRate + strategyProtocolFeeRate <= 1e6

     * Allocation Strategy
        * Invariant A: assetsUnderManagement() == Σfundings + Σyield - Σwithdrawals - Σfees - Σlosses
        * Invariant B: fundsAsset.balanceOf(strategy) >= recordedAssets
        * Invariant C: totalDeployedAssets == ∑deployedAssetsOf(wallet)
        * Invariant D: deployedAssetsOf(wallet) == Σdeploys(wallet) - Σreturns(wallet) - Σlosses(wallet)
        * Invariant E: availableToWithdraw() <= assetsUnderManagement()
        * Invariant F: unrealizedLosses() <= assetsUnderManagement()
        * Invariant G: unrealizedYield() <= recordedAssets
        * Invariant H: unrealizedYield() <= scheduledYieldAssets()
        * Invariant I: yieldLastRealized <= yieldStart <= yieldDeadline
        * Invariant J: strategyDelegateFeeRate + strategyProtocolFeeRate <= 1e6

     * Pool Permission Manager
        * Invariant A: pool.permissionLevel ∈ [0, 3]
        * Invariant B: pool.bitmap ∈ [0, MAX]
        * Invariant C: lender.bitmap ∈ [0, MAX]
        * Invariant D: pool.permissionLevel == public -> permanently public

     * Withdrawal Manager (Queue)
        * Invariant A: ∑request.shares + ∑owner.manualShares == totalShares
        * Invariant B: balanceOf(this) >= totalShares
        * Invariant C: ∀ requestId(owner) != 0 -> request.shares > 0 && request.owner == owner
        * Invariant D: nextRequestId <= lastRequestId + 1
        * Invariant E: nextRequestId != 0
        * Invariant F: requests(0) == (0, 0)
        * Invariant G: ∀ requestId[lender] ∈ [0, lastRequestId]
        * Invariant H: requestId is unique
        * Invariant I: ∀ owner, userEscrowedShares(owner) == ∑requestsByOwner(owner).shares
        * Invariant J: ∑owner.userEscrowedShares + ∑owner.manualSharesAvailable == totalShares
        * Invariant M: requestsByOwner lists are strictly increasing
        * Invariant N: requestsByOwner lists match active requests exactly

    /**************************************************************************************************************************************/
    /*** Pool Invariants                                                                                                                ***/
    /**************************************************************************************************************************************/

    function assert_pool_invariants_all(address pool_) internal view {
        assert_pool_invariants_A_B_D_E_F_G_I_J_K(pool_);

        assert_pool_invariant_C(pool_);
        assert_pool_invariant_H(pool_);
    }

    function assert_pool_invariants_A_B_D_E_G_I_J_K(address pool_) internal view {
        assert_pool_invariant_A(pool_);
        assert_pool_invariant_D(pool_);
        assert_pool_invariant_E(pool_);
        assert_pool_invariant_I(pool_);
        assert_pool_invariant_J(pool_);
        assert_pool_invariant_K(pool_);

        address withdrawalManager = IPoolManager(IPool(pool_).manager()).withdrawalManager();

        uint256 sumBalanceOf       = IPool(pool_).balanceOf(address(0));
        uint256 sumBalanceOfAssets = IPool(pool_).balanceOfAssets(address(0));

        for (uint256 i; i < lps.length; ++i) {
            sumBalanceOfAssets += IPool(pool_).balanceOfAssets(lps[i]);
            sumBalanceOf       += IPool(pool_).balanceOf(lps[i]);
        }

        sumBalanceOfAssets += IPool(pool_).balanceOfAssets(withdrawalManager);
        sumBalanceOf       += IPool(pool_).balanceOf(withdrawalManager);

        assert_pool_invariant_B(pool_, sumBalanceOfAssets);
        assert_pool_invariant_G(pool_, sumBalanceOf);
    }

    function assert_pool_invariants_A_B_D_E_F_G_I_J_K(address pool_) internal view {
        assert_pool_invariants_A_B_D_E_G_I_J_K(pool_);

        for (uint256 i; i < lps.length; ++i) {
            assert_pool_invariant_F(pool_, lps[i]);
        }
    }

    function assert_pool_invariant_A(address pool_) internal view {
        address asset = IPool(pool_).asset();

        assertGe(IPool(pool_).totalAssets(), IERC20(asset).balanceOf(pool_), "Pool Invariant A");
    }

    function assert_pool_invariant_B(address pool_, uint256 sumBalanceOfAssets) internal view {
        assertGe(IPool(pool_).totalAssets(), sumBalanceOfAssets, "Pool Invariant B1");

        assertApproxEqAbs(IPool(pool_).totalAssets(), sumBalanceOfAssets, lps.length + 1, "Pool Invariant B2");
    }

    function assert_pool_invariant_C(address pool_) internal view {
        assertGe(IPool(pool_).totalAssets(), IPool(pool_).totalSupply(), "Pool Invariant C");
    }

    function assert_pool_invariant_D(address pool_) internal view {
        uint256 totalSupply = IPool(pool_).totalSupply();

        assertGe(IPool(pool_).totalAssets(), IPool(pool_).convertToAssets(totalSupply), "Pool Invariant D1");

        assertApproxEqAbs(IPool(pool_).totalAssets(), IPool(pool_).convertToAssets(totalSupply), 1, "Pool Invariant D2");
    }

    function assert_pool_invariant_E(address pool_) internal view {
        uint256 totalAssets = IPool(pool_).totalAssets();

        assertGe(IPool(pool_).convertToShares(totalAssets), IPool(pool_).totalSupply(), "Pool Invariant E1");

        assertApproxEqAbs(IPool(pool_).convertToShares(totalAssets), IPool(pool_).totalSupply(), 1, "Pool Invariant E2");
    }

    function assert_pool_invariant_F(address pool_, address holder) internal view {
        assertGe(IPool(pool_).balanceOfAssets(holder), IPool(pool_).balanceOf(holder), "Pool Invariant F");
    }

    function assert_pool_invariant_G(address pool_, uint256 sumBalanceOf) internal view {
        assertEq(IPool(pool_).totalSupply(), sumBalanceOf, "Pool Invariant G");
    }

    function assert_pool_invariant_H(address pool_) internal view {
        uint256 totalAssets = IPool(pool_).totalAssets();

        if (totalAssets > 0) {
            assertEq(IPool(pool_).convertToShares(totalAssets), IPool(pool_).convertToExitShares(totalAssets), "Pool Invariant H");
        }
    }

    function assert_pool_invariant_I(address pool_) internal view {
        address poolManager = IPool(pool_).manager();

        assertEq(IPool(pool_).totalAssets(), IPoolManager(poolManager).totalAssets(), "Pool Invariant I");
    }

    function assert_pool_invariant_J(address pool_) internal view {
        address poolManager = IPool(pool_).manager();

        assertEq(IPool(pool_).unrealizedLosses(), IPoolManager(poolManager).unrealizedLosses(), "Pool Invariant J");
    }

    function assert_pool_invariant_K(address pool_) internal view {
        uint256 totalAssets = IPool(pool_).totalAssets();

        if (totalAssets - IPool(pool_).unrealizedLosses() > 0) {
            address poolManager = IPool(pool_).manager();

            assertEq(
                IPool(pool_).convertToExitShares(totalAssets),
                IPoolManager(poolManager).convertToExitShares(totalAssets),
                "Pool Invariant K"
            );
        }
    }

    /**************************************************************************************************************************************/
    /*** Pool Manager Functions                                                                                                         ***/
    /**************************************************************************************************************************************/

    function assert_pool_manager_invariants(address poolManager_) internal view {
        assert_poolManager_invariant_A(poolManager_);
        assert_poolManager_invariant_B(poolManager_);
        assert_poolManager_invariant_C(poolManager_);
        assert_poolManager_invariant_D(poolManager_);
        assert_poolManager_invariant_E(poolManager_);
    }

    function assert_poolManager_invariant_A(address poolManager_) internal view {
        address asset = IPoolManager(poolManager_).asset();
        address pool  = IPoolManager(poolManager_).pool();

        uint256 totalAssets   = IERC20(asset).balanceOf(pool);
        uint256 strategyCount = IPoolManager(poolManager_).strategyListLength();

        for (uint256 i; i < strategyCount; ++i) {
            address strategy = IPoolManager(poolManager_).strategyList(i);

            totalAssets += IPoolManager(poolManager_).isStrategyManager(strategy)
                ? IStrategyManager(strategy).assetsOf(poolManager_)
                : IStrategyLike(strategy).assetsUnderManagement();
        }

        assertEq(IPoolManager(poolManager_).totalAssets(), totalAssets, "PoolManager Invariant A");
    }

    function assert_poolManager_invariant_B(address poolManager_) internal view {
        assertLe(IPoolManager(poolManager_).unrealizedLosses(), IPoolManager(poolManager_).totalAssets(), "PoolManager Invariant B");
    }

    function assert_poolManager_invariant_C(address poolManager_) internal view {
        try IPoolManager(poolManager_).totalAssets() returns (uint256) {}
        catch {
            assertTrue(false, "PoolManager Invariant C: totalAssets reverted");
        }

        try IPoolManager(poolManager_).unrealizedLosses() returns (uint256) {}
        catch {
            assertTrue(false, "PoolManager Invariant C: unrealizedLosses reverted");
        }
    }

    function assert_poolManager_invariant_D(address poolManager_) internal view {
        uint256 strategyCount = IPoolManager(poolManager_).strategyListLength();

        for (uint256 i; i < strategyCount; ++i) {
            address strategy = IPoolManager(poolManager_).strategyList(i);

            assertTrue(
                IPoolManager(poolManager_).isStrategy(strategy) != IPoolManager(poolManager_).isStrategyManager(strategy),
                "PoolManager Invariant D"
            );
        }
    }

    function assert_poolManager_invariant_E(address poolManager_) internal view {
        uint256 strategyCount = IPoolManager(poolManager_).strategyListLength();

        for (uint256 i; i < strategyCount; ++i) {
            address strategy = IPoolManager(poolManager_).strategyList(i);

            uint256 count;

            for (uint256 j; j < strategyCount; ++j) {
                if (IPoolManager(poolManager_).strategyList(j) == strategy) count++;
            }

            assertEq(count, 1, "PoolManager Invariant E");
        }
    }

    /**************************************************************************************************************************************/
    /*** Open Term Loan Invariants                                                                                                      ***/
    /**************************************************************************************************************************************/

    function assert_otl_invariants(address[] memory loans_) internal view {
        for (uint256 i; i < loans_.length; ++i) {
            address loan = loans_[i];

            assert_otl_invariant_A(loan);
            assert_otl_invariant_B(loan);
            assert_otl_invariant_C(loan);
            assert_otl_invariant_D(loan);
            assert_otl_invariant_E(loan);
            assert_otl_invariant_F(loan);
            assert_otl_invariant_G(loan);
            assert_otl_invariant_H(loan);
            assert_otl_invariant_I(loan);
        }
    }

    function assert_otl_invariant_A(address loan_) internal view {
        IOpenTermLoan loan = IOpenTermLoan(loan_);

        if (loan.datePaid() != 0) {
            assertLe(loan.dateFunded(), loan.datePaid(), "OTL Invariant A");
        }
    }

    function assert_otl_invariant_B(address loan_) internal view {
        IOpenTermLoan loan = IOpenTermLoan(loan_);

        if (loan.dateImpaired() != 0) {
            assertLe(loan.dateFunded(), loan.dateImpaired(), "OTL Invariant B");
        }
    }

    function assert_otl_invariant_C(address loan_) internal view {
        IOpenTermLoan loan = IOpenTermLoan(loan_);

        if (loan.dateCalled() != 0) {
            assertLe(loan.dateFunded(), loan.dateCalled(), "OTL Invariant C");
        }
    }

    function assert_otl_invariant_D(address loan_) internal view {
        IOpenTermLoan loan = IOpenTermLoan(loan_);

        if (loan.datePaid() != 0 && loan.dateImpaired() != 0) {
            assertLe(loan.datePaid(), loan.dateImpaired(), "OTL Invariant D");
        }
    }

    function assert_otl_invariant_E(address loan_) internal view {
        IOpenTermLoan loan = IOpenTermLoan(loan_);

        if (loan.datePaid() != 0 && loan.dateCalled() != 0) {
            assertLe(loan.datePaid(), loan.dateCalled(), "OTL Invariant E");
        }
    }

    function assert_otl_invariant_F (address loan_) internal view {
        IOpenTermLoan loan = IOpenTermLoan(loan_);

        assertLe(loan.calledPrincipal(), loan.principal(), "OTL Invariant F");
    }

    function assert_otl_invariant_G (address loan_) internal view {
        IOpenTermLoan loan = IOpenTermLoan(loan_);

        assertTrue(
            loan.dateCalled() == 0 && loan.calledPrincipal() == 0 ||
            loan.dateCalled() != 0 && loan.calledPrincipal() != 0,
            "OTL Invariant G"
        );
    }

    function assert_otl_invariant_H(address loan_) internal view {
        IOpenTermLoan loan = IOpenTermLoan(loan_);

        assertLe(loan.paymentDueDate(), loan.defaultDate(), "OTL Invariant H");
    }

    function assert_otl_invariant_I(address loan_) internal view {
        (
            uint256 principal,
            uint256 interest,
            uint256 lateInterest,
            uint256 delegateServiceFee,
            uint256 platformServiceFee
        ) = IOpenTermLoan(loan_).getPaymentBreakdown(block.timestamp);

        (
            uint256 expectedPrincipal,
            uint256 expectedInterest,
            uint256 expectedLateInterest,
            uint256 expectedDelegateServiceFee,
            uint256 expectedPlatformServiceFee
        ) = _getExpectedPaymentBreakdown(loan_);

        assertEq(principal,          expectedPrincipal,          "OTL Invariant I (principal)");
        assertEq(interest,           expectedInterest,           "OTL Invariant I (interest)");
        assertEq(lateInterest,       expectedLateInterest,       "OTL Invariant I (lateInterest)");
        assertEq(delegateServiceFee, expectedDelegateServiceFee, "OTL Invariant I (delegateServiceFee)");
        assertEq(platformServiceFee, expectedPlatformServiceFee, "OTL Invariant I (platformServiceFee)");
    }

    /**************************************************************************************************************************************/
    /*** Open Term Loan Manager Invariants                                                                                              ***/
    /**************************************************************************************************************************************/

    function assert_otlm_invariants_A_B_C_D_E_F_G_H_I_J_K_L_M(address loanManager_, address[] memory loans_) internal view {
        assert_otlm_invariants_B_C_F_H_I_J_K_L_M(loanManager_, loans_);

        assert_otlm_invariant_A(loanManager_, loans_);
        assert_otlm_invariant_D(loanManager_, loans_);
        assert_otlm_invariant_E(loanManager_);
        assert_otlm_invariant_G(loanManager_);
    }

    function assert_otlm_invariants_B_C_F_H_I_J_K_L_M(address loanManager_, address[] memory loans_) internal view {
        assert_otlm_invariant_B(loanManager_, loans_);
        assert_otlm_invariant_C(loanManager_, loans_);
        assert_otlm_invariant_F(loanManager_, loans_);
        assert_otlm_invariant_K(loanManager_, loans_);
        assert_otlm_invariant_L(loanManager_);
        assert_otlm_invariant_M(loanManager_, loans_);

        for (uint256 i; i < loans_.length; ++i) {
            address loan = loans_[i];

            assert_otlm_invariant_H(loan, loanManager_);
            assert_otlm_invariant_I(loan, loanManager_);
            assert_otlm_invariant_J(loan, loanManager_);
        }
    }

    function assert_otlm_invariant_A(address openTermLoanManager_, address[] memory loans_) internal view {
        uint256 assetsUnderManagement = IOpenTermLoanManager(openTermLoanManager_).assetsUnderManagement();
        uint256 expectedAssetsUnderManagement;

        for (uint256 i; i < loans_.length; ++i) {
            expectedAssetsUnderManagement += IOpenTermLoan(loans_[i]).principal() + _getExpectedNetInterest(loans_[i]);
        }

        assertApproxEqAbs(
            assetsUnderManagement,
            expectedAssetsUnderManagement,
            ALLOWED_OTL_AUM_DIFF,  // As the number can be unbounded but we realistically expect it to not go over $1
            "OTLM Invariant A"
        );
    }

    function assert_otlm_invariant_B(address openTermLoanManager_, address[] memory loans_) internal view {
        IOpenTermLoanManager openTermLoanManager = IOpenTermLoanManager(openTermLoanManager_);

        uint256 assetsUnderManagement = openTermLoanManager.assetsUnderManagement();

        for (uint256 i; i < loans_.length; ++i) {
            ( , , uint40 startDate, ) = openTermLoanManager.paymentFor(loans_[i]);

            if (startDate != 0) return;
        }

        assertApproxEqAbs(assetsUnderManagement, 0, otlHandler.numLoans(), "OTLM Invariant B");
    }

    function assert_otlm_invariant_C(address openTermLoanManager_, address[] memory loans_) internal view {
        uint256 principalOut = IOpenTermLoanManager(openTermLoanManager_).principalOut();
        uint256 expectedPrincipalOut;

        for (uint256 i; i < loans_.length; ++i) {
            expectedPrincipalOut += IOpenTermLoan(loans_[i]).principal();
        }

        assertEq(principalOut, expectedPrincipalOut, "OTLM Invariant C");
    }

    function assert_otlm_invariant_D(address openTermLoanManager_, address[] memory loans_) internal view {
        IOpenTermLoanManager openTermLoanManager = IOpenTermLoanManager(openTermLoanManager_);

        uint256 issuanceRate = openTermLoanManager.issuanceRate();
        uint256 expectedIssuanceRate;

        for (uint256 i; i < loans_.length; ++i) {
            ( , , , uint168 issuanceRate_ ) = openTermLoanManager.paymentFor(loans_[i]);
            expectedIssuanceRate += issuanceRate_;
        }

        assertEq(issuanceRate, expectedIssuanceRate, "OTLM Invariant D");
    }

    function assert_otlm_invariant_E(address openTermLoanManager_) internal view {
        IOpenTermLoanManager openTermLoanManager = IOpenTermLoanManager(openTermLoanManager_);

        uint256 unrealizedLosses      = openTermLoanManager.unrealizedLosses();
        uint256 assetsUnderManagement = openTermLoanManager.assetsUnderManagement();

        assertLe(unrealizedLosses, assetsUnderManagement, "OTLM Invariant E");
    }

    function assert_otlm_invariant_F(address openTermLoanManager_, address[] memory loans_) internal view {
        IOpenTermLoanManager openTermLoanManager = IOpenTermLoanManager(openTermLoanManager_);

        uint256 unrealizedLosses = openTermLoanManager.unrealizedLosses();

        for (uint256 i; i < loans_.length; ++i) {
            ( uint40 impairmentDate, ) = openTermLoanManager.impairmentFor(loans_[i]);

            if (impairmentDate != 0) return;
        }

        assertEq(unrealizedLosses, 0, "OTLM Invariant F");
    }

    function assert_otlm_invariant_G(address openTermLoanManager_) internal view {
        uint256 domainStart = IOpenTermLoanManager(openTermLoanManager_).domainStart();

        assertGe(block.timestamp, domainStart, "OTLM Invariant G");
    }

    function assert_otlm_invariant_H(address loan_, address openTermLoanManager_) internal view {
        IOpenTermLoan loan = IOpenTermLoan(loan_);

        ( , , uint40 paymentStartDate, ) = IOpenTermLoanManager(openTermLoanManager_).paymentFor(address(loan));

        assertTrue(
            paymentStartDate == loan.dateFunded() ||
            paymentStartDate == loan.datePaid(),
            "OTLM Invariant H"
        );
    }

    function assert_otlm_invariant_I(address loan_, address openTermLoanManager_) internal view {
        ( , , , uint168 issuanceRate ) = IOpenTermLoanManager(openTermLoanManager_).paymentFor(loan_);
        uint256 expectedIssuanceRate   = _getExpectedIssuanceRate(loan_);

        assertEq(issuanceRate, expectedIssuanceRate, "OTLM Invariant I");
    }

    function assert_otlm_invariant_J(address loan_, address openTermLoanManager_) internal view {
        IOpenTermLoanManager openTermLoanManager = IOpenTermLoanManager(openTermLoanManager_);

        ( uint40 impairmentDate, ) = openTermLoanManager.impairmentFor(loan_);
        ( , , uint40 startDate, )  = openTermLoanManager.paymentFor(loan_);

        if (impairmentDate != 0) {
            assertGe(impairmentDate, startDate, "OTLM Invariant J");
        }
    }

    function assert_otlm_invariant_K(address loanManager_, address[] memory loans_) internal view {
        uint256 outstandingValue;

        uint256 assetsUnderManagement = IOpenTermLoanManager(loanManager_).assetsUnderManagement();
        uint256 unrealizedLosses      = IOpenTermLoanManager(loanManager_).unrealizedLosses();

        for (uint256 i; i < loans_.length; ++i) {
            outstandingValue += _getOutstandingValue(loans_[i]);
        }

        uint256 a = assetsUnderManagement;
        uint256 b = unrealizedLosses + outstandingValue;
        uint256 diff = a > b ? a - b : b - a;

        assertApproxEqAbs(diff, 0, ALLOWED_OTLM_DIFF, "OTLM Invariant K");
    }

    function assert_otlm_invariant_L(address loanManager_) internal view {
        uint256 balance = fundsAsset.balanceOf(address(loanManager_));

        assertEq(balance, 0, "OTLM Invariant L");
    }

    function assert_otlm_invariant_M(address loanManager_, address[] memory loans_) internal view {
        for (uint256 i; i < loans_.length; ++i) {
            assertEq(fundsAsset.allowance(loanManager_, loans_[i]), 0, "OTLM Invariant M");
        }
    }

    /**************************************************************************************************************************************/
    /*** Pool Permission Manager Invariants                                                                                             ***/
    /**************************************************************************************************************************************/

    function assert_ppm_invariants(address poolPermissionManager_) internal view {
        assert_ppm_invariant_A(poolPermissionManager_, address(poolManager));
        assert_ppm_invariant_B(poolPermissionManager_, address(poolManager), functionIds);
        assert_ppm_invariant_C(poolPermissionManager_, lps);
    }

    function assert_ppm_invariant_A(address poolPermissionManager_, address poolManager_) internal view {
        IPoolPermissionManager ppm = IPoolPermissionManager(poolPermissionManager_);

        uint256 permissionLevel = ppm.permissionLevels(poolManager_);

        assertLe(permissionLevel, 3, "PPM Invariant A");
    }

    function assert_ppm_invariant_B(address poolPermissionManager_, address poolManager_, bytes32[] memory functionIds_) internal view {
        IPoolPermissionManager ppm = IPoolPermissionManager(poolPermissionManager_);

        for (uint256 i; i < functionIds_.length; ++i) {

            assertLe(ppm.poolBitmaps(poolManager_, functionIds_[i]), MAXIMUM_BITMAP, "PPM Invariant B");
        }
    }

    function assert_ppm_invariant_C(address poolPermissionManager_, address[] memory lenders_) internal view {
        IPoolPermissionManager ppm = IPoolPermissionManager(poolPermissionManager_);

        for (uint256 i; i < lenders_.length; ++i) {
            assertLe(ppm.lenderBitmaps(lenders_[i]), MAXIMUM_BITMAP, "PPM Invariant C");
        }
    }

    // TODO: Currently unused.
    function assert_ppm_invariant_D(address poolPermissionManager_, address[] memory poolManagers_) internal view {
        IPoolPermissionManager ppm = IPoolPermissionManager(poolPermissionManager_);

        for (uint256 i; i < poolManagers_.length; i++) {
            assertEq(ppm.permissionLevels(poolManagers_[i]), PUBLIC_PERMISSION_LEVEL, "PPM Invariant D");
        }
    }

    /**************************************************************************************************************************************/
    /*** Withdrawal Manager (Queue) Invariants                                                                                          ***/
    /**************************************************************************************************************************************/

    function assert_wm_queue_invariants(address withdrawalManager_, address[] memory lenders_) internal {
        assert_wmq_invariant_A(withdrawalManager_, lenders_);
        assert_wmq_invariant_C(withdrawalManager_, lenders_);
        assert_wmq_invariant_G(withdrawalManager_, lenders_);
        assert_wmq_invariant_H(withdrawalManager_, lenders_);
        assert_wmq_invariant_I(withdrawalManager_, lenders_);
        assert_wmq_invariant_J(withdrawalManager_, lenders_);
        assert_wmq_invariant_M(withdrawalManager_, lenders_);
        assert_wmq_invariant_N(withdrawalManager_, lenders_);

        assert_wmq_invariant_B(withdrawalManager_);
        assert_wmq_invariant_D(withdrawalManager_);
        assert_wmq_invariant_E(withdrawalManager_);
        assert_wmq_invariant_F(withdrawalManager_);
    }

    function assert_wmq_invariant_A(address withdrawalManager_, address[] memory lenders_) internal view {
        IWithdrawalManagerQueue wm = IWithdrawalManagerQueue(withdrawalManager_);

        ( uint256 nextRequestId, uint256 lastRequestId ) = wm.queue();

        uint256 countedShares;
        uint256 totalShares = wm.totalShares();

        for (uint256 requestId = nextRequestId; requestId <= lastRequestId; requestId++) {
            ( , uint256 shares ) = wm.requests(requestId);

            countedShares += shares;
        }

        // NOTE: If the request is manual but is processed, the link to the owner address is lost.
        //       That's why the lenders addresses are passed in manually.
        for (uint256 i; i < lenders_.length; i++) {
            address owner = lenders_[i];

            countedShares += wm.manualSharesAvailable(owner);
        }

        assertEq(countedShares, totalShares, "WMQ Invariant A");
    }

    function assert_wmq_invariant_B(address withdrawalManager_) internal view {
        IWithdrawalManagerQueue wm = IWithdrawalManagerQueue(withdrawalManager_);
        IPool pool                 = IPool(wm.pool());

        uint256 balance     = pool.balanceOf(withdrawalManager_);
        uint256 totalShares = wm.totalShares();

        assertGe(balance, totalShares, "WMQ Invariant B");
    }

    function assert_wmq_invariant_C(address withdrawalManager_, address[] memory lenders_) internal view {
        IWithdrawalManagerQueue wm = IWithdrawalManagerQueue(withdrawalManager_);

        for (uint256 i; i < lenders_.length; i++) {
            uint256 requestId = wm.requestIds(lenders_[i]);

            if (requestId == 0) continue;

            ( address owner, uint256 shares ) = wm.requests(requestId);

            assertTrue(shares > 0 && owner == lenders_[i], "WMQ Invariant C");
        }
    }

    function assert_wmq_invariant_D(address withdrawalManager_) internal view {
        IWithdrawalManagerQueue wm = IWithdrawalManagerQueue(withdrawalManager_);

        ( uint256 nextRequestId, uint256 lastRequestId ) = wm.queue();

        assertLe(nextRequestId, lastRequestId + 1, "WMQ Invariant D");
    }

    function assert_wmq_invariant_E(address withdrawalManager_) internal view {
        IWithdrawalManagerQueue wm = IWithdrawalManagerQueue(withdrawalManager_);

        ( uint256 nextRequestId, ) = wm.queue();

        assertTrue(nextRequestId != 0, "WMQ Invariant E");
    }

    function assert_wmq_invariant_F(address withdrawalManager_) internal view {
        IWithdrawalManagerQueue wm = IWithdrawalManagerQueue(withdrawalManager_);

        ( address owner, uint256 shares ) = wm.requests(0);

        assertEq(owner,  address(0), "WMQ Invariant F");
        assertEq(shares, uint256(0), "WMQ Invariant F");
    }

    function assert_wmq_invariant_G(address withdrawalManager_, address[] memory lenders_) internal view {
        IWithdrawalManagerQueue wm = IWithdrawalManagerQueue(withdrawalManager_);

        ( , uint256 lastRequestId ) = wm.queue();

        for (uint256 i; i < lenders_.length; i++) {
            uint256 requestId = wm.requestIds(lenders_[i]);

            assertLe(requestId, lastRequestId, "WMQ Invariant G");
        }
    }

    function assert_wmq_invariant_H(address withdrawalManager_, address[] memory lenders_) internal {
        for (uint256 i; i < lenders_.length; i++) {
            uint256 requestId = IWithdrawalManagerQueue(withdrawalManager_).requestIds(lenders_[i]);

            if (requestId == 0) continue;

            assertFalse(existingRequestIds[requestId], "WMQ Invariant H");

            existingRequestIds[requestId] = true;
        }

        // NOTE: Clean up storage for future assertion calls.
        for (uint256 i; i < lenders_.length; i++) {
            uint256 requestId = IWithdrawalManagerQueue(withdrawalManager_).requestIds(lenders_[i]);

            existingRequestIds[requestId] = false;
        }
    }

    function assert_wmq_invariant_I(address withdrawalManager_, address[] memory lenders_) internal view {
        IWithdrawalManagerQueue wm = IWithdrawalManagerQueue(withdrawalManager_);

        for (uint256 i; i < lenders_.length; i++) {
            address owner = lenders_[i];

            ( , uint256[] memory shares ) = wm.requestsByOwner(owner);

            uint256 ownerEscrowedShares;

            for (uint256 j; j < shares.length; ++j) {
                ownerEscrowedShares += shares[j];
            }

            assertEq(wm.userEscrowedShares(owner), ownerEscrowedShares, "WMQ Invariant I: ESCROWED_SHARES_SUM_MISMATCH");
        }
    }

    function assert_wmq_invariant_J(address withdrawalManager_, address[] memory lenders_) internal view {
        IWithdrawalManagerQueue wm = IWithdrawalManagerQueue(withdrawalManager_);

        uint256 countedShares;

        for (uint256 i; i < lenders_.length; i++) {
            address owner = lenders_[i];

            countedShares += wm.userEscrowedShares(owner) + wm.manualSharesAvailable(owner);
        }

        assertEq(countedShares, wm.totalShares(), "WMQ Invariant J: TOTAL_SHARES_SUM_MISMATCH");
    }

    function assert_wmq_invariant_M(address withdrawalManager_, address[] memory lenders_) internal view {
        IWithdrawalManagerQueue wm = IWithdrawalManagerQueue(withdrawalManager_);

        ( , uint256 lastRequestId ) = wm.queue();

        for (uint256 i; i < lenders_.length; ++i) {
            ( uint256[] memory requestIds, ) = wm.requestsByOwner(lenders_[i]);

            for (uint256 j; j < requestIds.length; ++j) {
                uint256 requestId = requestIds[j];

                assertGt(requestId, 0,             "WMQ Invariant M: REQUEST_ID_ZERO");
                assertLe(requestId, lastRequestId, "WMQ Invariant M: REQUEST_ID_GT_LAST");

                if (j != 0) {
                    assertGt(requestId, requestIds[j - 1], "WMQ Invariant M: REQUEST_IDS_NOT_INCREASING");
                }
            }
        }
    }

    // NOTE: lenders_ must include every owner with an active request, otherwise this invariant will revert.
    function assert_wmq_invariant_N(address withdrawalManager_, address[] memory lenders_) internal {
        IWithdrawalManagerQueue wm = IWithdrawalManagerQueue(withdrawalManager_);

        ( , uint256 lastRequestId ) = wm.queue();

        uint256 totalOwnerRequests;

        for (uint256 i; i < lenders_.length; ++i) {
            address owner = lenders_[i];

            ( uint256[] memory requestIds, uint256[] memory shares ) = wm.requestsByOwner(owner);

            uint256 latestRequestId;

            if (requestIds.length != 0) {
                latestRequestId = requestIds[requestIds.length - 1];
            }

            assertEq(wm.requestIds(owner), latestRequestId, "WMQ Invariant N: LATEST_REQUEST_ID_MISMATCH");
            assertEq(shares.length, requestIds.length,     "WMQ Invariant N: shares LEN_MISMATCH");

            for (uint256 j; j < requestIds.length; ++j) {
                uint256 requestId = requestIds[j];

                assertGt(requestId, 0,             "WMQ Invariant N: REQUEST_ID_ZERO");
                assertLe(requestId, lastRequestId, "WMQ Invariant N: REQUEST_ID_GT_LAST");

                assertFalse(existingRequestIds[requestId], "WMQ Invariant N: DUPLICATE_REQUEST_ID");

                existingRequestIds[requestId] = true;

                ( address requestOwner, uint256 requestShares ) = wm.requests(requestId);

                assertEq(requestOwner,  owner,     "WMQ Invariant N: OWNER_MISMATCH");
                assertGt(requestShares, 0,         "WMQ Invariant N: REQUEST_SHARES_ZERO");
                assertEq(requestShares, shares[j], "WMQ Invariant N: SHARES_MISMATCH");

                ++totalOwnerRequests;
            }
        }

        uint256 activeRequests;

        // Every active request in the mapping must be represented in exactly one owner list.
        for (uint256 requestId = 1; requestId <= lastRequestId; ++requestId) {
            ( address owner, uint256 requestShares ) = wm.requests(requestId);

            if (owner == address(0)) {
                assertEq(requestShares, 0, "WMQ Invariant N: INACTIVE_REQUEST_SHARES_NONZERO");
                assertFalse(existingRequestIds[requestId], "WMQ Invariant N: INACTIVE_REQUEST_MARKED");
            } else {
                assertGt(requestShares, 0, "WMQ Invariant N: ACTIVE_REQUEST_SHARES_ZERO");
                assertTrue(existingRequestIds[requestId], "WMQ Invariant N: ACTIVE_REQUEST_NOT_MARKED");

                ++activeRequests;
            }
        }

        assertEq(totalOwnerRequests, activeRequests, "WMQ Invariant N: ACTIVE_REQUEST_COUNT_MISMATCH");

        for (uint256 requestId = 1; requestId <= lastRequestId; ++requestId) {
            existingRequestIds[requestId] = false;
        }
    }

    /**************************************************************************************************************************************/
    /*** Strategy Manager Invariants                                                                                                    ***/
    /**************************************************************************************************************************************/

    function assert_strategyManager_invariants(address strategyManager_, address[] memory poolManagers_) internal view {
        assert_strategyManager_invariant_A(strategyManager_);
        assert_strategyManager_invariant_B(strategyManager_);
        assert_strategyManager_invariant_C(strategyManager_, poolManagers_);
        assert_strategyManager_invariant_D(strategyManager_, poolManagers_);
        assert_strategyManager_invariant_E(strategyManager_, poolManagers_);
        assert_strategyManager_invariant_F(strategyManager_);
        assert_strategyManager_invariant_G(strategyManager_);
        assert_strategyManager_invariant_H(strategyManager_, poolManagers_);
        assert_strategyManager_invariant_I(strategyManager_, poolManagers_);
    }

    function assert_strategyManager_invariant_A(address strategyManager_) internal view {
        address underlyingStrategy = IStrategyManager(strategyManager_).underlyingStrategy();

        assertEq(
            IStrategyManager(strategyManager_).assetsUnderManagement(),
            IUnderlyingStrategyLike(underlyingStrategy).assetsUnderManagement(),
            "SM Invariant A1"
        );

        assertEq(
            IStrategyManager(strategyManager_).unrealizedLosses(),
            IUnderlyingStrategyLike(underlyingStrategy).unrealizedLosses(),
            "SM Invariant A2"
        );
    }

    function assert_strategyManager_invariant_B(address strategyManager_) internal view {
        assertLe(
            IStrategyManager(strategyManager_).unrealizedLosses(),
            IStrategyManager(strategyManager_).assetsUnderManagement(),
            "SM Invariant B"
        );
    }

    function assert_strategyManager_invariant_C(address strategyManager_, address[] memory poolManagers_) internal view {
        uint256 sumShares = IStrategyManager(strategyManager_).sharesOf(address(0));

        for (uint256 i; i < poolManagers_.length; ++i) {
            sumShares += IStrategyManager(strategyManager_).sharesOf(poolManagers_[i]);
        }

        assertEq(IStrategyManager(strategyManager_).totalShares(), sumShares, "SM Invariant C");
    }

    function assert_strategyManager_invariant_D(address strategyManager_, address[] memory poolManagers_) internal view {
        uint256 sumPendingShares;

        for (uint256 i; i < poolManagers_.length; ++i) {
            sumPendingShares += IStrategyManager(strategyManager_).pendingSharesOf(poolManagers_[i]);
        }

        assertEq(IStrategyManager(strategyManager_).totalPendingShares(), sumPendingShares, "SM Invariant D");
    }

    function assert_strategyManager_invariant_E(address strategyManager_, address[] memory poolManagers_) internal view {
        for (uint256 i; i < poolManagers_.length; ++i) {
            assertLe(
                IStrategyManager(strategyManager_).pendingSharesOf(poolManagers_[i]),
                IStrategyManager(strategyManager_).sharesOf(poolManagers_[i]),
                "SM Invariant E"
            );
        }
    }

    function assert_strategyManager_invariant_F(address strategyManager_) internal view {
        assertGe(
            IStrategyManager(strategyManager_).totalShares(),
            IStrategyManager(strategyManager_).sharesOf(address(0)),
            "SM Invariant F"
        );
    }

    function assert_strategyManager_invariant_G(address strategyManager_) internal view {
        uint256 shares = IStrategyManager(strategyManager_).totalShares();

        assertLe(
            IStrategyManager(strategyManager_).convertToExitAssets(shares),
            IStrategyManager(strategyManager_).convertToAssets(shares),
            "SM Invariant G"
        );
    }

    function assert_strategyManager_invariant_H(address strategyManager_, address[] memory poolManagers_) internal view {
        uint256 sumAssetsOf;

        for (uint256 i; i < poolManagers_.length; ++i) {
            sumAssetsOf += IStrategyManager(strategyManager_).assetsOf(poolManagers_[i]);
        }

        assertLe(sumAssetsOf, IStrategyManager(strategyManager_).assetsUnderManagement(), "SM Invariant H");
    }

    function assert_strategyManager_invariant_I(address strategyManager_, address[] memory poolManagers_) internal view {
        uint256 sumUnrealizedLossesOf = IStrategyManager(strategyManager_).unrealizedLossesOf(address(0));

        for (uint256 i; i < poolManagers_.length; ++i) {
            sumUnrealizedLossesOf += IStrategyManager(strategyManager_).unrealizedLossesOf(poolManagers_[i]);
        }

        assertGe(sumUnrealizedLossesOf, IStrategyManager(strategyManager_).unrealizedLosses(), "SM Invariant I");
    }

    /**************************************************************************************************************************************/
    /*** Aave V3 Strategy Invariants                                                                                                    ***/
    /**************************************************************************************************************************************/

    function assert_aaveV3Strategy_invariants(
        address strategy_,
        uint256 totalFundings_,
        uint256 totalYield_,
        uint256 totalWithdrawals_,
        uint256 totalFees_
    )
        internal view
    {
        assert_aaveV3Strategy_invariant_A(strategy_, totalFundings_, totalYield_, totalWithdrawals_, totalFees_);
        assert_aaveV3Strategy_invariant_B(strategy_, totalFundings_, totalWithdrawals_, totalFees_);
        assert_aaveV3Strategy_invariant_C(strategy_);
        assert_aaveV3Strategy_invariant_D(strategy_);
        assert_aaveV3Strategy_invariant_E(strategy_);
        assert_aaveV3Strategy_invariant_F(strategy_);
        assert_aaveV3Strategy_invariant_G(strategy_);
        assert_aaveV3Strategy_invariant_H(strategy_);
        assert_aaveV3Strategy_invariant_I(strategy_);
        assert_aaveV3Strategy_invariant_J(strategy_);
    }

    function assert_aaveV3Strategy_invariant_A(
        address strategy_,
        uint256 totalFundings_,
        uint256 totalYield_,
        uint256 totalWithdrawals_,
        uint256 totalFees_
    )
        internal view
    {
        if (IAaveV3Strategy(strategy_).isLossRecognized()) return;

        ( uint256 pendingYield, uint256 pendingFee ) = _pendingAaveAccrual(strategy_);

        uint256 recordedAum = totalFundings_ + totalYield_ - totalWithdrawals_ - totalFees_;
        uint256 pendingAum  = pendingYield - pendingFee;
        uint256 expectedAum = recordedAum + pendingAum;

        assertApproxEqAbs(
            IAaveV3Strategy(strategy_).assetsUnderManagement(),
            expectedAum,
            AAVE_ROUNDING_TOLERANCE,
            "AaveV3 Invariant A"
        );
    }

    function assert_aaveV3Strategy_invariant_B(
        address strategy_,
        uint256 totalFundings_,
        uint256 totalWithdrawals_,
        uint256 totalFees_
    )
        internal view
    {
        address aaveToken     = IAaveV3Strategy(strategy_).aaveToken();
        uint256 aTokenBalance = IERC20(aaveToken).balanceOf(strategy_);

        uint256 netOutflows   = totalWithdrawals_ + totalFees_ + AAVE_ROUNDING_TOLERANCE;
        uint256 expectedFloor = netOutflows < totalFundings_ ? totalFundings_ - netOutflows : 0;

        assertGe(aTokenBalance, expectedFloor, "AaveV3 Invariant B");
    }

    // NOTE: Should not be used on mainnet as it's vulnerable to griefing by donation attacks.
    function assert_aaveV3Strategy_invariant_C(address underlyingStrategy_) internal view {
        assertEq(IERC20(IAaveV3Strategy(underlyingStrategy_).fundsAsset()).balanceOf(underlyingStrategy_), 0, "AaveV3 Invariant C");
    }

    function assert_aaveV3Strategy_invariant_D(address strategy_) internal view {
        address fundsAsset = IAaveV3Strategy(strategy_).fundsAsset();
        address aavePool   = IAaveV3Strategy(strategy_).aavePool();

        assertEq(IERC20(fundsAsset).allowance(strategy_, aavePool), 0, "AaveV3 Invariant D");
    }

    function assert_aaveV3Strategy_invariant_E(address strategy_) internal view {
        address aaveToken     = IAaveV3Strategy(strategy_).aaveToken();
        uint256 aTokenBalance = IERC20(aaveToken).balanceOf(strategy_);

        assertGe(aTokenBalance, IAaveV3Strategy(strategy_).lastRecordedTotalAssets(), "AaveV3 Invariant E");
    }

    function assert_aaveV3Strategy_invariant_F(address strategy_) internal view {
        assertGe(
            IAaveV3Strategy(strategy_).assetsUnderManagement(),
            IAaveV3Strategy(strategy_).lastRecordedTotalAssets(),
            "AaveV3 Invariant F"
        );
    }

    function assert_aaveV3Strategy_invariant_G(address strategy_) internal view {
        assertLe(
            IAaveV3Strategy(strategy_).availableToWithdraw(),
            IAaveV3Strategy(strategy_).assetsUnderManagement(),
            "AaveV3 Invariant G"
        );
    }

    function assert_aaveV3Strategy_invariant_H(address strategy_) internal view {
        address fundsAsset = IAaveV3Strategy(strategy_).fundsAsset();
        address aavePool   = IAaveV3Strategy(strategy_).aavePool();
        address aaveToken  = IAaveV3Strategy(strategy_).aaveToken();

        uint256 aaveLiquidity = IAaveV3Strategy(strategy_).useVirtualUnderlyingBalance()
            ? uint256(IAavePoolLike(aavePool).getVirtualUnderlyingBalance(fundsAsset))
            : IERC20(fundsAsset).balanceOf(aaveToken);

        assertLe(IAaveV3Strategy(strategy_).availableToWithdraw(), aaveLiquidity, "AaveV3 Invariant H");
    }

    function assert_aaveV3Strategy_invariant_I(address strategy_) internal view {
        assertLe(
            IAaveV3Strategy(strategy_).unrealizedLosses(),
            IAaveV3Strategy(strategy_).assetsUnderManagement(),
            "AaveV3 Invariant I"
        );
    }

    function assert_aaveV3Strategy_invariant_J(address strategy_) internal view {
        uint32 delegateFeeRate = IAaveV3Strategy(strategy_).strategyDelegateFeeRate();
        uint32 protocolFeeRate = IAaveV3Strategy(strategy_).strategyProtocolFeeRate();

        assertLe(delegateFeeRate + protocolFeeRate, 1e6, "AaveV3 Invariant J");
    }

    /**************************************************************************************************************************************/
    /*** Sky Strategy Invariants                                                                                                        ***/
    /**************************************************************************************************************************************/

    function assert_skyStrategy_invariants(
        address strategy_,
        uint256 fundings_,
        uint256 yield_,
        uint256 withdrawals_,
        uint256 fees_
    )
        internal view
    {
        assert_skyStrategy_invariant_A(strategy_, fundings_, yield_, withdrawals_, fees_);
        assert_skyStrategy_invariant_B(strategy_);
        assert_skyStrategy_invariant_C(strategy_);
        assert_skyStrategy_invariant_D(strategy_, ISkyStrategy(strategy_).assetsUnderManagement());
        assert_skyStrategy_invariant_E(strategy_);
        assert_skyStrategy_invariant_F(strategy_);
        assert_skyStrategy_invariant_G(strategy_);
        assert_skyStrategy_invariant_H(strategy_);
        assert_skyStrategy_invariant_I(strategy_);
    }

    function assert_skyStrategy_invariant_A(
        address strategy_,
        uint256 fundings_,
        uint256 yield_,
        uint256 withdrawals_,
        uint256 fees_
    )
        internal view
    {
        if (ISkyStrategy(strategy_).isLossRecognized()) return;

        ( uint256 pendingYield, uint256 pendingFee ) = _pendingSkyAccrual(strategy_);

        uint256 recordedAum = fundings_ + yield_ - withdrawals_ - fees_;
        uint256 pendingAum  = pendingYield - pendingFee;
        uint256 expectedAum = recordedAum + pendingAum;

        assertApproxEqAbs(
            ISkyStrategy(strategy_).assetsUnderManagement(),
            expectedAum,
            SKY_ROUNDING_TOLERANCE,
            "Sky Invariant A"
        );
    }

    // NOTE: Should not be used on mainnet as it's vulnerable to griefing by donation attacks.
    function assert_skyStrategy_invariant_B(address underlyingStrategy_) internal view {
        assertEq(IERC20(ISkyStrategy(underlyingStrategy_).usds()).balanceOf(underlyingStrategy_),       0, "Sky Invariant B1");
        assertEq(IERC20(ISkyStrategy(underlyingStrategy_).fundsAsset()).balanceOf(underlyingStrategy_), 0, "Sky Invariant B2");
    }

    function assert_skyStrategy_invariant_C(address strategy_) internal view {
        address usds        = ISkyStrategy(strategy_).usds();
        address psm         = ISkyStrategy(strategy_).psm();
        address savingsUsds = ISkyStrategy(strategy_).savingsUsds();

        assertEq(IERC20(usds).allowance(strategy_, psm),         0, "Sky Invariant C1");
        assertEq(IERC20(usds).allowance(strategy_, savingsUsds), 0, "Sky Invariant C2");
    }

    function assert_skyStrategy_invariant_D(address strategy_, uint256 gemAmount_) internal view {
        address psm = ISkyStrategy(strategy_).psm();

        uint256 usdsAmount   = _usdsForGem(strategy_, psm, gemAmount_);
        uint256 roundTripGem = _gemForUsds(strategy_, psm, usdsAmount);

        assertApproxEqAbs(roundTripGem, gemAmount_, 2, "Sky Invariant D");
    }

    function assert_skyStrategy_invariant_E(address strategy_) internal view {
        assertGe(
            ISkyStrategy(strategy_).assetsUnderManagement(),
            ISkyStrategy(strategy_).lastRecordedTotalAssets(),
            "Sky Invariant E"
        );
    }

    function assert_skyStrategy_invariant_F(address strategy_) internal view {
        assertLe(
            ISkyStrategy(strategy_).availableToWithdraw(),
            ISkyStrategy(strategy_).assetsUnderManagement(),
            "Sky Invariant F"
        );
    }

    function assert_skyStrategy_invariant_G(address strategy_) internal view {
        address fundsAsset = ISkyStrategy(strategy_).fundsAsset();
        address psm        = ISkyStrategy(strategy_).psm();

        uint256 pocketLiquidity = IERC20(fundsAsset).balanceOf(IPSMLike(psm).pocket());

        assertLe(ISkyStrategy(strategy_).availableToWithdraw(), pocketLiquidity, "Sky Invariant G");
    }

    function assert_skyStrategy_invariant_H(address strategy_) internal view {
        assertLe(
            ISkyStrategy(strategy_).unrealizedLosses(),
            ISkyStrategy(strategy_).assetsUnderManagement(),
            "Sky Invariant H"
        );
    }

    function assert_skyStrategy_invariant_I(address strategy_) internal view {
        uint32 delegateFeeRate = ISkyStrategy(strategy_).strategyDelegateFeeRate();
        uint32 protocolFeeRate = ISkyStrategy(strategy_).strategyProtocolFeeRate();

        assertLe(delegateFeeRate + protocolFeeRate, 1e6, "Sky Invariant I");
    }

    /**************************************************************************************************************************************/
    /*** Allocation Strategy Invariants                                                                                                 ***/
    /**************************************************************************************************************************************/

    function assert_allocationStrategy_invariants(
        address strategy_,
        uint256 fundings_,
        uint256 yield_,
        uint256 withdrawals_,
        uint256 fees_,
        uint256 losses_,
        AllocationStrategyHandler.ManagedWalletInfo[] memory walletInfo_
    )
        internal view
    {
        assert_allocationStrategy_invariant_A(strategy_, fundings_, yield_, withdrawals_, fees_, losses_);
        assert_allocationStrategy_invariant_B(strategy_);
        assert_allocationStrategy_invariant_C(strategy_, walletInfo_);

        for (uint256 i; i < walletInfo_.length; ++i) {
            assert_allocationStrategy_invariant_D(strategy_, walletInfo_[i]);
        }

        assert_allocationStrategy_invariant_E(strategy_);
        assert_allocationStrategy_invariant_F(strategy_);
        assert_allocationStrategy_invariant_G(strategy_);
        assert_allocationStrategy_invariant_H(strategy_);
        assert_allocationStrategy_invariant_I(strategy_);
        assert_allocationStrategy_invariant_J(strategy_);
    }

    function assert_allocationStrategy_invariant_A(
        address strategy_,
        uint256 fundings_,
        uint256 yield_,
        uint256 withdrawals_,
        uint256 fees_,
        uint256 losses_
    )
        internal view
    {
        uint256 recordedAum     = fundings_ + yield_ - withdrawals_ - fees_ - losses_;
        uint256 unrealizedYield = IAllocationStrategy(strategy_).unrealizedYield();
        uint256 expectedAum     = recordedAum - unrealizedYield;

        assertEq(IAllocationStrategy(strategy_).assetsUnderManagement(), expectedAum, "Allocation Invariant A");
    }

    function assert_allocationStrategy_invariant_B(address strategy_) internal view {
        address fundsAsset = IAllocationStrategy(strategy_).fundsAsset();

        assertGe(
            IERC20(fundsAsset).balanceOf(strategy_),
            IAllocationStrategy(strategy_).recordedAssets(),
            "Allocation Invariant B"
        );
    }

    function assert_allocationStrategy_invariant_C(
        address strategy_,
        AllocationStrategyHandler.ManagedWalletInfo[] memory walletInfo_
    )
        internal view
    {
        uint256 sumDeployed;

        for (uint256 i; i < walletInfo_.length; ++i) {
            sumDeployed += IAllocationStrategy(strategy_).deployedAssetsOf(walletInfo_[i].wallet);
        }

        assertEq(IAllocationStrategy(strategy_).totalDeployedAssets(), sumDeployed, "Allocation Invariant C");
    }

    function assert_allocationStrategy_invariant_D(
        address strategy_,
        AllocationStrategyHandler.ManagedWalletInfo memory walletInfo_
    )
        internal view
    {
        uint256 expectedDeployedAssets = walletInfo_.deployed - walletInfo_.returned - walletInfo_.lost;

        assertEq(IAllocationStrategy(strategy_).deployedAssetsOf(walletInfo_.wallet), expectedDeployedAssets, "Allocation Invariant D");
    }

    function assert_allocationStrategy_invariant_E(address strategy_) internal view {
        assertLe(
            IAllocationStrategy(strategy_).availableToWithdraw(),
            IAllocationStrategy(strategy_).assetsUnderManagement(),
            "Allocation Invariant E"
        );
    }

    function assert_allocationStrategy_invariant_F(address strategy_) internal view {
        assertLe(
            IAllocationStrategy(strategy_).unrealizedLosses(),
            IAllocationStrategy(strategy_).assetsUnderManagement(),
            "Allocation Invariant F"
        );
    }

    function assert_allocationStrategy_invariant_G(address strategy_) internal view {
        assertLe(
            IAllocationStrategy(strategy_).unrealizedYield(),
            IAllocationStrategy(strategy_).recordedAssets(),
            "Allocation Invariant G"
        );
    }

    function assert_allocationStrategy_invariant_H(address strategy_) internal view {
        assertLe(
            IAllocationStrategy(strategy_).unrealizedYield(),
            IAllocationStrategy(strategy_).scheduledYieldAssets(),
            "Allocation Invariant H"
        );
    }

    function assert_allocationStrategy_invariant_I(address strategy_) internal view {
        uint32 yieldStart        = IAllocationStrategy(strategy_).yieldStart();
        uint32 yieldDeadline     = IAllocationStrategy(strategy_).yieldDeadline();
        uint32 yieldLastRealized = IAllocationStrategy(strategy_).yieldLastRealized();

        assertLe(yieldLastRealized, yieldStart,    "Allocation Invariant I1");
        assertLe(yieldStart,        yieldDeadline, "Allocation Invariant I2");
    }

    function assert_allocationStrategy_invariant_J(address strategy_) internal view {
        uint32 delegateFeeRate = IAllocationStrategy(strategy_).strategyDelegateFeeRate();
        uint32 protocolFeeRate = IAllocationStrategy(strategy_).strategyProtocolFeeRate();

        assertLe(delegateFeeRate + protocolFeeRate, 1e6, "Allocation Invariant J");
    }

    /**************************************************************************************************************************************/
    /*** Internal Helpers Functions                                                                                                     ***/
    /**************************************************************************************************************************************/

    function _gemForUsds(address strategy_, address psm_, uint256 usdsAmount_) internal view returns (uint256 gemAmount_) {
        uint256 tout = _resolveTout(strategy_, psm_);
        uint256 to18 = IPSMLike(psm_).to18ConversionFactor();

        gemAmount_ = (usdsAmount_ * 1e18) / (to18 * (1e18 + tout));
    }

    function _getActiveLoans() internal view returns (address[] memory loans) {
        if (address(otlHandler) == address(0)) return loans;

        uint256 index;
        uint256 length;

        for (uint256 i; i < otlHandler.numLoans(); ++i) {
            if (IOpenTermLoan(otlHandler.loans(i)).dateFunded() != 0) length++;
        }

        loans = new address[](length);

        for (uint256 i; i < otlHandler.numLoans(); ++i) {
            address loan = otlHandler.loans(i);

            if (IOpenTermLoan(loan).dateFunded() != 0) {
                loans[index++] = loan;
            }
        }
    }

    function _getExpectedIssuanceRate(address loan) internal view returns (uint256 expectedIssuanceRate) {
        (
            uint24 platformManagementFeeRate,
            uint24 delegateManagementFeeRate,
            ,
        ) = IOpenTermLoanManager(otlHandler.loanManager()).paymentFor(loan);

        uint256 grossInterest  = _getProRatedAmount(
            IOpenTermLoan(loan).principal(),
            IOpenTermLoan(loan).interestRate(),
            IOpenTermLoan(loan).paymentInterval()
        );

        uint256 managementFees = grossInterest * (delegateManagementFeeRate + platformManagementFeeRate) / 1e6;

        expectedIssuanceRate = (grossInterest - managementFees) * 1e27 / IOpenTermLoan(loan).paymentInterval();
    }

    function _getExpectedNetInterest(address loan) internal view returns (uint256 netInterest) {
        ( , uint256 grossInterest, , , ) = IOpenTermLoan(loan).getPaymentBreakdown(block.timestamp);

        (
            uint24 platformManagementFeeRate,
            uint24 delegateManagementFeeRate,
            ,
        ) = IOpenTermLoanManager(otlHandler.loanManager()).paymentFor(loan);

        uint256 managementFees = grossInterest * (delegateManagementFeeRate + platformManagementFeeRate) / 1e6;

        netInterest = grossInterest - managementFees;
    }

    function _getExpectedPaymentBreakdown(address loan) internal view
        returns (
            uint256 expectedPrincipal,
            uint256 expectedInterest,
            uint256 expectedLateInterest,
            uint256 expectedDelegateServiceFee,
            uint256 expectedPlatformServiceFee
        )
    {
        uint256 startTime = IOpenTermLoan(loan).datePaid() == 0 ? IOpenTermLoan(loan).dateFunded() : IOpenTermLoan(loan).datePaid();
        uint256 interval  = block.timestamp - startTime;

        uint256 lateInterval = block.timestamp > IOpenTermLoan(loan).paymentDueDate()
            ? block.timestamp - IOpenTermLoan(loan).paymentDueDate()
            : 0;

        uint256 principal = IOpenTermLoan(loan).principal();

        expectedPrincipal          = IOpenTermLoan(loan).dateCalled() == 0 ? 0 : IOpenTermLoan(loan).calledPrincipal();
        expectedInterest           = _getProRatedAmount(principal, IOpenTermLoan(loan).interestRate(), interval);
        expectedLateInterest       = 0;
        expectedDelegateServiceFee = _getProRatedAmount(principal, IOpenTermLoan(loan).delegateServiceFeeRate(), interval);
        expectedPlatformServiceFee = _getProRatedAmount(principal, IOpenTermLoan(loan).platformServiceFeeRate(), interval);

        if (lateInterval > 0) {
            expectedLateInterest += _getProRatedAmount(principal, IOpenTermLoan(loan).lateInterestPremiumRate(), lateInterval);
            expectedLateInterest += principal * IOpenTermLoan(loan).lateFeeRate() / 1e6;
        }
    }

    function _getOutstandingValue(address loan_) internal view returns (uint256 outstandingValue_) {
        if (IOpenTermLoan(loan_).dateFunded()   == 0) return 0;
        if (IOpenTermLoan(loan_).dateImpaired() != 0) return 0;
        if (otlHandler.isDefaulted(loan_))            return 0;

        address loanManager_ = address(otlHandler.loanManager());

        (
            uint256 platformManagementFeeRate_,
            uint256 delegateManagementFeeRate_,
            ,
        ) = IOpenTermLoanManager(loanManager_).paymentFor(loan_);

        uint256 startTime_ = IOpenTermLoan(loan_).datePaid() != 0
            ? IOpenTermLoan(loan_).datePaid()
            : IOpenTermLoan(loan_).dateFunded();

        uint256 grossInterest_ = _getProRatedAmount(
            IOpenTermLoan(loan_).principal(),
            IOpenTermLoan(loan_).interestRate(),
            block.timestamp - startTime_
        );

        uint256 netInterest_ = grossInterest_ * (1e6 - delegateManagementFeeRate_ - platformManagementFeeRate_) / 1e6;

        outstandingValue_ = IOpenTermLoan(loan_).principal() + netInterest_;
    }

    function _getProRatedAmount(uint256 amount_, uint256 rate_, uint256 interval_) internal pure returns (uint256 proRatedAmount_) {
        proRatedAmount_ = (amount_ * rate_ * interval_) / (365 days * 1e6);
    }

    function _pendingAaveAccrual(address strategy_) internal view returns (uint256 pendingYield_, uint256 pendingFee_) {
        uint256 currentTotalAssets = IERC20(IAaveV3Strategy(strategy_).aaveToken()).balanceOf(strategy_);
        uint256 lastRecorded       = IAaveV3Strategy(strategy_).lastRecordedTotalAssets();

        if (currentTotalAssets <= lastRecorded) return (0, 0);

        pendingYield_ = currentTotalAssets - lastRecorded;

        uint32 delegateFeeRate = IAaveV3Strategy(strategy_).strategyDelegateFeeRate();
        uint32 protocolFeeRate = IAaveV3Strategy(strategy_).strategyProtocolFeeRate();

        pendingFee_ = pendingYield_ * (delegateFeeRate + protocolFeeRate) / 1e6;
    }

    function _pendingSkyAccrual(address strategy_) internal view returns (uint256 pendingYield_, uint256 pendingFee_) {
        address savingsUsds = ISkyStrategy(strategy_).savingsUsds();
        address psm         = ISkyStrategy(strategy_).psm();

        uint256 sUsdsBalance       = IERC20(savingsUsds).balanceOf(strategy_);
        uint256 usdsAmount         = IERC4626Like(savingsUsds).previewRedeem(sUsdsBalance);
        uint256 currentTotalAssets = _gemForUsds(strategy_, psm, usdsAmount);

        uint256 lastRecorded = ISkyStrategy(strategy_).lastRecordedTotalAssets();

        if (currentTotalAssets <= lastRecorded) return (0, 0);

        pendingYield_ = currentTotalAssets - lastRecorded;

        uint32 delegateFeeRate = ISkyStrategy(strategy_).strategyDelegateFeeRate();
        uint32 protocolFeeRate = ISkyStrategy(strategy_).strategyProtocolFeeRate();

        pendingFee_ = pendingYield_ * (delegateFeeRate + protocolFeeRate) / 1e6;
    }

    function _resolveTout(address strategy_, address psm_) internal view returns (uint256 tout_) {
        tout_ = IPSMLike(psm_).tout();

        if (tout_ == type(uint256).max) tout_ = ISkyStrategy(strategy_).fallbackTout();
    }

    function _usdsForGem(address strategy_, address psm_, uint256 gemAmount_) internal view returns (uint256 usdsAmount_) {
        uint256 tout     = _resolveTout(strategy_, psm_);
        uint256 to18     = IPSMLike(psm_).to18ConversionFactor();
        uint256 gemAmt18 = gemAmount_ * to18;

        usdsAmount_ = gemAmt18 + gemAmt18 * tout / 1e18;
    }

}
