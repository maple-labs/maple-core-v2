// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    ICompositeToken,
    IMockERC20,
    IPool,
    IPoolManager,
    ISyrupBitcoinRouter,
    IWithdrawalManagerQueue,
    Permit
} from "../../../contracts/interfaces/Interfaces.sol";

import { console } from "../../../contracts/Runner.sol";

import { HandlerBase } from "./HandlerBase.sol";

// TODO: Should max deposit values be different?
contract BitcoinRouterHandler is HandlerBase {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    address poolDelegate;

    bytes32 emptyMetadata = "";

    uint256 maxDeposit = 10_000e8;

    address[] liquidityProviders;

    uint256[] requestIdCache;

    Permit emptyPermit;

    ISyrupBitcoinRouter     bitcoinRouter;
    IMockERC20              depositAsset;
    IPool                   pool;
    ICompositeToken         poolAsset;
    IPoolManager            poolManager;
    IWithdrawalManagerQueue withdrawalManager;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(ISyrupBitcoinRouter router, IMockERC20 asset, address[] memory lps) {
        bitcoinRouter      = router;
        depositAsset       = asset;
        liquidityProviders = lps;

        pool              = IPool(router.pool());
        poolAsset         = ICompositeToken(pool.asset());
        poolManager       = IPoolManager(pool.manager());
        poolDelegate      = poolManager.poolDelegate();
        withdrawalManager = IWithdrawalManagerQueue(poolManager.withdrawalManager());

        emptyPermit = Permit(false, 0, 0, 0, 0);
    }

    /**************************************************************************************************************************************/
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function deposit(uint256 seed) external {
        console.log("brh.deposit(%s)", seed);
        numberOfCalls["brh.deposit"]++;

        address lp = selectLp(seed);

        randomDeposit(seed, lp);
    }

    function processRedemptionsOnRouter(uint256 seed) external {
        console.log("brh.processRedemptionOnRouter(%s)", seed);
        numberOfCalls["brh.processRedemptionsOnRouter"]++;

        uint256[] memory requestIds = selectRequestsToRedeem(seed);

        // Skip if nothing can be redeemed.
        if (requestIds.length == 0) {
            return;
        }

        vm.prank(poolDelegate);
        bitcoinRouter.processRedemptions(requestIds);
    }

    function processRedemptionsOnWm(uint256 seed) external {
        console.log("brh.processRedemptionOnWm(%s)", seed);
        numberOfCalls["brh.processRedemptionsOnWm"]++;

        uint256 sharesToProcess = selectRequestsToProcess(seed);

        // Skip if nothing can be processed.
        if (sharesToProcess == 0) {
            return;
        }

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(sharesToProcess);
    }

    function processEmptyRedemptionsOnWm(uint256 seed) external {
        console.log("brh.processEmptyRedemptionsOnWm(%s)", seed);
        numberOfCalls["brh.processEmptyRedemptionsOnWm"]++;

        ( uint128 nextRequestId, uint128 lastRequestId ) = withdrawalManager.queue();

        if (nextRequestId >= lastRequestId) return;

        uint256 numberOfRequests = lastRequestId - nextRequestId;
        uint256 numberOfRequestsToProcess = _bound(_randomize(seed, "numberOfRequestsToProcess"), 1, numberOfRequests);

        vm.prank(poolDelegate);
        withdrawalManager.processEmptyRedemptions(numberOfRequestsToProcess);
    }

    function removeRequests(uint256 seed) external {
        console.log("brh.removeRequests(%s)", seed);
        numberOfCalls["brh.removeRequests"]++;

        ( uint256 requestId, address lp, uint256 shares ) = selectRequest(seed);

        // Request a new withdrawal if you couldn't find one (or if you selected a cancelled request).
        if (shares == 0) {
            lp     = selectLp(seed);
            shares = sharesOf(lp);

            // Deposit some assets so a withdrawal can be requested.
            if (shares == 0) {
                shares = randomDeposit(seed, lp);
            }

            ( shares, requestId ) = randomRequestRedeem(seed, lp, shares);
        }

        removeRequest(lp, requestId);
    }

    function removeSharesById(uint256 seed) external {
        console.log("brh.removeSharesById(%s)", seed);
        numberOfCalls["brh.removeSharesById"]++;

        ( uint256 requestId, address lp, uint256 shares ) = selectRequest(seed);

        // Request a new withdrawal if you couldn't find one (or if you selected a cancelled request).
        if (shares == 0) {
            lp     = selectLp(seed);
            shares = sharesOf(lp);

            // Deposit some assets so a withdrawal can be requested.
            if (shares == 0) {
                shares = randomDeposit(seed, lp);
            }

            ( shares, requestId ) = randomRequestRedeem(seed, lp, shares);
        }

        randomRemoveSharesById(seed, lp, requestId, shares);
    }

    function requestRedeem(uint256 seed) external {
        console.log("brh.requestRedeem(%s)", seed);
        numberOfCalls["brh.requestRedeem"]++;

        address lp     = selectLp(seed);
        uint256 shares = sharesOf(lp);

        // Deposit some assets so a withdrawal can be requested.
        if (shares == 0) {
            shares = randomDeposit(seed, lp);
        }

        randomRequestRedeem(seed, lp, shares);
    }

    function setFees(uint256 seed) external {
        console.log("brh.setFees(%s)", seed);
        numberOfCalls["brh.setFees"]++;

        uint256 mintFeeRate       = _bound(_randomize(seed, "mint"),   0, 1e6);
        uint256 redemptionFeeRate = _bound(_randomize(seed, "redeem"), 0, 1e6);

        vm.prank(poolDelegate);
        bitcoinRouter.setFees(address(depositAsset), mintFeeRate, redemptionFeeRate);
    }

    /**************************************************************************************************************************************/
    /*** Utilities                                                                                                                      ***/
    /**************************************************************************************************************************************/

    function randomDeposit(uint256 seed, address lp) internal returns (uint256 shares) {
        uint256 assets = selectAssets(seed, 1, maxDeposit);

        vm.startPrank(lp);
        depositAsset.mint(lp, assets);
        depositAsset.approve(address(bitcoinRouter), assets);
        shares = bitcoinRouter.deposit(address(depositAsset), assets, emptyMetadata, emptyPermit);
        vm.stopPrank();
    }

    function randomRequestRedeem(uint256 seed, address lp, uint256 maxShares) internal returns (uint256 shares, uint256 requestId) {
        shares = selectShares(seed, 1, maxShares);

        vm.startPrank(lp);
        pool.approve(address(bitcoinRouter), shares);
        ( shares, requestId ) = bitcoinRouter.requestRedeem(address(depositAsset), shares, emptyMetadata, emptyPermit);
        vm.stopPrank();
    }

    function randomRemoveSharesById(uint256 seed, address lp, uint256 requestId, uint256 maxShares) internal {
        uint256 shares = selectShares(seed, 1, maxShares);

        vm.prank(lp);
        bitcoinRouter.removeSharesById(requestId, shares);
    }

    function removeRequest(address lp, uint256 requestId) internal {
        uint256[] memory requestIds = new uint256[](1);

        requestIds[0] = requestId;

        vm.prank(poolDelegate);
        bitcoinRouter.removeRequests(lp, requestIds);
    }

    function routerShares() public view returns (uint256 requestShares) {
        // NOTE: The router doesn't know which requests were fully processed, so search from the start of the queue instead.
        uint256 nextRequestId = 1;

        ( , uint256 lastRequestId ) = withdrawalManager.queue();

        for ( ; nextRequestId <= lastRequestId; nextRequestId++) {
            ( , , uint256 shares ) = bitcoinRouter.redeemRequests(nextRequestId);

            requestShares += shares;
        }
    }

    function selectAssets(uint256 seed, uint256 from, uint256 to) internal pure returns (uint256 assets) {
        assets = _bound(_randomize(seed, "assets"), from, to);
    }

    function selectLp(uint256 seed) internal view returns (address lp) {
        uint256 index = _bound(_randomize(seed, "lp"), 0, liquidityProviders.length - 1);

        lp = liquidityProviders[index];
    }

    function selectRequest(uint256 seed) internal view returns (uint256 requestId, address lp, uint256 shares) {
        ( uint256 nextRequestId, uint256 lastRequestId ) = withdrawalManager.queue();

        if (nextRequestId > lastRequestId) {
            return (0, address(0), 0);
        }

        requestId = _bound(_randomize(seed, "request"), nextRequestId, lastRequestId);

        // NOTE: These values can be zero if the request has been cancelled but not yet processed.
        ( , lp, )    = bitcoinRouter.redeemRequests(requestId);
        ( , shares ) = withdrawalManager.requests(requestId);
    }

    function selectRequestsToProcess(uint256 seed) internal view returns (uint256 totalShares) {
        ( uint256 nextRequestId, uint256 lastRequestId ) = withdrawalManager.queue();

        uint256 liquidity = poolAsset.balanceOf(address(pool));

        // Select as many requests as can be processed.
        for ( ; nextRequestId <= lastRequestId; nextRequestId++) {

            // Stop selecting requests once there is no liquidity left.
            if (liquidity == 0) {
                break;
            }

            ( , uint256 shares ) = withdrawalManager.requests(nextRequestId);

            // Skip cancelled requests.
            if (shares == 0) {
                continue;
            }

            uint256 assets = pool.convertToExitAssets(shares);

            // Stop selecting requests if you can't fully process the current one.
            // TODO: Replace this with logic that partially processes the request instead.
            if (liquidity < assets) {
                break;
            }

            totalShares += shares;
            liquidity -= assets;
        }

        totalShares = _bound(_randomize(seed, "totalShares"), 0, totalShares);
    }

    function selectRequestsToRedeem(uint256 seed) internal returns (uint256[] memory requestIds) {
        // NOTE: The router doesn't know which requests were fully processed, so search from the start of the queue instead.
        uint256 nextRequestId = 1;

        ( , uint256 lastRequestId ) = withdrawalManager.queue();

        uint256 liquidity = poolAsset.balanceOf(address(pool));

        for ( ; nextRequestId <= lastRequestId; nextRequestId++) {
            // Stop selecting requests once there is no liquidity left.
            if (liquidity == 0) {
                break;
            }

            ( , , uint256 totalShares     ) = bitcoinRouter.redeemRequests(nextRequestId);
            ( ,   uint256 remainingShares ) = withdrawalManager.requests(nextRequestId);

            uint256 processedShares = totalShares - remainingShares;

            // Skip cancelled requests.
            if (processedShares == 0) {
                continue;
            }

            uint256 assets = pool.convertToExitAssets(processedShares);

            // Stop selecting requests if you can't fully redeem this one.
            if (liquidity < assets) {
                break;
            }

            requestIdCache.push(nextRequestId);
            liquidity -= assets;
        }

        // Pick random number of request to redeem
        uint256 numberOfProcessedRequests = requestIdCache.length;
        uint256 numberOfRequestsToRedeem  = _bound(_randomize(seed, "requestsToRedeem"), 0, numberOfProcessedRequests);

        requestIds = new uint256[](numberOfRequestsToRedeem);

        // Pick random requests to redeem in completely random order
        for (uint256 i; i < numberOfRequestsToRedeem; i++) {
            uint256 randomIndex = _bound(_randomize(seed, "requestIndex"), 0, requestIdCache.length - 1);

            requestIds[i] = requestIdCache[randomIndex];

            requestIdCache[randomIndex] = requestIdCache[requestIdCache.length - 1];
            requestIdCache.pop();
        }

        delete requestIdCache;
    }

    function selectShares(uint256 seed, uint256 from, uint256 to) internal pure returns (uint256 shares) {
        shares = _bound(_randomize(seed, "shares"), from, to);
    }

    function sharesOf(address lp) internal view returns (uint256 shares) {
        shares = pool.balanceOf(lp);
    }

    function wmShares() public view returns (uint256[] memory shares) {
        ( uint256 nextRequestId, uint256 lastRequestId ) = withdrawalManager.queue();

        uint256 index;
        uint256 length = nextRequestId <= lastRequestId ? lastRequestId - nextRequestId + 1 : 0;

        if (length > 0) {
            shares = new uint256[](length);
        }

        while (nextRequestId <= lastRequestId) {
            ( , shares[index] ) = withdrawalManager.requests(nextRequestId);

            nextRequestId++;
            index++;
        }
    }

}
