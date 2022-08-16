// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { Address, TestUtils } from "../modules/contract-test-utils/contracts/test.sol";
import { MapleLoan as Loan  } from "../modules/loan/contracts/MapleLoan.sol";

import { TestBase } from "../contracts/TestBase.sol";

contract BalanceOfAssetsTests is TestBase {

    address lp1;
    address lp2;

    function setUp() public override {
        super.setUp();

        lp1 = address(new Address());
        lp2 = address(new Address());
    }

    function test_balanceOfAssets() external {
        depositLiquidity({
            lp:        lp1,
            liquidity: 1_000e6
        });

        assertEq(pool.balanceOfAssets(lp1), 1_000e6);
        assertEq(pool.balanceOfAssets(lp2), 0);

        depositLiquidity({
            lp:        lp2,
            liquidity: 3_000e6
        });

        assertEq(pool.balanceOfAssets(lp1), 1_000e6);
        assertEq(pool.balanceOfAssets(lp2), 3_000e6);

        fundsAsset.mint(address(pool), 4_000e6);  // Double totalAssets

        assertEq(pool.balanceOfAssets(lp1), 2_000e6);
        assertEq(pool.balanceOfAssets(lp2), 6_000e6);
    }

    function testFuzz_balanceOfAssets(uint256 depositAmount1, uint256 depositAmount2, uint256 additionalAmount) external {
        depositAmount1   = constrictToRange(depositAmount1,   1, 1e29);
        depositAmount2   = constrictToRange(depositAmount2,   1, 1e29);
        additionalAmount = constrictToRange(additionalAmount, 1, 1e29);

        uint256 totalDeposits = depositAmount1 + depositAmount2;

        depositLiquidity({
            lp:        lp1,
            liquidity: depositAmount1
        });

        assertEq(pool.balanceOfAssets(lp1), depositAmount1);
        assertEq(pool.balanceOfAssets(lp2), 0);

        depositLiquidity({
            lp:        lp2,
            liquidity: depositAmount2
        });

        assertEq(pool.balanceOfAssets(lp1), depositAmount1);
        assertEq(pool.balanceOfAssets(lp2), depositAmount2);

        fundsAsset.mint(address(pool), additionalAmount);

        assertEq(pool.balanceOfAssets(lp1), depositAmount1 + additionalAmount * depositAmount1 / totalDeposits);
        assertEq(pool.balanceOfAssets(lp2), depositAmount2 + additionalAmount * depositAmount2 / totalDeposits);
    }

}

