// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Action }          from "./Action.sol";
import { ProtocolActions } from "../../contracts/ProtocolActions.sol";

contract RefinanceAction is Action, ProtocolActions {

    address public loan;
    address public poolManager;
    address public refinancer;

    uint256 public principalIncrease;

    bytes[] public refinanceCalls;

    constructor(
        uint256 timestamp_,
        string memory description_,
        address loan_,
        address poolManager_,
        address refinancer_,
        uint256 principalIncrease_,
        bytes[] memory calls_
    )
        Action(timestamp_, description_)
    {
        loan              = loan_;
        poolManager       = poolManager_;
        principalIncrease = principalIncrease_;
        refinanceCalls    = calls_;
        refinancer        = refinancer_;
    }

    function act() external override {
        // TODO: `principalIncrease` no longer works in `proposeRefinance` due to inability to pre-compute origination fees.
        proposeRefinance(loan, refinancer, block.timestamp + 1, refinanceCalls);
        acceptRefinance(poolManager, loan, refinancer, block.timestamp + 1, refinanceCalls, principalIncrease);
    }

}
