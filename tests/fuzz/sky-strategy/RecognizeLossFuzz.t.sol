// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC20 } from "../../../contracts/interfaces/Interfaces.sol";

import { SkyFuzzBase } from "./SkyFuzzBase.sol";

abstract contract SkyRecognizeLossFuzzTests is SkyFuzzBase {

    SkyStrategyStorage strategyStorage;
    FeeAccrualStorage feeAccrualStorage;
    PoolManagerStorage poolManagerStorage;
    StrategyManagerStorage strategyManagerStorage;
    StrategyManagerPositionStorage positionStorage;

    function testFuzzFork_sky_recognizeLoss(uint256 seed_) external {
        /**********************************************************************************************************************************/
        /*** Execute set of random actions across all strategies on both pools and choose on which pool to perform testing              ***/
        /**********************************************************************************************************************************/

        fuzzSkySetup(seed_);

        /**********************************************************************************************************************************/
        /*** Fund the strategy if the pool holds no position, so that the loss has something to write off                               ***/
        /**********************************************************************************************************************************/

        if (skyManager.sharesOf(address(poolManager)) == 0) {
            uint256 minFundAmount = getMinimumFundableAssets(address(skyManager));

            if (fundsAsset.balanceOf(address(pool)) < minFundAmount) deposit(address(pool), lps[0], lpDeposit);

            fundStrategyManager(address(poolManager), address(skyManager), getSomeValue(minFundAmount, fundsAsset.balanceOf(address(pool))));

            vm.warp(block.timestamp + getSomeValue(1 hours, 10 days));
        }

        /**********************************************************************************************************************************/
        /*** Take a snapshot of the pool, the Sky strategy, the pool's position on the strategy manager and balances before the loss    ***/
        /**********************************************************************************************************************************/

        poolManagerStorage     = _snapshotPoolManager(address(poolManager));
        strategyStorage        = _snapshotSkyStrategy(address(skyStrategy));
        strategyManagerStorage = _snapshotStrategyManager(address(skyManager));
        positionStorage        = _snapshotStrategyManagerPosition(address(skyManager), address(poolManager));
        feeAccrualStorage      = _snapshotFeeAccrualSky(address(skyStrategy));

        /**********************************************************************************************************************************/
        /*** Recognize the loss                                                                                                        ***/
        /**********************************************************************************************************************************/

        recognizeStrategyLoss(address(skyStrategy));

        /**********************************************************************************************************************************/
        /*** Recognizing a loss is an accounting write off, so no fees are settled and the sUSDS stays with the strategy                ***/
        /**********************************************************************************************************************************/

        assertEq(fundsAsset.balanceOf(skyStrategyDelegate), feeAccrualStorage.previousDelegateBalance);
        assertEq(fundsAsset.balanceOf(treasury),            feeAccrualStorage.previousTreasuryBalance);
        assertEq(fundsAsset.balanceOf(address(pool)),       poolManagerStorage.previousFundsAssetBalance);

        assertEq(IERC20(skyStrategy.savingsUsds()).balanceOf(address(skyStrategy)), strategyStorage.previousSavingsUsdsBalance);

        /**********************************************************************************************************************************/
        /*** Assert new state                                                                                                          ***/
        /**********************************************************************************************************************************/

        assertEq(skyStrategy.isLossRecognized(),        true);
        assertEq(skyStrategy.lastRecordedTotalAssets(), 0);
        assertEq(skyStrategy.impairedAssets(),          0);
        assertEq(skyStrategy.assetsUnderManagement(),   0);
        assertEq(skyStrategy.availableToWithdraw(),     0);
        assertEq(skyStrategy.unrealizedLosses(),        0);
        assertEq(skyStrategy.strategyDelegateFeeRate(), strategyStorage.previousStrategyDelegateFeeRate);
        assertEq(skyStrategy.strategyProtocolFeeRate(), strategyStorage.previousStrategyProtocolFeeRate);

        assertEq(skyManager.totalShares(),           strategyManagerStorage.previousTotalShares);
        assertEq(skyManager.totalPendingShares(),    strategyManagerStorage.previousTotalPendingShares);
        assertEq(skyManager.assetsUnderManagement(), 0);
        assertEq(skyManager.availableToWithdraw(),   0);
        assertEq(skyManager.unrealizedLosses(),      0);

        assertEq(skyManager.assetsOf(address(poolManager)),           0);
        assertEq(skyManager.unrealizedLossesOf(address(poolManager)), 0);
        assertEq(skyManager.sharesOf(address(poolManager)),           positionStorage.previousShares);
        assertEq(skyManager.pendingSharesOf(address(poolManager)),    positionStorage.previousPendingShares);

        assertEq(pool.totalSupply(),      poolManagerStorage.previousTotalSupply);
        assertEq(pool.totalAssets(),      poolManagerStorage.previousTotalAssets - positionStorage.previousAssets);
        assertEq(pool.unrealizedLosses(), poolManagerStorage.previousUnrealizedLosses - positionStorage.previousUnrealizedLosses);

        assertEq(poolManager.totalAssets(),      poolManagerStorage.previousTotalAssets - positionStorage.previousAssets);
        assertEq(poolManager.unrealizedLosses(), poolManagerStorage.previousUnrealizedLosses - positionStorage.previousUnrealizedLosses);
    }

}

contract SkyRecognizeLossForkFuzzTests is SkyRecognizeLossFuzzTests {

    function setUp() public override {
        _setupForkEnvironment();
    }

}

contract SkyRecognizeLossUpgradeForkFuzzTests is SkyRecognizeLossFuzzTests {

    function setUp() public override {
        _setupUpgradeForkEnvironment();
    }

}
