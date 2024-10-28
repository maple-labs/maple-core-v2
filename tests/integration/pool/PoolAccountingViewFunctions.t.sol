// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../../TestBase.sol";

contract BalanceOfAssetsTests is TestBase {

    address lp1;
    address lp2;

    function setUp() public override {
        super.setUp();

        lp1 = makeAddr("lp1");
        lp2 = makeAddr("lp2");
    }

    function test_balanceOfAssets() external {
        deposit(lp1, 1_000e6);

        assertEq(pool.balanceOfAssets(lp1), 1_000e6);
        assertEq(pool.balanceOfAssets(lp2), 0);

        deposit(lp2, 3_000e6);

        assertEq(pool.balanceOfAssets(lp1), 1_000e6);
        assertEq(pool.balanceOfAssets(lp2), 3_000e6);

        fundsAsset.mint(address(pool), 4_000e6);  // Double totalAssets

        assertEq(pool.balanceOfAssets(lp1), 2_000e6);
        assertEq(pool.balanceOfAssets(lp2), 6_000e6);
    }

    function testDeepFuzz_balanceOfAssets(uint256 depositAmount1, uint256 depositAmount2, uint256 additionalAmount) external {
        depositAmount1   = bound(depositAmount1,   1, 1e29);
        depositAmount2   = bound(depositAmount2,   1, 1e29);
        additionalAmount = bound(additionalAmount, 1, 1e29);

        uint256 totalDeposits = depositAmount1 + depositAmount2;

        deposit(lp1, depositAmount1);

        assertEq(pool.balanceOfAssets(lp1), depositAmount1);
        assertEq(pool.balanceOfAssets(lp2), 0);

        deposit(lp2, depositAmount2);

        assertEq(pool.balanceOfAssets(lp1), depositAmount1);
        assertEq(pool.balanceOfAssets(lp2), depositAmount2);

        fundsAsset.mint(address(pool), additionalAmount);

        assertEq(pool.balanceOfAssets(lp1), depositAmount1 + additionalAmount * depositAmount1 / totalDeposits);
        assertEq(pool.balanceOfAssets(lp2), depositAmount2 + additionalAmount * depositAmount2 / totalDeposits);
    }

}

// TODO: Update to use new permissioning
contract MaxDepositTests is TestBase {

    address lp1;
    address lp2;

    function setUp() public override {
        start = block.timestamp;
        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createAndConfigurePool(start, 1 weeks, 2 days);

        lp1 = makeAddr("lp1");
        lp2 = makeAddr("lp2");
    }

    function test_maxDeposit_closedPool() external {
        vm.prank(poolDelegate);
        poolManager.setLiquidityCap(1_000e6);

        assertEq(pool.maxDeposit(lp1), 0);
        assertEq(pool.maxDeposit(lp2), 0);

        allowLender(address(poolManager), lp1);

        assertEq(pool.maxDeposit(lp1), 1_000e6);
        assertEq(pool.maxDeposit(lp2), 0);

        openPool(address(poolManager));

        assertEq(pool.maxDeposit(lp1), 1_000e6);
        assertEq(pool.maxDeposit(lp2), 1_000e6);
    }

    function test_maxDeposit_totalAssetsIncrease() external {
        vm.prank(poolDelegate);
        poolManager.setLiquidityCap(1_000e6);

        openPool(address(poolManager));

        assertEq(pool.maxDeposit(lp1), 1_000e6);
        assertEq(pool.maxDeposit(lp2), 1_000e6);

        fundsAsset.mint(address(pool), 400e6);

        assertEq(pool.maxDeposit(lp1), 600e6);
        assertEq(pool.maxDeposit(lp2), 600e6);
    }

    function testDeepFuzz_maxDeposit_totalAssetsIncrease(uint256 liquidityCap, uint256 totalAssets) external {
        liquidityCap = bound(liquidityCap, 1, 1e29);
        totalAssets  = bound(totalAssets,  1, 1e29);

        uint256 availableDeposit = liquidityCap > totalAssets ? liquidityCap - totalAssets : 0;

        vm.startPrank(poolDelegate);
        poolManager.setLiquidityCap(liquidityCap);
        openPool(address(poolManager));

        assertEq(pool.maxDeposit(lp1), liquidityCap);
        assertEq(pool.maxDeposit(lp2), liquidityCap);

        fundsAsset.mint(address(pool), totalAssets);

        assertEq(pool.maxDeposit(lp1), availableDeposit);
        assertEq(pool.maxDeposit(lp2), availableDeposit);
    }

}

