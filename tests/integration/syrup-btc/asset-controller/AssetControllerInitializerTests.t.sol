// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IAssetController, IPoolManager } from "../../../../contracts/interfaces/Interfaces.sol";

import { SyrupBitcoinTestBase } from "../SyrupBitcoinTestBase.sol";

contract AssetControllerInitializerTests is SyrupBitcoinTestBase {

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

        priceOracleImplementation = deployFromFile("Contracts@25", "AssetControllerOracle");
        priceOracleProxy          = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                address(priceOracleImplementation),
                address(0),
                ""
            )
        );

        bitcoinRouterImplementation = deployFromFile("Contracts@25", "SyrupBitcoinRouter");
        bitcoinRouterInitializer    = deployFromFile("Contracts@25", "SyrupBitcoinRouterInitializer");
        bitcoinRouterProxy          = deployFromFile(
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

    function test_assetControllerInitializer_revert_invalidImplementation_implementationIsNotAContract() public {
        assetControllerImplementation = makeAddr("implementation");
        assetControllerInitializer    = deployFromFile("Contracts@25", "AssetControllerInitializer");

        vm.expectRevert("NTPI:U:INVALID_IMPLEMENTATION");
        deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                assetControllerImplementation,
                assetControllerInitializer,
                abi.encodeWithSignature(
                    "initialize(address,address)",
                    priceOracleProxy,
                    bitcoinRouterProxy
                )
            )
        );
    }

    function test_assetControllerInitializer_revert_invalidMigrator_migratorIsNotAContract() public {
        assetControllerImplementation = deployFromFile("Contracts@25", "AssetController");
        assetControllerInitializer    = makeAddr("migrator");

        vm.expectRevert("NTPI:U:INVALID_MIGRATOR");
        deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                assetControllerImplementation,
                assetControllerInitializer,
                abi.encodeWithSignature(
                    "initialize(address,address)",
                    priceOracleProxy,
                    bitcoinRouterProxy
                )
            )
        );
    }

    function test_assetControllerInitializer_revert_assetControllerOracleNotSetAsInstanceOfControllerOracleOnGlobals() external {
        assetControllerImplementation = deployFromFile("Contracts@25", "AssetController");
        assetControllerInitializer    = deployFromFile("Contracts@25", "AssetControllerInitializer");

        vm.expectRevert("ACI:I:INVALID_ORACLE");
        assetControllerProxy          = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                assetControllerImplementation,
                assetControllerInitializer,
                abi.encodeWithSignature(
                    "initialize(address,address)",
                    priceOracleProxy,
                    bitcoinRouterProxy
                )
            )
        );
    }

    function test_assetControllerInitializer_revert_compositePoolAssetNotSetAsInstanceOfCompositePoolAssetOnGlobals() external {
        assetControllerImplementation = deployFromFile("Contracts@25", "AssetController");
        assetControllerInitializer    = deployFromFile("Contracts@25", "AssetControllerInitializer");

        vm.startPrank(governor);
        globals.setValidInstanceOf("CONTROLLER_ORACLE",    priceOracleProxy,    true);
        globals.setValidInstanceOf("COMPOSITE_POOL_ASSET", compositeTokenProxy, false);
        vm.stopPrank();

        vm.expectRevert("ACI:I:INVALID_ASSET");
        assetControllerProxy = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                assetControllerImplementation,
                assetControllerInitializer,
                abi.encodeWithSignature(
                    "initialize(address,address)",
                    priceOracleProxy,
                    bitcoinRouterProxy
                )
            )
        );
    }

    function test_assetControllerInitializer_revert_bitcoinRouterNotSetAsInstanceOfBitcoinRouterOnGlobals() external {
        assetControllerImplementation = deployFromFile("Contracts@25", "AssetController");
        assetControllerInitializer    = deployFromFile("Contracts@25", "AssetControllerInitializer");

        vm.prank(governor);
        globals.setValidInstanceOf("CONTROLLER_ORACLE",    priceOracleProxy,    true);

        vm.expectRevert("ACI:I:INVALID_ROUTER");
        assetControllerProxy          = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                assetControllerImplementation,
                assetControllerInitializer,
                abi.encodeWithSignature(
                    "initialize(address,address)",
                    priceOracleProxy,
                    bitcoinRouterProxy
                )
            )
        );
    }

    function test_assetControllerInitializer_success() external {
        vm.startPrank(governor);
        globals.setValidInstanceOf("CONTROLLER_ORACLE", priceOracleProxy,   true);
        globals.setValidInstanceOf("SYRUP_BTC_ROUTER",  bitcoinRouterProxy, true);
        vm.stopPrank();

        assetControllerImplementation = deployFromFile("Contracts@25", "AssetController");
        assetControllerInitializer    = deployFromFile("Contracts@25", "AssetControllerInitializer");
        assetControllerProxy          = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                assetControllerImplementation,
                assetControllerInitializer,
                abi.encodeWithSignature(
                    "initialize(address,address)",
                    priceOracleProxy,
                    bitcoinRouterProxy
                )
            )
        );

        assertEq(IAssetController(assetControllerProxy).locked(),         1);
        assertEq(IAssetController(assetControllerProxy).globals(),        address(globals));
        assertEq(IAssetController(assetControllerProxy).oracle(),         priceOracleProxy);
        assertEq(IAssetController(assetControllerProxy).router(),         bitcoinRouterProxy);
        assertEq(IAssetController(assetControllerProxy).implementation(), assetControllerImplementation);
    }

}
