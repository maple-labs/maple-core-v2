// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract TradingStrategyTestBase is TestBaseWithAssertions {

    address lp = makeAddr("lp");

    address tradingStrategy;
    address tradingStrategyManager;

    function setUp() public virtual override {
        super.setUp();

        ( tradingStrategyManager, tradingStrategy ) = _deployTradingStrategy();

        addStrategyManagerToPool(address(poolManager), tradingStrategyManager);
    }

}
