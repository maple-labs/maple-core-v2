// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console, Script } from "../modules/forge-std/src/Script.sol";

import { IAllocationStrategy, IGlobals, IStrategyManager } from "../contracts/interfaces/Interfaces.sol";

import { UpgradeAddressRegistry } from "../tests/protocol-upgrade/UpgradeAddressRegistry.sol";

contract ModularStrategyConfiguration is UpgradeAddressRegistry, Script {

    uint256 constant DEPLOYMENT_CAP = 10_000e6;
    uint256 constant YIELD_CAP      = 5_000e6;

    function run() public {
        address delegate = pyusdUSDCDelegate;

        address strategyManager    = IGlobals(globals).ownedStrategyManager(delegate);
        address underlyingStrategy = IStrategyManager(strategyManager).underlyingStrategy();

        address[] memory accounts = new address[](2);
        bool[]    memory flags    = new bool[](2);
        uint256[] memory caps     = new uint256[](2);

        accounts[0] = pyusdUSDC_syrupUSDC_managedWallet;
        accounts[1] = pyusdUSDC_securedLending2USDC_managedWallet;

        for (uint256 i; i < accounts.length; i++) {
            flags[i] = true;
            caps[i]  = DEPLOYMENT_CAP;
        }

        vm.startBroadcast(delegate);

        IAllocationStrategy(underlyingStrategy).setPermissions(accounts, flags, flags, flags);
        IAllocationStrategy(underlyingStrategy).setDeploymentCaps(accounts, caps);
        IAllocationStrategy(underlyingStrategy).setYieldCap(YIELD_CAP);

        vm.stopBroadcast();

        console.log("StrategyDelegate:  ", delegate);
        console.log("StrategyManager:   ", strategyManager);
        console.log("UnderlyingStrategy:", underlyingStrategy);
        console.log("DeploymentCap:     ", DEPLOYMENT_CAP);
        console.log("YieldCap:          ", YIELD_CAP);

        for (uint256 i; i < accounts.length; i++) {
            console.log("ManagedWallet:     ", accounts[i]);
        }
    }

}
