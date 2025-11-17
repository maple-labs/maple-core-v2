// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAssetController,
    IBitcoinStrategy,
    IERC20,
    IPool,
    IPoolManager,
    IPoolPermissionManager,
    ISyrupBitcoinRouter,
    IStrategyLike,
    IWithdrawalManagerQueue
} from "../../contracts/interfaces/Interfaces.sol";

contract SyrupBTCHealthChecker {

    /**************************************************************************************************************************************/
    /*** Invariant Tests                                                                                                                ***/
    /***************************************************************************************************************************************
    * Syrup BTC
        * Invariant A: depositAssets(wBTC) == poolAssets(wBTC)
        * Invariant B: balanceOf(pool) == poolAssets(wBTC)
        * Invariant C: totalSupply == balanceOf(pool)
        * Invariant D: balanceOf(wm) >= Σrequest.shares
        * Invariant E: Σrouter.request.shares == Σwm.request.shares + manualShares(router)
        * Invariant F: (remainingYield > 0) == (remainingDuration > 0)
        * Invariant G: accruedFees() <= accruedYield()

    * Pool
        * Invariant A: totalAssets > fundsAsset balance of pool
        * Invariant D: convertToAssets(totalSupply) == totalAssets (with rounding)
        * Invariant E: convertToShares(totalAssets) == totalSupply (with rounding)
        * Invariant I: totalAssets == poolManager.totalAssets()
        * Invariant J: unrealizedLosses == poolManager.unrealizedLosses()
        * Invariant K: convertToExitShares == poolManager.convertToExitShares()

    * PoolManager
        * Invariant A: totalAssets == cash + ∑assetsUnderManagement[loanManager]
        * Invariant B: totalAssets >= unrealizedLosses

    * Withdrawal Manager (Queue)
        * Invariant A: ∑request.shares + ∑owner.manualShares == totalShares
        * Invariant B: balanceOf(this) >= totalShares
        * Invariant D: nextRequestId <= lastRequestId + 1
        * Invariant E: nextRequestId != 0
        * Invariant F: requests(0) == (0, 0)
        * Invariant H: requestId is unique && owner is bitcoinRouter

    ***************************************************************************************************************************************/

    struct Invariants {
        bool syrupBTCInvariantA;
        bool syrupBTCInvariantB;
        bool syrupBTCInvariantC;
        bool syrupBTCInvariantD;
        bool syrupBTCInvariantE;
        bool syrupBTCInvariantF;
        bool syrupBTCInvariantG;
        bool poolInvariantA;
        bool poolInvariantD;
        bool poolInvariantE;
        bool poolInvariantI;
        bool poolInvariantJ;
        bool poolInvariantK;
        bool poolManagerInvariantA;
        bool poolManagerInvariantB;
        bool poolPermissionManagerInvariantA;
        bool withdrawalManagerQueueInvariantA;
        bool withdrawalManagerQueueInvariantB;
        bool withdrawalManagerQueueInvariantD;
        bool withdrawalManagerQueueInvariantE;
        bool withdrawalManagerQueueInvariantF;
        bool withdrawalManagerQueueInvariantH;
    }

    function checkInvariants(
        address bitcoinRouter_,
        address[] memory depositAssets_
    ) external view returns (Invariants memory invariants_) {
        address pool_        = ISyrupBitcoinRouter(bitcoinRouter_).pool();
        address poolManager_ = IPool(pool_).manager();
        address wm_          = IPoolManager(poolManager_).withdrawalManager();

        invariants_.syrupBTCInvariantA = true;
        invariants_.syrupBTCInvariantB = true;

        for (uint i; i < depositAssets_.length; i++) {
            address depositAsset_ = depositAssets_[i];
            address controller_   = ISyrupBitcoinRouter(bitcoinRouter_).assetController(depositAsset_);

            invariants_.syrupBTCInvariantA =
                invariants_.syrupBTCInvariantA && check_syrupBTC_invariant_A(depositAsset_, controller_);

            invariants_.syrupBTCInvariantB =
                invariants_.syrupBTCInvariantB && check_syrupBTC_invariant_B(depositAsset_, pool_, controller_);
        }

        invariants_.syrupBTCInvariantC = check_syrupBTC_invariant_C(pool_);

        ( , uint256[] memory wmShares_ ) = IWithdrawalManagerQueue(wm_).requestsByOwner(bitcoinRouter_);

        invariants_.syrupBTCInvariantD = check_syrupBTC_invariant_D(pool_, wmShares_);

        ( , uint256 lastRequestId)    = IWithdrawalManagerQueue(wm_).queue();
        uint256[] memory routerShares = new uint256[](lastRequestId + 1);

        for (uint i; i < routerShares.length; i++) {
            ( , , uint256 sharesOnRouter ) = ISyrupBitcoinRouter(bitcoinRouter_).redeemRequests(i);
            routerShares[i]                = sharesOnRouter;
        }

        invariants_.syrupBTCInvariantE = check_syrupBTC_invariant_E(bitcoinRouter_, wm_, routerShares, wmShares_);

        invariants_.syrupBTCInvariantF = true;
        invariants_.syrupBTCInvariantG = true;

        uint256 strategyCount = IPoolManager(poolManager_).strategyListLength();

        for (uint256 i; i < strategyCount; i++) {
            address strategy_ = IPoolManager(poolManager_).strategyList(i);

            invariants_.syrupBTCInvariantF = invariants_.syrupBTCInvariantF && check_syrupBTC_invariant_F(strategy_);
            invariants_.syrupBTCInvariantG = invariants_.syrupBTCInvariantG && check_syrupBTC_invariant_G(strategy_);
        }

        invariants_.poolInvariantA = check_pool_invariant_A(pool_);
        invariants_.poolInvariantD = check_pool_invariant_D(pool_);
        invariants_.poolInvariantE = check_pool_invariant_E(pool_);
        invariants_.poolInvariantI = check_pool_invariant_I(pool_, poolManager_);
        invariants_.poolInvariantJ = check_pool_invariant_J(pool_, poolManager_);
        invariants_.poolInvariantK = check_pool_invariant_K(pool_, poolManager_);

        invariants_.poolManagerInvariantA = check_poolManager_invariant_A(
            IPool(pool_).asset(),
            pool_,
            poolManager_
        );

        invariants_.poolManagerInvariantB = check_poolManager_invariant_B(poolManager_);

        invariants_.poolPermissionManagerInvariantA = check_poolPermissionManager_invariant_A(poolManager_);

        invariants_.withdrawalManagerQueueInvariantA = check_withdrawalManagerQueue_invariant_A(wm_, bitcoinRouter_);
        invariants_.withdrawalManagerQueueInvariantB = check_withdrawalManagerQueue_invariant_B(wm_);
        invariants_.withdrawalManagerQueueInvariantD = check_withdrawalManagerQueue_invariant_D(wm_);
        invariants_.withdrawalManagerQueueInvariantE = check_withdrawalManagerQueue_invariant_E(wm_);
        invariants_.withdrawalManagerQueueInvariantF = check_withdrawalManagerQueue_invariant_F(wm_);
        invariants_.withdrawalManagerQueueInvariantH = check_withdrawalManagerQueue_invariant_H(wm_, bitcoinRouter_);
    }

    /**************************************************************************************************************************************/
    /*** SyrupBTC Invariant Helpers                                                                                                     ***/
    /**************************************************************************************************************************************/

    function check_syrupBTC_invariant_A(address asset, address controller) public view returns (bool isMaintained_) {
        uint256 depositAssets = IAssetController(controller).depositAssets(asset);
        uint256 poolAssets    = IAssetController(controller).poolAssets(asset);

        isMaintained_ = depositAssets == poolAssets;
    }

    function check_syrupBTC_invariant_B(address depositAsset, address pool, address controller) public view returns (bool isMaintained_) {
        address poolAsset      = IPool(pool).asset();
        uint256 poolBalance    = IERC20(poolAsset).balanceOf(pool);
        uint256 poolAccounting = IAssetController(controller).poolAssets(depositAsset);

        isMaintained_ = poolBalance == poolAccounting;
    }

    function check_syrupBTC_invariant_C(address pool) public view returns (bool isMaintained_) {
        address poolAsset   = IPool(pool).asset();
        uint256 poolBalance = IERC20(poolAsset).balanceOf(pool);
        uint256 totalSupply = IERC20(poolAsset).totalSupply();

        isMaintained_ = poolBalance == totalSupply;
    }

    function check_syrupBTC_invariant_D(address pool, uint256[] memory shares) public view returns (bool isMaintained_) {
        address manager      = IPool(pool).manager();
        address wm           = IPoolManager(manager).withdrawalManager();
        uint256 wmBalance    = IERC20(pool).balanceOf(wm);
        uint256 wmAccounting = 0;

        for (uint256 i; i < shares.length; i++) {
            wmAccounting += shares[i];
        }

        isMaintained_ = wmBalance >= wmAccounting;
    }

    function check_syrupBTC_invariant_E(
        address router,
        address wm,
        uint256[] memory routerShares,
        uint256[] memory wmShares
    ) public view returns (bool isMaintained_) {
        uint256 routerAccounting = 0;
        uint256 wmAccounting     = IWithdrawalManagerQueue(wm).manualSharesAvailable(router);

        for (uint256 i; i < routerShares.length; i++) {
            routerAccounting += routerShares[i];
        }

        for (uint256 i; i < wmShares.length; i++) {
            wmAccounting += wmShares[i];
        }

        isMaintained_ = routerAccounting == wmAccounting;
    }

    function check_syrupBTC_invariant_F(address strategy_) public view returns (bool isMaintained_) {
        ( uint256 remainingYield, , uint32 remainingDuration ) = IBitcoinStrategy(strategy_).schedules(0);

        bool nothingScheduled = remainingYield == 0 && remainingDuration == 0;
        bool yieldScheduled   = remainingYield > 0  && remainingDuration > 0;

        isMaintained_ = nothingScheduled || yieldScheduled;
    }

    function check_syrupBTC_invariant_G(address strategy_) public view returns (bool isMaintained_) {
        uint256 accruedFees  = IBitcoinStrategy(strategy_).accruedFees();
        uint256 accruedYield = IBitcoinStrategy(strategy_).accruedYield();

        isMaintained_ = accruedFees <= accruedYield;
    }

    /**************************************************************************************************************************************/
    /*** Pool Invariants                                                                                                                ***/
    /**************************************************************************************************************************************/

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

    /**************************************************************************************************************************************/
    /*** Pool Manager Invariants                                                                                                        ***/
    /**************************************************************************************************************************************/

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

        isMaintained_ = totalAUM + IERC20(fundsAsset_).balanceOf(pool_) == IPoolManager(poolManager_).totalAssets();
    }

    function check_poolManager_invariant_B(address poolManager_) public view returns (bool isMaintained_) {
        IPoolManager poolManager = IPoolManager(poolManager_);

        isMaintained_ = poolManager.totalAssets() >= poolManager.unrealizedLosses();
    }

    /**************************************************************************************************************************************/
    /*** Pool Permission Manager Invariants                                                                                             ***/
    /**************************************************************************************************************************************/

    function check_poolPermissionManager_invariant_A(address poolManager_) public view returns (bool isMaintained_) {
        IPoolPermissionManager ppm = IPoolPermissionManager(IPoolManager(poolManager_).poolPermissionManager());

        uint256 permissionLevel = ppm.permissionLevels(poolManager_);

        isMaintained_ = permissionLevel >= 0 && permissionLevel <= 3;
    }

    /**************************************************************************************************************************************/
    /*** Withdrawal Manager Invariants (Queue)                                                                                          ***/
    /**************************************************************************************************************************************/

    function check_withdrawalManagerQueue_invariant_A(
        address withdrawalManager_,
        address bitcoinRouter_
    ) public view returns (bool isMaintained_) {
        IWithdrawalManagerQueue withdrawalManager = IWithdrawalManagerQueue(withdrawalManager_);

        uint256 shares;
        uint256 sumOfShares;
        uint256 totalShares = withdrawalManager.totalShares();

        ( uint128 nextRequestId, uint128 lastRequestId ) = withdrawalManager.queue();

        for (uint128 requestId = nextRequestId; requestId <= lastRequestId; requestId++) {
            ( , shares ) = withdrawalManager.requests(requestId);

            sumOfShares += shares;
        }

        sumOfShares += withdrawalManager.manualSharesAvailable(bitcoinRouter_);

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

    function check_withdrawalManagerQueue_invariant_H(
        address withdrawalManager_,
        address bitcoinRouter_
    ) public view returns (bool isMaintained_) {
        uint256 prevRequestId;

        ( uint256[] memory requestIds, ) = IWithdrawalManagerQueue(withdrawalManager_).requestsByOwner(bitcoinRouter_);

        for (uint256 i; i < requestIds.length; i++) {
            if (requestIds[i] <= prevRequestId) {
                return false;
            }

            prevRequestId = requestIds[i];
        }

        ( uint256 nextRequestId, uint256 lastRequestId ) = IWithdrawalManagerQueue(withdrawalManager_).queue();

        for (uint256 requestId = nextRequestId; requestId <= lastRequestId; requestId++) {
            ( address owner, ) = IWithdrawalManagerQueue(withdrawalManager_).requests(requestId);

            if (owner != address(0) && owner != bitcoinRouter_) {
                return false;
            }
        }

        return true;
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _getDiff(uint256 x, uint256 y) internal pure returns (uint256 diff) {
        diff = x > y ? x - y : y - x;
    }

}
