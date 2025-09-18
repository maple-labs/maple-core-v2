// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { Permit } from "../../../../contracts/interfaces/Interfaces.sol";

import { SyrupBitcoinTestBase } from "../SyrupBitcoinTestBase.sol";

contract SyrupBitcoinRouterRequestRedeemTests is SyrupBitcoinTestBase {

    address alice;
    address bob;

    uint256 alicePrivateKey;
    uint256 bobPrivateKey;

    function setUp() public override {
        super.setUp();

        ( alice, alicePrivateKey ) = makeAddrAndKey("alice");
        ( bob,   bobPrivateKey   ) = makeAddrAndKey("bob");

        uint256 initialDepositAmount = 100e8;

        depositAsset.mint(alice, initialDepositAmount);
        depositAsset.mint(bob,   initialDepositAmount);

        assertEq(depositAsset.balanceOf(alice), initialDepositAmount);
        assertEq(depositAsset.balanceOf(bob),   initialDepositAmount);

        vm.startPrank(alice);
        depositAsset.approve(address(bitcoinRouter), initialDepositAmount);
        bitcoinRouter.deposit(address(depositAsset), initialDepositAmount, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();

        vm.startPrank(bob);
        depositAsset.approve(address(bitcoinRouter), initialDepositAmount);
        bitcoinRouter.deposit(address(depositAsset), initialDepositAmount, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();

        assertEq(pool.balanceOf(alice), initialDepositAmount);
        assertEq(pool.balanceOf(bob),   initialDepositAmount);
    }

    function test_requestRedeem_revert_paused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("SBR:PAUSED");
        bitcoinRouter.requestRedeem(address(depositAsset), 100e8, EMPTY_METADATA, emptyPermit());
    }

    function test_requestRedeem_revert_noAssetController() external {
        vm.expectRevert("SBR:RR:NO_ASSET_CONTROLLER");
        bitcoinRouter.requestRedeem(makeAddr("invalidAsset"), 100e8, EMPTY_METADATA, emptyPermit());
    }

    function test_requestRedeem_revert_permitExpired() external {
        Permit memory permit = signPermit(alicePrivateKey, address(pool), alice, 100e8, block.timestamp - 1 days);

        vm.prank(alice);
        vm.expectRevert("ERC20:P:EXPIRED");
        bitcoinRouter.requestRedeem(address(depositAsset), 100e8, EMPTY_METADATA, permit);
    }

    function test_requestRedeem_revert_invalidPermit_invalidAsset() external {
        Permit memory permit = signPermit(alicePrivateKey, address(depositAsset), alice, 100e8, block.timestamp + 1 days);

        vm.prank(alice);
        vm.expectRevert("ERC20:P:INVALID_SIGNATURE");
        bitcoinRouter.requestRedeem(address(depositAsset), 100e8, EMPTY_METADATA, permit);
    }

    function test_requestRedeem_revert_invalidPermit_wrongAmount() external {
        Permit memory permit = signPermit(alicePrivateKey, address(pool), alice, 100e8, block.timestamp + 1 days);

        vm.prank(alice);
        vm.expectRevert("ERC20:P:INVALID_SIGNATURE");
        bitcoinRouter.requestRedeem(address(depositAsset), 100e8 + 1, EMPTY_METADATA, permit);
    }

    function test_requestRedeem_revert_transferFromUserFailed() external {
        vm.prank(alice);
        vm.expectRevert("SBR:RR:TRANSFER_FAILED");
        bitcoinRouter.requestRedeem(address(depositAsset), 100e8, EMPTY_METADATA, emptyPermit());
    }

    function test_requestRedeem_revert_cannotUnwrap() external {
        address[] memory assets       = new address[](1);
        bool[]    memory canWrap      = new bool[](1);
        bool[]    memory canUnwrap    = new bool[](1);
        bool[]    memory canDeploy    = new bool[](1);
        bool[]    memory canReconcile = new bool[](1);

        assets[0]       = address(depositAsset);
        canWrap[0]      = true;
        canUnwrap[0]    = false;
        canDeploy[0]    = true;
        canReconcile[0] = true;

        vm.prank(governor);
        assetController.setAssets(assets, canWrap, canUnwrap, canDeploy, canReconcile);

        uint256 redeemAmount = 10e8;

        vm.startPrank(alice);
        pool.approve(address(bitcoinRouter), redeemAmount);

        vm.expectRevert("SBR:RR:CANNOT_UNWRAP");
        bitcoinRouter.requestRedeem(address(depositAsset), redeemAmount, EMPTY_METADATA, emptyPermit());
    }

    function test_requestRedeem_revert_zeroAmount() external {
        vm.startPrank(alice);
        vm.expectRevert("WM:AS:ZERO_SHARES");
        bitcoinRouter.requestRedeem(address(depositAsset), 0, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();
    }

    function test_requestRedeem_success_singleRequestByOneLp_allowanceOverridesPermit_notEmptyMetadata() external {
        uint256 redeemAmount             = 10e8;
        uint256 aliceSharesBalanceBefore = pool.balanceOf(alice);
        uint256 wmSharesBalanceBefore    = pool.balanceOf(address(withdrawalManager));

        ( uint256 nextRequestId, uint256 lastRequestId ) = withdrawalManager.queue();
        assertEq(nextRequestId, 1);
        assertEq(lastRequestId, 0);

        assertEq(withdrawalManager.totalShares(),                                 0);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    0);
        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);

        assertRequestOnRouter({
            requestId: 0,
            asset:     address(0),
            owner:     address(0),
            shares:    0
        });

        assertRequestOnWm({
            requestId: 0,
            owner:     address(0),
            shares:    0
        });

        Permit memory permit = signPermit(alicePrivateKey, address(pool), alice, redeemAmount, block.timestamp + 1 days);
        bytes32 metadata     = keccak256("random_metadata");

        vm.startPrank(alice);
        pool.approve(address(bitcoinRouter), redeemAmount);

        assertEq(pool.allowance(alice, address(bitcoinRouter)), redeemAmount);

        ( uint256 sharesLocked, uint256 requestId ) =
            bitcoinRouter.requestRedeem(address(depositAsset), redeemAmount, metadata, permit);
        vm.stopPrank();

        assertEq(pool.allowance(alice, address(bitcoinRouter)), 0);

        assertEq(sharesLocked, redeemAmount);
        assertEq(requestId,    1);

        ( nextRequestId, lastRequestId ) = withdrawalManager.queue();
        assertEq(nextRequestId, 1);
        assertEq(lastRequestId, 1);

        assertEq(withdrawalManager.totalShares(),                                 redeemAmount);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    redeemAmount);
        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);

        assertRequestOnRouter({
            requestId: 1,
            asset:     address(depositAsset),
            owner:     alice,
            shares:    redeemAmount
        });

        assertRequestOnWm({
            requestId: 1,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount
        });

        assertEq(pool.balanceOf(alice),                      aliceSharesBalanceBefore - redeemAmount);
        assertEq(pool.balanceOf(address(withdrawalManager)), wmSharesBalanceBefore + redeemAmount);
    }

    function test_requestRedeem_success_singleRequestByOneLp() external {
        uint256 redeemAmount             = 10e8;
        uint256 aliceSharesBalanceBefore = pool.balanceOf(alice);
        uint256 wmSharesBalanceBefore    = pool.balanceOf(address(withdrawalManager));

        ( uint256 nextRequestId, uint256 lastRequestId ) = withdrawalManager.queue();
        assertEq(nextRequestId, 1);
        assertEq(lastRequestId, 0);

        assertEq(withdrawalManager.totalShares(),                                 0);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    0);
        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);

        assertRequestOnRouter({
            requestId: 0,
            asset:     address(0),
            owner:     address(0),
            shares:    0
        });

        assertRequestOnWm({
            requestId: 0,
            owner:     address(0),
            shares:    0
        });

        vm.startPrank(alice);
        pool.approve(address(bitcoinRouter), redeemAmount);

        ( uint256 sharesLocked, uint256 requestId ) =
            bitcoinRouter.requestRedeem(address(depositAsset), redeemAmount, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();

        assertEq(sharesLocked, redeemAmount);
        assertEq(requestId,    1);

        ( nextRequestId, lastRequestId ) = withdrawalManager.queue();
        assertEq(nextRequestId, 1);
        assertEq(lastRequestId, 1);

        assertEq(withdrawalManager.totalShares(),                                 redeemAmount);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    redeemAmount);
        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);

        assertRequestOnRouter({
            requestId: 1,
            asset:     address(depositAsset),
            owner:     alice,
            shares:    redeemAmount
        });

        assertRequestOnWm({
            requestId: 1,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount
        });

        assertEq(pool.balanceOf(alice),                      aliceSharesBalanceBefore - redeemAmount);
        assertEq(pool.balanceOf(address(withdrawalManager)), wmSharesBalanceBefore + redeemAmount);
    }

    function test_requestRedeem_success_singleRequestByOneLp_fullRedeem() external {
        uint256 redeemAmount          = pool.balanceOf(alice);
        uint256 wmSharesBalanceBefore = pool.balanceOf(address(withdrawalManager));

        ( uint256 nextRequestId, uint256 lastRequestId ) = withdrawalManager.queue();
        assertEq(nextRequestId, 1);
        assertEq(lastRequestId, 0);

        assertEq(withdrawalManager.totalShares(),                                 0);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    0);
        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);

        assertRequestOnRouter({
            requestId: 0,
            asset:     address(0),
            owner:     address(0),
            shares:    0
        });

        assertRequestOnWm({
            requestId: 0,
            owner:     address(0),
            shares:    0
        });

        vm.startPrank(alice);
        pool.approve(address(bitcoinRouter), redeemAmount);

        ( uint256 sharesLocked, uint256 requestId ) =
            bitcoinRouter.requestRedeem(address(depositAsset), redeemAmount, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();

        assertEq(sharesLocked, redeemAmount);
        assertEq(requestId,    1);

        ( nextRequestId, lastRequestId ) = withdrawalManager.queue();
        assertEq(nextRequestId, 1);
        assertEq(lastRequestId, 1);

        assertEq(withdrawalManager.totalShares(),                                 redeemAmount);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    redeemAmount);
        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);

        assertRequestOnRouter({
            requestId: 1,
            asset:     address(depositAsset),
            owner:     alice,
            shares:    redeemAmount
        });

        assertRequestOnWm({
            requestId: 1,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount
        });

        assertEq(pool.balanceOf(alice),                      0);
        assertEq(pool.balanceOf(address(withdrawalManager)), wmSharesBalanceBefore + redeemAmount);
    }

    function test_requestRedeem_success_permit_singleRequestByOneLp() external {
        uint256 redeemAmount             = 10e8;
        uint256 aliceSharesBalanceBefore = pool.balanceOf(alice);
        uint256 wmSharesBalanceBefore    = pool.balanceOf(address(withdrawalManager));

        ( uint256 nextRequestId, uint256 lastRequestId ) = withdrawalManager.queue();
        assertEq(nextRequestId, 1);
        assertEq(lastRequestId, 0);

        assertEq(withdrawalManager.totalShares(),                                 0);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    0);
        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);

        assertRequestOnRouter({
            requestId: 0,
            asset:     address(0),
            owner:     address(0),
            shares:    0
        });

        assertRequestOnWm({
            requestId: 0,
            owner:     address(0),
            shares:    0
        });

        vm.startPrank(alice);
        Permit memory permit = signPermit(alicePrivateKey, address(pool), alice, redeemAmount, block.timestamp + 1 days);

        ( uint256 sharesLocked, uint256 requestId ) =
            bitcoinRouter.requestRedeem(address(depositAsset), redeemAmount, EMPTY_METADATA, permit);
        vm.stopPrank();

        assertEq(sharesLocked, redeemAmount);
        assertEq(requestId,    1);

        ( nextRequestId, lastRequestId ) = withdrawalManager.queue();
        assertEq(nextRequestId, 1);
        assertEq(lastRequestId, 1);

        assertEq(withdrawalManager.totalShares(),                                 redeemAmount);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    redeemAmount);
        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);

        assertRequestOnRouter({
            requestId: 1,
            asset:     address(depositAsset),
            owner:     alice,
            shares:    redeemAmount
        });

        assertRequestOnWm({
            requestId: 1,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount
        });

        assertEq(pool.balanceOf(alice),                      aliceSharesBalanceBefore - redeemAmount);
        assertEq(pool.balanceOf(address(withdrawalManager)), wmSharesBalanceBefore + redeemAmount);
    }

    function test_requestRedeem_success_multipleRequestsByOneLp() external {
        uint256 redeemAmount1 = 10e8;
        uint256 redeemAmount2 = 20e8;

        uint256 aliceSharesBalanceBefore = pool.balanceOf(alice);
        uint256 wmSharesBalanceBefore    = pool.balanceOf(address(withdrawalManager));

        ( uint256 nextRequestId, uint256 lastRequestId ) = withdrawalManager.queue();
        assertEq(nextRequestId, 1);
        assertEq(lastRequestId, 0);

        assertEq(withdrawalManager.totalShares(),                                 0);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    0);
        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);

        assertRequestOnRouter({
            requestId: 0,
            asset:     address(0),
            owner:     address(0),
            shares:    0
        });

        assertRequestOnWm({
            requestId: 0,
            owner:     address(0),
            shares:    0
        });

        vm.startPrank(alice);
        pool.approve(address(bitcoinRouter), redeemAmount1);

        ( uint256 sharesLocked, uint256 firstRequestId ) =
            bitcoinRouter.requestRedeem(address(depositAsset), redeemAmount1, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();

        assertEq(sharesLocked,   redeemAmount1);
        assertEq(firstRequestId, lastRequestId + 1);

        ( nextRequestId, lastRequestId ) = withdrawalManager.queue();
        assertEq(nextRequestId, 1);
        assertEq(lastRequestId, firstRequestId);

        assertEq(withdrawalManager.totalShares(),                                 redeemAmount1);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    redeemAmount1);
        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);

        assertRequestOnRouter({
            requestId: firstRequestId,
            asset:     address(depositAsset),
            owner:     alice,
            shares:    redeemAmount1
        });

        assertRequestOnWm({
            requestId: firstRequestId,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount1
        });

        assertEq(pool.balanceOf(alice),                      aliceSharesBalanceBefore - redeemAmount1);
        assertEq(pool.balanceOf(address(withdrawalManager)), wmSharesBalanceBefore + redeemAmount1);

        aliceSharesBalanceBefore = pool.balanceOf(alice);
        wmSharesBalanceBefore    = pool.balanceOf(address(withdrawalManager));

        vm.startPrank(alice);
        pool.approve(address(bitcoinRouter), redeemAmount2);

        ( uint256 secondSharesLocked, uint256 secondRequestId ) =
            bitcoinRouter.requestRedeem(address(depositAsset), redeemAmount2, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();

        assertEq(secondSharesLocked, redeemAmount2);
        assertEq(secondRequestId,    lastRequestId + 1);

        ( nextRequestId, lastRequestId ) = withdrawalManager.queue();
        assertEq(nextRequestId, 1);
        assertEq(lastRequestId, secondRequestId);

        assertEq(withdrawalManager.totalShares(),                                 redeemAmount1 + redeemAmount2);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    redeemAmount1 + redeemAmount2);
        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);

        assertRequestOnRouter({
            requestId: firstRequestId,
            asset:     address(depositAsset),
            owner:     alice,
            shares:    redeemAmount1
        });

        assertRequestOnWm({
            requestId: firstRequestId,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount1
        });

        assertRequestOnRouter({
            requestId: secondRequestId,
            asset:     address(depositAsset),
            owner:     alice,
            shares:    redeemAmount2
        });

        assertRequestOnWm({
            requestId: secondRequestId,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount2
        });

        assertEq(pool.balanceOf(alice),                      aliceSharesBalanceBefore - redeemAmount2);
        assertEq(pool.balanceOf(address(withdrawalManager)), wmSharesBalanceBefore + redeemAmount2);
    }

    function test_requestRedeem_success_multipleRequestsMultipleUsers() external {
        uint256 redeemAmount1 = 10e8;
        uint256 redeemAmount2 = 20e8;
        uint256 redeemAmount3 = 30e8;

        uint256 aliceSharesBalanceBefore = pool.balanceOf(alice);
        uint256 bobSharesBalanceBefore   = pool.balanceOf(bob);
        uint256 wmSharesBalanceBefore    = pool.balanceOf(address(withdrawalManager));

        ( uint256 nextRequestId, uint256 lastRequestId ) = withdrawalManager.queue();
        assertEq(nextRequestId, 1);
        assertEq(lastRequestId, 0);

        assertEq(withdrawalManager.totalShares(),                                 0);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    0);
        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);

        assertRequestOnRouter({
            requestId: 0,
            asset:     address(0),
            owner:     address(0),
            shares:    0
        });

        assertRequestOnWm({
            requestId: 0,
            owner:     address(0),
            shares:    0
        });

        vm.startPrank(alice);
        pool.approve(address(bitcoinRouter), redeemAmount1);

        ( uint256 sharesLocked, uint256 requestId ) =
            bitcoinRouter.requestRedeem(address(depositAsset), redeemAmount1, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();

        assertEq(sharesLocked, redeemAmount1);
        assertEq(requestId,    lastRequestId + 1);

        ( nextRequestId, lastRequestId ) = withdrawalManager.queue();
        assertEq(nextRequestId, 1);
        assertEq(lastRequestId, requestId);

        assertEq(withdrawalManager.totalShares(),                                 redeemAmount1);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    redeemAmount1);
        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);

        assertRequestOnRouter({
            requestId: requestId,
            asset:     address(depositAsset),
            owner:     alice,
            shares:    redeemAmount1
        });

        assertRequestOnWm({
            requestId: requestId,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount1
        });

        assertEq(pool.balanceOf(alice),                      aliceSharesBalanceBefore - redeemAmount1);
        assertEq(pool.balanceOf(address(withdrawalManager)), wmSharesBalanceBefore + redeemAmount1);

        aliceSharesBalanceBefore = pool.balanceOf(alice);
        bobSharesBalanceBefore   = pool.balanceOf(bob);
        wmSharesBalanceBefore    = pool.balanceOf(address(withdrawalManager));

        vm.startPrank(bob);
        pool.approve(address(bitcoinRouter), redeemAmount2);

        ( sharesLocked, requestId ) = bitcoinRouter.requestRedeem(address(depositAsset), redeemAmount2, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();

        assertEq(sharesLocked, redeemAmount2);
        assertEq(requestId,    lastRequestId + 1);

        ( nextRequestId, lastRequestId ) = withdrawalManager.queue();
        assertEq(nextRequestId, 1);
        assertEq(lastRequestId, requestId);

        assertEq(withdrawalManager.totalShares(),                                 redeemAmount1 + redeemAmount2);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    redeemAmount1 + redeemAmount2);
        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);

        assertRequestOnRouter({
            requestId: requestId,
            asset:     address(depositAsset),
            owner:     bob,
            shares:    redeemAmount2
        });

        assertRequestOnWm({
            requestId: requestId,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount2
        });

        assertEq(pool.balanceOf(alice),                      aliceSharesBalanceBefore);
        assertEq(pool.balanceOf(bob),                        bobSharesBalanceBefore - redeemAmount2);
        assertEq(pool.balanceOf(address(withdrawalManager)), wmSharesBalanceBefore + redeemAmount2);

        aliceSharesBalanceBefore = pool.balanceOf(alice);
        bobSharesBalanceBefore   = pool.balanceOf(bob);
        wmSharesBalanceBefore    = pool.balanceOf(address(withdrawalManager));

        vm.startPrank(alice);
        pool.approve(address(bitcoinRouter), redeemAmount3);

        ( sharesLocked, requestId ) = bitcoinRouter.requestRedeem(address(depositAsset), redeemAmount3, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();

        assertEq(sharesLocked, redeemAmount3);
        assertEq(requestId,    lastRequestId + 1);

        ( nextRequestId, lastRequestId ) = withdrawalManager.queue();
        assertEq(nextRequestId, 1);
        assertEq(lastRequestId, requestId);

        assertEq(withdrawalManager.totalShares(),                                 redeemAmount1 + redeemAmount2 + redeemAmount3);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    redeemAmount1 + redeemAmount2 + redeemAmount3);
        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);

        assertRequestOnRouter({
            requestId: requestId,
            asset:     address(depositAsset),
            owner:     alice,
            shares:    redeemAmount3
        });

        assertRequestOnWm({
            requestId: requestId,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount3
        });

        assertEq(pool.balanceOf(alice),                      aliceSharesBalanceBefore - redeemAmount3);
        assertEq(pool.balanceOf(bob),                        bobSharesBalanceBefore);
        assertEq(pool.balanceOf(address(withdrawalManager)), wmSharesBalanceBefore + redeemAmount3);

        ( uint256[] memory requestIds, uint256[] memory shares ) = withdrawalManager.requestsByOwner(address(bitcoinRouter));

        assertEq(requestIds.length, 3);
        assertEq(shares.length, 3);

        assertEq(requestIds[0], 1);
        assertEq(requestIds[1], 2);
        assertEq(requestIds[2], 3);

        assertEq(shares[0], redeemAmount1);
        assertEq(shares[1], redeemAmount2);
        assertEq(shares[2], redeemAmount3);
    }

}
