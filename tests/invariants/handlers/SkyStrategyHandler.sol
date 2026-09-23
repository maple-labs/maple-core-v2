// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC20, IERC4626Like, IPSMLike, ISkyStrategy } from "../../../contracts/interfaces/Interfaces.sol";

import { DefiStrategyHandler } from "./DefiStrategyHandler.sol";

// TODO: Add actions for adjusting `tin` and `tout` (but without pausing).
// TODO: Consider testing recognizeLoss() and recoverPosition() on Sky.
contract SkyStrategyHandler is DefiStrategyHandler {

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(string memory handlerName_, address underlyingStrategy_) DefiStrategyHandler(handlerName_, underlyingStrategy_) { }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _currentTotalAssets() internal view override returns (uint256 currentTotalAssets_) {
        address savingsUsds_ = ISkyStrategy(underlyingStrategy).savingsUsds();

        uint256 sUsdsBalance_ = IERC20(savingsUsds_).balanceOf(underlyingStrategy);
        uint256 usdsAmount_   = IERC4626Like(savingsUsds_).previewRedeem(sUsdsBalance_);

        currentTotalAssets_ = _gemForUsds(usdsAmount_);
    }

    function _gemForUsds(uint256 usdsAmount_) internal view returns (uint256 gemAmount_) {
        address psm_  = ISkyStrategy(underlyingStrategy).psm();
        uint256 tout_ = IPSMLike(psm_).tout();

        if (tout_ == type(uint256).max) tout_ = ISkyStrategy(underlyingStrategy).fallbackTout();

        uint256 to18ConversionFactor_ = IPSMLike(psm_).to18ConversionFactor();

        gemAmount_ = (usdsAmount_ * 1e18) / (to18ConversionFactor_ * (1e18 + tout_));
    }

}
