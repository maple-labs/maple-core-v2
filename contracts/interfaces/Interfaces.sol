// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC20 } from "../../modules/erc20/contracts/interfaces/IERC20.sol";

import { IMapleProxied } from "../../modules/pool/modules/maple-proxy-factory/contracts/interfaces/IMapleProxied.sol";

import { IGovernorTimelock as IGTL } from "../../modules/globals/contracts/interfaces/IGovernorTimelock.sol";
import { IMapleGlobals as IMG } from "../../modules/globals/contracts/interfaces/IMapleGlobals.sol";

import {
    INonTransparentProxied
} from "../../modules/globals/modules/non-transparent-proxy/contracts/interfaces/INonTransparentProxied.sol";
import { INonTransparentProxy } from "../../modules/globals/modules/non-transparent-proxy/contracts/interfaces/INonTransparentProxy.sol";

import { IMapleLoan as IMOTL } from "../../modules/open-term-loan/contracts/interfaces/IMapleLoan.sol";

import { IMapleLoanManager as IMOTLM } from "../../modules/open-term-loan-manager/contracts/interfaces/IMapleLoanManager.sol";
import { IMapleLoanManagerStructs as IMOTLMS } from "../../modules/open-term-loan-manager/tests/utils/Interfaces.sol";

import { IMaplePool as IMP } from "../../modules/pool/contracts/interfaces/IMaplePool.sol";

import {
    IMaplePoolDeployer as IMPD,
    PoolConfigParams,
    PoolManagerInitParams,
    StrategyDeployParams,
    StrategyManagerParams
} from "../../modules/pool/contracts/interfaces/IMaplePoolDeployer.sol";

import { IMaplePoolManager as IMPM } from "../../modules/pool/contracts/interfaces/IMaplePoolManager.sol";
import { IMapleProxied } from "../../modules/pool/modules/maple-proxy-factory/contracts/interfaces/IMapleProxied.sol";
import { IMapleProxyFactory } from "../../modules/pool/modules/maple-proxy-factory/contracts/interfaces/IMapleProxyFactory.sol";

import {
    IMaplePoolPermissionManager as IMPPM
} from "../../modules/pool-permission-manager/contracts/interfaces/IMaplePoolPermissionManager.sol";

import {
    IMaplePoolPermissionManagerInitializer as IMPPMI
} from "../../modules/pool-permission-manager/contracts/interfaces/IMaplePoolPermissionManagerInitializer.sol";

import { ISyrupRouter as ISR } from "../../modules/syrup-utils/contracts/interfaces/ISyrupRouter.sol";

import {
    IMapleWithdrawalManager as IMWMC
} from "../../modules/withdrawal-manager-cyclical/contracts/interfaces/IMapleWithdrawalManager.sol";

import { IMapleWithdrawalManager as IMWMQ } from "../../modules/withdrawal-manager-queue/contracts/interfaces/IMapleWithdrawalManager.sol";

import { IMapleBorrowerActions } from "../../modules/syrup-utils/contracts/interfaces/IMapleBorrowerActions.sol";

import {
    Action,
    ActionType,
    IMapleLiquidityRouter as IMLR
} from "../../modules/strategy-manager/contracts/interfaces/IMapleLiquidityRouter.sol";

import { IMapleStrategyDeployer as IMSD } from "../../modules/strategy-manager/contracts/interfaces/IMapleStrategyDeployer.sol";
import { IMapleStrategyManager as IMSM } from "../../modules/strategy-manager/contracts/interfaces/IMapleStrategyManager.sol";

import { IAavePoolLike as IAPL } from "../../modules/defi-strategies/contracts/interfaces/Interfaces.sol";
import { IMapleAaveV3Strategy as IMAV3S } from "../../modules/defi-strategies/contracts/interfaces/IMapleAaveV3Strategy.sol";
import { IMapleSkyStrategy as IMSS } from "../../modules/defi-strategies/contracts/interfaces/IMapleSkyStrategy.sol";

import { AaveV3StrategyInitializerParams } from "../../modules/defi-strategies/contracts/interfaces/IMapleAaveV3StrategyInitializer.sol";
import { SkyStrategyInitializerParams } from "../../modules/defi-strategies/contracts/interfaces/IMapleSkyStrategyInitializer.sol";

