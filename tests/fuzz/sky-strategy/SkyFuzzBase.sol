// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IPool,
    IPoolManager,
    IStrategyManager,
    ISkyStrategy
} from "../../../contracts/interfaces/Interfaces.sol";

import { FuzzedSetupFork } from "../FuzzedSetupFork.sol";
import { StorageSnapshot } from "../StorageSnapshot.sol";

contract SkyFuzzBase is FuzzedSetupFork, StorageSnapshot {

    uint256 constant OTL_LOAN_COUNT          = 5;
    uint256 constant LOAN_ACTION_COUNT       = 20;
    uint256 constant ALLOCATION_ACTION_COUNT = 10;
    uint256 constant AAVE_ACTION_COUNT       = 10;
    uint256 constant SKY_ACTION_COUNT        = 25;

    uint256 constant SKY_ROUNDING_ERROR = 2;

    ISkyStrategy     skyStrategy;
    IStrategyManager skyManager;

    function fuzzSkySetup(uint256 seed_) internal {
        fuzzedSetup(OTL_LOAN_COUNT, LOAN_ACTION_COUNT, ALLOCATION_ACTION_COUNT, AAVE_ACTION_COUNT, SKY_ACTION_COUNT, seed_);

        poolManager = IPoolManager(seed_ % 2 == 0 ? poolManager1 : poolManager2);
        pool        = IPool(poolManager.pool());
        skyStrategy = ISkyStrategy(skyUnderlyingStrategyShared);
        skyManager  = IStrategyManager(skyStrategyManagerShared);
    }

}
