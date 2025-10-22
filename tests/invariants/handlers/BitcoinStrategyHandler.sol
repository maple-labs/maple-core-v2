// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IBitcoinStrategy,
    ICompositeToken,
    IMockERC20,
    IPool,
    IPoolManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { console2 as console } from "../../../contracts/Runner.sol";

import { HandlerBase } from "./HandlerBase.sol";


// TODO: Should the max and min values be different?
contract BitcoinStrategyHandler is HandlerBase {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    address strategyManager;
    address poolDelegate;

    uint256 maxYield    = 100e8;
    uint256 maxDuration = 30 days;
    uint256 minDuration = 1 days;

    ICompositeToken poolAsset;
    IMockERC20      depositAsset;
    IPool           pool;

    IBitcoinStrategy[] public strategies;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(IPoolManager pm, IMockERC20 asset, address sm) {
        pool            = IPool(pm.pool());
        poolAsset       = ICompositeToken(pm.asset());
        depositAsset    = asset;
        poolDelegate    = pm.poolDelegate();
        strategyManager = sm;

        for (uint i; i < pm.strategyListLength(); i++) {
            strategies.push(IBitcoinStrategy(pm.strategyList(i)));
        }
    }

    /**************************************************************************************************************************************/
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function deploy(uint256 seed) external {
        console.log("bsh.deploy(%s)", seed);
        numberOfCalls["bsh.deploy"]++;

        uint256 liquidity = poolAsset.balanceOf(address(pool));

        // Skip if nothing can be deployed.
        if (liquidity == 0) {
            return;
        }

        // Skip if no deposits were performed.
        if (pool.totalSupply() == 0) {
            return;
        }

        IBitcoinStrategy strategy = selectStrategy(seed);
        uint256 assets = selectAmount(seed, 1, liquidity);

        vm.prank(strategyManager);
        strategy.deploy(address(depositAsset), assets);
    }

    function reconcile(uint256 seed) external {
        console.log("bsh.reconcile(%s)", seed);
        numberOfCalls["bsh.reconcile"]++;

        IBitcoinStrategy strategy = selectStrategy(seed);

        uint256 aum = strategy.assetsUnderManagement();

        // Skip if nothing can be reconciled.
        if (aum == 0) {
            return;
        }

        uint256 assets = selectAmount(seed, 1, aum);

        vm.startPrank(strategyManager);
        depositAsset.mint(strategyManager, assets);
        depositAsset.approve(address(strategy), assets);
        strategy.reconcile(address(depositAsset), assets);
        vm.stopPrank();
    }

    function schedule(uint256 seed) external {
        console.log("bsh.schedule(%s)", seed);
        numberOfCalls["bsh.schedule"]++;

        IBitcoinStrategy strategy = selectStrategy(seed);

        uint256 yield    = selectAmount(seed, 1, maxYield);
        uint32  deadline = selectDeadline(seed);

        vm.prank(strategyManager);
        strategy.schedule(yield, deadline);
    }

    function setDefault(uint256 seed) external {
        console.log("bsh.setDefault(%s)", seed);
        numberOfCalls["bsh.setDefault"]++;

        IBitcoinStrategy strategy = selectStrategy(seed);

        uint256 assetsToDefault = _bound(seed, 0, strategy.assetsUnderManagement());

        vm.prank(poolDelegate);
        strategy.setDefault(assetsToDefault);
    }

    function setFeeRate(uint256 seed) external {
        console.log("bsh.setFeeRate(%s)", seed);
        numberOfCalls["bsh.setFeeRate"]++;

        IBitcoinStrategy strategy = selectStrategy(seed);

        uint256 feeRate = _bound(seed, 0, 1e6);

        vm.prank(poolDelegate);
        strategy.setFeeRate(feeRate);
    }

    function setImpairment(uint256 seed) external {
        console.log("bsh.setImpairment(%s)", seed);
        numberOfCalls["bsh.setImpairment"]++;

        IBitcoinStrategy strategy = selectStrategy(seed);

        uint256 assetsToImpair = _bound(seed, 0, strategy.assetsUnderManagement());

        vm.prank(poolDelegate);
        strategy.setImpairment(assetsToImpair);
    }

    /**************************************************************************************************************************************/
    /*** Utilities                                                                                                                      ***/
    /**************************************************************************************************************************************/

    function selectAmount(uint256 seed, uint256 from, uint256 to) internal pure returns (uint256 amount) {
        amount = _bound(_randomize(seed, "amount"), from, to);
    }

    function selectDeadline(uint256 seed) internal view returns (uint32 deadline) {
        uint256 from = block.timestamp + minDuration;
        uint256 to   = block.timestamp + maxDuration;

        deadline = uint32(_bound(_randomize(seed, "deadline"), from, to));
    }

    function selectStrategy(uint256 seed) internal view returns (IBitcoinStrategy strategy) {
        uint256 index = _bound(_randomize(seed, "strategy"), 0, strategies.length - 1);

        strategy = strategies[index];
    }

}
