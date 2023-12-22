// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { TestBase } from "../TestBase.sol";

contract HasPermissionFuzzTests is TestBase {

    uint256 constant PRIVATE        = 0;
    uint256 constant FUNCTION_LEVEL = 1;
    uint256 constant POOL_LEVEL     = 2;
    uint256 constant PUBLIC         = 3;

    uint256 constant MAX_AMOUNT = 1e30;

    uint256 privateKey = 8764352426;

    address lender = vm.addr(privateKey);

    function setUp() public override {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createAndConfigurePool(start, 1 weeks, 2 days);

        // NOTE: Pool and Withdrawal manager need to be whitelisted to allow redemption workflow to work.
        setLenderAllowlist(address(poolManager), address(poolManager), true);
        setLenderAllowlist(address(poolManager), address(cyclicalWM),  true);
    }

    /**************************************************************************************************************************************/
    /*** Helper Functions                                                                                                               ***/
    /**************************************************************************************************************************************/

    function hasPermission(
        uint256 permissionLevel,
        bool    isAllowlisted,
        uint256 poolBitmap,
        uint256 lenderBitmap
    )
        internal pure returns (bool isAllowed)
    {
        if (permissionLevel == PUBLIC || isAllowlisted) return true;
        if (permissionLevel == PRIVATE) return false;

        return poolBitmap & lenderBitmap == poolBitmap;
    }

    function setupApproval(address owner, address caller, uint256 amount) internal {
        vm.prank(owner);
        pool.approve(caller, amount);
    }

    function setupDeposit(address account, uint256 assets) internal {
        vm.startPrank(account);
        fundsAsset.mint(account, assets);
        fundsAsset.approve(address(pool), assets);
        vm.stopPrank();

        setLenderAllowlist(address(poolManager), account, true);

        vm.prank(account);
        pool.deposit(assets, account);

        setLenderAllowlist(address(poolManager), account, false);
    }

    function setupLenderPermissions(address account, bool isAllowlisted, uint256 bitmap) internal {
        setLenderBitmap(address(poolPermissionManager), permissionAdmin, account, bitmap);
        setLenderAllowlist(address(poolManager), account, isAllowlisted);
    }

    function setupPoolPermissions(uint256 permissionLevel, bytes32 functionId, uint256 bitmap) internal {
        setPoolPermissionLevel(address(poolManager), permissionLevel);
        setPoolBitmap(address(poolManager), permissionLevel == FUNCTION_LEVEL ? functionId : bytes32(0), bitmap);
    }

    function setupPoolPermissions(uint256 permissionLevel, bytes32 functionId1, bytes32 functionId2, uint256 bitmap) internal {
        setPoolPermissionLevel(address(poolManager), permissionLevel);
        setPoolBitmap(address(poolManager), permissionLevel == FUNCTION_LEVEL ? functionId1 : bytes32(0), bitmap);
        setPoolBitmap(address(poolManager), permissionLevel == FUNCTION_LEVEL ? functionId2 : bytes32(0), bitmap);
    }

    function setupRequest(address account, uint256 shares) internal {
        setLenderAllowlist(address(poolManager), account, true);

        vm.prank(lender);
        pool.requestRedeem(shares, lender);

        setLenderAllowlist(address(poolManager), account, false);
    }

    /**************************************************************************************************************************************/
    /*** Fuzz Tests                                                                                                                     ***/
    /**************************************************************************************************************************************/

    function testFuzz_hasPermission_deposit(
        uint256 permissionLevel,
        uint256 poolBitmap,
        uint256 lenderBitmap,
        bool    isAllowlisted,
        uint256 assetsToDeposit
    )
        external
    {
        permissionLevel = bound(permissionLevel, 0, PUBLIC);
        assetsToDeposit = bound(assetsToDeposit, 1, MAX_AMOUNT);

        vm.startPrank(lender);
        fundsAsset.mint(lender, assetsToDeposit);
        fundsAsset.approve(address(pool), assetsToDeposit);
        vm.stopPrank();

        setupPoolPermissions(permissionLevel, "P:deposit", poolBitmap);
        setupLenderPermissions(lender, isAllowlisted, lenderBitmap);

        bool isAllowed = hasPermission(permissionLevel, isAllowlisted, poolBitmap, lenderBitmap);

        assertEq(fundsAsset.balanceOf(address(pool)), 0);
        assertEq(fundsAsset.balanceOf(lender),        assetsToDeposit);

        assertEq(pool.balanceOf(lender), 0);
        assertEq(pool.totalSupply(),     0);

        if (!isAllowed) vm.expectRevert("PM:CC:NOT_ALLOWED");

        vm.prank(lender);
        pool.deposit(assetsToDeposit, lender);

        if (!isAllowed) return;

        assertEq(fundsAsset.balanceOf(address(pool)), assetsToDeposit);
        assertEq(fundsAsset.balanceOf(lender),        0);

        assertEq(pool.balanceOf(lender), assetsToDeposit);
        assertEq(pool.totalSupply(),     assetsToDeposit);
    }

    function testFuzz_hasPermission_depositWithPermit(
        uint256 permissionLevel,
        uint256 poolBitmap,
        uint256 lenderBitmap,
        bool    isAllowlisted,
        uint256 assetsToDeposit
    )
        external
    {
        permissionLevel = bound(permissionLevel, 0, PUBLIC);
        assetsToDeposit = bound(assetsToDeposit, 1, MAX_AMOUNT);

        fundsAsset.mint(lender, assetsToDeposit);

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(
            address(fundsAsset),
            lender,
            address(pool),
            assetsToDeposit,
            type(uint256).max,
            privateKey
        );

        setupPoolPermissions(permissionLevel, "P:depositWithPermit", poolBitmap);
        setupLenderPermissions(lender, isAllowlisted, lenderBitmap);

        bool isAllowed = hasPermission(permissionLevel, isAllowlisted, poolBitmap, lenderBitmap);

        assertEq(fundsAsset.balanceOf(address(pool)), 0);
        assertEq(fundsAsset.balanceOf(lender),        assetsToDeposit);

        assertEq(pool.balanceOf(lender), 0);
        assertEq(pool.totalSupply(),     0);

        if (!isAllowed) vm.expectRevert("PM:CC:NOT_ALLOWED");

        vm.prank(lender);
        pool.depositWithPermit(assetsToDeposit, lender, type(uint256).max, v, r, s);

        if (!isAllowed) return;

        assertEq(fundsAsset.balanceOf(address(pool)), assetsToDeposit);
        assertEq(fundsAsset.balanceOf(lender),        0);

        assertEq(pool.balanceOf(lender), assetsToDeposit);
        assertEq(pool.totalSupply(),     assetsToDeposit);

    }

    function testFuzz_hasPermission_mint(
        uint256 permissionLevel,
        uint256 poolBitmap,
        uint256 lenderBitmap,
        bool    isAllowlisted,
        uint256 sharesToMint
    )
        external
    {
        permissionLevel = bound(permissionLevel, 0, PUBLIC);
        sharesToMint    = bound(sharesToMint,    1, MAX_AMOUNT);

        vm.startPrank(lender);
        fundsAsset.mint(lender, sharesToMint);
        fundsAsset.approve(address(pool), sharesToMint);
        vm.stopPrank();

        setupPoolPermissions(permissionLevel, "P:mint", poolBitmap);
        setupLenderPermissions(lender, isAllowlisted, lenderBitmap);

        bool isAllowed = hasPermission(permissionLevel, isAllowlisted, poolBitmap, lenderBitmap);

        assertEq(fundsAsset.balanceOf(address(pool)), 0);
        assertEq(fundsAsset.balanceOf(lender),        sharesToMint);

        assertEq(pool.balanceOf(lender), 0);
        assertEq(pool.totalSupply(),     0);

        if (!isAllowed) vm.expectRevert("PM:CC:NOT_ALLOWED");

        vm.prank(lender);
        pool.mint(sharesToMint, lender);

        if (!isAllowed) return;

        assertEq(fundsAsset.balanceOf(address(pool)), sharesToMint);
        assertEq(fundsAsset.balanceOf(lender),        0);

        assertEq(pool.balanceOf(lender), sharesToMint);
        assertEq(pool.totalSupply(),     sharesToMint);
    }

    function testFuzz_hasPermission_mintWithPermit(
        uint256 permissionLevel,
        uint256 poolBitmap,
        uint256 lenderBitmap,
        bool    isAllowlisted,
        uint256 sharesToMint
    )
        external
    {
        permissionLevel = bound(permissionLevel, 0, PUBLIC);
        sharesToMint    = bound(sharesToMint,    1, MAX_AMOUNT);

        fundsAsset.mint(lender, sharesToMint);

        ( uint8 v, bytes32 r, bytes32 s ) = _getValidPermitSignature(
            address(fundsAsset),
            lender,
            address(pool),
            sharesToMint,
            type(uint256).max,
            privateKey
        );

        setupPoolPermissions(permissionLevel, "P:mintWithPermit", poolBitmap);
        setupLenderPermissions(lender, isAllowlisted, lenderBitmap);

        bool isAllowed = hasPermission(permissionLevel, isAllowlisted, poolBitmap, lenderBitmap);

        assertEq(fundsAsset.balanceOf(address(pool)), 0);
        assertEq(fundsAsset.balanceOf(lender),        sharesToMint);

        assertEq(pool.balanceOf(lender), 0);
        assertEq(pool.totalSupply(),     0);

        if (!isAllowed) vm.expectRevert("PM:CC:NOT_ALLOWED");

        vm.prank(lender);
        pool.mintWithPermit(sharesToMint, lender, sharesToMint, type(uint256).max, v, r, s);

        if (!isAllowed) return;

        assertEq(fundsAsset.balanceOf(address(pool)), sharesToMint);
        assertEq(fundsAsset.balanceOf(lender),        0);

        assertEq(pool.balanceOf(lender), sharesToMint);
        assertEq(pool.totalSupply(),     sharesToMint);
    }

    function testFuzz_hasPermission_removeShares(
        uint256 permissionLevel,
        uint256 poolBitmap,
        uint256 lenderBitmap,
        bool    isAllowlisted,
        uint256 sharesToRequest,
        uint256 sharesToRemove
    )
        external
    {
        permissionLevel = bound(permissionLevel, 0, PUBLIC);
        sharesToRequest = bound(sharesToRequest, 1, MAX_AMOUNT);
        sharesToRemove  = bound(sharesToRemove,  1, sharesToRequest);

        setupDeposit(lender, sharesToRequest);
        setupRequest(lender, sharesToRequest);
        setupPoolPermissions(permissionLevel, "P:removeShares", "P:transfer", poolBitmap);
        setupLenderPermissions(lender, isAllowlisted, lenderBitmap);

        bool isAllowed = hasPermission(permissionLevel, isAllowlisted, poolBitmap, lenderBitmap);

        assertEq(pool.balanceOf(lender),              0);
        assertEq(pool.balanceOf(address(cyclicalWM)), sharesToRequest);

        if (!isAllowed) vm.expectRevert("PM:CC:NOT_ALLOWED");

        vm.warp(start + 2 weeks);
        vm.prank(lender);
        pool.removeShares(sharesToRemove, lender);

        if (!isAllowed) return;

        assertEq(pool.balanceOf(lender),              sharesToRemove);
        assertEq(pool.balanceOf(address(cyclicalWM)), sharesToRequest - sharesToRemove);
    }

    function testFuzz_hasPermission_redeem(
        uint256 permissionLevel,
        uint256 poolBitmap,
        uint256 lenderBitmap,
        bool    isAllowlisted,
        uint256 sharesToRedeem,
        address receiver
    )
        external
    {
        vm.assume(receiver != address(0));
        vm.assume(receiver != address(pool));

        permissionLevel = bound(permissionLevel, 0, PUBLIC);
        sharesToRedeem  = bound(sharesToRedeem,  1, MAX_AMOUNT);

        setupDeposit(lender, sharesToRedeem);
        setupRequest(lender, sharesToRedeem);
        setupPoolPermissions(permissionLevel, "P:redeem", "P:transfer", poolBitmap);
        setupLenderPermissions(lender, isAllowlisted, lenderBitmap);

        bool isAllowed = hasPermission(permissionLevel, isAllowlisted, poolBitmap, lenderBitmap);

        uint256 receiverBalance = fundsAsset.balanceOf(receiver);

        assertEq(pool.balanceOf(address(cyclicalWM)), sharesToRedeem);

        if (!isAllowed) vm.expectRevert("PM:CC:NOT_ALLOWED");

        vm.warp(start + 2 weeks);
        vm.prank(lender);
        pool.redeem(sharesToRedeem, receiver, lender);

        if (!isAllowed) return;

        assertEq(fundsAsset.balanceOf(receiver), receiverBalance + sharesToRedeem);

        assertEq(pool.balanceOf(address(cyclicalWM)), 0);
    }

    function testFuzz_hasPermission_requestRedeem(
        uint256 permissionLevel,
        uint256 poolBitmap,
        uint256 lenderBitmap,
        bool    isAllowlisted,
        uint256 sharesToRedeem
    )
        external
    {
        permissionLevel = bound(permissionLevel, 0, PUBLIC);
        sharesToRedeem  = bound(sharesToRedeem,  1, MAX_AMOUNT);

        setupDeposit(lender, sharesToRedeem);
        setupPoolPermissions(permissionLevel, "P:requestRedeem", poolBitmap);
        setupLenderPermissions(lender, isAllowlisted, lenderBitmap);

        bool isAllowed = hasPermission(permissionLevel, isAllowlisted, poolBitmap, lenderBitmap);

        assertEq(pool.balanceOf(lender),              sharesToRedeem);
        assertEq(pool.balanceOf(address(cyclicalWM)), 0);

        if (!isAllowed) vm.expectRevert("PM:CC:NOT_ALLOWED");

        vm.prank(lender);
        pool.requestRedeem(sharesToRedeem, lender);

        if (!isAllowed) return;

        assertEq(pool.balanceOf(lender),              0);
        assertEq(pool.balanceOf(address(cyclicalWM)), sharesToRedeem);
    }

    function testFuzz_hasPermission_requestWithdraw(
        uint256 permissionLevel,
        uint256 poolBitmap,
        uint256 lenderBitmap,
        bool    isAllowlisted,
        uint256 assetsToWithdraw
    )
        external
    {
        permissionLevel  = bound(permissionLevel,  0, PUBLIC);
        assetsToWithdraw = bound(assetsToWithdraw, 0, MAX_AMOUNT);

        fundsAsset.mint(address(pool), 1);

        setupPoolPermissions(permissionLevel, "P:requestWithdraw", poolBitmap);
        setupLenderPermissions(lender, isAllowlisted, lenderBitmap);

        bool isAllowed = hasPermission(permissionLevel, isAllowlisted, poolBitmap, lenderBitmap);

        if (isAllowed) {
            vm.expectRevert("PM:RW:NOT_ENABLED");
        } else {
            vm.expectRevert("PM:CC:NOT_ALLOWED");
        }

        vm.prank(lender);
        pool.requestWithdraw(assetsToWithdraw, lender);
    }

    function testFuzz_hasPermission_transfer(
        uint256 permissionLevel,
        uint256 poolBitmap,
        address sender,
        uint256 senderBitmap,
        bool    isSenderAllowlisted,
        address receiver,
        uint256 receiverBitmap,
        bool    isReceiverAllowlisted,
        uint256 sharesToTransfer
    )
        external
    {
        vm.assume(sender != address(0));
        vm.assume(sender != receiver);

        permissionLevel  = bound(permissionLevel,  0, PUBLIC);
        sharesToTransfer = bound(sharesToTransfer, 1, MAX_AMOUNT);

        setupDeposit(sender, sharesToTransfer);
        setupPoolPermissions(permissionLevel, "P:transfer", poolBitmap);
        setupLenderPermissions(sender, isSenderAllowlisted, senderBitmap);
        setupLenderPermissions(receiver, isReceiverAllowlisted, receiverBitmap);

        bool isSenderAllowed   = hasPermission(permissionLevel, isSenderAllowlisted,   poolBitmap, senderBitmap);
        bool isReceiverAllowed = hasPermission(permissionLevel, isReceiverAllowlisted, poolBitmap, receiverBitmap);
        bool isAllowed         = isSenderAllowed && isReceiverAllowed;

        uint256 senderBalance   = pool.balanceOf(sender);
        uint256 receiverBalance = pool.balanceOf(receiver);

        if (!isAllowed) vm.expectRevert("PM:CC:NOT_ALLOWED");

        vm.prank(sender);
        pool.transfer(receiver, sharesToTransfer);

        if (!isAllowed) return;

        assertEq(pool.balanceOf(sender),   senderBalance - sharesToTransfer);
        assertEq(pool.balanceOf(receiver), receiverBalance + sharesToTransfer);
    }

    function testFuzz_hasPermission_transferFrom(
        uint256 permissionLevel,
        uint256 poolBitmap,
        address sender,
        uint256 senderBitmap,
        bool    isSenderAllowlisted,
        address receiver,
        uint256 receiverBitmap,
        bool    isReceiverAllowlisted,
        address caller,
        uint256 sharesToTransfer
    )
        external
    {
        vm.assume(sender != address(0));
        vm.assume(sender != receiver);

        permissionLevel  = bound(permissionLevel,  0, PUBLIC);
        sharesToTransfer = bound(sharesToTransfer, 1, MAX_AMOUNT);

        setupDeposit(sender, sharesToTransfer);
        setupApproval(sender, caller, sharesToTransfer);
        setupPoolPermissions(permissionLevel, "P:transferFrom", poolBitmap);
        setupLenderPermissions(sender, isSenderAllowlisted, senderBitmap);
        setupLenderPermissions(receiver, isReceiverAllowlisted, receiverBitmap);

        bool isSenderAllowed   = hasPermission(permissionLevel, isSenderAllowlisted,   poolBitmap, senderBitmap);
        bool isReceiverAllowed = hasPermission(permissionLevel, isReceiverAllowlisted, poolBitmap, receiverBitmap);
        bool isAllowed         = isSenderAllowed && isReceiverAllowed;

        uint256 senderBalance   = pool.balanceOf(sender);
        uint256 receiverBalance = pool.balanceOf(receiver);

        if (!isAllowed) vm.expectRevert("PM:CC:NOT_ALLOWED");

        vm.prank(caller);
        pool.transferFrom(sender, receiver, sharesToTransfer);

        if (!isAllowed) return;

        assertEq(pool.balanceOf(sender),   senderBalance - sharesToTransfer);
        assertEq(pool.balanceOf(receiver), receiverBalance + sharesToTransfer);
    }

    function testFuzz_hasPermission_withdraw(
        uint256 permissionLevel,
        uint256 poolBitmap,
        uint256 lenderBitmap,
        bool    isAllowlisted,
        uint256 assetsToWithdraw,
        address receiver
    )
        external
    {
        permissionLevel  = bound(permissionLevel,  0, PUBLIC);
        assetsToWithdraw = bound(assetsToWithdraw, 0, MAX_AMOUNT);

        fundsAsset.mint(address(pool), 1);

        setupPoolPermissions(permissionLevel, "P:withdraw", poolBitmap);
        setupLenderPermissions(lender, isAllowlisted, lenderBitmap);

        bool isAllowed = hasPermission(permissionLevel, isAllowlisted, poolBitmap, lenderBitmap);

        if (isAllowed) {
            vm.expectRevert("PM:PW:NOT_ENABLED");
        } else {
            vm.expectRevert("PM:CC:NOT_ALLOWED");
        }

        vm.prank(lender);
        pool.withdraw(assetsToWithdraw, receiver, lender);
    }

}
