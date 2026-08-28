// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IMockERC20,
    IPool,
    IPoolManager,
    IUnderlyingStrategyLike
} from "../../contracts/interfaces/Interfaces.sol";

import { FuzzedSetup } from "./FuzzedSetup.sol";

contract FuzzedSetupFork is FuzzedSetup {

    address aaveStrategyDelegate = makeAddr("aaveStrategyDelegate");
    address skyStrategyDelegate  = makeAddr("skyStrategyDelegate");

    function setUp() public virtual override {

        /**********************************************************************************************************************************/
        /*** Deploy the protocol, the shared allocation strategy and both pools against the forked funds asset                          ***/
        /**********************************************************************************************************************************/

        vm.createSelectFork(vm.envString("ETH_RPC_URL"), MAINNET_FORK_BLOCK);

        // Aave and Sky are funded out of pool liquidity, which has to stay within the real supply caps of those markets.
        lpDeposit = 5_000_000e6;

        super.setUp();

        /**********************************************************************************************************************************/
        /*** Deploy the yield strategies that will be shared by both pools                                                              ***/
        /**********************************************************************************************************************************/

        ( aaveStrategyManagerShared, aaveUnderlyingStrategyShared ) = _deployAaveV3Strategy({
            strategyDelegate_:            aaveStrategyDelegate,
            aaveToken_:                   AAVE_USDC,
            useVirtualUnderlyingBalance_: true,
            strategyDelegateFeeRate_:     STRATEGY_DELEGATE_FEE_RATE,
            strategyProtocolFeeRate_:     STRATEGY_PROTOCOL_FEE_RATE,
            strategyLiquidityCap_:        type(uint256).max,
            bootstrapMint_:               0
        });

        ( skyStrategyManagerShared, skyUnderlyingStrategyShared ) = _deploySkyStrategy({
            strategyDelegate_:        skyStrategyDelegate,
            fundsAsset_:              address(fundsAsset),
            savingsUsds_:             SAVINGS_USDS,
            psm_:                     USDS_LITE_PSM,
            strategyDelegateFeeRate_: STRATEGY_DELEGATE_FEE_RATE,
            strategyProtocolFeeRate_: STRATEGY_PROTOCOL_FEE_RATE,
            strategyLiquidityCap_:    type(uint256).max,
            bootstrapMint_:           0
        });

        _addSharedStrategyManager(poolManager1, aaveStrategyManagerShared);
        _addSharedStrategyManager(poolManager1, skyStrategyManagerShared);

        _addSharedStrategyManager(poolManager2, aaveStrategyManagerShared);
        _addSharedStrategyManager(poolManager2, skyStrategyManagerShared);
    }

    function _addSharedStrategyManager(address poolManager_, address strategyManager_) internal {
        vm.startPrank(governor);
        IPoolManager(poolManager_).addStrategyManager(strategyManager_);
        IPoolManager(poolManager_).setStrategyCap(strategyManager_, type(uint256).max);
        vm.stopPrank();
    }

    // Underlying _createAssets deploys mock tokens. On a fork we want real USDC so we can interact with Aave and Sky
    function _createAssets() internal override {
        fundsAsset = IMockERC20(USDC);
    }

    /**************************************************************************************************************************************/
    /*** Shared Strategy Fuzz Helpers                                                                                                   ***/
    /**************************************************************************************************************************************/

    function expectedFees(address strategy, uint256 grossAssets, uint256 lastRecordedTotalAssets)
        internal view returns (uint256 delegateFee, uint256 protocolFee)
    {
        if (grossAssets <= lastRecordedTotalAssets) return (0, 0);

        uint256 yieldAccrued = grossAssets - lastRecordedTotalAssets;

        delegateFee = mulDivDown(yieldAccrued, IUnderlyingStrategyLike(strategy).strategyDelegateFeeRate(), HUNDRED_PERCENT);
        protocolFee = mulDivDown(yieldAccrued, IUnderlyingStrategyLike(strategy).strategyProtocolFeeRate(), HUNDRED_PERCENT);
    }

    // Maximum drift, in assets, between `assetsOf` read back after an action and `previousAssets + assetsMoved`.
    //
    // `MapleStrategyManager` divides three times between the two, and the truncations do not cancel:
    //   1. `_convertToAssets` for `assetsOf` at the snapshot  - truncates under one asset
    //   2. `_convertToShares` when minting                    - truncates under one SHARE
    //   3. `_convertToAssets` for `assetsOf` on the read back - truncates under one asset
    //
    // 2 dominates, because a truncated share is worth `totalAssets / totalShares` assets rather than one.
    //
    // Example: 100 shares over 500 assets, so a share is worth 5 assets. A pool holding 30 shares funds 7 assets.
    //   1. assetsOf = floor(30 * 500 / 100) = 150
    //   2. minted   = floor(7 * 100 / 500)  = floor(1.4)    = 1 share, discarding 0.4 shares worth 2 assets
    //   3. assetsOf = floor(31 * 507 / 101) = floor(155.61) = 155
    //
    //   expected = 150 + 7 = 157
    //   actual             = 155
    //   drift              =   2
    //
    // Worst case is a share lost to 2 plus an asset to 3, so the bound is one share price plus one. 1 works the other way,
    // lowering the expected value, so the drift is one directional: `assetsOf` is never above what the test expects.
    function maxShareConversionError(uint256 totalAssets, uint256 totalShares) internal pure returns (uint256 maxError) {
        maxError = mulDivDown(totalAssets, 1, totalShares) + 1;
    }

    function mulDivDown(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        result = denominator == 0 ? 0 : x * y / denominator;
    }

    function mulDivUp(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        result = denominator == 0 ? 0 : (x * y + denominator - 1) / denominator;
    }

    function min(uint256 x, uint256 y) internal pure returns (uint256 minimum) {
        minimum = x < y ? x : y;
    }

}
