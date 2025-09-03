// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IMapleProxyFactory, IWithdrawalManagerQueue } from "../../contracts/interfaces/Interfaces.sol";

import { Runner } from "../../contracts/Runner.sol";

import { UpgradeAddressRegistry } from "./UpgradeAddressRegistry.sol";

contract ProtocolUpgradeBase is Runner, UpgradeAddressRegistry {

    /**************************************************************************************************************************************/
    /*** Upgrade Procedure                                                                                                              ***/
    /**************************************************************************************************************************************/

    function upgradeProtocol() internal {
        upgradeGovernorTimelock();
        setupWithdrawalManager();
    }

    function upgradeGovernorTimelock() internal {
        proposer  = makeAddr("proposer");
        executor  = operationalAdmin;
        canceller = securityAdmin;
        roleAdmin = governor;
        timelock  = deployFromFile("Contracts@25", "Timelock", abi.encode(governor, proposer, executor, canceller, roleAdmin));
    }

    // TODO: Update Helper and upgrade all active Pools WM
    function setupWithdrawalManager() internal {
        mapleWithdrawalManagerV200Implementation = deployFromFile("Contracts@7", "WithdrawalManagerQueue");
        mapleWithdrawalManagerV200Migrator       = deployFromFile("Contracts@7", "WithdrawalManagerQueueMigrator");

        IWithdrawalManagerQueue withdrawalManager = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue);

        vm.startPrank(governor);

        assertEq(IMapleProxyFactory(withdrawalManagerQueueFactory).versionOf(withdrawalManager.implementation()), 100);

        IMapleProxyFactory(withdrawalManagerQueueFactory).registerImplementation(
            200,
            mapleWithdrawalManagerV200Implementation,
            address(0)
        );

        IMapleProxyFactory(withdrawalManagerQueueFactory).enableUpgradePath(100, 200, mapleWithdrawalManagerV200Migrator);
        IMapleProxyFactory(withdrawalManagerQueueFactory).setDefaultVersion(200);

        vm.stopPrank();

        assertEq(IMapleProxyFactory(withdrawalManagerQueueFactory).defaultVersion(),          200);
        assertEq(IMapleProxyFactory(withdrawalManagerQueueFactory).migratorForPath(100, 200), mapleWithdrawalManagerV200Migrator);

        vm.prank(securityAdmin);
        withdrawalManager.upgrade(200, "");

        assertEq(withdrawalManager.implementation(), mapleWithdrawalManagerV200Implementation);

        assertEq(IMapleProxyFactory(withdrawalManagerQueueFactory).versionOf(withdrawalManager.implementation()), 200);
    }

}
