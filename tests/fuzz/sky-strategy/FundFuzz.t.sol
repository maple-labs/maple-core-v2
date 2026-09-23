// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC20 } from "../../../contracts/interfaces/Interfaces.sol";

import { SkyFuzzBase } from "./SkyFuzzBase.sol";

abstract contract SkyFundFuzzTests is SkyFuzzBase {

    SkyStrategyStorage strategyStorage;
    FeeAccrualStorage feeAccrualStorage;
    PoolManagerStorage poolManagerStorage;
    StrategyManagerStorage strategyManagerStorage;
    StrategyManagerPositionStorage positionStorage;

    function testFuzzFork_sky_fund(uint256 seed_) external {
        /**********************************************************************************************************************************/
        /*** Execute set of random actions across all strategies on both pools and choose on which pool to perform testing              ***/
        /**********************************************************************************************************************************/

        fuzzSkySetup(seed_);

        /**********************************************************************************************************************************/
        /*** Generate fund amount and deposit assets in the pool if pool does not have enough to perform the funding action             ***/
        /**********************************************************************************************************************************/

        uint256 minFundAmount = getMinimumFundableAssets(address(skyManager));

        if (fundsAsset.balanceOf(address(pool)) < minFundAmount) deposit(address(pool), lps[0], lpDeposit);

        uint256 fundAmount = getSomeValue(minFundAmount, fundsAsset.balanceOf(address(pool)));

        /**********************************************************************************************************************************/
        /*** Take a snapshot of the pool, the Sky strategy, the pool's position on the strategy manager and balances before funding     ***/
        /**********************************************************************************************************************************/

        poolManagerStorage     = _snapshotPoolManager(address(poolManager));
        strategyStorage        = _snapshotSkyStrategy(address(skyStrategy));
        strategyManagerStorage = _snapshotStrategyManager(address(skyManager));
        positionStorage        = _snapshotStrategyManagerPosition(address(skyManager), address(poolManager));
        feeAccrualStorage      = _snapshotFeeAccrualSky(address(skyStrategy));

        (uint256 expectedDelegateFee, uint256 expectedProtocolFee) =
            expectedFees(address(skyStrategy), strategyStorage.previousCurrentTotalAssets, strategyStorage.previousLastRecordedTotalAssets);

        /**********************************************************************************************************************************/
        /*** Fund the Sky strategy                                                                                                     ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), address(skyManager), fundAmount);

        /**********************************************************************************************************************************/
        /*** Fees accrued before the funding are settled at the position held before the new principal was deployed                     ***/
        /**********************************************************************************************************************************/

        assertEq(fundsAsset.balanceOf(skyStrategyDelegate), feeAccrualStorage.previousDelegateBalance + expectedDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),            feeAccrualStorage.previousTreasuryBalance + expectedProtocolFee);

        /**********************************************************************************************************************************/
        /*** The assets under management grow by what was funded, up to the PSM and sUSDS conversion rounding                           ***/
        /*** Every value below is derived from that position, which makes the remaining assertions exact                                ***/
        /**********************************************************************************************************************************/

        uint256 assetsUnderManagementAfter = skyStrategy.assetsUnderManagement();
        uint256 netDeposit                 = assetsUnderManagementAfter - strategyStorage.previousAssetsUnderManagement;
        uint256 expectedUnrealizedLosses   = min(strategyStorage.previousImpairedAssets, assetsUnderManagementAfter);

        // Here we are validating both just to fullfil assertions because we are not going to assert AUM after.
        assertApproxEqAbs(netDeposit, fundAmount, SKY_ROUNDING_ERROR);
        assertApproxEqAbs(assetsUnderManagementAfter, strategyStorage.previousAssetsUnderManagement + fundAmount, SKY_ROUNDING_ERROR);

        assertEq(skyStrategy.impairedAssets(),          strategyStorage.previousImpairedAssets);
        assertEq(skyStrategy.isLossRecognized(),        false);
        assertEq(skyStrategy.strategyDelegateFeeRate(), strategyStorage.previousStrategyDelegateFeeRate);
        assertEq(skyStrategy.strategyProtocolFeeRate(), strategyStorage.previousStrategyProtocolFeeRate);

        assertEq(skyStrategy.lastRecordedTotalAssets(), assetsUnderManagementAfter);
        assertEq(skyStrategy.unrealizedLosses(),        expectedUnrealizedLosses);

        /**********************************************************************************************************************************/
        /*** Assert new state                                                                                                          ***/
        /**********************************************************************************************************************************/

        uint256 sharesMinted = skyManager.totalShares() - strategyManagerStorage.previousTotalShares;
        uint256 expectedShares = strategyManagerStorage.previousTotalShares == 0
            ? fundAmount
            : mulDivDown(fundAmount, strategyManagerStorage.previousTotalShares, strategyManagerStorage.previousTotalAssets);

        assertApproxEqAbs(sharesMinted, expectedShares, SKY_ROUNDING_ERROR);

        assertEq(skyManager.totalShares(),        strategyManagerStorage.previousTotalShares + sharesMinted);
        assertEq(skyManager.totalPendingShares(), strategyManagerStorage.previousTotalPendingShares);
        assertEq(skyManager.unrealizedLosses(),   expectedUnrealizedLosses);

        uint256 expectedUnrealizedLossesOf = mulDivUp(
            positionStorage.previousShares + sharesMinted,
            expectedUnrealizedLosses,
            strategyManagerStorage.previousTotalShares + sharesMinted
        );

        uint256 shareConversionError =
            maxShareConversionError(strategyManagerStorage.previousTotalAssets, strategyManagerStorage.previousTotalShares);

        assertApproxEqAbs(skyManager.assetsOf(address(poolManager)), positionStorage.previousAssets + netDeposit, shareConversionError);

        assertEq(skyManager.unrealizedLossesOf(address(poolManager)), expectedUnrealizedLossesOf);
        assertEq(skyManager.sharesOf(address(poolManager)),           positionStorage.previousShares + sharesMinted);
        assertEq(skyManager.pendingSharesOf(address(poolManager)),    positionStorage.previousPendingShares);

        uint256 expectedUnrealizedLossesGain = expectedUnrealizedLossesOf - positionStorage.previousUnrealizedLosses;

        assertApproxEqAbs(pool.totalAssets(), poolManagerStorage.previousTotalAssets - (fundAmount - netDeposit), shareConversionError);

        assertEq(pool.totalSupply(),      poolManagerStorage.previousTotalSupply);
        assertEq(pool.unrealizedLosses(), poolManagerStorage.previousUnrealizedLosses + expectedUnrealizedLossesGain);

        assertApproxEqAbs(
            poolManager.totalAssets(), poolManagerStorage.previousTotalAssets - (fundAmount - netDeposit), shareConversionError
        );

        assertEq(poolManager.unrealizedLosses(), poolManagerStorage.previousUnrealizedLosses + expectedUnrealizedLossesGain);

        assertEq(fundsAsset.balanceOf(address(pool)), poolManagerStorage.previousFundsAssetBalance - fundAmount);
    }

}

contract SkyFundForkFuzzTests is SkyFundFuzzTests {

    function setUp() public override {
        _setupForkEnvironment();
    }

}

contract SkyFundUpgradeForkFuzzTests is SkyFundFuzzTests {

    function setUp() public override {
        _setupUpgradeForkEnvironment();
    }

}
