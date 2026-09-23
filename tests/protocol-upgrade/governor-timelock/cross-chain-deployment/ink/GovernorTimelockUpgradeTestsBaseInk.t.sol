// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IGovernorTimelock } from "../../../../../contracts/interfaces/Interfaces.sol";
import { Runner } from "../../../../../contracts/Runner.sol";

import { UpgradeAddressRegistry } from "../../../UpgradeAddressRegistry.sol";

contract GovernorTimelockUpgradeTestsBaseInk is Runner, UpgradeAddressRegistry {

    function setUp() public virtual {
        vm.createSelectFork(vm.rpcUrl("ink"), 37826313); // Fix Block for Testing

        deployGovernorTimelock();
    }

    function deployGovernorTimelock() internal {
        tokenWithdrawerInk = makeAddr("tokenWithdrawerInk");
        proposerInk        = makeAddr("proposerInk");
        executorInk        = makeAddr("executorInk");
        cancellerInk       = makeAddr("cancellerInk");
        roleAdminInk       = makeAddr("roleAdminInk");

        timelockInk = deployFromFile(
            "Contracts@25", "Timelock", abi.encode(tokenWithdrawerInk, proposerInk, executorInk, cancellerInk, roleAdminInk)
        );
    }

    function testFork_setUp_governorTimelockUpgradeTests_Ink() public view {
        assertEq(IGovernorTimelock(timelockInk).hasRole(proposerInk, IGovernorTimelock(timelockInk).PROPOSER_ROLE()),   true);
        assertEq(IGovernorTimelock(timelockInk).hasRole(executorInk, IGovernorTimelock(timelockInk).EXECUTOR_ROLE()),   true);
        assertEq(IGovernorTimelock(timelockInk).hasRole(cancellerInk, IGovernorTimelock(timelockInk).CANCELLER_ROLE()), true);
        assertEq(IGovernorTimelock(timelockInk).hasRole(roleAdminInk, IGovernorTimelock(timelockInk).ROLE_ADMIN()),     true);

        assertEq(IGovernorTimelock(timelockInk).tokenWithdrawer(), tokenWithdrawerInk);

        assertEq(IGovernorTimelock(timelockInk).MIN_DELAY(),            1 days);
        assertEq(IGovernorTimelock(timelockInk).MIN_EXECUTION_WINDOW(), 1 days);

        (uint32 defaultDelay, uint32 defaultExecutionWindow) = IGovernorTimelock(timelockInk).defaultTimelockParameters();

        assertEq(defaultDelay,           IGovernorTimelock(timelockInk).MIN_DELAY());
        assertEq(defaultExecutionWindow, IGovernorTimelock(timelockInk).MIN_EXECUTION_WINDOW());
    }

}
