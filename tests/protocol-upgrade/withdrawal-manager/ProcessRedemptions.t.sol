// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IWithdrawalManagerQueue } from "../../../contracts/interfaces/Interfaces.sol";

import { MapleWithdrawalManagerUpgradeBaseTest } from "./MapleWithdrawalManagerUpgradeBase.t.sol";

contract ProcessRedemptionsTests is MapleWithdrawalManagerUpgradeBaseTest {

    function testFork_processRedemptions_revert_zeroShares() external {
        vm.prank(operationalAdmin);
        vm.expectRevert("WM:PR:ZERO_SHARES");
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).processRedemptions(0);
    }

    function testFork_processRedemptions_revert_lowLiquidity() external {
        vm.prank(operationalAdmin);
        vm.expectRevert("WM:PR:LOW_LIQUIDITY");
        IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).processRedemptions(type(uint128).max);
    }

    function testFork_processRedemptions_success_multipleRequests() external {
        ( uint256 nextRequestId, ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();

        ( address owner1, uint256 shares1 ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);
        ( address owner2, uint256 shares2 ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId + 1);
        ( address owner3, uint256 shares3 ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId + 2);

        assertNotEq(owner1, address(0));
        assertEq(shares1, 1e6);

        assertEq(owner2, address(0));
        assertEq(shares2, 0);

        assertNotEq(owner3, address(0));
        assertEq(shares3, 4e6);

        uint256 sharesToProcess = 1.5e6;

        processRedemptions(syrupUSDCPool, sharesToProcess);

        uint256 expectedSharesLeftRequest3 = 3.5e6;

        ( owner1, shares1 ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);
        ( owner2, shares2 ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId + 1);
        ( owner3, shares3 ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId + 2);

        assertEq(owner1, address(0));
        assertEq(shares1, 0);

        assertEq(owner2, address(0));
        assertEq(shares2, 0);

        assertNotEq(owner3, address(0));
        assertEq(shares3, expectedSharesLeftRequest3);

        ( uint256 nextRequestIdAfter, ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();
        assertEq(nextRequestIdAfter, nextRequestId + 2);
    }

    function testFork_processRedemptions_success_processAllRequests() external {
        ( uint256 nextRequestId, ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();

        ( address owner1, uint256 shares1 ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);
        ( address owner2, uint256 shares2 ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId + 1);
        ( address owner3, uint256 shares3 ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId + 2);

        assertNotEq(owner1, address(0));
        assertEq(shares1, 1e6);

        assertEq(owner2, address(0));
        assertEq(shares2, 0);

        assertNotEq(owner3, address(0));
        assertEq(shares3, 4e6);

        uint256 sharesToProcess = 5e6;

        processRedemptions(syrupUSDCPool, sharesToProcess);

        ( owner1, shares1 ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);
        ( owner2, shares2 ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId + 1);
        ( owner3, shares3 ) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId + 2);

        assertEq(owner1, address(0));
        assertEq(owner2, address(0));
        assertEq(owner3, address(0));

        assertEq(shares1, 0);
        assertEq(shares2, 0);
        assertEq(shares3, 0);
    }

}
