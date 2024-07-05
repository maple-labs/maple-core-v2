// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Vm } from "../../../modules/forge-std/src/Vm.sol";

import { SyrupRouter } from "../../../modules/syrup-utils/contracts/SyrupRouter.sol";

import { TestBase } from "../../TestBase.sol";

contract SyrupRouterDepositsIntegrationTests is TestBase {

    uint256 constant FUNCTION_LEVEL = 1;
    uint256 constant POOL_LEVEL     = 2;

    address liquidityProvider = makeAddr("liquidityProvider");

    bytes32 functionId = "P:deposit";

    uint256 depositAmount = 100_000e6;

    uint256 insufficientBitmap = 0x1;  // 0b0001
    uint256 requiredBitmap     = 0x3;  // 0b0011
    uint256 sufficientBitmap   = 0xB;  // 0b1011
    uint256 zeroBitmap         = 0x0;  // 0b0000

    SyrupRouter public syrupRouter;

    Vm.Wallet liquidityProviderWallet;

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

        liquidityProviderWallet = vm.createWallet("liquidityProvider");

        allowLender(address(poolManager), address(syrupRouter));
    }

    /**************************************************************************************************************************************/
    /*** Private Pool - Router Tests                                                                                                    ***/
    /**************************************************************************************************************************************/

    function test_deposit_private_unauthorized() external {
        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        syrupRouter.deposit(depositAmount, bytes32(0));
    }

    function test_depositWithPermit_private_unauthorized() external {
        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        syrupRouter.depositWithPermit(depositAmount, block.timestamp, v, r, s, bytes32(0));
    }

    function test_deposit_private_insufficientApproval() external {
        allowLender(address(poolManager), liquidityProvider);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount - 1);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:TRANSFER_FROM_FAIL");
        syrupRouter.deposit(depositAmount, bytes32(0));
    }

    function test_deposit_private_insufficientAmount() external {
        allowLender(address(poolManager), liquidityProvider);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount - 1);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:TRANSFER_FROM_FAIL");
        syrupRouter.deposit(depositAmount, bytes32(0));
    }

    function test_depositWithPermit_private_invalidSignature() external {
        allowLender(address(poolManager), liquidityProvider);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp - 1 seconds // Different signature
            )
        );

        vm.prank(liquidityProvider);
        vm.expectRevert("ERC20:P:INVALID_SIGNATURE");
        syrupRouter.depositWithPermit(depositAmount, block.timestamp, v, r, s, bytes32(0));
    }

    function test_depositWithPermit_private_expiredDeadline() external {
        allowLender(address(poolManager), liquidityProvider);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp - 2 seconds
            )
        );

        vm.prank(liquidityProvider);
        vm.expectRevert("ERC20:P:EXPIRED");
        syrupRouter.depositWithPermit(depositAmount, block.timestamp - 2 seconds, v, r, s, bytes32(0));
    }

    function test_deposit_private_zeroShares() external {
        allowLender(address(poolManager), liquidityProvider);

        vm.prank(liquidityProvider);
        vm.expectRevert("P:M:ZERO_SHARES");
        syrupRouter.deposit(0, bytes32(0));
    }

    function test_depositWithPermit_private_zeroShares() external {
        allowLender(address(poolManager), liquidityProvider);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                0,
                block.timestamp
            )
        );

        vm.prank(liquidityProvider);
        vm.expectRevert("P:M:ZERO_SHARES");
        syrupRouter.depositWithPermit(0, block.timestamp, v, r, s, bytes32(0));
    }

    function test_deposit_private_approval() external {
        allowLender(address(poolManager), liquidityProvider);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        vm.prank(liquidityProvider);
        syrupRouter.deposit(depositAmount, bytes32(0));

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    function test_deposit_private_infiniteApproval() external {
        allowLender(address(poolManager), liquidityProvider);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), type(uint256).max);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        vm.prank(liquidityProvider);
        syrupRouter.deposit(depositAmount, bytes32(0));

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    function test_depositWithPermit_private_allowListed() external {
        allowLender(address(poolManager), liquidityProvider);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        vm.prank(liquidityProvider);
        syrupRouter.depositWithPermit(depositAmount, block.timestamp, v, r, s, bytes32(0));

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    /**************************************************************************************************************************************/
    /*** Function Level Pool - Router Tests                                                                                             ***/
    /**************************************************************************************************************************************/

    function test_deposit_functionLevel_zeroBitmap() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, zeroBitmap);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        syrupRouter.deposit(depositAmount, bytes32(0));
    }

    function test_depositWithPermit_functionLevel_zeroBitmap() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, zeroBitmap);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        syrupRouter.depositWithPermit(depositAmount, block.timestamp, v, r, s, bytes32(0));
    }

    function test_deposit_functionLevel_insufficientPermission() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, insufficientBitmap);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        syrupRouter.deposit(depositAmount, bytes32(0));
    }

    function test_depositWithPermit_functionLevel_insufficientPermission() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, insufficientBitmap);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        syrupRouter.depositWithPermit(depositAmount, block.timestamp, v, r, s, bytes32(0));
    }

    function test_deposit_functionLevel_insufficientApproval() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount - 1);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:TRANSFER_FROM_FAIL");
        syrupRouter.deposit(depositAmount, bytes32(0));
    }

    function test_deposit_functionLevel_insufficientAmount() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount - 1);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:TRANSFER_FROM_FAIL");
        syrupRouter.deposit(depositAmount, bytes32(0));
    }

    function test_depositWithPermit_functionLevel_invalidSignature() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp - 1 seconds  // Different signature
            )
        );

        vm.prank(liquidityProvider);
        vm.expectRevert("ERC20:P:INVALID_SIGNATURE");
        syrupRouter.depositWithPermit(depositAmount, block.timestamp, v, r, s, bytes32(0));
    }

    function test_depositWithPermit_functionLevel_expiredDeadline() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp - 2 seconds
            )
        );

        vm.prank(liquidityProvider);
        vm.expectRevert("ERC20:P:EXPIRED");
        syrupRouter.depositWithPermit(depositAmount, block.timestamp - 2 seconds, v, r, s, bytes32(0));
    }

    function test_deposit_functionLevel_zeroShares() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        vm.prank(liquidityProvider);
        vm.expectRevert("P:M:ZERO_SHARES");
        syrupRouter.deposit(0, bytes32(0));
    }

    function test_depositWithPermit_functionLevel_zeroShares() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                0,
                block.timestamp
            )
        );

        vm.prank(liquidityProvider);
        vm.expectRevert("P:M:ZERO_SHARES");
        syrupRouter.depositWithPermit(0, block.timestamp, v, r, s, bytes32(0));
    }

    function test_deposit_functionLevel_approval() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        vm.prank(liquidityProvider);
        syrupRouter.deposit(depositAmount, bytes32(0));

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    function test_deposit_functionLevel_infiniteApproval() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), type(uint256).max);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        vm.prank(liquidityProvider);
        syrupRouter.deposit(depositAmount, bytes32(0));

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    function test_depositWithPermit_functionLevel_sufficientPermission() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        vm.prank(liquidityProvider);
        syrupRouter.depositWithPermit(depositAmount, block.timestamp, v, r, s, bytes32(0));

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    function test_deposit_functionLevel_allowlisted() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        allowLender(address(poolManager), liquidityProvider);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), type(uint256).max);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        vm.prank(liquidityProvider);
        syrupRouter.deposit(depositAmount, bytes32(0));

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    function test_depositWithPermit_functionLevel_allowListed() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        allowLender(address(poolManager), liquidityProvider);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        vm.prank(liquidityProvider);
        syrupRouter.depositWithPermit(depositAmount, block.timestamp, v, r, s, bytes32(0));

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    /**************************************************************************************************************************************/
    /*** Pool Level Pool - Router Tests                                                                                                 ***/
    /**************************************************************************************************************************************/

    function test_deposit_poolLevel_zeroBitmap() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, zeroBitmap);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        syrupRouter.deposit(depositAmount, bytes32(0));
    }

    function test_depositWithPermit_poolLevel_zeroBitmap() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, zeroBitmap);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        syrupRouter.depositWithPermit(depositAmount, block.timestamp, v, r, s, bytes32(0));
    }

    function test_deposit_poolLevel_insufficientPermission() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, insufficientBitmap);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        syrupRouter.deposit(depositAmount, bytes32(0));
    }

    function test_depositWithPermit_poolLevel_insufficientPermission() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, insufficientBitmap);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        syrupRouter.depositWithPermit(depositAmount, block.timestamp, v, r, s, bytes32(0));
    }

    function test_deposit_poolLevel_insufficientApproval() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount - 1);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:TRANSFER_FROM_FAIL");
        syrupRouter.deposit(depositAmount, bytes32(0));
    }

    function test_deposit_poolLevel_insufficientAmount() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount - 1);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:TRANSFER_FROM_FAIL");
        syrupRouter.deposit(depositAmount, bytes32(0));
    }

    function test_depositWithPermit_poolLevel_invalidSignature() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp - 1 seconds  // Different signature
            )
        );

        vm.prank(liquidityProvider);
        vm.expectRevert("ERC20:P:INVALID_SIGNATURE");
        syrupRouter.depositWithPermit(depositAmount, block.timestamp, v, r, s, bytes32(0));
    }

    function test_depositWithPermit_poolLevel_expiredDeadline() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp - 2 seconds
            )
        );

        vm.prank(liquidityProvider);
        vm.expectRevert("ERC20:P:EXPIRED");
        syrupRouter.depositWithPermit(depositAmount, block.timestamp - 2 seconds, v, r, s, bytes32(0));
    }

    function test_deposit_poolLevel_zeroShares() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        vm.prank(liquidityProvider);
        vm.expectRevert("P:M:ZERO_SHARES");
        syrupRouter.deposit(0, bytes32(0));
    }

    function test_depositWithPermit_poolLevel_zeroShares() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                0,
                block.timestamp
            )
        );

        vm.prank(liquidityProvider);
        vm.expectRevert("P:M:ZERO_SHARES");
        syrupRouter.depositWithPermit(0, block.timestamp, v, r, s, bytes32(0));
    }

    function test_deposit_poolLevel_approval() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        vm.prank(liquidityProvider);
        syrupRouter.deposit(depositAmount, bytes32(0));

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    function test_deposit_poolLevel_infiniteApproval() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), type(uint256).max);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        vm.prank(liquidityProvider);
        syrupRouter.deposit(depositAmount, bytes32(0));

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    function test_depositWithPermit_poolLevel_sufficientPermission() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        vm.prank(liquidityProvider);
        syrupRouter.depositWithPermit(depositAmount, block.timestamp, v, r, s, bytes32(0));

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    function test_deposit_poolLevel_allowlisted() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        allowLender(address(poolManager), liquidityProvider);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), type(uint256).max);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        vm.prank(liquidityProvider);
        syrupRouter.deposit(depositAmount, bytes32(0));

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    function test_depositWithPermit_poolLevel_allowListed() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        allowLender(address(poolManager), liquidityProvider);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        vm.prank(liquidityProvider);
        syrupRouter.depositWithPermit(depositAmount, block.timestamp, v, r, s, bytes32(0));

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    /**************************************************************************************************************************************/
    /*** Public Pool - Router Tests                                                                                                     ***/
    /**************************************************************************************************************************************/

    function test_deposit_public_insufficientApproval() external {
        openPool(address(poolManager));

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount - 1);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:TRANSFER_FROM_FAIL");
        syrupRouter.deposit(depositAmount, bytes32(0));
    }

    function test_deposit_public_insufficientAmount() external {
        openPool(address(poolManager));

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount - 1);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:TRANSFER_FROM_FAIL");
        syrupRouter.deposit(depositAmount, bytes32(0));
    }

    function test_depositWithPermit_public_invalidSignature() external {
        openPool(address(poolManager));

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp - 1 seconds  // Different signature
            )
        );

        vm.prank(liquidityProvider);
        vm.expectRevert("ERC20:P:INVALID_SIGNATURE");
        syrupRouter.depositWithPermit(depositAmount, block.timestamp, v, r, s, bytes32(0));
    }

    function test_depositWithPermit_public_expiredDeadline() external {
        openPool(address(poolManager));

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp - 2 seconds
            )
        );

        vm.prank(liquidityProvider);
        vm.expectRevert("ERC20:P:EXPIRED");
        syrupRouter.depositWithPermit(depositAmount, block.timestamp - 2 seconds, v, r, s, bytes32(0));
    }

    function test_deposit_public_zeroShares() external {
        openPool(address(poolManager));

        vm.prank(liquidityProvider);
        vm.expectRevert("P:M:ZERO_SHARES");
        syrupRouter.deposit(0, bytes32(0));
    }

    function test_depositWithPermit_public_zeroShares() external {
        openPool(address(poolManager));

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                0,
                block.timestamp
            )
        );

        vm.prank(liquidityProvider);
        vm.expectRevert("P:M:ZERO_SHARES");
        syrupRouter.depositWithPermit(0, block.timestamp, v, r, s, bytes32(0));
    }

    function test_deposit_public_approval() external {
        openPool(address(poolManager));

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        vm.prank(liquidityProvider);
        syrupRouter.deposit(depositAmount, bytes32(0));

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    function test_deposit_public_infiniteApproval() external {
        openPool(address(poolManager));

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), type(uint256).max);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        vm.prank(liquidityProvider);
        syrupRouter.deposit(depositAmount, bytes32(0));

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    function test_depositWithPermit_public_success() external {
        openPool(address(poolManager));

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        vm.prank(liquidityProvider);
        syrupRouter.depositWithPermit(depositAmount, block.timestamp, v, r, s, bytes32(0));

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

}


