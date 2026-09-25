// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IGlobals,
    IMapleProxyFactory,
    IMockERC20,
    IOpenTermLoan,
    IOpenTermLoanManager,
    IPool,
    IPoolManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { HandlerBase } from "./HandlerBase.sol";

contract OpenTermLoanHandler is HandlerBase {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    address public refinancer;

    uint256 public numLoans;
    uint256 public maxLoans;

    uint256 public totalUnrealizedLosses;

    address[] public borrowers;
    address[] public loans;

    mapping(address => bool) public isDefaulted;
    mapping(address => uint256) public unrealizedLossesByLoan;
    mapping(address => uint256) public poolIndexOf;

    IGlobals public globals;
    IMapleProxyFactory public loanFactory;
    IMockERC20 public asset;

    IOpenTermLoanManager[] public loanManagers;
    IPool[] public pools;
    IPoolManager[] public poolManagers;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(
        string memory handlerName_,
        address loanFactory_,
        address refinancer_,
        address[] memory poolManagers_,
        address[] memory borrowers_,
        uint256 maxLoans_
    )
        HandlerBase(handlerName_)
    {
        loanFactory = IMapleProxyFactory(loanFactory_);

        asset = IMockERC20(IPoolManager(poolManagers_[0]).asset());

        for (uint256 i; i < poolManagers_.length; ++i) {
            IPoolManager poolManager_ = IPoolManager(poolManagers_[i]);

            require(poolManager_.asset() == address(asset), "OTLH:INVALID_ASSET");

            poolManagers.push(poolManager_);
            loanManagers.push(IOpenTermLoanManager(poolManager_.strategyList(0)));
            pools.push(IPool(poolManager_.pool()));
        }

        globals = IGlobals(loanFactory.mapleGlobals());

        refinancer = refinancer_;
        borrowers  = borrowers_;
        maxLoans   = maxLoans_;
    }

    /**************************************************************************************************************************************/
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function callLoan(uint256 seed_) external {
        address loan_ = _selectActiveLoan(seed_);

        if (loan_ == address(0)) {
            _recordSkip();
            return;
        }

        uint256 principal_ = _bound(_randomize(seed_, ""), 1, IOpenTermLoan(loan_).principal());

        callLoan(loan_, principal_);
    }

    function fundLoan(uint256 seed_) public {
        address loan_ = _createLoan(seed_);

        if (loan_ == address(0)) {
            _recordSkip();
            return;
        }

        fundLoan(loan_);
    }

    function impairLoan(uint256 seed_) external {
        address loan_ = _selectActiveLoan(seed_);

        if (loan_ == address(0)) {
            _recordSkip();
            return;
        }

        if (isDefaulted[loan_]) {
            _recordSkip();
            return;
        }

        if (unrealizedLossesByLoan[loan_] != 0) {
            _recordSkip();
            return;
        }

        uint256 principal_   = IOpenTermLoan(loan_).principal();
        uint256 netInterest_ = _getLoanInterest(loan_);

        totalUnrealizedLosses        += principal_ + netInterest_;
        unrealizedLossesByLoan[loan_] = principal_ + netInterest_;

        address caller_ = _selectCaller(seed_, loan_);

        impairLoan(loan_, caller_);
    }

    function makePayment(uint256 seed_) public {
        address loan_ = _selectActiveLoan(seed_);

        if (loan_ == address(0)) {
            _recordSkip();
            return;
        }

        makePayment(loan_);

        totalUnrealizedLosses        -= unrealizedLossesByLoan[loan_];
        unrealizedLossesByLoan[loan_] = 0;
    }

    function refinance(uint256 seed_) public {
        address loan_ = _selectActiveLoan(seed_);

        if (loan_ == address(0)) {
            _recordSkip();
            return;
        }

        (bytes[] memory calls_, int256 principalDelta_) = _generateRefinanceCalls(_randomize(seed_, "refinance"), loan_);

        (, uint256 interest_, uint256 lateInterest_, uint256 delegateServiceFee_, uint256 platformServiceFee_) =
            IOpenTermLoan(loan_).getPaymentBreakdown(block.timestamp);

        uint256 amountToReturn_ = interest_ + lateInterest_ + delegateServiceFee_ + platformServiceFee_;

        // If the principal is decreased the borrower must return the decreased amount.
        if (principalDelta_ < 0) {
            amountToReturn_ += uint256(principalDelta_ * -1);
        }
        // If principal is increased the borrower deducts fees/interest from the increased amount.
        // This can result in all fees/interest being covered by the increased principal.
        else if (principalDelta_ > 0) {
            amountToReturn_ = uint256(principalDelta_) < amountToReturn_ ? amountToReturn_ - uint256(principalDelta_) : 0;
        }

        address borrower_ = IOpenTermLoan(loan_).borrower();

        if (amountToReturn_ > 0) {
            erc20_mint(address(asset), borrower_, amountToReturn_);
            erc20_approve(address(asset), borrower_, loan_, amountToReturn_);
        }

        proposeRefinance(loan_, refinancer, block.timestamp, calls_);
        acceptRefinanceOT(loan_, refinancer, block.timestamp, calls_);

        totalUnrealizedLosses        -= unrealizedLossesByLoan[loan_];
        unrealizedLossesByLoan[loan_] = 0;
    }

    function removeLoanCall(uint256 seed_) external {
        address loan_ = _selectCalledLoan(seed_);

        if (loan_ == address(0)) {
            _recordSkip();
            return;
        }

        removeLoanCall(loan_);
    }

    function removeLoanImpairment(uint256 seed_) external {
        address loan_ = _selectImpairedLoan(seed_);

        if (loan_ == address(0)) {
            _recordSkip();
            return;
        }

        removeLoanImpairment(loan_, globals.governor());

        totalUnrealizedLosses        -= unrealizedLossesByLoan[loan_];
        unrealizedLossesByLoan[loan_] = 0;
    }

    function triggerDefault(uint256 seed_) external {
        address loan_ = _selectOverdueLoan(seed_);

        if (loan_ == address(0)) {
            _recordSkip();
            return;
        }

        address caller_ = _selectCaller(seed_, loan_);

        if (unrealizedLossesByLoan[loan_] != 0) {
            // Unrealized losses become realized losses when the loan is triggered default.
            totalUnrealizedLosses        -= unrealizedLossesByLoan[loan_];
            unrealizedLossesByLoan[loan_] = 0;
        }

        isDefaulted[loan_] = true;

        triggerDefault(loan_, caller_);
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _activeLoans(bool onlyOverdue_) internal view returns (address[] memory activeLoans_) {
        uint256 index_;
        uint256 length_;

        for (uint256 i; i < loans.length; ++i) {
            if (!_isActive(loans[i], onlyOverdue_)) continue;

            length_++;
        }

        activeLoans_ = new address[](length_);

        for (uint256 i; i < loans.length; ++i) {
            if (!_isActive(loans[i], onlyOverdue_)) continue;

            activeLoans_[index_++] = loans[i];
        }
    }

    function _buildRefinanceCalls(
        uint256 seed_,
        uint256 principalIncrease_,
        uint256 principalDecrease_
    )
        internal
        pure
        returns (bytes[] memory calls_)
    {
        (uint256[3] memory terms_, uint256[4] memory rates_) = _getLoanParams(seed_);

        calls_ = new bytes[](9);

        // Create an array of arguments, even if not all will be used
        calls_[0] = abi.encodeWithSignature("decreasePrincipal(uint256)", principalDecrease_);
        calls_[1] = abi.encodeWithSignature("increasePrincipal(uint256)", principalIncrease_);
        calls_[2] = abi.encodeWithSignature("setGracePeriod(uint32)", terms_[0]);
        calls_[3] = abi.encodeWithSignature("setNoticePeriod(uint32)", terms_[1]);
        calls_[4] = abi.encodeWithSignature("setPaymentInterval(uint32)", terms_[2]);
        calls_[5] = abi.encodeWithSignature("setDelegateServiceFeeRate(uint64)", rates_[0]);
        calls_[6] = abi.encodeWithSignature("setInterestRate(uint64)", rates_[1]);
        calls_[7] = abi.encodeWithSignature("setLateFeeRate(uint64)", rates_[2]);
        calls_[8] = abi.encodeWithSignature("setLateInterestPremiumRate(uint64)", rates_[3]);
    }

    function _createLoan(uint256 seed_) internal returns (address loan_) {
        // Do nothing if the maximum number of loans has already been created.
        if (loans.length >= maxLoans) return address(0);

        uint256 poolIndex_ = _selectPoolIndex(seed_);

        // Do nothing if no pool has any deposits yet.
        if (poolIndex_ == type(uint256).max) return address(0);

        IPool pool_ = pools[poolIndex_];

        address borrower_  = borrowers[_bound(_randomize(seed_, "borrower"), 0, borrowers.length - 1)];
        uint256 principal_ = _getPrincipalIncrease(seed_, pool_);

        // Do nothing if there are no assets available for utilization.
        if (principal_ == 0) return address(0);

        (uint256[3] memory terms_, uint256[4] memory rates_) = _getLoanParams(seed_);

        loan_ = createOpenTermLoan(
            address(loanFactory), borrower_, address(loanManagers[poolIndex_]), address(asset), principal_, terms_, rates_
        );

        loans.push(loan_);
        poolIndexOf[loan_] = poolIndex_;
        numLoans++;
    }

    function _generateRefinanceCalls(uint256 seed_, address loan_) internal returns (bytes[] memory data_, int256 principalDelta_) {
        // Get how many calls will be done
        uint256 numberOfCalls = _randomize(seed_, "numberOfCalls") % 9 + 1; // 9 functions on refi contract (1 - 9)

        uint256 principalIncrease = _getPrincipalIncrease(seed_, pools[poolIndexOf[loan_]]);
        uint256 principalDecrease = _bound(_randomize(seed_, "decrease"), 0, IOpenTermLoan(loan_).principal() - 1);

        bytes[] memory calls = _buildRefinanceCalls(seed_, principalIncrease, principalDecrease);

        data_ = new bytes[](numberOfCalls);

        bool[9] memory callUsed_;

        uint256 principalIncreased;
        uint256 principalDecreased;

        for (uint256 i = 0; i < numberOfCalls; i++) {
            // Get a random index, so calls happen in different orders every time. Can cause repeated calls, but that's ok.
            uint256 index = _randomize(seed_, string(abi.encode(i))) % calls.length;

            // If index is already used for decrease or increase principal find another.
            if (callUsed_[index] && (index == 0 || index == 1)) index = _bound(_randomize(seed_, string(abi.encode(i))), 2, 8);

            // If index is 0 or 1, we need to update the principalIncrease and Decrease
            if (index == 0 && !callUsed_[0]) principalDecreased += principalDecrease;
            if (index == 1 && !callUsed_[1]) principalIncreased += principalIncrease;

            data_[i]         = calls[index];
            callUsed_[index] = true;
        }

        principalDelta_ = int256(principalIncreased) - int256(principalDecreased);
    }

    function _getLoanInterest(address loan_) internal view returns (uint256 netInterest_) {
        (uint256 platformManagementFeeRate_, uint256 delegateManagementFeeRate_,,) =
            IOpenTermLoanManager(IOpenTermLoan(loan_).lender()).paymentFor(loan_);

        uint256 startTime_ = IOpenTermLoan(loan_).datePaid() != 0 ? IOpenTermLoan(loan_).datePaid() : IOpenTermLoan(loan_).dateFunded();

        uint256 grossInterest_ =
            IOpenTermLoan(loan_).principal() * IOpenTermLoan(loan_).interestRate() * (block.timestamp - startTime_) / (365 days * 1e6);

        netInterest_ = grossInterest_ * (1e6 - delegateManagementFeeRate_ - platformManagementFeeRate_) / 1e6;
    }

    function _getLoanParams(uint256 seed_) internal pure returns (uint256[3] memory terms_, uint256[4] memory rates_) {
        uint256 noticePeriod_    = _bound(_randomize(seed_, "noticePeriod"), 1, 30 days);
        uint256 gracePeriod_     = _bound(_randomize(seed_, "gracePeriod"), 0, 30 days);
        uint256 paymentInterval_ = _bound(_randomize(seed_, "paymentInterval"), 1 hours, 30 days);

        uint256 delegateServiceFeeRate_ = _bound(_randomize(seed_, "delegateService"), 0, 0.1e6);
        uint256 interestRate_           = _bound(_randomize(seed_, "interestRate"), 0, 0.2e6);
        uint256 lateFeeRate_            = _bound(_randomize(seed_, "lateFeeRate"), 0, 0.1e6);
        uint256 lateInterestPremium_    = _bound(_randomize(seed_, "lateInterest"), 0, 0.1e6);

        terms_ = [gracePeriod_, noticePeriod_, paymentInterval_];
        rates_ = [delegateServiceFeeRate_, interestRate_, lateFeeRate_, lateInterestPremium_];
    }

    function _getPrincipalIncrease(uint256 seed_, IPool pool_) internal view returns (uint256 principal_) {
        uint256 availableAssets_ = asset.balanceOf(address(pool_)) / 2;

        // Do nothing if there are no assets available for utilization.
        if (availableAssets_ == 0) return 0;

        principal_ = _bound(_randomize(seed_, "principal"), 1, availableAssets_);
    }

    function _isActive(address loan_, bool onlyOverdue_) internal view returns (bool filter_) {
        // Don't include loans that are not active.
        if (IOpenTermLoan(loan_).dateFunded() == 0) return false;

        // Only include loans that are overdue (if the flag is set).
        if (!onlyOverdue_ || block.timestamp > IOpenTermLoan(loan_).defaultDate()) return true;
    }

    function _selectActiveLoan(uint256 seed_) internal view returns (address loan_) {
        address[] memory activeLoans_ = _activeLoans({
            onlyOverdue_: false
        });

        if (activeLoans_.length == 0) return address(0);

        loan_ = activeLoans_[_bound(seed_, 0, activeLoans_.length - 1)];
    }

    function _selectCalledLoan(uint256 seed_) internal view returns (address loan_) {
        uint256 index_;
        uint256 length_;
        address[] memory calledLoans_;

        for (uint256 i; i < loans.length; ++i) {
            if (IOpenTermLoan(loans[i]).dateCalled() != 0) length_++;
        }

        calledLoans_ = new address[](length_);

        for (uint256 i; i < loans.length; ++i) {
            if (IOpenTermLoan(loans[i]).dateCalled() != 0) calledLoans_[index_++] = loans[i];
        }

        if (calledLoans_.length == 0) return address(0);

        loan_ = calledLoans_[_bound(seed_, 0, calledLoans_.length - 1)];
    }

    function _selectCaller(uint256 seed_, address loan_) internal view returns (address caller_) {
        caller_ = seed_ % 2 == 0 ? poolManagers[poolIndexOf[loan_]].poolDelegate() : globals.governor();
    }

    function _selectImpairedLoan(uint256 seed_) internal view returns (address loan_) {
        uint256 index_;
        uint256 length_;
        address[] memory impairedLoans_;

        for (uint256 i; i < loans.length; ++i) {
            if (IOpenTermLoan(loans[i]).dateImpaired() != 0) length_++;
        }

        impairedLoans_ = new address[](length_);

        for (uint256 i; i < loans.length; ++i) {
            if (IOpenTermLoan(loans[i]).dateImpaired() != 0) impairedLoans_[index_++] = loans[i];
        }

        if (impairedLoans_.length == 0) return address(0);

        loan_ = impairedLoans_[_bound(seed_, 0, impairedLoans_.length - 1)];
    }

    function _selectOverdueLoan(uint256 seed_) internal view returns (address loan_) {
        address[] memory overdueLoans_ = _activeLoans({
            onlyOverdue_: true
        });

        if (overdueLoans_.length == 0) return address(0);

        loan_ = overdueLoans_[_bound(seed_, 0, overdueLoans_.length - 1)];
    }

    function _selectPoolIndex(uint256 seed_) internal view returns (uint256 index_) {
        uint256 start_ = _bound(_randomize(seed_, "pool"), 0, pools.length - 1);

        for (uint256 i; i < pools.length; ++i) {
            uint256 candidate_ = (start_ + i) % pools.length;

            if (pools[candidate_].totalSupply() != 0) return candidate_;
        }

        return type(uint256).max;
    }

}
