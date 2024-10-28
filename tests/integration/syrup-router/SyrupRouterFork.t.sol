// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC20,
    IPoolPermissionManager,
    ISyrupRouter
} from "../../../contracts/interfaces/Interfaces.sol";

import { ProtocolActions } from "../../../contracts/ProtocolActions.sol";

import { MapleAddressRegistryETH } from "../../../modules/address-registry/contracts/MapleAddressRegistryETH.sol";
import { Vm }                      from "../../../modules/forge-std/src/Vm.sol";
import { SyrupRouter }             from "../../../modules/syrup-utils/contracts/SyrupRouter.sol";

contract SyrupRouterForkTests is ProtocolActions, MapleAddressRegistryETH {

    address pa   = permissionsAdmin;
    address pool = securedLendingUSDCPool;
    address pm   = securedLendingUSDCPoolManager;
    address ppm  = poolPermissionManager;
    address router;

    uint256 assets = 100_00e6;
    uint256 initial;

    Vm.Wallet lp;

    function setUp() external {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 19773189);

        // Create and allowlist the router.
        router = address(new SyrupRouter(pool));

        allowLender(pm, router);

        // Create, fund, and permission the liquidity provider.
        lp = vm.createWallet("lp");

        erc20_mint(usdc, lp.addr, assets);
        setLenderBitmap(ppm, pa, lp.addr, 3);

        // Get the current pool balance.
        initial = IERC20(usdc).balanceOf(pool);

        // Check pool is set to pool-level permissions.
        assertEq(IPoolPermissionManager(ppm).permissionLevels(pm), 2);

        // Check the pool bitmap has been set.
        assertEq(IPoolPermissionManager(ppm).poolBitmaps(pm, bytes32(0)), 3);
    }

    /**************************************************************************************************************************************/
    /*** Syrup Router Fork Tests                                                                                                        ***/
    /**************************************************************************************************************************************/

    function testFork_router_deposit() external {
        // Approve the transfer.
        erc20_approve(usdc, lp.addr, router, assets);

        // Perform the deposit.
        vm.prank(lp.addr);
        uint256 shares = ISyrupRouter(router).deposit(assets, bytes32(0));

        // Check the asset and share balances.
        assertEq(IERC20(usdc).balanceOf(lp.addr), 0);
        assertEq(IERC20(usdc).balanceOf(router),  0);
        assertEq(IERC20(usdc).balanceOf(pool),    initial + assets);

        assertEq(IERC20(pool).balanceOf(lp.addr), shares);
        assertEq(IERC20(pool).balanceOf(router),  0);
    }

    function testFork_router_depositWithPermit() external {
        // Get the signature.
        ( uint8 v, bytes32 r, bytes32 s ) = vm.sign(lp, _getDigest(usdc, lp.addr, router, assets, block.timestamp));

        // Perform the deposit.
        vm.prank(lp.addr);
        uint256 shares = ISyrupRouter(router).depositWithPermit(assets, block.timestamp, v, r, s, bytes32(0));

        // Check the asset and share balances.
        assertEq(IERC20(usdc).balanceOf(lp.addr), 0);
        assertEq(IERC20(usdc).balanceOf(router),  0);
        assertEq(IERC20(usdc).balanceOf(pool),    initial + assets);

        assertEq(IERC20(pool).balanceOf(lp.addr), shares);
        assertEq(IERC20(pool).balanceOf(router),  0);
    }

}
