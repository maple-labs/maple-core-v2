// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IERC20,
    IPool,
    IPoolManager,
    IWithdrawalManagerCyclical as IWithdrawalManager
} from "../../contracts/interfaces/Interfaces.sol";

contract LPHealthChecker {

    /******************************************************************************************************************************/
    /*** Invariant Tests                                                                                                        ***/
    /*******************************************************************************************************************************
    * Pool (non-liquidating)
        * Invariant B: ∑balanceOfAssets == totalAssets (with rounding)
        * Invariant G: ∑balanceOf[user] == totalSupply

    * Withdrawal Manager
        * Invariant A: WM LP balance == ∑lockedShares(user)
        * Invariant B: totalCycleShares == ∑lockedShares(user)[cycle] (for all cycles)
        * Invariant F: getRedeemableAmounts.shares[owner] <= WM LP balance
        * Invariant G: getRedeemableAmounts.shares[owner] <= lockedShares[user]
        * Invariant H: getRedeemableAmounts.shares[owner] <= totalCycleShares[exitCycleId[user]]
        * Invariant I: getRedeemableAmounts.assets[owner] <= fundsAsset balance of pool
        * Invariant J: getRedeemableAmounts.assets[owner] <= totalCycleShares[exitCycleId[user]] * exchangeRate
        * Invariant K: getRedeemableAmounts.assets[owner] <= lockedShares[user] * exchangeRate
        * Invariant L: getRedeemableAmounts.partialLiquidity == (lockedShares[user] * exchangeRate < fundsAsset balance of pool)

    *******************************************************************************************************************************/

    // Struct to avoid stack too deep compiler error.
    struct Invariants {
        bool poolInvariantB;
        bool poolInvariantG;
        bool withdrawalManagerInvariantA;
        bool withdrawalManagerInvariantB;
        bool withdrawalManagerInvariantF;
        bool withdrawalManagerInvariantG;
        bool withdrawalManagerInvariantH;
        bool withdrawalManagerInvariantI;
        bool withdrawalManagerInvariantJ;
        bool withdrawalManagerInvariantK;
        bool withdrawalManagerInvariantL;
    }

    function checkInvariants(address poolManager_, address[] memory poolLps_) external view returns (Invariants memory invariants_) {
        IPoolManager poolManager = IPoolManager(poolManager_);

        address pool_              = poolManager.pool();
        address withdrawalManager_ = poolManager.withdrawalManager();

        bool noSupply = IERC20(pool_).totalSupply() == 0;

        invariants_.poolInvariantB = check_pool_invariant_B(pool_, withdrawalManager_, poolLps_);
        invariants_.poolInvariantG = check_pool_invariant_G(pool_, withdrawalManager_, poolLps_);

        invariants_.withdrawalManagerInvariantA = noSupply || check_withdrawalManager_invariant_A(pool_, withdrawalManager_, poolLps_);
        invariants_.withdrawalManagerInvariantB = noSupply || check_withdrawalManager_invariant_B(withdrawalManager_, poolLps_);
        invariants_.withdrawalManagerInvariantF = noSupply || check_withdrawalManager_invariant_F(pool_, withdrawalManager_, poolLps_);
        invariants_.withdrawalManagerInvariantG = noSupply || check_withdrawalManager_invariant_G(withdrawalManager_, poolLps_);
        invariants_.withdrawalManagerInvariantH = noSupply || check_withdrawalManager_invariant_H(withdrawalManager_, poolLps_);
        invariants_.withdrawalManagerInvariantI = noSupply || check_withdrawalManager_invariant_I(pool_, withdrawalManager_, poolLps_);
        invariants_.withdrawalManagerInvariantJ = noSupply || check_withdrawalManager_invariant_J(pool_, withdrawalManager_, poolLps_);
        invariants_.withdrawalManagerInvariantK = noSupply || check_withdrawalManager_invariant_K(pool_, withdrawalManager_, poolLps_);
        invariants_.withdrawalManagerInvariantL = noSupply || check_withdrawalManager_invariant_L(pool_, withdrawalManager_, poolLps_);
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
    /*** Withdrawal Manager Invariants                                                                                          ***/
    /******************************************************************************************************************************/

    function check_withdrawalManager_invariant_A(
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

    function check_withdrawalManager_invariant_B(
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

    function check_withdrawalManager_invariant_F(
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

    function check_withdrawalManager_invariant_G(
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

    function check_withdrawalManager_invariant_H(
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

    function check_withdrawalManager_invariant_I(
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

    function check_withdrawalManager_invariant_J(
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

    function check_withdrawalManager_invariant_K(
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

    function check_withdrawalManager_invariant_L(
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

}
