// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IGovernorTimelock } from "../../../../../contracts/interfaces/Interfaces.sol";
import { Runner } from "../../../../../contracts/Runner.sol";

import { UpgradeAddressRegistry } from "../../../UpgradeAddressRegistry.sol";

contract GovernorTimelockUpgradeTestsBaseArc is Runner, UpgradeAddressRegistry {

    function setUp() public virtual {
        vm.createSelectFork(vm.rpcUrl("arc"), 23350000); // Fix Block for Testing

        deployGovernorTimelock();
    }

    function deployGovernorTimelock() internal {
        tokenWithdrawerArc = makeAddr("tokenWithdrawerArc");
        proposerArc        = makeAddr("proposerArc");
        executorArc        = makeAddr("executorArc");
        cancellerArc       = makeAddr("cancellerArc");
        roleAdminArc       = makeAddr("roleAdminArc");

        timelockArc = deployFromFile(
            "Contracts@25", "Timelock", abi.encode(tokenWithdrawerArc, proposerArc, executorArc, cancellerArc, roleAdminArc)
        );
    }

    function testFork_setUp_governorTimelockUpgradeTests_Arc() public view {
        assertEq(IGovernorTimelock(timelockArc).hasRole(proposerArc, IGovernorTimelock(timelockArc).PROPOSER_ROLE()),   true);
        assertEq(IGovernorTimelock(timelockArc).hasRole(executorArc, IGovernorTimelock(timelockArc).EXECUTOR_ROLE()),   true);
        assertEq(IGovernorTimelock(timelockArc).hasRole(cancellerArc, IGovernorTimelock(timelockArc).CANCELLER_ROLE()), true);
        assertEq(IGovernorTimelock(timelockArc).hasRole(roleAdminArc, IGovernorTimelock(timelockArc).ROLE_ADMIN()),     true);

        assertEq(IGovernorTimelock(timelockArc).tokenWithdrawer(), tokenWithdrawerArc);

        assertEq(IGovernorTimelock(timelockArc).MIN_DELAY(),            1 days);
        assertEq(IGovernorTimelock(timelockArc).MIN_EXECUTION_WINDOW(), 1 days);

        (uint32 defaultDelay, uint32 defaultExecutionWindow) = IGovernorTimelock(timelockArc).defaultTimelockParameters();

        assertEq(defaultDelay,           IGovernorTimelock(timelockArc).MIN_DELAY());
        assertEq(defaultExecutionWindow, IGovernorTimelock(timelockArc).MIN_EXECUTION_WINDOW());
    }

}
