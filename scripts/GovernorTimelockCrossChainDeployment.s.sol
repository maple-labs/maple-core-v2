// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { console, Script } from "../modules/forge-std/src/Script.sol";

import { MapleAddressRegistryETH } from "../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

import { GovernorTimelock } from "../modules/globals/contracts/GovernorTimelock.sol";

// TODO: Update Role addresses correctly and confirm with Matt
contract GovernorTimelockCrossChainDeployment is Script, MapleAddressRegistryETH {

    function run() public {
        address ETH_SENDER = vm.envAddress("ETH_SENDER");

        console.log("ETH_SENDER: ", ETH_SENDER);

        vm.startBroadcast(ETH_SENDER);

        console.log("Governor Timelock...");

        address tokenWithdrawerCrossChain = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
        address proposerCrossChain        = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;
        address executorCrossChain        = 0xdd2d33F35D4D46c5Ec6E6351907964A6EcD49ec9;
        address cancellerCrossChain       = 0x013B906178aefe190Ac238e1b08d4C9Ba9A3894c;
        address roleAdminCrossChain       = 0xfDc1603A3B6675eAB4d29119752c19FeD730639e;

        // Deploy GovernorTimelock
        address governorTimelockCrossChain = address(new GovernorTimelock({
            tokenWithdrawer_: tokenWithdrawerCrossChain,
            proposer_:        proposerCrossChain,
            executor_:        executorCrossChain,
            canceller_:       cancellerCrossChain,
            roleAdmin_:       roleAdminCrossChain
        }));

        console.log("Governor Timelock deployed at:", governorTimelockCrossChain);
        console.log("---------------------------------");

        vm.stopBroadcast();
    }

}
