// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IPoolPermissionManager } from "../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../TestBase.sol";

import { FixedTermLoanManagerHarness } from "./utils/FixedTermLoanManagerHarness.sol";

contract PoolViewFunctionsFuzzTests is TestBase {

    address user;

    uint256 constant MAX_TOTAL_ASSET   = 1e29;
    uint256 constant MAX_LIQUIDITY_CAP = 1e29;

    uint256 constant BITMAP = 1;

    uint256 constant PRIVATE        = 0;
    uint256 constant FUNCTION_LEVEL = 1;
    uint256 constant POOL_LEVEL     = 2;
    uint256 constant PUBLIC         = 3;

    FixedTermLoanManagerHarness loanManagerHarness;

    function setUp() public override {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createPoolWithQueue();
        _configurePool();

        allowLender(address(poolManager), address(queueWM));

        user = makeAddr("user");

        address loanManager = poolManager.loanManagerList(0);

        vm.etch(loanManager, address(new FixedTermLoanManagerHarness()).code);

        loanManagerHarness = FixedTermLoanManagerHarness(loanManager);
    }

    function testFuzz_getTotalAssetsFromPM(uint256 principalOut_, uint256 accountedInterest_) external {
        principalOut_      = bound(principalOut_,      1, 1e29);
        accountedInterest_ = bound(accountedInterest_, 1, 1e29);

        loanManagerHarness.__setPrincipalOut(principalOut_);
        loanManagerHarness.__setAccountedInterest(accountedInterest_);

        assertEq(poolManager.totalAssets(), pool.totalAssets());
    }

    function testFuzz_getUnrealizedLossesFromPM(uint256 unrealizedLosses_) external {
        unrealizedLosses_ = bound(unrealizedLosses_, 1, 1e29);

        loanManagerHarness.__setUnrealizedLosses(unrealizedLosses_);

        assertEq(poolManager.unrealizedLosses(), pool.unrealizedLosses());
    }

    function testFuzz_convertToAssets_whenTotalSupplyIsZero(uint256 sharesAmount_) external {
        sharesAmount_ = bound(sharesAmount_, 0, 1e29);

        assertEq(pool.totalSupply(),                  0);
        assertEq(pool.convertToAssets(sharesAmount_), sharesAmount_);
    }

    function testFuzz_convertToAssets_whenTotalSupplyExists(
        uint256 sharesAmount_,
        uint256 amountToDeposit_,
        uint256 principalOut_,
        uint256 accountedInterest_
    )
        external
    {
        sharesAmount_      = bound(sharesAmount_,      0, 1e29);
        amountToDeposit_   = bound(amountToDeposit_,   1, 1e29);
        principalOut_      = bound(principalOut_,      1, 1e29);
        accountedInterest_ = bound(accountedInterest_, 1, 1e29);

        loanManagerHarness.__setPrincipalOut(principalOut_);
        loanManagerHarness.__setAccountedInterest(accountedInterest_);

        deposit(address(pool), user, amountToDeposit_);

        // Check totalSupply increased
        assertEq(pool.totalSupply(), amountToDeposit_);

        uint256 assetsAmount = pool.convertToAssets(sharesAmount_);

        // Calculate the expected amount
        assertEq(assetsAmount, (sharesAmount_ * pool.totalAssets()) / pool.totalSupply());
    }

    function testFuzz_convertToShares_whenTotalSupplyIsZero(uint256 assetAmount_) external {
        assetAmount_ = bound(assetAmount_, 0, 1e29);

        assertEq(pool.totalSupply(),                 0);
        assertEq(pool.convertToShares(assetAmount_), assetAmount_);
    }

    function testFuzz_convertToShares_whenTotalSupplyExists(
        uint256 assetAmount_,
        uint256 amountToDeposit_,
        uint256 principalOut_,
        uint256 accountedInterest_
    )
        external
    {
        assetAmount_       = bound(assetAmount_,       0, 1e29);
        amountToDeposit_   = bound(amountToDeposit_,   1, 1e29);
        principalOut_      = bound(principalOut_,      1, 1e29);
        accountedInterest_ = bound(accountedInterest_, 1, 1e29);

        loanManagerHarness.__setPrincipalOut(principalOut_);
        loanManagerHarness.__setAccountedInterest(accountedInterest_);

        deposit(address(pool), user, amountToDeposit_);

        // Check totalSupply increased
        assertEq(pool.totalSupply(), amountToDeposit_);

        uint256 sharesAmount = pool.convertToShares(assetAmount_);

        // Calculate the expected amount
        assertEq(sharesAmount, (assetAmount_ * pool.totalSupply()) / pool.totalAssets());
    }

    function testFuzz_convertToExitShares(
        uint256 assetAmount_,
        uint256 amountToDeposit_,
        uint256 principalOut_,
        uint256 accountedInterest_,
        uint256 unrealizedLosses_
    )
        external
    {
        assetAmount_       = bound(assetAmount_,       0, 1e29);
        amountToDeposit_   = bound(amountToDeposit_,   1, 1e29);
        principalOut_      = bound(principalOut_,      1, 1e29);
        accountedInterest_ = bound(accountedInterest_, 1, 1e29);
        unrealizedLosses_  = bound(unrealizedLosses_,  1, amountToDeposit_);

        loanManagerHarness.__setPrincipalOut(principalOut_);
        loanManagerHarness.__setAccountedInterest(accountedInterest_);
        loanManagerHarness.__setUnrealizedLosses(unrealizedLosses_);

        deposit(address(pool), user, amountToDeposit_);

        // Check totalSupply increased
        assertEq(pool.totalSupply(), amountToDeposit_);

        assertEq(
            pool.convertToExitShares(assetAmount_),
            _divRoundUp(assetAmount_ * pool.totalSupply(), pool.totalAssets() - pool.unrealizedLosses())
        );
    }

    function testFuzz_maxDeposit(uint256 totalAssets, uint256 liquidityCap) external {
        totalAssets  = bound(totalAssets,  1, MAX_TOTAL_ASSET);
        liquidityCap = bound(liquidityCap, 1, MAX_LIQUIDITY_CAP);

        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), "P:deposit", BITMAP);

        vm.prank(poolDelegate);
        poolManager.setLiquidityCap(liquidityCap);

        assertEq(pool.maxDeposit(user), 0);  // without permission

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, user, BITMAP);

        assertEq(pool.maxDeposit(user), liquidityCap);  // with permission

        fundsAsset.mint(address(pool), totalAssets);

        bool depositAllowed = IPoolPermissionManager(address(poolPermissionManager)).hasPermission(address(poolManager), user, "P:deposit");

        uint256 maxAssets = liquidityCap > totalAssets && depositAllowed ? liquidityCap - totalAssets : 0;

        assertEq(pool.maxDeposit(user), maxAssets);
    }

    function testFuzz_maxMint(uint256 totalAssets, uint256 liquidityCap) external {
        totalAssets  = bound(totalAssets,  1, MAX_TOTAL_ASSET);
        liquidityCap = bound(liquidityCap, 1, MAX_LIQUIDITY_CAP);

        setPoolPermissionLevel(address(poolManager), FUNCTION_LEVEL);
        setPoolBitmap(address(poolManager), "P:mint", BITMAP);

        assertEq(pool.maxMint(user), 0);  // without permission

        vm.prank(poolDelegate);
        poolManager.setLiquidityCap(liquidityCap);

        setLenderBitmap(address(poolPermissionManager), permissionAdmin, user, BITMAP);

        assertEq(pool.maxMint(user), liquidityCap);  // with permission

        fundsAsset.mint(address(pool), totalAssets);

        bool depositAllowed = IPoolPermissionManager(address(poolPermissionManager)).hasPermission(address(poolManager), user, "P:mint");

        uint256 maxShares = pool.previewDeposit(liquidityCap > totalAssets && depositAllowed ? liquidityCap - totalAssets : 0);

        assertEq(pool.maxMint(user), maxShares);
    }

    function testFuzz_maxRedeem(uint256 assets) external {
        assets = bound(assets, 1, 1e29);

        openPool(address(poolManager));

        setManualWithdrawal(address(poolManager), user, true);

        deposit(user, assets);

        assertEq(pool.balanceOf(user), assets);

        assertEq(pool.maxRedeem(user), 0);

        vm.prank(user);
        pool.requestRedeem(assets, user);  // lock shares

        processRedemptions(address(pool), assets);  // assets <> shares conversion rate 1:1 due to single LP

        uint256 shares = queueWM.lockedShares(user);

        assertEq(pool.maxRedeem(user), shares);

        redeem(address(pool), user, shares);

        assertEq(pool.maxRedeem(user), 0);
    }

    function testFuzz_maxWithdraw(uint256 assets) external {
        assets = bound(assets, 1, 1e29);

        openPool(address(poolManager));

        deposit(user, assets);

        assertEq(pool.balanceOf(user), assets);

        assertEq(pool.maxWithdraw(user), 0);

        vm.prank(user);
        pool.requestRedeem(assets, user);

        assertEq(pool.maxWithdraw(user), 0);
    }

    function testFuzz_previewDeposit_whenTotalSupplyIsZero(uint256 assetAmount_) external {
        assetAmount_ = bound(assetAmount_, 0, 1e29);

        assertEq(pool.totalSupply(),                0);
        assertEq(pool.previewDeposit(assetAmount_), assetAmount_);
    }

    function testFuzz_previewDeposit_whenTotalSupplyExists(uint256 assetAmount_, uint256 amountToDeposit_) external {
        assetAmount_     = bound(assetAmount_,     0, 1e29);
        amountToDeposit_ = bound(amountToDeposit_, 1, 1e29);

        deposit(address(pool), user, amountToDeposit_);

        // Check totalSupply increased
        assertEq(pool.totalSupply(), amountToDeposit_);

        uint256 sharesAmount = pool.previewDeposit(assetAmount_);

        // Calculate the expected amount
        assertEq(sharesAmount, (assetAmount_ * pool.totalSupply()) / pool.totalAssets());
    }

    function testFuzz_previewMint_whenTotalSupplyIsZero(uint256 sharesAmount_) external {
        sharesAmount_ = bound(sharesAmount_, 0, 1e29);

        assertEq(pool.totalSupply(),              0);
        assertEq(pool.previewMint(sharesAmount_), sharesAmount_);
    }

    function testFuzz_previewMint_whenTotalSupplyExists(
        uint256 sharesAmount_,
        uint256 amountToDeposit_,
        uint256 principalOut_,
        uint256 accountedInterest_
    )
        external
    {
        sharesAmount_      = bound(sharesAmount_,      0, 1e29);
        amountToDeposit_   = bound(amountToDeposit_,   1, 1e29);
        principalOut_      = bound(principalOut_,      1, 1e29);
        accountedInterest_ = bound(accountedInterest_, 1, 1e29);

        loanManagerHarness.__setPrincipalOut(principalOut_);
        loanManagerHarness.__setAccountedInterest(accountedInterest_);

        deposit(address(pool), user, amountToDeposit_);

        // Check totalSupply increased
        assertEq(pool.totalSupply(), amountToDeposit_);

        uint256 assetsAmount = pool.previewMint(sharesAmount_);

        // Calculate the expected amount
        assertEq(assetsAmount, _divRoundUp(sharesAmount_ * pool.totalAssets(), pool.totalSupply()));
    }

    function _divRoundUp(uint256 numerator_, uint256 divisor_) internal pure returns (uint256 result_) {
        result_ = (numerator_ / divisor_) + (numerator_ % divisor_ > 0 ? 1 : 0);
    }

}
