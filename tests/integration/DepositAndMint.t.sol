// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address }            from "../../modules/contract-test-utils/contracts/test.sol";
import { MockERC20 as Asset } from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { TestBase } from "../../contracts/utilities/TestBase.sol";

contract EnterBase is TestBase {

    address internal lp;

    function setUp() public virtual override {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _createFactories();
        _createPool(1 weeks, 2 days);
        // NOTE: As opposed to super.setUp(), do not configure the pool or perform any later steps, because pool configuration will be validated in the tests.

        start = block.timestamp;
    }

    function _getValidPermitSignature(
        address asset_,
        address owner_,
        address spender_,
        uint256 value_,
        uint256 nonce_,
        uint256 deadline_,
        uint256 ownerSk_
    )
        internal
        returns (uint8 v_, bytes32 r_, bytes32 s_)
    {
        ( v_, r_, s_ ) = vm.sign(ownerSk_, _getDigest(asset_, owner_, spender_, value_, nonce_, deadline_));
    }

    // Returns an ERC-2612 `permit` digest for the `owner` to sign
    function _getDigest(address asset_, address owner_, address spender_, uint256 value_, uint256 nonce_, uint256 deadline_)
        private view
        returns (bytes32 digest_)
    {
        digest_ = keccak256(
            abi.encodePacked(
                '\x19\x01',
                Asset(asset_).DOMAIN_SEPARATOR(),
                keccak256(abi.encode(Asset(asset_).PERMIT_TYPEHASH(), owner_, spender_, value_, nonce_, deadline_))
            )
        );
    }

}

