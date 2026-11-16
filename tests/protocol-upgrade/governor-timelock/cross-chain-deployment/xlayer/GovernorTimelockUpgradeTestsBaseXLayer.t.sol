// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IGovernorTimelock } from "../../../../../contracts/interfaces/Interfaces.sol";
import { Runner } from "../../../../../contracts/Runner.sol";

import { UpgradeAddressRegistry } from "../../../UpgradeAddressRegistry.sol";

contract GovernorTimelockUpgradeTestsBaseXLayer is Runner, UpgradeAddressRegistry {

    function setUp() public virtual {
        vm.createSelectFork(vm.rpcUrl("xlayer"), 73700000); // Fix Block for Testing

        deployGovernorTimelock();
    }

    function deployGovernorTimelock() internal {
        tokenWithdrawerXLayer = makeAddr("tokenWithdrawerXLayer");
        proposerXLayer        = makeAddr("proposerXLayer");
        executorXLayer        = makeAddr("executorXLayer");
        cancellerXLayer       = makeAddr("cancellerXLayer");
        roleAdminXLayer       = makeAddr("roleAdminXLayer");

        timelockXLayer = deployFromFile(
            "Contracts@25", "Timelock", abi.encode(tokenWithdrawerXLayer, proposerXLayer, executorXLayer, cancellerXLayer, roleAdminXLayer)
        );
    }

    function testFork_setUp_governorTimelockUpgradeTests_XLayer() public view {
        assertEq(IGovernorTimelock(timelockXLayer).hasRole(proposerXLayer, IGovernorTimelock(timelockXLayer).PROPOSER_ROLE()),   true);
        assertEq(IGovernorTimelock(timelockXLayer).hasRole(executorXLayer, IGovernorTimelock(timelockXLayer).EXECUTOR_ROLE()),   true);
        assertEq(IGovernorTimelock(timelockXLayer).hasRole(cancellerXLayer, IGovernorTimelock(timelockXLayer).CANCELLER_ROLE()), true);
        assertEq(IGovernorTimelock(timelockXLayer).hasRole(roleAdminXLayer, IGovernorTimelock(timelockXLayer).ROLE_ADMIN()),     true);

        assertEq(IGovernorTimelock(timelockXLayer).tokenWithdrawer(), tokenWithdrawerXLayer);

        assertEq(IGovernorTimelock(timelockXLayer).MIN_DELAY(),            1 days);
        assertEq(IGovernorTimelock(timelockXLayer).MIN_EXECUTION_WINDOW(), 1 days);

        (uint32 defaultDelay, uint32 defaultExecutionWindow) = IGovernorTimelock(timelockXLayer).defaultTimelockParameters();

        assertEq(defaultDelay,           IGovernorTimelock(timelockXLayer).MIN_DELAY());
        assertEq(defaultExecutionWindow, IGovernorTimelock(timelockXLayer).MIN_EXECUTION_WINDOW());
    }

}
