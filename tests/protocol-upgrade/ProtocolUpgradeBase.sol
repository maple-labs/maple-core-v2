// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IMapleProxyFactory, IOpenTermLoan, IOpenTermLoanManager } from "../../contracts/interfaces/Interfaces.sol";

import { UpgradeAddressRegistry } from "./UpgradeAddressRegistry.sol";

import { Runner } from "../../contracts/Runner.sol";

contract ProtocolUpgradeBase is Runner, UpgradeAddressRegistry {

    /**************************************************************************************************************************************/
    /*** Upgrade Procedure                                                                                                              ***/
    /**************************************************************************************************************************************/

    // TODO: MapleCoreStrategy setup
    function upgradeProtocol() internal {
        setupLoan();
        setupLoanManager();
    }

    /**************************************************************************************************************************************/
    /*** Helper Functions                                                                                                               ***/
    /**************************************************************************************************************************************/

    function setupLoan() internal {
        // Deploy the loan contract and initializer.
        openTermLoanV202Implementation = deployFromFile("Contracts@7", "OpenTermLoan");
        openTermLoanV202Initializer    = deployFromFile("Contracts@7", "OpenTermLoanInitializer");
        openTermLoanV202Migrator       = deployFromFile("Contracts@7", "OpenTermLoanV202Migrator");

        // Configure the OTL Factory.
        vm.startPrank(governor);
        IMapleProxyFactory(openTermLoanFactory).registerImplementation(202, openTermLoanV202Implementation, openTermLoanV202Initializer);
        IMapleProxyFactory(openTermLoanFactory).enableUpgradePath(101, 202, openTermLoanV202Migrator);
        IMapleProxyFactory(openTermLoanFactory).enableUpgradePath(201, 202, address(0));
        IMapleProxyFactory(openTermLoanFactory).enableUpgradePath(200, 202, address(0));
        IMapleProxyFactory(openTermLoanFactory).setDefaultVersion(202);
        vm.stopPrank();

        // Assert factory configurations.
        assertEq(IMapleProxyFactory(openTermLoanFactory).migratorForPath(202, 202), openTermLoanV202Initializer);
        assertEq(IMapleProxyFactory(openTermLoanFactory).migratorForPath(101, 202), openTermLoanV202Migrator);
        assertEq(IMapleProxyFactory(openTermLoanFactory).migratorForPath(201, 202), address(0));
        assertEq(IMapleProxyFactory(openTermLoanFactory).migratorForPath(200, 202), address(0));
        assertEq(IMapleProxyFactory(openTermLoanFactory).defaultVersion(), 202);

        // Upgrade All Open Term Loans
        for (uint256 i; i < openTermLoans.length; i++) {
            IOpenTermLoan openTermLoan = IOpenTermLoan(openTermLoans[i]);

            vm.prank(securityAdmin);
            openTermLoan.upgrade(202, "");

            assertEq(openTermLoan.implementation(), openTermLoanV202Implementation);

            assertEq(
                IMapleProxyFactory(openTermLoanFactory).versionOf(openTermLoan.implementation())
                , 202
            );

            assertEq(openTermLoan.loanTermsAccepted(), true);
        }
    }

    function setupLoanManager() internal {
        // Deploy the open term loan manager contract and initializer.
        openTermLoanManagerV101Implementation = deployFromFile("Contracts@7", "OpenTermLoanManager");
        openTermLoanManagerV101Initializer    = deployFromFile("Contracts@7", "OpenTermLoanManagerInitializer");

        // Configure the OTLM Factory.
        vm.startPrank(governor);
        IMapleProxyFactory(openTermLoanManagerFactory).registerImplementation(
            101,
            openTermLoanManagerV101Implementation,
            openTermLoanManagerV101Initializer
        );

        IMapleProxyFactory(openTermLoanManagerFactory).enableUpgradePath(100, 101, address(0));
        IMapleProxyFactory(openTermLoanManagerFactory).setDefaultVersion(101);
        vm.stopPrank();

        // Assert factory configurations.
        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).migratorForPath(101, 101), openTermLoanManagerV101Initializer);
        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).migratorForPath(100, 101), address(0));
        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).defaultVersion(), 101);

        // Upgrade All Open Term Loan Managers
        for (uint256 i; i < openTermLoanManagers.length; i++) {
            IOpenTermLoanManager openTermLoanManager = IOpenTermLoanManager(openTermLoanManagers[i]);

            vm.prank(securityAdmin);
            openTermLoanManager.upgrade(101, "");

            assertEq(openTermLoanManager.implementation(), openTermLoanManagerV101Implementation);

            assertEq(
                IMapleProxyFactory(openTermLoanManagerFactory).versionOf(openTermLoanManager.implementation())
                , 101
            );
        }
    }

}
