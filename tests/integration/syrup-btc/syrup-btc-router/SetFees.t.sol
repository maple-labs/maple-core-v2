// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../SyrupBitcoinTestBase.sol";

contract SyrupBitcoinRouterSetFeesTests is SyrupBitcoinTestBase {

    uint256 constant ONE_HUNDRED = 1e6; // 100.0000%

    address depositAsset2;

    uint256 newMintFeeA        = 0.12e6;  // 12.0%
    uint256 newMintFeeB        = 0.13e6;  // 13.0%
    uint256 newRedemptionFeeA  = 0.14e6;  // 14.0%
    uint256 newRedemptionFeeB  = 0.15e6;  // 15.0%

    function setUp() public virtual override {
        super.setUp();

        depositAsset2 = makeAddr("another_asset");
    }

    function test_setFees_revert_paused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("SBR:PAUSED");
        bitcoinRouter.setFees(address(depositAsset), 0, 0);
    }

    function test_setFees_revert_notAuthorized() external {
        vm.expectRevert("SBR:NOT_GOV_OR_POOL_DELEGATE");
        bitcoinRouter.setFees(address(depositAsset), 0, 0);
    }

    function test_setFees_revert_mintFeeTooHigh() external {
        vm.prank(governor);
        vm.expectRevert("SBR:SF:INVALID_FEE");
        bitcoinRouter.setFees(address(depositAsset), ONE_HUNDRED + 1, 0);
    }

    function test_setFees_revert_redemptionFeeTooHigh() external {
        vm.prank(governor);
        vm.expectRevert("SBR:SF:INVALID_FEE");
        bitcoinRouter.setFees(address(depositAsset), 0, ONE_HUNDRED + 1);
    }

    function test_setFees_success_zeroes() external {
        vm.prank(governor);
        bitcoinRouter.setFees(address(depositAsset), 0, 0);

        assertEq(bitcoinRouter.mintFee(address(depositAsset)),       0);
        assertEq(bitcoinRouter.redemptionFee(address(depositAsset)), 0);
    }

    function test_setFees_success_maxValues() external {
        vm.prank(governor);
        bitcoinRouter.setFees(address(depositAsset), ONE_HUNDRED, ONE_HUNDRED);

        assertEq(bitcoinRouter.mintFee(address(depositAsset)),       ONE_HUNDRED);
        assertEq(bitcoinRouter.redemptionFee(address(depositAsset)), ONE_HUNDRED);
    }

    function test_setFees_success_update_overwrite() external {
        vm.startPrank(governor);
        bitcoinRouter.setFees(address(depositAsset), newMintFeeA, newRedemptionFeeA);

        assertEq(bitcoinRouter.mintFee(address(depositAsset)),       newMintFeeA);
        assertEq(bitcoinRouter.redemptionFee(address(depositAsset)), newRedemptionFeeA);

        bitcoinRouter.setFees(address(depositAsset), newMintFeeB, newRedemptionFeeB);
        vm.stopPrank();

        assertEq(bitcoinRouter.mintFee(address(depositAsset)),       newMintFeeB);
        assertEq(bitcoinRouter.redemptionFee(address(depositAsset)), newRedemptionFeeB);
    }

    function test_setFees_success_PerAsset() external {
        vm.startPrank(governor);
        bitcoinRouter.setFees(address(depositAsset), newMintFeeA, newRedemptionFeeA);
        bitcoinRouter.setFees(depositAsset2,         newMintFeeB, newRedemptionFeeB);
        vm.stopPrank();

        assertEq(bitcoinRouter.mintFee(address(depositAsset)),       newMintFeeA);
        assertEq(bitcoinRouter.redemptionFee(address(depositAsset)), newRedemptionFeeA);

        assertEq(bitcoinRouter.mintFee(depositAsset2),       newMintFeeB);
        assertEq(bitcoinRouter.redemptionFee(depositAsset2), newRedemptionFeeB);
    }

    function test_setFees_success_setSameValues() external {
        vm.startPrank(governor);
        bitcoinRouter.setFees(address(depositAsset), newMintFeeA, newRedemptionFeeA);
        bitcoinRouter.setFees(address(depositAsset), newMintFeeA, newRedemptionFeeA);
        vm.stopPrank();

        assertEq(bitcoinRouter.mintFee(address(depositAsset)),       newMintFeeA);
        assertEq(bitcoinRouter.redemptionFee(address(depositAsset)), newRedemptionFeeA);
    }

}