import { IMapleAllocationStrategy as IMAS } from "../../modules/allocation-strategy/contracts/interfaces/IMapleAllocationStrategy.sol";

import {
    AllocationStrategyInitializerParams
} from "../../modules/allocation-strategy/contracts/interfaces/IMapleAllocationStrategyInitializer.sol";

/******************************************************************************************************************************************/
/*** Re-Exports                                                                                                                         ***/
/******************************************************************************************************************************************/

interface IAllocationStrategy is IMAS { }

interface IAaveV3Strategy is IMAV3S { }

interface IBorrowerActions is IMapleBorrowerActions { }

interface IGlobals is IMG { }

interface IGovernorTimelock is IGTL { }

interface IMapleLiquidityRouter is IMLR { }

interface IOpenTermLoan is IMOTL { }

interface IOpenTermLoanManager is IMOTLM { }

interface IOpenTermLoanManagerStructs is IMOTLMS { }

interface IPool is IMP { }

interface IPoolDeployer is IMPD { }

interface IPoolManager is IMPM { }

interface IPoolPermissionManager is IMPPM { }

interface IPoolPermissionManagerInitializer is IMPPMI { }

interface IStrategyDeployer is IMSD { }

interface IStrategyManager is IMSM { }

interface ISyrupRouter is ISR { }

interface ISkyStrategy is IMSS { }

interface IWithdrawalManagerCyclical is IMWMC { }

interface IWithdrawalManagerQueue is IMWMQ { }

/******************************************************************************************************************************************/
/*** Like Interfaces                                                                                                                    ***/
/******************************************************************************************************************************************/

interface IAavePoolAddressesProviderLike {

    function getACLAdmin() external view returns (address aclAdmin_);

    function getPoolConfigurator() external view returns (address poolConfigurator_);

}

interface IAavePoolConfiguratorLike {

    function setReserveFreeze(address asset_, bool freeze_) external;

    function setReservePause(address asset_, bool pause_) external;

    function setSupplyCap(address asset_, uint256 supplyCap_) external;

}

interface IAavePoolLike is IAPL {

    function borrow(address asset_, uint256 amount_, uint256 interestRateMode_, uint16 referralCode_, address onBehalfOf_) external;

    function repay(address asset_, uint256 amount_, uint256 interestRateMode_, address onBehalfOf_) external returns (uint256 repaidAssets_);

}

interface IAaveV3StrategyLike {

    function aavePool() external view returns (address aavePool);

    function aaveToken() external view returns (address aaveToken);

    function assetsUnderManagement() external view returns (uint256 assetsUnderManagement);

    function availableToWithdraw() external view returns (uint256 availableToWithdraw);

    function fundsAsset() external view returns (address fundsAsset);

    function lastRecordedTotalAssets() external view returns (uint256 lastRecordedTotalAssets);

    function strategyDelegateFeeRate() external view returns (uint32 strategyDelegateFeeRate);

    function strategyProtocolFeeRate() external view returns (uint32 strategyProtocolFeeRate);

    function unrealizedLosses() external view returns (uint256 unrealizedLosses);

    function useVirtualUnderlyingBalance() external view returns (bool useVirtualUnderlyingBalance);

}

interface IAllocationStrategyLike {

    function assetsUnderManagement() external view returns (uint256 assetsUnderManagement);

    function availableToWithdraw() external view returns (uint256 availableToWithdraw);

    function deployedAssetsOf(address account) external view returns (uint256 deployedAssets);

    function fundsAsset() external view returns (address fundsAsset);

    function recordedAssets() external view returns (uint256 recordedAssets);

    function scheduledYieldAssets() external view returns (uint256 scheduledYieldAssets);

    function strategyDelegateFeeRate() external view returns (uint32 strategyDelegateFeeRate);

    function strategyProtocolFeeRate() external view returns (uint32 strategyProtocolFeeRate);

    function totalDeployedAssets() external view returns (uint256 totalDeployedAssets);

    function unrealizedLosses() external view returns (uint256 unrealizedLosses);

