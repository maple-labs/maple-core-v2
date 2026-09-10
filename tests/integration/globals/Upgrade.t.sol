// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IMapleProxyFactory,
    INonTransparentProxied,
    INonTransparentProxy,
    IProxiedLike
} from "../../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../../TestBase.sol";

contract GlobalsUpgradeTests is TestBase {

    address newImplementation = deployFromFile("Contracts@34", "Globals");

    function test_upgradeGlobals_notAdmin() external {
        INonTransparentProxy proxy = INonTransparentProxy(address(globals));

        vm.expectRevert("NTP:SI:NOT_ADMIN");
        proxy.setImplementation(newImplementation);

        vm.prank(governor);
        proxy.setImplementation(newImplementation);

        assertEq(INonTransparentProxied(globals).implementation(), newImplementation);
    }

    function test_upgradeGlobals() external {
        INonTransparentProxy proxy = INonTransparentProxy(address(globals));

        vm.prank(governor);
        proxy.setImplementation(newImplementation);

        assertEq(INonTransparentProxied(globals).implementation(), newImplementation);
    }

}

contract PoolManagerUpgradeTests is TestBase {

    address newImplementation = deployFromFile("Contracts@34", "PoolManager");

    bytes upgradeCallData = new bytes(0);

    function setUp() public override {
        super.setUp();

        vm.startPrank(governor);

        IMapleProxyFactory(poolManagerFactory).registerImplementation(2, newImplementation, address(0));
        IMapleProxyFactory(poolManagerFactory).enableUpgradePath(1, 2, address(0));

        vm.stopPrank();
    }

    function test_upgradePoolManager_notSecurityAdmin() external {
        vm.expectRevert("PM:U:NO_AUTH");
        poolManager.upgrade(2, upgradeCallData);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:U:NO_AUTH");
        poolManager.upgrade(2, upgradeCallData);

        vm.prank(governor);
        vm.expectRevert("PM:U:NO_AUTH");
        poolManager.upgrade(2, upgradeCallData);

        vm.prank(operationalAdmin);
        vm.expectRevert("PM:U:NO_AUTH");
        poolManager.upgrade(2, upgradeCallData);
    }

    function test_upgradePoolManager_scheduledCallDoesNotAuthorizePoolDelegate() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.prank(poolDelegate);
        globals.scheduleCall(address(poolManager), "PM:UPGRADE", scheduleArgs);

        vm.warp(start + 1 weeks);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:U:NO_AUTH");
        poolManager.upgrade(2, upgradeCallData);
    }

    function test_upgradePoolManager_asSecurityAdmin() external {
        assertTrue(IProxiedLike(address(poolManager)).implementation() != newImplementation);

        vm.prank(securityAdmin);
        poolManager.upgrade(2, upgradeCallData);

        assertEq(IProxiedLike(address(poolManager)).implementation(), newImplementation);
    }

}