contract MaxMintTests is TestBase {

    address lp1;
    address lp2;

    function setUp() public override {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createAndConfigurePool(start, 1 weeks, 2 days);

        lp1 = makeAddr("lp1");
        lp2 = makeAddr("lp2");
    }

    function test_maxMint_closedPool() external {
        vm.prank(poolDelegate);
        poolManager.setLiquidityCap(1_000e6);

        assertEq(pool.maxMint(lp1), 0);
        assertEq(pool.maxMint(lp2), 0);

        allowLender(address(poolManager), lp1);

        assertEq(pool.maxMint(lp1), 1_000e6);
        assertEq(pool.maxMint(lp2), 0);

        openPool(address(poolManager));

        assertEq(pool.maxMint(lp1), 1_000e6);
        assertEq(pool.maxMint(lp2), 1_000e6);
    }

    function test_maxMint_totalAssetsIncrease() external {
        vm.prank(poolDelegate);
        poolManager.setLiquidityCap(1_000e6);

        openPool(address(poolManager));

        assertEq(pool.maxMint(lp1), 1_000e6);
        assertEq(pool.maxMint(lp2), 1_000e6);

        fundsAsset.mint(address(pool), 400e6);

        assertEq(pool.maxMint(lp1), 600e6);
        assertEq(pool.maxMint(lp2), 600e6);
    }

    function testDeepFuzz_maxMint_totalAssetsIncrease(uint256 liquidityCap, uint256 totalAssets) external {
        liquidityCap = bound(liquidityCap, 1, 1e29);
        totalAssets  = bound(totalAssets,  1, 1e29);

        uint256 availableDeposit = liquidityCap > totalAssets ? liquidityCap - totalAssets : 0;

        vm.startPrank(poolDelegate);
        poolManager.setLiquidityCap(liquidityCap);
        openPool(address(poolManager));

        assertEq(pool.maxMint(lp1), liquidityCap);
        assertEq(pool.maxMint(lp2), liquidityCap);

        fundsAsset.mint(address(pool), totalAssets);

        assertEq(pool.maxMint(lp1), availableDeposit);
        assertEq(pool.maxMint(lp2), availableDeposit);
    }

    function test_maxMint_exchangeRateGtOne() external {
        vm.prank(poolDelegate);
        poolManager.setLiquidityCap(10_000e6);

        openPool(address(poolManager));

        deposit(lp1, 1_000e6);

        assertEq(pool.maxMint(lp1), 9_000e6);
        assertEq(pool.maxMint(lp2), 9_000e6);

        fundsAsset.mint(address(pool), 1_000e6);  // Double totalAssets.

        assertEq(pool.maxMint(lp1), 4_000e6);  // totalAssets = 2000, 8000 of room at 2:1
        assertEq(pool.maxMint(lp2), 4_000e6);
    }

    function testDeepFuzz_maxMint_exchangeRateGtOne(uint256 liquidityCap, uint256 depositAmount, uint256 transferAmount) external {
        liquidityCap   = bound(liquidityCap,   1, 1e29);
        depositAmount  = bound(depositAmount,  1, liquidityCap);
        transferAmount = bound(transferAmount, 1, 1e29);

        vm.prank(poolDelegate);
        poolManager.setLiquidityCap(liquidityCap);

        openPool(address(poolManager));

        deposit(lp1, depositAmount);

        uint256 availableDeposit = liquidityCap > depositAmount ? liquidityCap - depositAmount : 0;

        assertEq(pool.maxMint(lp1), availableDeposit);
        assertEq(pool.maxMint(lp2), availableDeposit);

        fundsAsset.mint(address(pool), transferAmount);

        uint256 totalAssets = depositAmount + transferAmount;

        availableDeposit = liquidityCap > totalAssets ? liquidityCap - totalAssets : 0;

        assertEq(pool.maxMint(lp1), availableDeposit * depositAmount / totalAssets);
        assertEq(pool.maxMint(lp2), availableDeposit * depositAmount / totalAssets);
    }

}

