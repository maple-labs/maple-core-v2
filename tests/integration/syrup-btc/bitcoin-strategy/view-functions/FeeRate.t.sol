// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract FeeRateTests is SyrupBitcoinTestBase {

    function test_feeRate_default() external view {
        assertEq(bitcoinStrategy.feeRate(), 0);
    }

    function testFuzz_feeRate_updated(uint256 feeRate) external {
        feeRate = bound(feeRate, 0, 1e6);

        vm.prank(governor);
        bitcoinStrategy.setFeeRate(feeRate);

        assertEq(bitcoinStrategy.feeRate(), feeRate);
    }

}
