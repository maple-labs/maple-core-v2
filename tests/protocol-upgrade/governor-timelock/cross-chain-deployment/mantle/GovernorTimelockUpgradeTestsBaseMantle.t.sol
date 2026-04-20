// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IGovernorTimelock } from "../../../../../contracts/interfaces/Interfaces.sol";
import { Runner }            from "../../../../../contracts/Runner.sol";

import { UpgradeAddressRegistry } from "../../../UpgradeAddressRegistry.sol";

contract GovernorTimelockUpgradeTestsBaseMantle is Runner, UpgradeAddressRegistry {

    function setUp() public virtual {
        vm.createSelectFork(vm.rpcUrl("mantle"), 88409789);  // Fix Block for Testing

        deployGovernorTimelock();
    }

    function deployGovernorTimelock() internal {
        tokenWithdrawerMantle = makeAddr("tokenWithdrawerMantle");
        proposerMantle        = makeAddr("proposerMantle");
        executorMantle        = makeAddr("executorMantle");
        cancellerMantle       = makeAddr("cancellerMantle");
        roleAdminMantle       = makeAddr("roleAdminMantle");

        timelockMantle = deployFromFile(
            "Contracts@25",
            "Timelock",
            abi.encode(
                tokenWithdrawerMantle,
                proposerMantle,
                executorMantle,
                cancellerMantle,
                roleAdminMantle
            )
        );
    }

    function testFork_setUp_governorTimelockUpgradeTests_Mantle() public view {
        assertEq(IGovernorTimelock(timelockMantle).hasRole(proposerMantle,  IGovernorTimelock(timelockMantle).PROPOSER_ROLE()),  true);
        assertEq(IGovernorTimelock(timelockMantle).hasRole(executorMantle,  IGovernorTimelock(timelockMantle).EXECUTOR_ROLE()),  true);
        assertEq(IGovernorTimelock(timelockMantle).hasRole(cancellerMantle, IGovernorTimelock(timelockMantle).CANCELLER_ROLE()), true);
        assertEq(IGovernorTimelock(timelockMantle).hasRole(roleAdminMantle, IGovernorTimelock(timelockMantle).ROLE_ADMIN()),     true);

        assertEq(IGovernorTimelock(timelockMantle).tokenWithdrawer(), tokenWithdrawerMantle);

        assertEq(IGovernorTimelock(timelockMantle).MIN_DELAY(),            1 days);
        assertEq(IGovernorTimelock(timelockMantle).MIN_EXECUTION_WINDOW(), 1 days);

        ( uint32 defaultDelay, uint32 defaultExecutionWindow ) = IGovernorTimelock(timelockMantle).defaultTimelockParameters();

        assertEq(defaultDelay,           IGovernorTimelock(timelockMantle).MIN_DELAY());
        assertEq(defaultExecutionWindow, IGovernorTimelock(timelockMantle).MIN_EXECUTION_WINDOW());
    }

}
