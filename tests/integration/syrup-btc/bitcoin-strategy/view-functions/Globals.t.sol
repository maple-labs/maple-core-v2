// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IBitcoinStrategy, IMapleProxyFactory, IMapleProxied } from "../../../../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../../../../TestBase.sol";

contract GlobalsViewFunctionTests is TestBase {

    address strategy;

    function setUp() public override {
        _setUpBitcoinPool();

        strategy = poolManager.strategyList(0);
    }

    function test_globals_updatesAfterFactorySetGlobals() external {
        address newGovernor = makeAddr("newGovernor");
        address newGlobals  = deployNTP(newGovernor, deploy("MapleGlobals"));

        vm.prank(governor);
        IMapleProxyFactory(bitcoinStrategyFactory).setGlobals(newGlobals);

        assertEq(IMapleProxied(strategy).factory(), bitcoinStrategyFactory);
        assertEq(IMapleProxyFactory(bitcoinStrategyFactory).mapleGlobals(), newGlobals);
        assertEq(IBitcoinStrategy(strategy).globals(), newGlobals);
    }

}
