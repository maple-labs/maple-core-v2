// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IERC20Like, ILoanManager, IMapleLoan } from "../../contracts/interfaces/Interfaces.sol";

import { Action } from "./Action.sol";

contract LiquidationAction is Action {

    address public loan;
    address public loanManager;

    uint256 public liquidationPrice;

    constructor(
        uint256 timestamp_,
        string memory description_,
        address loanManager_,
        address loan_,
        uint256 liquidationPrice_
    )
        Action(timestamp_, description_)
    {
        loan             = loan_;
        liquidationPrice = liquidationPrice_;
        loanManager      = loanManager_;
    }

    function act() external override {
        ( , , , , , address liquidator_ ) = ILoanManager(loanManager).liquidationInfo(loan);

        IERC20Like collateralAsset = IERC20Like(IMapleLoan(loan).collateralAsset());
        IERC20Like fundsAsset      = IERC20Like(IMapleLoan(loan).fundsAsset());

        uint256 recoveredAmount =
            collateralAsset.balanceOf(liquidator_)
                * liquidationPrice                  // Convert from `fromAsset` value.
                * 10 ** fundsAsset.decimals()       // Convert to `toAsset` decimal precision.
                / 10 ** collateralAsset.decimals()  // Convert from `fromAsset` decimal precision.
                / 1e6;                              // Divide basis points for slippage.

        fundsAsset.mint(liquidator_, recoveredAmount);
        collateralAsset.burn(liquidator_, collateralAsset.balanceOf(liquidator_));

        vm.store(liquidator_, bytes32(uint256(3)), bytes32(uint256(0)));  // Set `collateralRemaining` to zero.
    }

}

interface ILiquidator {
    function collateralRemaining() external view returns (uint256);
}
