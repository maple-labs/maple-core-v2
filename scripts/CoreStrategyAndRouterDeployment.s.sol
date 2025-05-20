// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { console2 as console, Script } from "../modules/forge-std/src/Script.sol";

import { MapleAddressRegistryETH } from "../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

import { MapleStrategyFactory }          from "../modules/strategies/contracts/proxy/MapleStrategyFactory.sol";
import { MapleCoreStrategy }             from "../modules/strategies/contracts/MapleCoreStrategy.sol";
import { MapleCoreStrategyInitializer }  from "../modules/strategies/contracts/proxy/coreStrategy/MapleCoreStrategyInitializer.sol";

import { MaplePoolManager }            from "../modules/pool/contracts/MaplePoolManager.sol";
import { MaplePoolManagerInitializer } from "../modules/pool/contracts/proxy/MaplePoolManagerInitializer.sol";

import { NonTransparentProxy }    from "../modules/syrup-utils/modules/non-transparent-proxy/contracts/NonTransparentProxy.sol";
import { MapleRouter }            from "../modules/syrup-utils/contracts/MapleRouter.sol";
import { MapleRouterInitializer } from "../modules/syrup-utils/contracts/MapleRouterInitializer.sol";

contract CoreStrategyAndRouterDeployment is Script, MapleAddressRegistryETH {

    function run() public {
        address ETH_SENDER = vm.envAddress("ETH_SENDER");

        console.log("ETH_SENDER: ", ETH_SENDER);

        vm.startBroadcast(ETH_SENDER);

        console.log("Deploying core strategy...");

        // Deploy factories
        address coreFactory = address(new MapleStrategyFactory(globals));

        // Deploy Initializer
        address coreInitializer = address(new MapleCoreStrategyInitializer());

        // Deploy Implementation
        address coreImplementation = address(new MapleCoreStrategy());

        console.log("Core factory deployed at         ", coreFactory);
        console.log("Core implementation deployed at  ", coreImplementation);
        console.log("Core initializer deployed at     ", coreInitializer);
        console.log("---------------------------------");
        console.log("Deploying pool manager...");

        // Deploy Initializer
        address poolManagerInitializer = address(new MaplePoolManagerInitializer());

        // Deploy Implementation
        address poolManagerImplementation = address(new MaplePoolManager());

        console.log("Pool manager implementation deployed at  ", poolManagerImplementation);
        console.log("Pool manager initializer deployed at     ", poolManagerInitializer);
        console.log("---------------------------------");
        console.log("Deploying Maple Router...");

        // Deploy Initializer
        address routerInitializer = address(new MapleRouterInitializer());

        // Deploy Implementation
        address routerImplementation = address(new MapleRouter());

        // Deploy Proxy
        address routerProxy = address(new NonTransparentProxy(operationalAdmin, routerInitializer));

        console.log("Router implementation deployed at  ", routerImplementation);
        console.log("Router initializer deployed at     ", routerInitializer);
        console.log("Router proxy deployed at           ", routerProxy);
        console.log("---------------------------------");

        vm.stopBroadcast();
    }

}
