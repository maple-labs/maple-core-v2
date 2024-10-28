// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

contract ProcessExitFuzzTests is TestBaseWithAssertions {

    uint256 constant MAX_SHARES = 1e30;
    uint256 constant MIN_SHARES = 100;

    uint128 lastRequestId;
    uint256 totalShares;

    mapping(address => bool)    lpManuals;
    mapping(address => uint256) lpShares;
    mapping(uint128 => address) lpRequests;

    function setUp() public override {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createPoolWithQueue();
        _configurePool();

        openPool(address(poolManager));
    }

    function testFuzz_processExit(
        address[10] memory lps,
        bool[10]    memory isManual,
        uint256[10] memory shares,
        uint256            sharesToProcess
    )
        external
    {
        for (uint256 i = 0; i < 10; i++) {
            if (lps[i] == address(0)) continue;
            if (lps[i] == address(pool)) continue;
            if (queueWM.requestIds(lps[i]) != 0) continue;

            uint256 sharesToRequest = bound(shares[i], MIN_SHARES, MAX_SHARES);

            totalShares                += sharesToRequest;
            lpManuals[lps[i]]           = isManual[i];
            lpRequests[++lastRequestId] = lps[i];
            lpShares[lps[i]]            = sharesToRequest;

            if (isManual[i]) setManualWithdrawal(address(poolManager), lps[i], true);

            deposit(lps[i], sharesToRequest);
            requestRedeem(lps[i], sharesToRequest);
        }

        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: lastRequestId });
        assertEq(queueWM.totalShares(), totalShares);

        sharesToProcess = bound(sharesToProcess, MIN_SHARES, totalShares);

        processRedemptions(address(pool), sharesToProcess);

        ( uint128 nextRequestId_, uint128 lastRequestId_ ) = queueWM.queue();

        uint256 sharesProcessed;

        for (uint128 i = 1; i < nextRequestId_; i++) {
            address lp = lpRequests[i];

            assertRequest({
                poolManager: address(poolManager),
                requestId:   i,
                shares:      0,
                owner:       address(0)
            });

            if (lpManuals[lp]) {
                assertEq(queueWM.manualSharesAvailable(lp), lpShares[lp]);
            }

            sharesProcessed += lpShares[lp];
        }

        address nextLp = lpRequests[nextRequestId_];

        // NOTE: The next request is fully or partially processed to calculate use the below.
        uint256 nextLpProcessedShares = sharesToProcess - sharesProcessed;

        assertRequest({
            poolManager: address(poolManager),
            requestId:   nextRequestId_,
            shares:      lpShares[nextLp] - nextLpProcessedShares,
            owner:       nextLp
        });

        if (lpManuals[nextLp]) {
            assertEq(queueWM.manualSharesAvailable(nextLp), nextLpProcessedShares);
        }

        for (uint128 i = nextRequestId_ + 1; i <= lastRequestId_; i++) {
            address lp = lpRequests[i];

            assertRequest({
                poolManager: address(poolManager),
                requestId: i,
                shares: lpShares[lp],
                owner: lp
            });
        }
    }

}
