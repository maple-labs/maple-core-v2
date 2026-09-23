// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAllocationStrategy,
    IERC20,
    ILoanLike,
    IOpenTermLoan,
    IOpenTermLoanManager,
    IPool,
    IPoolManager,
    IStrategyManager,
    IUnderlyingStrategyLike,
    IWithdrawalManagerQueue
} from "../../contracts/interfaces/Interfaces.sol";

import { console } from "../../contracts/Runner.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

enum LoanAction {
    Call,
    Impair,
    Payment,
    RemoveCall,
    RemoveImpairment,
    TriggerDefault
}

// TODO: Add more strategy managed functions as we develop fuzz tests
enum AllocationStrategyAction {
    CancelRedemption,
    DeployAssets,
    Fund,
    Impair,
    ProcessRedemption,
    ReturnAssets,
    RemoveImpairment,
    RecognizeLoss,
    RequestRedeem,
    RealizeYield,
    None
}

// Shared by the Aave and Sky strategies, which expose the same set of managed functions.
enum DefiStrategyAction {
    Fund,
    RequestRedeem,
    ProcessRedemption,
    CancelRedemption,
    Impair,
    RemoveImpairment,
    None
}

// TODO: Bootstrap mint is not set when deploying allocation strategy. Consider changing that when fuzz for allocation are being written.
// TODO: Here we don't fuzz new LP deposits, consider changing that.
abstract contract FuzzedUtil is TestBaseWithAssertions {

    /**************************************************************************************************************************************/
    /*** Open term loan manager factors                                                                                                 ***/
    /**************************************************************************************************************************************/

    uint256 constant CALL_FACTOR              = 75;
    uint256 constant DEFAULT_FACTOR           = 33;
    uint256 constant IMPAIR_FACTOR            = 75;
    uint256 constant PAYMENT_FACTOR           = 100;
    uint256 constant REMOVE_CALL_FACTOR       = 100;
    uint256 constant REMOVE_IMPAIRMENT_FACTOR = 100;

    /**************************************************************************************************************************************/
    /*** Allocation strategy factors                                                                                                    ***/
    /**************************************************************************************************************************************/

    uint256 constant DEPLOY_ASSETS_FACTOR              = 125;
    uint256 constant IMPAIR_STRATEGY_FACTOR            = 50;
    uint256 constant REALIZE_YIELD_FACTOR              = 100;
    uint256 constant RECOGNIZE_LOSS_FACTOR             = 33;
    uint256 constant REMOVE_STRATEGY_IMPAIRMENT_FACTOR = 75;
    uint256 constant RETURN_ASSETS_FACTOR              = 75;

    uint256 constant ALLOCATION_CANCEL_REDEMPTION_FACTOR  = 50;
    uint256 constant ALLOCATION_FUND_FACTOR               = 125;
    uint256 constant ALLOCATION_PROCESS_REDEMPTION_FACTOR = 100;
    uint256 constant ALLOCATION_REQUEST_REDEEM_FACTOR     = 100;

    /**************************************************************************************************************************************/
    /*** Defi strategy factors                                                                                                          ***/
    /**************************************************************************************************************************************/

    uint256 constant DEFI_CANCEL_REDEMPTION_FACTOR  = 50;
    uint256 constant DEFI_FUND_FACTOR               = 125;
    uint256 constant DEFI_IMPAIR_FACTOR             = 50;
    uint256 constant DEFI_PROCESS_REDEMPTION_FACTOR = 100;
    uint256 constant DEFI_REMOVE_IMPAIRMENT_FACTOR  = 75;
    uint256 constant DEFI_REQUEST_REDEEM_FACTOR     = 100;

    /**************************************************************************************************************************************/
    /*** Strategy fee rates                                                                                                             ***/
    /**************************************************************************************************************************************/

    uint32 constant STRATEGY_DELEGATE_FEE_RATE = 0.1e6; // 10% of accrued yield.
    uint32 constant STRATEGY_PROTOCOL_FEE_RATE = 0.05e6; // 5% of accrued yield.

    /**************************************************************************************************************************************/
    /*** Open term loan fee rates                                                                                                       ***/
    /**************************************************************************************************************************************/

    // The delegate service fee rate is fuzzed per loan when the loan is created.
    uint256 constant DELEGATE_MANAGEMENT_FEE_RATE = 0.1e6; // 10% of accrued interest.
    uint256 constant PLATFORM_MANAGEMENT_FEE_RATE = 0.05e6; // 5% of accrued interest.
    uint256 constant PLATFORM_SERVICE_FEE_RATE    = 0.02e6; // 2% of principal, pro rated over the payment interval.

    /**************************************************************************************************************************************/
    /*** Local addresses that will be used in the setup                                                                                 ***/
    /**************************************************************************************************************************************/

    address pool1;
    address pool2;
    address poolManager1;
    address poolManager2;

    address openTermLoanManagerPool1;
    address openTermLoanManagerPool2;

    address allocationStrategyManagerShared;
    address allocationUnderlyingStrategyShared;
    address aaveStrategyManagerShared; // Used only on fork fuzz tests. Otherwise address(0)
    address aaveUnderlyingStrategyShared; // Used only on fork fuzz tests. Otherwise address(0)
    address skyStrategyManagerShared; // Used only on fork fuzz tests. Otherwise address(0)
    address skyUnderlyingStrategyShared; // Used only on fork fuzz tests. Otherwise address(0)

    address managedWalletShared;

    uint256 expectedLoanCount;
    uint256 seed;

    uint256 lpDeposit = 100_000_000e6;

    address[] lps;
    address[] loans;

    function fuzzedSetup(
        uint256 openTermLoans,
        uint256 loanActionCount,
        uint256 allocationActionCount,
        uint256 aaveActionCount,
        uint256 skyActionCount,
        uint256 seed_
    )
        internal
    {
        seed              = seed_;
        expectedLoanCount = openTermLoans;

        /**********************************************************************************************************************************/
        /*** Create and fund open term loans for both pools                                                                             ***/
        /**********************************************************************************************************************************/

        for (uint256 i; i < openTermLoans; ++i) {
            vm.warp(block.timestamp + 1 days);

            createAndFundLoan(pool1);
            createAndFundLoan(pool2);
        }

        /**********************************************************************************************************************************/
        /*** Fund the allocation strategy from both pools                                                                               ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(poolManager1, allocationStrategyManagerShared, fundsAsset.balanceOf(pool1) / 2);
        fundStrategyManager(poolManager2, allocationStrategyManagerShared, fundsAsset.balanceOf(pool2) / 2);

        /**********************************************************************************************************************************/
        /*** Perform random actions on the loans                                                                                        ***/
        /**********************************************************************************************************************************/

        for (uint256 i; i < loanActionCount; ++i) {
            // Get loan and due date of active loan with earliest due date.
            (address loan, uint256 dueDate) = getEarliestDueDate();

            // If no active loans are remaining: no further loan actions can be performed.
            if (loan == address(0)) break;

            uint256 maxDate = dueDate < block.timestamp ? 1 days : (dueDate - block.timestamp) + 10 days;

            // Warp to anytime from 1 day from now to 11 days past the loan's due date.
            vm.warp(block.timestamp + 1 days + getSomeValue(0, maxDate));

            performSomeLoanAction(loan);

            if (ILoanLike(loan).principal() == 0) {
                removeLoan(loan);
            }
        }

        /**********************************************************************************************************************************/
        /*** Perform random actions on the allocation strategy                                                                          ***/
        /**********************************************************************************************************************************/

        for (uint256 i; i < allocationActionCount; ++i) {
            vm.warp(block.timestamp + getSomeValue(1 hours, 10 days));

            performSomeAllocationStrategyAction(poolManager1);
            performSomeAllocationStrategyAction(poolManager2);
        }

        /**********************************************************************************************************************************/
        /*** Perform random actions on the aave strategy                                                                                ***/
        /**********************************************************************************************************************************/

        for (uint256 i; i < aaveActionCount; ++i) {
            vm.warp(block.timestamp + getSomeValue(1 hours, 10 days));

            performSomeDefiStrategyAction(poolManager1, aaveStrategyManagerShared);
            performSomeDefiStrategyAction(poolManager2, aaveStrategyManagerShared);
        }

        /**********************************************************************************************************************************/
        /*** Perform random actions on the sky strategy                                                                                 ***/
        /**********************************************************************************************************************************/

        for (uint256 i; i < skyActionCount; ++i) {
            vm.warp(block.timestamp + getSomeValue(1 hours, 10 days));

            performSomeDefiStrategyAction(poolManager1, skyStrategyManagerShared);
            performSomeDefiStrategyAction(poolManager2, skyStrategyManagerShared);
        }
    }

    function performSomeLoanAction(address loan) internal {
        LoanAction action = getSomeOpenTermAction(loan);

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
            triggerDefault(loan);
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

    function performSomeAllocationStrategyAction(address poolManager_) internal {
        AllocationStrategyAction action = getSomeAllocationStrategyAction(poolManager_);

        if (action == AllocationStrategyAction.DeployAssets) {
            uint256 assets = getSomeValue(1, IAllocationStrategy(allocationUnderlyingStrategyShared).availableToWithdraw());

            deployAssets(allocationUnderlyingStrategyShared, managedWalletShared, assets);
            console.log("Assets deployed:", assets);
        }

        if (action == AllocationStrategyAction.ReturnAssets) {
            uint256 deployedAssets = IAllocationStrategy(allocationUnderlyingStrategyShared).deployedAssetsOf(managedWalletShared);
            uint256 assets         = getSomeValue(1, deployedAssets);

            returnAssets(allocationUnderlyingStrategyShared, managedWalletShared, managedWalletShared, assets);
            console.log("Assets returned:", assets);
        }

        if (action == AllocationStrategyAction.RealizeYield) {
            uint256 yield    = getSomeValue(0, IAllocationStrategy(allocationUnderlyingStrategyShared).yieldCap());
            uint32  duration = uint32(getSomeValue(0, 30 days));

            realizeYield(allocationUnderlyingStrategyShared, managedWalletShared, yield, duration);
            console.log("Yield realized:", yield);
        }

        if (action == AllocationStrategyAction.Impair) {
            IAllocationStrategy strategy = IAllocationStrategy(allocationUnderlyingStrategyShared);

            uint256 impairedAssets = strategy.impairedAssets();
            uint256 maxImpairment  = strategy.assetsUnderManagement() + strategy.unrealizedYield() - impairedAssets;
            uint256 assets         = getSomeValue(1, maxImpairment);

            impairAllocationStrategy(allocationUnderlyingStrategyShared, assets);
            console.log("Strategy impaired:", assets);
        }

        if (action == AllocationStrategyAction.RemoveImpairment) {
            uint256 assets = getSomeValue(1, IAllocationStrategy(allocationUnderlyingStrategyShared).impairedAssets());

            removeStrategyImpairment(allocationUnderlyingStrategyShared, assets);
            console.log("Strategy impairment removed:", assets);
        }

        if (action == AllocationStrategyAction.RecognizeLoss) {
            uint256 deployedAssets = IAllocationStrategy(allocationUnderlyingStrategyShared).deployedAssetsOf(managedWalletShared);
            uint256 assets         = getSomeValue(1, deployedAssets);

            recognizeLoss(allocationUnderlyingStrategyShared, managedWalletShared, assets);
            console.log("Loss recognized:", assets);
        }

        if (action == AllocationStrategyAction.Fund) {
            uint256 minAssets = getMinimumFundableAssets(allocationStrategyManagerShared);
            uint256 assets    = getSomeValue(minAssets, fundsAsset.balanceOf(IPoolManager(poolManager_).pool()));

            fundStrategyManager(poolManager_, allocationStrategyManagerShared, assets);
            console.log("Allocation strategy funded:", assets);
        }

        if (action == AllocationStrategyAction.RequestRedeem) {
            IStrategyManager strategyManager = IStrategyManager(allocationStrategyManagerShared);

            uint256 shares = getSomeValue(1, strategyManager.sharesOf(poolManager_) - strategyManager.pendingSharesOf(poolManager_));

            requestRedeemFromStrategyManager(poolManager_, allocationStrategyManagerShared, shares);
            console.log("Allocation strategy redemption requested:", shares);
        }

        if (action == AllocationStrategyAction.ProcessRedemption) {
            IStrategyManager strategyManager = IStrategyManager(allocationStrategyManagerShared);

            uint256 minShares = strategyManager.convertToExitShares(1);

            if (strategyManager.convertToExitAssets(minShares) == 0) ++minShares;

            uint256 shares = getSomeValue(minShares, getMaximumProcessableShares(poolManager_, allocationStrategyManagerShared));

            processRedemptionFromStrategyManager(poolManager_, allocationStrategyManagerShared, shares);
            console.log("Allocation strategy redemption processed:", shares);
        }

        if (action == AllocationStrategyAction.CancelRedemption) {
            uint256 shares = getSomeValue(1, IStrategyManager(allocationStrategyManagerShared).pendingSharesOf(poolManager_));

            cancelRedemptionFromStrategyManager(poolManager_, allocationStrategyManagerShared, shares);
            console.log("Allocation strategy redemption cancelled:", shares);
        }
    }

    function performSomeDefiStrategyAction(address poolManager_, address strategyManager_) internal {
        IStrategyManager        strategyManager    = IStrategyManager(strategyManager_);
        IUnderlyingStrategyLike underlyingStrategy = IUnderlyingStrategyLike(strategyManager.underlyingStrategy());

        DefiStrategyAction action = getSomeDefiStrategyAction(poolManager_, strategyManager_);

        if (action == DefiStrategyAction.Fund) {
            uint256 minAssets = getMinimumFundableAssets(strategyManager_);
            uint256 assets    = getSomeValue(minAssets, fundsAsset.balanceOf(IPoolManager(poolManager_).pool()));

            fundStrategyManager(poolManager_, strategyManager_, assets);
            console.log("Defi strategy funded:", assets);
        }

        if (action == DefiStrategyAction.RequestRedeem) {
            uint256 requestableShares = strategyManager.sharesOf(poolManager_) - strategyManager.pendingSharesOf(poolManager_);

            uint256 shares = getSomeValue(1, requestableShares);

            requestRedeemFromStrategyManager(poolManager_, strategyManager_, shares);
            console.log("Defi strategy redemption requested:", shares);
        }

        if (action == DefiStrategyAction.ProcessRedemption) {
            uint256 minShares = strategyManager.convertToExitShares(1);

            if (strategyManager.convertToExitAssets(minShares) == 0) ++minShares;

            uint256 shares = getSomeValue(minShares, getMaximumProcessableShares(poolManager_, strategyManager_));

            processRedemptionFromStrategyManager(poolManager_, strategyManager_, shares);
            console.log("Defi strategy redemption processed:", shares);
        }

        if (action == DefiStrategyAction.CancelRedemption) {
            uint256 shares = getSomeValue(1, IStrategyManager(strategyManager_).pendingSharesOf(poolManager_));

            cancelRedemptionFromStrategyManager(poolManager_, strategyManager_, shares);
            console.log("Defi strategy redemption cancelled:", shares);
        }

        if (action == DefiStrategyAction.Impair) {
            // Over impairment is allowed. 2xAUM is set to be upper limit so we are giving equal chance to partial and full impairment.
            // If we would allow impairments up to uint256.max partial impairment scenarios would be very rare.
            uint256 assets = getSomeValue(1, underlyingStrategy.assetsUnderManagement() * 2 - underlyingStrategy.impairedAssets());

            impairStrategy(address(underlyingStrategy), assets);
            console.log("Defi strategy impaired:", assets);
        }

        if (action == DefiStrategyAction.RemoveImpairment) {
            uint256 assets = getSomeValue(1, underlyingStrategy.impairedAssets());

            removeStrategyImpairment(address(underlyingStrategy), assets);
            console.log("Defi strategy impairment removed:", assets);
        }
    }

    function getEarliestDueDate() internal view returns (address loan_, uint256 dueDate_) {
        for (uint256 i; i < loans.length; ++i) {
            address loan           = loans[i];
            uint256 paymentDueDate = IOpenTermLoan(loan).paymentDueDate();

            // Loans that are not funded anymore do not have a due date.
            if (paymentDueDate == 0) continue;

            if (paymentDueDate < dueDate_ || dueDate_ == 0) {
                loan_    = loan;
                dueDate_ = paymentDueDate;
            }
        }
    }

    function getEarliestDueDate(address pool_) internal view returns (address loan_, uint256 dueDate_) {
        address openTermLoanManager = IPoolManager(IPool(pool_).manager()).strategyList(0);

        for (uint256 i; i < loans.length; ++i) {
            address loan = loans[i];

            // Only consider loans that belong to the given pool.
            if (IOpenTermLoan(loan).lender() != openTermLoanManager) continue;

            uint256 paymentDueDate = IOpenTermLoan(loan).paymentDueDate();

            // Loans that are not funded anymore do not have a due date.
            if (paymentDueDate == 0) continue;

            if (paymentDueDate < dueDate_ || dueDate_ == 0) {
                loan_    = loan;
                dueDate_ = paymentDueDate;
            }
        }
    }

    /**************************************************************************************************************************************/
    /*** Loan state functions                                                                                                           ***/
    /**************************************************************************************************************************************/

    function isActiveLoan(address loan_) internal view returns (bool isActiveLoan_) {
        isActiveLoan_ = ILoanLike(loan_).principal() > 0;
    }

    function isActiveOpenTermLoan(address loan_) internal view returns (bool isActiveOpenTermLoan_) {
        isActiveOpenTermLoan_ = isActiveLoan(loan_);
    }

    function isCalledOpenTermLoan(address loan_) internal view returns (bool isCalledOpenTermLoan_) {
        isCalledOpenTermLoan_ = IOpenTermLoan(loan_).isCalled();
    }

    function isImpairedOpenTermLoan(address loan_) internal view returns (bool isImpairedOpenTermLoan_) {
        isImpairedOpenTermLoan_ = IOpenTermLoan(loan_).isImpaired();
    }

    /**************************************************************************************************************************************/
    /*** Functions for retrieving random loans and strategies                                                                           ***/
    /**************************************************************************************************************************************/

    function getSomeActiveOpenTermLoan() internal returns (address loan_) {
        loan_ = getSomeLoan(isActiveOpenTermLoan);
    }

    function getSomeCalledOpenTermLoan() internal returns (address loan_) {
        loan_ = getSomeLoan(isCalledOpenTermLoan);
    }

    function getSomeImpairedOpenTermLoan() internal returns (address loan_) {
        loan_ = getSomeLoan(isImpairedOpenTermLoan);
    }

    function getSomeLoan(function(address) returns (bool) filter_) internal returns (address loan) {
        if (loans.length == 0) return address(0);

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

    /**************************************************************************************************************************************/
    /*** Functions for retrieving random loan and strategy actions                                                                      ***/
    /**************************************************************************************************************************************/

    function getSomeOpenTermAction(address loan) internal returns (LoanAction) {
        bool isCalled    = IOpenTermLoan(loan).isCalled();
        bool isImpaired  = IOpenTermLoan(loan).isImpaired();
        bool isInDefault = IOpenTermLoan(loan).isInDefault();

        uint256[] memory factors = new uint256[](6);

        // Payments and calls can always be performed.
        factors[uint256(LoanAction.Payment)] = PAYMENT_FACTOR;
        factors[uint256(LoanAction.Call)] = CALL_FACTOR;

        uint256 sumOfFactors = PAYMENT_FACTOR + CALL_FACTOR;

        // If the loan is called also enable call removal.
        if (isCalled) {
            factors[uint256(LoanAction.RemoveCall)] = REMOVE_CALL_FACTOR;
            sumOfFactors += REMOVE_CALL_FACTOR;
        }

        // If the loan is impaired enable impairment removal, otherwise enable impairments.
        if (isImpaired) {
            factors[uint256(LoanAction.RemoveImpairment)] = REMOVE_IMPAIRMENT_FACTOR;
            sumOfFactors += REMOVE_IMPAIRMENT_FACTOR;
        } else {
            factors[uint256(LoanAction.Impair)] = IMPAIR_FACTOR;
            sumOfFactors += IMPAIR_FACTOR;
        }

        // If the loan is past the default date also enable default triggering.
        if (isInDefault) {
            factors[uint256(LoanAction.TriggerDefault)] = DEFAULT_FACTOR;
            sumOfFactors += DEFAULT_FACTOR;
        }

        uint256 draw = getSomeValue(0, sumOfFactors - 1);

        for (uint256 i; i < factors.length; ++i) {
            if (draw < factors[i]) return LoanAction(i);

            draw -= factors[i];
        }
    }

    function getSomeAllocationStrategyAction(address poolManager_) internal returns (AllocationStrategyAction) {
        IAllocationStrategy strategy        = IAllocationStrategy(allocationUnderlyingStrategyShared);
        IStrategyManager    strategyManager = IStrategyManager(allocationStrategyManagerShared);

        uint256 sumOfFactors;

        uint256[] memory factors = new uint256[](10);

        if (strategy.availableToWithdraw() > 0) {
            factors[uint256(AllocationStrategyAction.DeployAssets)] = DEPLOY_ASSETS_FACTOR;
            sumOfFactors += DEPLOY_ASSETS_FACTOR;
        }

        if (strategy.impairedAssets() < strategy.assetsUnderManagement()) {
            factors[uint256(AllocationStrategyAction.Impair)] = IMPAIR_STRATEGY_FACTOR;
            sumOfFactors += IMPAIR_STRATEGY_FACTOR;
        }

        if (strategy.deployedAssetsOf(managedWalletShared) > 0) {
            factors[uint256(AllocationStrategyAction.ReturnAssets)] = RETURN_ASSETS_FACTOR;
            sumOfFactors += RETURN_ASSETS_FACTOR;
        }

        if (strategy.impairedAssets() > 0) {
            factors[uint256(AllocationStrategyAction.RemoveImpairment)] = REMOVE_STRATEGY_IMPAIRMENT_FACTOR;
            sumOfFactors += REMOVE_STRATEGY_IMPAIRMENT_FACTOR;
        }

        if (strategy.deployedAssetsOf(managedWalletShared) > 0) {
            factors[uint256(AllocationStrategyAction.RecognizeLoss)] = RECOGNIZE_LOSS_FACTOR;
            sumOfFactors += RECOGNIZE_LOSS_FACTOR;
        }

        if (strategy.yieldCooldown() == 0) {
            factors[uint256(AllocationStrategyAction.RealizeYield)] = REALIZE_YIELD_FACTOR;
            sumOfFactors += REALIZE_YIELD_FACTOR;
        }

        if (fundsAsset.balanceOf(IPoolManager(poolManager_).pool()) >= getMinimumFundableAssets(address(strategyManager))) {
            factors[uint256(AllocationStrategyAction.Fund)] = ALLOCATION_FUND_FACTOR;
            sumOfFactors += ALLOCATION_FUND_FACTOR;
        }

        if (strategyManager.sharesOf(poolManager_) > strategyManager.pendingSharesOf(poolManager_)) {
            factors[uint256(AllocationStrategyAction.RequestRedeem)] = ALLOCATION_REQUEST_REDEEM_FACTOR;
            sumOfFactors += ALLOCATION_REQUEST_REDEEM_FACTOR;
        }

        if (
            strategyManager.assetsUnderManagement() > strategyManager.unrealizedLosses()
                && strategyManager.convertToExitAssets(getMaximumProcessableShares(poolManager_, address(strategyManager))) > 0
        ) {
            factors[uint256(AllocationStrategyAction.ProcessRedemption)] = ALLOCATION_PROCESS_REDEMPTION_FACTOR;
            sumOfFactors += ALLOCATION_PROCESS_REDEMPTION_FACTOR;
        }

        if (strategyManager.pendingSharesOf(poolManager_) > 0) {
            factors[uint256(AllocationStrategyAction.CancelRedemption)] = ALLOCATION_CANCEL_REDEMPTION_FACTOR;
            sumOfFactors += ALLOCATION_CANCEL_REDEMPTION_FACTOR;
        }

        // No action can be performed when the strategy holds no assets and has no impairment to remove.
        if (sumOfFactors == 0) return AllocationStrategyAction.None;

        uint256 draw = getSomeValue(0, sumOfFactors - 1);

        for (uint256 i; i < factors.length; ++i) {
            if (draw < factors[i]) return AllocationStrategyAction(i);

            draw -= factors[i];
        }
    }

    function getSomeDefiStrategyAction(address poolManager_, address strategyManager_) internal returns (DefiStrategyAction) {
        IStrategyManager        strategyManager = IStrategyManager(strategyManager_);
        IUnderlyingStrategyLike strategy        = IUnderlyingStrategyLike(strategyManager.underlyingStrategy());

        uint256 impairedAssets = strategy.impairedAssets();

        bool canFund             = fundsAsset.balanceOf(IPoolManager(poolManager_).pool()) >= getMinimumFundableAssets(strategyManager_);
        bool canImpair           = impairedAssets < strategy.assetsUnderManagement();
        bool canRemoveImpairment = impairedAssets > 0;
        bool canRequestRedeem    = strategyManager.sharesOf(poolManager_) > strategyManager.pendingSharesOf(poolManager_);
        bool canCancelRedemption = strategyManager.pendingSharesOf(poolManager_) > 0;
        bool canProcessRedemption = strategyManager.assetsUnderManagement() > strategyManager.unrealizedLosses()
            && strategyManager.convertToExitAssets(getMaximumProcessableShares(poolManager_, strategyManager_)) > 0;

        uint256[] memory factors = new uint256[](6);

        uint256 sumOfFactors;

        if (canFund) {
            factors[uint256(DefiStrategyAction.Fund)] = DEFI_FUND_FACTOR;
            sumOfFactors += DEFI_FUND_FACTOR;
        }

        if (canRequestRedeem) {
            factors[uint256(DefiStrategyAction.RequestRedeem)] = DEFI_REQUEST_REDEEM_FACTOR;
            sumOfFactors += DEFI_REQUEST_REDEEM_FACTOR;
        }

        if (canProcessRedemption) {
            factors[uint256(DefiStrategyAction.ProcessRedemption)] = DEFI_PROCESS_REDEMPTION_FACTOR;
            sumOfFactors += DEFI_PROCESS_REDEMPTION_FACTOR;
        }

        if (canCancelRedemption) {
            factors[uint256(DefiStrategyAction.CancelRedemption)] = DEFI_CANCEL_REDEMPTION_FACTOR;
            sumOfFactors += DEFI_CANCEL_REDEMPTION_FACTOR;
        }

        if (canImpair) {
            factors[uint256(DefiStrategyAction.Impair)] = DEFI_IMPAIR_FACTOR;
            sumOfFactors += DEFI_IMPAIR_FACTOR;
        }

        if (canRemoveImpairment) {
            factors[uint256(DefiStrategyAction.RemoveImpairment)] = DEFI_REMOVE_IMPAIRMENT_FACTOR;
            sumOfFactors += DEFI_REMOVE_IMPAIRMENT_FACTOR;
        }

        // No action can be performed when the pool holds no liquidity and the strategy holds no position.
        if (sumOfFactors == 0) return DefiStrategyAction.None;

        uint256 draw = getSomeValue(0, sumOfFactors - 1);

        for (uint256 i; i < factors.length; ++i) {
            if (draw < factors[i]) return DefiStrategyAction(i);

            draw -= factors[i];
        }

        return DefiStrategyAction.None;
    }

    // Pending shares capped by the liquidity the underlying strategy can release.
    function getMaximumProcessableShares(address poolManager_, address strategyManager_) internal view returns (uint256 maxShares_) {
        IStrategyManager strategyManager = IStrategyManager(strategyManager_);

        uint256 pendingShares      = strategyManager.pendingSharesOf(poolManager_);
        uint256 withdrawableShares = strategyManager.convertToExitShares(strategyManager.availableToWithdraw());

        maxShares_ = withdrawableShares < pendingShares ? withdrawableShares : pendingShares;
    }

    // Funding less than the value of a single share mints nothing, which the strategy manager rejects. The extra unit covers
    // both the rounding down in the conversion and the assets the underlying strategy can lose while depositing.
    function getMinimumFundableAssets(address strategyManager_) internal view returns (uint256 minAssets_) {
        minAssets_ = IStrategyManager(strategyManager_).convertToAssets(1) + 2;
    }

    function getSomeValue(uint256 min_, uint256 max_) internal returns (uint256 value_) {
        value_ = _bound(seed = uint256(keccak256(abi.encode(seed))), min_, max_);
    }

    /**************************************************************************************************************************************/
    /*** Internal functions for creating and funding loans                                                                              ***/
    /**************************************************************************************************************************************/

    function payOffLoansAndRedeemAllLps(address pool_) internal returns (uint256 lastDomainStart_) {
        lastDomainStart_ = payOffAllLoans(pool_);

        withdrawAllFromAllocationStrategy(pool_);
        requestRedeemAllLps(pool_);
        redeemFromQueue(pool_);
    }

    function withdrawAllFromAllocationStrategy(address pool_) internal {
        IAllocationStrategy strategy        = IAllocationStrategy(allocationUnderlyingStrategyShared);
        IStrategyManager    strategyManager = IStrategyManager(allocationStrategyManagerShared);
        address             poolManager_    = IPool(pool_).manager();
        uint256             shares          = IStrategyManager(allocationStrategyManagerShared).sharesOf(poolManager_);

        // Recognized losses can wipe out the entire position, which is then worth nothing and can never be redeemed.
        if (strategyManager.assetsOf(poolManager_) == 0) return;

        uint256 deployedAssets = strategy.deployedAssetsOf(managedWalletShared);

        if (deployedAssets > 0) {
            returnAssets(allocationUnderlyingStrategyShared, managedWalletShared, managedWalletShared, deployedAssets);
        }

        // If there is a full impairment withdraw will fail so we need to remove impairment at least partially so withdraw can pass.
        // Here we must have while loop because we might remove impairment but still round down to 0 assets when withdrawing.
        while (strategyManager.convertToExitAssets(shares) == 0) {
            removeStrategyImpairment(allocationUnderlyingStrategyShared, getSomeValue(1, strategy.impairedAssets()));
        }

        // Part of the position can already be queued, and only the rest of it can be requested.
        uint256 pendingShares = strategyManager.pendingSharesOf(poolManager_);

        if (shares > pendingShares) {
            requestRedeemFromStrategyManager(poolManager_, allocationStrategyManagerShared, shares - pendingShares);
        }

        processRedemptionFromStrategyManager(poolManager_, allocationStrategyManagerShared, shares);
    }

    function payOffAllLoans(address pool_) internal returns (uint256 lastDomainStart_) {
        (address loan,) = getEarliestDueDate(pool_);

        lastDomainStart_ = IOpenTermLoanManager(IPoolManager(IPool(pool_).manager()).strategyList(0)).domainStart();

        while (loan != address(0)) {
            uint256 nextPaymentDueDate = IOpenTermLoan(loan).paymentDueDate();

            // Call open terms after 5 payments on average
            if (uint256(keccak256(abi.encode(nextPaymentDueDate))) % 5 == 0) {
                callLoan(loan, IOpenTermLoan(loan).principal());
            }

            if (nextPaymentDueDate > block.timestamp) {
                vm.warp(nextPaymentDueDate);
            }

            makePayment(loan);

            lastDomainStart_ = block.timestamp;

            if (ILoanLike(loan).principal() == 0) {
                removeLoan(loan);
            }

            (loan,) = getEarliestDueDate(pool_);
        }
    }

    function requestRedeemAllLps(address pool_) internal {
        for (uint256 i; i < lps.length; ++i) {
            address lp = lps[i];

            // Request redeem all LP tokens.
            requestRedeem(pool_, lp, IERC20(pool_).balanceOf(lp));
        }
    }

    function redeemFromQueue(address pool_) internal {
        IPoolManager            poolManager       = IPoolManager(IPool(pool_).manager());
        IWithdrawalManagerQueue withdrawalManager = IWithdrawalManagerQueue(poolManager.withdrawalManager());

        uint256 totalShares = withdrawalManager.totalShares();

        // `processRedemptions` reverts unless passed exactly what current liquidity supports, so mirror its own
        // liquidity check here first rather than guessing a share count that leaves enough of a buffer.
        if (totalShares > 0) {
            uint256 totalSupply_           = IPool(pool_).totalSupply();
            uint256 totalAssetsWithLosses_ = poolManager.totalAssets() - poolManager.unrealizedLosses();
            uint256 availableLiquidity_    = fundsAsset.balanceOf(pool_);
            uint256 requiredLiquidity_     = totalAssetsWithLosses_ * totalShares / totalSupply_;

            uint256 redeemableShares =
                availableLiquidity_ < requiredLiquidity_ ? totalShares * availableLiquidity_ / requiredLiquidity_ : totalShares;

            if (redeemableShares > 0) {
                vm.prank(poolManager.poolDelegate());
                withdrawalManager.processRedemptions(redeemableShares);
            }
        }

        // Redeem all manually available shares that are currently backed by idle liquidity.
        for (uint256 i; i < lps.length; ++i) {
            uint256 manualSharesAvailable_ = withdrawalManager.manualSharesAvailable(lps[i]);

            if (manualSharesAvailable_ > 0) {
                // manualSharesAvailable is only the unlocked amount
                // previewRedeem caps it to what can be redeemed without over-asking the pool for assets.
                (uint256 redeemableShares_,) = withdrawalManager.previewRedeem(lps[i], manualSharesAvailable_);

                if (redeemableShares_ > 0) {
                    redeem(pool_, lps[i], redeemableShares_);
                }
            }
        }
    }

    function createAndFundLoan(address pool_) internal returns (address loan) {
        loan = createSomeOpenTermLoan(pool_);
        loans.push(loan);
        fundLoan(loan);
    }

    function createSomeOpenTermLoan(address pool_) internal returns (address loan) {
        require(fundsAsset.balanceOf(pool_) > 0, "No funding is available.");

        uint256 poolBalance  = fundsAsset.balanceOf(pool_);
        uint256 maxPrincipal = poolBalance / expectedLoanCount;
        uint256 minPrincipal = maxPrincipal / 5;

        uint256 principal              = getSomeValue(minPrincipal, maxPrincipal);
        uint256 noticePeriod           = getSomeValue(1 hours, 10 days);
        uint256 gracePeriod            = getSomeValue(0, 10 days);
        uint256 paymentInterval        = getSomeValue(10 days, 90 days);
        uint256 delegateServiceFeeRate = getSomeValue(0, 0.1e6);
        uint256 interestRate           = getSomeValue(0.01e6, 0.25e6);
        uint256 lateFeeRate            = getSomeValue(0, 0.1e6);
        uint256 lateInterestPremium    = getSomeValue(0, 0.1e6);

        address loanManager = IPoolManager(IPool(pool_).manager()).strategyList(0);

        loan = createOpenTermLoan(
            openTermLoanFactory,
            makeAddr("borrower"),
            loanManager,
            address(fundsAsset),
            principal,
            [gracePeriod, noticePeriod, paymentInterval],
            [delegateServiceFeeRate, interestRate, lateFeeRate, lateInterestPremium]
        );

        console.log("Open-term loan created:", loan);
    }

    function removeLoan(address loan) internal {
        for (uint256 i; i < loans.length; ++i) {
            if (loan != loans[i]) continue;

            loans[i] = loans[loans.length - 1];

            loans.pop();

            return;
        }
    }

}

contract FuzzedSetup is FuzzedUtil {

    function setUp() public virtual override {
        /**********************************************************************************************************************************/
        /*** Deploy core of the protocol                                                                                                ***/
        /**********************************************************************************************************************************/

        _deployProtocol();

        /**********************************************************************************************************************************/
        /*** Deploy allocation strategy that will be shared by two pools and set managed wallet permissions                             ***/
        /**********************************************************************************************************************************/

        managedWalletShared = makeAddr("managedWallet");

        (allocationStrategyManagerShared, allocationUnderlyingStrategyShared) = _deployAllocationStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: STRATEGY_DELEGATE_FEE_RATE,
            strategyProtocolFeeRate_: STRATEGY_PROTOCOL_FEE_RATE,
            strategyLiquidityCap_:    type(uint256).max,
            bootstrapMint_:           0
        });

        setManagedWallet({
            strategy_:        allocationUnderlyingStrategyShared,
            managedWallet_:   managedWalletShared,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   type(uint256).max
        });

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategyShared).setYieldCap(10_000_000e6);

        /**********************************************************************************************************************************/
        /*** Deploy two pools that will share the allocation strategy                                                                   ***/
        /**********************************************************************************************************************************/

        (pool1, poolManager1) = _createPoolSharingStrategy("poolDelegate1", allocationStrategyManagerShared);
        (pool2, poolManager2) = _createPoolSharingStrategy("poolDelegate2", allocationStrategyManagerShared);

        openPool(poolManager1);
        openPool(poolManager2);

        openTermLoanManagerPool1 = IPoolManager(poolManager1).strategyList(0);
        openTermLoanManagerPool2 = IPoolManager(poolManager2).strategyList(0);

        /**********************************************************************************************************************************/
        /*** Set the open term loan fees for both pools                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.startPrank(governor);
        globals.setPlatformManagementFeeRate(poolManager1, PLATFORM_MANAGEMENT_FEE_RATE);
        globals.setPlatformManagementFeeRate(poolManager2, PLATFORM_MANAGEMENT_FEE_RATE);
        globals.setPlatformServiceFeeRate(poolManager1, PLATFORM_SERVICE_FEE_RATE);
        globals.setPlatformServiceFeeRate(poolManager2, PLATFORM_SERVICE_FEE_RATE);
        vm.stopPrank();

        setDelegateManagementFeeRate(poolManager1, DELEGATE_MANAGEMENT_FEE_RATE);
        setDelegateManagementFeeRate(poolManager2, DELEGATE_MANAGEMENT_FEE_RATE);

        /**********************************************************************************************************************************/
        /*** Create LPs and fund both pools with liquidity from the LPs
        ***/
        /**********************************************************************************************************************************/

        lps.push(makeAddr("lp1"));
        lps.push(makeAddr("lp2"));
        lps.push(makeAddr("lp3"));
        lps.push(makeAddr("lp4"));
        lps.push(makeAddr("lp5"));

        for (uint256 i; i < lps.length; ++i) {
            deposit(pool1, lps[i], lpDeposit);
            deposit(pool2, lps[i], lpDeposit);
        }
    }

    /**************************************************************************************************************************************/
    /*** Shared Strategy Fuzz Helpers                                                                                                   ***/
    /**************************************************************************************************************************************/

    function expectedFees(
        address strategy,
        uint256 grossAssets,
        uint256 lastRecordedTotalAssets
    )
        internal
        view
        returns (uint256 delegateFee, uint256 protocolFee)
    {
        if (grossAssets <= lastRecordedTotalAssets) return (0, 0);

        uint256 yieldAccrued = grossAssets - lastRecordedTotalAssets;

        delegateFee = mulDivDown(yieldAccrued, IUnderlyingStrategyLike(strategy).strategyDelegateFeeRate(), HUNDRED_PERCENT);
        protocolFee = mulDivDown(yieldAccrued, IUnderlyingStrategyLike(strategy).strategyProtocolFeeRate(), HUNDRED_PERCENT);
    }

    // Maximum drift, in assets, between `assetsOf` read back after an action and `previousAssets + assetsMoved`.
    //
    // `MapleStrategyManager` divides three times between the two, and the truncations do not cancel:
    //   1. `_convertToAssets` for `assetsOf` at the snapshot  - truncates under one asset
    //   2. `_convertToShares` when minting                    - truncates under one SHARE
    //   3. `_convertToAssets` for `assetsOf` on the read back - truncates under one asset
    //
    // 2 dominates, because a truncated share is worth `totalAssets / totalShares` assets rather than one.
    //
    // Example: 100 shares over 500 assets, so a share is worth 5 assets. A pool holding 30 shares funds 7 assets.
    //   1. assetsOf = floor(30 * 500 / 100) = 150
    //   2. minted   = floor(7 * 100 / 500)  = floor(1.4)    = 1 share, discarding 0.4 shares worth 2 assets
    //   3. assetsOf = floor(31 * 507 / 101) = floor(155.61) = 155
    //
    //   expected = 150 + 7 = 157
    //   actual             = 155
    //   drift              =   2
    //
    // Worst case is a share lost to 2 plus an asset to 3, so the bound is one share price plus one. 1 works the other way,
    // lowering the expected value, so the drift is one directional: `assetsOf` is never above what the test expects.
    function maxShareConversionError(uint256 totalAssets, uint256 totalShares) internal pure returns (uint256 maxError) {
        maxError = mulDivDown(totalAssets, 1, totalShares) + 1;
    }

    function mulDivDown(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        result = denominator == 0 ? 0 : x * y / denominator;
    }

    function mulDivUp(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        result = denominator == 0 ? 0 : (x * y + denominator - 1) / denominator;
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 minimum) {
        minimum = x < y ? x : y;
    }

}
