// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { Address, console   } from "../modules/contract-test-utils/contracts/test.sol";
import { MockERC20 as Asset } from "../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { TestBase } from "../contracts/utilities/TestBase.sol";

contract EnterBase is TestBase {

    address lp;

    function setUp() public virtual override {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _createFactories();
        _createPool(1 weeks, 2 days);
        // NOTE: As opposed to super.setUp(), do not configure the pool or perform any later steps, because pool configuration will be validated in the tests.

        start = block.timestamp;
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

    uint256 deadline = 5_000_000_000;
    uint256 lpSk     = 1;
    uint256 nonce;

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

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity, nonce, deadline, lpSk);

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

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity, nonce, deadline, lpSk);

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

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity, nonce, deadline, lpSk);

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

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity, nonce, deadline, lpSk);

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

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity - 1, nonce, deadline, lpSk);

        vm.expectRevert("ERC20:P:INVALID_SIGNATURE");
        pool.depositWithPermit(liquidity, lp, deadline, v, r, s);

        ( v, r, s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity, nonce, deadline, lpSk);
        pool.depositWithPermit(liquidity, lp, deadline, v, r, s);
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

    uint256 deadline = 5_000_000_000;
    uint256 lpSk     = 1;
    uint256 nonce;

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

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity, nonce, deadline, lpSk);

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

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity, nonce, deadline, lpSk);

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

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity, nonce, deadline, lpSk);

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

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity, nonce, deadline, lpSk);

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

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), liquidity, nonce, deadline, lpSk);

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

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), assets - 1, nonce, deadline, lpSk);

        vm.expectRevert("P:MWP:INSUFFICIENT_PERMIT");
        pool.mintWithPermit(shares, lp, assets - 1, deadline, v, r, s);

        ( v, r, s ) = _getValidPermitSignature(address(fundsAsset), lp, address(pool), assets, nonce, deadline, lpSk);
        pool.mintWithPermit(shares, lp, liquidity, deadline, v, r, s);
    }

}