contract DepositTest is EnterBase {

    function setUp() public override {
        super.setUp();

        lp = address(new Address());

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();
    }

    function test_deposit_singleUser_oneToOne() public {
        // Mint asset to LP
        fundsAsset.mint(address(lp), 1_000_000e6);

        // Approve
        vm.prank(lp);
        fundsAsset.approve(address(pool), 1_000_000e6);

        // Pre deposit assertions
        assertEq(pool.balanceOf(address(lp)),                      0);
        assertEq(pool.totalSupply(),                               0);
        assertEq(fundsAsset.balanceOf(address(pool)),              0);
        assertEq(fundsAsset.balanceOf(address(lp)),                1_000_000e6);
        assertEq(fundsAsset.allowance(address(lp), address(pool)), 1_000_000e6);

        assertEq(poolManager.totalAssets(), 0);

        vm.prank(lp);
        uint256 shares = pool.deposit(1_000_000e6, lp);

        assertEq(pool.balanceOf(address(lp)),                      shares);
        assertEq(pool.balanceOf(address(lp)),                      1_000_000e6);
        assertEq(pool.totalSupply(),                               1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(pool)),              1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(lp)),                0);
        assertEq(fundsAsset.allowance(address(lp), address(pool)), 0);

        assertEq(poolManager.totalAssets(), 1_000_000e6);
    }

    function testDeepFuzz_deposit_singleUser(uint256 depositAmount) public {
        // With max uint256, the assertion of allowance after deposit fails because on the token is treated as infinite allowance.
        depositAmount = constrictToRange(depositAmount, 1, type(uint256).max - 1);

        // Mint asset to LP
        fundsAsset.mint(address(lp), depositAmount);

        // Approve
        vm.prank(lp);
        fundsAsset.approve(address(pool), depositAmount);

        // Pre deposit assertions
        assertEq(pool.balanceOf(address(lp)),                      0);
        assertEq(pool.totalSupply(),                               0);
        assertEq(fundsAsset.balanceOf(address(pool)),              0);
        assertEq(fundsAsset.balanceOf(address(lp)),                depositAmount);
        assertEq(fundsAsset.allowance(address(lp), address(pool)), depositAmount);

        assertEq(poolManager.totalAssets(), 0);

        vm.prank(lp);
        uint256 shares = pool.deposit(depositAmount, lp);

        assertEq(pool.balanceOf(address(lp)),                      shares);
        assertEq(pool.balanceOf(address(lp)),                      depositAmount);
        assertEq(pool.totalSupply(),                               depositAmount);
        assertEq(fundsAsset.balanceOf(address(pool)),              depositAmount);
        assertEq(fundsAsset.balanceOf(address(lp)),                0);
        assertEq(fundsAsset.allowance(address(lp), address(pool)), 0);

        assertEq(poolManager.totalAssets(), depositAmount);
    }

    function test_deposit_twoUsers_oneToOne() public {
        // Mint asset to LP
        fundsAsset.mint(address(lp), 1_000_000e6);

        // Approve
        vm.prank(lp);
        fundsAsset.approve(address(pool), 1_000_000e6);

        // Pre deposit assertions
        assertEq(pool.balanceOf(address(lp)),                      0);
        assertEq(pool.totalSupply(),                               0);
        assertEq(fundsAsset.balanceOf(address(pool)),              0);
        assertEq(fundsAsset.balanceOf(address(lp)),                1_000_000e6);
        assertEq(fundsAsset.allowance(address(lp), address(pool)), 1_000_000e6);

        assertEq(poolManager.totalAssets(), 0);

        vm.prank(lp);
        uint256 shares = pool.deposit(1_000_000e6, lp);

        assertEq(pool.balanceOf(address(lp)),                      shares);
        assertEq(pool.balanceOf(address(lp)),                      1_000_000e6);
        assertEq(pool.totalSupply(),                               1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(pool)),              1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(lp)),                0);
        assertEq(fundsAsset.allowance(address(lp), address(pool)), 0);

        assertEq(poolManager.totalAssets(), 1_000_000e6);

        address lp2 = address(new Address());

        fundsAsset.mint(address(lp2), 3_000_000e6);

        // Approve
        vm.prank(lp2);
        fundsAsset.approve(address(pool), 3_000_000e6);

        // Pre deposit 2 assertions
        assertEq(pool.balanceOf(address(lp2)), 0);
        assertEq(fundsAsset.balanceOf(address(lp2)),                3_000_000e6);
        assertEq(fundsAsset.allowance(address(lp2), address(pool)), 3_000_000e6);

        vm.prank(lp2);
        uint256 shares2 = pool.deposit(3_000_000e6, lp2);

        assertEq(pool.balanceOf(address(lp2)),                      shares2);
        assertEq(pool.balanceOf(address(lp2)),                      3_000_000e6);
        assertEq(pool.totalSupply(),                                4_000_000e6);
        assertEq(pool.totalSupply(),                                shares + shares2);
        assertEq(fundsAsset.balanceOf(address(pool)),               4_000_000e6);
        assertEq(fundsAsset.balanceOf(address(lp2)),                0);
        assertEq(fundsAsset.allowance(address(lp2), address(pool)), 0);

        assertEq(poolManager.totalAssets(), 4_000_000e6);
    }

    function testDeepFuzz_deposit_variableExchangeRate(uint256 depositAmount, uint256 warpTime) public {
        address initialDepositor = address(new Address());

        // Initial user does a deposit
        fundsAsset.mint(address(initialDepositor), 1_000_000e6);

        // Approve
        vm.prank(initialDepositor);
        fundsAsset.approve(address(pool), 1_000_000e6);

        vm.prank(initialDepositor);
        pool.deposit(1_000_000e6, initialDepositor);

        // Fund loan
        fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e18), uint256(0), uint256(0), uint256(0)]
        });

        // Constrict time to be within the first loan payment and amount to be within token amounts
        warpTime      = constrictToRange(warpTime,      0, 1_000_000);
        depositAmount = constrictToRange(depositAmount, 1, 1e32);

        vm.warp(start + warpTime);

        // Mint asset to LP
        fundsAsset.mint(address(lp), depositAmount);

        vm.prank(lp);
        fundsAsset.approve(address(pool), depositAmount);

        uint256 previewedShares = pool.previewDeposit(depositAmount);

        if (previewedShares == 0) {
            vm.prank(lp);
            vm.expectRevert("P:M:ZERO_SHARES");
            pool.deposit(depositAmount, lp);
        } else {

            uint256 expectedShares = depositAmount * pool.totalSupply() / poolManager.totalAssets();

            vm.prank(lp);
            uint256 shares = pool.deposit(depositAmount, lp);

            assertEq(shares,                                           expectedShares);
            assertEq(pool.totalSupply(),                               shares + 1_000_000e6);
            assertEq(pool.balanceOf(address(lp)),                      shares);
            assertEq(fundsAsset.balanceOf(address(pool)),              depositAmount);
            assertEq(fundsAsset.balanceOf(address(lp)),                0);
            assertEq(fundsAsset.allowance(address(lp), address(pool)), 0);
        }
    }

}