contract SyrupRouterAuthorizeAndDepositTests is TestBase {
    uint256 constant POOL_LEVEL = 2;

    address liquidityProvider = makeAddr("liquidityProvider");
    address ppa               = makeAddr("permissionAdmin");

    bytes32 functionId = "P:deposit";

    uint256 depositAmount = 100_000e6;

    uint256 requiredBitmap     = 0x3;  // 0b0011
    uint256 sufficientBitmap   = 0xB;  // 0b1011

    uint256 authDeadline = block.timestamp;

    SyrupRouter public syrupRouter;

    Vm.Wallet liquidityProviderWallet;
    Vm.Wallet ppaWallet;

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

        liquidityProviderWallet = vm.createWallet("liquidityProvider");
        ppaWallet               = vm.createWallet("permissionAdmin");

        allowLender(address(poolManager), address(syrupRouter));

        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        vm.startPrank(governor);
        poolPermissionManager.setPermissionAdmin(ppa, true);
        poolPermissionManager.setPermissionAdmin(address(syrupRouter), true);
        vm.stopPrank();

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);
    }

    /**************************************************************************************************************************************/
    /*** Authorize and Deposit                                                                                                          ***/
    /**************************************************************************************************************************************/

    function test_authorizeAndDeposit_expiredDeadline() external {
        authDeadline = block.timestamp - 1;

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:A:EXPIRED");
        syrupRouter.authorizeAndDeposit(sufficientBitmap, authDeadline, 0, bytes32(0), bytes32(0), depositAmount, bytes32(0));
    }

    function test_authorizeAndDeposit_malleable() external {
        uint8 v = 2;

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:A:MALLEABLE");
        syrupRouter.authorizeAndDeposit(sufficientBitmap, authDeadline, v, bytes32(0), bytes32(0), depositAmount, bytes32(0));
    }

    function test_authorizeAndDeposit_notPermissionAdmin() external {
        vm.prank(governor);
        poolPermissionManager.setPermissionAdmin(ppa, false);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(ppaWallet, _getAuthDigest(
            address(syrupRouter), liquidityProvider, sufficientBitmap, authDeadline)
        );

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:A:NOT_PERMISSION_ADMIN");
        syrupRouter.authorizeAndDeposit(sufficientBitmap, authDeadline, v, r, s, depositAmount, bytes32(0));
    }

    function test_authorizeAndDeposit_repeatedNonce() external {
        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(ppaWallet, _getAuthDigest(
            address(syrupRouter), liquidityProvider, sufficientBitmap, authDeadline)
        );

        // First transaction goes through
        vm.prank(liquidityProvider);
        syrupRouter.authorizeAndDeposit(sufficientBitmap, authDeadline, v, r, s, depositAmount, bytes32(0));

        // Second transaction with the same nonce fails
        vm.prank(liquidityProvider);
        vm.expectRevert("SR:A:NOT_PERMISSION_ADMIN");
        syrupRouter.authorizeAndDeposit(sufficientBitmap, authDeadline, v, r, s, depositAmount, bytes32(0));
    }

    function test_authorizeAndDeposit_success() external {
        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(ppaWallet, _getAuthDigest(
            address(syrupRouter), liquidityProvider, sufficientBitmap, authDeadline)
        );

        vm.prank(liquidityProvider);
        syrupRouter.authorizeAndDeposit(sufficientBitmap, authDeadline, v, r, s, depositAmount, bytes32(0));

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);

        assertEq(poolPermissionManager.lenderBitmaps(liquidityProvider), sufficientBitmap);
    }

    /**************************************************************************************************************************************/
    /*** Authorize and Deposit with Permit                                                                                              ***/
    /**************************************************************************************************************************************/

    function test_authorizeAndDepositWithPermit_expiredDeadline() external {
        authDeadline = block.timestamp - 1;

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:A:EXPIRED");
        syrupRouter.authorizeAndDepositWithPermit(
            sufficientBitmap, authDeadline, 0, bytes32(0), bytes32(0), depositAmount, bytes32(0), block.timestamp, 0, bytes32(0), bytes32(0)
        );
    }

    function test_authorizeAndDepositWithPermit_malleable() external {
        uint8 v = 2;

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:A:MALLEABLE");
        syrupRouter.authorizeAndDepositWithPermit(
            sufficientBitmap, authDeadline, v, bytes32(0), bytes32(0), depositAmount, bytes32(0), block.timestamp, 0, bytes32(0), bytes32(0)
        );
    }

    function test_authorizeAndDepositWithPermit_notPermissionAdmin() external {
        vm.prank(governor);
        poolPermissionManager.setPermissionAdmin(ppa, false);

        (uint8 v, bytes32 r, bytes32 s ) = vm.sign(ppaWallet, _getAuthDigest(
            address(syrupRouter), liquidityProvider, sufficientBitmap, authDeadline)
        );

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:A:NOT_PERMISSION_ADMIN");
        syrupRouter.authorizeAndDepositWithPermit(
            sufficientBitmap, authDeadline, v, s, r, depositAmount, bytes32(0), block.timestamp, 0, bytes32(0), bytes32(0)
        );
    }

    function test_authorizeAndDepositWithPermit_repeatedNonce() external {
        (uint8 auth_v, bytes32 auth_r, bytes32 auth_s ) = vm.sign(ppaWallet, _getAuthDigest(
            address(syrupRouter), liquidityProvider, sufficientBitmap, authDeadline)
        );

        (uint8 permit_v, bytes32 permit_r, bytes32 permit_s) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        // First transaction succeeds
        vm.prank(liquidityProvider);
        syrupRouter.authorizeAndDepositWithPermit(
            sufficientBitmap,
            authDeadline,
            auth_v,
            auth_r,
            auth_s,
            depositAmount,
            bytes32(0),
            block.timestamp,
            permit_v,
            permit_r,
            permit_s
        );

        // Second transaction with the same nonce fails
        vm.prank(liquidityProvider);
        vm.expectRevert("SR:A:NOT_PERMISSION_ADMIN");
        syrupRouter.authorizeAndDepositWithPermit(
            sufficientBitmap,
            authDeadline,
            auth_v,
            auth_r,
            auth_s,
            depositAmount,
            bytes32(0),
            block.timestamp,
            permit_v,
            permit_r,
            permit_s
        );
    }

    function test_authorizeAndDepositWithPermit_success() external {

        (uint8 auth_v, bytes32 auth_r, bytes32 auth_s ) = vm.sign(ppaWallet, _getAuthDigest(
            address(syrupRouter), liquidityProvider, sufficientBitmap, authDeadline)
        );

        (uint8 permit_v, bytes32 permit_r, bytes32 permit_s) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        vm.prank(liquidityProvider);
        syrupRouter.authorizeAndDepositWithPermit(
            sufficientBitmap,
            authDeadline,
            auth_v,
            auth_r,
            auth_s,
            depositAmount,
            bytes32(0),
            block.timestamp,
            permit_v,
            permit_r,
            permit_s
        );

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);

        assertEq(poolPermissionManager.lenderBitmaps(liquidityProvider), sufficientBitmap);
    }

    /**************************************************************************************************************************************/
    /*** Helper                                                                                                                         ***/
    /**************************************************************************************************************************************/

    function _getAuthDigest(address router_, address owner_, uint256 bitmap_, uint256 deadline_)
        internal view returns (bytes32 digest_)
    {
        return keccak256(abi.encodePacked(
            '\x19\x01',
            block.chainid,
            router_,
            owner_,
            SyrupRouter(router_).nonces(owner_),
            bitmap_,
            deadline_
        ));
    }

}
