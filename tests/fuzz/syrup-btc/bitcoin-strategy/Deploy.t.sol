// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IBitcoinStrategy } from "../../../../contracts/interfaces/Interfaces.sol";

import { SyrupBtcFuzzBase } from "../SyrupBtcFuzzBase.t.sol";

contract SyrupBtcDepositFuzzTests is SyrupBtcFuzzBase {

    function testFuzz_deploy(
      uint256 totalDeposited,
      uint256 strategyIndex,
      uint256 assetsToDeploy,
      uint256[4] memory deployedAssets,
      uint256[4] memory defaultedAssets
    ) external {
        strategyIndex   = bound(strategyIndex,  0, 3);
        totalDeposited  = bound(totalDeposited, 1, type(uint256).max);

        deployedAssets  = _boundDeployedAssets(totalDeposited, deployedAssets);
        defaultedAssets = _boundDefaultedAssets(deployedAssets, defaultedAssets);

        ( uint256 totalDeployed, ) = _setUpSyrupBtcState(totalDeposited, deployedAssets, defaultedAssets);

        assetsToDeploy = bound(assetsToDeploy, 0, totalDeposited - totalDeployed);

        address targetStrategy = poolManager.strategyList(strategyIndex);

        if (assetsToDeploy == 0) {
            vm.prank(strategyManager);
            vm.expectRevert("MBS:D:ZERO_AMOUNT");
            IBitcoinStrategy(targetStrategy).deploy(address(depositAsset), assetsToDeploy);
        } else { 
            uint256 totalAssetsBefore = pool.totalAssets();
            uint256 strategyAumBefore = IBitcoinStrategy(targetStrategy).assetsUnderManagement();

            vm.prank(strategyManager);
            IBitcoinStrategy(targetStrategy).deploy(address(depositAsset), assetsToDeploy);

            assertEq(pool.totalAssets(),                                       totalAssetsBefore);
            assertEq(IBitcoinStrategy(targetStrategy).assetsUnderManagement(), strategyAumBefore + assetsToDeploy);
        }
    }

}