contract MaxRedeemTests is TestBase {

    address lp;

    function setUp() public override {
        super.setUp();

        lp = makeAddr("lp");
    }

    function test_maxRedeem_noLockedShares_notInExitWindow() external {
        deposit(lp, 1_000e6);

        assertEq(pool.balanceOf(lp), 1_000e6);

        assertTrue(!cyclicalWM.isInExitWindow(lp));

        assertEq(pool.maxRedeem(lp), 0);
    }

    function test_maxRedeem_lockedShares_notInExitWindow() external {
        deposit(lp, 1_000e6);

        assertEq(pool.balanceOf(lp), 1_000e6);

        vm.prank(lp);
        pool.requestRedeem(1_000e6, lp);

        vm.warp(start + 2 weeks - 1);

        assertTrue(!cyclicalWM.isInExitWindow(lp));

        assertEq(pool.maxRedeem(lp), 0);
    }

    function test_maxRedeem_lockedShares_inExitWindow() external {
        deposit(lp, 1_000e6);

        assertEq(pool.balanceOf(lp), 1_000e6);

        vm.prank(lp);
        uint256 shares = pool.requestRedeem(1_000e6, lp);

        assertEq(shares, 1_000e6);
        assertEq(pool.maxRedeem(lp), 0);

        vm.warp(start + 2 weeks);

        assertTrue(cyclicalWM.isInExitWindow(lp));

        assertEq(pool.maxRedeem(lp), shares);
    }

}

contract MaxRedeemWMQueueTests is TestBase {

    address lp1;
    address lp2;
    address wm;

    uint256 maxShares;

    function setUp() public override {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _createFactories();
        _createPoolWithQueue();
        _configurePool();

        openPool(address(poolManager));

        lp1 = makeAddr("lp1");
        lp2 = makeAddr("lp2");

        wm = address(queueWM);

        deposit(lp1, 1_000e6);
        deposit(lp2, 1_000e6);

        fundsAsset.mint(address(pool), 2_000e6);

        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lp1, true);

        requestRedeem(lp1, 1_000e6);
        requestRedeem(lp2, 1_000e6);
    }

    function test_maxRedeem_beforeRedeem() external {
        maxShares = pool.maxRedeem(lp1);

        assertEq(maxShares, 0);
    }

    function test_maxRedeem_afterPartialRedeem() external {
        vm.prank(poolDelegate);
        queueWM.processRedemptions(1_000e6 / 2);

        maxShares = pool.maxRedeem(lp1);

        assertEq(maxShares, 1_000e6 / 2);
    }

    function test_maxRedeem_afterFullRedeem() external {
        vm.prank(poolDelegate);
        queueWM.processRedemptions(1_000e6);

        maxShares = pool.maxRedeem(lp1);

        assertEq(maxShares, 1_000e6);
    }

    function test_maxRedeem_afterPartialManualRedeem() external {
        vm.prank(poolDelegate);
        queueWM.processRedemptions(1_000e6);

        redeem(address(pool), lp1, 1_000e6 / 2);

        maxShares = pool.maxRedeem(lp1);

        assertEq(maxShares, 1_000e6 / 2);
    }

    function test_maxRedeem_afterFullManualRedeem() external {
        vm.prank(poolDelegate);
        queueWM.processRedemptions(1_000e6);

        redeem(address(pool), lp1, 1_000e6);

        maxShares = pool.maxRedeem(lp1);

        assertEq(maxShares, 0);
    }

    function test_maxRedeem_notManual() external {
        vm.prank(poolDelegate);
        queueWM.processRedemptions(2_000e6);

        maxShares = pool.maxRedeem(lp2);

        assertEq(maxShares, 0);
    }

}

