// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IPool, IWithdrawalManagerQueue } from "../../../contracts/interfaces/Interfaces.sol";

import { MapleWithdrawalManagerUpgradeBaseTest } from "./MapleWithdrawalManagerUpgradeBase.t.sol";

contract RequestRedeemTests is MapleWithdrawalManagerUpgradeBaseTest {

    function testFork_requestRedeem_revert_zeroShares() external {
        address user = makeAddr("user");

        vm.prank(user);
        vm.expectRevert("WM:AS:ZERO_SHARES");
        IPool(syrupUSDCPool).requestRedeem(0, user);
    }

    function testFork_requestRedeem_success() external {
        address user           = makeAddr("user");
        uint256 depositAmount  = 3e6;
        uint256 sharesToRedeem = 1e6;

        deposit(syrupUSDCPool, user, depositAmount);

        ( , uint256 lastRequestId ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();

        requestRedeem(syrupUSDCPool, user, sharesToRedeem);

        ( , uint256 lastRequestIdAfter ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();

        assertEq(lastRequestIdAfter, lastRequestId + 1);

        ( address owner, uint256 shares ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(lastRequestIdAfter);

        assertEq(owner,  user);
        assertEq(shares, sharesToRedeem);
    }

}
