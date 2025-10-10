// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { ISyrupBitcoinRouter, IPoolManager } from "../../../../contracts/interfaces/Interfaces.sol";

import { SyrupBitcoinTestBase } from "../SyrupBitcoinTestBase.sol";

contract BitcoinRouterInitializerTests is SyrupBitcoinTestBase {

    function setUp() public override {
        start = block.timestamp;

        _createAccounts();
        _createGlobals();
        _createAssets();
        _configureGlobals();
        _createFactories();

        strategyFactories       = new address[](0);
        strategyDeploymentData_ = new bytes[](0);

        strategyFactories.push(bitcoinStrategyFactory);
        strategyDeploymentData_.push(new bytes(0)); 

        vm.startPrank(governor);
        globals.setValidPoolAsset(compositeTokenProxy, true);
        globals.setValidInstanceOf("COMPOSITE_POOL_ASSET", compositeTokenProxy, true);
        vm.stopPrank();

        uint256[4] memory configParams = [uint256(0), uint256(0), uint256(0), uint256(0)];

        vm.prank(poolDelegate);
        poolManager = IPoolManager(deployer.deployPool(
            poolManagerFactory,
            queueWMFactory,
            strategyFactories,
            strategyDeploymentData_,
            compositeTokenProxy,
            address(poolPermissionManager),
            "Syrup Bitcoin",
            "SyrupBTC",
            configParams
        ));
    }

    function test_bitcoinRouterInitializer_revert_invalidGlobals_globalsIsNotAContract() public {
        bitcoinRouterImplementation = deployFromFile("Contracts@25", "SyrupBitcoinRouter");
        bitcoinRouterInitializer    = deployFromFile("Contracts@25", "SyrupBitcoinRouterInitializer");

        vm.prank(governor);
        globals.setValidInstanceOf("POOL_MANAGER_FACTORY", poolManagerFactory, false);

        vm.expectRevert("SBI:I:INVALID_PM_FACTORY");
        bitcoinRouterProxy = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                address(bitcoinRouterImplementation),
                address(bitcoinRouterInitializer),
                abi.encodeWithSignature("initialize(address)", address(poolManager))
            )
        );
    }

    function test_bitcoinRouterInitializer_revert_invalidImplementation_implementationIsNotAContract() public {
        bitcoinRouterImplementation = makeAddr("implementation");
        bitcoinRouterInitializer    = deployFromFile("Contracts@25", "SyrupBitcoinRouterInitializer");

        vm.expectRevert("NTPI:U:INVALID_IMPLEMENTATION");
        deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                bitcoinRouterImplementation,
                bitcoinRouterInitializer,
                abi.encodeWithSignature("initialize(address)", address(poolManager))
            )
        );
    }

    function test_bitcoinRouterInitializer_revert_invalidMigrator_migratorIsNotAContract() public {
        bitcoinRouterImplementation = deployFromFile("Contracts@25", "SyrupBitcoinRouter");
        bitcoinRouterInitializer    = makeAddr("migrator");

        vm.expectRevert("NTPI:U:INVALID_MIGRATOR");
        deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                bitcoinRouterImplementation,
                bitcoinRouterInitializer,
                abi.encodeWithSignature("initialize(address)", address(poolManager))
            )
        );
    }

    function test_bitcoinRouterInitializer_success() public {
        bitcoinRouterImplementation = deployFromFile("Contracts@25", "SyrupBitcoinRouter");
        bitcoinRouterInitializer    = deployFromFile("Contracts@25", "SyrupBitcoinRouterInitializer");

        bitcoinRouterProxy = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                address(bitcoinRouterImplementation),
                address(bitcoinRouterInitializer),
                abi.encodeWithSignature("initialize(address)", address(poolManager))
            )
        );

        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).locked(),         1);
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).globals(),        address(globals));
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).implementation(), address(bitcoinRouterImplementation));
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).poolManager(),    address(poolManager));
        assertEq(ISyrupBitcoinRouter(bitcoinRouterProxy).pool(),           poolManager.pool());
    }
    
}
