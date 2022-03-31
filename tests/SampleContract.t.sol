// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.7;

import { TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

contract ERC20BaseTest is TestUtils { 

    function setUp() public virtual { }

    function test_success() external {
        assertTrue(true);
    }

    function test_failure() external {
        assertTrue(false);
    }

    function test_fuzz(uint256 x) external {
        assertEq(x, x);
    }

}
