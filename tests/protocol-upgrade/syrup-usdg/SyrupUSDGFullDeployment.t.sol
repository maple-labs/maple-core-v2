// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC20,
    IGlobals,
    IMapleProxyFactory,
    IOpenTermLoan,
    IOpenTermLoanManager,
    IPool,
    IPoolManager,
    IPoolPermissionManager,
    ISyrupRouter,
    IWithdrawalManagerQueue,
    IWithdrawalManagerQueueV200Like
} from "../../../contracts/interfaces/Interfaces.sol";

import { SyrupUSDGDeploymentBase } from "./SyrupUSDGDeploymentBase.t.sol";

contract SyrupUSDGFullDeploymentTests is SyrupUSDGDeploymentBase {

    function testFork_usdgDeployment_staticConfiguration() public view {
        assertEq(block.timestamp, startingTime + 3 days);

        assertEq(IMapleProxyFactory(withdrawalManagerQueueFactory).defaultVersion(), 200);
        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).defaultVersion(),    100);

        assertEq(IPool(usdgPool).asset(),                USDG);
        assertEq(IPool(usdgPool).manager(),              usdgPoolManager);
        assertEq(IPool(usdgPool).name(),                 "Syrup USDG");
        assertEq(IPool(usdgPool).symbol(),               "syrupUSDG");
        assertEq(IPool(usdgPool).decimals(),             6);
        assertEq(IPool(usdgPool).BOOTSTRAP_MINT(),       BOOTSTRAP_MINT);
        assertEq(IPool(usdgPool).balanceOf(address(0)),  INITIAL_DEPOSIT);
        assertEq(IPool(usdgPool).balanceOf(firstLender), 0);
        assertEq(IPool(usdgPool).totalSupply(),          INITIAL_DEPOSIT);
        assertEq(IPool(usdgPool).totalAssets(),          INITIAL_DEPOSIT);

        assertEq(IPoolManager(usdgPoolManager).asset(),                     USDG);
        assertEq(IPoolManager(usdgPoolManager).pool(),                      usdgPool);
        assertEq(IPoolManager(usdgPoolManager).withdrawalManager(),         usdgWithdrawalManager);
        assertEq(IPoolManager(usdgPoolManager).poolPermissionManager(),     poolPermissionManager);
        assertEq(IPoolManager(usdgPoolManager).poolDelegate(),              poolDelegate);
        assertEq(IPoolManager(usdgPoolManager).governor(),                  timelock);
        assertEq(IPoolManager(usdgPoolManager).globals(),                   globals);
        assertEq(IPoolManager(usdgPoolManager).factory(),                   poolManagerFactory);
        assertEq(IPoolManager(usdgPoolManager).implementation(),            poolManagerV500Implementation);
        assertEq(IPoolManager(usdgPoolManager).configured(),                true);
        assertEq(IPoolManager(usdgPoolManager).active(),                    true);
        assertEq(IPoolManager(usdgPoolManager).hasSufficientCover(),        true);
        assertEq(IPoolManager(usdgPoolManager).liquidityCap(),              LIQUIDITY_CAP);
        assertEq(IPoolManager(usdgPoolManager).delegateManagementFeeRate(), DELEGATE_MANAGEMENT_FEE_RATE);
        assertEq(IPoolManager(usdgPoolManager).totalAssets(),               INITIAL_DEPOSIT);
        assertEq(IPoolManager(usdgPoolManager).unrealizedLosses(),          0);
        assertEq(IPoolManager(usdgPoolManager).strategyListLength(),        1);
        assertEq(IPoolManager(usdgPoolManager).strategyList(0),             usdgOpenTermLoanManager);
        assertEq(IPoolManager(usdgPoolManager).pendingPoolDelegate(),       address(0));

        assertEq(IWithdrawalManagerQueue(usdgWithdrawalManager).asset(),          USDG);
        assertEq(IWithdrawalManagerQueue(usdgWithdrawalManager).pool(),           usdgPool);
        assertEq(IWithdrawalManagerQueue(usdgWithdrawalManager).poolManager(),    usdgPoolManager);
        assertEq(IWithdrawalManagerQueue(usdgWithdrawalManager).poolDelegate(),   poolDelegate);
        assertEq(IWithdrawalManagerQueue(usdgWithdrawalManager).globals(),        globals);
        assertEq(IWithdrawalManagerQueue(usdgWithdrawalManager).governor(),       timelock);
        assertEq(IWithdrawalManagerQueue(usdgWithdrawalManager).factory(),        withdrawalManagerQueueFactory);
        assertEq(IWithdrawalManagerQueue(usdgWithdrawalManager).implementation(), WithdrawalManagerQueueV200Implementation);
        assertEq(IWithdrawalManagerQueue(usdgWithdrawalManager).totalShares(),    0);

        assertEq(IOpenTermLoanManager(usdgOpenTermLoanManager).fundsAsset(),            USDG);
        assertEq(IOpenTermLoanManager(usdgOpenTermLoanManager).poolManager(),           usdgPoolManager);
        assertEq(IOpenTermLoanManager(usdgOpenTermLoanManager).implementation(),        OpenTermLoanManagerV100Implementation);
        assertEq(IOpenTermLoanManager(usdgOpenTermLoanManager).assetsUnderManagement(), 0);
        assertEq(IOpenTermLoanManager(usdgOpenTermLoanManager).unrealizedLosses(),      0);

        assertEq(ISyrupRouter(usdgSyrupRouter).asset(),                 USDG);
        assertEq(ISyrupRouter(usdgSyrupRouter).pool(),                  usdgPool);
        assertEq(ISyrupRouter(usdgSyrupRouter).poolManager(),           usdgPoolManager);
        assertEq(ISyrupRouter(usdgSyrupRouter).poolPermissionManager(), poolPermissionManager);
        assertEq(IERC20(USDG).allowance(usdgSyrupRouter, usdgPool),     type(uint256).max);

        assertEq(IGlobals(globals).isPoolAsset(USDG),                           true);
        assertEq(IGlobals(globals).bootstrapMint(USDG),                         BOOTSTRAP_MINT);
        assertEq(IGlobals(globals).maxCoverLiquidationPercent(usdgPoolManager), 0);
        assertEq(IGlobals(globals).minCoverAmount(usdgPoolManager),             0);
        assertEq(IGlobals(globals).platformOriginationFeeRate(usdgPoolManager), PLATFORM_ORIGINATION_FEE_RATE);
        assertEq(IGlobals(globals).platformServiceFeeRate(usdgPoolManager),     PLATFORM_SERVICE_FEE_RATE);
        assertEq(IGlobals(globals).platformManagementFeeRate(usdgPoolManager),  PLATFORM_MANAGEMENT_FEE_RATE);

        ( address ownedPoolManager, bool isPoolDelegate ) = IGlobals(globals).poolDelegates(poolDelegate);

        assertEq(ownedPoolManager, usdgPoolManager);
        assertEq(isPoolDelegate,   true);

        IPoolPermissionManager permissionManager = IPoolPermissionManager(poolPermissionManager);

        assertEq(permissionManager.permissionLevels(usdgPoolManager),                   1);
        assertEq(permissionManager.poolBitmaps(usdgPoolManager, "P:transfer"),          0);
        assertEq(permissionManager.poolBitmaps(usdgPoolManager, "P:transferFrom"),      0);
        assertEq(permissionManager.poolBitmaps(usdgPoolManager, "P:deposit"),           SYRUP_USDG_LENDER_BITMAP);
        assertEq(permissionManager.poolBitmaps(usdgPoolManager, "P:depositWithPermit"), SYRUP_USDG_LENDER_BITMAP);
        assertEq(permissionManager.poolBitmaps(usdgPoolManager, "P:mint"),              SYRUP_USDG_LENDER_BITMAP);
        assertEq(permissionManager.poolBitmaps(usdgPoolManager, "P:mintWithPermit"),    SYRUP_USDG_LENDER_BITMAP);
        assertEq(permissionManager.poolBitmaps(usdgPoolManager, "P:redeem"),            SYRUP_USDG_LENDER_BITMAP);
        assertEq(permissionManager.poolBitmaps(usdgPoolManager, "P:withdraw"),          SYRUP_USDG_LENDER_BITMAP);
        assertEq(permissionManager.poolBitmaps(usdgPoolManager, "P:removeShares"),      SYRUP_USDG_LENDER_BITMAP);
        assertEq(permissionManager.poolBitmaps(usdgPoolManager, "P:requestRedeem"),     0);
        assertEq(permissionManager.poolBitmaps(usdgPoolManager, "P:requestWithdraw"),   SYRUP_USDG_LENDER_BITMAP);

        assertEq(permissionManager.lenderAllowlist(usdgPoolManager, usdgSyrupRouter),       true);
        assertEq(permissionManager.lenderAllowlist(usdgPoolManager, usdgWithdrawalManager), true);
        assertEq(permissionManager.lenderBitmaps(firstLender),                              SYRUP_USDG_LENDER_BITMAP);
    }

    function testFork_usdgDeployment_initialDeposit_burnsShares() public view {
        assertEq(IERC20(USDG).balanceOf(firstLender),    0);
        assertEq(IERC20(USDG).balanceOf(usdgPool),       INITIAL_DEPOSIT);
        assertEq(IPool(usdgPool).balanceOf(address(0)),  INITIAL_DEPOSIT);
        assertEq(IPool(usdgPool).balanceOf(firstLender), 0);
        assertEq(IPool(usdgPool).totalSupply(),          INITIAL_DEPOSIT);
        assertEq(IPool(usdgPool).totalAssets(),          INITIAL_DEPOSIT);
    }

    function testFork_usdgFullDeployment_deposit_success() public {
        address lender = makeAddr("fullDeploymentDepositLender");
        uint256 amount = 25e6;

        uint256 initialPoolAssets = IERC20(USDG).balanceOf(usdgPool);
        uint256 initialPoolSupply = IPool(usdgPool).totalSupply();

        _setLenderBitmap(lender);
        deal(USDG, lender, amount);

        vm.startPrank(lender);
        IERC20(USDG).approve(usdgPool, amount);
        uint256 shares = IPool(usdgPool).deposit(amount, lender);
        vm.stopPrank();

        assertEq(shares,                                amount);
        assertEq(IERC20(USDG).balanceOf(lender),        0);
        assertEq(IERC20(USDG).balanceOf(usdgPool),      initialPoolAssets + amount);
        assertEq(IPool(usdgPool).balanceOf(address(0)), INITIAL_DEPOSIT);
        assertEq(IPool(usdgPool).balanceOf(lender),     amount);
        assertEq(IPool(usdgPool).totalSupply(),         initialPoolSupply + amount);
        assertEq(IPool(usdgPool).totalAssets(),         initialPoolAssets + amount);
    }

    function testFork_usdgFullDeployment_redeem_success() public {
        IWithdrawalManagerQueue withdrawalManager = IWithdrawalManagerQueue(usdgWithdrawalManager);

        address lender        = makeAddr("fullDeploymentRedeemLender");
        uint256 depositAmount = 25e6;
        uint256 redeemShares  = 5e6;

        uint256 initialPoolAssets = IERC20(USDG).balanceOf(usdgPool);
        uint256 initialPoolSupply = IPool(usdgPool).totalSupply();

        _setLenderBitmap(lender);
        deal(USDG, lender, depositAmount);

        vm.prank(poolDelegate);
        withdrawalManager.setManualWithdrawal(lender, true);

        vm.startPrank(lender);
        IERC20(USDG).approve(usdgPool, depositAmount);
        IPool(usdgPool).deposit(depositAmount, lender);
        IPool(usdgPool).requestRedeem(redeemShares, lender);
        vm.stopPrank();

        vm.prank(poolDelegate);
        IWithdrawalManagerQueueV200Like(usdgWithdrawalManager).processRedemptions(redeemShares);

        assertEq(withdrawalManager.manualSharesAvailable(lender), redeemShares);
        assertEq(withdrawalManager.totalShares(),                 redeemShares);

        vm.prank(lender);
        uint256 assets = IPool(usdgPool).redeem(redeemShares, lender, lender);

        assertEq(assets,                                           redeemShares);
        assertEq(IERC20(USDG).balanceOf(lender),                   redeemShares);
        assertEq(IERC20(USDG).balanceOf(usdgPool),                 initialPoolAssets + depositAmount - redeemShares);
        assertEq(IPool(usdgPool).balanceOf(address(0)),            INITIAL_DEPOSIT);
        assertEq(IPool(usdgPool).balanceOf(lender),                depositAmount - redeemShares);
        assertEq(IPool(usdgPool).balanceOf(usdgWithdrawalManager), 0);
        assertEq(IPool(usdgPool).totalSupply(),                    initialPoolSupply + depositAmount - redeemShares);
        assertEq(IPool(usdgPool).totalAssets(),                    initialPoolAssets + depositAmount - redeemShares);
        assertEq(withdrawalManager.manualSharesAvailable(lender),  0);
        assertEq(withdrawalManager.totalShares(),                  0);
    }

    function testFork_usdgFullDeployment_fundLoan_success() public {
        address borrower  = makeAddr("fullDeploymentBorrower");
        uint256 principal = 3e6;

        uint256 initialPoolAssets  = IPool(usdgPool).totalAssets();
        uint256 initialPoolBalance = IERC20(USDG).balanceOf(usdgPool);

        address loanAddress = createOpenTermLoan({
            factory_:   openTermLoanFactory,
            borrower_:  borrower,
            lender_:    usdgOpenTermLoanManager,
            asset_:     USDG,
            principal_: principal,
            terms_:     [uint256(1 days), uint256(2 days), uint256(30 days)],
            rates_:     [uint256(0), uint256(0.05e6), uint256(0), uint256(0)]
        });

        fundLoan(loanAddress);

        assertEq(IOpenTermLoan(loanAddress).borrower(),                                 borrower);
        assertEq(IOpenTermLoan(loanAddress).lender(),                                   usdgOpenTermLoanManager);
        assertEq(IOpenTermLoan(loanAddress).fundsAsset(),                               USDG);
        assertEq(IOpenTermLoan(loanAddress).principal(),                                principal);
        assertEq(IOpenTermLoan(loanAddress).dateFunded(),                               block.timestamp);
        assertEq(IERC20(USDG).balanceOf(borrower),                                      principal);
        assertEq(IERC20(USDG).balanceOf(usdgPool),                                      initialPoolBalance - principal);
        assertEq(IOpenTermLoanManager(usdgOpenTermLoanManager).principalOut(),          principal);
        assertEq(IOpenTermLoanManager(usdgOpenTermLoanManager).assetsUnderManagement(), principal);
        assertEq(IPool(usdgPool).totalAssets(),                                         initialPoolAssets);
        assertEq(IPoolManager(usdgPoolManager).totalAssets(),                           initialPoolAssets);
    }

    function testFork_usdgRouter_deposit_revertWhenLenderHasInvalidBitmap() public {
        address lender = makeAddr("syrupUSDGLender");
        uint256 amount = 25e6;

        _setLenderBitmap(lender, 0);
        deal(USDG, lender, amount);

        vm.startPrank(lender);
        IERC20(USDG).approve(usdgSyrupRouter, amount);
        vm.expectRevert("SR:D:NOT_AUTHORIZED");
        ISyrupRouter(usdgSyrupRouter).deposit(amount, DEPOSIT_DATA);
        vm.stopPrank();
    }

    function testFork_usdgRouter_deposit_success() public {
        address lender = makeAddr("routerDepositLender");
        uint256 amount = 25e6;

        uint256 initialPoolAssets = IERC20(USDG).balanceOf(usdgPool);
        uint256 initialPoolSupply = IPool(usdgPool).totalSupply();

        _setLenderBitmap(lender);
        deal(USDG, lender, amount);

        vm.startPrank(lender);
        IERC20(USDG).approve(usdgSyrupRouter, amount);
        uint256 shares = ISyrupRouter(usdgSyrupRouter).deposit(amount, DEPOSIT_DATA);
        vm.stopPrank();

        assertEq(shares,                                     amount);
        assertEq(IERC20(USDG).balanceOf(lender),             0);
        assertEq(IERC20(USDG).balanceOf(usdgSyrupRouter),    0);
        assertEq(IERC20(USDG).balanceOf(usdgPool),           initialPoolAssets + amount);
        assertEq(IPool(usdgPool).balanceOf(lender),          shares);
        assertEq(IPool(usdgPool).balanceOf(usdgSyrupRouter), 0);
        assertEq(IPool(usdgPool).totalSupply(),              initialPoolSupply + shares);
        assertEq(IPool(usdgPool).totalAssets(),              initialPoolAssets + amount);
    }

    function testFork_usdgRouter_depositWithPermit_success() public {
        uint256 lenderPrivateKey = 0xA11CE;
        address lender           = vm.addr(lenderPrivateKey);
        uint256 amount           = 25e6;
        uint256 deadline         = block.timestamp;

        uint256 initialPoolAssets = IERC20(USDG).balanceOf(usdgPool);
        uint256 initialPoolSupply = IPool(usdgPool).totalSupply();

        _setLenderBitmap(lender);
        deal(USDG, lender, amount);

        (
            uint8   v,
            bytes32 r,
            bytes32 s
        ) = vm.sign(lenderPrivateKey, _getPermitDigest(lender, usdgSyrupRouter, amount, deadline));

        vm.prank(lender);
        uint256 shares = ISyrupRouter(usdgSyrupRouter).depositWithPermit(amount, deadline, v, r, s, DEPOSIT_DATA);

        assertEq(shares,                                     amount);
        assertEq(IERC20(USDG).balanceOf(lender),             0);
        assertEq(IERC20(USDG).balanceOf(usdgSyrupRouter),    0);
        assertEq(IERC20(USDG).balanceOf(usdgPool),           initialPoolAssets + amount);
        assertEq(IPool(usdgPool).balanceOf(lender),          shares);
        assertEq(IPool(usdgPool).balanceOf(usdgSyrupRouter), 0);
        assertEq(IPool(usdgPool).totalSupply(),              initialPoolSupply + shares);
        assertEq(IPool(usdgPool).totalAssets(),              initialPoolAssets + amount);
    }

    function testFork_usdgRouter_authorizeAndDeposit_success() public {
        uint256 permissionAdminPrivateKey = 0xB0B;
        uint256 lenderPrivateKey          = 0xC0DE;
        address lender                    = vm.addr(lenderPrivateKey);
        uint256 amount                    = 25e6;
        uint256 deadline                  = block.timestamp;

        vm.startPrank(operationalAdmin);
        IPoolPermissionManager(poolPermissionManager).setPermissionAdmin(vm.addr(permissionAdminPrivateKey), true);
        IPoolPermissionManager(poolPermissionManager).setPermissionAdmin(usdgSyrupRouter, true);
        vm.stopPrank();

        deal(USDG, lender, amount);

        ( uint8 v, bytes32 r, bytes32 s ) = vm.sign(permissionAdminPrivateKey, _getAuthDigest(lender, SYRUP_USDG_LENDER_BITMAP, deadline));

        vm.startPrank(lender);
        IERC20(USDG).approve(usdgSyrupRouter, amount);
        uint256 shares = ISyrupRouter(usdgSyrupRouter).authorizeAndDeposit(
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
        assertEq(IPool(usdgPool).balanceOf(lender),                                   shares);
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
        IPoolPermissionManager(poolPermissionManager).setPermissionAdmin(usdgSyrupRouter, true);
        vm.stopPrank();

        deal(USDG, lender, amount);

        uint8[2]   memory v;
        bytes32[2] memory r;
        bytes32[2] memory s;

        ( v[0], r[0], s[0] ) = vm.sign(permissionAdminPrivateKey, _getAuthDigest(lender, SYRUP_USDG_LENDER_BITMAP, deadline));
        ( v[1], r[1], s[1] ) = vm.sign(lenderPrivateKey, _getPermitDigest(lender, usdgSyrupRouter, amount, deadline));

        vm.prank(lender);
        uint256 shares = ISyrupRouter(usdgSyrupRouter).authorizeAndDepositWithPermit(
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
        assertEq(IPool(usdgPool).balanceOf(lender),                                   shares);
        assertEq(IPoolPermissionManager(poolPermissionManager).lenderBitmaps(lender), SYRUP_USDG_LENDER_BITMAP);
    }

    function testFork_usdgFullDeployment_processRedemptions_success() public {
        address lender        = makeAddr("queueWithdrawalLender");
        uint256 depositAmount = 25e6;
        uint256 redeemShares  = 10e6;

        uint256 initialPoolAssets = IERC20(USDG).balanceOf(usdgPool);
        uint256 initialPoolSupply = IPool(usdgPool).totalSupply();

        _setLenderBitmap(lender);
        deal(USDG, lender, depositAmount);

        vm.startPrank(lender);
        IERC20(USDG).approve(usdgSyrupRouter, depositAmount);
        uint256 depositShares = ISyrupRouter(usdgSyrupRouter).deposit(depositAmount, DEPOSIT_DATA);
        IPool(usdgPool).requestRedeem(redeemShares, lender);
        vm.stopPrank();

        uint256 requestId = IWithdrawalManagerQueue(usdgWithdrawalManager).requestIds(lender);

        vm.prank(poolDelegate);
        IWithdrawalManagerQueueV200Like(usdgWithdrawalManager).processRedemptions(redeemShares);

        assertEq(depositShares,                                                depositAmount);
        assertEq(requestId,                                                    1);
        assertEq(IERC20(USDG).balanceOf(lender),                               redeemShares);
        assertEq(IERC20(USDG).balanceOf(usdgPool),                             initialPoolAssets + depositAmount - redeemShares);
        assertEq(IPool(usdgPool).balanceOf(lender),                            depositShares - redeemShares);
        assertEq(IPool(usdgPool).balanceOf(usdgWithdrawalManager),             0);
        assertEq(IPool(usdgPool).totalSupply(),                                initialPoolSupply + depositShares - redeemShares);
        assertEq(IPool(usdgPool).totalAssets(),                                initialPoolAssets + depositAmount - redeemShares);
        assertEq(IWithdrawalManagerQueue(usdgWithdrawalManager).totalShares(), 0);
    }

    function _getAuthDigest(address owner_, uint256 bitmap_, uint256 deadline_) internal view returns (bytes32 digest_) {
        digest_ = keccak256(abi.encodePacked(
            "\x19\x01",
            block.chainid,
            usdgSyrupRouter,
            owner_,
            ISyrupRouter(usdgSyrupRouter).nonces(owner_),
            bitmap_,
            deadline_
        ));
    }

}