contract MaxWithdrawTests is TestBase {

    address lp;

    function setUp() public override {
        super.setUp();

        lp = makeAddr("lp");
    }

    function test_maxWithdraw_noLockedShares_notInExitWindow() external {
        deposit(lp, 1_000e6);

        assertEq(pool.balanceOf(lp), 1_000e6);

        assertTrue(!cyclicalWM.isInExitWindow(lp));

        assertEq(pool.maxWithdraw(lp), 0);
    }

    function test_maxWithdraw_lockedShares_notInExitWindow() external {
        deposit(lp, 1_000e6);

        assertEq(pool.balanceOf(lp), 1_000e6);

        vm.prank(lp);
        pool.requestRedeem(1_000e6, lp);

        vm.warp(start + 2 weeks - 1);

        assertTrue(!cyclicalWM.isInExitWindow(lp));

        assertEq(pool.maxWithdraw(lp), 0);
    }

    function test_maxWithdraw_lockedShares_inExitWindow() external {
        deposit(lp, 1_000e6);

        assertEq(pool.balanceOf(lp), 1_000e6);

        vm.prank(lp);
        pool.requestRedeem(1_000e6, lp);

        assertEq(pool.maxWithdraw(lp), 0);

        vm.warp(start + 2 weeks);

        assertTrue(cyclicalWM.isInExitWindow(lp));

        assertEq(pool.maxWithdraw(lp), 0);
    }

    function testDeepFuzz_maxWithdraw_lockedShares_inExitWindow(uint256 assets_) external {
        assets_ = bound(assets_, 1, 1_000e6);

        deposit(lp, assets_);

        assertEq(pool.balanceOf(lp), assets_);

        vm.prank(lp);
        pool.requestRedeem(assets_, lp);

        assertEq(pool.maxWithdraw(lp), 0);

        vm.warp(start + 2 weeks);

        assertTrue(cyclicalWM.isInExitWindow(lp));

        assertEq(pool.maxWithdraw(lp), 0);
    }

}

contract PreviewRedeemTests is TestBase {

    address lp;

    function setUp() public override {
        super.setUp();

        lp = makeAddr("lp");
    }

    function test_previewRedeem_invalidShares() external {
        deposit(lp, 1_000e6);

        vm.startPrank(lp);
        pool.requestRedeem(1_000e6, lp);

        assertEq(pool.previewRedeem(1), 0);
    }

    function test_previewRedeem_noLockedShares_notInExitWindow() external {
        vm.prank(lp);
        assertEq(pool.previewRedeem(0), 0);
    }

    function test_previewRedeem_lockedShares_notInExitWindow() external {
        deposit(lp, 1_000e6);

        vm.startPrank(lp);
        pool.requestRedeem(1_000e6, lp);

        vm.warp(start + 2 weeks - 1);

        assertEq(pool.previewRedeem(1_000e6), 0);
    }

    function test_previewRedeem_lockedShares_inExitWindow() external {
        deposit(lp, 1_000e6);

        vm.startPrank(lp);
        pool.requestRedeem(1_000e6, lp);

        vm.warp(start + 2 weeks);

        assertEq(pool.previewRedeem(1_000e6), 1_000e6);
    }

}

