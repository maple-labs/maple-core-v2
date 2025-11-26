// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract ImpairedAssetsTests is SyrupBitcoinTestBase {

    address depositor = makeAddr("depositor");

    uint256 principal = 21_000_000e8;

    function test_impairedAssets_default() external view {
        assertEq(bitcoinStrategy.impairedAssets(), 0);
    }

    function testFuzz_impairedAssets_withImpairment(uint256 impairment) external {
        // Mint, deposit, and deploy assets.
        depositAsset.mint(depositor, principal);

        vm.startPrank(depositor);
        depositAsset.approve(address(bitcoinRouter), principal);
        bitcoinRouter.deposit(address(depositAsset), principal, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();

        vm.prank(strategyManager);
        bitcoinStrategy.deploy(address(depositAsset), principal);

        // Set impairment amount.
        impairment = bound(impairment, 0, principal);

        vm.prank(governor);
        bitcoinStrategy.setImpairment(impairment);

        // Assert impaired assets.
        assertEq(bitcoinStrategy.impairedAssets(), impairment);
    }

}
