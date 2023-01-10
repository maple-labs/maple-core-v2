// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IERC20 } from "../../../../modules/erc20/contracts/interfaces/IERC20.sol";

contract TransfererBase {

    IERC20 internal token;

    constructor (address token_) {
        token = IERC20(token_);
    }

    function approve(address spender_, uint256 amount_) external returns (bool success_) {
        success_ = token.approve(spender_, amount_);
    }

    function decreaseAllowance(address spender_, uint256 subtractedAmount_) external returns (bool success_) {
        success_ = token.decreaseAllowance(spender_, subtractedAmount_);
    }

    function increaseAllowance(address spender_, uint256 addedAmount_) external returns (bool success_) {
        success_ = token.increaseAllowance(spender_, addedAmount_);
    }

    function permit(address owner_, address spender_, uint256 amount_, uint256 deadline_, uint8 v_, bytes32 r_, bytes32 s_) external {
        token.permit(owner_, spender_, amount_, deadline_, v_, r_, s_);
    }

    function transfer(address recipient_, uint256 amount_) external returns (bool success_) {
        success_ = token.transfer(recipient_, amount_);
    }

    function transferFrom(address owner_, address recipient_, uint256 amount_) external returns (bool success_) {
        success_ = token.transferFrom(owner_, recipient_, amount_);
    }


}
