// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract BootstrapTestBase is TestBaseWithAssertions {

    uint256 constant BOOTSTRAP_MINT_AMOUNT = 1e5;

    address lp1;
    address lp2;

    function setUp() public virtual override {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();

        vm.prank(governor);
        globals.setBootstrapMint(address(fundsAsset), BOOTSTRAP_MINT_AMOUNT);

        _createFactories();
        _createAndConfigurePool(start, 1 weeks, 2 days);
        openPool(address(poolManager));

        lp1 = makeAddr("lp1");
        lp2 = makeAddr("lp2");

        assertEq(pool.BOOTSTRAP_MINT(), 1e5);
    }

}

contract SetBootstrapMintTests is BootstrapTestBase {

    function test_setBootstrapMint_failIfNotOperationalAdmin() external {
        vm.expectRevert("MG:NOT_GOV_OR_OA");
        globals.setBootstrapMint(address(fundsAsset), BOOTSTRAP_MINT_AMOUNT);
    }

    function test_setBootstrapMint_success_asOperationalAdmin() external {
        vm.prank(governor);
        globals.setBootstrapMint(address(fundsAsset), 0);

        assertEq(globals.bootstrapMint(address(fundsAsset)), 0);

        vm.prank(operationalAdmin);
        globals.setBootstrapMint(address(fundsAsset), BOOTSTRAP_MINT_AMOUNT);

        assertEq(globals.bootstrapMint(address(fundsAsset)), BOOTSTRAP_MINT_AMOUNT);
    }

}

contract BootstrapDepositTests is BootstrapTestBase {

    function test_deposit_ltBootstrapMintAmount() external {
        fundsAsset.mint(lp1, BOOTSTRAP_MINT_AMOUNT - 1);

        vm.startPrank(lp1);

        fundsAsset.approve(address(pool), BOOTSTRAP_MINT_AMOUNT - 1);

        vm.expectRevert(arithmeticError);
        pool.deposit(BOOTSTRAP_MINT_AMOUNT - 1, lp1);

        vm.stopPrank();
    }

    function testFuzz_deposit_ltBootstrapMintAmount(uint256 amount_) external {
        amount_ = bound(amount_, 1, BOOTSTRAP_MINT_AMOUNT - 1);

        fundsAsset.mint(lp1, amount_);

        vm.startPrank(lp1);

        fundsAsset.approve(address(pool), amount_);

        vm.expectRevert(arithmeticError);
        pool.deposit(amount_, lp1);

        vm.stopPrank();
    }

    function test_deposit_exactBootstrapMintAmount() public {
        deposit(lp1, BOOTSTRAP_MINT_AMOUNT);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp1), 0);
    }

    function test_deposit_gtBootstrapMintAmount() public {
        deposit(lp1, BOOTSTRAP_MINT_AMOUNT + 1);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT + 1,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT + 1,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT + 1
        });

        assertEq(pool.balanceOf(lp1), 1);
    }

    function testFuzz_deposit_gtBootstrapMintAmount(uint256 amount_) external {
        amount_ = bound(amount_, BOOTSTRAP_MINT_AMOUNT + 1, 1_000_000e6);

        deposit(lp1, amount_);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        amount_,
            totalAssets:        amount_,
            unrealizedLosses:   0,
            availableLiquidity: amount_
        });

        assertEq(pool.balanceOf(lp1), amount_ - BOOTSTRAP_MINT_AMOUNT);
    }

    function test_deposit_secondDepositorGetsCorrectShares() external {
        deposit(lp1, BOOTSTRAP_MINT_AMOUNT);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp1), 0);

        deposit(lp2, 10_000e6);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT + 10_000e6,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT + 10_000e6,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT + 10_000e6
        });

        assertEq(pool.balanceOf(lp2), 10_000e6);
    }

    function testFuzz_deposit_secondDepositorGetsCorrectShares(uint256 amount_) external {
        amount_ = bound(amount_, 1, 1_000_000e6);

        deposit(lp1, BOOTSTRAP_MINT_AMOUNT);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp1), 0);

        deposit(lp2, amount_);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT + amount_,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT + amount_,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT + amount_
        });

        assertEq(pool.balanceOf(lp2), amount_);
    }

}

