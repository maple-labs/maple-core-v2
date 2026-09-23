// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IAaveV3Strategy, IPool, IPoolManager, IStrategyManager } from "../../../contracts/interfaces/Interfaces.sol";

import { FuzzedSetupUpgradeFork } from "../FuzzedSetupUpgradeFork.sol";
import { StorageSnapshot } from "../StorageSnapshot.sol";

contract AaveV3FuzzBase is FuzzedSetupUpgradeFork, StorageSnapshot {

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

    IAaveV3Strategy aaveStrategy;
    IStrategyManager aaveStrategyManager;

    function fuzzAaveSetup(uint256 seed_) internal {
        fuzzedSetup(OTL_LOAN_COUNT, LOAN_ACTION_COUNT, ALLOCATION_ACTION_COUNT, AAVE_ACTION_COUNT, SKY_ACTION_COUNT, seed_);

        poolManager         = IPoolManager(seed_ % 2 == 0 ? poolManager1 : poolManager2);
        pool                = IPool(poolManager.pool());
        aaveStrategy        = IAaveV3Strategy(aaveUnderlyingStrategyShared);
        aaveStrategyManager = IStrategyManager(aaveStrategyManagerShared);
    }

}
