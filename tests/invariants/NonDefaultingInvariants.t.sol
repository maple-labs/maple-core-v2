// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { DepositHandler }      from "./handlers/DepositHandler.sol";
import { DistributionHandler } from "./handlers/DistributionHandler.sol";
import { OpenTermLoanHandler } from "./handlers/OpenTermLoanHandler.sol";
import { TransferHandler }     from "./handlers/TransferHandler.sol";
import { WithdrawalHandler }   from "./handlers/WithdrawalHandler.sol";

import { BaseInvariants } from "./BaseInvariants.t.sol";

contract NonDefaultingInvariants is BaseInvariants {

    /**************************************************************************************************************************************/
    /*** Constants                                                                                                                      ***/
    /**************************************************************************************************************************************/

    uint256 constant NUM_BORROWERS = 5;
    uint256 constant NUM_OT_LOANS  = 10;
    uint256 constant NUM_LPS       = 10;

    /**************************************************************************************************************************************/
    /*** Setup Function                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function setUp() public override {
        _setUpOpenPool();

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

        depositHandler    = new DepositHandler("depositHandler", pools, lps);
        transferHandler   = new TransferHandler("transferHandler", pools, lps);
        withdrawalHandler = new WithdrawalHandler("withdrawalHandler", pools, lps);

        otlHandler = new OpenTermLoanHandler({
            handlerName_:       "otlHandler",
            loanFactory_:       address(openTermLoanFactory),
            liquidatorFactory_: address(liquidatorFactory),
            poolManager_:       address(poolManager),
            refinancer_:        openTermRefinancer,
            maxBorrowers_:      NUM_BORROWERS,
            maxLoans_:          NUM_OT_LOANS
        });

        depositHandler.addAction("deposit(uint256)", 7_500);
        depositHandler.addAction("mint(uint256)",    2_500);

        transferHandler.addAction("transfer(uint256)", 10_000);

        withdrawalHandler.addAction("processRedemptions(uint256)",      2_700);
        withdrawalHandler.addAction("processEmptyRedemptions(uint256)", 300);
        withdrawalHandler.addAction("redeem(uint256)",                  1_000);
        withdrawalHandler.addAction("removeRequest(uint256)",           1_000);
        withdrawalHandler.addAction("removeShares(uint256)",            500);
        withdrawalHandler.addAction("removeSharesById(uint256)",        500);
        withdrawalHandler.addAction("requestRedeem(uint256)",           3_000);
        withdrawalHandler.addAction("setManualWithdrawal(uint256)",     1_000);

        otlHandler.addAction("callLoan(uint256)",       1_000);
        otlHandler.addAction("fundLoan(uint256)",       3_000);
        otlHandler.addAction("makePayment(uint256)",    4_000);
        otlHandler.addAction("refinance(uint256)",      1_000);
        otlHandler.addAction("removeLoanCall(uint256)", 1_000);

        address[] memory targetContracts = new address[](4);
        targetContracts[0] = address(transferHandler);
        targetContracts[1] = address(depositHandler);
        targetContracts[2] = address(withdrawalHandler);
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
        assert_pool_invariants_all(address(pool));
        assert_pool_manager_invariants(address(poolManager));

        address[] memory loans = _getActiveLoans();

        assert_otl_invariants(loans);
        assert_otlm_invariants_A_B_C_D_E_F_G_H_I_J_K_L_M(address(otlHandler.loanManager()), loans);

        assert_wm_queue_invariants(address(queueWM), lps);
    }

}
