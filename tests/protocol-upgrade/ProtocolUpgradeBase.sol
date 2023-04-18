// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IGlobals,
    INonTransparentProxy,
    IProxiedLike,
    IProxyFactoryLike
} from "../../contracts/interfaces/Interfaces.sol";

import {
    FixedTermLoan,
    FixedTermLoanInitializer,
    FixedTermLoanManager,
    FixedTermLoanV5Migrator,
    Globals,
    OpenTermLoan,
    OpenTermLoanFactory,
    OpenTermLoanInitializer,
    OpenTermLoanManager,
    OpenTermLoanManagerFactory,
    OpenTermLoanManagerInitializer,
    OpenTermRefinancer,
    PoolDeployer,
    PoolManager
} from "../../contracts/Contracts.sol";

import { ProtocolActions } from "../../contracts/ProtocolActions.sol";

import { AddressRegistry } from "./AddressRegistry.sol";

contract ProtocolUpgradeBase is AddressRegistry, ProtocolActions {

    // TODO: Add assert(false) for old keys for isInstance after changes are made (ie. LOAN_MANAGER etc)
    // TODO: Check bytecode hashes for contracts, sync on which contracts are needed
    // TODO: Assert entire storage layout against all real upgrades
    // TODO: Update timestamp to current and add newest maven 11 pool and updated loan set

    /**************************************************************************************************************************************/
    /*** New Contracts Storage and Setup                                                                                                ***/
    /**************************************************************************************************************************************/

    // New PoolDeployer contract.
    address newPoolDeployer;

    // New Globals and PoolManager implementations.
    address newGlobalsImplementation;
    address newPoolManagerImplementation;

    // New FixedTermLoan contracts.
    address newFixedTermLoanImplementation;
    address newFixedTermLoanInitializer;
    address newFixedTermLoanMigrator;

    // New FixedTermLoanManager contracts.
    address newFixedTermLoanManagerImplementation;

    // OpenTermLoan contracts.
    address openTermLoanFactory;
    address openTermLoanImplementation;
    address openTermLoanInitializer;
    address openTermLoanRefinancer;

    // OpenTermLoanManager contracts.
    address openTermLoanManagerFactory;
    address openTermLoanManagerImplementation;
    address openTermLoanManagerInitializer;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 16990500);
    }

    /**************************************************************************************************************************************/
    /*** Deployment Helper Functions                                                                                                    ***/
    /**************************************************************************************************************************************/

    // Step 1: Deploy all new contracts necessary for protocol upgrade.
    function _deployAllNewContracts() internal {
        newPoolDeployer = address(new PoolDeployer(mapleGlobalsV2Proxy));

        // Upgrade contracts for PoolManager and Globals
        newGlobalsImplementation     = address(new Globals());
        newPoolManagerImplementation = address(new PoolManager());

        // Upgrade contracts for Fixed Term Loan and Fixed Term Loan Manager
        newFixedTermLoanImplementation        = address(new FixedTermLoan());
        newFixedTermLoanInitializer           = address(new FixedTermLoanInitializer());
        newFixedTermLoanManagerImplementation = address(new FixedTermLoanManager());
        newFixedTermLoanMigrator              = address(new FixedTermLoanV5Migrator());

        // New contracts for Open Term Loan
        openTermLoanManagerFactory        = address(new OpenTermLoanManagerFactory(mapleGlobalsV2Proxy));
        openTermLoanManagerImplementation = address(new OpenTermLoanManager());
        openTermLoanManagerInitializer    = address(new OpenTermLoanManagerInitializer());

        // New contracts for Open Term LoanManager
        openTermLoanFactory        = address(new OpenTermLoanFactory(mapleGlobalsV2Proxy));
        openTermLoanInitializer    = address(new OpenTermLoanInitializer());
        openTermLoanImplementation = address(new OpenTermLoan());
        openTermLoanRefinancer     = address(new OpenTermRefinancer());
    }

    // Step 3. Configure globals factories, instances, and deployers.
    function _reconfigureGlobals() internal {
        IGlobals globals_ = IGlobals(mapleGlobalsV2Proxy);

        vm.startPrank(governor);

        // Remove old instance settings
        globals_.setValidInstanceOf("LIQUIDATOR",         liquidatorFactory,           false);
        globals_.setValidInstanceOf("LOAN_MANAGER",       fixedTermLoanManagerFactory, false);
        globals_.setValidInstanceOf("POOL_MANAGER",       poolManagerFactory,          false);
        globals_.setValidInstanceOf("WITHDRAWAL_MANAGER", withdrawalManagerFactory,    false);
        globals_.setValidInstanceOf("LOAN",               fixedTermLoanFactory,        false);

        globals_.setValidPoolDeployer(poolDeployer, false);

        // Apply new instance settings
        globals_.setValidInstanceOf("LIQUIDATOR_FACTORY",         liquidatorFactory,        true);
        globals_.setValidInstanceOf("POOL_MANAGER_FACTORY",       poolManagerFactory,       true);
        globals_.setValidInstanceOf("WITHDRAWAL_MANAGER_FACTORY", withdrawalManagerFactory, true);

        globals_.setValidInstanceOf("FT_LOAN_FACTORY", fixedTermLoanFactory, true);
        globals_.setValidInstanceOf("LOAN_FACTORY",    fixedTermLoanFactory, true);

        globals_.setValidInstanceOf("OT_LOAN_FACTORY", openTermLoanFactory, true);
        globals_.setValidInstanceOf("LOAN_FACTORY",    openTermLoanFactory, true);

        globals_.setValidInstanceOf("FT_LOAN_MANAGER_FACTORY", fixedTermLoanManagerFactory, true);
        globals_.setValidInstanceOf("LOAN_MANAGER_FACTORY",    fixedTermLoanManagerFactory, true);

        globals_.setValidInstanceOf("OT_LOAN_MANAGER_FACTORY", openTermLoanManagerFactory, true);
        globals_.setValidInstanceOf("LOAN_MANAGER_FACTORY",    openTermLoanManagerFactory, true);

        globals_.setValidInstanceOf("FT_REFINANCER", address(fixedTermRefinancer), true);
        globals_.setValidInstanceOf("REFINANCER",    address(fixedTermRefinancer), true);

        globals_.setValidInstanceOf("OT_REFINANCER", openTermLoanRefinancer, true);
        globals_.setValidInstanceOf("REFINANCER",    openTermLoanRefinancer, true);

        // TODO: Add FeeManager whitelist check.
        // TODO: Check if actually need canDeploy, since it was mainly to alow borrowers to deploy either of the loans, but since there is
        //       no new FT Loan Factory, we question it's usefulness. Consider new FT Factories to make proper use of all of this.

        globals_.setCanDeploy(poolManagerFactory,       newPoolDeployer, true);
        globals_.setCanDeploy(withdrawalManagerFactory, newPoolDeployer, true);

        vm.stopPrank();
    }

    // Step 4: Allowlist all new contracts and register new versions and upgrades in factories.
    function _setupFactories() internal {
        vm.startPrank(governor);

        // PoolManager upgrade 100 => 200
        IProxyFactoryLike(poolManagerFactory).registerImplementation(200, newPoolManagerImplementation, address(0));
        IProxyFactoryLike(poolManagerFactory).setDefaultVersion(200);
        IProxyFactoryLike(poolManagerFactory).enableUpgradePath(100, 200, address(0));

        IProxyFactoryLike(fixedTermLoanFactory).registerImplementation(500, newFixedTermLoanImplementation, newFixedTermLoanInitializer);
        IProxyFactoryLike(fixedTermLoanFactory).setDefaultVersion(500);
        IProxyFactoryLike(fixedTermLoanFactory).enableUpgradePath(400, 500, newFixedTermLoanMigrator);

        // FTLM upgrade 200 => 300
        IProxyFactoryLike(fixedTermLoanManagerFactory).registerImplementation(
            300,
            newFixedTermLoanManagerImplementation,
            address(0)
        );
        IProxyFactoryLike(fixedTermLoanManagerFactory).setDefaultVersion(300);
        IProxyFactoryLike(fixedTermLoanManagerFactory).enableUpgradePath(200, 300, address(0));

        // OTL initial config for 100
        IProxyFactoryLike(openTermLoanFactory).registerImplementation(100, openTermLoanImplementation, openTermLoanInitializer);
        IProxyFactoryLike(openTermLoanFactory).setDefaultVersion(100);

        // OTLM initial config for 100
        IProxyFactoryLike(openTermLoanManagerFactory).registerImplementation(
            100,
            openTermLoanManagerImplementation,
            openTermLoanManagerInitializer
        );
        IProxyFactoryLike(openTermLoanManagerFactory).setDefaultVersion(100);

        vm.stopPrank();
    }

    // Step 5: Upgrade PoolManager and FixedTermLoanManager contracts as the Governor.
    function _upgradePoolContractsAsGovernor() internal {
        // Governor atomically upgrades all Pool Managers
        upgradePoolManagerAsGovernor(mavenPermissionedPoolManager, 200, new bytes(0));
        upgradePoolManagerAsGovernor(mavenUsdcPoolManager,         200, new bytes(0));
        upgradePoolManagerAsGovernor(mavenWethPoolManager,         200, new bytes(0));
        upgradePoolManagerAsGovernor(orthogonalPoolManager,        200, new bytes(0));
        upgradePoolManagerAsGovernor(icebreakerPoolManager,        200, new bytes(0));
        upgradePoolManagerAsGovernor(aqruPoolManager,              200, new bytes(0));
        upgradePoolManagerAsGovernor(mavenUsdc3PoolManager,        200, new bytes(0));

        // Governor atomically upgrades all Fixed Term Loan Managers
        upgradeLoanManagerAsGovernor(mavenPermissionedFixedTermLoanManager, 300, new bytes(0));
        upgradeLoanManagerAsGovernor(mavenUsdcFixedTermLoanManager,         300, new bytes(0));
        upgradeLoanManagerAsGovernor(mavenWethFixedTermLoanManager,         300, new bytes(0));
        upgradeLoanManagerAsGovernor(orthogonalFixedTermLoanManager,        300, new bytes(0));
        upgradeLoanManagerAsGovernor(icebreakerFixedTermLoanManager,        300, new bytes(0));
        upgradeLoanManagerAsGovernor(aqruFixedTermLoanManager,              300, new bytes(0));
        upgradeLoanManagerAsGovernor(mavenUsdc3FixedTermLoanManager,        300, new bytes(0));
    }

    // Step 6: Upgrade PoolManager and FixedTermLoanManager contracts as the Governor.
    function _upgradeLoanContractsAsSecurityAdmin() internal {
        // TODO: Determine if protocol is vulnerable at this stage

        // Security Admin atomically upgrades all Fixed Term Loans
        upgradeLoansAsSecurityAdmin(mavenPermissionedLoans, 500, new bytes(0));
        upgradeLoansAsSecurityAdmin(mavenUsdcLoans,         500, new bytes(0));
        upgradeLoansAsSecurityAdmin(mavenWethLoans,         500, new bytes(0));
        upgradeLoansAsSecurityAdmin(orthogonalLoans,        500, new bytes(0));
        upgradeLoansAsSecurityAdmin(icebreakerLoans,        500, new bytes(0));
        upgradeLoansAsSecurityAdmin(aqruLoans,              500, new bytes(0));
        upgradeLoansAsSecurityAdmin(mavenUsdc3Loans,        500, new bytes(0));
    }

    // Full protocol upgrade
    function _performProtocolUpgrade() internal {
        // 1. Deploy all the new implementations and factories
        _deployAllNewContracts();

        // 2. Upgrade Globals, as the new version is needed to setup all the factories accordingly
        upgradeGlobals(mapleGlobalsV2Proxy, newGlobalsImplementation);

        // 3. Configure globals factories, instances, and deployers.
        _reconfigureGlobals();

        // 4. Register the factories on globals and set the default versions.
        _setupFactories();

        // 5. Upgrade all the existing Pool and Loan Managers
        _upgradePoolContractsAsGovernor();

        // 6. Upgrade all the existing Loans
        _upgradeLoanContractsAsSecurityAdmin();
    }

    /**************************************************************************************************************************************/
    /*** Post-Deployment Helper Functions                                                                                               ***/
    /**************************************************************************************************************************************/

    function _addLoanManagers() internal {
        // Pool Delegate performs these actions
        // TODO: Determine if this needs to be part of upgrade or can be done after.
        addLoanManager(mavenPermissionedPoolManager, openTermLoanManagerFactory);
        addLoanManager(mavenUsdcPoolManager,         openTermLoanManagerFactory);
        addLoanManager(mavenWethPoolManager,         openTermLoanManagerFactory);
        addLoanManager(orthogonalPoolManager,        openTermLoanManagerFactory);
        addLoanManager(icebreakerPoolManager,        openTermLoanManagerFactory);
        addLoanManager(aqruPoolManager,              openTermLoanManagerFactory);
        addLoanManager(mavenUsdc3PoolManager,        openTermLoanManagerFactory);
    }

    function _addWithdrawalManagersToAllowlists() internal {
        // TODO: Whitelist the withdrawal managers for AQRU and Maven 03 on mainnet.
        allowLender(mavenUsdc3PoolManager, mavenUsdc3WithdrawalManager);
        allowLender(aqruPoolManager,       aqruWithdrawalManager);
    }

    // TODO: Add deprecation steps.

    /**************************************************************************************************************************************/
    /*** Assertion Helper Functions                                                                                                     ***/
    /**************************************************************************************************************************************/

    function _assertLoans(address[] memory loans, address implementation) internal {
        for (uint256 i; i < loans.length; ++i) {
            assertEq(IProxiedLike(loans[i]).implementation(), implementation);
        }
    }

}
