// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { AllocationFuzzBase } from "./AllocationFuzzBase.sol";

contract AllocationFundFuzzTests is AllocationFuzzBase {

    AllocationStrategyStorage      strategyStorage;
    PoolManagerStorage             poolManagerStorage;
    StrategyManagerStorage         strategyManagerStorage;
    StrategyManagerPositionStorage positionStorage;

    function testFuzz_allocation_fund(uint256 seed_) external {

        /**********************************************************************************************************************************/
        /*** Execute set of random actions across the loans and the allocation strategy, then choose the pool to test against          ***/
        /**********************************************************************************************************************************/

        fuzzAllocationSetup(seed_);

        /**********************************************************************************************************************************/
        /*** Generate fund amount and deposit assets in the pool if pool does not have enough to perform the funding action             ***/
        /**********************************************************************************************************************************/

        uint256 minFundAmount = getMinimumFundableAssets(address(allocationManager));

        if (fundsAsset.balanceOf(address(pool)) < minFundAmount) deposit(address(pool), lps[0], lpDeposit);

        uint256 fundAmount = getSomeValue(minFundAmount, fundsAsset.balanceOf(address(pool)));

        /**********************************************************************************************************************************/
        /*** Take a snapshot of the pool, the strategy, the pool's position on the strategy manager and balances before funding         ***/
        /**********************************************************************************************************************************/

        poolManagerStorage     = _snapshotPoolManager(address(poolManager));
        strategyStorage        = _snapshotAllocationStrategy(address(allocationStrategy));
        strategyManagerStorage = _snapshotStrategyManager(address(allocationManager));
        positionStorage        = _snapshotStrategyManagerPosition(address(allocationManager), address(poolManager));

        uint256 delegateBalanceBefore = fundsAsset.balanceOf(strategyDelegate);
        uint256 treasuryBalanceBefore = fundsAsset.balanceOf(treasury);

        /**********************************************************************************************************************************/
        /*** Fund the allocation strategy                                                                                              ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), address(allocationManager), fundAmount);

        /**********************************************************************************************************************************/
        /*** No fees are charged on funding, so delegate and treasury balances remain unchanged                                         ***/
        /**********************************************************************************************************************************/

        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateBalanceBefore);
        assertEq(fundsAsset.balanceOf(treasury),                     treasuryBalanceBefore);
        assertEq(fundsAsset.balanceOf(address(allocationStrategy)),  strategyStorage.previousFundsAssetBalance + fundAmount);

        uint256 expectedAssetsUnderManagement = strategyStorage.previousAssetsUnderManagement + fundAmount;

        assertAllocationStrategy({
            allocationStrategy:    address(allocationStrategy),
            assetsUnderManagement: expectedAssetsUnderManagement,
            availableToWithdraw:   strategyStorage.previousAvailableToWithdraw + fundAmount,
            recordedAssets:        strategyStorage.previousRecordedAssets      + fundAmount,
            totalDeployedAssets:   strategyStorage.previousTotalDeployedAssets,
            unrealizedLosses:      min(strategyStorage.previousImpairedAssets, expectedAssetsUnderManagement)
        });

        assertEq(allocationStrategy.impairedAssets(),          strategyStorage.previousImpairedAssets);
        assertEq(allocationStrategy.strategyDelegateFeeRate(), strategyStorage.previousStrategyDelegateFeeRate);
        assertEq(allocationStrategy.strategyProtocolFeeRate(), strategyStorage.previousStrategyProtocolFeeRate);

        /**********************************************************************************************************************************/
        /*** Assert new state                                                                                                          ***/
        /**********************************************************************************************************************************/

        uint256 sharesMinted = allocationManager.totalShares() - strategyManagerStorage.previousTotalShares;

        uint256 expectedShares = strategyManagerStorage.previousTotalShares == 0
            ? fundAmount
            : mulDivDown(
                fundAmount,
                strategyManagerStorage.previousTotalShares,
                strategyManagerStorage.previousTotalAssets
            );

        assertEq(sharesMinted, expectedShares);

        uint256 expectedUnrealizedLosses = min(strategyStorage.previousImpairedAssets, expectedAssetsUnderManagement);

        assertEq(allocationManager.totalShares(),           strategyManagerStorage.previousTotalShares + sharesMinted);
        assertEq(allocationManager.totalPendingShares(),    strategyManagerStorage.previousTotalPendingShares);
        assertEq(allocationManager.assetsUnderManagement(), expectedAssetsUnderManagement);
        assertEq(allocationManager.unrealizedLosses(),      expectedUnrealizedLosses);

        uint256 expectedAssetsOf = mulDivDown(
            positionStorage.previousShares + sharesMinted,
            expectedAssetsUnderManagement,
            strategyManagerStorage.previousTotalShares + sharesMinted
        );

        uint256 expectedUnrealizedLossesOf = mulDivUp(
            positionStorage.previousShares + sharesMinted,
            expectedUnrealizedLosses,
            strategyManagerStorage.previousTotalShares + sharesMinted
        );

        assertEq(allocationManager.assetsOf(address(poolManager)),           expectedAssetsOf);
        assertEq(allocationManager.unrealizedLossesOf(address(poolManager)), expectedUnrealizedLossesOf);
        assertEq(allocationManager.sharesOf(address(poolManager)),           positionStorage.previousShares + sharesMinted);
        assertEq(allocationManager.pendingSharesOf(address(poolManager)),    positionStorage.previousPendingShares);

        assertEq(
            pool.totalAssets(),
            poolManagerStorage.previousTotalAssets + expectedAssetsOf - positionStorage.previousAssets - fundAmount
        );

        assertEq(pool.totalSupply(), poolManagerStorage.previousTotalSupply);
        assertEq(
            pool.unrealizedLosses(),
            poolManagerStorage.previousUnrealizedLosses + expectedUnrealizedLossesOf - positionStorage.previousUnrealizedLosses
        );

        assertEq(fundsAsset.balanceOf(address(pool)), poolManagerStorage.previousFundsAssetBalance - fundAmount);
    }

}
