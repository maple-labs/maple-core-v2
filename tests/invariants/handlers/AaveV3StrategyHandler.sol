// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IAaveV3Strategy, IERC20 } from "../../../contracts/interfaces/Interfaces.sol";

import { DefiStrategyHandler } from "./DefiStrategyHandler.sol";

// TODO: Consider testing recognizeLoss() and recoverPosition() on Aave.
contract AaveV3StrategyHandler is DefiStrategyHandler {

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(string memory handlerName_, address underlyingStrategy_) DefiStrategyHandler(handlerName_, underlyingStrategy_) { }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _currentTotalAssets() internal view override returns (uint256 currentTotalAssets_) {
        currentTotalAssets_ = IERC20(IAaveV3Strategy(underlyingStrategy).aaveToken()).balanceOf(underlyingStrategy);
    }

}
