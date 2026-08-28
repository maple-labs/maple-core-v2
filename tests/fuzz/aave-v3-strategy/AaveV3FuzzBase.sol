// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAaveV3Strategy,
    IPool,
    IPoolManager,
    IStrategyManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { FuzzedSetupFork } from "../FuzzedSetupFork.sol";
import { StorageSnapshot } from "../StorageSnapshot.sol";

contract AaveV3FuzzBase is FuzzedSetupFork, StorageSnapshot {

    uint256 constant OTL_LOAN_COUNT          = 5;
    uint256 constant LOAN_ACTION_COUNT       = 20;
    uint256 constant ALLOCATION_ACTION_COUNT = 10;
    uint256 constant AAVE_ACTION_COUNT       = 25;
    uint256 constant SKY_ACTION_COUNT        = 10;

    // Rounding down can happen on maximum four places:
    //   1. the `balanceOf` read taken for the snapshot                           (rayMul)
    //   2. the fee withdrawal `_harvestAndWithdraw` makes before the main action (rayDiv, rounded up when burning)
    //   3. the `supply` or `withdraw` carrying the action itself                 (rayDiv)
    //   4. the `balanceOf` read taken after the action                           (rayMul)
    uint256 constant AAVE_ROUNDING_ERROR = 4;

    IAaveV3Strategy  aaveStrategy;
    IStrategyManager aaveStrategyManager;

    function fuzzAaveSetup(uint256 seed_) internal {
        fuzzedSetup(OTL_LOAN_COUNT, LOAN_ACTION_COUNT, ALLOCATION_ACTION_COUNT, AAVE_ACTION_COUNT, SKY_ACTION_COUNT, seed_);

        poolManager         = IPoolManager(seed_ % 2 == 0 ? poolManager1 : poolManager2);
        pool                = IPool(poolManager.pool());
        aaveStrategy        = IAaveV3Strategy(aaveUnderlyingStrategyShared);
        aaveStrategyManager = IStrategyManager(aaveStrategyManagerShared);
    }

    function expectedFees(uint256 grossAssets, uint256 lastRecordedTotalAssets)
        internal view returns (uint256 delegateFee, uint256 protocolFee)
    {
        if (grossAssets <= lastRecordedTotalAssets) return (0, 0);

        uint256 yieldAccrued = grossAssets - lastRecordedTotalAssets;

        delegateFee = mulDivDown(yieldAccrued, aaveStrategy.strategyDelegateFeeRate(), HUNDRED_PERCENT);
        protocolFee = mulDivDown(yieldAccrued, aaveStrategy.strategyProtocolFeeRate(), HUNDRED_PERCENT);
    }

    // Maximum drift, in assets, between `assetsOf` read back after an action and `previousAssets + assetsMoved`.
    //
    // `MapleStrategyManager` divides three times between the two, and the truncations do not cancel:
    //   1. `_convertToAssets` for `assetsOf` at the snapshot  - truncates under one asset
    //   2. `_convertToShares` when minting                    - truncates under one SHARE
    //   3. `_convertToAssets` for `assetsOf` on the read back - truncates under one asset
    //
    // Example: 100 shares over 500 assets, so a share is worth 5 assets. A pool holding 30 shares funds 7 assets.
    //   1. assetsOf = floor(30 * 500 / 100) = 150
    //   2. minted   = floor(7 * 100 / 500)  = floor(1.4)    = 1 share, discarding 0.4 shares worth 2 assets
    //   3. assetsOf = floor(31 * 507 / 101) = floor(155.61) = 155
    //
    //   expected = 150 + 7 = 157
    //   actual             = 155
    //   drift              =   2
    //
    // The pool funded 7 and gained 5: 507 assets are split across 101 shares instead of the 101.4 that were paid for, so the
    // discarded fraction accrues to the remaining shareholders.
    //
    // Worst case is a share lost to 2 plus an asset to each of 1 and 3, so the bound is one share price plus one.
    // The drift is one directional: `assetsOf` is never above what the test expects.
    function maxShareConversionError(uint256 totalAssets, uint256 totalShares) internal pure returns (uint256 maxError) {
        maxError = mulDivDown(totalAssets, 1, totalShares) + 1;
    }

    function mulDivDown(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        result = denominator == 0 ? 0 : x * y / denominator;
    }

    function mulDivUp(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        result = denominator == 0 ? 0 : (x * y + denominator - 1) / denominator;
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 minimum) {
        minimum = x < y ? x : y;
    }

}
