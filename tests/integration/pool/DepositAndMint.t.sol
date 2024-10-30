// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../../TestBase.sol";

contract EnterBase is TestBase {

    address lp;

    function setUp() public virtual override {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createPoolWithCyclical(start, 1 weeks, 2 days);
        // NOTE: As opposed to super.setUp(), do not configure the pool or perform any later steps,
        //       because pool configuration will be validated in the tests.
    }

}

contract DepositTest is EnterBase {

    function setUp() public override {
        super.setUp();

        lp = makeAddr("lp");

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        openPool(address(poolManager));
    }

    function test_deposit_singleUser_oneToOne() public {
        // Pre deposit assertions
        assertEq(pool.balanceOf(lp),                      0);
        assertEq(pool.totalSupply(),                      0);
        assertEq(fundsAsset.balanceOf(address(pool)),     0);
        assertEq(fundsAsset.balanceOf(lp),                0);
        assertEq(fundsAsset.allowance(lp, address(pool)), 0);

        assertEq(poolManager.totalAssets(), 0);

        uint256 shares = deposit(address(pool), lp, 1_000_000e6);

        assertEq(pool.balanceOf(lp),                      shares);
        assertEq(pool.balanceOf(lp),                      1_000_000e6);
        assertEq(pool.totalSupply(),                      1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(pool)),     1_000_000e6);
        assertEq(fundsAsset.balanceOf(lp),                0);
        assertEq(fundsAsset.allowance(lp, address(pool)), 0);

        assertEq(poolManager.totalAssets(), 1_000_000e6);
    }

    function testDeepFuzz_deposit_singleUser(uint256 depositAmount) public {
        // With max uint256, the assertion of allowance after deposit fails because on the token is treated as infinite allowance.
        depositAmount = bound(depositAmount, 1, type(uint256).max - 1);

        // Pre deposit assertions
        assertEq(pool.balanceOf(lp),                      0);
        assertEq(pool.totalSupply(),                      0);
        assertEq(fundsAsset.balanceOf(address(pool)),     0);
        assertEq(fundsAsset.balanceOf(lp),                0);
        assertEq(fundsAsset.allowance(lp, address(pool)), 0);

        assertEq(poolManager.totalAssets(), 0);

        uint256 shares = deposit(address(pool), lp, depositAmount);

        assertEq(pool.balanceOf(lp),                      shares);
        assertEq(pool.balanceOf(lp),                      depositAmount);
        assertEq(pool.totalSupply(),                      depositAmount);
        assertEq(fundsAsset.balanceOf(address(pool)),     depositAmount);
        assertEq(fundsAsset.balanceOf(lp),                0);
        assertEq(fundsAsset.allowance(lp, address(pool)), 0);

        assertEq(poolManager.totalAssets(), depositAmount);
    }

    function test_deposit_twoUsers_oneToOne() public {
        // Pre deposit assertions
        assertEq(pool.balanceOf(lp),                      0);
        assertEq(pool.totalSupply(),                      0);
        assertEq(fundsAsset.balanceOf(address(pool)),     0);
        assertEq(fundsAsset.balanceOf(lp),                0);
        assertEq(fundsAsset.allowance(lp, address(pool)), 0);

        assertEq(poolManager.totalAssets(), 0);

        uint256 shares = deposit(address(pool), lp, 1_000_000e6);

        assertEq(pool.balanceOf(lp),                      shares);
        assertEq(pool.balanceOf(lp),                      1_000_000e6);
        assertEq(pool.totalSupply(),                      1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(pool)),     1_000_000e6);
        assertEq(fundsAsset.balanceOf(lp),                0);
        assertEq(fundsAsset.allowance(lp, address(pool)), 0);

        assertEq(poolManager.totalAssets(), 1_000_000e6);

        address lp2 = makeAddr("lp2");

        // Pre deposit 2 assertions
        assertEq(pool.balanceOf(lp2),                      0);
        assertEq(fundsAsset.balanceOf(lp2),                0);
        assertEq(fundsAsset.allowance(lp2, address(pool)), 0);

        uint256 shares2 = deposit(address(pool), lp2, 3_000_000e6);

        assertEq(pool.balanceOf(lp2),                      shares2);
        assertEq(pool.balanceOf(lp2),                      3_000_000e6);
        assertEq(pool.totalSupply(),                       4_000_000e6);
        assertEq(pool.totalSupply(),                       shares + shares2);
        assertEq(fundsAsset.balanceOf(address(pool)),      4_000_000e6);
        assertEq(fundsAsset.balanceOf(lp2),                0);
        assertEq(fundsAsset.allowance(lp2, address(pool)), 0);

        assertEq(poolManager.totalAssets(), 4_000_000e6);
    }

    function testDeepFuzz_deposit_variableExchangeRate(uint256 depositAmount, uint256 warpTime) public {
        address initialDepositor = makeAddr("initialDepositor");

        deposit(address(pool), initialDepositor, 1_000_000e6);

        // Fund loan
        fundAndDrawdownLoan({
            borrower:    makeAddr("borrower"),
            termDetails: [uint256(12 hours), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e6), uint256(0), uint256(0), uint256(0)],
            loanManager: poolManager.strategyList(0)
        });

        // Constrict time to be within the first loan payment and amount to be within token amounts
        warpTime      = bound(warpTime,      0, 1_000_000);
        depositAmount = bound(depositAmount, 1, 1e32);

        vm.warp(start + warpTime);

        uint256 previewedShares = pool.previewDeposit(depositAmount);

        if (previewedShares == 0) {
            vm.expectRevert("P:M:ZERO_SHARES");
            vm.prank(lp);
            pool.deposit(depositAmount, lp);
        } else {
            uint256 expectedShares = depositAmount * pool.totalSupply() / poolManager.totalAssets();

            uint256 shares = deposit(address(pool), lp, depositAmount);

            assertEq(shares,                                  expectedShares);
            assertEq(pool.totalSupply(),                      shares + 1_000_000e6);
            assertEq(pool.balanceOf(lp),                      shares);
            assertEq(fundsAsset.balanceOf(address(pool)),     depositAmount);
            assertEq(fundsAsset.balanceOf(lp),                0);
            assertEq(fundsAsset.allowance(lp, address(pool)), 0);
        }
    }

}

