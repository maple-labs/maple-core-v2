// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IGovernorTimelock } from "../../../../../contracts/interfaces/Interfaces.sol";
import { Runner }            from "../../../../../contracts/Runner.sol";

import { UpgradeAddressRegistry } from "../../../UpgradeAddressRegistry.sol";

contract GovernorTimelockUpgradeTestsBaseMonad is Runner, UpgradeAddressRegistry {

    function setUp() public virtual {
        vm.createSelectFork(vm.rpcUrl("monad"), 80000000);  // Fix Block for Testing

        deployGovernorTimelock();
    }

    function deployGovernorTimelock() internal {
        tokenWithdrawerMonad = makeAddr("tokenWithdrawerMonad");
        proposerMonad        = makeAddr("proposerMonad");
        executorMonad        = makeAddr("executorMonad");
        cancellerMonad       = makeAddr("cancellerMonad");
        roleAdminMonad       = makeAddr("roleAdminMonad");

        timelockMonad = deployFromFile(
            "Contracts@25",
            "Timelock",
            abi.encode(
                tokenWithdrawerMonad,
                proposerMonad,
                executorMonad,
                cancellerMonad,
                roleAdminMonad
            )
        );
    }

    function testFork_setUp_governorTimelockUpgradeTests_Monad() public view {
        assertEq(IGovernorTimelock(timelockMonad).hasRole(proposerMonad,  IGovernorTimelock(timelockMonad).PROPOSER_ROLE()),  true);
        assertEq(IGovernorTimelock(timelockMonad).hasRole(executorMonad,  IGovernorTimelock(timelockMonad).EXECUTOR_ROLE()),  true);
        assertEq(IGovernorTimelock(timelockMonad).hasRole(cancellerMonad, IGovernorTimelock(timelockMonad).CANCELLER_ROLE()), true);
        assertEq(IGovernorTimelock(timelockMonad).hasRole(roleAdminMonad, IGovernorTimelock(timelockMonad).ROLE_ADMIN()),     true);

        assertEq(IGovernorTimelock(timelockMonad).tokenWithdrawer(), tokenWithdrawerMonad);

        assertEq(IGovernorTimelock(timelockMonad).MIN_DELAY(),            1 days);
        assertEq(IGovernorTimelock(timelockMonad).MIN_EXECUTION_WINDOW(), 1 days);

        ( uint32 defaultDelay, uint32 defaultExecutionWindow ) = IGovernorTimelock(timelockMonad).defaultTimelockParameters();

        assertEq(defaultDelay,           IGovernorTimelock(timelockMonad).MIN_DELAY());
        assertEq(defaultExecutionWindow, IGovernorTimelock(timelockMonad).MIN_EXECUTION_WINDOW());
    }

}
