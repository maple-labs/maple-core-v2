// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { stdStorage, StdStorage } from "../../modules/forge-std/src/Test.sol";

import {
    IAaveStrategy,
    IGlobals,
    IMapleProxyFactory,
    IMockERC20,
    INonTransparentProxy,
    IPool,
    IPoolManager,
    IPSMLike,
    ISkyStrategy,
    IWithdrawalManagerQueue as IWithdrawalManager
} from "../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

contract StrategyScenarios is TestBaseWithAssertions {

    using stdStorage for StdStorage;

    uint256 constant USDC_PRECISION    = 1e6;   // USDC has 6 decimals.
    uint256 constant USDS_PRECISION    = 1e18;  // USDS has 18 decimals.
    uint256 constant CONVERSION_FACTOR = 1e12;  // Difference in precision between USDC and USDS.

    address lp_0 = makeAddr("lp_0");
    address lp_1 = makeAddr("lp_1");
    address lp_2 = makeAddr("lp_2");

    // TODO: Check if these values are realistic.
    uint256 psmTin  = 3e16;
    uint256 psmTout = 5e16;

    uint256 liquidity  = 1_000_000e6;
    uint256 strategyIn = 750_000e6;

    IAaveStrategy aaveStrategy;
    ISkyStrategy  skyStrategy;

    /**************************************************************************************************************************************/
    /*** Setup                                                                                                                          ***/
    /**************************************************************************************************************************************/

    function setUp() public virtual override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 21073000);

        fundsAsset = IMockERC20(USDC);

        _createAccounts();
        _createGlobals();
        _setTreasury();
        _createFactories();

        poolManager = IPoolManager(deployPoolWithQueue({
            poolDelegate_:           address(poolDelegate),
            deployer_:               address(deployer),
            poolManagerFactory_:     address(poolManagerFactory),
            queueWMFactory_:         address(queueWMFactory),
            strategyFactories_:      new address[](0),
            strategyDeploymentData_: new bytes[](0),
            fundsAsset_:             USDC,
            poolPermissionManager_:  address(poolPermissionManager),
            name_:                   "Pool",
            symbol_:                 "MP",
            configParams_:           [type(uint256).max, 0, 0, 0]
        }));

        vm.startPrank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", SAVINGS_USDS,  true);
        globals.setValidInstanceOf("STRATEGY_VAULT", AAVE_USDC,     true);
        globals.setValidInstanceOf("PSM",            USDS_LITE_PSM, true);
        vm.stopPrank();

        vm.prank(governor);
        poolManager.addStrategy(address(skyStrategyFactory), abi.encode(SAVINGS_USDS, USDS_LITE_PSM));

        vm.prank(governor);
        poolManager.addStrategy(address(aaveStrategyFactory), abi.encode(AAVE_USDC));

        pool         = IPool(poolManager.pool());
        queueWM      = IWithdrawalManager(poolManager.withdrawalManager());
        skyStrategy  = ISkyStrategy(poolManager.strategyList(0));
        aaveStrategy = IAaveStrategy(poolManager.strategyList(1));

        activatePool(address(poolManager), HUNDRED_PERCENT);
        openPool(address(poolManager));

        start = block.timestamp;
    }

    /**************************************************************************************************************************************/
    /*** Utilities                                                                                                                      ***/
    /**************************************************************************************************************************************/

    function reduceByPsmFees(uint256 usdcIn_, uint256 psmTin_, uint256 psmTout_) internal pure returns (uint256) {
        // Convert USDC to USDS and reduce it by the PSM input fee (if any).
        uint256 usdsOut_ = (usdcIn_ * CONVERSION_FACTOR) - ((usdcIn_ * psmTin_) / USDC_PRECISION);

        // NOTE: Simplifies `_gemForUsds` function in the Sky Strategy
        // Convert USDS to USDC and reduce it by the PSM output fee (if any).
        uint256 usdcOut_ = usdsOut_ * USDC_PRECISION / (USDS_PRECISION + psmTout_);

        return usdcOut_;
    }

    function setPsmFees(uint256 tin, uint256 tout) internal {
        address psm = IPSMLike(USDS_LITE_PSM).psm();

        stdstore
            .target(psm)
            .sig("wards(address)")
            .with_key(address(this))
            .checked_write(1);

        IPSMLike(psm).file("tin",  tin);
        IPSMLike(psm).file("tout", tout);
    }

    /**************************************************************************************************************************************/
    /*** Strategy Scenarios                                                                                                              **/
    /**************************************************************************************************************************************/

    function testFork_strategy_scenario1() external {
        uint256 assetsIn_1 = 490_000e6;
        uint256 assetsIn_2 = 500_000e6;

        // Deposit funds.
        deposit(address(pool), lp_0, liquidity);

        uint256 shares_1 = deposit(address(pool), lp_1, assetsIn_1);
        uint256 shares_2 = deposit(address(pool), lp_2, assetsIn_2);

        uint256 totalAssets = liquidity + assetsIn_1 + assetsIn_2;

        assertEq(fundsAsset.balanceOf(lp_1), 0);
        assertEq(fundsAsset.balanceOf(lp_2), 0);

        assertEq(pool.balanceOf(lp_1), shares_1);
        assertEq(pool.balanceOf(lp_2), shares_2);

        assertEq(pool.totalAssets(), totalAssets);

        assertEq(skyStrategy.assetsUnderManagement(), 0);

        // Fund the Sky strategy.
        fundStrategy(address(skyStrategy), strategyIn);

        assertApproxEqAbs(pool.totalAssets(), totalAssets, 1);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(), strategyIn, 1);

        // Accrue yield.
        vm.warp(start + 35 days);

        uint256 yield = skyStrategy.assetsUnderManagement() - skyStrategy.lastRecordedTotalAssets();
        uint256 aum   = strategyIn + yield;

        totalAssets += yield;

        assertApproxEqAbs(pool.totalAssets(), totalAssets, 1);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(), aum, 1);

        // 1st user withdraws.
        uint256 assetsOut_1 = totalAssets * shares_1 / pool.totalSupply();

        requestRedeem(address(pool), lp_1, shares_1);
        processRedemptions(address(pool), shares_1);

        totalAssets -= assetsOut_1;

        assertEq(fundsAsset.balanceOf(lp_1), assetsOut_1);
        assertEq(fundsAsset.balanceOf(lp_2), 0);

        assertEq(pool.balanceOf(lp_1), 0);
        assertEq(pool.balanceOf(lp_2), shares_2);

        assertApproxEqAbs(pool.totalAssets(), totalAssets, 1);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(), aum, 1);

        // Set PSM fees.
        setPsmFees(psmTin, psmTout);

        uint256 netAum  = reduceByPsmFees(strategyIn + yield, 0, psmTout);
        uint256 psmFees = strategyIn + yield - netAum;

        totalAssets -= psmFees;

        assertApproxEqAbs(pool.totalAssets(), totalAssets, 1);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(), netAum, 1);

        assertLt(netAum, aum);

        // 2nd user withdraws less.
        uint256 assetsOut_2 = totalAssets * shares_2 / pool.totalSupply();

        requestRedeem(address(pool), lp_2, shares_2);
        processRedemptions(address(pool), shares_2);

        totalAssets -= assetsOut_2;

        assertApproxEqAbs(fundsAsset.balanceOf(lp_1), assetsOut_1, 1);
        assertApproxEqAbs(fundsAsset.balanceOf(lp_2), assetsOut_2, 1);

        assertEq(pool.balanceOf(lp_1), 0);
        assertEq(pool.balanceOf(lp_2), 0);

        assertApproxEqAbs(pool.totalAssets(), totalAssets, 1);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(), netAum, 1);

        assertLt(assetsIn_1,  assetsIn_2);
        assertGt(assetsOut_1, assetsOut_2);
    }

    function testFork_strategy_scenario2() external {
        uint256 assetsIn_1 = 490_000e6;
        uint256 assetsIn_2 = 500_000e6;

        // Deposit funds.
        deposit(address(pool), lp_0, liquidity);

        uint256 shares_1 = deposit(address(pool), lp_1, assetsIn_1);
        uint256 shares_2 = deposit(address(pool), lp_2, assetsIn_2);

        uint256 totalAssets = liquidity + assetsIn_1 + assetsIn_2;

        assertEq(fundsAsset.balanceOf(lp_1), 0);
        assertEq(fundsAsset.balanceOf(lp_2), 0);

        assertEq(pool.balanceOf(lp_1), shares_1);
        assertEq(pool.balanceOf(lp_2), shares_2);

        assertEq(pool.totalAssets(), totalAssets);

        assertEq(skyStrategy.assetsUnderManagement(), 0);

        // Fund the Sky strategy.
        fundStrategy(address(skyStrategy), strategyIn);

        assertApproxEqAbs(pool.totalAssets(), totalAssets, 1);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(), strategyIn, 1);

        // Accrue yield.
        vm.warp(start + 28 days);

        uint256 yield = skyStrategy.assetsUnderManagement() - skyStrategy.lastRecordedTotalAssets();
        uint256 aum   = strategyIn + yield;

        totalAssets += yield;

        assertApproxEqAbs(pool.totalAssets(), totalAssets, 1);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(), aum, 1);

        // 1st user withdraws.
        uint256 assetsOut_1 = totalAssets * shares_1 / pool.totalSupply();

        requestRedeem(address(pool), lp_1, shares_1);
        processRedemptions(address(pool), shares_1);

        totalAssets -= assetsOut_1;

        assertEq(fundsAsset.balanceOf(lp_1), assetsOut_1);
        assertEq(fundsAsset.balanceOf(lp_2), 0);

        assertEq(pool.balanceOf(lp_1), 0);
        assertEq(pool.balanceOf(lp_2), shares_2);

        assertApproxEqAbs(pool.totalAssets(), totalAssets, 1);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(), aum, 1);

        // Impair strategy.
        impairStrategy(address(skyStrategy));

        assertApproxEqAbs(pool.totalAssets(),      totalAssets, 1);
        assertApproxEqAbs(pool.unrealizedLosses(), aum, 1);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(), aum, 1);
        assertApproxEqAbs(skyStrategy.unrealizedLosses(),      aum, 1);

        // 2nd user withdraws less.
        uint256 assetsOut_2 = (totalAssets - aum) * shares_2 / pool.totalSupply();

        requestRedeem(address(pool), lp_2, shares_2);
        processRedemptions(address(pool), shares_2);

        totalAssets -= assetsOut_2;

        assertApproxEqAbs(fundsAsset.balanceOf(lp_1), assetsOut_1, 1);
        assertApproxEqAbs(fundsAsset.balanceOf(lp_2), assetsOut_2, 1);

        assertEq(pool.balanceOf(lp_1), 0);
        assertEq(pool.balanceOf(lp_2), 0);

        assertApproxEqAbs(pool.totalAssets(),      totalAssets, 1);
        assertApproxEqAbs(pool.unrealizedLosses(), aum, 1);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(), aum, 1);
        assertApproxEqAbs(skyStrategy.unrealizedLosses(),      aum, 1);

        assertLt(assetsIn_1,  assetsIn_2);
        assertGt(assetsOut_1, assetsOut_2);
    }

    function testFork_strategy_scenario3() external {
        uint256 assetsIn_1 = 500_000e6;
        uint256 assetsIn_2 = 450_000e6;

        // Deposit funds.
        deposit(address(pool), lp_0, liquidity);

        uint256 shares_1 = deposit(address(pool), lp_1, assetsIn_1);
        uint256 shares_2 = deposit(address(pool), lp_2, assetsIn_2);

        uint256 totalAssets = liquidity + assetsIn_1 + assetsIn_2;

        assertEq(fundsAsset.balanceOf(lp_1), 0);
        assertEq(fundsAsset.balanceOf(lp_2), 0);

        assertEq(pool.balanceOf(lp_1), shares_1);
        assertEq(pool.balanceOf(lp_2), shares_2);

        assertEq(pool.totalAssets(), totalAssets);

        assertEq(skyStrategy.assetsUnderManagement(), 0);

        // Fund the Sky strategy.
        fundStrategy(address(skyStrategy), strategyIn);

        assertApproxEqAbs(pool.totalAssets(), totalAssets, 1);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(), strategyIn, 1);

        // Accrue yield.
        vm.warp(start + 14 days);

        uint256 yield = skyStrategy.assetsUnderManagement() - skyStrategy.lastRecordedTotalAssets();
        uint256 aum   = strategyIn + yield;

        totalAssets += yield;

        assertApproxEqAbs(pool.totalAssets(), totalAssets, 1);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(), aum, 1);

        // Deactivate strategy.
        deactivateStrategy(address(skyStrategy));

        totalAssets -= aum;

        assertApproxEqAbs(pool.totalAssets(), totalAssets, 1);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(), 0, 1);

        // 1st user withdraws with losses.
        uint256 assetsOut_1 = totalAssets * shares_1 / pool.totalSupply();

        requestRedeem(address(pool), lp_1, shares_1);
        processRedemptions(address(pool), shares_1);

        totalAssets -= assetsOut_1;

        assertEq(fundsAsset.balanceOf(lp_1), assetsOut_1);
        assertEq(fundsAsset.balanceOf(lp_2), 0);

        assertEq(pool.balanceOf(lp_1), 0);
        assertEq(pool.balanceOf(lp_2), shares_2);

        assertApproxEqAbs(pool.totalAssets(), totalAssets, 1);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(), 0, 1);

        // Reactivate strategy.
        reactivateStrategy(address(skyStrategy));

        totalAssets += aum;

        assertApproxEqAbs(pool.totalAssets(), totalAssets, 1);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(), aum, 1);

        // 2nd user withdraws without losses.
        uint256 assetsOut_2 = totalAssets * shares_2 / pool.totalSupply();

        requestRedeem(address(pool), lp_2, shares_2);
        processRedemptions(address(pool), shares_2);

        totalAssets -= assetsOut_2;

        assertApproxEqAbs(fundsAsset.balanceOf(lp_1), assetsOut_1, 1);
        assertApproxEqAbs(fundsAsset.balanceOf(lp_2), assetsOut_2, 1);

        assertEq(pool.balanceOf(lp_1), 0);
        assertEq(pool.balanceOf(lp_2), 0);

        assertApproxEqAbs(pool.totalAssets(), totalAssets, 1);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(), aum, 1);

        assertGt(assetsIn_1,  assetsIn_2);
        assertLt(assetsOut_1, assetsOut_2);
    }

    function testFork_strategy_scenario4() external {
        // Deposit funds.
        deposit(address(pool), lp_0, 1_000_000e6);
        deposit(address(pool), lp_1, 450_000e6);
        deposit(address(pool), lp_2, 500_000e6);

        uint256 totalAssets = 1_000_000e6 + 450_000e6 + 500_000e6;
        uint256 totalSupply = totalAssets;

        assertEq(fundsAsset.balanceOf(lp_1), 0);
        assertEq(fundsAsset.balanceOf(lp_2), 0);

        assertEq(pool.balanceOf(lp_1), 450_000e6);
        assertEq(pool.balanceOf(lp_2), 500_000e6);

        assertEq(pool.totalAssets(), totalAssets);

        assertEq(skyStrategy.assetsUnderManagement(),  0);
        assertEq(aaveStrategy.assetsUnderManagement(), 0);

        // Fund both Aave and Sky strategies.
        fundStrategy(address(skyStrategy),  100_000e6);
        fundStrategy(address(aaveStrategy), 125_000e6);

        assertApproxEqAbs(pool.totalAssets(), totalAssets, 1);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),  100_000e6, 1);
        assertApproxEqAbs(aaveStrategy.assetsUnderManagement(), 125_000e6, 1);

        // Accrue yield.
        vm.warp(start + 15 days);

        uint256 skyYield  = skyStrategy.assetsUnderManagement() - skyStrategy.lastRecordedTotalAssets();
        uint256 aaveYield = aaveStrategy.assetsUnderManagement() - aaveStrategy.lastRecordedTotalAssets();

        totalAssets = 1_000_000e6 + 450_000e6 + 500_000e6 + skyYield + aaveYield;

        assertApproxEqAbs(pool.totalAssets(), totalAssets, 1);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),  100_000e6 + skyYield,  1);
        assertApproxEqAbs(aaveStrategy.assetsUnderManagement(), 125_000e6 + aaveYield, 1);

        // Both users withdraw all their shares.
        requestRedeem(address(pool), lp_1, 450_000e6);
        requestRedeem(address(pool), lp_2, 500_000e6);

        processRedemptions(address(pool), 450_000e6 + 500_000e6);

        uint256 assetsWithdrawn = totalAssets * (450_000e6 + 500_000e6) / totalSupply;

        assertEq(fundsAsset.balanceOf(lp_1), totalAssets * 450_000e6 / totalSupply);
        assertEq(fundsAsset.balanceOf(lp_2), totalAssets * 500_000e6 / totalSupply);

        assertEq(pool.balanceOf(lp_1), 0);
        assertEq(pool.balanceOf(lp_2), 0);

        assertApproxEqAbs(pool.totalAssets(), totalAssets - assetsWithdrawn, 1);

        assertApproxEqAbs(skyStrategy.assetsUnderManagement(),  100_000e6 + skyYield,  1);
        assertApproxEqAbs(aaveStrategy.assetsUnderManagement(), 125_000e6 + aaveYield, 1);
    }

}