contract DepositWithPermitTests is EnterBase {

    uint256 deadline = 5_000_000_000;
    uint256 lpPK     = 1;

    function setUp() public override {
        super.setUp();

        lp = vm.addr(lpPK);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        openPool(address(poolManager));
    }

    function test_depositWithPermit_singleUser() public {
        // Pre deposit assertions
        assertEq(pool.balanceOf(lp),                      0);
        assertEq(pool.totalSupply(),                      0);
        assertEq(fundsAsset.balanceOf(address(pool)),     0);
        assertEq(fundsAsset.balanceOf(lp),                0);
        assertEq(fundsAsset.allowance(lp, address(pool)), 0);

        assertEq(poolManager.totalAssets(), 0);

        uint256 shares = depositWithPermit(address(pool), lpPK, 1_000_000e6, deadline);

        assertEq(pool.balanceOf(lp),                      shares);
        assertEq(pool.balanceOf(lp),                      1_000_000e6);
        assertEq(pool.totalSupply(),                      1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(pool)),     1_000_000e6);
        assertEq(fundsAsset.balanceOf(lp),                0);
        assertEq(fundsAsset.allowance(lp, address(pool)), 0);

        assertEq(poolManager.totalAssets(), 1_000_000e6);
    }

    function testDeepFuzz_depositWithPermit_singleUser(uint256 depositAmount) public {
        // With max uint256, the assertion of allowance after deposit fails because on the token is treated as infinite allowance.
        depositAmount = bound(depositAmount, 1, type(uint256).max - 1);

        // Pre deposit assertions
        assertEq(pool.balanceOf(lp),                      0);
        assertEq(pool.totalSupply(),                      0);
        assertEq(fundsAsset.balanceOf(address(pool)),     0);
        assertEq(fundsAsset.balanceOf(lp),                0);
        assertEq(fundsAsset.allowance(lp, address(pool)), 0);

        assertEq(poolManager.totalAssets(), 0);

        uint256 shares = depositWithPermit(address(pool), lpPK, depositAmount, deadline);

        assertEq(pool.balanceOf(lp),                      shares);
        assertEq(pool.balanceOf(lp),                      depositAmount);
        assertEq(pool.totalSupply(),                      depositAmount);
        assertEq(fundsAsset.balanceOf(address(pool)),     depositAmount);
        assertEq(fundsAsset.balanceOf(lp),                0);
        assertEq(fundsAsset.allowance(lp, address(pool)), 0);

        assertEq(poolManager.totalAssets(), depositAmount);
    }

}

