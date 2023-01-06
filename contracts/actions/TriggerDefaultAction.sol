// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IPoolManagerLike } from "../interfaces/Interfaces.sol";

import { Action } from "./Action.sol";

contract TriggerDefaultAction is Action {

    address liquidatorFactory;
    address loan;

    IPoolManagerLike poolManager;

    constructor(
        uint256 timestamp_,
        string memory description_,
        IPoolManagerLike poolManager_,
        address loan_,
        address liquidatorFactory_
    )
        Action(timestamp_, description_)
    {
        poolManager       = poolManager_;
        loan              = loan_;
        liquidatorFactory = liquidatorFactory_;
    }

    function act() external override {
        vm.startPrank(poolManager.poolDelegate());
        poolManager.triggerDefault(loan, liquidatorFactory);
        vm.stopPrank();
    }

}
