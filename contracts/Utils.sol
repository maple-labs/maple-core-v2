// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { Test } from "../modules/forge-std/src/Test.sol";

contract Utils is Test {

    function divRoundUp(uint256 numerator_, uint256 divisor_) internal pure returns (uint256 result_) {
        result_ = (numerator_ + divisor_ - 1) / divisor_;
    }

}
