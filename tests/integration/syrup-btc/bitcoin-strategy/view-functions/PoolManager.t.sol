// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract PoolManagerTests is SyrupBitcoinTestBase {

    function test_poolManager_getter() external view {
        assertEq(bitcoinStrategy.poolManager(), address(poolManager));
    }

}