contract LoanManagerUpgradeTests is TestBase {

    address newImplementation = deployFromFile("Contracts@7","OpenTermLoanManager");

    address loanManager;

    bytes upgradeCallData = new bytes(0);

    function setUp() public override {
        super.setUp();

        loanManager = poolManager.strategyList(0);

        vm.startPrank(governor);

        IMapleProxyFactory(openTermLoanManagerFactory).registerImplementation(2, newImplementation, address(0));
        IMapleProxyFactory(openTermLoanManagerFactory).enableUpgradePath(1, 2, address(0));

        vm.stopPrank();
    }

    function test_upgradeLoanManager_noTimelock() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.startPrank(poolDelegate);

        vm.expectRevert("LM:U:INVALID_SCHED_CALL");
        IProxiedLike(loanManager).upgrade(2, upgradeCallData);

        globals.scheduleCall(loanManager, "LM:UPGRADE", scheduleArgs);

        // Wait for delay duration.
        vm.warp(start + 1 weeks);

        IProxiedLike(loanManager).upgrade(2, upgradeCallData);
    }

    function test_upgradeLoanManager_delayNotPassed() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.startPrank(poolDelegate);

        globals.scheduleCall(loanManager, "LM:UPGRADE", scheduleArgs);

        // Warp to right before clearing delay.
        vm.warp(start + 1 weeks - 1);

        vm.expectRevert("LM:U:INVALID_SCHED_CALL");
        IProxiedLike(loanManager).upgrade(2, upgradeCallData);

        vm.warp(start + 1 weeks);
        IProxiedLike(loanManager).upgrade(2, upgradeCallData);
    }

    function test_upgradeLoanManager_durationPassed() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.startPrank(poolDelegate);

        globals.scheduleCall(loanManager, "LM:UPGRADE", scheduleArgs);

        // Warp to right after duration end.
        vm.warp(start + 1 weeks + 2 days + 1);

        vm.expectRevert("LM:U:INVALID_SCHED_CALL");
        IProxiedLike(loanManager).upgrade(2, upgradeCallData);

        vm.warp(start + 1 weeks + 2 days);
        IProxiedLike(loanManager).upgrade(2, upgradeCallData);
    }

    function test_upgradeLoanManager_timelockExtended() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.prank(poolDelegate);
        globals.scheduleCall(loanManager, "LM:UPGRADE", scheduleArgs);

        // Warp to beginning of timelock duration.
        vm.warp(start + 1 weeks);

        bool isValid = globals.isValidScheduledCall(poolDelegate, loanManager, "LM:UPGRADE", scheduleArgs);

        // Should be valid before we change the timelock settings.
        assertTrue(isValid);

        vm.prank(governor);
        globals.setTimelockWindow(loanManager, "LM:UPGRADE", 2 weeks, 1 weeks);

        isValid = globals.isValidScheduledCall(poolDelegate, loanManager, "LM:UPGRADE", scheduleArgs);
        assertTrue(!isValid);

        vm.startPrank(poolDelegate);

        // With timelock change, upgrade should now revert.
        vm.expectRevert("LM:U:INVALID_SCHED_CALL");
        IProxiedLike(loanManager).upgrade(2, upgradeCallData);

        // Warp to right before duration begin
        vm.warp(start + 2 weeks - 1);

        vm.expectRevert("LM:U:INVALID_SCHED_CALL");
        IProxiedLike(loanManager).upgrade(2, upgradeCallData);

        // Warp to past duration.
        vm.warp(start + 2 weeks + 1 weeks + 1);

        vm.expectRevert("LM:U:INVALID_SCHED_CALL");
        IProxiedLike(loanManager).upgrade(2, upgradeCallData);

        // Warp to right at duration end.
        vm.warp(start + 2 weeks + 1 weeks);

        IProxiedLike(loanManager).upgrade(2, upgradeCallData);
    }

    function test_upgradeLoanManager_timelockShortened() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.prank(poolDelegate);
        globals.scheduleCall(loanManager, "LM:UPGRADE", scheduleArgs);

        // Warp to beginning of timelock duration.
        vm.warp(start + 1 weeks);

        bool isValid = globals.isValidScheduledCall(poolDelegate, loanManager, "LM:UPGRADE", scheduleArgs);

        // Should be valid before we change the timelock settings.
        assertTrue(isValid);

        vm.prank(governor);
        globals.setTimelockWindow(loanManager, "LM:UPGRADE", 2 days, 1 days);

        isValid = globals.isValidScheduledCall(poolDelegate, loanManager, "LM:UPGRADE", scheduleArgs);
        assertTrue(!isValid);

        vm.startPrank(poolDelegate);

        // With timelock change, we should be past the duration.
        vm.expectRevert("LM:U:INVALID_SCHED_CALL");
        IProxiedLike(loanManager).upgrade(2, upgradeCallData);

        // Warp to right before duration begin
        vm.warp(start + 2 days - 1);

        vm.expectRevert("LM:U:INVALID_SCHED_CALL");
        IProxiedLike(loanManager).upgrade(2, upgradeCallData);

        // Warp to past duration.
        vm.warp(start + 2 days + 1 days + 1);

        vm.expectRevert("LM:U:INVALID_SCHED_CALL");
        IProxiedLike(loanManager).upgrade(2, upgradeCallData);

        // Warp to right at duration end.
        vm.warp(start + 2 days + 1 days);

        IProxiedLike(loanManager).upgrade(2, upgradeCallData);
    }

    function test_upgradeLoanManager_securityAdmin_noTimelockNeeded() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.startPrank(poolDelegate);

        globals.scheduleCall(loanManager, "LM:UPGRADE", scheduleArgs);

        // Warp to right before clearing delay.
        vm.warp(start + 1 weeks - 1);

        vm.expectRevert("LM:U:INVALID_SCHED_CALL");
        IProxiedLike(loanManager).upgrade(2, upgradeCallData);

        // Call upgrade using governor instead, unaffected by pool delegate's scheduled timelock.
        vm.stopPrank();

        vm.prank(securityAdmin);
        IProxiedLike(loanManager).upgrade(2, upgradeCallData);
    }

}

