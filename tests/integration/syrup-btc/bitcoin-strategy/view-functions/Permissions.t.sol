// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract PermissionsTests is SyrupBitcoinTestBase {

    address account = makeAddr("account");

    address[] addresses = [account];

    bool[] deployers   = [false];
    bool[] reconcilers = [false];
    bool[] schedulers  = [false];

    function testFuzz_permissions_random(address target) external view {
        vm.assume(target != strategyManager);

        ( bool canDeploy, bool canReconcile, bool canSchedule ) = bitcoinStrategy.permissions(target);

        assertEq(canDeploy,    false);
        assertEq(canReconcile, false);
        assertEq(canSchedule,  false);
    }

    function testFuzz_permissions_configured(bool deployer, bool reconciler, bool scheduler) external {
        deployers[0]   = deployer;
        reconcilers[0] = reconciler;
        schedulers[0]  = scheduler;

        vm.prank(governor);
        bitcoinStrategy.setPermissions(addresses, deployers, reconcilers, schedulers);

        ( bool canDeploy, bool canReconcile, bool canSchedule ) = bitcoinStrategy.permissions(account);

        assertEq(canDeploy,    deployer);
        assertEq(canReconcile, reconciler);
        assertEq(canSchedule,  scheduler);
    }

}
