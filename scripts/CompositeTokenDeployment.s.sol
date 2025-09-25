// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { console2 as console, Script } from "../modules/forge-std/src/Script.sol";

import { MapleAddressRegistryETH } from "../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

import { CompositeToken }                   from "../modules/controller/contracts/CompositeToken.sol";
import { NonTransparentProxyInitializable } from "../modules/controller/contracts/NonTransparentProxyInitializable.sol";
import { CompositeTokenInitializer }        from "../modules/controller/contracts/proxy/CompositeTokenInitializer.sol";

contract CompositeTokenDeployment is Script, MapleAddressRegistryETH {

    address compositeTokenImplementation;
    address compositeTokenInitializer;
    address compositeTokenProxy;

    address deployer = vm.envAddress("ETH_SENDER");

    string name   = vm.envString("COMPOSITE_TOKEN_NAME");
    string symbol = vm.envString("COMPOSITE_TOKEN_SYMBOL");

    uint8 decimals = 8;

    function run() public {
        console.log("Deployer:", deployer, "\n");

        console.log("Token name:    ", name);
        console.log("Token symbol:  ", symbol);
        console.log("Token decimals:", decimals, "\n");

        vm.startBroadcast(deployer);

        compositeTokenImplementation = address(new CompositeToken());
        compositeTokenInitializer    = address(new CompositeTokenInitializer());
        compositeTokenProxy          = address(new NonTransparentProxyInitializable({
            globals_:        globals,
            implementation_: compositeTokenImplementation,
            initializer_:    compositeTokenInitializer,
            calldata_:       abi.encodeWithSignature("initialize(string,string,uint8)", name, symbol, decimals)
        }));

        vm.stopBroadcast();

        console.log("CompositeToken implementation deployed at:", compositeTokenImplementation);
        console.log("CompositeToken initializer deployed at:   ", compositeTokenInitializer);
        console.log("CompositeToken proxy deployed at:         ", compositeTokenProxy);
    }

}
