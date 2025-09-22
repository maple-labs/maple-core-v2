// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract PoolAssetsTests is SyrupBitcoinTestBase {

    function test_poolAssets_success() external {
        uint256 amount    = 1e8;
        address depositor = makeAddr("depositor");

        assertEq(assetController.poolAssets(address(depositAsset)), 0);

        depositAsset.mint(depositor, amount);

        vm.startPrank(depositor);
        depositAsset.approve(address(bitcoinRouter), amount);
        bitcoinRouter.deposit(address(depositAsset), amount, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();

        assertEq(assetController.poolAssets(address(depositAsset)),         amount);
        assertEq(depositAsset.allowance(depositor, address(bitcoinRouter)), 0);
    }

}
