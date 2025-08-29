// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { GovernorTimelockTestBase } from "./GovernorTimelockTestBase.t.sol";

contract WithdrawERC20TokenTests is GovernorTimelockTestBase {

    function test_withdrawERC20Token_revert_notTokenWithdrawer() public {
        vm.expectRevert("GT:WET:NOT_AUTHORIZED");
        timelock.withdrawERC20Token(address(collateralAsset), 100);
    }

    function test_withdrawERC20Token_success() public {
        uint256 balanceBefore    = 100e18;
        uint256 amountToWithdraw = 40e18;
        collateralAsset.mint(address(timelock), balanceBefore);

        vm.prank(governor);
        timelock.withdrawERC20Token(address(collateralAsset), amountToWithdraw);

        assertEq(collateralAsset.balanceOf(governor),          amountToWithdraw);
        assertEq(collateralAsset.balanceOf(address(timelock)), balanceBefore - amountToWithdraw);
    }

}
