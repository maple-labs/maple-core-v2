// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC20 } from "../../../contracts/interfaces/Interfaces.sol";

import { SkyFuzzBase } from "./SkyFuzzBase.sol";

abstract contract SkyProcessRedemptionFuzzTests is SkyFuzzBase {

    SkyStrategyStorage strategyStorage;
    FeeAccrualStorage feeAccrualStorage;
    PoolManagerStorage poolManagerStorage;
    StrategyManagerStorage strategyManagerStorage;
    StrategyManagerPositionStorage positionStorage;

    function testFuzzFork_sky_processRedemption(uint256 seed_) external {
        /**********************************************************************************************************************************/
        /*** Execute set of random actions across all strategies on both pools and choose on which pool to perform testing              ***/
        /**********************************************************************************************************************************/

        fuzzSkySetup(seed_);

        /**********************************************************************************************************************************/
        /*** Queue a redemption if nothing is pending, funding the strategy first if the pool holds no shares at all                    ***/
        /**********************************************************************************************************************************/

        if (skyManager.pendingSharesOf(address(poolManager)) == 0) {
            if (skyManager.sharesOf(address(poolManager)) == 0) {
                uint256 minFundAmount = getMinimumFundableAssets(address(skyManager));

                if (fundsAsset.balanceOf(address(pool)) < minFundAmount) deposit(address(pool), lps[0], lpDeposit);

                fundStrategyManager(
                    address(poolManager), address(skyManager), getSomeValue(minFundAmount, fundsAsset.balanceOf(address(pool)))
                );

                vm.warp(block.timestamp + getSomeValue(1 hours, 10 days));
            }

            requestRedeemFromStrategyManager(
                address(poolManager), address(skyManager), getSomeValue(1, skyManager.sharesOf(address(poolManager)))
            );
        }

        /**********************************************************************************************************************************/
        /*** Generate share amount, giving back enough impairment for those shares to be worth at least a single asset                  ***/
        /**********************************************************************************************************************************/

        uint256 sharesToProcess = getSomeValue(1, skyManager.pendingSharesOf(address(poolManager)));

        if (skyManager.convertToExitAssets(sharesToProcess) == 0 && skyStrategy.impairedAssets() > 0) {
            uint256 impairedAssets = skyStrategy.impairedAssets();
            uint256 minValueNeeded = mulDivUp(skyManager.totalShares(), 1, sharesToProcess);
            uint256 totalAssets    = skyManager.assetsUnderManagement();

            uint256 maxImpairment  = totalAssets > minValueNeeded ? totalAssets - minValueNeeded : 0;
            uint256 minimumRemoval = impairedAssets > maxImpairment ? impairedAssets - maxImpairment : 1;

            removeStrategyImpairment(address(skyStrategy), getSomeValue(minimumRemoval, impairedAssets));
        }

        /**********************************************************************************************************************************/
        /*** Take a snapshot of the pool, the Sky strategy, the pool's position on the strategy manager and balances before processing  ***/
        /**********************************************************************************************************************************/

        poolManagerStorage     = _snapshotPoolManager(address(poolManager));
        strategyStorage        = _snapshotSkyStrategy(address(skyStrategy));
        strategyManagerStorage = _snapshotStrategyManager(address(skyManager));
        positionStorage        = _snapshotStrategyManagerPosition(address(skyManager), address(poolManager));
        feeAccrualStorage      = _snapshotFeeAccrualSky(address(skyStrategy));

        (uint256 expectedDelegateFee, uint256 expectedProtocolFee) = expectedFees(
            address(skyStrategy), strategyStorage.previousCurrentTotalAssets, strategyStorage.previousLastRecordedTotalAssets
        );

        uint256 expectedAssetsToReceive = mulDivDown(
            sharesToProcess,
            strategyManagerStorage.previousTotalAssets - strategyManagerStorage.previousUnrealizedLosses,
            strategyManagerStorage.previousTotalShares
        );

        /**********************************************************************************************************************************/
        /*** Process the redemption                                                                                                    ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), address(skyManager), sharesToProcess);

        /**********************************************************************************************************************************/
        /*** Fees and exit assets leave the PSM as the funds asset, so every balance moves by an exact amount                           ***/
        /**********************************************************************************************************************************/

        assertEq(fundsAsset.balanceOf(skyStrategyDelegate), feeAccrualStorage.previousDelegateBalance + expectedDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),            feeAccrualStorage.previousTreasuryBalance + expectedProtocolFee);
        assertEq(fundsAsset.balanceOf(address(pool)),       poolManagerStorage.previousFundsAssetBalance + expectedAssetsToReceive);

        /**********************************************************************************************************************************/
        /*** The assets under management shrink by what was released, up to the PSM and sUSDS conversion rounding                       ***/
        /*** Every value below is derived from that position, which makes the remaining assertions exact                                ***/
        /**********************************************************************************************************************************/

        uint256 assetsUnderManagementAfter = skyStrategy.assetsUnderManagement();
        uint256 expectedUnrealizedLosses   = min(strategyStorage.previousImpairedAssets, assetsUnderManagementAfter);

        assertApproxEqAbs(
            assetsUnderManagementAfter, strategyStorage.previousAssetsUnderManagement - expectedAssetsToReceive, SKY_ROUNDING_ERROR
        );

        assertEq(skyStrategy.impairedAssets(),          strategyStorage.previousImpairedAssets);
        assertEq(skyStrategy.isLossRecognized(),        false);
        assertEq(skyStrategy.strategyDelegateFeeRate(), strategyStorage.previousStrategyDelegateFeeRate);
        assertEq(skyStrategy.strategyProtocolFeeRate(), strategyStorage.previousStrategyProtocolFeeRate);

        assertEq(skyStrategy.lastRecordedTotalAssets(), assetsUnderManagementAfter);
        assertEq(skyStrategy.unrealizedLosses(),        expectedUnrealizedLosses);

        assertLt(IERC20(skyStrategy.savingsUsds()).balanceOf(address(skyStrategy)), strategyStorage.previousSavingsUsdsBalance);

        /**********************************************************************************************************************************/
        /*** Assert new state                                                                                                          ***/
        /**********************************************************************************************************************************/

        assertEq(skyManager.totalShares(),        strategyManagerStorage.previousTotalShares - sharesToProcess);
        assertEq(skyManager.totalPendingShares(), strategyManagerStorage.previousTotalPendingShares - sharesToProcess);
        assertEq(skyManager.unrealizedLosses(),   expectedUnrealizedLosses);

        uint256 expectedAssetsOf = mulDivDown(
            assetsUnderManagementAfter,
            positionStorage.previousShares - sharesToProcess,
            strategyManagerStorage.previousTotalShares - sharesToProcess
        );

        uint256 expectedUnrealizedLossesOf = mulDivUp(
            expectedUnrealizedLosses,
            positionStorage.previousShares - sharesToProcess,
            strategyManagerStorage.previousTotalShares - sharesToProcess
        );

        uint256 unrealizedLossesDecrease = positionStorage.previousUnrealizedLosses - expectedUnrealizedLossesOf;

        assertEq(skyManager.assetsOf(address(poolManager)),           expectedAssetsOf);
        assertEq(skyManager.unrealizedLossesOf(address(poolManager)), expectedUnrealizedLossesOf);
        assertEq(skyManager.sharesOf(address(poolManager)),           positionStorage.previousShares - sharesToProcess);
        assertEq(skyManager.pendingSharesOf(address(poolManager)),    positionStorage.previousPendingShares - sharesToProcess);

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

contract SkyProcessRedemptionForkFuzzTests is SkyProcessRedemptionFuzzTests {

    function setUp() public override {
        _setupForkEnvironment();
    }

}

contract SkyProcessRedemptionUpgradeForkFuzzTests is SkyProcessRedemptionFuzzTests {

    function setUp() public override {
        _setupUpgradeForkEnvironment();
    }

}
