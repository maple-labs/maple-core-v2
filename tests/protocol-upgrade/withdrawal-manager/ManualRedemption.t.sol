// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC20, IPool, IWithdrawalManagerQueue } from "../../../contracts/interfaces/Interfaces.sol";

import { MapleWithdrawalManagerUpgradeBaseTest } from "./MapleWithdrawalManagerUpgradeBase.t.sol";

contract ManualRedemptionTests is MapleWithdrawalManagerUpgradeBaseTest {

    function testFork_manualRedemption_revert_notPoolManager() external {
        vm.expectRevert("WM:NOT_PM");
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).processExit(1, address(0));
    }

    function testFork_manualRedemption_success() external {
        (uint256 nextRequestId, )         = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();
        ( address owner, uint256 shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);

        assertNotEq(owner, address(0));
        assertEq(shares, 1e6);

        uint256 ownerBalanceBefore = IERC20(USDC).balanceOf(owner);
        uint256 expectedToReceive  = IPool(syrupUSDCPool).convertToExitAssets(shares);

        vm.prank(operationalAdmin);
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).setManualWithdrawal(owner, true);

        vm.prank(operationalAdmin);
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).processRedemptions(shares);

        assertEq(IERC20(USDC).balanceOf(owner), ownerBalanceBefore);

        ( address ownerAfter, uint256 sharesAfter ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);

        assertEq(ownerAfter,  address(0));
        assertEq(sharesAfter, 0);

        assertEq(IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).manualSharesAvailable(owner), shares);

        vm.prank(owner);
        IPool(syrupUSDCPool).redeem(shares, owner, owner);

        assertEq(IERC20(USDC).balanceOf(owner), ownerBalanceBefore + expectedToReceive);

        assertEq(IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).manualSharesAvailable(owner), 0);
    }

}
