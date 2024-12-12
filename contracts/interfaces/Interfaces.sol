// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC20 } from "../../modules/erc20/contracts/interfaces/IERC20.sol";

import { IMapleProxied } from "../../modules/pool/modules/maple-proxy-factory/contracts/interfaces/IMapleProxied.sol";

import { IMapleGlobals as IMG }   from "../../modules/globals/contracts/interfaces/IMapleGlobals.sol";
import { INonTransparentProxied } from "../../modules/globals/modules/non-transparent-proxy/contracts/interfaces/INonTransparentProxied.sol";
import { INonTransparentProxy }   from "../../modules/globals/modules/non-transparent-proxy/contracts/interfaces/INonTransparentProxy.sol";

import { IMapleLiquidator as IML } from "../../modules/liquidations/contracts/interfaces/IMapleLiquidator.sol";

import { IMapleLoan as IMFTL }           from "../../modules/fixed-term-loan/contracts/interfaces/IMapleLoan.sol";
import { IMapleLoanFeeManager as IMLFM } from "../../modules/fixed-term-loan/contracts/interfaces/IMapleLoanFeeManager.sol";
import { IMapleRefinancer as IMFTLR }    from "../../modules/fixed-term-loan/contracts/interfaces/IMapleRefinancer.sol";

import { IMapleLoanManager as IMFTLM }         from "../../modules/fixed-term-loan-manager/contracts/interfaces/IMapleLoanManager.sol";
import { IMapleLoanManagerStructs as IMFTLMS } from "../../modules/fixed-term-loan-manager/tests/interfaces/IMapleLoanManagerStructs.sol";

import { IMapleLoan as IMOTL }        from "../../modules/open-term-loan/contracts/interfaces/IMapleLoan.sol";
import { IMapleRefinancer as IMOTLR } from "../../modules/open-term-loan/contracts/interfaces/IMapleRefinancer.sol";

import { IMapleLoanManager as IMOTLM }         from "../../modules/open-term-loan-manager/contracts/interfaces/IMapleLoanManager.sol";
import { IMapleLoanManagerStructs as IMOTLMS } from "../../modules/open-term-loan-manager/tests/utils/Interfaces.sol";

import { IMaplePool as IMP }                from "../../modules/pool/contracts/interfaces/IMaplePool.sol";
import { IMaplePoolDelegateCover as IMPDC } from "../../modules/pool/contracts/interfaces/IMaplePoolDelegateCover.sol";
import { IMaplePoolDeployer as IMPD }       from "../../modules/pool/contracts/interfaces/IMaplePoolDeployer.sol";
import { IMaplePoolManager as IMPM }        from "../../modules/pool/contracts/interfaces/IMaplePoolManager.sol";
import { IMapleProxied }                    from "../../modules/pool/modules/maple-proxy-factory/contracts/interfaces/IMapleProxied.sol";
import { IMapleProxyFactory }               from "../../modules/pool/modules/maple-proxy-factory/contracts/interfaces/IMapleProxyFactory.sol";

import { IMaplePoolPermissionManager as IMPPM }
    from "../../modules/pool-permission-manager/contracts/interfaces/IMaplePoolPermissionManager.sol";

import { IMaplePoolPermissionManagerInitializer as IMPPMI }
    from "../../modules/pool-permission-manager/contracts/interfaces/IMaplePoolPermissionManagerInitializer.sol";

import { ISyrupRouter as ISR } from "../../modules/syrup-utils/contracts/interfaces/ISyrupRouter.sol";

import { IMapleWithdrawalManager as IMWMC }
    from "../../modules/withdrawal-manager-cyclical/contracts/interfaces/IMapleWithdrawalManager.sol";

import { IMapleWithdrawalManager as IMWMQ }
    from "../../modules/withdrawal-manager-queue/contracts/interfaces/IMapleWithdrawalManager.sol";