contract DepositWithPermitTests is EnterBase {

    uint256 internal deadline = 5_000_000_000;
    uint256 internal lpPK     = 1;
    uint256 internal nonce;

    function setUp() public override {
        super.setUp();

        lp = vm.addr(lpPK);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();
    }

    function test_depositWithPermit_singleUser() public {
        // Mint asset to LP
        fundsAsset.mint(address(lp), 1_000_000e6);

        // Pre deposit assertions
        assertEq(pool.balanceOf(address(lp)),                      0);
        assertEq(pool.totalSupply(),                               0);
        assertEq(fundsAsset.balanceOf(address(pool)),              0);
        assertEq(fundsAsset.balanceOf(address(lp)),                1_000_000e6);
        assertEq(fundsAsset.allowance(address(lp), address(pool)), 0);

        assertEq(poolManager.totalAssets(), 0);

        vm.startPrank(lp);
        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), 1_000_000e6, nonce, deadline, lpPK);

        uint256 shares = pool.depositWithPermit(1_000_000e6, lp, deadline, v, r, s);

        assertEq(pool.balanceOf(address(lp)),                      shares);
        assertEq(pool.balanceOf(address(lp)),                      1_000_000e6);
        assertEq(pool.totalSupply(),                               1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(pool)),              1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(lp)),                0);
        assertEq(fundsAsset.allowance(address(lp), address(pool)), 0);

        assertEq(poolManager.totalAssets(), 1_000_000e6);
    }

    function testDeepFuzz_depositWithPermit_singleUser(uint256 depositAmount) public {
        // With max uint256, the assertion of allowance after deposit fails because on the token is treated as infinite allowance.
        depositAmount = constrictToRange(depositAmount, 1, type(uint256).max - 1);

        // Mint asset to LP
        fundsAsset.mint(address(lp), depositAmount);

        // Approve
        vm.prank(lp);
        fundsAsset.approve(address(pool), depositAmount);

        // Pre deposit assertions
        assertEq(pool.balanceOf(address(lp)),                      0);
        assertEq(pool.totalSupply(),                               0);
        assertEq(fundsAsset.balanceOf(address(pool)),              0);
        assertEq(fundsAsset.balanceOf(address(lp)),                depositAmount);
        assertEq(fundsAsset.allowance(address(lp), address(pool)), depositAmount);

        assertEq(poolManager.totalAssets(), 0);

        vm.startPrank(lp);
        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), depositAmount, nonce, deadline, lpPK);

        uint256 shares = pool.depositWithPermit(depositAmount, lp, deadline, v, r, s);

        assertEq(pool.balanceOf(address(lp)),                      shares);
        assertEq(pool.balanceOf(address(lp)),                      depositAmount);
        assertEq(pool.totalSupply(),                               depositAmount);
        assertEq(fundsAsset.balanceOf(address(pool)),              depositAmount);
        assertEq(fundsAsset.balanceOf(address(lp)),                0);
        assertEq(fundsAsset.allowance(address(lp), address(pool)), 0);

        assertEq(poolManager.totalAssets(), depositAmount);
    }

}

contract DepositFailureTests is EnterBase {

    function setUp() public virtual override {
        super.setUp();

        lp = address(new Address());
    }

    function test_deposit_protocolPaused() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.prank(poolDelegate);
        poolManager.setAllowedLender(lp, true);

        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.startPrank(lp);

        fundsAsset.approve(address(pool), liquidity);

        vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        pool.deposit(liquidity, lp);

        vm.stopPrank();

        vm.prank(governor);
        globals.setProtocolPause(false);

        vm.startPrank(lp);
        pool.deposit(liquidity, lp);
    }

    function test_deposit_notActive() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity);

        vm.prank(poolDelegate);
        poolManager.setAllowedLender(lp, true);

        vm.startPrank(lp);

        fundsAsset.approve(address(pool), liquidity);

        vm.expectRevert("P:D:NOT_ACTIVE");
        pool.deposit(liquidity, lp);

        vm.stopPrank();

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.startPrank(lp);
        pool.deposit(liquidity, lp);
    }

    function test_deposit_privatePoolInvalidRecipient() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.startPrank(lp);

        fundsAsset.approve(address(pool), liquidity);

        vm.expectRevert("P:D:LENDER_NOT_ALLOWED");
        pool.deposit(liquidity, lp);

        vm.stopPrank();

        vm.prank(poolDelegate);
        poolManager.setAllowedLender(lp, true);

        vm.startPrank(lp);
        pool.deposit(liquidity, lp);
    }

    function test_deposit_privatePoolInvalidRecipient_openPoolToPublic() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.startPrank(lp);

        fundsAsset.approve(address(pool), liquidity);

        vm.expectRevert("P:D:LENDER_NOT_ALLOWED");
        pool.deposit(liquidity, lp);

        vm.stopPrank();

        // Pool is opened to public, shares may be transferred to anyone.
        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();

        vm.startPrank(lp);
        pool.deposit(liquidity, lp);
    }

    function test_deposit_liquidityCapExceeded() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity + 1);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.startPrank(poolDelegate);

        poolManager.setOpenToPublic();
        poolManager.setLiquidityCap(1_000e6);

        vm.stopPrank();

        vm.startPrank(lp);

        fundsAsset.approve(address(pool), liquidity);

        // Deposit an initial amount before setting liquidity cap.
        pool.deposit(400e6, lp);

        vm.expectRevert("P:D:DEPOSIT_GT_LIQ_CAP");
        pool.deposit(600e6 + 1, lp);

        pool.deposit(600e6, lp);
    }

    function test_deposit_insufficientApproval() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.prank(poolDelegate);
        poolManager.setAllowedLender(lp, true);

        vm.startPrank(lp);

        fundsAsset.approve(address(pool), liquidity - 1);

        vm.expectRevert("P:M:TRANSFER_FROM");
        pool.deposit(liquidity, lp);

        vm.stopPrank();

        vm.startPrank(lp);

        fundsAsset.approve(address(pool), liquidity);

        pool.deposit(liquidity, lp);
    }

}

