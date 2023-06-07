// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IOpenTermLoanManager, IFixedTermLoanManager } from "../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

import { FuzzedSetup } from "./FuzzedSetup.sol";

contract ClosePoolFuzz is FuzzedSetup {

    uint256 constant ACTION_COUNT   = 10;
    uint256 constant FTL_LOAN_COUNT = 1;
    uint256 constant OTL_LOAN_COUNT = 10;
    uint256 constant ALLOWED_DIFF   = 1000;

    function testFuzz_fuzzedSetup_closePool(uint256 seed_) external {
        fuzzedSetup(FTL_LOAN_COUNT, OTL_LOAN_COUNT, ACTION_COUNT, seed_);

        ( uint256 lastDomainStartFTLM, uint256 lastDomainStartOTLM ) = payOffLoansAndRedeemAllLps();

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

        assertFixedTermLoanManagerWithDiff({
            loanManager:       _fixedTermLoanManager,
            accruedInterest:   0,
            accountedInterest: 0,
            principalOut:      0,
            issuanceRate:      0,
            domainStart:       lastDomainStartFTLM,
            domainEnd:         lastDomainStartFTLM,
            unrealizedLosses:  0,
            diff:              ALLOWED_DIFF
        });

        assertPoolStateWithDiff({
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0,
            diff:               ALLOWED_DIFF
        });

    }

}
