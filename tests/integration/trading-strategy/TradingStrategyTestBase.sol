// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract TradingStrategyTestBase is TestBaseWithAssertions {

    uint256 constant INITIAL_LIQUIDITY = 1_000_000e6;

    address lp     = makeAddr("lp");
    address trader = makeAddr("trader");

    function setUp() public virtual override {
        super.setUp();

        _deployTradingStrategy();

        addStrategyManagerToPool(address(poolManager), tradingStrategyManager);

        setTradingAddress({
            strategy_:        tradingUnderlyingStrategy,
            tradingAddress_:  trader,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   type(uint256).max
        });
    }

}
