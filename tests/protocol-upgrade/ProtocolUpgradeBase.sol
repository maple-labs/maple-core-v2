// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IGlobals,
    ILoanLike,
    IProxiedLike,
    IProxyFactoryLike,
    IPoolManager,
    IPoolPermissionManager
} from "../../contracts/interfaces/Interfaces.sol";

import {
    FixedTermLoan,
    FixedTermLoanFactory,
    FixedTermLoanInitializer,
    FixedTermLoanV502Migrator,
    Globals,
    NonTransparentProxy,
    PoolDeployer,
    PoolManager,
    PoolManagerInitializer,
    PoolManagerMigrator,
    PoolManagerWMMigrator,
    PoolPermissionManager,
    PoolPermissionManagerInitializer,
    WithdrawalManagerCyclical,
    WithdrawalManagerCyclicalInitializer,
    WithdrawalManagerQueueFactory,
    WithdrawalManagerQueue,
    WithdrawalManagerQueueInitializer
} from "../../contracts/Contracts.sol";

import { ProtocolActions } from "../../contracts/ProtocolActions.sol";

import { UpgradeAddressRegistry as AddressRegistry } from "./UpgradeAddressRegistry.sol";

contract ProtocolUpgradeBase is AddressRegistry, ProtocolActions {

    PoolPermissionManager poolPermissionManager;

    /**************************************************************************************************************************************/
    /*** Upgrade Procedure                                                                                                              ***/
    /**************************************************************************************************************************************/

    function _performProtocolUpgrade() internal {
        address governor = protocol.governor;
        address globals  = protocol.globals;

        _deployAllNewContracts(governor, globals, protocol.fixedTermLoanFactory);

        upgradeGlobals(globals, globalsImplementationV3);

        _enableGlobalsSetInstance(governor, globals, fixedTermLoanFactoryV2,            true, "LOAN_FACTORY");
        _enableGlobalsSetInstance(governor, globals, fixedTermLoanFactoryV2,            true, "FT_LOAN_FACTORY");
        _enableGlobalsSetInstance(governor, globals, address(poolPermissionManager),    true, "POOL_PERMISSION_MANAGER");
        _enableGlobalsSetInstance(governor, globals, protocol.withdrawalManagerFactory, true, "WITHDRAWAL_MANAGER_CYCLE_FACTORY");
        _enableGlobalsSetInstance(governor, globals, queueWMFactory,                    true, "WITHDRAWAL_MANAGER_QUEUE_FACTORY");
        _enableGlobalsSetInstance(governor, globals, queueWMFactory,                    true, "WITHDRAWAL_MANAGER_FACTORY");
        _enableGlobalsSetInstance(governor, globals, poolDeployerV3,                    true, "POOL_DEPLOYER");

        _enableGlobalsSetCanDeploy(governor, globals, protocol.poolManagerFactory,       poolDeployerV3, true);
        _enableGlobalsSetCanDeploy(governor, globals, protocol.withdrawalManagerFactory, poolDeployerV3, true);
        _enableGlobalsSetCanDeploy(governor, globals, queueWMFactory,                    poolDeployerV3, true);

        if (protocol.assets.length > 0) {
            for (uint i = 0; i < protocol.assets.length; i++) {
                _addDelayToOracles(governor, globals, protocol.assets[i].asset, protocol.assets[i].oracle, 1 days);
            }
        }

        _setupFactories(
            governor,
            protocol.poolManagerFactory,
            protocol.fixedTermLoanFactory,
            protocol.withdrawalManagerFactory,
            queueWMFactory
        );

        for (uint i = 0; i < pools.length; i++) {
            Pool storage p = pools[i];

            _upgradePoolContractsAsSecurityAdmin(poolPermissionManager, p.poolManager, 300);

            if (p.ftLoans.length > 0) {
                _upgradeFixedTermLoansAsSecurityAdmin(p.ftLoans, 502, abi.encode(fixedTermLoanFactoryV2));
            }

            _addWMAndPMToAllowlists(p.poolManager, p.withdrawalManager);
            _addWMAndPMToAllowlists(p.poolManager, p.poolManager);

            _allowLenders(p.poolManager, p.lps);
        }
    }

    function _performPartialProtocolUpgrade() internal {
        address governor = protocol.governor;
        address globals  = protocol.globals;

        _deployAllNewContracts(governor, globals, protocol.fixedTermLoanFactory);

        upgradeGlobals(globals, globalsImplementationV3);

        _enableGlobalsSetInstance(governor, globals, fixedTermLoanFactoryV2,            true, "LOAN_FACTORY");
        _enableGlobalsSetInstance(governor, globals, fixedTermLoanFactoryV2,            true, "FT_LOAN_FACTORY");
        _enableGlobalsSetInstance(governor, globals, address(poolPermissionManager),    true, "POOL_PERMISSION_MANAGER");
        _enableGlobalsSetInstance(governor, globals, protocol.withdrawalManagerFactory, true, "WITHDRAWAL_MANAGER_CYCLE_FACTORY");
        _enableGlobalsSetInstance(governor, globals, queueWMFactory,                    true, "WITHDRAWAL_MANAGER_QUEUE_FACTORY");
        _enableGlobalsSetInstance(governor, globals, queueWMFactory,                    true, "WITHDRAWAL_MANAGER_FACTORY");
        _enableGlobalsSetInstance(governor, globals, poolDeployerV3,                    true, "POOL_DEPLOYER");

        _enableGlobalsSetCanDeploy(governor, globals, protocol.poolManagerFactory,       poolDeployerV3, true);
        _enableGlobalsSetCanDeploy(governor, globals, protocol.withdrawalManagerFactory, poolDeployerV3, true);
        _enableGlobalsSetCanDeploy(governor, globals, queueWMFactory,                    poolDeployerV3, true);

        if (protocol.assets.length > 0) {
            for (uint i = 0; i < protocol.assets.length; i++) {
                _addDelayToOracles(governor, globals, protocol.assets[i].asset, protocol.assets[i].oracle, 1 days);
            }
        }

        _setupFactories(
            governor,
            protocol.poolManagerFactory,
            protocol.fixedTermLoanFactory,
            protocol.withdrawalManagerFactory,
            queueWMFactory
        );
    }

    /**************************************************************************************************************************************/
    /*** Deployment Helper Functions                                                                                                    ***/
    /**************************************************************************************************************************************/

    function _addWMAndPMToAllowlists(address poolManager, address addrToAllow) internal {
        allowLender(poolManager, addrToAllow);
    }

    function _addDelayToOracles(address governor, address globals, address asset, address priceOracle, uint96 delay) internal {
        vm.prank(governor);
        IGlobals(globals).setPriceOracle(asset, priceOracle, delay);
    }

    function _allowLenders(address poolManager, address[] memory lenders) internal {
        for (uint256 i = 0; i < lenders.length; ++i) {
            allowLender(poolManager, lenders[i]);
        }
    }

    function _deployAllNewContracts(address governor, address globals, address fixedTermLoanFactory) internal {
        fixedTermLoanFactoryV2          = address(new FixedTermLoanFactory(globals, fixedTermLoanFactory));
        fixedTermLoanImplementationV502 = address(new FixedTermLoan());
        fixedTermLoanInitializerV500    = address(IProxyFactoryLike(fixedTermLoanFactory).migratorForPath(501, 501));
        fixedTermLoanV502Migrator       = address(new FixedTermLoanV502Migrator());

        // Upgrade contract for Globals
        globalsImplementationV3 = address(new Globals());

        // New contract for PoolDeployer
        poolDeployerV3 = address(new PoolDeployer(globals));

        // Upgrade contracts for PoolManager
        poolManagerImplementationV300 = address(new PoolManager());
        poolManagerImplementationV301 = address(new PoolManager());
        poolManagerInitializer        = address(new PoolManagerInitializer());
        poolManagerMigrator           = address(new PoolManagerMigrator());
        poolManagerWMMigrator         = address(new PoolManagerWMMigrator());

        // New contract for PoolPermissionManager
        poolPermissionManagerImplementation = address(new PoolPermissionManager());
        poolPermissionManagerInitializer    = address(new PoolPermissionManagerInitializer());

        poolPermissionManager = PoolPermissionManager(
            address(new NonTransparentProxy(governor, poolPermissionManagerInitializer))
        );

        cyclicalWMImplementation = address(new WithdrawalManagerCyclical());
        cyclicalWMInitializer    = address(new WithdrawalManagerCyclicalInitializer());

        queueWMFactory        = address(new WithdrawalManagerQueueFactory(globals));
        queueWMImplementation = address(new WithdrawalManagerQueue());
        queueWMInitializer    = address(new WithdrawalManagerQueueInitializer());

        vm.prank(governor);
        PoolPermissionManagerInitializer(address(poolPermissionManager)).initialize(
            poolPermissionManagerImplementation,
            globals
        );
    }

    function _deployNewLoan(address governor) internal {
        address newImplementation = address(new FixedTermLoan());

        vm.startPrank(governor);
        IProxyFactoryLike(fixedTermLoanFactoryV2).registerImplementation(
            503,
            newImplementation,
            fixedTermLoanInitializerV500
        );

        IProxyFactoryLike(fixedTermLoanFactoryV2).enableUpgradePath(502, 503, address(0));
        vm.stopPrank();
    }

    function _deployQueueWM(address governor, address globals, address pool_) internal returns (address queueWM) {
        address deployer = makeAddr("deployer");

        vm.prank(governor);
        IGlobals(globals).setCanDeployFrom(address(queueWMFactory), deployer, true);

        vm.prank(deployer);
        queueWM = address(WithdrawalManagerQueue(
            IProxyFactoryLike(queueWMFactory).createInstance(abi.encode(address(pool_)), "SALT")
        ));
    }

    function _enableGlobalsSetInstance(address governor, address globals, address instance, bool isInstance, bytes32 instanceKey) internal {
        IGlobals globals_ = IGlobals(globals);

        vm.prank(governor);
        globals_.setValidInstanceOf(instanceKey, instance, isInstance);
    }

    function _enableGlobalsSetCanDeploy(address governor, address globals, address factory, address deployer, bool isInstance) internal {
        IGlobals globals_ = IGlobals(globals);

        vm.prank(governor);
        globals_.setCanDeployFrom(factory, deployer, isInstance);
    }

    function _setupFactories(address governor, address pmFactory, address ftlFactory, address cyclicalWMFactory, address queueWMFactory) internal {
        vm.startPrank(governor);

        // PoolManager upgrade 200 => 300
        IProxyFactoryLike(pmFactory).registerImplementation(
            300,
            poolManagerImplementationV300,
            poolManagerInitializer
        );
        IProxyFactoryLike(pmFactory).registerImplementation(
            301,
            poolManagerImplementationV301,
            poolManagerInitializer
        );
        IProxyFactoryLike(pmFactory).setDefaultVersion(300);
        IProxyFactoryLike(pmFactory).enableUpgradePath(200, 300, poolManagerMigrator);
        IProxyFactoryLike(pmFactory).enableUpgradePath(201, 300, poolManagerMigrator);    // For Aqru pool
        IProxyFactoryLike(pmFactory).enableUpgradePath(300, 301, poolManagerWMMigrator);  // For Cash Management pools

        IProxyFactoryLike(ftlFactory).registerImplementation(
            502,
            fixedTermLoanImplementationV502,
            fixedTermLoanInitializerV500
        );
        IProxyFactoryLike(ftlFactory).enableUpgradePath(501, 502, fixedTermLoanV502Migrator);

        IProxyFactoryLike(fixedTermLoanFactoryV2).registerImplementation(
            502,
            fixedTermLoanImplementationV502,
            fixedTermLoanInitializerV500
        );
        IProxyFactoryLike(fixedTermLoanFactoryV2).setDefaultVersion(502);

        IProxyFactoryLike(cyclicalWMFactory).registerImplementation(
            110,
            cyclicalWMImplementation,
            cyclicalWMInitializer
        );
        IProxyFactoryLike(cyclicalWMFactory).setDefaultVersion(110);

        IProxyFactoryLike(queueWMFactory).registerImplementation(
            100,
            queueWMImplementation,
            queueWMInitializer
        );
        IProxyFactoryLike(queueWMFactory).setDefaultVersion(100);

        vm.stopPrank();
    }

    function _upgradePoolContractsAsSecurityAdmin(PoolPermissionManager poolPermissionManager_, address poolManager, uint256 version) internal {
        bytes memory arguments = abi.encode(poolPermissionManager_);

        upgradePoolManagerAsSecurityAdmin(poolManager, version, arguments);
    }

    function _upgradeFixedTermLoansAsSecurityAdmin(address[] memory loans, uint256 version, bytes memory arguments) internal {
        upgradeLoansAsSecurityAdmin(loans, version, arguments);
    }

    function _upgradeToQueueWM(address governor, address globals, address poolManager) internal {
        _enableGlobalsSetInstance(governor, globals, poolManager, true, "QUEUE_POOL_MANAGER");

        address wm = _deployQueueWM(governor, globals, IPoolManager(poolManager).pool());

        bytes memory arguments = abi.encode(wm);

        upgradePoolManagerAsSecurityAdmin(poolManager, 301, arguments);
    }

    /**************************************************************************************************************************************/
    /*** Assertion Helper Functions                                                                                                     ***/
    /**************************************************************************************************************************************/

    function _assertAllowedLenders() internal {
        for (uint i = 0; i < pools.length; i++) {
            Pool storage pool = pools[i];

            _assertLendersPermission(pool.poolManager, pool.lps);
        }
    }

    function _assertFactories(address pmFactory, address ftlFactory, address cyclicalWMFactory, address queueWMFactory_) internal {
        IProxyFactoryLike poolManagerFactory = IProxyFactoryLike(pmFactory);

        assertEq(poolManagerFactory.defaultVersion(),          300);
        assertEq(poolManagerFactory.implementationOf(300),     poolManagerImplementationV300);
        assertEq(poolManagerFactory.implementationOf(301),     poolManagerImplementationV301);
        assertEq(poolManagerFactory.migratorForPath(200, 300), poolManagerMigrator);
        assertEq(poolManagerFactory.migratorForPath(201, 300), poolManagerMigrator);
        assertEq(poolManagerFactory.migratorForPath(300, 301), poolManagerWMMigrator);

        IProxyFactoryLike fixedTermLoanFactory = IProxyFactoryLike(ftlFactory);

        assertEq(fixedTermLoanFactory.defaultVersion(),          501);
        assertEq(fixedTermLoanFactory.implementationOf(502),     fixedTermLoanImplementationV502);
        assertEq(fixedTermLoanFactory.migratorForPath(501, 502), fixedTermLoanV502Migrator);

        IProxyFactoryLike fixedTermLoanFactoryV2 = IProxyFactoryLike(fixedTermLoanFactoryV2);

        assertEq(fixedTermLoanFactoryV2.defaultVersion(),          502);
        assertEq(fixedTermLoanFactoryV2.implementationOf(502),     fixedTermLoanImplementationV502);
        assertEq(fixedTermLoanFactoryV2.migratorForPath(502, 502), fixedTermLoanInitializerV500);

        IProxyFactoryLike withdrawalManagerFactory = IProxyFactoryLike(cyclicalWMFactory);

        assertEq(withdrawalManagerFactory.defaultVersion(),          110);
        assertEq(withdrawalManagerFactory.migratorForPath(110, 110), cyclicalWMInitializer);
        assertEq(withdrawalManagerFactory.implementationOf(110),     cyclicalWMImplementation);

        IProxyFactoryLike queueWMFactory = IProxyFactoryLike(queueWMFactory_);

        assertEq(queueWMFactory.defaultVersion(),          100);
        assertEq(queueWMFactory.migratorForPath(100, 100), queueWMInitializer);
        assertEq(queueWMFactory.implementationOf(100),     queueWMImplementation);
    }

    function _assertGlobals() internal {
        _assertGlobalsIsInstanceOf(protocol.globals, fixedTermLoanFactoryV2,            "LOAN_FACTORY");
        _assertGlobalsIsInstanceOf(protocol.globals, fixedTermLoanFactoryV2,            "FT_LOAN_FACTORY");
        _assertGlobalsIsInstanceOf(protocol.globals, address(poolPermissionManager),    "POOL_PERMISSION_MANAGER");
        _assertGlobalsIsInstanceOf(protocol.globals, protocol.withdrawalManagerFactory, "WITHDRAWAL_MANAGER_CYCLE_FACTORY");
        _assertGlobalsIsInstanceOf(protocol.globals, queueWMFactory,                    "WITHDRAWAL_MANAGER_QUEUE_FACTORY");
        _assertGlobalsIsInstanceOf(protocol.globals, queueWMFactory,                    "WITHDRAWAL_MANAGER_FACTORY");
        _assertGlobalsIsInstanceOf(protocol.globals, poolDeployerV3,                    "POOL_DEPLOYER");

        _assertGlobalsCanDeployFrom(protocol.globals, protocol.poolManagerFactory,       poolDeployerV3);
        _assertGlobalsCanDeployFrom(protocol.globals, protocol.withdrawalManagerFactory, poolDeployerV3);
        _assertGlobalsCanDeployFrom(protocol.globals, queueWMFactory,                    poolDeployerV3);
    }

    function _assertGlobalsIsInstanceOf(address globals, address instance, bytes32 instanceKey) internal {
        IGlobals globals_ = IGlobals(globals);

        assertTrue(globals_.isInstanceOf(instanceKey, instance));
    }

    function _assertGlobalsCanDeployFrom(address globals, address factory, address poolDeployer) internal {
        IGlobals globals_ = IGlobals(globals);

        assertTrue(globals_.canDeployFrom(factory, poolDeployer));
    }

    function _assertIsLoan(address[] memory loans) internal {
        for (uint256 i; i < loans.length; ++i) {
            assertEq(ILoanLike(loans[i]).factory(), fixedTermLoanFactoryV2);
            assertEq(IProxyFactoryLike(fixedTermLoanFactoryV2).isLoan(loans[i]), true);
        }
    }

    function _assertFTLs() internal {
         for (uint i = 0; i < pools.length; i++) {
            Pool storage pool = pools[i];

            if (pool.ftLoans.length > 0) _assertIsLoan(pool.ftLoans);
        }
    }

    function _assertLoanVersion(uint256 version) internal {

        for (uint i = 0; i < pools.length; i++) {
            Pool storage pool = pools[i];

            for (uint256 j; j < pool.ftLoans.length; ++j) {
                address expectedImplementation = IProxyFactoryLike(fixedTermLoanFactoryV2).implementationOf(version);
                assertEq(ILoanLike(pool.ftLoans[j]).implementation(), expectedImplementation);
            }
        }
    }

    function _assertLendersPermission(address poolManager, address[] memory lenders) internal {
        for (uint256 i = 0; i < lenders.length; i++) {
            assertTrue(poolPermissionManager.lenderAllowlist(poolManager, lenders[i]));
        }
    }

    function _assertPoolManager(address poolManager, address implementation) internal {
        assertEq(IProxiedLike(poolManager).implementation(), implementation);
    }

    function _assertPoolManagers() internal {
        for (uint i = 0; i < pools.length; i++) {
            Pool storage pool = pools[i];

            _assertPoolManager(pool.poolManager, poolManagerImplementationV300);
        }
    }

    function _assertPermission(PoolPermissionManager poolPermissionManager_, address poolManager, address addrWithPermission) internal {
        assertTrue(poolPermissionManager_.lenderAllowlist(poolManager, addrWithPermission));
    }

    function  _assertPermissions() internal {
        for (uint i = 0; i < pools.length; i++) {
            Pool storage pool = pools[i];

            _assertPermission(poolPermissionManager, pool.poolManager, pool.poolManager);
            _assertPermission(poolPermissionManager, pool.poolManager, pool.withdrawalManager);
        }
    }

    function _assertQueuePoolManager(address cashMgtPoolManager_) internal {
        _assertGlobalsIsInstanceOf(protocol.globals, cashMgtPoolManager_,  "QUEUE_POOL_MANAGER");
        assertEq(IProxiedLike(cashMgtPoolManager_).implementation(), poolManagerImplementationV301);
    }

}
