// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { TestBase } from "../../TestBase.sol";

contract OperationalAdminTests is TestBase {

    function setUp() public override {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _createFactories();
    }

    function test_operationalAdminAcl_setMinCoverAmount() external {
        assertEq(globals.minCoverAmount(address(1)), 0);

        vm.prank(operationalAdmin);
        globals.setMinCoverAmount(address(1), 50);

        assertEq(globals.minCoverAmount(address(1)), 50);
    }

    function test_operationalAdminAcl_setPermissionAdmin() external {
        assertEq(poolPermissionManager.permissionAdmins(address(1)), false);

        vm.prank(operationalAdmin);
        poolPermissionManager.setPermissionAdmin(address(1), true);

        assertEq(poolPermissionManager.permissionAdmins(address(1)), true);
    }

    function test_operationalAdminAcl_setPlatformManagementFeeRate() external {
        assertEq(globals.platformManagementFeeRate(address(poolManager)), 0);

        vm.prank(operationalAdmin);
        globals.setPlatformManagementFeeRate(address(poolManager), 10);

        assertEq(globals.platformManagementFeeRate(address(poolManager)), 10);
    }

    function test_operationalAdminAcl_setPlatformOriginationFeeRate() external {
        assertEq(globals.platformOriginationFeeRate(address(poolManager)), 0);

        vm.prank(operationalAdmin);
        globals.setPlatformOriginationFeeRate(address(poolManager), 10);

        assertEq(globals.platformOriginationFeeRate(address(poolManager)), 10);
    }

    function test_operationalAdminAcl_setPlatformServiceFeeRate() external {
        assertEq(globals.platformServiceFeeRate(address(poolManager)), 0);

        vm.prank(operationalAdmin);
        globals.setPlatformServiceFeeRate(address(poolManager), 10);

        assertEq(globals.platformServiceFeeRate(address(poolManager)), 10);
    }

    function test_operationalAdminAcl_setValidInstanceOf() external {
        assertFalse(globals.isInstanceOf("TEST_INSTANCE", address(1)));

        vm.prank(operationalAdmin);
        globals.setValidInstanceOf("TEST_INSTANCE", address(1), true);

        assertTrue(globals.isInstanceOf("TEST_INSTANCE", address(1)));
    }

}
