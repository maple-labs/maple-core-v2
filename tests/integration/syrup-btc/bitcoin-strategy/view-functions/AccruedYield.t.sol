// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract AccruedYieldTests is SyrupBitcoinTestBase {

    address depositor = makeAddr("depositor");

    function test_accruedYield_withoutSchedule() external {
        assertEq(bitcoinStrategy.accruedYield(), 0);
    }

    function testFuzz_accruedYield_withSchedule(uint256 yield, uint32 duration, uint32 elapsed) external {
        yield = bound(yield, 1, 10_000_000e8);

        duration = uint32(bound(duration, 1 seconds, 365 days));
        elapsed  = uint32(bound(elapsed,  0 seconds, duration + 30 days));

        // Schedule yield.
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yield, startingTime + duration);

        // Warp randomly into the future.
        vm.warp(startingTime + elapsed);

        // Calculate expected yield and fees.
        uint256 accruedYield = elapsed < duration ? yield * elapsed / duration : yield;

        // Assert accrued yield matches expected value.
        assertEq(bitcoinStrategy.accruedYield(), accruedYield);
    }

}
