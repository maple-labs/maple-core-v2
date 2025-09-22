// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract LockedTests is SyrupBitcoinTestBase {

    function test_locked_modifyViaStorage() external {
        // Using cheat codes here to modify the storage as there is no locked setter.

        assertEq(assetController.locked(), 1);

        bytes32 slot = bytes32(uint256(3));

        vm.store(address(assetController), slot, bytes32(uint256(2)));
        assertEq(assetController.locked(), 2);

        vm.store(address(assetController), slot, bytes32(uint256(1)));
        assertEq(assetController.locked(), 1);
    }

}
