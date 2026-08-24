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
    IWithdrawalManagerQueue
} from "../../contracts/interfaces/Interfaces.sol";

import { console } from "../../contracts/Runner.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

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

// TODO: Add more strategy managed functions as we develop fuzz tests
enum AllocationStrategyAction {
    DeployAssets,
    Impair,
    ReturnAssets,
    RemoveImpairment,
    RecognizeLoss,
    RealizeYield,
    None
}

// TODO: Bootstrap mint is not set when deploying allocation strategy. Consider changing that when fuzz for allocation are being written.
// TODO: Here we don't fuzz new LP deposits, consider changing that.
// TODO: We don't have fees (protocol or delegate), consider changing that it introduce complexity.
abstract contract FuzzedUtil is TestBaseWithAssertions {

    /**************************************************************************************************************************************/
    /*** Open term loan manager factors                                                                                                 ***/
    /**************************************************************************************************************************************/

    uint256 constant CALL_FACTOR              = 75;
    uint256 constant DEFAULT_FACTOR           = 33;
    uint256 constant FUND_FACTOR              = 100;
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

    address managedWalletShared;

    uint256 expectedLoanCount;
    uint256 seed;

    address[] lps;
    address[] loans;

    function fuzzedSetup(
        uint256 openTermLoans,
        uint256 loanActionCount,
        uint256 strategyActionCount,
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
            ( address loan, uint256 dueDate ) = getEarliestDueDate();

            // If no active loans are remaining: no further loan actions can be performed.
            if (loan == address(0)) break;

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

        /**********************************************************************************************************************************/
        /*** Perform random actions on the allocation strategy                                                                          ***/
        /**********************************************************************************************************************************/

        for (uint256 i; i < strategyActionCount; ++i) {
            vm.warp(block.timestamp + getSomeValue(1 hours, 10 days));

            performSomeAllocationStrategyAction();
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

    function performSomeAllocationStrategyAction() internal {
        AllocationStrategyAction action = getSomeAllocationStrategyAction();

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

    function getSomeLoan(function (address) returns (bool) filter_) internal returns (address loan) {
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

    function getSomeOpenTermAction(address loan) internal returns (LoanAction action) {
        // Always enable payments, calls, impairments to be performed.
        uint256 total = PAYMENT_FACTOR + CALL_FACTOR;

        bool isCalled    = IOpenTermLoan(loan).isCalled();
        bool isImpaired  = IOpenTermLoan(loan).isImpaired();
        bool isInDefault = IOpenTermLoan(loan).isInDefault();

        // If the loan is called also enable call removal.
        if (isCalled) {
            total += REMOVE_CALL_FACTOR;
        }

        // If the loan is impaired enabled impairment removal, otherwise enable impairments.
        if (isImpaired) {
            total += REMOVE_IMPAIRMENT_FACTOR;
        } else {
            total += IMPAIR_FACTOR;
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

        if (isCalled) {
            if (draw < REMOVE_CALL_FACTOR) return LoanAction.RemoveCall;

            draw -= REMOVE_CALL_FACTOR;
        }

        if (isImpaired) {
            if (draw < REMOVE_IMPAIRMENT_FACTOR) return LoanAction.RemoveImpairment;

            draw -= REMOVE_IMPAIRMENT_FACTOR;
        } else {
            if (draw < IMPAIR_FACTOR) return LoanAction.Impair;

            draw -= IMPAIR_FACTOR;
        }

        return LoanAction.TriggerDefault;
    }

    function getSomeAllocationStrategyAction() internal returns (AllocationStrategyAction) {
        IAllocationStrategy strategy = IAllocationStrategy(allocationUnderlyingStrategyShared);

        uint256 sumOfFactors;

        bool canDeployAssets             = strategy.availableToWithdraw() > 0;
        bool canImpairStrategy           = strategy.impairedAssets() < strategy.assetsUnderManagement();
        bool canReturnAssets             = strategy.deployedAssetsOf(managedWalletShared) > 0;
        bool canRecognizeLoss            = strategy.deployedAssetsOf(managedWalletShared) > 0;
        bool canRemoveStrategyImpairment = strategy.impairedAssets() > 0;
        bool canRealizeYield             = strategy.yieldCooldown() == 0;

        uint256[] memory factors = new uint256[](6);

        if (canDeployAssets) {
            factors[uint256(AllocationStrategyAction.DeployAssets)] = DEPLOY_ASSETS_FACTOR;
            sumOfFactors += DEPLOY_ASSETS_FACTOR;
        }

        if (canImpairStrategy) {
            factors[uint256(AllocationStrategyAction.Impair)] = IMPAIR_STRATEGY_FACTOR;
            sumOfFactors += IMPAIR_STRATEGY_FACTOR;
        }

        if (canReturnAssets) {
            factors[uint256(AllocationStrategyAction.ReturnAssets)] = RETURN_ASSETS_FACTOR;
            sumOfFactors += RETURN_ASSETS_FACTOR;
        }

        if (canRemoveStrategyImpairment) {
            factors[uint256(AllocationStrategyAction.RemoveImpairment)] = REMOVE_STRATEGY_IMPAIRMENT_FACTOR;
            sumOfFactors += REMOVE_STRATEGY_IMPAIRMENT_FACTOR;
        }

        if (canRecognizeLoss) {
            factors[uint256(AllocationStrategyAction.RecognizeLoss)] = RECOGNIZE_LOSS_FACTOR;
            sumOfFactors += RECOGNIZE_LOSS_FACTOR;
        }

        if (canRealizeYield) {
            factors[uint256(AllocationStrategyAction.RealizeYield)] = REALIZE_YIELD_FACTOR;
            sumOfFactors += REALIZE_YIELD_FACTOR;
        }

        // No action can be performed when the strategy holds no assets and has no impairment to remove.
        if (sumOfFactors == 0) return AllocationStrategyAction.None;

        uint256 draw = getSomeValue(0, sumOfFactors - 1);

        for (uint256 i; i < factors.length; ++i) {
            if (draw < factors[i]) return AllocationStrategyAction(i);

            draw -= factors[i];
        }
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
        IAllocationStrategy strategy     = IAllocationStrategy(allocationUnderlyingStrategyShared);
        IStrategyManager strategyManager = IStrategyManager(allocationStrategyManagerShared);
        address poolManager_             = IPool(pool_).manager();
        uint256 shares                   = IStrategyManager(allocationStrategyManagerShared).sharesOf(poolManager_);

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

        requestRedeemFromStrategyManager(poolManager_, allocationStrategyManagerShared, shares);
        processRedemptionFromStrategyManager(poolManager_, allocationStrategyManagerShared, shares);
    }

    function payOffAllLoans(address pool_) internal returns (uint256 lastDomainStart_) {
        ( address loan , ) = getEarliestDueDate(pool_);

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

            ( loan , ) = getEarliestDueDate(pool_);
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

        // There's some rounding in the pools that prevent the last hundred or so shares from being redeemed.
        if (totalShares > 100) {
            vm.prank(poolManager.poolDelegate());
            withdrawalManager.processRedemptions(totalShares - 100);
        }

        // Redeem all manually available shares that are currently backed by idle liquidity.
        for (uint256 i; i < lps.length; ++i) {
            uint256 manualSharesAvailable_ = withdrawalManager.manualSharesAvailable(lps[i]);

            if (manualSharesAvailable_ > 0) {
                // manualSharesAvailable is only the unlocked amount
                // previewRedeem caps it to what can be redeemed without over-asking the pool for assets.
                ( uint256 redeemableShares_, ) = withdrawalManager.previewRedeem(lps[i], manualSharesAvailable_);

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
        uint256 maxPrincipal = poolBalance  / expectedLoanCount;
        uint256 minPrincipal = maxPrincipal / 5;

        uint256 principal              = getSomeValue(minPrincipal, maxPrincipal);
        uint256 noticePeriod           = getSomeValue(1 hours,      10 days);
        uint256 gracePeriod            = getSomeValue(0,            10 days);
        uint256 paymentInterval        = getSomeValue(10 days,      90 days);
        uint256 delegateServiceFeeRate = getSomeValue(0,            0.1e6);
        uint256 interestRate           = getSomeValue(0.01e6,       0.25e6);
        uint256 lateFeeRate            = getSomeValue(0,            0.1e6);
        uint256 lateInterestPremium    = getSomeValue(0,            0.1e6);

        address loanManager = IPoolManager(IPool(pool_).manager()).strategyList(0);

        loan = createOpenTermLoan(
            openTermLoanFactory,
            makeAddr("borrower"),
            loanManager,
            address(fundsAsset),
            principal,
            [gracePeriod,            noticePeriod, paymentInterval],
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

        ( allocationStrategyManagerShared, allocationUnderlyingStrategyShared ) = _deployAllocationStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
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

        ( pool1, poolManager1 ) = _createPoolSharingStrategy("poolDelegate1", allocationStrategyManagerShared);
        ( pool2, poolManager2 ) = _createPoolSharingStrategy("poolDelegate2", allocationStrategyManagerShared);

        openPool(poolManager1);
        openPool(poolManager2);

        openTermLoanManagerPool1 = IPoolManager(poolManager1).strategyList(0);
        openTermLoanManagerPool2 = IPoolManager(poolManager2).strategyList(0);

        /**********************************************************************************************************************************/
        /*** Create LPs and fund both pools with liquidity from the LPs                                                                  ***/
        /**********************************************************************************************************************************/

        lps.push(makeAddr("lp1"));
        lps.push(makeAddr("lp2"));
        lps.push(makeAddr("lp3"));
        lps.push(makeAddr("lp4"));
        lps.push(makeAddr("lp5"));

        for (uint256 i; i < lps.length; ++i) {
            deposit(pool1, lps[i], 100_000_000e6);
            deposit(pool2, lps[i], 100_000_000e6);
        }
    }

}
