// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC20 } from "../../../contracts/interfaces/Interfaces.sol";

import { AaveV3FuzzBase } from "./AaveV3FuzzBase.sol";

abstract contract FundFuzzTests is AaveV3FuzzBase {

    AaveStrategyStorage            strategyStorage;
    FeeAccrualStorage              feeAccrualStorage;
    PoolManagerStorage             poolManagerStorage;
    StrategyManagerStorage         strategyManagerStorage;
    StrategyManagerPositionStorage positionStorage;

    function testFuzzFork_aave_fund(uint256 seed_) external {

        /**********************************************************************************************************************************/
        /*** Execute set of random actions across all strategies on both pools and choose on which pool to perform testing              ***/
        /**********************************************************************************************************************************/

        fuzzAaveSetup(seed_);

        /**********************************************************************************************************************************/
        /*** Generate fund amount and deposit assets in the pool if pool does not have enough to perform the funding action             ***/
        /**********************************************************************************************************************************/

        uint256 minFundAmount = getMinimumFundableAssets(address(aaveStrategyManager));

        if (fundsAsset.balanceOf(address(pool)) < minFundAmount) deposit(address(pool), lps[0], lpDeposit);

        uint256 fundAmount = getSomeValue(minFundAmount, fundsAsset.balanceOf(address(pool)));

        /**********************************************************************************************************************************/
        /*** Take a snapshot of the pool, the Aave strategy, the pool's position on the strategy manager and balances before funding    ***/
        /**********************************************************************************************************************************/

        poolManagerStorage     = _snapshotPoolManager(address(poolManager));
        strategyStorage        = _snapshotAaveStrategy(address(aaveStrategy));
        strategyManagerStorage = _snapshotStrategyManager(address(aaveStrategyManager));
        positionStorage        = _snapshotStrategyManagerPosition(address(aaveStrategyManager), address(poolManager));
        feeAccrualStorage      = _snapshotFeeAccrual(address(aaveStrategy));

        ( uint256 expectedDelegateFee, uint256 expectedProtocolFee ) =
            expectedFees(address(aaveStrategy), strategyStorage.previousATokenBalance, strategyStorage.previousLastRecordedTotalAssets);

        /**********************************************************************************************************************************/
        /*** Fund the Aave strategy                                                                                                    ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), address(aaveStrategyManager), fundAmount);

        /**********************************************************************************************************************************/
        /*** Fees accrued before the funding are settled at the balance held before the new principal was supplied                      ***/
        /**********************************************************************************************************************************/

        assertEq(fundsAsset.balanceOf(aaveStrategyDelegate), feeAccrualStorage.previousDelegateBalance + expectedDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),             feeAccrualStorage.previousTreasuryBalance + expectedProtocolFee);

        /**********************************************************************************************************************************/
        /*** The assets under management grow by exactly what was funded, up to Aave's scaled balance rounding                          ***/
        /*** Every value below is derived from this balance, which makes all of the remaining assertions exact                          ***/
        /**********************************************************************************************************************************/

        uint256 aTokenBalanceAfter       = IERC20(aaveStrategy.aaveToken()).balanceOf(address(aaveStrategy));
        uint256 netDeposit               = aTokenBalanceAfter - strategyStorage.previousAssetsUnderManagement;
        uint256 expectedUnrealizedLosses = min(strategyStorage.previousImpairedAssets, aTokenBalanceAfter);

        assertApproxEqAbs(netDeposit, fundAmount, AAVE_ROUNDING_ERROR);

        assertApproxEqAbs(
            aTokenBalanceAfter,
            strategyStorage.previousATokenBalance - expectedDelegateFee - expectedProtocolFee + fundAmount,
            AAVE_ROUNDING_ERROR
        );

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

        uint256 sharesMinted   = aaveStrategyManager.totalShares() - strategyManagerStorage.previousTotalShares;
        uint256 expectedShares = strategyManagerStorage.previousTotalShares == 0
            ? fundAmount
            : mulDivDown(
                fundAmount,
                strategyManagerStorage.previousTotalShares,
                strategyManagerStorage.previousTotalAssets
            );

        assertApproxEqAbs(sharesMinted, expectedShares, AAVE_ROUNDING_ERROR);

        assertEq(aaveStrategyManager.totalShares(),           strategyManagerStorage.previousTotalShares + sharesMinted);
        assertEq(aaveStrategyManager.totalPendingShares(),    strategyManagerStorage.previousTotalPendingShares);
        assertEq(aaveStrategyManager.assetsUnderManagement(), aTokenBalanceAfter);
        assertEq(aaveStrategyManager.availableToWithdraw(),   aTokenBalanceAfter);
        assertEq(aaveStrategyManager.unrealizedLosses(),      expectedUnrealizedLosses);

        uint256 expectedUnrealizedLossesOf = mulDivUp(
            positionStorage.previousShares + sharesMinted,
            expectedUnrealizedLosses,
            strategyManagerStorage.previousTotalShares + sharesMinted
        );

        uint256 shareConversionError = maxShareConversionError(
            strategyManagerStorage.previousTotalAssets,
            strategyManagerStorage.previousTotalShares
        );

        assertApproxEqAbs(
            aaveStrategyManager.assetsOf(address(poolManager)),
            positionStorage.previousAssets + netDeposit,
            shareConversionError
        );

        assertEq(aaveStrategyManager.unrealizedLossesOf(address(poolManager)), expectedUnrealizedLossesOf);
        assertEq(aaveStrategyManager.sharesOf(address(poolManager)),           positionStorage.previousShares + sharesMinted);
        assertEq(aaveStrategyManager.pendingSharesOf(address(poolManager)),    positionStorage.previousPendingShares);

        uint256 expectedUnrealizedLossesGain = expectedUnrealizedLossesOf - positionStorage.previousUnrealizedLosses;

        assertApproxEqAbs(
            pool.totalAssets(),
            poolManagerStorage.previousTotalAssets - (fundAmount - netDeposit),
            shareConversionError
        );

        assertEq(pool.totalSupply(),      poolManagerStorage.previousTotalSupply);
        assertEq(pool.unrealizedLosses(), poolManagerStorage.previousUnrealizedLosses + expectedUnrealizedLossesGain);

        assertApproxEqAbs(
            poolManager.totalAssets(),
            poolManagerStorage.previousTotalAssets - (fundAmount - netDeposit),
            shareConversionError
        );

        assertEq(poolManager.unrealizedLosses(), poolManagerStorage.previousUnrealizedLosses + expectedUnrealizedLossesGain);

        assertEq(fundsAsset.balanceOf(address(pool)), poolManagerStorage.previousFundsAssetBalance - fundAmount);
    }

}

contract FundForkFuzzTests is FundFuzzTests {

    function setUp() public override {
        _setupForkEnvironment();
    }

}

contract FundUpgradeForkFuzzTests is FundFuzzTests {

    function setUp() public override {
        _setupUpgradeForkEnvironment();
    }

}
