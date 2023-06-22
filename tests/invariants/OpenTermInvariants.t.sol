// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IOpenTermLoan } from "../../contracts/interfaces/Interfaces.sol";

import { DistributionHandler } from "./handlers/DistributionHandler.sol";
import { GlobalsHandler }      from "./handlers/GlobalsHandler.sol";
import { LpHandler }           from "./handlers/LpHandler.sol";
import { OpenTermLoanHandler } from "./handlers/OpenTermLoanHandler.sol";

import { BaseInvariants } from "./BaseInvariants.t.sol";

contract OpenTermInvariants is BaseInvariants {

    uint256 constant NUM_LPS       = 10;
    uint256 constant NUM_OT_LOANS  = 10;
    uint256 constant NUM_BORROWERS = 5;

    function setUp() public override {
        super.setUp();

        // TODO: Check if all timestamp accounting can be removed.
        currentTimestamp = block.timestamp;

        vm.startPrank(governor);
        globals.setPlatformServiceFeeRate(address(poolManager),    0.025e6);
        globals.setPlatformManagementFeeRate(address(poolManager), 0.08e6);
        vm.stopPrank();

        vm.prank(poolDelegate);
        poolManager.setDelegateManagementFeeRate(0.02e6);

        lpHandler = new LpHandler(address(pool), address(this), NUM_LPS);

        otlHandler = new OpenTermLoanHandler({
            loanFactory_:       address(openTermLoanFactory),
            liquidatorFactory_: address(liquidatorFactory),
            poolManager_:       address(poolManager),
            refinancer_:        address(openTermRefinancer),
            maxBorrowers_:      NUM_BORROWERS,
            maxLoans_:          NUM_OT_LOANS
        });

        globalsHandler = new GlobalsHandler({
            globals_:     address(globals),
            poolManager_: address(poolManager)
        });

        lpHandler.setSelectorWeight("deposit(uint256)",       25);
        lpHandler.setSelectorWeight("mint(uint256)",          15);
        lpHandler.setSelectorWeight("redeem(uint256)",        15);
        lpHandler.setSelectorWeight("removeShares(uint256)",  15);
        lpHandler.setSelectorWeight("requestRedeem(uint256)", 15);
        lpHandler.setSelectorWeight("transfer(uint256)",      15);

        otlHandler.setSelectorWeight("callLoan(uint256)",             5);
        otlHandler.setSelectorWeight("fundLoan(uint256)",             15);
        otlHandler.setSelectorWeight("impairLoan(uint256)",           5);
        otlHandler.setSelectorWeight("makePayment(uint256)",          20);
        otlHandler.setSelectorWeight("refinance(uint256)",            10);
        otlHandler.setSelectorWeight("removeLoanCall(uint256)",       5);
        otlHandler.setSelectorWeight("removeLoanImpairment(uint256)", 5);
        otlHandler.setSelectorWeight("triggerDefault(uint256)",       10);
        otlHandler.setSelectorWeight("warp(uint256)",                 25);

        globalsHandler.setSelectorWeight("setMaxCoverLiquidationPercent(uint256)", 20);
        globalsHandler.setSelectorWeight("setMinCoverAmount(uint256)",             20);
        globalsHandler.setSelectorWeight("setPlatformManagementFeeRate(uint256)",  20);
        globalsHandler.setSelectorWeight("setPlatformOriginationFeeRate(uint256)", 20);
        globalsHandler.setSelectorWeight("setPlatformServiceFeeRate(uint256)",     20);

        uint256[] memory weightsDistributorHandler = new uint256[](3);
        weightsDistributorHandler[0] = 20;  // lpHandler()
        weightsDistributorHandler[1] = 70;  // OTLHandler()
        weightsDistributorHandler[2] = 10;  // globalsHandler()

        address[] memory targetContracts = new address[](3);
        targetContracts[0] = address(lpHandler);
        targetContracts[1] = address(otlHandler);
        targetContracts[2] = address(globalsHandler);

        address distributionHandler = address(new DistributionHandler(targetContracts, weightsDistributorHandler));

        targetContract(distributionHandler);
    }

    /**************************************************************************************************************************************/
    /*** Loan Iteration Invariants (Loan and LoanManager)                                                                               ***/
    /**************************************************************************************************************************************/

    function invariant_openTermLoan_A_B_C_D_E_F_G_H_I_openTermLoanManager_A_B_C_D_F_H_I_J() external useCurrentTimestamp {
        IOpenTermLoan[] memory loans = _getActiveLoans();

        assert_otlm_invariant_A(address(otlHandler.loanManager()), loans);
        assert_otlm_invariant_B(address(otlHandler.loanManager()), loans);
        assert_otlm_invariant_C(address(otlHandler.loanManager()), loans);
        assert_otlm_invariant_D(address(otlHandler.loanManager()), loans);
        assert_otlm_invariant_F(address(otlHandler.loanManager()), loans);
        assert_otlm_invariant_K(address(otlHandler.loanManager()), loans);

        for (uint256 i; i < loans.length; ++i) {
            assert_otl_invariant_A(address(loans[i]));
            assert_otl_invariant_B(address(loans[i]));
            assert_otl_invariant_C(address(loans[i]));
            assert_otl_invariant_D(address(loans[i]));
            assert_otl_invariant_E(address(loans[i]));
            assert_otl_invariant_F(address(loans[i]));
            assert_otl_invariant_G(address(loans[i]));
            assert_otl_invariant_H(address(loans[i]));
            assert_otl_invariant_I(address(loans[i]));

            assert_otlm_invariant_H(address(loans[i]), address(otlHandler.loanManager()));
            assert_otlm_invariant_I(address(loans[i]), address(otlHandler.loanManager()));
            assert_otlm_invariant_J(address(loans[i]), address(otlHandler.loanManager()));
        }
    }

    /**************************************************************************************************************************************/
    /*** Open Term Loan Manager Non-Iterative Invariants                                                                                ***/
    /**************************************************************************************************************************************/

    function invariant_openTermLoanManager_E() external useCurrentTimestamp {
        assert_otlm_invariant_E(address(otlHandler.loanManager()));
    }

    function invariant_openTermLoanManager_G() external useCurrentTimestamp {
        assert_otlm_invariant_G(address(otlHandler.loanManager()));
    }

}
