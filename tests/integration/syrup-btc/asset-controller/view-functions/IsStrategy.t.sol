// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract IsStrategyTests is SyrupBitcoinTestBase {

    function setUp() public virtual override {
        super.setUp();

        // 4 strategies are added in the test base
        for (uint256 i = 0; i < 4; i++) {
            address strategy = poolManager.strategyList(i);
            assertEq(assetController.isStrategy(strategy), true);
        }
    }

    function test_isStrategy_false_forRandom() external {
        address random = makeAddr("randomStrategy");
        assertEq(assetController.isStrategy(random), false);
    }

    function test_isStrategy_modifyFlags() external {
        address strategy = poolManager.strategyList(0);

        assertEq(assetController.isStrategy(strategy), true);

        address[] memory strategyAddresses = new address[](1);
        bool[]    memory flags             = new bool[](1);

        strategyAddresses[0] = strategy;
        flags[0]             = false;

        vm.prank(governor);
        assetController.setStrategies(strategyAddresses, flags);

        assertEq(assetController.isStrategy(strategy), false);

        flags[0] = true;

        vm.prank(governor);
        assetController.setStrategies(strategyAddresses, flags);

        assertEq(assetController.isStrategy(strategy), true);
    }

}
