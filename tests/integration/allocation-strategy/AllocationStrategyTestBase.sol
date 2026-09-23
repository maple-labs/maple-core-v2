// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract AllocationStrategyTestBase is TestBaseWithAssertions {

    uint256 constant INITIAL_LIQUIDITY = 1_000_000e6;

    address lp            = makeAddr("lp");
    address managedWallet = makeAddr("managedWallet");

    function setUp() public virtual override {
        super.setUp();

        (allocationStrategyManager, allocationUnderlyingStrategy) = _deployAllocationStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        addStrategyManagerToPool(address(poolManager), allocationStrategyManager);

        setManagedWallet({
            strategy_:        allocationUnderlyingStrategy,
            managedWallet_:   managedWallet,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   type(uint256).max
        });
    }

}
