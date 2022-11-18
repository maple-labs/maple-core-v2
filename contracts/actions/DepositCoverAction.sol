// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Action } from "./Action.sol";

contract DepositCoverAction is Action {

    constructor(uint256 timestamp_, string memory description_) Action(timestamp_, description_) { }

    function act() external override {
        // TODO
    }

}
