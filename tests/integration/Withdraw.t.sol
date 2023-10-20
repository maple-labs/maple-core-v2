// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IFixedTermLoanManager } from "../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../TestBase.sol";

contract RequestWithdrawTests is TestBase {

    address borrower;
    address lp;
    address wm;

    function setUp() public override {
        super.setUp();

        borrower = makeAddr("borrower");
        lp       = makeAddr("lp");
        wm       = address(cyclicalWM);
    }

    function test_requestWithdraw() external {
        deposit(lp, 1_000e6);

        vm.startPrank(lp);

        assertEq(pool.balanceOf(lp), 1_000e6);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(cyclicalWM.exitCycleId(lp),     0);
        assertEq(cyclicalWM.lockedShares(lp),    0);
        assertEq(cyclicalWM.totalCycleShares(3), 0);

        vm.expectRevert("PM:RW:NOT_ENABLED");
        pool.requestWithdraw(1_000e6, lp);
    }

    function test_requestWithdraw_withApproval() external {
        deposit(lp, 1_000e6);

        address sender = makeAddr("sender");

        vm.prank(lp);
        pool.approve(sender, 1_000e6);

        assertEq(pool.balanceOf(lp),         1_000e6);
        assertEq(pool.balanceOf(wm),         0);
        assertEq(pool.allowance(lp, sender), 1_000e6);

        assertEq(cyclicalWM.exitCycleId(lp),     0);
        assertEq(cyclicalWM.lockedShares(lp),    0);
        assertEq(cyclicalWM.totalCycleShares(3), 0);

        vm.expectRevert("PM:RW:NOT_ENABLED");
        vm.prank(sender);
        pool.requestWithdraw(1_000e6, lp);
    }

    function test_requestWithdraw_premature() external {
        deposit(lp, 1_000e6);

        assertEq(pool.balanceOf(lp), 1_000e6);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(cyclicalWM.exitCycleId(lp),     0);
        assertEq(cyclicalWM.lockedShares(lp),    0);
        assertEq(cyclicalWM.totalCycleShares(3), 0);

        vm.warp(start - 10 days);
        vm.prank(lp);
        vm.expectRevert("PM:RW:NOT_ENABLED");
        pool.requestWithdraw(1_000e6, lp);
    }

    function testDeepFuzz_requestWithdraw(uint256 depositAmount, uint256 withdrawAmount) external {
        depositAmount  = bound(depositAmount,  1, 1e30);
        withdrawAmount = bound(withdrawAmount, 1, depositAmount);

        deposit(lp, depositAmount);

        vm.startPrank(lp);

        assertEq(pool.totalSupply(), depositAmount);
        assertEq(pool.balanceOf(lp), depositAmount);
        assertEq(pool.balanceOf(wm), 0);

        assertEq(cyclicalWM.exitCycleId(lp),     0);
        assertEq(cyclicalWM.lockedShares(lp),    0);
        assertEq(cyclicalWM.totalCycleShares(3), 0);

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

        borrower = makeAddr("borrower");
        lp       = makeAddr("lp");
        wm       = address(cyclicalWM);

        deposit(lp, 1_000e6);
    }

    function test_requestWithdraw_failIfInsufficientApproval() external {
        vm.expectRevert(arithmeticError);
        pool.requestWithdraw(1_000e6, lp);

        vm.prank(lp);
        pool.approve(address(this), 1_000e6 - 1);

        vm.expectRevert(arithmeticError);
        pool.requestWithdraw(1_000e6, lp);
    }

    function test_requestWithdraw_failIfNotPool() external {
        vm.expectRevert("PM:NOT_POOL");
        poolManager.requestRedeem(0, address(lp), address(lp));
    }

    function test_requestWithdraw_failIfNotPM() external {
        vm.expectRevert("WM:AS:NOT_POOL_MANAGER");
        cyclicalWM.addShares(0, address(lp));
    }

}

contract WithdrawFailureTests is TestBase {

    address borrower;
    address lp;
    address wm;

    function setUp() public override {
        super.setUp();

        borrower = makeAddr("borrower");
        lp       = makeAddr("lp");
        wm       = address(cyclicalWM);

        deposit(lp, 1_000e6);
    }

    function test_withdraw_failIfNotPool() external {
        vm.expectRevert("PM:NOT_POOL");
        poolManager.processRedeem(1, lp, lp);
    }

    function test_withdraw_failIfNotPoolManager() external {
        vm.expectRevert("WM:PE:NOT_PM");
        cyclicalWM.processExit(1_000e6, address(lp));
    }

    function test_withdraw_zeroAssetInput() external {
        vm.expectRevert("PM:PW:NOT_ENABLED");
        pool.withdraw(0, lp, lp);
    }

    function test_withdraw_premature() external {
        vm.warp(start - 10 days);
        vm.expectRevert("PM:PW:NOT_ENABLED");
        pool.withdraw(0, lp, lp);
    }

    function testDeepFuzz_withdraw(uint256 assets_, address receiver_, address owner_) external {
        vm.expectRevert("PM:PW:NOT_ENABLED");
        pool.withdraw(assets_, receiver_, owner_);
    }

}

