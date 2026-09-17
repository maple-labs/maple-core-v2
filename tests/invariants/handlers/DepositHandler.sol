// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IPool } from "../../../contracts/interfaces/Interfaces.sol";

import { HandlerBase } from "./HandlerBase.sol";

contract DepositHandler is HandlerBase {

    /**************************************************************************************************************************************/
    /*** Constants                                                                                                                      ***/
    /**************************************************************************************************************************************/

    uint256 constant MAXIMUM_DEPOSIT_AMOUNT = 1_000_000e6;
    uint256 constant MAXIMUM_MINT_AMOUNT    = 500_000e6;
    uint256 constant ROUNDING_BUFFER        = 100;

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    address asset;

    address[] lps;
    address[] pools;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(
        string    memory handlerName_,
        address[] memory pools_,
        address[] memory lps_
    )
        HandlerBase(handlerName_)
    {
        pools = pools_;
        lps   = lps_;

        asset = IPool(pools_[0]).asset();

        for (uint256 i = 1; i < pools_.length; i++) {
            require(IPool(pools_[i]).asset() == asset, "DH:INVALID_ASSET");
        }
    }

    /**************************************************************************************************************************************/
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function deposit(uint256 seed_) external {
        address lp_     = _selectLp(seed_);
        address pool_   = _selectPool(seed_);
        uint256 assets_ = _selectAssets(seed_);

        erc20_mint(asset, lp_, assets_);
        erc20_approve(asset, lp_, pool_, assets_);

        vm.prank(lp_);
        IPool(pool_).deposit(assets_, lp_);
    }

    function mint(uint256 seed_) external {
        address lp_     = _selectLp(seed_);
        address pool_   = _selectPool(seed_);
        uint256 shares_ = _selectShares(seed_);
        uint256 assets_ = _convertToAssets(pool_, shares_);

        erc20_mint(asset, lp_, assets_);
        erc20_approve(asset, lp_, pool_, assets_);

        vm.prank(lp_);
        IPool(pool_).mint(shares_, lp_);
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _convertToAssets(address pool_, uint256 shares_) internal view returns (uint256 assets_) {
        uint256 totalSupply_ = IPool(pool_).totalSupply();

        assets_ = totalSupply_ == 0 ? shares_ : IPool(pool_).totalAssets() * shares_ / totalSupply_ + ROUNDING_BUFFER;
    }

    function _selectAssets(uint256 seed_) internal pure returns (uint256 assets_) {
        assets_ = _bound(_randomize(seed_, "assets"), 100, MAXIMUM_DEPOSIT_AMOUNT);
    }

    function _selectLp(uint256 seed_) internal view returns (address lp_) {
        lp_ = lps[_bound(_randomize(seed_, "lp"), 0, lps.length - 1)];
    }

    function _selectPool(uint256 seed_) internal view returns (address pool_) {
        pool_ = pools[_bound(_randomize(seed_, "pool"), 0, pools.length - 1)];
    }

    function _selectShares(uint256 seed_) internal pure returns (uint256 shares_) {
        shares_ = _bound(_randomize(seed_, "shares"), 10, MAXIMUM_MINT_AMOUNT);
    }

}
