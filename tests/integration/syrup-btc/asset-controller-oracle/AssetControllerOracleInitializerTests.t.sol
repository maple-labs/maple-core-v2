// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IAssetControllerOracle, IGlobals } from "../../../../contracts/interfaces/Interfaces.sol";

import { SyrupBitcoinTestBase } from "../SyrupBitcoinTestBase.sol";

contract AssetControllerOracleInitializerTests is SyrupBitcoinTestBase {

    function setUp() public override {
        start = block.timestamp;

        _createAccounts();
        _createGlobals();
        _createAssets();
        _configureGlobals();
        _createFactories();
    }

    function test_assetControllerOracleInitializer_revert_invalidGlobals_globalsIsNotAContract() public {
        globals                   = IGlobals(makeAddr("globals"));
        priceOracleImplementation = deployFromFile("Contracts@25", "AssetControllerOracle");

        vm.expectRevert("NTPI:C:INVALID_GLOBALS");
        deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                priceOracleImplementation,
                address(0),
                ""
            )
        );
    }

    function test_assetControllerOracleInitializer_revert_invalidImplementation_implementationIsNotAContract() public {
        priceOracleImplementation = makeAddr("implementation");

        vm.expectRevert("NTPI:U:INVALID_IMPLEMENTATION");
        deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                priceOracleImplementation,
                address(0),
                ""
            )
        );
    }

    function test_assetControllerOracleInitializer_revert_invalidMigrator_migratorIsNotAContract() public {
        priceOracleImplementation = deployFromFile("Contracts@25", "AssetControllerOracle");

        vm.expectRevert("NTPI:U:INVALID_MIGRATOR");
        deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                priceOracleImplementation,
                makeAddr("migrator"),
                abi.encodeWithSignature("initialize(address,address)", priceOracleProxy, bitcoinRouterProxy)
            )
        );
    }

    function test_assetControllerOracleInitializer_success() public {
        priceOracleImplementation = deployFromFile("Contracts@25", "AssetControllerOracle");
        priceOracleProxy          = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                priceOracleImplementation,
                address(0),
                ""
            )
        );

        assertEq(IAssetControllerOracle(priceOracleProxy).globals(),        address(globals));
        assertEq(IAssetControllerOracle(priceOracleProxy).implementation(), priceOracleImplementation);
    }
    
}