contract WithdrawalManagerUpgradeTests is TestBase {

    address newImplementation = deployFromFile("Contracts@7", "WithdrawalManagerQueue");

    bytes upgradeCallData = new bytes(0);

    function setUp() public override {
        _setUpOpenPool();

        vm.startPrank(governor);

        IMapleProxyFactory(queueWMFactory).registerImplementation(2, newImplementation, address(0));
        IMapleProxyFactory(queueWMFactory).enableUpgradePath(1, 2, address(0));

        vm.stopPrank();
    }

    function test_upgradeWithdrawalManager_noTimelock() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.startPrank(poolDelegate);

        vm.expectRevert("WM:U:INVALID_SCHED_CALL");
        queueWM.upgrade(2, upgradeCallData);

        globals.scheduleCall(address(queueWM), "WM:UPGRADE", scheduleArgs);

        // Wait for delay duration.
        vm.warp(start + 1 weeks);

        queueWM.upgrade(2, upgradeCallData);
    }

    function test_upgradeWithdrawalManager_delayNotPassed() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.startPrank(poolDelegate);

        globals.scheduleCall(address(queueWM), "WM:UPGRADE", scheduleArgs);

        // Warp to right before clearing delay.
        vm.warp(start + 1 weeks - 1);

        vm.expectRevert("WM:U:INVALID_SCHED_CALL");
        queueWM.upgrade(2, upgradeCallData);

        vm.warp(start + 1 weeks);
        queueWM.upgrade(2, upgradeCallData);
    }

    function test_upgradeWithdrawalManager_durationPassed() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.startPrank(poolDelegate);

        globals.scheduleCall(address(queueWM), "WM:UPGRADE", scheduleArgs);

        // Warp to right after duration end.
        vm.warp(start + 1 weeks + 2 days + 1);

        vm.expectRevert("WM:U:INVALID_SCHED_CALL");
        queueWM.upgrade(2, upgradeCallData);

        vm.warp(start + 1 weeks + 2 days);
        queueWM.upgrade(2, upgradeCallData);
    }

    function test_upgradeWithdrawalManager_timelockExtended() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.prank(poolDelegate);
        globals.scheduleCall(address(queueWM), "WM:UPGRADE", scheduleArgs);

        // Warp to beginning of timelock duration.
        vm.warp(start + 1 weeks);

        bool isValid = globals.isValidScheduledCall(poolDelegate, address(queueWM), "WM:UPGRADE", scheduleArgs);

        // Should be valid before we change the timelock settings.
        assertTrue(isValid);

        vm.prank(governor);
        globals.setTimelockWindow(address(queueWM), "WM:UPGRADE", 2 weeks, 1 weeks);

        isValid = globals.isValidScheduledCall(poolDelegate, address(queueWM), "WM:UPGRADE", scheduleArgs);
        assertTrue(!isValid);

        vm.startPrank(poolDelegate);

        // With timelock change, upgrade should now revert.
        vm.expectRevert("WM:U:INVALID_SCHED_CALL");
        queueWM.upgrade(2, upgradeCallData);

        // Warp to right before duration begin
        vm.warp(start + 2 weeks - 1);

        vm.expectRevert("WM:U:INVALID_SCHED_CALL");
        queueWM.upgrade(2, upgradeCallData);

        // Warp to past duration.
        vm.warp(start + 2 weeks + 1 weeks + 1);

        vm.expectRevert("WM:U:INVALID_SCHED_CALL");
        queueWM.upgrade(2, upgradeCallData);

        // Warp to right at duration end.
        vm.warp(start + 2 weeks + 1 weeks);

        queueWM.upgrade(2, upgradeCallData);
    }

    function test_upgradeWithdrawalManager_timelockShortened() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.prank(poolDelegate);
        globals.scheduleCall(address(queueWM), "WM:UPGRADE", scheduleArgs);

        // Warp to beginning of timelock duration.
        vm.warp(start + 1 weeks);

        bool isValid = globals.isValidScheduledCall(poolDelegate, address(queueWM), "WM:UPGRADE", scheduleArgs);

        // Should be valid before we change the timelock settings.
        assertTrue(isValid);

        vm.prank(governor);
        globals.setTimelockWindow(address(queueWM), "WM:UPGRADE", 2 days, 1 days);

        isValid = globals.isValidScheduledCall(poolDelegate, address(queueWM), "WM:UPGRADE", scheduleArgs);
        assertTrue(!isValid);

        vm.startPrank(poolDelegate);

        // With timelock change, we should be past the duration.
        vm.expectRevert("WM:U:INVALID_SCHED_CALL");
        queueWM.upgrade(2, upgradeCallData);

        // Warp to right before duration begin
        vm.warp(start + 2 days - 1);

        vm.expectRevert("WM:U:INVALID_SCHED_CALL");
        queueWM.upgrade(2, upgradeCallData);

        // Warp to past duration.
        vm.warp(start + 2 days + 1 days + 1);

        vm.expectRevert("WM:U:INVALID_SCHED_CALL");
        queueWM.upgrade(2, upgradeCallData);

        // Warp to right at duration end.
        vm.warp(start + 2 days + 1 days);

        queueWM.upgrade(2, upgradeCallData);
    }

    function test_upgradeWithdrawalManager_securityAdmin_noTimelockNeeded() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.startPrank(poolDelegate);

        globals.scheduleCall(address(queueWM), "WM:UPGRADE", scheduleArgs);

        // Warp to right before clearing delay.
        vm.warp(start + 1 weeks - 1);

        vm.expectRevert("WM:U:INVALID_SCHED_CALL");
        queueWM.upgrade(2, upgradeCallData);

        // Call upgrade using governor instead, unaffected by withdrawal delegate's scheduled timelock.
        vm.stopPrank();

        vm.prank(securityAdmin);
        queueWM.upgrade(2, upgradeCallData);
    }

}

contract UnscheduleCallTests is TestBase {

    bytes upgradeCallData = new bytes(0);

    function test_unscheduleCall_governor() external {
        address loanManager = poolManager.strategyList(0);

        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        // PD schedules the upgrade call
        vm.prank(poolDelegate);
        globals.scheduleCall(loanManager, "LM:UPGRADE", scheduleArgs);

        vm.warp(start + 1 weeks);

        assertTrue(globals.isValidScheduledCall(poolDelegate, loanManager, "LM:UPGRADE", scheduleArgs));

        // Governor unschedule the upgrade call
        vm.prank(governor);
        globals.unscheduleCall(poolDelegate, loanManager, "LM:UPGRADE", scheduleArgs);

        assertTrue(!globals.isValidScheduledCall(poolDelegate, loanManager, "LM:UPGRADE", scheduleArgs));
    }

}