contract DepositWithPermitFailureTests is EnterBase {

    uint256 internal deadline = 5_000_000_000;
    uint256 internal lpSk     = 1;
    uint256 internal nonce;

    function setUp() public virtual override {
        super.setUp();

        lp = vm.addr(lpSk);
    }

    function test_depositWithPermit_protocolPaused() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.prank(poolDelegate);
        poolManager.setAllowedLender(lp, true);

        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.startPrank(lp);

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity, nonce, deadline, lpSk);

        vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        pool.depositWithPermit(liquidity, lp, deadline, v, r, s);

        vm.stopPrank();

        vm.prank(governor);
        globals.setProtocolPause(false);

        vm.startPrank(lp);
        pool.depositWithPermit(liquidity, lp, deadline, v, r, s);
    }

    function test_depositWithPermit_notActive() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity);

        vm.prank(poolDelegate);
        poolManager.setAllowedLender(lp, true);

        vm.startPrank(lp);

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity, nonce, deadline, lpSk);

        vm.expectRevert("P:DWP:NOT_ACTIVE");
        pool.depositWithPermit(liquidity, lp, deadline, v, r, s);

        vm.stopPrank();

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.startPrank(lp);
        pool.depositWithPermit(liquidity, lp, deadline, v, r, s);
    }

    function test_depositWithPermit_privatePoolInvalidRecipient() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.startPrank(lp);

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity, nonce, deadline, lpSk);

        vm.expectRevert("P:DWP:LENDER_NOT_ALLOWED");
        pool.depositWithPermit(liquidity, lp, deadline, v, r, s);

        vm.stopPrank();

        vm.prank(poolDelegate);
        poolManager.setAllowedLender(lp, true);

        vm.startPrank(lp);
        pool.depositWithPermit(liquidity, lp, deadline, v, r, s);
    }

    function test_depositWithPermit_privatePoolInvalidRecipient_openPoolToPublic() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.startPrank(lp);

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity, nonce, deadline, lpSk);

        vm.expectRevert("P:DWP:LENDER_NOT_ALLOWED");
        pool.depositWithPermit(liquidity, lp, deadline, v, r, s);

        vm.stopPrank();

        // Pool is opened to public, shares may be transferred to anyone.
        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();

        vm.startPrank(lp);
        pool.depositWithPermit(liquidity, lp, deadline, v, r, s);
    }

    function test_depositWithPermit_liquidityCapExceeded() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity + 1);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.startPrank(poolDelegate);

        poolManager.setOpenToPublic();
        poolManager.setLiquidityCap(1_000e6);

        vm.stopPrank();

        vm.startPrank(lp);

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), 400e6, nonce, deadline, lpSk);

        // Deposit an initial amount before setting liquidity cap.
        pool.depositWithPermit(400e6, lp, deadline, v, r, s);
        nonce += 1;

        ( v, r, s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), 600e6 + 1, nonce, deadline, lpSk);

        vm.expectRevert("P:DWP:DEPOSIT_GT_LIQ_CAP");
        pool.depositWithPermit(600e6 + 1, lp, deadline, v, r, s);

        ( v, r, s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), 600e6, nonce, deadline, lpSk);

        pool.depositWithPermit(600e6, lp, deadline, v, r, s);
    }

    function test_depositWithPermit_invalidSignature() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.prank(poolDelegate);
        poolManager.setAllowedLender(lp, true);

        vm.startPrank(lp);

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity - 1, nonce, deadline, lpSk);

        vm.expectRevert("ERC20:P:INVALID_SIGNATURE");
        pool.depositWithPermit(liquidity, lp, deadline, v, r, s);

        ( v, r, s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity, nonce, deadline, lpSk);
        pool.depositWithPermit(liquidity, lp, deadline, v, r, s);
    }

}

