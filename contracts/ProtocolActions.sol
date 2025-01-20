// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC20,
    IERC20Like,
    IExemptionsManagerLike,
    IFixedTermLoan,
    IFixedTermLoanManager,
    IGlobals,
    IKycERC20Like,
    ILoanLike,
    ILoanManagerLike,
    IMapleProxyFactory,
    INonTransparentProxy,
    IOpenTermLoan,
    IOpenTermLoanManager,
    IPool,
    IPoolDeployer,
    IPoolManager,
    IPoolPermissionManager,
    IPoolPermissionManagerInitializer,
    IProxiedLike,
    IStrategyLike,
    IWithdrawalManagerCyclical as IWithdrawalManager,
    IWithdrawalManagerQueue
} from "./interfaces/Interfaces.sol";


import { Runner, ERC20Helper, console2 as console } from "./Runner.sol";

/// @dev This contract is the reference on how to perform most of the Maple Protocol actions.
contract ProtocolActions is Runner {

    uint256 constant HUNDRED_PERCENT = 100_0000;  // TODO: Fix Globals module to export this constant in its interface.

    address MPL       = address(0x33349B282065b0284d756F0577FB39c158F935e6);
    address WBTC      = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address WETH      = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address USDC      = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address USDT      = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    address USDC_BASE = address(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);

    address MPL_SOURCE       = address(0x4937A209D4cDbD3ecD48857277cfd4dA4D82914c);
    address WBTC_SOURCE      = address(0xBF72Da2Bd84c5170618Fbe5914B0ECA9638d5eb5);
    address WETH_SOURCE      = address(0xF04a5cC80B1E94C69B48f5ee68a08CD2F09A7c3E);
    address USDC_SOURCE      = address(0x4B16c5dE96EB2117bBE5fd171E4d203624B014aa);
    address USDT_SOURCE      = address(0xA7A93fd0a276fc1C0197a5B5623eD117786eeD06);
    address USDC_BASE_SOURCE = address(0x20FE51A9229EEf2cF8Ad9E89d91CAb9312cF3b7A);
    address USDS_SOURCE      = address(0xDBF5E9c5206d0dB70a90108bf936DA60221dC080);

    address AAVE_ACL      = address(0xc2aaCf6553D20d1e9d78E365AAba8032af9c85b0);
    address AAVE_CONFIG   = address(0x64b761D848206f447Fe2dd461b0c635Ec39EbB27);
    address AAVE_USDC     = address(0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c);
    address AAVE_USDS     = address(0x32a6268f9Ba3642Dda7892aDd74f1D34469A4259);
    address AAVE_USDT     = address(0x23878914EFE38d27C4D67Ab83ed1b93A74D4086a);
    address SAVINGS_USDS  = address(0xa3931d71877C0E7a3148CB7Eb4463524FEc27fbD);
    address USDS_LITE_PSM = address(0xA188EEC8F81263234dA3622A406892F3D630f98c);
    address USDS          = address(0xdC035D45d973E3EC169d2276DDab16f1e407384F);

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function erc20_approve(address asset_, address account_, address spender_, uint256 amount_) internal {
        vm.startPrank(account_);
        require(ERC20Helper.approve(asset_, spender_, amount_), "erc20_approve failed");
        vm.stopPrank();
    }

    function erc20_transfer(address asset_, address account_, address destination_, uint256 amount_) internal {
        vm.startPrank(account_);
        require(ERC20Helper.transfer(asset_, destination_, amount_), "erc20_transfer failed");
        vm.stopPrank();
    }

    function erc20_mint(address asset_, address account_, uint256 amount_) internal {
        if      (asset_ == MPL)       erc20_transfer(MPL,       MPL_SOURCE,       account_, amount_);
        else if (asset_ == WBTC)      erc20_transfer(WBTC,      WBTC_SOURCE,      account_, amount_);
        else if (asset_ == WETH)      erc20_transfer(WETH,      WETH_SOURCE,      account_, amount_);
        else if (asset_ == USDC)      erc20_transfer(USDC,      USDC_SOURCE,      account_, amount_);
        else if (asset_ == USDT)      erc20_transfer(USDT,      USDT_SOURCE,      account_, amount_);
        else if (asset_ == USDC_BASE) erc20_transfer(USDC_BASE, USDC_BASE_SOURCE, account_, amount_);
        else if (asset_ == USDS)      erc20_transfer(USDS,      USDS_SOURCE,      account_, amount_);
        else IERC20Like(asset_).mint(account_, amount_);  // Try to mint if its not one of the "real" tokens.
    }

    function isFixedTermLoan(address loan) internal view returns (bool isFixedTermLoan_) {
        isFixedTermLoan_ = !isOpenTermLoan(loan);
    }

    function isOpenTermLoan(address loan) internal view returns (bool isOpenTermLoan_) {
        try IOpenTermLoan(loan).dateCalled() {
            isOpenTermLoan_ = true;
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

    function createFixedTermLoan(
        address           factory_,
        address           borrower_,
        address           lender_,
        address           feeManager_,
        address[2] memory assets_,
        uint256[3] memory amounts_,
        uint256[3] memory terms_,
        uint256[4] memory rates_,
        uint256[2] memory fees_
    )
        internal returns (address loan_)
    {
        address globals_  = IMapleProxyFactory(factory_).mapleGlobals();
        address governor_ = IGlobals(globals_).governor();

        vm.prank(governor_);
        IGlobals(globals_).setValidBorrower(borrower_, true);

        vm.prank(borrower_);
        loan_ = IMapleProxyFactory(factory_).createInstance({
            arguments_: abi.encode(
                borrower_,
                lender_,
                feeManager_,
                assets_,
                terms_,
                amounts_,
                rates_,
                fees_
            ),
            salt_: "SALT"
        });
    }

    function createOpenTermLoan(
        address           factory_,
        address           borrower_,
        address           lender_,
        address           asset_,
        uint256           principal_,
        uint256[3] memory terms_,
        uint256[4] memory rates_
    )
        internal returns (address loan_)
    {
        address globals_  = IMapleProxyFactory(factory_).mapleGlobals();
        address governor_ = IGlobals(globals_).governor();

        vm.prank(governor_);
        IGlobals(globals_).setValidBorrower(borrower_, true);

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
        address        loan_,
        address        refinancer_,
        uint256        expiry_,
        bytes[] memory refinanceCalls_,
        uint256        principalIncrease_
    ) internal {
        if (isOpenTermLoan(loan_)) return acceptRefinanceOT(loan_, refinancer_, expiry_, refinanceCalls_);

        acceptRefinanceFT(loan_, refinancer_, expiry_, refinanceCalls_, principalIncrease_);
    }

    function acceptRefinanceFT(
        address        loan_,
        address        refinancer_,
        uint256        expiry_,
        bytes[] memory refinanceCalls_,
        uint256        principalIncrease_
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
        address ppm_         = IPoolManager(poolManager_).poolPermissionManager();

        if (IPoolPermissionManager(ppm_).permissionLevels(poolManager_) < 3) allowLender(poolManager_, account_);

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
        address ppm_         = IPoolManager(poolManager_).poolPermissionManager();

        if (IPoolPermissionManager(ppm_).permissionLevels(poolManager_) == 0) allowLender(poolManager_, account_);

        erc20_mint(asset_, account_, assets);

        vm.prank(account_);
        shares_ = IPool(pool_).depositWithPermit(assets, account_, deadline_, v_, r_, s_);
    }

    function mint(address pool_, address account_, uint256 shares_) internal returns (uint256 assets_) {
        address poolManager_ = IPool(pool_).manager();
        address ppm_         = IPoolManager(poolManager_).poolPermissionManager();

        if (IPoolPermissionManager(ppm_).permissionLevels(poolManager_) == 0) allowLender(poolManager_, account_);

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
        address ppm_         = IPoolManager(poolManager_).poolPermissionManager();

        if (IPoolPermissionManager(ppm_).permissionLevels(poolManager_) == 0) allowLender(poolManager_, account_);

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

    function activatePoolManager(address poolManager_) internal {
        address globals_  = IPoolManager(poolManager_).globals();
        address governor_ = IGlobals(globals_).governor();

        vm.prank(governor_);
        IGlobals(globals_).activatePoolManager(poolManager_);
    }

    function activatePool(address poolManager_, uint256 maxLiquidationPercent_) internal {
        address globals_  = IPoolManager(poolManager_).globals();
        address governor_ = IGlobals(globals_).governor();

        vm.startPrank(governor_);
        IGlobals(globals_).activatePoolManager(poolManager_);
        IGlobals(globals_).setMaxCoverLiquidationPercent(poolManager_, maxLiquidationPercent_);
        vm.stopPrank();
    }

    function addStrategy(address poolManager_, address strategyFactory_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.prank(poolDelegate_);
        IPoolManager(poolManager_).addStrategy(strategyFactory_, abi.encode(poolManager_));
    }

    function addStrategy(address poolManager_, address strategyFactory_, bytes memory data_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();

        vm.prank(poolDelegate_);
        IPoolManager(poolManager_).addStrategy(strategyFactory_, data_);
    }

    function allowLender(address poolManager_, address lender_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();
        address ppm_          = IPoolManager(poolManager_).poolPermissionManager();

        address[] memory lenders = new address[](1);
        lenders[0] = lender_;

        bool[] memory allows = new bool[](1);
        allows[0] = true;

        vm.startPrank(poolDelegate_);
        IPoolPermissionManager(ppm_).setLenderAllowlist(poolManager_, lenders, allows);
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

    // TODO: This can only deploy pools with loan managers but not with strategies.
    function deployAndActivatePool(
        address           deployer_,
        address           fundsAsset_,
        address           globals_,
        address           poolDelegate_,
        address           poolManagerFactory_,
        address           withdrawalManagerFactory_,
        string     memory name_,
        string     memory symbol_,
        address[]  memory strategyFactories_,
        uint256[7] memory configParams_
    )
        internal returns (address poolManager_)
    {
        if (configParams_[2] > 0) {
            erc20_mint(fundsAsset_, poolDelegate_, configParams_[2]);

            erc20_approve(fundsAsset_, poolDelegate_, deployer_, configParams_[2]);
        }

        // Set Valid PD
        {
            IGlobals globals = IGlobals(globals_);
            vm.prank(globals.governor());
            globals.setValidPoolDelegate(poolDelegate_, true);
        }

        address ppm_ = _deployPoolPermissionManager(globals_);

        address poolManagerDeployment = IMapleProxyFactory(poolManagerFactory_).getInstanceAddress(
            abi.encode(poolDelegate_, fundsAsset_, 0, name_, symbol_), // 0 is the initial supply
            keccak256(abi.encode(poolDelegate_))
        );

        bytes[] memory strategyDeploymentData_ = new bytes[](strategyFactories_.length);
        for (uint256 i = 0; i < strategyFactories_.length; i++) {
            strategyDeploymentData_[i] = abi.encode(poolManagerDeployment);
        }

        poolManager_ = deployPoolWithCyclical(
            poolDelegate_,
            deployer_,
            poolManagerFactory_,
            withdrawalManagerFactory_,
            strategyFactories_,
            strategyDeploymentData_,
            fundsAsset_,
            ppm_,
            name_,
            symbol_,
            configParams_
        );

        // Governor activates the pool
        activatePool(poolManager_, HUNDRED_PERCENT);
    }

    function deployPoolWithCyclical(
        address           poolDelegate_,
        address           deployer_,
        address           poolManagerFactory_,
        address           cyclicalWMFactory_,
        address[]  memory strategyFactories_,
        bytes[]    memory strategyDeploymentData_,
        address           fundsAsset_,
        address           poolPermissionManager_,
        string     memory name_,
        string     memory symbol_,
        uint256[7] memory configParams_
    )
        internal
        returns (address poolManager_)
    {
        vm.prank(poolDelegate_);
        poolManager_ = IPoolDeployer(deployer_).deployPool({
            poolManagerFactory_:       poolManagerFactory_,
            withdrawalManagerFactory_: cyclicalWMFactory_,
            strategyFactories_:        strategyFactories_,
            strategyDeploymentData_:   strategyDeploymentData_,
            asset_:                    fundsAsset_,
            poolPermissionManager_:    poolPermissionManager_,
            name_:                     name_,
            symbol_:                   symbol_,
            configParams_:             configParams_
        });
    }

    function deployPoolWithQueue(
        address           poolDelegate_,
        address           deployer_,
        address           poolManagerFactory_,
        address           queueWMFactory_,
        address[]  memory strategyFactories_,
        bytes[]    memory strategyDeploymentData_,
        address           fundsAsset_,
        address           poolPermissionManager_,
        string     memory name_,
        string     memory symbol_,
        uint256[4] memory configParams_
    )
        internal returns (address poolManager_)
    {
        vm.prank(poolDelegate_);
        poolManager_ = IPoolDeployer(deployer_).deployPool({
            poolManagerFactory_:       poolManagerFactory_,
            withdrawalManagerFactory_: queueWMFactory_,
            strategyFactories_:        strategyFactories_,
            strategyDeploymentData_:   strategyDeploymentData_,
            asset_:                    fundsAsset_,
            poolPermissionManager_:    poolPermissionManager_,
            name_:                     name_,
            symbol_:                   symbol_,
            configParams_:             configParams_
        });
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
        address borrower = ILoanLike(loan_).borrower();

        // Fund loans can be called on both old and new loans, therefore this can fail.
        vm.prank(borrower);
        try ILoanLike(loan_).acceptLoanTerms() { } catch { }

        ILoanManagerLike loanManager_ = ILoanManagerLike(ILoanLike(loan_).lender());

        address poolDelegate_ = IPoolManager(loanManager_.poolManager()).poolDelegate();

        vm.startPrank(poolDelegate_);
        loanManager_.fund(loan_);
        vm.stopPrank();
    }

    function impairLoan(address loan_) internal {
        address poolDelegate_ = IPoolManager(ILoanManagerLike(ILoanLike(loan_).lender()).poolManager()).poolDelegate();

        impairLoan(loan_, poolDelegate_);
    }

    function impairLoan(address loan_, address caller_) internal {
        ILoanManagerLike loanManager_ = ILoanManagerLike(ILoanLike(loan_).lender());

        vm.prank(caller_);
        loanManager_.impairLoan(loan_);
    }

    function openPool(address poolManager_) internal {
        address poolDelegate_ = IPoolManager(poolManager_).poolDelegate();
        address ppm_          = IPoolManager(poolManager_).poolPermissionManager();

        vm.startPrank(poolDelegate_);
        IPoolPermissionManager(ppm_).setPoolPermissionLevel(poolManager_, 3);
        vm.stopPrank();
    }

    // NOTE: Only works for queued withdrawal managers.
    function processRedemptions(address pool_, uint256 shares_) internal {
        address poolManager_       = IPool(pool_).manager();
        address withdrawalManager_ = IPoolManager(poolManager_).withdrawalManager();
        address governor_          = IPoolManager(poolManager_).governor();

        vm.prank(governor_);
        IWithdrawalManagerQueue(withdrawalManager_).processRedemptions(shares_);
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
        address poolDelegate_ = IPoolManager(ILoanManagerLike(ILoanLike(loan_).lender()).poolManager()).poolDelegate();

        removeLoanImpairment(loan_, poolDelegate_);
    }

    function removeLoanImpairment(address loan_, address caller_) internal {
        ILoanManagerLike loanManager_ = ILoanManagerLike(ILoanLike(loan_).lender());

        vm.prank(caller_);
        loanManager_.removeLoanImpairment(loan_);
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

    // NOTE: Only works for queued withdrawal managers.
    function setManualWithdrawal(address poolManager_, address lender_, bool isManual_) internal {
        IPoolManager pm_            = IPoolManager(poolManager_);
        IWithdrawalManagerQueue wm_ = IWithdrawalManagerQueue(pm_.withdrawalManager());

        address governor_ = pm_.governor();

        vm.prank(governor_);
        wm_.setManualWithdrawal(lender_, isManual_);
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
        address poolDelegate_ = IPoolManager(ILoanManagerLike(ILoanLike(loan_).lender()).poolManager()).poolDelegate();

        triggerDefault(loan_, liquidatorFactory_, poolDelegate_);
    }

    function triggerDefault(address loan_, address liquidatorFactory_, address caller_) internal {
        IPoolManager poolManager_ = IPoolManager(ILoanManagerLike(ILoanLike(loan_).lender()).poolManager());

        vm.prank(caller_);
        poolManager_.triggerDefault(loan_, liquidatorFactory_);
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

    function upgradeGlobals(address globals_, address newImplementation_) internal {
        address governor = IGlobals(globals_).governor();

        vm.prank(governor);
        INonTransparentProxy(globals_).setImplementation(newImplementation_);
    }

    /**************************************************************************************************************************************/
    /*** Permission Functions                                                                                                           ***/
    /**************************************************************************************************************************************/

    function setLenderAllowlist(address poolManager_, address lender_, bool boolean_) internal {
        address[] memory lenders_  = new address[](1);
        bool[]    memory booleans_ = new bool[](1);

        lenders_[0]  = lender_;
        booleans_[0] = boolean_;

        setLenderAllowlist(poolManager_, lenders_, booleans_);
    }

    function setLenderAllowlist(address poolManager_, address[] memory lenders_, bool[] memory booleans_) internal {
        IPoolManager           pm_  = IPoolManager(poolManager_);
        IPoolPermissionManager ppm_ = IPoolPermissionManager(pm_.poolPermissionManager());

        address governor_ = pm_.governor();

        vm.prank(governor_);
        ppm_.setLenderAllowlist(poolManager_, lenders_, booleans_);
    }

    function setLenderBitmap(address poolPermissionManager_, address permissionAdmin_, address lender_, uint256 bitmap_) internal {
        address[] memory lenders_ = new address[](1);
        uint256[] memory bitmaps_ = new uint256[](1);

        lenders_[0] = lender_;
        bitmaps_[0] = bitmap_;

        setLenderBitmaps(poolPermissionManager_, permissionAdmin_, lenders_, bitmaps_);
    }

    function setLenderBitmaps(
        address poolPermissionManager_,
        address permissionAdmin_,
        address[] memory lenders_,
        uint256[] memory bitmaps_
    )
        internal
    {
        IPoolPermissionManager ppm_ = IPoolPermissionManager(poolPermissionManager_);

        vm.prank(permissionAdmin_);
        ppm_.setLenderBitmaps(lenders_, bitmaps_);
    }

    function setPermissionAdmin(address poolPermissionManager_, address account_, bool isPermissionAdmin_) internal {
        IPoolPermissionManager ppm_     = IPoolPermissionManager(poolPermissionManager_);
        IGlobals               globals_ = IGlobals(ppm_.globals());

        address governor_ = globals_.governor();

        vm.prank(governor_);
        ppm_.setPermissionAdmin(account_, isPermissionAdmin_);
    }

    function setPermissionConfiguration(
        address poolManager_,
        uint256 permissionLevel_,
        bytes32[] memory functionIds_,
        uint256[] memory poolBitmaps_
    )
        internal
    {
        IPoolManager           pm_  = IPoolManager(poolManager_);
        IPoolPermissionManager ppm_ = IPoolPermissionManager(pm_.poolPermissionManager());

        address poolDelegate_ = pm_.poolDelegate();

        vm.prank(poolDelegate_);
        ppm_.configurePool(poolManager_, permissionLevel_, functionIds_, poolBitmaps_);
    }

    function setPoolBitmap(address poolManager_, uint256 bitmap_) internal {
        setPoolBitmap(poolManager_, bytes32(0), bitmap_);
    }

    function setPoolBitmap(address poolManager_, bytes32 functionId_, uint256 bitmap_) internal {
        bytes32[] memory functionIds_ = new bytes32[](1);
        uint256[] memory bitmaps_     = new uint256[](1);

        functionIds_[0] = functionId_;
        bitmaps_[0]     = bitmap_;

        setPoolBitmaps(poolManager_, functionIds_, bitmaps_);
    }

    function setPoolBitmaps(address poolManager_, bytes32[] memory functionIds_, uint256[] memory bitmaps_) internal {
        IPoolManager           pm_  = IPoolManager(poolManager_);
        IPoolPermissionManager ppm_ = IPoolPermissionManager(pm_.poolPermissionManager());

        address governor_ = pm_.governor();

        vm.prank(governor_);
        ppm_.setPoolBitmaps(poolManager_, functionIds_, bitmaps_);
    }

    function setPoolPermissionLevel(address poolManager_, uint256 permissionLevel_) internal {
        IPoolManager           pm_  = IPoolManager(poolManager_);
        IPoolPermissionManager ppm_ = IPoolPermissionManager(pm_.poolPermissionManager());

        address governor_ = pm_.governor();

        vm.prank(governor_);
        ppm_.setPoolPermissionLevel(poolManager_, permissionLevel_);
    }

    /**************************************************************************************************************************************/
    /*** Strategy Functions                                                                                                             ***/
    /**************************************************************************************************************************************/

    function deactivateStrategy(address strategy_) internal {
        IStrategyLike s_ = IStrategyLike(strategy_);
        IPoolManager pm_ = IPoolManager(s_.poolManager());

        address poolDelegate_ = pm_.poolDelegate();

        vm.prank(poolDelegate_);
        s_.deactivateStrategy();
    }

    function fundStrategy(address strategy_, uint256 assetsIn_) internal {
        IStrategyLike s_ = IStrategyLike(strategy_);
        IPoolManager pm_ = IPoolManager(s_.poolManager());

        address poolDelegate_ = pm_.poolDelegate();

        vm.startPrank(poolDelegate_);

        // TODO: Replace with type checks.
        try s_.fundStrategy(assetsIn_) {}
        catch { s_.fundStrategy(assetsIn_, 0); }

        vm.stopPrank();
    }

    function impairStrategy(address strategy_) internal {
        IStrategyLike s_ = IStrategyLike(strategy_);
        IPoolManager pm_ = IPoolManager(s_.poolManager());

        address poolDelegate_ = pm_.poolDelegate();

        vm.prank(poolDelegate_);
        s_.impairStrategy();
    }

    function reactivateStrategy(address strategy_) internal {
        reactivateStrategy(strategy_, false);
    }

    function reactivateStrategy(address strategy_, bool updateAccounting_) internal {
        IStrategyLike s_ = IStrategyLike(strategy_);
        IPoolManager pm_ = IPoolManager(s_.poolManager());

        address poolDelegate_ = pm_.poolDelegate();

        vm.prank(poolDelegate_);
        s_.reactivateStrategy(updateAccounting_);
    }

    function setStrategyFeeRate(address strategy_, uint256 feeRate_) internal {
        IStrategyLike s_ = IStrategyLike(strategy_);
        IPoolManager pm_ = IPoolManager(s_.poolManager());

        address poolDelegate_ = pm_.poolDelegate();

        vm.prank(poolDelegate_);
        s_.setStrategyFeeRate(feeRate_);
    }

    function withdrawFromStrategy(address strategy_, uint256 assetsOut_) internal {
        IStrategyLike s_ = IStrategyLike(strategy_);
        IPoolManager pm_ = IPoolManager(s_.poolManager());

        address poolDelegate_ = pm_.poolDelegate();

        vm.startPrank(poolDelegate_);

        // TODO: Replace with type checks.
        try s_.withdrawFromStrategy(assetsOut_) {}
        catch { s_.withdrawFromStrategy(assetsOut_, type(uint256).max); }

        vm.stopPrank();
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _deployPoolPermissionManager(address globals_) internal returns (address ppm_) {
        address poolPermissionManagerImplementation = deploy("PoolPermissionManager");
        address poolPermissionManagerInitializer    = deploy("PoolPermissionManagerInitializer");

        address governor = IGlobals(globals_).governor();

        ppm_ = deploy("NonTransparentProxy", abi.encode(governor, poolPermissionManagerInitializer));

        vm.prank(governor);
        IPoolPermissionManagerInitializer(address(ppm_)).initialize(poolPermissionManagerImplementation, address(globals_));

        vm.prank(governor);
        IGlobals(globals_).setValidInstanceOf("POOL_PERMISSION_MANAGER", address(ppm_), true);
    }

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
        internal view
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

    function configureFactory(
        address globals_,
        address factory_,
        address implementation_,
        address initializer_,
        bytes32 key_
    )
        internal
    {
        address governor = IGlobals(globals_).governor();

        vm.startPrank(governor);
        IMapleProxyFactory(factory_).registerImplementation(1, implementation_, initializer_);
        IMapleProxyFactory(factory_).setDefaultVersion(1);

        IGlobals(globals_).setValidInstanceOf(key_, factory_, true);
        vm.stopPrank();
    }

    function setMaxCoverLiquidationPercent(address globals, address poolManager, uint256 maxCoverLiquidationPercent) internal {
        address governor = IGlobals(globals).governor();

        vm.prank(governor);
        IGlobals(globals).setMaxCoverLiquidationPercent(poolManager, maxCoverLiquidationPercent);
    }

    function setMinCoverAmount(address globals, address poolManager, uint256 minCoverAmount) internal {
        address governor = IGlobals(globals).governor();

        vm.prank(governor);
        IGlobals(globals).setMinCoverAmount(poolManager, minCoverAmount);
    }

    function setPlatformManagementFeeRate(address globals, address poolManager, uint256 feeRate) internal {
        address governor = IGlobals(globals).governor();

        vm.prank(governor);
        IGlobals(globals).setPlatformManagementFeeRate(address(poolManager), feeRate);
    }

    function setPlatformOriginationFeeRate(address globals, address poolManager, uint256 feeRate) internal {
        address governor = IGlobals(globals).governor();

        vm.prank(governor);
        IGlobals(globals).setPlatformOriginationFeeRate(address(poolManager), feeRate);
    }

    function setPlatformServiceFeeRate(address globals, address poolManager, uint256 feeRate) internal {
        address governor = IGlobals(globals).governor();

        vm.prank(governor);
        IGlobals(globals).setPlatformServiceFeeRate(address(poolManager), feeRate);
    }

    function upgradeLoansAsBorrowers(address[] memory loans, uint256 version, bytes memory data) internal {
        for (uint256 i; i < loans.length; ++i) {
            upgradeLoanAsBorrower(loans[i], version, data);
        }
    }

    function upgradeLoansAsSecurityAdmin(address[] memory loans, uint256 version, bytes memory data) internal {
        for (uint256 i; i < loans.length; ++i) {
            upgradeLoanAsSecurityAdmin(loans[i], version, data);
        }
    }

    function upgradeLoanAsBorrower(address loan, uint256 version, bytes memory data) internal {
        address borrower = ILoanLike(loan).borrower();

        vm.prank(borrower);
        IProxiedLike(loan).upgrade(version, data);
    }

    function upgradeLoanAsSecurityAdmin(address loan, uint256 version, bytes memory data) internal {
        address securityAdmin = IGlobals(ILoanLike(loan).globals()).securityAdmin();

        vm.prank(securityAdmin);
        IProxiedLike(loan).upgrade(version, data);
    }

    function upgradeLoanManagerAsGovernor(address loanManager, uint256 version, bytes memory data) internal {
        vm.prank(IPoolManager(ILoanManagerLike(loanManager).poolManager()).governor());
        IProxiedLike(loanManager).upgrade(version, data);
    }

    function upgradePoolManagerAsGovernor(address poolManager, uint256 version, bytes memory data) internal {
        vm.prank(IPoolManager(poolManager).governor());
        IProxiedLike(poolManager).upgrade(version, data);
    }

    function upgradePoolManagerAsSecurityAdmin(address poolManager, uint256 version, bytes memory data) internal {
        vm.prank(IGlobals(ILoanLike(poolManager).globals()).securityAdmin());
        IProxiedLike(poolManager).upgrade(version, data);
    }

}
