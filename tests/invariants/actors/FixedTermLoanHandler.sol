// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IFeeManager,
    IFixedTermLoan,
    IFixedTermLoanManager,
    IGlobals,
    IInvariantTest,
    ILiquidator,
    ILoanLike,
    IMapleProxyFactory,
    IPool,
    IPoolManager,
    IProxyFactoryLike,
    IWithdrawalManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { console2, MockERC20 } from "../../../contracts/Contracts.sol";

import { HandlerBase } from "./HandlerBase.sol";

// TODO: Reorder functions alphabetically

contract FixedTermLoanHandler is HandlerBase {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    uint256 constant internal MAX_LOANS = 20;

    // Actors
    address poolDelegate;

    // Contract addresses
    address feeManager;
    address globals;
    address governor;
    address liquidatorFactory;
    address loanFactory;

    // Debugging
    uint256 public numBorrowers;
    uint256 public numDefaults;
    uint256 public numLatePayments;
    uint256 public numLoans;
    uint256 public numMatures;
    uint256 public numPayments;
    uint256 public unrealizedLosses;

    address[] borrowers;

    mapping (address => bool) public loanDefaulted;
    mapping (address => bool) public loanImpaired;

    // Contract instances
    MockERC20 collateralAsset;
    MockERC20 fundsAsset;

    IFixedTermLoanManager loanManager;   // Liquidation interfaces prevent this from being ILoanManagerLike. Consider an address.
    IPool                 pool;
    IPoolManager          poolManager;

    /**************************************************************************************************************************************/
    /*** State Variables for Invariant Assertions                                                                                       ***/
    /**************************************************************************************************************************************/

    // Summed values
    uint256 public sum_loan_principal;
    uint256 public sum_loanManager_paymentIssuanceRate;

    // Loan info
    uint256 public earliestPaymentDueDate;

    // Contract references
    address[] public activeLoans;

    mapping (address => uint256) public fundingTime;
    mapping (address => uint256) public lateIntervalInterest;
    mapping (address => uint256) public paymentTimestamp;
    mapping (address => uint256) public platformOriginationFee;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor (
        address collateralAsset_,
        address feeManager_,
        address governor_,
        address liquidatorFactory_,
        address loanFactory_,
        address poolManager_,
        address testContract_,
        uint256 numBorrowers_
    ) {
        feeManager  = feeManager_;
        loanFactory = loanFactory_;
        globals     = IMapleProxyFactory(loanFactory).mapleGlobals();
        governor    = governor_;

        collateralAsset   = MockERC20(collateralAsset_);
        poolManager       = IPoolManager(poolManager_);
        fundsAsset        = MockERC20(poolManager.asset());
        liquidatorFactory = liquidatorFactory_;
        loanManager       = IFixedTermLoanManager(poolManager.loanManagerList(0));  // TODO: May need to be constructor arg.
        pool              = IPool(poolManager.pool());
        testContract      = IInvariantTest(testContract_);

        poolDelegate = makeAddr("poolDelegate");

        earliestPaymentDueDate = testContract.currentTimestamp();

        for (uint256 i; i < numBorrowers_; ++i) {
            address borrower = makeAddr(string(abi.encode("borrower", i)));

            vm.startPrank(governor);
            IGlobals(globals).setValidBorrower(borrower, true);
            IGlobals(globals).setCanDeploy(loanFactory, borrower, true);
            vm.stopPrank();

            borrowers.push(borrower);
        }

        numBorrowers = numBorrowers_;
    }

    /**************************************************************************************************************************************/
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function createLoanAndFund(uint256 seed_) public useTimestamps {
        console2.log("createLoanAndFund() with seed:", seed_);

        numberOfCalls["createLoanAndFund"]++;

        if (numLoans > MAX_LOANS) return;

        address borrower_ = borrowers[bound(_randomize(seed_, "borrower_"), 0, numBorrowers - 1)];

        uint256[3] memory termDetails_;

        termDetails_[0] = bound(_randomize(seed_, "termDetails_[0]"), 0,      30 days);   // Grace period
        termDetails_[1] = bound(_randomize(seed_, "termDetails_[1]"), 1 days, 730 days);  // Payment interval
        termDetails_[2] = bound(_randomize(seed_, "termDetails_[2]"), 1,      30);        // Number of payments

        uint256[3] memory amounts_;

        amounts_[0] = bound(_randomize(seed_, "amounts_[0]"), 0,        1e29);         // Collateral required is zero as we don't drawdown
        amounts_[1] = bound(_randomize(seed_, "amounts_[1]"), 10_000e6, 1e29);         // Principal requested
        amounts_[2] = bound(_randomize(seed_, "amounts_[2]"), 0,        amounts_[1]);  // Ending principal

        require(amounts_[1] >= amounts_[2], "LH:INVALID_AMOUNTS");

        uint256[4] memory rates_;

        rates_[0] = bound(_randomize(seed_, "rates_[0]"), 0.0001e6, 0.5e6);  // Interest rate
        rates_[1] = bound(_randomize(seed_, "rates_[1]"), 0.0001e6, 1.0e6);  // Closing fee rate
        rates_[2] = bound(_randomize(seed_, "rates_[2]"), 0.0001e6, 0.6e6);  // Late fee rate
        rates_[3] = bound(_randomize(seed_, "rates_[3]"), 0.0001e6, 0.2e6);  // Late interest premium

        uint256[2] memory fees_;

        fees_[0] = bound(_randomize(seed_, "fees_[0]"), 0, amounts_[1] / 10);  // Delegate origination fee
        fees_[1] = bound(_randomize(seed_, "fees_[1]"), 0, amounts_[1] / 10);  // Delegate service fee

        if (
            pool.totalSupply() == 0 ||
            delta(fundsAsset.balanceOf(address(pool)), IWithdrawalManager(poolManager.withdrawalManager()).lockedLiquidity()) < amounts_[1] ||
            IWithdrawalManager(poolManager.withdrawalManager()).lockedLiquidity() > fundsAsset.balanceOf(address(pool))
        ) return;

        vm.startPrank(borrower_);
        address loan_ = IProxyFactoryLike(loanFactory).createInstance({
            arguments_: abi.encode(
                borrower_,
                address(loanManager),
                feeManager,
                [address(collateralAsset), address(fundsAsset)],
                termDetails_,
                amounts_,
                rates_,
                fees_
            ),
            salt_: keccak256(abi.encodePacked(seed_, numCalls))
        });
        vm.stopPrank();

        vm.startPrank(borrower_);
        collateralAsset.mint(borrower_, amounts_[0]);
        collateralAsset.approve(loan_, amounts_[0]);
        IFixedTermLoan(loan_).postCollateral(amounts_[0]);
        vm.stopPrank();

        vm.prank(poolManager.poolDelegate());
        loanManager.fund(loan_);

        fundingTime[loan_] = block.timestamp;

        platformOriginationFee[loan_] =
            IFeeManager(feeManager).getPlatformOriginationFee(loan_, IFixedTermLoan(loan_).principalRequested());

        uint256 paymentWithEarliestDueDate = loanManager.paymentWithEarliestDueDate();

        if (paymentWithEarliestDueDate != 0) {
            ( , , earliestPaymentDueDate ) = loanManager.sortedPayments(loanManager.paymentWithEarliestDueDate());
        } else {
            earliestPaymentDueDate = block.timestamp;
        }

        require(earliestPaymentDueDate == loanManager.domainEnd());

        ( , , , , , , uint256 issuanceRate ) = loanManager.payments(loanManager.paymentIdOf(address(loan_)));

        sum_loan_principal                  += IFixedTermLoan(loan_).principal();
        sum_loanManager_paymentIssuanceRate += issuanceRate;

        activeLoans.push(loan_);
        numLoans++;
    }

    // NOTE: Only keep one makePayment function active via the weights.
    function makePayment(uint256 seed_) public virtual useTimestamps {
        console2.log("makePayment() with seed:", seed_);

        numberOfCalls["makePayment"]++;

        if (activeLoans.length == 0) return;

        uint256 loanIndex_ = bound(seed_, 0, activeLoans.length - 1);

        address borrower_ = borrowers[bound(_randomize(seed_, "borrower_"), 0, numBorrowers - 1)];

        vm.startPrank(borrower_);

        IFixedTermLoan loan_ = IFixedTermLoan(activeLoans[loanIndex_]);

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

        ( , , , , , , issuanceRate ) = loanManager.payments(loanManager.paymentIdOf(address(loan_)));

        sum_loan_principal                  += loan_.principal();
        sum_loanManager_paymentIssuanceRate += issuanceRate;
    }

    // NOTE: Only keep one makePayment function active via the weights.
    function impairmentMakePayment(uint256 seed_) public useTimestamps {
        console2.log("impairmentMakePayment() with seed:", seed_);

        numberOfCalls["impairmentMakePayment"]++;

        if (activeLoans.length == 0) return;

        uint256 loanIndex_ = bound(seed_, 0, activeLoans.length - 1);

        address borrower_ = borrowers[bound(_randomize(seed_, "borrower_"), 0, numBorrowers - 1)];

        vm.startPrank(borrower_);

        address loan_ = activeLoans[loanIndex_];

        uint256 previousPaymentDueDate = IFixedTermLoan(loan_).nextPaymentDueDate();

        ( uint256 principal_, uint256 interest_, uint256 fees_ ) = IFixedTermLoan(loan_).getNextPaymentBreakdown();

        uint256 amount_ = principal_ + interest_ + fees_;

        fundsAsset.mint(borrower_, amount_);
        fundsAsset.approve(loan_, amount_);

        if (!ILoanLike(loan_).isImpaired()) {
            ( , , , , , , uint256 issuanceRate_ ) = loanManager.payments(loanManager.paymentIdOf(loan_));
            sum_loanManager_paymentIssuanceRate -= issuanceRate_;
        }

        sum_loan_principal -= ILoanLike(loan_).principal();

        IFixedTermLoan(loan_).makePayment(amount_);

        numPayments++;

        vm.stopPrank();

        uint256 paymentWithEarliestDueDate = loanManager.paymentWithEarliestDueDate();

        if (paymentWithEarliestDueDate != 0) {
            ( , , earliestPaymentDueDate ) = loanManager.sortedPayments(loanManager.paymentWithEarliestDueDate());
        } else {
            earliestPaymentDueDate = block.timestamp;
        }

        require(earliestPaymentDueDate == loanManager.domainEnd(), "Not equal");

        if (IFixedTermLoan(loan_).paymentsRemaining() == 0) {
            activeLoans[loanIndex_] = activeLoans[activeLoans.length - 1];
            activeLoans.pop();
            numLoans--;
            numMatures++;
            return;
        }

        if (block.timestamp > previousPaymentDueDate) {
            numLatePayments++;
        }

        paymentTimestamp[loan_] = block.timestamp;

        ( , interest_, ) = IFixedTermLoan(loan_).getNextPaymentBreakdown();

        uint256 issuanceRate;

        ( , , , , , , issuanceRate ) = loanManager.payments(loanManager.paymentIdOf(loan_));

        sum_loan_principal                  += ILoanLike(loan_).principal();
        sum_loanManager_paymentIssuanceRate += issuanceRate;

        unrealizedLosses = poolManager.unrealizedLosses();
    }

    // NOTE: Only keep one makePayment function active via the weights.
    function defaultMakePayment(uint256 seed_) public useTimestamps {
        console2.log("defaultMakePayment() with seed:", seed_);

        numberOfCalls["defaultMakePayment"]++;

        if (activeLoans.length == 0) return;

        uint256 loanIndex_ = bound(seed_, 0, activeLoans.length - 1);

        if (loanDefaulted[activeLoans[loanIndex_]]) return;  // Loan defaulted

        this.makePayment(seed_);
    }

    function impairLoan(uint256 seed_) public useTimestamps {
        console2.log("impairLoan() with seed:", seed_);

        numberOfCalls["impairLoan"]++;

        if (activeLoans.length == 0) return;

        uint256 loanIndex_ = bound(seed_, 0, activeLoans.length - 1);
        address loanAddress = activeLoans[loanIndex_];

        if (loanImpaired[loanAddress]) return;

        ( , , , , , , uint256 issuanceRate ) = loanManager.payments(loanManager.paymentIdOf(address(loanAddress)));

        sum_loanManager_paymentIssuanceRate -= issuanceRate;

        vm.prank(poolManager.poolDelegate());
        loanManager.impairLoan(loanAddress);

        unrealizedLosses       = poolManager.unrealizedLosses();
        earliestPaymentDueDate = block.timestamp;

        uint256 paymentWithEarliestDueDate = loanManager.paymentWithEarliestDueDate();

        if (paymentWithEarliestDueDate != 0) {
            ( , , earliestPaymentDueDate ) = loanManager.sortedPayments(loanManager.paymentWithEarliestDueDate());
        } else {
            earliestPaymentDueDate = block.timestamp;
        }

        loanImpaired[loanAddress] = true;
    }

    function triggerDefault(uint256 seed_) public useTimestamps {
        console2.log("triggerDefault() with seed:", seed_);

        numberOfCalls["triggerDefault"]++;

        if (activeLoans.length == 0) return;

        uint256 loanIndex_  = bound(seed_, 0, activeLoans.length - 1);
        address loanAddress = activeLoans[loanIndex_];

        if (loanDefaulted[loanAddress]) return;  // Loan already defaulted

        // Check loan can be defaulted
        uint256 nextPaymentDueDate_ = IFixedTermLoan(loanAddress).nextPaymentDueDate();
        uint256 gracePeriod_        = ILoanLike(loanAddress).gracePeriod();

        if (block.timestamp <= nextPaymentDueDate_ + gracePeriod_) {
            vm.warp(nextPaymentDueDate_ + gracePeriod_ + 1);
        }

        // If loan isn't impaired account for update to issuance rate
        if (!ILoanLike(loanAddress).isImpaired()) {
            ( , , , , , , uint256 issuanceRate ) = loanManager.payments(loanManager.paymentIdOf(address(loanAddress)));
            sum_loanManager_paymentIssuanceRate -= issuanceRate;
        }

        // Non-liquidating therefore update principal
        if (IFixedTermLoan(loanAddress).collateral() == 0 || IFixedTermLoan(loanAddress).collateralAsset() == address(fundsAsset)) {
            sum_loan_principal -= ILoanLike(loanAddress).principal();
        }

        vm.prank(poolManager.poolDelegate());
        poolManager.triggerDefault(loanAddress, liquidatorFactory);

        numDefaults++;

        loanDefaulted[loanAddress] = true;

        unrealizedLosses = poolManager.unrealizedLosses();

        uint256 paymentWithEarliestDueDate = loanManager.paymentWithEarliestDueDate();

        if (paymentWithEarliestDueDate != 0) {
            ( , , earliestPaymentDueDate ) = loanManager.sortedPayments(loanManager.paymentWithEarliestDueDate());
        } else {
            earliestPaymentDueDate = block.timestamp;
        }
    }

    function finishCollateralLiquidation(uint256 seed_) public useTimestamps {
        console2.log("finishCollateralLiquidation() with seed:", seed_);

        numberOfCalls["finishCollateralLiquidation"]++;

        if (activeLoans.length == 0) return;

        uint256 loanIndex_  = bound(seed_, 0, activeLoans.length - 1);
        address loanAddress = activeLoans[loanIndex_];

        // Check loan needs liquidation
        if(!loanManager.isLiquidationActive(loanAddress)) return;

        ( , uint256 principal_ , , , , address liquidator_ ) = loanManager.liquidationInfo(loanAddress);

        uint256 collateralAmount_ = collateralAsset.balanceOf(liquidator_);
        uint256 expectedAmount_   = ILiquidator(liquidator_).getExpectedAmount(collateralAmount_);

        address externalLiquidator = makeAddr("externalLiquidator");

        // Mint fund asset to external liquidator and liquidate collateral
        vm.startPrank(externalLiquidator);
        fundsAsset.mint(externalLiquidator, expectedAmount_);
        fundsAsset.approve(liquidator_, expectedAmount_);
        ILiquidator(liquidator_).liquidatePortion(collateralAmount_, expectedAmount_, bytes(""));
        vm.stopPrank();

        vm.prank(poolManager.poolDelegate());
        poolManager.finishCollateralLiquidation(loanAddress);

        sum_loan_principal -= principal_;  // Note: principalOut is updated during finishCollateralLiquidation
        unrealizedLosses    = poolManager.unrealizedLosses();

        uint256 paymentWithEarliestDueDate = loanManager.paymentWithEarliestDueDate();

        if (paymentWithEarliestDueDate != 0) {
            ( , , earliestPaymentDueDate ) = loanManager.sortedPayments(loanManager.paymentWithEarliestDueDate());
        } else {
            earliestPaymentDueDate = block.timestamp;
        }
    }

    function warp(uint256 seed_) public useTimestamps {
        console2.log("warp() with seed:", seed_);

        numberOfCalls["warp"]++;

        uint256 warpAmount_ = bound(seed_, 0, 10 days);

        vm.warp(block.timestamp + warpAmount_);
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _randomize(uint256 seed, string memory salt) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(seed, salt)));
    }

    function max(uint256 a_, uint256 b_) internal pure returns (uint256 maximum_) {
        maximum_ = a_ > b_ ? a_ : b_;
    }

    function min(uint256 a_, uint256 b_) internal pure returns (uint256 minimum_) {
        minimum_ = a_ < b_ ? a_ : b_;
    }

    function delta(uint256 x, uint256 y) internal pure returns (uint256 diff) {
        diff = x > y ? x - y : y - x;
    }

}
