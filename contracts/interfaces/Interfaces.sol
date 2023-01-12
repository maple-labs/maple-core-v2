// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IERC20 } from "../../modules/erc20/contracts/interfaces/IERC20.sol";

import { IMapleGlobals }          from "../../modules/globals-v2/contracts/interfaces/IMapleGlobals.sol";
import { INonTransparentProxied } from "../../modules/globals-v2/modules/non-transparent-proxy/contracts/interfaces/INonTransparentProxied.sol";
import { INonTransparentProxy }   from "../../modules/globals-v2/modules/non-transparent-proxy/contracts/interfaces/INonTransparentProxy.sol";

import { ILiquidator } from "../../modules/liquidations/contracts/interfaces/ILiquidator.sol";

import { IMapleLoan }           from "../../modules/loan-v400/contracts/interfaces/IMapleLoan.sol";
import { IMapleLoanFactory }    from "../../modules/loan-v400/contracts/interfaces/IMapleLoanFactory.sol";
import { IMapleLoanFeeManager } from "../../modules/loan-v400/contracts/interfaces/IMapleLoanFeeManager.sol";
import { IRefinancer }          from "../../modules/loan-v400/contracts/interfaces/IRefinancer.sol";

import { IAccountingChecker } from "../../modules/migration-helpers/contracts/interfaces/IAccountingChecker.sol";
import { IMigrationHelper }   from "../../modules/migration-helpers/contracts/interfaces/IMigrationHelper.sol";

import { ILoanManager }            from "../../modules/pool-v2/contracts/interfaces/ILoanManager.sol";
import { ILoanManagerInitializer } from "../../modules/pool-v2/contracts/interfaces/ILoanManagerInitializer.sol";
import { IMapleProxied }           from "../../modules/pool-v2/modules/maple-proxy-factory/contracts/interfaces/IMapleProxied.sol";
import { IMapleProxyFactory }      from "../../modules/pool-v2/modules/maple-proxy-factory/contracts/interfaces/IMapleProxyFactory.sol";
import { IPool }                   from "../../modules/pool-v2/contracts/interfaces/IPool.sol";
import { IPoolDeployer }           from "../../modules/pool-v2/contracts/interfaces/IPoolDeployer.sol";
import { IPoolManager }            from "../../modules/pool-v2/contracts/interfaces/IPoolManager.sol";
import { IPoolManagerInitializer } from "../../modules/pool-v2/contracts/interfaces/IPoolManagerInitializer.sol";

import { IWithdrawalManager }           from "../../modules/withdrawal-manager/contracts/interfaces/IWithdrawalManager.sol";
import { IWithdrawalManagerInitializer }from "../../modules/withdrawal-manager/contracts/interfaces/IWithdrawalManagerInitializer.sol";

interface IDebtLockerLike is IMapleProxied {

    function acceptNewTerms(address refinancer, uint256 deadline, bytes[] calldata calls, uint256 amount) external;

    function lender() external view returns (address lender);

    function loanMigrator() external view returns (address loanMigrator);

    function pool() external view returns (address pool);

    function poolDelegate() external view returns (address poolDelegate);

}

interface IERC20Like {

    function allowance(address owner, address spender) external view returns (uint256 allowance);

    function approve(address spender, uint256 amount) external returns (bool success);

    function balanceOf(address account) external view returns (uint256 balance);

    function burn(address owner, uint256 amount) external;

    function decimals() external view returns (uint8 decimals);

    function mint(address recipient, uint256 amount) external;

    function name() external view returns (string memory name);

    function symbol() external view returns (string memory symbol);

    function totalSupply() external view returns (uint256 totalSupply);

    function transfer(address recipient, uint256 amount) external returns (bool success);

    function transferFrom(address owner, address recipient, uint256 amount) external returns (bool success);

}

interface IHasGLobalsLike {

    function globals() external view returns (address globals);

}

interface IMapleGlobalsV1Like {

    function getLatestPrice(address asset) external view returns (uint256 price);

    function globalAdmin() external view returns (address globalAdmin);

    function governor() external view returns (address governor);

    function investorFee() external view returns (uint256 investorFee);

    function protocolPaused() external view returns (bool protocolPaused);

    function setInvestorFee(uint256 investorFee) external;

    function setMaxCoverLiquidationPercent(address poolManager, uint256 maxCoverLiquidationPercent) external;

    function setMinCoverAmount(address poolManager, uint256 minCoverAmount) external;

    function setPriceOracle(address asset, address oracle) external;

    function setProtocolPause(bool pause) external;

    function setStakerCooldownPeriod(uint256 cooldown) external;

