// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { FuzzedSetup } from "./FuzzedSetup.sol";

contract ClosePoolFuzzWithWMQueue is FuzzedSetup {

    uint256 constant ACTION_COUNT   = 10;
    uint256 constant OTL_LOAN_COUNT = 6;
    uint256 constant ALLOWED_DIFF   = 1000;

    function setUp() public override {
        super.setUp();

        vm.prank(poolManager.poolDelegate());
        queueWM.setManualWithdrawal(lps[2], true);
    }

    function testFuzz_fuzzedSetup_closePool_withQueueWM(uint256 seed_) external {
        fuzzedSetup(OTL_LOAN_COUNT, ACTION_COUNT, 0, seed_);

        uint256 lastDomainStartOTLM = payOffLoansAndRedeemAllLps();

        assertOpenTermLoanManagerWithDiff({
            loanManager:       _openTermLoanManager,
            accountedInterest: 0,
            accruedInterest:   0,
            domainStart:       lastDomainStartOTLM,
            issuanceRate:      0,
            principalOut:      0,
            unrealizedLosses:  0,
            diff:              ALLOWED_DIFF
        });

        assertPoolStateWithDiff({
            pool:               address(pool),
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0,
            diff:               ALLOWED_DIFF
        });

    }

}
