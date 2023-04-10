// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IOpenTermLoan,
    IOpenTermLoanManager,
    IGlobals,
    IInvariantTest,
    IMapleProxyFactory,
    IMockERC20,
    IPool,
    IPoolManager,
    IWithdrawalManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { console } from "../../../contracts/Contracts.sol";

import { ProtocolActions } from "../../../contracts/ProtocolActions.sol";

contract OpenTermLoanHandler is ProtocolActions {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    address[] public borrowers;
    address[] public loans;

    uint256 public numLoans;
    uint256 public maxLoans;

    IGlobals             public globals;
    IMapleProxyFactory   public liquidatorFactory;
    IMapleProxyFactory   public loanFactory;
    IMockERC20           public asset;
    IOpenTermLoanManager public loanManager;
    IPool                public pool;
    IPoolManager         public poolManager;

    IInvariantTest testContract;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(address loanFactory_, address liquidatorFactory_, address poolManager_, uint256 maxBorrowers_, uint256 maxLoans_) {
        loanFactory       = IMapleProxyFactory(loanFactory_);
        liquidatorFactory = IMapleProxyFactory(liquidatorFactory_);
        poolManager       = IPoolManager(poolManager_);

        asset        = IMockERC20(poolManager.asset());
        globals      = IGlobals(loanFactory.mapleGlobals());
        loanManager  = IOpenTermLoanManager(poolManager.loanManagerList(1));
        pool         = IPool(poolManager.pool());
        testContract = IInvariantTest(msg.sender);

        for (uint256 i; i < maxBorrowers_; ++i) {
            borrowers.push(makeAddr(string(abi.encode("borrower", i))));
        }

        maxLoans = maxLoans_;
    }

    /**************************************************************************************************************************************/
    /*** Modifiers                                                                                                                      ***/
    /**************************************************************************************************************************************/

    modifier useTimestamps {
        vm.warp(testContract.currentTimestamp());
        _;
        testContract.setCurrentTimestamp(block.timestamp);
    }

    /**************************************************************************************************************************************/
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    // function callLoan(uint256 seed_) external useTimestamps  {
    //     address loan_ = _selectActiveLoan(seed_ = _hash(seed_));

    //     if (loan_ == address(0)) return;

    //     uint256 principal_ = bound(seed_ = _hash(seed_), 1, IOpenTermLoan(loan_).principal());

    //     callLoan(loan_, principal_);
    // }

    function fundLoan(uint256 seed_) external useTimestamps {
        address loan_ = _createLoan(seed_);

        if (loan_ == address(0)) return;

        fundLoan(loan_);
    }

    // TODO: Enable later.
    // function impairLoan(uint256 seed_) external useTimestamps {
    //     address loan_ = _selectActiveLoan(seed_);

    //     if (loan_ == address(0)) return;

    //     impairLoan(loan_);
    // }

    function makePayment(uint256 seed_) external useTimestamps {
        address loan_ = _selectActiveLoan(seed_);

        if (loan_ == address(0)) return;

        makePayment(loan_);
    }

    function triggerDefault(uint256 seed_) external useTimestamps {
        address loan_ = _selectOverdueLoan(seed_);

        if (loan_ == address(0)) return;

        triggerDefault(loan_, address(liquidatorFactory));
    }

    function warp(uint256 seed_) external useTimestamps {
        uint256 timeSpan_ = bound(seed_, 1 days, 15 days);

        vm.warp(block.timestamp + timeSpan_);
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

        address borrower_ = borrowers[bound(seed_ = _hash(seed_), 0, borrowers.length - 1)];

        uint256 availableAssets_ = asset.balanceOf(address(pool));
        uint256 lockedLiquidity_ = IWithdrawalManager(poolManager.withdrawalManager()).lockedLiquidity();

        // Do nothing if there are no assets available for utilization.
        if (availableAssets_ <= lockedLiquidity_) return address(0);

        uint256 principal_ = bound(seed_ = _hash(seed_), 1, availableAssets_ - lockedLiquidity_);

        uint256 noticePeriod_    = 1 weeks;
        uint256 gracePeriod_     = 5 days;
        uint256 paymentInterval_ = bound(seed_ = _hash(seed_), 10 days, 30 days);

        uint256 delegateServiceFeeRate_ = bound(seed_ = _hash(seed_), 0, 0.1e6);
        uint256 interestRate_           = bound(seed_ = _hash(seed_), 1, 0.2e6);
        uint256 lateFeeRate_            = bound(seed_ = _hash(seed_), 0, 0.1e6);
        uint256 lateInterestPremium_    = bound(seed_ = _hash(seed_), 0, 0.1e6);

        uint256[3] memory terms_ = [gracePeriod_, noticePeriod_, paymentInterval_];
        uint256[4] memory rates_ = [delegateServiceFeeRate_, interestRate_, lateFeeRate_, lateInterestPremium_];

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

    function _hash(uint256 number_) internal pure returns (uint256 hash_) {
        hash_ = uint256(keccak256(abi.encode(number_)));
    }

    function _selectActiveLoan(uint256 seed_) internal view returns (address loan_) {
        address[] memory activeLoans_ = _activeLoans({ onlyOverdue_: false });

        if (activeLoans_.length == 0) return address(0);

        loan_ = activeLoans_[bound(seed_, 0, activeLoans_.length - 1)];
    }

    function _selectOverdueLoan(uint256 seed_) internal view returns (address loan_) {
        address[] memory overdueLoans_ = _activeLoans({ onlyOverdue_: true });

        if (overdueLoans_.length == 0) return address(0);

        loan_ = overdueLoans_[bound(seed_, 0, overdueLoans_.length - 1)];
    }

}
