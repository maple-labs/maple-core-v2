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
    IWithdrawalManagerCyclical as IWithdrawalManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { console2 as console, MockERC20 } from "../../../contracts/Contracts.sol";

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
    address refinancer;

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
        address refinancer_,
        address testContract_,
        uint256 numBorrowers_
    ) {
        feeManager  = feeManager_;
        loanFactory = loanFactory_;
        globals     = IMapleProxyFactory(loanFactory).mapleGlobals();
        governor    = governor_;
        refinancer  = refinancer_;

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

            vm.prank(governor);
            IGlobals(globals).setValidBorrower(borrower, true);

            borrowers.push(borrower);
        }

        numBorrowers = numBorrowers_;
    }

    /**************************************************************************************************************************************/
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function createLoanAndFund(uint256 seed_) public useTimestamps {
        console.log("ftlHandler.createLoanAndFund(%s)", seed_);

        numberOfCalls["createLoanAndFund"]++;

        if (numLoans > MAX_LOANS) return;

        address borrower_ = borrowers[_bound(_randomize(seed_, "borrower_"), 0, numBorrowers - 1)];

        uint256[3] memory termDetails_ = _getLoanTerms(_randomize(seed_, "termDetails"));
        uint256[3] memory amounts_     = _getLoanAmounts(_randomize(seed_, "amounts"));
        uint256[4] memory rates_       = _getLoanRates(_randomize(seed_, "rates"));

        if (amounts_[1] == 0) return;

        uint256[2] memory fees_ = _getLoanFees(_randomize(seed_,"fees"), amounts_[1]);

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
        console.log("ftlHandler.makePayment(%s)", seed_);

        numberOfCalls["makePayment"]++;

        if (activeLoans.length == 0) return;

        uint256 loanIndex_ = _bound(seed_, 0, activeLoans.length - 1);

        address borrower_ = borrowers[_bound(_randomize(seed_, "borrower_"), 0, numBorrowers - 1)];

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
        console.log("ftlHandler.impairmentMakePayment(%s)", seed_);

        numberOfCalls["impairmentMakePayment"]++;

        if (activeLoans.length == 0) return;

        uint256 loanIndex_ = _bound(seed_, 0, activeLoans.length - 1);

        address borrower_ = borrowers[_bound(_randomize(seed_, "borrower_"), 0, numBorrowers - 1)];

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
        console.log("ftlHandler.defaultMakePayment(%s)", seed_);

        numberOfCalls["defaultMakePayment"]++;

        if (activeLoans.length == 0) return;

        uint256 loanIndex_ = _bound(seed_, 0, activeLoans.length - 1);

        if (loanDefaulted[activeLoans[loanIndex_]]) return;  // Loan defaulted

        this.makePayment(seed_);
    }

    function impairLoan(uint256 seed_) public useTimestamps {
        console.log("ftlHandler.impairLoan(%s)", seed_);

        numberOfCalls["impairLoan"]++;

        if (activeLoans.length == 0) return;

        uint256 loanIndex_ = _bound(seed_, 0, activeLoans.length - 1);
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
        console.log("ftlHandler.triggerDefault(%s)", seed_);

        numberOfCalls["triggerDefault"]++;

        if (activeLoans.length == 0) return;

        uint256 loanIndex_  = _bound(seed_, 0, activeLoans.length - 1);
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
        console.log("ftlHandler.finishCollateralLiquidation(%s)", seed_);

        numberOfCalls["finishCollateralLiquidation"]++;

        if (activeLoans.length == 0) return;

        uint256 loanIndex_  = _bound(seed_, 0, activeLoans.length - 1);
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

    function refinance(uint256 seed_) public useTimestamps {
        console.log("ftlHandler.refinance(%s)", seed_);

        numberOfCalls["refinance"]++;

        if (activeLoans.length == 0) return;

        uint256 loanIndex_ = _bound(seed_, 0, activeLoans.length - 1);

        IFixedTermLoan loan_ = IFixedTermLoan(activeLoans[loanIndex_]);

        ( bytes[] memory calls_, uint256 principalIncrease_ ) = _generateRefinanceCalls(_randomize(seed_, "refinance"), address(loan_));

        ( , , uint256 startDate , , , , uint256 issuanceRate ) = loanManager.payments(loanManager.paymentIdOf(address(loan_)));

        // Loan is not active
        if (startDate == 0) return;

        if (!loanImpaired[address(loan_)]) {
            sum_loanManager_paymentIssuanceRate -= issuanceRate;
        }

        sum_loan_principal -= loan_.principal();

        // There's a need to pay origination fees during refinance, but it's impossible
        // to know how much it'll be. So an exorbitant amount is sent then is drawdown.
        address borrower = loan_.borrower();
        fundsAsset.mint(borrower, 1e29);
        vm.startPrank(borrower);
        fundsAsset.approve(address(loan_), 1e29);
        loan_.returnFunds(1e29);

        collateralAsset.mint(address(loan_), 1e29);
        loan_.postCollateral(0);
        vm.stopPrank();

        proposeRefinanceFT(address(loan_), refinancer, block.timestamp, calls_);

        acceptRefinanceFT(address(loan_), refinancer, block.timestamp, calls_, principalIncrease_);

        ( , , , , , , issuanceRate ) = loanManager.payments(loanManager.paymentIdOf(address(loan_)));

        sum_loan_principal                  += loan_.principal();
        sum_loanManager_paymentIssuanceRate += issuanceRate;

        paymentTimestamp[address(loan_)] = block.timestamp;
        numPayments++;

        uint256 paymentWithEarliestDueDate = loanManager.paymentWithEarliestDueDate();

        if (paymentWithEarliestDueDate != 0) {
            ( , , earliestPaymentDueDate ) = loanManager.sortedPayments(loanManager.paymentWithEarliestDueDate());
        } else {
            earliestPaymentDueDate = block.timestamp;
        }

        require(earliestPaymentDueDate == loanManager.domainEnd(), "Not equal");

        uint256 drawable   = loan_.drawableFunds();
        uint256 collateral = loan_.getAdditionalCollateralRequiredFor(drawable);

        collateralAsset.mint(address(loan_), collateral);

        vm.startPrank(borrower);
        loan_.drawdownFunds(drawable, address(borrower));
        loan_.removeCollateral(loan_.excessCollateral(), address(borrower));
        vm.stopPrank();

        fundsAsset.burn(borrower, fundsAsset.balanceOf(borrower));
        collateralAsset.burn(borrower, collateralAsset.balanceOf(borrower));
    }


    function warp(uint256 seed_) public useTimestamps {
        console.log("ftlHandler.warp(%s)", seed_);

        numberOfCalls["warp"]++;

        uint256 warpAmount_ = _bound(seed_, 0, 10 days);

        console.log("warp():", warpAmount_);

        vm.warp(block.timestamp + warpAmount_);
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

     function _availableLiquidity() internal view returns (uint256 availableLiquidity) {
        if (pool.totalSupply() == 0) return 0;

        uint256 lockedLiquidity = IWithdrawalManager(poolManager.withdrawalManager()).lockedLiquidity();
        uint256 assetBalance    = fundsAsset.balanceOf(address(pool));

        availableLiquidity = lockedLiquidity > assetBalance ? 0 : assetBalance - lockedLiquidity;
    }

    function _generateRefinanceCalls(uint256 seed_, address loan_)
        internal view returns (bytes[] memory data_, uint256 principalChange_)
    {
        uint256 currentPrincipal = IFixedTermLoan(loan_).principal();

        // Increase is limited to available principal
        uint256 principalIncrease = _bound(_randomize(seed_, "principal"), 0, _availableLiquidity() > 1e29 ? 1e29 : _availableLiquidity());

        uint256 endingPrincipal = _bound(_randomize(seed_, "endingPrincipal"), 0, currentPrincipal + principalIncrease);

        uint256[3] memory termDetails = _getLoanTerms(_randomize(seed_, "termDetails"));
        uint256[4] memory rates       = _getLoanRates(_randomize(seed_, "rates"));
        uint256[2] memory fees        = _getLoanFees(_randomize(seed_, "fees"), currentPrincipal);

        // Create an array of arguments, even if not all will be used
        bytes[] memory calls = new bytes[](11);

        calls[0] = abi.encodeWithSignature("setCollateralRequired(uint256)", _bound(_randomize(seed_, "collateralRequired"), 0, 1e29));

        calls[1]  = abi.encodeWithSignature("increasePrincipal(uint256)",              principalIncrease);
        calls[2]  = abi.encodeWithSignature("setEndingPrincipal(uint256)",             endingPrincipal);
        calls[3]  = abi.encodeWithSignature("setInterestRate(uint256)",                rates[0]);
        calls[4]  = abi.encodeWithSignature("setClosingRate(uint256)",                 rates[1]);
        calls[5]  = abi.encodeWithSignature("setLateFeeRate(uint256)",                 rates[2]);
        calls[6]  = abi.encodeWithSignature("setGracePeriod(uint256)",                 termDetails[0]);
        calls[7]  = abi.encodeWithSignature("setPaymentInterval(uint256)",             termDetails[1]);
        calls[8]  = abi.encodeWithSignature("setPaymentsRemaining(uint256)",           termDetails[2]);
        calls[9]  = abi.encodeWithSignature("setLateInterestPremiumRate(uint256)",     rates[3]);
        calls[10] = abi.encodeWithSignature("updateDelegateFeeTerms(uint256,uint256)", fees[0], fees[1]);

        // Get how many calls will be done
        uint256 numOfCalls = (_randomize(seed_, "numOfCalls") % 11) + 1; // 11 functions on refi contract

        data_ = new bytes[](numOfCalls);

        for (uint256 i = 0; i < numOfCalls; i++) {
            // Get a random index, so calls happen in different orders every time.
            uint256 index = _randomize(seed_, string(abi.encode(i))) % calls.length;

            data_[i] = calls[index];

            // `increasePrincipal`-specific logic
            if (index == 1) {

                // Only call `increasePrincipal` once to ensure that amount corresponds to available liquidity
                if (principalChange_ > 0) {
                    data_[i] = calls[4];  // `setClosingRate` instead of duplicate `increasePrincipal`
                    continue;
                }

                principalChange_ += principalIncrease;

                // If the ending principal is set to a value higher than the current principal and the ending principal is set
                // before the new principal is set, the refinance will revert with `R:SEP:ABOVE_CURRENT_PRINCIPAL`.
                // Reorder the calls to fix this.
                for (uint256 j; j < i; j++) {
                    if (keccak256(data_[j]) == keccak256(calls[2])) {
                        data_[j] = calls[index];
                        data_[i] = calls[2];
                        break;
                    }
                }
            }
        }

        if (principalChange_ > 0) return (data_, principalChange_);

        // If there is no principal change, ensure that all `setEndingPrincipal` calls
        // are made with an amount less than principal + increase
        for (uint256 i; i < data_.length; i++) {
            if (keccak256(data_[i]) == keccak256(calls[2])) {
                data_[i] = abi.encodeWithSignature(
                    "setEndingPrincipal(uint256)",
                    _bound(_randomize(seed_, "endingPrincipal 2"), 0, currentPrincipal)
                );
            }
        }
    }

    function _getLoanAmounts(uint256 seed_) internal view returns(uint256[3] memory amounts_) {
        uint256 availableLiquidity = _availableLiquidity();

        if (availableLiquidity < 10_000e6) return [uint256(0), 0, 0];

        uint256 maxPrincipal = availableLiquidity > 1e29 ? 1e29 : availableLiquidity;

        amounts_[0] = _bound(_randomize(seed_, "collateralRequired"), 0,        1e29);
        amounts_[1] = _bound(_randomize(seed_, "principalRequested"), 10_000e6, maxPrincipal);
        amounts_[2] = _bound(_randomize(seed_, "endingPrincipal"),    0,        amounts_[1]);

        require(amounts_[1] >= amounts_[2], "LH:INVALID_AMOUNTS");
    }

    function _getLoanFees(uint256 seed_, uint256 principal_) internal pure returns(uint256[2] memory fees_) {
        fees_[0] = _bound(_randomize(seed_, "delegateOriginationFee"), 0, principal_ * 0.025e6 / 1e6);
        fees_[1] = _bound(_randomize(seed_, "delegateServiceFee"),     0, principal_ * 0.025e6 / 1e6);
    }

    function _getLoanRates(uint256 seed_) internal pure returns(uint256[4] memory rates_) {
        rates_[0] = _bound(_randomize(seed_, "interestRate"),            0, 1.0e6);
        rates_[1] = _bound(_randomize(seed_, "closingFeeRate"),          0, 1.0e6);
        rates_[2] = _bound(_randomize(seed_, "lateFeeRate"),             0, 0.6e6);
        rates_[3] = _bound(_randomize(seed_, "lateInterestPremiumRate"), 0, 0.2e6);
    }

    function _getLoanTerms(uint256 seed_) internal pure returns(uint256[3] memory termDetails_) {
        termDetails_[0] = _bound(_randomize(seed_, "gracePeriod"),      12 hours,  30 days);
        termDetails_[1] = _bound(_randomize(seed_, "paymentInterval"),  5 minutes, 730 days);
        termDetails_[2] = _bound(_randomize(seed_, "numberOfPayments"), 1,         30);
    }

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
