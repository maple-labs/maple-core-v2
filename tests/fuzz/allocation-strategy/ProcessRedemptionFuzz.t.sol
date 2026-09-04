// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { AllocationFuzzBase } from "./AllocationFuzzBase.sol";

contract AllocationProcessRedemptionFuzzTests is AllocationFuzzBase {

    AllocationStrategyStorage      strategyStorage;
    PoolManagerStorage             poolManagerStorage;
    StrategyManagerStorage         strategyManagerStorage;
    StrategyManagerPositionStorage positionStorage;

    function testFuzz_allocation_processRedemption(uint256 seed_) external {

        /**********************************************************************************************************************************/
        /*** Execute set of random actions across the loans and the allocation strategy, then choose the pool to test against           ***/
        /**********************************************************************************************************************************/

        fuzzAllocationSetup(seed_);

        /**********************************************************************************************************************************/
        /*** Queue a redemption if nothing is pending, funding the strategy first if the pool holds no shares at all                    ***/
        /**********************************************************************************************************************************/

        if (allocationManager.pendingSharesOf(address(poolManager)) == 0) {
            if (allocationManager.sharesOf(address(poolManager)) == 0) {
                uint256 minFundAmount = getMinimumFundableAssets(address(allocationManager));

                if (fundsAsset.balanceOf(address(pool)) < minFundAmount) deposit(address(pool), lps[0], lpDeposit);

                fundStrategyManager(
                    address(poolManager),
                    address(allocationManager),
                    getSomeValue(minFundAmount, fundsAsset.balanceOf(address(pool)))
                );
            }

            requestRedeemFromStrategyManager(
                address(poolManager),
                address(allocationManager),
                getSomeValue(1, allocationManager.sharesOf(address(poolManager)))
            );
        }

        /**********************************************************************************************************************************/
        /*** Generate share amount, giving back enough impairment for those shares to be worth at least a single asset                  ***/
        /**********************************************************************************************************************************/

        uint256 sharesToProcess = getSomeValue(1, allocationManager.pendingSharesOf(address(poolManager)));

        if (allocationManager.convertToExitAssets(sharesToProcess) == 0 && allocationStrategy.impairedAssets() > 0) {
            uint256 impairedAssets = allocationStrategy.impairedAssets();
            uint256 minValueNeeded = mulDivUp(allocationManager.totalShares(), 1, sharesToProcess);
            uint256 totalAssets    = allocationManager.assetsUnderManagement();

            uint256 maxImpairment  = totalAssets > minValueNeeded ? totalAssets - minValueNeeded : 0;
            uint256 minimumRemoval = impairedAssets > maxImpairment ? impairedAssets - maxImpairment : 1;

            removeStrategyImpairment(address(allocationStrategy), getSomeValue(minimumRemoval, impairedAssets));
        }

        uint256 exitAssets = allocationManager.convertToExitAssets(sharesToProcess);

        if (exitAssets > allocationStrategy.availableToWithdraw()) {
            uint256 assetsToReturn = exitAssets - allocationStrategy.availableToWithdraw();
            returnAssets(address(allocationStrategy), managedWalletShared, managedWalletShared, assetsToReturn);
        }

        /**********************************************************************************************************************************/
        /*** Take a snapshot of the pool, the strategy, the pool's position on the strategy manager and balances before processing      ***/
        /**********************************************************************************************************************************/

        poolManagerStorage     = _snapshotPoolManager(address(poolManager));
        strategyStorage        = _snapshotAllocationStrategy(address(allocationStrategy));
        strategyManagerStorage = _snapshotStrategyManager(address(allocationManager));
        positionStorage        = _snapshotStrategyManagerPosition(address(allocationManager), address(poolManager));

        uint256 delegateBalanceBefore = fundsAsset.balanceOf(strategyDelegate);
        uint256 treasuryBalanceBefore = fundsAsset.balanceOf(treasury);

        uint256 expectedAssetsToReceive = mulDivDown(
            sharesToProcess,
            strategyManagerStorage.previousTotalAssets - strategyManagerStorage.previousUnrealizedLosses,
            strategyManagerStorage.previousTotalShares
        );

        /**********************************************************************************************************************************/
        /*** Process the redemption                                                                                                    ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), address(allocationManager), sharesToProcess);

        /**********************************************************************************************************************************/
        /*** The strategy simply hands over the assets it was holding, and fees are only settled when yield is realized                 ***/
        /**********************************************************************************************************************************/

        assertEq(fundsAsset.balanceOf(strategyDelegate),            delegateBalanceBefore);
        assertEq(fundsAsset.balanceOf(treasury),                    treasuryBalanceBefore);
        assertEq(fundsAsset.balanceOf(address(allocationStrategy)), strategyStorage.previousFundsAssetBalance - expectedAssetsToReceive);
        assertEq(fundsAsset.balanceOf(address(pool)),               poolManagerStorage.previousFundsAssetBalance + expectedAssetsToReceive);

        uint256 expectedAssetsUnderManagement = strategyStorage.previousAssetsUnderManagement - expectedAssetsToReceive;
        uint256 expectedUnrealizedLosses      = min(strategyStorage.previousImpairedAssets, expectedAssetsUnderManagement);

        assertAllocationStrategy({
            allocationStrategy:    address(allocationStrategy),
            assetsUnderManagement: expectedAssetsUnderManagement,
            availableToWithdraw:   strategyStorage.previousAvailableToWithdraw - expectedAssetsToReceive,
            recordedAssets:        strategyStorage.previousRecordedAssets      - expectedAssetsToReceive,
            totalDeployedAssets:   strategyStorage.previousTotalDeployedAssets,
            unrealizedLosses:      expectedUnrealizedLosses
        });

        assertEq(allocationStrategy.impairedAssets(),          strategyStorage.previousImpairedAssets);
        assertEq(allocationStrategy.strategyDelegateFeeRate(), strategyStorage.previousStrategyDelegateFeeRate);
        assertEq(allocationStrategy.strategyProtocolFeeRate(), strategyStorage.previousStrategyProtocolFeeRate);

        /**********************************************************************************************************************************/
        /*** Assert new state                                                                                                          ***/
        /**********************************************************************************************************************************/

        assertEq(allocationManager.totalShares(),           strategyManagerStorage.previousTotalShares        - sharesToProcess);
        assertEq(allocationManager.totalPendingShares(),    strategyManagerStorage.previousTotalPendingShares - sharesToProcess);
        assertEq(allocationManager.assetsUnderManagement(), expectedAssetsUnderManagement);
        assertEq(allocationManager.unrealizedLosses(),      expectedUnrealizedLosses);

        uint256 expectedAssetsOf = mulDivDown(
            positionStorage.previousShares - sharesToProcess,
            expectedAssetsUnderManagement,
            strategyManagerStorage.previousTotalShares - sharesToProcess
        );

        uint256 expectedUnrealizedLossesOf = mulDivUp(
            positionStorage.previousShares - sharesToProcess,
            expectedUnrealizedLosses,
            strategyManagerStorage.previousTotalShares - sharesToProcess
        );

        assertEq(allocationManager.assetsOf(address(poolManager)),           expectedAssetsOf);
        assertEq(allocationManager.unrealizedLossesOf(address(poolManager)), expectedUnrealizedLossesOf);
        assertEq(allocationManager.sharesOf(address(poolManager)),           positionStorage.previousShares        - sharesToProcess);
        assertEq(allocationManager.pendingSharesOf(address(poolManager)),    positionStorage.previousPendingShares - sharesToProcess);

        assertEq(
            pool.totalAssets(),
            poolManagerStorage.previousTotalAssets + expectedAssetsToReceive + expectedAssetsOf - positionStorage.previousAssets
        );

        assertEq(pool.totalSupply(), poolManagerStorage.previousTotalSupply);
        assertEq(
            pool.unrealizedLosses(),
            poolManagerStorage.previousUnrealizedLosses + expectedUnrealizedLossesOf - positionStorage.previousUnrealizedLosses
        );
    }

}
