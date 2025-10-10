// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IGovernorTimelock, ISyrupUSDTPlasmaLike } from "../../../../contracts/interfaces/Interfaces.sol";

import { ProtocolUpgradeBase } from "../../ProtocolUpgradeBase.t.sol";

contract GovernorTimelockUpgradeTestsBasePlasma is ProtocolUpgradeBase {

    // TODO: Look at best way to manage multi-chain RPCs
    function setUp() public virtual {
        vm.createSelectFork("https://plasma.gateway.tenderly.co", 3177303);  // Fix Block for Testing

        deployGovernorTimelockPlasma();

        vm.startPrank(syrupUSDTDefaultAdmin);

        ISyrupUSDTPlasmaLike(syrupUSDTPlasma).grantRole(ISyrupUSDTPlasmaLike(syrupUSDTPlasma).DEFAULT_ADMIN_ROLE(), timelockPlasma);

        ISyrupUSDTPlasmaLike(syrupUSDTPlasma).renounceRole(
            ISyrupUSDTPlasmaLike(syrupUSDTPlasma).DEFAULT_ADMIN_ROLE(),
            syrupUSDTDefaultAdmin
        );

        vm.stopPrank();
    }

    function testFork_setUp_governorTimelockUpgradeTestsPlasma() public {
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
            ISyrupUSDTPlasmaLike(syrupUSDTPlasma).hasRole(ISyrupUSDTPlasmaLike(syrupUSDTPlasma).DEFAULT_ADMIN_ROLE(), timelockPlasma),
            true
        );

        assertEq(
            ISyrupUSDTPlasmaLike(syrupUSDTPlasma).hasRole(
                ISyrupUSDTPlasmaLike(syrupUSDTPlasma).DEFAULT_ADMIN_ROLE(),
                syrupUSDTDefaultAdmin
            ),
            false
        );
    }

}
