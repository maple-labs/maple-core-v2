// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console2 as console } from "../../modules/forge-std/src/console2.sol";
import { StdInvariant        } from "../../modules/forge-std/src/Test.sol";

import {
    IERC20,
    IERC20Like,
    IERC4626Like,
    IOpenTermLoan,
    IOpenTermLoanManager,
    IPool,
    IPoolManager,
    IPoolPermissionManager,
    IStrategyLike,
    IWithdrawalManagerQueue
} from "../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

import { DepositHandler }         from "./handlers/DepositHandler.sol";
import { OpenTermLoanHandler }    from "./handlers/OpenTermLoanHandler.sol";
import { PermissionHandler }      from "./handlers/PermissionHandler.sol";
import { QueueWithdrawalHandler } from "./handlers/QueueWithdrawalHandler.sol";
import { TransferHandler }        from "./handlers/TransferHandler.sol";

contract BaseInvariants is StdInvariant, TestBaseWithAssertions {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    uint256 constant ALLOWED_DIFF         = 150;
    uint256 constant ALLOWED_OTL_AUM_DIFF = 1e6;
    uint256 constant PUBLIC               = 3;
    uint256 constant MAXIMUM_BITMAP       = 2 ** 16 - 1;

    DepositHandler            depositHandler;
    OpenTermLoanHandler       otlHandler;
    PermissionHandler         permissionHandler;
    QueueWithdrawalHandler    queueWithdrawalHandler;
    TransferHandler           transferHandler;

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

     * PoolManager (non-liquidating)
        * Invariant A: totalAssets == cash + ∑assetsUnderManagement[openTermLoanManager]
        * Invariant B: totalAssets >= unrealizedLosses

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

    function assert_pool_invariants_all() internal view {
        assert_pool_invariants_A_B_D_E_F_G_I_J_K();

        assert_pool_invariant_C();
        assert_pool_invariant_H();
    }

    function assert_pool_invariants_A_B_D_E_G_I_J_K() internal view {
        assert_pool_invariant_A();
        assert_pool_invariant_D();
        assert_pool_invariant_E();
        assert_pool_invariant_I();
        assert_pool_invariant_J();
        assert_pool_invariant_K();

        uint256 sumBalanceOf;
        uint256 sumBalanceOfAssets;

        for (uint256 i; i < lps.length; ++i) {
            sumBalanceOfAssets += pool.balanceOfAssets(lps[i]);
            sumBalanceOf       += pool.balanceOf(lps[i]);
        }

        sumBalanceOfAssets += pool.balanceOfAssets(poolManager.withdrawalManager());
        sumBalanceOf       += pool.balanceOf(poolManager.withdrawalManager());

        assert_pool_invariant_B(sumBalanceOfAssets);
        assert_pool_invariant_G(sumBalanceOf);
    }

    function assert_pool_invariants_A_B_D_E_F_G_I_J_K() internal view {
        assert_pool_invariants_A_B_D_E_G_I_J_K();

        for (uint256 i; i < lps.length; ++i) {
            assert_pool_invariant_F(lps[i]);
        }
    }

    function assert_pool_invariant_A() internal view {
        assertGe(pool.totalAssets(), fundsAsset.balanceOf(address(pool)), "Pool Invariant A");
    }

    function assert_pool_invariant_B(uint256 sumBalanceOfAssets) internal view {
        assertGe(pool.totalAssets(), sumBalanceOfAssets, "Pool Invariant B1");

        assertApproxEqAbs(pool.totalAssets(), sumBalanceOfAssets, lps.length, "Pool Invariant B2");
    }

    function assert_pool_invariant_C() internal view {
        assertGe(pool.totalAssets(), pool.totalSupply(), "Pool Invariant C");
    }

    function assert_pool_invariant_D() internal view {
        assertGe(pool.totalAssets(), pool.convertToAssets(pool.totalSupply()), "Pool Invariant D1");

        assertApproxEqAbs(pool.totalAssets(), pool.convertToAssets(pool.totalSupply()), 1, "Pool Invariant D2");
    }

    function assert_pool_invariant_E() internal view {
        assertGe(pool.convertToShares(pool.totalAssets()), pool.totalSupply(), "Pool Invariant E1");

        assertApproxEqAbs(pool.convertToShares(pool.totalAssets()), pool.totalSupply(), 1, "Pool Invariant E2");
    }

    function assert_pool_invariant_F(address holder) internal view {
        assertGe(pool.balanceOfAssets(holder), pool.balanceOf(holder), "Pool Invariant F");
    }

    function assert_pool_invariant_G(uint256 sumBalanceOf) internal view {
        assertEq(pool.totalSupply(), sumBalanceOf, "Pool Invariant G");
    }

    function assert_pool_invariant_H() internal view {
        if (pool.totalAssets() > 0) {
            assertEq(pool.convertToShares(pool.totalAssets()), pool.convertToExitShares(pool.totalAssets()), "Pool Invariant H");
        }
    }

    function assert_pool_invariant_I() internal view {
        assertEq(pool.totalAssets(), poolManager.totalAssets(), "Pool Invariant I");
    }

    function assert_pool_invariant_J() internal view {
        assertEq(pool.unrealizedLosses(), poolManager.unrealizedLosses(), "Pool Invariant J");
    }

    function assert_pool_invariant_K() internal view {
        if (pool.totalAssets() - pool.unrealizedLosses() > 0) {
            assertEq(pool.convertToExitShares(pool.totalAssets()), poolManager.convertToExitShares(pool.totalAssets()), "Pool Invariant K");
        }
    }

    /**************************************************************************************************************************************/
    /*** Pool Manager Functions                                                                                                         ***/
    /**************************************************************************************************************************************/

    function assert_pool_manager_invariants() internal view {
        assert_poolManager_invariant_A();
        assert_poolManager_invariant_B();
    }

    function assert_poolManager_invariant_A() internal view {
        uint256 aumUnderOpenTermLoans = getExpectedAumOtl();

        uint256 expectedTotalAssets = aumUnderOpenTermLoans + fundsAsset.balanceOf(address(pool));

        uint256 allowedOpenTermLoanCalcError = address(otlHandler) == address(0) ? 0 : ALLOWED_OTL_AUM_DIFF;

        assertApproxEqAbs(
            poolManager.totalAssets(),
            expectedTotalAssets,
            allowedOpenTermLoanCalcError,
            "PoolManager Invariant A"
        );
    }

    function assert_poolManager_invariant_B() internal view {
        assertTrue(poolManager.unrealizedLosses() <= poolManager.totalAssets(), "PoolManager Invariant B");
    }

    /**************************************************************************************************************************************/
    /*** Open Term Loan Invariants                                                                                                      ***/
    /**************************************************************************************************************************************/

    function assert_otl_invariants() internal view {
        address[] memory loans = _getActiveLoans();

        for (uint256 i; i < loans.length; ++i) {
            address loan = loans[i];

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

    function assert_otlm_invariants_A_B_C_D_E_F_G_H_I_J_L_M() internal view {
        assert_otlm_invariants_B_C_F_H_I_J_L_M();

        address[] memory loans = _getActiveLoans();

        address loanManager = address(otlHandler.loanManager());

        assert_otlm_invariant_A(loanManager, loans);
        assert_otlm_invariant_D(loanManager, loans);
        assert_otlm_invariant_E(loanManager);
        assert_otlm_invariant_G(loanManager);
    }

    function assert_otlm_invariants_B_C_F_H_I_J_L_M() internal view {
        address[] memory loans = _getActiveLoans();

        address loanManager = address(otlHandler.loanManager());

        assert_otlm_invariant_B(loanManager, loans);
        assert_otlm_invariant_C(loanManager, loans);
        assert_otlm_invariant_F(loanManager, loans);
        assert_otlm_invariant_L(loanManager);
        assert_otlm_invariant_M(loanManager, loans);

        for (uint256 i; i < loans.length; ++i) {
            address loan = loans[i];

            assert_otlm_invariant_H(loan, loanManager);
            assert_otlm_invariant_I(loan, loanManager);
            assert_otlm_invariant_J(loan, loanManager);
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

        assertApproxEqAbs(assetsUnderManagement, 0, otlHandler.numLoans() + ALLOWED_DIFF, "OTLM Invariant B");
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

        assertApproxEqAbs(diff, 0, ALLOWED_DIFF, "OTLM Invariant K");
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

    function assert_ppm_invariants() internal view {
        assert_ppm_invariant_A(address(poolPermissionManager), address(poolManager));
        assert_ppm_invariant_B(address(poolPermissionManager), address(poolManager), functionIds);
        assert_ppm_invariant_C(address(poolPermissionManager), lps);
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
            assertEq(ppm.permissionLevels(poolManagers_[i]), PUBLIC, "PPM Invariant D");
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
    /*** Internal Helpers Functions                                                                                                     ***/
    /**************************************************************************************************************************************/

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

    function _getLoanManager() internal view returns (address loanManager_) {
        loanManager_ = address(otlHandler.loanManager());
    }

    function _getOutstandingValue(address loan_) internal view returns (uint256 outstandingValue_) {
        if (IOpenTermLoan(loan_).dateFunded()   == 0) return 0;
        if (IOpenTermLoan(loan_).dateImpaired() != 0) return 0;
        if (otlHandler.isDefaulted(loan_))            return 0;

        address loanManager_ = _getLoanManager();

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

    function max(uint256 a_, uint256 b_) internal pure returns (uint256 maximum_) {
        maximum_ = a_ > b_ ? a_ : b_;
    }

    function min(uint256 a_, uint256 b_) internal pure returns (uint256 minimum_) {
        minimum_ = a_ < b_ ? a_ : b_;
    }

    /**************************************************************************************************************************************/
    /*** Public View Functions                                                                                                          ***/
    /**************************************************************************************************************************************/

    function getExpectedAumOtl() public view returns (uint256 expectedAum) {
        address[] memory loans = _getActiveLoans();

        for (uint256 i; i < loans.length; ++i) {
            expectedAum += _getOutstandingValue(loans[i]);
        }

        if (address(otlHandler) != address(0)) {
            expectedAum += otlHandler.totalUnrealizedLosses();
        }
    }

}
