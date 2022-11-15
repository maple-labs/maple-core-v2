// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

import { ILoanLike, ILoanManagerLike, IPoolManagerLike } from "./interfaces/Interfaces.sol";

contract LoanScenario is TestUtils {

    address public liquidatorFactory;
    address public refinancer;

    uint256 public closingPayment;
    uint256 public finishCollateralLiquidationOffset;
    uint256 public fundingTime;
    uint256 public impairedPayment;
    uint256 public liquidationPrice;  // 1e6 precision
    uint256 public liquidationTriggerOffset;
    uint256 public principalIncrease;
    uint256 public returnFundAmount;

    string public name;

    bool[] public missingPayments;

    bytes[] public refinanceCalls;

    int256[] public impairmentOffsets;
    int256[] public paymentOffsets;
    int256[] public refinancerOffset;

    ILoanLike        public loan;
    ILoanManagerLike public loanManager;
    IPoolManagerLike public poolManager;

    constructor(address loan_, address poolManager_, address liquidatorFactory_, uint256 fundingTime_, string memory name_) {
        liquidatorFactory = liquidatorFactory_;
        loan              = ILoanLike(loan_);
        poolManager       = IPoolManagerLike(poolManager_);
        loanManager       = ILoanManagerLike(poolManager.loanManagerList(0));
        fundingTime       = fundingTime_;
        name              = name_;

        // Increase size of arrays by one to ignore the zero index element.
        impairmentOffsets = new int256[](loan.paymentsRemaining() + 1);
        missingPayments   = new bool[](loan.paymentsRemaining() + 1);
        paymentOffsets    = new int256[](loan.paymentsRemaining() + 1);
        refinancerOffset  = new int256[](loan.paymentsRemaining() + 1);
    }

    function setLiquidation(uint256 payment_, uint256 liquidationTriggerOffset_, uint256 finishCollateralLiquidationOffset_, uint256 liquidationPrice_) external {
        for ( ; payment_ < missingPayments.length; ++payment_) {
            missingPayments[payment_] = true;
        }

        liquidationPrice                  = liquidationPrice_;
        liquidationTriggerOffset          = liquidationTriggerOffset_;
        finishCollateralLiquidationOffset = finishCollateralLiquidationOffset_;
    }

    function setLoanImpairment(uint256 payment_, int256 impairmentOffset_) external {
        impairmentOffsets[payment_] = impairmentOffset_;
    }

    function setClosingPayment(uint256 payment) external {
        closingPayment = payment;
        for (payment = closingPayment + 1; payment < missingPayments.length; ++payment) {
            missingPayments[payment] = true;
        }
    }

    function setPaymentOffset(uint256 payment, int256 offset) external {
        paymentOffsets[payment] = offset;
    }

    function setRefinance(address refinancer_, uint256 payment_, int256 refinancerOffset_, uint256 principalIncrease_, uint256 returnFundAmount_, bytes[] memory refinanceCalls_) external {
        refinancer        = refinancer_;
        principalIncrease = principalIncrease_;
        returnFundAmount  = returnFundAmount_;
        refinanceCalls    = refinanceCalls_;

        refinancerOffset[payment_] = refinancerOffset_;
    }

    function getRefinanceCalls() external view returns (bytes[] memory) {
        return refinanceCalls;
    }

}
