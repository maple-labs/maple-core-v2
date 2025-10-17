// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { Permit } from "../../../../contracts/interfaces/Interfaces.sol";
import { IBitcoinStrategy } from "../../../../contracts/interfaces/Interfaces.sol";

import { SyrupBtcFuzzBase } from "../SyrupBtcFuzzBase.t.sol";

contract SyrupBtcDepositFuzzTests is SyrupBtcFuzzBase {

    function testFuzz_deposit(
      address depositor,
      uint256 totalDeposited,
      uint256 depositorAssets,
      uint256 assetsToDeposit,
      uint256[4] memory deployedAssets,
      uint256[4] memory defaultedAssets
    ) external {
        if (depositor == address(0)) depositor = address(1);

        vm.assume(depositor != address(pool) && depositor != address(this));

        totalDeposited  = bound(totalDeposited,  0, 1e30);
        depositorAssets = bound(depositorAssets, 1, 1e30);
        assetsToDeposit = bound(assetsToDeposit, 1, depositorAssets);

        deployedAssets  = _boundDeployedAssets(totalDeposited, deployedAssets);
        defaultedAssets = _boundDefaultedAssets(deployedAssets, defaultedAssets);

        ( , uint256 totalDefaulted ) = _setUpSyrupBtcState(totalDeposited, deployedAssets, defaultedAssets);

        vm.assume(totalDeposited > totalDefaulted);

        assertEq(pool.totalAssets(),        totalDeposited - totalDefaulted);
        assertEq(pool.totalSupply(),        totalDeposited);
        assertEq(pool.balanceOf(depositor), 0);

        vm.startPrank(depositor);
        depositAsset.mint(depositor, depositorAssets);
        depositAsset.approve(address(bitcoinRouter), assetsToDeposit);
        bitcoinRouter.deposit(address(depositAsset), assetsToDeposit, "", Permit(false, 0, 0, 0, 0));
        vm.stopPrank();

        uint256 totalAssetsBeforeDeposit = totalDeposited - totalDefaulted;
        uint256 expectedShares           = assetsToDeposit * totalDeposited / totalAssetsBeforeDeposit;

        assertEq(pool.totalAssets(),                totalAssetsBeforeDeposit + assetsToDeposit);
        assertEq(pool.totalSupply(),                totalDeposited + expectedShares);
        assertEq(pool.balanceOf(depositor),         expectedShares);
        assertEq(depositAsset.balanceOf(depositor), depositorAssets - assetsToDeposit);
    }

}