contract PreviewRedeemWithQueueWMTests is TestBase {

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

contract AutomatedPreviewRedeemWithQueueWMTests is TestBase {

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

contract PreviewWithdrawTests is TestBase {

    address lp;

    function setUp() public override {
        super.setUp();

        lp = makeAddr("lp");
    }

    function test_previewWithdraw() external {
        deposit(lp, 1_000e6);

        vm.prank(lp);
        assertEq(pool.previewWithdraw(1_000e6), 0);
    }

    function test_previewWithdraw_zeroAssetsWithDeposit() external {
        deposit(lp, 1_000e6);

        vm.prank(lp);
        assertEq(pool.previewWithdraw(0), 0);
    }

    function test_previewWithdraw_zeroAssetsWithoutDeposit() external {
        vm.prank(lp);
        assertEq(pool.previewWithdraw(0), 0);
    }

    function testDeepFuzz_previewWithdraw_lockedShares_notInExitWindow(uint256 assets_) external {
        assets_ = bound(assets_, 1, 1_000e6);

        deposit(lp, assets_);

        vm.startPrank(lp);
        pool.requestRedeem(assets_, lp);

        vm.warp(start + 2 weeks - 1);

        assertEq(pool.previewWithdraw(assets_), 0);
    }

    function testDeepFuzz_previewWithdraw_lockedShares_inExitWindow(uint256 assets_) external {
        assets_ = bound(assets_, 1, 1_000e6);

        deposit(lp, assets_);

        vm.startPrank(lp);
        pool.requestRedeem(assets_, lp);

        vm.warp(start + 2 weeks);

        assertEq(pool.previewWithdraw(assets_), 0);
    }

    function testDeepFuzz_previewWithdraw(uint256 assets_) external {
        vm.prank(lp);
        assertEq(pool.previewWithdraw(assets_), 0);
    }

}

contract PreviewWithdrawWithQueueWMTests is TestBase {

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
    }

    function testFuzz_previewWithdraw(
        address lender,
        bool    isManual,
        uint256 amountToRequest,
        uint256 amountToProcess,
        uint256 amountToWithdraw
    )
        external
    {
        vm.assume(lender != address(0));

        amountToRequest = bound(amountToRequest,  0, 1e30);
        amountToProcess = bound(amountToProcess,  0, amountToRequest);

        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lender, isManual);

        if (amountToRequest > 0) {
            deposit(lender, amountToRequest);

            vm.prank(lender);
            pool.requestRedeem(amountToRequest, lender);
        }

        if (amountToProcess > 0) {
            vm.prank(poolDelegate);
            queueWM.processRedemptions(amountToProcess);
        }

        vm.prank(lender);
        uint256 sharesToBurn = pool.previewWithdraw(amountToWithdraw);

        assertEq(sharesToBurn, 0);
    }

}

contract ConvertToAssetsTests is TestBase {

    address lp1;
    address lp2;
    address lp3;

    function setUp() public override {
        super.setUp();

        lp1 = makeAddr("lp1");
        lp2 = makeAddr("lp2");
        lp3 = makeAddr("lp3");
    }

    function test_convertToAssets_zeroTotalSupply() external {
        assertEq(pool.convertToAssets(1),       1);
        assertEq(pool.convertToAssets(2),       2);
        assertEq(pool.convertToAssets(1_000e6), 1_000e6);
    }

    function test_convertToAssets_singleUser() external {
        deposit(lp1, 1_000e6);

        assertEq(pool.convertToAssets(1),       1);
        assertEq(pool.convertToAssets(2),       2);
        assertEq(pool.convertToAssets(1_000e6), 1_000e6);
    }

    function test_convertToAssets_multipleUsers() external {
        deposit(lp1, 1_000e6);
        deposit(lp2, 1_000e6);
        deposit(lp3, 1_000e6);

        assertEq(pool.convertToAssets(1),       1);
        assertEq(pool.convertToAssets(2),       2);
        assertEq(pool.convertToAssets(1_000e6), 1_000e6);
    }

    function test_convertToAssets_multipleUsers_changeTotalAssets() external {
        deposit(lp1, 1_000e6);
        deposit(lp2, 1_000e6);
        deposit(lp3, 1_000e6);

        vm.prank(address(pool));
        fundsAsset.transfer(address(0), 1_500e6);  // Simulate loss of 50% of funds

        assertEq(pool.convertToAssets(1),       0);      // Rounds down as expected
        assertEq(pool.convertToAssets(2),       1);
        assertEq(pool.convertToAssets(1_000e6), 500e6);
    }

}

