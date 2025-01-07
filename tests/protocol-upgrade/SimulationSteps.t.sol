// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console2 as console, Test } from "../../contracts/Runner.sol";

import { IGlobals, IMapleProxied, IMapleProxyFactory, INonTransparentProxy, IPoolManager } from "../../contracts/interfaces/Interfaces.sol";

import { UpgradeAddressRegistry } from "./UpgradeAddressRegistry.sol";

// Create a new anvil network
//anvil --auto-impersonate -f $ETH_RPC_URL --disable-code-size-limit --gas-price 0 --block-base-fee-per-gas 0

// To deploy pointing to an anvil network
// forge script --rpc-url "http://localhost:8545"  -vvvv --unlocked --slow scripts/MapleStrategiesDeployment.s.sol:MapleStrategiesDeployment --broadcast


contract DoGlobalsUpgrade is UpgradeAddressRegistry, Test {

    function run() external {
        vm.startBroadcast(governor);
        INonTransparentProxy(globals).setImplementation(newGlobalsImplementation);
        vm.stopBroadcast();
    }

}

contract DoFactoriesSetup is UpgradeAddressRegistry, Test {

    function run() external {
        vm.startBroadcast(governor);
        IMapleProxyFactory(poolManagerFactory).registerImplementation(400, newPoolManagerImplementation, newPoolManagerInitializer);
        IMapleProxyFactory(poolManagerFactory).enableUpgradePath(300, 400, address(0));
        IMapleProxyFactory(poolManagerFactory).enableUpgradePath(301, 400, address(0));
        IMapleProxyFactory(poolManagerFactory).setDefaultVersion(400);

        IMapleProxyFactory(basicStrategyFactory).registerImplementation(100, newBasicStrategyImplementation, newBasicStrategyInitializer);
        IMapleProxyFactory(aaveStrategyFactory).registerImplementation(100,  newAaveStrategyImplementation,  newAaveStrategyInitializer);
        IMapleProxyFactory(skyStrategyFactory).registerImplementation(100,   newSkyStrategyImplementation,   newSkyStrategyInitializer);

        IMapleProxyFactory(basicStrategyFactory).setDefaultVersion(100);
        IMapleProxyFactory(aaveStrategyFactory).setDefaultVersion(100);
        IMapleProxyFactory(skyStrategyFactory).setDefaultVersion(100);

        vm.stopBroadcast();
    }

}

contract DoPoolManagerUpgrade is UpgradeAddressRegistry, Test {

    function run() external {
        vm.startBroadcast(securityAdmin);
        IPoolManager(syrupUSDCPoolManager).upgrade(400, "");
        IPoolManager(syrupUSDTPoolManager).upgrade(400, "");
        IPoolManager(highYieldCorpUSDCPoolManager).upgrade(400, "");
        vm.stopBroadcast();
    }

}

contract DoGlobalsSetup is UpgradeAddressRegistry, Test {

    function run() external {
        IGlobals globals_ = IGlobals(globals);

        vm.startBroadcast(operationalAdmin);
        globals_.setValidInstanceOf("STRATEGY_FACTORY", address(fixedTermLoanManagerFactory), true);
        globals_.setValidInstanceOf("STRATEGY_FACTORY", address(openTermLoanManagerFactory),  true);
        globals_.setValidInstanceOf("STRATEGY_FACTORY", address(basicStrategyFactory),        true);
        globals_.setValidInstanceOf("STRATEGY_FACTORY", address(aaveStrategyFactory),         true);
        globals_.setValidInstanceOf("STRATEGY_FACTORY", address(skyStrategyFactory),          true);
        globals_.setValidInstanceOf("STRATEGY_VAULT",   address(aUsdc),                       true);
        globals_.setValidInstanceOf("STRATEGY_VAULT",   address(aUsdt),                       true);
        globals_.setValidInstanceOf("STRATEGY_VAULT",   address(savingsUsds),                 true);
        globals_.setValidInstanceOf("PSM",              address(usdsLitePSM),                 true);
        vm.stopBroadcast();
    }

}

contract DoStrategyAddition is UpgradeAddressRegistry, Test {

    function run() external {
        vm.startBroadcast(operationalAdmin);
        IPoolManager(syrupUSDCPoolManager).addStrategy(address(aaveStrategyFactory), abi.encode(aUsdc));
        IPoolManager(syrupUSDCPoolManager).addStrategy(address(skyStrategyFactory),  abi.encode(savingsUsds, usdsLitePSM));

        IPoolManager(securedLendingUSDCPoolManager).addStrategy(address(aaveStrategyFactory), abi.encode(aUsdc));

        IPoolManager(syrupUSDTPoolManager).addStrategy(address(aaveStrategyFactory), abi.encode(aUsdt));
        vm.stopBroadcast();
    }

}

contract DoLoanFactoriesSetup is UpgradeAddressRegistry, Test {

    function run() external {
        vm.startBroadcast(governor);
        IMapleProxyFactory(fixedTermLoanManagerFactory).registerImplementation(
            600, newFixedTermLoanImplementation, newFixedTermLoanInitializer
        );

        IMapleProxyFactory(openTermLoanManagerFactory).registerImplementation(
            200, newOpenTermLoanImplementation, newOpenTermLoanInitializer
        );

        IMapleProxyFactory(fixedTermLoanManagerFactory).setDefaultVersion(600);
        IMapleProxyFactory(openTermLoanManagerFactory).setDefaultVersion(200);

        vm.stopBroadcast();
    }

}
