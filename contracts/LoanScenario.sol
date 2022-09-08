// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

import { ILoanLike, ILoanManagerLike, IPoolManagerLike } from "./interfaces/Interfaces.sol";

contract LoanScenario is TestUtils {

    uint256 public closingPayment;
    uint256 public fundingTime;

    string public name;

    bool[] public missingPayments;

    int256[] public paymentOffsets;

    ILoanLike        public loan;
    ILoanManagerLike public loanManager;
    IPoolManagerLike public poolManager;

    constructor(address loan_, address poolManager_, uint256 fundingTime_, string memory name_) {
        loan        = ILoanLike(loan_);
        poolManager = IPoolManagerLike(poolManager_);
        loanManager = ILoanManagerLike(poolManager.loanManagerList(0));
        fundingTime = fundingTime_;
        name        = name_;

        // Increase size of arrays by one to ignore the zero index element.
        paymentOffsets  = new int256[](loan.paymentsRemaining() + 1);
        missingPayments = new bool[](loan.paymentsRemaining() + 1);
    }

    function setMissingPayment(uint256 payment) external {
        for ( ; payment < missingPayments.length; ++payment) {
            missingPayments[payment] = true;
        }
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

}
