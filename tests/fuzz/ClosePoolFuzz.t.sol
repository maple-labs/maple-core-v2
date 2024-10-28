// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { FuzzedSetup, IPoolManager, IWithdrawalManagerQueue } from "./FuzzedSetup.sol";

contract ClosePoolFuzz is FuzzedSetup {

    uint256 constant ACTION_COUNT   = 10;
    uint256 constant FTL_LOAN_COUNT = 3;
    uint256 constant OTL_LOAN_COUNT = 7;
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
            pool:               address(pool),
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0,
            diff:               ALLOWED_DIFF
        });

    }

}

contract ClosePoolFuzzWithWMQueue is FuzzedSetup {

    uint256 constant ACTION_COUNT   = 10;
    uint256 constant FTL_LOAN_COUNT = 4;
    uint256 constant OTL_LOAN_COUNT = 6;
    uint256 constant ALLOWED_DIFF   = 1000;

    function setUp() public override {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createPoolWithQueue();
        _configurePool();

        openPool(address(poolManager));

        setAddresses(address(pool));

        _collateralAsset      = address(collateralAsset);
        _feeManager           = address(fixedTermFeeManager);
        _fixedTermLoanFactory = address(fixedTermLoanFactory);
        _liquidatorFactory    = address(liquidatorFactory);
        _openTermLoanFactory  = address(openTermLoanFactory);

        // Deposit the initial liquidity.
        lps.push(makeAddr("lp1"));
        lps.push(makeAddr("lp2"));
        lps.push(makeAddr("lp3"));
        lps.push(makeAddr("lp4"));
        lps.push(makeAddr("lp5"));

        for (uint256 i; i < lps.length; ++i) {
            deposit(address(pool), lps[i], 100_000_000e6);
        }

        address withdrawalManager = IPoolManager(_poolManager).withdrawalManager();

        vm.prank(poolManager.poolDelegate());
        IWithdrawalManagerQueue(withdrawalManager).setManualWithdrawal(lps[2], true);
    }

    function testFuzz_fuzzedSetup_closePool_withQueueWM(uint256 seed_) external {
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
            pool:               address(pool),
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0,
            diff:               ALLOWED_DIFF
        });

    }

}
