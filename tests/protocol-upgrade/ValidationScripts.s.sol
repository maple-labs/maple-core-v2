// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IProxiedLike } from "../../contracts/interfaces/Interfaces.sol";

import { console2, Test } from "../../contracts/Contracts.sol";

import { AddressRegistry } from "./AddressRegistry.sol";

contract ValidationBase is AddressRegistry, Test {

    function setUp() external {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

}

contract ValidateUpgradeMapleGlobals is ValidationBase {

    // TODO: Replace this with the address of the new MapleGlobals implementation.
    address constant newImplementation = address(0);

    // TODO: Replace this with the code hash of the new MapleGlobals implementation.
    bytes32 constant expectedCodeHash = bytes32(0);

    function run() external view {
        bytes32 computedCodeHash = keccak256(abi.encode(newImplementation.code));

        console2.log("computed code hash:", uint256(computedCodeHash));
        console2.log("expected code hash:", uint256(expectedCodeHash));

        require(computedCodeHash == expectedCodeHash, "implementation code hash does not match");

        address implementation = IProxiedLike(mapleGlobalsV2Proxy).implementation();

        console2.log("current implementation address: ", implementation);
        console2.log("expected implementation address:", newImplementation);

        require(implementation == newImplementation, "implementation address does not match");
    }

}
