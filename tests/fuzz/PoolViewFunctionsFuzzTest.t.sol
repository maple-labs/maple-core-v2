// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { Address } from "../../modules/contract-test-utils/contracts/test.sol";

import { TestBase } from "../../contracts/utilities/TestBase.sol";

import { LoanManagerHarness } from "./harnesses/LoanManagerHarness.sol";

contract PoolViewFunctionsFuzzTests is TestBase {

    address user;

    LoanManagerHarness loanManagerHarness;

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

    function testFuzz_convertToAssets_whenTotalSupplyIsZero(uint256 sharesAmount) external {
        sharesAmount = constrictToRange(sharesAmount, 0, 1e29);

        assertEq(pool.totalSupply(),                 0);
        assertEq(pool.convertToAssets(sharesAmount), sharesAmount);
    }

    function testFuzz_convertToAssets_whenTotalSupplyExists(uint256 sharesAmount, uint256 amountToDeposit, uint256 principalOut_, uint256 accountedInterest_) external {
        sharesAmount       = constrictToRange(sharesAmount,       0, 1e29);
        amountToDeposit    = constrictToRange(amountToDeposit,    1, 1e29);
        principalOut_      = constrictToRange(principalOut_,      1, 1e29);
        accountedInterest_ = constrictToRange(accountedInterest_, 1, 1e29);

        loanManagerHarness.__setPrincipalOut(principalOut_);
        loanManagerHarness.__setAccountedInterest(accountedInterest_);

        _mintToUserAndDepositToPool(user, amountToDeposit);

        // Check totalSupply increased
        assertEq(pool.totalSupply(), amountToDeposit);

        uint256 assetsAmount = pool.convertToAssets(sharesAmount);

        // Calculate the expected amount
        assertEq(assetsAmount, (sharesAmount * pool.totalAssets()) / pool.totalSupply());
    }

    function testFuzz_convertToShares_whenTotalSupplyIsZero(uint256 assetAmount) external {
        assetAmount = constrictToRange(assetAmount, 0, 1e29);

        assertEq(pool.totalSupply(),                0);
        assertEq(pool.convertToShares(assetAmount), assetAmount);
    }

    function testFuzz_convertToShares_whenTotalSupplyExists(uint256 assetAmount, uint256 amountToDeposit, uint256 principalOut_, uint256 accountedInterest_) external {
        assetAmount        = constrictToRange(assetAmount,        0, 1e29);
        amountToDeposit    = constrictToRange(amountToDeposit,    1, 1e29);
        principalOut_      = constrictToRange(principalOut_,      1, 1e29);
        accountedInterest_ = constrictToRange(accountedInterest_, 1, 1e29);

        loanManagerHarness.__setPrincipalOut(principalOut_);
        loanManagerHarness.__setAccountedInterest(accountedInterest_);


        _mintToUserAndDepositToPool(user, amountToDeposit);

        // Check totalSupply increased
        assertEq(pool.totalSupply(), amountToDeposit);

        uint256 sharesAmount = pool.convertToShares(assetAmount);

        // Calculate the expected amount
        assertEq(sharesAmount, (assetAmount * pool.totalSupply()) / pool.totalAssets());
    }

    function testFuzz_convertToExitShares(uint256 assetAmount, uint256 amountToDeposit, uint256 principalOut_, uint256 accountedInterest_, uint256 unrealizedLosses_) external {
        assetAmount        = constrictToRange(assetAmount,        0, 1e29);
        amountToDeposit    = constrictToRange(amountToDeposit,    1, 1e29);
        principalOut_      = constrictToRange(principalOut_,      1, 1e29);
        accountedInterest_ = constrictToRange(accountedInterest_, 1, 1e29);
        unrealizedLosses_  = constrictToRange(unrealizedLosses_,  1, amountToDeposit);

        loanManagerHarness.__setPrincipalOut(principalOut_);
        loanManagerHarness.__setAccountedInterest(accountedInterest_);
        loanManagerHarness.__setUnrealizedLosses(unrealizedLosses_);

        _mintToUserAndDepositToPool(user, amountToDeposit);

        // Check totalSupply increased
        assertEq(pool.totalSupply(), amountToDeposit);

        assertEq(pool.convertToExitShares(assetAmount), _divRoundUp(assetAmount * pool.totalSupply(), pool.totalAssets() - pool.unrealizedLosses()));
    }

    function testFuzz_previewDeposit_whenTotalSupplyIsZero(uint256 assetAmount) external {
        assetAmount = constrictToRange(assetAmount, 0, 1e29);

        assertEq(pool.totalSupply(),               0);
        assertEq(pool.previewDeposit(assetAmount), assetAmount);
    }

    function testFuzz_previewDeposit_whenTotalSupplyExists(uint256 assetAmount, uint256 amountToDeposit) external {
        assetAmount     = constrictToRange(assetAmount,     0, 1e29);
        amountToDeposit = constrictToRange(amountToDeposit, 1, 1e29);

        _mintToUserAndDepositToPool(user, amountToDeposit);

        // Check totalSupply increased
        assertEq(pool.totalSupply(), amountToDeposit);

        uint256 sharesAmount = pool.previewDeposit(assetAmount);

        // Calculate the expected amount
        assertEq(sharesAmount, (assetAmount * pool.totalSupply()) / pool.totalAssets());
    }

    function testFuzz_previewMint_whenTotalSupplyIsZero(uint256 sharesAmount) external {
        sharesAmount = constrictToRange(sharesAmount, 0, 1e29);

        assertEq(pool.totalSupply(),             0);
        assertEq(pool.previewMint(sharesAmount), sharesAmount);
    }

    function testFuzz_previewMint_whenTotalSupplyExists(uint256 sharesAmount, uint256 amountToDeposit, uint256 principalOut_, uint256 accountedInterest_) external {
        sharesAmount       = constrictToRange(sharesAmount,       0, 1e29);
        amountToDeposit    = constrictToRange(amountToDeposit,    1, 1e29);
        principalOut_      = constrictToRange(principalOut_,      1, 1e29);
        accountedInterest_ = constrictToRange(accountedInterest_, 1, 1e29);

        loanManagerHarness.__setPrincipalOut(principalOut_);
        loanManagerHarness.__setAccountedInterest(accountedInterest_);

        _mintToUserAndDepositToPool(user, amountToDeposit);

        // Check totalSupply increased
        assertEq(pool.totalSupply(), amountToDeposit);

        uint256 assetsAmount = pool.previewMint(sharesAmount);

        // Calculate the expected amount
        assertEq(assetsAmount, _divRoundUp(sharesAmount * pool.totalAssets(), pool.totalSupply()));
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
