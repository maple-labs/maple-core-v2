// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC20,
    IERC4626Like,
    IOpenTermLoanManager,
    IPool,
    IPoolManager,
    IPoolPermissionManager,
    IStrategyLike,
    IWithdrawalManagerQueue
} from "../../contracts/interfaces/Interfaces.sol";

// NOTE: This contract only uses onchain calls to check invariants.
// NOTE: This contract assumes one strategy type is deployed per Pool.
contract ProtocolHealthChecker {

    uint256 internal constant BUFFER = 1e6;

    /******************************************************************************************************************************/
    /*** Invariant Tests                                                                                                        ***/
    /*******************************************************************************************************************************
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
        * Invariant B: totalAssets >= unrealizedLosses

     * Pool Permission Manager
        * Invariant A: pool.permissionLevel ∈ [0, 3]

     * Withdrawal Manager (Queue)
        * Invariant A: ∑request.shares + ∑owner.manualShares == totalShares
        * Invariant B: balanceOf(this) >= totalShares
        * Invariant D: nextRequestId <= lastRequestId + 1
        * Invariant E: nextRequestId != 0
        * Invariant F: requests(0) == (0, 0)

    *******************************************************************************************************************************/

    struct Strategies {
        address openTermLoanManager;
    }

    // Struct to avoid stack too deep compiler error.
    struct Invariants {
        // TODO: Fixed-term loans are deprecated; these are always `true` and only kept so this struct's layout
        //       matches the currently-deployed (pre-deprecation) on-chain health checker. Remove them in the
        //       next health checker release once a struct-aligned checker is deployed.
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
        // NOTE: Cyclical WM is deprecated (all pools use the Queue WM). These fields are kept only so this struct's
        //       ABI layout matches the deployed V2 checker decoded in ProtocolHealthCheckerV3.t.sol; always `true`.
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
        bool strategiesInvariantA;
        bool strategiesInvariantB;
        bool strategiesInvariantC;
        bool strategiesInvariantD;
        bool strategiesInvariantE;
        bool strategiesInvariantF;
        bool strategiesInvariantG;
    }

    function checkInvariants(
        address poolManager_,
        address[] calldata manualRedeemers_
    )
        external
        view
        returns (Invariants memory invariants_)
    {
        IPoolManager poolManager = IPoolManager(poolManager_);

        Strategies memory strategies = _getStrategies(poolManager_);

        invariants_ = _bootstrapInvariantsResults();

        address pool_              = poolManager.pool();
        address fundsAsset_        = IPool(pool_).asset();
        address withdrawalManager_ = poolManager.withdrawalManager();

        if (strategies.openTermLoanManager != address(0)) {
            invariants_.openTermLoanManagerInvariantE = check_openTermLoanManager_invariant_E(strategies.openTermLoanManager);
            invariants_.openTermLoanManagerInvariantG = check_openTermLoanManager_invariant_G(strategies.openTermLoanManager);
        }

        invariants_.poolInvariantA = check_pool_invariant_A(pool_);
        invariants_.poolInvariantD = check_pool_invariant_D(pool_);
        invariants_.poolInvariantE = check_pool_invariant_E(pool_);
        invariants_.poolInvariantI = check_pool_invariant_I(pool_, poolManager_);
        invariants_.poolInvariantJ = check_pool_invariant_J(pool_, poolManager_);
        invariants_.poolInvariantK = check_pool_invariant_K(pool_, poolManager_);

        invariants_.poolManagerInvariantA = check_poolManager_invariant_A(fundsAsset_, pool_, poolManager_);

        invariants_.poolManagerInvariantB = check_poolManager_invariant_B(poolManager_);

        invariants_.poolPermissionManagerInvariantA = check_poolPermissionManager_invariant_A(poolManager_);

        invariants_.withdrawalManagerQueueInvariantA = check_withdrawalManagerQueue_invariant_A(withdrawalManager_, manualRedeemers_);
        invariants_.withdrawalManagerQueueInvariantB = check_withdrawalManagerQueue_invariant_B(withdrawalManager_);
        invariants_.withdrawalManagerQueueInvariantD = check_withdrawalManagerQueue_invariant_D(withdrawalManager_);
        invariants_.withdrawalManagerQueueInvariantE = check_withdrawalManagerQueue_invariant_E(withdrawalManager_);
        invariants_.withdrawalManagerQueueInvariantF = check_withdrawalManagerQueue_invariant_F(withdrawalManager_);
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
                pool.convertToExitShares(pool.totalAssets()) == IPoolManager(poolManager_).convertToExitShares(pool.totalAssets());
        }
    }

    /******************************************************************************************************************************/
    /*** Pool Manager Invariants                                                                                                ***/
    /******************************************************************************************************************************/

    function check_poolManager_invariant_A(
        address fundsAsset_,
        address pool_,
        address poolManager_
    )
        public
        view
        returns (bool isMaintained_)
    {
        uint256 length = IPoolManager(poolManager_).strategyListLength();

        uint256 totalAUM = 0;

        for (uint256 i; i < length; ++i) {
            totalAUM += IStrategyLike(IPoolManager(poolManager_).strategyList(i)).assetsUnderManagement();
        }

        isMaintained_ =
            _assertApproxEqAbs((totalAUM + IERC20(fundsAsset_).balanceOf(pool_)), IPoolManager(poolManager_).totalAssets(), BUFFER);
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
    /*** Withdrawal Manager Invariants (Queue)                                                                                  ***/
    /******************************************************************************************************************************/

    function check_withdrawalManagerQueue_invariant_A(
        address withdrawalManager_,
        address[] calldata manualRedeemers_
    )
        public
        view
        returns (bool isMaintained_)
    {
        IWithdrawalManagerQueue withdrawalManager = IWithdrawalManagerQueue(withdrawalManager_);

        uint256 sumOfShares;
        uint256 totalShares = withdrawalManager.totalShares();

        (uint128 nextRequestId, uint128 lastRequestId) = withdrawalManager.queue();

        for (uint128 requestId = nextRequestId; requestId <= lastRequestId; requestId++) {
            (, uint256 shares) = withdrawalManager.requests(requestId);

            sumOfShares += shares;
        }

        for (uint256 i; i < manualRedeemers_.length; i++) {
            sumOfShares += withdrawalManager.manualSharesAvailable(manualRedeemers_[i]);
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

        (uint128 nextRequestId, uint128 lastRequestId) = withdrawalManager.queue();

        isMaintained_ = nextRequestId <= lastRequestId + 1;
    }

    function check_withdrawalManagerQueue_invariant_E(address withdrawalManager_) public view returns (bool isMaintained_) {
        IWithdrawalManagerQueue withdrawalManager = IWithdrawalManagerQueue(withdrawalManager_);

        (uint128 nextRequestId,) = withdrawalManager.queue();

        isMaintained_ = nextRequestId != 0;
    }

    function check_withdrawalManagerQueue_invariant_F(address withdrawalManager_) public view returns (bool isMaintained_) {
        IWithdrawalManagerQueue withdrawalManager = IWithdrawalManagerQueue(withdrawalManager_);

        (address owner, uint256 shares) = withdrawalManager.requests(0);

        isMaintained_ = shares == 0 && owner == address(0);
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
        // TODO: Fixed-term loans are deprecated; kept always-true only to preserve the deployed checker's struct
        //       layout. Remove in the next health checker release.
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

    function _getDiff(uint256 x, uint256 y) internal pure returns (uint256 diff) {
        diff = x > y ? x - y : y - x;
    }

    function _getStrategies(address poolManager) internal view returns (Strategies memory strategies) {
        uint256 length = IPoolManager(poolManager).strategyListLength();

        for (uint256 i = 0; i < length; i++) {
            address strategy = IPoolManager(poolManager).strategyList(i);
            if (_isOpenTermLoanManager(strategy)) strategies.openTermLoanManager = strategy;
        }
    }

    function _isOpenTermLoanManager(address loan) internal view returns (bool isOpenTermLoanManager_) {
        try IOpenTermLoanManager(loan).paymentFor(address(0)) {
            isOpenTermLoanManager_ = true;
        } catch { }
    }

}
