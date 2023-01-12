// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address } from "../../modules/contract-test-utils/contracts/test.sol";

import { TestBase } from "../TestBase.sol";

import { LoanManagerHarness } from "./harnesses/LoanManagerHarness.sol";

contract PoolViewFunctionsFuzzTests is TestBase {

    address internal user;

    LoanManagerHarness internal loanManagerHarness;

    function setUp() public override {
        super.setUp();

        user = address(new Address());

        loanManagerHarness = new LoanManagerHarness();

        vm.etch(address(loanManager), address(loanManagerHarness).code);

        loanManagerHarness = LoanManagerHarness(address(loanManager));
    }

    function testFuzz_getTotalAssetsFromPM(uint256 principalOut_, uint256 accountedInterest_) external {
        principalOut_      = constrictToRange(principalOut_,      1, 1e29);
        accountedInterest_ = constrictToRange(accountedInterest_, 1, 1e29);

        loanManagerHarness.__setPrincipalOut(principalOut_);
        loanManagerHarness.__setAccountedInterest(accountedInterest_);

        assertEq(poolManager.totalAssets(), pool.totalAssets());
    }

    function testFuzz_getUnrealizedLossesFromPM(uint256 unrealizedLosses_) external {
        unrealizedLosses_ = constrictToRange(unrealizedLosses_, 1, 1e29);

        loanManagerHarness.__setUnrealizedLosses(unrealizedLosses_);

        assertEq(poolManager.unrealizedLosses(), pool.unrealizedLosses());
    }

    function testFuzz_convertToAssets_whenTotalSupplyIsZero(uint256 sharesAmount_) external {
        sharesAmount_ = constrictToRange(sharesAmount_, 0, 1e29);

        assertEq(pool.totalSupply(),                 0);
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
        sharesAmount_      = constrictToRange(sharesAmount_,      0, 1e29);
        amountToDeposit_   = constrictToRange(amountToDeposit_,   1, 1e29);
        principalOut_      = constrictToRange(principalOut_,      1, 1e29);
        accountedInterest_ = constrictToRange(accountedInterest_, 1, 1e29);

        loanManagerHarness.__setPrincipalOut(principalOut_);
        loanManagerHarness.__setAccountedInterest(accountedInterest_);

        _mintToUserAndDepositToPool(user, amountToDeposit_);

        // Check totalSupply increased
        assertEq(pool.totalSupply(), amountToDeposit_);

        uint256 assetsAmount = pool.convertToAssets(sharesAmount_);

        // Calculate the expected amount
        assertEq(assetsAmount, (sharesAmount_ * pool.totalAssets()) / pool.totalSupply());
    }

    function testFuzz_convertToShares_whenTotalSupplyIsZero(uint256 assetAmount_) external {
        assetAmount_ = constrictToRange(assetAmount_, 0, 1e29);

        assertEq(pool.totalSupply(),                0);
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
        assetAmount_       = constrictToRange(assetAmount_,       0, 1e29);
        amountToDeposit_   = constrictToRange(amountToDeposit_,   1, 1e29);
        principalOut_      = constrictToRange(principalOut_,      1, 1e29);
        accountedInterest_ = constrictToRange(accountedInterest_, 1, 1e29);

        loanManagerHarness.__setPrincipalOut(principalOut_);
        loanManagerHarness.__setAccountedInterest(accountedInterest_);


        _mintToUserAndDepositToPool(user, amountToDeposit_);

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
        assetAmount_       = constrictToRange(assetAmount_,       0, 1e29);
        amountToDeposit_   = constrictToRange(amountToDeposit_,   1, 1e29);
        principalOut_      = constrictToRange(principalOut_,      1, 1e29);
        accountedInterest_ = constrictToRange(accountedInterest_, 1, 1e29);
        unrealizedLosses_  = constrictToRange(unrealizedLosses_,  1, amountToDeposit_);

        loanManagerHarness.__setPrincipalOut(principalOut_);
        loanManagerHarness.__setAccountedInterest(accountedInterest_);
        loanManagerHarness.__setUnrealizedLosses(unrealizedLosses_);

        _mintToUserAndDepositToPool(user, amountToDeposit_);

        // Check totalSupply increased
        assertEq(pool.totalSupply(), amountToDeposit_);

        assertEq(
            pool.convertToExitShares(assetAmount_),
            _divRoundUp(assetAmount_ * pool.totalSupply(), pool.totalAssets() - pool.unrealizedLosses())
        );
    }

    function testFuzz_previewDeposit_whenTotalSupplyIsZero(uint256 assetAmount_) external {
        assetAmount_ = constrictToRange(assetAmount_, 0, 1e29);

        assertEq(pool.totalSupply(),               0);
        assertEq(pool.previewDeposit(assetAmount_), assetAmount_);
    }

    function testFuzz_previewDeposit_whenTotalSupplyExists(uint256 assetAmount_, uint256 amountToDeposit_) external {
        assetAmount_     = constrictToRange(assetAmount_,     0, 1e29);
        amountToDeposit_ = constrictToRange(amountToDeposit_, 1, 1e29);

        _mintToUserAndDepositToPool(user, amountToDeposit_);

        // Check totalSupply increased
        assertEq(pool.totalSupply(), amountToDeposit_);

        uint256 sharesAmount = pool.previewDeposit(assetAmount_);

        // Calculate the expected amount
        assertEq(sharesAmount, (assetAmount_ * pool.totalSupply()) / pool.totalAssets());
    }

    function testFuzz_previewMint_whenTotalSupplyIsZero(uint256 sharesAmount_) external {
        sharesAmount_ = constrictToRange(sharesAmount_, 0, 1e29);

        assertEq(pool.totalSupply(),             0);
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
        sharesAmount_      = constrictToRange(sharesAmount_,      0, 1e29);
        amountToDeposit_   = constrictToRange(amountToDeposit_,   1, 1e29);
        principalOut_      = constrictToRange(principalOut_,      1, 1e29);
        accountedInterest_ = constrictToRange(accountedInterest_, 1, 1e29);

        loanManagerHarness.__setPrincipalOut(principalOut_);
        loanManagerHarness.__setAccountedInterest(accountedInterest_);

        _mintToUserAndDepositToPool(user, amountToDeposit_);

        // Check totalSupply increased
        assertEq(pool.totalSupply(), amountToDeposit_);

        uint256 assetsAmount = pool.previewMint(sharesAmount_);

        // Calculate the expected amount
        assertEq(assetsAmount, _divRoundUp(sharesAmount_ * pool.totalAssets(), pool.totalSupply()));
    }

    function _mintToUserAndDepositToPool(address user_, uint256 amountToDeposit_) internal {
        // Mint to user
        fundsAsset.mint(user_, amountToDeposit_);
        vm.startPrank(user_);
        fundsAsset.approve(address(pool), amountToDeposit_);

        // Deposit in pool to increase totalSupply
        pool.deposit(amountToDeposit_, user_);
        vm.stopPrank();
    }

    function _divRoundUp(uint256 numerator_, uint256 divisor_) internal pure returns (uint256 result_) {
        result_ = (numerator_ / divisor_) + (numerator_ % divisor_ > 0 ? 1 : 0);
    }

}
