// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC20,
    IPool,
    IPoolManager,
    IWithdrawalManagerCyclical as IWithdrawalManager,
    IWithdrawalManagerQueue
} from "../../contracts/interfaces/Interfaces.sol";

contract LPHealthChecker {

    /******************************************************************************************************************************/
    /*** Invariant Tests                                                                                                        ***/
    /*******************************************************************************************************************************
    * Pool (non-liquidating)
        * Invariant B: ∑balanceOfAssets == totalAssets (with rounding)
        * Invariant G: ∑balanceOf[user] == totalSupply

    * Withdrawal Manager (Cyclical)
        * Invariant A: WM LP balance == ∑lockedShares(user)
        * Invariant B: totalCycleShares == ∑lockedShares(user)[cycle] (for all cycles)
        * Invariant F: getRedeemableAmounts.shares[owner] <= WM LP balance
        * Invariant G: getRedeemableAmounts.shares[owner] <= lockedShares[user]
        * Invariant H: getRedeemableAmounts.shares[owner] <= totalCycleShares[exitCycleId[user]]
        * Invariant I: getRedeemableAmounts.assets[owner] <= fundsAsset balance of pool
        * Invariant J: getRedeemableAmounts.assets[owner] <= totalCycleShares[exitCycleId[user]] * exchangeRate
        * Invariant K: getRedeemableAmounts.assets[owner] <= lockedShares[user] * exchangeRate
        * Invariant L: getRedeemableAmounts.partialLiquidity == (lockedShares[user] * exchangeRate < fundsAsset balance of pool)

    * Withdrawal Manager (Queue)
        * Invariant C: ∀ requestId(owner) != 0 -> request.shares > 0 && request.owner == owner
        * Invariant G: ∀ requestId[lender] ∈ [0, lastRequestId]
        * Invariant H: requestId is unique

    *******************************************************************************************************************************/

    // Struct to avoid stack too deep compiler error.
    struct Invariants {
        bool poolInvariantB;
        bool poolInvariantG;
        bool withdrawalManagerCyclicalInvariantA;
        bool withdrawalManagerCyclicalInvariantB;
        bool withdrawalManagerCyclicalInvariantF;
        bool withdrawalManagerCyclicalInvariantG;
        bool withdrawalManagerCyclicalInvariantH;
        bool withdrawalManagerCyclicalInvariantI;
        bool withdrawalManagerCyclicalInvariantJ;
        bool withdrawalManagerCyclicalInvariantK;
        bool withdrawalManagerCyclicalInvariantL;
        bool withdrawalManagerQueueInvariantC;
        bool withdrawalManagerQueueInvariantG;
        bool withdrawalManagerQueueInvariantH;
    }

    function checkInvariants(address poolManager_, address[] memory poolLps_) external view returns (Invariants memory invariants_) {
        IPoolManager poolManager = IPoolManager(poolManager_);

        address pool_              = poolManager.pool();
        address withdrawalManager_ = poolManager.withdrawalManager();

        bool noSupply = IERC20(pool_).totalSupply() == 0;

        bool isWithdrawalManagerCyclical_ = isWithdrawalManagerCyclical(withdrawalManager_);

        invariants_.poolInvariantB = check_pool_invariant_B(pool_, withdrawalManager_, poolLps_);
        invariants_.poolInvariantG = check_pool_invariant_G(pool_, withdrawalManager_, poolLps_);

        invariants_.withdrawalManagerCyclicalInvariantA =
            (noSupply || !isWithdrawalManagerCyclical_) ||
            check_withdrawalManagerCyclical_invariant_A(pool_, withdrawalManager_, poolLps_);
        invariants_.withdrawalManagerCyclicalInvariantB =
            (noSupply || !isWithdrawalManagerCyclical_) ||
            check_withdrawalManagerCyclical_invariant_B(withdrawalManager_, poolLps_);
        invariants_.withdrawalManagerCyclicalInvariantF =
            (noSupply || !isWithdrawalManagerCyclical_) ||
            check_withdrawalManagerCyclical_invariant_F(pool_, withdrawalManager_, poolLps_);
        invariants_.withdrawalManagerCyclicalInvariantG =
            (noSupply || !isWithdrawalManagerCyclical_) ||
            check_withdrawalManagerCyclical_invariant_G(withdrawalManager_, poolLps_);
        invariants_.withdrawalManagerCyclicalInvariantH =
            (noSupply || !isWithdrawalManagerCyclical_) ||
            check_withdrawalManagerCyclical_invariant_H(withdrawalManager_, poolLps_);
        invariants_.withdrawalManagerCyclicalInvariantI =
            (noSupply || !isWithdrawalManagerCyclical_) ||
            check_withdrawalManagerCyclical_invariant_I(pool_, withdrawalManager_, poolLps_);
        invariants_.withdrawalManagerCyclicalInvariantJ =
            (noSupply || !isWithdrawalManagerCyclical_) ||
            check_withdrawalManagerCyclical_invariant_J(pool_, withdrawalManager_, poolLps_);
        invariants_.withdrawalManagerCyclicalInvariantK =
            (noSupply || !isWithdrawalManagerCyclical_) ||
            check_withdrawalManagerCyclical_invariant_K(pool_, withdrawalManager_, poolLps_);
        invariants_.withdrawalManagerCyclicalInvariantL =
            (noSupply || !isWithdrawalManagerCyclical_) ||
            check_withdrawalManagerCyclical_invariant_L(pool_, withdrawalManager_, poolLps_);

        invariants_.withdrawalManagerQueueInvariantC =
            isWithdrawalManagerCyclical_ || check_withdrawalManagerQueue_invariant_C(withdrawalManager_, poolLps_);
        invariants_.withdrawalManagerQueueInvariantG =
            isWithdrawalManagerCyclical_ || check_withdrawalManagerQueue_invariant_G(withdrawalManager_, poolLps_);
        invariants_.withdrawalManagerQueueInvariantH =
            isWithdrawalManagerCyclical_ || check_withdrawalManagerQueue_invariant_H(withdrawalManager_, poolLps_);
    }

    /******************************************************************************************************************************/
    /*** Pool Invariants                                                                                                        ***/
    /******************************************************************************************************************************/

    function check_pool_invariant_B(
        address          pool_,
        address          withdrawManager_,
        address[] memory poolLps_
    ) public view returns (bool isMaintained_) {
        if (poolLps_.length == 0) return true;

        IPool pool = IPool(pool_);

        uint256 sumBalanceOfAssets;

        for (uint256 i; i < poolLps_.length; i++) {
            sumBalanceOfAssets += IPool(pool_).balanceOfAssets(poolLps_[i]);
        }

        sumBalanceOfAssets += IPool(pool_).balanceOfAssets(withdrawManager_);

        isMaintained_ = _getDiff(pool.totalAssets(), sumBalanceOfAssets) <= poolLps_.length;
    }

    function check_pool_invariant_G(
        address          pool_,
        address          withdrawManager_,
        address[] memory poolLps_
    ) public view returns (bool isMaintained_) {
        if (poolLps_.length == 0) return true;

        IPool pool = IPool(pool_);

        uint256 sumBalanceOf;

        for (uint256 i; i < poolLps_.length; i++) {
            sumBalanceOf += IPool(pool_).balanceOf(poolLps_[i]);
        }

        sumBalanceOf += IPool(pool_).balanceOf(withdrawManager_);

        isMaintained_ = pool.totalSupply() == sumBalanceOf;
    }

    /******************************************************************************************************************************/
    /*** Withdrawal Manager Invariants (Cyclical)                                                                               ***/
    /******************************************************************************************************************************/

    function check_withdrawalManagerCyclical_invariant_A(
        address          pool_,
        address          withdrawalManager_,
        address[] memory poolLps_
    ) public view returns (bool isMaintained_) {
        if (poolLps_.length == 0) return true;

        uint256 sumLockedShares;

        for (uint256 i; i < poolLps_.length; i++) {
            sumLockedShares += IWithdrawalManager(withdrawalManager_).lockedShares(poolLps_[i]);
        }

        isMaintained_ = IPool(pool_).balanceOf(address(withdrawalManager_)) == sumLockedShares;
    }

    function check_withdrawalManagerCyclical_invariant_B(
        address          withdrawalManager_,
        address[] memory poolLps_
    ) public view returns (bool isMaintained_) {
        if (poolLps_.length == 0) return true;

        IWithdrawalManager withdrawalManager = IWithdrawalManager(withdrawalManager_);

        uint256 currentCycleId = withdrawalManager.getCurrentCycleId();

        for (uint256 cycleId = 1; cycleId <= currentCycleId; ++cycleId) {
            uint256 sumCycleShares;

            for (uint256 i; i < poolLps_.length; ++i) {
                if (withdrawalManager.exitCycleId(poolLps_[i]) == cycleId) {
                    sumCycleShares += withdrawalManager.lockedShares(poolLps_[i]);
                }
            }

            if (withdrawalManager.totalCycleShares(cycleId) != sumCycleShares) return false;
        }

        isMaintained_ = true;
    }

    function check_withdrawalManagerCyclical_invariant_F(
        address          pool_,
        address          withdrawalManager_,
        address[] memory poolLps_
    ) public view returns (bool isMaintained_) {
        IWithdrawalManager withdrawalManager = IWithdrawalManager(withdrawalManager_);

        for (uint256 i; i < poolLps_.length; i++) {
            ( uint256 shares, , ) = withdrawalManager.getRedeemableAmounts(withdrawalManager.lockedShares(poolLps_[i]), poolLps_[i]);

            if (shares > IPool(pool_).balanceOf(withdrawalManager_)) return false;
        }

        isMaintained_ = true;
    }

    function check_withdrawalManagerCyclical_invariant_G(
        address          withdrawalManager_,
        address[] memory poolLps_
    ) public view returns (bool isMaintained_) {
        IWithdrawalManager withdrawalManager = IWithdrawalManager(withdrawalManager_);

        for (uint256 i; i < poolLps_.length; i++) {
            ( uint256 shares, , ) = withdrawalManager.getRedeemableAmounts(withdrawalManager.lockedShares(poolLps_[i]), poolLps_[i]);

            if (shares > withdrawalManager.lockedShares(poolLps_[i])) return false;
        }

        isMaintained_ = true;
    }

    function check_withdrawalManagerCyclical_invariant_H(
        address          withdrawalManager_,
        address[] memory poolLps_
    ) public view returns (bool isMaintained_) {
        IWithdrawalManager withdrawalManager = IWithdrawalManager(withdrawalManager_);

        for (uint256 i; i < poolLps_.length; i++) {
            ( uint256 shares, , ) = withdrawalManager.getRedeemableAmounts(withdrawalManager.lockedShares(poolLps_[i]), poolLps_[i]);

            if (shares > withdrawalManager.totalCycleShares(withdrawalManager.exitCycleId( poolLps_[i]))) return false;
        }

        isMaintained_ = true;
    }

    function check_withdrawalManagerCyclical_invariant_I(
        address          pool_,
        address          withdrawalManager_,
        address[] memory poolLps_
    ) public view returns (bool isMaintained_) {
        IWithdrawalManager withdrawalManager = IWithdrawalManager(withdrawalManager_);

        for (uint256 i; i < poolLps_.length; i++) {
            ( , uint256 assets, ) = withdrawalManager.getRedeemableAmounts(withdrawalManager.lockedShares(poolLps_[i]), poolLps_[i]);

            if (assets > IERC20(IPool(pool_).asset()).balanceOf(pool_)) return false;
        }

        isMaintained_ = true;
    }

    function check_withdrawalManagerCyclical_invariant_J(
        address          pool_,
        address          withdrawalManager_,
        address[] memory poolLps_
    ) public view returns (bool isMaintained_) {
        IWithdrawalManager withdrawalManager = IWithdrawalManager(withdrawalManager_);

        for (uint256 i; i < poolLps_.length; i++) {
            ( , uint256 assets, ) = withdrawalManager.getRedeemableAmounts(withdrawalManager.lockedShares(poolLps_[i]), poolLps_[i]);

            uint256 totalRequestedLiquidity = _getTotalRequestedLiquidity(pool_, withdrawalManager_, poolLps_[i]);

            if (assets > totalRequestedLiquidity) return false;
        }

        isMaintained_ = true;
    }

    function check_withdrawalManagerCyclical_invariant_K(
        address          pool_,
        address          withdrawalManager_,
        address[] memory poolLps_
    ) public view returns (bool isMaintained_) {
        IPool pool = IPool(pool_);

        IWithdrawalManager withdrawalManager = IWithdrawalManager(withdrawalManager_);

        if (pool.totalSupply() == 0) return true;

        for (uint256 i; i < poolLps_.length; i++) {
            ( , uint256 assets, ) = withdrawalManager.getRedeemableAmounts(withdrawalManager.lockedShares(poolLps_[i]), poolLps_[i]);

            uint256 lpRequestedLiquidity =
                (withdrawalManager.lockedShares(poolLps_[i]) * (pool.totalAssets() - pool.unrealizedLosses())) / pool.totalSupply();

            if (assets > lpRequestedLiquidity) return false;
        }

        isMaintained_ = true;
    }

    function check_withdrawalManagerCyclical_invariant_L(
        address          pool_,
        address          withdrawalManager_,
        address[] memory poolLps_
    ) public view returns (bool isMaintained_) {
        IWithdrawalManager withdrawalManager = IWithdrawalManager(withdrawalManager_);

        for (uint256 i; i < poolLps_.length; i++) {
            ( , , bool partialLiquidity ) =
                withdrawalManager.getRedeemableAmounts(withdrawalManager.lockedShares(poolLps_[i]), poolLps_[i]);

            uint256 totalRequestedLiquidity = _getTotalRequestedLiquidity(pool_, withdrawalManager_, poolLps_[i]);

            if (partialLiquidity != (IERC20(IPool(pool_).asset()).balanceOf(pool_) < totalRequestedLiquidity)) return false;
        }

        isMaintained_ = true;
    }

    /******************************************************************************************************************************/
    /*** Withdrawal Manager Invariants (Queue)                                                                                  ***/
    /******************************************************************************************************************************/

    function check_withdrawalManagerQueue_invariant_C(
        address          withdrawalManager_,
        address[] memory poolLps_
    ) public view returns (bool isMaintained_) {
        IWithdrawalManagerQueue withdrawalManager = IWithdrawalManagerQueue(withdrawalManager_);

        address owner;
        uint128 requestId;
        uint256 shares;

        for (uint256 i; i < poolLps_.length; i++) {
            requestId = withdrawalManager.requestIds(poolLps_[i]);

            if (requestId != 0) {
                ( owner, shares ) = withdrawalManager.requests(requestId);

                if (!(shares > 0 && owner == poolLps_[i])) {
                    return false;
                }
            }
        }

        return true;
    }

    function check_withdrawalManagerQueue_invariant_G(
        address          withdrawalManager_,
        address[] memory poolLps_
    ) public view returns (bool isMaintained_) {
        IWithdrawalManagerQueue withdrawalManager = IWithdrawalManagerQueue(withdrawalManager_);

        uint128 requestId;

        ( , uint128 lastRequestId) = withdrawalManager.queue();

        for (uint256 i; i < poolLps_.length; i++) {
            requestId = withdrawalManager.requestIds(poolLps_[i]);

            if (requestId > lastRequestId) {
                return false;
            }
        }

        return true;
    }

    function check_withdrawalManagerQueue_invariant_H(
        address          withdrawalManager_,
        address[] memory poolLps_
    ) public view returns (bool isMaintained_) {
        IWithdrawalManagerQueue withdrawalManager = IWithdrawalManagerQueue(withdrawalManager_);

        uint128 requestId;

        uint128[] memory requestIdList = new uint128[](poolLps_.length);

        for (uint256 i; i < poolLps_.length; i++) {
            requestId = withdrawalManager.requestIds(poolLps_[i]);

            for (uint256 j; j < i; j++) {
                if (requestId == requestIdList[j] && requestId != 0) {
                    return false;
                }
            }

            requestIdList[i] = requestId;
        }

        return true;
    }

    /******************************************************************************************************************************/
    /*** Helpers                                                                                                                ***/
    /******************************************************************************************************************************/

    function _getTotalRequestedLiquidity(
        address pool_,
        address withdrawalManager_,
        address poolLp_
    ) internal view returns (uint256 totalRequestedLiquidity_) {
        uint256 supply = IPool(pool_).totalSupply();

        if (supply == 0) return 0;

        totalRequestedLiquidity_ =
            (
                IWithdrawalManager(withdrawalManager_).totalCycleShares(
                    IWithdrawalManager(withdrawalManager_).exitCycleId(poolLp_)
                ) *
                (
                    IPool(pool_).totalAssets() - IPool(pool_).unrealizedLosses()
                )
            ) / IPool(pool_).totalSupply();
    }

    function _getDiff(uint256 x, uint256 y) internal pure returns (uint256 diff) {
        diff = x > y ? x - y : y - x;
    }

    function isWithdrawalManagerCyclical(address wm) internal view returns (bool isWithdrawalManagerCyclical_) {
        try IWithdrawalManager(wm).getCurrentCycleId() {
            isWithdrawalManagerCyclical_ = true;
        } catch { }
    }

}
