// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";

import { CloseLoanAction    } from "../../contracts/actions/CloseLoanAction.sol";
import { DrawdownLoanAction } from "../../contracts/actions/DrawdownLoanAction.sol";
import { FundLoanAction     } from "../../contracts/actions/FundLoanAction.sol";
import { MakePaymentAction  } from "../../contracts/actions/MakePaymentAction.sol";

import { IAction          } from "../interfaces/IAction.sol";
import { IActionGenerator } from "../interfaces/IActionGenerator.sol";

import { LoanScenario } from "../LoanScenario.sol";

contract LoanActionGenerator is TestUtils, IActionGenerator {

    IAction[] internal actions;

    function generateActions(LoanScenario scenario_) external override returns (IAction[] memory actions_) {
        delete actions;

        // Create the funding action.
        actions.push(new FundLoanAction({
            timestamp_:   scenario_.fundingTime(),
            description_: string(abi.encodePacked("Fund '", scenario_.name(), "'")),
            poolManager_: scenario_.poolManager(),
            loan_:        scenario_.loan()
        }));

        // Create the drawdown action.
        actions.push(new DrawdownLoanAction({
            timestamp_:   scenario_.fundingTime(),
            description_: string(abi.encodePacked("Draw down '", scenario_.name(), "'")),
            loan_:        scenario_.loan()
        }));

        for (uint256 payment = 1; payment <= scenario_.loan().paymentsRemaining(); ++payment) {

            // If the payment is missing, stop generating actions.
            if (scenario_.missingPayments(payment)) {
                break;
            }

            // If this is the closing payment, create a close action and stop generating payment actions.
            if (scenario_.closingPayment() == payment) {
                actions.push(new CloseLoanAction({
                    timestamp_:   uint256(int256(scenario_.fundingTime()) + int256(payment * scenario_.loan().paymentInterval()) + scenario_.paymentOffsets(payment)),
                    description_: string(abi.encodePacked("Close loan '", scenario_.name(), "'")),
                    loan_:        scenario_.loan()
                }));
                break;
            }

            // Otherwise, make a regular payment with any specified offsets.
            actions.push(new MakePaymentAction({
                timestamp_:   uint256(int256(scenario_.fundingTime()) + int256(payment * scenario_.loan().paymentInterval()) + scenario_.paymentOffsets(payment)),
                description_: _generatePaymentDescription(scenario_.name(), payment, scenario_.paymentOffsets(payment)),
                loan_:        scenario_.loan()
            }));
        }

        // Copy all actions into the memory array.
        actions_ = new IAction[](actions.length);
        actions_ = actions;
    }

    function _generatePaymentDescription(string memory name_, uint256 payment_, int256 paymentOffset_) internal pure returns (string memory description_) {
        string memory endDescription = string(abi.encodePacked("payment '", convertUintToString(payment_), "' on '", name_, "'"));
        string memory startDescription = "Make ";

        if (paymentOffset_ > 0) {
            startDescription = "Make late ";
        } else if (paymentOffset_ < 0) {
            startDescription = "Make early ";
        }

        description_ = string(abi.encodePacked(startDescription, endDescription));
    }

}
