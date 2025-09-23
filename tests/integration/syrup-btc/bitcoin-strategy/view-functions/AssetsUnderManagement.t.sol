// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract AssetsUnderManagementTests is SyrupBitcoinTestBase {

    address depositor = makeAddr("depositor");

    function test_assetsUnderManagement_default() external {
        assertEq(bitcoinStrategy.assetsUnderManagement(), 0);
    }

    function testFuzz_assetsUnderManagement_principalAndYield(
        uint256 feeRate,
        uint256 principal,
        uint256 yield,
        uint32  duration,
        uint32  elapsed
    )
        external
    {
        feeRate   = bound(feeRate,   0,               1e6);
        principal = bound(principal, 1e8,             10_000_000e8);
        yield     = bound(yield,     principal / 100, principal / 10);

        duration = uint32(bound(duration, 1 seconds, 365 days));
        elapsed  = uint32(bound(elapsed,  0 seconds, duration + 30 days));

        // Configure fees.
        vm.prank(governor);
        bitcoinStrategy.setFeeRate(feeRate);

        // Mint, deposit and deploy principal.
        depositAsset.mint(depositor, principal);

        vm.startPrank(depositor);
        depositAsset.approve(address(bitcoinRouter), principal);
        bitcoinRouter.deposit(address(depositAsset), principal, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();

        vm.prank(strategyManager);
        bitcoinStrategy.deploy(address(depositAsset), principal);

        // Schedule yield.
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yield, startingTime + duration);

        // Warp randomly into the future.
        vm.warp(startingTime + elapsed);

        // Calculate expected yield and fees.
        uint256 accruedYield = elapsed < duration ? yield * elapsed / duration : yield;
        uint256 accruedFees  = accruedYield * feeRate / 1e6;

        // Assert AUM matches expected value.
        assertEq(bitcoinStrategy.assetsUnderManagement(), principal + accruedYield - accruedFees);
    }

}
