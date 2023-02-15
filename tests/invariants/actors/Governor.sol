// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IGlobals, IPoolManager } from "../../../contracts/interfaces/Interfaces.sol";

contract GovernorBase {

    IGlobals     globals;
    IPoolManager poolManager;

    constructor (address globals_, address poolManager_) {
        globals     = IGlobals(globals_);
        poolManager = IPoolManager(poolManager_);
    }

    /**************************************************************************************************************************************/
    /*** Globals Functions                                                                                                              ***/
    /**************************************************************************************************************************************/

    function activatePoolManager(address poolManager_) public virtual {
        globals.activatePoolManager(poolManager_);
    }

    function setMapleTreasury(address mapleTreasury_) public virtual {
        globals.setMapleTreasury(mapleTreasury_);
    }

    function setMigrationAdmin(address migrationAdmin_) public virtual {
        globals.setMigrationAdmin(migrationAdmin_);
    }

    function setPriceOracle(address asset_, address priceOracle_) public virtual {
        globals.setPriceOracle(asset_, priceOracle_);
    }

    function setSecurityAdmin(address securityAdmin_) public virtual {
        globals.setSecurityAdmin(securityAdmin_);
    }

    function setDefaultTimelockParameters(uint128 defaultTimelockDelay_, uint128 defaultTimelockDuration_) public virtual {
        globals.setDefaultTimelockParameters(defaultTimelockDelay_, defaultTimelockDuration_);
    }

    function setProtocolPause(bool protocolPaused_) public virtual {
        globals.setProtocolPause(protocolPaused_);
    }

    function setValidBorrower(address borrower_, bool isValid_) public virtual {
        globals.setValidBorrower(borrower_, isValid_);
    }

    function setValidFactory(bytes32 factoryKey_, address factory_, bool isValid_) public virtual {
        globals.setValidFactory(factoryKey_, factory_, isValid_);
    }

    function setValidPoolAsset(address poolAsset_, bool isValid_) public virtual {
        globals.setValidPoolAsset(poolAsset_, isValid_);
    }

    function setValidPoolDelegate(address poolDelegate_, bool isValid_) public virtual {
        globals.setValidPoolDelegate(poolDelegate_, isValid_);
    }

    function setValidPoolDeployer(address poolDeployer_, bool isValid_) public virtual {
        globals.setValidPoolDeployer(poolDeployer_, isValid_);
    }

    function setManualOverridePrice(address asset_, uint256 price_) public virtual {
        globals.setManualOverridePrice(asset_, price_);
    }

    function setMaxCoverLiquidationPercent(address poolManager_, uint256 maxCoverLiquidationPercent_) public virtual {
        globals.setMaxCoverLiquidationPercent(poolManager_, maxCoverLiquidationPercent_);
    }

    function setMinCoverAmount(address poolManager_, uint256 minCoverAmount_) public virtual {
        globals.setMinCoverAmount(poolManager_, minCoverAmount_);
    }

    function setPlatformManagementFeeRate(address poolManager_, uint256 platformManagementFeeRate_) public virtual {
        globals.setPlatformManagementFeeRate(poolManager_, platformManagementFeeRate_);
    }

    function setPlatformOriginationFeeRate(address poolManager_, uint256 platformOriginationFeeRate_) public virtual {
        globals.setPlatformOriginationFeeRate(poolManager_, platformOriginationFeeRate_);
    }

    function setPlatformServiceFeeRate(address poolManager_, uint256 platformServiceFeeRate_) public virtual {
        globals.setPlatformServiceFeeRate(poolManager_, platformServiceFeeRate_);
    }

    function setTimelockWindow(address contract_, bytes32 functionId_, uint128 delay_, uint128 duration_) public virtual {
        globals.setTimelockWindow(contract_, functionId_, delay_, duration_);
    }

    function setTimelockWindows(
        address contract_,
        bytes32[] calldata functionIds_,
        uint128[] calldata delays_,
        uint128[] calldata durations_
    )
        public virtual
    {
        globals.setTimelockWindows(contract_, functionIds_, delays_, durations_);
    }

    function transferOwnedPoolManager(address fromPoolDelegate_, address toPoolDelegate_) public virtual {
        globals.transferOwnedPoolManager(fromPoolDelegate_, toPoolDelegate_);
    }

    function scheduleCall(address contract_, bytes32 functionId_, bytes calldata callData_) public virtual {
        globals.scheduleCall(contract_, functionId_, callData_);
    }

    function unscheduleCall(address caller_, bytes32 functionId_, bytes calldata callData_) public virtual {
        globals.unscheduleCall(caller_, functionId_, callData_);
    }

    function unscheduleCall(address caller_, address contract_, bytes32 functionId_, bytes calldata callData_) public virtual {
        globals.unscheduleCall(caller_, contract_, functionId_, callData_);
    }

    /**************************************************************************************************************************************/
    /*** PoolManager Functions                                                                                                          ***/
    /**************************************************************************************************************************************/

    function finishCollateralLiquidation(address loan_) public virtual {
        poolManager.finishCollateralLiquidation(loan_);
    }

    function impairLoan(address loan_) public virtual {
        poolManager.impairLoan(loan_);
    }

    function setAllowedSlippage(address loanManager_, address collateralAsset_, uint256 allowedSlippage_) public virtual {
        poolManager.setAllowedSlippage(loanManager_, collateralAsset_, allowedSlippage_);
    }

    function setMinRatio(address loanManager_, address collateralAsset_, uint256 minRatio_) public virtual {
        poolManager.setMinRatio(loanManager_, collateralAsset_, minRatio_);
    }

    function removeLoanImpairment(address loan_) public virtual {
        poolManager.removeLoanImpairment(loan_);
    }

    function triggerDefault(address loan_, address liquidatorFactory_) public virtual {
        poolManager.triggerDefault(loan_, liquidatorFactory_);
    }

    function upgrade(uint256 version_, bytes calldata arguments_) public virtual {
        poolManager.upgrade(version_, arguments_);
    }

}
