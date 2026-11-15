// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { GovernorTimelock as GT } from "../modules/globals/contracts/GovernorTimelock.sol";

import { MapleBorrowerActions } from "../modules/syrup-utils/contracts/MapleBorrowerActions.sol";
import { NonTransparentProxy as NTP } from "../modules/syrup-utils/modules/non-transparent-proxy/contracts/NonTransparentProxy.sol";

contract BorrowerActions is MapleBorrowerActions { }

contract Timelock is GT {

    constructor(
        address tokenWithdrawer_,
        address proposer_,
        address executor_,
        address canceller_,
        address roleAdmin_
    )
        GT(tokenWithdrawer_, proposer_, executor_, canceller_, roleAdmin_)
    { }

}
