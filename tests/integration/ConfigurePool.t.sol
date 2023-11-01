// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { TestBase } from "../TestBase.sol";

contract ConfigurePoolTests is TestBase {

    uint256 constant FUNCTION_LEVEL = 1;
    uint256 constant PUBLIC         = 3;

    bytes32[] functionIds;

    uint256[] bitmaps;

    function setUp() public override {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createAndConfigurePool(start, 1 weeks, 2 days);

        functionIds.push("P:transfer");
        functionIds.push("P:deposit");

        bitmaps.push(createBitmap([1]));
        bitmaps.push(createBitmap([2, 3]));
    }

    function test_configurePool_notAuthorized() external {
        vm.expectRevert("PPM:NOT_PD_GOV_OR_OA");
        poolPermissionManager.configurePool(address(poolManager), FUNCTION_LEVEL, functionIds, bitmaps);
    }

    function test_configurePool_anotherPoolDelegate() external {
        address anotherPoolDelegate = makeAddr("anotherPoolDelegate");

        vm.prank(governor);
        globals.setValidPoolDelegate(anotherPoolDelegate, true);

        vm.prank(anotherPoolDelegate);
        vm.expectRevert("PPM:NOT_PD_GOV_OR_OA");
        poolPermissionManager.configurePool(address(poolManager), FUNCTION_LEVEL, functionIds, bitmaps);
    }

    function test_configurePool_publicPool() external {
        setPoolPermissionLevel(address(poolManager), PUBLIC);

        vm.prank(poolDelegate);
        vm.expectRevert("PPM:CP:PUBLIC_POOL");
        poolPermissionManager.configurePool(address(poolManager), FUNCTION_LEVEL, functionIds, bitmaps);
    }

    function test_configurePool_invalidLevel() external {
        vm.prank(poolDelegate);
        vm.expectRevert("PPM:CP:INVALID_LEVEL");
        poolPermissionManager.configurePool(address(poolManager), PUBLIC + 1, functionIds, bitmaps);
    }

    function test_configurePool_lengthMismatch() external {
        functionIds.push("P:redeem");

        vm.prank(poolDelegate);
        vm.expectRevert("PPM:CP:LENGTH_MISMATCH");
        poolPermissionManager.configurePool(address(poolManager), FUNCTION_LEVEL, functionIds, bitmaps);
    }

    function test_configurePool_poolDelegate() external {
        vm.prank(poolDelegate);
        poolPermissionManager.configurePool(address(poolManager), FUNCTION_LEVEL, functionIds, bitmaps);

        assertEq(poolPermissionManager.permissionLevels(address(poolManager)), FUNCTION_LEVEL);

        for (uint i; i < functionIds.length; ++i) {
            assertEq(poolPermissionManager.poolBitmaps(address(poolManager), functionIds[i]), bitmaps[i]);
        }
    }

    function test_configurePool_governor() external {
        vm.prank(governor);
        poolPermissionManager.configurePool(address(poolManager), FUNCTION_LEVEL, functionIds, bitmaps);

        assertEq(poolPermissionManager.permissionLevels(address(poolManager)), FUNCTION_LEVEL);

        for (uint i; i < functionIds.length; ++i) {
            assertEq(poolPermissionManager.poolBitmaps(address(poolManager), functionIds[i]), bitmaps[i]);
        }
    }

    function test_configurePool_operationalAdmin() external {
        vm.prank(operationalAdmin);
        poolPermissionManager.configurePool(address(poolManager), FUNCTION_LEVEL, functionIds, bitmaps);

        assertEq(poolPermissionManager.permissionLevels(address(poolManager)), FUNCTION_LEVEL);

        for (uint i; i < functionIds.length; ++i) {
            assertEq(poolPermissionManager.poolBitmaps(address(poolManager), functionIds[i]), bitmaps[i]);
        }
    }

    function testFuzz_configurePool(
        uint256 oldPermissionLevel,
        uint256 newPermissionLevel,
        uint256[] memory bitmaps_
    )
        external
    {
        oldPermissionLevel = bound(oldPermissionLevel, 0, PUBLIC);
        newPermissionLevel = bound(newPermissionLevel, 0, PUBLIC + 1);

        // NOTE: The function identifiers are set manually because the fuzzer can generate duplicates.
        bytes32[] memory functionIds_ = new bytes32[](bitmaps_.length);
        for (uint i; i < functionIds_.length; ++i) {
            functionIds_[i] = bytes32(i);
        }

        setPoolPermissionLevel(address(poolManager), oldPermissionLevel);

        if (oldPermissionLevel == PUBLIC) vm.expectRevert("PPM:CP:PUBLIC_POOL");
        else if (newPermissionLevel > PUBLIC) vm.expectRevert("PPM:CP:INVALID_LEVEL");
        else if (functionIds_.length == 0) vm.expectRevert("PPM:CP:NO_FUNCTIONS");
        else if (functionIds_.length != bitmaps_.length) vm.expectRevert("PPM:CP:LENGTH_MISMATCH");

        vm.prank(poolDelegate);
        poolPermissionManager.configurePool(address(poolManager), newPermissionLevel, functionIds_, bitmaps_);

        if (
            oldPermissionLevel != PUBLIC &&
            newPermissionLevel <= PUBLIC &&
            functionIds_.length > 0 &&
            functionIds_.length == bitmaps_.length
        ) {
            assertEq(poolPermissionManager.permissionLevels(address(poolManager)), newPermissionLevel);

            for (uint i; i < functionIds_.length; ++i) {
                assertEq(poolPermissionManager.poolBitmaps(address(poolManager), functionIds_[i]), bitmaps_[i]);
            }
        }
    }

}