contract ConvertToSharesTests is TestBase {

    address lp1;
    address lp2;
    address lp3;

    function setUp() public override {
        super.setUp();

        lp1 = makeAddr("lp1");
        lp2 = makeAddr("lp2");
        lp3 = makeAddr("lp3");
    }

    function test_convertToShares_zeroTotalSupply() external {
        assertEq(pool.convertToShares(1),       1);
        assertEq(pool.convertToShares(2),       2);
        assertEq(pool.convertToShares(1_000e6), 1_000e6);
    }

    function test_convertToShares_singleUser() external {
        deposit(lp1, 1_000e6);

        assertEq(pool.convertToShares(1),       1);
        assertEq(pool.convertToShares(2),       2);
        assertEq(pool.convertToShares(1_000e6), 1_000e6);
    }

    function test_convertToShares_multipleUsers() external {
        deposit(lp1, 1_000e6);
        deposit(lp2, 1_000e6);
        deposit(lp3, 1_000e6);

        assertEq(pool.convertToShares(1),       1);
        assertEq(pool.convertToShares(2),       2);
        assertEq(pool.convertToShares(1_000e6), 1_000e6);
    }

    function test_convertToShares_multipleUsers_changeTotalAssets() external {
        deposit(lp1, 1_000e6);
        deposit(lp2, 1_000e6);
        deposit(lp3, 1_000e6);

        vm.prank(address(pool));
        fundsAsset.transfer(address(0), 1_500e6);  // Simulate loss of 50% of funds

        assertEq(pool.convertToShares(1),       2);
        assertEq(pool.convertToShares(2),       4);
        assertEq(pool.convertToShares(1_000e6), 2_000e6);
    }

}

contract PreviewDepositTests is TestBase {

    address lp1;
    address lp2;
    address lp3;

    function setUp() public override {
        super.setUp();

        lp1 = makeAddr("lp1");
        lp2 = makeAddr("lp2");
        lp3 = makeAddr("lp3");
    }

    function test_previewDeposit_zeroTotalSupply() external {
        assertEq(pool.previewDeposit(1),       1);
        assertEq(pool.previewDeposit(2),       2);
        assertEq(pool.previewDeposit(1_000e6), 1_000e6);
    }

    function test_previewDeposit_nonZeroTotalSupply() external {
        deposit(lp1, 1_000e6);

        assertEq(pool.previewDeposit(1),       1);
        assertEq(pool.previewDeposit(2),       2);
        assertEq(pool.previewDeposit(1_000e6), 1_000e6);
    }

    function test_previewDeposit_multipleUsers() external {
        deposit(lp1, 1_000e6);
        deposit(lp2, 1_000e6);
        deposit(lp3, 1_000e6);

        assertEq(pool.previewDeposit(1),       1);
        assertEq(pool.previewDeposit(2),       2);
        assertEq(pool.previewDeposit(1_000e6), 1_000e6);
    }

    function test_previewDeposit_multipleUsers_changeTotalAssets() external {
        deposit(lp1, 1_000e6);
        deposit(lp2, 1_000e6);
        deposit(lp3, 1_000e6);

        vm.prank(address(pool));
        fundsAsset.transfer(address(0), 1_500e6);  // Simulate loss of 50% of funds

        assertEq(pool.previewDeposit(1),       2);
        assertEq(pool.previewDeposit(2),       4);
        assertEq(pool.previewDeposit(1_000e6), 2_000e6);
    }

}