    function unrealizedYield() external view returns (uint256 unrealizedYield);

    function yieldDeadline() external view returns (uint32 yieldDeadline);

    function yieldLastRealized() external view returns (uint32 yieldLastRealized);

    function yieldStart() external view returns (uint32 yieldStart);

}

interface IDaiJoinLike {

    function cage() external;

    function live() external view returns (uint256 live_);

}

interface IDefiStrategyLike {

    function isLossRecognized() external view returns (bool isLossRecognized_);

    function recognizeLoss() external;

}

interface IOpenTermLoanLike {

    function calledPrincipal() external view returns (uint256 calledPrincipal_);

    function dateCalled() external view returns (uint40 dateCalled_);

    function dateFunded() external view returns (uint40 dateFunded_);

    function dateImpaired() external view returns (uint40 dateImpaired_);

    function datePaid() external view returns (uint40 datePaid_);

    function defaultDate() external view returns (uint40 defaultDate_);

    function delegateServiceFeeRate() external view returns (uint64 delegateServiceFeeRate_);

    function getPaymentBreakdown(uint256 timestamp_)
        external
        view
        returns (uint256 principal_, uint256 interest_, uint256 lateInterest_, uint256 delegateServiceFee_, uint256 platformServiceFee_);

    function interestRate() external view returns (uint64 interestRate_);

    function isImpaired() external view returns (bool isImpaired_);

    function lateFeeRate() external view returns (uint64 lateFeeRate_);

    function lateInterestPremiumRate() external view returns (uint64 lateInterestPremiumRate_);

    function paymentDueDate() external view returns (uint40 paymentDueDate_);

    function paymentInterval() external view returns (uint32 paymentInterval_);

    function platformServiceFeeRate() external view returns (uint64 platformServiceFeeRate_);

    function principal() external view returns (uint256 principal_);

}

interface IOpenTermLoanManagerLike {

    function assetsUnderManagement() external view returns (uint256 assetsUnderManagement_);

    function domainStart() external view returns (uint40 domainStart_);

    function fundsAsset() external view returns (address fundsAsset_);

    function impairmentFor(address loan_) external view returns (uint40 impairedDate, bool impairedByGovernor);

    function issuanceRate() external view returns (uint256 issuanceRate_);

    function paymentFor(address loan_)
        external
        view
        returns (uint24 platformManagementFeeRate, uint24 delegateManagementFeeRate, uint40 startDate, uint168 issuanceRate);

    function principalOut() external view returns (uint128 principalOut_);

    function unrealizedLosses() external view returns (uint128 unrealizedLosses_);

}

interface IPoolLike {

    function asset() external view returns (address asset_);

    function balanceOf(address account_) external view returns (uint256 balance_);

    function balanceOfAssets(address account_) external view returns (uint256 assets_);

    function convertToAssets(uint256 shares_) external view returns (uint256 assets_);

    function convertToExitShares(uint256 assets_) external view returns (uint256 shares_);

    function convertToShares(uint256 assets_) external view returns (uint256 shares_);

    function manager() external view returns (address manager_);

    function totalAssets() external view returns (uint256 totalAssets_);

    function totalSupply() external view returns (uint256 totalSupply_);

    function unrealizedLosses() external view returns (uint256 unrealizedLosses_);

}

interface IPoolManagerLike {

    function asset() external view returns (address asset_);

    function convertToExitShares(uint256 amount) external view returns (uint256 shares);

    function isStrategy(address strategy_) external view returns (bool isStrategy_);

    function isStrategyManager(address strategyManager_) external view returns (bool isStrategyManager_);

    function pool() external view returns (address pool_);

    function poolPermissionManager() external view returns (address poolPermissionManager_);

    function strategyList(uint256 index_) external view returns (address strategy_);

    function strategyListLength() external view returns (uint256 strategyListLength);

    function totalAssets() external view returns (uint256 totalAssets);

    function unrealizedLosses() external view returns (uint256 unrealizedLosses);

    function withdrawalManager() external view returns (address withdrawalManager_);

}

interface IPoolPermissionManagerLike {

    function lenderBitmaps(address lender) external view returns (uint256 bitmap);