contract DepositFailureTests is EnterBase {

    function setUp() public virtual override {
        super.setUp();

        lp = makeAddr("lp");
    }

    function test_deposit_protocolPaused() external {
        uint256 liquidity = 1_000e6;

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("PM:CC:PAUSED");
        vm.prank(lp);
        pool.deposit(liquidity, lp);
    }

    function test_deposit_privatePoolInvalidRecipient() external {
        uint256 liquidity = 1_000e6;

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.expectRevert("PM:CC:NOT_ALLOWED");
        vm.prank(lp);
        pool.deposit(liquidity, lp);

        allowLender(address(poolManager), lp);

        deposit(address(pool), lp, liquidity);
    }

    function test_deposit_privatePoolInvalidRecipient_openPoolToPublic() external {
        uint256 liquidity = 1_000e6;

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.expectRevert("PM:CC:NOT_ALLOWED");
        vm.prank(lp);
        pool.deposit(liquidity, lp);

        // Pool is opened to public, shares may be transferred to anyone.
        openPool(address(poolManager));

        deposit(address(pool), lp, liquidity);
    }

    function test_deposit_liquidityCapExceeded() external {
        uint256 liquidity = 1_000e6;

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        openPool(address(poolManager));
        setLiquidityCap(address(poolManager), liquidity);

        // Deposit an initial amount before setting liquidity cap.
        deposit(address(pool), lp, 400e6);

        vm.expectRevert("P:DEPOSIT_GT_LIQ_CAP");
        vm.prank(lp);
        pool.deposit(600e6 + 1, lp);

        deposit(address(pool), lp, 600e6);
    }

    function test_deposit_insufficientApproval() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        allowLender(address(poolManager), lp);

        vm.startPrank(lp);

        fundsAsset.approve(address(pool), liquidity - 1);

        vm.expectRevert("P:M:TRANSFER_FROM");
        pool.deposit(liquidity, lp);

        vm.stopPrank();
    }

}

