// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IERC20,
    IFixedTermLoan,
    IFixedTermLoanManager,
    ILoanLike,
    IOpenTermLoan,
    IOpenTermLoanManager,
    IPool,
    IPoolManager,
    IWithdrawalManagerCyclical,
    IWithdrawalManagerQueue
} from "../../contracts/interfaces/Interfaces.sol";

import { console2 as console } from "../../contracts/Contracts.sol";

import { ProtocolActions } from "../../contracts/ProtocolActions.sol";

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

contract FuzzedUtil is ProtocolActions {

    uint256 constant CALL_FACTOR              = 75;
    // uint256 constant CLOSE_FACTOR          = 100;
    uint256 constant DEFAULT_FACTOR           = 33;
    uint256 constant FUND_FACTOR              = 100;
    uint256 constant IMPAIR_FACTOR            = 75;
    uint256 constant PAYMENT_FACTOR           = 100;
    uint256 constant REMOVE_CALL_FACTOR       = 100;
    uint256 constant REMOVE_IMPAIRMENT_FACTOR = 100;

    // Local addresses that will be overridden by implementers
    address _collateralAsset;
    address _feeManager;
    address _fixedTermLoanManager;
    address _fixedTermLoanFactory;
    address _fundsAsset;
    address _liquidatorFactory;
    address _openTermLoanFactory;
    address _openTermLoanManager;
    address _pool;
    address _poolManager;

    uint256 seed;

    address[] _fixedTermLoans;
    address[] _openTermLoans;
    address[] lps;
    address[] loans;

    uint256[] escrowedShares;

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

            if (ILoanLike(loan).principal() == 0) {
                removeLoan(loan);
            }
        }
    }

    function payOffLoansAndRedeemAllLps() internal returns (uint256 lastDomainStartFTLM_, uint256 lastDomainStartOTLM_) {
        ( lastDomainStartFTLM_, lastDomainStartOTLM_ ) = payOffAllLoans();

        requestRedeemAllLps();
        redeemAllLps();
    }

    function payOffAllLoans() internal returns (uint256 lastDomainStartFTLM_, uint256 lastDomainStartOTLM_) {
        ( address loan , ) = getEarliestDueDate();

        lastDomainStartFTLM_ = IFixedTermLoanManager(_fixedTermLoanManager).domainStart();
        lastDomainStartOTLM_ = IOpenTermLoanManager(_openTermLoanManager).domainStart();

        while (loan != address(0)) {
            bool isOpenTermLoan = isOpenTermLoan(loan);

            uint256 nextPaymentDueDate = isOpenTermLoan
                ? IOpenTermLoan(loan).paymentDueDate()
                : IFixedTermLoan(loan).nextPaymentDueDate();

            // Call open terms after 5 payments on average
            if (isOpenTermLoan && uint256(keccak256(abi.encode(nextPaymentDueDate))) % 5 == 0) {
                callLoan(loan, IOpenTermLoan(loan).principal());
            }

            if (nextPaymentDueDate > block.timestamp) {
                vm.warp(nextPaymentDueDate);
            }

            makePayment(loan);

            isOpenTermLoan ? lastDomainStartOTLM_ = block.timestamp : lastDomainStartFTLM_ = block.timestamp;

            if (ILoanLike(loan).principal() == 0) {
                removeLoan(loan);
            }

            ( loan , ) = getEarliestDueDate();
        }
    }

    function requestRedeemAllLps() internal {
        for (uint256 i; i < lps.length; ++i) {
            address lp = lps[i];

            escrowedShares.push(IERC20(address(_pool)).balanceOf(lp));

            // Request redeem all LP tokens.
            requestRedeem(address(_pool), lp, IERC20(address(_pool)).balanceOf(lp));
        }
    }

    function redeemAllLps() internal {
        if (isWMQueue(_poolManager)) {
            redeemFromQueue();
            return;
        }

        for (uint256 i; i < lps.length; ++i) {
            redeemFromCyclical(lps[i], escrowedShares[i]);
        }
    }

    function redeemFromCyclical(address lp, uint256 shares) internal {
        IWithdrawalManagerCyclical withdrawalManager = IWithdrawalManagerCyclical(IPoolManager(_poolManager).withdrawalManager());

        uint256 exitCycleId = withdrawalManager.exitCycleId(lp);

        uint256 withdrawalWindowStart = withdrawalManager.getWindowStart(exitCycleId);

        if (withdrawalWindowStart > block.timestamp) {
            vm.warp(withdrawalWindowStart);
        }

        // Redeem all LP tokens.
        redeem(address(_pool), lp, shares);
    }

    function redeemFromQueue() internal {
        IPoolManager            poolManager       = IPoolManager(_poolManager);
        IWithdrawalManagerQueue withdrawalManager = IWithdrawalManagerQueue(poolManager.withdrawalManager());

        uint256 totalShares = withdrawalManager.totalShares();

        // There's some rounding in the pools that prevent the last hundred or so shares from being redeemed.
        if (totalShares > 100) {
            vm.prank(poolManager.poolDelegate());
            withdrawalManager.processRedemptions(totalShares - 100);
            // Redeem all LP tokens.
            for (uint256 i; i < lps.length; ++i) {
                if (withdrawalManager.manualSharesAvailable(lps[i]) > 0) {
                    redeem(address(_pool), lps[i], escrowedShares[i]);
                }
            }
        }

    }

    function createAndFundLoan(function() returns (address) createLoan_) internal returns (address loan) {
        loan = createLoan_();
        loans.push(loan);
        fundLoan(loan);
    }

    function createSomeOpenTermLoan() internal returns (address loan) {
        require(IERC20(_fundsAsset).balanceOf(address(_pool)) > 0, "No funding is available.");

        uint256 principal              = getSomeValue(100_000e6, 1_000_000e6);
        uint256 noticePeriod           = getSomeValue(1 hours,   10 days);
        uint256 gracePeriod            = getSomeValue(0,         10 days);
        uint256 paymentInterval        = getSomeValue(10 days,   90 days);
        uint256 delegateServiceFeeRate = getSomeValue(0,         0.1e6);
        uint256 interestRate           = getSomeValue(0.01e6,    0.25e6);
        uint256 lateFeeRate            = getSomeValue(0,         0.1e6);
        uint256 lateInterestPremium    = getSomeValue(0,         0.1e6);
        loan = createOpenTermLoan(
            address(_openTermLoanFactory),
            makeAddr("borrower"),
            address(_openTermLoanManager),
            address(_fundsAsset),
            principal,
            [gracePeriod, noticePeriod, paymentInterval],
            [delegateServiceFeeRate, interestRate, lateFeeRate, lateInterestPremium]
        );
    }

    function createSomeFixedTermLoan() internal returns (address loan) {
        require(IERC20(_fundsAsset).balanceOf(address(_pool)) > 0, "No funding is available.");

        uint256 principal = getSomeValue(100_000e6, 1_000_000e6);

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
            address(_fixedTermLoanFactory),
            makeAddr(string(abi.encode("borrower", getSomeValue(0, 100)))),
            address(_fixedTermLoanManager),
            address(_feeManager),
            [address(_collateralAsset), address(_fundsAsset)],
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
            console.log("Payment made:", loan);
            return;
        }

        if (action == LoanAction.Call) {
            callLoan(loan, getSomeValue(1, IOpenTermLoan(loan).principal()));
            console.log("Loan called:", loan);
            return;
        }

        if (action == LoanAction.Impair) {
            impairLoan(loan);
            console.log("Loan impaired:", loan);
            return;
        }

        if (action == LoanAction.TriggerDefault) {
            triggerDefault(loan, address(_liquidatorFactory));
            console.log("Default triggered:", loan);
            return;
        }

        if (action == LoanAction.RemoveImpairment) {
            removeLoanImpairment(loan);
            console.log("Loan impairment removed:", loan);
            return;
        }

        if (action == LoanAction.RemoveCall) {
            removeLoanCall(loan);
            console.log("Loan call removed:", loan);
            return;
        }
    }

    // NOTE: Code duplication with `getSomeOpenTermAction` because can not yet identify cleaner way to do this.
    function getSomeFixedTermAction(address loan) internal returns (LoanAction action) {
        // Always enable payments to be performed.
        uint256 total = PAYMENT_FACTOR;

        bool isImpaired  = IFixedTermLoan(loan).isImpaired();
        bool isInDefault = block.timestamp > IFixedTermLoan(loan).nextPaymentDueDate() + IFixedTermLoan(loan).gracePeriod();

        // If the loan is not impaired, enable impairment, else if the loan is impaired and not late, enable impairment removal.
        if (!isImpaired) {
            total += IMPAIR_FACTOR;
        } else if (block.timestamp <= IFixedTermLoan(loan).originalNextPaymentDueDate()) {
            total += REMOVE_IMPAIRMENT_FACTOR;
        }

        // If the loan is past the default date also enable default triggering.
        if (isInDefault) {
            total += DEFAULT_FACTOR;
        }

        uint256 draw = getSomeValue(0, total - 1);

        if (draw < PAYMENT_FACTOR) return LoanAction.Payment;

        draw -= PAYMENT_FACTOR;

        if (!isImpaired) {
            if (draw < IMPAIR_FACTOR) return LoanAction.Impair;

            draw -= IMPAIR_FACTOR;
        } else if (block.timestamp <= IFixedTermLoan(loan).originalNextPaymentDueDate()) {
            if (draw < REMOVE_IMPAIRMENT_FACTOR) return LoanAction.RemoveImpairment;

            draw -= REMOVE_IMPAIRMENT_FACTOR;
        }

        return LoanAction.TriggerDefault;
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

    function getEarliestDueDate() internal view returns (address loan_, uint256 dueDate_) {
        for (uint256 i; i < loans.length; ++i) {
            address loan           = loans[i];
            uint256 paymentDueDate = isOpenTermLoan(loan) ?
                IOpenTermLoan(loan).paymentDueDate() : IFixedTermLoan(loan).nextPaymentDueDate();

            if (paymentDueDate < dueDate_ || (paymentDueDate > 0 && dueDate_ == 0)) {
                loan_    = loan;
                dueDate_ = paymentDueDate;
            }
        }
    }

    function getNextDueDate() internal view returns (address loan_, uint256 dueDate_) {
        for (uint256 i; i < loans.length; ++i) {
            address loan           = loans[i];
            uint256 paymentDueDate = isOpenTermLoan(loan) ?
                IOpenTermLoan(loan).paymentDueDate() : IFixedTermLoan(loan).nextPaymentDueDate();

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

    function getSomeCalledOpenTermLoan() internal returns (address loan_) {
        loan_ = getSomeLoan(isCalledOpenTermLoan);
    }

    function getSomeImpairedOpenTermLoan() internal returns (address loan_) {
        loan_ = getSomeLoan(isImpairedOpenTermLoan);
    }

    function isActiveLoan(address loan_) internal view returns (bool isActiveLoan_) {
        isActiveLoan_ = ILoanLike(loan_).principal() > 0;
    }

    function isActiveFixedTermLoan(address loan_) internal view returns (bool isActiveFixedTermLoan_) {
        isActiveFixedTermLoan_ = isFixedTermLoan(loan_) && isActiveLoan(loan_);
    }

    function isActiveOpenTermLoan(address loan_) internal view returns (bool isActiveOpenTermLoan_) {
        isActiveOpenTermLoan_ = isOpenTermLoan(loan_) && isActiveLoan(loan_);
    }

    function isCalledOpenTermLoan(address loan_) internal view returns (bool isCalledOpenTermLoan_) {
        isCalledOpenTermLoan_ = isOpenTermLoan(loan_) && IOpenTermLoan(loan_).isCalled();
    }

    function isImpairedOpenTermLoan(address loan_) internal view returns (bool isImpairedOpenTermLoan_) {
        isImpairedOpenTermLoan_ = isOpenTermLoan(loan_) && IOpenTermLoan(loan_).isImpaired();
    }

    function isWMQueue(address poolManager_) internal view returns (bool isWMQueue_) {
        address wm = IPoolManager(poolManager_).withdrawalManager();

        try IWithdrawalManagerQueue(wm).queue() {
            isWMQueue_ = true;
        } catch { }
    }

    function getAllActiveFixedTermLoans() internal returns (address[] memory loans_) {
        for (uint256 i; i < loans.length; ++i) {
            if (isActiveFixedTermLoan(loans[i])) {
                _fixedTermLoans.push(loans[i]);
            }
        }

        return abi.decode(abi.encode(_fixedTermLoans), (address[]));
    }

    function getAllActiveOpenTermLoans() internal returns (address[] memory loans_) {
        for (uint256 i; i < loans.length; ++i) {
            if (isActiveOpenTermLoan(loans[i])) {
                _openTermLoans.push(loans[i]);
            }
        }

        return abi.decode(abi.encode(_openTermLoans), (address[]));
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

    function setAddresses(address pool) internal {
        _pool        = pool;
        _poolManager = IPool(pool).manager();
        _fundsAsset  = IPool(pool).asset();

        address lm1 = IPoolManager(_poolManager).loanManagerList(0);
        address lm2 = IPoolManager(_poolManager).loanManagerList(1);

        if (_isOpenTermLoanManager(lm1)) {
            _openTermLoanManager  = lm1;
            _fixedTermLoanManager = lm2;
        } else {
            _openTermLoanManager  = lm2;
            _fixedTermLoanManager = lm1;
        }

    }

    function _isOpenTermLoanManager(address loanManager_) internal view returns (bool isOpenTermLoanManager_) {
        try IOpenTermLoanManager(loanManager_).paymentFor(address(0)) {
            isOpenTermLoanManager_ = true;
        } catch { }
    }

}

contract FuzzedSetup is TestBaseWithAssertions, FuzzedUtil {

    function setUp() public virtual override {
        super.setUp();

        setAddresses(address(pool));

        _collateralAsset      = address(collateralAsset);
        _feeManager           = address(fixedTermFeeManager);
        _fixedTermLoanFactory = address(fixedTermLoanFactory);
        _liquidatorFactory    = address(liquidatorFactory);
        _openTermLoanFactory  = address(openTermLoanFactory);

        // Deposit the initial liquidity.
        lps.push(makeAddr("lp1"));
        lps.push(makeAddr("lp2"));
        lps.push(makeAddr("lp3"));
        lps.push(makeAddr("lp4"));
        lps.push(makeAddr("lp5"));

        for (uint256 i; i < lps.length; ++i) {
            deposit(address(pool), lps[i], 100_000_000e6);
        }

    }

}
