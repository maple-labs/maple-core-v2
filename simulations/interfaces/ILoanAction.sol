// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IAction } from "./IAction.sol";

interface ILoanAction is IAction {

    function loan() external view returns (address loan_);

}
