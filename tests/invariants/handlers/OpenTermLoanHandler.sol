// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IGlobals,
    IInvariantTest,
    IMapleProxyFactory,
    IMockERC20,
    IOpenTermLoan,
    IOpenTermLoanManager,
    IPool,
    IPoolManager,
    IWithdrawalManagerCyclical as IWithdrawalManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { console2 as console } from "../../../contracts/Contracts.sol";

import { HandlerBase } from "./HandlerBase.sol";

contract OpenTermLoanHandler is HandlerBase {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    address public refinancer;

    uint256 public numLoans;
    uint256 public maxLoans;

    address[] public borrowers;
    address[] public loans;

    IGlobals             public globals;
    IMapleProxyFactory   public liquidatorFactory;
    IMapleProxyFactory   public loanFactory;
    IMockERC20           public asset;
    IOpenTermLoanManager public loanManager;
    IPool                public pool;
    IPoolManager         public poolManager;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(
        address loanFactory_,
        address liquidatorFactory_,
        address poolManager_,
        address refinancer_,
        uint256 maxBorrowers_,
        uint256 maxLoans_
    )
    {
        loanFactory       = IMapleProxyFactory(loanFactory_);
        liquidatorFactory = IMapleProxyFactory(liquidatorFactory_);
        poolManager       = IPoolManager(poolManager_);

        asset        = IMockERC20(poolManager.asset());
        globals      = IGlobals(loanFactory.mapleGlobals());
        loanManager  = IOpenTermLoanManager(poolManager.loanManagerList(1));
        pool         = IPool(poolManager.pool());
        testContract = IInvariantTest(msg.sender);

        refinancer = refinancer_;

        for (uint256 i; i < maxBorrowers_; ++i) {
            borrowers.push(makeAddr(string(abi.encode("borrower", i))));
        }

        maxLoans = maxLoans_;
    }

    /**************************************************************************************************************************************/
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function callLoan(uint256 seed_) external useTimestamps {
        console.log("otlHandler.callLoan(%s)", seed_);

        numberOfCalls["callLoan"]++;

        address loan_ = _selectActiveLoan(seed_);

        if (loan_ == address(0)) return;

        uint256 principal_ = _bound(_hash(seed_, ""), 1, IOpenTermLoan(loan_).principal());

        callLoan(loan_, principal_);
    }

    function fundLoan(uint256 seed_) public useTimestamps {
        console.log("otlHandler.fundLoan(%s)", seed_);

        numberOfCalls["fundLoan"]++;

        address loan_ = _createLoan(seed_);

        if (loan_ == address(0)) return;

        fundLoan(loan_);
    }

    function impairLoan(uint256 seed_) external useTimestamps {
        console.log("otlHandler.impairLoan(%s)", seed_);

        numberOfCalls["impairLoan"]++;

        address loan_ = _selectActiveLoan(seed_);

        if (loan_ == address(0)) return;

        address caller_ = _selectCaller(seed_);

        impairLoan(loan_, caller_);
    }

    function makePayment(uint256 seed_) public useTimestamps {
        console.log("otlHandler.makePayment(%s)", seed_);

        numberOfCalls["makePayment"]++;

        address loan_ = _selectActiveLoan(seed_);

        if (loan_ == address(0)) return;

        makePayment(loan_);
    }

    function refinance(uint256 seed_) public useTimestamps {
        console.log("otlHandler.refinance(%s)", seed_);

        numberOfCalls["refinance"]++;

        address loan_ = _selectActiveLoan(seed_);

        if (loan_ == address(0)) return;

        bytes[] memory calls_ = _generateRefinanceCalls(_hash(seed_, "refinance"), loan_);

        proposeRefinance(loan_, refinancer, block.timestamp, calls_);

        acceptRefinanceOT(loan_, refinancer, block.timestamp, calls_);
    }

    function removeLoanCall(uint256 seed_) external useTimestamps {
        numberOfCalls["removeLoanCall"]++;

        address loan_ = _selectCalledLoan(seed_);

        if (loan_ == address(0)) return;

        removeLoanCall(loan_);
    }

    function removeLoanImpairment(uint256 seed_) external useTimestamps {
        numberOfCalls["removeLoanImpairment"]++;

        address loan_ = _selectImpairedLoan(seed_);

        if (loan_ == address(0)) return;

        address caller_ = _selectCaller(seed_);

        removeLoanImpairment(loan_, caller_);
    }

    function triggerDefault(uint256 seed_) external useTimestamps {
        numberOfCalls["triggerDefault"]++;

        address loan_ = _selectOverdueLoan(seed_);

        if (loan_ == address(0)) return;

        address caller_ = _selectCaller(seed_);

        triggerDefault(loan_, address(liquidatorFactory), caller_);
    }

    function warp(uint256 seed_) public useTimestamps {
        console.log("otlHandler.warp(%s)", seed_);

        numberOfCalls["warp"]++;

        uint256 warpAmount_ = _bound(seed_, 1 days, 15 days);

        console.log("warp():", warpAmount_);

        vm.warp(block.timestamp + warpAmount_);
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _activeLoans(bool onlyOverdue_) internal view returns (address[] memory activeLoans_) {
        uint256 index_;
        uint256 length_;

        for (uint256 i; i < loans.length; ++i) {
            if (!_filterLoan(loans[i], onlyOverdue_)) continue;

            length_++;
        }

        activeLoans_ = new address[](length_);

        for (uint256 i; i < loans.length; ++i) {
            if (!_filterLoan(loans[i], onlyOverdue_)) continue;

            activeLoans_[index_++] = loans[i];
        }
    }

    function _createLoan(uint256 seed_) internal returns (address loan_) {
        // Do nothing if the maximum number of loans has already been created.
        if (loans.length >= maxLoans) return address(0);

        // Do nothing if no deposits have been made yet.
        if (pool.totalSupply() == 0) return address(0);

        address borrower_  = borrowers[_bound(_hash(seed_, "borrower"), 0, borrowers.length - 1)];
        uint256 principal_ = _getPrincipalIncrease(seed_);

        // Do nothing if there are no assets available for utilization.
        if (principal_ == 0) return address(0);

        ( uint256[3] memory terms_, uint256[4] memory rates_ ) = _getLoanParams(seed_);

        loan_ = createOpenTermLoan(
            address(loanFactory),
            borrower_,
            address(loanManager),
            address(asset),
            principal_,
            terms_,
            rates_
        );

        loans.push(loan_);
        numLoans++;
    }

    // TODO: Rename this function as the filter criteria is unclear.
    function _filterLoan(address loan_, bool onlyOverdue_) internal view returns (bool filter_) {
        // Don't include loans that are not active.
        if (IOpenTermLoan(loan_).dateFunded() == 0) return false;

        // Only include loans that are overdue (if the flag is set).
        if (!onlyOverdue_ || block.timestamp > IOpenTermLoan(loan_).defaultDate()) return true;
    }

    function _getLoanParams(uint256 seed_) internal pure returns (uint256[3] memory terms_, uint256[4] memory rates_) {
        uint256 noticePeriod_    = _bound(_hash(seed_, "noticePeriod"),    0,       30 days);
        uint256 gracePeriod_     = _bound(_hash(seed_, "gracePeriod"),     0,       30 days);
        uint256 paymentInterval_ = _bound(_hash(seed_, "paymentInterval"), 1 hours, 30 days);

        uint256 delegateServiceFeeRate_ = _bound(_hash(seed_, "delegateService"), 0, 0.1e6);
        uint256 interestRate_           = _bound(_hash(seed_, "interestRate"),    1, 0.2e6);
        uint256 lateFeeRate_            = _bound(_hash(seed_, "lateFeeRate"),     0, 0.1e6);
        uint256 lateInterestPremium_    = _bound(_hash(seed_, "lateInterest"),    0, 0.1e6);

        terms_ = [gracePeriod_, noticePeriod_, paymentInterval_];
        rates_ = [delegateServiceFeeRate_, interestRate_, lateFeeRate_, lateInterestPremium_];
    }

    function _generateRefinanceCalls(uint256 seed_, address loan_) internal view returns (bytes[] memory data_) {
        // Get how many calls will be done
        uint256 numberOfCalls = _hash(seed_, "numberOfCalls") % 10; // 9 functions on refi contract (0 - 9)

        // Generate completely new loan parameters
        ( uint256[3] memory terms_, uint256[4] memory rates_ ) = _getLoanParams(seed_);

        uint256 principalIncrease = _getPrincipalIncrease(seed_);
        uint256 principalDecrease =  _bound(_hash(seed_, "decrease"), 0, IOpenTermLoan(loan_).principal() - 1);

        bytes[] memory calls = new bytes[](9);

        // Create an array of arguments, even if not all will be used
        calls[0] = abi.encodeWithSignature("decreasePrincipal(uint256)",         principalIncrease);
        calls[1] = abi.encodeWithSignature("increasePrincipal(uint256)",         principalDecrease);
        calls[2] = abi.encodeWithSignature("setGracePeriod(uint32)",             terms_[0]);
        calls[3] = abi.encodeWithSignature("setNoticePeriod(uint32)",            terms_[1]);
        calls[4] = abi.encodeWithSignature("setPaymentInterval(uint32)",         terms_[2]);
        calls[5] = abi.encodeWithSignature("setDelegateServiceFeeRate(uint64)",  rates_[0]);
        calls[6] = abi.encodeWithSignature("setInterestRate(uint64)",            rates_[1]);
        calls[7] = abi.encodeWithSignature("setLateFeeRate(uint64)",             rates_[2]);
        calls[8] = abi.encodeWithSignature("setLateInterestPremiumRate(uint64)", rates_[3]);

        data_ = new bytes[](numberOfCalls);

        for (uint i = 0; i < numberOfCalls; i++) {
            // Get a random index, so calls happen in different orders every time. Can cause repeated calls, but that's ok.
            uint256 index = _hash(seed_, string(abi.encode(i))) % calls.length;

            data_[i] = calls[index];
        }
    }

    function _getPrincipalIncrease(uint256 seed_) internal view returns (uint256 principal_) {
        uint256 availableAssets_ = asset.balanceOf(address(pool));
        uint256 lockedLiquidity_ = IWithdrawalManager(poolManager.withdrawalManager()).lockedLiquidity();

        // Do nothing if there are no assets available for utilization.
        if (availableAssets_ <= lockedLiquidity_) return 0;

        principal_ = _bound(_hash(seed_, "principal"), 1, availableAssets_ - lockedLiquidity_);
    }

    function _hash(uint256 number_, string memory salt) internal pure returns (uint256 hash_) {
        hash_ = uint256(keccak256(abi.encode(number_, salt)));
    }

    function _selectActiveLoan(uint256 seed_) internal view returns (address loan_) {
        address[] memory activeLoans_ = _activeLoans({ onlyOverdue_: false });

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

    function _selectCaller(uint256 seed_) internal view returns (address caller_) {
        caller_ = seed_ % 2 == 0 ? poolManager.poolDelegate() : globals.governor();
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
        address[] memory overdueLoans_ = _activeLoans({ onlyOverdue_: true });

        if (overdueLoans_.length == 0) return address(0);

        loan_ = overdueLoans_[_bound(seed_, 0, overdueLoans_.length - 1)];
    }

}