contract MintTest is EnterBase {

    function setUp() public override {
        super.setUp();

        lp = address(new Address());

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();
    }

    function test_mint_singleUser_oneToOne() public {
        // Mint asset to LP
        fundsAsset.mint(address(lp), 1_000_000e6);

        // Approve
        vm.prank(lp);
        fundsAsset.approve(address(pool), 1_000_000e6);

        // Pre mint assertions
        assertEq(pool.balanceOf(address(lp)),                      0);
        assertEq(pool.totalSupply(),                               0);
        assertEq(fundsAsset.balanceOf(address(pool)),              0);
        assertEq(fundsAsset.balanceOf(address(lp)),                1_000_000e6);
        assertEq(fundsAsset.allowance(address(lp), address(pool)), 1_000_000e6);

        assertEq(poolManager.totalAssets(), 0);

        vm.prank(lp);
        uint256 shares = pool.mint(1_000_000e6, lp);

        assertEq(pool.balanceOf(address(lp)),                      shares);
        assertEq(pool.balanceOf(address(lp)),                      1_000_000e6);
        assertEq(pool.totalSupply(),                               1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(pool)),              1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(lp)),                0);
        assertEq(fundsAsset.allowance(address(lp), address(pool)), 0);

        assertEq(poolManager.totalAssets(), 1_000_000e6);
    }

    function testDeepFuzz_mint_singleUser(uint256 mintAmount) public {
        // With max uint256, the assertion of allowance after deposit fails because on the token is treated as infinite allowance.
        mintAmount = constrictToRange(mintAmount, 1, type(uint256).max - 1);

        // Mint asset to LP
        fundsAsset.mint(address(lp), mintAmount);

        // Approve
        vm.prank(lp);
        fundsAsset.approve(address(pool), mintAmount);

        // Pre mint assertions
        assertEq(pool.balanceOf(address(lp)),                      0);
        assertEq(pool.totalSupply(),                               0);
        assertEq(fundsAsset.balanceOf(address(pool)),              0);
        assertEq(fundsAsset.balanceOf(address(lp)),                mintAmount);
        assertEq(fundsAsset.allowance(address(lp), address(pool)), mintAmount);

        assertEq(poolManager.totalAssets(), 0);

        vm.prank(lp);
        uint256 shares = pool.mint(mintAmount, lp);

        assertEq(pool.balanceOf(address(lp)),                      shares);
        assertEq(pool.balanceOf(address(lp)),                      mintAmount);
        assertEq(pool.totalSupply(),                               mintAmount);
        assertEq(fundsAsset.balanceOf(address(pool)),              mintAmount);
        assertEq(fundsAsset.balanceOf(address(lp)),                0);
        assertEq(fundsAsset.allowance(address(lp), address(pool)), 0);

        assertEq(poolManager.totalAssets(), mintAmount);
    }

    function test_mint_twoUsers_OneToOne() public {
        // Mint asset to LP
        fundsAsset.mint(address(lp), 1_000_000e6);

        // Approve
        vm.prank(lp);
        fundsAsset.approve(address(pool), 1_000_000e6);

        // Pre mint assertions
        assertEq(pool.balanceOf(address(lp)),                      0);
        assertEq(pool.totalSupply(),                               0);
        assertEq(fundsAsset.balanceOf(address(pool)),              0);
        assertEq(fundsAsset.balanceOf(address(lp)),                1_000_000e6);
        assertEq(fundsAsset.allowance(address(lp), address(pool)), 1_000_000e6);

        assertEq(poolManager.totalAssets(), 0);

        vm.prank(lp);
        uint256 shares = pool.mint(1_000_000e6, lp);

        assertEq(pool.balanceOf(address(lp)),                      shares);
        assertEq(pool.balanceOf(address(lp)),                      1_000_000e6);
        assertEq(pool.totalSupply(),                               1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(pool)),              1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(lp)),                0);
        assertEq(fundsAsset.allowance(address(lp), address(pool)), 0);

        assertEq(poolManager.totalAssets(), 1_000_000e6);

        address lp2 = address(new Address());

        fundsAsset.mint(address(lp2), 3_000_000e6);

        // Approve
        vm.prank(lp2);
        fundsAsset.approve(address(pool), 3_000_000e6);

        // Pre mint 2 assertions
        assertEq(pool.balanceOf(address(lp2)), 0);
        assertEq(fundsAsset.balanceOf(address(lp2)),                3_000_000e6);
        assertEq(fundsAsset.allowance(address(lp2), address(pool)), 3_000_000e6);

        vm.prank(lp2);
        uint256 shares2 = pool.mint(3_000_000e6, lp2);

        assertEq(pool.balanceOf(address(lp2)),                      shares2);
        assertEq(pool.balanceOf(address(lp2)),                      3_000_000e6);
        assertEq(pool.totalSupply(),                                4_000_000e6);
        assertEq(pool.totalSupply(),                                shares + shares2);
        assertEq(fundsAsset.balanceOf(address(pool)),               4_000_000e6);
        assertEq(fundsAsset.balanceOf(address(lp2)),                0);
        assertEq(fundsAsset.allowance(address(lp2), address(pool)), 0);

        assertEq(poolManager.totalAssets(), 4_000_000e6);
    }

    function testDeepFuzz_mint_variableExchangeRate(uint256 assetAmount, uint256 warpTime) public {

        address initialDepositor = address(new Address());

        // Initial user does a deposit
        fundsAsset.mint(address(initialDepositor), 1_000_000e6);

        // Approve
        vm.prank(initialDepositor);
        fundsAsset.approve(address(pool), 1_000_000e6);

        vm.prank(initialDepositor);
        pool.mint(1_000_000e6, initialDepositor);

        // Fund loan
        fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e18), uint256(0), uint256(0), uint256(0)]
        });

        // Constrict time to be within the first loan payment and amount to be within token amounts
        warpTime    = constrictToRange(warpTime, 2, 1_000_000);
        assetAmount = constrictToRange(assetAmount, 1e6, 1e32);

        vm.warp(start + warpTime);

        // Mint asset to LP
        fundsAsset.mint(address(lp), assetAmount);

        vm.prank(lp);
        fundsAsset.approve(address(pool), assetAmount);

        uint256 calculatedShares = pool.convertToShares(assetAmount);

        if (calculatedShares == 0) {
            vm.prank(lp);
            vm.expectRevert("P:M:ZERO_SHARES");
            pool.mint(assetAmount, lp);

        } else {

            uint256 expectedShares = assetAmount * pool.totalSupply() / poolManager.totalAssets();

            vm.prank(lp);
            uint256 assets = pool.mint(calculatedShares, lp);

            assertEq(pool.balanceOf(address(lp)), expectedShares);

            assertWithinDiff(assets,                                           assetAmount,                    1);
            assertWithinDiff(pool.totalSupply(),                               calculatedShares + 1_000_000e6, 1);
            assertWithinDiff(pool.balanceOf(address(lp)),                      calculatedShares,               0);
            // Assets from initial depositor are in the loan
            assertWithinDiff(fundsAsset.balanceOf(address(pool)),              assetAmount,                    1);
            assertWithinDiff(fundsAsset.balanceOf(address(lp)),                0,                              1);
            assertWithinDiff(fundsAsset.allowance(address(lp), address(pool)), 0,                              1);
        }
    }

}

