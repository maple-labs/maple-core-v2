// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IAction } from "../interfaces/IAction.sol";

import { TestUtils } from "../../contracts/Contracts.sol";

abstract contract Action is IAction, TestUtils {

    uint256 public override timestamp;

    string public override description;

    constructor(uint256 timestamp_, string memory description_) {
        timestamp   = timestamp_;
        description = description_;
    }

}
