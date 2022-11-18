// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";

import { CloseLoanAction                   } from "../../contracts/actions/CloseLoanAction.sol";
import { DrawdownLoanAction                } from "../../contracts/actions/DrawdownLoanAction.sol";
import { FinishCollateralLiquidationAction } from "../../contracts/actions/FinishCollateralLiquidationAction.sol";
import { FundLoanAction                    } from "../../contracts/actions/FundLoanAction.sol";
import { ImpairLoanAction                  } from "../../contracts/actions/ImpairLoanAction.sol";
import { LiquidationAction                 } from "../../contracts/actions/LiquidationAction.sol";
import { MakePaymentAction                 } from "../../contracts/actions/MakePaymentAction.sol";
import { RefinanceAction                   } from "../../contracts/actions/RefinanceAction.sol";
import { TriggerDefaultAction              } from "../../contracts/actions/TriggerDefaultAction.sol";

import { IAction          } from "../interfaces/IAction.sol";
import { IActionGenerator } from "../interfaces/IActionGenerator.sol";
import { ILoanLike        } from "../interfaces/Interfaces.sol";

import { LoanScenario } from "../LoanScenario.sol";

contract LoanActionGenerator is TestUtils, IActionGenerator {

    IAction[] internal actions;

    function generateActions(LoanScenario scenario_) external override returns (IAction[] memory actions_) {
        delete actions;

        ILoanLike loan_ = scenario_.loan();

        // Create the funding action.
        actions.push(new FundLoanAction({
            timestamp_:   scenario_.fundingTime(),
            description_: string(abi.encodePacked("Fund '", scenario_.name(), "'")),
            poolManager_: scenario_.poolManager(),
            loan_:        loan_
        }));

        // Create the drawdown action.
        actions.push(new DrawdownLoanAction({
            timestamp_:   scenario_.fundingTime(),
            description_: string(abi.encodePacked("Draw down '", scenario_.name(), "'")),
            loan_:        loan_
        }));

        for (uint256 payment = 1; payment <= loan_.paymentsRemaining(); ++payment) {
            if (scenario_.impairmentOffsets(payment) != 0) {
                actions.push(new ImpairLoanAction({
                    timestamp_:   uint256(int256(scenario_.fundingTime()) + int256(payment * scenario_.loan().paymentInterval()) + scenario_.impairmentOffsets(payment)),
                    description_: string(abi.encodePacked("Impair loan", scenario_.name(), "'")),
                    poolManager_: scenario_.poolManager(),
                    loan_:        address(loan_)
                }));
            }

            if (scenario_.refinancerOffset(payment) != 0) {
                actions.push(new RefinanceAction({
                    timestamp_:         uint256(int256(scenario_.fundingTime()) + int256(payment * scenario_.loan().paymentInterval()) + scenario_.refinancerOffset(payment)),
                    description_:       string(abi.encodePacked("Refinance '", scenario_.name(), "'")),
                    loan_:              loan_,
                    poolManager_:       scenario_.poolManager(),
                    refinancer_:        scenario_.refinancer(),
                    principalIncrease_: scenario_.principalIncrease(),
                    returnFundAmount_:  scenario_.returnFundAmount(),
                    calls_:             scenario_.getRefinanceCalls()
                }));
            }

            // If the payment is missing, stop generating actions.
            if (scenario_.missingPayments(payment)) {
                actions.push(new TriggerDefaultAction({
                    timestamp_:         uint256(int256(scenario_.fundingTime()) + int256(payment * loan_.paymentInterval()) + int256(scenario_.liquidationTriggerOffset())),
                    description_:       string(abi.encodePacked("Trigger default '", scenario_.name(), "'")),
                    poolManager_:       scenario_.poolManager(),
                    loan_:              address(loan_),
                    liquidatorFactory_: scenario_.liquidatorFactory()
                }));

                actions.push(new LiquidationAction({
                    timestamp_:        uint256(int256(scenario_.fundingTime()) + int256(payment * loan_.paymentInterval()) + int256(scenario_.liquidationTriggerOffset())),
                    description_:      string(abi.encodePacked("Liquidation '", scenario_.name(), "'")),
                    loan_:             address(loan_),
                    loanManager_:      address(scenario_.loanManager()),
                    liquidationPrice_: scenario_.liquidationPrice()
                }));

                actions.push(new FinishCollateralLiquidationAction({
                    timestamp_:         uint256(int256(scenario_.fundingTime()) + int256(payment * loan_.paymentInterval()) + int256(scenario_.finishCollateralLiquidationOffset())),
                    description_:       string(abi.encodePacked("Finish collateral liquidation '", scenario_.name(), "'")),
                    poolManager_:       scenario_.poolManager(),
                    loan_:              address(loan_)
                }));
                break;
            }

            // If this is the closing payment, create a close action and stop generating payment actions.
            if (scenario_.closingPayment() == payment) {
                actions.push(new CloseLoanAction({
                    timestamp_:   uint256(int256(scenario_.fundingTime()) + int256(payment * scenario_.loan().paymentInterval()) + scenario_.paymentOffsets(payment)),
                    description_: string(abi.encodePacked("Close loan '", scenario_.name(), "'")),
                    loan_:        loan_
                }));
                break;
            }

            // Otherwise, make a regular payment with any specified offsets.
            actions.push(new MakePaymentAction({
                timestamp_:   uint256(int256(scenario_.fundingTime()) + int256(payment * loan_.paymentInterval()) + scenario_.paymentOffsets(payment)),
                description_: _generatePaymentDescription(scenario_.name(), payment, scenario_.paymentOffsets(payment)),
                loan_:        loan_
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
