// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract RealizedFeesTests is SyrupBitcoinTestBase {

    address depositor = makeAddr("depositor");

    function test_realizedFees_withoutSchedule() external {
        assertEq(bitcoinStrategy.realizedFees(), 0);
    }

    function testFuzz_realizedFees_withSchedule(uint256 yield, uint256 feeRate, uint32 duration, uint32 elapsed) external {
        yield   = bound(yield,   1, 10_000_000e8);
        feeRate = bound(feeRate, 0, 1e6);

        duration = uint32(bound(duration, 1 seconds, 365 days));
        elapsed  = uint32(bound(elapsed,  0 seconds, duration + 30 days));

        // Configure fees.
        vm.prank(governor);
        bitcoinStrategy.setFeeRate(feeRate);

        // Schedule yield.
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yield, startingTime + duration);

        // Warp randomly into the future.
        vm.warp(startingTime + elapsed);

        // Cancel schedule to realized fees.
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(0, 0);

        // Calculate expected fees.
        uint256 accruedYield = elapsed < duration ? yield * elapsed / duration : yield;
        uint256 accruedFees  = accruedYield * feeRate / 1e6;

        // Assert accrued yield matches expected value.
        assertEq(bitcoinStrategy.realizedFees(), accruedFees);
    }

}
