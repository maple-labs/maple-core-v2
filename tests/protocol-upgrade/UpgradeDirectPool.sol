// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IGlobals,
    IPool,
    IPoolManager,
    IProxyFactoryLike,
    IWithdrawalManagerCyclical
} from "../../contracts/interfaces/Interfaces.sol";

import { AddressRegistry, console2 as console } from "../../contracts/Contracts.sol";
import { MaplePoolManager as PoolManager }      from "../../modules/pool/contracts/MaplePoolManager.sol";

import { ProtocolUpgradeBase } from "./ProtocolUpgradeBase.sol";

contract UpgradeDirectPool is ProtocolUpgradeBase, AddressRegistry {

    address mapleDirectUSDCWithdrawalManagerQueue;

    address pendingLp = 0x6D7F31cDbE68e947fAFaCad005f6495eDA04cB12;

    uint256 pendingShares = 1066254803425;

    uint256 windowStart = 1704895691;

    function setUp() external {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));
    }

    function test_directUpgrade() external {
        // Set PM as valid queue pool manager.
        vm.prank(operationalAdmin);
        IGlobals(globals).setValidInstanceOf("QUEUE_POOL_MANAGER", mapleDirectUSDCPoolManager, true);

        // Enable operational admin to deploy a new Q-WM instance.
        vm.prank(operationalAdmin);
        IGlobals(globals).setCanDeployFrom(address(queueWMFactory), operationalAdmin, true);

        // Deploy a new Q-WM.
        vm.prank(operationalAdmin);
        mapleDirectUSDCWithdrawalManagerQueue = IProxyFactoryLike(queueWMFactory).createInstance(
            abi.encode(mapleDirectUSDCPool),
            bytes32(bytes20(mapleDirectUSDCPool))
        );

        // Redeem pending withdrawal request.
        vm.warp(windowStart);
        vm.prank(pendingLp);
        IPool(mapleDirectUSDCPool).redeem(pendingShares, pendingLp, pendingLp);

        // Pause PM.
        vm.startPrank(securityAdmin);
        IGlobals(globals).setContractPause(mapleDirectUSDCPoolManager, true);
        IGlobals(globals).setFunctionUnpause(mapleDirectUSDCPoolManager, PoolManager.migrate.selector,           true);
        IGlobals(globals).setFunctionUnpause(mapleDirectUSDCPoolManager, PoolManager.setImplementation.selector, true);
        IGlobals(globals).setFunctionUnpause(mapleDirectUSDCPoolManager, PoolManager.upgrade.selector,           true);
        vm.stopPrank();

        // Upgrade PM.
        vm.prank(securityAdmin);
        IPoolManager(mapleDirectUSDCPoolManager).upgrade(301, abi.encode(mapleDirectUSDCWithdrawalManagerQueue));

        // Unpause PM.
        vm.prank(securityAdmin);
        IGlobals(globals).setContractPause(mapleDirectUSDCPoolManager, false);

        // Disable operational admin from deploying.
        vm.prank(operationalAdmin);
        IGlobals(globals).setCanDeployFrom(address(queueWMFactory), operationalAdmin, false);
    }

}
