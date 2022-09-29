// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { ILoanManager } from "../../../modules/pool-v2/contracts/interfaces/ILoanManager.sol";
import { IPool }        from "../../../modules/pool-v2/contracts/interfaces/IPool.sol";
import { IPoolManager } from "../../../modules/pool-v2/contracts/interfaces/IPoolManager.sol";

contract PoolDelegateBase {

    address poolDelegateCover;

    ILoanManager loanManager;
    IPool        pool;
    IPoolManager poolManager;


    constructor (address poolManager_) {
        poolManager = IPoolManager(poolManager_);

        loanManager       = ILoanManager(poolManager.loanManagerList(0));
        pool              = IPool(poolManager.pool());
        poolDelegateCover = poolManager.poolDelegateCover();
    }

    function acceptPendingPoolDelegate() public virtual {
        poolManager.acceptPendingPoolDelegate();
    }

    function setPendingPoolDelegate(address pendingPoolDelegate_) public virtual {
        poolManager.setPendingPoolDelegate(pendingPoolDelegate_);
    }

    function configure(address loanManager_, address withdrawalManager_, uint256 liquidityCap_, uint256 managementFee_) public virtual {
        poolManager.configure(loanManager_, withdrawalManager_, liquidityCap_, managementFee_);
    }

    function addLoanManager(address loanManager_) public virtual {
        poolManager.addLoanManager(loanManager_);
    }

    function removeLoanManager(address loanManager_) public virtual {
        poolManager.removeLoanManager(loanManager_);
    }

    function setActive(bool active_) public virtual {
        poolManager.setActive(active_);
    }

    function setAllowedLender(address lender_, bool isValid_) public virtual {
        poolManager.setAllowedLender(lender_, isValid_);
    }

    function setAllowedSlippage(address loanManager_, address collateralAsset_, uint256 allowedSlippage_) public virtual {
        poolManager.setAllowedSlippage(loanManager_, collateralAsset_, allowedSlippage_);
    }

    function setLiquidityCap(uint256 liquidityCap_) public virtual {
        poolManager.setLiquidityCap(liquidityCap_);
    }

    function setDelegateManagementFeeRate(uint256 delegateManagementFeeRate_) public virtual {
        poolManager.setDelegateManagementFeeRate(delegateManagementFeeRate_);
    }

    function setMinRatio(address loanManager_, address collateralAsset_, uint256 minRatio_) public virtual {
        poolManager.setMinRatio(loanManager_, collateralAsset_, minRatio_);
    }

    function setOpenToPublic() public virtual {
        poolManager.setOpenToPublic();
    }

    function setWithdrawalManager(address withdrawalManager_) public virtual {
        poolManager.setWithdrawalManager(withdrawalManager_);
    }

    function acceptNewTerms(
        address loan_,
        address refinancer_,
        uint256 deadline_,
        bytes[] calldata calls_,
        uint256 principalIncrease_
    ) public virtual {
        poolManager.acceptNewTerms(loan_, refinancer_, deadline_, calls_, principalIncrease_);
    }

    function fund(uint256 principal_, address loan_, address loanManager_) public virtual {
        poolManager.fund(principal_, loan_, loanManager_);
    }

    function finishCollateralLiquidation(address loan_) public virtual {
        poolManager.finishCollateralLiquidation(loan_);
    }

    function removeLoanImpairment(address loan_) public virtual {
        poolManager.removeLoanImpairment(loan_);
    }

    function triggerDefault(address loan_, address liquidatorFactory_) public virtual {
        poolManager.triggerDefault(loan_, liquidatorFactory_);
    }

    function impairLoan(address loan_) public virtual {
        poolManager.impairLoan(loan_);
    }

    function depositCover(uint256 amount_) public virtual {
        poolManager.depositCover(amount_);
    }

    function withdrawCover(uint256 amount_, address recipient_) public virtual {
        poolManager.withdrawCover(amount_, recipient_);
    }

}
