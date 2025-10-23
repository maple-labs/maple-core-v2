// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAssetController,
    IBitcoinStrategy,
    IERC20,
    IPool,
    IPoolManager,
    ISyrupBitcoinRouter,
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

    ***************************************************************************************************************************************/

    struct Invariants {
        bool syrupBTCInvariantA;
        bool syrupBTCInvariantB;
        bool syrupBTCInvariantC;
        bool syrupBTCInvariantD;
        bool syrupBTCInvariantE;
        bool syrupBTCInvariantF;
        bool syrupBTCInvariantG;
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

}