contract BootstrapDepositWithPermitTests is BootstrapTestBase {

    uint256 deadline = 5_000_000_000;
    uint256 lp1PK    = 1;
    uint256 lp2PK    = 2;

    function setUp() override public {
        super.setUp();

        lp1 = vm.addr(lp1PK);
        lp2 = vm.addr(lp2PK);
    }

    function test_depositWithPermit_ltBootstrapMintAmount() external {
        fundsAsset.mint(lp1, BOOTSTRAP_MINT_AMOUNT - 1);

        (
            uint8   v,
            bytes32 r,
            bytes32 s
        ) = _getValidPermitSignature(address(fundsAsset), lp1, address(pool), BOOTSTRAP_MINT_AMOUNT - 1, deadline, lp1PK);

        vm.expectRevert(arithmeticError);
        vm.prank(lp1);
        pool.depositWithPermit(BOOTSTRAP_MINT_AMOUNT - 1, lp1, deadline, v, r, s);
    }

    function testFuzz_depositWithPermit_ltBootstrapMintAmount(uint256 amount_) external {
        amount_ = bound(amount_, 1, BOOTSTRAP_MINT_AMOUNT - 1);

        (
            uint8   v,
            bytes32 r,
            bytes32 s
        ) = _getValidPermitSignature(address(fundsAsset), lp1, address(pool), amount_, deadline, lp1PK);

        vm.expectRevert(arithmeticError);
        vm.prank(lp1);
        pool.depositWithPermit(amount_, lp1, deadline, v, r, s);
    }

    function test_depositWithPermit_exactBootstrapMintAmount() public {
        depositWithPermit(address(pool), lp1PK, BOOTSTRAP_MINT_AMOUNT, deadline);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp1), 0);
    }

    function test_depositWithPermit_gtBootstrapMintAmount() public {
        depositWithPermit(address(pool), lp1PK, BOOTSTRAP_MINT_AMOUNT + 1, deadline);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT + 1,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT + 1,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT + 1
        });

        assertEq(pool.balanceOf(lp1), 1);
    }

    function testFuzz_depositWithPermit_gtBootstrapMintAmount(uint256 amount_) external {
        amount_ = bound(amount_, BOOTSTRAP_MINT_AMOUNT + 1, 1_000_000e6);

        depositWithPermit(address(pool), lp1PK, amount_, deadline);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        amount_,
            totalAssets:        amount_,
            unrealizedLosses:   0,
            availableLiquidity: amount_
        });

        assertEq(pool.balanceOf(lp1), amount_ - BOOTSTRAP_MINT_AMOUNT);
    }

    function test_depositWithPermit_secondDepositorGetsCorrectShares() external {
        depositWithPermit(address(pool), lp1PK, BOOTSTRAP_MINT_AMOUNT, deadline);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp1), 0);

        depositWithPermit(address(pool), lp2PK, 10_000e6, deadline);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT + 10_000e6,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT + 10_000e6,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT + 10_000e6
        });

        assertEq(pool.balanceOf(lp2), 10_000e6);
    }

    function testFuzz_depositWithPermit_secondDepositorGetsCorrectShares(uint256 amount_) external {
        amount_ = bound(amount_, 1, 1_000_000e6);

        depositWithPermit(address(pool), lp1PK, BOOTSTRAP_MINT_AMOUNT, deadline);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp1), 0);

        depositWithPermit(address(pool), lp2PK, amount_, deadline);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT + amount_,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT + amount_,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT + amount_
        });

        assertEq(pool.balanceOf(lp2), amount_);
    }

}

contract BootstrapMintTests is BootstrapTestBase {

    function test_mint_ltBootstrapMintAmount() external {
        fundsAsset.mint(lp1, BOOTSTRAP_MINT_AMOUNT - 1);

        vm.startPrank(lp1);

        fundsAsset.approve(address(pool), BOOTSTRAP_MINT_AMOUNT - 1);

        vm.expectRevert(arithmeticError);
        pool.mint(BOOTSTRAP_MINT_AMOUNT - 1, lp1);

        vm.stopPrank();
    }

    function testFuzz_mint_ltBootstrapMintAmount(uint256 amount_) external {
        amount_ = bound(amount_, 1, BOOTSTRAP_MINT_AMOUNT - 1);

        fundsAsset.mint(lp1, amount_);

        vm.startPrank(lp1);

        fundsAsset.approve(address(pool), amount_);

        vm.expectRevert(arithmeticError);
        pool.mint(amount_, lp1);

        vm.stopPrank();
    }

    function test_mint_exactBootstrapMintAmount() public {
        mint(address(pool), lp1, BOOTSTRAP_MINT_AMOUNT);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp1), 0);
    }

    function test_mint_gtBootstrapMintAmount() public {
        mint(address(pool), lp1, BOOTSTRAP_MINT_AMOUNT + 1);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT + 1,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT + 1,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT + 1
        });

        assertEq(pool.balanceOf(lp1), 1);
    }

    function testFuzz_mint_gtBootstrapMintAmount(uint256 amount_) external {
        amount_ = bound(amount_, BOOTSTRAP_MINT_AMOUNT + 1, 1_000_000e6);

        mint(address(pool), lp1, amount_);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        amount_,
            totalAssets:        amount_,
            unrealizedLosses:   0,
            availableLiquidity: amount_
        });

        assertEq(pool.balanceOf(lp1), amount_ - BOOTSTRAP_MINT_AMOUNT);
    }

    function test_mint_secondDepositorGetsCorrectShares() external {
        mint(address(pool), lp1, BOOTSTRAP_MINT_AMOUNT);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp1), 0);

        mint(address(pool), lp2, 10_000e6);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT + 10_000e6,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT + 10_000e6,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT + 10_000e6
        });

        assertEq(pool.balanceOf(lp2), 10_000e6);
    }

    function testFuzz_mint_secondDepositorGetsCorrectShares(uint256 amount_) external {
        amount_ = bound(amount_, 1, 1_000_000e6);

        mint(address(pool), lp1, BOOTSTRAP_MINT_AMOUNT);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp1), 0);

        mint(address(pool), lp2, amount_);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT + amount_,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT + amount_,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT + amount_
        });

        assertEq(pool.balanceOf(lp2), amount_);
    }

}

