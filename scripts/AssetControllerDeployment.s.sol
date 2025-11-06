// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { console, Script } from "../modules/forge-std/src/Script.sol";

import { MapleAddressRegistryETH } from "../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

import { AssetController }                  from "../modules/controller/contracts/AssetController.sol";
import { NonTransparentProxyInitializable } from "../modules/controller/contracts/NonTransparentProxyInitializable.sol";
import { AssetControllerInitializer }       from "../modules/controller/contracts/proxy/AssetControllerInitializer.sol";

contract AssetControllerDeployment is Script, MapleAddressRegistryETH {

    address assetControllerImplementation;
    address assetControllerInitializer;
    address assetControllerProxy;

    address deployer = vm.envAddress("ETH_SENDER");

    address assetControllerOracleProxy = vm.envAddress("ASSET_CONTROLLER_ORACLE");
    address bitcoinRouterProxy         = vm.envAddress("SYRUP_BTC_ROUTER");

    function run() public {
        console.log("Deployer:", deployer, "\n");

        console.log("AssetControllerOracle proxy:", assetControllerOracleProxy);
        console.log("SyrupBitcoinRouter proxy:   ", bitcoinRouterProxy, "\n");

        vm.startBroadcast(deployer);

        assetControllerImplementation = address(new AssetController());
        assetControllerInitializer    = address(new AssetControllerInitializer());
        assetControllerProxy          = address(new NonTransparentProxyInitializable({
            globals_:        globals,
            implementation_: assetControllerImplementation,
            initializer_:    assetControllerInitializer,
            calldata_:       abi.encodeWithSignature(
                "initialize(address,address)",
                assetControllerOracleProxy,
                bitcoinRouterProxy
            )
        }));

        console.log("AssetController implementation deployed at:", assetControllerImplementation);
        console.log("AssetController initializer deployed at:   ", assetControllerInitializer);
        console.log("AssetController proxy deployed at:         ", assetControllerProxy);

        vm.stopBroadcast();
    }

}
