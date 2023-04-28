// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IFixedTermLoanManager, ILoanLike } from "../../contracts/interfaces/Interfaces.sol";

import { DistributionHandler }  from "./handlers/DistributionHandler.sol";
import { FixedTermLoanHandler } from "./handlers/FixedTermLoanHandler.sol";
import { LpHandler }            from "./handlers/LpHandler.sol";

import { BaseInvariants } from "./BaseInvariants.t.sol";

contract DefaultsInvariants is BaseInvariants {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    uint256 constant NUM_BORROWERS = 5;
    uint256 constant NUM_LPS       = 10;

    /**************************************************************************************************************************************/
    /*** Setup Function                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function setUp() public override {
        super.setUp();

        currentTimestamp = block.timestamp;

        ftlHandler = new FixedTermLoanHandler({
            collateralAsset_:   address(collateralAsset),
            feeManager_:        address(feeManager),
            governor_:          governor,
            liquidatorFactory_: liquidatorFactory,
            loanFactory_:       fixedTermLoanFactory,
            poolManager_:       address(poolManager),
            testContract_:      address(this),
            numBorrowers_:      NUM_BORROWERS
        });

        lpHandler = new LpHandler(address(pool), address(this), NUM_LPS);

        ftlHandler.setSelectorWeight("createLoanAndFund(uint256)",           30);
        ftlHandler.setSelectorWeight("makePayment(uint256)",                 0);
        ftlHandler.setSelectorWeight("impairmentMakePayment(uint256)",       0);
        ftlHandler.setSelectorWeight("defaultMakePayment(uint256)",          20);
        ftlHandler.setSelectorWeight("impairLoan(uint256)",                  0);
        ftlHandler.setSelectorWeight("triggerDefault(uint256)",              20);
        ftlHandler.setSelectorWeight("finishCollateralLiquidation(uint256)", 10);
        ftlHandler.setSelectorWeight("warp(uint256)",                        20);

        lpHandler.setSelectorWeight("deposit(uint256)",       25);
        lpHandler.setSelectorWeight("mint(uint256)",          15);
        lpHandler.setSelectorWeight("redeem(uint256)",        15);
        lpHandler.setSelectorWeight("removeShares(uint256)",  15);
        lpHandler.setSelectorWeight("requestRedeem(uint256)", 15);
        lpHandler.setSelectorWeight("transfer(uint256)",      15);

        uint256[] memory weightsDistributorHandler = new uint256[](2);
        weightsDistributorHandler[0] = 20;  // lpHandler()
        weightsDistributorHandler[1] = 80;  // OTLHandler()

        address[] memory targetContracts = new address[](2);
        targetContracts[0] = address(lpHandler);
        targetContracts[1] = address(ftlHandler);

        address distributionHandler = address(new DistributionHandler(targetContracts, weightsDistributorHandler));

        targetContract(distributionHandler);

        targetSender(address(0xdeed));
    }

    /**************************************************************************************************************************************/
    /*** Invariants Removed                                                                                                             ***/
    /***************************************************************************************************************************************

    * Loan Manager
        * Invariant G: unrealizedLosses == 0
            NOTE: triggerDefault() with collateral that needs liquidating then unrealizedLosses will be > 0

    * Pool
        * Invariant C: totalAssets >= totalSupply (in non-liquidating scenario)
        * Invariant F: balanceOfAssets[user] >= balanceOf[user]
        * Invariant H: convertToExitShares == convertToShares
            NOTE: triggerDefault() with collateral that needs liquidating then unrealizedLosses will be > 0 hence a different exchange rate

    ***************************************************************************************************************************************/

    /**************************************************************************************************************************************/
    /*** Loan Iteration Invariants (Loan and LoanManager)                                                                               ***/
    /**************************************************************************************************************************************/

    function invariant_fixedTermLoan_A_B_fixedTermLoanManager_L_M_N() external useCurrentTimestamp {
        for (uint256 i; i < ftlHandler.numLoans(); ++i) {
            address               loan        = ftlHandler.activeLoans(i);
            IFixedTermLoanManager loanManager = IFixedTermLoanManager(ILoanLike(loan).lender());

            assert_ftl_invariant_A(loan);
            assert_ftl_invariant_B(loan);
            assert_ftl_invariant_C(loan, ftlHandler.platformOriginationFee(loan));

            (
                ,
                ,
                uint256 startDate,
                uint256 paymentDueDate,
                ,
                uint256 refinanceInterest
                ,
            ) = loanManager.payments(loanManager.paymentIdOf(loan));

            assert_ftlm_invariant_L(loan, refinanceInterest);
            assert_ftlm_invariant_M(loan, paymentDueDate);
            assert_ftlm_invariant_N(loan, startDate);
        }
    }

    /**************************************************************************************************************************************/
    /*** Loan Manager Non-Iterative Invariants                                                                                          ***/
    /**************************************************************************************************************************************/

    function invariant_fixedTermLoanManager_A() external useCurrentTimestamp { assert_ftlm_invariant_A(poolManager.loanManagerList(0)); }
    function invariant_fixedTermLoanManager_B() external useCurrentTimestamp { assert_ftlm_invariant_B(poolManager.loanManagerList(0)); }
    function invariant_fixedTermLoanManager_C() external useCurrentTimestamp { assert_ftlm_invariant_C(poolManager.loanManagerList(0)); }
    function invariant_fixedTermLoanManager_D() external useCurrentTimestamp { assert_ftlm_invariant_D(poolManager.loanManagerList(0)); }
    function invariant_fixedTermLoanManager_E() external useCurrentTimestamp { assert_ftlm_invariant_E(poolManager.loanManagerList(0)); }
    function invariant_fixedTermLoanManager_F() external useCurrentTimestamp { assert_ftlm_invariant_F(poolManager.loanManagerList(0)); }
    function invariant_fixedTermLoanManager_H() external useCurrentTimestamp { assert_ftlm_invariant_H(poolManager.loanManagerList(0)); }
    function invariant_fixedTermLoanManager_I() external useCurrentTimestamp { assert_ftlm_invariant_I(poolManager.loanManagerList(0)); }
    function invariant_fixedTermLoanManager_J() external useCurrentTimestamp { assert_ftlm_invariant_J(poolManager.loanManagerList(0)); }
    function invariant_fixedTermLoanManager_K() external useCurrentTimestamp { assert_ftlm_invariant_K(poolManager.loanManagerList(0)); }

    /**************************************************************************************************************************************/
    /*** Pool Invariants                                                                                                                ***/
    /**************************************************************************************************************************************/

    function invariant_pool_A() external useCurrentTimestamp { assert_pool_invariant_A(); }
    function invariant_pool_D() external useCurrentTimestamp { assert_pool_invariant_D(); }
    function invariant_pool_E() external useCurrentTimestamp { assert_pool_invariant_E(); }
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
        }

        assert_pool_invariant_B(sumBalanceOfAssets);
        assert_pool_invariant_G(sumBalanceOf);
    }

    /**************************************************************************************************************************************/
    /*** Pool Manager Invariants                                                                                                        ***/
    /**************************************************************************************************************************************/

    function invariant_poolManager_A() external useCurrentTimestamp {
        assert_poolManager_invariant_A();
    }

    function invariant_poolManager_B() external useCurrentTimestamp {
        assert_poolManager_invariant_B();
    }

    /**************************************************************************************************************************************/
    /*** Withdrawal Manager Invariants                                                                                                  ***/
    /**************************************************************************************************************************************/

    function invariant_withdrawalManager_A_F_G_H_I_J_K_L() external useCurrentTimestamp {
        if (pool.totalSupply() == 0 || pool.totalAssets() == 0) return;

        uint256 sumLockedShares;

        for (uint256 i; i < lpHandler.numLps(); ++i) {
            address lp = lpHandler.lps(i);

            sumLockedShares += withdrawalManager.lockedShares(lp);

            uint256 totalRequestedLiquidity =
                withdrawalManager.totalCycleShares(withdrawalManager.exitCycleId(lp)) * (pool.totalAssets() - pool.unrealizedLosses()) /
                pool.totalSupply();

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
