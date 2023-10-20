// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IFixedTermLoanManager,
    INonTransparentProxied,
    INonTransparentProxy,
    IProxiedLike,
    IProxyFactoryLike
} from "../../contracts/interfaces/Interfaces.sol";

import {
    FixedTermLoanManager,
    Globals,
    PoolManager,
    WithdrawalManagerCyclical
} from "../../contracts/Contracts.sol";

import { TestBase } from "../TestBase.sol";

contract GlobalsUpgradeTests is TestBase {

    address newImplementation = address(new Globals());

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

contract LoanManagerUpgradeTests is TestBase {

    address newImplementation = address(new FixedTermLoanManager());

    address loanManager;

    bytes upgradeCallData = new bytes(0);

    function setUp() public override {
        super.setUp();

        loanManager = poolManager.loanManagerList(0);

        vm.startPrank(governor);

        IProxyFactoryLike(fixedTermLoanManagerFactory).registerImplementation(2, newImplementation, address(0));
        IProxyFactoryLike(fixedTermLoanManagerFactory).enableUpgradePath(1, 2, address(0));

        vm.stopPrank();
    }

    function test_upgradeLoanManager_noTimelock() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.startPrank(poolDelegate);

        vm.expectRevert("LM:U:INV_SCHED_CALL");
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

        vm.expectRevert("LM:U:INV_SCHED_CALL");
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

        vm.expectRevert("LM:U:INV_SCHED_CALL");
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
        vm.expectRevert("LM:U:INV_SCHED_CALL");
        IProxiedLike(loanManager).upgrade(2, upgradeCallData);

        // Warp to right before duration begin
        vm.warp(start + 2 weeks - 1);

        vm.expectRevert("LM:U:INV_SCHED_CALL");
        IProxiedLike(loanManager).upgrade(2, upgradeCallData);

        // Warp to past duration.
        vm.warp(start + 2 weeks + 1 weeks + 1);

        vm.expectRevert("LM:U:INV_SCHED_CALL");
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
        vm.expectRevert("LM:U:INV_SCHED_CALL");
        IProxiedLike(loanManager).upgrade(2, upgradeCallData);

        // Warp to right before duration begin
        vm.warp(start + 2 days - 1);

        vm.expectRevert("LM:U:INV_SCHED_CALL");
        IProxiedLike(loanManager).upgrade(2, upgradeCallData);

        // Warp to past duration.
        vm.warp(start + 2 days + 1 days + 1);

        vm.expectRevert("LM:U:INV_SCHED_CALL");
        IProxiedLike(loanManager).upgrade(2, upgradeCallData);

        // Warp to right at duration end.
        vm.warp(start + 2 days + 1 days);

        IProxiedLike(loanManager).upgrade(2, upgradeCallData);
    }

    function test_upgradeLoanManager_governor_noTimelockNeeded() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.startPrank(poolDelegate);

        globals.scheduleCall(loanManager, "LM:UPGRADE", scheduleArgs);

        // Warp to right before clearing delay.
        vm.warp(start + 1 weeks - 1);

        vm.expectRevert("LM:U:INV_SCHED_CALL");
        IProxiedLike(loanManager).upgrade(2, upgradeCallData);

        // Call upgrade using governor instead, unaffected by pool delegate's scheduled timelock.
        vm.stopPrank();

        vm.prank(governor);
        IProxiedLike(loanManager).upgrade(2, upgradeCallData);
    }

}

