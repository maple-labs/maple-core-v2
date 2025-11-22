// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IGovernorTimelock, ISyrupUSDCrossChainLike } from "../../../../../contracts/interfaces/Interfaces.sol";
import { Runner }                                      from "../../../../../contracts/Runner.sol";

import { UpgradeAddressRegistry } from "../../../UpgradeAddressRegistry.sol";

contract GovernorTimelockUpgradeTestsBaseBase is Runner, UpgradeAddressRegistry {

    function setUp() public virtual {
        vm.createSelectFork(vm.rpcUrl("base"), 38162707);  // Fix Block for Testing

        deployGovernorTimelock();

        vm.startPrank(syrupUSDCBaseDefaultAdmin);

        ISyrupUSDCrossChainLike(syrupUSDCBase).grantRole(ISyrupUSDCrossChainLike(syrupUSDCBase).DEFAULT_ADMIN_ROLE(), timelockBase);

        ISyrupUSDCrossChainLike(syrupUSDCBase).renounceRole(
            ISyrupUSDCrossChainLike(syrupUSDCBase).DEFAULT_ADMIN_ROLE(),
            syrupUSDCBaseDefaultAdmin
        );

        vm.stopPrank();
    }

    function deployGovernorTimelock() internal {
        tokenWithdrawerBase = makeAddr("tokenWithdrawerBase");
        proposerBase        = makeAddr("proposerBase");
        executorBase        = makeAddr("executorBase");
        cancellerBase       = makeAddr("cancellerBase");
        roleAdminBase       = makeAddr("roleAdminBase");

        timelockBase = deployFromFile(
            "Contracts@25",
            "Timelock",
            abi.encode(
                tokenWithdrawerBase,
                proposerBase,
                executorBase,
                cancellerBase,
                roleAdminBase
            )
        );
    }

    function testFork_setUp_governorTimelockUpgradeTests_Base() public view {
        assertEq(IGovernorTimelock(timelockBase).hasRole(proposerBase,  IGovernorTimelock(timelockBase).PROPOSER_ROLE()),  true);
        assertEq(IGovernorTimelock(timelockBase).hasRole(executorBase,  IGovernorTimelock(timelockBase).EXECUTOR_ROLE()),  true);
        assertEq(IGovernorTimelock(timelockBase).hasRole(cancellerBase, IGovernorTimelock(timelockBase).CANCELLER_ROLE()), true);
        assertEq(IGovernorTimelock(timelockBase).hasRole(roleAdminBase, IGovernorTimelock(timelockBase).ROLE_ADMIN()),     true);

        assertEq(IGovernorTimelock(timelockBase).tokenWithdrawer(), tokenWithdrawerBase);

        assertEq(IGovernorTimelock(timelockBase).MIN_DELAY(),            1 days);
        assertEq(IGovernorTimelock(timelockBase).MIN_EXECUTION_WINDOW(), 1 days);

        ( uint32 defaultDelay, uint32 defaultExecutionWindow ) = IGovernorTimelock(timelockBase).defaultTimelockParameters();

        assertEq(defaultDelay,           IGovernorTimelock(timelockBase).MIN_DELAY());
        assertEq(defaultExecutionWindow, IGovernorTimelock(timelockBase).MIN_EXECUTION_WINDOW());

        assertEq(
            ISyrupUSDCrossChainLike(syrupUSDCBase).hasRole(ISyrupUSDCrossChainLike(syrupUSDCBase).DEFAULT_ADMIN_ROLE(), timelockBase),
            true
        );

        assertEq(
            ISyrupUSDCrossChainLike(syrupUSDCBase).hasRole(
                ISyrupUSDCrossChainLike(syrupUSDCBase).DEFAULT_ADMIN_ROLE(),
                syrupUSDCBaseDefaultAdmin
            ),
            false
        );
    }

}
