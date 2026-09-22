// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAaveV3Strategy,
    IAllocationStrategy,
    IERC20,
    IGlobals,
    IMapleProxyFactory,
    IPool,
    IPoolManager,
    ISkyStrategy,
    IStrategyManager,
    IWithdrawalManagerQueue
} from "../../../contracts/interfaces/Interfaces.sol";

import { ModularReleaseBase } from "./ModularReleaseBase.sol";

contract ModularReleaseProcedure is ModularReleaseBase {

    bytes32 constant IMPLEMENTATION_SLOT = bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);

    uint256 assetsToDeposit  = 133_769e6;
    uint256 maxRoundingError = 2;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 25_760_242);

        startingTime = block.timestamp;

        upgradeProtocol({ attachAaveAndSkyStrategies: true });
    }

    function testFork_modularRelease_fullUpgradeProcedure() external {

        /**********************************************************************************************************************************/
        /*** Globals                                                                                                                    ***/
        /**********************************************************************************************************************************/

        assertEq(address(uint160(uint256(vm.load(globals, IMPLEMENTATION_SLOT)))), globalsV500Implementation);

        assertEq(IGlobals(globals).isInstanceOf("POOL_MANAGER_FACTORY",        poolManagerFactory),            true);
        assertEq(IGlobals(globals).isInstanceOf("WITHDRAWAL_MANAGER_FACTORY",  withdrawalManagerQueueFactory), true);
        assertEq(IGlobals(globals).isInstanceOf("STRATEGY_MANAGER_FACTORY",    strategyManagerFactory),        true);

        assertEq(IGlobals(globals).isInstanceOf("UNDERLYING_STRATEGY_FACTORY", modularAaveStrategyFactory), true);
        assertEq(IGlobals(globals).isInstanceOf("UNDERLYING_STRATEGY_FACTORY", modularSkyStrategyFactory),  true);
        assertEq(IGlobals(globals).isInstanceOf("UNDERLYING_STRATEGY_FACTORY", allocationStrategyFactory),  true);

        assertEq(IGlobals(globals).isInstanceOf("STRATEGY_VAULT", aUsdc),        true);
        assertEq(IGlobals(globals).isInstanceOf("STRATEGY_VAULT", aUsdt),        true);
        assertEq(IGlobals(globals).isInstanceOf("STRATEGY_VAULT", AAVE_USDG),    true);
        assertEq(IGlobals(globals).isInstanceOf("STRATEGY_VAULT", SAVINGS_USDS), true);

        assertEq(IGlobals(globals).isInstanceOf("LIQUIDITY_ROUTER", liquidityRouterV100), true);

        assertEq(IGlobals(globals).canDeployFrom(poolManagerFactory,            poolDeployerV500), true);
        assertEq(IGlobals(globals).canDeployFrom(withdrawalManagerQueueFactory, poolDeployerV500), true);

        assertEq(IGlobals(globals).canDeployFrom(strategyManagerFactory,     strategyDeployerV100), true);
        assertEq(IGlobals(globals).canDeployFrom(modularAaveStrategyFactory, strategyDeployerV100), true);
        assertEq(IGlobals(globals).canDeployFrom(modularSkyStrategyFactory,  strategyDeployerV100), true);
        assertEq(IGlobals(globals).canDeployFrom(allocationStrategyFactory,  strategyDeployerV100), true);

        assertEq(IGlobals(globals).bootstrapMint(USDC), BOOTSTRAP_MINT);
        assertEq(IGlobals(globals).bootstrapMint(USDT), BOOTSTRAP_MINT);
        assertEq(IGlobals(globals).bootstrapMint(USDG), BOOTSTRAP_MINT);

        for (uint256 i; i < specs.length; i++) {
            assertEq(IGlobals(globals).isStrategyDelegate(specs[i].delegate), true);
            assertEq(IGlobals(globals).ownedStrategyManager(specs[i].delegate), strategyManagers[specs[i].name]);

            if (specs[i].kind != StrategyKind.Allocation) continue;

            assertEq(IGlobals(globals).isInstanceOf("MAPLE_MANAGED_WALLET", managedWallets[specs[i].name]), true);
        }

        /**********************************************************************************************************************************/
        /*** Factories                                                                                                                  ***/
        /**********************************************************************************************************************************/

        assertEq(IMapleProxyFactory(poolManagerFactory).implementationOf(500), poolManagerV500Implementation);
        assertEq(IMapleProxyFactory(poolManagerFactory).defaultVersion(), 500);
        assertEq(IMapleProxyFactory(poolManagerFactory).upgradeEnabledForPath(400, 500), true);

        assertEq(IMapleProxyFactory(strategyManagerFactory).implementationOf(100), strategyManagerV100Implementation);
        assertEq(IMapleProxyFactory(strategyManagerFactory).defaultVersion(), 100);

        assertEq(IMapleProxyFactory(modularAaveStrategyFactory).implementationOf(100), modularAaveStrategyV100Implementation);
        assertEq(IMapleProxyFactory(modularAaveStrategyFactory).defaultVersion(), 100);

        assertEq(IMapleProxyFactory(modularSkyStrategyFactory).implementationOf(100), modularSkyStrategyV100Implementation);
        assertEq(IMapleProxyFactory(modularSkyStrategyFactory).defaultVersion(), 100);

        assertEq(IMapleProxyFactory(allocationStrategyFactory).implementationOf(100), allocationStrategyV100Implementation);
        assertEq(IMapleProxyFactory(allocationStrategyFactory).defaultVersion(), 100);

        assertEq(IMapleProxyFactory(withdrawalManagerQueueFactory).implementationOf(201), withdrawalManagerQueueV201Implementation);
        assertEq(IMapleProxyFactory(withdrawalManagerQueueFactory).defaultVersion(), 201);
        assertEq(IMapleProxyFactory(withdrawalManagerQueueFactory).upgradeEnabledForPath(200, 201), true);

        /**********************************************************************************************************************************/
        /*** Pool Managers                                                                                                              ***/
        /**********************************************************************************************************************************/

        for (uint256 i; i < poolManagers.length; i++) {
            assertEq(IPoolManager(poolManagers[i]).factory(),        poolManagerFactory);
            assertEq(IPoolManager(poolManagers[i]).implementation(), poolManagerV500Implementation);
            assertEq(IPoolManager(poolManagers[i]).active(),         true);
            assertEq(IPoolManager(poolManagers[i]).configured(),     true);
        }

        assertEq(IPoolManager(syrupUSDCPoolManager).strategyListLength(), 7);

        assertEq(IPoolManager(syrupUSDCPoolManager).isStrategy(syrupUSDCOpenTermLoanManager),                  true);
        assertEq(IPoolManager(syrupUSDCPoolManager).isStrategyManager(strategyManagers["Aave Strategy USDC"]), true);
        assertEq(IPoolManager(syrupUSDCPoolManager).isStrategyManager(strategyManagers["Sky Strategy USDC"]),  true);
        assertEq(IPoolManager(syrupUSDCPoolManager).isStrategyManager(strategyManagers["LP DEX USDC"]),        true);
        assertEq(IPoolManager(syrupUSDCPoolManager).isStrategyManager(strategyManagers["Cross Pool USDC"]),    true);
        assertEq(IPoolManager(syrupUSDCPoolManager).isStrategyManager(strategyManagers["TBills USDC"]),        true);
        assertEq(IPoolManager(syrupUSDCPoolManager).isStrategyManager(strategyManagers["PYUSD USDC"]),         true);

        assertEq(IPoolManager(syrupUSDTPoolManager).strategyListLength(), 7);

        assertEq(IPoolManager(syrupUSDTPoolManager).isStrategy(syrupUSDTOpenTermLoanManager),                  true);
        assertEq(IPoolManager(syrupUSDTPoolManager).isStrategyManager(strategyManagers["Aave Strategy USDT"]), true);
        assertEq(IPoolManager(syrupUSDTPoolManager).isStrategyManager(strategyManagers["LP DEX USDT"]),        true);
        assertEq(IPoolManager(syrupUSDTPoolManager).isStrategyManager(strategyManagers["Cross Pool USDT"]),    true);
        assertEq(IPoolManager(syrupUSDTPoolManager).isStrategyManager(strategyManagers["TBills USDT"]),        true);
        assertEq(IPoolManager(syrupUSDTPoolManager).isStrategyManager(strategyManagers["PYUSD USDT"]),         true);
        assertEq(IPoolManager(syrupUSDTPoolManager).isStrategyManager(strategyManagers["Spreads USDT"]),       true);

        assertEq(IPoolManager(syrupUSDGPoolManager).strategyListLength(), 6);

        assertEq(IPoolManager(syrupUSDGPoolManager).isStrategy(syrupUSDGOpenTermLoanManager),                  true);
        assertEq(IPoolManager(syrupUSDGPoolManager).isStrategyManager(strategyManagers["Aave Strategy USDG"]), true);
        assertEq(IPoolManager(syrupUSDGPoolManager).isStrategyManager(strategyManagers["LP DEX USDG"]),        true);
        assertEq(IPoolManager(syrupUSDGPoolManager).isStrategyManager(strategyManagers["Cross Pool USDG"]),    true);
        assertEq(IPoolManager(syrupUSDGPoolManager).isStrategyManager(strategyManagers["TBills USDG"]),        true);
        assertEq(IPoolManager(syrupUSDGPoolManager).isStrategyManager(strategyManagers["PYUSD USDG"]),         true);

        assertEq(IPoolManager(securedLendingUSDCPoolManager).strategyListLength(), 5);

        assertEq(IPoolManager(securedLendingUSDCPoolManager).isStrategy(securedLendingUSDCOpenTermLoanManager),         true);
        assertEq(IPoolManager(securedLendingUSDCPoolManager).isStrategyManager(strategyManagers["Aave Strategy USDC"]), true);
        assertEq(IPoolManager(securedLendingUSDCPoolManager).isStrategyManager(strategyManagers["Sky Strategy USDC"]),  true);
        assertEq(IPoolManager(securedLendingUSDCPoolManager).isStrategyManager(strategyManagers["TBills USDC"]),        true);
        assertEq(IPoolManager(securedLendingUSDCPoolManager).isStrategyManager(strategyManagers["PYUSD USDC"]),         true);

        /**********************************************************************************************************************************/
        /*** Withdrawal Managers                                                                                                        ***/
        /**********************************************************************************************************************************/

        for (uint256 i; i < poolManagers.length; i++) {
            address withdrawalManager = IPoolManager(poolManagers[i]).withdrawalManager();

            assertEq(IWithdrawalManagerQueue(withdrawalManager).factory(),        withdrawalManagerQueueFactory);
            assertEq(IWithdrawalManagerQueue(withdrawalManager).implementation(), withdrawalManagerQueueV201Implementation);
        }

        /**********************************************************************************************************************************/
        /*** Strategy Managers                                                                                                          ***/
        /**********************************************************************************************************************************/

        for (uint256 i; i < specs.length; i++) {
            address strategyManager = strategyManagers[specs[i].name];

            assertEq(IStrategyManager(strategyManager).active(),           true);
            assertEq(IStrategyManager(strategyManager).configured(),       true);
            assertEq(IStrategyManager(strategyManager).factory(),          strategyManagerFactory);
            assertEq(IStrategyManager(strategyManager).implementation(),   strategyManagerV100Implementation);
            assertEq(IStrategyManager(strategyManager).strategyDelegate(), specs[i].delegate);

            uint256 bootstrapShares = IStrategyManager(strategyManager).sharesOf(address(0));

            assertApproxEqAbs(bootstrapShares, BOOTSTRAP_MINT, maxRoundingError);

            // NOTE: AUM can be higher than the bootstrap mint amount due to yield accrual.
            assertGe(IStrategyManager(strategyManager).assetsUnderManagement(), BOOTSTRAP_MINT);
            assertEq(IStrategyManager(strategyManager).totalShares(),           bootstrapShares);
            assertEq(IStrategyManager(strategyManager).unrealizedLosses(),      0);
        }

        /**********************************************************************************************************************************/
        /*** Underlying Strategies                                                                                                      ***/
        /**********************************************************************************************************************************/

        for (uint256 i; i < specs.length; i++) {
            StrategySpecification memory spec = specs[i];

            address underlyingStrategy = IStrategyManager(strategyManagers[spec.name]).underlyingStrategy();

            if (spec.kind == StrategyKind.Aave) {
                assertEq(IAaveV3Strategy(underlyingStrategy).factory(),                     modularAaveStrategyFactory);
                assertEq(IAaveV3Strategy(underlyingStrategy).aaveToken(),                   spec.vault);
                assertEq(IAaveV3Strategy(underlyingStrategy).strategyDelegate(),            spec.delegate);
                assertEq(IAaveV3Strategy(underlyingStrategy).strategyDelegateFeeRate(),     spec.delegateFeeRate);
                assertEq(IAaveV3Strategy(underlyingStrategy).strategyProtocolFeeRate(),     spec.protocolFeeRate);
                assertEq(IAaveV3Strategy(underlyingStrategy).useVirtualUnderlyingBalance(), true);
                assertGe(IAaveV3Strategy(underlyingStrategy).assetsUnderManagement(),       BOOTSTRAP_MINT);
            }

            if (spec.kind == StrategyKind.Sky) {
                assertEq(ISkyStrategy(underlyingStrategy).factory(),                 modularSkyStrategyFactory);
                assertEq(ISkyStrategy(underlyingStrategy).psm(),                     USDS_LITE_PSM);
                assertEq(ISkyStrategy(underlyingStrategy).savingsUsds(),             SAVINGS_USDS);
                assertEq(ISkyStrategy(underlyingStrategy).strategyDelegate(),        spec.delegate);
                assertEq(ISkyStrategy(underlyingStrategy).strategyDelegateFeeRate(), spec.delegateFeeRate);
                assertEq(ISkyStrategy(underlyingStrategy).strategyProtocolFeeRate(), spec.protocolFeeRate);
                assertGe(ISkyStrategy(underlyingStrategy).assetsUnderManagement(),   BOOTSTRAP_MINT);
            }

            if (spec.kind == StrategyKind.Allocation) {
                assertEq(IAllocationStrategy(underlyingStrategy).factory(),                 allocationStrategyFactory);
                assertEq(IAllocationStrategy(underlyingStrategy).fundsAsset(),              spec.asset);
                assertEq(IAllocationStrategy(underlyingStrategy).yieldCap(),                YIELD_CAP);
                assertEq(IAllocationStrategy(underlyingStrategy).strategyDelegate(),        spec.delegate);
                assertEq(IAllocationStrategy(underlyingStrategy).strategyDelegateFeeRate(), spec.delegateFeeRate);
                assertEq(IAllocationStrategy(underlyingStrategy).strategyProtocolFeeRate(), spec.protocolFeeRate);
                assertEq(IAllocationStrategy(underlyingStrategy).assetsUnderManagement(),   BOOTSTRAP_MINT);

                (
                    bool canDeployAssets,
                    bool canReturnAssets,
                    bool canRealizeYield
                ) = IAllocationStrategy(underlyingStrategy).permissions(managedWallets[spec.name]);

                assertEq(canDeployAssets, true);
                assertEq(canReturnAssets, true);
                assertEq(canRealizeYield, true);
            }
        }

        /**********************************************************************************************************************************/
        /*** Deposit / Redeem Checks - Pools                                                                                            ***/
        /**********************************************************************************************************************************/

        for (uint256 i; i < poolManagers.length; i++) {
            address pool  = IPoolManager(poolManagers[i]).pool();
            address asset = IPoolManager(poolManagers[i]).asset();
            address lp    = makeAddr(string(abi.encodePacked("lp", pool)));

            uint256 totalAssets      = IPool(pool).totalAssets();
            uint256 totalSupply      = IPool(pool).totalSupply();
            uint256 poolAssetBalance = IERC20(asset).balanceOf(pool);

            uint256 sharesMinted   = deposit(pool, lp, assetsToDeposit);
            uint256 sharesToRedeem = sharesMinted / 3;

            assertEq(IERC20(asset).balanceOf(lp),   0);
            assertEq(IERC20(asset).balanceOf(pool), poolAssetBalance + assetsToDeposit);

            assertEq(IPool(pool).balanceOf(lp), sharesMinted);

            assertEq(IPool(pool).totalAssets(), totalAssets + assetsToDeposit);
            assertEq(IPool(pool).totalSupply(), totalSupply + sharesMinted);

            requestRedeem(pool, lp, sharesToRedeem);

            uint256 assetsWithdrawn = IPool(pool).convertToExitAssets(sharesToRedeem);

            processRedemptions(pool, sharesToRedeem);

            assertEq(IERC20(asset).balanceOf(lp),   assetsWithdrawn);
            assertEq(IERC20(asset).balanceOf(pool), poolAssetBalance + assetsToDeposit - assetsWithdrawn);

            assertEq(IPool(pool).balanceOf(lp), sharesMinted - sharesToRedeem);

            assertEq(IPool(pool).totalAssets(), totalAssets + assetsToDeposit - assetsWithdrawn);
            assertEq(IPool(pool).totalSupply(), totalSupply + sharesMinted - sharesToRedeem);
        }

        /**********************************************************************************************************************************/
        /*** Deposit / Redeem Checks - Strategies                                                                                       ***/
        /**********************************************************************************************************************************/

        for (uint256 i; i < specs.length; i++) {
            address strategyManager = strategyManagers[specs[i].name];

            for (uint256 j; j < poolManagers.length; j++) {
                address poolManager = poolManagers[j];
                address pool        = IPoolManager(poolManager).pool();
                address asset       = IPool(pool).asset();

                if (!IPoolManager(poolManager).isStrategyManager(strategyManager)) continue;

                uint256 totalSharesBefore = IStrategyManager(strategyManager).totalShares();
                uint256 aumBefore         = IStrategyManager(strategyManager).assetsUnderManagement();
                uint256 sharesMinted      = IStrategyManager(strategyManager).convertToShares(assetsToDeposit);

                deposit(pool, makeAddr(string(abi.encodePacked("lp", "_", specs[i].name, "_", j))), assetsToDeposit);
                openStrategyCaps(poolManager, strategyManager);
                fundStrategyManager(poolManager, strategyManager, assetsToDeposit);

                assertApproxEqAbs(
                    IStrategyManager(strategyManager).assetsOf(poolManager),
                    assetsToDeposit,
                    maxRoundingError
                );

                assertApproxEqAbs(
                    IStrategyManager(strategyManager).sharesOf(poolManager),
                    sharesMinted,
                    maxRoundingError
                );

                assertApproxEqAbs(
                    IStrategyManager(strategyManager).assetsUnderManagement(),
                    aumBefore + assetsToDeposit,
                    maxRoundingError
                );

                assertApproxEqAbs(
                    IStrategyManager(strategyManager).totalShares(),
                    totalSharesBefore + sharesMinted,
                    maxRoundingError
                );

                uint256 sharesToRedeem  = sharesMinted / 3;
                uint256 assetsWithdrawn = IStrategyManager(strategyManager).convertToExitAssets(sharesToRedeem);
                uint256 poolLiquidity   = IERC20(asset).balanceOf(pool);

                requestRedeemFromStrategyManager(poolManager, strategyManager, sharesToRedeem);
                processRedemptionFromStrategyManager(poolManager, strategyManager, sharesToRedeem);

                assertApproxEqAbs(
                    IStrategyManager(strategyManager).assetsOf(poolManager),
                    assetsToDeposit - assetsWithdrawn,
                    maxRoundingError
                );

                assertApproxEqAbs(
                    IStrategyManager(strategyManager).sharesOf(poolManager),
                    sharesMinted - sharesToRedeem,
                    maxRoundingError
                );

                assertApproxEqAbs(
                    IStrategyManager(strategyManager).assetsUnderManagement(),
                    aumBefore + assetsToDeposit - assetsWithdrawn,
                    maxRoundingError
                );

                assertApproxEqAbs(
                    IStrategyManager(strategyManager).totalShares(),
                    totalSharesBefore + sharesMinted - sharesToRedeem,
                    maxRoundingError
                );

                assertEq(IERC20(asset).balanceOf(pool), poolLiquidity + assetsWithdrawn);
            }
        }
    }

    /**************************************************************************************************************************************/
    /*** Utility Functions                                                                                                              ***/
    /**************************************************************************************************************************************/

    function openStrategyCaps(address poolManager, address strategyManager) internal {
        address poolDelegate     = IPoolManager(poolManager).poolDelegate();
        address strategyDelegate = IStrategyManager(strategyManager).strategyDelegate();

        vm.prank(poolDelegate);
        IPoolManager(poolManager).setStrategyCap(strategyManager, type(uint256).max);

        if (IStrategyManager(strategyManager).strategyLiquidityCap() == type(uint256).max) return;

        vm.prank(strategyDelegate);
        IStrategyManager(strategyManager).setStrategyLiquidityCap(type(uint256).max);
    }

}
