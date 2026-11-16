// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../../TestBase.sol";

contract PoolManagerGetterTests is TestBase {

    function test_addressGetters() external view {
        assertEq(poolManager.governor(), governor);
        assertEq(poolManager.globals(),  address(globals));
    }

    function testDeepFuzz_getEscrowParams_shouldReturnValues(uint256 amount) external {
        amount = bound(amount, 0, 1e29);

        address account = makeAddr("account");

        // Any address and any destination will do - function just returns values and contract address
        (uint256 returnedShares, address destination) = poolManager.getEscrowParams(account, amount);

        assertEq(returnedShares, amount);
        assertEq(destination,    address(poolManager));
    }

}