contract PreviewMintTests is TestBase {

    address lp1;
    address lp2;
    address lp3;

    function setUp() public override {
        super.setUp();

        lp1 = makeAddr("lp1");
        lp2 = makeAddr("lp2");
        lp3 = makeAddr("lp3");
    }

    function test_previewMint_zeroTotalSupply() external {
        assertEq(pool.previewMint(1),       1);
        assertEq(pool.previewMint(2),       2);
        assertEq(pool.previewMint(1_000e6), 1_000e6);
    }

    function test_previewMint_nonZeroTotalSupply() external {
        deposit(lp1, 1_000e6);

        assertEq(pool.previewMint(1),       1);
        assertEq(pool.previewMint(2),       2);
        assertEq(pool.previewMint(1_000e6), 1_000e6);
    }

    function test_previewMint_multipleUsers() external {
        deposit(lp1, 1_000e6);
        deposit(lp2, 1_000e6);
        deposit(lp3, 1_000e6);

        assertEq(pool.previewMint(1),       1);
        assertEq(pool.previewMint(2),       2);
        assertEq(pool.previewMint(1_000e6), 1_000e6);
    }

    function test_previewMint_multipleUsers_changeTotalAssets() external {
        deposit(lp1, 1_000e6);
        deposit(lp2, 1_000e6);
        deposit(lp3, 1_000e6);

        vm.prank(address(pool));
        fundsAsset.transfer(address(0), 1_500e6);  // Simulate loss of 50% of funds

        assertEq(pool.previewMint(1),       1);  // Rounds up the asset token amount
        assertEq(pool.previewMint(2),       1);
        assertEq(pool.previewMint(1_000e6), 500e6);
    }

}

contract TotalAssetsTests is TestBase {

    address borrower;
    address loan;
    address lp1;

    function setUp() public override {
        super.setUp();

        lp1      = makeAddr("lp1");
        borrower = makeAddr("borrower");

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,  // 10k after 1m seconds
            platformManagementFeeRate:  0.08e6
        });
    }

    function test_totalAssets_zeroTotalSupply() external {
        assertEq(pool.totalAssets(), 0);
    }

    function test_totalAssets_singleDeposit() external {
        deposit(lp1, 1_000e6);

        assertEq(pool.totalAssets(), 1_000e6);
    }

    function test_totalAssets_singleLoanFunded() external {
        deposit(lp1, 1_500_000e6);

        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(ONE_MONTH), uint256(3)],
            amounts:     [uint256(0), uint256(1_500_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.075e6), uint256(0), uint256(0), uint256(0)],
            loanManager: poolManager.loanManagerList(0)
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 0);  // Funds moved out of pool
        assertEq(pool.totalAssets(),                  1_500_000e6);
    }

    function test_totalAssets_singleLoanFundedWithInterest() external {
        deposit(lp1, 1_500_000e6);

        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(ONE_MONTH), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.075e6), uint256(0), uint256(0), uint256(0)],
            loanManager: poolManager.loanManagerList(0)
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);  // Funds moved out of pool
        assertEq(pool.totalAssets(),                  1_500_000e6);

        vm.warp(start + ONE_MONTH);

        // +------------+--------+--------+
        // |    POOL    |   PD   |   MT   |
        // +------------+--------+--------+
        // |   500,000  |   500  |    250 |
        // | +   6,250  | + 275  | +  550 | Interest and service fees paid
        // | -     625  | + 125  | +  500 | Management fee distribution
        // | = 505,625  | = 900  | = 1300 |
        // +------------+--------+--------+
        assertEq(pool.totalAssets(), 1_505_624_999999);  // Note: Rounding
    }

    function test_totalAssets_singleLoanFundedWithPayment() external {
        deposit(lp1, 1_500_000e6);

        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(ONE_MONTH), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.075e6), uint256(0), uint256(0), uint256(0)],
            loanManager: poolManager.loanManagerList(0)
        });

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);  // Funds moved out of pool
        assertEq(pool.totalAssets(),                  1_500_000e6);

        /************************/
        /*** Make 1st Payment ***/
        /************************/

        vm.warp(start + ONE_MONTH);
        makePayment(loan);

        // +------------+--------+--------+
        // |    POOL    |   PD   |   MT   |
        // +------------+--------+--------+
        // |   500,000  |   500  |    250 |
        // | +   6,250  | + 275  | +  550 | Interest and service fees paid
        // | -     625  | + 125  | +  500 | Management fee distribution
        // | = 505,625  | = 900  | = 1300 |
        // +------------+--------+--------+
        assertEq(pool.totalAssets(),                  1_505_625e6);
        assertEq(fundsAsset.balanceOf(address(pool)), 505_625e6);
    }

}
