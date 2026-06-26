// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IMapleProxyFactory, IMapleProxied } from "../../../../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../../../../TestBase.sol";

contract ImplementationViewFunctionTests is TestBase {

    address strategy;

    function setUp() public override {
        _setUpBitcoinPool();

        strategy = poolManager.strategyList(0);
    }

    function test_implementation_updatesAfterUpgrade() external {
        address oldImplementation = IMapleProxied(strategy).implementation();

        address newImplementation = deployFromFile("Contracts@25", "BitcoinStrategy");

        uint256 oldVersion = IMapleProxyFactory(bitcoinStrategyFactory).versionOf(oldImplementation);
        uint256 newVersion = 201;

        vm.startPrank(governor);
        IMapleProxyFactory(bitcoinStrategyFactory).registerImplementation(newVersion, newImplementation, address(0));
        IMapleProxyFactory(bitcoinStrategyFactory).enableUpgradePath(oldVersion, newVersion, address(0));
        vm.stopPrank();

        vm.prank(securityAdmin);
        IMapleProxied(strategy).upgrade(newVersion, "");

        assertEq(IMapleProxied(strategy).implementation(), newImplementation);
    }

}
