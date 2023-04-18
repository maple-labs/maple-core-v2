// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IERC20,
    IERC20Like,
    IFeeManager,
    IFixedTermLoan,
    IFixedTermLoanManager,
    IGlobals,
    ILoanLike,
    ILoanManagerLike,
    IMapleProxyFactory,
    IOpenTermLoan,
    IOpenTermLoanManager,
    IPool,
    IPoolManager,
    IProxiedLike,
    IWithdrawalManager
} from "./interfaces/Interfaces.sol";

import { Test } from "../contracts/Contracts.sol";

// TODO: `deployPool`.
// TODO: `createLoan`.

/// @dev This contract is the reference on how to perform most of the Maple Protocol actions.
contract ProtocolActions is Test {

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

    function erc20_approve(address asset_, address account_, address spender_, uint256 amount_) internal {
        vm.startPrank(account_);
        IERC20Like(asset_).approve(spender_, amount_);
        vm.stopPrank();
    }

    function erc20_transfer(address asset_, address account_, address destination_, uint256 amount_) internal {
        vm.startPrank(account_);
        IERC20(asset_).transfer(destination_, amount_);
        vm.stopPrank();
    }

    function erc20_mint(address asset_, address account_, uint256 amount_) internal {
        // TODO: Consider using minters for each token.

        if      (asset_ == MPL)  erc20_transfer(MPL,  MPL_SOURCE,  account_, amount_);
        else if (asset_ == WBTC) erc20_transfer(WBTC, WBTC_SOURCE, account_, amount_);
        else if (asset_ == WETH) erc20_transfer(WETH, WETH_SOURCE, account_, amount_);
        else if (asset_ == USDC) erc20_transfer(USDC, USDC_SOURCE, account_, amount_);
        else IERC20Like(asset_).mint(account_, amount_);  // Try to mint if its not one of the "real" tokens.
    }

    function isOpenTermLoan(address loan) internal view returns (bool isOpen) {
        try IOpenTermLoan(loan).dateCalled() {
            isOpen = true;
        } catch { }
    }

    /**************************************************************************************************************************************/
    /*** Borrow Functions                                                                                                               ***/
    /**************************************************************************************************************************************/

    function close(address loan_) internal returns (uint256 principal_, uint256 interest_, uint256 fees_) {
        require(!isOpenTermLoan(loan_), "NOT_SUPPORTED_FOR_OT_LOAN");

        ( principal_, interest_, fees_ ) = IFixedTermLoan(loan_).getClosingPaymentBreakdown();

        address borrower_   = ILoanLike(loan_).borrower();
        address fundsAsset_ = ILoanLike(loan_).fundsAsset();
        uint256 payment_    = principal_ + interest_ + fees_;

        erc20_mint(fundsAsset_, borrower_, payment_);
        erc20_approve(fundsAsset_, borrower_, loan_, payment_);

        vm.startPrank(borrower_);
        ( principal_, interest_, fees_ ) = IFixedTermLoan(loan_).closeLoan(payment_);
        vm.stopPrank();
    }

    function createOpenTermLoan(
        address factory_,
        address borrower_,
        address lender_,
        address asset_,
        uint256 principal_,
        uint256[3] memory terms_,
        uint256[4] memory rates_
    )
        internal returns (address loan_)
    {
        address globals_  = IMapleProxyFactory(factory_).mapleGlobals();
        address governor_ = IGlobals(globals_).governor();

        vm.startPrank(governor_);
        IGlobals(globals_).setValidBorrower(borrower_, true);
        IGlobals(globals_).setCanDeploy(factory_, address(borrower_), true);
        vm.stopPrank();

        vm.prank(borrower_);
        loan_ = IMapleProxyFactory(factory_).createInstance({
            arguments_: abi.encode(
                borrower_,
                lender_,
                asset_,
                principal_,
                [uint32(terms_[0]), uint32(terms_[1]), uint32(terms_[2])],
                [uint64(rates_[0]), uint64(rates_[1]), uint64(rates_[2]), uint64(rates_[3])]
            ),
            salt_: "SALT"
        });
    }

    function drawdown(address loan_, uint256 amount_) internal returns (uint256 collateralPosted_) {
        require(!isOpenTermLoan(loan_), "NOT_SUPPORTED_FOR_OT_LOAN");

        address borrower_           = ILoanLike(loan_).borrower();
        address collateralAsset_    = IFixedTermLoan(loan_).collateralAsset();
        uint256 collateralRequired_ = IFixedTermLoan(loan_).getAdditionalCollateralRequiredFor(amount_);

        erc20_mint(collateralAsset_, borrower_, collateralRequired_);
        erc20_approve(collateralAsset_, borrower_, loan_, collateralRequired_);

        vm.startPrank(borrower_);
        ( collateralPosted_ ) = IFixedTermLoan(loan_).drawdownFunds(amount_, borrower_);
        vm.stopPrank();
    }

    function makePayment(address loan_) internal returns (uint256 principal_, uint256 totalInterest_, uint256 totalFees_) {
        if (isOpenTermLoan(loan_)) {
            uint256 interest_;
            uint256 lateInterest_;
            uint256 delegateServiceFee_;
            uint256 platformServiceFee_;

            ( principal_, interest_, lateInterest_, delegateServiceFee_, platformServiceFee_ ) = makePaymentOT(loan_);

            ( principal_, totalInterest_, totalFees_ )
                = ( principal_, interest_ + lateInterest_, delegateServiceFee_ + platformServiceFee_);
        } else {
            ( principal_, totalInterest_, totalFees_ ) = makePaymentFT(loan_);
        }
    }

    function makePayment(address loan_, uint256 amount_) internal returns (uint256 principal_, uint256 totalInterest_, uint256 totalFees_) {
        if (isOpenTermLoan(loan_)) {
            uint256 interest_;
            uint256 lateInterest_;
            uint256 delegateServiceFee_;
            uint256 platformServiceFee_;

            ( interest_, lateInterest_, delegateServiceFee_, platformServiceFee_ ) = makePaymentOT(loan_, amount_);

            ( principal_, totalInterest_, totalFees_ ) = ( amount_, interest_ + lateInterest_, delegateServiceFee_ + platformServiceFee_);
        } else {
            ( principal_, totalInterest_, totalFees_ ) = makePaymentFT(loan_, amount_);
        }
    }

    function makePaymentFT(address loan_) internal returns (uint256 principal_, uint256 interest_, uint256 fees_) {
        ( principal_, interest_, fees_ ) = IFixedTermLoan(loan_).getNextPaymentBreakdown();
        ( principal_, interest_, fees_ ) = _makePaymentFT(loan_, principal_ + interest_ + fees_);
    }

    function makePaymentFT(address loan_, uint256 amount_) internal returns (uint256 principal_, uint256 interest_, uint256 fees_) {
        ( principal_, interest_, fees_ ) = _makePaymentFT(loan_, amount_);
    }

    function _makePaymentFT(address loan_, uint256 amount_) internal returns (uint256 principal_, uint256 interest_, uint256 fees_) {
        address borrower_   = ILoanLike(loan_).borrower();
        address fundsAsset_ = ILoanLike(loan_).fundsAsset();

        erc20_mint(fundsAsset_, borrower_, amount_);
        erc20_approve(fundsAsset_, borrower_, loan_, amount_);

        vm.startPrank(borrower_);
        ( principal_, interest_, fees_ ) = IFixedTermLoan(loan_).makePayment(amount_);
        vm.stopPrank();
    }

    function makePaymentOT(address loan_) internal
        returns (uint256 principal_, uint256 interest_, uint256 lateInterest_, uint256 delegateServiceFee_, uint256 platformServiceFee_)
    {
        (
            principal_,
            interest_,
            lateInterest_,
            delegateServiceFee_,
            platformServiceFee_
        ) = IOpenTermLoan(loan_).getPaymentBreakdown(block.timestamp);

        uint256 paymentAmount_ = principal_ + interest_ + lateInterest_ + delegateServiceFee_ + platformServiceFee_;

        ( interest_, lateInterest_, delegateServiceFee_, platformServiceFee_ ) = _makePaymentOT(loan_, paymentAmount_, principal_);
    }

    function makePaymentOT(address loan_, uint256 principalToReturn_) internal
        returns (uint256 interest_, uint256 lateInterest_, uint256 delegateServiceFee_, uint256 platformServiceFee_)
    {
        (
            , // UNUSED
            interest_,
            lateInterest_,
            delegateServiceFee_,
            platformServiceFee_
        ) = IOpenTermLoan(loan_).getPaymentBreakdown(block.timestamp);

        uint256 paymentAmount_ = principalToReturn_ + interest_ + lateInterest_ + delegateServiceFee_ + platformServiceFee_;

        ( interest_, lateInterest_, delegateServiceFee_, platformServiceFee_ ) = _makePaymentOT(loan_, paymentAmount_, principalToReturn_);
    }

    function _makePaymentOT(address loan_, uint256 paymentAmount_, uint256 principalToReturn_) internal
        returns (uint256 interest_, uint256 lateInterest_, uint256 delegateServiceFee_, uint256 platformServiceFee_)
    {
        address borrower_   = ILoanLike(loan_).borrower();
        address fundsAsset_ = ILoanLike(loan_).fundsAsset();

        erc20_mint(fundsAsset_, borrower_, paymentAmount_);
        erc20_approve(fundsAsset_, borrower_, loan_, paymentAmount_);

        vm.startPrank(borrower_);
        ( interest_, lateInterest_, delegateServiceFee_, platformServiceFee_ ) = IOpenTermLoan(loan_).makePayment(principalToReturn_);
        vm.stopPrank();
    }

    function postCollateral(address loan_, uint256 amount_) internal returns (uint256 collateralPosted_) {
        require(!isOpenTermLoan(loan_), "NOT_SUPPORTED_FOR_OT_LOAN");

        address borrower_        = ILoanLike(loan_).borrower();
        address collateralAsset_ = IFixedTermLoan(loan_).collateralAsset();

        erc20_mint(collateralAsset_, borrower_, amount_);
        erc20_approve(collateralAsset_, borrower_, loan_, amount_);

        vm.startPrank(borrower_);
        collateralPosted_ = IFixedTermLoan(loan_).postCollateral(amount_);
        vm.stopPrank();
    }

    function removeCollateral(address loan_, uint256 amount_) internal {
        require(!isOpenTermLoan(loan_), "NOT_SUPPORTED_FOR_OT_LOAN");

        address borrower_ = ILoanLike(loan_).borrower();

        vm.startPrank(borrower_);
        IFixedTermLoan(loan_).removeCollateral(amount_, borrower_);
        vm.stopPrank();
    }

    function returnFunds(address loan_, uint256 amount_) internal returns (uint256 fundsReturned_) {
        require(!isOpenTermLoan(loan_), "NOT_SUPPORTED_FOR_OT_LOAN");

        address borrower_   = ILoanLike(loan_).borrower();
        address fundsAsset_ = ILoanLike(loan_).fundsAsset();

        erc20_mint(fundsAsset_, borrower_, amount_);
        erc20_approve(fundsAsset_, borrower_, loan_, amount_);

        vm.startPrank(borrower_);
        fundsReturned_ = IFixedTermLoan(loan_).returnFunds(amount_);
        vm.stopPrank();
    }

    /**************************************************************************************************************************************/
    /*** Refinance Functions                                                                                                            ***/
    /**************************************************************************************************************************************/

    function acceptRefinance(address loan_, address refinancer_, uint256 expiry_, bytes[] memory refinanceCalls_) internal {
        if (isOpenTermLoan(loan_)) return acceptRefinanceOT(loan_, refinancer_, expiry_, refinanceCalls_);

        acceptRefinanceFT(loan_, refinancer_, expiry_, refinanceCalls_, 0);
    }

    function acceptRefinance(
        address loan_,
        address refinancer_,
        uint256 expiry_,
        bytes[] memory refinanceCalls_,
        uint256 principalIncrease_
    ) internal {
        if (isOpenTermLoan(loan_)) return acceptRefinanceOT(loan_, refinancer_, expiry_, refinanceCalls_);

        acceptRefinanceFT(loan_, refinancer_, expiry_, refinanceCalls_, principalIncrease_);
    }

    function acceptRefinanceFT(
        address loan_,
        address refinancer_,
        uint256 expiry_,
        bytes[] memory refinanceCalls_,
        uint256 principalIncrease_
    ) internal {
        address loanManager_ = ILoanLike(loan_).lender();

        address poolDelegate_ = IPoolManager(
            ILoanManagerLike(loanManager_).poolManager()
        ).poolDelegate();

        vm.startPrank(poolDelegate_);
        IFixedTermLoanManager(loanManager_).acceptNewTerms(loan_, refinancer_, expiry_, refinanceCalls_, principalIncrease_);
        vm.stopPrank();
    }

    function acceptRefinanceOT(address loan_, address refinancer_, uint256 expiry_, bytes[] memory refinanceCalls_) internal {
        address borrower = ILoanLike(loan_).borrower();

        vm.startPrank(borrower);
        ILoanLike(loan_).acceptNewTerms(refinancer_, expiry_, refinanceCalls_);
        vm.stopPrank();
    }

    function cancelRefinanceAsBorrower(address loan_, address refinancer_, uint256 expiry_, bytes[] memory refinanceCalls_) internal {
        address borrower_ = ILoanLike(loan_).borrower();

        vm.startPrank(borrower_);
        ILoanLike(loan_).rejectNewTerms(refinancer_, expiry_, refinanceCalls_);
        vm.stopPrank();
    }

    function cancelRefinanceAsLender(address loan_, address refinancer_, uint256 expiry_, bytes[] memory refinanceCalls_) internal {
        address poolDelegate_ = IPoolManager(
            ILoanManagerLike(
                ILoanLike(loan_).lender()
            ).poolManager()
        ).poolDelegate();

        vm.startPrank(poolDelegate_);
        ILoanManagerLike(loan_).rejectNewTerms(loan_, refinancer_, expiry_, refinanceCalls_);
        vm.stopPrank();
    }

    function proposeRefinance(address loan_, address refinancer_, uint256 expiry_, bytes[] memory refinanceCalls_) internal {
        (isOpenTermLoan(loan_) ? proposeRefinanceOT : proposeRefinanceFT)(loan_, refinancer_, expiry_, refinanceCalls_);
    }

    function proposeRefinanceFT(address loan_, address refinancer_, uint256 expiry_, bytes[] memory refinanceCalls_) internal {
        address borrower_ = ILoanLike(loan_).borrower();

        vm.startPrank(borrower_);
        ILoanLike(loan_).proposeNewTerms(refinancer_, expiry_, refinanceCalls_);
        vm.stopPrank();
    }

    function proposeRefinanceOT(address loan_, address refinancer_, uint256 expiry_, bytes[] memory refinanceCalls_) internal {
        address loanManager_ = ILoanLike(loan_).lender();

        address poolDelegate_ = IPoolManager(
            ILoanManagerLike(loanManager_).poolManager()
        ).poolDelegate();

        vm.startPrank(poolDelegate_);
        IOpenTermLoanManager(loanManager_).proposeNewTerms(loan_, refinancer_, expiry_, refinanceCalls_);
        vm.stopPrank();
    }

    /**************************************************************************************************************************************/
    /*** Liquidity Provider Functions                                                                                                   ***/
    /**************************************************************************************************************************************/

    function deposit(address pool_, address account_, uint256 assets_) internal returns (uint256 shares_) {
        address poolManager_ = IPool(pool_).manager();

        if (!IPoolManager(poolManager_).openToPublic()) allowLender(poolManager_, account_);

        address asset_ = IPool(pool_).asset();

        erc20_mint(asset_, account_, assets_);
        erc20_approve(asset_, account_, pool_, assets_);

        vm.startPrank(account_);
        shares_ = IPool(pool_).deposit(assets_, account_);
        vm.stopPrank();
    }

    function depositWithPermit(address pool_, uint256 privateKey_, uint256 assets, uint256 deadline_) internal returns (uint256 shares_) {
        address account_ = vm.addr(privateKey_);
        address asset_   = IPool(pool_).asset();

        (
            uint8   v_,
            bytes32 r_,
            bytes32 s_
        ) = _getValidPermitSignature(asset_, account_, pool_, assets, deadline_, privateKey_);

        address poolManager_ = IPool(pool_).manager();

        if (!IPoolManager(poolManager_).openToPublic()) allowLender(poolManager_, account_);

        erc20_mint(asset_, account_, assets);

        vm.prank(account_);
        shares_ = IPool(pool_).depositWithPermit(assets, account_, deadline_, v_, r_, s_);
    }

    function mint(address pool_, address account_, uint256 shares_) internal returns (uint256 assets_) {
        address poolManager_ = IPool(pool_).manager();

        if (!IPoolManager(poolManager_).openToPublic()) allowLender(poolManager_, account_);

        address asset_ = IPool(pool_).asset();

        assets_ = IPool(pool_).previewMint(shares_);

        erc20_mint(asset_, account_, assets_);
        erc20_approve(asset_, account_, pool_, assets_);

        vm.startPrank(account_);
        assets_ = IPool(pool_).mint(shares_, account_);
        vm.stopPrank();
    }

    function mintWithPermit(address pool_, uint256 privateKey_, uint256 shares_, uint256 deadline_) internal returns (uint256 assets_) {
        address account_ = vm.addr(privateKey_);
        address asset_ = IPool(pool_).asset();

        (
            uint8   v_,
            bytes32 r_,
            bytes32 s_
        ) = _getValidPermitSignature(asset_, account_, pool_, shares_, deadline_, privateKey_);

        address poolManager_ = IPool(pool_).manager();

        if (!IPoolManager(poolManager_).openToPublic()) allowLender(poolManager_, account_);

        assets_ = IPool(pool_).previewMint(shares_);

        erc20_mint(asset_, account_, assets_);

        vm.prank(account_);
        assets_ = IPool(pool_).mintWithPermit(shares_, account_, shares_, deadline_, v_, r_, s_);
    }

    function redeem(address pool_, address account_, uint256 amount_) internal returns (uint256 assets_) {
        vm.startPrank(account_);
        assets_ = IPool(pool_).redeem(amount_, account_, account_);
        vm.stopPrank();
    }

    function removeShares(address pool_, address account_, uint256 amount_) internal returns (uint256 sharesReturned_) {
        vm.startPrank(account_);
        sharesReturned_ = IPool(pool_).removeShares(amount_, account_);
        vm.stopPrank();
    }

    function requestRedeem(address pool_, address account_, uint256 amount_) internal returns (uint256 escrowShares_) {
        vm.startPrank(account_);
        escrowShares_ = IPool(pool_).requestRedeem(amount_, account_);
        vm.stopPrank();
    }

    /**************************************************************************************************************************************/
    /*** Pool Delegate Functions                                                                                                        ***/
    /**************************************************************************************************************************************/

    function acceptPoolDelegate(address poolManager_) internal {
        address pendingPoolDelegate_ = IPoolManager(poolManager_).pendingPoolDelegate();

        vm.startPrank(pendingPoolDelegate_);
        IPoolManager(poolManager_).acceptPoolDelegate();
        vm.stopPrank();
    }

    function addLoanManager(address poolManager_, address loanManagerFactory_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.prank(poolDelegate_);
        IPoolManager(poolManager_).addLoanManager(loanManagerFactory_);
    }

    function allowLender(address poolManager_, address lender_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.startPrank(poolDelegate_);
        IPoolManager(poolManager_).setAllowedLender(lender_, true);
        vm.stopPrank();
    }

    function callLoan(address loan_, uint256 principal_) internal {
        require(isOpenTermLoan(loan_), "NOT_SUPPORTED_FOR_FT_LOAN");

        address loanManager_ = ILoanLike(loan_).lender();

        address poolDelegate_ = IPoolManager(
            ILoanManagerLike(loanManager_).poolManager()
        ).poolDelegate();

        vm.startPrank(poolDelegate_);
        IOpenTermLoanManager(loanManager_).callPrincipal(loan_, principal_);
        vm.stopPrank();
    }

    function depositCover(address poolManager_, uint256 amount_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();
        address asset_        = IPool(IPoolManager(poolManager_).pool()).asset();

        erc20_mint(asset_, poolDelegate_, amount_);
        erc20_approve(asset_, poolDelegate_, poolManager_, amount_);

        vm.startPrank(poolDelegate_);
        IPoolManager(poolManager_).depositCover(amount_);
        vm.stopPrank();

        assertEq(IERC20(asset_).balanceOf(IPoolManager(poolManager_).poolDelegateCover()), amount_);
    }

    function finishCollateralLiquidation(address loan_) internal {
        require(!isOpenTermLoan(loan_), "NOT_SUPPORTED_FOR_OT_LOAN");

        IPoolManager poolManager_ = IPoolManager(
            ILoanManagerLike(
                ILoanLike(loan_).lender()
            ).poolManager()
        );

        address poolDelegate_ = poolManager_.poolDelegate();

        vm.startPrank(poolDelegate_);
        poolManager_.finishCollateralLiquidation(loan_);
        vm.stopPrank();
    }

    function fundLoan(address loan_) internal {
        ILoanManagerLike loanManager_ = ILoanManagerLike(ILoanLike(loan_).lender());

        address poolDelegate_ = IPoolManager(loanManager_.poolManager()).poolDelegate();

        vm.startPrank(poolDelegate_);
        loanManager_.fund(loan_);
        vm.stopPrank();
    }

    function impairLoan(address loan_) internal {
        ILoanManagerLike loanManager_ = ILoanManagerLike(ILoanLike(loan_).lender());

        address poolDelegate_ = IPoolManager(loanManager_.poolManager()).poolDelegate();

        vm.startPrank(poolDelegate_);
        loanManager_.impairLoan(loan_);
        vm.stopPrank();
    }

    function openPool(address poolManager_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.startPrank(poolDelegate_);
        IPoolManager(poolManager_).setOpenToPublic();
        vm.stopPrank();
    }

    function removeLoanCall(address loan_) internal {
        require(isOpenTermLoan(loan_), "NOT_SUPPORTED_FOR_FT_LOAN");

        IOpenTermLoanManager loanManager_ = IOpenTermLoanManager(ILoanLike(loan_).lender());

        address poolDelegate_ = IPoolManager(loanManager_.poolManager()).poolDelegate();

        vm.startPrank(poolDelegate_);
        loanManager_.removeCall(loan_);
        vm.stopPrank();
    }

    function removeLoanImpairment(address loan_) internal {
        ILoanManagerLike loanManager_ = ILoanManagerLike(ILoanLike(loan_).lender());

        address poolDelegate_ = IPoolManager(loanManager_.poolManager()).poolDelegate();

        vm.startPrank(poolDelegate_);
        loanManager_.removeLoanImpairment(loan_);
        vm.stopPrank();
    }

    function setDelegateManagementFeeRate(address poolManager_, uint256 rate_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.startPrank(poolDelegate_);
        IPoolManager(poolManager_).setDelegateManagementFeeRate(rate_);
        vm.stopPrank();
    }

    function setExitConfig(address withdrawalManager_, uint256 cycleDuration_, uint256 windowDuration_) internal {
        address poolDelegate_ = IPoolManager(IWithdrawalManager(withdrawalManager_).poolManager()).poolDelegate();

        vm.startPrank(poolDelegate_);
        IWithdrawalManager(withdrawalManager_).setExitConfig(cycleDuration_, windowDuration_);
        vm.stopPrank();
    }

    function setLiquidityCap(address poolManager_, uint256 amount_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.startPrank(poolDelegate_);
        IPoolManager(poolManager_).setLiquidityCap(amount_);
        vm.stopPrank();
    }

    function setPendingPoolDelegate(address poolManager_, address newPoolDelegate_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.startPrank(poolDelegate_);
        IPoolManager(poolManager_).setPendingPoolDelegate(newPoolDelegate_);
        vm.stopPrank();
    }

    function setWithdrawalManager(address poolManager_, address withdrawalManager_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.startPrank(poolDelegate_);
        IPoolManager(poolManager_).setWithdrawalManager(withdrawalManager_);
        vm.stopPrank();
    }

    function triggerDefault(address loan_, address liquidatorFactory_) internal {
        IPoolManager poolManager_ = IPoolManager(
            ILoanManagerLike(
                ILoanLike(loan_).lender()
            ).poolManager()
        );

        address poolDelegate_ = poolManager_.poolDelegate();

        vm.startPrank(poolDelegate_);
        poolManager_.triggerDefault(loan_, liquidatorFactory_);
        vm.stopPrank();
    }

    function withdrawCover(address poolManager_, uint256 amount_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.startPrank(poolDelegate_);
        IPoolManager(poolManager_).withdrawCover(amount_, poolDelegate_);
        vm.stopPrank();
    }

    function updateAccounting(address loanManager_) internal {
        address poolDelegate_ = IPoolManager(ILoanManagerLike(loanManager_).poolManager()).poolDelegate();

        vm.startPrank(poolDelegate_);
        IFixedTermLoanManager(loanManager_).updateAccounting();
        vm.stopPrank();
    }

    /**************************************************************************************************************************************/
    /*** Governor Functions                                                                                                              **/
    /**************************************************************************************************************************************/

    function setValidBorrower(address globals_, address borrower_, bool valid_) internal {
        IGlobals globals = IGlobals(globals_);

        vm.prank(globals.governor());
        globals.setValidBorrower(borrower_, valid_);
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _getValidPermitSignature(
        address asset_,
        address owner_,
        address spender_,
        uint256 value_,
        uint256 deadline_,
        uint256 ownerSk_
    )
        internal view
        returns (uint8 v_, bytes32 r_, bytes32 s_)
    {
        ( v_, r_, s_ ) = vm.sign(ownerSk_, _getDigest(asset_, owner_, spender_, value_, deadline_));
    }

    // Returns an ERC-2612 `permit` digest for the `owner` to sign
    function _getDigest(address asset_, address owner_, address spender_, uint256 value_, uint256 deadline_)
        private view
        returns (bytes32 digest_)
    {
        digest_ = keccak256(
            abi.encodePacked(
                '\x19\x01',
                IERC20(asset_).DOMAIN_SEPARATOR(),
                keccak256(abi.encode(IERC20(asset_).PERMIT_TYPEHASH(), owner_, spender_, value_, IERC20(asset_).nonces(owner_), deadline_))
            )
        );
    }

    /**************************************************************************************************************************************/
    /*** Governor Functions                                                                                                             ***/
    /**************************************************************************************************************************************/

    function upgradeLoans(address[] memory loans, uint256 version, bytes memory data, address caller) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            vm.prank(caller);
            IProxiedLike(loans[i]).upgrade(version, data);
        }
    }

    function upgradeLoan(address loan, uint256 version, bytes memory data, address caller) internal {
        vm.prank(caller);
        IProxiedLike(loan).upgrade(version, data);
    }

    function upgradeLoanManagerByGovernor(address loanManager, uint256 version, bytes memory data) internal {
        vm.prank(IPoolManager(ILoanManagerLike(loanManager).poolManager()).governor());
        IProxiedLike(loanManager).upgrade(version, data);
    }

    function upgradePoolManagerByGovernor(address poolManager, uint256 version, bytes memory data) internal {
        vm.prank(IPoolManager(poolManager).governor());
        IProxiedLike(poolManager).upgrade(version, data);
    }

}
