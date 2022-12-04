// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { SimulationBase } from "../simulations/mainnet/SimulationBase.sol";

contract DeployMapleV2 is SimulationBase {

    function run() external {
        vm.startBroadcast(deployer);

        deployProtocol();

        vm.stopBroadcast();

        // setupFactoriesForSimulation();

        // migrate();

        // // PoolV2 Lifecycle start
        // depositAllCovers();
        // increaseAllLiquidityCaps();
        // makeAllDeposits();
    }

}
