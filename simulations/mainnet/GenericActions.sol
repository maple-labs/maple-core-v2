// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestUtils, console } from "../../modules/contract-test-utils/contracts/test.sol";

import { IERC20 }               from "../../modules/erc20/contracts/interfaces/IERC20.sol";
import { IMapleLoan }           from "../../modules/loan-v401/contracts/interfaces/IMapleLoan.sol";
import { IMapleLoanFeeManager } from "../../modules/loan-v401/contracts/interfaces/IMapleLoanFeeManager.sol";
import { IPool }                from "../../modules/pool-v2/contracts/interfaces/IPool.sol";
import { IPoolManager }         from "../../modules/pool-v2/contracts/interfaces/IPoolManager.sol";

import { IERC20Like } from "./Interfaces.sol";

contract GenericActions is TestUtils {

    address internal MPL  = address(0x33349B282065b0284d756F0577FB39c158F935e6);
    address internal WBTC = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address internal WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address internal USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    address internal MPL_SOURCE  = address(0x4937A209D4cDbD3ecD48857277cfd4dA4D82914c);
    address internal WBTC_SOURCE = address(0xBF72Da2Bd84c5170618Fbe5914B0ECA9638d5eb5);
    address internal WETH_SOURCE = address(0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E);
    address internal USDC_SOURCE = address(0x0A59649758aa4d66E25f08Dd01271e891fe52199);

    /******************************************************************************************************************************/
    /*** Helpers                                                                                                                ***/
    /******************************************************************************************************************************/

    function erc20_transfer(address asset_, address account_, address destination_, uint256 amount_) internal {
        vm.startPrank(account_);
        IERC20Like(asset_).transfer(destination_, amount_);
        vm.stopPrank();
    }

    function erc20_mint(address asset_, address account_, uint256 amount_) internal {
        // TODO: consider using minters for each token

        if (asset_ == MPL) erc20_transfer(MPL, MPL_SOURCE, account_, amount_);
        else if (asset_ == WBTC) erc20_transfer(WBTC, WBTC_SOURCE, account_, amount_);
        else if (asset_ == WETH) erc20_transfer(WETH, WETH_SOURCE, account_, amount_);
        else if (asset_ == USDC) erc20_transfer(USDC, USDC_SOURCE, account_, amount_);
        else revert();
    }

    function erc20_fillAccount(address account_, address asset_, uint256 amount_) internal {
        uint256 balance_ = IERC20Like(asset_).balanceOf(account_);

        if (balance_ >= amount_) return;

        uint256 topUp = amount_ - balance_;

        erc20_mint(asset_, account_, topUp);
    }

    function getCollateralRequiredFor(uint256 principal_, uint256 drawableFunds_, uint256 principalRequested_, uint256 collateralRequired_) internal pure returns (uint256 collateral_) {
        return principal_ <= drawableFunds_ ? uint256(0) : (collateralRequired_ * (principal_ - drawableFunds_) + principalRequested_ - 1) / principalRequested_;
    }

    /******************************************************************************************************************************/
    /*** Borrow Functions                                                                                                       ***/
    /******************************************************************************************************************************/

    function closeLoan(address loan_) internal {
        ( uint256 principal_, uint256 interest_, uint256 fees_ ) = IMapleLoan(loan_).getClosingPaymentBreakdown();

        address borrower_   = IMapleLoan(loan_).borrower();
        address fundsAsset_ = IMapleLoan(loan_).fundsAsset();
        uint256 payment_    = principal_ + interest_ + fees_;

        erc20_fillAccount(borrower_, fundsAsset_, payment_);

        vm.startPrank(borrower_);
        IERC20(fundsAsset_).approve(loan_, payment_);
        IMapleLoan(loan_).closeLoan(payment_);
        vm.stopPrank();
    }

    function drawdown(address loan_, uint256 amount_) internal {
        address borrower_           = IMapleLoan(loan_).borrower();
        address collateralAsset_    = IMapleLoan(loan_).collateralAsset();
        uint256 collateralRequired_ = IMapleLoan(loan_).getAdditionalCollateralRequiredFor(amount_);

        erc20_fillAccount(borrower_, collateralAsset_, collateralRequired_);

        vm.startPrank(borrower_);
        IERC20(collateralAsset_).approve(loan_, collateralRequired_);
        IMapleLoan(loan_).drawdownFunds(amount_, borrower_);
        vm.stopPrank();
    }

    function makePayment(address loan_) internal {
        ( uint256 principal_, uint256 interest_, uint256 fees_ ) = IMapleLoan(loan_).getNextPaymentBreakdown();

        address borrower_   = IMapleLoan(loan_).borrower();
        address fundsAsset_ = IMapleLoan(loan_).fundsAsset();
        uint256 payment_    = principal_ + interest_ + fees_;

        erc20_fillAccount(borrower_, fundsAsset_, payment_);

        vm.startPrank(borrower_);
        IERC20(fundsAsset_).approve(loan_, payment_);
        IMapleLoan(loan_).makePayment(payment_);
        vm.stopPrank();
    }

    function postCollateral(address loan_, uint256 amount_) internal {
        address borrower_        = IMapleLoan(loan_).borrower();
        address collateralAsset_ = IMapleLoan(loan_).collateralAsset();

        erc20_fillAccount(borrower_, collateralAsset_, amount_);

        vm.startPrank(borrower_);
        IERC20(collateralAsset_).approve(loan_, amount_);
        IMapleLoan(loan_).postCollateral(amount_);
        vm.stopPrank();
    }

    function proposeRefinance(address loan_, address refinancer_, uint256 expiry_, bytes[] memory refinanceCalls_, uint256 principalIncrease_, uint256 collateralRequiredIncrease_) internal {
        address borrower_              = IMapleLoan(loan_).borrower();
        uint256 newPrincipal_          = IMapleLoan(loan_).principal() + principalIncrease_;
        uint256 newPrincipalRequested_ = IMapleLoan(loan_).principalRequested() + principalIncrease_;
        uint256 newCollateralRequired_ = IMapleLoan(loan_).collateralRequired() + collateralRequiredIncrease_;
        uint256 originationFees_       = IMapleLoanFeeManager(IMapleLoan(loan_).feeManager()).getOriginationFees(loan_, newPrincipalRequested_);
        uint256 drawableFunds_         = IMapleLoan(loan_).drawableFunds();

        if (originationFees_ != 0) {                                    // If there are originationFees_
            if (drawableFunds_ > originationFees_) {                    // and sufficient drawableFunds_ to pay them
                drawableFunds_ -= originationFees_;                     // then decrement from drawableFunds_ for the collateralRequired_ math
            } else {
                returnFunds(loan_, originationFees_ - drawableFunds_);  // else return enough to pay the originationFees_
                drawableFunds_ = 0;                                     // and zero the drawableFunds_ for the collateralRequired_ math
            }
        }

        uint256 requiredCollateral_ = getCollateralRequiredFor(newPrincipal_, drawableFunds_, newPrincipalRequested_, newCollateralRequired_);
        uint256 collateral_         = IMapleLoan(loan_).collateral();

        // If the post-refinance required collateral given the post-refinance drawableFunds, then post collateral.
        if (requiredCollateral_ > collateral_) postCollateral(loan_, requiredCollateral_ - collateral_);

        vm.startPrank(borrower_);
        IMapleLoan(loan_).proposeNewTerms(refinancer_, expiry_, refinanceCalls_);
        vm.stopPrank();
    }

    function removeCollateral(address loan_, uint256 amount_) internal {
        address borrower_   = IMapleLoan(loan_).borrower();

        vm.startPrank(borrower_);
        IMapleLoan(loan_).removeCollateral(amount_, borrower_);
        vm.stopPrank();
    }

    function returnFunds(address loan_, uint256 amount_) internal {
        address borrower_   = IMapleLoan(loan_).borrower();
        address fundsAsset_ = IMapleLoan(loan_).fundsAsset();

        erc20_fillAccount(borrower_, fundsAsset_, amount_);

        vm.startPrank(borrower_);
        IERC20(fundsAsset_).approve(loan_, amount_);
        IMapleLoan(loan_).returnFunds(amount_);
        vm.stopPrank();
    }

    function rejectNewTerms(address loan_, address refinancer_, uint256 expiry_, bytes[] memory refinanceCalls_) internal {
        address borrower_ = IMapleLoan(loan_).borrower();

        vm.startPrank(borrower_);
        IMapleLoan(loan_).rejectNewTerms(refinancer_, expiry_, refinanceCalls_);
        vm.stopPrank();
    }

    /******************************************************************************************************************************/
    /*** Liquidity Provider Functions                                                                                           ***/
    /******************************************************************************************************************************/

    function depositLiquidity(address pool_, address account_, uint256 amount_) internal {
        address poolManager_ = IPool(pool_).manager();

        if (!IPoolManager(poolManager_).openToPublic()) allowLender(poolManager_, account_);

        address asset_ = IPool(pool_).asset();
        uint256 initialBalance_ = IERC20Like(asset_).balanceOf(pool_);

        erc20_fillAccount(account_, asset_, amount_);

        vm.startPrank(account_);
        IERC20(asset_).approve(pool_, amount_);
        uint256 shares_ = IPool(pool_).deposit(amount_, account_);
        vm.stopPrank();

        assertEq(IERC20Like(asset_).balanceOf(pool_),   initialBalance_ + amount_);
        assertEq(IERC20Like(pool_).balanceOf(account_), shares_);
    }

    function requestRedeem(address pool_, address account_, uint256 amount_) internal {
        vm.startPrank(account_);
        IPool(pool_).requestRedeem(amount_, account_);
        vm.stopPrank();
    }

    function redeem(address pool_, address account_, uint256 amount_) internal {
        vm.startPrank(account_);
        IPool(pool_).redeem(amount_, account_, account_);
        vm.stopPrank();
    }

    /******************************************************************************************************************************/
    /*** Pool Delegate Functions                                                                                                ***/
    /******************************************************************************************************************************/

    function acceptRefinance(address poolManager_, address loan_, address refinancer_, uint256 expiry_, bytes[] memory refinanceCalls_, uint256 principalIncrease_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.startPrank(poolDelegate_);
        IPoolManager(poolManager_).acceptNewTerms(loan_, refinancer_, expiry_, refinanceCalls_, principalIncrease_);
        vm.stopPrank();
    }

    function fundLoan(address poolManager_, address loan_) internal {
        address poolDelegate_       = IPoolManager(poolManager_).poolDelegate();
        address loanManager_        = IPoolManager(poolManager_).loanManagerList(0);
        uint256 principalRequested_ = IMapleLoan(loan_).principalRequested();

        vm.startPrank(poolDelegate_);
        IPoolManager(poolManager_).fund(principalRequested_, loan_, loanManager_);
        vm.stopPrank();
    }

    function impairLoan(address poolManager_, address loan_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.startPrank(poolDelegate_);
        IPoolManager(poolManager_).impairLoan(loan_);
        vm.stopPrank();
    }

    function removeLoanImpairment(address poolManager_, address loan_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.startPrank(poolDelegate_);
        IPoolManager(poolManager_).removeLoanImpairment(loan_);
        vm.stopPrank();
    }

    function finishCollateralLiquidation(address poolManager_, address loan_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.startPrank(poolDelegate_);
        IPoolManager(poolManager_).finishCollateralLiquidation(loan_);
        vm.stopPrank();
    }

    function triggerDefault(address poolManager_, address loan_, address liquidatorFactory_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.startPrank(poolDelegate_);
        IPoolManager(poolManager_).triggerDefault(loan_, liquidatorFactory_);
        vm.stopPrank();
    }

    function depositCover(address poolManager_, uint256 amount_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();
        address asset_        = IPool(IPoolManager(poolManager_).pool()).asset();

        erc20_fillAccount(poolDelegate_, asset_, amount_);

        vm.startPrank(poolDelegate_);
        IERC20(asset_).approve(poolManager_, amount_);
        IPoolManager(poolManager_).depositCover(amount_);
        vm.stopPrank();

        assertEq(IERC20Like(asset_).balanceOf(IPoolManager(poolManager_).poolDelegateCover()), amount_);
    }

    function withdrawCover(address poolManager_, uint256 amount_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.startPrank(poolDelegate_);
        IPoolManager(poolManager_).withdrawCover(amount_, poolDelegate_);
        vm.stopPrank();
    }

    function allowLender(address poolManager_, address lender_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.startPrank(poolDelegate_);
        IPoolManager(poolManager_).setAllowedLender(lender_, true);
        vm.stopPrank();
    }

    // NOTE: This works for PoolManagers or PoolV1
    function setLiquidityCap(address poolManager_, uint256 amount_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.startPrank(poolDelegate_);
        IPoolManager(poolManager_).setLiquidityCap(amount_);
        vm.stopPrank();

        assertEq(IPoolManager(poolManager_).liquidityCap(), amount_);
    }

    function openPool(address poolManager_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.startPrank(poolDelegate_);
        IPoolManager(poolManager_).setOpenToPublic();
        vm.stopPrank();
    }

    function setPendingPoolDelegate(address poolManager_, address newPoolDelegate_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.startPrank(poolDelegate_);
        IPoolManager(poolManager_).setPendingPoolDelegate(newPoolDelegate_);
        vm.stopPrank();
    }

    function acceptPoolDelegate(address poolManager_) internal {
        address pendingPoolDelegate_ = IPoolManager(poolManager_).pendingPoolDelegate();

        vm.startPrank(pendingPoolDelegate_);
        IPoolManager(poolManager_).acceptPendingPoolDelegate();
        vm.stopPrank();
    }

}
