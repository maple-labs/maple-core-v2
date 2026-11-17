// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { ISkyStrategy } from "../../../contracts/interfaces/Interfaces.sol";

import { SkyStrategyTestBase } from "./SkyStrategyTestBase.sol";

contract SkyStrategySetFeeRatesFailureTests is SkyStrategyTestBase {

    uint32 feeRate = 0.1e6; // 10% of accrued yield.

    function testFork_setStrategyDelegateFeeRate_failWhenPsmHalted() external {
        setSkyTout(type(uint256).max);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:SSDFR:PSM_HALTED");
        ISkyStrategy(skyUnderlyingStrategy).setStrategyDelegateFeeRate(feeRate);
    }

    function testFork_setStrategyProtocolFeeRate_failWhenPsmHalted() external {
        setSkyTout(type(uint256).max);

        vm.prank(governor);
        vm.expectRevert("MSS:SSPFR:PSM_HALTED");
        ISkyStrategy(skyUnderlyingStrategy).setStrategyProtocolFeeRate(feeRate);
    }

}
