// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { Address } from "../../modules/contract-test-utils/contracts/test.sol";

import { LoanScenario   }              from "../../contracts/LoanScenario.sol";
import { ILoanLike, IPoolManagerLike } from "../../contracts/interfaces/Interfaces.sol";
import { SimulationBase }              from "../../contracts/utilities/SimulationBase.sol";

contract MultiLoanSimulation is SimulationBase {

    function setUp() public override {
        super.setUp();

        // Specify initial cover and liquidity.
        initialCover     = 0;
        initialLiquidity = 100_000_000e6;

        // Add 1st loan.
        scenarios.push(new LoanScenario({
            loan_: address(createLoan({
                borrower:    address(new Address()),
                termDetails: [uint256(10 days), uint256(30 days), uint256(3)],
                amounts:     [uint256(0), uint256(10_000_000e6), uint256(10_000_000e6)],
                rates:       [uint256(0.12e18), uint256(0.02e18), uint256(0), uint256(0)]
            })),
            poolManager_: address(poolManager),
            fundingTime_: start,
            name_:        "loan-1"
        }));

        // Add 2nd loan.
        scenarios.push(new LoanScenario({
            loan_: address(createLoan({
                borrower:    address(new Address()),
                termDetails: [uint256(10 days), uint256(10 days), uint256(3)],
                amounts:     [uint256(0), uint256(20_000_000e6), uint256(20_000_000e6)],
                rates:       [uint256(0.10e18), uint256(0.02e18), uint256(0), uint256(0)]
            })),
            poolManager_: address(poolManager),
            fundingTime_: start + 5.12 days,
            name_:        "loan-2"
        }));

        // Add 3rd loan.
        scenarios.push(new LoanScenario({
            loan_: address(createLoan({
                borrower:    address(new Address()),
                termDetails: [uint256(10 days), uint256(15 days), uint256(3)],
                amounts:     [uint256(0), uint256(10_000_000e6), uint256(10_000_000e6)],
                rates:       [uint256(0.16e18), uint256(0.02e18), uint256(0), uint256(0)]
            })),
            poolManager_: address(poolManager),
            fundingTime_: start + 8.88 days,
            name_:        "loan-3"
        }));

        // Add 4th loan.
        scenarios.push(new LoanScenario({
            loan_: address(createLoan({
                borrower:    address(new Address()),
                termDetails: [uint256(10 days), uint256(30 days), uint256(3)],
                amounts:     [uint256(0), uint256(10_000_000e6), uint256(10_000_000e6)],
                rates:       [uint256(0.08e18), uint256(0.02e18), uint256(0), uint256(0)]
            })),
            poolManager_: address(poolManager),
            fundingTime_: start + 12.4 days,
            name_:        "loan-4"
        }));
    }

    function test_multiLoanSimulation_earlyPayments() external {
        scenarios[0].setPaymentOffset(1, -1.34 days);
        scenarios[0].setPaymentOffset(2, -1.99 days);
        scenarios[0].setPaymentOffset(3, -2.61 days);

        scenarios[1].setPaymentOffset(1, -1.21 days);
        scenarios[1].setPaymentOffset(2, -1.09 days);
        scenarios[1].setPaymentOffset(3, -3.98 days);

        scenarios[2].setPaymentOffset(1, -1.77 days);
        scenarios[2].setPaymentOffset(2, -1.11 days);
        scenarios[2].setPaymentOffset(3, -0.1 days);

        scenarios[3].setPaymentOffset(1, -1.98 days);
        scenarios[3].setPaymentOffset(2, -1.12 days);
        scenarios[3].setPaymentOffset(3, -3.88 days);

        runSimulation("early-payments");
    }

    function test_multiLoanSimulation_variousPayments() external {
        scenarios[0].setPaymentOffset(1,  1.34 days);
        scenarios[0].setPaymentOffset(2, -1.99 days);
        scenarios[0].setPaymentOffset(3,  2.61 days);

        scenarios[1].setPaymentOffset(1, -1.21 days);
        scenarios[1].setClosingPayment(2);

        scenarios[2].setClosingPayment(1);

        scenarios[3].setPaymentOffset(1,  1.98 days);
        scenarios[3].setPaymentOffset(2, -1.12 days);
        scenarios[3].setPaymentOffset(3,  3.88 days);

        runSimulation("various-payments");
    }

}
