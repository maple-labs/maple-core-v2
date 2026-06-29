// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IMockERC20 } from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract AaveV3StrategyTestBase is TestBaseWithAssertions {

    address lp = makeAddr("lp");

    function setUp() public virtual override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 21073000);

        start      = block.timestamp;
        fundsAsset = IMockERC20(USDC);

        _createAccounts();
        _createGlobals();
        _configureGlobals();
        _createFactories();
        _createPoolWithOTLM(poolDelegate);
        _configurePool();

        _deployAaveV3Strategy(AAVE_USDC);

        addStrategyManagerToPool(address(poolManager), aaveV3StrategyManager);
    }

}
