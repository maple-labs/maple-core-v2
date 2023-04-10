// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    INonTransparentProxy,
    INonTransparentProxied,
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
    PoolManager
} from "../../contracts/Contracts.sol";

import { ProtocolActions } from "../../contracts/ProtocolActions.sol";

import { AddressRegistry } from "./AddressRegistry.sol";

contract UpgradeSimulation is AddressRegistry, ProtocolActions {

    // Generic contracts
    address newGlobalsImplementation;
    address newPoolManagerImplementation;

    // Fixed term contracts
    address newFixedTermLoanImplementation;
    address newFixedTermLoanInitializer;
    address newFixedTermLoanManagerImplementation;
    address newFixedTermLoanMigrator;

    // Open term contracts
    address newOpenTermLoanManagerFactory;
    address newOpenTermLoanManagerImplementation;
    address newOpenTermLoanManagerInitializer;

    address newOpenTermLoanFactory;
    address newOpenTermLoanImplementation;
    address newOpenTermLoanInitializer;
    address newOpenTermLoanRefinancer;

    // TODO: Add assert(false) for old keys for isInstance after changes are made (ie. LOAN_MANAGER etc)
    // TODO: Check bytecode hashes for contracts, sync on which contracts are needed
    // TODO: Assert entire storage layout against all real upgrades
    // TODO: Update timestamp to current and add newest maven 11 pool and updated loan set

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 16990500);
    }

    function test_mainnet_protocol_upgrade() external {
        /********************************/
        /*** Perform protocol upgrade ***/
        /********************************/

        // 1. Deploy all the new implementations and factories
        _deployNewContracts();

        // 2. Upgrade Globals, as the new version is needed to setup all the factories accordingly
        _upgradeGlobals();

        // 3. Register the factories on globals and set the default versions.
        _setupFactories();

        // 4. Upgrade all the existing Pool and Loan Managers
        _upgradeContracts();

        // 5. Add the new OT Loan Managers to the existing Pools.
        _addLoanManagers();

        /**************************/
        /*** Perform assertions ***/
        /**************************/

        // 1. Instances are registered on the new Globals
        Globals globals_ = Globals(mapleGlobalsV2Proxy);

        // TODO: Define whole set, including falses.
        assertTrue(globals_.isInstanceOf("POOL_MANAGER_FACTORY",    poolManagerFactory));
        assertTrue(globals_.isInstanceOf("OT_LOAN_FACTORY",         newOpenTermLoanFactory));
        assertTrue(globals_.isInstanceOf("LOAN_MANAGER_FACTORY",    fixedTermLoanManagerFactory));
        assertTrue(globals_.isInstanceOf("LOAN_MANAGER_FACTORY",    newOpenTermLoanManagerFactory));
        assertTrue(globals_.isInstanceOf("FT_LOAN_MANAGER_FACTORY", fixedTermLoanManagerFactory));
        assertTrue(globals_.isInstanceOf("OT_LOAN_MANAGER_FACTORY", newOpenTermLoanManagerFactory));
        assertTrue(globals_.isInstanceOf("FT_REFINANCER",           address(fixedTermRefinancer)));
        assertTrue(globals_.isInstanceOf("OT_REFINANCER",           newOpenTermLoanRefinancer));

        // 2. Assert all factories have correct default versions and upgrade paths enabled.
        assertEq(IProxyFactoryLike(fixedTermLoanFactory).defaultVersion(),          500);
        assertEq(IProxyFactoryLike(fixedTermLoanManagerFactory).defaultVersion(),   300);
        assertEq(IProxyFactoryLike(newOpenTermLoanFactory).defaultVersion(),        100);
        assertEq(IProxyFactoryLike(newOpenTermLoanManagerFactory).defaultVersion(), 100);
        assertEq(IProxyFactoryLike(poolManagerFactory).defaultVersion(),            200);

        assertTrue(IProxyFactoryLike(fixedTermLoanFactory).upgradeEnabledForPath(400, 500));
        assertTrue(IProxyFactoryLike(fixedTermLoanManagerFactory).upgradeEnabledForPath(200, 300));
        assertTrue(IProxyFactoryLike(poolManagerFactory).upgradeEnabledForPath(100, 200));

        assertEq(IProxyFactoryLike(fixedTermLoanFactory).migratorForPath(400, 500),        newFixedTermLoanMigrator);
        assertEq(IProxyFactoryLike(fixedTermLoanManagerFactory).migratorForPath(200, 300), address(0));
        assertEq(IProxyFactoryLike(poolManagerFactory).migratorForPath(100, 200),          address(0));

        assertEq(IProxyFactoryLike(newOpenTermLoanFactory).migratorForPath(100, 100),        newOpenTermLoanInitializer);
        assertEq(IProxyFactoryLike(newOpenTermLoanManagerFactory).migratorForPath(100, 100), newOpenTermLoanManagerInitializer);

        // 3. All the Pool Managers are upgraded
        assertEq(PoolManager(mavenPermissionedPoolManager).implementation(), newPoolManagerImplementation);
        assertEq(PoolManager(mavenUsdcPoolManager).implementation(),         newPoolManagerImplementation);
        assertEq(PoolManager(mavenWethPoolManager).implementation(),         newPoolManagerImplementation);
        assertEq(PoolManager(orthogonalPoolManager).implementation(),        newPoolManagerImplementation);
        assertEq(PoolManager(icebreakerPoolManager).implementation(),        newPoolManagerImplementation);
        assertEq(PoolManager(aqruPoolManager).implementation(),              newPoolManagerImplementation);
        assertEq(PoolManager(mavenUsdc3PoolManager).implementation(),        newPoolManagerImplementation);

        // 4. All the Fixed Term Loan Managers are upgraded
        assertEq(FixedTermLoanManager(mavenPermissionedFixedTermLoanManager).implementation(), newFixedTermLoanManagerImplementation);
        assertEq(FixedTermLoanManager(mavenUsdcFixedTermLoanManager).implementation(),         newFixedTermLoanManagerImplementation);
        assertEq(FixedTermLoanManager(mavenWethFixedTermLoanManager).implementation(),         newFixedTermLoanManagerImplementation);
        assertEq(FixedTermLoanManager(orthogonalFixedTermLoanManager).implementation(),        newFixedTermLoanManagerImplementation);
        assertEq(FixedTermLoanManager(icebreakerFixedTermLoanManager).implementation(),        newFixedTermLoanManagerImplementation);
        assertEq(FixedTermLoanManager(aqruFixedTermLoanManager).implementation(),              newFixedTermLoanManagerImplementation);
        assertEq(FixedTermLoanManager(mavenUsdc3FixedTermLoanManager).implementation(),        newFixedTermLoanManagerImplementation);

        // 5. Globals is upgraded
        assertEq(globals_.implementation(), newGlobalsImplementation);

        // 5. An Open Term Loan Manager was added to each poolManager
        IProxyFactoryLike newOpenTermLoanManagerFactory_ = IProxyFactoryLike(newOpenTermLoanManagerFactory);

        assertTrue(newOpenTermLoanManagerFactory_.isInstance(PoolManager(mavenPermissionedPoolManager).loanManagerList(1)));
        assertTrue(newOpenTermLoanManagerFactory_.isInstance(PoolManager(mavenUsdcPoolManager).loanManagerList(1)));
        assertTrue(newOpenTermLoanManagerFactory_.isInstance(PoolManager(mavenWethPoolManager).loanManagerList(1)));
        assertTrue(newOpenTermLoanManagerFactory_.isInstance(PoolManager(orthogonalPoolManager).loanManagerList(1)));
        assertTrue(newOpenTermLoanManagerFactory_.isInstance(PoolManager(icebreakerPoolManager).loanManagerList(1)));
        assertTrue(newOpenTermLoanManagerFactory_.isInstance(PoolManager(aqruPoolManager).loanManagerList(1)));
        assertTrue(newOpenTermLoanManagerFactory_.isInstance(PoolManager(mavenUsdc3PoolManager).loanManagerList(1)));

        // 6. All fixed term loans were upgraded
        _assertLoans(mavenPermissionedLoans, newFixedTermLoanImplementation);
        _assertLoans(mavenUsdcLoans,         newFixedTermLoanImplementation);
        _assertLoans(mavenWethLoans,         newFixedTermLoanImplementation);
        _assertLoans(orthogonalLoans,        newFixedTermLoanImplementation);
        _assertLoans(icebreakerLoans,        newFixedTermLoanImplementation);
        _assertLoans(aqruLoans,              newFixedTermLoanImplementation);
        _assertLoans(mavenUsdc3Loans,        newFixedTermLoanImplementation);
    }

    function _addLoanManagers() internal {
        // Pool Delegate performs these actions
        // TODO: Determine if this needs to be part of upgrade or can be done after.
        addLoanManager(mavenPermissionedPoolManager, newOpenTermLoanManagerFactory);
        addLoanManager(mavenUsdcPoolManager,         newOpenTermLoanManagerFactory);
        addLoanManager(mavenWethPoolManager,         newOpenTermLoanManagerFactory);
        addLoanManager(orthogonalPoolManager,        newOpenTermLoanManagerFactory);
        addLoanManager(icebreakerPoolManager,        newOpenTermLoanManagerFactory);
        addLoanManager(aqruPoolManager,              newOpenTermLoanManagerFactory);
        addLoanManager(mavenUsdc3PoolManager,        newOpenTermLoanManagerFactory);
    }

    function _assertLoans(address[] memory loans, address implementation) internal {
        for (uint i = 0; i < loans.length; i++) {
            assertEq(FixedTermLoan(loans[i]).implementation(), implementation);
        }
    }

    function _deployNewContracts() internal {
        // Upgrade contracts for PoolManager and Globals
        newGlobalsImplementation     = address(new Globals());
        newPoolManagerImplementation = address(new PoolManager());

        // Upgrade contracts for Fixed Term Loan and Fixed Term Loan Manager
        newFixedTermLoanImplementation        = address(new FixedTermLoan());
        newFixedTermLoanInitializer           = address(new FixedTermLoanInitializer());
        newFixedTermLoanManagerImplementation = address(new FixedTermLoanManager());
        newFixedTermLoanMigrator              = address(new FixedTermLoanV5Migrator());

        // New contracts for Open Term Loan
        newOpenTermLoanManagerFactory        = address(new OpenTermLoanManagerFactory(mapleGlobalsV2Proxy));
        newOpenTermLoanManagerImplementation = address(new OpenTermLoanManager());
        newOpenTermLoanManagerInitializer    = address(new OpenTermLoanManagerInitializer());

        // New contracts for Open Term LoanManager
        newOpenTermLoanFactory        = address(new OpenTermLoanFactory(mapleGlobalsV2Proxy));
        newOpenTermLoanInitializer    = address(new OpenTermLoanInitializer());
        newOpenTermLoanImplementation = address(new OpenTermLoan());
        newOpenTermLoanRefinancer     = address(new OpenTermRefinancer());
    }

    function _setupFactories() internal {
        Globals globals_ = Globals(mapleGlobalsV2Proxy);
        vm.startPrank(governor);

        globals_.setValidInstanceOf("POOL_MANAGER_FACTORY",    poolManagerFactory,            true);
        globals_.setValidInstanceOf("OT_LOAN_FACTORY",         newOpenTermLoanFactory,        true);
        globals_.setValidInstanceOf("FT_LOAN_MANAGER_FACTORY", fixedTermLoanManagerFactory,   true);
        globals_.setValidInstanceOf("LOAN_MANAGER_FACTORY",    fixedTermLoanManagerFactory,   true);
        globals_.setValidInstanceOf("LOAN_MANAGER_FACTORY",    newOpenTermLoanManagerFactory, true);
        globals_.setValidInstanceOf("OT_LOAN_MANAGER_FACTORY", newOpenTermLoanManagerFactory, true);

        // This needs to happen after Globals is upgraded
        globals_.setValidInstanceOf("FT_REFINANCER", address(fixedTermRefinancer), true);
        globals_.setValidInstanceOf("OT_REFINANCER", newOpenTermLoanRefinancer,    true);

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
        IProxyFactoryLike(newOpenTermLoanFactory).registerImplementation(100, newOpenTermLoanImplementation, newOpenTermLoanInitializer);
        IProxyFactoryLike(newOpenTermLoanFactory).setDefaultVersion(100);

        // OTLM initial config for 100
        IProxyFactoryLike(newOpenTermLoanManagerFactory).registerImplementation(
            100,
            newOpenTermLoanManagerImplementation,
            newOpenTermLoanManagerInitializer
        );
        IProxyFactoryLike(newOpenTermLoanManagerFactory).setDefaultVersion(100);

        vm.stopPrank();
    }

    function _upgradeContracts() internal {
        // Governor atomically upgrades all Pool Managers
        upgradePoolManagerByGovernor(mavenPermissionedPoolManager, 200, new bytes(0));
        upgradePoolManagerByGovernor(mavenUsdcPoolManager,         200, new bytes(0));
        upgradePoolManagerByGovernor(mavenWethPoolManager,         200, new bytes(0));
        upgradePoolManagerByGovernor(orthogonalPoolManager,        200, new bytes(0));
        upgradePoolManagerByGovernor(icebreakerPoolManager,        200, new bytes(0));
        upgradePoolManagerByGovernor(aqruPoolManager,              200, new bytes(0));
        upgradePoolManagerByGovernor(mavenUsdc3PoolManager,        200, new bytes(0));

        // Governor atomically upgrades all Fixed Term Loan Managers
        upgradeLoanManagerByGovernor(mavenPermissionedFixedTermLoanManager, 300, new bytes(0));
        upgradeLoanManagerByGovernor(mavenUsdcFixedTermLoanManager,         300, new bytes(0));
        upgradeLoanManagerByGovernor(mavenWethFixedTermLoanManager,         300, new bytes(0));
        upgradeLoanManagerByGovernor(orthogonalFixedTermLoanManager,        300, new bytes(0));
        upgradeLoanManagerByGovernor(icebreakerFixedTermLoanManager,        300, new bytes(0));
        upgradeLoanManagerByGovernor(aqruFixedTermLoanManager,              300, new bytes(0));
        upgradeLoanManagerByGovernor(mavenUsdc3FixedTermLoanManager,        300, new bytes(0));

        // TODO: Determine if protocol is vulnerable at this stage

        // Security Admin atomically upgrades all Fixed Term Loans
        upgradeLoans(mavenPermissionedLoans, 500, new bytes(0), securityAdmin);
        upgradeLoans(mavenUsdcLoans,         500, new bytes(0), securityAdmin);
        upgradeLoans(mavenWethLoans,         500, new bytes(0), securityAdmin);
        upgradeLoans(orthogonalLoans,        500, new bytes(0), securityAdmin);
        upgradeLoans(icebreakerLoans,        500, new bytes(0), securityAdmin);
        upgradeLoans(aqruLoans,              500, new bytes(0), securityAdmin);
        upgradeLoans(mavenUsdc3Loans,        500, new bytes(0), securityAdmin);
    }

    function _upgradeGlobals() internal {
        vm.prank(governor);
        INonTransparentProxy(mapleGlobalsV2Proxy).setImplementation(newGlobalsImplementation);
    }

}