    function permissionLevels(address poolManager) external view returns (uint256 permissionLevel);

    function poolBitmaps(address poolManager, bytes32 functionId) external view returns (uint256 bitmap);

}

interface ISkyStrategyLike {

    function assetsUnderManagement() external view returns (uint256 assetsUnderManagement);

    function availableToWithdraw() external view returns (uint256 availableToWithdraw);

    function fallbackTout() external view returns (uint256 fallbackTout);

    function fundsAsset() external view returns (address fundsAsset);

    function lastRecordedTotalAssets() external view returns (uint256 lastRecordedTotalAssets);

    function psm() external view returns (address psm);

    function savingsUsds() external view returns (address savingsUsds);

    function strategyDelegateFeeRate() external view returns (uint32 strategyDelegateFeeRate);

    function strategyProtocolFeeRate() external view returns (uint32 strategyProtocolFeeRate);

    function unrealizedLosses() external view returns (uint256 unrealizedLosses);

    function usds() external view returns (address usds);

}

interface IStrategyManagerLike {

    function assetsOf(address poolManager) external view returns (uint256 assets);

    function assetsUnderManagement() external view returns (uint256 assetsUnderManagement);

    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    function convertToExitAssets(uint256 shares) external view returns (uint256 assets);

    function pendingSharesOf(address poolManager) external view returns (uint256 pendingSharesOf);

    function sharesOf(address poolManager) external view returns (uint256 sharesOf);

    function totalPendingShares() external view returns (uint256 totalPendingShares);

    function totalShares() external view returns (uint256 totalShares);

    function underlyingStrategy() external view returns (address underlyingStrategy);

    function unrealizedLosses() external view returns (uint256 unrealizedLosses);

    function unrealizedLossesOf(address poolManager) external view returns (uint256 unrealizedLosses);

}

interface IWithdrawalManagerQueueLike {

    function manualSharesAvailable(address owner) external view returns (uint256 sharesAvailable);

    function pool() external view returns (address pool);

    function queue() external view returns (uint128 nextRequestId, uint128 lastRequestId);

    function requestIds(address owner) external view returns (uint256 requestId);

    function requests(uint256 requestId) external view returns (address owner, uint256 shares);

    function requestsByOwner(address owner) external view returns (uint256[] memory requestIds, uint256[] memory shares);

    function totalShares() external view returns (uint256 totalShares);

    function userEscrowedShares(address owner) external view returns (uint256 escrowedShares);

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

interface IERC4626Like is IERC20Like {

    function asset() external view returns (address asset_);

    function convertToAssets(uint256 shares_) external view returns (uint256 assets_);

    function convertToShares(uint256 assets_) external view returns (uint256 shares_);

    function deposit(uint256 assets_, address receiver_) external returns (uint256 shares_);

    function maxWithdraw(address account_) external view returns (uint256 assets_);

    function previewRedeem(uint256 shares_) external view returns (uint256 assets_);

    function redeem(uint256 shares_, address receiver_, address owner_) external returns (uint256 assets_);

    function withdraw(uint256 assets_, address receiver_, address owner_) external returns (uint256 shares_);

    function totalAssets() external view returns (uint256 totalAssets_);

}

interface IExemptionsManagerLike {

    function admitGlobalExemption(address[] calldata exemptions, string memory description) external;

    function approvePolicyExemptions(uint32 policyId, address[] memory exemptions) external;

    function isPolicyExemption(uint32 policyId, address exemption) external view returns (bool isExempt);

}

interface IKycERC20Like {

    function admissionPolicyId() external view returns (uint32 admissionPolicyId);

    function depositFor(address trader, uint256 amount) external returns (bool success);

    function exemptionsManager() external view returns (address exemptionsManager);

    function policyManager() external view returns (address policyManager);

}

interface IPoolDeployerV2Like {

    function deployPool(
        address poolManagerFactory_,
        address withdrawalManagerFactory_,
        address[] memory loanManagerFactories_,
        address asset_,
        string memory name_,
        string memory symbol_,
        uint256[6] memory configParams_
    )
        external
        returns (address poolManager_);

}

interface IProxiedLike {

    function factory() external view returns (address factory_);

    function implementation() external view returns (address implementation_);

