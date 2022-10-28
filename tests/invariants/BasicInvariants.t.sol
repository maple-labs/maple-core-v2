// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { Address, console, InvariantTest } from "../../modules/contract-test-utils/contracts/test.sol";
import { IMapleLoan }                      from "../../modules/loan/contracts/interfaces/IMapleLoan.sol";
import { IMapleLoanFeeManager }            from "../../modules/loan/contracts/interfaces/IMapleLoanFeeManager.sol";

import { TestBaseWithAssertions } from "../../contracts/utilities/TestBaseWithAssertions.sol";

import { LoanHandler } from "./actors/LoanHandler.sol";
import { LpHander }    from "./actors/LpHandler.sol";

import { BaseInvariants } from "./BaseInvariants.t.sol";

contract BoundedActorBasedInvariants_NoDefaultTests is BaseInvariants {

    /******************************************************************************************************************************/
    /*** State Variables                                                                                                        ***/
    /******************************************************************************************************************************/

    uint256 constant public NUM_BORROWERS = 5;
    uint256 constant public NUM_LPS       = 10;
    uint256 constant public MAX_NUM_LOANS = 50;

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
            numBorrowers_:    NUM_BORROWERS,
            maxLoans_:        MAX_NUM_LOANS
        });

        lpHandler = new LpHander(address(pool), address(this), NUM_LPS);

        targetContract(address(lpHandler));
        targetContract(address(loanHandler));

        targetSender(address(0xdeed));
    }

    /******************************************************************************************************************************/
    /*** Loan Iteration Invariants (Loan and LoanManager)                                                                       ***/
    /******************************************************************************************************************************/

    function invariant_loan_A_B_C_loanManager_L_M_N() external useCurrentTimestamp {
        for (uint256 i; i < loanHandler.numLoans(); ++i) {
            address loan = loanHandler.activeLoans(i);
            assert_loan_invariant_A(loan);
            assert_loan_invariant_B(loan);
            assert_loan_invariant_C(loan);

            ( , , uint256 startDate, uint256 paymentDueDate, , uint256 refinanceInterest , ) = loanManager.payments(loanManager.paymentIdOf(loan));

            assert_loanManager_invariant_L(loan, refinanceInterest);
            assert_loanManager_invariant_M(loan, paymentDueDate);
            assert_loanManager_invariant_N(loan, startDate);
        }
    }

    /******************************************************************************************************************************/
    /*** Loan Manager Non-Iterative Invariants                                                                                  ***/
    /******************************************************************************************************************************/

    function invariant_loanManager_A() external useCurrentTimestamp { assert_loanManager_invariant_A(); }
    function invariant_loanManager_B() external useCurrentTimestamp { assert_loanManager_invariant_B(); }
    function invariant_loanManager_C() external useCurrentTimestamp { assert_loanManager_invariant_C(); }
    function invariant_loanManager_D() external useCurrentTimestamp { assert_loanManager_invariant_D(); }
    function invariant_loanManager_E() external useCurrentTimestamp { assert_loanManager_invariant_E(); }
    function invariant_loanManager_F() external useCurrentTimestamp { assert_loanManager_invariant_F(); }
    function invariant_loanManager_G() external useCurrentTimestamp { assert_loanManager_invariant_G(); }
    function invariant_loanManager_H() external useCurrentTimestamp { assert_loanManager_invariant_H(); }
    function invariant_loanManager_I() external useCurrentTimestamp { assert_loanManager_invariant_I(); }
    function invariant_loanManager_J() external useCurrentTimestamp { assert_loanManager_invariant_J(); }
    function invariant_loanManager_K() external useCurrentTimestamp { assert_loanManager_invariant_K(); }

    /******************************************************************************************************************************/
    /*** Pool Invariants                                                                                                        ***/
    /******************************************************************************************************************************/

    function invariant_pool_A() external useCurrentTimestamp { assert_pool_invariant_A(); }
    function invariant_pool_C() external useCurrentTimestamp { assert_pool_invariant_C(); }
    function invariant_pool_D() external useCurrentTimestamp { assert_pool_invariant_D(); }
    function invariant_pool_E() external useCurrentTimestamp { assert_pool_invariant_E(); }
    function invariant_pool_H() external useCurrentTimestamp { assert_pool_invariant_H(); }
    function invariant_pool_I() external useCurrentTimestamp { assert_pool_invariant_I(); }
    function invariant_pool_J() external useCurrentTimestamp { assert_pool_invariant_J(); }
    function invariant_pool_K() external useCurrentTimestamp { assert_pool_invariant_K(); }

    function invariant_pool_B_F_G() external useCurrentTimestamp {
        uint256 sumBalanceOf;
        uint256 sumBalanceOfAssets;

        for (uint256 i; i < lpHandler.numHolders(); ++i) {
            address holder = lpHandler.holders(i);

            sumBalanceOfAssets += pool.balanceOfAssets(holder);
            sumBalanceOf       += pool.balanceOf(holder);

            assert_pool_invariant_F(holder);
        }

        assert_pool_invariant_B(sumBalanceOfAssets);
        assert_pool_invariant_G(sumBalanceOf);
    }

    /******************************************************************************************************************************/
    /*** Pool Manager Invariants                                                                                                ***/
    /******************************************************************************************************************************/

    function invariant_poolManager_A_totalAssetsEqCashPlusAUM() external useCurrentTimestamp {
        assert_poolManager_invariant_A();
    }

    /******************************************************************************************************************************/
    /*** Withdrawal Manager Invariants                                                                                          ***/
    /******************************************************************************************************************************/

    function invariant_withdrawalManager_A_F_G_H_I_J_K_L() external useCurrentTimestamp {
        if (pool.totalSupply() == 0 || pool.totalAssets() == 0) return;

        uint256 sumLockedShares;

        for (uint256 i; i < lpHandler.numLps(); ++i) {
            address lp = lpHandler.lps(i);

            sumLockedShares += withdrawalManager.lockedShares(lp);

            uint256 totalRequestedLiquidity = withdrawalManager.totalCycleShares(withdrawalManager.exitCycleId(lp)) * pool.totalAssets() / pool.totalSupply();

            ( uint256 shares, uint256 assets, bool partialLiquidity ) = withdrawalManager.getRedeemableAmounts(withdrawalManager.lockedShares(lp), lp);

            assert_withdrawalManager_invariant_F(shares);
            assert_withdrawalManager_invariant_G(lp, shares);
            assert_withdrawalManager_invariant_H(lp, shares);

            assert_withdrawalManager_invariant_I(assets);
            assert_withdrawalManager_invariant_J(assets, totalRequestedLiquidity);
            assert_withdrawalManager_invariant_K(lp, assets);

            assert_withdrawalManager_invariant_L(partialLiquidity, totalRequestedLiquidity);
        }

        assertTrue(pool.balanceOf(address(withdrawalManager)) == sumLockedShares);
    }

    function invariant_withdrawalManager_B() external useCurrentTimestamp { assert_withdrawalManager_invariant_B(); }
    function invariant_withdrawalManager_C() external useCurrentTimestamp { assert_withdrawalManager_invariant_C(); }
    function invariant_withdrawalManager_D() external useCurrentTimestamp { assert_withdrawalManager_invariant_D(); }
    function invariant_withdrawalManager_E() external useCurrentTimestamp { assert_withdrawalManager_invariant_E(); }
    function invariant_withdrawalManager_M() external useCurrentTimestamp { assert_withdrawalManager_invariant_M(); }
    function invariant_withdrawalManager_N() external useCurrentTimestamp { assert_withdrawalManager_invariant_N(); }

}