contract MaxDepositTests is TestBase {

    address lp1;
    address lp2;

    function setUp() public override {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _createFactories();
        _createPool();

        lp1 = address(new Address());
        lp2 = address(new Address());
    }

    function test_maxDeposit_closedPool() external {
        vm.prank(poolDelegate);
        poolManager.setLiquidityCap(1_000e6);

        assertEq(pool.maxDeposit(lp1), 0);
        assertEq(pool.maxDeposit(lp2), 0);

        vm.prank(poolDelegate);
        poolManager.setAllowedLender(lp1, true);

        assertEq(pool.maxDeposit(lp1), 1_000e6);
        assertEq(pool.maxDeposit(lp2), 0);

        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();

        assertEq(pool.maxDeposit(lp1), 1_000e6);
        assertEq(pool.maxDeposit(lp2), 1_000e6);
    }

    function test_maxDeposit_totalAssetsIncrease() external {
        vm.prank(poolDelegate);
        poolManager.setLiquidityCap(1_000e6);

        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();

        assertEq(pool.maxDeposit(lp1), 1_000e6);
        assertEq(pool.maxDeposit(lp2), 1_000e6);

        fundsAsset.mint(address(pool), 400e6);

        assertEq(pool.maxDeposit(lp1), 600e6);
        assertEq(pool.maxDeposit(lp2), 600e6);
    }

    function testFuzz_maxDeposit_totalAssetsIncrease(uint256 liquidityCap, uint256 totalAssets) external {
        liquidityCap = constrictToRange(liquidityCap, 1, 1e29);
        totalAssets  = constrictToRange(totalAssets,  1, 1e29);

        uint256 availableDeposit = liquidityCap > totalAssets ? liquidityCap - totalAssets : 0;

        vm.startPrank(poolDelegate);
        poolManager.setLiquidityCap(liquidityCap);
        poolManager.setOpenToPublic();

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
        _createAccounts();
        _createAssets();
        _createGlobals();
        _createFactories();
        _createPool();

        lp1 = address(new Address());
        lp2 = address(new Address());
    }

    function test_maxMint_closedPool() external {
        vm.prank(poolDelegate);
        poolManager.setLiquidityCap(1_000e6);

        assertEq(pool.maxMint(lp1), 0);
        assertEq(pool.maxMint(lp2), 0);

        vm.prank(poolDelegate);
        poolManager.setAllowedLender(lp1, true);

        assertEq(pool.maxMint(lp1), 1_000e6);
        assertEq(pool.maxMint(lp2), 0);

        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();

        assertEq(pool.maxMint(lp1), 1_000e6);
        assertEq(pool.maxMint(lp2), 1_000e6);
    }

    function test_maxMint_totalAssetsIncrease() external {
        vm.prank(poolDelegate);
        poolManager.setLiquidityCap(1_000e6);

        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();

        assertEq(pool.maxMint(lp1), 1_000e6);
        assertEq(pool.maxMint(lp2), 1_000e6);

        fundsAsset.mint(address(pool), 400e6);

        assertEq(pool.maxMint(lp1), 600e6);
        assertEq(pool.maxMint(lp2), 600e6);
    }

    function testFuzz_maxMint_totalAssetsIncrease(uint256 liquidityCap, uint256 totalAssets) external {
        liquidityCap = constrictToRange(liquidityCap, 1, 1e29);
        totalAssets  = constrictToRange(totalAssets,  1, 1e29);

        uint256 availableDeposit = liquidityCap > totalAssets ? liquidityCap - totalAssets : 0;

        vm.startPrank(poolDelegate);
        poolManager.setLiquidityCap(liquidityCap);
        poolManager.setOpenToPublic();

        assertEq(pool.maxMint(lp1), liquidityCap);
        assertEq(pool.maxMint(lp2), liquidityCap);

        fundsAsset.mint(address(pool), totalAssets);

        assertEq(pool.maxMint(lp1), availableDeposit);
        assertEq(pool.maxMint(lp2), availableDeposit);
    }

    function test_maxMint_exchangeRateGtOne() external {
        vm.startPrank(poolDelegate);
        poolManager.setLiquidityCap(10_000e6);
        poolManager.setOpenToPublic();
        vm.stopPrank();

        depositLiquidity({
            lp:        lp1,
            liquidity: 1_000e6
        });

        assertEq(pool.maxMint(lp1), 9_000e6);
        assertEq(pool.maxMint(lp2), 9_000e6);

        fundsAsset.mint(address(pool), 1_000e6);  // Double totalAssets.

        assertEq(pool.maxMint(lp1), 4_000e6);  // totalAssets = 2000, 8000 of room at 2:1
        assertEq(pool.maxMint(lp2), 4_000e6);
    }

    function testFuzz_maxMint_exchangeRateGtOne(uint256 liquidityCap, uint256 depositAmount, uint256 transferAmount) external {
        liquidityCap   = constrictToRange(liquidityCap,   1, 1e29);
        depositAmount  = constrictToRange(depositAmount,  1, liquidityCap);
        transferAmount = constrictToRange(transferAmount, 1, 1e29);

        vm.startPrank(poolDelegate);
        poolManager.setLiquidityCap(liquidityCap);
        poolManager.setOpenToPublic();
        vm.stopPrank();

        depositLiquidity({
            lp:        lp1,
            liquidity: depositAmount
        });

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

contract MaxRedeemTests is TestBase {}
contract MaxWithdrawTests is TestBase {}
contract PreviewRedeemTests is TestBase {}
contract PreviewWithdrawTests is TestBase {}
contract ConvertToAssetsTests is TestBase {}
contract ConvertToSharesTests is TestBase {}
contract PreviewDepositTests is TestBase {}
contract PreviewMintTests is TestBase {}
contract TotalAssetsTests is TestBase {}
