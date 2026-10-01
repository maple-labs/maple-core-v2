// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC20,
    IOpenTermLoan,
    IOpenTermLoanManager,
    IPool,
    IPoolManager,
    IWithdrawalManagerCyclical,
    IWithdrawalManagerQueue
} from "../../../contracts/interfaces/Interfaces.sol";

import { ModularReleaseBase } from "./ModularReleaseBase.sol";

contract ModularReleaseProcedure is ModularReleaseBase {

    address aqruPoolManager               = 0xA9c908Ee077eE26B52137FfF714150C7Eb69E160;
    address cashManagementUSDCPoolManager = 0x219654A61a0BC394055652986BE403fa14405Bb8;
    address cashManagementUSDTPoolManager = 0xE76b219f83E887E2503E14c343Bb7E0B62A7Af5d;
    address icebreakerPoolManager         = 0xC0323b64eF95E5698B30fEbD6A54BFD66ca2210E;
    address mapleDirectUSDCPoolManager    = 0x5eE9587Bf5f4ccceEEd87B0216a31EBb513fAC25;
    address mavenPermissionedPoolManager  = 0x24617612DeC91855e126e6330580425F6A262ee9;
    address mavenUsdc3PoolManager         = 0x83376E49c7Bf776495313C89F9Bf226c8b8971B6;
    address mavenUsdcPoolManager          = 0x00d950A41a0d277ed91bF9fD366a5523FEF0371e;
    address mavenWethPoolManager          = 0x833A5c9Fc016a87419D21B10B64e24082Bd1e49d;
    address orthogonalPoolManager         = 0xE10A065D15A6eCA69bb8A0063Fe57eDdb66999DF;

    address aqruPool               = 0xe9d33286f0E37f517B1204aA6dA085564414996d;
    address cashManagementUSDCPool = 0xfe119e9C24ab79F1bDd5dd884B86Ceea2eE75D92;
    address cashManagementUSDTPool = 0xf05681A33a9ADF14076990789A89ab3dA3F6B536;
    address icebreakerPool         = 0x137F2EA5cfB0fE59408BAb2779E33EE868F1810E;
    address mapleDirectUSDCPool    = 0xc1dD3F011290F212227170F0D02F511EBF57E433;
    address mavenPermissionedPool  = 0x00e0C1ea2085e30E5233E98CFA940ca8cbB1b0b7;
    address mavenUsdc3Pool         = 0xD2b01f8327eECa47829EFC731F1A89C6d07E6B92;
    address mavenUsdcPool          = 0xd3cd37a7299B963bbc69592e5Ba933388f70dc88;
    address mavenWethPool          = 0xFfF9A1CAf78b2e5b0A49355a8637EA78b43fB6c3;
    address orthogonalPool         = 0x79400A2c9a5E2431419CaC98Bf46893c86E8bDd7;

    address aqruOpenTermLoanManager = 0x483082e93635ef280bc5E9f65575A7ff288aBA33;
    address aqruActiveOpenTermLoan  = 0x29356F80d6016583C03991Cda7Dd42259517c005;

    address lp = makeAddr("lp");

    uint256 stablecoinAmount = 1_337e6;
    uint256 wethAmount       = 10e18;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 26_096_404);

        startingTime = block.timestamp;

        upgradeProtocol({
            attachAaveAndSkyStrategies: true
        });
    }

    /**************************************************************************************************************************************/
    /*** LP Tests                                                                                                                       ***/
    /**************************************************************************************************************************************/

    function testFork_modularRelease_aqru_lps() external {
        setLiquidityCap(aqruPoolManager, type(uint256).max);

        uint256 poolAssetBalance = IERC20(USDC).balanceOf(aqruPool);
        uint256 sharesMinted     = deposit(aqruPool, lp, stablecoinAmount);

        assertEq(IERC20(USDC).balanceOf(lp),       0);
        assertEq(IERC20(USDC).balanceOf(aqruPool), poolAssetBalance + stablecoinAmount);

        assertEq(IPool(aqruPool).balanceOf(lp), sharesMinted);

        requestRedeem(aqruPool, lp, sharesMinted);

        uint256 assetsWithdrawn = processCyclicalRedeem(aqruPool, lp);

        assertEq(IERC20(USDC).balanceOf(lp),       assetsWithdrawn);
        assertEq(IERC20(USDC).balanceOf(aqruPool), poolAssetBalance + stablecoinAmount - assetsWithdrawn);

        assertEq(IPool(aqruPool).balanceOf(lp), 0);
    }

    function testFork_modularRelease_cashManagementUSDC_lps() external {
        drainRedemptionQueue(cashManagementUSDCPool);
        setLiquidityCap(cashManagementUSDCPoolManager, type(uint256).max);

        uint256 poolAssetBalance = IERC20(USDC).balanceOf(cashManagementUSDCPool);
        uint256 sharesMinted     = deposit(cashManagementUSDCPool, lp, stablecoinAmount);

        assertEq(IERC20(USDC).balanceOf(lp),                     0);
        assertEq(IERC20(USDC).balanceOf(cashManagementUSDCPool), poolAssetBalance + stablecoinAmount);

        assertEq(IPool(cashManagementUSDCPool).balanceOf(lp), sharesMinted);

        requestRedeem(cashManagementUSDCPool, lp, sharesMinted);
        processQueueRedeem(cashManagementUSDCPool, lp);

        // NOTE: Rounding error in favor of the protocol.
        assertEq(IERC20(USDC).balanceOf(lp),                     stablecoinAmount - 1);
        assertEq(IERC20(USDC).balanceOf(cashManagementUSDCPool), poolAssetBalance + 1);

        assertEq(IPool(cashManagementUSDCPool).balanceOf(lp), 0);
    }

    function testFork_modularRelease_cashManagementUSDT_lps() external {
        drainRedemptionQueue(cashManagementUSDTPool);
        setLiquidityCap(cashManagementUSDTPoolManager, type(uint256).max);

        uint256 sharesMinted = deposit(cashManagementUSDTPool, lp, stablecoinAmount);

        assertEq(IERC20(USDT).balanceOf(lp),                     0);
        assertEq(IERC20(USDT).balanceOf(cashManagementUSDTPool), stablecoinAmount);

        assertEq(IPool(cashManagementUSDTPool).balanceOf(lp), sharesMinted);

        requestRedeem(cashManagementUSDTPool, lp, sharesMinted);
        processQueueRedeem(cashManagementUSDTPool, lp);

        assertEq(IERC20(USDT).balanceOf(lp),                     stablecoinAmount);
        assertEq(IERC20(USDT).balanceOf(cashManagementUSDTPool), 0);

        assertEq(IPool(cashManagementUSDTPool).balanceOf(lp), 0);
    }

    function testFork_modularRelease_icebreaker_lps() external {
        setLiquidityCap(icebreakerPoolManager, type(uint256).max);
        deposit(icebreakerPool, lp, stablecoinAmount);

        // NOTE: Initial deposit reduced due to bootstrap mint.
        uint256 bootstrapMint = 1e5;
        uint256 sharesMinted  = stablecoinAmount - bootstrapMint;

        assertEq(IERC20(USDC).balanceOf(lp),             0);
        assertEq(IERC20(USDC).balanceOf(icebreakerPool), stablecoinAmount);

        assertEq(IPool(icebreakerPool).balanceOf(lp), sharesMinted);

        requestRedeem(icebreakerPool, lp, sharesMinted);
        processCyclicalRedeem(icebreakerPool, lp);

        assertEq(IERC20(USDC).balanceOf(lp),             sharesMinted);
        assertEq(IERC20(USDC).balanceOf(icebreakerPool), bootstrapMint);

        assertEq(IPool(icebreakerPool).balanceOf(lp), 0);
    }

    function testFork_modularRelease_mapleDirectUSDC_lps() external {
        drainRedemptionQueue(mapleDirectUSDCPool);
        setLiquidityCap(mapleDirectUSDCPoolManager, type(uint256).max);

        uint256 poolAssetBalance = IERC20(USDC).balanceOf(mapleDirectUSDCPool);
        uint256 sharesMinted     = deposit(mapleDirectUSDCPool, lp, stablecoinAmount);

        assertEq(IERC20(USDC).balanceOf(lp),                  0);
        assertEq(IERC20(USDC).balanceOf(mapleDirectUSDCPool), poolAssetBalance + stablecoinAmount);

        assertEq(IPool(mapleDirectUSDCPool).balanceOf(lp), sharesMinted);

        requestRedeem(mapleDirectUSDCPool, lp, sharesMinted);
        processQueueRedeem(mapleDirectUSDCPool, lp);

        // NOTE: Rounding error in favor of the protocol.
        assertEq(IERC20(USDC).balanceOf(lp),                  stablecoinAmount - 1);
        assertEq(IERC20(USDC).balanceOf(mapleDirectUSDCPool), poolAssetBalance + 1);

        assertEq(IPool(mapleDirectUSDCPool).balanceOf(lp), 0);
    }

    function testFork_modularRelease_mavenPermissioned_lps() external {
        setLiquidityCap(mavenPermissionedPoolManager, type(uint256).max);

        uint256 poolAssetBalance = IERC20(USDC).balanceOf(mavenPermissionedPool);
        uint256 sharesMinted     = deposit(mavenPermissionedPool, lp, stablecoinAmount);

        assertEq(IERC20(USDC).balanceOf(lp),                    0);
        assertEq(IERC20(USDC).balanceOf(mavenPermissionedPool), poolAssetBalance + stablecoinAmount);

        assertEq(IPool(mavenPermissionedPool).balanceOf(lp), sharesMinted);

        requestRedeem(mavenPermissionedPool, lp, sharesMinted);
        processCyclicalRedeem(mavenPermissionedPool, lp);

        // NOTE: Rounding error in favor of the protocol.
        assertEq(IERC20(USDC).balanceOf(lp),                    stablecoinAmount - 1);
        assertEq(IERC20(USDC).balanceOf(mavenPermissionedPool), poolAssetBalance + 1);

        assertEq(IPool(mavenPermissionedPool).balanceOf(lp), 0);
    }

    function testFork_modularRelease_mavenUsdc3_lps() external {
        uint256 poolAssetBalance = IERC20(USDC).balanceOf(mavenUsdc3Pool);
        uint256 sharesMinted     = deposit(mavenUsdc3Pool, lp, stablecoinAmount);

        assertEq(IERC20(USDC).balanceOf(lp),             0);
        assertEq(IERC20(USDC).balanceOf(mavenUsdc3Pool), poolAssetBalance + stablecoinAmount);

        assertEq(IPool(mavenUsdc3Pool).balanceOf(lp), sharesMinted);

        requestRedeem(mavenUsdc3Pool, lp, sharesMinted);
        processCyclicalRedeem(mavenUsdc3Pool, lp);

        // NOTE: Rounding error in favor of the protocol.
        assertEq(IERC20(USDC).balanceOf(lp),             stablecoinAmount - 1);
        assertEq(IERC20(USDC).balanceOf(mavenUsdc3Pool), poolAssetBalance + 1);

        assertEq(IPool(mavenUsdc3Pool).balanceOf(lp), 0);
    }

    function testFork_modularRelease_mavenUsdc_lps() external {
        uint256 poolAssetBalance = IERC20(USDC).balanceOf(mavenUsdcPool);
        uint256 sharesMinted     = deposit(mavenUsdcPool, lp, stablecoinAmount);

        assertEq(IERC20(USDC).balanceOf(lp),            0);
        assertEq(IERC20(USDC).balanceOf(mavenUsdcPool), poolAssetBalance + stablecoinAmount);

        assertEq(IPool(mavenUsdcPool).balanceOf(lp), sharesMinted);

        requestRedeem(mavenUsdcPool, lp, sharesMinted);
        processCyclicalRedeem(mavenUsdcPool, lp);

        // NOTE: Rounding error in favor of the protocol.
        assertEq(IERC20(USDC).balanceOf(lp),            stablecoinAmount - 1);
        assertEq(IERC20(USDC).balanceOf(mavenUsdcPool), poolAssetBalance + 1);

        assertEq(IPool(mavenUsdcPool).balanceOf(lp), 0);
    }

    function testFork_modularRelease_mavenWeth_lps() external {
        uint256 poolAssetBalance = IERC20(WETH).balanceOf(mavenWethPool);
        uint256 sharesMinted     = deposit(mavenWethPool, lp, wethAmount);

        assertEq(IERC20(WETH).balanceOf(lp),            0);
        assertEq(IERC20(WETH).balanceOf(mavenWethPool), poolAssetBalance + wethAmount);

        assertEq(IPool(mavenWethPool).balanceOf(lp), sharesMinted);

        requestRedeem(mavenWethPool, lp, sharesMinted);
        processCyclicalRedeem(mavenWethPool, lp);

        // NOTE: Rounding error in favor of the protocol.
        assertEq(IERC20(WETH).balanceOf(lp),            wethAmount - 1);
        assertEq(IERC20(WETH).balanceOf(mavenWethPool), poolAssetBalance + 1);

        assertEq(IPool(mavenWethPool).balanceOf(lp), 0);
    }

    function testFork_modularRelease_orthogonal_lps() external {
        setLiquidityCap(orthogonalPoolManager, type(uint256).max);

        uint256 poolAssetBalance = IERC20(USDC).balanceOf(orthogonalPool);
        uint256 sharesMinted     = deposit(orthogonalPool, lp, stablecoinAmount);

        assertEq(IERC20(USDC).balanceOf(lp),             0);
        assertEq(IERC20(USDC).balanceOf(orthogonalPool), poolAssetBalance + stablecoinAmount);

        assertEq(IPool(orthogonalPool).balanceOf(lp), sharesMinted);

        requestRedeem(orthogonalPool, lp, sharesMinted);
        processCyclicalRedeem(orthogonalPool, lp);

        // NOTE: Rounding error in favor of the protocol.
        assertEq(IERC20(USDC).balanceOf(lp),             stablecoinAmount - 1);
        assertEq(IERC20(USDC).balanceOf(orthogonalPool), poolAssetBalance + 1);

        assertEq(IPool(orthogonalPool).balanceOf(lp), 0);
    }

    /**************************************************************************************************************************************/
    /*** Loan Tests                                                                                                                     ***/
    /**************************************************************************************************************************************/

    function testFork_modularRelease_aqru_fundNewLoan() external {
        address borrower  = makeAddr("otlmBorrower");
        uint256 principal = 1_000e6;

        uint256 lockedLiquidity = IWithdrawalManagerCyclical(IPoolManager(aqruPoolManager).withdrawalManager()).lockedLiquidity();

        setLiquidityCap(aqruPoolManager, type(uint256).max);
        deposit(aqruPool, makeAddr("otlmLiquidityProvider"), lockedLiquidity + principal);

        uint256[3] memory terms = [uint256(5 days), 5 days, 30 days];
        uint256[4] memory rates = [uint256(0.03e6), 0.1e6, 0, 0];

        address loan = createOpenTermLoan(openTermLoanFactory, borrower, aqruOpenTermLoanManager, USDC, principal, terms, rates);

        uint256 poolBalance  = IERC20(USDC).balanceOf(aqruPool);
        uint256 principalOut = IOpenTermLoanManager(aqruOpenTermLoanManager).principalOut();

        assertEq(IOpenTermLoanManager(aqruOpenTermLoanManager).principalOut(), principalOut);

        assertEq(IOpenTermLoan(loan).dateFunded(), 0);
        assertEq(IOpenTermLoan(loan).principal(),  principal);

        assertEq(IERC20(USDC).balanceOf(borrower), 0);
        assertEq(IERC20(USDC).balanceOf(aqruPool), poolBalance);

        fundLoan(loan);

        assertEq(IOpenTermLoanManager(aqruOpenTermLoanManager).principalOut(), principalOut + principal);

        assertEq(IOpenTermLoan(loan).dateFunded(), block.timestamp);
        assertEq(IOpenTermLoan(loan).principal(),  principal);

        assertEq(IERC20(USDC).balanceOf(borrower), principal);
        assertEq(IERC20(USDC).balanceOf(aqruPool), poolBalance - principal);
    }

    function testFork_modularRelease_aqru_callLoan() external {
        uint256 principal = IOpenTermLoan(aqruActiveOpenTermLoan).principal();

        assertEq(IOpenTermLoan(aqruActiveOpenTermLoan).isCalled(),        false);
        assertEq(IOpenTermLoan(aqruActiveOpenTermLoan).dateCalled(),      0);
        assertEq(IOpenTermLoan(aqruActiveOpenTermLoan).calledPrincipal(), 0);

        callLoan(aqruActiveOpenTermLoan, principal);

        assertEq(IOpenTermLoan(aqruActiveOpenTermLoan).isCalled(),        true);
        assertEq(IOpenTermLoan(aqruActiveOpenTermLoan).dateCalled(),      block.timestamp);
        assertEq(IOpenTermLoan(aqruActiveOpenTermLoan).calledPrincipal(), principal);
    }

    function testFork_modularRelease_aqru_impairLoan() external {
        assertEq(IOpenTermLoan(aqruActiveOpenTermLoan).isImpaired(),   false);
        assertEq(IOpenTermLoan(aqruActiveOpenTermLoan).dateImpaired(), 0);

        (uint40 impairedDate, bool impairedByGovernor) = IOpenTermLoanManager(aqruOpenTermLoanManager).impairmentFor(aqruActiveOpenTermLoan);

        assertEq(impairedDate,       0);
        assertEq(impairedByGovernor, false);

        impairLoan(aqruActiveOpenTermLoan);

        assertEq(IOpenTermLoan(aqruActiveOpenTermLoan).isImpaired(),   true);
        assertEq(IOpenTermLoan(aqruActiveOpenTermLoan).dateImpaired(), block.timestamp);

        (impairedDate, impairedByGovernor) = IOpenTermLoanManager(aqruOpenTermLoanManager).impairmentFor(aqruActiveOpenTermLoan);

        assertEq(impairedDate,       block.timestamp);
        assertEq(impairedByGovernor, false);
    }

    function testFork_modularRelease_aqru_refinance() external {
        uint64  currentInterestRate = IOpenTermLoan(aqruActiveOpenTermLoan).interestRate();
        uint64  newInterestRate     = currentInterestRate + 0.01e6;
        uint256 deadline            = block.timestamp + 3 days;

        bytes[] memory calls = new bytes[](1);

        calls[0] = abi.encodeWithSignature("setInterestRate(uint64)", newInterestRate);

        bytes32 expectedCommitment = keccak256(abi.encode(openTermRefinancer, deadline, calls));

        proposeRefinanceOT(aqruActiveOpenTermLoan, openTermRefinancer, deadline, calls);

        assertEq(IOpenTermLoan(aqruActiveOpenTermLoan).refinanceCommitment(), expectedCommitment);
        assertEq(IOpenTermLoan(aqruActiveOpenTermLoan).interestRate(),        currentInterestRate);

        // NOTE: Accepting new terms settles all outstanding interest first, so the borrower needs funds on hand.
        erc20_mint(USDC, IOpenTermLoan(aqruActiveOpenTermLoan).borrower(), 1_000_000e6);

        acceptRefinanceOT(aqruActiveOpenTermLoan, openTermRefinancer, deadline, calls);

        assertEq(IOpenTermLoan(aqruActiveOpenTermLoan).refinanceCommitment(), bytes32(0));
        assertEq(IOpenTermLoan(aqruActiveOpenTermLoan).interestRate(),        newInterestRate);
    }

    /**************************************************************************************************************************************/
    /*** Utility Functions                                                                                                              ***/
    /**************************************************************************************************************************************/

    function drainRedemptionQueue(address pool) internal {
        address poolManager       = IPool(pool).manager();
        address withdrawalManager = IPoolManager(poolManager).withdrawalManager();
        uint256 pendingShares     = IWithdrawalManagerQueue(withdrawalManager).totalShares();

        if (pendingShares == 0) return;

        processRedemptions(pool, pendingShares);
    }

    function processCyclicalRedeem(address pool, address account) internal returns (uint256 assets) {
        address poolManager       = IPool(pool).manager();
        address withdrawalManager = IPoolManager(poolManager).withdrawalManager();
        uint256 exitCycleId       = IWithdrawalManagerCyclical(withdrawalManager).exitCycleId(account);
        uint256 lockedShares      = IWithdrawalManagerCyclical(withdrawalManager).lockedShares(account);

        (uint256 windowStart,) = IWithdrawalManagerCyclical(withdrawalManager).getWindowAtId(exitCycleId);

        vm.warp(windowStart);

        uint256 toppedUp = topUpCyclicalLiquidity(pool, withdrawalManager, exitCycleId);

        assets = redeem(pool, account, lockedShares);

        removeExcessLiquidity(pool, toppedUp);
    }

    function processQueueRedeem(address pool, address account) internal returns (uint256 assets) {
        address asset             = IPool(pool).asset();
        address poolManager       = IPool(pool).manager();
        address withdrawalManager = IPoolManager(poolManager).withdrawalManager();

        uint256 balance       = IERC20(asset).balanceOf(account);
        uint256 pendingShares = IWithdrawalManagerQueue(withdrawalManager).totalShares();

        uint256 toppedUp = topUpPoolLiquidity(pool);

        processRedemptions(pool, pendingShares);

        removeExcessLiquidity(pool, toppedUp);

        assets = IERC20(asset).balanceOf(account) - balance;
    }

    function removeExcessLiquidity(address pool, uint256 amount) internal {
        if (amount == 0) return;

        address asset = IPool(pool).asset();

        vm.prank(pool);
        IERC20(asset).transfer(address(0xdead), amount);
    }

    function topUpCyclicalLiquidity(address pool, address withdrawalManager, uint256 exitCycleId) internal returns (uint256 toppedUp) {
        address poolManager = IPool(pool).manager();
        address asset       = IPool(pool).asset();

        uint256 poolBalance           = IERC20(asset).balanceOf(pool);
        uint256 totalAssetsWithLosses = IPoolManager(poolManager).totalAssets() - IPoolManager(poolManager).unrealizedLosses();
        uint256 elsewhere             = totalAssetsWithLosses - poolBalance;

        uint256 totalCycleShares = IWithdrawalManagerCyclical(withdrawalManager).totalCycleShares(exitCycleId);
        uint256 totalSupply      = IPool(pool).totalSupply();

        if (totalCycleShares == 0 || totalCycleShares >= totalSupply) return 0;

        // Rounded up by one to clear integer-division truncation at the boundary.
        uint256 requiredBalance = (totalCycleShares * elsewhere) / (totalSupply - totalCycleShares) + 1;

        if (poolBalance >= requiredBalance) return 0;

        toppedUp = requiredBalance - poolBalance;

        erc20_mint(asset, pool, toppedUp);
    }

    function topUpPoolLiquidity(address pool) internal returns (uint256 toppedUp) {
        address asset          = IPool(pool).asset();
        uint256 currentBalance = IERC20(asset).balanceOf(pool);
        uint256 totalAssets    = IPool(pool).totalAssets();

        if (currentBalance >= totalAssets) return 0;

        toppedUp = totalAssets - currentBalance;

        erc20_mint(asset, pool, toppedUp);
    }

}
