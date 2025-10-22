// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console2 as console } from "../../../contracts/Runner.sol";

import { HandlerBase } from "./HandlerBase.sol";

contract WarpHandler is HandlerBase {

    /**************************************************************************************************************************************/
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function warp(uint256 seed) external {
        console.log("warpHandler.warp(%s)", seed);
        numberOfCalls["warpHandler.warp"]++;

        uint256 timespan_ = _bound(seed, 1 seconds, 1 days);

        vm.warp(block.timestamp + timespan_);
    }

}
