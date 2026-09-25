// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { DepositHandler } from "./handlers/DepositHandler.sol";
import { DistributionHandler } from "./handlers/DistributionHandler.sol";
import { OpenTermLoanHandler } from "./handlers/OpenTermLoanHandler.sol";
import { TransferHandler } from "./handlers/TransferHandler.sol";
import { WithdrawalHandler } from "./handlers/WithdrawalHandler.sol";

import { BaseInvariants } from "./BaseInvariants.t.sol";

contract LosslessLoanInvariants is BaseInvariants {

    /**************************************************************************************************************************************/
    /*** Constants                                                                                                                      ***/
    /**************************************************************************************************************************************/

    uint256 constant NUM_BORROWERS = 5;
    uint256 constant NUM_OT_LOANS  = 10;
    uint256 constant NUM_LPS       = 2;

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
            platformServiceFeeRate:     0.005e6,
            platformManagementFeeRate:  0.08e6
        });

        depositHandler    = new DepositHandler("depositHandler", pools, lps);
        transferHandler   = new TransferHandler("transferHandler", pools, lps);
        withdrawalHandler = new WithdrawalHandler("withdrawalHandler", pools, lps);

        address[] memory borrowers_ = new address[](NUM_BORROWERS);

        for (uint256 i; i < NUM_BORROWERS; i++) {
            borrowers_[i] = makeAddr(string(abi.encode("borrower", i)));
        }

        otlHandler = new OpenTermLoanHandler({
            handlerName_:  "otlHandler",
            loanFactory_:  address(openTermLoanFactory),
            refinancer_:   openTermRefinancer,
            poolManagers_: poolManagers,
            borrowers_:    borrowers_,
            maxLoans_:     NUM_OT_LOANS
        });

        depositHandler.addAction("deposit(uint256)", 7_500);
        depositHandler.addAction("mint(uint256)", 2_500);

        transferHandler.addAction("transfer(uint256)", 10_000);

        withdrawalHandler.addAction("processRedemptions(uint256)", 2_700);
        withdrawalHandler.addAction("processEmptyRedemptions(uint256)", 300);
        withdrawalHandler.addAction("redeem(uint256)", 1_000);
        withdrawalHandler.addAction("removeRequest(uint256)", 1_000);
        withdrawalHandler.addAction("removeShares(uint256)", 500);
        withdrawalHandler.addAction("removeSharesById(uint256)", 500);
        withdrawalHandler.addAction("requestRedeem(uint256)", 3_000);
        withdrawalHandler.addAction("setManualWithdrawal(uint256)", 1_000);

        otlHandler.addAction("callLoan(uint256)", 1_000);
        otlHandler.addAction("fundLoan(uint256)", 3_000);
        otlHandler.addAction("makePayment(uint256)", 4_000);
        otlHandler.addAction("refinance(uint256)", 1_000);
        otlHandler.addAction("removeLoanCall(uint256)", 1_000);

        address[] memory contracts = new address[](4);
        uint256[] memory weights   = new uint256[](4);

        contracts[0] = address(transferHandler);
        contracts[1] = address(depositHandler);
        contracts[2] = address(withdrawalHandler);
        contracts[3] = address(otlHandler);

        weights[0] = 10;
        weights[1] = 10;
        weights[2] = 10;
        weights[3] = 70;

        address distributionHandler = address(new DistributionHandler(contracts, weights));

        targetContract(distributionHandler);
    }

    function statefulFuzz_losslessLoanInvariants() external {
        assert_pool_lossless_invariants(address(pool));
        assert_pool_manager_invariants(address(poolManager));
        assert_wm_invariants(address(queueWM), lps);

        address[] memory loans = _getActiveLoans();

        assert_otl_invariants(loans);
        assert_otlm_invariants(address(otlHandler.loanManagers(0)), loans);
    }

}
