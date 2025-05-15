// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IGlobals,
    IPoolManager
} from "../../contracts/interfaces/Interfaces.sol";

import { ProtocolUpgradeBase } from "./ProtocolUpgradeBase.sol";

contract ProtocolUpgradeTests is ProtocolUpgradeBase {

    uint256 start;

    function setUp() external {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 22446028);

        upgradeProtocol();

        start = block.timestamp;
    }

    function testFork_addCoreStrategy() external {
        vm.prank(governor);
        IGlobals(globals).setValidInstanceOf("STRATEGY_VAULT", highYieldCorpUSDCPool, true);

        vm.prank(syrupUSDCPoolDelegate);
        IPoolManager(syrupUSDCPoolManager).addStrategy(coreStrategyFactory, abi.encode(highYieldCorpUSDCPool));
    }

}
