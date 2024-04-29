// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Vm } from "../../../modules/forge-std/src/Vm.sol";

import { SyrupRouter } from "../../../modules/syrup-router/contracts/SyrupRouter.sol";

import { TestBase } from "../../TestBase.sol";

contract SyrupRouterIntegrationTests is TestBase {

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
        syrupRouter.deposit(depositAmount);
    }

    function test_depositWithPermit_private_unauthorized() external {
        (uint8 v , bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        syrupRouter.depositWithPermit(liquidityProviderWallet.addr, depositAmount, block.timestamp, v, r, s);
    }

    function test_deposit_private_insufficientApproval() external {
        allowLender(address(poolManager), liquidityProvider);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount - 1);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:TRANSFER_FROM_FAIL");
        syrupRouter.deposit(depositAmount);
    }

    function test_deposit_private_insufficientAmount() external {
        allowLender(address(poolManager), liquidityProvider);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount - 1);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:TRANSFER_FROM_FAIL");
        syrupRouter.deposit(depositAmount);
    }

    function test_depositWithPermit_private_invalidSignature() external {
        allowLender(address(poolManager), liquidityProvider);

        (uint8 v , bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp - 1 seconds // Different signature
            )
        );

        vm.expectRevert("ERC20:P:INVALID_SIGNATURE");
        syrupRouter.depositWithPermit(liquidityProviderWallet.addr, depositAmount, block.timestamp, v, r, s);
    }

    function test_depositWithPermit_private_expiredDeadline() external {
        allowLender(address(poolManager), liquidityProvider);

        (uint8 v , bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp - 2 seconds
            )
        );

        vm.expectRevert("ERC20:P:EXPIRED");
        syrupRouter.depositWithPermit(liquidityProviderWallet.addr, depositAmount, block.timestamp - 2 seconds, v, r, s);
    }

    function test_deposit_private_zeroShares() external {
        allowLender(address(poolManager), liquidityProvider);

        vm.prank(liquidityProvider);
        vm.expectRevert("P:M:ZERO_SHARES");
        syrupRouter.deposit(0);
    }

    function test_depositWithPermit_private_zeroShares() external {
        allowLender(address(poolManager), liquidityProvider);

        (uint8 v , bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                0,
                block.timestamp
            )
        );

        vm.expectRevert("P:M:ZERO_SHARES");
        syrupRouter.depositWithPermit(liquidityProviderWallet.addr, 0, block.timestamp, v, r, s);
    }

    function test_deposit_private_approval() external {
        allowLender(address(poolManager), liquidityProvider);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        vm.prank(liquidityProvider);
        syrupRouter.deposit(depositAmount);

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
        syrupRouter.deposit(depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    function test_depositWithPermit_private_allowListed() external {
        allowLender(address(poolManager), liquidityProvider);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        (uint8 v , bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        syrupRouter.depositWithPermit(liquidityProviderWallet.addr, depositAmount, block.timestamp, v, r, s);

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
        syrupRouter.deposit(depositAmount);
    }

    function test_depositWithPermit_functionLevel_zeroBitmap() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, zeroBitmap);

        (uint8 v , bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        syrupRouter.depositWithPermit(liquidityProviderWallet.addr, depositAmount, block.timestamp, v, r, s);
    }

    function test_deposit_functionLevel_insufficientPermission() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, insufficientBitmap);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        syrupRouter.deposit(depositAmount);
    }

    function test_depositWithPermit_functionLevel_insufficientPermission() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, insufficientBitmap);

        (uint8 v , bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        syrupRouter.depositWithPermit(liquidityProviderWallet.addr, depositAmount, block.timestamp, v, r, s);
    }

    function test_deposit_functionLevel_insufficientApproval() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount - 1);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:TRANSFER_FROM_FAIL");
        syrupRouter.deposit(depositAmount);
    }

    function test_deposit_functionLevel_insufficientAmount() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount - 1);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:TRANSFER_FROM_FAIL");
        syrupRouter.deposit(depositAmount);
    }

    function test_depositWithPermit_functionLevel_invalidSignature() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        (uint8 v , bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp - 1 seconds  // Different signature
            )
        );

        vm.expectRevert("ERC20:P:INVALID_SIGNATURE");
        syrupRouter.depositWithPermit(liquidityProviderWallet.addr, depositAmount, block.timestamp, v, r, s);
    }

    function test_depositWithPermit_functionLevel_expiredDeadline() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        (uint8 v , bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp - 2 seconds
            )
        );

        vm.expectRevert("ERC20:P:EXPIRED");
        syrupRouter.depositWithPermit(liquidityProviderWallet.addr, depositAmount, block.timestamp - 2 seconds, v, r, s);
    }

    function test_deposit_functionLevel_zeroShares() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        vm.prank(liquidityProvider);
        vm.expectRevert("P:M:ZERO_SHARES");
        syrupRouter.deposit(0);
    }

    function test_depositWithPermit_functionLevel_zeroShares() external {
        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), functionId, requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        (uint8 v , bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                0,
                block.timestamp
            )
        );

        vm.expectRevert("P:M:ZERO_SHARES");
        syrupRouter.depositWithPermit(liquidityProviderWallet.addr, 0, block.timestamp, v, r, s);
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
        syrupRouter.deposit(depositAmount);

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
        syrupRouter.deposit(depositAmount);

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

        (uint8 v , bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        syrupRouter.depositWithPermit(liquidityProviderWallet.addr, depositAmount, block.timestamp, v, r, s);

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
        syrupRouter.deposit(depositAmount);

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

        (uint8 v , bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        syrupRouter.depositWithPermit(liquidityProviderWallet.addr, depositAmount, block.timestamp, v, r, s);

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
        syrupRouter.deposit(depositAmount);
    }

    function test_depositWithPermit_poolLevel_zeroBitmap() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, zeroBitmap);

        (uint8 v , bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        syrupRouter.depositWithPermit(liquidityProviderWallet.addr, depositAmount, block.timestamp, v, r, s);
    }

    function test_deposit_poolLevel_insufficientPermission() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, insufficientBitmap);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        syrupRouter.deposit(depositAmount);
    }

    function test_depositWithPermit_poolLevel_insufficientPermission() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, insufficientBitmap);

        (uint8 v , bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        syrupRouter.depositWithPermit(liquidityProviderWallet.addr, depositAmount, block.timestamp, v, r, s);
    }

    function test_deposit_poolLevel_insufficientApproval() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount - 1);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:TRANSFER_FROM_FAIL");
        syrupRouter.deposit(depositAmount);
    }

    function test_deposit_poolLevel_insufficientAmount() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount - 1);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:TRANSFER_FROM_FAIL");
        syrupRouter.deposit(depositAmount);
    }

    function test_depositWithPermit_poolLevel_invalidSignature() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        (uint8 v , bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp - 1 seconds  // Different signature
            )
        );

        vm.expectRevert("ERC20:P:INVALID_SIGNATURE");
        syrupRouter.depositWithPermit(liquidityProviderWallet.addr, depositAmount, block.timestamp, v, r, s);
    }

    function test_depositWithPermit_poolLevel_expiredDeadline() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        (uint8 v , bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp - 2 seconds
            )
        );

        vm.expectRevert("ERC20:P:EXPIRED");
        syrupRouter.depositWithPermit(liquidityProviderWallet.addr, depositAmount, block.timestamp - 2 seconds, v, r, s);
    }

    function test_deposit_poolLevel_zeroShares() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        vm.prank(liquidityProvider);
        vm.expectRevert("P:M:ZERO_SHARES");
        syrupRouter.deposit(0);
    }

    function test_depositWithPermit_poolLevel_zeroShares() external {
        setPoolPermissionLevel(address(poolManager), POOL_LEVEL);
        setPoolBitmap(address(poolManager), requiredBitmap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, liquidityProvider, sufficientBitmap);

        (uint8 v , bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                0,
                block.timestamp
            )
        );

        vm.expectRevert("P:M:ZERO_SHARES");
        syrupRouter.depositWithPermit(liquidityProviderWallet.addr, 0, block.timestamp, v, r, s);
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
        syrupRouter.deposit(depositAmount);

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
        syrupRouter.deposit(depositAmount);

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

        (uint8 v , bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        syrupRouter.depositWithPermit(liquidityProviderWallet.addr, depositAmount, block.timestamp, v, r, s);

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
        syrupRouter.deposit(depositAmount);

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

        (uint8 v , bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        syrupRouter.depositWithPermit(liquidityProviderWallet.addr, depositAmount, block.timestamp, v, r, s);

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
        syrupRouter.deposit(depositAmount);
    }

    function test_deposit_public_insufficientAmount() external {
        openPool(address(poolManager));

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount - 1);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);

        vm.prank(liquidityProvider);
        vm.expectRevert("SR:D:TRANSFER_FROM_FAIL");
        syrupRouter.deposit(depositAmount);
    }

    function test_depositWithPermit_public_invalidSignature() external {
        openPool(address(poolManager));

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);

        (uint8 v , bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp - 1 seconds  // Different signature
            )
        );

        vm.expectRevert("ERC20:P:INVALID_SIGNATURE");
        syrupRouter.depositWithPermit(liquidityProviderWallet.addr, depositAmount, block.timestamp, v, r, s);
    }

    function test_depositWithPermit_public_expiredDeadline() external {
        openPool(address(poolManager));

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);

        (uint8 v , bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp - 2 seconds
            )
        );

        vm.expectRevert("ERC20:P:EXPIRED");
        syrupRouter.depositWithPermit(liquidityProviderWallet.addr, depositAmount, block.timestamp - 2 seconds, v, r, s);
    }

    function test_deposit_public_zeroShares() external {
        openPool(address(poolManager));

        vm.prank(liquidityProvider);
        vm.expectRevert("P:M:ZERO_SHARES");
        syrupRouter.deposit(0);
    }

    function test_depositWithPermit_public_zeroShares() external {
        openPool(address(poolManager));

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);

        (uint8 v , bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                0,
                block.timestamp
            )
        );

        vm.expectRevert("P:M:ZERO_SHARES");
        syrupRouter.depositWithPermit(liquidityProviderWallet.addr, 0, block.timestamp, v, r, s);
    }

    function test_deposit_public_approval() external {
        openPool(address(poolManager));

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);
        erc20_approve(address(fundsAsset), liquidityProvider, address(syrupRouter), depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        vm.prank(liquidityProvider);
        syrupRouter.deposit(depositAmount);

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
        syrupRouter.deposit(depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

    function test_depositWithPermit_public_success() external {
        openPool(address(poolManager));

        erc20_mint(address(fundsAsset), liquidityProvider, depositAmount);

        assertEq(fundsAsset.balanceOf(liquidityProvider), depositAmount);
        assertEq(pool.balanceOf(liquidityProvider),       0);

        (uint8 v , bytes32 r, bytes32 s ) = vm.sign(
            liquidityProviderWallet,
            _getDigest(
                address(fundsAsset),
                liquidityProviderWallet.addr,
                address(syrupRouter),
                depositAmount,
                block.timestamp
            )
        );

        syrupRouter.depositWithPermit(liquidityProviderWallet.addr, depositAmount, block.timestamp, v, r, s);

        assertEq(fundsAsset.balanceOf(liquidityProvider), 0);
        assertEq(pool.balanceOf(liquidityProvider),       depositAmount);
    }

}

