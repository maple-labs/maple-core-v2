// // SPDX-License-Identifier: BUSL-1.1
// pragma solidity 0.8.7;

// import { TestUtils }            from "../../../modules/contract-test-utils/contracts/test.sol";
// import { IMapleGlobals }        from "../../../modules/globals-v2/contracts/interfaces/IMapleGlobals.sol";
// import { MapleLoanInitializer } from "../../../modules/loan-v401/contracts/MapleLoanInitializer.sol";
// import { IMapleLoan }           from "../../../modules/loan-v401/contracts/interfaces/IMapleLoan.sol";
// import { IMapleLoanFactory }    from "../../../modules/loan-v401/contracts/interfaces/IMapleLoanFactory.sol";
// import { ILoanManager }         from "../../../modules/pool-v2/contracts/interfaces/ILoanManager.sol";
// import { IPool }                from "../../../modules/pool-v2/contracts/interfaces/IPool.sol";
// import { IPoolManager }         from "../../../modules/pool-v2/contracts/interfaces/IPoolManager.sol";

// contract PoolDelegateBase is TestUtils {

//     uint256 public numCalls;

//     mapping(bytes32 => uint256) public numberOfCalls;

//     address collateralAsset;
//     address feeManager;
//     address fundsAsset;
//     address globals;
//     address governor;
//     address loanFactory;

//     BorrowerManager borrowerManager;

//     ILoanManager loanManager;
//     IPool        pool;
//     IPoolManager poolManager;

//     constructor (
//         address borrowerManager_,
//         address collateralAsset_,
//         address feeManager_,
//         address fundsAsset_,
//         address globals_,
//         address governor_,
//         address loanFactory_,
//         address poolManager_
//     ) {
//         collateralAsset = collateralAsset_;
//         feeManager      = feeManager_;
//         fundsAsset      = fundsAsset_;
//         globals         = globals_;
//         governor        = governor_;
//         loanFactory     = loanFactory_;

//         borrowerManager = BorrowerManager(borrowerManager_);
//         poolManager     = IPoolManager(poolManager_);
//         loanManager     = ILoanManager(poolManager.loanManagerList(0));
//         pool            = IPool(poolManager.pool());
//     }

//     // function createLoanAndFund(
//     //     uint256 borrowerIndex_,
//     //     uint256[3] memory termDetails_,
//     //     uint256[3] memory amounts_,
//     //     uint256[4] memory rates_,
//     //     uint256[2] memory fees_
//     // ) external {
//     //     numCalls++;
//     //     numberOfCalls["createLoan"]++;

//     //     uint256 numBorrowers_ = borrowerManager.numBorrowers();

//     //     if (numBorrowers_ == 0) return;

//     //     termDetails_[0] = constrictToRange(termDetails_[0], 0,      30 days);   // Grace period
//     //     termDetails_[1] = constrictToRange(termDetails_[1], 1 days, 730 days);  // Payment interval
//     //     termDetails_[2] = constrictToRange(termDetails_[2], 0,      30);        // Number of payments

//     //     amounts_[0] = constrictToRange(amounts_[0], 0,   1e29);         // Collateral required
//     //     amounts_[1] = constrictToRange(amounts_[1], 1e6, 1e29);         // Principal requested
//     //     amounts_[2] = constrictToRange(amounts_[2], 0,   amounts_[1]);  // Ending principal

//     //     rates_[0] = constrictToRange(rates_[0], 0, 0.5e18);  // Interest rate
//     //     rates_[1] = constrictToRange(rates_[1], 0, 1.0e18);  // Closing fee rate
//     //     rates_[2] = constrictToRange(rates_[2], 0, 0.6e18);  // Late fee rate
//     //     rates_[3] = constrictToRange(rates_[3], 0, 0.2e18);  // Late interest premium

//     //     fees_[0] = constrictToRange(fees_[0], 0, 1e29);  // Grace period
//     //     fees_[1] = constrictToRange(fees_[1], 0, 1e29);  // Payment interval

//     //     address borrower_ = borrowerManager.borrowers(constrictToRange(borrowerIndex_, 0, numBorrowers_ - 1));

