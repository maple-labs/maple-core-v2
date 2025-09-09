// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC20Like,
    ISyrupBitcoinRouter,
    Permit
} from "../../../../contracts/interfaces/Interfaces.sol";

import { SyrupBTCRouterTestBase } from "../syrup-btc-router/SyrupBTCRouterTestBase.sol";

contract SyrupBitcoinRouterDepositTests is SyrupBTCRouterTestBase {

    bytes32 constant EMPTY_METADATA = "";

    address depositor;
    address invalidDepositAsset;

    uint256 depositAmount;
    uint256 depositorPrivateKey;

    function setUp() public virtual override {
        super.setUp();

        depositAmount = 20e8;

        ( depositor, depositorPrivateKey ) = makeAddrAndKey("depositor");

        invalidDepositAsset = makeAddr("invalidDepositAsset");

        depositAsset.mint(depositor, depositAmount);

        assertEq(depositAsset.balanceOf(depositor), depositAmount);

        vm.prank(depositor);
        depositAsset.approve(address(bitcoinRouter), depositAmount);

        vm.prank(governor);
        bitcoinRouter.setFees(address(depositAsset), 0, 0);
    }

    function test_syrupBitcoinRouter_deposit_revert_paused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("SBR:PAUSED");
        bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, emptyPermit());
    }

    function test_syrupBitcoinRouter_deposit_revert_noAssetController() external {
        vm.expectRevert("SBR:D:NO_ASSET_CONTROLLER");
        bitcoinRouter.deposit(address(invalidDepositAsset), depositAmount, EMPTY_METADATA, emptyPermit());
    }

    function test_syrupBitcoinRouter_deposit_revert_noAssetController_disabledAsset() external {
        assertNotEq(address(assetController), address(0));

        assertEq(
            ISyrupBitcoinRouter(address(bitcoinRouter)).assetController(address(depositAsset)),
            address(assetController)
        );

        vm.prank(governor);
        bitcoinRouter.setAssetController(address(depositAsset), address(0));

        assertEq(
            ISyrupBitcoinRouter(address(bitcoinRouter)).assetController(address(depositAsset)),
            address(0)
        );

        vm.expectRevert("SBR:D:NO_ASSET_CONTROLLER");
        bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, emptyPermit());
    }

    function test_syrupBitcoinRouter_deposit_revert_invalidPermit_wrongSigner() external {
        vm.prank(depositor);
        depositAsset.approve(address(bitcoinRouter), 0);

        uint256 invalidPrivateKey = 1;

        Permit memory permit_ = signPermit(invalidPrivateKey, address(depositAsset), depositor, depositAmount, block.timestamp);

        vm.prank(depositor);
        vm.expectRevert("ERC20:P:INVALID_SIGNATURE");
        bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, permit_);
    }

    function test_syrupBitcoinRouter_deposit_revert_invalidPermit_wrongAmount() external {
        vm.prank(depositor);
        depositAsset.approve(address(bitcoinRouter), 0);

        Permit memory permit_ =
            signPermit(
                depositorPrivateKey,
                address(depositAsset),
                depositor,
                depositAmount - 1,
                block.timestamp
            );

        vm.prank(depositor);
        vm.expectRevert("ERC20:P:INVALID_SIGNATURE");
        bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, permit_);
    }

    function test_syrupBitcoinRouter_deposit_revert_invalidPermit_expired() external {
        vm.prank(depositor);
        depositAsset.approve(address(bitcoinRouter), 0);

        Permit memory permit_ =
            signPermit(
                depositorPrivateKey,
                address(depositAsset),
                depositor,
                depositAmount,
                block.timestamp
            );

        vm.warp(block.timestamp + 1);

        vm.prank(depositor);
        vm.expectRevert("ERC20:P:EXPIRED");
        bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, permit_);
    }

    function test_syrupBitcoinRouter_deposit_revert_transferFailed_insufficientAssets() external {
        depositAsset.burn(depositor, depositAmount);

        vm.prank(depositor);
        vm.expectRevert("SBR:D:TRANSFER_FAILED");
        bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, emptyPermit());
    }

    function test_syrupBitcoinRouter_deposit_revert_transferFailed_insufficientApproval() external {
        vm.prank(depositor);
        depositAsset.approve(address(bitcoinRouter), 0);

        vm.prank(depositor);
        vm.expectRevert("SBR:D:TRANSFER_FAILED");
        bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, emptyPermit());
    }

    function test_syrupBitcoinRouter_deposit_revert_wrapFailed_invalidAsset() external {
        address[] memory assets = new address[](1);

        bool[] memory allowed    = new bool[](1);
        bool[] memory notAllowed = new bool[](1);

        assets[0] = address(depositAsset);

        allowed[0]    = true;
        notAllowed[0] = false;

        vm.prank(governor);
        assetController.setAssets(assets, notAllowed, allowed, allowed, allowed);

        vm.prank(depositor);
        vm.expectRevert("AC:W:INVALID_ASSET");
        bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, emptyPermit());
    }

    function test_syrupBitcoinRouter_deposit_revert_wrapFailed_zeroDepositAmount() external {
        depositAmount = 0;

        vm.prank(depositor);
        vm.expectRevert("AC:W:ZERO_DEPOSIT");
        bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, emptyPermit());
    }

    function test_syrupBitcoinRouter_deposit_revert_zeroDeposit_withFullFee() external {
        uint256 mintFee       = 1e6;  // One Hundred Percent
        uint256 redemptionFee = 0;

        vm.prank(governor);
        bitcoinRouter.setFees(address(depositAsset), mintFee, redemptionFee);

        vm.prank(depositor);
        vm.expectRevert("AC:W:ZERO_DEPOSIT");
        bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, emptyPermit());
    }

    function test_syrupBitcoinRouter_deposit_revert_mint_invalidAssetController() external {
        address[] memory controllers = new address[](1);
        bool[] memory flags          = new bool[](1);

        controllers[0] = address(assetController);
        flags[0]       = false;

        vm.prank(governor);
        compositeAsset.setAssetControllers(controllers, flags);

        vm.prank(depositor);
        vm.expectRevert("CT:NOT_CONTROLLER");
        bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, emptyPermit());
    }

    function test_syrupBitcoinRouter_deposit_revert_mint_notAllowAddress() external {
        address[] memory controllers = new address[](1);
        bool[] memory allowed        = new bool[](1);

        controllers[0] = address(assetController);
        allowed[0]     = false;

        vm.prank(governor);
        compositeAsset.allowAddresses(controllers, allowed);

        vm.prank(depositor);
        vm.expectRevert("CT:NOT_ALLOWED");
        bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, emptyPermit());
    }

    function test_syrupBitcoinRouter_deposit_revert_wrap_zeroOracleQuote() external {
        vm.mockCall(
            address(priceOracle),
            abi.encodeWithSelector(
                bytes4(keccak256(bytes("convert(address,address,uint256,bytes32)")))
            ),
            abi.encode(0)
        );

        vm.prank(depositor);
        vm.expectRevert("CT:M:ZERO_AMOUNT");
        bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, emptyPermit());
    }

    function test_syrupBitcoinRouter_deposit_reverts_roundSharesToZero() external {
        address otherDepositor    = makeAddr("other_depositor");
        uint256 otherDepositAmount = 10e8;

        depositAsset.mint(otherDepositor, otherDepositAmount);

        vm.startPrank(otherDepositor);

        depositAsset.approve(address(bitcoinRouter), otherDepositAmount);

        uint256 initialShares = bitcoinRouter.deposit(address(depositAsset), otherDepositAmount, EMPTY_METADATA, emptyPermit());

        vm.stopPrank();

        assertEq(initialShares, otherDepositAmount);

        uint256 largeTopUp = 1_000_000_000e8;  // Increases the exchange rate so that 1 WBTC deposit will round down to zero shares.

        vm.prank(address(assetController));
        compositeAsset.mint(address(pool), largeTopUp);

        depositAmount = 1e8;

        uint256 preview = pool.previewDeposit(depositAmount);

        assertEq(preview, 0);

        vm.expectRevert(bytes("P:M:ZERO_SHARES"));
        vm.prank(depositor);
        bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, emptyPermit());
    }

    function test_syrupBitcoinRouter_deposit_revert_wrap_transferFailureToAssetController() external {
        vm.prank(address(bitcoinRouter));
        depositAsset.approve(address(assetController), 0);

        vm.prank(depositor);
        vm.expectRevert("AC:W:DEPOSIT_ASSET_FAILURE");
        bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, emptyPermit());
    }

    function test_syrupBitcoinRouter_deposit_revert_wrapFailed_transferToBitcoinRouter() external {
        vm.mockCall(
            address(compositeAsset),
            abi.encodeWithSelector(
                IERC20Like.transfer.selector,
                address(bitcoinRouter),
                depositAmount
            ),
            abi.encode(false)
        );

        vm.prank(depositor);
        vm.expectRevert("AC:W:COMPOSITE_ASSET_FAILURE");
        bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, emptyPermit());
    }

    function test_syrupBitcoinRouter_deposit_revert_feeTransferFailure() external {
        vm.mockCall(
            address(depositAsset),
            abi.encodeWithSelector(
                IERC20Like.transfer.selector,
                address(treasury),
                0
            ),
            abi.encode(false)
        );

        vm.prank(depositor);
        vm.expectRevert("SBR:D:TRANSFER_FEE_FAILED");
        bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, emptyPermit());
    }

    function test_syrupBitcoinRouter_deposit_revert_poolTransferFailed() external {
        vm.mockCall(
            address(pool),
            abi.encodeWithSelector(
                IERC20Like.transfer.selector,
                depositor,
                depositAmount
            ),
            abi.encode(false)
        );

        vm.prank(depositor);
        vm.expectRevert("SBR:D:FORWARDING_FAILED");
        bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, emptyPermit());
    }

    function test_syrupBitcoinRouter_deposit_success_noPermit_fullApproval() external {
        assertEq(depositAsset.balanceOf(depositor),                depositAmount);
        assertEq(depositAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(pool)),            0);
        assertEq(depositAsset.balanceOf(address(treasury)),        0);

        assertEq(compositeAsset.balanceOf(depositor),                0);
        assertEq(compositeAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);
        assertEq(compositeAsset.balanceOf(address(pool)),            0);

        assertEq(assetController.poolAssets(address(depositAsset)),    0);
        assertEq(assetController.depositAssets(address(depositAsset)), 0);

        assertEq(pool.balanceOf(depositor), 0);

        vm.prank(depositor);
        uint256 sharesMinted = bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, emptyPermit());

        assertEq(sharesMinted, depositAmount);

        assertEq(depositAsset.balanceOf(depositor),                0);
        assertEq(depositAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(depositAsset.balanceOf(address(assetController)), depositAmount);
        assertEq(depositAsset.balanceOf(address(pool)),            0);
        assertEq(depositAsset.balanceOf(address(treasury)),        0);

        assertEq(compositeAsset.balanceOf(depositor),                0);
        assertEq(compositeAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);
        assertEq(compositeAsset.balanceOf(address(pool)),            depositAmount);

        assertEq(assetController.poolAssets(address(depositAsset)),    depositAmount);
        assertEq(assetController.depositAssets(address(depositAsset)), depositAmount);

        assertEq(pool.balanceOf(depositor), depositAmount);
    }

    function test_syrupBitcoinRouter_deposit_success_withMetadata() external {
        bytes32 metadata_ = bytes32(type(uint256).max);

        assertEq(depositAsset.balanceOf(depositor),                depositAmount);
        assertEq(depositAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(pool)),            0);
        assertEq(depositAsset.balanceOf(address(treasury)),        0);

        assertEq(compositeAsset.balanceOf(depositor),                0);
        assertEq(compositeAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);
        assertEq(compositeAsset.balanceOf(address(pool)),            0);

        assertEq(assetController.poolAssets(address(depositAsset)),    0);
        assertEq(assetController.depositAssets(address(depositAsset)), 0);

        assertEq(pool.balanceOf(depositor), 0);

        vm.prank(depositor);
        uint256 sharesMinted_ = bitcoinRouter.deposit(address(depositAsset), depositAmount, metadata_, emptyPermit());

        assertEq(sharesMinted_, depositAmount);

        assertEq(depositAsset.balanceOf(depositor),                0);
        assertEq(depositAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(depositAsset.balanceOf(address(assetController)), depositAmount);
        assertEq(depositAsset.balanceOf(address(pool)),            0);
        assertEq(depositAsset.balanceOf(address(treasury)),        0);

        assertEq(compositeAsset.balanceOf(depositor),                0);
        assertEq(compositeAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);
        assertEq(compositeAsset.balanceOf(address(pool)),            depositAmount);

        assertEq(assetController.poolAssets(address(depositAsset)),    depositAmount);
        assertEq(assetController.depositAssets(address(depositAsset)), depositAmount);

        assertEq(pool.balanceOf(depositor), depositAmount);
    }

    function test_syrupBitcoinRouter_deposit_success_withPermit_noApproval() external {
        Permit memory permit_ =
            signPermit(
                depositorPrivateKey,
                address(depositAsset),
                depositor,
                depositAmount,
                block.timestamp
            );

        vm.prank(depositor);
        depositAsset.approve(address(bitcoinRouter), 0);

        assertEq(depositAsset.allowance(depositor, address(bitcoinRouter)), 0);

        assertEq(depositAsset.balanceOf(depositor),                depositAmount);
        assertEq(depositAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(pool)),            0);
        assertEq(depositAsset.balanceOf(address(treasury)),        0);

        assertEq(compositeAsset.balanceOf(depositor),                0);
        assertEq(compositeAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);
        assertEq(compositeAsset.balanceOf(address(pool)),            0);

        assertEq(assetController.poolAssets(address(depositAsset)),    0);
        assertEq(assetController.depositAssets(address(depositAsset)), 0);

        assertEq(pool.balanceOf(depositor), 0);

        vm.prank(depositor);
        uint256 sharesMinted_ = bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, permit_);

        assertEq(sharesMinted_, depositAmount);

        assertEq(depositAsset.balanceOf(depositor),                0);
        assertEq(depositAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(depositAsset.balanceOf(address(assetController)), depositAmount);
        assertEq(depositAsset.balanceOf(address(pool)),            0);
        assertEq(depositAsset.balanceOf(address(treasury)),        0);

        assertEq(compositeAsset.balanceOf(depositor),                0);
        assertEq(compositeAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);
        assertEq(compositeAsset.balanceOf(address(pool)),            depositAmount);

        assertEq(assetController.poolAssets(address(depositAsset)),    depositAmount);
        assertEq(assetController.depositAssets(address(depositAsset)), depositAmount);

        assertEq(pool.balanceOf(depositor), depositAmount);
    }

    function test_syrupBitcoinRouter_deposit_success_withPermit_and_fullApproval() external {
        Permit memory permit_ =
            signPermit(
                depositorPrivateKey,
                address(depositAsset),
                depositor,
                depositAmount,
                block.timestamp
            );

        assertEq(depositAsset.nonces(address(depositor)), 0);

        assertEq(depositAsset.balanceOf(depositor),                depositAmount);
        assertEq(depositAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(pool)),            0);
        assertEq(depositAsset.balanceOf(address(treasury)),        0);

        assertEq(compositeAsset.balanceOf(depositor),                0);
        assertEq(compositeAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);
        assertEq(compositeAsset.balanceOf(address(pool)),            0);

        assertEq(assetController.poolAssets(address(depositAsset)),    0);
        assertEq(assetController.depositAssets(address(depositAsset)), 0);

        assertEq(pool.balanceOf(depositor), 0);

        vm.prank(depositor);
        uint256 sharesMinted_ = bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, permit_);

        assertEq(depositAsset.nonces(address(depositor)), 0);

        assertEq(sharesMinted_, depositAmount);

        assertEq(depositAsset.balanceOf(depositor),                0);
        assertEq(depositAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(depositAsset.balanceOf(address(assetController)), depositAmount);
        assertEq(depositAsset.balanceOf(address(pool)),            0);
        assertEq(depositAsset.balanceOf(address(treasury)),        0);

        assertEq(compositeAsset.balanceOf(depositor),                0);
        assertEq(compositeAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);
        assertEq(compositeAsset.balanceOf(address(pool)),            depositAmount);

        assertEq(assetController.poolAssets(address(depositAsset)),    depositAmount);
        assertEq(assetController.depositAssets(address(depositAsset)), depositAmount);

        assertEq(pool.balanceOf(depositor), depositAmount);
    }

    function test_syrupBitcoinRouter_deposit_success_withPartialFee_fullApproval() external {
        uint256 mintFee       = 0.15e6;  // 15% Fee
        uint256 redemptionFee = 0;
        uint256 expectedFee   = calculateFee(depositAmount, mintFee);

        vm.prank(governor);
        bitcoinRouter.setFees(address(depositAsset), mintFee, redemptionFee);

        assertEq(depositAsset.balanceOf(depositor),                depositAmount);
        assertEq(depositAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(pool)),            0);
        assertEq(depositAsset.balanceOf(address(treasury)),        0);

        assertEq(compositeAsset.balanceOf(depositor),                0);
        assertEq(compositeAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);
        assertEq(compositeAsset.balanceOf(address(pool)),            0);

        assertEq(assetController.poolAssets(address(depositAsset)),    0);
        assertEq(assetController.depositAssets(address(depositAsset)), 0);

        assertEq(pool.balanceOf(depositor), 0);

        vm.prank(depositor);
        uint256 sharesMinted = bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, emptyPermit());

        assertEq(sharesMinted, depositAmount - expectedFee);

        assertEq(depositAsset.balanceOf(depositor),                0);
        assertEq(depositAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(depositAsset.balanceOf(address(assetController)), depositAmount - expectedFee);
        assertEq(depositAsset.balanceOf(address(pool)),            0);
        assertEq(depositAsset.balanceOf(address(treasury)),        expectedFee);

        assertEq(compositeAsset.balanceOf(depositor),                0);
        assertEq(compositeAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);
        assertEq(compositeAsset.balanceOf(address(pool)),            depositAmount - expectedFee);

        assertEq(assetController.poolAssets(address(depositAsset)),    depositAmount - expectedFee);
        assertEq(assetController.depositAssets(address(depositAsset)), depositAmount - expectedFee);

        assertEq(pool.balanceOf(depositor), depositAmount - expectedFee);
    }

    function test_syrupBitcoinRouter_deposit_success_withFee_changeTreasury() external {
        uint256 mintFee       = 0.15e6;  // 15% Fee
        uint256 redemptionFee = 0;
        uint256 expectedFee   = calculateFee(depositAmount, mintFee);

        address newTreasury   = makeAddr("new_treasury");

        vm.startPrank(governor);
        bitcoinRouter.setFees(address(depositAsset), mintFee, redemptionFee);
        globals.setMapleTreasury(newTreasury);
        vm.stopPrank();

        assertEq(depositAsset.balanceOf(depositor),                depositAmount);
        assertEq(depositAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(pool)),            0);
        assertEq(depositAsset.balanceOf(address(newTreasury)),     0);

        assertEq(compositeAsset.balanceOf(depositor),                0);
        assertEq(compositeAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);
        assertEq(compositeAsset.balanceOf(address(pool)),            0);

        assertEq(assetController.poolAssets(address(depositAsset)),    0);
        assertEq(assetController.depositAssets(address(depositAsset)), 0);

        assertEq(pool.balanceOf(depositor), 0);

        vm.prank(depositor);
        uint256 sharesMinted = bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, emptyPermit());

        assertEq(sharesMinted, depositAmount - expectedFee);

        assertEq(depositAsset.balanceOf(depositor),                0);
        assertEq(depositAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(depositAsset.balanceOf(address(assetController)), depositAmount - expectedFee);
        assertEq(depositAsset.balanceOf(address(pool)),            0);
        assertEq(depositAsset.balanceOf(address(newTreasury)),     expectedFee);

        assertEq(compositeAsset.balanceOf(depositor),                0);
        assertEq(compositeAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);
        assertEq(compositeAsset.balanceOf(address(pool)),            depositAmount - expectedFee);

        assertEq(assetController.poolAssets(address(depositAsset)),    depositAmount - expectedFee);
        assertEq(assetController.depositAssets(address(depositAsset)), depositAmount - expectedFee);

        assertEq(pool.balanceOf(depositor), depositAmount - expectedFee);
    }

    function test_syrupBitcoinRouter_deposit_success_minimumDeposit_zeroFee() external {
        uint256 minimumDepositAmount  = 1;
        uint256 depositorBalance      = depositAsset.balanceOf(depositor);

        assertEq(depositAsset.balanceOf(depositor),                depositorBalance);
        assertEq(depositAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(pool)),            0);
        assertEq(depositAsset.balanceOf(address(treasury)),        0);

        assertEq(compositeAsset.balanceOf(depositor),                0);
        assertEq(compositeAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);
        assertEq(compositeAsset.balanceOf(address(pool)),            0);

        assertEq(assetController.poolAssets(address(depositAsset)),    0);
        assertEq(assetController.depositAssets(address(depositAsset)), 0);

        assertEq(pool.balanceOf(depositor), 0);

        vm.prank(depositor);
        uint256 sharesMinted = bitcoinRouter.deposit(address(depositAsset), minimumDepositAmount, EMPTY_METADATA, emptyPermit());

        assertEq(sharesMinted, minimumDepositAmount);

        assertEq(depositAsset.balanceOf(depositor),                depositorBalance - minimumDepositAmount);
        assertEq(depositAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(depositAsset.balanceOf(address(assetController)), minimumDepositAmount);
        assertEq(depositAsset.balanceOf(address(pool)),            0);
        assertEq(depositAsset.balanceOf(address(treasury)),        0);

        assertEq(compositeAsset.balanceOf(depositor),                0);
        assertEq(compositeAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);
        assertEq(compositeAsset.balanceOf(address(pool)),            minimumDepositAmount);

        assertEq(assetController.poolAssets(address(depositAsset)),    minimumDepositAmount);
        assertEq(assetController.depositAssets(address(depositAsset)), minimumDepositAmount);

        assertEq(pool.balanceOf(depositor), minimumDepositAmount);
    }

    function test_syrupBitcoinRouter_deposit_success_minimumDeposit_withFeeRoundedDown() external {
        uint256 minimumDepositAmount = 1;
        uint256 depositorBalance     = depositAsset.balanceOf(depositor);
        uint256 mintFee              = 0.15e6;  // 15% Fee
        uint256 redemptionFee        = 0;
        uint256 expectedFee          = calculateFee(minimumDepositAmount, mintFee);

        assertEq(expectedFee, 0);

        vm.startPrank(governor);
        bitcoinRouter.setFees(address(depositAsset), mintFee, redemptionFee);
        vm.stopPrank();

        assertEq(depositAsset.balanceOf(depositor),                depositorBalance);
        assertEq(depositAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(pool)),            0);
        assertEq(depositAsset.balanceOf(address(treasury)),        0);

        assertEq(compositeAsset.balanceOf(depositor),                0);
        assertEq(compositeAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);
        assertEq(compositeAsset.balanceOf(address(pool)),            0);

        assertEq(assetController.poolAssets(address(depositAsset)),    0);
        assertEq(assetController.depositAssets(address(depositAsset)), 0);

        assertEq(pool.balanceOf(depositor), 0);

        vm.prank(depositor);
        uint256 sharesMinted_ = bitcoinRouter.deposit(address(depositAsset), minimumDepositAmount, EMPTY_METADATA, emptyPermit());

        assertEq(sharesMinted_, minimumDepositAmount);

        assertEq(depositAsset.balanceOf(depositor),                depositorBalance - minimumDepositAmount);
        assertEq(depositAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(depositAsset.balanceOf(address(assetController)), minimumDepositAmount);
        assertEq(depositAsset.balanceOf(address(pool)),            0);
        assertEq(depositAsset.balanceOf(address(treasury)),        expectedFee);

        assertEq(compositeAsset.balanceOf(depositor),                0);
        assertEq(compositeAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);
        assertEq(compositeAsset.balanceOf(address(pool)),            minimumDepositAmount);

        assertEq(assetController.poolAssets(address(depositAsset)),    minimumDepositAmount);
        assertEq(assetController.depositAssets(address(depositAsset)), minimumDepositAmount);

        assertEq(pool.balanceOf(depositor), minimumDepositAmount);
    }

    function test_syrupBitcoinRouter_deposit_success_differentShareMintRatio() external {
        address otherDepositor      = makeAddr("other_depositor");
        uint256 otherDepositAmount  = 10e8;
        uint256 topUp               = 5e8;

        depositAsset.mint(otherDepositor, otherDepositAmount);

        vm.startPrank(otherDepositor);

        depositAsset.approve(address(bitcoinRouter), otherDepositAmount);

        uint256 otherDepositorShares =
            bitcoinRouter.deposit(
                address(depositAsset),
                otherDepositAmount,
                EMPTY_METADATA,
                emptyPermit()
            );

        vm.stopPrank();

        assertEq(otherDepositorShares, otherDepositAmount);

        // Change exchange rate by increasing totalAssets without minting shares
        vm.prank(address(assetController));
        compositeAsset.mint(address(pool), topUp);

        uint256 previewShares = pool.previewDeposit(depositAmount);

        assertLt(previewShares, depositAmount);

        uint256 totalSupply    = pool.totalSupply();
        uint256 totalAssets    = pool.totalAssets();
        uint256 expectedShares = (depositAmount * totalSupply) / totalAssets;

        assertEq(previewShares, expectedShares);

        assertEq(depositAsset.balanceOf(depositor),                depositAmount);
        assertEq(depositAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(depositAsset.balanceOf(address(assetController)), otherDepositAmount);
        assertEq(depositAsset.balanceOf(address(pool)),            0);
        assertEq(depositAsset.balanceOf(address(treasury)),        0);

        assertEq(compositeAsset.balanceOf(depositor),                0);
        assertEq(compositeAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);
        assertEq(compositeAsset.balanceOf(address(pool)),            otherDepositorShares + topUp);

        assertEq(assetController.poolAssets(address(depositAsset)),    otherDepositAmount);
        assertEq(assetController.depositAssets(address(depositAsset)), otherDepositAmount);

        assertEq(pool.balanceOf(depositor), 0);

        vm.prank(depositor);
        uint256 sharesMinted = bitcoinRouter.deposit(address(depositAsset), depositAmount, EMPTY_METADATA, emptyPermit());

        assertEq(sharesMinted, previewShares);

        assertEq(depositAsset.balanceOf(depositor),                0);
        assertEq(depositAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(depositAsset.balanceOf(address(assetController)), otherDepositAmount + depositAmount);
        assertEq(depositAsset.balanceOf(address(pool)),            0);
        assertEq(depositAsset.balanceOf(address(treasury)),        0);

        assertEq(compositeAsset.balanceOf(depositor),                0);
        assertEq(compositeAsset.balanceOf(address(bitcoinRouter)),   0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);
        assertEq(compositeAsset.balanceOf(address(pool)),            otherDepositorShares + topUp + depositAmount);

        assertEq(assetController.poolAssets(address(depositAsset)),    otherDepositAmount + depositAmount);
        assertEq(assetController.depositAssets(address(depositAsset)), otherDepositAmount + depositAmount);

        assertEq(pool.balanceOf(depositor), sharesMinted);

        assertLt(sharesMinted, depositAmount);
    }

}
