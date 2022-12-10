// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Lifecycle } from "../simulations/mainnet/Lifecycle.t.sol";

contract DeployMapleV2 is Lifecycle {

    function run() external {
        vm.startBroadcast(deployer);

        _deployProtocol();
        _deploy401DebtLockerAndAccountingChecker();

        vm.stopBroadcast();
    }

}