contract LiquidationUpgradeTests is TestBase {

    address borrower          = makeAddr("borrower");
    address lp                = makeAddr("lp");
    address newImplementation = address(new FixedTermLoanManager());

    address liquidator;
    address loan;

    bytes upgradeCallData = new bytes(0);

    function setUp() public override {
        super.setUp();

        vm.startPrank(governor);

        IProxyFactoryLike(liquidatorFactory).registerImplementation(2, newImplementation, address(0));
        IProxyFactoryLike(liquidatorFactory).enableUpgradePath(1, 2, address(0));

        vm.stopPrank();

        deposit(lp, 1_500_000e6);

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         275e6,
            delegateManagementFeeRate:  0.02e6,    // 1,000,000 * 3.1536% * 2% * 1,000,000 / (365 * 86400) = 20
            platformOriginationFeeRate: 0.001e6,   // 1,000,000 * 0.10%   * 3  * 1,000,000 / (365 * 86400) = 95.129375e6
            platformServiceFeeRate:     0.0066e6,  // 1,000,000 * 0.66%        * 1,000,000 / (365 * 86400) = 209.2846270e6
            platformManagementFeeRate:  0.08e6     // 1,000,000 * 3.1536% * 8% * 1,000,000 / (365 * 86400) = 80
        });

        address loanManager = poolManager.loanManagerList(0);

        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0), uint256(0.0001e6), uint256(0.031536e6)],
            loanManager: loanManager
        });

        // Since we round up days when it comes to late interest, this payment is 6 days late.
        vm.warp(start + 1_000_000 + 5 days + 1);

        triggerDefault(loan, address(liquidatorFactory));

        ( , , , , , liquidator ) = IFixedTermLoanManager(loanManager).liquidationInfo(loan);

        // Resetting start because we had to advance time to trigger default.
        start = block.timestamp;
    }

    function test_upgradeLiquidator_noTimelock() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.startPrank(poolDelegate);

        vm.expectRevert("LIQ:U:INVALID_SCHED_CALL");
        IProxiedLike(liquidator).upgrade(2, upgradeCallData);

        globals.scheduleCall(liquidator, "LIQ:UPGRADE", scheduleArgs);

        // Wait for delay duration.
        vm.warp(start + 1 weeks);

        IProxiedLike(liquidator).upgrade(2, upgradeCallData);
    }

    function test_upgradeLiquidator_delayNotPassed() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.startPrank(poolDelegate);

        globals.scheduleCall(liquidator, "LIQ:UPGRADE", scheduleArgs);

        // Warp to right before clearing delay.
        vm.warp(start + 1 weeks - 1);

        vm.expectRevert("LIQ:U:INVALID_SCHED_CALL");
        IProxiedLike(liquidator).upgrade(2, upgradeCallData);

        vm.warp(start + 1 weeks);
        IProxiedLike(liquidator).upgrade(2, upgradeCallData);
    }

    function test_upgradeLiquidator_durationPassed() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.startPrank(poolDelegate);

        globals.scheduleCall(liquidator, "LIQ:UPGRADE", scheduleArgs);

        // Warp to right after duration end.
        vm.warp(start + 1 weeks + 2 days + 1);

        vm.expectRevert("LIQ:U:INVALID_SCHED_CALL");
        IProxiedLike(liquidator).upgrade(2, upgradeCallData);

        vm.warp(start + 1 weeks + 2 days);
        IProxiedLike(liquidator).upgrade(2, upgradeCallData);
    }

    function test_upgradeLiquidator_timelockExtended() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.prank(poolDelegate);
        globals.scheduleCall(liquidator, "LIQ:UPGRADE", scheduleArgs);

        // Warp to beginning of timelock duration.
        vm.warp(start + 1 weeks);

        bool isValid = globals.isValidScheduledCall(poolDelegate, liquidator, "LIQ:UPGRADE", scheduleArgs);

        // Should be valid before we change the timelock settings.
        assertTrue(isValid);

        vm.prank(governor);
        globals.setTimelockWindow(liquidator, "LIQ:UPGRADE", 2 weeks, 1 weeks);

        isValid = globals.isValidScheduledCall(poolDelegate, liquidator, "LIQ:UPGRADE", scheduleArgs);
        assertTrue(!isValid);

        vm.startPrank(poolDelegate);

        // With timelock change, upgrade should now revert.
        vm.expectRevert("LIQ:U:INVALID_SCHED_CALL");
        IProxiedLike(liquidator).upgrade(2, upgradeCallData);

        // Warp to right before duration begin
        vm.warp(start + 2 weeks - 1);

        vm.expectRevert("LIQ:U:INVALID_SCHED_CALL");
        IProxiedLike(liquidator).upgrade(2, upgradeCallData);

        // Warp to past duration.
        vm.warp(start + 2 weeks + 1 weeks + 1);

        vm.expectRevert("LIQ:U:INVALID_SCHED_CALL");
        IProxiedLike(liquidator).upgrade(2, upgradeCallData);

        // Warp to right at duration end.
        vm.warp(start + 2 weeks + 1 weeks);

        IProxiedLike(liquidator).upgrade(2, upgradeCallData);
    }

    function test_upgradeLiquidator_timelockShortened() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.prank(poolDelegate);
        globals.scheduleCall(liquidator, "LIQ:UPGRADE", scheduleArgs);

        // Warp to beginning of timelock duration.
        vm.warp(start + 1 weeks);

        bool isValid = globals.isValidScheduledCall(poolDelegate, liquidator, "LIQ:UPGRADE", scheduleArgs);

        // Should be valid before we change the timelock settings.
        assertTrue(isValid);

        vm.prank(governor);
        globals.setTimelockWindow(liquidator, "LIQ:UPGRADE", 2 days, 1 days);

        isValid = globals.isValidScheduledCall(poolDelegate, liquidator, "LIQ:UPGRADE", scheduleArgs);
        assertTrue(!isValid);

        vm.startPrank(poolDelegate);

        // With timelock change, we should be past the duration.
        vm.expectRevert("LIQ:U:INVALID_SCHED_CALL");
        IProxiedLike(liquidator).upgrade(2, upgradeCallData);

        // Warp to right before duration begin
        vm.warp(start + 2 days - 1);

        vm.expectRevert("LIQ:U:INVALID_SCHED_CALL");
        IProxiedLike(liquidator).upgrade(2, upgradeCallData);

        // Warp to past duration.
        vm.warp(start + 2 days + 1 days + 1);

        vm.expectRevert("LIQ:U:INVALID_SCHED_CALL");
        IProxiedLike(liquidator).upgrade(2, upgradeCallData);

        // Warp to right at duration end.
        vm.warp(start + 2 days + 1 days);

        IProxiedLike(liquidator).upgrade(2, upgradeCallData);
    }

    function test_upgradeLiquidator_governor_noTimelockNeeded() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.startPrank(poolDelegate);

        globals.scheduleCall(liquidator, "LIQ:UPGRADE", scheduleArgs);

        // Warp to right before clearing delay.
        vm.warp(start + 1 weeks - 1);

        vm.expectRevert("LIQ:U:INVALID_SCHED_CALL");
        IProxiedLike(liquidator).upgrade(2, upgradeCallData);

        // Call upgrade using governor instead, unaffected by pool delegate's scheduled timelock.
        vm.stopPrank();

        vm.prank(governor);
        IProxiedLike(liquidator).upgrade(2, upgradeCallData);
    }

}

