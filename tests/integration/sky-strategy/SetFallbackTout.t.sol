// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { ISkyStrategy } from "../../../contracts/interfaces/Interfaces.sol";

import { SkyStrategyTestBase } from "./SkyStrategyTestBase.sol";

contract SkyStrategySetFallbackToutFailureTests is SkyStrategyTestBase {

    function testFork_setFallbackTout_failWithToutAboveWad() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:SFT:INVALID_TOUT");
        ISkyStrategy(skyUnderlyingStrategy).setFallbackTout(1e18 + 1);
    }

}
