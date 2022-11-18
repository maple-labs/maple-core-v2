// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestBase } from "../../contracts/utilities/TestBase.sol";

import { Address, console  } from "../../modules/contract-test-utils/contracts/test.sol";
import { MapleLoan as Loan } from "../../modules/loan-v401/contracts/MapleLoan.sol";

contract RequestWithdrawTests is TestBase {

    address borrower;
    address lp;
    address wm;

    function setUp() public override {
        super.setUp();

        borrower = address(new Address());
        lp       = address(new Address());
        wm       = address(withdrawalManager);
    }

    function test_requestWithdraw() external {
        depositLiquidity(lp, 1_000e6);

        vm.startPrank(lp);

        assertEq(pool.balanceOf(lp), 1_000e6);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),     0);
        assertEq(withdrawalManager.lockedShares(lp),    0);
        assertEq(withdrawalManager.totalCycleShares(3), 0);

        vm.expectRevert("PM:RW:NOT_ENABLED");
        pool.requestWithdraw(1_000e6, lp);
    }

    function test_requestWithdraw_withApproval() external {
        depositLiquidity(lp, 1_000e6);

        address sender = address(new Address());

        vm.prank(lp);
        pool.approve(sender, 1_000e6);

        assertEq(pool.balanceOf(lp),         1_000e6);
        assertEq(pool.balanceOf(wm),         0);
        assertEq(pool.allowance(lp, sender), 1_000e6);

        assertEq(withdrawalManager.exitCycleId(lp),     0);
        assertEq(withdrawalManager.lockedShares(lp),    0);
        assertEq(withdrawalManager.totalCycleShares(3), 0);

        vm.expectRevert("PM:RW:NOT_ENABLED");
        vm.prank(sender);
        pool.requestWithdraw(1_000e6, lp);
    }


    function testFuzz_requestWithdraw(uint256 depositAmount, uint256 withdrawAmount) external {
        depositAmount  = constrictToRange(depositAmount,  1, 1e30);
        withdrawAmount = constrictToRange(withdrawAmount, 1, depositAmount);

        depositLiquidity(lp, depositAmount);

        vm.startPrank(lp);

        assertEq(pool.totalSupply(), depositAmount);
        assertEq(pool.balanceOf(lp), depositAmount);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(withdrawalManager.exitCycleId(lp),     0);
        assertEq(withdrawalManager.lockedShares(lp),    0);
        assertEq(withdrawalManager.totalCycleShares(3), 0);

        vm.expectRevert("PM:RW:NOT_ENABLED");
        pool.requestWithdraw(withdrawAmount, lp);
    }

}

contract RequestWithdrawFailureTests is TestBase {

    address borrower;
    address lp;
    address wm;

    function setUp() public override {
        super.setUp();

        borrower = address(new Address());
        lp       = address(new Address());
        wm       = address(withdrawalManager);

        depositLiquidity(lp, 1_000e6);
    }

    function test_requestWithdraw_failIfInsufficientApproval() external {
        vm.expectRevert(ARITHMETIC_ERROR);
        pool.requestWithdraw(1_000e6, lp);

        vm.prank(lp);
        pool.approve(address(this), 1_000e6 - 1);

        vm.expectRevert(ARITHMETIC_ERROR);
        pool.requestWithdraw(1_000e6, lp);
    }

    function test_requestWithdraw_failIfNotPool() external {
        vm.expectRevert("PM:RR:NOT_POOL");
        poolManager.requestRedeem(0, address(lp));
    }

    function test_requestWithdraw_failIfNotPM() external {
        vm.expectRevert("WM:AS:NOT_POOL_MANAGER");
        withdrawalManager.addShares(0, address(lp));
    }

}