contract MintWithPermitTests is EnterBase {

    uint256 internal deadline = 5_000_000_000;
    uint256 internal lpPK     = 1;
    uint256 internal nonce;

    function setUp() public override {
        super.setUp();

        lp = vm.addr(lpPK);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();
    }

    function test_mintWithPermit_singleUser() public {
        // Mint asset to LP
        fundsAsset.mint(address(lp), 1_000_000e6);

        // Pre mint assertions
        assertEq(pool.balanceOf(address(lp)),                      0);
        assertEq(pool.totalSupply(),                               0);
        assertEq(fundsAsset.balanceOf(address(pool)),              0);
        assertEq(fundsAsset.balanceOf(address(lp)),                1_000_000e6);
        assertEq(fundsAsset.allowance(address(lp), address(pool)), 0);

        assertEq(poolManager.totalAssets(), 0);

        vm.startPrank(lp);
        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), 1_000_000e6, nonce, deadline, lpPK);

        uint256 shares = pool.mintWithPermit(1_000_000e6, lp, 1_000_000e6, deadline, v, r, s);

        assertEq(pool.balanceOf(address(lp)),                      shares);
        assertEq(pool.balanceOf(address(lp)),                      1_000_000e6);
        assertEq(pool.totalSupply(),                               1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(pool)),              1_000_000e6);
        assertEq(fundsAsset.balanceOf(address(lp)),                0);
        assertEq(fundsAsset.allowance(address(lp), address(pool)), 0);

        assertEq(poolManager.totalAssets(), 1_000_000e6);
    }

    function testDeepFuzz_mintWithPermit_singleUser(uint256 mintAmount) public {
        vm.assume(mintAmount > 0);
        // With max uint256, the assertion of allowance after deposit fails because in the token is treated as infinite allowance.
        vm.assume(mintAmount <= type(uint256).max - 1);

        // Mint asset to LP
        fundsAsset.mint(address(lp), mintAmount);

        // Approve
        vm.prank(lp);
        fundsAsset.approve(address(pool), mintAmount);

        // Pre mint assertions
        assertEq(pool.balanceOf(address(lp)),                      0);
        assertEq(pool.totalSupply(),                               0);
        assertEq(fundsAsset.balanceOf(address(pool)),              0);
        assertEq(fundsAsset.balanceOf(address(lp)),                mintAmount);
        assertEq(fundsAsset.allowance(address(lp), address(pool)), mintAmount);

        assertEq(poolManager.totalAssets(), 0);

        vm.startPrank(lp);
        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), mintAmount, nonce, deadline, lpPK);

        uint256 shares = pool.mintWithPermit(mintAmount, lp, mintAmount, deadline, v, r, s);

        assertEq(pool.balanceOf(address(lp)),                      shares);
        assertEq(pool.balanceOf(address(lp)),                      mintAmount);
        assertEq(pool.totalSupply(),                               mintAmount);
        assertEq(fundsAsset.balanceOf(address(pool)),              mintAmount);
        assertEq(fundsAsset.balanceOf(address(lp)),                0);
        assertEq(fundsAsset.allowance(address(lp), address(pool)), 0);

        assertEq(poolManager.totalAssets(), mintAmount);
    }

}

