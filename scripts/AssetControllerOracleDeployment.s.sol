// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { console, Script } from "../modules/forge-std/src/Script.sol";

import { MapleAddressRegistryETH } from "../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

import { AssetControllerOracle }            from "../modules/controller/contracts/AssetControllerOracle.sol";
import { NonTransparentProxyInitializable } from "../modules/controller/contracts/NonTransparentProxyInitializable.sol";

contract AssetControllerOracleDeployment is Script, MapleAddressRegistryETH {

    address assetControllerOracleImplementation;
    address assetControllerOracleProxy;

    address deployer = vm.envAddress("ETH_SENDER");

    function run() public {
        console.log("Deployer:", deployer, "\n");

        vm.startBroadcast(deployer);

        assetControllerOracleImplementation = address(new AssetControllerOracle());
        assetControllerOracleProxy          = address(new NonTransparentProxyInitializable({
            globals_:        globals,
            implementation_: assetControllerOracleImplementation,
            initializer_:    address(0),
            calldata_:       ""
        }));

        vm.stopBroadcast();

        console.log("AssetControllerOracle implementation deployed at:", assetControllerOracleImplementation);
        console.log("AssetControllerOracle proxy deployed at:         ", assetControllerOracleProxy);
    }

}
