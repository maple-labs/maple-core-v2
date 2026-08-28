// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC20 } from "../../../contracts/interfaces/Interfaces.sol";

import { AaveV3FuzzBase } from "./AaveV3FuzzBase.sol";

contract ProcessRedemptionFuzzTests is AaveV3FuzzBase {

    AaveStrategyStorage            strategyStorage;
    FeeAccrualStorage              feeAccrualStorage;
    PoolManagerStorage             poolManagerStorage;
    StrategyManagerStorage         strategyManagerStorage;
    StrategyManagerPositionStorage positionStorage;

    function testFuzzFork_aave_processRedemption(uint256 seed_) external {

        /**********************************************************************************************************************************/
        /*** Execute set of random actions across all strategies on both pools and choose on which pool to perform testing              ***/
        /**********************************************************************************************************************************/

        fuzzAaveSetup(seed_);

        /**********************************************************************************************************************************/
        /*** Queue a redemption if nothing is pending, funding the strategy first if the pool holds no shares at all                    ***/
        /**********************************************************************************************************************************/

        if (aaveStrategyManager.pendingSharesOf(address(poolManager)) == 0) {
            if (aaveStrategyManager.sharesOf(address(poolManager)) == 0) {
                uint256 minFundAmount = getMinimumFundableAssets(address(aaveStrategyManager));

                if (fundsAsset.balanceOf(address(pool)) < minFundAmount) deposit(address(pool), lps[0], lpDeposit);

                fundStrategyManager(
                    address(poolManager),
                    address(aaveStrategyManager),
                    getSomeValue(minFundAmount, fundsAsset.balanceOf(address(pool)))
                );

                vm.warp(block.timestamp + getSomeValue(1 hours, 10 days));
            }

            requestRedeemFromStrategyManager(
                address(poolManager),
                address(aaveStrategyManager),
                getSomeValue(1, aaveStrategyManager.sharesOf(address(poolManager)))
            );
        }

        /**********************************************************************************************************************************/
        /*** Generate share amount, giving back enough impairment for those shares to be worth at least a single asset                  ***/
        /**********************************************************************************************************************************/

        uint256 sharesToProcess = getSomeValue(1, aaveStrategyManager.pendingSharesOf(address(poolManager)));

        if (aaveStrategyManager.convertToExitAssets(sharesToProcess) == 0 && aaveStrategy.impairedAssets() > 0) {
            uint256 impairedAssets = aaveStrategy.impairedAssets();
            uint256 minValueNeeded = mulDivUp(aaveStrategyManager.totalShares(), 1, sharesToProcess);
            uint256 totalAssets    = aaveStrategyManager.assetsUnderManagement();

            uint256 maxImpairment  = totalAssets > minValueNeeded ? totalAssets - minValueNeeded : 0;
            uint256 minimumRemoval = impairedAssets > maxImpairment ? impairedAssets - maxImpairment : 1;

            removeStrategyImpairment(address(aaveStrategy), getSomeValue(minimumRemoval, impairedAssets));
        }

        /**********************************************************************************************************************************/
        /*** Take a snapshot of the pool, the Aave strategy, the pool's position on the strategy manager and balances before processing ***/
        /**********************************************************************************************************************************/

        poolManagerStorage     = _snapshotPoolManager(address(poolManager));
        strategyStorage        = _snapshotAaveStrategy(address(aaveStrategy));
        strategyManagerStorage = _snapshotStrategyManager(address(aaveStrategyManager));
        positionStorage        = _snapshotStrategyManagerPosition(address(aaveStrategyManager), address(poolManager));
        feeAccrualStorage      = _snapshotFeeAccrual(address(aaveStrategy));

        ( uint256 expectedDelegateFee, uint256 expectedProtocolFee ) =
            expectedFees(strategyStorage.previousATokenBalance, strategyStorage.previousLastRecordedTotalAssets);

        uint256 expectedAssetsToReceive = mulDivDown(
            sharesToProcess,
            strategyManagerStorage.previousTotalAssets - strategyManagerStorage.previousUnrealizedLosses,
            strategyManagerStorage.previousTotalShares
        );

        /**********************************************************************************************************************************/
        /*** Process the redemption                                                                                                     ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), address(aaveStrategyManager), sharesToProcess);

        /**********************************************************************************************************************************/
        /*** Fees accrued before the redemption are settled and the exit assets are transferred straight to the pool                    ***/
        /**********************************************************************************************************************************/

        assertEq(fundsAsset.balanceOf(aaveStrategyDelegate), feeAccrualStorage.previousDelegateBalance    + expectedDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),             feeAccrualStorage.previousTreasuryBalance    + expectedProtocolFee);
        assertEq(fundsAsset.balanceOf(address(pool)),        poolManagerStorage.previousFundsAssetBalance + expectedAssetsToReceive);

        /**********************************************************************************************************************************/
        /*** The assets under management shrink by exactly what was released, up to Aave's scaled balance rounding                      ***/
        /*** Every value below is derived from this balance, which makes all of the remaining assertions exact                          ***/
        /**********************************************************************************************************************************/

        uint256 aTokenBalanceAfter       = IERC20(aaveStrategy.aaveToken()).balanceOf(address(aaveStrategy));
        uint256 expectedUnrealizedLosses = min(strategyStorage.previousImpairedAssets, aTokenBalanceAfter);

        assertApproxEqAbs(aTokenBalanceAfter, strategyStorage.previousAssetsUnderManagement - expectedAssetsToReceive, AAVE_ROUNDING_ERROR);

        assertEq(aaveStrategy.impairedAssets(),          strategyStorage.previousImpairedAssets);
        assertEq(aaveStrategy.isLossRecognized(),        false);
        assertEq(aaveStrategy.strategyDelegateFeeRate(), strategyStorage.previousStrategyDelegateFeeRate);
        assertEq(aaveStrategy.strategyProtocolFeeRate(), strategyStorage.previousStrategyProtocolFeeRate);

        assertEq(aaveStrategy.assetsUnderManagement(),   aTokenBalanceAfter);
        assertEq(aaveStrategy.lastRecordedTotalAssets(), aTokenBalanceAfter);
        assertEq(aaveStrategy.unrealizedLosses(),        expectedUnrealizedLosses);

        /**********************************************************************************************************************************/
        /*** Assert new state                                                                                                           ***/
        /**********************************************************************************************************************************/

        assertEq(aaveStrategyManager.totalShares(),           strategyManagerStorage.previousTotalShares - sharesToProcess);
        assertEq(aaveStrategyManager.totalPendingShares(),    strategyManagerStorage.previousTotalPendingShares - sharesToProcess);
        assertEq(aaveStrategyManager.assetsUnderManagement(), aTokenBalanceAfter);
        assertEq(aaveStrategyManager.availableToWithdraw(),   aTokenBalanceAfter);
        assertEq(aaveStrategyManager.unrealizedLosses(),      expectedUnrealizedLosses);

        uint256 expectedAssetsOf = mulDivDown(
            aTokenBalanceAfter,
            positionStorage.previousShares - sharesToProcess,
            strategyManagerStorage.previousTotalShares - sharesToProcess
        );

        uint256 expectedUnrealizedLossesOf = mulDivUp(
            expectedUnrealizedLosses,
            positionStorage.previousShares - sharesToProcess,
            strategyManagerStorage.previousTotalShares - sharesToProcess
        );

        uint256 unrealizedLossesDecrease = positionStorage.previousUnrealizedLosses - expectedUnrealizedLossesOf;

        assertEq(aaveStrategyManager.assetsOf(address(poolManager)),           expectedAssetsOf);
        assertEq(aaveStrategyManager.unrealizedLossesOf(address(poolManager)), expectedUnrealizedLossesOf);
        assertEq(aaveStrategyManager.sharesOf(address(poolManager)),           positionStorage.previousShares - sharesToProcess);
        assertEq(aaveStrategyManager.pendingSharesOf(address(poolManager)),    positionStorage.previousPendingShares - sharesToProcess);

        assertEq(
            pool.totalAssets(),
            poolManagerStorage.previousTotalAssets + expectedAssetsToReceive + expectedAssetsOf - positionStorage.previousAssets
        );

        assertEq(pool.totalSupply(),      poolManagerStorage.previousTotalSupply);
        assertEq(pool.unrealizedLosses(), poolManagerStorage.previousUnrealizedLosses - unrealizedLossesDecrease);

        assertEq(
            poolManager.totalAssets(),
            poolManagerStorage.previousTotalAssets + expectedAssetsToReceive + expectedAssetsOf - positionStorage.previousAssets
        );

        assertEq(poolManager.unrealizedLosses(), poolManagerStorage.previousUnrealizedLosses - unrealizedLossesDecrease);
    }

}