//     //     address loan_ = IMapleLoanFactory(loanFactory).createInstance({
//     //         arguments_: new MapleLoanInitializer().encodeArguments({
//     //             borrower_:    borrowerManager.borrowers(constrictToRange(borrowerIndex_, 0, numBorrowers_ - 1)),
//     //             feeManager_:  feeManager,
//     //             assets_:      [collateralAsset, fundsAsset],
//     //             termDetails_: termDetails_,
//     //             amounts_:     amounts_,
//     //             rates_:       rates_,
//     //             fees_:        fees_
//     //         }),
//     //         salt_: "SALT"
//     //     });

//     //     Borrower(borrower_).addLoan(loan_);

//     //     vm.prank(poolManager.poolDelegate());
//     //     poolManager.fund(amounts_[1], loan_, address(loanManager));
//     // }

//     // function acceptPendingPoolDelegate() public virtual {
//     //     poolManager.acceptPendingPoolDelegate();
//     // }

//     // function setPendingPoolDelegate(address pendingPoolDelegate_) public virtual {
//     //     poolManager.setPendingPoolDelegate(pendingPoolDelegate_);
//     // }

//     // function configure(address loanManager_, address withdrawalManager_, uint256 liquidityCap_, uint256 managementFee_) public virtual {
//     //     poolManager.configure(loanManager_, withdrawalManager_, liquidityCap_, managementFee_);
//     // }

//     // function addLoanManager(address loanManager_) public virtual {
//     //     poolManager.addLoanManager(loanManager_);
//     // }

//     // function removeLoanManager(address loanManager_) public virtual {
//     //     poolManager.removeLoanManager(loanManager_);
//     // }

//     // function setActive(bool active_) public virtual {
//     //     poolManager.setActive(active_);
//     // }

//     // function setAllowedLender(address lender_, bool isValid_) public virtual {
//     //     poolManager.setAllowedLender(lender_, isValid_);
//     // }

//     // function setAllowedSlippage(address loanManager_, address collateralAsset_, uint256 allowedSlippage_) public virtual {
//     //     poolManager.setAllowedSlippage(loanManager_, collateralAsset_, allowedSlippage_);
//     // }

//     // function setLiquidityCap(uint256 liquidityCap_) public virtual {
//     //     poolManager.setLiquidityCap(liquidityCap_);
//     // }

//     // function setDelegateManagementFeeRate(uint256 delegateManagementFeeRate_) public virtual {
//     //     poolManager.setDelegateManagementFeeRate(delegateManagementFeeRate_);
//     // }

//     // function setMinRatio(address loanManager_, address collateralAsset_, uint256 minRatio_) public virtual {
//     //     poolManager.setMinRatio(loanManager_, collateralAsset_, minRatio_);
//     // }

//     // function setOpenToPublic() public virtual {
//     //     poolManager.setOpenToPublic();
//     // }

//     // function setWithdrawalManager(address withdrawalManager_) public virtual {
//     //     poolManager.setWithdrawalManager(withdrawalManager_);
//     // }

//     // function acceptNewTerms(
//     //     address loan_,
//     //     address refinancer_,
//     //     uint256 deadline_,
//     //     bytes[] calldata calls_,
//     //     uint256 principalIncrease_
//     // ) public virtual {
//     //     poolManager.acceptNewTerms(loan_, refinancer_, deadline_, calls_, principalIncrease_);
//     // }

//     // function fund(uint256 principal_, address loan_, address loanManager_) public virtual {
//     //     poolManager.fund(principal_, loan_, loanManager_);
//     // }

//     // function finishCollateralLiquidation(address loan_) public virtual {
//     //     poolManager.finishCollateralLiquidation(loan_);
//     // }

//     // function removeLoanImpairment(address loan_) public virtual {
//     //     poolManager.removeLoanImpairment(loan_);
//     // }

//     // function triggerDefault(address loan_, address liquidatorFactory_) public virtual {
//     //     poolManager.triggerDefault(loan_, liquidatorFactory_);
//     // }

//     // function impairLoan(address loan_) public virtual {
//     //     poolManager.impairLoan(loan_);
//     // }

//     // function depositCover(uint256 amount_) public virtual {
//     //     poolManager.depositCover(amount_);
//     // }

//     // function withdrawCover(uint256 amount_, address recipient_) public virtual {
//     //     poolManager.withdrawCover(amount_, recipient_);
//     // }

// }
