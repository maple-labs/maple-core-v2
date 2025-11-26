// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract SchedulesTests is SyrupBitcoinTestBase {

    function test_schedules_withoutSchedule() external view {
        ( uint256 remainingYield, uint32 lastUpdated, uint32 remainingDuration ) = bitcoinStrategy.schedules(0);

        assertEq(remainingYield,    0);
        assertEq(remainingDuration, 0);
        assertEq(lastUpdated,       0);
    }

    function testFuzz_schedules_withSchedule(uint256 yield, uint32 duration, uint32 elapsed) external {
        yield = bound(yield, 1, 10_000_000e8);

        duration = uint32(bound(duration, 1 seconds, 365 days));
        elapsed  = uint32(bound(elapsed,  0 seconds, duration + 30 days));

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yield, startingTime + duration);

        ( uint256 remainingYield, uint32 lastUpdated, uint32 remainingDuration ) = bitcoinStrategy.schedules(0);

        assertEq(remainingYield,    yield);
        assertEq(remainingDuration, duration);
        assertEq(lastUpdated,       startingTime);

        vm.warp(startingTime + elapsed);

        ( remainingYield, lastUpdated, remainingDuration ) = bitcoinStrategy.schedules(0);

        assertEq(remainingYield,    yield);
        assertEq(remainingDuration, duration);
        assertEq(lastUpdated,       startingTime);
    }

}