contract MintFailureTests is EnterBase {

    function setUp() public virtual override {
        super.setUp();

        lp = address(new Address());
    }

    function test_mint_protocolPaused() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.prank(poolDelegate);
        poolManager.setAllowedLender(lp, true);

        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.startPrank(lp);

        uint256 shares = pool.previewDeposit(liquidity);

        fundsAsset.approve(address(pool), liquidity);

        vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        pool.mint(shares, lp);

        vm.stopPrank();

        vm.prank(governor);
        globals.setProtocolPause(false);

        vm.startPrank(lp);
        pool.deposit(shares, lp);
    }

    function test_mint_notActive() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity);

        vm.prank(poolDelegate);
        poolManager.setAllowedLender(lp, true);

        vm.startPrank(lp);

        uint256 shares = pool.previewDeposit(liquidity);

        fundsAsset.approve(address(pool), liquidity);

        vm.expectRevert("P:M:NOT_ACTIVE");
        pool.mint(shares, lp);

        vm.stopPrank();

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.startPrank(lp);
        pool.mint(shares, lp);
    }

    function test_mint_privatePoolInvalidRecipient() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.startPrank(lp);

        uint256 shares = pool.previewDeposit(liquidity);

        fundsAsset.approve(address(pool), liquidity);

        vm.expectRevert("P:M:LENDER_NOT_ALLOWED");
        pool.mint(shares, lp);

        vm.stopPrank();

        vm.prank(poolDelegate);
        poolManager.setAllowedLender(lp, true);

        vm.startPrank(lp);
        pool.mint(shares, lp);
    }

    function test_mint_privatePoolInvalidRecipient_openPoolToPublic() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.startPrank(lp);

        uint256 shares = pool.previewDeposit(liquidity);

        fundsAsset.approve(address(pool), liquidity);

        vm.expectRevert("P:M:LENDER_NOT_ALLOWED");
        pool.mint(shares, lp);

        vm.stopPrank();

        // Pool is opened to public, shares may be transferred to anyone.
        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();

        vm.startPrank(lp);
        pool.mint(shares, lp);
    }

    function test_mint_liquidityCapExceeded() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity + 1);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.startPrank(poolDelegate);

        poolManager.setOpenToPublic();
        poolManager.setLiquidityCap(1_000e6);

        vm.stopPrank();

        vm.startPrank(lp);

        uint256 shares = pool.previewDeposit(liquidity);

        fundsAsset.approve(address(pool), liquidity);

        // Deposit an initial amount before setting liquidity cap.
        uint256 initialMintAmount = shares * 4 / 10;
        uint256 nextMintAmount    = shares - initialMintAmount;

        pool.mint(initialMintAmount, lp);

        vm.expectRevert("P:M:DEPOSIT_GT_LIQ_CAP");
        pool.mint(nextMintAmount + 1, lp);

        pool.mint(nextMintAmount, lp);
    }

    function test_mint_insufficientApproval() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.prank(poolDelegate);
        poolManager.setAllowedLender(lp, true);

        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.startPrank(lp);

        uint256 shares = pool.previewDeposit(liquidity);

        fundsAsset.approve(address(pool), liquidity - 1);

        vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        pool.mint(shares, lp);

        vm.stopPrank();

        vm.prank(governor);
        globals.setProtocolPause(false);

        vm.startPrank(lp);

        fundsAsset.approve(address(pool), liquidity);

        pool.mint(shares, lp);
    }

}

