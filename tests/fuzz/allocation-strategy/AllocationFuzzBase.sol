// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAllocationStrategy,
    IPool,
    IPoolManager,
    IStrategyManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { FuzzedSetup }     from "../FuzzedSetup.sol";
import { StorageSnapshot } from "../StorageSnapshot.sol";

contract AllocationFuzzBase is FuzzedSetup, StorageSnapshot {

    uint256 constant OTL_LOAN_COUNT          = 5;
    uint256 constant LOAN_ACTION_COUNT       = 20;
    uint256 constant ALLOCATION_ACTION_COUNT = 25;

    IAllocationStrategy allocationStrategy;
    IStrategyManager    allocationManager;

    function fuzzAllocationSetup(uint256 seed_) internal {
        fuzzedSetup(OTL_LOAN_COUNT, LOAN_ACTION_COUNT, ALLOCATION_ACTION_COUNT, 0, 0, seed_);

        poolManager = IPoolManager(seed_ % 2 == 0 ? poolManager1 : poolManager2);
        pool        = IPool(poolManager.pool());

        allocationStrategy = IAllocationStrategy(allocationUnderlyingStrategyShared);
        allocationManager  = IStrategyManager(allocationStrategyManagerShared);
    }

}
