// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IERC20,
    IFixedTermLoanManager,
    IOpenTermLoanManager,
    IPool,
    IPoolManager,
    IWithdrawalManager
} from "../../contracts/interfaces/Interfaces.sol";

// NOTE: This contract only uses onchain calls to check invariants.
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

     * Withdrawal Manager
        * Invariant C: windowStart[currentCycle] <= block.timestamp
        * Invariant D: initialCycleTime[currentConfig] <= block.timestamp
        * Invariant E: initialCycleId[currentConfig] <= currentCycle
        * Invariant M: lockedLiquidity <= pool.totalAssets()
        * Invariant N: lockedLiquidity <= totalCycleShares[exitCycleId[user]] * exchangeRate

    *******************************************************************************************************************************/

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
        bool withdrawalManagerInvariantC;
        bool withdrawalManagerInvariantD;
        bool withdrawalManagerInvariantE;
        bool withdrawalManagerInvariantM;
        bool withdrawalManagerInvariantN;
    }

    function checkInvariants(address poolManager_) external returns (Invariants memory invariants_) {
        IPoolManager poolManager = IPoolManager(poolManager_);

        address fixedTermLoanManager_;
        address openTermLoanManager_;

        bool noFixedTermLM;
        bool noOpenTermLM;

        // Assume indexes for FT/OT LMs are 0 and 1 respectively. This might not be true for some deployed pools.;
        try poolManager.loanManagerList(0) {
            fixedTermLoanManager_ = poolManager.loanManagerList(0);
        } catch {
            noFixedTermLM = true;
        }

        try poolManager.loanManagerList(1) {
            openTermLoanManager_ = poolManager.loanManagerList(1);
        } catch {
            noOpenTermLM = true;
        }

        address pool_                 = poolManager.pool();
        address fundsAsset_           = IPool(pool_).asset();
        address withdrawalManager_    = poolManager.withdrawalManager();

        invariants_.fixedTermLoanManagerInvariantA = noFixedTermLM || check_fixedTermLoanManager_invariant_A(fixedTermLoanManager_);
        invariants_.fixedTermLoanManagerInvariantB = noFixedTermLM || check_fixedTermLoanManager_invariant_B(fixedTermLoanManager_);
        invariants_.fixedTermLoanManagerInvariantF = noFixedTermLM || check_fixedTermLoanManager_invariant_F(fixedTermLoanManager_);
        invariants_.fixedTermLoanManagerInvariantI = noFixedTermLM || check_fixedTermLoanManager_invariant_I(fixedTermLoanManager_);
        invariants_.fixedTermLoanManagerInvariantJ = true; // 0 interest loan possible, is this really an invariants as our system allows it
        invariants_.fixedTermLoanManagerInvariantK = noFixedTermLM || check_fixedTermLoanManager_invariant_K(fixedTermLoanManager_);

        invariants_.openTermLoanManagerInvariantE = noOpenTermLM || check_openTermLoanManager_invariant_E(openTermLoanManager_);
        invariants_.openTermLoanManagerInvariantG = noOpenTermLM || check_openTermLoanManager_invariant_G(openTermLoanManager_);

        invariants_.poolInvariantA = check_pool_invariant_A(pool_);
        invariants_.poolInvariantD = check_pool_invariant_D(pool_);
        invariants_.poolInvariantE = check_pool_invariant_E(pool_);
        invariants_.poolInvariantI = check_pool_invariant_I(pool_, poolManager_);
        invariants_.poolInvariantJ = check_pool_invariant_J(pool_, poolManager_);
        invariants_.poolInvariantK = check_pool_invariant_K(pool_, poolManager_);

        invariants_.poolManagerInvariantA = check_poolManager_invariant_A(
            fundsAsset_,
            fixedTermLoanManager_,
            openTermLoanManager_,
            pool_,
            poolManager_
        );

        invariants_.poolManagerInvariantB = check_poolManager_invariant_B(poolManager_);

        invariants_.withdrawalManagerInvariantC = check_withdrawalManager_invariant_C(withdrawalManager_);
        invariants_.withdrawalManagerInvariantD = check_withdrawalManager_invariant_D(withdrawalManager_);
        invariants_.withdrawalManagerInvariantE = check_withdrawalManager_invariant_E(withdrawalManager_);
        invariants_.withdrawalManagerInvariantM = check_withdrawalManager_invariant_M(pool_, withdrawalManager_);
        invariants_.withdrawalManagerInvariantN = check_withdrawalManager_invariant_N(pool_, withdrawalManager_);
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
        if (IFixedTermLoanManager(fixedTermLoanManager_).paymentWithEarliestDueDate() == 0) isMaintained_ = true;

        if (IFixedTermLoanManager(fixedTermLoanManager_).paymentWithEarliestDueDate() != 0) {
            isMaintained_ = IFixedTermLoanManager(fixedTermLoanManager_).issuanceRate() > 0;
        }
    }

    function check_fixedTermLoanManager_invariant_K(address fixedTermLoanManager_) public view returns (bool isMaintained_) {
        IFixedTermLoanManager loanManager = IFixedTermLoanManager(fixedTermLoanManager_);

        uint256 paymentWithEarliestDueDate = loanManager.paymentWithEarliestDueDate();

        ( , , uint256 earliestPaymentDueDate ) = loanManager.sortedPayments(paymentWithEarliestDueDate);

        if (paymentWithEarliestDueDate == 0) isMaintained_ = true;

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
        address fixedTermLoanManager_,
        address openTermLoanManager_,
        address pool_,
        address poolManager_
    ) public view returns (bool isMaintained_) {
        uint256 fixedTermAUM =
            fixedTermLoanManager_ == address(0) ? 0 : IFixedTermLoanManager(fixedTermLoanManager_).assetsUnderManagement();

        uint256 openTermAUM =
            openTermLoanManager_ == address(0) ? 0 : IOpenTermLoanManager(openTermLoanManager_).assetsUnderManagement();

        isMaintained_ =
        _assertApproxEqAbs(
            (fixedTermAUM +
            openTermAUM +
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
    /*** Withdrawal Manager Invariants                                                                                          ***/
    /******************************************************************************************************************************/

    function check_withdrawalManager_invariant_C(address withdrawalManager_) public view returns (bool isMaintained_) {
        IWithdrawalManager withdrawalManager = IWithdrawalManager(withdrawalManager_);

        uint256 withdrawalWindowStart = withdrawalManager.getWindowStart(withdrawalManager.getCurrentCycleId());

        isMaintained_ = withdrawalWindowStart <= block.timestamp;
    }

    function check_withdrawalManager_invariant_D(address withdrawalManager_) public returns (bool isMaintained_) {
        IWithdrawalManager withdrawalManager = IWithdrawalManager(withdrawalManager_);

        ( , uint256 initialCycleTime , , ) = withdrawalManager.cycleConfigs(withdrawalManager.getCurrentCycleId());

        isMaintained_ = initialCycleTime <= block.timestamp;
    }

    function check_withdrawalManager_invariant_E(address withdrawalManager_) public returns (bool isMaintained_) {
        IWithdrawalManager withdrawalManager = IWithdrawalManager(withdrawalManager_);

        ( uint256 initialCycleId , , , ) = withdrawalManager.cycleConfigs(withdrawalManager.getCurrentCycleId());

        isMaintained_ = initialCycleId <= withdrawalManager.getCurrentCycleId();
    }

    function check_withdrawalManager_invariant_M(address pool_, address withdrawalManager_) public view returns (bool isMaintained_) {
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

    function check_withdrawalManager_invariant_N(address pool_, address withdrawalManager_) public view returns (bool isMaintained_) {
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
    /*** Helpers                                                                                                                ***/
    /******************************************************************************************************************************/

    function _assertApproxEqAbs(uint256 a, uint256 b, uint256 maxDelta) internal pure returns (bool) {
        uint256 delta = _delta(a, b);

        if (delta > maxDelta) {
            return false;
        }

        return true;
    }

    function _delta(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a - b : b - a;
    }

    function _getDiff(uint256 x, uint256 y) internal pure returns (uint256 diff) {
        diff = x > y ? x - y : y - x;
    }

}
