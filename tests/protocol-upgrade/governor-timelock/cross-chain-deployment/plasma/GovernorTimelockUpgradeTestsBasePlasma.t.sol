// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IGovernorTimelock, ISyrupUSDCrossChainLike } from "../../../../../contracts/interfaces/Interfaces.sol";
import { Runner }                                     from "../../../../../contracts/Runner.sol";

import { UpgradeAddressRegistry } from "../../../UpgradeAddressRegistry.sol";

contract GovernorTimelockUpgradeTestsBasePlasma is Runner, UpgradeAddressRegistry {

    function setUp() public virtual {
        vm.createSelectFork(vm.rpcUrl("plasma"), 3177303);  // Fix Block for Testing

        deployGovernorTimelockPlasma();

        vm.startPrank(syrupUSDTDefaultAdmin);

        ISyrupUSDCrossChainLike(syrupUSDTPlasma).grantRole(ISyrupUSDCrossChainLike(syrupUSDTPlasma).DEFAULT_ADMIN_ROLE(), timelockPlasma);

        ISyrupUSDCrossChainLike(syrupUSDTPlasma).renounceRole(
            ISyrupUSDCrossChainLike(syrupUSDTPlasma).DEFAULT_ADMIN_ROLE(),
            syrupUSDTDefaultAdmin
        );

        vm.stopPrank();
    }

    function deployGovernorTimelockPlasma() internal {
        tokenWithdrawerPlasma = makeAddr("tokenWithdrawerPlasma");
        proposerPlasma        = makeAddr("proposerPlasma");
        executorPlasma        = makeAddr("executorPlasma");
        cancellerPlasma       = makeAddr("cancellerPlasma");
        roleAdminPlasma       = makeAddr("roleAdminPlasma");

        timelockPlasma = deployFromFile(
            "Contracts@25",
            "Timelock",
            abi.encode(
                tokenWithdrawerPlasma,
                proposerPlasma,
                executorPlasma,
                cancellerPlasma,
                roleAdminPlasma
            )
        );
    }

    function testFork_setUp_governorTimelockUpgradeTests_Plasma() public view {
        assertEq(IGovernorTimelock(timelockPlasma).hasRole(proposerPlasma,  IGovernorTimelock(timelockPlasma).PROPOSER_ROLE()),  true);
        assertEq(IGovernorTimelock(timelockPlasma).hasRole(executorPlasma,  IGovernorTimelock(timelockPlasma).EXECUTOR_ROLE()),  true);
        assertEq(IGovernorTimelock(timelockPlasma).hasRole(cancellerPlasma, IGovernorTimelock(timelockPlasma).CANCELLER_ROLE()), true);
        assertEq(IGovernorTimelock(timelockPlasma).hasRole(roleAdminPlasma, IGovernorTimelock(timelockPlasma).ROLE_ADMIN()),     true);

        assertEq(IGovernorTimelock(timelockPlasma).tokenWithdrawer(), tokenWithdrawerPlasma);

        assertEq(IGovernorTimelock(timelockPlasma).MIN_DELAY(),            1 days);
        assertEq(IGovernorTimelock(timelockPlasma).MIN_EXECUTION_WINDOW(), 1 days);

        ( uint32 defaultDelay, uint32 defaultExecutionWindow ) = IGovernorTimelock(timelockPlasma).defaultTimelockParameters();

        assertEq(defaultDelay,           IGovernorTimelock(timelockPlasma).MIN_DELAY());
        assertEq(defaultExecutionWindow, IGovernorTimelock(timelockPlasma).MIN_EXECUTION_WINDOW());

        assertEq(
            ISyrupUSDCrossChainLike(syrupUSDTPlasma).hasRole(
                ISyrupUSDCrossChainLike(syrupUSDTPlasma).DEFAULT_ADMIN_ROLE(),
                timelockPlasma
            ),
            true
        );

        assertEq(
            ISyrupUSDCrossChainLike(syrupUSDTPlasma).hasRole(
                ISyrupUSDCrossChainLike(syrupUSDTPlasma).DEFAULT_ADMIN_ROLE(),
                syrupUSDTDefaultAdmin
            ),
            false
        );
    }

}
