// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IERC20 } from "../../modules/erc20/contracts/interfaces/IERC20.sol";

import { IMapleGlobals as IMG }   from "../../modules/globals/contracts/interfaces/IMapleGlobals.sol";
import { INonTransparentProxied } from "../../modules/globals/modules/non-transparent-proxy/contracts/interfaces/INonTransparentProxied.sol";
import { INonTransparentProxy }   from "../../modules/globals/modules/non-transparent-proxy/contracts/interfaces/INonTransparentProxy.sol";

import { IMapleLiquidator as IML } from "../../modules/liquidations/contracts/interfaces/IMapleLiquidator.sol";

import { IMapleLoan as IMFTL }           from "../../modules/fixed-term-loan/contracts/interfaces/IMapleLoan.sol";
import { IMapleLoanFeeManager as IMLFM } from "../../modules/fixed-term-loan/contracts/interfaces/IMapleLoanFeeManager.sol";
import { IMapleRefinancer as IMFTLR }    from "../../modules/fixed-term-loan/contracts/interfaces/IMapleRefinancer.sol";

import { IMapleLoanManager as IMFTLM }         from "../../modules/fixed-term-loan-manager/contracts/interfaces/IMapleLoanManager.sol";
import { IMapleLoanManagerStructs as IMFTLMS } from "../../modules/fixed-term-loan-manager/tests/interfaces/IMapleLoanManagerStructs.sol";

import { IMapleLoan as IMOTL } from "../../modules/open-term-loan/contracts/interfaces/IMapleLoan.sol";

import { IMapleLoanManager as IMOTLM }         from "../../modules/open-term-loan-manager/contracts/interfaces/IMapleLoanManager.sol";
import { IMapleLoanManagerStructs as IMOTLMS } from "../../modules/open-term-loan-manager/tests/utils/Interfaces.sol";

import { IMaplePool as IMP }          from "../../modules/pool/contracts/interfaces/IMaplePool.sol";
import { IMaplePoolDeployer as IMPD } from "../../modules/pool/contracts/interfaces/IMaplePoolDeployer.sol";
import { IMaplePoolManager as IMPM }  from "../../modules/pool/contracts/interfaces/IMaplePoolManager.sol";
import { IMapleProxyFactory }         from "../../modules/pool/modules/maple-proxy-factory/contracts/interfaces/IMapleProxyFactory.sol";

import { IMapleWithdrawalManager as IMWM } from "../../modules/withdrawal-manager/contracts/interfaces/IMapleWithdrawalManager.sol";

/******************************************************************************************************************************************/
/*** Re-Exports                                                                                                                         ***/
/******************************************************************************************************************************************/

interface IFeeManager is IMLFM { }

interface IFixedTermLoan is IMFTL { }

interface IFixedTermLoanManager is IMFTLM { }

interface IFixedTermLoanManagerStructs is IMFTLMS { }

interface IFixedTermRefinancer is IMFTLR { }

interface IGlobals is IMG { }

interface ILiquidator is IML { }

interface IOpenTermLoan is IMOTL { }

interface IOpenTermLoanManager is IMOTLM { }

interface IOpenTermLoanManagerStructs is IMOTLMS { }

interface IPool is IMP { }

interface IPoolDeployer is IMPD { }

interface IPoolManager is IMPM { }

interface IWithdrawalManager is IMWM { }

/******************************************************************************************************************************************/
/*** Like Interfaces                                                                                                                    ***/
/******************************************************************************************************************************************/

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

interface ILiquidatorLike {

    function getExpectedAmount(uint256 swapAmount_) external view returns (uint256 expectedAmount_);

    function liquidatePortion(uint256 swapAmount_, uint256 maxReturnAmount_, bytes calldata data_) external;

}

interface IProxiedLike {

    function implementation() external view returns (address implementation_);

    function upgrade(uint256 toVersion_, bytes calldata arguments_) external;

}

// NOTE: Needs to be defined after `IProxiedLike`.
interface ILoanLike is IProxiedLike {

    function acceptBorrower() external;

    function acceptLender() external;

    function acceptNewTerms(address refinancer_, uint256 deadline_, bytes[] calldata calls_)
        external returns (bytes32 refinanceCommitment_);

    function borrower() external view returns (address borrower_);

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

// NOTE: Isn't it better to import the interface from the module instead of re-declaring it here?
interface IProxyFactoryLike {

    function createInstance(bytes calldata arguments_, bytes32 salt_) external returns (address instance_);

    function defaultVersion() external view returns (uint256 defaultVersion_);

    function enableUpgradePath(uint256 fromVersion_, uint256 toVersion_, address migrator_) external;

    function implementationOf(uint256 version_) external view returns (address implementation_);

    function isInstance(address instance_) external view returns (bool isInstance_);

    function migratorForPath(uint256 oldVersion_, uint256 newVersion_) external view returns (address migrator_);

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

}
