// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IAllocationStrategy, IStrategyManager } from "../../../contracts/interfaces/Interfaces.sol";

import { AllocationStrategyTestBase } from "../../integration/allocation-strategy/AllocationStrategyTestBase.sol";

contract AllocationYieldEntryTimingTests is AllocationStrategyTestBase {

    address poolALp = makeAddr("poolALp");
    address poolBLp = makeAddr("poolBLp");

    address poolA;
    address poolB;
    address poolManagerA;
    address poolManagerB;

    uint256 grossYield     = 100_000e6;
    uint256 poolFunding    = 380_000e6;
    uint256 poolShares     = 380_000e6;
    uint256 strategyShares = 380_000e6;

    uint32 delegateFeeRate = 0.02e6;  // 2%
    uint32 protocolFeeRate = 0.03e6;  // 3%

    function setUp() public override {
        super.setUp();

        poolA        = address(pool);
        poolManagerA = address(poolManager);

        setStrategyDelegateFeeRate(allocationUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(allocationUnderlyingStrategy, protocolFeeRate);
    }

    function test_poolJoinsBeforeYieldRealization_receivesPreEntryYield() external {
        uint256 delegateFee = grossYield * delegateFeeRate / 1e6;      // 2_000e6
        uint256 protocolFee = grossYield * protocolFeeRate / 1e6;      // 3_000e6
        uint256 netYield    = grossYield - delegateFee - protocolFee;  // 95_000e6

        uint256 totalStrategyShares   = strategyShares + strategyShares;       // 760_000e6
        uint256 totalAssetsAfterYield = poolFunding + poolFunding + netYield;  // 855_000e6

        uint256 poolAAssetsAfterYield = strategyShares * totalAssetsAfterYield / totalStrategyShares;  // 427_500e6
        uint256 poolBAssetsAfterYield = strategyShares * totalAssetsAfterYield / totalStrategyShares;  // 427_500e6

        uint256 poolBPreEntryYield = poolBAssetsAfterYield - poolFunding;  // 47_500e6

        /**********************************************************************************************************************************/
        /*** Keep Pool A invested while its unrecognized yield sits in the managed wallet                                               ***/
        /**********************************************************************************************************************************/

        ( poolB, poolManagerB ) = _createPoolSharingStrategy("poolBDelegate", allocationStrategyManager);

        openPool(poolManagerB);

        deposit(poolA, poolALp, poolFunding);
        deposit(poolB, poolBLp, poolFunding);

        fundStrategyManager(poolManagerA, allocationStrategyManager, poolFunding);
        deployAssets(allocationUnderlyingStrategy, managedWallet, poolFunding);

        erc20_mint(address(fundsAsset), managedWallet, grossYield);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolFunding,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolFunding,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolFunding
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: poolFunding,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerA,
            assets:           poolFunding,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: poolFunding,
            availableToWithdraw:   0,
            recordedAssets:        0,
            totalDeployedAssets:   poolFunding,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            yieldLastRealized:    0,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), poolFunding);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(managedWallet),                poolFunding + grossYield);
        assertEq(fundsAsset.balanceOf(poolA),                        0);
        assertEq(fundsAsset.balanceOf(poolB),                        poolFunding);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);

        /**********************************************************************************************************************************/
        /*** Fund Pool B before realization so both Pools hold equal shares when the yield is recognized                                ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(poolManagerB, allocationStrategyManager, poolFunding);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolFunding,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolFunding,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           totalStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalStrategyShares,
            availableToWithdraw:   poolFunding,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerA,
            assets:           poolFunding,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           poolFunding,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalStrategyShares,
            availableToWithdraw:   poolFunding,
            recordedAssets:        poolFunding,
            totalDeployedAssets:   poolFunding,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            yieldLastRealized:    0,
            realizedYield:        0
        });

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), poolFunding);
        assertEq(fundsAsset.balanceOf(managedWallet),                poolFunding + grossYield);
        assertEq(fundsAsset.balanceOf(poolA),                        0);
        assertEq(fundsAsset.balanceOf(poolB),                        0);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);

        /**********************************************************************************************************************************/
        /*** Realize the pre-entry yield and prove Pool B receives half because it already owns half the shares                         ***/
        /**********************************************************************************************************************************/

        vm.startPrank(managedWallet);
        fundsAsset.approve(allocationUnderlyingStrategy, grossYield);
        IAllocationStrategy(allocationUnderlyingStrategy).realizeYield(grossYield, 0, "");
        vm.stopPrank();

        assertEq(IStrategyManager(allocationStrategyManager).assetsOf(poolManagerB) - poolFunding, poolBPreEntryYield);
        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(strategyShares),  poolBAssetsAfterYield);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssetsAfterYield,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBAssetsAfterYield,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           totalStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssetsAfterYield,
            availableToWithdraw:   poolFunding + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerA,
            assets:           poolAAssetsAfterYield,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           poolBAssetsAfterYield,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssetsAfterYield,
            availableToWithdraw:   poolFunding + netYield,
            recordedAssets:        poolFunding + netYield,
            totalDeployedAssets:   poolFunding,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), poolFunding + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                poolFunding);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Return Pool A's principal and redeem both Strategy Manager positions                                                       ***/
        /**********************************************************************************************************************************/

        vm.startPrank(managedWallet);
        fundsAsset.approve(allocationUnderlyingStrategy, poolFunding);
        IAllocationStrategy(allocationUnderlyingStrategy).returnAssets(poolFunding, managedWallet, "");
        vm.stopPrank();

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssetsAfterYield,
            availableToWithdraw:   totalAssetsAfterYield,
            recordedAssets:        totalAssetsAfterYield,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), totalAssetsAfterYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);

        requestRedeemFromStrategyManager(poolManagerB, allocationStrategyManager, strategyShares);
        processRedemptionFromStrategyManager(poolManagerB, allocationStrategyManager, strategyShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssetsAfterYield,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBAssetsAfterYield,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolBAssetsAfterYield
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: poolAAssetsAfterYield,
            availableToWithdraw:   poolAAssetsAfterYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerA,
            assets:           poolAAssetsAfterYield,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        requestRedeemFromStrategyManager(poolManagerA, allocationStrategyManager, strategyShares);
        processRedemptionFromStrategyManager(poolManagerA, allocationStrategyManager, strategyShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssetsAfterYield,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolAAssetsAfterYield
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBAssetsAfterYield,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolBAssetsAfterYield
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerA,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            recordedAssets:        0,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);
        assertEq(fundsAsset.balanceOf(poolA),                        poolAAssetsAfterYield);
        assertEq(fundsAsset.balanceOf(poolB),                        poolBAssetsAfterYield);

        /**********************************************************************************************************************************/
        /*** Redeem both LPs and reconcile every deposited and yielded asset                                                            ***/
        /**********************************************************************************************************************************/

        requestRedeem(poolB, poolBLp, poolShares);
        processRedemptions(poolB, poolShares);

        requestRedeem(poolA, poolALp, poolShares);
        processRedemptions(poolA, poolShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(fundsAsset.balanceOf(poolALp),          poolAAssetsAfterYield);
        assertEq(fundsAsset.balanceOf(poolBLp),          poolBAssetsAfterYield);
        assertEq(fundsAsset.balanceOf(strategyDelegate), delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         protocolFee);

        assertEq(poolAAssetsAfterYield + poolBAssetsAfterYield,     totalAssetsAfterYield);
        assertEq(totalAssetsAfterYield + delegateFee + protocolFee, 2 * poolFunding + grossYield);
    }

    function test_poolJoinsAfterYieldRealization_receivesNoPreEntryYield() external {
        uint256 delegateFee = grossYield * delegateFeeRate / 1e6;      // 2_000e6
        uint256 protocolFee = grossYield * protocolFeeRate / 1e6;      // 3_000e6
        uint256 netYield    = grossYield - delegateFee - protocolFee;  // 95_000e6

        uint256 poolAAssetsAfterYield = poolFunding + netYield;                                // 475_000e6
        uint256 poolBStrategyShares   = poolFunding * strategyShares / poolAAssetsAfterYield;  // 304_000e6
        uint256 totalStrategyShares   = strategyShares + poolBStrategyShares;                  // 684_000e6
        uint256 totalAssetsAfterEntry = poolAAssetsAfterYield + poolFunding;                   // 855_000e6

        uint256 poolAAssetsAfterEntry = strategyShares * totalAssetsAfterEntry / totalStrategyShares;       // 475_000e6
        uint256 poolBAssetsAfterEntry = poolBStrategyShares * totalAssetsAfterEntry / totalStrategyShares;  // 380_000e6

        /**********************************************************************************************************************************/
        /*** Keep Pool A invested while its unrecognized yield sits in the managed wallet                                               ***/
        /**********************************************************************************************************************************/

        ( poolB, poolManagerB ) = _createPoolSharingStrategy("poolBDelegate", allocationStrategyManager);

        openPool(poolManagerB);

        deposit(poolA, poolALp, poolFunding);
        deposit(poolB, poolBLp, poolFunding);

        fundStrategyManager(poolManagerA, allocationStrategyManager, poolFunding);
        deployAssets(allocationUnderlyingStrategy, managedWallet, poolFunding);

        erc20_mint(address(fundsAsset), managedWallet, grossYield);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolFunding,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolFunding,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolFunding
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: poolFunding,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerA,
            assets:           poolFunding,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: poolFunding,
            availableToWithdraw:   0,
            recordedAssets:        0,
            totalDeployedAssets:   poolFunding,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            yieldLastRealized:    0,
            realizedYield:        0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), poolFunding);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(managedWallet),                poolFunding + grossYield);
        assertEq(fundsAsset.balanceOf(poolA),                        0);
        assertEq(fundsAsset.balanceOf(poolB),                        poolFunding);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);

        /**********************************************************************************************************************************/
        /*** Realize all yield before Pool B funds so Pool A owns the complete pre-entry gain                                           ***/
        /**********************************************************************************************************************************/

        vm.startPrank(managedWallet);
        fundsAsset.approve(allocationUnderlyingStrategy, grossYield);
        IAllocationStrategy(allocationUnderlyingStrategy).realizeYield(grossYield, 0, "");
        vm.stopPrank();

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssetsAfterYield,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolFunding,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolFunding
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: poolAAssetsAfterYield,
            availableToWithdraw:   netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerA,
            assets:           poolAAssetsAfterYield,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: poolAAssetsAfterYield,
            availableToWithdraw:   netYield,
            recordedAssets:        netYield,
            totalDeployedAssets:   poolFunding,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                poolFunding);
        assertEq(fundsAsset.balanceOf(poolA),                        0);
        assertEq(fundsAsset.balanceOf(poolB),                        poolFunding);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Fund Pool B at the post-yield share price and prove none of Pool A's yield transfers                                       ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(poolManagerB, allocationStrategyManager, poolFunding);

        assertEq(IStrategyManager(allocationStrategyManager).assetsOf(poolManagerA),                   poolAAssetsAfterYield);
        assertEq(IStrategyManager(allocationStrategyManager).assetsOf(poolManagerB),                   poolFunding);
        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(poolBStrategyShares), poolFunding);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssetsAfterEntry,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBAssetsAfterEntry,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           totalStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssetsAfterEntry,
            availableToWithdraw:   poolFunding + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerA,
            assets:           poolAAssetsAfterEntry,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           poolBAssetsAfterEntry,
            shares:           poolBStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssetsAfterEntry,
            availableToWithdraw:   poolFunding + netYield,
            recordedAssets:        poolFunding + netYield,
            totalDeployedAssets:   poolFunding,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), poolFunding + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                poolFunding);
        assertEq(fundsAsset.balanceOf(poolA),                        0);
        assertEq(fundsAsset.balanceOf(poolB),                        0);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Return Pool A's principal and redeem both Strategy Manager positions                                                       ***/
        /**********************************************************************************************************************************/

        vm.startPrank(managedWallet);
        fundsAsset.approve(allocationUnderlyingStrategy, poolFunding);
        IAllocationStrategy(allocationUnderlyingStrategy).returnAssets(poolFunding, managedWallet, "");
        vm.stopPrank();

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssetsAfterEntry,
            availableToWithdraw:   totalAssetsAfterEntry,
            recordedAssets:        totalAssetsAfterEntry,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), totalAssetsAfterEntry);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);

        requestRedeemFromStrategyManager(poolManagerB, allocationStrategyManager, poolBStrategyShares);
        processRedemptionFromStrategyManager(poolManagerB, allocationStrategyManager, poolBStrategyShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssetsAfterEntry,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBAssetsAfterEntry,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolBAssetsAfterEntry
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: poolAAssetsAfterEntry,
            availableToWithdraw:   poolAAssetsAfterEntry,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerA,
            assets:           poolAAssetsAfterEntry,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        requestRedeemFromStrategyManager(poolManagerA, allocationStrategyManager, strategyShares);
        processRedemptionFromStrategyManager(poolManagerA, allocationStrategyManager, strategyShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssetsAfterEntry,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolAAssetsAfterEntry
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBAssetsAfterEntry,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolBAssetsAfterEntry
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerA,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            recordedAssets:        0,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);
        assertEq(fundsAsset.balanceOf(poolA),                        poolAAssetsAfterEntry);
        assertEq(fundsAsset.balanceOf(poolB),                        poolBAssetsAfterEntry);

        /**********************************************************************************************************************************/
        /*** Redeem both LPs and reconcile every deposited and yielded asset                                                            ***/
        /**********************************************************************************************************************************/

        requestRedeem(poolB, poolBLp, poolShares);
        processRedemptions(poolB, poolShares);

        requestRedeem(poolA, poolALp, poolShares);
        processRedemptions(poolA, poolShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(fundsAsset.balanceOf(poolALp),          poolAAssetsAfterEntry);
        assertEq(fundsAsset.balanceOf(poolBLp),          poolBAssetsAfterEntry);
        assertEq(fundsAsset.balanceOf(strategyDelegate), delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         protocolFee);

        assertEq(poolAAssetsAfterEntry + poolBAssetsAfterEntry,     totalAssetsAfterEntry);
        assertEq(totalAssetsAfterEntry + delegateFee + protocolFee, 2 * poolFunding + grossYield);
    }

}
