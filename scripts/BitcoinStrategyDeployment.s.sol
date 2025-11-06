
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { console, Script } from "../modules/forge-std/src/Script.sol";

import { MapleAddressRegistryETH } from "../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

import { MapleBitcoinStrategy }            from "../modules/strategies/contracts/MapleBitcoinStrategy.sol";
import { MapleBitcoinStrategyInitializer } from "../modules/strategies/contracts/proxy/bitcoinStrategy/MapleBitcoinStrategyInitializer.sol";
import { MapleStrategyFactory }            from "../modules/strategies/contracts/proxy/MapleStrategyFactory.sol";

contract BitcoinStrategyDeployment is Script, MapleAddressRegistryETH {

    address bitcoinStrategyFactory;
    address bitcoinStrategyImplementation;
    address bitcoinStrategyInitializer;

    address deployer = vm.envAddress("ETH_SENDER");

    function run() public {
        console.log("Deployer:", deployer, "\n");

        vm.startBroadcast(deployer);

        bitcoinStrategyFactory        = address(new MapleStrategyFactory(globals));
        bitcoinStrategyImplementation = address(new MapleBitcoinStrategy());
        bitcoinStrategyInitializer    = address(new MapleBitcoinStrategyInitializer());

        console.log("BitcoinStrategy factory deployed at:       ", bitcoinStrategyFactory);
        console.log("BitcoinStrategy implementation deployed at:", bitcoinStrategyImplementation);
        console.log("BitcoinStrategy initializer deployed at:   ", bitcoinStrategyInitializer);
        console.log("");

        vm.stopBroadcast();
    }

}
