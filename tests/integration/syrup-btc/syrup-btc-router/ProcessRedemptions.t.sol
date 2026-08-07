// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAssetController,
    IERC20Like
} from "../../../../contracts/interfaces/Interfaces.sol";

import { SyrupBitcoinTestBase } from "../SyrupBitcoinTestBase.sol";

contract SyrupBitcoinRouterProcessRedemptionsTests is SyrupBitcoinTestBase {

    uint256[] requestIds;

    address depositorA;
    address depositorB;

    uint256 depositAmountA;
    uint256 depositAmountB;

    function setUp() public virtual override {
        super.setUp();

        vm.label(address(bitcoinRouter),     "Bitcoin Router");
        vm.label(address(assetController),   "Asset Controller");
        vm.label(address(withdrawalManager), "Withdrawal Manager");

        depositAmountA = 20e8;
        depositAmountB = 40e8;
        depositorA     = makeAddr("depositorA");
        depositorB     = makeAddr("depositorB");

        depositAsset.mint(depositorA, depositAmountA);
        depositAsset.mint(depositorB, depositAmountB);

        vm.startPrank(depositorA);
        depositAsset.approve(address(bitcoinRouter), depositAmountA);
        bitcoinRouter.deposit(address(depositAsset), depositAmountA, EMPTY_METADATA, emptyPermit());

        pool.approve(address(bitcoinRouter), depositAmountA);
        ( , uint256 requestId1 ) = bitcoinRouter.requestRedeem(address(depositAsset), depositAmountA, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();

        vm.startPrank(depositorB);
        depositAsset.approve(address(bitcoinRouter), depositAmountB);
        bitcoinRouter.deposit(address(depositAsset), depositAmountB, EMPTY_METADATA, emptyPermit());

        pool.approve(address(bitcoinRouter), depositAmountB);
        ( , uint256 requestId2 ) = bitcoinRouter.requestRedeem(address(depositAsset), depositAmountB, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();

        requestIds.push(requestId1);
        requestIds.push(requestId2);

        assertEq(depositAsset.balanceOf(depositorA), 0);
        assertEq(depositAsset.balanceOf(depositorB), 0);

        assertEq(pool.balanceOf(depositorA),             0);
        assertEq(pool.balanceOf(depositorB),             0);
        assertEq(pool.balanceOf(address(bitcoinRouter)), 0);

        assertEq(withdrawalManager.requestIds(address(bitcoinRouter)), requestIds[1]);

        ( address wmRequest1Owner, uint256 wmRequest1RemainingShares ) = withdrawalManager.requests(requestIds[0]);

        assertEq(wmRequest1Owner,           address(bitcoinRouter));
        assertEq(wmRequest1RemainingShares, depositAmountA);

        ( address wmRequest2Owner, uint256 wmRequest2RemainingShares ) = withdrawalManager.requests(requestIds[1]);

        assertEq(wmRequest2Owner,           address(bitcoinRouter));
        assertEq(wmRequest2RemainingShares, depositAmountB);

        ( address routerReq1Asset, address routerReq1User, uint256 routerReq1Shares ) = bitcoinRouter.redeemRequests(requestIds[0]);

        assertEq(routerReq1Asset,  address(depositAsset));
        assertEq(routerReq1User,   depositorA);
        assertEq(routerReq1Shares, depositAmountA);

        ( address routerReq2Asset, address routerReq2User, uint256 routerReq2Shares ) = bitcoinRouter.redeemRequests(requestIds[1]);

        assertEq(routerReq2Asset,  address(depositAsset));
        assertEq(routerReq2User,   depositorB);
        assertEq(routerReq2Shares, depositAmountB);

        assertEq(withdrawalManager.isManualWithdrawal(address(bitcoinRouter)), true);

        assertEq(withdrawalManager.userEscrowedShares(address(bitcoinRouter)), depositAmountA + depositAmountB);
    }

    function test_syrupBitcoinRouter_processRedemptions_revert_paused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("SBR:PAUSED");
        bitcoinRouter.processRedemptions(requestIds);
    }

    function test_syrupBitcoinRouter_processRedemptions_revert_onlyRedeemer() external {
        vm.expectRevert("SBR:NOT_REDEEMER");
        bitcoinRouter.processRedemptions(requestIds);
    }

    function test_syrupBitcoinRouter_processRedemptions_revert_emptyRequestIds() external {
        vm.prank(redeemer);
        vm.expectRevert("SBR:PR:EMPTY_REQUESTS_ARRAY");
        bitcoinRouter.processRedemptions(new uint256[](0));
    }

    function test_syrupBitcoinRouter_processRedemptions_success_skipCancelledRequestId() external {
        uint256[] memory toCancel = new uint256[](1);
        toCancel[0]               = requestIds[1];

        vm.prank(depositorB);
        bitcoinRouter.removeSharesById(requestIds[1], depositAmountB);

        ( address routerReq2AssetBefore, address routerReq2OwnerBefore, uint256 routerReq2SharesBefore ) =
            bitcoinRouter.redeemRequests(requestIds[1]);

        assertEq(routerReq2AssetBefore,  address(0));
        assertEq(routerReq2OwnerBefore,  address(0));
        assertEq(routerReq2SharesBefore, 0);

        vm.prank(redeemer);
        bitcoinRouter.processRedemptions(toCancel);

        ( address routerReq1AssetAfter, address routerReq1OwnerAfter, uint256 routerReq1SharesAfter ) =
            bitcoinRouter.redeemRequests(requestIds[0]);
        ( address routerReq2AssetAfter, address routerReq2OwnerAfter, uint256 routerReq2SharesAfter ) =
            bitcoinRouter.redeemRequests(requestIds[1]);

        assertEq(routerReq1AssetAfter,  address(depositAsset));
        assertEq(routerReq1OwnerAfter,  depositorA);
        assertEq(routerReq1SharesAfter, depositAmountA);

        assertEq(routerReq2AssetAfter,  address(0));
        assertEq(routerReq2OwnerAfter,  address(0));
        assertEq(routerReq2SharesAfter, 0);

        assertEq(depositAsset.balanceOf(address(treasury)), 0);
        assertEq(depositAsset.balanceOf(depositorA),        0);
        assertEq(depositAsset.balanceOf(depositorB),        0);
    }

    function test_syrupBitcoinRouter_processRedemptions_success_skipCancelledThenProcessValid() external {
        uint256[] memory toCancel = new uint256[](1);
        toCancel[0]               = requestIds[1];

        vm.prank(depositorB);
        bitcoinRouter.removeSharesById(requestIds[1], depositAmountB);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(depositAmountA);

        uint256[] memory ids = new uint256[](2);
        ids[0]               = requestIds[1];  // Cancelled
        ids[1]               = requestIds[0];  // Valid

        ( address req2AssetBefore, address req2OwnerBefore, uint256 req2SharesBefore ) = bitcoinRouter.redeemRequests(requestIds[1]);

        assertEq(req2AssetBefore,  address(0));
        assertEq(req2OwnerBefore,  address(0));
        assertEq(req2SharesBefore, 0);

        vm.prank(poolDelegate);
        bitcoinRouter.processRedemptions(ids);

        assertEq(depositAsset.balanceOf(depositorA),        depositAmountA);
        assertEq(depositAsset.balanceOf(depositorB),        0);
        assertEq(depositAsset.balanceOf(address(treasury)), 0);

        ( address req1AssetAfter, address req1OwnerAfter, uint256 req1SharesAfter ) = bitcoinRouter.redeemRequests(requestIds[0]);
        ( address req2AssetAfter, address req2OwnerAfter, uint256 req2SharesAfter ) = bitcoinRouter.redeemRequests(requestIds[1]);

        assertEq(req1AssetAfter,  address(0));
        assertEq(req1OwnerAfter,  address(0));
        assertEq(req1SharesAfter, 0);

        assertEq(req2AssetAfter,  address(0));
        assertEq(req2OwnerAfter,  address(0));
        assertEq(req2SharesAfter, 0);
    }

    function test_syrupBitcoinRouter_processRedemptions_success_skipAlreadyProcessedRequests() external {
        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(depositAmountA + depositAmountB);

        vm.prank(poolDelegate);
        bitcoinRouter.processRedemptions(requestIds);

        ( , , uint256 r1SharesAfterFirst ) = bitcoinRouter.redeemRequests(requestIds[0]);
        ( , , uint256 r2SharesAfterFirst ) = bitcoinRouter.redeemRequests(requestIds[1]);

        assertEq(r1SharesAfterFirst,                 0);
        assertEq(r2SharesAfterFirst,                 0);
        assertEq(depositAsset.balanceOf(depositorA), depositAmountA);
        assertEq(depositAsset.balanceOf(depositorB), depositAmountB);

        vm.prank(poolDelegate);
        bitcoinRouter.processRedemptions(requestIds);

        ( , , uint256 r1SharesAfterSecond ) = bitcoinRouter.redeemRequests(requestIds[0]);
        ( , , uint256 r2SharesAfterSecond ) = bitcoinRouter.redeemRequests(requestIds[1]);

        assertEq(r1SharesAfterSecond,                       0);
        assertEq(r2SharesAfterSecond,                       0);
        assertEq(depositAsset.balanceOf(depositorA),        depositAmountA);
        assertEq(depositAsset.balanceOf(depositorB),        depositAmountB);
        assertEq(depositAsset.balanceOf(address(treasury)), 0);
    }

    function test_syrupBitcoinRouter_processRedemptions_success_skipFutureRequestIds() external {
        uint256 futureRequestId = requestIds[1] + 100;

        uint256[] memory ids = new uint256[](1);
        ids[0]               = futureRequestId;

        vm.prank(poolDelegate);
        bitcoinRouter.processRedemptions(ids);

        ( , address owner1, uint256 shares1 ) = bitcoinRouter.redeemRequests(requestIds[0]);
        ( , address owner2, uint256 shares2 ) = bitcoinRouter.redeemRequests(requestIds[1]);

        assertEq(owner1,                                    depositorA);
        assertEq(shares1,                                   depositAmountA);
        assertEq(owner2,                                    depositorB);
        assertEq(shares2,                                   depositAmountB);
        assertEq(depositAsset.balanceOf(address(treasury)), 0);
        assertEq(depositAsset.balanceOf(depositorA),        0);
        assertEq(depositAsset.balanceOf(depositorB),        0);
    }

    function test_syrupBitcoinRouter_processRedemptions_revert_noAssetController() external {
        vm.prank(governor);
        bitcoinRouter.setAssetController(address(depositAsset), address(0));

        vm.prank(redeemer);
        vm.expectRevert("SBR:PR:NO_ASSET_CONTROLLER");
        bitcoinRouter.processRedemptions(requestIds);
    }

    function test_syrupBitcoinRouter_processRedemptions_revert_requestIdTooBig() external {
        uint256[] memory tooLargeRequestIds = new uint256[](1);
        tooLargeRequestIds[0]               = uint256(type(uint128).max) + 1;

        vm.prank(redeemer);
        vm.expectRevert("WM:TU:UINT256_CAST");
        bitcoinRouter.processRedemptions(tooLargeRequestIds);
    }

    function test_syrupBitcoinRouter_processRedemptions_revert_noSharesToRedeem() external {
        vm.prank(redeemer);
        vm.expectRevert("WM:PE:NO_SHARES");
        bitcoinRouter.processRedemptions(requestIds);
    }

    function test_syrupBitcoinRouter_processRedemptions_revert_tooManyShares() external {
        // Mocked because we need the withdrawal manager to think there are no unprocessed shares, so that the redeem request reverts.
        vm.mockCall(
            address(withdrawalManager),
            abi.encodeWithSignature(
                "requests(uint256)",
                1
            ),
            abi.encode(address(bitcoinRouter), 0)
        );

        vm.prank(redeemer);
        vm.expectRevert("WM:PE:TOO_MANY_SHARES");
        bitcoinRouter.processRedemptions(requestIds);
    }

    function test_syrupBitcoinRouter_processRedemptions_revert_insufficientLiquidity() external {
        uint256 liquidityRemaining = 10e8;  // Leave 10e8 for liquidity.
        uint256 amountToDeploy     = compositeAsset.balanceOf(address(pool)) - liquidityRemaining;

        uint256 manualSharesAvailableBefore = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableBefore, 0);

        ( address owner1, uint256 shares1 ) = withdrawalManager.requests(1);
        ( address owner2, uint256 shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(bitcoinRouter));
        assertEq(owner2, address(bitcoinRouter));

        assertEq(shares1, depositAmountA);
        assertEq(shares2, depositAmountB);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(depositAmountA + depositAmountB);

        ( owner1, shares1 ) = withdrawalManager.requests(1);
        ( owner2, shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(0));
        assertEq(owner2, address(0));

        assertEq(shares1, 0);
        assertEq(shares2, 0);

        uint256 manualSharesAvailableAfter = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableAfter, depositAmountA + depositAmountB);

        assertEq(depositAsset.balanceOf(address(assetController)), depositAmountA + depositAmountB);
        assertEq(compositeAsset.balanceOf(address(pool)),          depositAmountA + depositAmountB);

        address activeAssetController = bitcoinRouter.assetController(address(depositAsset));

        assertEq(IAssetController(activeAssetController).canDeploy(address(depositAsset)), true);

        vm.prank(strategyManager);
        bitcoinStrategy.deploy(address(depositAsset), amountToDeploy);

        assertEq(depositAsset.balanceOf(address(assetController)), liquidityRemaining);
        assertEq(compositeAsset.balanceOf(address(pool)),          liquidityRemaining);

        vm.prank(redeemer);
        vm.expectRevert("WM:PE:NOT_ENOUGH_LIQUIDITY");
        bitcoinRouter.processRedemptions(requestIds);
    }

    function test_syrupBitcoinRouter_processRedemptions_revert_assetController_canUnwrapFalse() external {
        address[] memory assets = new address[](1);

        bool[] memory canWrap      = new bool[](1);
        bool[] memory canUnwrap    = new bool[](1);
        bool[] memory canDeploy    = new bool[](1);
        bool[] memory canReconcile = new bool[](1);

        assets[0] = address(depositAsset);

        canWrap[0]      = true;
        canUnwrap[0]    = false;
        canDeploy[0]    = true;
        canReconcile[0] = true;

        vm.prank(governor);
        assetController.setAssets(assets, canWrap, canUnwrap, canDeploy, canReconcile);

        assertEq(assetController.canWrap(address(depositAsset)),      true);
        assertEq(assetController.canUnwrap(address(depositAsset)),    false);
        assertEq(assetController.canDeploy(address(depositAsset)),    true);
        assertEq(assetController.canReconcile(address(depositAsset)), true);

        uint256 manualSharesAvailableBefore = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableBefore, 0);

        ( address owner1, uint256 shares1 ) = withdrawalManager.requests(1);
        ( address owner2, uint256 shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(bitcoinRouter));
        assertEq(owner2, address(bitcoinRouter));

        assertEq(shares1, depositAmountA);
        assertEq(shares2, depositAmountB);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(depositAmountA + depositAmountB);

        ( owner1, shares1 ) = withdrawalManager.requests(1);
        ( owner2, shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(0));
        assertEq(owner2, address(0));

        assertEq(shares1, 0);
        assertEq(shares2, 0);

        uint256 manualSharesAvailableAfter = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableAfter, depositAmountA + depositAmountB);

        vm.prank(redeemer);
        vm.expectRevert("AC:U:INVALID_ASSET");
        bitcoinRouter.processRedemptions(requestIds);
    }

    function test_syrupBitcoinRouter_processRedemptions_revert_assetController_zeroWithdrawAmount() external {
        uint256 manualSharesAvailableBefore = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableBefore, 0);

        ( address owner1, uint256 shares1 ) = withdrawalManager.requests(1);
        ( address owner2, uint256 shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(bitcoinRouter));
        assertEq(owner2, address(bitcoinRouter));

        assertEq(shares1, depositAmountA);
        assertEq(shares2, depositAmountB);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(depositAmountA + depositAmountB);

        ( owner1, shares1 ) = withdrawalManager.requests(1);
        ( owner2, shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(0));
        assertEq(owner2, address(0));

        assertEq(shares1, 0);
        assertEq(shares2, 0);

        uint256 manualSharesAvailableAfter = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableAfter, depositAmountA + depositAmountB);

        // Mocked because the oracle will convert 1:1 unless mocked.
        vm.mockCall(
            address(priceOracle),
            abi.encodeWithSignature(
                "convert(address,address,uint256,bytes32)"
            ),
            abi.encode(0)
        );

        vm.prank(redeemer);
        vm.expectRevert("AC:U:ZERO_WITHDRAW");
        bitcoinRouter.processRedemptions(requestIds);
    }

    function test_syrupBitcoinRouter_processRedemptions_revert_assetController_transferFromFailed() external {
        uint256 manualSharesAvailableBefore = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableBefore, 0);

        ( address owner1, uint256 shares1 ) = withdrawalManager.requests(1);
        ( address owner2, uint256 shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(bitcoinRouter));
        assertEq(owner2, address(bitcoinRouter));

        assertEq(shares1, depositAmountA);
        assertEq(shares2, depositAmountB);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(depositAmountA + depositAmountB);

        ( owner1, shares1 ) = withdrawalManager.requests(1);
        ( owner2, shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(0));
        assertEq(owner2, address(0));

        assertEq(shares1, 0);
        assertEq(shares2, 0);

        uint256 manualSharesAvailableAfter = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableAfter, depositAmountA + depositAmountB);

        vm.startPrank(address(bitcoinRouter));
        IERC20Like(assetController.poolAsset()).approve(address(assetController), 0);
        vm.stopPrank();

        vm.prank(redeemer);
        vm.expectRevert("AC:U:COMPOSITE_ASSET_FAILURE");
        bitcoinRouter.processRedemptions(requestIds);
    }

    function test_syrupBitcoinRouter_processRedemptions_revert_assetController_transferFailed() external {
        uint256 manualSharesAvailableBefore = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableBefore, 0);

        ( address owner1, uint256 shares1 ) = withdrawalManager.requests(1);
        ( address owner2, uint256 shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(bitcoinRouter));
        assertEq(owner2, address(bitcoinRouter));

        assertEq(shares1, depositAmountA);
        assertEq(shares2, depositAmountB);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(depositAmountA + depositAmountB);

        ( owner1, shares1 ) = withdrawalManager.requests(1);
        ( owner2, shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(0));
        assertEq(owner2, address(0));

        assertEq(shares1, 0);
        assertEq(shares2, 0);

        uint256 manualSharesAvailableAfter = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableAfter, depositAmountA + depositAmountB);

        uint256 balanceOfController = depositAsset.balanceOf(address(assetController));

        depositAsset.burn(address(assetController), balanceOfController);

        vm.prank(redeemer);
        vm.expectRevert("AC:U:DEPOSIT_ASSET_FAILURE");
        bitcoinRouter.processRedemptions(requestIds);
    }

    function test_syrupBitcoinRouter_deposit_processRedemptions_transferFeeFailure() external {
        uint256 redemptionFeeRate = 0.15e6;

        vm.prank(governor);
        bitcoinRouter.setFees(address(depositAsset), 0, redemptionFeeRate);

        uint256 manualSharesAvailableBefore = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableBefore, 0);

        ( address owner1, uint256 shares1 ) = withdrawalManager.requests(1);
        ( address owner2, uint256 shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(bitcoinRouter));
        assertEq(owner2, address(bitcoinRouter));

        assertEq(shares1, depositAmountA);
        assertEq(shares2, depositAmountB);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(depositAmountA + depositAmountB);

        ( owner1, shares1 ) = withdrawalManager.requests(1);
        ( owner2, shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(0));
        assertEq(owner2, address(0));

        assertEq(shares1, 0);
        assertEq(shares2, 0);

        uint256 manualSharesAvailableAfter = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableAfter, depositAmountA + depositAmountB);

        // Mocked because the transfer amount is based on a calculation and will always succeed.
        vm.mockCall(
            address(depositAsset),
            abi.encodeWithSelector(
                IERC20Like.transfer.selector,
                address(treasury),
                depositAmountA * redemptionFeeRate / 1e6
            ),
            abi.encode(false)
        );

        vm.prank(redeemer);
        vm.expectRevert("SBR:PR:TRANSFER_FEE_FAILED");
        bitcoinRouter.processRedemptions(requestIds);
    }

    function test_syrupBitcoinRouter_deposit_processRedemptions_transferFailure() external {
        uint256 manualSharesAvailableBefore = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableBefore, 0);

        ( address owner1, uint256 shares1 ) = withdrawalManager.requests(1);
        ( address owner2, uint256 shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(bitcoinRouter));
        assertEq(owner2, address(bitcoinRouter));

        assertEq(shares1, depositAmountA);
        assertEq(shares2, depositAmountB);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(depositAmountA + depositAmountB);

        ( owner1, shares1 ) = withdrawalManager.requests(1);
        ( owner2, shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(0));
        assertEq(owner2, address(0));

        assertEq(shares1, 0);
        assertEq(shares2, 0);

        uint256 manualSharesAvailableAfter = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableAfter, depositAmountA + depositAmountB);

        // Mocked because the transfer amount is based on a calculation and will always succeed.
        vm.mockCall(
            address(depositAsset),
            abi.encodeWithSelector(
                IERC20Like.transfer.selector,
                depositorA,
                depositAmountA
            ),
            abi.encode(false)
        );

        vm.prank(redeemer);
        vm.expectRevert("SBR:PR:TRANSFER_FAILED");
        bitcoinRouter.processRedemptions(requestIds);
    }

    function test_syrupBitcoinRouter_processRedemptions_success() external {
        uint256 manualSharesAvailableBefore = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableBefore, 0);

        ( address owner1, uint256 shares1 ) = withdrawalManager.requests(1);
        ( address owner2, uint256 shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(bitcoinRouter));
        assertEq(owner2, address(bitcoinRouter));

        assertEq(shares1, depositAmountA);
        assertEq(shares2, depositAmountB);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(depositAmountA + depositAmountB);

        ( owner1, shares1 ) = withdrawalManager.requests(1);
        ( owner2, shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(0));
        assertEq(owner2, address(0));

        assertEq(shares1, 0);
        assertEq(shares2, 0);

        uint256 manualSharesAvailableAfter = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableAfter, depositAmountA + depositAmountB);

        uint256 treasuryDepositAssetBalanceBefore = depositAsset.balanceOf(address(treasury));

        assertEq(treasuryDepositAssetBalanceBefore, 0);

        {
            ( address routerRequest1AssetBefore, address routerRequest1OwnerBefore, uint256 routerRequest1SharesBefore ) =
                bitcoinRouter.redeemRequests(1);

            ( address routerRequest2AssetBefore, address routerRequest2OwnerBefore, uint256 routerRequest2SharesBefore ) =
                bitcoinRouter.redeemRequests(2);

            ( address wmRequest1OwnerBefore, uint256 wmRequest1SharesBefore ) = withdrawalManager.requests(1);
            ( address wmRequest2OwnerBefore, uint256 wmRequest2SharesBefore ) = withdrawalManager.requests(2);

            assertEq(wmRequest1OwnerBefore,  address(0));
            assertEq(wmRequest1SharesBefore, 0);
            assertEq(wmRequest2OwnerBefore,  address(0));
            assertEq(wmRequest2SharesBefore, 0);

            assertEq(depositAsset.balanceOf(depositorA),     0);
            assertEq(depositAsset.balanceOf(depositorB),     0);
            assertEq(pool.balanceOf(address(bitcoinRouter)), 0);

            assertEq(routerRequest1AssetBefore,  address(depositAsset));
            assertEq(routerRequest1OwnerBefore,  depositorA);
            assertEq(routerRequest1SharesBefore, depositAmountA);

            assertEq(routerRequest2AssetBefore,  address(depositAsset));
            assertEq(routerRequest2OwnerBefore,  depositorB);
            assertEq(routerRequest2SharesBefore, depositAmountB);

            assertEq(assetController.depositAssets(address(depositAsset)),  depositAmountA + depositAmountB);
            assertEq(assetController.poolAssets(address(depositAsset)),     depositAmountA + depositAmountB);
        }

        vm.prank(poolDelegate);
        bitcoinRouter.processRedemptions(requestIds);

        {
            assertEq(depositAsset.balanceOf(depositorA),        depositAmountA);
            assertEq(depositAsset.balanceOf(depositorB),        depositAmountB);
            assertEq(depositAsset.balanceOf(address(treasury)), treasuryDepositAssetBalanceBefore);
            assertEq(pool.balanceOf(address(bitcoinRouter)),    0);

            ( address routerRequest1AssetAfter, address routerRequest1OwnerAfter, uint256 routerRequest1SharesAfter ) =
                bitcoinRouter.redeemRequests(1);

            ( address routerRequest2AssetAfter, address routerRequest2OwnerAfter, uint256 routerRequest2SharesAfter ) =
                bitcoinRouter.redeemRequests(2);

            assertEq(routerRequest1AssetAfter,  address(0));
            assertEq(routerRequest1OwnerAfter,  address(0));
            assertEq(routerRequest1SharesAfter, 0);

            assertEq(routerRequest2AssetAfter,  address(0));
            assertEq(routerRequest2OwnerAfter,  address(0));
            assertEq(routerRequest2SharesAfter, 0);

            ( address wmRequest1OwnerAfter, uint256 wmRequest1SharesAfter ) = withdrawalManager.requests(1);
            ( address wmRequest2OwnerAfter, uint256 wmRequest2SharesAfter ) = withdrawalManager.requests(2);

            assertEq(wmRequest1OwnerAfter,  address(0));
            assertEq(wmRequest1SharesAfter, 0);
            assertEq(wmRequest2OwnerAfter,  address(0));
            assertEq(wmRequest2SharesAfter, 0);

            assertEq(assetController.depositAssets(address(depositAsset)),  0);
            assertEq(assetController.poolAssets(address(depositAsset)),     0);
        }
    }

    function test_syrupBitcoinRouter_processRedemptions_success_outOfOrderIds() external {
        uint256 manualSharesAvailableBefore = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableBefore, 0);

        ( address owner1, uint256 shares1 ) = withdrawalManager.requests(1);
        ( address owner2, uint256 shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(bitcoinRouter));
        assertEq(owner2, address(bitcoinRouter));

        assertEq(shares1, depositAmountA);
        assertEq(shares2, depositAmountB);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(depositAmountA + depositAmountB);

        ( owner1, shares1 ) = withdrawalManager.requests(1);
        ( owner2, shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(0));
        assertEq(owner2, address(0));

        assertEq(shares1, 0);
        assertEq(shares2, 0);

        uint256 manualSharesAvailableAfter = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableAfter, depositAmountA + depositAmountB);

        uint256 treasuryDepositAssetBalanceBefore = depositAsset.balanceOf(address(treasury));

        assertEq(treasuryDepositAssetBalanceBefore, 0);

        ( , , uint256 routerRequest1SharesBefore ) = bitcoinRouter.redeemRequests(1);
        ( , , uint256 routerRequest2SharesBefore ) = bitcoinRouter.redeemRequests(2);

        assertEq(routerRequest1SharesBefore, depositAmountA);
        assertEq(routerRequest2SharesBefore, depositAmountB);

        uint256[] memory reversedIds = new uint256[](2);
        reversedIds[0] = requestIds[1];
        reversedIds[1] = requestIds[0];

        vm.prank(poolDelegate);
        bitcoinRouter.processRedemptions(reversedIds);

        assertEq(depositAsset.balanceOf(depositorA),        depositAmountA);
        assertEq(depositAsset.balanceOf(depositorB),        depositAmountB);
        assertEq(depositAsset.balanceOf(address(treasury)), treasuryDepositAssetBalanceBefore);
        assertEq(pool.balanceOf(address(bitcoinRouter)),    0);

        ( address routerRequest1AssetAfter, address routerRequest1OwnerAfter, uint256 routerRequest1SharesAfter ) =
            bitcoinRouter.redeemRequests(1);

        ( address routerRequest2AssetAfter, address routerRequest2OwnerAfter, uint256 routerRequest2SharesAfter ) =
            bitcoinRouter.redeemRequests(2);

        assertEq(routerRequest1AssetAfter,  address(0));
        assertEq(routerRequest1OwnerAfter,  address(0));
        assertEq(routerRequest1SharesAfter, 0);

        assertEq(routerRequest2AssetAfter,  address(0));
        assertEq(routerRequest2OwnerAfter,  address(0));
        assertEq(routerRequest2SharesAfter, 0);
    }

    function test_syrupBitcoinRouter_processRedemptions_success_singleRequestOnly() external {
        uint256 manualSharesAvailableBefore = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableBefore, 0);

        ( address owner1, uint256 shares1 ) = withdrawalManager.requests(1);
        ( address owner2, uint256 shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(bitcoinRouter));
        assertEq(owner2, address(bitcoinRouter));

        assertEq(shares1, depositAmountA);
        assertEq(shares2, depositAmountB);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(depositAmountA + depositAmountB);

        ( owner1, shares1 ) = withdrawalManager.requests(1);
        ( owner2, shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(0));
        assertEq(owner2, address(0));

        assertEq(shares1, 0);
        assertEq(shares2, 0);

        uint256 manualSharesAvailableAfter = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableAfter, depositAmountA + depositAmountB);

        uint256 treasuryDepositAssetBalanceBefore = depositAsset.balanceOf(address(treasury));

        assertEq(treasuryDepositAssetBalanceBefore, 0);

        ( address routerRequest1AssetBefore, address routerRequest1OwnerBefore, uint256 routerRequest1SharesBefore ) =
            bitcoinRouter.redeemRequests(1);

        ( address routerRequest2AssetBefore, address routerRequest2OwnerBefore, uint256 routerRequest2SharesBefore ) =
            bitcoinRouter.redeemRequests(2);

        assertEq(routerRequest1AssetBefore,  address(depositAsset));
        assertEq(routerRequest1OwnerBefore,  depositorA);
        assertEq(routerRequest1SharesBefore, depositAmountA);

        assertEq(routerRequest2AssetBefore,  address(depositAsset));
        assertEq(routerRequest2OwnerBefore,  depositorB);
        assertEq(routerRequest2SharesBefore, depositAmountB);

        assertEq(depositAsset.balanceOf(depositorA), 0);
        assertEq(depositAsset.balanceOf(depositorB), 0);

        uint256[] memory oneRequest = new uint256[](1);
        oneRequest[0]               = requestIds[0];

        vm.prank(poolDelegate);
        bitcoinRouter.processRedemptions(oneRequest);

        assertEq(depositAsset.balanceOf(depositorA),        depositAmountA);
        assertEq(depositAsset.balanceOf(depositorB),        0);
        assertEq(depositAsset.balanceOf(address(treasury)), treasuryDepositAssetBalanceBefore);
        assertEq(pool.balanceOf(address(bitcoinRouter)),    0);

        ( address routerRequest1AssetAfter, address routerRequest1OwnerAfter, uint256 routerRequest1SharesAfter ) =
            bitcoinRouter.redeemRequests(1);

        assertEq(routerRequest1AssetAfter,  address(0));
        assertEq(routerRequest1OwnerAfter,  address(0));
        assertEq(routerRequest1SharesAfter, 0);

        ( address routerRequest2AssetAfter, address routerRequest2OwnerAfter, uint256 routerRequest2SharesAfter ) =
            bitcoinRouter.redeemRequests(2);

        assertEq(routerRequest2AssetAfter,  address(depositAsset));
        assertEq(routerRequest2OwnerAfter,  depositorB);
        assertEq(routerRequest2SharesAfter, depositAmountB);
    }

    function test_syrupBitcoinRouter_processRedemptions_success_withRedemptionFee() external {
        uint256 redemptionFeeRate = 0.15e6;  // 15% fee
        vm.prank(governor);
        bitcoinRouter.setFees(address(depositAsset), 0, redemptionFeeRate);

        uint256 manualSharesAvailableBefore = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableBefore, 0);

        ( address owner1, uint256 shares1 ) = withdrawalManager.requests(1);
        ( address owner2, uint256 shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(bitcoinRouter));
        assertEq(owner2, address(bitcoinRouter));

        assertEq(shares1, depositAmountA);
        assertEq(shares2, depositAmountB);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(depositAmountA + depositAmountB);

        ( owner1, shares1 ) = withdrawalManager.requests(1);
        ( owner2, shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(0));
        assertEq(owner2, address(0));

        assertEq(shares1, 0);
        assertEq(shares2, 0);

        uint256 manualSharesAvailableAfter = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableAfter, depositAmountA + depositAmountB);

        uint256 treasuryDepositAssetBalanceBefore = depositAsset.balanceOf(address(treasury));

        assertEq(treasuryDepositAssetBalanceBefore, 0);

        uint256 expectedFeeA                  = (depositAmountA * redemptionFeeRate) / 1e6;
        uint256 expectedFeeB                  = (depositAmountB * redemptionFeeRate) / 1e6;
        uint256 expectedPayoutA               = depositAmountA - expectedFeeA;
        uint256 expectedPayoutB               = depositAmountB - expectedFeeB;
        uint256 expectedTreasuryBalanceAfter  = treasuryDepositAssetBalanceBefore + expectedFeeA + expectedFeeB;

        vm.prank(poolDelegate);
        bitcoinRouter.processRedemptions(requestIds);

        assertEq(depositAsset.balanceOf(depositorA),        expectedPayoutA);
        assertEq(depositAsset.balanceOf(depositorB),        expectedPayoutB);
        assertEq(depositAsset.balanceOf(address(treasury)), expectedTreasuryBalanceAfter);
        assertEq(pool.balanceOf(address(bitcoinRouter)),    0);

        ( address routerRequest1AssetAfter, address routerRequest1OwnerAfter, uint256 routerRequest1SharesAfter ) =
            bitcoinRouter.redeemRequests(1);

        ( address routerRequest2AssetAfter, address routerRequest2OwnerAfter, uint256 routerRequest2SharesAfter ) =
            bitcoinRouter.redeemRequests(2);

        assertEq(routerRequest1AssetAfter,  address(0));
        assertEq(routerRequest1OwnerAfter,  address(0));
        assertEq(routerRequest1SharesAfter, 0);

        assertEq(routerRequest2AssetAfter,  address(0));
        assertEq(routerRequest2OwnerAfter,  address(0));
        assertEq(routerRequest2SharesAfter, 0);
    }

    function test_syrupBitcoinRouter_processRedemptions_success_redemptionFeeEqualsRedeemAmount_userReceivesZeroShares() external {
        uint256 redemptionFeeRate = 0.1e6;  // 10% fee
        uint256 processedShares   = 1 wei;
        uint256 expectedFee       = calculateFee(processedShares, redemptionFeeRate);

        assertEq(expectedFee, processedShares);

        assertEq(pool.balanceOf(address(bitcoinRouter)),           0);
        assertEq(pool.balanceOf(depositorA),                       0);
        assertEq(pool.balanceOf(depositorB),                       0);
        assertEq(pool.balanceOf(address(withdrawalManager)),       depositAmountA + depositAmountB);
        assertEq(depositAsset.balanceOf(address(treasury)),        0);
        assertEq(depositAsset.balanceOf(address(assetController)), depositAmountA + depositAmountB);
        assertEq(compositeAsset.balanceOf(address(pool)),          depositAmountA + depositAmountB);

        ( address wmRequestOwner, uint256 wmRequestShares ) = withdrawalManager.requests(requestIds[0]);

        assertEq(wmRequestOwner,  address(bitcoinRouter));
        assertEq(wmRequestShares, depositAmountA);

        (
            address routerRequestAsset,
            address routerRequestOwner,
            uint256 routerRequestShares
        ) = bitcoinRouter.redeemRequests(requestIds[0]);

        assertEq(routerRequestAsset,  address(depositAsset));
        assertEq(routerRequestOwner,  depositorA);
        assertEq(routerRequestShares, depositAmountA);

        vm.prank(governor);
        bitcoinRouter.setFees(address(depositAsset), 0, redemptionFeeRate);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(processedShares);

        assertEq(pool.balanceOf(address(bitcoinRouter)),           0);
        assertEq(pool.balanceOf(depositorA),                       0);
        assertEq(pool.balanceOf(depositorB),                       0);
        assertEq(pool.balanceOf(address(withdrawalManager)),       depositAmountA + depositAmountB);
        assertEq(depositAsset.balanceOf(address(treasury)),        0);
        assertEq(depositAsset.balanceOf(address(assetController)), depositAmountA + depositAmountB);
        assertEq(compositeAsset.balanceOf(address(pool)),          depositAmountA + depositAmountB);

        ( wmRequestOwner, wmRequestShares ) = withdrawalManager.requests(requestIds[0]);

        assertEq(wmRequestOwner,  address(bitcoinRouter));
        assertEq(wmRequestShares, depositAmountA - processedShares);

        (
            routerRequestAsset,
            routerRequestOwner,
            routerRequestShares
        ) = bitcoinRouter.redeemRequests(requestIds[0]);

        assertEq(routerRequestAsset,  address(depositAsset));
        assertEq(routerRequestOwner,  depositorA);
        assertEq(routerRequestShares, depositAmountA);

        uint256[] memory requestIdsToProcess = new uint256[](1);
        requestIdsToProcess[0]               = requestIds[0];

        vm.prank(poolDelegate);
        bitcoinRouter.processRedemptions(requestIdsToProcess);

        assertEq(pool.balanceOf(address(bitcoinRouter)),           0);
        assertEq(pool.balanceOf(depositorA),                       0);
        assertEq(pool.balanceOf(depositorB),                       0);
        assertEq(pool.balanceOf(address(withdrawalManager)),       depositAmountA + depositAmountB - processedShares);
        assertEq(depositAsset.balanceOf(address(treasury)),        expectedFee);
        assertEq(depositAsset.balanceOf(address(assetController)), depositAmountA + depositAmountB - processedShares);
        assertEq(compositeAsset.balanceOf(address(pool)),          depositAmountA + depositAmountB - processedShares);

        ( wmRequestOwner, wmRequestShares ) = withdrawalManager.requests(requestIds[0]);

        assertEq(wmRequestOwner,  address(bitcoinRouter));
        assertEq(wmRequestShares, depositAmountA - processedShares);

        (
            routerRequestAsset,
            routerRequestOwner,
            routerRequestShares
        ) = bitcoinRouter.redeemRequests(requestIds[0]);

        assertEq(routerRequestAsset,  address(depositAsset));
        assertEq(routerRequestOwner,  depositorA);
        assertEq(routerRequestShares, depositAmountA - processedShares);
    }

    function test_syrupBitcoinRouter_processRedemptions_success_withFullRedemptionFee() external {
        uint256 redemptionFeeRate = 1e6;  // 100% fee

        vm.prank(governor);
        bitcoinRouter.setFees(address(depositAsset), 0, redemptionFeeRate);

        uint256 manualSharesAvailableBefore = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableBefore, 0);

        ( address owner1, uint256 shares1 ) = withdrawalManager.requests(1);
        ( address owner2, uint256 shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(bitcoinRouter));
        assertEq(owner2, address(bitcoinRouter));

        assertEq(shares1, depositAmountA);
        assertEq(shares2, depositAmountB);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(depositAmountA + depositAmountB);

        ( owner1, shares1 ) = withdrawalManager.requests(1);
        ( owner2, shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(0));
        assertEq(owner2, address(0));

        assertEq(shares1, 0);
        assertEq(shares2, 0);

        uint256 manualSharesAvailableAfter = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableAfter, depositAmountA + depositAmountB);

        uint256 treasuryDepositAssetBalanceBefore = depositAsset.balanceOf(address(treasury));

        assertEq(treasuryDepositAssetBalanceBefore, 0);

        ( address wmRequest1OwnerBefore, uint256 wmRequest1SharesBefore ) = withdrawalManager.requests(1);
        ( address wmRequest2OwnerBefore, uint256 wmRequest2SharesBefore ) = withdrawalManager.requests(2);

        assertEq(wmRequest1OwnerBefore,  address(0));
        assertEq(wmRequest1SharesBefore, 0);
        assertEq(wmRequest2OwnerBefore,  address(0));
        assertEq(wmRequest2SharesBefore, 0);

        ( address routerRequest1AssetBefore, address routerRequest1OwnerBefore, uint256 routerRequest1SharesBefore ) =
            bitcoinRouter.redeemRequests(1);

        ( address routerRequest2AssetBefore, address routerRequest2OwnerBefore, uint256 routerRequest2SharesBefore ) =
            bitcoinRouter.redeemRequests(2);

        assertEq(routerRequest1AssetBefore,  address(depositAsset));
        assertEq(routerRequest1OwnerBefore,  depositorA);
        assertEq(routerRequest1SharesBefore, depositAmountA);

        assertEq(routerRequest2AssetBefore,  address(depositAsset));
        assertEq(routerRequest2OwnerBefore,  depositorB);
        assertEq(routerRequest2SharesBefore, depositAmountB);

        assertEq(depositAsset.balanceOf(depositorA),     0);
        assertEq(depositAsset.balanceOf(depositorB),     0);
        assertEq(pool.balanceOf(address(bitcoinRouter)), 0);

        vm.prank(poolDelegate);
        bitcoinRouter.processRedemptions(requestIds);

        uint256 expectedTreasuryBalanceAfter = depositAmountA + depositAmountB;

        assertEq(depositAsset.balanceOf(depositorA),        0);
        assertEq(depositAsset.balanceOf(depositorB),        0);
        assertEq(depositAsset.balanceOf(address(treasury)), expectedTreasuryBalanceAfter);
        assertEq(pool.balanceOf(address(bitcoinRouter)),    0);

        ( address routerRequest1AssetAfter, address routerRequest1OwnerAfter, uint256 routerRequest1SharesAfter ) =
            bitcoinRouter.redeemRequests(1);

        ( address routerRequest2AssetAfter, address routerRequest2OwnerAfter, uint256 routerRequest2SharesAfter ) =
            bitcoinRouter.redeemRequests(2);

        assertEq(routerRequest1AssetAfter,  address(0));
        assertEq(routerRequest1OwnerAfter,  address(0));
        assertEq(routerRequest1SharesAfter, 0);

        assertEq(routerRequest2AssetAfter,  address(0));
        assertEq(routerRequest2OwnerAfter,  address(0));
        assertEq(routerRequest2SharesAfter, 0);

        ( address wmRequest1OwnerAfter, uint256 wmRequest1SharesAfter ) = withdrawalManager.requests(1);
        ( address wmRequest2OwnerAfter, uint256 wmRequest2SharesAfter ) = withdrawalManager.requests(2);

        assertEq(wmRequest1OwnerAfter,  address(0));
        assertEq(wmRequest1SharesAfter, 0);
        assertEq(wmRequest2OwnerAfter,  address(0));
        assertEq(wmRequest2SharesAfter, 0);
    }

    function test_syrupBitcoinRouter_processRedemptions_success_zeroPoolAssets() external {
        uint256 manualSharesAvailableBefore = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableBefore, 0);

        ( address owner1, uint256 shares1 ) = withdrawalManager.requests(1);
        ( address owner2, uint256 shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(bitcoinRouter));
        assertEq(owner2, address(bitcoinRouter));

        assertEq(shares1, depositAmountA);
        assertEq(shares2, depositAmountB);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(depositAmountA + depositAmountB);

        ( owner1, shares1 ) = withdrawalManager.requests(1);
        ( owner2, shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(0));
        assertEq(owner2, address(0));

        assertEq(shares1, 0);
        assertEq(shares2, 0);

        uint256 manualSharesAvailableAfter = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableAfter, depositAmountA + depositAmountB);

        uint256 treasuryDepositAssetBalanceBefore = depositAsset.balanceOf(address(treasury));

        assertEq(treasuryDepositAssetBalanceBefore, 0);

        ( address wmRequest1OwnerBefore, uint256 wmRequest1SharesBefore ) = withdrawalManager.requests(1);
        ( address wmRequest2OwnerBefore, uint256 wmRequest2SharesBefore ) = withdrawalManager.requests(2);

        assertEq(wmRequest1OwnerBefore,  address(0));
        assertEq(wmRequest1SharesBefore, 0);
        assertEq(wmRequest2OwnerBefore,  address(0));
        assertEq(wmRequest2SharesBefore, 0);

        ( address routerRequest1AssetBefore, address routerRequest1OwnerBefore, uint256 routerRequest1SharesBefore ) =
            bitcoinRouter.redeemRequests(1);

        ( address routerRequest2AssetBefore, address routerRequest2OwnerBefore, uint256 routerRequest2SharesBefore ) =
            bitcoinRouter.redeemRequests(2);

        assertEq(routerRequest1AssetBefore,  address(depositAsset));
        assertEq(routerRequest1OwnerBefore,  depositorA);
        assertEq(routerRequest1SharesBefore, depositAmountA);

        assertEq(routerRequest2AssetBefore,  address(depositAsset));
        assertEq(routerRequest2OwnerBefore,  depositorB);
        assertEq(routerRequest2SharesBefore, depositAmountB);

        assertEq(depositAsset.balanceOf(depositorA),     0);
        assertEq(depositAsset.balanceOf(depositorB),     0);
        assertEq(pool.balanceOf(address(bitcoinRouter)), 0);

        // Make the pool shares worthless.
        address compositeToken  = pool.asset();
        uint256 poolCash        = IERC20Like(address(compositeToken)).balanceOf(address(pool));

        vm.prank(address(assetController));
        IERC20Like(compositeToken).burn(address(pool), poolCash);

        vm.prank(redeemer);
        bitcoinRouter.processRedemptions(requestIds);

        assertEq(depositAsset.balanceOf(depositorA),        0);
        assertEq(depositAsset.balanceOf(depositorB),        0);
        assertEq(depositAsset.balanceOf(address(treasury)), 0);

        assertEq(pool.balanceOf(address(bitcoinRouter)), 0);

        ( address routerRequest1AssetAfter, address routerRequest1OwnerAfter, uint256 routerRequest1SharesAfter ) =
            bitcoinRouter.redeemRequests(1);

        ( address routerRequest2AssetAfter, address routerRequest2OwnerAfter, uint256 routerRequest2SharesAfter ) =
            bitcoinRouter.redeemRequests(2);

        assertEq(routerRequest1AssetAfter,  address(0));
        assertEq(routerRequest1OwnerAfter,  address(0));
        assertEq(routerRequest1SharesAfter, 0);

        assertEq(routerRequest2AssetAfter,  address(0));
        assertEq(routerRequest2OwnerAfter,  address(0));
        assertEq(routerRequest2SharesAfter, 0);
    }

    function test_syrupBitcoinRouter_processRedemptions_success_partialFirstRequest() external {
        uint256 manualSharesAvailableBefore = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableBefore, 0);

        ( address owner1, uint256 shares1 ) = withdrawalManager.requests(1);
        ( address owner2, uint256 shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(bitcoinRouter));
        assertEq(owner2, address(bitcoinRouter));

        assertEq(shares1, depositAmountA);
        assertEq(shares2, depositAmountB);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(depositAmountA / 2);

        ( owner1, shares1 ) = withdrawalManager.requests(1);
        ( owner2, shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(bitcoinRouter));
        assertEq(owner2, address(bitcoinRouter));

        assertEq(shares1, depositAmountA / 2);
        assertEq(shares2, depositAmountB);

        uint256 manualSharesAvailableAfter = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableAfter, depositAmountA / 2);

        uint256 treasuryDepositAssetBalanceBefore = depositAsset.balanceOf(address(treasury));

        assertEq(treasuryDepositAssetBalanceBefore, 0);

        ( , , uint256 routerRequest1SharesBefore ) = bitcoinRouter.redeemRequests(1);
        ( , , uint256 routerRequest2SharesBefore ) = bitcoinRouter.redeemRequests(2);

        assertEq(routerRequest1SharesBefore, depositAmountA);
        assertEq(routerRequest2SharesBefore, depositAmountB);

        ( address wmRequest1OwnerBefore, uint256 wmRequest1RemainingSharesBefore ) = withdrawalManager.requests(1);

        assertEq(wmRequest1OwnerBefore,           address(bitcoinRouter));
        assertEq(wmRequest1RemainingSharesBefore, depositAmountA - depositAmountA / 2);

        uint256[] memory oneRequest = new uint256[](1);
        oneRequest[0]               = requestIds[0];

        vm.prank(poolDelegate);
        bitcoinRouter.processRedemptions(oneRequest);

        assertEq(depositAsset.balanceOf(depositorA),        depositAmountA / 2);
        assertEq(depositAsset.balanceOf(depositorB),        0);
        assertEq(depositAsset.balanceOf(address(treasury)), treasuryDepositAssetBalanceBefore);
        assertEq(pool.balanceOf(address(bitcoinRouter)),    0);

        ( address routerRequest1AssetAfter, address routerRequest1OwnerAfter, uint256 routerRequest1SharesAfter )
            = bitcoinRouter.redeemRequests(1);

        ( address routerRequest2AssetAfter, address routerRequest2OwnerAfter, uint256 routerRequest2SharesAfter )
            = bitcoinRouter.redeemRequests(2);

        assertEq(routerRequest1AssetAfter,  address(depositAsset));
        assertEq(routerRequest1OwnerAfter,  depositorA);
        assertEq(routerRequest1SharesAfter, depositAmountA - (depositAmountA / 2));

        assertEq(routerRequest2AssetAfter,  address(depositAsset));
        assertEq(routerRequest2OwnerAfter,  depositorB);
        assertEq(routerRequest2SharesAfter, depositAmountB);
    }

    function test_syrupBitcoinRouter_processRedemptions_success_partialThenFinish() external {
        uint256 manualSharesAvailableBefore = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableBefore, 0);

        ( address owner1, uint256 shares1 ) = withdrawalManager.requests(1);
        ( address owner2, uint256 shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(bitcoinRouter));
        assertEq(owner2, address(bitcoinRouter));

        assertEq(shares1, depositAmountA);
        assertEq(shares2, depositAmountB);

        vm.prank(poolDelegate);
        withdrawalManager.processRedemptions(depositAmountA / 2);

        ( owner1, shares1 ) = withdrawalManager.requests(1);
        ( owner2, shares2 ) = withdrawalManager.requests(2);

        assertEq(owner1, address(bitcoinRouter));
        assertEq(owner2, address(bitcoinRouter));

        assertEq(shares1, depositAmountA / 2);
        assertEq(shares2, depositAmountB);

        uint256 manualSharesAvailableAfter = withdrawalManager.manualSharesAvailable(address(bitcoinRouter));

        assertEq(manualSharesAvailableAfter, (depositAmountA / 2));

        vm.prank(redeemer);
        uint256[] memory oneRequest = new uint256[](1);
        oneRequest[0]               = requestIds[0];

        bitcoinRouter.processRedemptions(oneRequest);

        uint256 depositorADepositAssetBalanceAfterFirst = depositAsset.balanceOf(depositorA);

        assertEq(depositorADepositAssetBalanceAfterFirst, depositAmountA / 2);

        vm.startPrank(poolDelegate);
        withdrawalManager.processRedemptions((depositAmountA - (depositAmountA / 2)) + depositAmountB);
        vm.stopPrank();

        vm.prank(poolDelegate);
        bitcoinRouter.processRedemptions(requestIds);

        assertEq(depositAsset.balanceOf(depositorA), depositAmountA);
        assertEq(depositAsset.balanceOf(depositorB), depositAmountB);

        ( address request1Asset, address request1Owner, uint256 request1Shares ) = bitcoinRouter.redeemRequests(1);
        ( address request2Asset, address request2Owner, uint256 request2Shares ) = bitcoinRouter.redeemRequests(2);

        assertEq(request1Asset,  address(0));
        assertEq(request1Owner,  address(0));
        assertEq(request1Shares, 0);

        assertEq(request2Asset,  address(0));
        assertEq(request2Owner,  address(0));
        assertEq(request2Shares, 0);
    }

}
