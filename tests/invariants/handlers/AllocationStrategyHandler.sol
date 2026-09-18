// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IAllocationStrategy } from "../../../contracts/interfaces/Interfaces.sol";

import { HandlerBase } from "./HandlerBase.sol";

// TODO: Add explicit action for flushing yield?
// TODO: Add explicit action for extending/reducing yield duration?
contract AllocationStrategyHandler is HandlerBase {

    /**************************************************************************************************************************************/
    /*** Structs                                                                                                                        ***/
    /**************************************************************************************************************************************/

    struct ManagedWalletInfo {
        address wallet;
        uint256 deployed;
        uint256 returned;
        uint256 lost;
    }

    /**************************************************************************************************************************************/
    /*** Constants                                                                                                                      ***/
    /**************************************************************************************************************************************/

    uint256 constant MAX_DEPLOYMENT_AMOUNT = 1_000_000e6;
    uint256 constant MAX_YIELD_AMOUNT      = 1_000_000e6;
    uint256 constant MIN_YIELD_AMOUNT      = 1;

    uint32 constant MAX_YIELD_DURATION = 30 days;
    uint32 constant MIN_YIELD_DURATION = 1 days;

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    uint256 public totalYield;
    uint256 public totalFees;
    uint256 public totalLosses;

    address[] public managedWallets;

    mapping(address => uint256) public totalDeployedOf;
    mapping(address => uint256) public totalReturnedOf;
    mapping(address => uint256) public totalLostOf;

    IAllocationStrategy public underlyingStrategy;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(
        string    memory handlerName_,
        address   underlyingStrategy_,
        address[] memory managedWallets_
    )
        HandlerBase(handlerName_)
    {
        underlyingStrategy = IAllocationStrategy(underlyingStrategy_);
        managedWallets     = managedWallets_;
    }

    /**************************************************************************************************************************************/
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function deployAssets(uint256 seed_) external {
        address managedWallet_ = _selectManagedWallet(seed_);
        uint256 maxAssets_     = _min(underlyingStrategy.availableToWithdraw(), MAX_DEPLOYMENT_AMOUNT);

        if (maxAssets_ == 0) {
            _recordSkip();
            return;
        }

        uint256 assets_ = _bound(_randomize(seed_, "assets"), 1, maxAssets_);

        deployAssets(address(underlyingStrategy), managedWallet_, assets_);

        totalDeployedOf[managedWallet_] += assets_;
    }

    function returnAssets(uint256 seed_) external {
        ( address managedWallet_, uint256 deployedAssets_ ) = _selectWalletWithDeployedAssets(seed_);

        if (managedWallet_ == address(0)) {
            _recordSkip();
            return;
        }

        uint256 assets_ = _bound(_randomize(seed_, "assets"), 1, deployedAssets_);

        returnAssets(address(underlyingStrategy), managedWallet_, managedWallet_, assets_);

        totalReturnedOf[managedWallet_] += assets_;
    }

    function realizeYield(uint256 seed_) external {
        if (underlyingStrategy.yieldCooldown() != 0) {
            _recordSkip();
            return;
        }

        address managedWallet_ = _selectManagedWallet(seed_);

        uint256 yield_    = _bound(_randomize(seed_, "yield"),    MIN_YIELD_AMOUNT,   MAX_YIELD_AMOUNT);
        uint256 duration_ = _bound(_randomize(seed_, "duration"), MIN_YIELD_DURATION, MAX_YIELD_DURATION);

        uint256 delegateFee_ = yield_ * underlyingStrategy.strategyDelegateFeeRate() / 1e6;
        uint256 protocolFee_ = yield_ * underlyingStrategy.strategyProtocolFeeRate() / 1e6;

        realizeYield(address(underlyingStrategy), managedWallet_, yield_, uint32(duration_));

        totalYield += yield_;
        totalFees  += delegateFee_ + protocolFee_;
    }

    function cancelYield(uint256 seed_) external {
        uint256 unrealizedYield_ = underlyingStrategy.unrealizedYield();

        if (unrealizedYield_ == 0) {
            _recordSkip();
            return;
        }

        uint256 assets_    = _bound(_randomize(seed_, "assets"), 1, unrealizedYield_);
        address recipient_ = _selectManagedWallet(seed_);

        cancelYield(address(underlyingStrategy), assets_, recipient_);

        totalYield -= assets_;
    }

    function recognizeLoss(uint256 seed_) external {
        ( address managedWallet_, uint256 deployedAssets_ ) = _selectWalletWithDeployedAssets(seed_);

        if (managedWallet_ == address(0)) {
            _recordSkip();
            return;
        }

        uint256 assets_ = _bound(_randomize(seed_, "assets"), 1, deployedAssets_);

        recognizeLoss(address(underlyingStrategy), managedWallet_, assets_);

        totalLosses                 += assets_;
        totalLostOf[managedWallet_] += assets_;
    }

    function impair(uint256 seed_) external {
        uint256 maxTotalImpairment_ = 2 * underlyingStrategy.assetsUnderManagement();
        uint256 currentImpairment_  = underlyingStrategy.impairedAssets();

        if (currentImpairment_ >= maxTotalImpairment_) {
            _recordSkip();
            return;
        }

        uint256 assets_ = _bound(seed_, 1, maxTotalImpairment_ - currentImpairment_);

        impairAllocationStrategy(address(underlyingStrategy), assets_);
    }

    function removeImpairment(uint256 seed_) external {
        uint256 impairedAssets_ = underlyingStrategy.impairedAssets();

        if (impairedAssets_ == 0) {
            _recordSkip();
            return;
        }

        uint256 assets_ = _bound(seed_, 1, impairedAssets_);

        removeStrategyImpairment(address(underlyingStrategy), assets_);
    }

    function setStrategyDelegateFeeRate(uint256 seed_) external {
        uint256 currentDelegateFeeRate_ = underlyingStrategy.strategyDelegateFeeRate();
        uint256 currentProtocolFeeRate_ = underlyingStrategy.strategyProtocolFeeRate();

        uint256 feeRate_ = _bound(seed_, 0, 1e6 - currentProtocolFeeRate_);

        if (feeRate_ == currentDelegateFeeRate_) {
            _recordSkip();
            return;
        }

        setStrategyDelegateFeeRate(address(underlyingStrategy), uint32(feeRate_));
    }

    function setStrategyProtocolFeeRate(uint256 seed_) external {
        uint256 currentDelegateFeeRate_ = underlyingStrategy.strategyDelegateFeeRate();
        uint256 currentProtocolFeeRate_ = underlyingStrategy.strategyProtocolFeeRate();

        uint256 feeRate_ = _bound(seed_, 0, 1e6 - currentDelegateFeeRate_);

        if (feeRate_ == currentProtocolFeeRate_) {
            _recordSkip();
            return;
        }

        setStrategyProtocolFeeRate(address(underlyingStrategy), uint32(feeRate_));
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function getManagedWalletInfo() external view returns (ManagedWalletInfo[] memory walletInfo_) {
        walletInfo_ = new ManagedWalletInfo[](managedWallets.length);

        for (uint256 i; i < managedWallets.length; i++) {
            address managedWallet_ = managedWallets[i];

            walletInfo_[i] = ManagedWalletInfo({
                wallet:   managedWallet_,
                deployed: totalDeployedOf[managedWallet_],
                returned: totalReturnedOf[managedWallet_],
                lost:     totalLostOf[managedWallet_]
            });
        }
    }

    function _selectManagedWallet(uint256 seed_) internal view returns (address managedWallet_) {
        managedWallet_ = managedWallets[_bound(seed_, 0, managedWallets.length - 1)];
    }

    function _selectWalletWithDeployedAssets(uint256 seed_) internal view returns (address managedWallet_, uint256 deployedAssets_) {
        uint256 count_;

        address[] memory candidates_ = new address[](managedWallets.length);

        for (uint256 i; i < managedWallets.length; ++i) {
            if (underlyingStrategy.deployedAssetsOf(managedWallets[i]) == 0) continue;

            candidates_[count_++] = managedWallets[i];
        }

        if (count_ == 0) return (address(0), 0);

        managedWallet_  = candidates_[_bound(seed_, 0, count_ - 1)];
        deployedAssets_ = underlyingStrategy.deployedAssetsOf(managedWallet_);
    }

    // NOTE: Does nothing since yield and fees are already accounted for.
    function _syncYieldAndFees() public {}

}
