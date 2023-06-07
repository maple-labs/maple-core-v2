// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IGlobals, INonTransparentProxy, INonTransparentProxied } from "../../contracts/interfaces/Interfaces.sol";

import { Globals, OpenTermLoanManagerFactory, OpenTermLoanFactory, OpenTermRefinancer } from "../../contracts/Contracts.sol";

import { ProtocolActions } from "../../contracts/ProtocolActions.sol";

import { ProtocolUpgradeBase } from "./ProtocolUpgradeBase.sol";

contract GlobalsMigration is ProtocolUpgradeBase {

    address internal SET_ADDRESS = makeAddr("SET_ADDRESS");

    function setUp() public override {
        super.setUp();

        _deployAllNewContracts();
    }

    function test_globals_upgrade() public {
        IGlobals globals_ = IGlobals(mapleGlobalsProxy);

        // Fetch current globals state.
        ( uint256 oldDelay, uint256 oldDuration ) = globals_.defaultTimelockParameters();

        // Use generic SET_ADDRESS to show storage slots are the same.
        vm.startPrank(governor);

        globals_.setPriceOracle(SET_ADDRESS, SET_ADDRESS);

        globals_.setValidBorrower(SET_ADDRESS, true);
        globals_.setValidCollateralAsset(SET_ADDRESS, true);
        globals_.setValidPoolAsset(SET_ADDRESS, true);

        // Increment uint256 values to differentiate storage slots.
        globals_.setManualOverridePrice(SET_ADDRESS, 1);
        globals_.setMaxCoverLiquidationPercent(SET_ADDRESS, 2);
        globals_.setMinCoverAmount(SET_ADDRESS, 3);
        globals_.setBootstrapMint(SET_ADDRESS, 4);
        globals_.setPlatformManagementFeeRate(SET_ADDRESS, 5);
        globals_.setPlatformOriginationFeeRate(SET_ADDRESS, 6);
        globals_.setPlatformServiceFeeRate(SET_ADDRESS, 7);

        globals_.setTimelockWindow(SET_ADDRESS, "TEST", uint128(oldDelay), uint128(oldDuration));

        globals_.scheduleCall(SET_ADDRESS, "TEST", "TEST");

        globals_.setValidPoolDelegate(SET_ADDRESS, true);

        vm.stopPrank();

        upgradeGlobals(mapleGlobalsProxy, globalsImplementationV2);

        /********************************/
        /*** Assert Old State         ***/
        /********************************/

        assertEq(globals_.mapleTreasury(),   mapleTreasury);
        assertEq(globals_.migrationAdmin(),  address(0));
        assertEq(globals_.pendingGovernor(), address(0));
        assertEq(globals_.securityAdmin(),   securityAdmin);
        assertEq(globals_.protocolPaused(),  false);

        ( uint256 delay, uint256 duration ) = globals_.defaultTimelockParameters();

        assertEq(delay,    oldDelay);
        assertEq(duration, oldDuration);

        assertEq(globals_.oracleFor(SET_ADDRESS), SET_ADDRESS);

        assertTrue(globals_.isBorrower(SET_ADDRESS));
        assertTrue(globals_.isCollateralAsset(SET_ADDRESS));
        assertTrue(globals_.isPoolAsset(SET_ADDRESS));

        assertEq(globals_.manualOverridePrice(SET_ADDRESS),        1);
        assertEq(globals_.maxCoverLiquidationPercent(SET_ADDRESS), 2);
        assertEq(globals_.minCoverAmount(SET_ADDRESS),             3);
        assertEq(globals_.bootstrapMint(SET_ADDRESS),              4);
        assertEq(globals_.platformManagementFeeRate(SET_ADDRESS),  5);
        assertEq(globals_.platformOriginationFeeRate(SET_ADDRESS), 6);
        assertEq(globals_.platformServiceFeeRate(SET_ADDRESS),     7);

        ( delay, duration ) = globals_.timelockParametersOf(SET_ADDRESS, "TEST");

        assertEq(delay,    oldDelay);
        assertEq(duration, oldDuration);

        ( uint256 time, bytes32 dataHash ) = globals_.scheduledCalls(governor, SET_ADDRESS, "TEST");

        assertEq(time,     block.timestamp);
        assertEq(dataHash, keccak256(abi.encode("TEST")));

        assertTrue(globals_.isPoolDelegate(SET_ADDRESS));

        // Ensure old factory keys still work when calling the renamed mapping `isInstanceOf()`
        // this demonstrates the old `isFactory()` and new `isInstanceOf()` mapping are using the same storage slots.
        assertTrue(globals_.isInstanceOf("POOL_MANAGER",       poolManagerFactory));
        assertTrue(globals_.isInstanceOf("WITHDRAWAL_MANAGER", withdrawalManagerFactory));
        assertTrue(globals_.isInstanceOf("LOAN_MANAGER",       fixedTermLoanManagerFactory));
        assertTrue(globals_.isInstanceOf("LOAN",               fixedTermLoanFactory));
        assertTrue(globals_.isInstanceOf("LIQUIDATOR",         liquidatorFactory));

        // Check new implementation is set
        assertTrue(INonTransparentProxied(mapleGlobalsProxy).implementation() == globalsImplementationV2);

        /********************************/
        /*** Backwards Compatibility  ***/
        /********************************/

        _enableGlobalsKeys();
        _disableGlobalsKeys();

        // Ensure the liquidator factory can call `isFactory()` to check if the loan manager factory is valid.
        vm.prank(liquidatorFactory);
        assertTrue(globals_.isFactory("LOAN_MANAGER", fixedTermLoanManagerFactory));

        // Ensure PoolManager and PoolDeployer can deploy their respective contracts by passing the `isPoolDeployer()` check.
        vm.prank(fixedTermLoanManagerFactory);
        assertTrue(globals_.isPoolDeployer(mavenPermissionedPoolManager));  // Any poolManager is sufficient to test.

        vm.prank(withdrawalManagerFactory);
        assertTrue(globals_.isPoolDeployer(poolDeployerV2));

        vm.prank(poolManagerFactory);
        assertTrue(globals_.isPoolDeployer(poolDeployerV2));

        // Old deployer is disabled.
        assertEq(vm.load(mapleGlobalsProxy, keccak256(abi.encode(poolDeployerV1, uint256(9)))), bytes32(0));

        // New deployer is enabled.
        // NOTE: Since the pool deployer mapping was deprecated, this is the way to read the slot to assert the expected values
        //       and to make sure this slot isn't updated when setting the new can deploy from mapping instead.
        assertEq(vm.load(mapleGlobalsProxy, keccak256(abi.encode(poolDeployerV2, uint256(9)))), bytes32(0));
    }

}
