// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IMapleProxied } from "../../../../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../../../../TestBase.sol";

contract FactoryViewFunctionTests is TestBase {

    address strategy;

    function setUp() public override {
        _setupBitcoinPool();

        strategy = poolManager.strategyList(0);
    }

    function test_factory() external {
        assertEq(IMapleProxied(strategy).factory(), bitcoinStrategyFactory);
    }

}
