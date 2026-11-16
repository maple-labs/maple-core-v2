// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IGovernorTimelock, ISyrupUSDCrossChainLike } from "../../../../../contracts/interfaces/Interfaces.sol";

import { GovernorTimelockUpgradeTestsBasePlasma } from "./GovernorTimelockUpgradeTestsBasePlasma.t.sol";

contract SyrupUSDTRoleManagingTests is GovernorTimelockUpgradeTestsBasePlasma {

    address syrupUSDTMinter = 0x1d952d2f6eE86Ef4940Fa648aA7477c8fF175F09;
    address syrupUSDTBurner = 0x1d952d2f6eE86Ef4940Fa648aA7477c8fF175F09;

    function testFork_roleUpdates_governorTimelockIsAbleToGrantAndRevokeRoles_Plasma() public {
        address newSyrupUSDTMinter = makeAddr("newSyrupUSDTMinter");
        address newSyrupUSDTBurner = makeAddr("newSyrupUSDTBurner");

        address[] memory targets = new address[](4);
        bytes[] memory   data    = new bytes[](4);

        targets[0] = address(syrupUSDTPlasma);
        targets[1] = address(syrupUSDTPlasma);
        targets[2] = address(syrupUSDTPlasma);
        targets[3] = address(syrupUSDTPlasma);

        data[0] = abi.encodeWithSelector(
            ISyrupUSDCrossChainLike(syrupUSDTPlasma).revokeRole.selector,
            ISyrupUSDCrossChainLike(syrupUSDTPlasma).MINTER_ROLE(),
            syrupUSDTMinter
        );

        data[1] = abi.encodeWithSelector(
            ISyrupUSDCrossChainLike(syrupUSDTPlasma).revokeRole.selector,
            ISyrupUSDCrossChainLike(syrupUSDTPlasma).BURNER_ROLE(),
            syrupUSDTBurner
        );

        data[2] = abi.encodeWithSelector(
            ISyrupUSDCrossChainLike(syrupUSDTPlasma).grantRole.selector,
            ISyrupUSDCrossChainLike(syrupUSDTPlasma).MINTER_ROLE(),
            newSyrupUSDTMinter
        );

        data[3] = abi.encodeWithSelector(
            ISyrupUSDCrossChainLike(syrupUSDTPlasma).grantRole.selector,
            ISyrupUSDCrossChainLike(syrupUSDTPlasma).BURNER_ROLE(),
            newSyrupUSDTBurner
        );

        vm.prank(proposerPlasma);
        IGovernorTimelock(timelockPlasma).scheduleProposals(targets, data);

        (,,, uint256 delayedUntil,) = IGovernorTimelock(timelockPlasma).proposals(IGovernorTimelock(timelockPlasma).latestProposalId());

        assertTrue(
            ISyrupUSDCrossChainLike(syrupUSDTPlasma).hasRole(ISyrupUSDCrossChainLike(syrupUSDTPlasma).MINTER_ROLE(), syrupUSDTMinter)
        );

        assertTrue(
            ISyrupUSDCrossChainLike(syrupUSDTPlasma).hasRole(ISyrupUSDCrossChainLike(syrupUSDTPlasma).BURNER_ROLE(), syrupUSDTBurner)
        );

        assertFalse(
            ISyrupUSDCrossChainLike(syrupUSDTPlasma).hasRole(ISyrupUSDCrossChainLike(syrupUSDTPlasma).MINTER_ROLE(), newSyrupUSDTMinter)
        );

        assertFalse(
            ISyrupUSDCrossChainLike(syrupUSDTPlasma).hasRole(ISyrupUSDCrossChainLike(syrupUSDTPlasma).BURNER_ROLE(), newSyrupUSDTBurner)
        );

        vm.warp(delayedUntil);

        uint256[] memory proposalsToExecute = new uint256[](4);
        proposalsToExecute[0]               = 1;
        proposalsToExecute[1]               = 2;
        proposalsToExecute[2]               = 3;
        proposalsToExecute[3]               = 4;

        vm.prank(executorPlasma);
        IGovernorTimelock(timelockPlasma).executeProposals(proposalsToExecute, targets, data);

        assertFalse(
            ISyrupUSDCrossChainLike(syrupUSDTPlasma).hasRole(ISyrupUSDCrossChainLike(syrupUSDTPlasma).MINTER_ROLE(), syrupUSDTMinter)
        );

        assertFalse(
            ISyrupUSDCrossChainLike(syrupUSDTPlasma).hasRole(ISyrupUSDCrossChainLike(syrupUSDTPlasma).BURNER_ROLE(), syrupUSDTBurner)
        );

        assertTrue(
            ISyrupUSDCrossChainLike(syrupUSDTPlasma).hasRole(ISyrupUSDCrossChainLike(syrupUSDTPlasma).MINTER_ROLE(), newSyrupUSDTMinter)
        );

        assertTrue(
            ISyrupUSDCrossChainLike(syrupUSDTPlasma).hasRole(ISyrupUSDCrossChainLike(syrupUSDTPlasma).BURNER_ROLE(), newSyrupUSDTBurner)
        );
    }

}
