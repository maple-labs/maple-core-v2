// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { MapleAddressRegistryETH } from "../../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

import { ProtocolActions } from "../../contracts/ProtocolActions.sol";

import {
    ICoreStrategy,
    IERC20,
    IGlobals,
    IMapleProxyFactory,
    IPool,
    IPoolManager,
    IPoolPermissionManager,
    IWithdrawalManagerQueue
} from "../../contracts/interfaces/Interfaces.sol";

contract CoreStrategyLoopTests is ProtocolActions, MapleAddressRegistryETH {

    address pool_A;
    address pool_B;

    address poolManager_A;
    address poolManager_B;

    address poolDelegate_A;
    address poolDelegate_B;

    address strategyFactory;

    function setUp() external {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 23428891);

        // Select a few existing Maple pools that use the same asset.
        pool_A = syrupUSDCPool;
        pool_B = securedLendingUSDCPool;

        poolManager_A = syrupUSDCPoolManager;
        poolManager_B = securedLendingUSDCPoolManager;

        poolDelegate_A = IPoolManager(poolManager_A).poolDelegate();
        poolDelegate_B = IPoolManager(poolManager_B).poolDelegate();

        // Upgrade all pools to the new pool manager that checks for AUM failure.
        address poolManagerImplementation = deployFromFile("Contracts@25", "PoolManager");
        address poolManagerInitializer    = deployFromFile("Contracts@25", "PoolManagerInitializer");

        address withdrawalManagerQueueImplementation = deployFromFile("Contracts@7", "WithdrawalManagerQueue");
        address withdrawalManagerQueueInitializer    = deployFromFile("Contracts@7", "WithdrawalManagerQueueInitializer");

        vm.startPrank(daoMultisig);
        IMapleProxyFactory(poolManagerFactory).registerImplementation(401, poolManagerImplementation, poolManagerInitializer);
        IMapleProxyFactory(poolManagerFactory).enableUpgradePath(400, 401, address(0));
        IMapleProxyFactory(poolManagerFactory).setDefaultVersion(401);

        IMapleProxyFactory(withdrawalManagerQueueFactory).registerImplementation(
            101,
            withdrawalManagerQueueImplementation,
            withdrawalManagerQueueInitializer
        );
        IMapleProxyFactory(withdrawalManagerQueueFactory).enableUpgradePath(100, 101, address(0));
        IMapleProxyFactory(withdrawalManagerQueueFactory).setDefaultVersion(101);
        vm.stopPrank();

        vm.startPrank(securityAdmin);
        IPoolManager(poolManager_A).upgrade(401, "");
        IPoolManager(poolManager_B).upgrade(401, "");

        IWithdrawalManagerQueue(IPoolManager(poolManager_A).withdrawalManager()).upgrade(101, "");
        IWithdrawalManagerQueue(IPoolManager(poolManager_B).withdrawalManager()).upgrade(101, "");
        vm.stopPrank();

        // Create the core strategy factory and set it up.
        strategyFactory = deployFromFile("Contracts@25", "StrategyFactory", abi.encode(address(globals)));

        address strategyImplementation = deployFromFile("Contracts@25", "CoreStrategy");
        address strategyInitializer    = deployFromFile("Contracts@25", "CoreStrategyInitializer");

        vm.startPrank(daoMultisig);
        IMapleProxyFactory(strategyFactory).registerImplementation(100, strategyImplementation, strategyInitializer);
        IMapleProxyFactory(strategyFactory).setDefaultVersion(100);
        vm.stopPrank();

        vm.prank(daoMultisig);
        IGlobals(globals).setValidInstanceOf("STRATEGY_FACTORY", strategyFactory, true);

        // Whitelist all Maple pools as valid strategy vaults.
        vm.startPrank(daoMultisig);
        IGlobals(globals).setValidInstanceOf("STRATEGY_VAULT", pool_A, true);
        IGlobals(globals).setValidInstanceOf("STRATEGY_VAULT", pool_B, true);
        vm.stopPrank();
    }

    function test_coreStrategyLoop_v1() external {
        // A->B
        vm.prank(poolDelegate_A);
        IPoolManager(poolManager_A).addStrategy(strategyFactory, abi.encode(pool_B));

        // A->B->A
        vm.prank(poolDelegate_B);
        vm.expectRevert("PM:AS:AUM_FAILURE");
        IPoolManager(poolManager_B).addStrategy(strategyFactory, abi.encode(pool_A));
    }

}
