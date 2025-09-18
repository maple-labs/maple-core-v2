// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC20 } from "../../../../contracts/interfaces/Interfaces.sol";

import { SyrupBitcoinTestBase } from "../SyrupBitcoinTestBase.sol";

contract SyrupBitcoinRouterRemoveSharesByIdTests is SyrupBitcoinTestBase {

    address depositor = makeAddr("depositor");

    uint256 requestId1;
    uint256 requestId2;
    uint256 redeemAmount1;
    uint256 redeemAmount2;
    uint256 totalRedeemRequested;

    function setUp() public virtual override {
        super.setUp();

        uint256 depositAmount = 1_000e8;

        depositAsset.mint(depositor, depositAmount);

        assertEq(depositAsset.balanceOf(depositor), depositAmount);

        vm.startPrank(depositor);

        depositAsset.approve(address(bitcoinRouter), depositAmount);
        bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, emptyPermit());

        redeemAmount1 = 500e8;
        redeemAmount2 = 300e8;

        pool.approve(address(bitcoinRouter), redeemAmount1 + redeemAmount2);

        (
            uint256 sharesLocked,
            uint256 requestId
        ) = bitcoinRouter.requestRedeem(address(depositAsset), redeemAmount1, EMPTY_METADATA, emptyPermit());

        requestId1 = requestId;

        assertEq(requestId,    1);
        assertEq(sharesLocked, redeemAmount1);

        (
            sharesLocked,
            requestId
        ) = bitcoinRouter.requestRedeem(address(depositAsset), redeemAmount2, EMPTY_METADATA, emptyPermit());

        requestId2 = requestId;

        assertEq(requestId,    2);
        assertEq(sharesLocked, redeemAmount2);

        totalRedeemRequested = redeemAmount1 + redeemAmount2;

        vm.stopPrank();

        assertEq(pool.balanceOf(address(withdrawalManager)),       totalRedeemRequested);
        assertEq(pool.balanceOf(depositor),                        depositAmount - totalRedeemRequested);
        assertEq(pool.totalAssets(),                               depositAmount);
        assertEq(IERC20(pool.asset()).balanceOf(address(pool)),    depositAmount);
        assertEq(depositAsset.balanceOf(address(assetController)), depositAmount);

        assertTrue(withdrawalManager.isManualWithdrawal(address(bitcoinRouter)));
    }

    function test_removeSharesById_revert_paused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("SBR:PAUSED");
        bitcoinRouter.removeSharesById(1, 500e8);
    }

    function test_removeSharesById_revert_invalidRequestId() external {
        vm.expectRevert("SBR:RSBI:INVALID_REQUESTID");
        bitcoinRouter.removeSharesById(1234, 500e8);
    }

    function test_removeSharesById_revert_invalidRequest_alreadyRemoved() external {
        vm.prank(depositor);
        bitcoinRouter.removeSharesById(requestId1, redeemAmount1);

        vm.prank(depositor);
        vm.expectRevert("SBR:RSBI:INVALID_REQUESTID");
        bitcoinRouter.removeSharesById(requestId1, 1);
    }

    function test_removeSharesById_revert_notAuthorized() external {
        address caller = makeAddr("caller");
        vm.prank(caller);
        vm.expectRevert("SBR:RSBI:NOT_AUTHORIZED");
        bitcoinRouter.removeSharesById(1, 500e8);
    }

    function test_removeSharesById_revert_invalidRequest_fullyProcessed() external {
        vm.prank(governor);
        withdrawalManager.processRedemptions(redeemAmount1);

        vm.prank(depositor);
        vm.expectRevert("WM:RSBI:INVALID_REQUEST");
        bitcoinRouter.removeSharesById(requestId1, 0);
    }

    function test_removeSharesById_revert_noChange_requestNotProcessed() external {
        vm.prank(depositor);
        vm.expectRevert("WM:RSBI:NO_CHANGE");
        bitcoinRouter.removeSharesById(requestId1, 0);
    }

    function test_removeSharesById_revert_noChange_wmRequestPartiallyProcessed() external {
        uint256 sharesToProcess = 100e8;

        vm.prank(governor);
        withdrawalManager.processRedemptions(sharesToProcess);

        vm.prank(depositor);
        vm.expectRevert("WM:RSBI:NO_CHANGE");
        bitcoinRouter.removeSharesById(requestId1, 0);
    }

    function test_removeSharesById_revert_wmInsufficientShares() external {
        vm.prank(depositor);
        vm.expectRevert("WM:RSBI:INSUFFICIENT_SHARES");
        bitcoinRouter.removeSharesById(requestId1, redeemAmount1 + 1);
    }

    function test_removeSharesById_revert_wmTransferFail() external {
        uint256 sharesToRemove = 20e8;

        vm.prank(address(withdrawalManager));
        pool.transfer(makeAddr("randomUser"), redeemAmount1 + redeemAmount2 - sharesToRemove + 1);

        vm.prank(depositor);
        vm.expectRevert("WM:RS:TRANSFER_FAIL");
        bitcoinRouter.removeSharesById(requestId1, sharesToRemove);
    }

    function test_removeSharesById_success_completeRemoval_wmRequestNotProcessed() external {
        uint256[] memory expectedRequestIds = new uint256[](2);
        expectedRequestIds[0]               = requestId1;
        expectedRequestIds[1]               = requestId2;

        uint256 depositorSharesBalanceBefore        = pool.balanceOf(depositor);
        uint256 wmSharesBalanceBefore               = pool.balanceOf(address(withdrawalManager));
        uint256 poolTotalAssetsBefore               = pool.totalAssets();
        uint256 poolDepositAssetBalanceBefore       = IERC20(pool.asset()).balanceOf(address(pool));
        uint256 controllerDepositAssetBalanceBefore = depositAsset.balanceOf(address(assetController));

        assertRequestOnRouter({
            requestId: requestId1,
            asset:     address(depositAsset),
            owner:     depositor,
            shares:    redeemAmount1
        });

        assertRequestOnRouter({
            requestId: requestId2,
            asset:     address(depositAsset),
            owner:     depositor,
            shares:    redeemAmount2
        });

        assertRequestOnWm({
            requestId: requestId1,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount1
        });

        assertRequestOnWm({
            requestId: requestId2,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount2
        });

        assertUsersRequestsOnWm(address(bitcoinRouter), expectedRequestIds);

        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    totalRedeemRequested);
        assertEq(withdrawalManager.totalShares(),                                 totalRedeemRequested);

        assertQueue({
            poolManager: address(poolManager),
            nextRequestId: requestId1,
            lastRequestId: requestId2
        });

        uint256 sharesToRemove = redeemAmount1;

        vm.prank(depositor);
        uint256 sharesReturned = bitcoinRouter.removeSharesById(requestId1, sharesToRemove);

        assertEq(sharesReturned, sharesToRemove);

        assertRequestOnRouter({
            requestId: requestId1,
            asset:     address(0),
            owner:     address(0),
            shares:    0
        });

        assertRequestOnRouter({
            requestId: requestId2,
            asset:     address(depositAsset),
            owner:     depositor,
            shares:    redeemAmount2
        });

        assertRequestOnWm({
            requestId: requestId1,
            owner:     address(0),
            shares:    0
        });

        assertRequestOnWm({
            requestId: requestId2,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount2
        });

        expectedRequestIds    = new uint256[](1);
        expectedRequestIds[0] = requestId2;

        assertUsersRequestsOnWm(address(bitcoinRouter), expectedRequestIds);

        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    totalRedeemRequested - sharesToRemove);
        assertEq(withdrawalManager.totalShares(),                                 totalRedeemRequested - sharesToRemove);

        assertEq(pool.balanceOf(depositor),                        depositorSharesBalanceBefore + sharesToRemove);
        assertEq(pool.balanceOf(address(withdrawalManager)),       wmSharesBalanceBefore - sharesToRemove);
        assertEq(pool.totalAssets(),                               poolTotalAssetsBefore);
        assertEq(IERC20(pool.asset()).balanceOf(address(pool)),    poolDepositAssetBalanceBefore);
        assertEq(depositAsset.balanceOf(address(assetController)), controllerDepositAssetBalanceBefore);

        assertQueue({
            poolManager: address(poolManager),
            nextRequestId: requestId1,
            lastRequestId: requestId2
        });
    }

    function test_removeSharesById_success_completeRemoval_wmRequestPartiallyProcessed() external {
        uint256[] memory expectedRequestIds = new uint256[](2);
        expectedRequestIds[0]               = requestId1;
        expectedRequestIds[1]               = requestId2;

        uint256 depositorSharesBalanceBefore        = pool.balanceOf(depositor);
        uint256 wmSharesBalanceBefore               = pool.balanceOf(address(withdrawalManager));
        uint256 poolTotalAssetsBefore               = pool.totalAssets();
        uint256 poolDepositAssetBalanceBefore       = IERC20(pool.asset()).balanceOf(address(pool));
        uint256 controllerDepositAssetBalanceBefore = depositAsset.balanceOf(address(assetController));

        assertRequestOnRouter({
            requestId: requestId1,
            asset:     address(depositAsset),
            owner:     depositor,
            shares:    redeemAmount1
        });

        assertRequestOnRouter({
            requestId: requestId2,
            asset:     address(depositAsset),
            owner:     depositor,
            shares:    redeemAmount2
        });

        assertRequestOnWm({
            requestId: requestId1,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount1
        });

        assertRequestOnWm({
            requestId: requestId2,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount2
        });

        assertUsersRequestsOnWm(address(bitcoinRouter), expectedRequestIds);

        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    totalRedeemRequested);
        assertEq(withdrawalManager.totalShares(),                                 totalRedeemRequested);

        assertQueue({
            poolManager: address(poolManager),
            nextRequestId: requestId1,
            lastRequestId: requestId2
        });

        uint256 sharesToProcess = 100e8;
        uint256 sharesToRemove  = redeemAmount1 - sharesToProcess;

        vm.prank(governor);
        withdrawalManager.processRedemptions(sharesToProcess);

        assertRequestOnRouter({
            requestId: requestId1,
            asset:     address(depositAsset),
            owner:     depositor,
            shares:    redeemAmount1
        });

        assertRequestOnRouter({
            requestId: requestId2,
            asset:     address(depositAsset),
            owner:     depositor,
            shares:    redeemAmount2
        });

        assertRequestOnWm({
            requestId: requestId1,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount1 - sharesToProcess
        });

        assertRequestOnWm({
            requestId: requestId2,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount2
        });

        assertUsersRequestsOnWm(address(bitcoinRouter), expectedRequestIds);

        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), sharesToProcess);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    totalRedeemRequested - sharesToProcess);
        assertEq(withdrawalManager.totalShares(),                                 totalRedeemRequested);

        assertEq(pool.balanceOf(depositor),                        depositorSharesBalanceBefore);
        assertEq(pool.balanceOf(address(withdrawalManager)),       wmSharesBalanceBefore);
        assertEq(pool.totalAssets(),                               poolTotalAssetsBefore);
        assertEq(IERC20(pool.asset()).balanceOf(address(pool)),    poolDepositAssetBalanceBefore);
        assertEq(depositAsset.balanceOf(address(assetController)), controllerDepositAssetBalanceBefore);

        assertQueue({
            poolManager: address(poolManager),
            nextRequestId: requestId1,
            lastRequestId: requestId2
        });

        vm.prank(depositor);
        uint256 sharesReturned = bitcoinRouter.removeSharesById(requestId1, sharesToRemove);

        assertEq(sharesReturned, sharesToRemove);

        assertRequestOnRouter({
            requestId: requestId1,
            asset:     address(depositAsset),
            owner:     depositor,
            shares:    sharesToProcess
        });

        assertRequestOnRouter({
            requestId: requestId2,
            asset:     address(depositAsset),
            owner:     depositor,
            shares:    redeemAmount2
        });

        assertRequestOnWm({
            requestId: requestId1,
            owner:     address(0),
            shares:    0
        });

        assertRequestOnWm({
            requestId: requestId2,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount2
        });

        expectedRequestIds    = new uint256[](1);
        expectedRequestIds[0] = requestId2;

        assertUsersRequestsOnWm(address(bitcoinRouter), expectedRequestIds);

        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), sharesToProcess);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    totalRedeemRequested - sharesToRemove - sharesToProcess);
        assertEq(withdrawalManager.totalShares(),                                 totalRedeemRequested - sharesToRemove);

        assertEq(pool.balanceOf(depositor),                        depositorSharesBalanceBefore + sharesToRemove);
        assertEq(pool.balanceOf(address(withdrawalManager)),       wmSharesBalanceBefore - sharesToRemove);
        assertEq(pool.totalAssets(),                               poolTotalAssetsBefore);
        assertEq(IERC20(pool.asset()).balanceOf(address(pool)),    poolDepositAssetBalanceBefore);
        assertEq(depositAsset.balanceOf(address(assetController)), controllerDepositAssetBalanceBefore);

        assertQueue({
            poolManager: address(poolManager),
            nextRequestId: requestId1,
            lastRequestId: requestId2
        });
    }

    function test_removeSharesById_success_decreaseShares_wmRequestNotProcessed() external {
        uint256[] memory expectedRequestIds = new uint256[](2);
        expectedRequestIds[0]               = requestId1;
        expectedRequestIds[1]               = requestId2;

        uint256 depositorSharesBalanceBefore        = pool.balanceOf(depositor);
        uint256 wmSharesBalanceBefore               = pool.balanceOf(address(withdrawalManager));
        uint256 poolTotalAssetsBefore               = pool.totalAssets();
        uint256 poolDepositAssetBalanceBefore       = IERC20(pool.asset()).balanceOf(address(pool));
        uint256 controllerDepositAssetBalanceBefore = depositAsset.balanceOf(address(assetController));

        assertRequestOnRouter({
            requestId: requestId1,
            asset:     address(depositAsset),
            owner:     depositor,
            shares:    redeemAmount1
        });

        assertRequestOnRouter({
            requestId: requestId2,
            asset:     address(depositAsset),
            owner:     depositor,
            shares:    redeemAmount2
        });

        assertRequestOnWm({
            requestId: requestId1,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount1
        });

        assertRequestOnWm({
            requestId: requestId2,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount2
        });

        assertUsersRequestsOnWm(address(bitcoinRouter), expectedRequestIds);

        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    totalRedeemRequested);
        assertEq(withdrawalManager.totalShares(),                                 totalRedeemRequested);

        assertQueue({
            poolManager: address(poolManager),
            nextRequestId: requestId1,
            lastRequestId: requestId2
        });

        uint256 sharesToRemove = 100e8;

        vm.prank(depositor);
        uint256 sharesReturned = bitcoinRouter.removeSharesById(requestId1, sharesToRemove);

        assertEq(sharesReturned, sharesToRemove);

        assertRequestOnRouter({
            requestId: requestId1,
            asset:     address(depositAsset),
            owner:     depositor,
            shares:    redeemAmount1 - sharesToRemove
        });

        assertRequestOnRouter({
            requestId: requestId2,
            asset:     address(depositAsset),
            owner:     depositor,
            shares:    redeemAmount2
        });

        assertRequestOnWm({
            requestId: requestId1,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount1 - sharesToRemove
        });

        assertRequestOnWm({
            requestId: requestId2,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount2
        });

        assertUsersRequestsOnWm(address(bitcoinRouter), expectedRequestIds);

        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    totalRedeemRequested - sharesToRemove);
        assertEq(withdrawalManager.totalShares(),                                 totalRedeemRequested - sharesToRemove);

        assertEq(pool.balanceOf(depositor),                        depositorSharesBalanceBefore + sharesToRemove);
        assertEq(pool.balanceOf(address(withdrawalManager)),       wmSharesBalanceBefore - sharesToRemove);
        assertEq(pool.totalAssets(),                               poolTotalAssetsBefore);
        assertEq(IERC20(pool.asset()).balanceOf(address(pool)),    poolDepositAssetBalanceBefore);
        assertEq(depositAsset.balanceOf(address(assetController)), controllerDepositAssetBalanceBefore);

        assertQueue({
            poolManager: address(poolManager),
            nextRequestId: requestId1,
            lastRequestId: requestId2
        });
    }

    function test_removeSharesById_success_decreaseShares_wmRequestPartiallyProcessed() external {
        uint256[] memory expectedRequestIds = new uint256[](2);
        expectedRequestIds[0]               = requestId1;
        expectedRequestIds[1]               = requestId2;

        uint256 depositorSharesBalanceBefore        = pool.balanceOf(depositor);
        uint256 wmSharesBalanceBefore               = pool.balanceOf(address(withdrawalManager));
        uint256 poolTotalAssetsBefore               = pool.totalAssets();
        uint256 poolDepositAssetBalanceBefore       = IERC20(pool.asset()).balanceOf(address(pool));
        uint256 controllerDepositAssetBalanceBefore = depositAsset.balanceOf(address(assetController));

        assertRequestOnRouter({
            requestId: requestId1,
            asset:     address(depositAsset),
            owner:     depositor,
            shares:    redeemAmount1
        });

        assertRequestOnRouter({
            requestId: requestId2,
            asset:     address(depositAsset),
            owner:     depositor,
            shares:    redeemAmount2
        });

        assertRequestOnWm({
            requestId: requestId1,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount1
        });

        assertRequestOnWm({
            requestId: requestId2,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount2
        });

        assertUsersRequestsOnWm(address(bitcoinRouter), expectedRequestIds);

        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    totalRedeemRequested);
        assertEq(withdrawalManager.totalShares(),                                 totalRedeemRequested);

        assertQueue({
            poolManager: address(poolManager),
            nextRequestId: requestId1,
            lastRequestId: requestId2
        });

        uint256 sharesToProcess = 100e8;
        uint256 sharesToRemove  = 200e8;

        vm.prank(governor);
        withdrawalManager.processRedemptions(sharesToProcess);

        assertRequestOnRouter({
            requestId: requestId1,
            asset:     address(depositAsset),
            owner:     depositor,
            shares:    redeemAmount1
        });

        assertRequestOnRouter({
            requestId: requestId2,
            asset:     address(depositAsset),
            owner:     depositor,
            shares:    redeemAmount2
        });

        assertRequestOnWm({
            requestId: requestId1,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount1 - sharesToProcess
        });

        assertRequestOnWm({
            requestId: requestId2,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount2
        });

        assertUsersRequestsOnWm(address(bitcoinRouter), expectedRequestIds);

        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), sharesToProcess);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    totalRedeemRequested - sharesToProcess);
        assertEq(withdrawalManager.totalShares(),                                 totalRedeemRequested);

        assertEq(pool.balanceOf(depositor),                        depositorSharesBalanceBefore);
        assertEq(pool.balanceOf(address(withdrawalManager)),       wmSharesBalanceBefore);
        assertEq(pool.totalAssets(),                               poolTotalAssetsBefore);
        assertEq(IERC20(pool.asset()).balanceOf(address(pool)),    poolDepositAssetBalanceBefore);
        assertEq(depositAsset.balanceOf(address(assetController)), controllerDepositAssetBalanceBefore);

        assertQueue({
            poolManager: address(poolManager),
            nextRequestId: requestId1,
            lastRequestId: requestId2
        });

        vm.prank(depositor);
        uint256 sharesReturned = bitcoinRouter.removeSharesById(requestId1, sharesToRemove);

        assertEq(sharesReturned, sharesToRemove);

        assertRequestOnRouter({
            requestId: requestId1,
            asset:     address(depositAsset),
            owner:     depositor,
            shares:    redeemAmount1 - sharesToRemove
        });

        assertRequestOnRouter({
            requestId: requestId2,
            asset:     address(depositAsset),
            owner:     depositor,
            shares:    redeemAmount2
        });

        assertRequestOnWm({
            requestId: requestId1,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount1 - sharesToRemove - sharesToProcess
        });

        assertRequestOnWm({
            requestId: requestId2,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount2
        });

        assertUsersRequestsOnWm(address(bitcoinRouter), expectedRequestIds);

        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), sharesToProcess);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    totalRedeemRequested - sharesToRemove - sharesToProcess);
        assertEq(withdrawalManager.totalShares(),                                 totalRedeemRequested - sharesToRemove);

        assertEq(pool.balanceOf(depositor),                        depositorSharesBalanceBefore + sharesToRemove);
        assertEq(pool.balanceOf(address(withdrawalManager)),       wmSharesBalanceBefore - sharesToRemove);
        assertEq(pool.totalAssets(),                               poolTotalAssetsBefore);
        assertEq(IERC20(pool.asset()).balanceOf(address(pool)),    poolDepositAssetBalanceBefore);
        assertEq(depositAsset.balanceOf(address(assetController)), controllerDepositAssetBalanceBefore);

        assertQueue({
            poolManager: address(poolManager),
            nextRequestId: requestId1,
            lastRequestId: requestId2
        });
    }

    function test_removeSharesById_success_multipleLPs_multipleRequests_removeRequestsOutOfOrder() external {
        uint256 requestId3;
        uint256 redeemAmount3;

        address depositor1 = depositor;
        address depositor2 = makeAddr("depositor2");

        {
            uint256 depositAmount = 1_000e8;
            depositAsset.mint(depositor2, depositAmount);

            vm.startPrank(depositor2);

            depositAsset.approve(address(bitcoinRouter), depositAmount);
            bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, emptyPermit());

            redeemAmount3 = 100e8;

            pool.approve(address(bitcoinRouter), redeemAmount3);
            ( , requestId3 ) = bitcoinRouter.requestRedeem(address(depositAsset), redeemAmount3, EMPTY_METADATA, emptyPermit());

            totalRedeemRequested += redeemAmount3;

            vm.stopPrank();
        }

        uint256[] memory expectedRequestIds = new uint256[](3);
        expectedRequestIds[0]               = requestId1;
        expectedRequestIds[1]               = requestId2;
        expectedRequestIds[2]               = requestId3;

        uint256 depositor1SharesBalanceBefore       = pool.balanceOf(depositor1);
        uint256 depositor2SharesBalanceBefore       = pool.balanceOf(depositor2);
        uint256 wmSharesBalanceBefore               = pool.balanceOf(address(withdrawalManager));
        uint256 poolTotalAssetsBefore               = pool.totalAssets();
        uint256 controllerDepositAssetBalanceBefore = depositAsset.balanceOf(address(assetController));

        assertRequestOnRouter({
            requestId: requestId1,
            asset:     address(depositAsset),
            owner:     depositor1,
            shares:    redeemAmount1
        });

        assertRequestOnRouter({
            requestId: requestId2,
            asset:     address(depositAsset),
            owner:     depositor1,
            shares:    redeemAmount2
        });

        assertRequestOnRouter({
            requestId: requestId3,
            asset:     address(depositAsset),
            owner:     depositor2,
            shares:    redeemAmount3
        });

        assertRequestOnWm({
            requestId: requestId1,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount1
        });

        assertRequestOnWm({
            requestId: requestId2,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount2
        });

        assertRequestOnWm({
            requestId: requestId3,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount3
        });

        assertUsersRequestsOnWm(address(bitcoinRouter), expectedRequestIds);

        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    totalRedeemRequested);
        assertEq(withdrawalManager.totalShares(),                                 totalRedeemRequested);

        assertQueue({
            poolManager: address(poolManager),
            nextRequestId: requestId1,
            lastRequestId: requestId3
        });

        uint256 sharesToRemoveRequest3 = 50e8;

        vm.prank(depositor2);
        uint256 sharesReturned = bitcoinRouter.removeSharesById(requestId3, sharesToRemoveRequest3);

        assertEq(sharesReturned, sharesToRemoveRequest3);

        assertRequestOnRouter({
            requestId: requestId1,
            asset:     address(depositAsset),
            owner:     depositor1,
            shares:    redeemAmount1
        });

        assertRequestOnRouter({
            requestId: requestId2,
            asset:     address(depositAsset),
            owner:     depositor1,
            shares:    redeemAmount2
        });

        assertRequestOnRouter({
            requestId: requestId3,
            asset:     address(depositAsset),
            owner:     depositor2,
            shares:    redeemAmount3 - sharesToRemoveRequest3
        });

        assertRequestOnWm({
            requestId: requestId1,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount1
        });

        assertRequestOnWm({
            requestId: requestId2,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount2
        });

        assertRequestOnWm({
            requestId: requestId3,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount3 - sharesToRemoveRequest3
        });

        assertUsersRequestsOnWm(address(bitcoinRouter), expectedRequestIds);

        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);
        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)),    totalRedeemRequested - sharesToRemoveRequest3);
        assertEq(withdrawalManager.totalShares(),                                 totalRedeemRequested - sharesToRemoveRequest3);

        assertEq(pool.balanceOf(depositor1),                       depositor1SharesBalanceBefore);
        assertEq(pool.balanceOf(depositor2),                       depositor2SharesBalanceBefore + sharesToRemoveRequest3);
        assertEq(pool.balanceOf(address(withdrawalManager)),       wmSharesBalanceBefore - sharesToRemoveRequest3);
        assertEq(pool.totalAssets(),                               poolTotalAssetsBefore);
        assertEq(depositAsset.balanceOf(address(assetController)), controllerDepositAssetBalanceBefore);

        assertQueue({
            poolManager: address(poolManager),
            nextRequestId: requestId1,
            lastRequestId: requestId3
        });

        uint256 sharesToRemoveRequest2 = 10e8;

        vm.prank(depositor1);
        sharesReturned = bitcoinRouter.removeSharesById(requestId2, sharesToRemoveRequest2);

        assertEq(sharesReturned, sharesToRemoveRequest2);

        uint256 requestId3_    = requestId3;
        uint256 redeemAmount3_ = redeemAmount3;

        assertRequestOnRouter({
            requestId: requestId1,
            asset:     address(depositAsset),
            owner:     depositor1,
            shares:    redeemAmount1
        });

        assertRequestOnRouter({
            requestId: requestId2,
            asset:     address(depositAsset),
            owner:     depositor1,
            shares:    redeemAmount2 - sharesToRemoveRequest2
        });

        assertRequestOnRouter({
            requestId: requestId3_,
            asset:     address(depositAsset),
            owner:     depositor2,
            shares:    redeemAmount3_ - sharesToRemoveRequest3
        });

        assertRequestOnWm({
            requestId: requestId1,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount1
        });

        assertRequestOnWm({
            requestId: requestId2,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount2 - sharesToRemoveRequest2
        });

        assertRequestOnWm({
            requestId: requestId3_,
            owner:     address(bitcoinRouter),
            shares:    redeemAmount3_ - sharesToRemoveRequest3
        });

        assertUsersRequestsOnWm(address(bitcoinRouter), expectedRequestIds);

        assertEq(withdrawalManager.manualSharesAvailable(address(bitcoinRouter)), 0);

        assertEq(
            withdrawalManager.userEscrowedShares(address(bitcoinRouter)),
            totalRedeemRequested - sharesToRemoveRequest2 - sharesToRemoveRequest3
        );

        assertEq(
            withdrawalManager.totalShares(),
            totalRedeemRequested - sharesToRemoveRequest2 - sharesToRemoveRequest3
        );

        assertEq(
            pool.balanceOf(address(withdrawalManager)),
            wmSharesBalanceBefore - sharesToRemoveRequest2 - sharesToRemoveRequest3
        );

        assertEq(pool.balanceOf(depositor1),                       depositor1SharesBalanceBefore + sharesToRemoveRequest2);
        assertEq(pool.balanceOf(depositor2),                       depositor2SharesBalanceBefore + sharesToRemoveRequest3);
        assertEq(pool.totalAssets(),                               poolTotalAssetsBefore);
        assertEq(depositAsset.balanceOf(address(assetController)), controllerDepositAssetBalanceBefore);

        assertQueue({
            poolManager: address(poolManager),
            nextRequestId: requestId1,
            lastRequestId: requestId3_
        });
    }

}
