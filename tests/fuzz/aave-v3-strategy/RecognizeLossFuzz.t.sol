// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC20 } from "../../../contracts/interfaces/Interfaces.sol";

import { AaveV3FuzzBase } from "./AaveV3FuzzBase.sol";

contract RecognizeLossFuzzTests is AaveV3FuzzBase {

    AaveStrategyStorage            strategyStorage;
    FeeAccrualStorage              feeAccrualStorage;
    PoolManagerStorage             poolManagerStorage;
    StrategyManagerStorage         strategyManagerStorage;
    StrategyManagerPositionStorage positionStorage;

    function testFuzzFork_aave_recognizeLoss(uint256 seed_) external {

        /**********************************************************************************************************************************/
        /*** Execute set of random actions across all strategies on both pools and choose on which pool to perform testing              ***/
        /**********************************************************************************************************************************/

        fuzzAaveSetup(seed_);

        /**********************************************************************************************************************************/
        /*** Fund the strategy if the pool holds no position, so that the loss has something to write off                               ***/
        /**********************************************************************************************************************************/

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

        /**********************************************************************************************************************************/
        /*** Take a snapshot of the pool, the Aave strategy, the pool's position on the strategy manager and balances before the loss   ***/
        /**********************************************************************************************************************************/

        poolManagerStorage     = _snapshotPoolManager(address(poolManager));
        strategyStorage        = _snapshotAaveStrategy(address(aaveStrategy));
        strategyManagerStorage = _snapshotStrategyManager(address(aaveStrategyManager));
        positionStorage        = _snapshotStrategyManagerPosition(address(aaveStrategyManager), address(poolManager));
        feeAccrualStorage      = _snapshotFeeAccrual(address(aaveStrategy));

        /**********************************************************************************************************************************/
        /*** Recognize the loss                                                                                                        ***/
        /**********************************************************************************************************************************/

        recognizeStrategyLoss(address(aaveStrategy));

        /**********************************************************************************************************************************/
        /*** Recognizing a loss is an accounting write off, so no fees are settled and the aTokens stay with the strategy               ***/
        /**********************************************************************************************************************************/

        assertEq(fundsAsset.balanceOf(aaveStrategyDelegate), feeAccrualStorage.previousDelegateBalance);
        assertEq(fundsAsset.balanceOf(treasury),             feeAccrualStorage.previousTreasuryBalance);
        assertEq(fundsAsset.balanceOf(address(pool)),        poolManagerStorage.previousFundsAssetBalance);

        assertEq(IERC20(aaveStrategy.aaveToken()).balanceOf(address(aaveStrategy)), strategyStorage.previousATokenBalance);

        /**********************************************************************************************************************************/
        /*** Assert new state                                                                                                          ***/
        /**********************************************************************************************************************************/

        assertEq(aaveStrategy.isLossRecognized(),        true);
        assertEq(aaveStrategy.lastRecordedTotalAssets(), 0);
        assertEq(aaveStrategy.impairedAssets(),          0);
        assertEq(aaveStrategy.assetsUnderManagement(),   0);
        assertEq(aaveStrategy.availableToWithdraw(),     0);
        assertEq(aaveStrategy.unrealizedLosses(),        0);
        assertEq(aaveStrategy.strategyDelegateFeeRate(), strategyStorage.previousStrategyDelegateFeeRate);
        assertEq(aaveStrategy.strategyProtocolFeeRate(), strategyStorage.previousStrategyProtocolFeeRate);

        assertEq(aaveStrategyManager.totalShares(),           strategyManagerStorage.previousTotalShares);
        assertEq(aaveStrategyManager.totalPendingShares(),    strategyManagerStorage.previousTotalPendingShares);
        assertEq(aaveStrategyManager.assetsUnderManagement(), 0);
        assertEq(aaveStrategyManager.availableToWithdraw(),   0);
        assertEq(aaveStrategyManager.unrealizedLosses(),      0);

        assertEq(aaveStrategyManager.assetsOf(address(poolManager)),           0);
        assertEq(aaveStrategyManager.unrealizedLossesOf(address(poolManager)), 0);
        assertEq(aaveStrategyManager.sharesOf(address(poolManager)),           positionStorage.previousShares);
        assertEq(aaveStrategyManager.pendingSharesOf(address(poolManager)),    positionStorage.previousPendingShares);

        assertEq(pool.totalAssets(),      poolManagerStorage.previousTotalAssets - positionStorage.previousAssets);
        assertEq(pool.totalSupply(),      poolManagerStorage.previousTotalSupply);
        assertEq(pool.unrealizedLosses(), poolManagerStorage.previousUnrealizedLosses - positionStorage.previousUnrealizedLosses);

        assertEq(poolManager.totalAssets(),      poolManagerStorage.previousTotalAssets - positionStorage.previousAssets);
        assertEq(poolManager.unrealizedLosses(), poolManagerStorage.previousUnrealizedLosses - positionStorage.previousUnrealizedLosses);
    }

}
