// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IMockERC20 } from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract SkyStrategyTestBase is TestBaseWithAssertions {

    address lp = makeAddr("lp");

    function setUp() public virtual override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), MAINNET_FORK_BLOCK);

        start = block.timestamp;

        fundsAsset = IMockERC20(USDC);

        _createAccounts();
        _createGlobals();
        _configureGlobals();
        _createFactories();
        _createPoolWithOTLM(poolDelegate);
        _configurePool();

        (skyStrategyManager, skyUnderlyingStrategy) = _deploySkyStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            savingsUsds_:             SAVINGS_USDS,
            psm_:                     USDS_LITE_PSM,
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        addStrategyManagerToPool(address(poolManager), skyStrategyManager);
    }

}
