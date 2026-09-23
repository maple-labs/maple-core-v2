// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IPool } from "../../../contracts/interfaces/Interfaces.sol";

import { HandlerBase } from "./HandlerBase.sol";

contract TransferHandler is HandlerBase {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    address[] lps;
    address[] pools;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(string memory handlerName_, address[] memory pools_, address[] memory lps_) HandlerBase(handlerName_) {
        pools = pools_;
        lps   = lps_;
    }

    /**************************************************************************************************************************************/
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function transfer(uint256 seed_) external {
        address pool_      = _selectPool(seed_);
        address sender_    = _selectSender(seed_);
        address recipient_ = _selectRecipient(seed_);

        if (IPool(pool_).balanceOf(sender_) == 0) {
            _recordSkip();
            return;
        }

        uint256 amount_ = _selectAmount(seed_, pool_, sender_);

        vm.prank(sender_);
        IPool(pool_).transfer(recipient_, amount_);
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _selectAmount(uint256 seed_, address pool_, address sender_) internal view returns (uint256 amount_) {
        amount_ = _bound(_randomize(seed_, "amount"), 1, IPool(pool_).balanceOf(sender_));
    }

    function _selectPool(uint256 seed_) internal view returns (address pool_) {
        pool_ = pools[_bound(_randomize(seed_, "pool"), 0, pools.length - 1)];
    }

    function _selectRecipient(uint256 seed_) internal view returns (address recipient_) {
        recipient_ = lps[_bound(_randomize(seed_, "recipient"), 0, lps.length - 1)];
    }

    function _selectSender(uint256 seed_) internal view returns (address sender_) {
        sender_ = lps[_bound(_randomize(seed_, "sender"), 0, lps.length - 1)];
    }

}
