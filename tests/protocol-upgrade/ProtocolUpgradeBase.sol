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
    PoolPermissionManager,
    PoolPermissionManagerInitializer
} from "../../contracts/Contracts.sol";

import { ProtocolActions } from "../../contracts/ProtocolActions.sol";

import { UpgradeAddressRegistry as AddressRegistry } from "./UpgradeAddressRegistry.sol";

contract ProtocolUpgradeBase is AddressRegistry, ProtocolActions {

    PoolPermissionManager poolPermissionManager;

    function setUp() public virtual {
        // Block fixed based on subgraph query results for UpgradeAddressRegistry.
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 18078136);
    }

    /**************************************************************************************************************************************/
    /*** Deployment Helper Functions                                                                                                    ***/
    /**************************************************************************************************************************************/

    // TODO: Need to add both WMs to deploy and configure
    function _deployAllNewContracts() internal {
        fixedTermLoanFactoryV502        = address(new FixedTermLoanFactory(globals, fixedTermLoanFactory));
        fixedTermLoanImplementationV502 = address(new FixedTermLoan());
        fixedTermLoanInitializerV500    = address(IProxyFactoryLike(fixedTermLoanFactory).migratorForPath(501, 501));

        // Upgrade contract for Globals
        globalsImplementationV3 = address(new Globals());

        // New contract for PoolDeployer
        poolDeployerV3 = address(new PoolDeployer(globals));

        // Upgrade contracts for PoolManager
        poolManagerImplementationV300 = address(new PoolManager());
        poolManagerInitializer        = address(IProxyFactoryLike(poolManagerFactory).migratorForPath(200, 200));
        poolManagerMigrator           = address(new PoolManagerMigrator());

        // New contract for PoolPermissionManager
        poolPermissionManagerImplementation = address(new PoolPermissionManager());
        poolPermissionManagerInitializer    = address(new PoolPermissionManagerInitializer());

        poolPermissionManager = PoolPermissionManager(
            address(new NonTransparentProxy(governor, poolPermissionManagerInitializer))
        );

        vm.prank(governor);
        PoolPermissionManagerInitializer(address(poolPermissionManager)).initialize(
            poolPermissionManagerImplementation,
            globals
        );
    }

    function _enableGlobalsKeys() internal {
        IGlobals globals_ = IGlobals(globals);

        vm.startPrank(governor);
        globals_.setValidInstanceOf("LOAN_FACTORY",            fixedTermLoanFactoryV502,       true);
        globals_.setValidInstanceOf("FT_LOAN_FACTORY",         fixedTermLoanFactoryV502,       true);
        globals_.setValidInstanceOf("POOL_PERMISSION_MANAGER", address(poolPermissionManager), true);

        globals_.setCanDeployFrom(poolManagerFactory,       poolDeployerV3, true);
        globals_.setCanDeployFrom(withdrawalManagerFactory, poolDeployerV3, true);
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
        IProxyFactoryLike(poolManagerFactory).setDefaultVersion(300);
        IProxyFactoryLike(poolManagerFactory).enableUpgradePath(200, 300, poolManagerMigrator);
        IProxyFactoryLike(poolManagerFactory).enableUpgradePath(201, 300, poolManagerMigrator);  // For Aqru pool

        IProxyFactoryLike(fixedTermLoanFactoryV502).registerImplementation(
            502,
            fixedTermLoanImplementationV502,
            fixedTermLoanInitializerV500
        );
        IProxyFactoryLike(fixedTermLoanFactoryV502).setDefaultVersion(502);

        vm.stopPrank();
    }

    function _upgradePoolContractsAsSecurityAdmin() internal {
        bytes memory arguments = abi.encode(poolPermissionManager);

        upgradePoolManagerAsSecurityAdmin(cashManagementUSDCPoolManager, 300, arguments);
        upgradePoolManagerAsSecurityAdmin(mavenPermissionedPoolManager,  300, arguments);
        upgradePoolManagerAsSecurityAdmin(mavenWethPoolManager,          300, arguments);
        upgradePoolManagerAsSecurityAdmin(aqruPoolManager,               300, arguments);
    }

    function _addWithdrawalManagersToAllowlists() internal {
        allowLender(cashManagementUSDCPoolManager, cashManagementUSDCWithdrawalManager);
        allowLender(mavenPermissionedPoolManager,  mavenPermissionedWithdrawalManager);
        allowLender(mavenWethPoolManager,          mavenWethWithdrawalManager);
        allowLender(aqruPoolManager,               aqruWithdrawalManager);
    }

    // NOTE: This is done to help facilitate lifecycle testing.
    function _addLoanManagers() internal {
        // Not needed for Aqru and cash management, its already added
        addLoanManager(mavenPermissionedPoolManager, openTermLoanManagerFactory);
        addLoanManager(mavenWethPoolManager,         openTermLoanManagerFactory);
    }

    function _performProtocolUpgrade() internal {

        _deployAllNewContracts();

        upgradeGlobals(globals, globalsImplementationV3);

        _enableGlobalsKeys();

        _setupFactories();

        _upgradePoolContractsAsSecurityAdmin();

        _addWithdrawalManagersToAllowlists();

        _addLoanManagers();
    }

    /**************************************************************************************************************************************/
    /*** Assertion Helper Functions                                                                                                     ***/
    /**************************************************************************************************************************************/

    function _assertIsLoan(address[] memory loans) internal {
        for (uint256 i; i < loans.length; ++i) {
            assertEq( IProxyFactoryLike(fixedTermLoanFactoryV502).isLoan(loans[i]), true);
        }
    }

}
