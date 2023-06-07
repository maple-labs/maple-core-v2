// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { ILiquidator } from "../../../contracts/interfaces/Interfaces.sol";

contract KeeperBase {

    ILiquidator liquidator;

    constructor (address liquidator_) {
        liquidator = ILiquidator(liquidator_);
    }

    function liquidatePortion(uint256 swapAmount_, uint256 maxReturnAmount_, bytes calldata data_) public virtual {
        liquidator.liquidatePortion(swapAmount_, maxReturnAmount_, data_);
    }

}