contract BootstrapMintWithPermitTests is BootstrapTestBase {

    uint256 deadline = 5_000_000_000;
    uint256 lp1PK    = 1;
    uint256 lp2PK    = 2;

    function setUp() override public {
        super.setUp();

        lp1  = vm.addr(lp1PK);
        lp2 = vm.addr(lp2PK);
    }

    function test_mintWithPermit_ltBootstrapMintAmount() external {
        fundsAsset.mint(lp1, BOOTSTRAP_MINT_AMOUNT - 1);

        (
            uint8   v,
            bytes32 r,
            bytes32 s
        ) = _getValidPermitSignature(address(fundsAsset), lp1, address(pool), BOOTSTRAP_MINT_AMOUNT - 1, deadline, lp1PK);

        vm.expectRevert(arithmeticError);
        vm.prank(lp1);
        pool.mintWithPermit(BOOTSTRAP_MINT_AMOUNT - 1, lp1, BOOTSTRAP_MINT_AMOUNT - 1, deadline, v, r, s);
    }

    function testFuzz_mintWithPermit_ltBootstrapMintAmount(uint256 amount_) external {
        amount_ = bound(amount_, 1, BOOTSTRAP_MINT_AMOUNT - 1);

        (
            uint8   v,
            bytes32 r,
            bytes32 s
        ) = _getValidPermitSignature(address(fundsAsset), lp1, address(pool), amount_, deadline, lp1PK);

        vm.expectRevert(arithmeticError);
        vm.prank(lp1);
        pool.mintWithPermit(amount_, lp1, amount_, deadline, v, r, s);
    }

    function test_mintWithPermit_exactBootstrapMintAmount() public {
        mintWithPermit(address(pool), lp1PK, BOOTSTRAP_MINT_AMOUNT, deadline);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp1), 0);
    }

    function test_mintWithPermit_gtBootstrapMintAmount() public {
        mintWithPermit(address(pool), lp1PK, BOOTSTRAP_MINT_AMOUNT + 1, deadline);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT + 1,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT + 1,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT + 1
        });

        assertEq(pool.balanceOf(lp1), 1);
    }

    function testFuzz_mintWithPermit_gtBootstrapMintAmount(uint256 amount_) external {
        amount_ = bound(amount_, BOOTSTRAP_MINT_AMOUNT + 1, 1_000_000e6);

        mintWithPermit(address(pool), lp1PK, amount_, deadline);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        amount_,
            totalAssets:        amount_,
            unrealizedLosses:   0,
            availableLiquidity: amount_
        });

        assertEq(pool.balanceOf(lp1), amount_ - BOOTSTRAP_MINT_AMOUNT);
    }

    function test_mintWithPermit_secondDepositorGetsCorrectShares() external {
        mintWithPermit(address(pool), lp1PK, BOOTSTRAP_MINT_AMOUNT, deadline);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp1), 0);

        mintWithPermit(address(pool), lp2PK, 10_000e6, deadline);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT + 10_000e6,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT + 10_000e6,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT + 10_000e6
        });

        assertEq(pool.balanceOf(lp2), 10_000e6);
    }

    function testFuzz_mintWithPermit_secondDepositorGetsCorrectShares(uint256 amount_) external {
        amount_ = bound(amount_, 1, 1_000_000e6);

        mintWithPermit(address(pool), lp1PK, BOOTSTRAP_MINT_AMOUNT, deadline);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp1), 0);

        mintWithPermit(address(pool), lp2PK, amount_, deadline);

        assertPoolState({
            pool:               address(pool),
            totalSupply:        BOOTSTRAP_MINT_AMOUNT + amount_,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT + amount_,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT + amount_
        });

        assertEq(pool.balanceOf(lp2), amount_);
    }

}
