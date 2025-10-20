
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { Permit } from "../../../../contracts/interfaces/Interfaces.sol";
import { IBitcoinStrategy } from "../../../../contracts/interfaces/Interfaces.sol";

import { SyrupBtcFuzzBase } from "../SyrupBtcFuzzBase.t.sol";

contract SyrupBtcRequestRedeemFuzzTests is SyrupBtcFuzzBase {

    function testFuzz_requestRedeem(
      uint256 totalDeposited,
      uint256 depositorAssets,
      uint256 assetsToDeposit,
      uint256 sharesToRedeem,
      uint256[4] memory deployedAssets,
      uint256[4] memory defaultedAssets
    ) external {
        address depositor = makeAddr("depositor");

        totalDeposited  = bound(totalDeposited,  0, 1e30);
        depositorAssets = bound(depositorAssets, 1, 1e30);
        assetsToDeposit = bound(assetsToDeposit, 1, depositorAssets);

        deployedAssets  = _boundDeployedAssets(totalDeposited, deployedAssets);
        defaultedAssets = _boundDefaultedAssets(deployedAssets, defaultedAssets);

        ( , uint256 totalDefaulted ) = _setUpSyrupBtcState(totalDeposited, deployedAssets, defaultedAssets);

        vm.assume(totalDeposited > totalDefaulted);

        vm.startPrank(depositor);
        depositAsset.mint(depositor, depositorAssets);
        depositAsset.approve(address(bitcoinRouter), assetsToDeposit);
        bitcoinRouter.deposit(address(depositAsset), assetsToDeposit, "", Permit(false, 0, 0, 0, 0));
        vm.stopPrank();

        uint256 receivedShares = pool.balanceOf(depositor);
        sharesToRedeem         = bound(sharesToRedeem, 0, receivedShares);

        if (sharesToRedeem == 0) {
            vm.prank(depositor);
            vm.expectRevert("WM:AS:ZERO_SHARES");
            bitcoinRouter.requestRedeem(address(depositAsset), sharesToRedeem, "", Permit(false, 0, 0, 0, 0));
            return;
        } else {
            vm.startPrank(depositor);
            pool.approve(address(bitcoinRouter), sharesToRedeem);
            bitcoinRouter.requestRedeem(address(depositAsset), sharesToRedeem, "", Permit(false, 0, 0, 0, 0));
            vm.stopPrank();
        }

        assertEq(pool.balanceOf(depositor), receivedShares - sharesToRedeem);
        assertEq(pool.balanceOf(address(withdrawalManager)), sharesToRedeem);

        assertRequestOnRouter({
            requestId: 1,
            asset:     address(depositAsset),
            owner:     depositor,
            shares:    sharesToRedeem
        });

        assertRequestOnWm({
            requestId: 1,
            owner:     address(bitcoinRouter),
            shares:    sharesToRedeem
        });
    }

}
