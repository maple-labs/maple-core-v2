// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IFixedTermLoanManager, ILoanLike } from "../../contracts/interfaces/Interfaces.sol";

import { CyclicalWithdrawalHandler } from "./handlers/CyclicalWithdrawalHandler.sol";
import { DepositHandler }            from "./handlers/DepositHandler.sol";
import { DistributionHandler }       from "./handlers/DistributionHandler.sol";
import { FixedTermLoanHandler }      from "./handlers/FixedTermLoanHandler.sol";
import { TransferHandler }           from "./handlers/TransferHandler.sol";

import { BaseInvariants } from "./BaseInvariants.t.sol";

contract BasicInvariants is BaseInvariants {

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

        for (uint256 i; i < NUM_LPS; i++) {
            lps.push(makeAddr(string(abi.encode("lp", i))));
        }

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.005e6,  // 10k after 1m seconds
            platformManagementFeeRate:  0.08e6
        });

        depositHandler            = new DepositHandler(address(pool), lps);
        transferHandler           = new TransferHandler(address(pool), lps);
        cyclicalWithdrawalHandler = new CyclicalWithdrawalHandler(address(pool), lps);

        ftlHandler = new FixedTermLoanHandler({
            collateralAsset_:   address(collateralAsset),
            feeManager_:        address(fixedTermFeeManager),
            governor_:          governor,
            liquidatorFactory_: liquidatorFactory,
            loanFactory_:       fixedTermLoanFactory,
            poolManager_:       address(poolManager),
            refinancer_:        address(fixedTermRefinancer),
            testContract_:      address(this),
            numBorrowers_:      NUM_BORROWERS
        });

        depositHandler.setSelectorWeight("deposit(uint256)", 7_500);
        depositHandler.setSelectorWeight("mint(uint256)",    2_500);

        transferHandler.setSelectorWeight("transfer(uint256)", 10_000);

        cyclicalWithdrawalHandler.setSelectorWeight("redeem(uint256)",        3_300);
        cyclicalWithdrawalHandler.setSelectorWeight("removeShares(uint256)",  3_300);
        cyclicalWithdrawalHandler.setSelectorWeight("requestRedeem(uint256)", 3_400);

        ftlHandler.setSelectorWeight("createLoanAndFund(uint256)",           3_000);
        ftlHandler.setSelectorWeight("makePayment(uint256)",                 4_500);
        ftlHandler.setSelectorWeight("impairmentMakePayment(uint256)",       0);
        ftlHandler.setSelectorWeight("defaultMakePayment(uint256)",          0);
        ftlHandler.setSelectorWeight("impairLoan(uint256)",                  0);
        ftlHandler.setSelectorWeight("triggerDefault(uint256)",              0);
        ftlHandler.setSelectorWeight("finishCollateralLiquidation(uint256)", 0);
        ftlHandler.setSelectorWeight("warp(uint256)",                        2_000);
        ftlHandler.setSelectorWeight("refinance(uint256)",                   500);

        address[] memory targetContracts = new address[](4);
        targetContracts[0] = address(transferHandler);
        targetContracts[1] = address(depositHandler);
        targetContracts[2] = address(cyclicalWithdrawalHandler);
        targetContracts[3] = address(ftlHandler);

        uint256[] memory weightsDistributorHandler = new uint256[](4);
        weightsDistributorHandler[0] = 5;
        weightsDistributorHandler[1] = 10;
        weightsDistributorHandler[2] = 10;
        weightsDistributorHandler[3] = 75;

        address distributionHandler = address(new DistributionHandler(targetContracts, weightsDistributorHandler));

        targetContract(distributionHandler);
    }

    /**************************************************************************************************************************************/
    /*** Loan Iteration Invariants (Loan and LoanManager)                                                                               ***/
    /**************************************************************************************************************************************/

    function statefulFuzz_basicInvariants_fixedTermLoan_A_B_C_fixedTermLoanManager_L_M_N() external useCurrentTimestamp {
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

    function statefulFuzz_basicInvariants_fixedTermLoanManager_A() external useCurrentTimestamp {
        assert_ftlm_invariant_A(poolManager.loanManagerList(0));

    }
    function statefulFuzz_basicInvariants_fixedTermLoanManager_B() external useCurrentTimestamp {
        assert_ftlm_invariant_B(poolManager.loanManagerList(0));
    }

    function statefulFuzz_basicInvariants_fixedTermLoanManager_C() external useCurrentTimestamp {
        assert_ftlm_invariant_C(poolManager.loanManagerList(0));
    }

    function statefulFuzz_basicInvariants_fixedTermLoanManager_D() external useCurrentTimestamp {
        assert_ftlm_invariant_D(poolManager.loanManagerList(0));
    }

    function statefulFuzz_basicInvariants_fixedTermLoanManager_E() external useCurrentTimestamp {
        assert_ftlm_invariant_E(poolManager.loanManagerList(0));
    }

    function statefulFuzz_basicInvariants_fixedTermLoanManager_F() external useCurrentTimestamp {
        assert_ftlm_invariant_F(poolManager.loanManagerList(0));
    }

    function statefulFuzz_basicInvariants_fixedTermLoanManager_G() external useCurrentTimestamp {
        assert_ftlm_invariant_G(poolManager.loanManagerList(0));
    }

    function statefulFuzz_basicInvariants_fixedTermLoanManager_H() external useCurrentTimestamp {
        assert_ftlm_invariant_H(poolManager.loanManagerList(0));
    }

    function statefulFuzz_basicInvariants_fixedTermLoanManager_I() external useCurrentTimestamp {
        assert_ftlm_invariant_I(poolManager.loanManagerList(0));
    }

    function statefulFuzz_basicInvariants_fixedTermLoanManager_J() external useCurrentTimestamp {
        assert_ftlm_invariant_J(poolManager.loanManagerList(0));
    }

    function statefulFuzz_basicInvariants_fixedTermLoanManager_K() external useCurrentTimestamp {
        assert_ftlm_invariant_K(poolManager.loanManagerList(0));
    }

    /**************************************************************************************************************************************/
    /*** Pool Invariants                                                                                                                ***/
    /**************************************************************************************************************************************/

    function statefulFuzz_basicInvariants_pool_A() external useCurrentTimestamp { assert_pool_invariant_A(); }
    function statefulFuzz_basicInvariants_pool_C() external useCurrentTimestamp { assert_pool_invariant_C(); }
    function statefulFuzz_basicInvariants_pool_D() external useCurrentTimestamp { assert_pool_invariant_D(); }
    function statefulFuzz_basicInvariants_pool_E() external useCurrentTimestamp { assert_pool_invariant_E(); }
    function statefulFuzz_basicInvariants_pool_H() external useCurrentTimestamp { assert_pool_invariant_H(); }
    function statefulFuzz_basicInvariants_pool_I() external useCurrentTimestamp { assert_pool_invariant_I(); }
    function statefulFuzz_basicInvariants_pool_J() external useCurrentTimestamp { assert_pool_invariant_J(); }
    function statefulFuzz_basicInvariants_pool_K() external useCurrentTimestamp { assert_pool_invariant_K(); }

    function statefulFuzz_basicInvariants_pool_B_F_G_2() external useCurrentTimestamp {
        uint256 sumBalanceOf;
        uint256 sumBalanceOfAssets;

        for (uint256 i; i < lps.length; ++i) {
            sumBalanceOfAssets += pool.balanceOfAssets(lps[i]);
            sumBalanceOf       += pool.balanceOf(lps[i]);

            assert_pool_invariant_F(lps[i]);
        }

        sumBalanceOfAssets += pool.balanceOfAssets(poolManager.withdrawalManager());
        sumBalanceOf       += pool.balanceOf(poolManager.withdrawalManager());

        assert_pool_invariant_B(sumBalanceOfAssets);
        assert_pool_invariant_G(sumBalanceOf);
    }

    /**************************************************************************************************************************************/
    /*** Pool Manager Invariants                                                                                                        ***/
    /**************************************************************************************************************************************/

    function statefulFuzz_basicInvariants_poolManager_A_totalAssetsEqCashPlusAUM() external useCurrentTimestamp {
        assert_poolManager_invariant_A();
    }

    function statefulFuzz_basicInvariants_poolManager_B() external useCurrentTimestamp {
        assert_poolManager_invariant_B();
    }

    /**************************************************************************************************************************************/
    /*** Withdrawal Manager Invariants                                                                                                  ***/
    /**************************************************************************************************************************************/

    function statefulFuzz_basicInvariants_withdrawalManager_A_F_G_H_I_J_K_L() external useCurrentTimestamp {
        if (pool.totalSupply() == 0 || pool.totalAssets() == 0) return;

        uint256 sumLockedShares;

        for (uint256 i; i < lps.length; ++i) {
            address lp = lps[i];

            sumLockedShares += cyclicalWM.lockedShares(lp);

            uint256 totalRequestedLiquidity =
                cyclicalWM.totalCycleShares(cyclicalWM.exitCycleId(lp)) * (pool.totalAssets() - pool.unrealizedLosses()) /
                pool.totalSupply();

            (
                uint256 shares,
                uint256 assets,
                bool partialLiquidity
            ) = cyclicalWM.getRedeemableAmounts(cyclicalWM.lockedShares(lp), lp);

            assert_withdrawalManager_invariant_F(shares);
            assert_withdrawalManager_invariant_G(lp, shares);
            assert_withdrawalManager_invariant_H(lp, shares);

            assert_withdrawalManager_invariant_I(assets);
            assert_withdrawalManager_invariant_J(assets, totalRequestedLiquidity);
            assert_withdrawalManager_invariant_K(lp, assets);

            assert_withdrawalManager_invariant_L(partialLiquidity, totalRequestedLiquidity);
        }

        assertTrue(pool.balanceOf(address(cyclicalWM)) == sumLockedShares);
    }

    function statefulFuzz_basicInvariants_withdrawalManager_B() external useCurrentTimestamp { assert_withdrawalManager_invariant_B(); }
    function statefulFuzz_basicInvariants_withdrawalManager_C() external useCurrentTimestamp { assert_withdrawalManager_invariant_C(); }
    function statefulFuzz_basicInvariants_withdrawalManager_D() external useCurrentTimestamp { assert_withdrawalManager_invariant_D(); }
    function statefulFuzz_basicInvariants_withdrawalManager_E() external useCurrentTimestamp { assert_withdrawalManager_invariant_E(); }
    function statefulFuzz_basicInvariants_withdrawalManager_M() external useCurrentTimestamp { assert_withdrawalManager_invariant_M(); }
    function statefulFuzz_basicInvariants_withdrawalManager_N() external useCurrentTimestamp { assert_withdrawalManager_invariant_N(); }

}
