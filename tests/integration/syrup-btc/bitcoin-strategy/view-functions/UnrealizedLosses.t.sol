// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract UnrealizedLossesTests is SyrupBitcoinTestBase {

    address depositor = makeAddr("depositor");

    uint256 principal = 21_000_000e8;

    function test_unrealizedLosses_default() external {
        assertEq(bitcoinStrategy.unrealizedLosses(), 0);
    }

    function testFuzz_unrealizedLosses_afterImpairment(uint256 impairedAssets, uint256 returnedAssets) external {
        // Mint, deposit, and deploy assets.
        depositAsset.mint(depositor, principal);

        vm.startPrank(depositor);
        depositAsset.approve(address(bitcoinRouter), principal);
        bitcoinRouter.deposit(address(depositAsset), principal, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();

        vm.prank(strategyManager);
        bitcoinStrategy.deploy(address(depositAsset), principal);

        // Set impairment.
        impairedAssets = bound(impairedAssets, 0, principal - 1);

        vm.prank(governor);
        bitcoinStrategy.setImpairment(impairedAssets);

        // Assert unrealized losses are equal to impairment.
        assertEq(bitcoinStrategy.unrealizedLosses(), impairedAssets);

        // Reconcile assets to cause over-impairment.
        returnedAssets = bound(returnedAssets, principal - impairedAssets, principal);

        vm.startPrank(strategyManager);
        depositAsset.approve(address(bitcoinStrategy), returnedAssets);
        bitcoinStrategy.reconcile(address(depositAsset), returnedAssets);
        vm.stopPrank();

        // Assert unrealized losses are capped to AUM.
        assertEq(bitcoinStrategy.unrealizedLosses(), bitcoinStrategy.assetsUnderManagement());
    }

}
