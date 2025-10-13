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
        deployGovernorTimelock();
        upgradeWithdrawalManagers();
    }

    function deployGovernorTimelock() internal {
        proposer  = makeAddr("proposer");
        executor  = operationalAdmin;
        canceller = securityAdmin;
        roleAdmin = governor;
        timelock  = deployFromFile("Contracts@25", "Timelock", abi.encode(governor, proposer, executor, canceller, roleAdmin));
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

    function upgradeWithdrawalManagers() internal {
        mapleWithdrawalManagerV200Implementation = deployFromFile("Contracts@7", "WithdrawalManagerQueue");
        mapleWithdrawalManagerV200Migrator       = deployFromFile("Contracts@7", "WithdrawalManagerQueueMigrator");
        mapleWithdrawalManagerV200Initializer    = deployFromFile("Contracts@7", "WithdrawalManagerQueueInitializer");

        vm.startPrank(governor);

        IMapleProxyFactory(withdrawalManagerQueueFactory).registerImplementation(
            200,
            mapleWithdrawalManagerV200Implementation,
            mapleWithdrawalManagerV200Initializer
        );

        IMapleProxyFactory(withdrawalManagerQueueFactory).enableUpgradePath(100, 200, mapleWithdrawalManagerV200Migrator);
        IMapleProxyFactory(withdrawalManagerQueueFactory).setDefaultVersion(200);

        vm.stopPrank();

        for (uint256 i; i < withdrawalManagerQueuesToUpgrade.length; ++i) {
            IWithdrawalManagerQueue wm = IWithdrawalManagerQueue(withdrawalManagerQueuesToUpgrade[i]);

            vm.prank(securityAdmin);
            wm.upgrade(200, "");

            assertEq(wm.implementation(), mapleWithdrawalManagerV200Implementation);
            
            assertEq(IMapleProxyFactory(withdrawalManagerQueueFactory).versionOf(wm.implementation()), 200);
        }
    }

}
