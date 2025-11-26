// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract YieldRateTests is SyrupBitcoinTestBase {

    function test_yieldRate_withoutSchedule() external view {
        assertEq(bitcoinStrategy.yieldRate(), 0);
    }

    function testFuzz_yieldRate_withSchedule(uint256 yield, uint32 duration, uint32 elapsed) external {
        yield = bound(yield, 1, 10_000_000e8);

        duration = uint32(bound(duration, 1 seconds, 365 days));
        elapsed  = uint32(bound(elapsed,  0 seconds, duration + 30 days));

        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yield, startingTime + duration);

        vm.warp(startingTime + elapsed);

        assertEq(bitcoinStrategy.yieldRate(), elapsed < duration ? 1e30 * yield / duration : 0);
    }

}