contract DepositWithPermitFailureTests is EnterBase {

    uint256 deadline = 5_000_000_000;
    uint256 lpSk     = 1;

    function setUp() public virtual override {
        super.setUp();

        lp = vm.addr(lpSk);
    }

    function test_depositWithPermit_protocolPaused() external {
        uint256 liquidity = 1_000e6;

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        allowLender(address(poolManager), lp);

        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("PM:CC:PAUSED");
        vm.prank(lp);
        pool.depositWithPermit(liquidity, lp, deadline, 0, bytes32(0), bytes32(0));
    }

    function test_depositWithPermit_privatePoolInvalidRecipient() external {
        uint256 liquidity = 1_000e6;

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.expectRevert("PM:CC:NOT_ALLOWED");
        vm.prank(lp);
        pool.depositWithPermit(liquidity, lp, deadline, 0, bytes32(0), bytes32(0));

        allowLender(address(poolManager), lp);

        depositWithPermit(address(pool), lpSk, liquidity, deadline);
    }

    function test_depositWithPermit_privatePoolInvalidRecipient_openPoolToPublic() external {
        uint256 liquidity = 1_000e6;

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.expectRevert("PM:CC:NOT_ALLOWED");
        vm.prank(lp);
        pool.depositWithPermit(liquidity, lp, deadline, 0, bytes32(0), bytes32(0));

        // Pool is opened to public, shares may be transferred to anyone.
        openPool(address(poolManager));

        depositWithPermit(address(pool), lpSk, liquidity, deadline);
    }

    function test_depositWithPermit_liquidityCapExceeded() external {
        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        openPool(address(poolManager));
        setLiquidityCap(address(poolManager), 1_000e6);

        // Deposit an initial amount before setting liquidity cap.
        depositWithPermit(address(pool), lpSk, 400e6, deadline);

        vm.expectRevert("P:DEPOSIT_GT_LIQ_CAP");
        vm.prank(lp);
        pool.depositWithPermit(600e6 + 1, lp, deadline, 0, bytes32(0), bytes32(0));

        depositWithPermit(address(pool), lpSk, 600e6, deadline);
    }

    function test_depositWithPermit_invalidSignature() external {
        uint256 liquidity = 1_000e6;

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        allowLender(address(poolManager), lp);

        (
            uint8   v,
            bytes32 r,
            bytes32 s
        ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity - 1, deadline, lpSk);

        vm.expectRevert("ERC20:P:INVALID_SIGNATURE");
        vm.prank(lp);
        pool.depositWithPermit(liquidity, lp, deadline, v, r, s);

        depositWithPermit(address(pool), lpSk, liquidity, deadline);
    }

}

