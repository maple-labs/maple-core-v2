// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestBase } from "../contracts/utilities/TestBase.sol";

import { Address } from "../modules/contract-test-utils/contracts/test.sol";

contract PoolManagerGetterTests is TestBase {

    function test_addressGetters() external {
        assertEq(poolManager.governor(), governor);
        assertEq(poolManager.globals(),  address(globals));
    }

    function testFuzz_getEscrowParams_shouldReturnValues(uint256 amount) external {
        amount = constrictToRange(amount, 0, 1e29);

        address account = address(new Address());

        // Any address and any destination will do - function just returns values and contract address
        ( uint256 returnedShares, address destination ) = poolManager.getEscrowParams(account, amount);

        assertEq(returnedShares, amount);
        assertEq(destination,    address(poolManager));
    }

    function test_hasSufficientCover_insufficientCover(uint256 amount) external {
        amount = constrictToRange(amount, 0, 1e29);

        assertEq(poolManager.poolDelegateCover(), address(poolCover));

        assertEq(globals.minCoverAmount(address(poolManager)), 0);
        assertEq(fundsAsset.balanceOf(address(poolCover)),     0);

        fundsAsset.mint(address(poolCover), amount);

        vm.prank(governor);
        globals.setMinCoverAmount(address(poolManager), amount + 1);

        assertEq(globals.minCoverAmount(address(poolManager)), amount + 1);
        assertEq(fundsAsset.balanceOf(address(poolCover)),     amount);

        assertTrue(!poolManager.hasSufficientCover());
    }

    function test_hasSufficientCover_sufficientCover(uint256 amount) external {
        amount = constrictToRange(amount, 0, 1e29);

        assertEq(poolManager.poolDelegateCover(), address(poolCover));

        assertEq(globals.minCoverAmount(address(poolManager)), 0);
        assertEq(fundsAsset.balanceOf(address(poolCover)),     0);

        fundsAsset.mint(address(poolCover), amount);

        vm.prank(governor);
        globals.setMinCoverAmount(address(poolManager), amount);

        assertEq(globals.minCoverAmount(address(poolManager)), amount);
        assertEq(fundsAsset.balanceOf(address(poolCover)),     amount);

        assertTrue(poolManager.hasSufficientCover());

        fundsAsset.mint(address(poolCover), 1);

        assertTrue(poolManager.hasSufficientCover());  // Maintains sufficient cover if funds are added
    }

}
