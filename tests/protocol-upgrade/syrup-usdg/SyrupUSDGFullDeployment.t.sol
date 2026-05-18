// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC20,
    IGlobals,
    IMapleProxyFactory,
    IOpenTermLoan,
    IOpenTermLoanManager,
    IPool,
    IPoolDelegateCover,
    IPoolManager,
    IPoolPermissionManager,
    ISyrupRouter,
    IWithdrawalManagerQueue,
    IWithdrawalManagerQueueV200Like
} from "../../../contracts/interfaces/Interfaces.sol";

import { ProtocolActions } from "../../../contracts/ProtocolActions.sol";

import { SyrupUSDGDeploymentBase } from "./SyrupUSDGDeploymentBase.t.sol";

contract SyrupUSDGFullDeploymentTests is SyrupUSDGDeploymentBase, ProtocolActions {

    function testFork_usdgDeployment_staticConfiguration() public view {
        assertEq(block.timestamp, startingTime + 3 days);

        assertEq(IMapleProxyFactory(withdrawalManagerQueueFactory).defaultVersion(), 200);
        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).defaultVersion(),    100);

        assertEq(IPool(syrupUSDGPool).asset(),                USDG);
        assertEq(IPool(syrupUSDGPool).manager(),              syrupUSDGPoolManager);
        assertEq(IPool(syrupUSDGPool).name(),                 "Syrup USDG");
        assertEq(IPool(syrupUSDGPool).symbol(),               "syrupUSDG");
        assertEq(IPool(syrupUSDGPool).decimals(),             6);
        assertEq(IPool(syrupUSDGPool).BOOTSTRAP_MINT(),       BOOTSTRAP_MINT);
        assertEq(IPool(syrupUSDGPool).balanceOf(address(0)),  INITIAL_DEPOSIT);
        assertEq(IPool(syrupUSDGPool).balanceOf(firstLender), 0);
        assertEq(IPool(syrupUSDGPool).totalSupply(),          INITIAL_DEPOSIT);
        assertEq(IPool(syrupUSDGPool).totalAssets(),          INITIAL_DEPOSIT);

        assertEq(IPoolManager(syrupUSDGPoolManager).asset(),                     USDG);
        assertEq(IPoolManager(syrupUSDGPoolManager).pool(),                      syrupUSDGPool);
        assertEq(IPoolManager(syrupUSDGPoolManager).withdrawalManager(),         syrupUSDGWithdrawalManager);
        assertEq(IPoolManager(syrupUSDGPoolManager).poolDelegateCover(),         syrupUSDGPoolDelegateCover);
        assertEq(IPoolManager(syrupUSDGPoolManager).poolPermissionManager(),     poolPermissionManager);
        assertEq(IPoolManager(syrupUSDGPoolManager).poolDelegate(),              poolDelegate);
        assertEq(IPoolManager(syrupUSDGPoolManager).governor(),                  timelock);
        assertEq(IPoolManager(syrupUSDGPoolManager).globals(),                   globals);
        assertEq(IPoolManager(syrupUSDGPoolManager).factory(),                   poolManagerFactory);
        assertEq(IPoolManager(syrupUSDGPoolManager).implementation(),            PoolManagerV400Implementation);
        assertEq(IPoolManager(syrupUSDGPoolManager).configured(),                true);
        assertEq(IPoolManager(syrupUSDGPoolManager).active(),                    true);
        assertEq(IPoolManager(syrupUSDGPoolManager).hasSufficientCover(),        true);
        assertEq(IPoolManager(syrupUSDGPoolManager).liquidityCap(),              LIQUIDITY_CAP);
        assertEq(IPoolManager(syrupUSDGPoolManager).delegateManagementFeeRate(), DELEGATE_MANAGEMENT_FEE_RATE);
        assertEq(IPoolManager(syrupUSDGPoolManager).totalAssets(),               INITIAL_DEPOSIT);
        assertEq(IPoolManager(syrupUSDGPoolManager).unrealizedLosses(),          0);
        assertEq(IPoolManager(syrupUSDGPoolManager).strategyListLength(),        1);
        assertEq(IPoolManager(syrupUSDGPoolManager).strategyList(0),             openTermLoanManager);
        assertEq(IPoolManager(syrupUSDGPoolManager).pendingPoolDelegate(),       address(0));

        assertEq(IWithdrawalManagerQueue(syrupUSDGWithdrawalManager).asset(),          USDG);
        assertEq(IWithdrawalManagerQueue(syrupUSDGWithdrawalManager).pool(),           syrupUSDGPool);
        assertEq(IWithdrawalManagerQueue(syrupUSDGWithdrawalManager).poolManager(),    syrupUSDGPoolManager);
        assertEq(IWithdrawalManagerQueue(syrupUSDGWithdrawalManager).poolDelegate(),   poolDelegate);
        assertEq(IWithdrawalManagerQueue(syrupUSDGWithdrawalManager).globals(),        globals);
        assertEq(IWithdrawalManagerQueue(syrupUSDGWithdrawalManager).governor(),       timelock);
        assertEq(IWithdrawalManagerQueue(syrupUSDGWithdrawalManager).factory(),        withdrawalManagerQueueFactory);
        assertEq(IWithdrawalManagerQueue(syrupUSDGWithdrawalManager).implementation(), WithdrawalManagerQueueV200Implementation);
        assertEq(IWithdrawalManagerQueue(syrupUSDGWithdrawalManager).totalShares(),    0);

        assertEq(IOpenTermLoanManager(openTermLoanManager).fundsAsset(),            USDG);
        assertEq(IOpenTermLoanManager(openTermLoanManager).poolManager(),           syrupUSDGPoolManager);
        assertEq(IOpenTermLoanManager(openTermLoanManager).implementation(),        OpenTermLoanManagerV100Implementation);
        assertEq(IOpenTermLoanManager(openTermLoanManager).assetsUnderManagement(), 0);
        assertEq(IOpenTermLoanManager(openTermLoanManager).unrealizedLosses(),      0);

        assertEq(IPoolDelegateCover(syrupUSDGPoolDelegateCover).asset(),       USDG);
        assertEq(IPoolDelegateCover(syrupUSDGPoolDelegateCover).poolManager(), syrupUSDGPoolManager);
        assertEq(IERC20(USDG).balanceOf(syrupUSDGPoolDelegateCover),           0);

        assertEq(ISyrupRouter(syrupUSDGSyrupRouter).asset(),                  USDG);
        assertEq(ISyrupRouter(syrupUSDGSyrupRouter).pool(),                   syrupUSDGPool);
        assertEq(ISyrupRouter(syrupUSDGSyrupRouter).poolManager(),            syrupUSDGPoolManager);
        assertEq(ISyrupRouter(syrupUSDGSyrupRouter).poolPermissionManager(),  poolPermissionManager);
        assertEq(IERC20(USDG).allowance(syrupUSDGSyrupRouter, syrupUSDGPool), type(uint256).max);

        assertEq(IGlobals(globals).isPoolAsset(USDG),                                true);
        assertEq(IGlobals(globals).bootstrapMint(USDG),                              BOOTSTRAP_MINT);
        assertEq(IGlobals(globals).maxCoverLiquidationPercent(syrupUSDGPoolManager), 0);
        assertEq(IGlobals(globals).minCoverAmount(syrupUSDGPoolManager),             0);
        assertEq(IGlobals(globals).platformOriginationFeeRate(syrupUSDGPoolManager), PLATFORM_ORIGINATION_FEE_RATE);
        assertEq(IGlobals(globals).platformServiceFeeRate(syrupUSDGPoolManager),     PLATFORM_SERVICE_FEE_RATE);
        assertEq(IGlobals(globals).platformManagementFeeRate(syrupUSDGPoolManager),  PLATFORM_MANAGEMENT_FEE_RATE);

        ( address ownedPoolManager, bool isPoolDelegate ) = IGlobals(globals).poolDelegates(poolDelegate);

        assertEq(ownedPoolManager, syrupUSDGPoolManager);
        assertEq(isPoolDelegate,   true);

        IPoolPermissionManager permissionManager = IPoolPermissionManager(poolPermissionManager);

        assertEq(permissionManager.permissionLevels(syrupUSDGPoolManager),                   1);
        assertEq(permissionManager.poolBitmaps(syrupUSDGPoolManager, "P:transfer"),          0);
        assertEq(permissionManager.poolBitmaps(syrupUSDGPoolManager, "P:transferFrom"),      0);
        assertEq(permissionManager.poolBitmaps(syrupUSDGPoolManager, "P:deposit"),           SYRUP_USDG_LENDER_BITMAP);
        assertEq(permissionManager.poolBitmaps(syrupUSDGPoolManager, "P:depositWithPermit"), SYRUP_USDG_LENDER_BITMAP);
        assertEq(permissionManager.poolBitmaps(syrupUSDGPoolManager, "P:mint"),              SYRUP_USDG_LENDER_BITMAP);
        assertEq(permissionManager.poolBitmaps(syrupUSDGPoolManager, "P:mintWithPermit"),    SYRUP_USDG_LENDER_BITMAP);
        assertEq(permissionManager.poolBitmaps(syrupUSDGPoolManager, "P:redeem"),            SYRUP_USDG_LENDER_BITMAP);
        assertEq(permissionManager.poolBitmaps(syrupUSDGPoolManager, "P:withdraw"),          SYRUP_USDG_LENDER_BITMAP);
        assertEq(permissionManager.poolBitmaps(syrupUSDGPoolManager, "P:removeShares"),      SYRUP_USDG_LENDER_BITMAP);
        assertEq(permissionManager.poolBitmaps(syrupUSDGPoolManager, "P:requestRedeem"),     0);
        assertEq(permissionManager.poolBitmaps(syrupUSDGPoolManager, "P:requestWithdraw"),   SYRUP_USDG_LENDER_BITMAP);

        assertEq(permissionManager.lenderAllowlist(syrupUSDGPoolManager, syrupUSDGSyrupRouter),       true);
        assertEq(permissionManager.lenderAllowlist(syrupUSDGPoolManager, syrupUSDGWithdrawalManager), true);
        assertEq(permissionManager.lenderBitmaps(firstLender),                                        SYRUP_USDG_LENDER_BITMAP);
    }

    function testFork_usdgDeployment_initialDeposit_burnsShares() public view {
        assertEq(IERC20(USDG).balanceOf(firstLender),          0);
        assertEq(IERC20(USDG).balanceOf(syrupUSDGPool),        INITIAL_DEPOSIT);
        assertEq(IPool(syrupUSDGPool).balanceOf(address(0)),   INITIAL_DEPOSIT);
        assertEq(IPool(syrupUSDGPool).balanceOf(firstLender),  0);
        assertEq(IPool(syrupUSDGPool).totalSupply(),           INITIAL_DEPOSIT);
        assertEq(IPool(syrupUSDGPool).totalAssets(),           INITIAL_DEPOSIT);
    }

    function testFork_usdgFullDeployment_deposit_success() public {
        address lender = makeAddr("fullDeploymentDepositLender");
        uint256 amount = 25e6;

        uint256 initialPoolAssets = IERC20(USDG).balanceOf(syrupUSDGPool);
        uint256 initialPoolSupply = IPool(syrupUSDGPool).totalSupply();

        _setLenderBitmap(lender);
        deal(USDG, lender, amount);

        vm.startPrank(lender);
        IERC20(USDG).approve(syrupUSDGPool, amount);
        uint256 shares = IPool(syrupUSDGPool).deposit(amount, lender);
        vm.stopPrank();

        assertEq(shares,                                     amount);
        assertEq(IERC20(USDG).balanceOf(lender),             0);
        assertEq(IERC20(USDG).balanceOf(syrupUSDGPool),      initialPoolAssets + amount);
        assertEq(IPool(syrupUSDGPool).balanceOf(address(0)), INITIAL_DEPOSIT);
        assertEq(IPool(syrupUSDGPool).balanceOf(lender),     amount);
        assertEq(IPool(syrupUSDGPool).totalSupply(),         initialPoolSupply + amount);
        assertEq(IPool(syrupUSDGPool).totalAssets(),         initialPoolAssets + amount);
    }

    function testFork_usdgFullDeployment_redeem_success() public {
        IWithdrawalManagerQueue withdrawalManager = IWithdrawalManagerQueue(syrupUSDGWithdrawalManager);

        address lender        = makeAddr("fullDeploymentRedeemLender");
        uint256 depositAmount = 25e6;
        uint256 redeemShares  = 5e6;

        uint256 initialPoolAssets = IERC20(USDG).balanceOf(syrupUSDGPool);
        uint256 initialPoolSupply = IPool(syrupUSDGPool).totalSupply();

        _setLenderBitmap(lender);
        deal(USDG, lender, depositAmount);

        vm.prank(poolDelegate);
        withdrawalManager.setManualWithdrawal(lender, true);

        vm.startPrank(lender);
        IERC20(USDG).approve(syrupUSDGPool, depositAmount);
        IPool(syrupUSDGPool).deposit(depositAmount, lender);
        IPool(syrupUSDGPool).requestRedeem(redeemShares, lender);
        vm.stopPrank();

        vm.prank(poolDelegate);
        IWithdrawalManagerQueueV200Like(syrupUSDGWithdrawalManager).processRedemptions(redeemShares);

        assertEq(withdrawalManager.manualSharesAvailable(lender), redeemShares);
        assertEq(withdrawalManager.totalShares(),                 redeemShares);

        vm.prank(lender);
        uint256 assets = IPool(syrupUSDGPool).redeem(redeemShares, lender, lender);

        assertEq(assets,                                                     redeemShares);
        assertEq(IERC20(USDG).balanceOf(lender),                             redeemShares);
        assertEq(IERC20(USDG).balanceOf(syrupUSDGPool),                      initialPoolAssets + depositAmount - redeemShares);
        assertEq(IPool(syrupUSDGPool).balanceOf(address(0)),                 INITIAL_DEPOSIT);
        assertEq(IPool(syrupUSDGPool).balanceOf(lender),                     depositAmount - redeemShares);
        assertEq(IPool(syrupUSDGPool).balanceOf(syrupUSDGWithdrawalManager), 0);
        assertEq(IPool(syrupUSDGPool).totalSupply(),                         initialPoolSupply + depositAmount - redeemShares);
        assertEq(IPool(syrupUSDGPool).totalAssets(),                         initialPoolAssets + depositAmount - redeemShares);
        assertEq(withdrawalManager.manualSharesAvailable(lender),            0);
        assertEq(withdrawalManager.totalShares(),                            0);
    }

    function testFork_usdgFullDeployment_fundLoan_success() public {
        address borrower  = makeAddr("fullDeploymentBorrower");
        uint256 principal = 3e6;

        uint256 initialPoolAssets  = IPool(syrupUSDGPool).totalAssets();
        uint256 initialPoolBalance = IERC20(USDG).balanceOf(syrupUSDGPool);

        address loanAddress = createOpenTermLoan({
            factory_:   openTermLoanFactory,
            borrower_:  borrower,
            lender_:    openTermLoanManager,
            asset_:     USDG,
            principal_: principal,
            terms_:     [uint256(1 days), uint256(2 days), uint256(30 days)],
            rates_:     [uint256(0), uint256(0.05e6), uint256(0), uint256(0)]
        });

        fundLoan(loanAddress);

        assertEq(IOpenTermLoan(loanAddress).borrower(),                             borrower);
        assertEq(IOpenTermLoan(loanAddress).lender(),                               openTermLoanManager);
        assertEq(IOpenTermLoan(loanAddress).fundsAsset(),                           USDG);
        assertEq(IOpenTermLoan(loanAddress).principal(),                            principal);
        assertEq(IOpenTermLoan(loanAddress).dateFunded(),                           block.timestamp);
        assertEq(IERC20(USDG).balanceOf(borrower),                                  principal);
        assertEq(IERC20(USDG).balanceOf(syrupUSDGPool),                             initialPoolBalance - principal);
        assertEq(IOpenTermLoanManager(openTermLoanManager).principalOut(),          principal);
        assertEq(IOpenTermLoanManager(openTermLoanManager).assetsUnderManagement(), principal);
        assertEq(IPool(syrupUSDGPool).totalAssets(),                                initialPoolAssets);
        assertEq(IPoolManager(syrupUSDGPoolManager).totalAssets(),                  initialPoolAssets);
    }

    function testFork_usdgRouter_deposit_revertWhenLenderHasInvalidBitmap() public {
        address lender = makeAddr("syrupUSDGLender");
        uint256 amount = 25e6;

        _setLenderBitmap(lender, 0);
        deal(USDG, lender, amount);

        vm.startPrank(lender);
        IERC20(USDG).approve(syrupUSDGSyrupRouter, amount);
        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        ISyrupRouter(syrupUSDGSyrupRouter).deposit(amount, DEPOSIT_DATA);
        vm.stopPrank();
    }

    function testFork_usdgRouter_deposit_success() public {
        address lender = makeAddr("routerDepositLender");
        uint256 amount = 25e6;

        uint256 initialPoolAssets = IERC20(USDG).balanceOf(syrupUSDGPool);
        uint256 initialPoolSupply = IPool(syrupUSDGPool).totalSupply();

        _setLenderBitmap(lender);
        deal(USDG, lender, amount);

        vm.startPrank(lender);
        IERC20(USDG).approve(syrupUSDGSyrupRouter, amount);
        uint256 shares = ISyrupRouter(syrupUSDGSyrupRouter).deposit(amount, DEPOSIT_DATA);
        vm.stopPrank();

        assertEq(shares,                                               amount);
        assertEq(IERC20(USDG).balanceOf(lender),                       0);
        assertEq(IERC20(USDG).balanceOf(syrupUSDGSyrupRouter),         0);
        assertEq(IERC20(USDG).balanceOf(syrupUSDGPool),                initialPoolAssets + amount);
        assertEq(IPool(syrupUSDGPool).balanceOf(lender),               shares);
        assertEq(IPool(syrupUSDGPool).balanceOf(syrupUSDGSyrupRouter), 0);
        assertEq(IPool(syrupUSDGPool).totalSupply(),                   initialPoolSupply + shares);
        assertEq(IPool(syrupUSDGPool).totalAssets(),                   initialPoolAssets + amount);
    }

    function testFork_usdgRouter_depositWithPermit_success() public {
        uint256 lenderPrivateKey = 0xA11CE;
        address lender           = vm.addr(lenderPrivateKey);
        uint256 amount           = 25e6;
        uint256 deadline         = block.timestamp;

        uint256 initialPoolAssets = IERC20(USDG).balanceOf(syrupUSDGPool);
        uint256 initialPoolSupply = IPool(syrupUSDGPool).totalSupply();

        _setLenderBitmap(lender);
        deal(USDG, lender, amount);

        (
            uint8   v,
            bytes32 r,
            bytes32 s
        ) = vm.sign(lenderPrivateKey, _getPermitDigest(lender, syrupUSDGSyrupRouter, amount, deadline));

        vm.prank(lender);
        uint256 shares = ISyrupRouter(syrupUSDGSyrupRouter).depositWithPermit(amount, deadline, v, r, s, DEPOSIT_DATA);

        assertEq(shares,                                               amount);
        assertEq(IERC20(USDG).balanceOf(lender),                       0);
        assertEq(IERC20(USDG).balanceOf(syrupUSDGSyrupRouter),         0);
        assertEq(IERC20(USDG).balanceOf(syrupUSDGPool),                initialPoolAssets + amount);
        assertEq(IPool(syrupUSDGPool).balanceOf(lender),               shares);
        assertEq(IPool(syrupUSDGPool).balanceOf(syrupUSDGSyrupRouter), 0);
        assertEq(IPool(syrupUSDGPool).totalSupply(),                   initialPoolSupply + shares);
        assertEq(IPool(syrupUSDGPool).totalAssets(),                   initialPoolAssets + amount);
    }

    function testFork_usdgRouter_authorizeAndDeposit_success() public {
        uint256 permissionAdminPrivateKey = 0xB0B;
        uint256 lenderPrivateKey          = 0xC0DE;
        address lender                    = vm.addr(lenderPrivateKey);
        uint256 amount                    = 25e6;
        uint256 deadline                  = block.timestamp;

        vm.startPrank(operationalAdmin);
        IPoolPermissionManager(poolPermissionManager).setPermissionAdmin(vm.addr(permissionAdminPrivateKey), true);
        IPoolPermissionManager(poolPermissionManager).setPermissionAdmin(syrupUSDGSyrupRouter, true);
        vm.stopPrank();

        deal(USDG, lender, amount);

        ( uint8 v, bytes32 r, bytes32 s ) = vm.sign(permissionAdminPrivateKey, _getAuthDigest(lender, SYRUP_USDG_LENDER_BITMAP, deadline));

        vm.startPrank(lender);
        IERC20(USDG).approve(syrupUSDGSyrupRouter, amount);
        uint256 shares = ISyrupRouter(syrupUSDGSyrupRouter).authorizeAndDeposit(
            SYRUP_USDG_LENDER_BITMAP,
            deadline,
            v,
            r,
            s,
            amount,
            DEPOSIT_DATA
        );
        vm.stopPrank();

        assertEq(shares,                                                              amount);
        assertEq(IERC20(USDG).balanceOf(lender),                                      0);
        assertEq(IPool(syrupUSDGPool).balanceOf(lender),                              shares);
        assertEq(IPoolPermissionManager(poolPermissionManager).lenderBitmaps(lender), SYRUP_USDG_LENDER_BITMAP);
    }

    function testFork_usdgRouter_authorizeAndDepositWithPermit_success() public {
        uint256 permissionAdminPrivateKey = 0xB0B;
        uint256 lenderPrivateKey          = 0xC0DE;
        address lender                    = vm.addr(lenderPrivateKey);
        uint256 amount                    = 25e6;
        uint256 deadline                  = block.timestamp;

        vm.startPrank(operationalAdmin);
        IPoolPermissionManager(poolPermissionManager).setPermissionAdmin(vm.addr(permissionAdminPrivateKey), true);
        IPoolPermissionManager(poolPermissionManager).setPermissionAdmin(syrupUSDGSyrupRouter, true);
        vm.stopPrank();

        deal(USDG, lender, amount);

        uint8[2]   memory v;
        bytes32[2] memory r;
        bytes32[2] memory s;

        ( v[0], r[0], s[0] ) = vm.sign(permissionAdminPrivateKey, _getAuthDigest(lender, SYRUP_USDG_LENDER_BITMAP, deadline));
        ( v[1], r[1], s[1] ) = vm.sign(lenderPrivateKey, _getPermitDigest(lender, syrupUSDGSyrupRouter, amount, deadline));

        vm.prank(lender);
        uint256 shares = ISyrupRouter(syrupUSDGSyrupRouter).authorizeAndDepositWithPermit(
            SYRUP_USDG_LENDER_BITMAP,
            deadline,
            v[0],
            r[0],
            s[0],
            amount,
            DEPOSIT_DATA,
            deadline,
            v[1],
            r[1],
            s[1]
        );

        assertEq(shares,                                                              amount);
        assertEq(IERC20(USDG).balanceOf(lender),                                      0);
        assertEq(IPool(syrupUSDGPool).balanceOf(lender),                              shares);
        assertEq(IPoolPermissionManager(poolPermissionManager).lenderBitmaps(lender), SYRUP_USDG_LENDER_BITMAP);
    }

    function testFork_usdgFullDeployment_processRedemptions_success() public {
        address lender        = makeAddr("queueWithdrawalLender");
        uint256 depositAmount = 25e6;
        uint256 redeemShares  = 10e6;

        uint256 initialPoolAssets = IERC20(USDG).balanceOf(syrupUSDGPool);
        uint256 initialPoolSupply = IPool(syrupUSDGPool).totalSupply();

        _setLenderBitmap(lender);
        deal(USDG, lender, depositAmount);

        vm.startPrank(lender);
        IERC20(USDG).approve(syrupUSDGSyrupRouter, depositAmount);
        uint256 depositShares = ISyrupRouter(syrupUSDGSyrupRouter).deposit(depositAmount, DEPOSIT_DATA);
        IPool(syrupUSDGPool).requestRedeem(redeemShares, lender);
        vm.stopPrank();

        uint256 requestId = IWithdrawalManagerQueue(syrupUSDGWithdrawalManager).requestIds(lender);

        vm.prank(poolDelegate);
        IWithdrawalManagerQueueV200Like(syrupUSDGWithdrawalManager).processRedemptions(redeemShares);

        assertEq(depositShares,                                                     depositAmount);
        assertEq(requestId,                                                         1);
        assertEq(IERC20(USDG).balanceOf(lender),                                    redeemShares);
        assertEq(IERC20(USDG).balanceOf(syrupUSDGPool),                             initialPoolAssets + depositAmount - redeemShares);
        assertEq(IPool(syrupUSDGPool).balanceOf(lender),                            depositShares - redeemShares);
        assertEq(IPool(syrupUSDGPool).balanceOf(syrupUSDGWithdrawalManager),        0);
        assertEq(IPool(syrupUSDGPool).totalSupply(),                                initialPoolSupply + depositShares - redeemShares);
        assertEq(IPool(syrupUSDGPool).totalAssets(),                                initialPoolAssets + depositAmount - redeemShares);
        assertEq(IWithdrawalManagerQueue(syrupUSDGWithdrawalManager).totalShares(), 0);
    }

    function _getAuthDigest(address owner_, uint256 bitmap_, uint256 deadline_) internal view returns (bytes32 digest_) {
        digest_ = keccak256(abi.encodePacked(
            "\x19\x01",
            block.chainid,
            syrupUSDGSyrupRouter,
            owner_,
            ISyrupRouter(syrupUSDGSyrupRouter).nonces(owner_),
            bitmap_,
            deadline_
        ));
    }

}
