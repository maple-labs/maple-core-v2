// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IFixedTermLoanManager, ILoanLike } from "../../contracts/interfaces/Interfaces.sol";

import { console } from "../../contracts/Runner.sol";

import { CyclicalWithdrawalHandler } from "./handlers/CyclicalWithdrawalHandler.sol";
import { DepositHandler }            from "./handlers/DepositHandler.sol";
import { DistributionHandler }       from "./handlers/DistributionHandler.sol";
import { FixedTermLoanHandler }      from "./handlers/FixedTermLoanHandler.sol";
import { OpenTermLoanHandler }       from "./handlers/OpenTermLoanHandler.sol";
import { TransferHandler }           from "./handlers/TransferHandler.sol";
import { QueueWithdrawalHandler }    from "./handlers/QueueWithdrawalHandler.sol";

import { BaseInvariants } from "./BaseInvariants.t.sol";

contract LiquidatingInvariants is BaseInvariants {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    uint256 constant NUM_BORROWERS = 5;
    uint256 constant NUM_OT_LOANS  = 10;
    uint256 constant NUM_LPS       = 10;

    /**************************************************************************************************************************************/
    /*** Setup Function                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function setUp() public override {
        _createAccounts();
        _createGlobals();
        _createAssets();
        _configureGlobals();
        _createFactories();
        _createPoolWithQueue();
        _configurePool();

        openPool(address(poolManager));

        for (uint256 i; i < NUM_LPS; i++) {
            address lp = makeAddr(string(abi.encode("lp", i)));

            lps.push(lp);
            allowLender(address(poolManager), lp);
        }

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.005e6,  // 10k after 1m seconds
            platformManagementFeeRate:  0.08e6
        });

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
            numBorrowers_:      NUM_BORROWERS
        });

        otlHandler = new OpenTermLoanHandler({
            loanFactory_:       address(openTermLoanFactory),
            liquidatorFactory_: address(liquidatorFactory),
            poolManager_:       address(poolManager),
            refinancer_:        address(openTermRefinancer),
            maxBorrowers_:      NUM_BORROWERS,
            maxLoans_:          NUM_OT_LOANS
        });

        depositHandler.setSelectorWeight("deposit(uint256)", 7_500);
        depositHandler.setSelectorWeight("mint(uint256)",    2_500);

        transferHandler.setSelectorWeight("transfer(uint256)", 10_000);

        queueWithdrawalHandler.setSelectorWeight("processRedemptions(uint256)",      2_700);
        queueWithdrawalHandler.setSelectorWeight("redeem(uint256)",                  1_000);
        queueWithdrawalHandler.setSelectorWeight("removeRequest(uint256)",           1_000);
        queueWithdrawalHandler.setSelectorWeight("removeShares(uint256)",            500);
        queueWithdrawalHandler.setSelectorWeight("removeSharesById(uint256)",        500);
        queueWithdrawalHandler.setSelectorWeight("requestRedeem(uint256)",           3_300);
        queueWithdrawalHandler.setSelectorWeight("setManualWithdrawal(uint256)",     1_000);

        ftlHandler.setSelectorWeight("createLoanAndFund(uint256)",           1_000);
        ftlHandler.setSelectorWeight("makePayment(uint256)",                 0);
        ftlHandler.setSelectorWeight("impairmentMakePayment(uint256)",       1_000);
        ftlHandler.setSelectorWeight("defaultMakePayment(uint256)",          2_000);
        ftlHandler.setSelectorWeight("impairLoan(uint256)",                  1_500);
        ftlHandler.setSelectorWeight("triggerDefault(uint256)",              2_000);
        ftlHandler.setSelectorWeight("finishCollateralLiquidation(uint256)", 1_500);
        ftlHandler.setSelectorWeight("refinance(uint256)",                   1_000);

        otlHandler.setSelectorWeight("callLoan(uint256)",             1_000);
        otlHandler.setSelectorWeight("fundLoan(uint256)",             1_000);
        otlHandler.setSelectorWeight("impairLoan(uint256)",           1_000);
        otlHandler.setSelectorWeight("makePayment(uint256)",          2_500);
        otlHandler.setSelectorWeight("refinance(uint256)",            1_000);
        otlHandler.setSelectorWeight("removeLoanCall(uint256)",       1_000);
        otlHandler.setSelectorWeight("removeLoanImpairment(uint256)", 1_000);
        otlHandler.setSelectorWeight("triggerDefault(uint256)",       1_500);

        address[] memory targetContracts = new address[](5);
        targetContracts[0] = address(transferHandler);
        targetContracts[1] = address(depositHandler);
        targetContracts[2] = address(queueWithdrawalHandler);
        targetContracts[3] = address(ftlHandler);
        targetContracts[4] = address(otlHandler);

        uint256[] memory weightsDistributorHandler = new uint256[](5);
        weightsDistributorHandler[0] = 10;
        weightsDistributorHandler[1] = 10;
        weightsDistributorHandler[2] = 10;
        weightsDistributorHandler[3] = 35;
        weightsDistributorHandler[4] = 35;

        address distributionHandler = address(new DistributionHandler(targetContracts, weightsDistributorHandler));

        targetContract(distributionHandler);
    }

    /**************************************************************************************************************************************/
    /*** Invariants Removed                                                                                                             ***/
    /***************************************************************************************************************************************

    * Loan Manager
        * Invariant G: unrealizedLosses == 0
            NOTE: triggerDefault() with collateral that needs liquidating then unrealizedLosses will be > 0
        * Invariant L: paymentInfo.refinanceInterest == loan's netRefinanceInterest.
            NOTE: If a loan is refinanced then defaulted, the refinanceInterest will be > 0 while paymentInfo will be zeroed.
        * Invariant M: paymentDueDate[payment] = loan.paymentDueDate()
            NOTE: Payments mapping state on Loan Manager is out of date during impairment
        * Invariant N: startDate[payment] <= loan.paymentDueDate() - loan.paymentInterval()
            NOTE: Payments mapping state on Loan Manager is out of date during impairment
    * Pool
        * Invariant C: totalAssets >= totalSupply (in non-liquidating scenario)
        * Invariant F: balanceOfAssets[user] >= balanceOf[user]
        * Invariant H: convertToExitShares == convertToShares
            NOTE: triggerDefault() with collateral that needs liquidating then unrealizedLosses will be > 0 hence a different exchange rate

    ***************************************************************************************************************************************/

    function statefulFuzz_liquidatingInvariants() external {
        assert_pool_invariants_A_B_D_E_G_I_J_K();
        assert_pool_manager_invariants();

        assert_ftl_invariants();
        assert_ftlm_invariants_A_B_C_D_E_F_H_I_J_K_L();

        assert_otl_invariants();
        assert_otlm_invariants_B_C_F_H_I_J_L_M();

        assert_wm_queue_invariants(address(queueWM), lps);
    }

}