    function setImplementation(address newImplementation_) external;

    function migrate(address migrator_, bytes calldata arguments_) external;

    function upgrade(uint256 toVersion_, bytes calldata arguments_) external;

}

// NOTE: Needs to be defined after `IProxiedLike`.
interface ILoanLike is IProxiedLike {

    function acceptBorrower() external;

    function acceptLender() external;

    function acceptLoanTerms() external;

    function acceptNewTerms(address refinancer_, uint256 deadline_, bytes[] calldata calls_) external returns (bytes32 refinanceCommitment_);

    function borrower() external view returns (address borrower_);

    function fundsAsset() external view returns (address fundsAsset_);

    function globals() external view returns (address globals_);

    function gracePeriod() external view returns (uint256 gracePeriod_);

    function isImpaired() external view returns (bool isImpaired_);

    function lender() external view returns (address lender_);

    function paymentInterval() external view returns (uint256 paymentInterval_);

    function principal() external view returns (uint256 principal_);

    function proposeNewTerms(
        address refinancer_,
        uint256 deadline_,
        bytes[] calldata calls_
    )
        external
        returns (bytes32 refinanceCommitment_);

    function rejectNewTerms(address refinancer_, uint256 deadline_, bytes[] calldata calls_) external returns (bytes32 refinanceCommitment_);

    function setPendingBorrower(address pendingBorrower_) external;

    function skim(address token_, address destination_) external returns (uint256 skimmed_);

}

// NOTE: Needs to be defined after `IProxiedLike`.
interface ILoanManagerLike is IProxiedLike {

    function accountedInterest() external view returns (uint112 accountedInterest_);

    function accruedInterest() external view returns (uint256 accruedInterest_);

    function assetsUnderManagement() external view returns (uint256 assetsUnderManagement_);

    function domainStart() external view returns (uint48 domainStart_);

    function fund(address loan_) external;

    function fundsAsset() external view returns (address fundsAsset_);

    function impairLoan(address loan_) external;

    function issuanceRate() external view returns (uint256 issuanceRate_);

    function poolManager() external view returns (address poolManager_);

    function principalOut() external view returns (uint128 principalOut_);

    function rejectNewTerms(address loan_, address refinancer_, uint256 deadline_, bytes[] calldata calls_) external;

    function removeLoanImpairment(address loan_) external;

    function triggerDefault(
        address loan_,
        address liquidatorFactory_
    )
        external
        returns (bool liquidationComplete_, uint256 remainingLosses_, uint256 platformFees_);

    function unrealizedLosses() external view returns (uint128 unrealizedLosses_);

}

interface IMapleCCIPReceiverLike {

    struct UniversalMessage {
        bytes32 universalSenderAddress;
        address pool;
        bytes32 metaData;
    }

    struct EVMTokenAmount {
        address token;
        uint256 amount;
    }

    struct Any2EVMMessage {
        bytes32 messageId;
        uint64 sourceChainSelector;
        bytes sender;
        bytes data;
        EVMTokenAmount[] destTokenAmounts;
    }

    function executeRedeemList(uint128[] calldata requestIds_) external;

    function processMessage(Any2EVMMessage calldata message_) external;

}

// NOTE: Isn't it better to import the interface from the module instead of re-declaring it here?
interface IProxyFactoryLike {

    function createInstance(bytes calldata arguments_, bytes32 salt_) external returns (address instance_);

    function defaultVersion() external view returns (uint256 defaultVersion_);

    function enableUpgradePath(uint256 fromVersion_, uint256 toVersion_, address migrator_) external;

    function implementationOf(uint256 version_) external view returns (address implementation_);

    function isInstance(address instance_) external view returns (bool isInstance_);

    function isLoan(address proxy_) external view returns (bool isLoan_);

    function migratorForPath(uint256 oldVersion_, uint256 newVersion_) external view returns (address migrator_);

    function mapleGlobals() external view returns (address globals_);

    function registerImplementation(uint256 version_, address implementationAddress_, address initializer_) external;

    function setDefaultVersion(uint256 version_) external;

    function upgradeEnabledForPath(uint256 toVersion_, uint256 fromVersion_) external view returns (bool allowed_);

