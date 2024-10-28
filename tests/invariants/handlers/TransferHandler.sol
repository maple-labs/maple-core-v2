// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IInvariantTest, IPool } from "../../../contracts/interfaces/Interfaces.sol";

import { console2 as console } from "../../../contracts/Runner.sol";

import { HandlerBase } from "./HandlerBase.sol";

contract TransferHandler is HandlerBase {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    address[] lps;

    IPool pool;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(address pool_, address[] memory lps_) {
        testContract = IInvariantTest(msg.sender);

        pool = IPool(pool_);
        lps  = lps_;
    }

    /**************************************************************************************************************************************/
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function transfer(uint256 seed_) external useTimestamps {
        console.log("transferHandler.transfer(%s)", seed_);
        numberOfCalls["transferHandler.transfer"]++;

        address sender_ = lps[_bound(_randomize(seed_, "sender"), 0, lps.length - 1)];

        if (pool.balanceOf(sender_) == 0) return;

        uint256 amount_    = _bound(_randomize(seed_, "amount"), 1, pool.balanceOf(sender_));
        address recipient_ = lps[_bound(_randomize(seed_, "recipient"), 0, lps.length - 1)];

        vm.prank(sender_);
        pool.transfer(recipient_, amount_);
    }

}
