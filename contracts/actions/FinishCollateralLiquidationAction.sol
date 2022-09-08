// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { Action } from "./Action.sol";

contract FinishCollateralLiquidationAction is Action {

    constructor(uint256 timestamp_, string memory description_) Action(timestamp_, description_) { }

    function act() external override {
        // TODO
    }

}
