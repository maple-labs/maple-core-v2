// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { Address, console, TestUtils } from "../../../modules/contract-test-utils/contracts/test.sol";
import { MockERC20 }                   from "../../../modules/erc20/contracts/test/mocks/MockERC20.sol";
import { IMapleGlobals }               from "../../../modules/globals-v2/contracts/interfaces/IMapleGlobals.sol";
import { MapleLoanInitializer }        from "../../../modules/loan/contracts/MapleLoanInitializer.sol";
import { IMapleLoan }                  from "../../../modules/loan/contracts/interfaces/IMapleLoan.sol";
import { IMapleLoanFactory }           from "../../../modules/loan/contracts/interfaces/IMapleLoanFactory.sol";
import { ILoanManager }                from "../../../modules/pool-v2/contracts/interfaces/ILoanManager.sol";
import { IPool }                       from "../../../modules/pool-v2/contracts/interfaces/IPool.sol";
import { IPoolManager }                from "../../../modules/pool-v2/contracts/interfaces/IPoolManager.sol";
import { IWithdrawalManager }          from "../../../modules/withdrawal-manager/contracts/interfaces/IWithdrawalManager.sol";

import { ITest } from "../interfaces/ITest.sol";

contract LoanHandler is TestUtils {

    /******************************************************************************************************************************/
    /*** State Variables                                                                                                        ***/
    /******************************************************************************************************************************/

    // Actors
    address poolDelegate;

    address[] borrowers;

    // Contract addresses
    address feeManager;
    address globals;
    address governor;
    address loanFactory;

    // Debugging
    uint256 public numBorrowers;
    uint256 public numCalls;
    uint256 public numLatePayments;
    uint256 public numLoans;
    uint256 public numMatures;
    uint256 public numPayments;

    mapping(bytes32 => uint256) public numberOfCalls;

    // Contract instances
    MockERC20 collateralAsset;
    MockERC20 fundsAsset;

    ILoanManager loanManager;
    IPool        pool;
    IPoolManager poolManager;
    ITest        testContract;

    /******************************************************************************************************************************/
    /*** State Variables for Invariant Assertions                                                                               ***/
    /******************************************************************************************************************************/

    // Contract references
    address[] public activeLoans;

    // Summed values
    uint256 public sum_loan_principal;
    uint256 public sum_loanManager_paymentIssuanceRate;

    // Max values
    uint256 maxLoans;

    // Loan info
    uint256 public earliestPaymentDueDate;

    mapping (address => uint256) public fundingTime;
    mapping (address => uint256) public lateIntervalInterest;
    mapping (address => uint256) public paymentTimestamp;

    /******************************************************************************************************************************/
    /*** Constructor                                                                                                            ***/
    /******************************************************************************************************************************/

    constructor (
        address collateralAsset_,
        address feeManager_,
        address fundsAsset_,
        address globals_,
        address governor_,
        address loanFactory_,
        address poolManager_,
        address testContract_,
        uint256 numBorrowers_,
        uint256 maxLoans_
    ) {
        feeManager  = feeManager_;
        globals     = globals_;
        governor    = governor_;
        loanFactory = loanFactory_;

        collateralAsset = MockERC20(collateralAsset_);
        fundsAsset      = MockERC20(fundsAsset_);
        poolManager     = IPoolManager(poolManager_);
        loanManager     = ILoanManager(poolManager.loanManagerList(0));
        pool            = IPool(poolManager.pool());
        testContract    = ITest(testContract_);

        poolDelegate = address(new Address());

        earliestPaymentDueDate = testContract.currentTimestamp();

        for (uint256 i = 0; i < numBorrowers_; i++) {
            address borrower = address(new Address());
            vm.prank(governor);
            IMapleGlobals(globals).setValidBorrower(borrower, true);
            borrowers.push(borrower);
        }

        numBorrowers = numBorrowers_;
        maxLoans     = maxLoans_;
    }

    /******************************************************************************************************************************/
    /*** Modifiers                                                                                                              ***/
    /******************************************************************************************************************************/

    modifier useTimestamps() {
        vm.warp(testContract.currentTimestamp());
        _;
        testContract.setCurrentTimestamp(block.timestamp);
    }

    /******************************************************************************************************************************/
    /*** Pool Functions                                                                                                         ***/
    /******************************************************************************************************************************/

    function createLoanAndFund(
        uint256 borrowerIndexSeed_,
        uint256[3] memory termDetails_,
        uint256[3] memory amounts_,
        uint256[4] memory rates_,
        uint256[2] memory fees_
    ) external useTimestamps {
        numCalls++;

        if (numLoans > maxLoans) return;

        address borrower_ = borrowers[constrictToRange(borrowerIndexSeed_, 0, numBorrowers - 1)];

        termDetails_[0] = constrictToRange(termDetails_[0], 0,      30 days);   // Grace period
        termDetails_[1] = constrictToRange(termDetails_[1], 1 days, 730 days);  // Payment interval
        termDetails_[2] = constrictToRange(termDetails_[2], 1,      30);        // Number of payments

        amounts_[0] = constrictToRange(amounts_[0], 0,        1e29);         // Collateral required
        amounts_[1] = constrictToRange(amounts_[1], 10_000e6, 1e29);         // Principal requested
        amounts_[2] = constrictToRange(amounts_[2], 0,        amounts_[1]);  // Ending principal

        rates_[0] = constrictToRange(rates_[0], 0.0001e18, 0.5e18);  // Interest rate
        rates_[1] = constrictToRange(rates_[1], 0.0001e18, 1.0e18);  // Closing fee rate
        rates_[2] = constrictToRange(rates_[2], 0.0001e18, 0.6e18);  // Late fee rate
        rates_[3] = constrictToRange(rates_[3], 0.0001e18, 0.2e18);  // Late interest premium

        fees_[0] = constrictToRange(fees_[0], 0, amounts_[1] / 10);  // Delegate origination fee
        fees_[1] = constrictToRange(fees_[1], 0, amounts_[1] / 10);  // Delegate service fee

        if (
            pool.totalSupply() == 0 ||
            fundsAsset.balanceOf(address(pool)) - IWithdrawalManager(poolManager.withdrawalManager()).lockedLiquidity() < amounts_[1]
        ) return;

        vm.startPrank(borrower_);
        address loan_ = IMapleLoanFactory(loanFactory).createInstance({
            arguments_: new MapleLoanInitializer().encodeArguments({
                borrower_:    borrower_,
                feeManager_:  feeManager,
                assets_:      [address(collateralAsset), address(fundsAsset)],
                termDetails_: termDetails_,
                amounts_:     amounts_,
                rates_:       rates_,
                fees_:        fees_
            }),
            salt_: "SALT"
        });
        vm.stopPrank();

        vm.startPrank(poolManager.poolDelegate());
        poolManager.fund(amounts_[1], loan_, address(loanManager));
        vm.stopPrank();

        fundingTime[loan_] = block.timestamp;

        uint256 nextPaymentDueDate_ = IMapleLoan(loan_).nextPaymentDueDate();

        uint256 paymentWithEarliestDueDate = loanManager.paymentWithEarliestDueDate();

        if (paymentWithEarliestDueDate != 0) {
            ( , , earliestPaymentDueDate ) = loanManager.sortedPayments(loanManager.paymentWithEarliestDueDate());
        } else {
            earliestPaymentDueDate = block.timestamp;
        }

        require(earliestPaymentDueDate == loanManager.domainEnd());

        ( , , , , , , uint256 issuanceRate ) = loanManager.payments(loanManager.paymentIdOf(address(loan_)));

        sum_loan_principal                  += IMapleLoan(loan_).principal();
        sum_loanManager_paymentIssuanceRate += issuanceRate;

        activeLoans.push(loan_);
        numLoans++;

        numberOfCalls["createLoanAndFund"]++;
    }

    function makePayment(uint256 borrowerIndexSeed_, uint256 loanIndexSeed_) public virtual useTimestamps {
        numCalls++;

        if (activeLoans.length == 0) return;

        uint256 loanIndex_ = constrictToRange(loanIndexSeed_, 0, activeLoans.length - 1);

        address borrower_ = borrowers[constrictToRange(borrowerIndexSeed_, 0, numBorrowers - 1)];

        vm.startPrank(borrower_);

        IMapleLoan loan_ = IMapleLoan(activeLoans[loanIndex_]);

        uint256 previousPaymentDueDate = loan_.nextPaymentDueDate();

        ( uint256 principal_, uint256 interest_, uint256 fees_ ) = loan_.getNextPaymentBreakdown();

        uint256 amount_ = principal_ + interest_ + fees_;

        fundsAsset.mint(borrower_, amount_);
        fundsAsset.approve(address(loan_), amount_);

        ( , , , , , , uint256 issuanceRate ) = loanManager.payments(loanManager.paymentIdOf(address(loan_)));

        sum_loan_principal                  -= loan_.principal();
        sum_loanManager_paymentIssuanceRate -= issuanceRate;

        loan_.makePayment(amount_);

        numPayments++;

        vm.stopPrank();

        uint256 nextPaymentDueDate_ = loan_.nextPaymentDueDate();

        uint256 paymentWithEarliestDueDate = loanManager.paymentWithEarliestDueDate();

        if (paymentWithEarliestDueDate != 0) {
            ( , , earliestPaymentDueDate ) = loanManager.sortedPayments(loanManager.paymentWithEarliestDueDate());
        } else {
            earliestPaymentDueDate = block.timestamp;
        }

        require(earliestPaymentDueDate == loanManager.domainEnd(), "Not equal");

        if (loan_.paymentsRemaining() == 0) {
            activeLoans[loanIndex_] = activeLoans[activeLoans.length - 1];
            activeLoans.pop();
            numLoans--;
            numMatures++;
            return;
        }

        if (block.timestamp > previousPaymentDueDate) {
            numLatePayments++;
        }

        paymentTimestamp[address(loan_)] = block.timestamp;

        ( , interest_, ) = loan_.getNextPaymentBreakdown();

        uint256 netInterest = interest_ * (1e6 - IMapleGlobals(globals).platformManagementFeeRate(address(poolManager)) - poolManager.delegateManagementFeeRate()) / 1e6;

        ( , , , , , , issuanceRate ) = loanManager.payments(loanManager.paymentIdOf(address(loan_)));

        sum_loan_principal                  += loan_.principal();
        sum_loanManager_paymentIssuanceRate += issuanceRate;

        numberOfCalls["makePayment"]++;
    }

    function warp(uint256 warpAmount_) external useTimestamps {
        numCalls++;

        warpAmount_ = constrictToRange(warpAmount_, 0, 10 days);

        vm.warp(block.timestamp + warpAmount_);
    }

    function max(uint256 a_, uint256 b_) internal pure returns (uint256 maximum_) {
        maximum_ = a_ > b_ ? a_ : b_;
    }

    function min(uint256 a_, uint256 b_) internal pure returns (uint256 minimum_) {
        minimum_ = a_ < b_ ? a_ : b_;
    }

}

