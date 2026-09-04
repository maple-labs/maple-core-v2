// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IMockERC20, IPoolManager } from "../../contracts/interfaces/Interfaces.sol";

import { FuzzedSetup } from "./FuzzedSetup.sol";

contract FuzzedSetupFork is FuzzedSetup {

    address aaveStrategyDelegate = makeAddr("aaveStrategyDelegate");
    address skyStrategyDelegate  = makeAddr("skyStrategyDelegate");

    function _setupForkEnvironment() internal {

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

    function _createAssets() internal virtual override {
        fundsAsset = IMockERC20(USDC);
    }

}