contract WithdrawScenarios is TestBase {

    IFixedTermLoanManager loanManager;

    function setUp() public override {
        super.setUp();

        loanManager = IFixedTermLoanManager(poolManager.loanManagerList(0));

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
        address lp1 = makeAddr("lp1");
        address lp2 = makeAddr("lp2");
        address lp3 = makeAddr("lp3");
        address lp4 = makeAddr("lp4");

        // Deposit liquidity into the pool.
        deposit(address(lp1), 500_000e6);
        deposit(address(lp2), 1_500_000e6);
        deposit(address(lp3), 500_000e6);
        deposit(address(lp4), 1_000_000e6);

        // Fund three loans.
        fundAndDrawdownLoan({
            borrower:    makeAddr("borrower"),
            termDetails: [uint256(5 days), uint256(10 days), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.075e6), uint256(0), uint256(0), uint256(0)],
            loanManager: address(loanManager)
        });

        fundAndDrawdownLoan({
            borrower:    makeAddr("borrower"),
            termDetails: [uint256(5 days), uint256(12 days), uint256(3)],
            amounts:     [uint256(0), uint256(2_000_000e6), uint256(2_000_000e6)],
            rates:       [uint256(0.09e6), uint256(0), uint256(0), uint256(0)],
            loanManager: address(loanManager)
        });

        fundAndDrawdownLoan({
            borrower:    makeAddr("borrower"),
            termDetails: [uint256(5 days), uint256(15 days), uint256(6)],
            amounts:     [uint256(0), uint256(500_000e6), uint256(500_000e6)],
            rates:       [uint256(0.081e6), uint256(0), uint256(0), uint256(0)],
            loanManager: address(loanManager)
        });

        // Deposit extra liquidity to allow for partial withdrawals.
        deposit(makeAddr("depositor"), 500_000e6);

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6);

        // Request all withdrawals.
        requestRedeem(address(lp1),   500_000e6);
        requestRedeem(address(lp2), 1_000_000e6);
        requestRedeem(address(lp3),   500_000e6);
        requestRedeem(address(lp4), 1_000_000e6);

        // Wait until the domain end has elapsed.
        vm.warp(start + 14 days);

        // Assert only 10 days of interest has accrued, even though 14 days have elapsed.
        uint256 interest1 = uint256(1_000_000e6) * 0.075e6 * 10 days / 365 days / 1e6;
        uint256 interest2 = uint256(2_000_000e6) * 0.09e6  * 10 days / 365 days / 1e6;
        uint256 interest3 = uint256(500_000e6)   * 0.081e6 * 10 days / 365 days / 1e6;

        assertEq(loanManager.domainEnd(),             start + 10 days);
        assertEq(loanManager.assetsUnderManagement(), 3_500_000e6 + interest1 + interest2 + interest3 - 1);
        assertEq(loanManager.assetsUnderManagement(), 3_508_095.890409e6);

        // Perform a withdrawal with the 1st and 2nd LP.
        vm.warp(start + 14 days);
        uint256 assets1 = redeem(address(lp1), 500_000e6);
        uint256 assets2 = redeem(address(lp2), 1_000_000e6);

        // Update accounting manually.
        vm.prank(poolDelegate);
        loanManager.updateAccounting();

        // Assert loans have accrued interest up to the latest payment.
        interest1 = uint256(1_000_000e6) * 0.075e6 * 10 days / 365 days / 1e6;
        interest2 = uint256(2_000_000e6) * 0.09e6  * 12 days / 365 days / 1e6;  // Account full loan2 amount.
        interest3 = uint256(500_000e6)   * 0.081e6 * 14 days / 365 days / 1e6;  // 14 days of interest on last loan.

        assertEq(loanManager.domainEnd(),             start + 15 days);
        assertEq(loanManager.assetsUnderManagement(), 3_500_000e6 + interest1 + interest2 + interest3 - 2);
        assertEq(loanManager.assetsUnderManagement(), 3_509_526.027394e6);

        // Perform a withdrawal with the 3rd and 4th LP in the same timestamp to show the atomic change in value after updateAccounting.
        uint256 assets3 = redeem(address(lp3), 500_000e6);
        uint256 assets4 = redeem(address(lp4), 1_000_000e6);

        uint256 totalWithdrawn = assets1 + assets2 + assets3 + assets4;

        assertEq(totalWithdrawn, 500_000e6);

        assertApproxEqAbs(fundsAsset.balanceOf(address(pool)), 0, 1);

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

        // lp3 and lp4 burn less shares than lp2 because of increase in exchange rate.
        assertEq(cyclicalWM.lockedShares(lp1),   500_000e6 -  83_165.009632e6);
        assertEq(cyclicalWM.lockedShares(lp2), 1_000_000e6 - 166_330.019265e6);
        assertEq(cyclicalWM.lockedShares(lp3),   500_000e6 -  83_133.373369e6);
        assertEq(cyclicalWM.lockedShares(lp4), 1_000_000e6 - 166_266.746740e6);
    }

    function test_withdrawals_cashInjection() external {
        address borrower = makeAddr("borrower");

        // Create two liquidity providers.
        address lp1 = makeAddr("lp1");
        address lp2 = makeAddr("lp2");

        // Deposit liquidity into the pool.
        deposit(address(lp1), 1_500_000e6);
        deposit(address(lp2), 2_500_000e6);

        // Fund three loans.
        address bigLoan = fundAndDrawdownLoan({
            borrower:    address(borrower),
            termDetails: [uint256(5 days), uint256(15 days), uint256(1)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(100e6), uint256(0), uint256(0), uint256(0)],
            loanManager: address(loanManager)
        });

        fundAndDrawdownLoan({
            borrower:    address(borrower),
            termDetails: [uint256(5 days), uint256(30 days), uint256(3)],
            amounts:     [uint256(0), uint256(2_000_000e6), uint256(2_000_000e6)],
            rates:       [uint256(0.09e6), uint256(0), uint256(0), uint256(0)],
            loanManager: address(loanManager)
        });

        fundAndDrawdownLoan({
            borrower:    address(borrower),
            termDetails: [uint256(5 days), uint256(30 days), uint256(6)],
            amounts:     [uint256(0), uint256(500_000e6), uint256(500_000e6)],
            rates:       [uint256(0.081e6), uint256(0), uint256(0), uint256(0)],
            loanManager: address(loanManager)
        });

        // First LP requests a withdrawal.
        requestRedeem(address(lp1), 1_500_000e6);
        requestRedeem(address(lp2), 2_500_000e6);

        // First LP exits.
        vm.warp(start + 15 days);

        ( uint256 redeemableShares, , bool partialLiquidity ) = cyclicalWM.getRedeemableAmounts(1_500_000e6, address(lp1));

        assertTrue(partialLiquidity);

        uint256 assets1 = redeem(lp1, 1_500_000e6);

        assertEq(cyclicalWM.lockedShares(address(lp1)), 1_500_000e6 - redeemableShares);
        assertEq(cyclicalWM.exitCycleId(address(lp1)),  4);

        address loan = createFixedTermLoan({
            borrower:    address(borrower),
            termDetails: [uint256(5 days), uint256(30 days), uint256(6)],
            amounts:     [uint256(0), uint256(300_000e6), uint256(300_000e6)],
            rates:       [uint256(0.055e6), uint256(0), uint256(0), uint256(0)],
            loanManager: address(loanManager)
        });

        vm.prank(poolDelegate);
        vm.expectRevert("PM:RF:LOCKED_LIQUIDITY");
        loanManager.fund(address(loan));

        makePayment(bigLoan);

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 1_000_000e6 + 4109589.041095e6 - assets1);

        vm.prank(address(poolDelegate));
        loanManager.fund(address(loan));

        ( redeemableShares, , partialLiquidity ) = cyclicalWM.getRedeemableAmounts(2_500_000e6, address(lp2));

        assertTrue(!partialLiquidity);

        uint256 assets2 = redeem(lp2, 2_500_000e6);

        assertEq(cyclicalWM.lockedShares(address(lp2)), 0);
        assertEq(cyclicalWM.exitCycleId(address(lp2)),  0);

        assertEq(fundsAsset.balanceOf(address(pool)), 500_000e6 + 1_000_000e6 + 4109589.041095e6 - 300_000e6 - assets1 - assets2);
    }

    function test_withdrawals_poorExchangeRates() external {
        address borrower = makeAddr("borrower");

        // Create four liquidity providers.
        address lp1 = makeAddr("lp1");
        address lp2 = makeAddr("lp2");
        address lp3 = makeAddr("lp3");
        address lp4 = makeAddr("lp4");

        // Deposit liquidity into the pool.
        deposit(address(lp1),   500_000e6);
        deposit(address(lp2), 1_500_000e6);
        deposit(address(lp3),   500_000e6);
        deposit(address(lp4), 1_000_000e6);

        // Fund three loans.
        address loan1 = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(10 days), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.075e6), uint256(0), uint256(0), uint256(0)],
            loanManager: address(loanManager)
        });

        address loan2 = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(30 days), uint256(3)],
            amounts:     [uint256(0), uint256(2_000_000e6), uint256(2_000_000e6)],
            rates:       [uint256(0.09e6), uint256(0), uint256(0), uint256(0)],
            loanManager: address(loanManager)
        });

        address loan3 = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5 days), uint256(30 days), uint256(6)],
            amounts:     [uint256(0), uint256(500_000e6), uint256(500_000e6)],
            rates:       [uint256(0.081e6), uint256(0), uint256(0), uint256(0)],
            loanManager: address(loanManager)
        });

        // Request all withdrawals.
        requestRedeem(address(lp1),   500_000e6);
        requestRedeem(address(lp2), 1_500_000e6);
        requestRedeem(address(lp3),   500_000e6);
        requestRedeem(address(lp4), 1_000_000e6);

        assertEq(cyclicalWM.totalCycleShares(3), 3_500_000e6);

        // 1st LP withdraws with no liquidity.
        vm.warp(start + 15 days);
        redeem(address(lp1), 500_000e6);

        assertEq(cyclicalWM.totalCycleShares(3),        3_000_000e6);
        assertEq(cyclicalWM.lockedShares(address(lp1)), 500_000e6);
        assertEq(cyclicalWM.exitCycleId(address(lp1)),  4);

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

        assertEq(cyclicalWM.totalCycleShares(3),        1_500_000e6);
        assertEq(cyclicalWM.lockedShares(address(lp2)), 0);
        assertEq(cyclicalWM.exitCycleId(address(lp2)),  0);

        assertEq(pool.totalSupply(),                 2_000_000e6);
        assertEq(pool.balanceOf(address(lp2)),       0);
        assertEq(fundsAsset.balanceOf(address(lp2)), 0);

        // A cash transfer is used to provide partial liquidity.
        fundsAsset.mint(address(pool), 100_000e6);

        assertEq(poolManager.totalAssets() - poolManager.unrealizedLosses(), 100_000e6);

        // 3rd LP withdraws with full liquidity and a 0.05 exchange rate (100k/2m)
        vm.warp(start + 15.58 days);
        redeem(address(lp3), 500_000e6);

        assertEq(cyclicalWM.lockedShares(address(lp3)), 0);
        assertEq(cyclicalWM.exitCycleId(address(lp3)),  0);

        assertEq(pool.balanceOf(address(lp3)),       0);
        assertEq(fundsAsset.balanceOf(address(lp3)), 500_000e6 * 100_000e6 / 2_000_000e6);
        assertEq(fundsAsset.balanceOf(address(lp3)), 25_000e6);

        // Check if loan impairment calculations are correct.
        (
            ,
            uint256 principal,
            uint256 interest,
            uint256 lateInterest,
            uint256 platformFees,
        ) = loanManager.liquidationInfo(address(loan1));

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

        assertEq(cyclicalWM.lockedShares(address(lp4)), 0);
        assertEq(cyclicalWM.exitCycleId(address(lp4)),  0);

        assertEq(pool.balanceOf(address(lp4)),       0);
        assertEq(fundsAsset.balanceOf(address(lp4)), assetsToWithdraw);
    }

}

