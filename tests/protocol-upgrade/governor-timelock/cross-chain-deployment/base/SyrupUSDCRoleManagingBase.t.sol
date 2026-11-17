// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IGovernorTimelock, ISyrupUSDCrossChainLike } from "../../../../../contracts/interfaces/Interfaces.sol";

import { GovernorTimelockUpgradeTestsBaseBase } from "./GovernorTimelockUpgradeTestsBaseBase.t.sol";

contract SyrupUSDCRoleManagingTests is GovernorTimelockUpgradeTestsBaseBase {

    address syrupUSDCMinter = 0xA36955b2Bc12Aee77FF7519482D16C7B86DBe42a;
    address syrupUSDCBurner = 0xA36955b2Bc12Aee77FF7519482D16C7B86DBe42a;

    function testFork_roleUpdates_governorTimelockIsAbleToGrantAndRevokeRoles_Base() public {
        address newSyrupUSDCMinter = makeAddr("newSyrupUSDCMinter");
        address newSyrupUSDCBurner = makeAddr("newSyrupUSDCBurner");

        address[] memory targets = new address[](4);
        bytes[] memory   data    = new bytes[](4);

        targets[0] = address(syrupUSDCBase);
        targets[1] = address(syrupUSDCBase);
        targets[2] = address(syrupUSDCBase);
        targets[3] = address(syrupUSDCBase);

        data[0] = abi.encodeWithSelector(
            ISyrupUSDCrossChainLike(syrupUSDCBase).revokeRole.selector,
            ISyrupUSDCrossChainLike(syrupUSDCBase).MINTER_ROLE(),
            syrupUSDCMinter
        );

        data[1] = abi.encodeWithSelector(
            ISyrupUSDCrossChainLike(syrupUSDCBase).revokeRole.selector,
            ISyrupUSDCrossChainLike(syrupUSDCBase).BURNER_ROLE(),
            syrupUSDCBurner
        );

        data[2] = abi.encodeWithSelector(
            ISyrupUSDCrossChainLike(syrupUSDCBase).grantRole.selector,
            ISyrupUSDCrossChainLike(syrupUSDCBase).MINTER_ROLE(),
            newSyrupUSDCMinter
        );

        data[3] = abi.encodeWithSelector(
            ISyrupUSDCrossChainLike(syrupUSDCBase).grantRole.selector,
            ISyrupUSDCrossChainLike(syrupUSDCBase).BURNER_ROLE(),
            newSyrupUSDCBurner
        );

        vm.prank(proposerBase);
        IGovernorTimelock(timelockBase).scheduleProposals(targets, data);

        (,,, uint256 delayedUntil,) = IGovernorTimelock(timelockBase).proposals(IGovernorTimelock(timelockBase).latestProposalId());

        assertTrue(ISyrupUSDCrossChainLike(syrupUSDCBase).hasRole(ISyrupUSDCrossChainLike(syrupUSDCBase).MINTER_ROLE(), syrupUSDCMinter));

        assertTrue(ISyrupUSDCrossChainLike(syrupUSDCBase).hasRole(ISyrupUSDCrossChainLike(syrupUSDCBase).BURNER_ROLE(), syrupUSDCBurner));

        assertFalse(
            ISyrupUSDCrossChainLike(syrupUSDCBase).hasRole(ISyrupUSDCrossChainLike(syrupUSDCBase).MINTER_ROLE(), newSyrupUSDCMinter)
        );

        assertFalse(
            ISyrupUSDCrossChainLike(syrupUSDCBase).hasRole(ISyrupUSDCrossChainLike(syrupUSDCBase).BURNER_ROLE(), newSyrupUSDCBurner)
        );

        vm.warp(delayedUntil);

        uint256[] memory proposalsToExecute = new uint256[](4);
        proposalsToExecute[0]               = 1;
        proposalsToExecute[1]               = 2;
        proposalsToExecute[2]               = 3;
        proposalsToExecute[3]               = 4;

        vm.prank(executorBase);
        IGovernorTimelock(timelockBase).executeProposals(proposalsToExecute, targets, data);

        assertFalse(ISyrupUSDCrossChainLike(syrupUSDCBase).hasRole(ISyrupUSDCrossChainLike(syrupUSDCBase).MINTER_ROLE(), syrupUSDCMinter));

        assertFalse(ISyrupUSDCrossChainLike(syrupUSDCBase).hasRole(ISyrupUSDCrossChainLike(syrupUSDCBase).BURNER_ROLE(), syrupUSDCBurner));

        assertTrue(ISyrupUSDCrossChainLike(syrupUSDCBase).hasRole(ISyrupUSDCrossChainLike(syrupUSDCBase).MINTER_ROLE(), newSyrupUSDCMinter));

        assertTrue(ISyrupUSDCrossChainLike(syrupUSDCBase).hasRole(ISyrupUSDCrossChainLike(syrupUSDCBase).BURNER_ROLE(), newSyrupUSDCBurner));
    }

}
