// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IAllocationStrategy, IStrategyManager } from "../../../contracts/interfaces/Interfaces.sol";

import { FuzzedSetup } from "../FuzzedSetup.sol";

contract ClosePoolFuzzWithWMQueue is FuzzedSetup {

    uint256 constant ACTION_COUNT   = 20;
    uint256 constant OTL_LOAN_COUNT = 6;
    uint256 constant ALLOWED_DIFF   = 1000;

    function setUp() public override {
        super.setUp();

        setManualWithdrawal(poolManager1, lps[2], true);
    }

    function testFuzz_fuzzedSetup_closePool_withQueueWM(uint256 seed_) external {
        fuzzedSetup(OTL_LOAN_COUNT, ACTION_COUNT, ACTION_COUNT, seed_);

        uint256 lastDomainStartOTLM = payOffLoansAndRedeemAllLps(pool1);

        assertOpenTermLoanManagerWithDiff({
            loanManager:       openTermLoanManagerPool1,
            accountedInterest: 0,
            accruedInterest:   0,
            domainStart:       lastDomainStartOTLM,
            issuanceRate:      0,
            principalOut:      0,
            unrealizedLosses:  0,
            diff:              ALLOWED_DIFF
        });

        assertPoolStateWithDiff({
            pool:               pool1,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0,
            diff:               ALLOWED_DIFF
        });

    }

    function test_closePool_withWorthlessStrategyPosition() external {
        fundStrategyManager(poolManager1, allocationStrategyManagerShared, fundsAsset.balanceOf(pool1) / 2);

        uint256 deployableAssets = IAllocationStrategy(allocationUnderlyingStrategyShared).availableToWithdraw();

        deployAssets(allocationUnderlyingStrategyShared, managedWalletShared, deployableAssets);
        recognizeLoss(allocationUnderlyingStrategyShared, managedWalletShared, deployableAssets);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategyShared).assetsUnderManagement(), 0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategyShared).impairedAssets(),        0);

        uint256 sharesBefore = IStrategyManager(allocationStrategyManagerShared).sharesOf(poolManager1);

        assertGt(sharesBefore, 0);

        payOffLoansAndRedeemAllLps(pool1);

        assertEq(IStrategyManager(allocationStrategyManagerShared).sharesOf(poolManager1), sharesBefore);

        assertPoolStateWithDiff({
            pool:               pool1,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0,
            diff:               ALLOWED_DIFF
        });
    }

    function test_closePool_withWorthlessStrategyPositionAndOutstandingImpairment() external {
        fundStrategyManager(poolManager1, allocationStrategyManagerShared, fundsAsset.balanceOf(pool1) / 2);

        uint256 deployableAssets = IAllocationStrategy(allocationUnderlyingStrategyShared).availableToWithdraw();

        impairAllocationStrategy(allocationUnderlyingStrategyShared, deployableAssets / 4);

        deployAssets(allocationUnderlyingStrategyShared, managedWalletShared, deployableAssets);
        recognizeLoss(allocationUnderlyingStrategyShared, managedWalletShared, deployableAssets);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategyShared).assetsUnderManagement(), 0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategyShared).impairedAssets(),        deployableAssets / 4);

        uint256 impairedBefore = IAllocationStrategy(allocationUnderlyingStrategyShared).impairedAssets();
        uint256 sharesBefore   = IStrategyManager(allocationStrategyManagerShared).sharesOf(poolManager1);

        assertGt(sharesBefore, 0);

        payOffLoansAndRedeemAllLps(pool1);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategyShared).impairedAssets(),        impairedBefore);
        assertEq(IStrategyManager(allocationStrategyManagerShared).sharesOf(poolManager1),        sharesBefore);

        assertPoolStateWithDiff({
            pool:               pool1,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0,
            diff:               ALLOWED_DIFF
        });
    }

}