    function setTreasuryFee(uint256 treasuryFee) external;

    function stakerCooldownPeriod() external view returns (uint256 stakerCooldownPeriod);

    function treasuryFee() external view returns (uint256 treasuryFee);

}

interface IMapleLoanV3Like is IMapleProxied {

    function borrower() external view returns (address borrower);

    function claimableFunds() external view returns (uint256 claimableFunds);

    function closeLoan(uint256 amount) external returns (uint256 principal, uint256 interest);

    function collateral() external view returns (uint256 collateral);

    function collateralAsset() external view returns (address collateralAsset);

    function collateralRequired() external view returns (uint256 collateralRequired);

    function delegateFee() external view returns (uint256 delegateFee);

    function drawableFunds() external view returns (uint256 drawableFunds);

    function earlyFeeRate() external view returns (uint256 earlyFeeRate);

    function endingPrincipal() external view returns (uint256 endingPrincipal);

    function feeManager() external view returns (address feeManager);

    function fundsAsset() external view returns (address fundsAsset);

    function getClosingPaymentBreakdown() external view returns (uint256 principal, uint256 interest, uint256 fees);

    function getNextPaymentBreakdown() external view returns (uint256 principal, uint256 interest, uint256 delegateFee, uint256 treasuryFee);

    function gracePeriod() external view returns (uint256 gracePeriod);

    function interestRate() external view returns (uint256 interestRate);

    function isImpaired() external view returns (bool isImpaired);  // Not used yet, but wil be used in complex lifecycle

    function lateFeeRate() external view returns (uint256 lateFeeRate);

    function lateInterestPremium() external view returns (uint256 lateInterestPremium);

    function lender() external view returns (address lender);

    function makePayment(uint256 amount) external returns (uint256 principal, uint256 interest);

    function nextPaymentDueDate() external view returns (uint256 nextPaymentDueDate);

    function paymentInterval() external view returns (uint256 paymentInterval);

    function paymentsRemaining() external view returns (uint256 paymentsRemaining);

    function pendingBorrower() external view returns (address pendingBorrower);

    function pendingLender() external view returns (address pendingLender);

    function principal() external view returns (uint256 principal);

    function principalRequested() external view returns (uint256 principalRequested);

    function proposeNewTerms(address refinancer, uint256 deadline, bytes[] calldata calls) external;

    function refinanceCommitment() external view returns (bytes32 refinanceCommitment);

    function refinanceInterest() external view returns (uint256 refinanceInterest);  // Not used yet, but wil be used in complex lifecycle

    function returnFunds(uint256 amount) external;

    function treasuryFee() external view returns (uint256 treasuryFee);

}

interface IMplRewardsLike {

    function exit() external;

    function stake(uint256 amount) external;

}

interface IPoolV1Like is IERC20Like {

    function claim(address loan, address dlFactory) external;

    function deactivate() external;

    function deposit(uint256 amount) external;

    function fundLoan(address loan, address dlFactory, uint256 amount) external;

    function intendToWithdraw() external;

    function interestSum() external view returns (uint256 interestSum);

    function liquidityAsset() external view returns (address liquidityAsset);

    function liquidityCap() external view returns (uint256 liquidityCap);

    function liquidityLocker() external pure returns (address liquidityLocker);

    function poolAdmins(address poolAdmin) external view returns (bool isPoolAdmin);

    function poolDelegate() external view returns (address poolDelegate);

    function poolLosses() external view returns (uint256 poolLosses);

    function poolState() external returns(uint8 state);

    function principalOut() external view returns (uint256 principalOut);

    function recognizableLossesOf(address owner) external view returns (uint256 recognizableLosses);

    function setLiquidityCap(uint256 newLiquidityCap) external;

    function setPoolAdmin(address poolAdmin, bool allowed) external;

    function stakeLocker() external view returns (address stakeLocker);

    function withdrawableFundsOf(address owner) external view returns (uint256 withdrawableFunds);

}

interface IStakeLockerLike is IERC20Like {

    function custodyAllowance(address from, address custodian) external view returns (uint256 allowance);

    function intendToUnstake() external;

    function lockupPeriod() external view returns (uint256 lockupPeriod);

    function pool() external view returns (address pool);

    function recognizableLossesOf(address owner) external view returns (uint256 recognizableLossesOf);

    function setLockupPeriod(uint256 newLockupPeriod) external;

    function stakeAsset() external view returns (address stakeAsset);

    function unstake(uint256 amount) external;

    function unstakeCooldown(address owner) external view returns (uint256 unstakeCooldown);

}
