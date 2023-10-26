// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { TestBase } from "../TestBase.sol";

contract PreviewRedeemTests is TestBase {

    address lender = makeAddr("lender");

    uint256 shares = 1_000e6;

    function setUp() public override virtual {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createPoolWithQueue();
        _configurePool();

        openPool(address(poolManager));
        deposit(lender, shares);

        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lender, true);

        vm.prank(lender);
        pool.requestRedeem(shares, lender);

        vm.prank(poolDelegate);
        queueWM.processRedemptions(shares);
    }

    function test_previewRedeem_insufficientShares() external {
        vm.prank(lender);
        vm.expectRevert("WM:PR:TOO_MANY_SHARES");
        pool.previewRedeem(shares + 1);
    }

    function test_previewRedeem_emptyRedemption_fullLiquidity() external {
        // Set the exchange rate to 1:2
        fundsAsset.mint(address(pool), shares);

        vm.prank(lender);
        uint256 assets = pool.previewRedeem(0);

        assertEq(assets, 0);
    }

    function test_previewRedeem_partialRedemption_fullLiquidity() external {
        // Set the exchange rate to 1:2
        fundsAsset.mint(address(pool), shares);

        vm.prank(lender);
        uint256 assets = pool.previewRedeem(shares * 3 / 4);

        assertEq(assets, shares * 6 / 4);
    }

    function test_previewRedeem_fullRedemption_fullLiquidity() external {
        // Set the exchange rate to 1:2
        fundsAsset.mint(address(pool), shares);

        vm.prank(lender);
        uint256 assets = pool.previewRedeem(shares);

        assertEq(assets, shares * 2);
    }

    function test_previewRedeem_emptyRedemption_partialLiquidity() external {
        // Set the exchange rate to 2:1
        fundsAsset.burn(address(pool), shares / 2);

        vm.prank(lender);
        uint256 assets = pool.previewRedeem(0);

        assertEq(assets, 0);
    }

    function test_previewRedeem_partialRedemption_partialLiquidity() external {
        // Set the exchange rate to 2:1
        fundsAsset.burn(address(pool), shares / 2);

        vm.prank(lender);
        uint256 assets = pool.previewRedeem(shares * 3 / 4);

        assertEq(assets, shares * 3 / 8);
    }

    function test_previewRedeem_fullRedemption_partialLiquidity() external {
        // Set the exchange rate to 2:1
        fundsAsset.burn(address(pool), shares / 2);

        vm.prank(lender);
        uint256 assets = pool.previewRedeem(shares);

        assertEq(assets, shares / 2);
    }

}

contract AutomatedPreviewRedeemTests is TestBase {

    address lender = makeAddr("lender");

    uint256 shares = 1_000e6;

    function setUp() public override virtual {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createPoolWithQueue();
        _configurePool();

        openPool(address(poolManager));
        deposit(lender, shares);

        vm.prank(lender);
        pool.requestRedeem(shares, lender);
    }

    function testFuzz_previewRedeem_notProcessed(uint256 sharesToRedeem) external {
        vm.prank(lender);
        uint256 assets = pool.previewRedeem(sharesToRedeem);

        assertEq(assets, 0);
    }

    function testFuzz_previewRedeem_processed(uint256 sharesToRedeem) external {
        vm.prank(poolDelegate);
        queueWM.processRedemptions(shares);

        vm.prank(lender);
        uint256 assets = pool.previewRedeem(sharesToRedeem);

        assertEq(assets, 0);
    }

}
