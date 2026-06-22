// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { DepositHandler }            from "./handlers/DepositHandler.sol";
import { DistributionHandler }       from "./handlers/DistributionHandler.sol";
import { OpenTermLoanHandler }       from "./handlers/OpenTermLoanHandler.sol";
import { TransferHandler }           from "./handlers/TransferHandler.sol";
import { QueueWithdrawalHandler }    from "./handlers/QueueWithdrawalHandler.sol";

import { BaseInvariants } from "./BaseInvariants.t.sol";

contract NonDefaultingInvariants is BaseInvariants {

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
        _setupPoolWithQueueWM();

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

        otlHandler.setSelectorWeight("callLoan(uint256)",             1_000);
        otlHandler.setSelectorWeight("fundLoan(uint256)",             2_000);
        otlHandler.setSelectorWeight("impairLoan(uint256)",           0);
        otlHandler.setSelectorWeight("makePayment(uint256)",          2_500);
        otlHandler.setSelectorWeight("refinance(uint256)",            1_500);
        otlHandler.setSelectorWeight("removeLoanCall(uint256)",       1_500);
        otlHandler.setSelectorWeight("removeLoanImpairment(uint256)", 1_500);
        otlHandler.setSelectorWeight("triggerDefault(uint256)",       0);

        address[] memory targetContracts = new address[](4);
        targetContracts[0] = address(transferHandler);
        targetContracts[1] = address(depositHandler);
        targetContracts[2] = address(queueWithdrawalHandler);
        targetContracts[3] = address(otlHandler);

        uint256[] memory weightsDistributorHandler = new uint256[](4);
        weightsDistributorHandler[0] = 10;
        weightsDistributorHandler[1] = 10;
        weightsDistributorHandler[2] = 10;
        weightsDistributorHandler[3] = 70;

        address distributionHandler = address(new DistributionHandler(targetContracts, weightsDistributorHandler));

        targetContract(distributionHandler);
    }

    function statefulFuzz_nonDefaultingInvariants() external {
        assert_pool_invariants_all();
        assert_pool_manager_invariants();

        assert_otl_invariants();
        assert_otlm_invariants_A_B_C_D_E_F_G_H_I_J_L_M();

        assert_wm_queue_invariants(address(queueWM), lps);
    }

}
