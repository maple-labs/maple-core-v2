// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IMapleLoan } from "../../contracts/interfaces/Interfaces.sol";

import { IAction } from "./IAction.sol";

interface ILoanAction is IAction {

    function loan() external view returns (IMapleLoan loan_);

}
