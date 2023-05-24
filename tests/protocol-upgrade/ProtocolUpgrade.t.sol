// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IGlobals, IProxyFactoryLike }       from "../../contracts/interfaces/Interfaces.sol";
import { FixedTermLoanManager, PoolManager } from "../../contracts/Contracts.sol";

import { ProtocolUpgradeBase } from "./ProtocolUpgradeBase.sol";

contract ProtocolUpgradeTest is ProtocolUpgradeBase {

    function test_mainnet_upgradeProtocol() external {
        _performProtocolUpgrade();

        // Add new loan managers to all new pools for assertions
        _addLoanManagers();

        // Assert all instances and deployers are registered on the new Globals.
        IGlobals globals_ = IGlobals(mapleGlobalsProxy);

        assertTrue(!globals_.isInstanceOf("LIQUIDATOR",         liquidatorFactory));
        assertTrue(!globals_.isInstanceOf("LOAN_MANAGER",       fixedTermLoanManagerFactory));
        assertTrue(!globals_.isInstanceOf("POOL_MANAGER",       poolManagerFactory));
        assertTrue(!globals_.isInstanceOf("WITHDRAWAL_MANAGER", withdrawalManagerFactory));
        assertTrue(!globals_.isInstanceOf("LOAN",               fixedTermLoanFactory));

        vm.startPrank(fixedTermLoanManagerFactory);
        assertTrue(globals_.isPoolDeployer(mavenPermissionedPoolManager));
        assertTrue(globals_.isPoolDeployer(mavenUsdcPoolManager));
        assertTrue(globals_.isPoolDeployer(mavenWethPoolManager));
        assertTrue(globals_.isPoolDeployer(orthogonalPoolManager));
        assertTrue(globals_.isPoolDeployer(icebreakerPoolManager));
        assertTrue(globals_.isPoolDeployer(aqruPoolManager));
        assertTrue(globals_.isPoolDeployer(mavenUsdc3PoolManager));
        vm.stopPrank();

        vm.prank(poolManagerFactory);
        assertTrue(globals_.isPoolDeployer(poolDeployerV2));

        vm.prank(withdrawalManagerFactory);
        assertTrue(globals_.isPoolDeployer(poolDeployerV2));

        assertTrue(globals_.isInstanceOf("LIQUIDATOR_FACTORY",         liquidatorFactory));
        assertTrue(globals_.isInstanceOf("POOL_MANAGER_FACTORY",       poolManagerFactory));
        assertTrue(globals_.isInstanceOf("WITHDRAWAL_MANAGER_FACTORY", withdrawalManagerFactory));

        assertTrue(globals_.isInstanceOf("FT_LOAN_FACTORY", fixedTermLoanFactory));
        assertTrue(globals_.isInstanceOf("LOAN_FACTORY",    fixedTermLoanFactory));

        assertTrue(globals_.isInstanceOf("OT_LOAN_FACTORY", openTermLoanFactory));
        assertTrue(globals_.isInstanceOf("LOAN_FACTORY",    openTermLoanFactory));

        assertTrue(globals_.isInstanceOf("FT_LOAN_MANAGER_FACTORY", fixedTermLoanManagerFactory));
        assertTrue(globals_.isInstanceOf("LOAN_MANAGER_FACTORY",    fixedTermLoanManagerFactory));

        assertTrue(globals_.isInstanceOf("OT_LOAN_MANAGER_FACTORY", openTermLoanManagerFactory));
        assertTrue(globals_.isInstanceOf("LOAN_MANAGER_FACTORY",    openTermLoanManagerFactory));

        assertTrue(globals_.isInstanceOf("FT_REFINANCER", fixedTermRefinancerV2));
        assertTrue(globals_.isInstanceOf("REFINANCER",    fixedTermRefinancerV2));

        assertTrue(globals_.isInstanceOf("OT_REFINANCER", openTermRefinancerV1));
        assertTrue(globals_.isInstanceOf("REFINANCER",    openTermRefinancerV1));

        // Assert all canDeployFrom values
        assertTrue(globals_.canDeployFrom(openTermLoanManagerFactory, mavenPermissionedPoolManager));
        assertTrue(globals_.canDeployFrom(openTermLoanManagerFactory, mavenUsdcPoolManager));
        assertTrue(globals_.canDeployFrom(openTermLoanManagerFactory, mavenWethPoolManager));
        assertTrue(globals_.canDeployFrom(openTermLoanManagerFactory, orthogonalPoolManager));
        assertTrue(globals_.canDeployFrom(openTermLoanManagerFactory, icebreakerPoolManager));
        assertTrue(globals_.canDeployFrom(openTermLoanManagerFactory, aqruPoolManager));
        assertTrue(globals_.canDeployFrom(openTermLoanManagerFactory, mavenUsdc3PoolManager));

        // Assert all factories have correct default versions and upgrade paths enabled.
        assertEq(IProxyFactoryLike(fixedTermLoanFactory).defaultVersion(),        500);
        assertEq(IProxyFactoryLike(fixedTermLoanManagerFactory).defaultVersion(), 300);
        assertEq(IProxyFactoryLike(openTermLoanFactory).defaultVersion(),         100);
        assertEq(IProxyFactoryLike(openTermLoanManagerFactory).defaultVersion(),  100);
        assertEq(IProxyFactoryLike(poolManagerFactory).defaultVersion(),          200);

        assertTrue(IProxyFactoryLike(fixedTermLoanFactory).upgradeEnabledForPath(400, 500));
        assertTrue(IProxyFactoryLike(fixedTermLoanManagerFactory).upgradeEnabledForPath(200, 300));
        assertTrue(IProxyFactoryLike(poolManagerFactory).upgradeEnabledForPath(100, 200));

        assertEq(IProxyFactoryLike(fixedTermLoanFactory).migratorForPath(400, 500),        fixedTermLoanMigratorV500);
        assertEq(IProxyFactoryLike(fixedTermLoanManagerFactory).migratorForPath(200, 300), address(0));
        assertEq(IProxyFactoryLike(poolManagerFactory).migratorForPath(100, 200),          address(0));

        assertEq(IProxyFactoryLike(openTermLoanFactory).migratorForPath(100, 100),        openTermLoanInitializerV100);
        assertEq(IProxyFactoryLike(openTermLoanManagerFactory).migratorForPath(100, 100), openTermLoanManagerInitializerV100);

        // All the Pool Managers are upgraded
        assertEq(PoolManager(mavenPermissionedPoolManager).implementation(), poolManagerImplementationV200);
        assertEq(PoolManager(mavenUsdcPoolManager).implementation(),         poolManagerImplementationV200);
        assertEq(PoolManager(mavenWethPoolManager).implementation(),         poolManagerImplementationV200);
        assertEq(PoolManager(orthogonalPoolManager).implementation(),        poolManagerImplementationV200);
        assertEq(PoolManager(icebreakerPoolManager).implementation(),        poolManagerImplementationV200);
        assertEq(PoolManager(aqruPoolManager).implementation(),              poolManagerImplementationV200);
        assertEq(PoolManager(mavenUsdc3PoolManager).implementation(),        poolManagerImplementationV200);

        // All the Fixed Term Loan Managers are upgraded
        assertEq(FixedTermLoanManager(mavenPermissionedFixedTermLoanManager).implementation(), fixedTermLoanManagerImplementationV300);
        assertEq(FixedTermLoanManager(mavenUsdcFixedTermLoanManager).implementation(),         fixedTermLoanManagerImplementationV300);
        assertEq(FixedTermLoanManager(mavenWethFixedTermLoanManager).implementation(),         fixedTermLoanManagerImplementationV300);
        assertEq(FixedTermLoanManager(orthogonalFixedTermLoanManager).implementation(),        fixedTermLoanManagerImplementationV300);
        assertEq(FixedTermLoanManager(icebreakerFixedTermLoanManager).implementation(),        fixedTermLoanManagerImplementationV300);
        assertEq(FixedTermLoanManager(aqruFixedTermLoanManager).implementation(),              fixedTermLoanManagerImplementationV300);
        assertEq(FixedTermLoanManager(mavenUsdc3FixedTermLoanManager).implementation(),        fixedTermLoanManagerImplementationV300);

        // Globals is upgraded
        assertEq(globals_.implementation(), globalsImplementationV2);

        // An Open Term Loan Manager was added to each poolManager
        IProxyFactoryLike newOpenTermLoanManagerFactory_ = IProxyFactoryLike(openTermLoanManagerFactory);

        assertTrue(newOpenTermLoanManagerFactory_.isInstance(PoolManager(mavenPermissionedPoolManager).loanManagerList(1)));
        assertTrue(newOpenTermLoanManagerFactory_.isInstance(PoolManager(mavenUsdcPoolManager).loanManagerList(1)));
        assertTrue(newOpenTermLoanManagerFactory_.isInstance(PoolManager(mavenWethPoolManager).loanManagerList(1)));
        assertTrue(newOpenTermLoanManagerFactory_.isInstance(PoolManager(orthogonalPoolManager).loanManagerList(1)));
        assertTrue(newOpenTermLoanManagerFactory_.isInstance(PoolManager(icebreakerPoolManager).loanManagerList(1)));
        assertTrue(newOpenTermLoanManagerFactory_.isInstance(PoolManager(aqruPoolManager).loanManagerList(1)));
        assertTrue(newOpenTermLoanManagerFactory_.isInstance(PoolManager(mavenUsdc3PoolManager).loanManagerList(1)));

        // All fixed term loans were upgraded
        _assertLoans(mavenPermissionedLoans, fixedTermLoanImplementationV500);
        _assertLoans(mavenUsdcLoans,         fixedTermLoanImplementationV500);
        _assertLoans(mavenWethLoans,         fixedTermLoanImplementationV500);
        _assertLoans(orthogonalLoans,        fixedTermLoanImplementationV500);
        _assertLoans(icebreakerLoans,        fixedTermLoanImplementationV500);
        _assertLoans(aqruLoans,              fixedTermLoanImplementationV500);
        _assertLoans(mavenUsdc3Loans,        fixedTermLoanImplementationV500);
    }

}
