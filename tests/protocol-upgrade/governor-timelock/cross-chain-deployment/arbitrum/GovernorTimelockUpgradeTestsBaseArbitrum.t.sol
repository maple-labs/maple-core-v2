// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IGovernorTimelock } from "../../../../../contracts/interfaces/Interfaces.sol";
import { Runner } from "../../../../../contracts/Runner.sol";

import { UpgradeAddressRegistry } from "../../../UpgradeAddressRegistry.sol";

contract GovernorTimelockUpgradeTestsBaseArbitrum is Runner, UpgradeAddressRegistry {

    function setUp() public virtual {
        vm.createSelectFork(vm.rpcUrl("arbitrum"), 509990000); // Fix Block for Testing

        deployGovernorTimelock();
    }

    function deployGovernorTimelock() internal {
        tokenWithdrawerArbitrum = makeAddr("tokenWithdrawerArbitrum");
        proposerArbitrum        = makeAddr("proposerArbitrum");
        executorArbitrum        = makeAddr("executorArbitrum");
        cancellerArbitrum       = makeAddr("cancellerArbitrum");
        roleAdminArbitrum       = makeAddr("roleAdminArbitrum");

        timelockArbitrum = deployFromFile(
            "Contracts@25",
            "Timelock",
            abi.encode(tokenWithdrawerArbitrum, proposerArbitrum, executorArbitrum, cancellerArbitrum, roleAdminArbitrum)
        );
    }

    function testFork_setUp_governorTimelockUpgradeTests_Arbitrum() public view {
        assertEq(IGovernorTimelock(timelockArbitrum).hasRole(roleAdminArbitrum, IGovernorTimelock(timelockArbitrum).ROLE_ADMIN()),   true);
        assertEq(IGovernorTimelock(timelockArbitrum).hasRole(proposerArbitrum, IGovernorTimelock(timelockArbitrum).PROPOSER_ROLE()), true);
        assertEq(IGovernorTimelock(timelockArbitrum).hasRole(executorArbitrum, IGovernorTimelock(timelockArbitrum).EXECUTOR_ROLE()), true);

        assertEq(IGovernorTimelock(timelockArbitrum).hasRole(cancellerArbitrum, IGovernorTimelock(timelockArbitrum).CANCELLER_ROLE()), true);

        assertEq(IGovernorTimelock(timelockArbitrum).tokenWithdrawer(), tokenWithdrawerArbitrum);

        assertEq(IGovernorTimelock(timelockArbitrum).MIN_DELAY(),            1 days);
        assertEq(IGovernorTimelock(timelockArbitrum).MIN_EXECUTION_WINDOW(), 1 days);

        (uint32 defaultDelay, uint32 defaultExecutionWindow) = IGovernorTimelock(timelockArbitrum).defaultTimelockParameters();

        assertEq(defaultDelay,           IGovernorTimelock(timelockArbitrum).MIN_DELAY());
        assertEq(defaultExecutionWindow, IGovernorTimelock(timelockArbitrum).MIN_EXECUTION_WINDOW());
    }

}
