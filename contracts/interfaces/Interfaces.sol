// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IERC20 } from "../../modules/erc20/contracts/interfaces/IERC20.sol";

import { IMapleGlobals as IMG }   from "../../modules/globals/contracts/interfaces/IMapleGlobals.sol";
import { INonTransparentProxied } from "../../modules/globals/modules/non-transparent-proxy/contracts/interfaces/INonTransparentProxied.sol";
import { INonTransparentProxy }   from "../../modules/globals/modules/non-transparent-proxy/contracts/interfaces/INonTransparentProxy.sol";

import { ILiquidator } from "../../modules/liquidations/contracts/interfaces/ILiquidator.sol";

import { IMapleLoan as IMFTL }           from "../../modules/fixed-term-loan/contracts/interfaces/IMapleLoan.sol";
import { IMapleLoanFeeManager as IMLFM } from "../../modules/fixed-term-loan/contracts/interfaces/IMapleLoanFeeManager.sol";
import { IRefinancer as IMFTLR }         from "../../modules/fixed-term-loan/contracts/interfaces/IRefinancer.sol";

import { ILoanManager as IMFTLM }         from "../../modules/fixed-term-loan-manager/contracts/interfaces/ILoanManager.sol";
import { ILoanManagerStructs as IMFTLMS } from "../../modules/fixed-term-loan-manager/tests/interfaces/ILoanManagerStructs.sol";

import { IMapleLoan as IMOTL } from "../../modules/open-term-loan/contracts/interfaces/IMapleLoan.sol";

import { ILoanManager as IMOTLM }         from "../../modules/open-term-loan-manager/contracts/interfaces/ILoanManager.sol";
import { ILoanManagerStructs as IMOTLMS } from "../../modules/open-term-loan-manager/tests/utils/Interfaces.sol";

import { IPool }        from "../../modules/pool/contracts/interfaces/IPool.sol";
import { IPoolManager } from "../../modules/pool/contracts/interfaces/IPoolManager.sol";

import { IWithdrawalManager } from "../../modules/withdrawal-manager/contracts/interfaces/IWithdrawalManager.sol";

/******************************************************************************************************************************************/
/*** Re-Exports                                                                                                                         ***/
/******************************************************************************************************************************************/

interface IFeeManager is IMLFM { }

interface IFixedTermLoan is IMFTL { }

interface IFixedTermLoanManager is IMFTLM { }

interface IFixedTermLoanManagerStructs is IMFTLMS { }

interface IFixedTermRefinancer is IMFTLR { }

interface IGlobals is IMG { }

interface IOpenTermLoan is IMOTL { }

interface IOpenTermLoanManager is IMOTLM { }

interface IOpenTermLoanManagerStructs is IMOTLMS { }

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

    function upgrade(uint256 toVersion_, bytes calldata arguments_) external;

}

interface ILoanLike is IProxiedLike {

    function acceptBorrower() external;

    function acceptLender() external;

    function acceptNewTerms(address refinancer_, uint256 deadline_, bytes[] calldata calls_)
        external returns (bytes32 refinanceCommitment_);

    function borrower() external view returns (address borrower_);

    function fundsAsset() external view returns (address fundsAsset_);

    function gracePeriod() external view returns (uint256 gracePeriod_);

    function isImpaired() external view returns (bool isImpaired_);

    function lender() external view returns (address lender_);

    function paymentInterval() external view returns (uint256 paymentInterval_);

    function principal() external view returns (uint256 principal_);

    function principalRequested() external view returns (uint256 principalRequested_);

    function proposeNewTerms(address refinancer_, uint256 deadline_, bytes[] calldata calls_)
        external returns (bytes32 refinanceCommitment_);

    function rejectNewTerms(address refinancer_, uint256 deadline_, bytes[] calldata calls_)
        external returns (bytes32 refinanceCommitment_);

    function setPendingBorrower(address pendingBorrower_) external;

    function skim(address token_, address destination_) external returns (uint256 skimmed_);

}

interface ILoanManagerLike is IProxiedLike {

    function acceptNewTerms(
        address loan_,
        address refinancer_,
        uint256 deadline_,
        bytes[] calldata calls_,
        uint256 principalIncrease_
    ) external;

    function accountedInterest() external view returns (uint112 accountedInterest_);

    function assetsUnderManagement() external view returns (uint256 assetsUnderManagement_);

    function domainEnd() external view returns (uint48 domainEnd_);

    function domainStart() external view returns (uint48 domainStart_);

    function fund(address loan_) external;

    function fundsAsset() external view returns (address fundsAsset_);

    function getAccruedInterest() external view returns (uint256 accruedInterest_);

    function impairLoan(address loan_) external;

    function issuanceRate() external view returns (uint256 issuanceRate_);

    function paymentIdOf(address loan_) external view returns (uint24 paymentId_);

    function paymentCounter() external view returns (uint24 paymentCounter_);

    function payments(uint256 paymentId_) external view returns (
        uint24  platformManagementFeeRate,
        uint24  delegateManagementFeeRate,
        uint48  startDate,
        uint48  paymentDueDate,
        uint128 incomingNetInterest,
        uint128 refinanceInterest,
        uint256 issuanceRate
    );

    function paymentWithEarliestDueDate() external view returns (uint24 paymentWithEarliestDueDate_);

    function poolManager() external view returns (address poolManager_);

    function principalOut() external view returns (uint128 principalOut_);

    function removeLoanImpairment(address loan_) external;

    function sortedPayments(uint256 paymentId_) external view returns (uint24 previous, uint24 next, uint48 paymentDueDate);

    function triggerDefault(address loan_, address liquidatorFactory_)
        external returns (bool liquidationComplete_, uint256 remainingLosses_, uint256 platformFees_);

    function unrealizedLosses() external view returns (uint128 unrealizedLosses_);

    function updateAccounting() external;

}

interface IProxyFactoryLike {

    function createInstance(bytes calldata arguments_, bytes32 salt_) external returns (address instance_);

    function defaultVersion() external view returns (uint256 defaultVersion_);

    function enableUpgradePath(uint256 fromVersion_, uint256 toVersion_, address migrator_) external;

    function registerImplementation(uint256 version_, address implementationAddress_, address initializer_) external;

}
