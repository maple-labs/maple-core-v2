
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IBitcoinStrategy } from "../../../../contracts/interfaces/Interfaces.sol";

import { SyrupBtcFuzzBase } from "../SyrupBtcFuzzBase.t.sol";

contract SyrupBtcReconcileFuzzTests is SyrupBtcFuzzBase {

    function testFuzz_reconcile(
      uint256 totalDeposited,
      uint256 strategyIndex,
      uint256 assetsToReconcile,
      uint256[4] memory deployedAssets,
      uint256[4] memory defaultedAssets
    ) external {
        strategyIndex   = bound(strategyIndex,  0, 3);
        totalDeposited  = bound(totalDeposited, 1, type(uint256).max);

        deployedAssets  = _boundDeployedAssets(totalDeposited, deployedAssets);
        defaultedAssets = _boundDefaultedAssets(deployedAssets, defaultedAssets);

        _setUpSyrupBtcState(totalDeposited, deployedAssets, defaultedAssets);

        address targetStrategy = poolManager.strategyList(strategyIndex);

        assetsToReconcile = bound(assetsToReconcile, 0, deployedAssets[strategyIndex] - defaultedAssets[strategyIndex]);

        if (assetsToReconcile == 0) {
            vm.prank(strategyManager);
            vm.expectRevert("MBS:R:ZERO_AMOUNT");
            IBitcoinStrategy(targetStrategy).reconcile(address(depositAsset), assetsToReconcile);
        } else {
            uint256 totalAssetsBefore = pool.totalAssets();
            uint256 strategyAumBefore = IBitcoinStrategy(targetStrategy).assetsUnderManagement();

            vm.startPrank(strategyManager);
            depositAsset.approve(targetStrategy, assetsToReconcile);
            IBitcoinStrategy(targetStrategy).reconcile(address(depositAsset), assetsToReconcile);
            vm.stopPrank();

            assertEq(pool.totalAssets(),                                       totalAssetsBefore);
            assertEq(IBitcoinStrategy(targetStrategy).assetsUnderManagement(), strategyAumBefore - assetsToReconcile);
        }
    }

}