contract MintTest is EnterBase {

    function setUp() public override {
        super.setUp();

        lp = makeAddr("lp");

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        openPool(address(poolManager));
    }

    function test_mint_singleUser_oneToOne() public {
        // Pre mint assertions
        assertEq(pool.balanceOf(lp),                      0);
        assertEq(pool.totalSupply(),                      0);
        assertEq(fundsAsset.balanceOf(address(pool)),     0);
        assertEq(fundsAsset.balanceOf(lp),                0);
        assertEq(fundsAsset.allowance(lp, address(pool)), 0);

        assertEq(poolManager.totalAssets(), 0);

        uint256 shares = mint(address(pool), lp, 1_000_000e6);

        assertEq(pool.balanceOf(lp),                      shares);
        assertEq(pool.balanceOf(lp),                      1_000_000e6);
        assertEq(pool.totalSupply(),                      1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(pool)),     1_000_000e6);
        assertEq(fundsAsset.balanceOf(lp),                0);
        assertEq(fundsAsset.allowance(lp, address(pool)), 0);

        assertEq(poolManager.totalAssets(), 1_000_000e6);
    }

    function testDeepFuzz_mint_singleUser(uint256 mintAmount) public {
        // With max uint256, the assertion of allowance after deposit fails because on the token is treated as infinite allowance.
        mintAmount = bound(mintAmount, 1, type(uint256).max - 1);

        // Pre mint assertions
        assertEq(pool.balanceOf(lp),                      0);
        assertEq(pool.totalSupply(),                      0);
        assertEq(fundsAsset.balanceOf(address(pool)),     0);
        assertEq(fundsAsset.balanceOf(lp),                0);
        assertEq(fundsAsset.allowance(lp, address(pool)), 0);

        assertEq(poolManager.totalAssets(), 0);

        uint256 shares = mint(address(pool), lp, mintAmount);

        assertEq(pool.balanceOf(lp),                      shares);
        assertEq(pool.balanceOf(lp),                      mintAmount);
        assertEq(pool.totalSupply(),                      mintAmount);
        assertEq(fundsAsset.balanceOf(address(pool)),     mintAmount);
        assertEq(fundsAsset.balanceOf(lp),                0);
        assertEq(fundsAsset.allowance(lp, address(pool)), 0);

        assertEq(poolManager.totalAssets(), mintAmount);
    }

    function test_mint_twoUsers_oneToOne() public {
        // Pre mint assertions
        assertEq(pool.balanceOf(lp),                      0);
        assertEq(pool.totalSupply(),                      0);
        assertEq(fundsAsset.balanceOf(address(pool)),     0);
        assertEq(fundsAsset.balanceOf(lp),                0);
        assertEq(fundsAsset.allowance(lp, address(pool)), 0);

        assertEq(poolManager.totalAssets(), 0);

        uint256 shares = mint(address(pool), lp, 1_000_000e6);

        assertEq(pool.balanceOf(lp),                      shares);
        assertEq(pool.balanceOf(lp),                      1_000_000e6);
        assertEq(pool.totalSupply(),                      1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(pool)),     1_000_000e6);
        assertEq(fundsAsset.balanceOf(lp),                0);
        assertEq(fundsAsset.allowance(lp, address(pool)), 0);

        assertEq(poolManager.totalAssets(), 1_000_000e6);

        address lp2 = makeAddr("lp2");

        // Pre mint 2 assertions
        assertEq(pool.balanceOf(lp2), 0);
        assertEq(fundsAsset.balanceOf(lp2),                0);
        assertEq(fundsAsset.allowance(lp2, address(pool)), 0);

        uint256 shares2 = mint(address(pool), lp2, 3_000_000e6);

        assertEq(pool.balanceOf(lp2),                      shares2);
        assertEq(pool.balanceOf(lp2),                      3_000_000e6);
        assertEq(pool.totalSupply(),                       4_000_000e6);
        assertEq(pool.totalSupply(),                       shares + shares2);
        assertEq(fundsAsset.balanceOf(address(pool)),      4_000_000e6);
        assertEq(fundsAsset.balanceOf(lp2),                0);
        assertEq(fundsAsset.allowance(lp2, address(pool)), 0);

        assertEq(poolManager.totalAssets(), 4_000_000e6);
    }

    function testDeepFuzz_mint_variableExchangeRate(uint256 assetAmount, uint256 warpTime) public {
        address initialDepositor = makeAddr("initialDepositor");

        mint(address(pool), initialDepositor, 1_000_000e6);

        // Fund loan
        fundAndDrawdownLoan({
            borrower:    makeAddr("borrower"),
            termDetails: [uint256(12 hours), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e6), uint256(0), uint256(0), uint256(0)],
            loanManager: poolManager.strategyList(0)
        });

        // Constrict time to be within the first loan payment and amount to be within token amounts
        warpTime    = bound(warpTime, 2, 1_000_000);
        assetAmount = bound(assetAmount, 1e6, 1e32);

        vm.warp(start + warpTime);

        uint256 calculatedShares = pool.convertToShares(assetAmount);

        if (calculatedShares == 0) {
            vm.prank(lp);
            vm.expectRevert("P:M:ZERO_SHARES");
            pool.mint(assetAmount, lp);
        } else {
            uint256 expectedShares = assetAmount * pool.totalSupply() / poolManager.totalAssets();

            uint256 assets = mint(address(pool), lp, calculatedShares);

            assertEq(pool.balanceOf(lp), expectedShares);

            assertApproxEqAbs(assets,                                  assetAmount,                    1);
            assertApproxEqAbs(pool.totalSupply(),                      calculatedShares + 1_000_000e6, 1);
            assertApproxEqAbs(pool.balanceOf(lp),                      calculatedShares,               0);
            // Assets from initial depositor are in the loan
            assertApproxEqAbs(fundsAsset.balanceOf(address(pool)),     assetAmount,                    1);
            assertApproxEqAbs(fundsAsset.balanceOf(lp),                0,                              1);
            assertApproxEqAbs(fundsAsset.allowance(lp, address(pool)), 0,                              1);
        }
    }

}

