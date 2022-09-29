// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { IPool } from "../../../modules/pool-v2/contracts/interfaces/IPool.sol";

contract LpBase {

    IPool pool;

    constructor (address pool_) {
        pool = IPool(pool_);
    }

    /******************************************************************************************************************************/
    /*** Pool Functions                                                                                                         ***/
    /******************************************************************************************************************************/

    function deposit(uint256 assets_, address receiver_) public virtual returns (uint256 shares_) {
        return pool.deposit(assets_, receiver_);
    }

    function depositWithPermit(uint256 assets_, address receiver_, uint256 deadline_, uint8 v_, bytes32 r_, bytes32 s_) public virtual returns (uint256 shares_) {
        return pool.depositWithPermit(assets_, receiver_, deadline_, v_, r_, s_);
    }

    function mint(uint256 shares_, address receiver_) public virtual returns (uint256 assets_) {
        return pool.mint(shares_, receiver_);
    }

    function mintWithPermit(uint256 shares_, address receiver_, uint256 maxAssets_, uint256 deadline_, uint8 v_, bytes32 r_, bytes32 s_) public virtual returns (uint256 assets_) {
        return pool.mintWithPermit(shares_, receiver_, maxAssets_, deadline_, v_, r_, s_);
    }

    function redeem(uint256 shares_, address receiver_, address owner_) public virtual returns (uint256 assets_) {
        return pool.redeem(shares_, receiver_, owner_);
    }

    function removeShares(uint256 shares_, address owner_) public virtual returns (uint256 sharesReturned_) {
        return pool.removeShares(shares_, owner_);
    }

    function requestWithdraw(uint256 assets_, address owner_) public virtual returns (uint256 escrowShares_) {
        return pool.requestWithdraw(assets_, owner_);
    }

    function requestRedeem(uint256 shares_, address owner_) public virtual returns (uint256 escrowShares_) {
        return pool.requestRedeem(shares_, owner_);
    }

    function withdraw(uint256 assets_, address receiver_, address owner_) public virtual returns (uint256 shares_) {
        return pool.withdraw(assets_, receiver_, owner_);
    }


    /******************************************************************************************************************************/
    /*** ERC-20 Functions                                                                                                       ***/
    /******************************************************************************************************************************/

    function approve(address spender_, uint256 amount_) public virtual returns (bool success_) {
        return pool.approve(spender_, amount_);
    }

    function decreaseAllowance(address spender_, uint256 subtractedAmount_) public virtual returns (bool success_) {
        return pool.decreaseAllowance(spender_, subtractedAmount_);
    }

    function increaseAllowance(address spender_, uint256 addedAmount_) public virtual returns (bool success_) {
        return pool.increaseAllowance(spender_, addedAmount_);
    }

    function permit(address owner_, address spender_, uint amount_, uint deadline_, uint8 v_, bytes32 r_, bytes32 s_) public virtual {
        pool.permit(owner_, spender_, amount_, deadline_, v_, r_, s_);
    }

    function transfer(address recipient_, uint256 amount_) public virtual returns (bool success_) {
        return pool.transfer(recipient_, amount_);
    }

    function transferFrom(address owner_, address recipient_, uint256 amount_) public virtual returns (bool success_) {
        return pool.transferFrom(owner_, recipient_, amount_);
    }


}