    function upgradeInstance(uint256 toVersion_, bytes calldata arguments_) external;

}

interface IPSMLike {

    function file(bytes32 what, uint256 data) external;

    function pocket() external view returns (address pocket_);

    function tin() external view returns (uint256 tin_);

    function tout() external view returns (uint256 tout_);

    function to18ConversionFactor() external view returns (uint256 to18ConversionFactor_);

}

interface IUnderlyingStrategyLike {

    function assetsUnderManagement() external view returns (uint256 assetsUnderManagement);

    function availableToWithdraw() external view returns (uint256 availableToWithdraw);

    function globals() external view returns (address globals);

    function impair(uint256 amount) external;

    function impairedAssets() external view returns (uint256 impairedAssets);

    function lastRecordedTotalAssets() external view returns (uint256 lastRecordedTotalAssets);

    function removeImpairment(uint256 amount) external;

    function strategyDelegate() external view returns (address strategyDelegate);

    function strategyDelegateFeeRate() external view returns (uint32 strategyDelegateFeeRate);

    function strategyProtocolFeeRate() external view returns (uint32 strategyProtocolFeeRate);

    function setStrategyDelegateFeeRate(uint32 strategyDelegateFeeRate) external;

    function setStrategyProtocolFeeRate(uint32 strategyProtocolFeeRate) external;

    function unrealizedLosses() external view returns (uint256 unrealizedLosses);

    function withdrawFromUnderlyingStrategy(address destination, uint256 assets, bytes calldata data) external;

}

// NOTE: cycleConfigs() is not defined as a view function in the submodule which needs updating.
interface IWithdrawalManagerLike {

    function cycleConfigs(uint256 configId_)
        external
        view
        returns (uint64 initialCycleId, uint64 initialCycleTime, uint64 cycleDuration, uint64 windowDuration);

    function getCurrentCycleId() external view returns (uint256 cycleId_);

}

interface IWithdrawalManagerQueueV200Like {

    function processRedemptions(uint256 maxSharesToProcess) external;

}

interface IStrategyLike {

    function assetsUnderManagement() external view returns (uint256 assetsUnderManagement);

    function unrealizedLosses() external view returns (uint256 unrealizedLosses);

    function fundsAsset() external view returns (address fundsAsset);

    function fundStrategy(uint256 assetsIn) external;

    function fundStrategy(uint256 assetsIn, uint256 minSharesOut) external;

    function pool() external view returns (address pool);

    function poolManager() external view returns (address poolManager);

    function withdrawFromStrategy(uint256 assetsOut) external;

    function withdrawFromStrategy(uint256 assetsOut, uint256 minSharesBurned) external;

}

interface ISyrupUSDCrossChainLike {

    function DEFAULT_ADMIN_ROLE() external view returns (bytes32 role);

    function MINTER_ROLE() external view returns (bytes32 role);

    function BURNER_ROLE() external view returns (bytes32 role);

    function hasRole(bytes32 role, address account) external view returns (bool hasRole);

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;

    function renounceRole(bytes32 role, address account) external;

}

interface IUSDCLike {

    function configureMinter(address minter, uint256 minterAllowedAmount) external returns (bool);

    function masterMinter() external view returns (address);

    function mint(address to, uint256 amount) external;

}

interface IMapleTreasuryLike {

    function reclaimERC20(address asset_, uint256 amount_) external;

}

/******************************************************************************************************************************************/
/*** Test Interfaces                                                                                                                    ***/
/******************************************************************************************************************************************/

interface IHandlerEntryPoint {

    function entryPoint(uint256 seed_) external;

}

interface IInvariantTest {

    function currentTimestamp() external view returns (uint256 currentTimestamp_);

    function setCurrentTimestamp(uint256 currentTimestamp_) external;

}

interface IMockERC20 is IERC20 {

    function burn(address owner_, uint256 amount_) external;

    function mint(address recipient_, uint256 amount_) external;

    // NOTE: Implemented by `ConfigurableMockERC20`, might not be available for all instances.
    function __failWhenCalledBy(address caller_) external;

}

interface IStrategyHandler {

    function _syncYieldAndFees() external;

}