contract MintWithPermitTests is EnterBase {

    uint256 deadline = 5_000_000_000;
    uint256 lpPK     = 1;

    function setUp() public override {
        super.setUp();

        lp = vm.addr(lpPK);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        openPool(address(poolManager));
    }

    function test_mintWithPermit_singleUser() public {
        // Pre mint assertions
        assertEq(pool.balanceOf(lp),                      0);
        assertEq(pool.totalSupply(),                      0);
        assertEq(fundsAsset.balanceOf(address(pool)),     0);
        assertEq(fundsAsset.balanceOf(lp),                0);
        assertEq(fundsAsset.allowance(lp, address(pool)), 0);

        assertEq(poolManager.totalAssets(), 0);

        uint256 shares = mintWithPermit(address(pool), lpPK, 1_000_000e6, deadline);

        assertEq(pool.balanceOf(lp),                      shares);
        assertEq(pool.balanceOf(lp),                      1_000_000e6);
        assertEq(pool.totalSupply(),                      1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(pool)),     1_000_000e6);
        assertEq(fundsAsset.balanceOf(lp),                0);
        assertEq(fundsAsset.allowance(lp, address(pool)), 0);

        assertEq(poolManager.totalAssets(), 1_000_000e6);
    }

    function testDeepFuzz_mintWithPermit_singleUser(uint256 mintAmount) public {
        vm.assume(mintAmount > 0);
        // With max uint256, the assertion of allowance after deposit fails because in the token is treated as infinite allowance.
        vm.assume(mintAmount <= type(uint256).max - 1);

        // Pre mint assertions
        assertEq(pool.balanceOf(lp),                      0);
        assertEq(pool.totalSupply(),                      0);
        assertEq(fundsAsset.balanceOf(address(pool)),     0);
        assertEq(fundsAsset.balanceOf(lp),                0);
        assertEq(fundsAsset.allowance(lp, address(pool)), 0);

        assertEq(poolManager.totalAssets(), 0);

        uint256 shares = mintWithPermit(address(pool), lpPK, mintAmount, deadline);

        assertEq(pool.balanceOf(lp),                      shares);
        assertEq(pool.balanceOf(lp),                      mintAmount);
        assertEq(pool.totalSupply(),                      mintAmount);
        assertEq(fundsAsset.balanceOf(address(pool)),     mintAmount);
        assertEq(fundsAsset.balanceOf(lp),                0);
        assertEq(fundsAsset.allowance(lp, address(pool)), 0);

        assertEq(poolManager.totalAssets(), mintAmount);
    }

}

contract MintFailureTests is EnterBase {

    function setUp() public virtual override {
        super.setUp();

        lp = makeAddr("lp");
    }

    function test_mint_protocolPaused() external {
        uint256 liquidity = 1_000e6;

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        allowLender(address(poolManager), lp);

        vm.prank(governor);
        globals.setProtocolPause(true);

        uint256 shares = pool.previewDeposit(liquidity);

        vm.expectRevert("PM:CC:PAUSED");
        vm.prank(lp);
        pool.mint(shares, lp);
    }

    function test_mint_privatePoolInvalidRecipient() external {
        uint256 liquidity = 1_000e6;

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        uint256 shares = pool.previewDeposit(liquidity);

        vm.expectRevert("PM:CC:NOT_ALLOWED");
        vm.prank(lp);
        pool.mint(shares, lp);

        allowLender(address(poolManager), lp);

        mint(address(pool), lp, shares);
    }

    function test_mint_privatePoolInvalidRecipient_openPoolToPublic() external {
        uint256 liquidity = 1_000e6;

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        uint256 shares = pool.previewDeposit(liquidity);

        vm.expectRevert("PM:CC:NOT_ALLOWED");
        vm.prank(lp);
        pool.mint(shares, lp);

        // Pool is opened to public, shares may be transferred to anyone.
        openPool(address(poolManager));

        mint(address(pool), lp, shares);
    }

    function test_mint_liquidityCapExceeded() external {
        uint256 liquidity = 1_000e6;

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        openPool(address(poolManager));
        setLiquidityCap(address(poolManager), 1_000e6);

        uint256 shares = pool.previewDeposit(liquidity);

        // Deposit an initial amount before setting liquidity cap.
        uint256 initialMintAmount = shares * 4 / 10;
        uint256 nextMintAmount    = shares - initialMintAmount;

        mint(address(pool), lp, initialMintAmount);

        vm.expectRevert("P:DEPOSIT_GT_LIQ_CAP");
        vm.prank(lp);
        pool.mint(nextMintAmount + 1, lp);

        mint(address(pool), lp, nextMintAmount);
    }

    function test_mint_insufficientApproval() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        allowLender(address(poolManager), lp);

        uint256 shares = pool.previewDeposit(liquidity);

        vm.startPrank(lp);

        fundsAsset.approve(address(pool), liquidity - 1);

        vm.expectRevert("P:M:TRANSFER_FROM");
        pool.mint(shares, lp);

        vm.stopPrank();
    }

}

