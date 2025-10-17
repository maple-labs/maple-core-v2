
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IBitcoinStrategy, Permit } from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract SyrupBtcFuzzBase is TestBaseWithAssertions {

    function setUp() public override {
        _setupBitcoinPool();
    }

    function _setUpSyrupBtcState(
        uint256 totalDeposited,
        uint256[4] memory deployedAssets,
        uint256[4] memory defaultedAssets
    ) internal returns (uint256 totalDeployed, uint256 totalDefaulted) {
        if (totalDeposited == 0) return (0, 0);

        depositAsset.mint(address(this), totalDeposited);
        depositAsset.approve(address(bitcoinRouter), totalDeposited);
        bitcoinRouter.deposit(address(depositAsset), totalDeposited, "", Permit(false, 0, 0, 0, 0));

        for (uint256 i; i < deployedAssets.length; i++) {
            if (deployedAssets[i] != 0) {
                address strategy     = poolManager.strategyList(i);
                uint256 deployAmount = deployedAssets[i];

                vm.prank(strategyManager);
                IBitcoinStrategy(strategy).deploy(address(depositAsset), deployAmount);

                totalDeployed += deployAmount;
            }
        }

        for (uint256 i; i < defaultedAssets.length; i++) {
            if (defaultedAssets[i] != 0) {
                address strategy      = poolManager.strategyList(i);
                uint256 defaultAmount = defaultedAssets[i];

                vm.prank(governor);
                IBitcoinStrategy(strategy).setDefault(defaultAmount);

                totalDefaulted += defaultAmount;
            }
        }

        assertEq(pool.totalAssets(),                               totalDeposited - totalDefaulted);
        assertEq(pool.totalSupply(),                               totalDeposited);
        assertEq(pool.balanceOf(address(this)),                    totalDeposited);
        assertEq(compositeAsset.balanceOf(address(pool)),          totalDeposited - totalDeployed);
        assertEq(depositAsset.balanceOf(address(this)),            0);
        assertEq(depositAsset.balanceOf(address(assetController)), totalDeposited - totalDeployed);
        assertEq(depositAsset.balanceOf(strategyManager),          totalDeployed);

        for (uint256 i; i < deployedAssets.length; i++) {
            address strategy        = poolManager.strategyList(i);
            uint256 deployedAmount  = deployedAssets[i];
            uint256 defaultedAmount = defaultedAssets[i];

            assertEq(IBitcoinStrategy(strategy).assetsUnderManagement(), deployedAmount - defaultedAmount);
        }
    }

    function _boundDeployedAssets(
        uint256 totalDeposited,
        uint256[4] memory deployedAssets
    ) internal pure returns (uint256[4] memory boundedDeployedAssets) {
        uint256 maxToDeploy = totalDeposited;

        for (uint256 i = 0; i < deployedAssets.length; i++) {
            boundedDeployedAssets[i] = bound(deployedAssets[i], 0, maxToDeploy);
            maxToDeploy             -= boundedDeployedAssets[i];
        }
    }

    function _boundDefaultedAssets(
        uint256[4] memory deployedAssets,
        uint256[4] memory defaultedAssets
    ) internal pure returns (uint256[4] memory boundedDefaultedAssets) {
        for (uint256 i = 0; i < deployedAssets.length; i++) {
            boundedDefaultedAssets[i] = bound(defaultedAssets[i], 0, deployedAssets[i]);
        }
    }

}
