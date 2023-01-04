// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address }            from "../../modules/contract-test-utils/contracts/test.sol";
import { MockERC20 as Asset } from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { TestBaseWithAssertions } from "../../contracts/utilities/TestBaseWithAssertions.sol";

contract BootstrapTestBase is TestBaseWithAssertions {

    uint256 constant BOOTSTRAP_MINT_AMOUNT = 1e5;

    address lp;
    address lp2;

    function setUp() public virtual override {
        _createAccounts();
        _createAssets();
        _createGlobals();

        vm.prank(governor);
        globals.setBootstrapMint(address(fundsAsset), BOOTSTRAP_MINT_AMOUNT);

        _createFactories();
        _createAndConfigurePool(1 weeks, 2 days);
        _openPool();

        lp  = address(new Address());
        lp2 = address(new Address());

        assertEq(pool.BOOTSTRAP_MINT(), 1e5);
    }

    function mintPoolShares(address lp_, uint256 shares_) internal returns (uint256 shares) {
        fundsAsset.mint(lp_, shares_);

        vm.startPrank(lp_);
        fundsAsset.approve(address(pool), shares_);
        shares = pool.mint(shares_, lp_);
        vm.stopPrank();
    }

    function _getValidPermitSignature(address asset_, address owner_, address spender_, uint256 value_, uint256 nonce_, uint256 deadline_, uint256 ownerSk_) internal returns (uint8 v_, bytes32 r_, bytes32 s_) {
        return vm.sign(ownerSk_, _getDigest(asset_, owner_, spender_, value_, nonce_, deadline_));
    }

    // Returns an ERC-2612 `permit` digest for the `owner` to sign
    function _getDigest(address asset_, address owner_, address spender_, uint256 value_, uint256 nonce_, uint256 deadline_) private view returns (bytes32 digest_) {
        return keccak256(
            abi.encodePacked(
                '\x19\x01',
                Asset(asset_).DOMAIN_SEPARATOR(),
                keccak256(abi.encode(Asset(asset_).PERMIT_TYPEHASH(), owner_, spender_, value_, nonce_, deadline_))
            )
        );
    }

}

