// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { console, Script } from "../modules/forge-std/src/Script.sol";

import { MapleAddressRegistryETH } from "../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

import { NonTransparentProxyInitializable } from "../modules/controller/contracts/NonTransparentProxyInitializable.sol";
import { SyrupBitcoinRouter }               from "../modules/controller/contracts/SyrupBitcoinRouter.sol";
import { SyrupBitcoinRouterInitializer }    from "../modules/controller/contracts/proxy/SyrupBitcoinRouterInitializer.sol";

contract SyrupBitcoinRouterDeployment is Script, MapleAddressRegistryETH {

    address bitcoinRouterImplementation;
    address bitcoinRouterInitializer;
    address bitcoinRouterProxy;

    address deployer    = vm.envAddress("ETH_SENDER");
    address poolManager = vm.envAddress("SYRUP_BTC_POOL_MANAGER");

    function run() public {
        console.log("Deployer:", deployer, "\n");
        console.log("Syrup BTC PoolManager:", poolManager, "\n");

        vm.startBroadcast(deployer);

        bitcoinRouterImplementation = address(new SyrupBitcoinRouter());
        bitcoinRouterInitializer    = address(new SyrupBitcoinRouterInitializer());
        bitcoinRouterProxy          = address(new NonTransparentProxyInitializable({
            globals_:        globals,
            implementation_: bitcoinRouterImplementation,
            initializer_:    bitcoinRouterInitializer,
            calldata_:       abi.encodeWithSignature("initialize(address)", poolManager)
        }));

        console.log("SyrupBitcoinRouter implementation deployed at:", bitcoinRouterImplementation);
        console.log("SyrupBitcoinRouter initializer deployed at:   ", bitcoinRouterInitializer);
        console.log("SyrupBitcoinRouter proxy deployed at:         ", bitcoinRouterProxy);

        vm.stopBroadcast();
    }

}
