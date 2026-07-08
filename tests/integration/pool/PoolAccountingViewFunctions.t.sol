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
        _setUpClosedPool();

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
        _setUpClosedPool();

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

contract MaxRedeemWMQueueTests is TestBase {

    address lp1;
    address lp2;
    address wm;

    uint256 maxShares;

    function setUp() public override {
        super.setUp();

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

    function test_maxRedeem_beforeRedeem() external view {
        assertEq(pool.maxRedeem(lp1), 0);
    }

    function test_maxRedeem_afterFullRedeem() external {
        processRedemptionByIds(address(pool), array(1));

        assertEq(pool.maxRedeem(lp1), 1_000e6);
    }

    function test_maxRedeem_afterPartialManualRedeem() external {
        processRedemptionByIds(address(pool), array(1));
        redeem(address(pool), lp1, 150e6);

        assertEq(pool.maxRedeem(lp1), 850e6);
    }

    function test_maxRedeem_afterFullManualRedeem() external {
        processRedemptionByIds(address(pool), array(1));
        redeem(address(pool), lp1, 1_000e6);

        assertEq(pool.maxRedeem(lp1), 0);
    }

    function test_maxRedeem_notManual() external {
        processRedemptionByIds(address(pool), array(1, 2));

        assertEq(pool.maxRedeem(lp2), 0);
    }

}

contract PreviewRedeemWithQueueWMTests is TestBase {

    address lender = makeAddr("lender");

    uint256 shares = 1_000e6;

    function setUp() public override {
        super.setUp();

        deposit(lender, shares);

        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lender, true);

        vm.prank(lender);
        pool.requestRedeem(shares, lender);

        vm.prank(poolDelegate);
        queueWM.processRedemptions(array(1));
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

    function setUp() public override {
        super.setUp();

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
        queueWM.processRedemptions(array(1));

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

    function testFuzz_previewWithdraw(
        address lender,
        bool    isManual,
        uint256 amountToDeposit,
        uint256 amountToRequestRedeem,
        uint256 amountToWithdraw
    )
        external
    {
        vm.assume(lender != address(0));

        amountToDeposit        = bound(amountToDeposit,       0, 1e30);
        amountToRequestRedeem  = bound(amountToRequestRedeem, 0, amountToDeposit);

        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lender, isManual);

        if (amountToDeposit > 0) {
            deposit(lender, amountToDeposit);
        }

        if (amountToRequestRedeem > 0) {
            vm.prank(lender);
            pool.requestRedeem(amountToRequestRedeem, lender);

            vm.prank(poolDelegate);
            queueWM.processRedemptions(array(1));
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

    function test_convertToAssets_zeroTotalSupply() external view {
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

    function test_convertToShares_zeroTotalSupply() external view {
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

    function test_previewDeposit_zeroTotalSupply() external view {
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

    function test_previewMint_zeroTotalSupply() external view {
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
    address lp1;
    address loan;

    function setUp() public override {
        super.setUp();

        borrower = makeAddr("borrower");
        lp1      = makeAddr("lp1");

        setupFees({
            delegateOriginationFee:     0,
            delegateServiceFee:         0,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0,
            platformServiceFeeRate:     0.031536e6,  // 1000e6 platform service fee after 1m seconds on 1M principal
            platformManagementFeeRate:  0.08e6
        });
    }

    function test_totalAssets_zeroTotalSupply() external view {
        assertEq(pool.totalAssets(), 0);
    }

    function test_totalAssets_singleDeposit() external {
        deposit(lp1, 1_000e6);

        assertEq(pool.totalAssets(), 1_000e6);
    }

    function test_totalAssets_singleLoanFunded() external {
        deposit(lp1, 1_500_000e6);

        loan = createOpenTermLoan(
            borrower,
            poolManager.strategyList(0),
            address(fundsAsset),
            1_500_000e6,
            [uint32(200_000), uint32(100_000), uint32(1_000_000)],
            [uint64(0.015768e6), uint64(0.031536e6), uint64(0), uint64(0.015768e6)]
        );

        fundLoan(loan);

        assertEq(fundsAsset.balanceOf(address(pool)), 0);  // All liquidity funded the loan
        assertEq(pool.totalAssets(),                  1_500_000e6);
    }

    function test_totalAssets_singleLoanFundedWithInterest() external {
        deposit(lp1, 1_500_000e6);

        loan = createOpenTermLoan(
            borrower,
            poolManager.strategyList(0),
            address(fundsAsset),
            1_000_000e6,
            [uint32(200_000), uint32(100_000), uint32(1_000_000)],
            [uint64(0.015768e6), uint64(0.031536e6), uint64(0), uint64(0.015768e6)]
        );

        fundLoan(loan);

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);
        assertEq(pool.totalAssets(),                  1_500_000e6);

        vm.warp(start + 1_000_000);

        // Gross interest 1000e6, 10% management fees skim 100e6 → 900e6 net accrued on the pool
        assertEq(pool.totalAssets(), 1_500_000e6 + 900e6);
    }

    function test_totalAssets_singleLoanFundedWithPayment() external {
        deposit(lp1, 1_500_000e6);

        loan = createOpenTermLoan(
            borrower,
            poolManager.strategyList(0),
            address(fundsAsset),
            1_000_000e6,
            [uint32(200_000), uint32(100_000), uint32(1_000_000)],
            [uint64(0.015768e6), uint64(0.031536e6), uint64(0), uint64(0.015768e6)]
        );

        fundLoan(loan);

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);
        assertEq(pool.totalAssets(),                  1_500_000e6);

        vm.warp(start + 1_000_000);
        makePayment(loan);

        // OT loans don't amortize: principalOut stays 1M, cash gains the 900e6 net interest
        assertEq(pool.totalAssets(),                  1_500_000e6 + 900e6);
        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6   + 900e6);
    }

}