contract MintWithPermitFailureTests is EnterBase {

    uint256 deadline = 5_000_000_000;
    uint256 lpSk     = 1;

    function setUp() public virtual override {
        super.setUp();

        lp = vm.addr(lpSk);
    }

    function test_mintWithPermit_protocolPaused() external {
        uint256 liquidity = 1_000e6;

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        allowLender(address(poolManager), lp);

        vm.prank(governor);
        globals.setProtocolPause(true);

        uint256 shares = pool.previewDeposit(liquidity);

        vm.expectRevert("PM:CC:PAUSED");
        vm.prank(lp);
        pool.mintWithPermit(shares, lp, liquidity, deadline, 0, bytes32(0), bytes32(0));
    }

    function test_mintWithPermit_privatePoolInvalidRecipient() external {
        uint256 liquidity = 1_000e6;

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        uint256 shares = pool.previewDeposit(liquidity);

        vm.expectRevert("PM:CC:NOT_ALLOWED");
        vm.prank(lp);
        pool.mintWithPermit(shares, lp, liquidity, deadline, 0, bytes32(0), bytes32(0));

        allowLender(address(poolManager), lp);

        mintWithPermit(address(pool), lpSk, shares, deadline);
    }

    function test_mintWithPermit_privatePoolInvalidRecipient_openPoolToPublic() external {
        uint256 liquidity = 1_000e6;

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        uint256 shares = pool.previewDeposit(liquidity);

        vm.expectRevert("PM:CC:NOT_ALLOWED");
        vm.prank(lp);
        pool.mintWithPermit(shares, lp, liquidity, deadline, 0, bytes32(0), bytes32(0));

        // Pool is opened to public, shares may be transferred to anyone.
        openPool(address(poolManager));

        mintWithPermit(address(pool), lpSk, shares, deadline);
    }

    function test_mintWithPermit_liquidityCapExceeded() external {
        uint256 liquidity = 1_000e6;

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        openPool(address(poolManager));
        setLiquidityCap(address(poolManager), 1_000e6);

        uint256 shares = pool.previewDeposit(liquidity);

        // Deposit an initial amount before setting liquidity cap.
        uint256 initialMintAmount = shares * 4 / 10;
        uint256 nextMintAmount    = shares - initialMintAmount;

        mintWithPermit(address(pool), lpSk, initialMintAmount, deadline);

        vm.expectRevert("P:DEPOSIT_GT_LIQ_CAP");
        vm.prank(lp);
        pool.mintWithPermit(nextMintAmount + 1, lp, liquidity, deadline, 0, bytes32(0), bytes32(0));

        mintWithPermit(address(pool), lpSk, nextMintAmount, deadline);
    }

    function test_mintWithPermit_insufficientPermit() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        allowLender(address(poolManager), lp);

        uint256 shares = pool.previewDeposit(liquidity);
        uint256 assets = pool.previewMint(shares);

        (
            uint8   v,
            bytes32 r,
            bytes32 s
        ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), assets - 1, deadline, lpSk);

        vm.expectRevert("P:MWP:INSUFFICIENT_PERMIT");
        vm.prank(lp);
        pool.mintWithPermit(shares, lp, assets - 1, deadline, v, r, s);

        mintWithPermit(address(pool), lpSk, shares, deadline);
    }

}
