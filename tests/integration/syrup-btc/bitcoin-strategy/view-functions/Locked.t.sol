// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract LockedTests is SyrupBitcoinTestBase {

    function test_locked_getter() external view {
        assertEq(bitcoinStrategy.locked(), 1);
    }

}
