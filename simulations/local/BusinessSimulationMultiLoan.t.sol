// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address } from "../../modules/contract-test-utils/contracts/test.sol";

import { Refinancer } from "../../modules/loan/contracts/Refinancer.sol";

import { LoanScenario   }              from "../../contracts/LoanScenario.sol";
import { ILoanLike, IPoolManagerLike } from "../../contracts/interfaces/Interfaces.sol";
import { SimulationBase }              from "../../contracts/utilities/SimulationBase.sol";

contract BusinessSimulationsMultiLoan is SimulationBase {

    address refinancer = address(new Refinancer());

    function setUp() public override {
        super.setUp();

        initialCover     = 0;
        initialLiquidity = 7_000e6;

        vm.prank(governor);
        globals.setMaxCoverLiquidationPercent(address(poolManager), 0.3e6);
    }

    function _createSimulationLoan(uint256 startingPrincipal, uint256 endingPrincipal, uint256 collateral, string memory loanName) internal {
        scenarios.push(new LoanScenario({
            loan_: address(createLoan({
                borrower:    address(new Address()),
                termDetails: [uint256(0), uint256(30 days), uint256(6)],
                amounts:     [uint256(collateral), uint256(startingPrincipal), uint256(endingPrincipal)],
                rates:       [uint256(0.15e18), uint256(0), uint256(0), uint256(0)]
            })),
            poolManager_:       address(poolManager),
            liquidatorFactory_: address(liquidatorFactory),
            fundingTime_:       start,
            name_:              loanName
        }));
    }

    function test_businessSimulationMultiLoan() external {
        _createSimulationLoan(1_000e6, 1_000e6, 0, 'loan-1');
        _createSimulationLoan(1_000e6, 1_000e6, 0, 'loan-2');
        _createSimulationLoan(1_000e6, 1_000e6, 0, 'loan-3');
        _createSimulationLoan(1_000e6, 1_000e6, 0, 'loan-4');
        _createSimulationLoan(1_000e6, 1_000e6, 0, 'loan-5');
        _createSimulationLoan(1_000e6, 1_000e6, 0, 'loan-6');
        _createSimulationLoan(1_000e6, 1_000e6, 0, 'loan-7');

        // Loan 1 actions
        scenarios[0].setPaymentOffset(1, -15 days);
        scenarios[0].setPaymentOffset(2, -10 days);
        scenarios[0].setPaymentOffset(3,  -2 days);
        scenarios[0].setPaymentOffset(4,   5 days);
        scenarios[0].setPaymentOffset(5,   3 days);

        // Loan 2 actions
        scenarios[1].setPaymentOffset(1, -15 days);
        scenarios[1].setPaymentOffset(2, -10 days);

        bytes[] memory data_ = encodeWithSignatureAndUint("setPaymentInterval(uint256)", 30 days);
        scenarios[1].setRefinance(refinancer, 3, 0, 0, 0, data_);  // Note: No offset as refinance on payment day 90

        scenarios[1].setLoanImpairment(5, -4 days);

        // Loan 3 actions
        scenarios[2].setPaymentOffset(1, -15 days);
        scenarios[2].setPaymentOffset(2, -10 days);

        data_ = encodeWithSignatureAndUint("setPaymentInterval(uint256)", 30 days);
        scenarios[2].setRefinance(refinancer, 3, 0, 0, 0, data_);  // Note: No offset as refinance on payment day 90

        scenarios[2].setLoanImpairment(5, -4 days);

        scenarios[2].setLiquidation(5, 0, 0, 0);  // Note: No offset as impairment on payment day 150

        // Loan 4 actions
        scenarios[3].setPaymentOffset(1, -15 days);
        scenarios[3].setPaymentOffset(2, -10 days);
        scenarios[3].setPaymentOffset(3,   5 days);

        scenarios[3].setLoanImpairment(4, 2 days);

        scenarios[3].setPaymentOffset(4, 4 days);

        // Loan 5 actions
        scenarios[4].setPaymentOffset(1, 5 days);
        scenarios[4].setPaymentOffset(2, 5 days);

        data_ = encodeWithSignatureAndUint("setPaymentInterval(uint256)", 30 days);
        scenarios[4].setRefinance(refinancer, 3, 0, 0, 0, data_);  // Note: No offset as refinance on payment day 90

        scenarios[4].setClosingPayment(4);

        // Loan 6 actions
        scenarios[5].setPaymentOffset(1, 5 days);
        scenarios[5].setPaymentOffset(2, 5 days);

        scenarios[5].setLiquidation(3, 5 days, 0, 0);

        // Loan 7 actions
        scenarios[6].setPaymentOffset(1, -15 days);
        scenarios[6].setPaymentOffset(2,  32 days);
        scenarios[6].setPaymentOffset(3,   2 days);


        string memory fileName = "business-sim-multi-loan";

        setUpSimulation(fileName);

        setUpBusinessLogger(fileName);
        simulation.run();
    }

}
