// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { console2 as console, Script } from "../modules/forge-std/src/Script.sol";

import { MapleAddressRegistryETH } from "../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

import { MapleStrategyFactory }          from "../modules/strategies/contracts/proxy/MapleStrategyFactory.sol";
import { MapleAaveStrategyInitializer }  from "../modules/strategies/contracts/proxy/aaveStrategy/MapleAaveStrategyInitializer.sol";
import { MapleBasicStrategyInitializer } from "../modules/strategies/contracts/proxy/basicStrategy/MapleBasicStrategyInitializer.sol";
import { MapleSkyStrategyInitializer }   from "../modules/strategies/contracts/proxy/skyStrategy/MapleSkyStrategyInitializer.sol";
import { MapleAaveStrategy }             from "../modules/strategies/contracts/MapleAaveStrategy.sol";
import { MapleBasicStrategy }            from "../modules/strategies/contracts/MapleBasicStrategy.sol";
import { MapleSkyStrategy }              from "../modules/strategies/contracts/MapleSkyStrategy.sol";

import { MaplePoolManager }            from "../modules/pool/contracts/MaplePoolManager.sol";
import { MaplePoolManagerInitializer } from "../modules/pool/contracts/proxy/MaplePoolManagerInitializer.sol";
import { MaplePoolDeployer }           from "../modules/pool/contracts/MaplePoolDeployer.sol";

import { MapleGlobals } from "../modules/globals/contracts/MapleGlobals.sol";

contract MapleStrategiesDeployment is Script, MapleAddressRegistryETH {

    function run() public {
        address ETH_SENDER = vm.envAddress("ETH_SENDER");

        vm.startBroadcast(ETH_SENDER);

        console.log("Deploying strategies...");

        // Deploy factories
        address aaveFactory  = address(new MapleStrategyFactory(globals));
        address basicFactory = address(new MapleStrategyFactory(globals));
        address skyFactory   = address(new MapleStrategyFactory(globals));

        // Deploy Initializers
        address aaveInitializer  = address(new MapleAaveStrategyInitializer());
        address basicInitializer = address(new MapleBasicStrategyInitializer());
        address skyInitializer   = address(new MapleSkyStrategyInitializer());

        // Deploy Implementations
        address aaveImplementation  = address(new MapleAaveStrategy());
        address basicImplementation = address(new MapleBasicStrategy());
        address skyImplementation   = address(new MapleSkyStrategy());

        console.log("Aave factory deployed at         ", aaveFactory);
        console.log("Aave initializer deployed at     ", aaveInitializer);
        console.log("Aave implementation deployed at  ", aaveImplementation);
        console.log("---------------------------------");

        console.log("Basic factory deployed at        ", basicFactory);
        console.log("Basic initializer deployed at    ", basicInitializer);
        console.log("Basic implementation deployed at ", basicImplementation);
        console.log("---------------------------------");

        console.log("Sky factory deployed at          ", skyFactory);
        console.log("Sky initializer deployed at      ", skyInitializer);
        console.log("Sky implementation deployed at   ", skyImplementation);

        console.log("---------------------------------");
        // Deploy new globals version
        address newGlobals = address(new MapleGlobals());

        console.log("Globals deployed at ", newGlobals);
        console.log("-----------------------------------");
        // Deploy PoolManager implementation
        address poolManagerInitializer    = address(new MaplePoolManagerInitializer());
        address poolManagerImplementation = address(new MaplePoolManager());
        address poolDeployer              = address(new MaplePoolDeployer(globals));

        console.log("PoolManager initializer deployed at    ", poolManagerInitializer);
        console.log("PoolManager implementation deployed at ", poolManagerImplementation);
        console.log("PoolDeployer deployed at               ", poolDeployer);
        console.log("-----------------------------------");

        vm.stopBroadcast();
    }

}