contract BootstrapDepositTests is BootstrapTestBase {

    function test_deposit_ltBootstrapMintAmount() external {
        fundsAsset.mint(lp, BOOTSTRAP_MINT_AMOUNT - 1);

        vm.startPrank(lp);
        fundsAsset.approve(address(pool), BOOTSTRAP_MINT_AMOUNT - 1);

        vm.expectRevert(ARITHMETIC_ERROR);
        pool.deposit(BOOTSTRAP_MINT_AMOUNT - 1, lp);
    }

    function testFuzz_deposit_ltBootstrapMintAmount(uint256 amount_) external {
        amount_ = constrictToRange(amount_, 1, BOOTSTRAP_MINT_AMOUNT - 1);

        fundsAsset.mint(lp, amount_);

        vm.startPrank(lp);
        fundsAsset.approve(address(pool), amount_);

        vm.expectRevert(ARITHMETIC_ERROR);
        pool.deposit(amount_, lp);
    }

    function test_deposit_exactBootstrapMintAmount() public {
        depositLiquidity(lp, BOOTSTRAP_MINT_AMOUNT);

        assertPoolState({
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp), 0);
    }

    function test_deposit_gtBootstrapMintAmount() public {
        depositLiquidity(lp, BOOTSTRAP_MINT_AMOUNT + 1);

        assertPoolState({
            totalSupply:        BOOTSTRAP_MINT_AMOUNT + 1,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT + 1,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT + 1
        });

        assertEq(pool.balanceOf(lp), 1);
    }

    function testFuzz_deposit_gtBootstrapMintAmount(uint256 amount_) external {
        amount_ = constrictToRange(amount_, BOOTSTRAP_MINT_AMOUNT + 1, 1_000_000e6);

        depositLiquidity(lp, amount_);

        assertPoolState({
            totalSupply:        amount_,
            totalAssets:        amount_,
            unrealizedLosses:   0,
            availableLiquidity: amount_
        });

        assertEq(pool.balanceOf(lp), amount_ - BOOTSTRAP_MINT_AMOUNT);
    }

    function test_deposit_secondDepositorGetsCorrectShares() external {
        depositLiquidity(lp, BOOTSTRAP_MINT_AMOUNT);

        assertPoolState({
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp), 0);

        depositLiquidity(lp2, 10_000e6);

        assertPoolState({
            totalSupply:        BOOTSTRAP_MINT_AMOUNT + 10_000e6,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT + 10_000e6,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT + 10_000e6
        });

        assertEq(pool.balanceOf(lp2), 10_000e6);
    }

    function testFuzz_deposit_secondDepositorGetsCorrectShares(uint256 amount_) external {
        amount_ = constrictToRange(amount_, 1, 1_000_000e6);

        depositLiquidity(lp, BOOTSTRAP_MINT_AMOUNT);

        assertPoolState({
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp), 0);

        depositLiquidity(lp2, amount_);

        assertPoolState({
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
    uint256 lpPK     = 1;
    uint256 lp2PK    = 2;
    uint256 nonce;

    function setUp() override public {
        super.setUp();

        lp  = vm.addr(lpPK);
        lp2 = vm.addr(lp2PK);
    }

    function test_depositWithPermit_ltBootstrapMintAmount() external {
        fundsAsset.mint(lp, BOOTSTRAP_MINT_AMOUNT - 1);

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), BOOTSTRAP_MINT_AMOUNT - 1, nonce, deadline, lpPK);

        vm.prank(lp);
        vm.expectRevert(ARITHMETIC_ERROR);
        pool.depositWithPermit(BOOTSTRAP_MINT_AMOUNT - 1, lp, deadline, v, r, s);
    }

    function testFuzz_depositWithPermit_ltBootstrapMintAmount(uint256 amount_) external {
        amount_ = constrictToRange(amount_, 1, BOOTSTRAP_MINT_AMOUNT - 1);

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), amount_, nonce, deadline, lpPK);

        vm.prank(lp);
        vm.expectRevert(ARITHMETIC_ERROR);
        pool.depositWithPermit(amount_, lp, deadline, v, r, s);
    }

    function test_depositWithPermit_exactBootstrapMintAmount() public {
        fundsAsset.mint(lp, BOOTSTRAP_MINT_AMOUNT);

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), BOOTSTRAP_MINT_AMOUNT, nonce, deadline, lpPK);

        vm.prank(lp);
        pool.depositWithPermit(BOOTSTRAP_MINT_AMOUNT, lp, deadline, v, r, s);

        assertPoolState({
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp), 0);
    }

    function test_depositWithPermit_gtBootstrapMintAmount() public {
        fundsAsset.mint(lp, BOOTSTRAP_MINT_AMOUNT + 1);

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), BOOTSTRAP_MINT_AMOUNT + 1, nonce, deadline, lpPK);

        vm.prank(lp);
        pool.depositWithPermit(BOOTSTRAP_MINT_AMOUNT + 1, lp, deadline, v, r, s);

        assertPoolState({
            totalSupply:        BOOTSTRAP_MINT_AMOUNT + 1,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT + 1,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT + 1
        });

        assertEq(pool.balanceOf(lp), 1);
    }

    function testFuzz_depositWithPermit_gtBootstrapMintAmount(uint256 amount_) external {
        amount_ = constrictToRange(amount_, BOOTSTRAP_MINT_AMOUNT + 1, 1_000_000e6);

        fundsAsset.mint(lp, amount_);

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), amount_, nonce, deadline, lpPK);

        vm.prank(lp);
        pool.depositWithPermit(amount_, lp, deadline, v, r, s);

        assertPoolState({
            totalSupply:        amount_,
            totalAssets:        amount_,
            unrealizedLosses:   0,
            availableLiquidity: amount_
        });

        assertEq(pool.balanceOf(lp), amount_ - BOOTSTRAP_MINT_AMOUNT);
    }

    function test_depositWithPermit_secondDepositorGetsCorrectShares() external {
        fundsAsset.mint(lp, BOOTSTRAP_MINT_AMOUNT);

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), BOOTSTRAP_MINT_AMOUNT, nonce, deadline, lpPK);

        vm.prank(lp);
        pool.depositWithPermit(BOOTSTRAP_MINT_AMOUNT, lp, deadline, v, r, s);

        assertPoolState({
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp), 0);

        fundsAsset.mint(lp2, 10_000e6);

        ( v, r, s ) = _getValidPermitSignature(address(fundsAsset), lp2, address(pool), 10_000e6, nonce, deadline, lp2PK);

        vm.prank(lp2);
        pool.depositWithPermit(10_000e6, lp2, deadline, v, r, s);

        assertPoolState({
            totalSupply:        BOOTSTRAP_MINT_AMOUNT + 10_000e6,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT + 10_000e6,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT + 10_000e6
        });

        assertEq(pool.balanceOf(lp2), 10_000e6);
    }

    function testFuzz_depositWithPermit_secondDepositorGetsCorrectShares(uint256 amount_) external {
        amount_ = constrictToRange(amount_, 1, 1_000_000e6);

        fundsAsset.mint(lp, BOOTSTRAP_MINT_AMOUNT);

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), BOOTSTRAP_MINT_AMOUNT, nonce, deadline, lpPK);

        vm.prank(lp);
        pool.depositWithPermit(BOOTSTRAP_MINT_AMOUNT, lp, deadline, v, r, s);

        assertPoolState({
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp), 0);

        fundsAsset.mint(lp2, amount_);

        ( v, r, s ) = _getValidPermitSignature(address(fundsAsset), lp2, address(pool), amount_, nonce, deadline, lp2PK);

        vm.prank(lp2);
        pool.depositWithPermit(amount_, lp2, deadline, v, r, s);

        assertPoolState({
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
        fundsAsset.mint(lp, BOOTSTRAP_MINT_AMOUNT - 1);

        vm.startPrank(lp);
        fundsAsset.approve(address(pool), BOOTSTRAP_MINT_AMOUNT - 1);

        vm.expectRevert(ARITHMETIC_ERROR);
        pool.mint(BOOTSTRAP_MINT_AMOUNT - 1, lp);
    }

    function testFuzz_mint_ltBootstrapMintAmount(uint256 amount_) external {
        amount_ = constrictToRange(amount_, 1, BOOTSTRAP_MINT_AMOUNT - 1);

        fundsAsset.mint(lp, amount_);

        vm.startPrank(lp);
        fundsAsset.approve(address(pool), amount_);

        vm.expectRevert(ARITHMETIC_ERROR);
        pool.mint(amount_, lp);
    }

    function test_mint_exactBootstrapMintAmount() public {
        mintPoolShares(lp, BOOTSTRAP_MINT_AMOUNT);

        assertPoolState({
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp), 0);
    }

    function test_mint_gtBootstrapMintAmount() public {
        mintPoolShares(lp, BOOTSTRAP_MINT_AMOUNT + 1);

        assertPoolState({
            totalSupply:        BOOTSTRAP_MINT_AMOUNT + 1,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT + 1,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT + 1
        });

        assertEq(pool.balanceOf(lp), 1);
    }

    function testFuzz_mint_gtBootstrapMintAmount(uint256 amount_) external {
        amount_ = constrictToRange(amount_, BOOTSTRAP_MINT_AMOUNT + 1, 1_000_000e6);

        mintPoolShares(lp, amount_);

        assertPoolState({
            totalSupply:        amount_,
            totalAssets:        amount_,
            unrealizedLosses:   0,
            availableLiquidity: amount_
        });

        assertEq(pool.balanceOf(lp), amount_ - BOOTSTRAP_MINT_AMOUNT);
    }

    function test_mint_secondDepositorGetsCorrectShares() external {
        mintPoolShares(lp, BOOTSTRAP_MINT_AMOUNT);

        assertPoolState({
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp), 0);

        mintPoolShares(lp2, 10_000e6);

        assertPoolState({
            totalSupply:        BOOTSTRAP_MINT_AMOUNT + 10_000e6,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT + 10_000e6,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT + 10_000e6
        });

        assertEq(pool.balanceOf(lp2), 10_000e6);
    }

    function testFuzz_mint_secondDepositorGetsCorrectShares(uint256 amount_) external {
        amount_ = constrictToRange(amount_, 1, 1_000_000e6);

        mintPoolShares(lp, BOOTSTRAP_MINT_AMOUNT);

        assertPoolState({
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp), 0);

        mintPoolShares(lp2, amount_);

        assertPoolState({
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
    uint256 lpPK     = 1;
    uint256 lp2PK    = 2;
    uint256 nonce;

    function setUp() override public {
        super.setUp();

        lp  = vm.addr(lpPK);
        lp2 = vm.addr(lp2PK);
    }

    function test_mintWithPermit_ltBootstrapMintAmount() external {
        fundsAsset.mint(lp, BOOTSTRAP_MINT_AMOUNT - 1);

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), BOOTSTRAP_MINT_AMOUNT - 1, nonce, deadline, lpPK);

        vm.prank(lp);
        vm.expectRevert(ARITHMETIC_ERROR);
        pool.mintWithPermit(BOOTSTRAP_MINT_AMOUNT - 1, lp, BOOTSTRAP_MINT_AMOUNT - 1, deadline, v, r, s);
    }

    function testFuzz_mintWithPermit_ltBootstrapMintAmount(uint256 amount_) external {
        amount_ = constrictToRange(amount_, 1, BOOTSTRAP_MINT_AMOUNT - 1);

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), amount_, nonce, deadline, lpPK);

        vm.prank(lp);
        vm.expectRevert(ARITHMETIC_ERROR);
        pool.mintWithPermit(amount_, lp, amount_, deadline, v, r, s);
    }

    function test_mintWithPermit_exactBootstrapMintAmount() public {
        fundsAsset.mint(lp, BOOTSTRAP_MINT_AMOUNT);

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), BOOTSTRAP_MINT_AMOUNT, nonce, deadline, lpPK);

        vm.prank(lp);
        pool.mintWithPermit(BOOTSTRAP_MINT_AMOUNT, lp, BOOTSTRAP_MINT_AMOUNT, deadline, v, r, s);

        assertPoolState({
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp), 0);
    }

    function test_mintWithPermit_gtBootstrapMintAmount() public {
        fundsAsset.mint(lp, BOOTSTRAP_MINT_AMOUNT + 1);

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), BOOTSTRAP_MINT_AMOUNT + 1, nonce, deadline, lpPK);

        vm.prank(lp);
        pool.mintWithPermit(BOOTSTRAP_MINT_AMOUNT + 1, lp, BOOTSTRAP_MINT_AMOUNT + 1, deadline, v, r, s);

        assertPoolState({
            totalSupply:        BOOTSTRAP_MINT_AMOUNT + 1,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT + 1,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT + 1
        });

        assertEq(pool.balanceOf(lp), 1);
    }

    function testFuzz_mintWithPermit_gtBootstrapMintAmount(uint256 amount_) external {
        amount_ = constrictToRange(amount_, BOOTSTRAP_MINT_AMOUNT + 1, 1_000_000e6);

        fundsAsset.mint(lp, amount_);

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), amount_, nonce, deadline, lpPK);

        vm.prank(lp);
        pool.mintWithPermit(amount_, lp, amount_, deadline, v, r, s);

        assertPoolState({
            totalSupply:        amount_,
            totalAssets:        amount_,
            unrealizedLosses:   0,
            availableLiquidity: amount_
        });

        assertEq(pool.balanceOf(lp), amount_ - BOOTSTRAP_MINT_AMOUNT);
    }

    function test_mintWithPermit_secondDepositorGetsCorrectShares() external {
        fundsAsset.mint(lp, BOOTSTRAP_MINT_AMOUNT);

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), BOOTSTRAP_MINT_AMOUNT, nonce, deadline, lpPK);

        vm.prank(lp);
        pool.mintWithPermit(BOOTSTRAP_MINT_AMOUNT, lp, BOOTSTRAP_MINT_AMOUNT, deadline, v, r, s);

        assertPoolState({
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp), 0);

        fundsAsset.mint(lp2, 10_000e6);

        ( v, r, s ) = _getValidPermitSignature(address(fundsAsset), lp2, address(pool), 10_000e6, nonce, deadline, lp2PK);

        vm.prank(lp2);
        pool.mintWithPermit(10_000e6, lp2, 10_000e6, deadline, v, r, s);

        assertPoolState({
            totalSupply:        BOOTSTRAP_MINT_AMOUNT + 10_000e6,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT + 10_000e6,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT + 10_000e6
        });

        assertEq(pool.balanceOf(lp2), 10_000e6);
    }

    function testFuzz_mintWithPermit_secondDepositorGetsCorrectShares(uint256 amount_) external {
        amount_ = constrictToRange(amount_, 1, 1_000_000e6);

        fundsAsset.mint(lp, BOOTSTRAP_MINT_AMOUNT);

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), BOOTSTRAP_MINT_AMOUNT, nonce, deadline, lpPK);

        vm.prank(lp);
        pool.mintWithPermit(BOOTSTRAP_MINT_AMOUNT, lp, BOOTSTRAP_MINT_AMOUNT, deadline, v, r, s);

        assertPoolState({
            totalSupply:        BOOTSTRAP_MINT_AMOUNT,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT
        });

        assertEq(pool.balanceOf(lp), 0);

        fundsAsset.mint(lp2, amount_);

        ( v, r, s ) = _getValidPermitSignature(address(fundsAsset), lp2, address(pool), amount_, nonce, deadline, lp2PK);

        vm.prank(lp2);
        pool.mintWithPermit(amount_, lp2, amount_, deadline, v, r, s);

        assertPoolState({
            totalSupply:        BOOTSTRAP_MINT_AMOUNT + amount_,
            totalAssets:        BOOTSTRAP_MINT_AMOUNT + amount_,
            unrealizedLosses:   0,
            availableLiquidity: BOOTSTRAP_MINT_AMOUNT + amount_
        });

        assertEq(pool.balanceOf(lp2), amount_);
    }

}
