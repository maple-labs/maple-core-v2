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

    function setUp() public virtual {
        // Block fixed based on subgraph query results for UpgradeAddressRegistry.
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 18421300);
    }

    /**************************************************************************************************************************************/
    /*** Deployment Helper Functions                                                                                                    ***/
    /**************************************************************************************************************************************/

    function _addWMAndPMToAllowlists() internal {
        allowLender(aqruPoolManager, aqruWithdrawalManager);
        allowLender(aqruPoolManager, aqruPoolManager);

        allowLender(cashManagementUSDCPoolManager, cashManagementUSDCWithdrawalManager);
        allowLender(cashManagementUSDCPoolManager, cashManagementUSDCPoolManager);

        allowLender(cashManagementUSDTPoolManager, cashManagementUSDTWithdrawalManager);
        allowLender(cashManagementUSDTPoolManager, cashManagementUSDTPoolManager);

        allowLender(cicadaPoolManager, cicadaWithdrawalManager);
        allowLender(cicadaPoolManager, cicadaPoolManager);

        allowLender(icebreakerPoolManager, icebreakerWithdrawalManager);
        allowLender(icebreakerPoolManager, icebreakerPoolManager);

        allowLender(laserPoolManager, laserWithdrawalManager);
        allowLender(laserPoolManager, laserPoolManager);

        allowLender(mapleDirectUSDCPoolManager, mapleDirectUSDCWithdrawalManager);
        allowLender(mapleDirectUSDCPoolManager, mapleDirectUSDCPoolManager);

        allowLender(mavenPermissionedPoolManager, mavenPermissionedWithdrawalManager);
        allowLender(mavenPermissionedPoolManager, mavenPermissionedPoolManager);

        allowLender(mavenUsdc3PoolManager, mavenUsdc3WithdrawalManager);
        allowLender(mavenUsdc3PoolManager, mavenUsdc3PoolManager);

        allowLender(mavenUsdcPoolManager, mavenUsdcWithdrawalManager);
        allowLender(mavenUsdcPoolManager, mavenUsdcPoolManager);

        allowLender(mavenWethPoolManager, mavenWethWithdrawalManager);
        allowLender(mavenWethPoolManager, mavenWethPoolManager);

        allowLender(orthogonalPoolManager, orthogonalWithdrawalManager);
        allowLender(orthogonalPoolManager, orthogonalPoolManager);
    }

    // NOTE: This is done to help facilitate lifecycle testing.
    function _addLoanManagers() internal {
        // Not needed for Aqru and cash management, its already added
        addLoanManager(mavenPermissionedPoolManager, openTermLoanManagerFactory);
        addLoanManager(mavenWethPoolManager,         openTermLoanManagerFactory);
    }

    // TODO: Need to confirm delay length
    function _addDelayToOracles() internal {
        vm.startPrank(governor);
        IGlobals(globals).setPriceOracle(usdc, usdUsdOracle, 1 days);
        IGlobals(globals).setPriceOracle(weth, ethUsdOracle, 1 days);
        IGlobals(globals).setPriceOracle(wbtc, btcUsdOracle, 1 days);
        vm.stopPrank();
    }

    function _deployAllNewContracts() internal {
        fixedTermLoanFactoryV2          = address(new FixedTermLoanFactory(globals, fixedTermLoanFactory));
        fixedTermLoanImplementationV502 = address(new FixedTermLoan());
        fixedTermLoanInitializerV500    = address(IProxyFactoryLike(fixedTermLoanFactory).migratorForPath(501, 501));

        // Upgrade contract for Globals
        globalsImplementationV3 = address(new Globals());

        // New contract for PoolDeployer
        poolDeployerV3 = address(new PoolDeployer(globals));

        // Upgrade contracts for PoolManager
        poolManagerImplementationV300 = address(new PoolManager());
        poolManagerImplementationV301 = address(new PoolManager());
        poolManagerInitializer        = address(IProxyFactoryLike(poolManagerFactory).migratorForPath(200, 200));
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

    function _deployQueueWM(address pool_) internal returns (address queueWM) {
        address deployer = makeAddr("deployer");

        vm.prank(governor);
        IGlobals(globals).setCanDeployFrom(address(queueWMFactory), deployer, true);

        vm.prank(deployer);
        queueWM = address(WithdrawalManagerQueue(
            IProxyFactoryLike(queueWMFactory).createInstance(abi.encode(address(pool_)), "SALT")
        ));
    }

    function _enableGlobalsKeys() internal {
        IGlobals globals_ = IGlobals(globals);

        vm.startPrank(governor);
        globals_.setValidInstanceOf("LOAN_FACTORY",                     fixedTermLoanFactoryV2,         true);
        globals_.setValidInstanceOf("FT_LOAN_FACTORY",                  fixedTermLoanFactoryV2,         true);
        globals_.setValidInstanceOf("POOL_PERMISSION_MANAGER",          address(poolPermissionManager), true);
        globals_.setValidInstanceOf("WITHDRAWAL_MANAGER_CYCLE_FACTORY", withdrawalManagerFactory,       true);
        globals_.setValidInstanceOf("WITHDRAWAL_MANAGER_QUEUE_FACTORY", queueWMFactory,                 true);
        globals_.setValidInstanceOf("WITHDRAWAL_MANAGER_FACTORY",       queueWMFactory,                 true);
        globals_.setValidInstanceOf("POOL_DEPLOYER",                    poolDeployerV3,                 true);
        globals_.setValidInstanceOf("QUEUE_POOL_MANAGER",               cashManagementUSDCPoolManager,  true);
        globals_.setValidInstanceOf("QUEUE_POOL_MANAGER",               cashManagementUSDTPoolManager,  true);

        globals_.setCanDeployFrom(poolManagerFactory,       poolDeployerV3, true);
        globals_.setCanDeployFrom(withdrawalManagerFactory, poolDeployerV3, true);
        globals_.setCanDeployFrom(queueWMFactory,           poolDeployerV3, true);
        vm.stopPrank();
    }

    function _setupFactories() internal {
        vm.startPrank(governor);

        // PoolManager upgrade 200 => 300
        IProxyFactoryLike(poolManagerFactory).registerImplementation(
            300,
            poolManagerImplementationV300,
            poolManagerInitializer
        );
        IProxyFactoryLike(poolManagerFactory).registerImplementation(
            301,
            poolManagerImplementationV301,
            poolManagerInitializer
        );
        IProxyFactoryLike(poolManagerFactory).setDefaultVersion(300);
        IProxyFactoryLike(poolManagerFactory).enableUpgradePath(200, 300, poolManagerMigrator);
        IProxyFactoryLike(poolManagerFactory).enableUpgradePath(201, 300, poolManagerMigrator);     // For Aqru pool
        IProxyFactoryLike(poolManagerFactory).enableUpgradePath(300, 301, poolManagerWMMigrator);  // For Cash Management pools

        IProxyFactoryLike(fixedTermLoanFactoryV2).registerImplementation(
            502,
            fixedTermLoanImplementationV502,
            fixedTermLoanInitializerV500
        );
        IProxyFactoryLike(fixedTermLoanFactoryV2).setDefaultVersion(502);

        IProxyFactoryLike(withdrawalManagerFactory).registerImplementation(
            110,
            cyclicalWMImplementation,
            cyclicalWMInitializer
        );
        IProxyFactoryLike(withdrawalManagerFactory).setDefaultVersion(110);

        IProxyFactoryLike(queueWMFactory).registerImplementation(
            100,
            queueWMImplementation,
            queueWMInitializer
        );
        IProxyFactoryLike(queueWMFactory).setDefaultVersion(100);

        vm.stopPrank();
    }

    function _upgradePoolContractsAsSecurityAdmin() internal {
        bytes memory arguments = abi.encode(poolPermissionManager);

        upgradePoolManagerAsSecurityAdmin(aqruPoolManager,               300, arguments);
        upgradePoolManagerAsSecurityAdmin(cashManagementUSDCPoolManager, 300, arguments);
        upgradePoolManagerAsSecurityAdmin(cashManagementUSDTPoolManager, 300, arguments);
        upgradePoolManagerAsSecurityAdmin(cicadaPoolManager,             300, arguments);
        upgradePoolManagerAsSecurityAdmin(icebreakerPoolManager,         300, arguments);
        upgradePoolManagerAsSecurityAdmin(laserPoolManager,              300, arguments);
        upgradePoolManagerAsSecurityAdmin(mapleDirectUSDCPoolManager,    300, arguments);
        upgradePoolManagerAsSecurityAdmin(mavenPermissionedPoolManager,  300, arguments);
        upgradePoolManagerAsSecurityAdmin(mavenUsdc3PoolManager,         300, arguments);
        upgradePoolManagerAsSecurityAdmin(mavenUsdcPoolManager,          300, arguments);
        upgradePoolManagerAsSecurityAdmin(mavenWethPoolManager,          300, arguments);
        upgradePoolManagerAsSecurityAdmin(orthogonalPoolManager,         300, arguments);
    }

    function _upgradeToQueueWM(address poolManager) internal {
        address wm = _deployQueueWM(IPoolManager(poolManager).pool());

        bytes memory arguments = abi.encode(wm);

        upgradePoolManagerAsSecurityAdmin(poolManager, 301, arguments);
    }

    function _performProtocolUpgrade() internal {

        _deployAllNewContracts();

        upgradeGlobals(globals, globalsImplementationV3);

        _enableGlobalsKeys();

        _addDelayToOracles();

        _setupFactories();

        _upgradePoolContractsAsSecurityAdmin();

        _addWMAndPMToAllowlists();

        _addLoanManagers();
    }

    /**************************************************************************************************************************************/
    /*** Assertion Helper Functions                                                                                                     ***/
    /**************************************************************************************************************************************/

    function _assertFactories() internal {
        IProxyFactoryLike poolManagerFactory = IProxyFactoryLike(poolManagerFactory);

        assertEq(poolManagerFactory.defaultVersion(),          300);
        assertEq(poolManagerFactory.implementationOf(300),     poolManagerImplementationV300);
        assertEq(poolManagerFactory.implementationOf(301),     poolManagerImplementationV301);
        assertEq(poolManagerFactory.migratorForPath(200, 300), poolManagerMigrator);
        assertEq(poolManagerFactory.migratorForPath(201, 300), poolManagerMigrator);
        assertEq(poolManagerFactory.migratorForPath(300, 301), poolManagerWMMigrator);

        IProxyFactoryLike fixedTermLoanFactoryV2 = IProxyFactoryLike(fixedTermLoanFactoryV2);

        assertEq(fixedTermLoanFactoryV2.defaultVersion(),          502);
        assertEq(fixedTermLoanFactoryV2.implementationOf(502),     fixedTermLoanImplementationV502);
        assertEq(fixedTermLoanFactoryV2.migratorForPath(502, 502), fixedTermLoanInitializerV500);

        IProxyFactoryLike withdrawalManagerFactory = IProxyFactoryLike(withdrawalManagerFactory);

        assertEq(withdrawalManagerFactory.defaultVersion(),          110);
        assertEq(withdrawalManagerFactory.migratorForPath(110, 110), cyclicalWMInitializer);
        assertEq(withdrawalManagerFactory.implementationOf(110),     cyclicalWMImplementation);

        IProxyFactoryLike queueWMFactory = IProxyFactoryLike(queueWMFactory);

        assertEq(queueWMFactory.defaultVersion(),          100);
        assertEq(queueWMFactory.migratorForPath(100, 100), queueWMInitializer);
        assertEq(queueWMFactory.implementationOf(100),     queueWMImplementation);
    }

    function _assertGlobals() internal {
        IGlobals globals_ = IGlobals(globals);

        assertTrue(globals_.isInstanceOf("LOAN_FACTORY",                     fixedTermLoanFactoryV2));
        assertTrue(globals_.isInstanceOf("FT_LOAN_FACTORY",                  fixedTermLoanFactoryV2));
        assertTrue(globals_.isInstanceOf("POOL_PERMISSION_MANAGER",          address(poolPermissionManager)));
        assertTrue(globals_.isInstanceOf("WITHDRAWAL_MANAGER_CYCLE_FACTORY", withdrawalManagerFactory));
        assertTrue(globals_.isInstanceOf("WITHDRAWAL_MANAGER_QUEUE_FACTORY", queueWMFactory));
        assertTrue(globals_.isInstanceOf("WITHDRAWAL_MANAGER_FACTORY",       queueWMFactory));
        assertTrue(globals_.isInstanceOf("POOL_DEPLOYER",                    poolDeployerV3));
        assertTrue(globals_.isInstanceOf("QUEUE_POOL_MANAGER",               cashManagementUSDCPoolManager));
        assertTrue(globals_.isInstanceOf("QUEUE_POOL_MANAGER",               cashManagementUSDTPoolManager));

        assertTrue(globals_.canDeployFrom(poolManagerFactory,       poolDeployerV3));
        assertTrue(globals_.canDeployFrom(withdrawalManagerFactory, poolDeployerV3));
        assertTrue(globals_.canDeployFrom(queueWMFactory,           poolDeployerV3));
    }

    function _assertIsLoan(address[] memory loans) internal {
        for (uint256 i; i < loans.length; ++i) {
            assertEq(IProxyFactoryLike(fixedTermLoanFactoryV2).isLoan(loans[i]), true);
        }
    }

    function _assertPermissions() internal {
        assertTrue(poolPermissionManager.lenderAllowlist(aqruPoolManager, aqruWithdrawalManager));
        assertTrue(poolPermissionManager.lenderAllowlist(aqruPoolManager, aqruPoolManager));

        assertTrue(poolPermissionManager.lenderAllowlist(cashManagementUSDCPoolManager, cashManagementUSDCWithdrawalManager));
        assertTrue(poolPermissionManager.lenderAllowlist(cashManagementUSDCPoolManager, cashManagementUSDCPoolManager));

        assertTrue(poolPermissionManager.lenderAllowlist(cashManagementUSDTPoolManager, cashManagementUSDTWithdrawalManager));
        assertTrue(poolPermissionManager.lenderAllowlist(cashManagementUSDTPoolManager, cashManagementUSDTPoolManager));

        assertTrue(poolPermissionManager.lenderAllowlist(cicadaPoolManager, cicadaWithdrawalManager));
        assertTrue(poolPermissionManager.lenderAllowlist(cicadaPoolManager, cicadaPoolManager));

        assertTrue(poolPermissionManager.lenderAllowlist(icebreakerPoolManager, icebreakerWithdrawalManager));
        assertTrue(poolPermissionManager.lenderAllowlist(icebreakerPoolManager, icebreakerPoolManager));

        assertTrue(poolPermissionManager.lenderAllowlist(laserPoolManager, laserWithdrawalManager));
        assertTrue(poolPermissionManager.lenderAllowlist(laserPoolManager, laserPoolManager));

        assertTrue(poolPermissionManager.lenderAllowlist(mapleDirectUSDCPoolManager, mapleDirectUSDCWithdrawalManager));
        assertTrue(poolPermissionManager.lenderAllowlist(mapleDirectUSDCPoolManager, mapleDirectUSDCPoolManager));

        assertTrue(poolPermissionManager.lenderAllowlist(mavenPermissionedPoolManager, mavenPermissionedWithdrawalManager));
        assertTrue(poolPermissionManager.lenderAllowlist(mavenPermissionedPoolManager, mavenPermissionedPoolManager));

        assertTrue(poolPermissionManager.lenderAllowlist(mavenUsdc3PoolManager, mavenUsdc3WithdrawalManager));
        assertTrue(poolPermissionManager.lenderAllowlist(mavenUsdc3PoolManager, mavenUsdc3PoolManager));

        assertTrue(poolPermissionManager.lenderAllowlist(mavenUsdcPoolManager, mavenUsdcWithdrawalManager));
        assertTrue(poolPermissionManager.lenderAllowlist(mavenUsdcPoolManager, mavenUsdcPoolManager));

        assertTrue(poolPermissionManager.lenderAllowlist(mavenWethPoolManager, mavenWethWithdrawalManager));
        assertTrue(poolPermissionManager.lenderAllowlist(mavenWethPoolManager, mavenWethPoolManager));

        assertTrue(poolPermissionManager.lenderAllowlist(orthogonalPoolManager, orthogonalWithdrawalManager));
        assertTrue(poolPermissionManager.lenderAllowlist(orthogonalPoolManager, orthogonalPoolManager));
    }

    function _assertPoolManagers() internal {
        assertEq(IProxiedLike(aqruPoolManager).implementation(),               poolManagerImplementationV300);
        assertEq(IProxiedLike(cashManagementUSDCPoolManager).implementation(), poolManagerImplementationV300);
        assertEq(IProxiedLike(cashManagementUSDTPoolManager).implementation(), poolManagerImplementationV300);
        assertEq(IProxiedLike(cicadaPoolManager).implementation(),             poolManagerImplementationV300);
        assertEq(IProxiedLike(icebreakerPoolManager).implementation(),         poolManagerImplementationV300);
        assertEq(IProxiedLike(laserPoolManager).implementation(),              poolManagerImplementationV300);
        assertEq(IProxiedLike(mapleDirectUSDCPoolManager).implementation(),    poolManagerImplementationV300);
        assertEq(IProxiedLike(mavenPermissionedPoolManager).implementation(),  poolManagerImplementationV300);
        assertEq(IProxiedLike(mavenUsdc3PoolManager).implementation(),         poolManagerImplementationV300);
        assertEq(IProxiedLike(mavenUsdcPoolManager).implementation(),          poolManagerImplementationV300);
        assertEq(IProxiedLike(mavenWethPoolManager).implementation(),          poolManagerImplementationV300);
        assertEq(IProxiedLike(orthogonalPoolManager).implementation(),         poolManagerImplementationV300);
    }

    function _assertCashPoolManagers() internal {
        assertEq(IProxiedLike(cashManagementUSDCPoolManager).implementation(), poolManagerImplementationV301);
        assertEq(IProxiedLike(cashManagementUSDTPoolManager).implementation(), poolManagerImplementationV301);
    }

    function _assertOracles() internal {
        ( address oracle, uint256 maxDelay ) = IGlobals(globals).priceOracleOf(usdc);

        assertEq(oracle,   usdUsdOracle);
        assertEq(maxDelay, 1 days);

        ( oracle, maxDelay ) = IGlobals(globals).priceOracleOf(weth);

        assertEq(oracle,   ethUsdOracle);
        assertEq(maxDelay, 1 days);

        ( oracle, maxDelay ) = IGlobals(globals).priceOracleOf(wbtc);

        assertEq(oracle,   btcUsdOracle);
        assertEq(maxDelay, 1 days);
    }

}