import { IMapleStrategy }      from "../../modules/strategies/contracts/interfaces/IMapleStrategy.sol";
import { IMapleAaveStrategy }  from "../../modules/strategies/contracts/interfaces/aaveStrategy/IMapleAaveStrategy.sol";
import { IMapleBasicStrategy } from "../../modules/strategies/contracts/interfaces/basicStrategy/IMapleBasicStrategy.sol";
import { IMapleSkyStrategy }   from "../../modules/strategies/contracts/interfaces/skyStrategy/IMapleSkyStrategy.sol";

/******************************************************************************************************************************************/
/*** Re-Exports                                                                                                                         ***/
/******************************************************************************************************************************************/

interface IAaveStrategy is IMapleAaveStrategy { }

interface IFeeManager is IMLFM { }

interface IFixedTermLoan is IMFTL { }

interface IFixedTermLoanManager is IMFTLM { }

interface IFixedTermLoanManagerStructs is IMFTLMS { }

interface IFixedTermRefinancer is IMFTLR { }

interface IGlobals is IMG { }

interface ILiquidator is IML { }

interface IOpenTermLoan is IMOTL { }

interface IOpenTermRefinancer is IMOTLR { }

interface IOpenTermLoanManager is IMOTLM { }

interface IOpenTermLoanManagerStructs is IMOTLMS { }

interface IPool is IMP { }

interface IPoolDelegateCover is IMPDC { }

interface IPoolDeployer is IMPD { }

interface IPoolManager is IMPM { }

interface IPoolPermissionManager is IMPPM { }

interface IPoolPermissionManagerInitializer is IMPPMI { }

interface IStrategy is IMapleStrategy { }

interface ISkyStrategy is IMapleSkyStrategy { }

interface IBasicStrategy is IMapleBasicStrategy { }

interface ISyrupRouter is ISR { }

interface IWithdrawalManagerCyclical is IMWMC { }

interface IWithdrawalManagerQueue is IMWMQ {}

/******************************************************************************************************************************************/
/*** Like Interfaces                                                                                                                    ***/
/******************************************************************************************************************************************/

interface IAaveRewardsControllerLike {

    function getRewardsList() external view returns (address[] memory);

    function getRewardsByAsset(address asset) external view returns (address[] memory);

    function getUserRewards(address[] calldata assets, address user, address reward) external view returns (uint256);

}

interface IAaveTokenLike {

    function getIncentivesController() external view returns (address controller);

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

interface ILiquidatorLike {

    function getExpectedAmount(uint256 swapAmount_) external view returns (uint256 expectedAmount_);

    function liquidatePortion(uint256 swapAmount_, uint256 maxReturnAmount_, bytes calldata data_) external;

}

interface IPoolDeployerV2Like {

    function deployPool(
        address           poolManagerFactory_,
        address           withdrawalManagerFactory_,
        address[]  memory loanManagerFactories_,
        address           asset_,
        string     memory name_,
        string     memory symbol_,
        uint256[6] memory configParams_
    )
        external
        returns (address poolManager_);
}

interface IProxiedLike {

    function implementation() external view returns (address implementation_);

    function upgrade(uint256 toVersion_, bytes calldata arguments_) external;

}

// NOTE: Needs to be defined after `IProxiedLike`.
interface ILoanLike is IProxiedLike {

    function acceptBorrower() external;

    function acceptLender() external;

    function acceptLoanTerms() external;

    function acceptNewTerms(address refinancer_, uint256 deadline_, bytes[] calldata calls_)
        external returns (bytes32 refinanceCommitment_);

    function borrower() external view returns (address borrower_);

    function factory() external view returns (address factory_);

    function fundsAsset() external view returns (address fundsAsset_);

    function globals() external view returns (address globals_);

    function gracePeriod() external view returns (uint256 gracePeriod_);

    function isImpaired() external view returns (bool isImpaired_);

    function lender() external view returns (address lender_);

    function paymentInterval() external view returns (uint256 paymentInterval_);

    function principal() external view returns (uint256 principal_);

    function proposeNewTerms(address refinancer_, uint256 deadline_, bytes[] calldata calls_)
        external returns (bytes32 refinanceCommitment_);

    function rejectNewTerms(address refinancer_, uint256 deadline_, bytes[] calldata calls_)
        external returns (bytes32 refinanceCommitment_);

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

