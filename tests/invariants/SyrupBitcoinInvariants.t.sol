// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { BitcoinRouterHandler }   from "./handlers/BitcoinRouterHandler.sol";
import { BitcoinStrategyHandler } from "./handlers/BitcoinStrategyHandler.sol";
import { DistributionHandler }    from "./handlers/DistributionHandler.sol";

import { BaseInvariants } from "./BaseInvariants.t.sol";

// TODO: Are there any other functions that should be included in the handlers?
// TODO: Think about which amount and ratio of runs:depth should be used during CI (100:500, 50:1000, 25:2000, etc).
contract SyrupBitcoinInvariants is BaseInvariants {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    uint256 lpCount       = 10;
    uint256 strategyCount = 4;

    DistributionHandler distributionHandler;

    /**************************************************************************************************************************************/
    /*** Setup Function                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function setUp() public override {
        // Set up a Syrup BTC pool with multiple strategies.
        initialStrategiesCount = strategyCount;

        _setupBitcoinPool();

        // Create multiple distinct LPs that can interact with the protocol.
        for (uint256 i; i < lpCount; i++) {
            lps.push(makeAddr(string(abi.encode("lp", i))));
        }

        // Create and configure all the handlers.
        bitcoinRouterHandler   = new BitcoinRouterHandler(bitcoinRouter, depositAsset, lps);
        bitcoinStrategyHandler = new BitcoinStrategyHandler(poolManager, depositAsset, strategyManager);

        bitcoinRouterHandler.setSelectorWeight("deposit(uint256)",                     4_500);
        bitcoinRouterHandler.setSelectorWeight("processRedemptionsOnRouter(uint256)",  1_000);
        bitcoinRouterHandler.setSelectorWeight("processRedemptionsOnWm(uint256)",      900);
        bitcoinRouterHandler.setSelectorWeight("processEmptyRedemptionsOnWm(uint256)", 100);
        bitcoinRouterHandler.setSelectorWeight("removeRequests(uint256)",              250);
        bitcoinRouterHandler.setSelectorWeight("removeSharesById(uint256)",            500);
        bitcoinRouterHandler.setSelectorWeight("requestRedeem(uint256)",               2_500);
        bitcoinRouterHandler.setSelectorWeight("setFees(uint256)",                     250);

        bitcoinStrategyHandler.setSelectorWeight("deploy(uint256)",        3_500);
        bitcoinStrategyHandler.setSelectorWeight("reconcile(uint256)",     2_000);
        bitcoinStrategyHandler.setSelectorWeight("schedule(uint256)",      3_500);
        bitcoinStrategyHandler.setSelectorWeight("setDefault(uint256)",    250);
        bitcoinStrategyHandler.setSelectorWeight("setFeeRate(uint256)",    500);
        bitcoinStrategyHandler.setSelectorWeight("setImpairment(uint256)", 250);

        address[] memory targets = new address[](2);
        uint256[] memory weights = new uint256[](2);

        targets[0] = address(bitcoinRouterHandler);
        targets[1] = address(bitcoinStrategyHandler);

        weights[0] = 65;
        weights[1] = 35;

        distributionHandler = new DistributionHandler(targets, weights);

        targetContract(address(distributionHandler));
    }

    /**************************************************************************************************************************************/
    /*** Strategy Invariants                                                                                                            ***/
    /**************************************************************************************************************************************/

    function statefulFuzz_syrupBtc_A_B_C_D_E_F_G() external {
        uint256[] memory wmShares = bitcoinRouterHandler.wmShares();
        uint256 routerShares = bitcoinRouterHandler.routerShares();

        assert_syrupBtc_invariant_A(address(depositAsset), address(assetController));
        assert_syrupBtc_invariant_B(address(depositAsset), address(pool), address(assetController));
        assert_syrupBtc_invariant_C(address(pool));
        assert_syrupBtc_invariant_D(address(pool), routerShares);
        assert_syrupBtc_invariant_E(address(bitcoinRouter), routerShares, wmShares);

        for (uint i; i < strategyCount; i++) {
            address strategy = address(bitcoinStrategyHandler.strategies(i));

            assert_syrupBtc_invariant_F(strategy);
            assert_syrupBtc_invariant_G(strategy);
        }
    }

}