contract WithdrawFailureTests is TestBase {

    address borrower;
    address lp;
    address wm;

    function setUp() public override {
        super.setUp();

        borrower = address(new Address());
        lp       = address(new Address());
        wm       = address(withdrawalManager);

        depositLiquidity(lp, 1_000e6);
    }

    function test_withdraw_failIfNotPool() external {
        vm.expectRevert("PM:PR:NOT_POOL");
        poolManager.processRedeem(1, lp);
    }

    function test_withdraw_failIfNotPoolManager() external {
        vm.expectRevert("WM:PE:NOT_PM");
        withdrawalManager.processExit(1_000e6, address(lp));
    }

    function test_withdraw_zeroAssetInput() external {
        vm.expectRevert("PM:PW:NOT_ENABLED");
        pool.withdraw(0, lp, lp);
    }

    function testFuzz_withdraw(uint256 assets_, address receiver_, address owner_) external {
        vm.expectRevert("PM:PW:NOT_ENABLED");
        pool.withdraw(assets_, receiver_, owner_);
    }

}

contract WithdrawScenarios is TestBase {

    function setUp() public override {
        super.setUp();

        // Remove all fees to make interest calculations easier.
        setupFees({
            delegateOriginationFee:     0,
            delegateServiceFee:         0,
            delegateManagementFeeRate:  0,
            platformOriginationFeeRate: 0,
            platformServiceFeeRate:     0,
            platformManagementFeeRate:  0
        });

        depositCover(2_500_000e6);
    }

    function test_withdrawals_withUpdateAccounting() external {
        // Create four liquidity providers.
        address lp1 = address(new Address());
        address lp2 = address(new Address());
        address lp3 = address(new Address());
        address lp4 = address(new Address());

        // Deposit liquidity into the pool.
        depositLiquidity(address(lp1), 500_000e6);
        depositLiquidity(address(lp2), 1_500_000e6);
        depositLiquidity(address(lp3), 500_000e6);
        depositLiquidity(address(lp4), 1_000_000e6);

        // Fund three loans.
        fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(5 days), uint256(10 days), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.075e18), uint256(0), uint256(0), uint256(0)]
        });

        fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(5 days), uint256(12 days), uint256(3)],
            amounts:     [uint256(0), uint256(2_000_000e6), uint256(2_000_000e6)],
            rates:       [uint256(0.09e18), uint256(0), uint256(0), uint256(0)]
        });

        fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(5 days), uint256(15 days), uint256(6)],
            amounts:     [uint256(0), uint256(500_000e6), uint256(500_000e6)],
            rates:       [uint256(0.081e18), uint256(0), uint256(0), uint256(0)]
        });

        // Deposit extra liquidity to allow for partial withdrawals.
        depositLiquidity(address(new Address()), 500_000e6);

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        // Request all withdrawals.
        requestRedeem(address(lp1),   500_000e6);
        requestRedeem(address(lp2), 1_000_000e6);
        requestRedeem(address(lp3),   500_000e6);
        requestRedeem(address(lp4), 1_000_000e6);

        // Wait until the domain end has elapsed.
        vm.warp(start + 14 days);

        // Assert only 10 days of interest has accrued, even though 14 days have elapsed.
        uint256 interest1 = uint256(1_000_000e6) * 0.075e18 * 10 days / 365 days / 1e18;
        uint256 interest2 = uint256(2_000_000e6) * 0.09e18  * 10 days / 365 days / 1e18;
        uint256 interest3 = uint256(500_000e6)   * 0.081e18 * 10 days / 365 days / 1e18;

        assertEq(loanManager.domainEnd(),             start + 10 days);
        assertEq(loanManager.assetsUnderManagement(), 3_500_000e6 + interest1 + interest2 + interest3 - 1);
        assertEq(loanManager.assetsUnderManagement(), 3_508_095.890409e6);

        // Perform a withdrawal with the 1st and 2nd LP.
        vm.warp(start + 14 days);
        uint256 assets1 = redeem(address(lp1), 500_000e6);
        uint256 assets2 = redeem(address(lp2), 1_000_000e6);

        // Update accounting manually.
        vm.prank(address(poolDelegate));
        loanManager.updateAccounting();

        // Assert loans have accrued interest up to the latest payment.
        interest1 = uint256(1_000_000e6) * 0.075e18 * 10 days / 365 days / 1e18;
        interest2 = uint256(2_000_000e6) * 0.09e18  * 12 days / 365 days / 1e18;  // Account full loan2 amount.
        interest3 = uint256(500_000e6)   * 0.081e18 * 14 days / 365 days / 1e18;  // 14 days of interest on last loan.

        assertEq(loanManager.domainEnd(),             start + 15 days);
        assertEq(loanManager.assetsUnderManagement(), 3_500_000e6 + interest1 + interest2 + interest3 - 2);
        assertEq(loanManager.assetsUnderManagement(), 3_509_526.027394e6);

        // Perform a withdrawal with the 3rd and 4th LP in the same timestamp to show the atomic change in value after updateAccounting.
        uint256 assets3 = redeem(address(lp3), 500_000e6);
        uint256 assets4 = redeem(address(lp4), 1_000_000e6);

        uint256 totalWithdrawn = assets1 + assets2 + assets3 + assets4;

        assertEq(totalWithdrawn, 500_000e6);

        assertWithinDiff(fundsAsset.balanceOf(address(pool)), 0, 1);

        // Assert all LP balances.
        assertEq(fundsAsset.balanceOf(address(lp1)), assets1);
        assertEq(fundsAsset.balanceOf(address(lp2)), assets2);
        assertEq(fundsAsset.balanceOf(address(lp3)), assets3);
        assertEq(fundsAsset.balanceOf(address(lp4)), assets4);

        assertEq(assets1,  83_333.333332e6);
        assertEq(assets2, 166_666.666666e6);
        assertEq(assets3,  83_333.333333e6);
        assertEq(assets4, 166_666.666669e6);

        assertEq(assets1, uint256(500_000e6 * 1) / 6 - 1);  // 500k/3.5m
        assertEq(assets2, uint256(500_000e6 * 2) / 6);
        assertEq(assets3, uint256(500_000e6 * 1) / 6);
        assertEq(assets4, uint256(500_000e6 * 2) / 6 + 3);

        assertEq(withdrawalManager.lockedShares(lp1),   500_000e6 -  83_165.009632e6);
        assertEq(withdrawalManager.lockedShares(lp2), 1_000_000e6 - 166_330.019265e6);
        assertEq(withdrawalManager.lockedShares(lp3),   500_000e6 -  83_133.373369e6);  // Burns less shares than lp1 because of increase in exchange rate.
        assertEq(withdrawalManager.lockedShares(lp4), 1_000_000e6 - 166_266.746740e6);  // Burns less shares than lp2 because of increase in exchange rate.
    }

    function test_withdrawals_cashInjection() external {
        address borrower = address(new Address());

        // Create two liquidity providers.
        address lp1 = address(new Address());
        address lp2 = address(new Address());

        // Deposit liquidity into the pool.
        depositLiquidity(address(lp1), 1_500_000e6);
        depositLiquidity(address(lp2), 2_500_000e6);

        // Fund three loans.
        Loan bigLoan = fundAndDrawdownLoan({
            borrower:    address(borrower),
            termDetails: [uint256(5 days), uint256(15 days), uint256(1)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(100e18), uint256(0), uint256(0), uint256(0)]
        });

        fundAndDrawdownLoan({
            borrower:    address(borrower),
            termDetails: [uint256(5 days), uint256(30 days), uint256(3)],
            amounts:     [uint256(0), uint256(2_000_000e6), uint256(2_000_000e6)],
            rates:       [uint256(0.09e18), uint256(0), uint256(0), uint256(0)]
        });

        fundAndDrawdownLoan({
            borrower:    address(borrower),
            termDetails: [uint256(5 days), uint256(30 days), uint256(6)],
            amounts:     [uint256(0), uint256(500_000e6), uint256(500_000e6)],
            rates:       [uint256(0.081e18), uint256(0), uint256(0), uint256(0)]
        });

        // First LP requests a withdrawal.
        requestRedeem(address(lp1), 1_500_000e6);
        requestRedeem(address(lp2), 2_500_000e6);

        // First LP exits.
        vm.warp(start + 15 days);

        ( uint256 redeemableShares, , bool partialLiquidity ) = withdrawalManager.getRedeemableAmounts(1_500_000e6, address(lp1));

        assertTrue(partialLiquidity);

        uint256 assets1 = redeem(lp1, 1_500_000e6);

        assertEq(withdrawalManager.lockedShares(address(lp1)), 1_500_000e6 - redeemableShares);
        assertEq(withdrawalManager.exitCycleId(address(lp1)),  4);

        Loan loan = createLoan({
            borrower:    address(borrower),
            termDetails: [uint256(5 days), uint256(30 days), uint256(6)],
            amounts:     [uint256(0), uint256(300_000e6), uint256(300_000e6)],
            rates:       [uint256(0.055e18), uint256(0), uint256(0), uint256(0)]
        });

        vm.prank(address(poolDelegate));
        vm.expectRevert("PM:VAFL:LOCKED_LIQUIDITY");
        poolManager.fund(300_000e6, address(loan), address(loanManager));

        makePayment(bigLoan);

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 1_000_000e6 + 4109589.041095e6 - assets1);

        vm.prank(address(poolDelegate));
        poolManager.fund(300_000e6, address(loan), address(loanManager));

        ( redeemableShares, , partialLiquidity ) = withdrawalManager.getRedeemableAmounts(2_500_000e6, address(lp2));

        assertTrue(!partialLiquidity);

        uint256 assets2 = redeem(lp2, 2_500_000e6);

        assertEq(withdrawalManager.lockedShares(address(lp2)), 0);
        assertEq(withdrawalManager.exitCycleId(address(lp2)),  0);

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 1_000_000e6 + 4109589.041095e6 - 300_000e6 - assets1 - assets2);
    }

    function test_withdrawals_poorExchangeRates() external {
        address borrower = address(new Address());

        // Create four liquidity providers.
        address lp1 = address(new Address());
        address lp2 = address(new Address());
        address lp3 = address(new Address());
        address lp4 = address(new Address());

        // Deposit liquidity into the pool.
        depositLiquidity(address(lp1),   500_000e6);
        depositLiquidity(address(lp2), 1_500_000e6);
        depositLiquidity(address(lp3),   500_000e6);
        depositLiquidity(address(lp4), 1_000_000e6);

        // Fund three loans.
        Loan loan1 = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(10 days), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.075e18), uint256(0), uint256(0), uint256(0)]
        });

        Loan loan2 = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(30 days), uint256(3)],
            amounts:     [uint256(0), uint256(2_000_000e6), uint256(2_000_000e6)],
            rates:       [uint256(0.09e18), uint256(0), uint256(0), uint256(0)]
        });

        Loan loan3 = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(30 days), uint256(6)],
            amounts:     [uint256(0), uint256(500_000e6), uint256(500_000e6)],
            rates:       [uint256(0.081e18), uint256(0), uint256(0), uint256(0)]
        });

        // Request all withdrawals.
        requestRedeem(address(lp1),   500_000e6);
        requestRedeem(address(lp2), 1_500_000e6);
        requestRedeem(address(lp3),   500_000e6);
        requestRedeem(address(lp4), 1_000_000e6);

        assertEq(withdrawalManager.totalCycleShares(3), 3_500_000e6);

        // 1st LP withdraws with no liquidity.
        vm.warp(start + 15 days);
        redeem(address(lp1), 500_000e6);

        assertEq(withdrawalManager.totalCycleShares(3),        3_000_000e6);
        assertEq(withdrawalManager.lockedShares(address(lp1)), 500_000e6);
        assertEq(withdrawalManager.exitCycleId(address(lp1)),  4);

        assertEq(pool.balanceOf(address(lp1)),       0);
        assertEq(fundsAsset.balanceOf(address(lp1)), 0);

        // Pool delegate impairs all loans, settings exchange rate to zero.
        vm.warp(start + 15.01 days);
        impairLoan(loan1);
        impairLoan(loan2);
        impairLoan(loan3);

        assertEq(poolManager.totalAssets(), poolManager.unrealizedLosses());

        // 2nd LP withdraws with no liquidity and a zero exchange rate, burning all their shares.
        vm.warp(start + 15.56 days);
        redeem(address(lp2), 1_500_000e6);

        assertEq(withdrawalManager.totalCycleShares(3),        1_500_000e6);
        assertEq(withdrawalManager.lockedShares(address(lp2)), 0);
        assertEq(withdrawalManager.exitCycleId(address(lp2)),  0);

        assertEq(pool.totalSupply(),                 2_000_000e6);
        assertEq(pool.balanceOf(address(lp2)),       0);
        assertEq(fundsAsset.balanceOf(address(lp2)), 0);

        // A cash transfer is used to provide partial liquidity.
        fundsAsset.mint(address(pool), 100_000e6);

        assertEq(poolManager.totalAssets() - poolManager.unrealizedLosses(), 100_000e6);

        // 3rd LP withdraws with full liquidity and a 0.05 exchange rate (100k/2m)
        vm.warp(start + 15.58 days);
        redeem(address(lp3), 500_000e6);

        assertEq(withdrawalManager.lockedShares(address(lp3)), 0);
        assertEq(withdrawalManager.exitCycleId(address(lp3)),  0);

        assertEq(pool.balanceOf(address(lp3)),       0);
        assertEq(fundsAsset.balanceOf(address(lp3)), 500_000e6 * 100_000e6 / 2_000_000e6);
        assertEq(fundsAsset.balanceOf(address(lp3)), 25_000e6);

        // Check if loan impairment calculations are correct.
        ( , uint256 principal, uint256 interest, uint256 lateInterest, uint256 platformFees, ) = loanManager.liquidationInfo(address(loan1));

        assertEq(principal,    1_000_000e6);
        assertEq(interest,     2_054.794520e6 - 1);
        assertEq(lateInterest, interest * 6 days / 10 days + 1);
        assertEq(platformFees, 0);

        // A loan defaults and the liquidated pool cover brings it to full liquidity.
        vm.warp(start + 15.59 days);
        defaultLoan(loan1);

        assertEq(fundsAsset.balanceOf(address(pool)),      poolManager.totalAssets() - poolManager.unrealizedLosses());
        assertEq(fundsAsset.balanceOf(address(pool)),      1_078_287.671231e6);
        assertEq(fundsAsset.balanceOf(address(pool)),      75_000e6    + principal + interest + lateInterest);
        assertEq(fundsAsset.balanceOf(address(poolCover)), 2_500_000e6 - principal - interest - lateInterest);

        uint256 assetsToWithdraw = 1_000_000e6 * (poolManager.totalAssets() - poolManager.unrealizedLosses()) / 1_500_000e6;

        assertEq(assetsToWithdraw, 718_858.447487e6);

        // 4th LP withdraws with full liquidity.
        vm.warp(start + 15.72 days);
        redeem(address(lp4), 1_000_000e6);

        assertEq(withdrawalManager.lockedShares(address(lp4)), 0);
        assertEq(withdrawalManager.exitCycleId(address(lp4)),  0);

        assertEq(pool.balanceOf(address(lp4)),       0);
        assertEq(fundsAsset.balanceOf(address(lp4)), assetsToWithdraw);
    }

}