contract PoolManagerUpgradeTests is TestBase {

    address newImplementation = address(new PoolManager());

    bytes upgradeCallData = new bytes(0);

    function setUp() public override {
        super.setUp();

        vm.startPrank(governor);

        IProxyFactoryLike(poolManagerFactory).registerImplementation(2, newImplementation, address(0));
        IProxyFactoryLike(poolManagerFactory).enableUpgradePath(1, 2, address(0));

        vm.stopPrank();
    }

    function test_upgradePoolManager_noTimelock() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.startPrank(poolDelegate);

        vm.expectRevert("PM:U:INVALID_SCHED_CALL");
        poolManager.upgrade(2, upgradeCallData);

        globals.scheduleCall(address(poolManager), "PM:UPGRADE", scheduleArgs);

        // Wait for delay duration.
        vm.warp(start + 1 weeks);

        poolManager.upgrade(2, upgradeCallData);
    }

    function test_upgradePoolManager_delayNotPassed() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.startPrank(poolDelegate);

        globals.scheduleCall(address(poolManager), "PM:UPGRADE", scheduleArgs);

        // Warp to right before clearing delay.
        vm.warp(start + 1 weeks - 1);

        vm.expectRevert("PM:U:INVALID_SCHED_CALL");
        poolManager.upgrade(2, upgradeCallData);

        vm.warp(start + 1 weeks);
        poolManager.upgrade(2, upgradeCallData);
    }

    function test_upgradePoolManager_durationPassed() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.startPrank(poolDelegate);

        globals.scheduleCall(address(poolManager), "PM:UPGRADE", scheduleArgs);

        // Warp to right after duration end.
        vm.warp(start + 1 weeks + 2 days + 1);

        vm.expectRevert("PM:U:INVALID_SCHED_CALL");
        poolManager.upgrade(2, upgradeCallData);

        vm.warp(start + 1 weeks + 2 days);
        poolManager.upgrade(2, upgradeCallData);
    }

    function test_upgradePoolManager_timelockExtended() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.prank(poolDelegate);
        globals.scheduleCall(address(poolManager), "PM:UPGRADE", scheduleArgs);

        // Warp to beginning of timelock duration.
        vm.warp(start + 1 weeks);

        bool isValid = globals.isValidScheduledCall(poolDelegate, address(poolManager), "PM:UPGRADE", scheduleArgs);

        // Should be valid before we change the timelock settings.
        assertTrue(isValid);

        vm.prank(governor);
        globals.setTimelockWindow(address(poolManager), "PM:UPGRADE", 2 weeks, 1 weeks);

        isValid = globals.isValidScheduledCall(poolDelegate, address(poolManager), "PM:UPGRADE", scheduleArgs);
        assertTrue(!isValid);

        vm.startPrank(poolDelegate);

        // With timelock change, upgrade should now revert.
        vm.expectRevert("PM:U:INVALID_SCHED_CALL");
        poolManager.upgrade(2, upgradeCallData);

        // Warp to right before duration begin
        vm.warp(start + 2 weeks - 1);

        vm.expectRevert("PM:U:INVALID_SCHED_CALL");
        poolManager.upgrade(2, upgradeCallData);

        // Warp to past duration.
        vm.warp(start + 2 weeks + 1 weeks + 1);

        vm.expectRevert("PM:U:INVALID_SCHED_CALL");
        poolManager.upgrade(2, upgradeCallData);

        // Warp to right at duration end.
        vm.warp(start + 2 weeks + 1 weeks);

        poolManager.upgrade(2, upgradeCallData);
    }

    function test_upgradePoolManager_timelockShortened() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.prank(poolDelegate);
        globals.scheduleCall(address(poolManager), "PM:UPGRADE", scheduleArgs);

        // Warp to beginning of timelock duration.
        vm.warp(start + 1 weeks);

        bool isValid = globals.isValidScheduledCall(poolDelegate, address(poolManager), "PM:UPGRADE", scheduleArgs);

        // Should be valid before we change the timelock settings.
        assertTrue(isValid);

        vm.prank(governor);
        globals.setTimelockWindow(address(poolManager), "PM:UPGRADE", 2 days, 1 days);

        isValid = globals.isValidScheduledCall(poolDelegate, address(poolManager), "PM:UPGRADE", scheduleArgs);
        assertTrue(!isValid);

        vm.startPrank(poolDelegate);

        // With timelock change, we should be past the duration.
        vm.expectRevert("PM:U:INVALID_SCHED_CALL");
        poolManager.upgrade(2, upgradeCallData);

        // Warp to right before duration begin
        vm.warp(start + 2 days - 1);

        vm.expectRevert("PM:U:INVALID_SCHED_CALL");
        poolManager.upgrade(2, upgradeCallData);

        // Warp to past duration.
        vm.warp(start + 2 days + 1 days + 1);

        vm.expectRevert("PM:U:INVALID_SCHED_CALL");
        poolManager.upgrade(2, upgradeCallData);

        // Warp to right at duration end.
        vm.warp(start + 2 days + 1 days);

        poolManager.upgrade(2, upgradeCallData);
    }

    function test_upgradePoolManager_governor_noTimelockNeeded() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.startPrank(poolDelegate);

        globals.scheduleCall(address(poolManager), "PM:UPGRADE", scheduleArgs);

        // Warp to right before clearing delay.
        vm.warp(start + 1 weeks - 1);

        vm.expectRevert("PM:U:INVALID_SCHED_CALL");
        poolManager.upgrade(2, upgradeCallData);

        // Call upgrade using governor instead, unaffected by pool delegate's scheduled timelock.
        vm.stopPrank();

        vm.prank(governor);
        poolManager.upgrade(2, upgradeCallData);
    }
}

