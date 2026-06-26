// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console } from "../../../modules/forge-std/src/Test.sol";

import { IMapleProxyFactory, IMockERC20, IPoolManager } from "../../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../../TestBase.sol";

contract AddStrategyTests is TestBase {

    function setUp() public override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 21073000);

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
            strategyData_:    new bytes[](0),
            name_:                      "Pool",
            symbol_:                    "MP",
            liquidityCap_:              type(uint256).max,
            delegateManagementFeeRate_: 0
        }));

        vm.startPrank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", address(AAVE_USDC),     true);
        globals.setValidInstanceOf("STRATEGY_VAULT", address(SAVINGS_USDS),  true);
        globals.setValidInstanceOf("PSM",            address(USDS_LITE_PSM), true);
        vm.stopPrank();
    }

    // TODO: Write the rest of the tests for addStrategy()

    function test_addStrategy_paused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("PM:PAUSED");
        poolManager.addStrategy(openTermLoanManagerFactory, keccak256(abi.encode(openTermLoanManagerFactory, new bytes(0))), new bytes(0));
    }

    function test_addStrategy_withExtraArguments_withGovernor() external {
        assertEq(poolManager.strategyListLength(), 0);

        vm.prank(governor);
        poolManager.addStrategy(
            skyStrategyFactory,
            keccak256(abi.encode(skyStrategyFactory, abi.encode(SAVINGS_USDS, USDS_LITE_PSM))),
            abi.encode(SAVINGS_USDS, USDS_LITE_PSM)
        );

        assertEq(poolManager.strategyListLength(), 1);

        address strategy = poolManager.strategyList(0);

        assertEq(poolManager.isStrategy(strategy),                            true);
        assertEq(IMapleProxyFactory(skyStrategyFactory).isInstance(strategy), true);
    }

}
