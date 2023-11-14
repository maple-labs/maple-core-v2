// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IOpenTermLoan } from "../../contracts/interfaces/Interfaces.sol";

import { CyclicalWithdrawalHandler } from "./handlers/CyclicalWithdrawalHandler.sol";
import { DepositHandler }            from "./handlers/DepositHandler.sol";
import { DistributionHandler }       from "./handlers/DistributionHandler.sol";
import { GlobalsHandler }            from "./handlers/GlobalsHandler.sol";
import { OpenTermLoanHandler }       from "./handlers/OpenTermLoanHandler.sol";
import { TransferHandler }           from "./handlers/TransferHandler.sol";

import { BaseInvariants } from "./BaseInvariants.t.sol";

// TODO: Add Globals Handler
contract OpenTermInvariants is BaseInvariants {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    uint256 constant NUM_LPS       = 10;
    uint256 constant NUM_OT_LOANS  = 10;
    uint256 constant NUM_BORROWERS = 5;

    /**************************************************************************************************************************************/
    /*** Setup Function                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function setUp() public override {
        super.setUp();

        currentTimestamp = block.timestamp;

        for (uint i; i < NUM_LPS; i++) {
            address lp = makeAddr(string(abi.encode("lp", i)));

            lps.push(lp);
            allowLender(address(poolManager), lp);
        }

        vm.startPrank(governor);
        globals.setPlatformServiceFeeRate(address(poolManager),    0.025e6);
        globals.setPlatformManagementFeeRate(address(poolManager), 0.08e6);
        vm.stopPrank();

        vm.prank(poolDelegate);
        poolManager.setDelegateManagementFeeRate(0.02e6);

        depositHandler            = new DepositHandler(address(pool), lps);
        transferHandler           = new TransferHandler(address(pool), lps);
        cyclicalWithdrawalHandler = new CyclicalWithdrawalHandler(address(pool), lps);

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

        cyclicalWithdrawalHandler.setSelectorWeight("redeem(uint256)",        3_300);
        cyclicalWithdrawalHandler.setSelectorWeight("removeShares(uint256)",  3_300);
        cyclicalWithdrawalHandler.setSelectorWeight("requestRedeem(uint256)", 3_400);

        otlHandler.setSelectorWeight("callLoan(uint256)",             500);
        otlHandler.setSelectorWeight("fundLoan(uint256)",             1_500);
        otlHandler.setSelectorWeight("impairLoan(uint256)",           0);
        otlHandler.setSelectorWeight("makePayment(uint256)",          2_500);
        otlHandler.setSelectorWeight("refinance(uint256)",            1_000);
        otlHandler.setSelectorWeight("removeLoanCall(uint256)",       500);
        otlHandler.setSelectorWeight("removeLoanImpairment(uint256)", 500);
        otlHandler.setSelectorWeight("triggerDefault(uint256)",       1_000);
        otlHandler.setSelectorWeight("warp(uint256)",                 2_500);

        address[] memory targetContracts = new address[](4);
        targetContracts[0] = address(transferHandler);
        targetContracts[1] = address(depositHandler);
        targetContracts[2] = address(cyclicalWithdrawalHandler);
        targetContracts[3] = address(otlHandler);

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

    function statefulFuzz_openTermLoan_A_B_C_D_E_F_G_H_I_openTermLoanManager_A_B_C_D_F_H_I_J() external useCurrentTimestamp {
        address[] memory loans = _getActiveLoans();

        address loanManager = address(otlHandler.loanManager());

        assert_otlm_invariant_A(loanManager, loans);
        assert_otlm_invariant_B(loanManager, loans);
        assert_otlm_invariant_C(loanManager, loans);
        assert_otlm_invariant_D(loanManager, loans);
        assert_otlm_invariant_F(loanManager, loans);
        // assert_otlm_invariant_K(loanManager, loans);  // TODO: Explore why this fails

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

            assert_otlm_invariant_H(loan, loanManager);
            assert_otlm_invariant_I(loan, loanManager);
            assert_otlm_invariant_J(loan, loanManager);
        }
    }

    /**************************************************************************************************************************************/
    /*** Open Term Loan Manager Non-Iterative Invariants                                                                                ***/
    /**************************************************************************************************************************************/

    function statefulFuzz_openTermLoanManager_E() external useCurrentTimestamp {
        assert_otlm_invariant_E(address(otlHandler.loanManager()));
    }

    function statefulFuzz_openTermLoanManager_G() external useCurrentTimestamp {
        assert_otlm_invariant_G(address(otlHandler.loanManager()));
    }

}
