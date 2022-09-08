// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { Address } from "../../modules/contract-test-utils/contracts/test.sol";

import { LoanScenario   }              from "../../contracts/LoanScenario.sol";
import { ILoanLike, IPoolManagerLike } from "../../contracts/interfaces/Interfaces.sol";
import { SimulationBase }              from "../../contracts/utilities/SimulationBase.sol";

contract BasicSimulation is SimulationBase {

    function setUp() public override {
        super.setUp();

        scenarios.push(new LoanScenario({
            loan_: address(createLoan({
                borrower:    address(new Address()),
                termDetails: [uint256(0), uint256(30 days), uint256(3)],
                amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
                rates:       [uint256(0.01e18), uint256(0), uint256(0), uint256(0)]
            })),
            poolManager_: address(poolManager),
            fundingTime_: start,  // End: 0 + 30 * 3 = 90
            name_:        "loan-1"
        }));

        setUpSimulation({ initialCover_: 0, initialLiquidity_: 1_500_000e6, filepath_: "basic-simulation" });
    }

    function test_basicSimulation() external {
        simulation.run();
    }

}
