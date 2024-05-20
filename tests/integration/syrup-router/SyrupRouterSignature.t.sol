// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Vm } from "../../../modules/forge-std/src/Vm.sol";

import { SyrupRouter } from "../../../modules/syrup-router/contracts/SyrupRouter.sol";

import { TestBase } from "../../TestBase.sol";

contract SyrupRouterAuthorizeAndDepositTests is TestBase {

    address liquidityProvider = 0xBeEfFe4B5b22050938A1c2fA0BcEFD964C54beef;
    address signatureProvider = 0x11C9cF9ac22137AF31Cc4408d994E19e0C943973;

    uint256 depositAmount    = 100_000e6;
    uint256 permissionLevel  = 2;
    uint256 requiredBitmap   = 0x3;  // 0b0011
    uint256 sufficientBitmap = 0xB;  // 0b1011

    // Generated from the following values:
    // - chainid:  31337
    // - router:   0x83898D1F3C03189fF03B471dd3456908FCA4423d
    // - lender:   0xBeEfFe4B5b22050938A1c2fA0BcEFD964C54beef
    // - nonce:    0
    // - bitmap:   11
    // - deadline: 1685721539
    uint8   v = 27;
    bytes32 r = bytes32(0x75bcbe3b25bbeeb3ba3344c4dc281063d31c7791f9cb5dfa50e59478bfed9ab3);
    bytes32 s = bytes32(0x27c9ccde7812c8999c854d09a7b1e90d761340e40539c9fb28eb57c50dfe5960);

    SyrupRouter public syrupRouter;

    function setUp() public virtual override {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createPoolWithQueue();
        _configurePool();

        syrupRouter = new SyrupRouter(address(pool));

        allowLender(address(poolManager), address(syrupRouter));

        setPoolPermissionLevel(address(poolManager), permissionLevel);
        setPoolBitmap(address(poolManager), requiredBitmap);

        vm.startPrank(governor);
        poolPermissionManager.setPermissionAdmin(signatureProvider, true);
        poolPermissionManager.setPermissionAdmin(address(syrupRouter), true);
        vm.stopPrank();

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);

        // Sanity checks
        assertEq(block.chainid,        31337);
        assertEq(block.timestamp,      1685721539);
        assertEq(address(syrupRouter), 0x83898D1F3C03189fF03B471dd3456908FCA4423d);
    }

    function test_signature_authorizeAndDeposit_expiredDeadline() external {
        vm.prank(liquidityProvider);
        vm.expectRevert("SR:A:EXPIRED");
        syrupRouter.authorizeAndDeposit(sufficientBitmap, block.timestamp - 1 seconds, v, r, s, depositAmount, bytes32(0));
    }

    function test_signature_authorizeAndDeposit_malleable() external {
        v = 26;

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:A:MALLEABLE");
        syrupRouter.authorizeAndDeposit(sufficientBitmap, block.timestamp, v, r, s, depositAmount, bytes32(0));
    }

    function test_signature_authorizeAndDeposit_invalidSignature() external {
        s <<= 1;

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:A:NOT_PERMISSION_ADMIN");
        syrupRouter.authorizeAndDeposit(sufficientBitmap, block.timestamp, v, r, s, depositAmount, bytes32(0));
    }

    function test_signature_authorizeAndDeposit_replayed() external {
        vm.prank(liquidityProvider);
        syrupRouter.authorizeAndDeposit(sufficientBitmap, block.timestamp, v, r, s, depositAmount, bytes32(0));

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:A:NOT_PERMISSION_ADMIN");
        syrupRouter.authorizeAndDeposit(sufficientBitmap, block.timestamp, v, r, s, depositAmount, bytes32(0));
    }

    function test_signature_authorizeAndDeposit_notPermissionAdmin() external {
        vm.prank(governor);
        poolPermissionManager.setPermissionAdmin(signatureProvider, false);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:A:NOT_PERMISSION_ADMIN");
        syrupRouter.authorizeAndDeposit(sufficientBitmap, block.timestamp, v, r, s, depositAmount, bytes32(0));
    }

    function test_signature_authorizeAndDeposit_success() external {
        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(fundsAsset.balanceOf(address(pool)),     0);

        assertEq(pool.balanceOf(liquidityProvider), 0);

        assertEq(poolPermissionManager.lenderBitmaps(liquidityProvider), 0);

        vm.prank(liquidityProvider);
        syrupRouter.authorizeAndDeposit(sufficientBitmap, block.timestamp, v, r, s, depositAmount, bytes32(0));

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(fundsAsset.balanceOf(address(pool)),     depositAmount);

        assertEq(pool.balanceOf(liquidityProvider), depositAmount);

        assertEq(poolPermissionManager.lenderBitmaps(liquidityProvider), sufficientBitmap);
    }

}
