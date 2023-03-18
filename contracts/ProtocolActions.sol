// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IERC20,
    IERC20Like,
    IFixedTermLoan,
    IFeeManager,
    ILoanLike,
    ILoanManagerLike,
    IOpenTermLoan,
    IOpenTermLoanManager,
    IPool,
    IPoolManager
} from "./interfaces/Interfaces.sol";

import { TestUtils } from "../contracts/Contracts.sol";

/// @dev This contract is the reference on how to perform most of the Maple Protocol actions.
contract ProtocolActions is TestUtils {

    address internal MPL  = address(0x33349B282065b0284d756F0577FB39c158F935e6);
    address internal WBTC = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address internal WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address internal USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);

    address internal MPL_SOURCE  = address(0x4937A209D4cDbD3ecD48857277cfd4dA4D82914c);
    address internal WBTC_SOURCE = address(0xBF72Da2Bd84c5170618Fbe5914B0ECA9638d5eb5);
    address internal WETH_SOURCE = address(0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E);
    address internal USDC_SOURCE = address(0x0A59649758aa4d66E25f08Dd01271e891fe52199);

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function erc20_transfer(address asset_, address account_, address destination_, uint256 amount_) internal {
        vm.startPrank(account_);
        IERC20Like(asset_).transfer(destination_, amount_);
        vm.stopPrank();
    }

    function erc20_mint(address asset_, address account_, uint256 amount_) internal {
        // TODO: consider using minters for each token

        if      (asset_ == MPL)  erc20_transfer(MPL,  MPL_SOURCE,  account_, amount_);
        else if (asset_ == WBTC) erc20_transfer(WBTC, WBTC_SOURCE, account_, amount_);
        else if (asset_ == WETH) erc20_transfer(WETH, WETH_SOURCE, account_, amount_);
        else if (asset_ == USDC) erc20_transfer(USDC, USDC_SOURCE, account_, amount_);
        else IERC20Like(asset_).mint(account_, amount_);  // Try to mint ig its not one of the "real" tokens.
    }

    function getCollateralRequiredFor(uint256 principal_, uint256 drawableFunds_, uint256 principalRequested_, uint256 collateralRequired_)
        internal pure
        returns (uint256 collateral_)
    {
        return principal_ <= drawableFunds_
            ? uint256(0)
            : (collateralRequired_ * (principal_ - drawableFunds_) + principalRequested_ - 1) / principalRequested_;
    }

    /**************************************************************************************************************************************/
    /*** Borrow Functions                                                                                                               ***/
    /**************************************************************************************************************************************/

    function close(address loan_) internal {
        ( uint256 principal_, uint256 interest_, uint256 fees_ ) = IFixedTermLoan(loan_).getClosingPaymentBreakdown();

        address borrower_   = ILoanLike(loan_).borrower();
        address fundsAsset_ = ILoanLike(loan_).fundsAsset();
        uint256 payment_    = principal_ + interest_ + fees_;

        erc20_mint(fundsAsset_, borrower_, payment_);

        vm.startPrank(borrower_);
        IERC20(fundsAsset_).approve(loan_, payment_);
        IFixedTermLoan(loan_).closeLoan(payment_);
        vm.stopPrank();
    }

    function drawdown(address loan_, uint256 amount_) internal {
        address borrower_           = ILoanLike(loan_).borrower();
        address collateralAsset_    = IFixedTermLoan(loan_).collateralAsset();
        uint256 collateralRequired_ = IFixedTermLoan(loan_).getAdditionalCollateralRequiredFor(amount_);

        erc20_mint(collateralAsset_, borrower_, collateralRequired_);

        vm.startPrank(borrower_);
        IERC20(collateralAsset_).approve(loan_, collateralRequired_);
        IFixedTermLoan(loan_).drawdownFunds(amount_, borrower_);
        vm.stopPrank();
    }

    // TODO: Use three function structure.
    function makeOpenTermPayment(address loan_) internal returns (uint256 principal_, uint256 totalInterest_, uint256 totalServiceFees_) {
        uint256 interest_;
        uint256 lateInterest_;
        uint256 delegateServiceFee_;
        uint256 platformServiceFee_;

        (
            principal_,
            interest_,
            lateInterest_,
            delegateServiceFee_,
            platformServiceFee_
        ) = IOpenTermLoan(loan_).paymentBreakdown(block.timestamp);

        totalInterest_    = interest_ + lateInterest_;
        totalServiceFees_ = delegateServiceFee_ + platformServiceFee_;

        address borrower_      = IOpenTermLoan(loan_).borrower();
        address fundsAsset_    = IOpenTermLoan(loan_).fundsAsset();
        uint256 paymentAmount_ = principal_ + totalInterest_ + totalServiceFees_;

        erc20_mint(fundsAsset_, borrower_, paymentAmount_);

        vm.startPrank(borrower_);
        IERC20(fundsAsset_).approve(loan_, paymentAmount_);
        IOpenTermLoan(loan_).makePayment(principal_);
        vm.stopPrank();
    }

    function makePayment(address loan_) internal {
        ( uint256 principal_, uint256 interest_, uint256 fees_ ) = IFixedTermLoan(loan_).getNextPaymentBreakdown();

        address borrower_   = ILoanLike(loan_).borrower();
        address fundsAsset_ = ILoanLike(loan_).fundsAsset();
        uint256 payment_    = principal_ + interest_ + fees_;

        erc20_mint(fundsAsset_, borrower_, payment_);

        vm.startPrank(borrower_);
        IERC20(fundsAsset_).approve(loan_, payment_);
        IFixedTermLoan(loan_).makePayment(payment_);
        vm.stopPrank();
    }

    function postCollateral(address loan_, uint256 amount_) internal {
        address borrower_        = ILoanLike(loan_).borrower();
        address collateralAsset_ = IFixedTermLoan(loan_).collateralAsset();

        erc20_mint(collateralAsset_, borrower_, amount_);

        vm.startPrank(borrower_);
        IERC20(collateralAsset_).approve(loan_, amount_);
        IFixedTermLoan(loan_).postCollateral(amount_);
        vm.stopPrank();
    }

    function proposeRefinance(address loan_, address refinancer_, uint256 expiry_, bytes[] memory refinanceCalls_) internal {
        address borrower_ = ILoanLike(loan_).borrower();

        vm.startPrank(borrower_);
        ILoanLike(loan_).proposeNewTerms(refinancer_, expiry_, refinanceCalls_);
        vm.stopPrank();
    }

    function removeCollateral(address loan_, uint256 amount_) internal {
        address borrower_ = ILoanLike(loan_).borrower();

        vm.startPrank(borrower_);
        IFixedTermLoan(loan_).removeCollateral(amount_, borrower_);
        vm.stopPrank();
    }

    function returnFunds(address loan_, uint256 amount_) internal {
        address borrower_   = ILoanLike(loan_).borrower();
        address fundsAsset_ = ILoanLike(loan_).fundsAsset();

        erc20_mint(fundsAsset_, borrower_, amount_);

        vm.startPrank(borrower_);
        IERC20(fundsAsset_).approve(loan_, amount_);
        IFixedTermLoan(loan_).returnFunds(amount_);
        vm.stopPrank();
    }

    function rejectNewTerms(address loan_, address refinancer_, uint256 expiry_, bytes[] memory refinanceCalls_) internal {
        address borrower_ = ILoanLike(loan_).borrower();

        vm.startPrank(borrower_);
        ILoanLike(loan_).rejectNewTerms(refinancer_, expiry_, refinanceCalls_);
        vm.stopPrank();
    }

    /**************************************************************************************************************************************/
    /*** Liquidity Provider Functions                                                                                                   ***/
    /**************************************************************************************************************************************/

    function depositLiquidity(address pool_, address account_, uint256 amount_) internal returns (uint256 shares_) {
        address poolManager_ = IPool(pool_).manager();

        if (!IPoolManager(poolManager_).openToPublic()) allowLender(poolManager_, account_);

        address asset_ = IPool(pool_).asset();

        erc20_mint(asset_, account_, amount_);

        vm.startPrank(account_);
        IERC20(asset_).approve(pool_, amount_);
        shares_ = IPool(pool_).deposit(amount_, account_);
        vm.stopPrank();
    }

    function requestRedeem(address pool_, address account_, uint256 amount_) internal {
        vm.startPrank(account_);
        IPool(pool_).requestRedeem(amount_, account_);
        vm.stopPrank();
    }

    function redeem(address pool_, address account_, uint256 amount_) internal returns (uint256 assets_) {
        vm.startPrank(account_);
        assets_ = IPool(pool_).redeem(amount_, account_, account_);
        vm.stopPrank();
    }

    /**************************************************************************************************************************************/
    /*** Pool Delegate Functions                                                                                                        ***/
    /**************************************************************************************************************************************/
    // TODO: Alphabetically order

    function acceptRefinance(
        address loan_,
        address refinancer_,
        uint256 expiry_,
        bytes[] memory refinanceCalls_,
        uint256 principalIncrease_
    ) internal {
        ILoanManagerLike loanManager_ = ILoanManagerLike(ILoanLike(loan_).lender());

        address poolDelegate_ = IPoolManager(loanManager_.poolManager()).poolDelegate();

        vm.prank(poolDelegate_);
        loanManager_.acceptNewTerms(loan_, refinancer_, expiry_, refinanceCalls_, principalIncrease_);
    }

    function callLoan(address loanManager_, address loan_, uint256 principal_) internal {
        address poolDelegate_ = IPoolManager(ILoanManagerLike(loanManager_).poolManager()).poolDelegate();

        vm.prank(poolDelegate_);
        IOpenTermLoanManager(loanManager_).callPrincipal(loan_, principal_);
    }

    function fundLoan(address loan_) internal {
        ILoanManagerLike loanManager_ = ILoanManagerLike(ILoanLike(loan_).lender());

        address poolDelegate_ = IPoolManager(loanManager_.poolManager()).poolDelegate();

        vm.prank(poolDelegate_);
        loanManager_.fund(loan_);
    }

    function impairLoan(address loan_) internal {
        ILoanManagerLike loanManager_  = ILoanManagerLike(ILoanLike(loan_).lender());

        address poolDelegate_ = IPoolManager(loanManager_.poolManager()).poolDelegate();

        vm.startPrank(poolDelegate_);
        loanManager_.impairLoan(loan_);
        vm.stopPrank();
    }

    function removeLoanCall(address loan_) internal {
        IOpenTermLoanManager loanManager_ = IOpenTermLoanManager(ILoanLike(loan_).lender());

        address poolDelegate_ = IPoolManager(loanManager_.poolManager()).poolDelegate();

        vm.prank(poolDelegate_);
        loanManager_.removeCall(loan_);
    }

    function removeLoanImpairment(address loan_) internal {
        ILoanManagerLike loanManager_ = ILoanManagerLike(ILoanLike(loan_).lender());

        address poolDelegate_ = IPoolManager(loanManager_.poolManager()).poolDelegate();

        vm.startPrank(poolDelegate_);
        loanManager_.removeLoanImpairment(loan_);
        vm.stopPrank();
    }

    function finishCollateralLiquidation(address loan_) internal {
        IPoolManager poolManager_ = IPoolManager(ILoanManagerLike(ILoanLike(loan_).lender()).poolManager());

        address poolDelegate_ = poolManager_.poolDelegate();

        vm.startPrank(poolDelegate_);
        poolManager_.finishCollateralLiquidation(loan_);
        vm.stopPrank();
    }

    function triggerDefault(address loan_, address liquidatorFactory_) internal {
        IPoolManager poolManager_ = IPoolManager(ILoanManagerLike(ILoanLike(loan_).lender()).poolManager());

        address poolDelegate_ = poolManager_.poolDelegate();

        vm.startPrank(poolDelegate_);
        poolManager_.triggerDefault(loan_, liquidatorFactory_);
        vm.stopPrank();
    }

    function depositCover(address poolManager_, uint256 amount_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();
        address asset_        = IPool(IPoolManager(poolManager_).pool()).asset();

        erc20_mint(asset_, poolDelegate_, amount_);

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

    function setDelegateManagementFeeRate(address poolManager_, uint256 rate_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.startPrank(poolDelegate_);
        IPoolManager(poolManager_).setDelegateManagementFeeRate(rate_);
        vm.stopPrank();

        assertEq(IPoolManager(poolManager_).delegateManagementFeeRate(), rate_);
    }

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
