// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC20,
    IERC4626Like,
    IFixedTermLoanManager,
    IOpenTermLoanManager,
    IPool,
    IPoolManager,
    IPoolPermissionManager,
    IPSMLike,
    IStrategyLike,
    IWithdrawalManagerCyclical as IWithdrawalManager,
    IWithdrawalManagerLike,
    IWithdrawalManagerQueue
} from "../../contracts/interfaces/Interfaces.sol";

// NOTE: This contract only uses onchain calls to check invariants.
// NOTE: This contract assumes one strategy type is deployed per Pool.
contract ProtocolHealthChecker {

    uint256 constant internal BUFFER_MULTIPLE = 4;
    uint256 constant internal BUFFER          = 1e6;

    /******************************************************************************************************************************/
    /*** Invariant Tests                                                                                                        ***/
    /*******************************************************************************************************************************
     * Fixed Term Loan Manager
        * Invariant A: domainStart <= domainEnd
        * Invariant B: sortedPayments is always sorted
        * Invariant F: unrealizedLosses <= assetsUnderManagement()
        * Invariant I: domainStart <= block.timestamp
        * Invariant J: if (loanManager.paymentWithEarliestDueDate != 0) then issuanceRate > 0
        * Invariant K: if (loanManager.paymentWithEarliestDueDate != 0) then domainEnd == paymentWithEarliestDueDate

     * Open Term Loan Manager
        * Invariant E: unrealizedLosses <= assetsUnderManagement()
        * Invariant G: block.timestamp >= domainStart

     * Pool
        * Invariant A: totalAssets > fundsAsset balance of pool
        * Invariant D: convertToAssets(totalSupply) == totalAssets (with rounding)
        * Invariant E: convertToShares(totalAssets) == totalSupply (with rounding)
        * Invariant I: totalAssets == poolManager.totalAssets()
        * Invariant J: unrealizedLosses == poolManager.unrealizedLosses()
        * Invariant K: convertToExitShares == poolManager.convertToExitShares()

     * PoolManager
        * Invariant A: totalAssets == cash + ∑assetsUnderManagement[loanManager]
        * Invariant B: hasSufficientCover == fundsAsset balance of cover > globals.minCoverAmount

     * Pool Permission Manager
        * Invariant A: pool.permissionLevel ∈ [0, 3]

     * Withdrawal Manager (Cyclical)
        * Invariant C: windowStart[currentCycle] <= block.timestamp
        * Invariant D: initialCycleTime[currentConfig] <= block.timestamp
        * Invariant E: initialCycleId[currentConfig] <= currentCycle
        * Invariant M: lockedLiquidity <= pool.totalAssets()
        * Invariant N: lockedLiquidity <= totalCycleShares[exitCycleId[user]] * exchangeRate

     * Withdrawal Manager (Queue)
        * Invariant A: ∑request.shares + ∑owner.manualShares == totalShares
        * Invariant B: balanceOf(this) >= totalShares
        * Invariant D: nextRequestId <= lastRequestId + 1
        * Invariant E: nextRequestId != 0
        * Invariant F: requests(0) == (0, 0)
        * Invariant I: lender is unique

     * Strategy
        * Invariant A: assetsUnderManagement == currentTotalAssets - accruedFees
        * Invariant B: currentAccruedFees <= currentTotalAssets
        * Invariant C: strategyState == ACTIVE -> unrealizedLosses == 0
        * Invariant D: strategyState == IMPAIRED -> assetsUnderManagement == unrealizedLosses
        * Invariant E: strategyState == INACTIVE -> assetsUnderManagement == unrealizedLosses == 0
        * Invariant F: strategyState ∈ [0, 2]
        * Invariant G: strategyFeeRate <= 1e6
    *******************************************************************************************************************************/

    struct Strategies {
        address fixedTermLoanManager;
        address openTermLoanManager;
        address aaveStrategy;
        address skyStrategy;
    }

    // Struct to avoid stack too deep compiler error.
    struct Invariants {
        bool fixedTermLoanManagerInvariantA;
        bool fixedTermLoanManagerInvariantB;
        bool fixedTermLoanManagerInvariantF;
        bool fixedTermLoanManagerInvariantI;
        bool fixedTermLoanManagerInvariantJ;
        bool fixedTermLoanManagerInvariantK;
        bool openTermLoanManagerInvariantE;
        bool openTermLoanManagerInvariantG;
        bool poolInvariantA;
        bool poolInvariantD;
        bool poolInvariantE;
        bool poolInvariantI;
        bool poolInvariantJ;
        bool poolInvariantK;
        bool poolManagerInvariantA;
        bool poolManagerInvariantB;
        bool poolPermissionManagerInvariantA;
        bool withdrawalManagerCyclicalInvariantC;
        bool withdrawalManagerCyclicalInvariantD;
        bool withdrawalManagerCyclicalInvariantE;
        bool withdrawalManagerCyclicalInvariantM;
        bool withdrawalManagerCyclicalInvariantN;
        bool withdrawalManagerQueueInvariantA;
        bool withdrawalManagerQueueInvariantB;
        bool withdrawalManagerQueueInvariantD;
        bool withdrawalManagerQueueInvariantE;
        bool withdrawalManagerQueueInvariantF;
        bool withdrawalManagerQueueInvariantI;
        bool strategiesInvariantA;
        bool strategiesInvariantB;
        bool strategiesInvariantC;
        bool strategiesInvariantD;
        bool strategiesInvariantE;
        bool strategiesInvariantF;
        bool strategiesInvariantG;
    }

    function checkInvariants(address poolManager_) external view returns (Invariants memory invariants_) {
        IPoolManager poolManager = IPoolManager(poolManager_);

        Strategies memory strategies = _getStrategies(poolManager_);

        invariants_ = _bootstrapInvariantsResults();

        address pool_              = poolManager.pool();
        address fundsAsset_        = IPool(pool_).asset();
        address withdrawalManager_ = poolManager.withdrawalManager();

        if (strategies.fixedTermLoanManager != address(0)) {
            invariants_.fixedTermLoanManagerInvariantA = check_fixedTermLoanManager_invariant_A(strategies.fixedTermLoanManager);
            invariants_.fixedTermLoanManagerInvariantB = check_fixedTermLoanManager_invariant_B(strategies.fixedTermLoanManager);
            invariants_.fixedTermLoanManagerInvariantF = check_fixedTermLoanManager_invariant_F(strategies.fixedTermLoanManager);
            invariants_.fixedTermLoanManagerInvariantI = check_fixedTermLoanManager_invariant_I(strategies.fixedTermLoanManager);
            invariants_.fixedTermLoanManagerInvariantJ = check_fixedTermLoanManager_invariant_J(strategies.fixedTermLoanManager);
            invariants_.fixedTermLoanManagerInvariantK = check_fixedTermLoanManager_invariant_K(strategies.fixedTermLoanManager);
        }

        if (strategies.openTermLoanManager != address(0)) {
            invariants_.openTermLoanManagerInvariantE = check_openTermLoanManager_invariant_E(strategies.openTermLoanManager);
            invariants_.openTermLoanManagerInvariantG = check_openTermLoanManager_invariant_G(strategies.openTermLoanManager);
        }

        if (strategies.aaveStrategy != address(0)) {
            invariants_.strategiesInvariantA = check_strategy_invariant_A(strategies.aaveStrategy);
            invariants_.strategiesInvariantB = check_strategy_invariant_B(strategies.aaveStrategy);
            invariants_.strategiesInvariantC = check_strategy_invariant_C(strategies.aaveStrategy);
            invariants_.strategiesInvariantD = check_strategy_invariant_D(strategies.aaveStrategy);
            invariants_.strategiesInvariantE = check_strategy_invariant_E(strategies.aaveStrategy);
            invariants_.strategiesInvariantF = check_strategy_invariant_F(strategies.aaveStrategy);
            invariants_.strategiesInvariantG = check_strategy_invariant_G(strategies.aaveStrategy);
        }

        if (strategies.skyStrategy != address(0)) {
            invariants_.strategiesInvariantA = check_strategy_invariant_A(strategies.skyStrategy);
            invariants_.strategiesInvariantB = check_strategy_invariant_B(strategies.skyStrategy);
            invariants_.strategiesInvariantC = check_strategy_invariant_C(strategies.skyStrategy);
            invariants_.strategiesInvariantD = check_strategy_invariant_D(strategies.skyStrategy);
            invariants_.strategiesInvariantE = check_strategy_invariant_E(strategies.skyStrategy);
            invariants_.strategiesInvariantF = check_strategy_invariant_F(strategies.skyStrategy);
            invariants_.strategiesInvariantG = check_strategy_invariant_G(strategies.skyStrategy);
        }

        invariants_.poolInvariantA = check_pool_invariant_A(pool_);
        invariants_.poolInvariantD = check_pool_invariant_D(pool_);
        invariants_.poolInvariantE = check_pool_invariant_E(pool_);
        invariants_.poolInvariantI = check_pool_invariant_I(pool_, poolManager_);
        invariants_.poolInvariantJ = check_pool_invariant_J(pool_, poolManager_);
        invariants_.poolInvariantK = check_pool_invariant_K(pool_, poolManager_);

        invariants_.poolManagerInvariantA = check_poolManager_invariant_A(
            fundsAsset_,
            pool_,
            poolManager_
        );

        invariants_.poolManagerInvariantB = check_poolManager_invariant_B(poolManager_);

        invariants_.poolPermissionManagerInvariantA = check_poolPermissionManager_invariant_A(poolManager_);

        if (isWithdrawalManagerCyclical(withdrawalManager_)) {
            invariants_.withdrawalManagerCyclicalInvariantC = check_withdrawalManagerCyclical_invariant_C(withdrawalManager_);
            invariants_.withdrawalManagerCyclicalInvariantD = check_withdrawalManagerCyclical_invariant_D(withdrawalManager_);
            invariants_.withdrawalManagerCyclicalInvariantE = check_withdrawalManagerCyclical_invariant_E(withdrawalManager_);
            invariants_.withdrawalManagerCyclicalInvariantM = check_withdrawalManagerCyclical_invariant_M(pool_, withdrawalManager_);
            invariants_.withdrawalManagerCyclicalInvariantN = check_withdrawalManagerCyclical_invariant_N(pool_, withdrawalManager_);
        } else {
            invariants_.withdrawalManagerQueueInvariantA = check_withdrawalManagerQueue_invariant_A(withdrawalManager_);
            invariants_.withdrawalManagerQueueInvariantB = check_withdrawalManagerQueue_invariant_B(withdrawalManager_);
            invariants_.withdrawalManagerQueueInvariantD = check_withdrawalManagerQueue_invariant_D(withdrawalManager_);
            invariants_.withdrawalManagerQueueInvariantE = check_withdrawalManagerQueue_invariant_E(withdrawalManager_);
            invariants_.withdrawalManagerQueueInvariantF = check_withdrawalManagerQueue_invariant_F(withdrawalManager_);
        }
    }

    /******************************************************************************************************************************/
    /*** Fixed Term Loan Manager Invariants                                                                                     ***/
    /******************************************************************************************************************************/

    function check_fixedTermLoanManager_invariant_A(address fixedTermLoanManager_) public view returns (bool isMaintained_) {
        isMaintained_ =
            IFixedTermLoanManager(fixedTermLoanManager_).domainStart() <= IFixedTermLoanManager(fixedTermLoanManager_).domainEnd();
    }

    function check_fixedTermLoanManager_invariant_B(address fixedTermLoanManager_) public view returns (bool isMaintained_) {
        IFixedTermLoanManager loanManager = IFixedTermLoanManager(fixedTermLoanManager_);

        uint256 next = loanManager.paymentWithEarliestDueDate();

        uint256 previousPaymentDueDate;
        uint256 nextPaymentDueDate;

        if (next == 0) isMaintained_ = true;

        while (next != 0) {
            uint256 current = next;

            ( , next, ) = loanManager.sortedPayments(current);  // Overwrite `next` in loop

            ( , , nextPaymentDueDate ) = loanManager.sortedPayments(next);  // Get the next payment due date

            // End of list
            if (next == 0 && nextPaymentDueDate == 0) {
                isMaintained_ = true;
                break;
            }

            isMaintained_ = previousPaymentDueDate <= nextPaymentDueDate;

            previousPaymentDueDate = nextPaymentDueDate;  // Set the previous payment due date
        }
    }

    function check_fixedTermLoanManager_invariant_F(address fixedTermLoanManager_) public view returns (bool isMaintained_) {
        IFixedTermLoanManager loanManager = IFixedTermLoanManager(fixedTermLoanManager_);

        isMaintained_ =
            loanManager.unrealizedLosses() <= loanManager.assetsUnderManagement() + (loanManager.paymentCounter() * BUFFER_MULTIPLE);
    }

    function check_fixedTermLoanManager_invariant_I(address fixedTermLoanManager_) public view returns (bool isMaintained_) {
        isMaintained_ = IFixedTermLoanManager(fixedTermLoanManager_).domainStart() <= block.timestamp;
    }

    function check_fixedTermLoanManager_invariant_J(address fixedTermLoanManager_) public view returns (bool isMaintained_) {
        if (IFixedTermLoanManager(fixedTermLoanManager_).paymentWithEarliestDueDate() == 0) {
            isMaintained_ = true;
        }

        if (IFixedTermLoanManager(fixedTermLoanManager_).paymentWithEarliestDueDate() != 0) {
            isMaintained_ = IFixedTermLoanManager(fixedTermLoanManager_).issuanceRate() > 0;
        }
    }

    function check_fixedTermLoanManager_invariant_K(address fixedTermLoanManager_) public view returns (bool isMaintained_) {
        IFixedTermLoanManager loanManager = IFixedTermLoanManager(fixedTermLoanManager_);

        uint256 paymentWithEarliestDueDate = loanManager.paymentWithEarliestDueDate();

        ( , , uint256 earliestPaymentDueDate ) = loanManager.sortedPayments(paymentWithEarliestDueDate);

        if (paymentWithEarliestDueDate == 0) {
            isMaintained_ = true;
        }

        if (paymentWithEarliestDueDate != 0) {
            isMaintained_ = loanManager.domainEnd() == earliestPaymentDueDate;
        }
    }

    /******************************************************************************************************************************/
    /*** Open Term Loan Manager Invariants                                                                                      ***/
    /******************************************************************************************************************************/

    function check_openTermLoanManager_invariant_E(address openTermLoanManager_) public view returns (bool isMaintained_) {
        IOpenTermLoanManager openTermLoanManager = IOpenTermLoanManager(openTermLoanManager_);

        isMaintained_ = openTermLoanManager.unrealizedLosses() <= openTermLoanManager.assetsUnderManagement() + BUFFER;
    }

    function check_openTermLoanManager_invariant_G(address openTermLoanManager_) public view returns (bool isMaintained_) {
        IOpenTermLoanManager openTermLoanManager = IOpenTermLoanManager(openTermLoanManager_);

        isMaintained_ = block.timestamp >= openTermLoanManager.domainStart();
    }

    /******************************************************************************************************************************/
    /*** Pool Invariants                                                                                                        ***/
    /******************************************************************************************************************************/

    function check_pool_invariant_A(address pool_) public view returns (bool isMaintained_) {
        IPool pool = IPool(pool_);

        isMaintained_ = pool.totalAssets() >= IERC20(pool.asset()).balanceOf(address(pool));
    }

    function check_pool_invariant_D(address pool_) public view returns (bool isMaintained_) {
        IPool pool = IPool(pool_);

        isMaintained_ = _getDiff(pool.totalAssets(), pool.convertToAssets(pool.totalSupply())) <= 1;
    }

    function check_pool_invariant_E(address pool_) public view returns (bool isMaintained_) {
        IPool pool = IPool(pool_);

        isMaintained_ = _getDiff(pool.convertToShares(pool.totalAssets()), pool.totalSupply()) <= 1;
    }

    function check_pool_invariant_I(address pool_, address poolManager) public view returns (bool isMaintained_) {
        isMaintained_ = IPool(pool_).totalAssets() == IPoolManager(poolManager).totalAssets();
    }

    function check_pool_invariant_J(address pool_, address poolManager) public view returns (bool isMaintained_) {
        isMaintained_ = IPool(pool_).unrealizedLosses() == IPoolManager(poolManager).unrealizedLosses();
    }

    function check_pool_invariant_K(address pool_, address poolManager_) public view returns (bool isMaintained_) {
        IPool pool = IPool(pool_);

        if (pool.totalAssets() == 0) isMaintained_ = true;

        if (pool.totalAssets() > 0) {
            isMaintained_ =
                pool.convertToExitShares(pool.totalAssets()) ==
                IPoolManager(poolManager_).convertToExitShares(pool.totalAssets());
        }
    }

    /******************************************************************************************************************************/
    /*** Pool Manager Invariants                                                                                                ***/
    /******************************************************************************************************************************/

    function check_poolManager_invariant_A(
        address fundsAsset_,
        address pool_,
        address poolManager_
    ) public view returns (bool isMaintained_) {
        uint256 length = IPoolManager(poolManager_).strategyListLength();

        uint256 totalAUM = 0;

        for (uint256 i; i < length; ++i) {
            totalAUM += IStrategyLike(IPoolManager(poolManager_).strategyList(i)).assetsUnderManagement();
        }

        isMaintained_ =
        _assertApproxEqAbs(
            (totalAUM +
            IERC20(fundsAsset_).balanceOf(pool_)),
            IPoolManager(poolManager_).totalAssets(),
            BUFFER
        );
    }

    function check_poolManager_invariant_B(address poolManager_) public view returns (bool isMaintained_) {
        IPoolManager poolManager = IPoolManager(poolManager_);

        isMaintained_ = poolManager.totalAssets() >= poolManager.unrealizedLosses();
    }

    /******************************************************************************************************************************/
    /*** Pool Permission Manager Invariants                                                                                     ***/
    /******************************************************************************************************************************/

    function check_poolPermissionManager_invariant_A(address poolManager_) public view returns (bool isMaintained_) {
        IPoolPermissionManager ppm = IPoolPermissionManager(IPoolManager(poolManager_).poolPermissionManager());

        uint256 permissionLevel = ppm.permissionLevels(poolManager_);

        isMaintained_ = permissionLevel >= 0 && permissionLevel <= 3;
    }

    /******************************************************************************************************************************/
    /*** Withdrawal Manager Invariants (Cyclical)                                                                               ***/
    /******************************************************************************************************************************/

    function check_withdrawalManagerCyclical_invariant_C(address withdrawalManager_) public view returns (bool isMaintained_) {
        IWithdrawalManager withdrawalManager = IWithdrawalManager(withdrawalManager_);

        uint256 withdrawalWindowStart = withdrawalManager.getWindowStart(withdrawalManager.getCurrentCycleId());

        isMaintained_ = withdrawalWindowStart <= block.timestamp;
    }

    function check_withdrawalManagerCyclical_invariant_D(address withdrawalManager_) public view returns (bool isMaintained_) {
        IWithdrawalManagerLike withdrawalManager = IWithdrawalManagerLike(withdrawalManager_);

        ( , uint256 initialCycleTime , , ) = withdrawalManager.cycleConfigs(withdrawalManager.getCurrentCycleId());

        isMaintained_ = initialCycleTime <= block.timestamp;
    }

    function check_withdrawalManagerCyclical_invariant_E(address withdrawalManager_) public view returns (bool isMaintained_) {
        IWithdrawalManagerLike withdrawalManager = IWithdrawalManagerLike(withdrawalManager_);

        ( uint256 initialCycleId , , , ) = withdrawalManager.cycleConfigs(withdrawalManager.getCurrentCycleId());

        isMaintained_ = initialCycleId <= withdrawalManager.getCurrentCycleId();
    }

    function check_withdrawalManagerCyclical_invariant_M(
        address pool_,
        address withdrawalManager_
    ) public view returns (bool isMaintained_) {
        IPool pool = IPool(pool_);
        IWithdrawalManager withdrawalManager = IWithdrawalManager(withdrawalManager_);

        if (pool.totalSupply() == 0 || pool.totalAssets() == 0) {
            return isMaintained_ = true;
        }

        uint256 cycleId = withdrawalManager.getCurrentCycleId();

        ( uint256 windowStart, uint256 windowEnd ) = withdrawalManager.getWindowAtId(cycleId);

        if (block.timestamp >= windowStart && block.timestamp < windowEnd) {
            isMaintained_ = withdrawalManager.lockedLiquidity() <= pool.totalAssets();
        } else {
            isMaintained_ = withdrawalManager.lockedLiquidity() == 0;
        }
    }

    function check_withdrawalManagerCyclical_invariant_N(
        address pool_,
        address withdrawalManager_
    ) public view returns (bool isMaintained_) {
        IPool pool = IPool(pool_);

        IWithdrawalManager withdrawalManager = IWithdrawalManager(withdrawalManager_);

        if (pool.totalSupply() == 0 || pool.totalAssets() == 0) {
            return isMaintained_ = true;
        }

        uint256 currentCycle = withdrawalManager.getCurrentCycleId();

        ( uint256 windowStart, uint256 windowEnd ) = withdrawalManager.getWindowAtId(currentCycle);

        if (block.timestamp >= windowStart && block.timestamp < windowEnd) {
            isMaintained_ = withdrawalManager.lockedLiquidity() <=
            (withdrawalManager.totalCycleShares(currentCycle) * (pool.totalAssets() - pool.unrealizedLosses())) / pool.totalSupply();
        } else {
            isMaintained_ = withdrawalManager.lockedLiquidity() == 0;
        }
    }

    /******************************************************************************************************************************/
    /*** Withdrawal Manager Invariants (Queue)                                                                                  ***/
    /******************************************************************************************************************************/

    function check_withdrawalManagerQueue_invariant_A(address withdrawalManager_) public view returns (bool isMaintained_) {
        IWithdrawalManagerQueue withdrawalManager = IWithdrawalManagerQueue(withdrawalManager_);

        address owner;

        uint256 shares;
        uint256 sumOfShares;
        uint256 totalShares = withdrawalManager.totalShares();

        ( uint128 nextRequestId, uint128 lastRequestId ) = withdrawalManager.queue();

        for (uint128 requestId = nextRequestId; requestId <= lastRequestId; requestId++) {
            ( owner, shares ) = withdrawalManager.requests(requestId);

            if (withdrawalManager.isManualWithdrawal(owner)) {
                sumOfShares += withdrawalManager.manualSharesAvailable(owner);
            } else {
                sumOfShares += shares;
            }
        }

        isMaintained_ = sumOfShares == totalShares;
    }

    function check_withdrawalManagerQueue_invariant_B(address withdrawalManager_) public view returns (bool isMaintained_) {
        IWithdrawalManagerQueue withdrawalManager = IWithdrawalManagerQueue(withdrawalManager_);
        IPool                   pool              = IPool(withdrawalManager.pool());

        uint256 totalShares = withdrawalManager.totalShares();
        uint256 balance     = pool.balanceOf(withdrawalManager_);

        isMaintained_ = balance >= totalShares;
    }

    function check_withdrawalManagerQueue_invariant_D(address withdrawalManager_) public view returns (bool isMaintained_) {
        IWithdrawalManagerQueue withdrawalManager = IWithdrawalManagerQueue(withdrawalManager_);

        ( uint128 nextRequestId, uint128 lastRequestId ) = withdrawalManager.queue();

        isMaintained_ = nextRequestId <= lastRequestId + 1;
    }

    function check_withdrawalManagerQueue_invariant_E(address withdrawalManager_) public view returns (bool isMaintained_) {
        IWithdrawalManagerQueue withdrawalManager = IWithdrawalManagerQueue(withdrawalManager_);

        ( uint128 nextRequestId, ) = withdrawalManager.queue();

        isMaintained_ = nextRequestId != 0;
    }

    function check_withdrawalManagerQueue_invariant_F(address withdrawalManager_) public view returns (bool isMaintained_) {
        IWithdrawalManagerQueue withdrawalManager = IWithdrawalManagerQueue(withdrawalManager_);

        ( address owner, uint256 shares ) = withdrawalManager.requests(0);

        isMaintained_ = shares == 0 && owner == address(0);
    }

    /**************************************************************************************************************************************/
    /*** Strategy Invariants                                                                                                            ***/
    /**************************************************************************************************************************************/

    function check_strategy_invariant_A(address strategy) public view returns(bool isMaintained_) {
        IStrategyLike s = IStrategyLike(strategy);

        // Ignore inactive strategies.
        if (s.strategyState() == 2) {
            return true;
        }

        uint256 assetsUnderManagement = s.assetsUnderManagement();
        uint256 currentTotalAssets    = _getCurrentTotalAssets(s);
        uint256 currentAccruedFees    = _getCurrentAccruedFees(s);

        isMaintained_ = assetsUnderManagement == currentTotalAssets - currentAccruedFees;
    }

    function check_strategy_invariant_B(address strategy) public view returns(bool isMaintained_) {
        IStrategyLike s = IStrategyLike(strategy);

        uint256 currentTotalAssets = _getCurrentTotalAssets(s);
        uint256 currentAccruedFees = _getCurrentAccruedFees(s);

        isMaintained_ = currentAccruedFees <= currentTotalAssets;
    }

    function check_strategy_invariant_C(address strategy) public view returns(bool isMaintained_) {
        IStrategyLike s = IStrategyLike(strategy);

        isMaintained_ = true;

        if (s.strategyState() == 0) {
            isMaintained_ = s.unrealizedLosses() == 0;
        }
    }

    function check_strategy_invariant_D(address strategy) public view returns(bool isMaintained_) {
        IStrategyLike s = IStrategyLike(strategy);

        isMaintained_ = true;

        if (s.strategyState() == 1) {
            isMaintained_ = s.assetsUnderManagement() == s.unrealizedLosses();
        }
    }

    function check_strategy_invariant_E(address strategy) public view returns(bool isMaintained_) {
        IStrategyLike s = IStrategyLike(strategy);

        isMaintained_ = true;

        if (s.strategyState() == 2) {
            isMaintained_ = s.assetsUnderManagement() == 0 && s.unrealizedLosses() == 0;
        }
    }

    function check_strategy_invariant_F(address strategy) public view returns(bool isMaintained_) {
        isMaintained_ = IStrategyLike(strategy).strategyState() <= 2;
    }

    function check_strategy_invariant_G(address strategy) public view returns(bool isMaintained_) {
        isMaintained_ = IStrategyLike(strategy).strategyFeeRate() <= 1e6;
    }


    /******************************************************************************************************************************/
    /*** Helpers                                                                                                                ***/
    /******************************************************************************************************************************/

    function _assertApproxEqAbs(uint256 a, uint256 b, uint256 maxDelta) internal pure returns (bool) {
        uint256 delta = _delta(a, b);

        if (delta > maxDelta) {
            return false;
        }

        return true;
    }

    function _bootstrapInvariantsResults() internal pure returns (Invariants memory invariants) {
        invariants.fixedTermLoanManagerInvariantA = true;
        invariants.fixedTermLoanManagerInvariantB = true;
        invariants.fixedTermLoanManagerInvariantF = true;
        invariants.fixedTermLoanManagerInvariantI = true;
        invariants.fixedTermLoanManagerInvariantJ = true;
        invariants.fixedTermLoanManagerInvariantK = true;

        invariants.openTermLoanManagerInvariantE = true;
        invariants.openTermLoanManagerInvariantG = true;

        invariants.poolInvariantA = true;
        invariants.poolInvariantD = true;
        invariants.poolInvariantE = true;
        invariants.poolInvariantI = true;
        invariants.poolInvariantJ = true;
        invariants.poolInvariantK = true;

        invariants.poolManagerInvariantA = true;
        invariants.poolManagerInvariantB = true;

        invariants.poolPermissionManagerInvariantA = true;

        invariants.withdrawalManagerCyclicalInvariantC = true;
        invariants.withdrawalManagerCyclicalInvariantD = true;
        invariants.withdrawalManagerCyclicalInvariantE = true;
        invariants.withdrawalManagerCyclicalInvariantM = true;
        invariants.withdrawalManagerCyclicalInvariantN = true;

        invariants.withdrawalManagerQueueInvariantA = true;
        invariants.withdrawalManagerQueueInvariantB = true;
        invariants.withdrawalManagerQueueInvariantD = true;
        invariants.withdrawalManagerQueueInvariantE = true;
        invariants.withdrawalManagerQueueInvariantF = true;
        invariants.withdrawalManagerQueueInvariantI = true;

        invariants.strategiesInvariantA = true;
        invariants.strategiesInvariantB = true;
        invariants.strategiesInvariantC = true;
        invariants.strategiesInvariantD = true;
        invariants.strategiesInvariantE = true;
        invariants.strategiesInvariantF = true;
        invariants.strategiesInvariantG = true;
    }

    function _delta(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    function _getCurrentAccruedFees(IStrategyLike strategy) internal view returns (uint256 currentAccruedFees) {
        uint256 currentTotalAssets      = _getCurrentTotalAssets(strategy);
        uint256 lastRecordedTotalAssets = strategy.lastRecordedTotalAssets();
        uint256 strategyFeeRate         = strategy.strategyFeeRate();

        if (currentTotalAssets <= lastRecordedTotalAssets) {
            return 0;
        }

        currentAccruedFees = (currentTotalAssets - lastRecordedTotalAssets) * strategyFeeRate / 1e6;
    }

    function _getCurrentTotalAssets(IStrategyLike strategy) internal view returns (uint256 currentTotalAssets) {
        bytes memory t = bytes(strategy.STRATEGY_TYPE());

        if (keccak256(t) == keccak256("BASIC")) {
            IERC4626Like strategyVault = IERC4626Like(strategy.strategyVault());
            uint256 currentTotalShares = strategyVault.balanceOf(address(strategy));

            currentTotalAssets = IERC4626Like(strategyVault).previewRedeem(currentTotalShares);
        }

        else if (keccak256(t) == keccak256("AAVE")) {
            IERC20 aaveToken = IERC20(strategy.aaveToken());

            currentTotalAssets = aaveToken.balanceOf(address(strategy));
        }

        else if (keccak256(t) == keccak256("SKY")) {
            IERC4626Like savingsUsds = IERC4626Like(strategy.savingsUsds());
            IPSMLike psm             = IPSMLike(strategy.psm());

            uint256 psmTout          = psm.tout();
            uint256 conversionFactor = psm.to18ConversionFactor();
            uint256 usdsAmount       = savingsUsds.previewRedeem(savingsUsds.balanceOf(address(strategy)));

            currentTotalAssets = (usdsAmount * 1e18) / (conversionFactor * (1e18 + psmTout));
        }

        else {
            require(false, "INVALID_STRATEGY");
        }
    }

    function _getDiff(uint256 x, uint256 y) internal pure returns (uint256 diff) {
        diff = x > y ? x - y : y - x;
    }

    function _getStrategies(address poolManager) internal view returns (Strategies memory strategies) {
        uint256 length = IPoolManager(poolManager).strategyListLength();

        for (uint256 i = 0; i < length; i++) {
            address strategy = IPoolManager(poolManager).strategyList(i);
            if (_isFixedTermLoanManager(strategy)) strategies.fixedTermLoanManager = strategy;
            if (_isOpenTermLoanManager(strategy))  strategies.openTermLoanManager  = strategy;
            if (_isAaveStrategy(strategy))         strategies.aaveStrategy         = strategy;
            if (_isSkyStrategy(strategy))          strategies.skyStrategy          = strategy;
        }

    }

    function _isFixedTermLoanManager(address loan) internal view returns (bool isFixedTermLoanManager_) {
        try IFixedTermLoanManager(loan).domainEnd() {
            isFixedTermLoanManager_ = true;
        } catch { }
    }

    function _isOpenTermLoanManager(address loan) internal view returns (bool isOpenTermLoanManager_) {
        try IOpenTermLoanManager(loan).paymentFor(address(0)) {
            isOpenTermLoanManager_ = true;
        } catch { }
    }

    function _isAaveStrategy(address strategy) internal view returns (bool isAaveStrategy_) {
        // Using specific function to not need to hash the strings for comparison.
        try IStrategyLike(strategy).aaveToken() {
            isAaveStrategy_ = true;
        } catch { }
    }

    function _isSkyStrategy(address strategy) internal view returns (bool isSkyStrategy_) {
        // Using specific function to not need to hash the strings for comparison.
        try IStrategyLike(strategy).savingsUsds() {
            isSkyStrategy_ = true;
        } catch { }
    }

    function isWithdrawalManagerCyclical(address wm) internal view returns (bool isWithdrawalManagerCyclical_) {
        try IWithdrawalManager(wm).getCurrentCycleId() {
            isWithdrawalManagerCyclical_ = true;
        } catch { }
    }

}
