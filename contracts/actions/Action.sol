// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";

import { IAction } from "../interfaces/IAction.sol";

abstract contract Action is IAction, TestUtils {

    uint256 public override timestamp;

    string public override description;

    constructor(uint256 timestamp_, string memory description_) {
        timestamp   = timestamp_;
        description = description_;
    }

}
