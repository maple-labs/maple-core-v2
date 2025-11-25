// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IFixedTermLoanManager, ILoanLike } from "../../../contracts/interfaces/Interfaces.sol";

import { CyclicalWithdrawalHandler } from "../handlers/CyclicalWithdrawalHandler.sol";
import { DepositHandler }            from "../handlers/DepositHandler.sol";
import { DistributionHandler }       from "../handlers/DistributionHandler.sol";
import { FixedTermLoanHandler }      from "../handlers/FixedTermLoanHandler.sol";
import { TransferHandler }           from "../handlers/TransferHandler.sol";

import { BaseInvariants } from "../BaseInvariants.t.sol";

contract ImpairInvariants is BaseInvariants {

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

        for (uint256 i; i < NUM_LPS; i++) {
            lps.push(makeAddr(string(abi.encode("lp", i))));
        }

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
            numBorrowers_:      NUM_BORROWERS
        });

        depositHandler.setSelectorWeight("deposit(uint256)", 7_500);
        depositHandler.setSelectorWeight("mint(uint256)",    2_500);

        transferHandler.setSelectorWeight("transfer(uint256)", 10_000);

        cyclicalWithdrawalHandler.setSelectorWeight("redeem(uint256)",        3_300);
        cyclicalWithdrawalHandler.setSelectorWeight("removeShares(uint256)",  3_300);
        cyclicalWithdrawalHandler.setSelectorWeight("requestRedeem(uint256)", 3_400);

        ftlHandler.setSelectorWeight("createLoanAndFund(uint256)",           3_000);
        ftlHandler.setSelectorWeight("makePayment(uint256)",                 0);
        ftlHandler.setSelectorWeight("impairmentMakePayment(uint256)",       3_500);
        ftlHandler.setSelectorWeight("defaultMakePayment(uint256)",          0);
        ftlHandler.setSelectorWeight("impairLoan(uint256)",                  2_000);
        ftlHandler.setSelectorWeight("triggerDefault(uint256)",              0);
        ftlHandler.setSelectorWeight("finishCollateralLiquidation(uint256)", 0);
        ftlHandler.setSelectorWeight("refinance(uint256)",                   1_500);

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
    /*** Invariants Removed                                                                                                             ***/
    /***************************************************************************************************************************************

     * Loan Manager
        * Invariant G: unrealizedLosses == 0
            NOTE: By definition impairment increases unrealizedLosses
        * Invariant M: paymentDueDate[payment] = loan.paymentDueDate()
            NOTE: Payments mapping state on Loan Manager is out of date during impairment
        * Invariant N: startDate[payment] <= loan.paymentDueDate() - loan.paymentInterval()
            NOTE: Payments mapping state on Loan Manager is out of date during impairment

     * Pool
        * Invariant C: totalAssets >= totalSupply (in non-liquidating scenario)
        * Invariant H: convertToExitShares == convertToShares
            NOTE: Not applicable as unrealized losses changes exchange rate

    ***************************************************************************************************************************************/

    function statefulFuzz_impairInvariants() external {
        assert_ftl_invariants();
        assert_ftlm_invariants_A_B_C_D_E_F_H_I_J_K_L();

        assert_pool_invariants_A_B_D_E_F_G_I_J_K();
        assert_pool_manager_invariants();

        assert_wm_cyclical_invariants();
    }

}
