// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console } from "../../../modules/forge-std/src/Test.sol";

import { IMockERC20, IPoolManager } from "../../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../../TestBase.sol";

contract AddStrategyTests is TestBase {

    function setUp() public override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), MAINNET_FORK_BLOCK);

        start = block.timestamp;

        fundsAsset = IMockERC20(USDC);

        _createAccounts();
        _createGlobals();
        _configureGlobals();
        _createFactories();

        // Create a pool with no strategies.
        poolManager = IPoolManager(_deployPoolWithQueue({
            poolDelegate_:              address(poolDelegate),
            fundsAsset_:                address(fundsAsset),
            strategyFactories_:         new address[](0),
            strategyData_:              new bytes[](0),
            name_:                      "Pool",
            symbol_:                    "MP",
            liquidityCap_:              type(uint256).max,
            delegateManagementFeeRate_: 0
        }));
    }

    // TODO: Write the rest of the tests for addStrategy()

    function test_addStrategy_paused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("PM:PAUSED");
        poolManager.addStrategy(openTermLoanManagerFactory, keccak256(abi.encode(openTermLoanManagerFactory, new bytes(0))), new bytes(0));
    }

}
