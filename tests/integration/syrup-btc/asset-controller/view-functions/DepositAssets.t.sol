// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract DepositAssetsTests is SyrupBitcoinTestBase {

    function test_success_depositAssets_updatesOnDeposit() external {
        uint256 amount    = 1e8;
        address depositor = makeAddr("depositor");

        assertEq(assetController.depositAssets(address(depositAsset)), 0);

        depositAsset.mint(depositor, amount);

        vm.startPrank(depositor);
        depositAsset.approve(address(bitcoinRouter), amount);
        bitcoinRouter.deposit(address(depositAsset), amount, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();

        assertEq(assetController.depositAssets(address(depositAsset)),      amount);
        assertEq(depositAsset.balanceOf(depositor),                         0);
        assertEq(depositAsset.allowance(depositor, address(bitcoinRouter)), 0);
    }

    function test_success_depositAssets_updatesOnRedemption() external {
        uint256 amount    = 1e8;
        address depositor = makeAddr("redeemer");

        depositAsset.mint(depositor, amount);

        vm.startPrank(depositor);
        depositAsset.approve(address(bitcoinRouter), amount);
        uint256 shares = bitcoinRouter.deposit(address(depositAsset), amount, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();

        assertEq(assetController.depositAssets(address(depositAsset)), amount);

        vm.startPrank(depositor);
        pool.approve(address(bitcoinRouter), shares);
        ( uint256 lockedShares, uint256 requestId ) =
            bitcoinRouter.requestRedeem(address(depositAsset), shares, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();

        assertEq(lockedShares, shares);

        uint256[] memory requestIds = new uint256[](1);
        requestIds[0]               = requestId;

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(requestIds);

        vm.prank(poolDelegate);
        bitcoinRouter.processRedemptions(requestIds);

        assertEq(assetController.depositAssets(address(depositAsset)), 0);
        assertEq(depositAsset.balanceOf(depositor),                    amount);
    }

    function test_success_depositAssets_updatesOnDeploy() external {
        uint256 amount       = 2e8;
        uint256 deployAmount = amount / 3;
        address depositor    = makeAddr("depositor");

        depositAsset.mint(depositor, amount);

        vm.startPrank(depositor);
        depositAsset.approve(address(bitcoinRouter), amount);
        bitcoinRouter.deposit(address(depositAsset), amount, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();

        assertEq(assetController.depositAssets(address(depositAsset)), amount);

        vm.prank(strategyManager);
        bitcoinStrategy.deploy(address(depositAsset), deployAmount);

        assertEq(assetController.depositAssets(address(depositAsset)), amount - deployAmount);
        assertEq(depositAsset.balanceOf(strategyManager),              deployAmount);
    }

    function test_success_depositAssets_updatesOnReconcile() external {
        uint256 amount    = 1e8;
        address depositor = makeAddr("depositor");

        depositAsset.mint(depositor, amount);

        vm.startPrank(depositor);
        depositAsset.approve(address(bitcoinRouter), amount);
        bitcoinRouter.deposit(address(depositAsset), amount, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();

        vm.prank(strategyManager);
        bitcoinStrategy.deploy(address(depositAsset), amount);

        assertEq(assetController.depositAssets(address(depositAsset)), 0);
        assertEq(depositAsset.balanceOf(strategyManager),              amount);

        vm.startPrank(strategyManager);
        depositAsset.approve(address(bitcoinStrategy), amount);
        bitcoinStrategy.reconcile(address(depositAsset), amount);
        vm.stopPrank();

        assertEq(assetController.depositAssets(address(depositAsset)), amount);
        assertEq(depositAsset.balanceOf(strategyManager),              0);
    }

}
