// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC20,
    IERC4626Like,
    IInvariantTest,
    IPSMLike,
    IStrategyLike
} from "../../../contracts/interfaces/Interfaces.sol";

import { console2 as console } from "../../../contracts/Runner.sol";

import { HandlerBase } from "./HandlerBase.sol";

contract StrategyHandler is HandlerBase {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    address[] public strategies;

    uint256 public maximumFunding;
    uint256 public strategyCount;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(address aaveStrategy_, address skyStrategy_) {
        strategies.push(aaveStrategy_);
        strategies.push(skyStrategy_);

        maximumFunding = 500_000e6;
        strategyCount  = strategies.length;

        testContract = IInvariantTest(msg.sender);
    }

    /**************************************************************************************************************************************/
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function fundStrategy(uint256 seed_) external useTimestamps {
        console.log("strategyHandler.fundStrategy(%s)", seed_);

        numberOfCalls["fundStrategy"]++;

        address strategy_ = _selectStrategy({ seed_: seed_, selectActive_: true, selectImpaired_: false, selectInactive_: false });

        if (strategy_ == address(0)) return;

        address asset_ = IStrategyLike(strategy_).fundsAsset();
        address pool_  = IStrategyLike(strategy_).pool();

        uint256 liquidity_ = IERC20(asset_).balanceOf(pool_);

        if (liquidity_ == 0) return;
        if (liquidity_ > maximumFunding) liquidity_ = maximumFunding;

        uint256 assets_ = _bound(seed_, 1, liquidity_);

        fundStrategy(strategy_, assets_);
    }

    function withdrawFromStrategy(uint256 seed_) external useTimestamps {
        console.log("strategyHandler.withdrawFromStrategy(%s)", seed_);

        numberOfCalls["withdrawFromStrategy"]++;

        address strategy_ = _selectStrategy({ seed_: seed_, selectActive_: true, selectImpaired_: true, selectInactive_: true });

        if (strategy_ == address(0)) return;

        uint256 totalAssets_ = _currentTotalAssets(strategy_);
        uint256 accruedFees_ = _currentAccruedFees(strategy_, totalAssets_);

        uint256 available_ = totalAssets_ - accruedFees_;

        if (available_ <= 1) return;

        uint256 assets_ = _bound(seed_, 1, available_ - 1);

        withdrawFromStrategy(strategy_, assets_);
    }

    function setStrategyFeeRate(uint256 seed_) external useTimestamps {
        console.log("strategyHandler.setStrategyFeeRate(%s)", seed_);

        numberOfCalls["setStrategyFeeRate"]++;

        address strategy_ = _selectStrategy({ seed_: seed_, selectActive_: true, selectImpaired_: false, selectInactive_: false });

        if (strategy_ == address(0)) return;

        uint256 feeRate_ = _bound(seed_, 0, 1e6);

        setStrategyFeeRate(strategy_, feeRate_);
    }

    function impairStrategy(uint256 seed_) external useTimestamps {
        console.log("strategyHandler.impairStrategy(%s)", seed_);

        numberOfCalls["impairStrategy"]++;

        address strategy_ = _selectStrategy({ seed_: seed_, selectActive_: true, selectImpaired_: false, selectInactive_: true });

        if (strategy_ == address(0)) return;

        impairStrategy(strategy_);
    }

    function deactivateStrategy(uint256 seed_) external useTimestamps {
        console.log("strategyHandler.deactivateStrategy(%s)", seed_);

        numberOfCalls["deactivateStrategy"]++;

        address strategy_ = _selectStrategy({ seed_: seed_, selectActive_: true, selectImpaired_: true, selectInactive_: false });

        if (strategy_ == address(0)) return;

        deactivateStrategy(strategy_);
    }

    function reactivateStrategy(uint256 seed_) external useTimestamps {
        console.log("strategyHandler.reactivateStrategy(%s)", seed_);

        numberOfCalls["reactivateStrategy"]++;

        address strategy_ = _selectStrategy({ seed_: seed_, selectActive_: false, selectImpaired_: true, selectInactive_: true });

        if (strategy_ == address(0)) return;

        bool updateAccounting_ = seed_ % 2 == 0 ? true : false;

        reactivateStrategy(strategy_, updateAccounting_);
    }

    function warp(uint256 seed_) external useTimestamps {
        console.log("strategyHandler.warp(%s)", seed_);

        numberOfCalls["warp"]++;

        uint256 timespan_ = _bound(seed_, 1 hours, 7 days);

        vm.warp(block.timestamp + timespan_);
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _currentAccruedFees(address strategy_, uint256 currentTotalAssets_) internal view returns (uint256 currentAccruedFees_) {
        IStrategyLike strategy = IStrategyLike(strategy_);

        uint256 strategyFeeRate_         = strategy.strategyFeeRate();
        uint256 lastRecordedTotalAssets_ = strategy.lastRecordedTotalAssets();

        if (strategyFeeRate_ == 0) {
            return 0;
        }

        if (currentTotalAssets_ <= lastRecordedTotalAssets_) {
            return 0;
        }

        uint256 yieldAccrued_ = currentTotalAssets_ - lastRecordedTotalAssets_;

        currentAccruedFees_ = yieldAccrued_ * strategyFeeRate_ / 1e6;
    }

    function _currentTotalAssets(address strategy_) internal view returns (uint256 currentTotalAssets) {
        IStrategyLike strategy = IStrategyLike(strategy_);

        bytes memory t = bytes(strategy.STRATEGY_TYPE());

        if (keccak256(t) == keccak256("BASIC")) {
            IERC4626Like strategyVault = IERC4626Like(strategy.strategyVault());
            uint256 currentTotalShares = strategyVault.balanceOf(address(strategy));

            currentTotalAssets = IERC4626Like(strategyVault).previewRedeem(currentTotalShares);
        }

        else if (keccak256(t) == keccak256("AAVE")) {
            IERC20 aaveToken = IERC20(strategy.aaveToken());

            currentTotalAssets = aaveToken.balanceOf(address(strategy));
        }

        else if (keccak256(t) == keccak256("SKY")) {
            IERC4626Like savingsUsds = IERC4626Like(strategy.savingsUsds());
            IPSMLike psm             = IPSMLike(strategy.psm());

            uint256 psmTout          = psm.tout();
            uint256 conversionFactor = psm.to18ConversionFactor();
            uint256 usdsAmount       = savingsUsds.previewRedeem(savingsUsds.balanceOf(address(strategy)));

            currentTotalAssets = (usdsAmount * 1e18) / (conversionFactor * (1e18 + psmTout));
        }

        else {
            require(false, "INVALID_STRATEGY");
        }
    }

    function _selectStrategy(
        uint256 seed_,
        bool selectActive_,
        bool selectImpaired_,
        bool selectInactive_
    )
        internal view returns (address strategy_)
    {
        uint256 index_;
        uint256 length_;

        for (uint256 i; i < strategies.length; ++i) {
            if (selectActive_   && IStrategyLike(strategies[i]).strategyState() == 0) length_++;
            if (selectImpaired_ && IStrategyLike(strategies[i]).strategyState() == 1) length_++;
            if (selectInactive_ && IStrategyLike(strategies[i]).strategyState() == 2) length_++;
        }

        address[] memory strategies_ = new address[](length_);

        for (uint256 i; i < strategies.length; ++i) {
            if (selectActive_   && IStrategyLike(strategies[i]).strategyState() == 0) strategies_[index_++] = strategies[i];
            if (selectImpaired_ && IStrategyLike(strategies[i]).strategyState() == 1) strategies_[index_++] = strategies[i];
            if (selectInactive_ && IStrategyLike(strategies[i]).strategyState() == 2) strategies_[index_++] = strategies[i];
        }

        if (strategies_.length == 0) return address(0);

        strategy_ = strategies_[_bound(seed_, 0, strategies_.length - 1)];
    }

}
