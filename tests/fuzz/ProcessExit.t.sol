// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

contract ProcessExitFuzzTests is TestBaseWithAssertions {

    uint256 constant MAX_SHARES = 1e30;
    uint256 constant MIN_SHARES = 100;

    uint256 lastRequestId;
    uint256 totalShares;

    mapping(address => bool)    lpManuals;
    mapping(address => uint256) lpShares;
    mapping(uint256 => address) lpRequests;

    function setUp() public override {
        start = block.timestamp;

        _createAccounts();
        _createGlobals();
        _createAssets();
        _configureGlobals();
        _createFactories();
        _createPoolWithQueue();
        _configurePool();

        openPool(address(poolManager));
    }

    function testFuzz_processExit(
        address[10] memory lps,
        bool[10]    memory isManual,
        uint256[10] memory shares,
        uint256            requestsToProcess,
        uint256            seed
    )
        external
    {
        for (uint256 i = 0; i < 10; i++) {
            if (lps[i] == address(0)) continue;
            if (lps[i] == address(pool)) continue;

            ( uint256[] memory requestIds, ) = queueWM.requestsByOwner(lps[i]);

            if (requestIds.length > 0) continue;

            uint256 sharesToRequest = bound(shares[i], MIN_SHARES, MAX_SHARES);

            totalShares                += sharesToRequest;
            lpManuals[lps[i]]           = isManual[i];
            lpRequests[++lastRequestId] = lps[i];
            lpShares[lps[i]]            = sharesToRequest;

            if (isManual[i]) setManualWithdrawal(address(poolManager), lps[i], true);

            deposit(lps[i], sharesToRequest);
            requestRedeem(lps[i], sharesToRequest);
        }

        assertEq(queueWM.totalShares(), totalShares);

        ( uint256[] memory allRequestIds_, , ) = queueWM.pendingRequestIds(0, type(uint256).max);

        if (allRequestIds_.length == 0) return;

        requestsToProcess = bound(requestsToProcess, 1, allRequestIds_.length);

        uint256[] memory requestIdsToProcess_ = randomSubset(seed, requestsToProcess, allRequestIds_);
        bool[]    memory processedRequestIds_ = new bool[](lastRequestId + 1);

        uint256 autoProcessedShares_;

        for (uint256 i = 0; i < requestIdsToProcess_.length; ++i) {
            uint256 requestId_ = requestIdsToProcess_[i];
            address lp_        = lpRequests[requestId_];
            uint256 shares_    = lpShares[lp_];

            processedRequestIds_[requestId_] = true;

            if (!lpManuals[lp_]) autoProcessedShares_ += shares_;
        }

        processRedemptionByIds(address(pool), requestIdsToProcess_);

        for (uint256 i = 1; i <= lastRequestId; ++i) {
            address lp = lpRequests[i];

            if (processedRequestIds_[i]) {
                assertRequest({
                    poolManager: address(poolManager),
                    requestId:   i,
                    shares:      0,
                    owner:       address(0)
                });

                if (lpManuals[lp]) {
                    assertEq(queueWM.manualSharesAvailable(lp), lpShares[lp]);
                }
            } else {
                assertRequest({
                    poolManager: address(poolManager),
                    requestId:   i,
                    shares:      lpShares[lp],
                    owner:       lp
                });
            }
        }

        uint256 expectedTotalShares = totalShares - autoProcessedShares_;

        assertEq(queueWM.totalShares(), expectedTotalShares);
    }

}
