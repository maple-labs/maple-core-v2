// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestUtils } from "../../../modules/contract-test-utils/contracts/test.sol";

contract WarperBase is TestUtils {

    function warp(uint256 warpAmount_) external {
        warpAmount_ = constrictToRange(warpAmount_, 0, 10 days);

        vm.warp(block.timestamp);
    }

}
