// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IPoolManager } from "../../contracts/interfaces/Interfaces.sol";

import { Action }          from "./Action.sol";
import { ProtocolActions } from "../../contracts/ProtocolActions.sol";

contract TriggerDefaultAction is Action, ProtocolActions {

    address public liquidatorFactory;
    address public loan;
    address public poolManager;

    constructor(
        uint256 timestamp_,
        string memory description_,
        address poolManager_,
        address loan_,
        address liquidatorFactory_
    )
        Action(timestamp_, description_)
    {
        liquidatorFactory = liquidatorFactory_;
        loan              = loan_;
        poolManager       = poolManager_;
    }

    function act() external override {
        triggerDefault(poolManager, loan, liquidatorFactory);
    }

}
