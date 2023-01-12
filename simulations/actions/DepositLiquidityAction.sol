// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { Action }          from "./Action.sol";
import { ProtocolActions } from "../../contracts/ProtocolActions.sol";

contract DepositLiquidityAction is Action, ProtocolActions {

    address public lp;
    address public pool;

    uint256 public amount;

    constructor(
        uint256 timestamp_,
        string memory description_,
        address pool_,
        address lp_,
        uint256 amount_
    )
        Action(timestamp_, description_)
    {
        amount = amount_;
        lp     = lp_;
        pool   = pool_;
    }

    function act() external override {
        depositLiquidity(pool, lp, amount);
    }

}
