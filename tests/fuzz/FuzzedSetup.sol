// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console2 } from "../../modules/forge-std/src/console2.sol";

import { IFixedTermLoan, ILoanLike, IOpenTermLoan } from "../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

// TODO: Add refinancing.
enum LoanAction {
    Call,
    Close,
    Fund,
    Impair,
    Payment,
    RemoveCall,
    RemoveImpairment,
    TriggerDefault
}

contract FuzzedSetup is TestBaseWithAssertions {

    uint256 constant CALL_FACTOR              = 75;
    uint256 constant DEFAULT_FACTOR           = 33;
    uint256 constant FUND_FACTOR              = 100;
    uint256 constant IMPAIR_FACTOR            = 75;
    uint256 constant PAYMENT_FACTOR           = 100;
    uint256 constant REMOVE_CALL_FACTOR       = 100;
    uint256 constant REMOVE_IMPAIRMENT_FACTOR = 100;

    address fixedTermLoanManager;
    address openTermLoanManager;

    uint256 seed;

    address[] loans;

    function setUp() public override {
        super.setUp();

        fixedTermLoanManager = poolManager.loanManagerList(0);
        openTermLoanManager  = poolManager.loanManagerList(1);

        // Deposit the initial liquidity.
        deposit(address(pool), makeAddr("lp"), 500_000_000e6);
    }

    function fuzzedSetup(uint256 fixedTermLoans, uint256 openTermLoans, uint256 actionCount, uint256 seed_) internal {
        seed = seed_;

        // Create and fund fixed loans.
        for (uint256 i; i < fixedTermLoans; ++i) {
            vm.warp(block.timestamp + 1 days);
            createAndFundLoan(createSomeFixedTermLoan);
        }

        // Create and fund open loans.
        for (uint256 i; i < openTermLoans; ++i) {
            vm.warp(block.timestamp + 1 days);
            createAndFundLoan(createSomeOpenTermLoan);
        }

        // Perform random loan actions.
        for (uint256 i; i < actionCount; ++i) {
            // Get loan and due date of active loan with earliest due date.
            ( address loan, uint256 dueDate ) = getEarliestDueDate();

            // If no active loans are remaining: no further actions can be performed.
            if (loan == address(0)) return;

            uint256 maxDate = dueDate < block.timestamp
                ? 1 days
                : (dueDate - block.timestamp) + 10 days;

            // Warp to anytime from 1 day from now to 11 days past the loan's due date.
            vm.warp(block.timestamp + 1 days + getSomeValue(0, maxDate));

            performSomeLoanAction(loan);

            if (isOpenTermLoan(loan) ? IOpenTermLoan(loan).paymentDueDate() == 0 : IFixedTermLoan(loan).nextPaymentDueDate() == 0) {
                removeLoan(loan);
            }
        }
    }

    function createAndFundLoan(function() returns (address) createLoan_) internal returns (address loan) {
        loan = createLoan_();

        loans.push(loan);
        fundLoan(loan);
    }

    function createSomeOpenTermLoan() internal returns (address loan) {
        require(fundsAsset.balanceOf(address(pool)) > 0, "No funding is available.");

        uint256 principal              = getSomeValue(100_000e6, 10_000_000e6);
        uint256 noticePeriod           = getSomeValue(0,         10 days);
        uint256 gracePeriod            = getSomeValue(0,         10 days);
        uint256 paymentInterval        = getSomeValue(10 days,   90 days);
        uint256 delegateServiceFeeRate = getSomeValue(0,         0.1e6);
        uint256 interestRate           = getSomeValue(0.01e6,    0.25e6);
        uint256 lateFeeRate            = getSomeValue(0,         0.1e6);
        uint256 lateInterestPremium    = getSomeValue(0,         0.1e6);

        loan = createOpenTermLoan(
            address(openTermLoanFactory),
            makeAddr("borrower"),
            address(openTermLoanManager),
            address(fundsAsset),
            principal,
            [gracePeriod, noticePeriod, paymentInterval],
            [delegateServiceFeeRate, interestRate, lateFeeRate, lateInterestPremium]
        );
    }

    function createSomeFixedTermLoan() internal returns (address loan) {
        require(fundsAsset.balanceOf(address(pool)) > 0, "No funding is available.");

        uint256 principal = getSomeValue(100_000e6, 10_000_000e6);

        uint256[3] memory amounts = [
            0,                          // collateralRequired
            principal,                  // principalRequested
            getSomeValue(0, principal)  // endingPrincipal
        ];

        uint256[3] memory term = [
            getSomeValue(12 hours, 10 days),  // gracePeriod
            getSomeValue(10 days,  90 days),  // paymentInterval
            getSomeValue(1,        12)        // payments
        ];

        uint256[4] memory rates = [
            getSomeValue(0.01e6, 0.25e6),  // interestRate
            getSomeValue(0.01e6, 0.25e6),  // closingFeeRate
            getSomeValue(0,      0.1e6),   // lateFeeRate
            getSomeValue(0,      0.1e6)    // lateInterestPremiumRate
        ];

        uint256[2] memory fees = [
            getSomeValue(0, principal * 0.025e6 / 1e6),  // delegateOriginationFee
            getSomeValue(0, 100_000e6)                   // delegateServiceFee
        ];

        loan = createFixedTermLoan(
            address(fixedTermLoanFactory),
            makeAddr(string(abi.encode("borrower", getSomeValue(0, 100)))),
            address(fixedTermLoanManager),
            address(feeManager),
            [address(collateralAsset), address(fundsAsset)],
            amounts,
            term,
            rates,
            fees
        );
    }

    function removeLoan(address loan) internal {
        for (uint256 i; i < loans.length; ++i) {
            if (loan != loans[i]) continue;

            loans[i] = loans[loans.length - 1];

            loans.pop();

            return;
        }
    }

    function performSomeLoanAction(address loan) internal {
        // Randomly select an action that can be performed on the loan.
        LoanAction action = isOpenTermLoan(loan) ? getSomeOpenTermAction(loan) : getSomeFixedTermAction(loan);

        if (action == LoanAction.Payment) {
            makePayment(loan);
            console2.log("Payment made:", loan);
            return;
        }

        if (action == LoanAction.Call) {
            callLoan(loan, getSomeValue(1, IOpenTermLoan(loan).principal()));
            console2.log("Loan called:", loan);
            return;
        }

        if (action == LoanAction.Impair) {
            impairLoan(loan);
            console2.log("Loan impaired:", loan);
            return;
        }

        if (action == LoanAction.TriggerDefault) {
            triggerDefault(loan, address(liquidatorFactory));
            console2.log("Default triggered:", loan);
            return;
        }

        if (action == LoanAction.RemoveImpairment) {
            removeLoanImpairment(loan);
            console2.log("Loan impairment removed:", loan);
            return;
        }

        if (action == LoanAction.RemoveCall) {
            removeLoanCall(loan);
            console2.log("Loan call removed:", loan);
            return;
        }
    }

    // NOTE: Code duplication with `getSomeOpenTermAction` because can not yet identify cleaner way to do this.
    function getSomeFixedTermAction(address loan) internal returns (LoanAction action) {
        // Always enable payments to be performed.
        uint256 total = PAYMENT_FACTOR;

        bool isImpaired  = IFixedTermLoan(loan).isImpaired();
        bool isInDefault = block.timestamp > IFixedTermLoan(loan).nextPaymentDueDate() + IFixedTermLoan(loan).gracePeriod();

        // If the loan is impaired also enable impairment removal, else enable impairment.
        total += isImpaired && block.timestamp <= IFixedTermLoan(loan).originalNextPaymentDueDate() ?
            REMOVE_IMPAIRMENT_FACTOR :
            IMPAIR_FACTOR;

        // If the loan is past the default date also enable default triggering.
        if (isInDefault) {
            total += DEFAULT_FACTOR;
        }

        uint256 draw = getSomeValue(0, total - 1);

        if (draw < PAYMENT_FACTOR) return LoanAction.Payment;

        draw -= PAYMENT_FACTOR;

        if (isImpaired && block.timestamp <= IFixedTermLoan(loan).originalNextPaymentDueDate()) {
            if (draw < REMOVE_IMPAIRMENT_FACTOR) return LoanAction.RemoveImpairment;

            draw -= REMOVE_IMPAIRMENT_FACTOR;
        } else if (!isImpaired) {
            if (draw < IMPAIR_FACTOR) return LoanAction.Impair;

            draw -= IMPAIR_FACTOR;
        } else if (isInDefault) {
            if (draw < DEFAULT_FACTOR) return LoanAction.TriggerDefault;

            draw -= DEFAULT_FACTOR;
        }

        return LoanAction.Payment;  // The default action if other conditions are not met.
    }

    // NOTE: Code duplication with `getSomeFixedTermAction` because can not yet identify cleaner way to do this.
    function getSomeOpenTermAction(address loan) internal returns (LoanAction action) {
        // Always enable payments, calls, impairments to be performed.
        uint256 total = PAYMENT_FACTOR + CALL_FACTOR + IMPAIR_FACTOR;

        bool isCalled    = IOpenTermLoan(loan).isCalled();
        bool isImpaired  = IOpenTermLoan(loan).isImpaired();
        bool isInDefault = IOpenTermLoan(loan).isInDefault();

        // If the loan is called also enable call removal.
        if (isCalled) {
            total += REMOVE_CALL_FACTOR;
        }

        // If the loan is impaired also enable impairment removal.
        if (isImpaired) {
            total += REMOVE_IMPAIRMENT_FACTOR;
        }

        // If the loan is past the default date also enable default triggering.
        if (isInDefault) {
            total += DEFAULT_FACTOR;
        }

        uint256 draw = getSomeValue(0, total - 1);

        if (draw < PAYMENT_FACTOR) return LoanAction.Payment;

        draw -= PAYMENT_FACTOR;

        if (draw < CALL_FACTOR) return LoanAction.Call;

        draw -= CALL_FACTOR;

        if (draw < IMPAIR_FACTOR) return LoanAction.Impair;

        draw -= IMPAIR_FACTOR;

        if (isCalled) {
            if (draw < REMOVE_CALL_FACTOR) return LoanAction.RemoveCall;

            draw -= REMOVE_CALL_FACTOR;
        }

        if (isImpaired) {
            if (draw < REMOVE_IMPAIRMENT_FACTOR) return LoanAction.RemoveImpairment;

            draw -= REMOVE_IMPAIRMENT_FACTOR;
        }

        return LoanAction.TriggerDefault;
    }

    function getEarliestDueDate() internal returns (address loan_, uint256 dueDate_) {
        for (uint256 i; i < loans.length; ++i) {
            address loan           = loans[i];
            uint256 paymentDueDate = isOpenTermLoan(loan) ? IOpenTermLoan(loan).paymentDueDate() : IFixedTermLoan(loan).nextPaymentDueDate();

            if (paymentDueDate < dueDate_ || (paymentDueDate > 0 && dueDate_ == 0)) {
                loan_    = loan;
                dueDate_ = paymentDueDate;
            }
        }
    }

    function getNextDueDate() internal returns (address loan_, uint256 dueDate_) {
        for (uint256 i; i < loans.length; ++i) {
            address loan           = loans[i];
            uint256 paymentDueDate = isOpenTermLoan(loan) ? IOpenTermLoan(loan).paymentDueDate() : IFixedTermLoan(loan).nextPaymentDueDate();

            if (paymentDueDate < dueDate_ || (paymentDueDate > block.timestamp && dueDate_ == 0)) {
                loan_    = loan;
                dueDate_ = paymentDueDate;
            }
        }
    }

    function getSomeActiveLoan() internal returns (address loan_) {
        loan_ = getSomeLoan(isActiveLoan);
    }

    function getSomeActiveFixedTermLoan() internal returns (address loan_) {
        loan_ = getSomeLoan(isActiveFixedTermLoan);
    }

    function getSomeActiveOpenTermLoan() internal returns (address loan_) {
        loan_ = getSomeLoan(isActiveOpenTermLoan);
    }

    function isActiveLoan(address loan_) internal returns (bool isActiveLoan_) {
        isActiveLoan_ = ILoanLike(loan_).principal() > 0;
    }

    function isActiveFixedTermLoan(address loan_) internal returns (bool isActiveFixedTermLoan_) {
        isActiveFixedTermLoan_ = isFixedTermLoan(loan_) && isActiveLoan(loan_);
    }

    function isActiveOpenTermLoan(address loan_) internal returns (bool isActiveOpenTermLoan_) {
        isActiveOpenTermLoan_ = isOpenTermLoan(loan_) && isActiveLoan(loan_);
    }

    function getSomeLoan(function (address) returns (bool) filter_) internal returns (address loan) {
        // Choose the starting loan.
        uint256 index = getSomeValue(0, loans.length - 1);

        for (uint256 i; i < loans.length; ++i) {
            loan = loans[index];

            // If the loan is meets filter condition, return it.
            if (filter_(loan)) return loan;

            // If the loan is not active then check the next one.
            index = (index + 1) % loans.length;
        }

        // If all loans are inactive return the zero address.
        return address(0);
    }

    function getSomeValue(uint256 min_, uint256 max_) internal returns (uint256 value_) {
        value_ = _bound(seed = uint256(keccak256(abi.encode(seed))), min_, max_);
    }

}