contract WithdrawOnPermissionedPool is TestBase {

    IFixedTermLoanManager loanManager;

    function setUp() public override {
        start = block.timestamp;

        // Manually doing setUp steps so the pool is not open to public.
        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createAndConfigurePool(start, 1 weeks, 2 days);

        loanManager = IFixedTermLoanManager(poolManager.loanManagerList(0));

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

        // Since it's a permissioned pool, the withdrawal manager needs to be allowlisted.
        allowLender(address(poolManager), address(cyclicalWM));

        // In the callstack, shares are transferred to the PM first, so it also needs to be allowlisted.
        allowLender(address(poolManager), address(poolManager)); 
    }

    function test_withdraw_withUnwhitelistedUser() external {
        address lp1 = makeAddr("lp1");

        deposit(address(lp1), 500_000e6);

        address[] memory lenders = new address[](1);
        lenders[0] = lp1;

        bool[] memory allows = new bool[](1);
        allows[0] = false;

        requestRedeem(address(lp1), 500_000e6);

        uint256 windowStart = cyclicalWM.getWindowStart(cyclicalWM.exitCycleId(address(lp1)));

        vm.warp(windowStart);

        // Now, remove the LP from the whitelist.
        vm.prank(poolDelegate);
        poolPermissionManager.setLenderAllowlist(address(poolManager), lenders, allows);

        vm.expectRevert("PM:CC:NOT_ALLOWED");
        redeem(address(lp1), 500_000e6);         // This fails because recipient is no longer allowed.
    }

}
