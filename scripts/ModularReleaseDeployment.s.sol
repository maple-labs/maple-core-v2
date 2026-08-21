// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { MapleAddressRegistryETH } from "../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

import { console, Script } from "../modules/forge-std/src/Script.sol";

import { MapleGlobals } from "../modules/globals/contracts/MapleGlobals.sol";

import { MaplePoolDeployer }            from "../modules/pool/contracts/MaplePoolDeployer.sol";
import { MaplePoolManager }             from "../modules/pool/contracts/MaplePoolManager.sol";
import { MaplePoolManagerInitializer }  from "../modules/pool/contracts/proxy/MaplePoolManagerInitializer.sol";
import { MaplePoolManagerMigratorV500 } from "../modules/pool/contracts/proxy/MaplePoolManagerMigratorV500.sol";

import { MapleStrategyDeployer }           from "../modules/strategy-manager/contracts/MapleStrategyDeployer.sol";
import { MapleStrategyManager }            from "../modules/strategy-manager/contracts/MapleStrategyManager.sol";
import { MapleStrategyManagerFactory }     from "../modules/strategy-manager/contracts/MapleStrategyManagerFactory.sol";
import { MapleStrategyManagerInitializer } from "../modules/strategy-manager/contracts/MapleStrategyManagerInitializer.sol";

import { MapleAaveV3Strategy }            from "../modules/defi-strategies/contracts/aaveV3/MapleAaveV3Strategy.sol";
import { MapleAaveV3StrategyFactory }     from "../modules/defi-strategies/contracts/aaveV3/MapleAaveV3StrategyFactory.sol";
import { MapleAaveV3StrategyInitializer } from "../modules/defi-strategies/contracts/aaveV3/MapleAaveV3StrategyInitializer.sol";

import { MapleSkyStrategy }            from "../modules/defi-strategies/contracts/sky/MapleSkyStrategy.sol";
import { MapleSkyStrategyFactory }     from "../modules/defi-strategies/contracts/sky/MapleSkyStrategyFactory.sol";
import { MapleSkyStrategyInitializer } from "../modules/defi-strategies/contracts/sky/MapleSkyStrategyInitializer.sol";

import { MapleAllocationStrategyFactory }     from "../modules/allocation-strategy/contracts/MapleAllocationStrategyFactory.sol";
import { MapleAllocationStrategy }            from "../modules/allocation-strategy/contracts/MapleAllocationStrategy.sol";
import { MapleAllocationStrategyInitializer } from "../modules/allocation-strategy/contracts/MapleAllocationStrategyInitializer.sol";

import { MapleLiquidityRouter } from "../modules/strategy-manager/contracts/MapleLiquidityRouter.sol";

contract ModularReleaseDeployment is Script, MapleAddressRegistryETH {

    function run() public {
        address deployer = vm.envAddress("ETH_SENDER");

        console.log("Deployer:                                     ", deployer);
        console.log("-----------------------------------------------------------------------------------------");

        vm.startBroadcast(deployer);

        // 1. MapleGlobals
        address globalsV500Implementation = address(new MapleGlobals());

        console.log("MapleGlobals implementation deployed at:      ", globalsV500Implementation);
        console.log("-----------------------------------------------------------------------------------------");

        // 2. Deployers
        address poolDeployerV500     = address(new MaplePoolDeployer(globals));
        address strategyDeployerV100 = address(new MapleStrategyDeployer(globals));

        console.log("PoolDeployer deployed at:                     ", poolDeployerV500);
        console.log("StrategyDeployer deployed at:                 ", strategyDeployerV100);
        console.log("-----------------------------------------------------------------------------------------");

        // 3. Pool manager contracts
        address poolManagerV500Implementation = address(new MaplePoolManager());
        address poolManagerV500Initializer    = address(new MaplePoolManagerInitializer());
        address poolManagerV500Migrator       = address(new MaplePoolManagerMigratorV500());

        console.log("PoolManager implementation deployed at:       ", poolManagerV500Implementation);
        console.log("PoolManager initializer deployed at:          ", poolManagerV500Initializer);
        console.log("PoolManager migrator deployed at:             ", poolManagerV500Migrator);
        console.log("-----------------------------------------------------------------------------------------");

        // 4. Strategy manager contracts
        address strategyManagerFactory            = address(new MapleStrategyManagerFactory(globals));
        address strategyManagerV100Implementation = address(new MapleStrategyManager());
        address strategyManagerV100Initializer    = address(new MapleStrategyManagerInitializer());

        console.log("StrategyManager factory deployed at:          ", strategyManagerFactory);
        console.log("StrategyManager implementation deployed at:   ", strategyManagerV100Implementation);
        console.log("StrategyManager initializer deployed at:      ", strategyManagerV100Initializer);
        console.log("-----------------------------------------------------------------------------------------");

        // 5. Aave V3 strategy contracts
        address modularAaveStrategyFactory            = address(new MapleAaveV3StrategyFactory(globals));
        address modularAaveStrategyV100Implementation = address(new MapleAaveV3Strategy());
        address modularAaveStrategyV100Initializer    = address(new MapleAaveV3StrategyInitializer());

        console.log("AaveV3Strategy factory deployed at:           ", modularAaveStrategyFactory);
        console.log("AaveV3Strategy implementation deployed at:    ", modularAaveStrategyV100Implementation);
        console.log("AaveV3Strategy initializer deployed at:       ", modularAaveStrategyV100Initializer);
        console.log("-----------------------------------------------------------------------------------------");

        // 6. Sky strategy contracts
        address modularSkyStrategyFactory            = address(new MapleSkyStrategyFactory(globals));
        address modularSkyStrategyV100Implementation = address(new MapleSkyStrategy());
        address modularSkyStrategyV100Initializer    = address(new MapleSkyStrategyInitializer());

        console.log("SkyStrategy factory deployed at:              ", modularSkyStrategyFactory);
        console.log("SkyStrategy implementation deployed at:       ", modularSkyStrategyV100Implementation);
        console.log("SkyStrategy initializer deployed at:          ", modularSkyStrategyV100Initializer);
        console.log("-----------------------------------------------------------------------------------------");

        // 7. Allocation strategy contracts
        address allocationStrategyFactory            = address(new MapleAllocationStrategyFactory(globals));
        address allocationStrategyV100Implementation = address(new MapleAllocationStrategy());
        address allocationStrategyV100Initializer    = address(new MapleAllocationStrategyInitializer());

        console.log("AllocationStrategy factory deployed at:       ", allocationStrategyFactory);
        console.log("AllocationStrategy implementation deployed at:", allocationStrategyV100Implementation);
        console.log("AllocationStrategy initializer deployed at:   ", allocationStrategyV100Initializer);
        console.log("-----------------------------------------------------------------------------------------");

        // 8. LiquidityRouter
        address liquidityRouterV100 = address(new MapleLiquidityRouter(globals));

        console.log("LiquidityRouter deployed at:                  ", liquidityRouterV100);
        console.log("-----------------------------------------------------------------------------------------");

        vm.stopBroadcast();
    }

}