    function triggerDefault(address loan_, address liquidatorFactory_)
        external returns (bool liquidationComplete_, uint256 remainingLosses_, uint256 platformFees_);

    function unrealizedLosses() external view returns (uint128 unrealizedLosses_);

}

interface IPolicyManagerLike {

    function getRoleAdmin(bytes32 role) external view returns (bytes32 admin);

    function grantRole(bytes32 role, address account) external;

    function policyDisabled(uint32 policyId) external view returns (bool isDisabled);

    function policyAllowApprovedCounterparties(uint32 policyId) external view returns (bool isAllowed);

}

interface IFixedTermLoanFactory is IMapleProxyFactory {

    function isLoan(address proxy_) external view returns (bool isLoan_);

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
}

// NOTE: cycleConfigs() is not defined as a view function in the submodule which needs updating.
interface IWithdrawalManagerLike {

    function cycleConfigs(uint256 configId_)
        external view returns (uint64 initialCycleId, uint64 initialCycleTime, uint64 cycleDuration, uint64 windowDuration);

    function getCurrentCycleId() external view returns (uint256 cycleId_);
}

interface IPSMLike {

    function buyGem(address usr, uint256 gemAmt) external returns (uint256 daiInWad);

    function file(bytes32 what, uint256 data) external;

    function gem() external view returns (address gem);

    function psm() external view returns (address pms);

    function sellGem(address usr, uint256 gemAmt) external returns (uint256 daiOutWad);

    function tin() external view returns (uint256 tin); // Sell side fee

    function tout() external view returns (uint256 tout); // Buy side fee

    function to18ConversionFactor() external view returns (uint256 to18ConversionFactor);

    function usds() external view returns (address usds);

}

interface IStrategyLike is IStrategy {

    function aaveToken() external view returns (address aaveToken);

    function fundsAsset() external view returns (address fundsAsset);

    function fundStrategy(uint256 assetsIn) external;

    function fundStrategy(uint256 assetsIn, uint256 minSharesOut) external;

    function lastRecordedTotalAssets() external view returns (uint256 lastRecordedTotalAssets);

    function pool() external view returns (address pool);

    function poolManager() external view returns (address poolManager);

    function psm() external view returns (address psm);

    function savingsUsds() external view returns (address savingsUsds);

    function strategyFeeRate() external view returns (uint256 strategyFeeRate);

    function strategyState() external view returns (uint256 strategyState);

    function strategyVault() external view returns (address strategyVault);

}

interface IUSDCLike {

    function masterMinter() external view returns (address);

    function configureMinter(address minter, uint256 minterAllowedAmount) external returns (bool);

}

/******************************************************************************************************************************************/
/*** Smart Account Interfaces                                                                                                           ***/
/******************************************************************************************************************************************/

struct UserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    uint256 callGasLimit;
    uint256 verificationGasLimit;
    uint256 preVerificationGas;
    uint256 maxFeePerGas;
    uint256 maxPriorityFeePerGas;
    bytes paymasterAndData;
    bytes signature;
}

struct Call {
    address target;
    uint256 value;
    bytes data;
}

interface IEntryPointLike {

    function depositTo(address) external payable;

    function addStake(uint32) external payable;

    function unlockStake() external;

    function withdrawStake(address payable) external;

    function handleOps(UserOperation[] calldata, address payable) external;

    function getNonce(address, uint192) external view returns (uint256);

    function getUserOpHash(UserOperation calldata) external view returns (bytes32);

}

interface IMultiOwnerModularAccountFactoryLike {

    function createAccount(uint256 salt, address[] calldata owners) external returns (address addr);

    function getAddress(uint256 salt, address[] calldata owners) external view returns (address);

}

interface IModularAccountLike {

    function execute(address target, uint256 value, bytes calldata data) external payable returns (bytes memory result);

    function executeBatch(Call[] calldata calls) external payable returns (bytes[] memory results);

    function getInstalledPlugins() external view returns (address[] memory pluginAddresses);

    function getNonce() external view returns (uint256);

    function installPlugin(
        address plugin,
        bytes32 manifestHash,
        bytes calldata pluginInstallData,
        bytes21[] calldata dependencies
    ) external;

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