contract WithdrawalManagerUpgradeTests is TestBase {

    address newImplementation = address(new WithdrawalManagerCyclical());

    bytes upgradeCallData = new bytes(0);

    function setUp() public override {
        super.setUp();

        vm.startPrank(governor);

        IProxyFactoryLike(cyclicalWMFactory).registerImplementation(2, newImplementation, address(0));
        IProxyFactoryLike(cyclicalWMFactory).enableUpgradePath(1, 2, address(0));

        vm.stopPrank();
    }

    function test_upgradeWithdrawalManager_noTimelock() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.startPrank(poolDelegate);

        vm.expectRevert("WM:U:INVALID_SCHED_CALL");
        cyclicalWM.upgrade(2, upgradeCallData);

        globals.scheduleCall(address(cyclicalWM), "WM:UPGRADE", scheduleArgs);

        // Wait for delay duration.
        vm.warp(start + 1 weeks);

        cyclicalWM.upgrade(2, upgradeCallData);
    }

    function test_upgradeWithdrawalManager_delayNotPassed() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.startPrank(poolDelegate);

        globals.scheduleCall(address(cyclicalWM), "WM:UPGRADE", scheduleArgs);

        // Warp to right before clearing delay.
        vm.warp(start + 1 weeks - 1);

        vm.expectRevert("WM:U:INVALID_SCHED_CALL");
        cyclicalWM.upgrade(2, upgradeCallData);

        vm.warp(start + 1 weeks);
        cyclicalWM.upgrade(2, upgradeCallData);
    }

    function test_upgradeWithdrawalManager_durationPassed() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.startPrank(poolDelegate);

        globals.scheduleCall(address(cyclicalWM), "WM:UPGRADE", scheduleArgs);

        // Warp to right after duration end.
        vm.warp(start + 1 weeks + 2 days + 1);

        vm.expectRevert("WM:U:INVALID_SCHED_CALL");
        cyclicalWM.upgrade(2, upgradeCallData);

        vm.warp(start + 1 weeks + 2 days);
        cyclicalWM.upgrade(2, upgradeCallData);
    }

    function test_upgradeWithdrawalManager_timelockExtended() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.prank(poolDelegate);
        globals.scheduleCall(address(cyclicalWM), "WM:UPGRADE", scheduleArgs);

        // Warp to beginning of timelock duration.
        vm.warp(start + 1 weeks);

        bool isValid = globals.isValidScheduledCall(poolDelegate, address(cyclicalWM), "WM:UPGRADE", scheduleArgs);

        // Should be valid before we change the timelock settings.
        assertTrue(isValid);

        vm.prank(governor);
        globals.setTimelockWindow(address(cyclicalWM), "WM:UPGRADE", 2 weeks, 1 weeks);

        isValid = globals.isValidScheduledCall(poolDelegate, address(cyclicalWM), "WM:UPGRADE", scheduleArgs);
        assertTrue(!isValid);

        vm.startPrank(poolDelegate);

        // With timelock change, upgrade should now revert.
        vm.expectRevert("WM:U:INVALID_SCHED_CALL");
        cyclicalWM.upgrade(2, upgradeCallData);

        // Warp to right before duration begin
        vm.warp(start + 2 weeks - 1);

        vm.expectRevert("WM:U:INVALID_SCHED_CALL");
        cyclicalWM.upgrade(2, upgradeCallData);

        // Warp to past duration.
        vm.warp(start + 2 weeks + 1 weeks + 1);

        vm.expectRevert("WM:U:INVALID_SCHED_CALL");
        cyclicalWM.upgrade(2, upgradeCallData);

        // Warp to right at duration end.
        vm.warp(start + 2 weeks + 1 weeks);

        cyclicalWM.upgrade(2, upgradeCallData);
    }

    function test_upgradeWithdrawalManager_timelockShortened() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.prank(poolDelegate);
        globals.scheduleCall(address(cyclicalWM), "WM:UPGRADE", scheduleArgs);

        // Warp to beginning of timelock duration.
        vm.warp(start + 1 weeks);

        bool isValid = globals.isValidScheduledCall(poolDelegate, address(cyclicalWM), "WM:UPGRADE", scheduleArgs);

        // Should be valid before we change the timelock settings.
        assertTrue(isValid);

        vm.prank(governor);
        globals.setTimelockWindow(address(cyclicalWM), "WM:UPGRADE", 2 days, 1 days);

        isValid = globals.isValidScheduledCall(poolDelegate, address(cyclicalWM), "WM:UPGRADE", scheduleArgs);
        assertTrue(!isValid);

        vm.startPrank(poolDelegate);

        // With timelock change, we should be past the duration.
        vm.expectRevert("WM:U:INVALID_SCHED_CALL");
        cyclicalWM.upgrade(2, upgradeCallData);

        // Warp to right before duration begin
        vm.warp(start + 2 days - 1);

        vm.expectRevert("WM:U:INVALID_SCHED_CALL");
        cyclicalWM.upgrade(2, upgradeCallData);

        // Warp to past duration.
        vm.warp(start + 2 days + 1 days + 1);

        vm.expectRevert("WM:U:INVALID_SCHED_CALL");
        cyclicalWM.upgrade(2, upgradeCallData);

        // Warp to right at duration end.
        vm.warp(start + 2 days + 1 days);

        cyclicalWM.upgrade(2, upgradeCallData);
    }

    function test_upgradeWithdrawalManager_governor_noTimelockNeeded() external {
        bytes memory scheduleArgs = abi.encodeWithSelector(IProxiedLike.upgrade.selector, uint256(2), upgradeCallData);

        vm.startPrank(poolDelegate);

        globals.scheduleCall(address(cyclicalWM), "WM:UPGRADE", scheduleArgs);

        // Warp to right before clearing delay.
        vm.warp(start + 1 weeks - 1);

        vm.expectRevert("WM:U:INVALID_SCHED_CALL");
        cyclicalWM.upgrade(2, upgradeCallData);

        // Call upgrade using governor instead, unaffected by withdrawal delegate's scheduled timelock.
        vm.stopPrank();

        vm.prank(governor);
        cyclicalWM.upgrade(2, upgradeCallData);
    }

}

contract UnscheduleCallTests is TestBase {

    bytes upgradeCallData = new bytes(0);

    function test_unscheduleCall_governor() external {
        address loanManager = poolManager.loanManagerList(0);

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
