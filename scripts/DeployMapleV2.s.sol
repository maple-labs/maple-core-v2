// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { SimulationBase } from "../simulations/mainnet/SimulationBase.sol";

contract DeployMapleV2 is SimulationBase {

    function run() external {
        vm.startBroadcast(deployer);

        _deployProtocol();

        vm.stopBroadcast();

        // TODO: sim to end of migration
        // TODO: run simple lifecycle

        // setupFactoriesForSimulation();

        // migrate();

        // // PoolV2 Lifecycle start
        // depositAllCovers();
        // increaseAllLiquidityCaps();
        // makeAllDeposits();
    }

}
