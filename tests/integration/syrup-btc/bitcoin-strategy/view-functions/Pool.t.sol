// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract PoolTests is SyrupBitcoinTestBase {

    function test_pool_getter() external view {
        assertEq(bitcoinStrategy.pool(), address(pool));
    }

}
