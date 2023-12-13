// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IFixedTermLoanManager, ILoanLike } from "../../contracts/interfaces/Interfaces.sol";

import { DepositHandler }         from "./handlers/DepositHandler.sol";
import { DistributionHandler }    from "./handlers/DistributionHandler.sol";
import { FixedTermLoanHandler }   from "./handlers/FixedTermLoanHandler.sol";
import { QueueWithdrawalHandler } from "./handlers/QueueWithdrawalHandler.sol";
import { TransferHandler }        from "./handlers/TransferHandler.sol";

import { BaseInvariants } from "./BaseInvariants.t.sol";

contract WithdrawalManagerQueueInvariants is BaseInvariants {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    uint256 constant NUM_BORROWERS = 5;
    uint256 constant NUM_LPS       = 10;

    /**************************************************************************************************************************************/
    /*** Setup Function                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function setUp() public override {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createPoolWithQueue();
        _configurePool();

        openPool(address(poolManager));

        currentTimestamp = block.timestamp;

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.005e6,  // 10k after 1m seconds
            platformManagementFeeRate:  0.08e6
        });

        for (uint256 i; i < NUM_LPS; i++) {
            address lp = makeAddr(string(abi.encode("lp", i)));

            lps.push(lp);
            allowLender(address(poolManager), lp);
        }

        depositHandler         = new DepositHandler(address(pool), lps);
        transferHandler        = new TransferHandler(address(pool), lps);
        queueWithdrawalHandler = new QueueWithdrawalHandler(address(pool), lps);

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

        queueWithdrawalHandler.setSelectorWeight("processRedemptions(uint256)",  3_000);
        queueWithdrawalHandler.setSelectorWeight("redeem(uint256)",              1_000);
        queueWithdrawalHandler.setSelectorWeight("removeRequest(uint256)",       1_000);
        queueWithdrawalHandler.setSelectorWeight("removeShares(uint256)",        1_000);
        queueWithdrawalHandler.setSelectorWeight("requestRedeem(uint256)",       3_000);
        queueWithdrawalHandler.setSelectorWeight("setManualWithdrawal(uint256)", 1_000);

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
        targetContracts[2] = address(queueWithdrawalHandler);
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

    function statefulFuzz_withdrawalManagerQueueInvariants_fixedTermLoan_A_B_C_fixedTermLoanManager_L_M_N() external useCurrentTimestamp {
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

    function statefulFuzz_withdrawalManagerQueueInvariants_fixedTermLoanManager_A() external useCurrentTimestamp {
        assert_ftlm_invariant_A(poolManager.loanManagerList(0));

    }
    function statefulFuzz_withdrawalManagerQueueInvariants_fixedTermLoanManager_B() external useCurrentTimestamp {
        assert_ftlm_invariant_B(poolManager.loanManagerList(0));
    }

    function statefulFuzz_withdrawalManagerQueueInvariants_fixedTermLoanManager_C() external useCurrentTimestamp {
        assert_ftlm_invariant_C(poolManager.loanManagerList(0));
    }

    function statefulFuzz_withdrawalManagerQueueInvariants_fixedTermLoanManager_D() external useCurrentTimestamp {
        assert_ftlm_invariant_D(poolManager.loanManagerList(0));
    }

    function statefulFuzz_withdrawalManagerQueueInvariants_fixedTermLoanManager_E() external useCurrentTimestamp {
        assert_ftlm_invariant_E(poolManager.loanManagerList(0));
    }

    function statefulFuzz_withdrawalManagerQueueInvariants_fixedTermLoanManager_F() external useCurrentTimestamp {
        assert_ftlm_invariant_F(poolManager.loanManagerList(0));
    }

    function statefulFuzz_withdrawalManagerQueueInvariants_fixedTermLoanManager_G() external useCurrentTimestamp {
        assert_ftlm_invariant_G(poolManager.loanManagerList(0));
    }

    function statefulFuzz_withdrawalManagerQueueInvariants_fixedTermLoanManager_H() external useCurrentTimestamp {
        assert_ftlm_invariant_H(poolManager.loanManagerList(0));
    }

    function statefulFuzz_withdrawalManagerQueueInvariants_fixedTermLoanManager_I() external useCurrentTimestamp {
        assert_ftlm_invariant_I(poolManager.loanManagerList(0));
    }

    function statefulFuzz_withdrawalManagerQueueInvariants_fixedTermLoanManager_J() external useCurrentTimestamp {
        assert_ftlm_invariant_J(poolManager.loanManagerList(0));
    }

    function statefulFuzz_withdrawalManagerQueueInvariants_fixedTermLoanManager_K() external useCurrentTimestamp {
        assert_ftlm_invariant_K(poolManager.loanManagerList(0));
    }

    /**************************************************************************************************************************************/
    /*** Pool Invariants                                                                                                                ***/
    /**************************************************************************************************************************************/

    function statefulFuzz_withdrawalManagerQueueInvariants_pool_A() external useCurrentTimestamp { assert_pool_invariant_A(); }
    function statefulFuzz_withdrawalManagerQueueInvariants_pool_C() external useCurrentTimestamp { assert_pool_invariant_C(); }
    function statefulFuzz_withdrawalManagerQueueInvariants_pool_D() external useCurrentTimestamp { assert_pool_invariant_D(); }
    function statefulFuzz_withdrawalManagerQueueInvariants_pool_E() external useCurrentTimestamp { assert_pool_invariant_E(); }
    function statefulFuzz_withdrawalManagerQueueInvariants_pool_H() external useCurrentTimestamp { assert_pool_invariant_H(); }
    function statefulFuzz_withdrawalManagerQueueInvariants_pool_I() external useCurrentTimestamp { assert_pool_invariant_I(); }
    function statefulFuzz_withdrawalManagerQueueInvariants_pool_J() external useCurrentTimestamp { assert_pool_invariant_J(); }
    function statefulFuzz_withdrawalManagerQueueInvariants_pool_K() external useCurrentTimestamp { assert_pool_invariant_K(); }

    function statefulFuzz_withdrawalManagerQueueInvariants_pool_B_F_G() external useCurrentTimestamp {
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

    function statefulFuzz_withdrawalManagerQueueInvariants_poolManager_A_totalAssetsEqCashPlusAUM() external useCurrentTimestamp {
        assert_poolManager_invariant_A();
    }

    function statefulFuzz_withdrawalManagerQueueInvariants_poolManager_B() external useCurrentTimestamp {
        assert_poolManager_invariant_B();
    }

    /**************************************************************************************************************************************/
    /*** Withdrawal Manager Invariants                                                                                                  ***/
    /**************************************************************************************************************************************/

    function statefulFuzz_withdrawalManagerQueueInvariants_wmq_invariant_A_C_G_H() external useCurrentTimestamp {
        assert_wmq_invariant_A(address(queueWM), lps);
        assert_wmq_invariant_C(address(queueWM), lps);
        assert_wmq_invariant_G(address(queueWM), lps);
        assert_wmq_invariant_H(address(queueWM), lps);
    }

    function statefulFuzz_withdrawalManagerQueueInvariants_wmq_invariant_B_D_E_F_I() external useCurrentTimestamp {
        assert_wmq_invariant_B(address(queueWM));
        assert_wmq_invariant_D(address(queueWM));
        assert_wmq_invariant_E(address(queueWM));
        assert_wmq_invariant_F(address(queueWM));
        assert_wmq_invariant_I(address(queueWM));
    }

}