contract MintWithPermitFailureTests is EnterBase {

    uint256 internal deadline = 5_000_000_000;
    uint256 internal lpSk     = 1;
    uint256 internal nonce;

    function setUp() public virtual override {
        super.setUp();

        lp = vm.addr(lpSk);
    }

    function test_mintWithPermit_protocolPaused() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.prank(poolDelegate);
        poolManager.setAllowedLender(lp, true);

        vm.prank(governor);
        globals.setProtocolPause(true);

        uint256 shares = pool.previewDeposit(liquidity);

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity, nonce, deadline, lpSk);

        vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        pool.mintWithPermit(shares, lp, liquidity, deadline, v, r, s);

        vm.stopPrank();

        vm.prank(governor);
        globals.setProtocolPause(false);

        vm.startPrank(lp);
        pool.mintWithPermit(shares, lp, liquidity, deadline, v, r, s);
    }

    function test_mintWithPermit_notActive() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity);

        vm.prank(poolDelegate);
        poolManager.setAllowedLender(lp, true);

        vm.startPrank(lp);

        uint256 shares = pool.previewDeposit(liquidity);

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity, nonce, deadline, lpSk);

        vm.expectRevert("P:MWP:NOT_ACTIVE");
        pool.mintWithPermit(shares, lp, liquidity, deadline, v, r, s);

        vm.stopPrank();

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.startPrank(lp);
        pool.mintWithPermit(shares, lp, liquidity, deadline, v, r, s);
    }

    function test_mintWithPermit_privatePoolInvalidRecipient() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.startPrank(lp);

        uint256 shares = pool.previewDeposit(liquidity);

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity, nonce, deadline, lpSk);

        vm.expectRevert("P:MWP:LENDER_NOT_ALLOWED");
        pool.mintWithPermit(shares, lp, liquidity, deadline, v, r, s);

        vm.stopPrank();

        vm.prank(poolDelegate);
        poolManager.setAllowedLender(lp, true);

        vm.prank(lp);
        pool.mintWithPermit(shares, lp, liquidity, deadline, v, r, s);
    }

    function test_mintWithPermit_privatePoolInvalidRecipient_openPoolToPublic() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.startPrank(lp);

        uint256 shares = pool.previewDeposit(liquidity);

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity, nonce, deadline, lpSk);

        vm.expectRevert("P:MWP:LENDER_NOT_ALLOWED");
        pool.mintWithPermit(shares, lp, liquidity, deadline, v, r, s);

        vm.stopPrank();

        // Pool is opened to public, shares may be transferred to anyone.
        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();

        vm.prank(lp);
        pool.mintWithPermit(shares, lp, liquidity, deadline, v, r, s);
    }

    function test_mintWithPermit_liquidityCapExceeded() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity );

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.startPrank(poolDelegate);

        poolManager.setOpenToPublic();
        poolManager.setLiquidityCap(1_000e6);

        vm.stopPrank();

        vm.startPrank(lp);

        uint256 shares = pool.previewDeposit(liquidity);

        // Deposit an initial amount before setting liquidity cap.
        uint256 initialMintAmount = shares * 4 / 10;
        uint256 nextMintAmount    = shares - initialMintAmount;

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity, nonce, deadline, lpSk);

        pool.mintWithPermit(initialMintAmount, lp, liquidity, deadline, v, r, s);
        nonce += 1;

        vm.stopPrank();

        vm.startPrank(lp);

        ( v, r, s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity, nonce, deadline, lpSk);

        vm.expectRevert("P:MWP:DEPOSIT_GT_LIQ_CAP");
        pool.mintWithPermit(nextMintAmount + 1, lp, liquidity, deadline, v, r, s);

        ( v, r, s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity, nonce, deadline, lpSk);

        pool.mintWithPermit(nextMintAmount, lp, liquidity, deadline, v, r, s);
    }

    function test_mintWithPermit_insufficientPermit() external {
        uint256 liquidity = 1_000e6;

        fundsAsset.mint(lp, liquidity);

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        vm.prank(poolDelegate);
        poolManager.setAllowedLender(lp, true);

        vm.startPrank(lp);

        uint256 shares = pool.previewDeposit(liquidity);
        uint256 assets = pool.previewMint(shares);

        (
            uint8 v,
            bytes32 r,
            bytes32 s
        ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), assets - 1, nonce, deadline, lpSk);

        vm.expectRevert("P:MWP:INSUFFICIENT_PERMIT");
        pool.mintWithPermit(shares, lp, assets - 1, deadline, v, r, s);

        ( v, r, s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), assets, nonce, deadline, lpSk);
        pool.mintWithPermit(shares, lp, liquidity, deadline, v, r, s);
    }

}
