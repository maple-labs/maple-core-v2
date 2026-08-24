// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IAllocationStrategy, IStrategyManager } from "../../../contracts/interfaces/Interfaces.sol";

import { AllocationStrategyTestBase } from "../../integration/allocation-strategy/AllocationStrategyTestBase.sol";

contract AllocationPrincipalExitLateYieldWithoutBootstrapTests is AllocationStrategyTestBase {

    address lateLp = makeAddr("lateLp");

    address poolA;
    address poolB;
    address poolManagerA;
    address poolManagerB;

    uint256 grossYield              = 50_000e6;
    uint256 lateFundingAssets       = 100_000e6;
    uint256 latePoolShares          = 100_000e6;
    uint256 lateStrategyShares      = 100_000e6;
    uint256 principalAssets         = 1_000_000e6;
    uint256 principalPoolShares     = 1_000_000e6;
    uint256 principalStrategyShares = 1_000_000e6;

    uint32 delegateFeeRate = 0.02e6;  // 2%
    uint32 protocolFeeRate = 0.03e6;  // 3%
    uint32 yieldDuration   = 10 days;

    function setUp() public override {
        super.setUp();

        poolA        = address(pool);
        poolManagerA = address(poolManager);

        setStrategyDelegateFeeRate(allocationUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(allocationUnderlyingStrategy, protocolFeeRate);
    }

    function test_allocationPrincipalExit_lateImmediateYield_noBootstrapMint() external {
        uint256 delegateFee = grossYield * delegateFeeRate / 1e6;      // 1_000e6
        uint256 protocolFee = grossYield * protocolFeeRate / 1e6;      // 1_500e6
        uint256 netYield    = grossYield - delegateFee - protocolFee;  // 47_500e6

        /**********************************************************************************************************************************/
        /*** Deploy the Pool principal and return the same tokens from the managed wallet                                               ***/
        /**********************************************************************************************************************************/

        deposit(poolA, lp, principalAssets);
        fundStrategyManager(poolManagerA, allocationStrategyManager, principalAssets);
        deployAssets(allocationUnderlyingStrategy, managedWallet, principalAssets);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), principalAssets);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(managedWallet),                principalAssets);

        vm.startPrank(managedWallet);
        fundsAsset.approve(allocationUnderlyingStrategy, principalAssets);
        IAllocationStrategy(allocationUnderlyingStrategy).returnAssets(principalAssets, managedWallet, "");
        vm.stopPrank();

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           principalStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: principalAssets,
            availableToWithdraw:   principalAssets,
            unrealizedLosses:      0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: principalAssets,
            availableToWithdraw:   principalAssets,
            recordedAssets:        principalAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), principalAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);

        /**********************************************************************************************************************************/
        /*** Redeem every Pool-owned strategy share, leaving zero assets and zero shares                                                ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(poolManagerA, allocationStrategyManager, principalStrategyShares);
        processRedemptionFromStrategyManager(poolManagerA, allocationStrategyManager, principalStrategyShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        principalAssets,
            totalSupply:        principalPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: principalAssets
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

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            yieldLastRealized:    0,
            realizedYield:        0
        });

        assertEq(fundsAsset.balanceOf(poolA),                        principalAssets);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);

        /**********************************************************************************************************************************/
        /*** Realize immediate yield after the exit, creating AUM while no strategy shares exist                                        ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, grossYield, 0);

        assertPoolState({
            pool:               poolA,
            totalAssets:        principalAssets,
            totalSupply:        principalPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: principalAssets
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: netYield,
            availableToWithdraw:   netYield,
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
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: netYield,
            availableToWithdraw:   netYield,
            recordedAssets:        netYield,
            totalDeployedAssets:   0,
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
        assertEq(fundsAsset.balanceOf(managedWallet),                0);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Let a fresh Pool fund first and redeem its contribution plus all of the shareless AUM                                      ***/
        /**********************************************************************************************************************************/

        ( poolB, poolManagerB ) = _createPoolSharingStrategy("latePoolDelegate", allocationStrategyManager);

        deposit(poolB, lateLp, lateFundingAssets);
        fundStrategyManager(poolManagerB, allocationStrategyManager, lateFundingAssets);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(lateStrategyShares), lateFundingAssets + netYield);

        assertPoolState({
            pool:               poolA,
            totalAssets:        principalAssets,
            totalSupply:        principalPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: principalAssets
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        lateFundingAssets + netYield,
            totalSupply:        latePoolShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           lateStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: lateFundingAssets + netYield,
            availableToWithdraw:   lateFundingAssets + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           lateFundingAssets + netYield,
            shares:           lateStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
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
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        requestRedeemFromStrategyManager(poolManagerB, allocationStrategyManager, lateStrategyShares);
        processRedemptionFromStrategyManager(poolManagerB, allocationStrategyManager, lateStrategyShares);

        assertPoolState({
            pool:               poolB,
            totalAssets:        lateFundingAssets + netYield,
            totalSupply:        latePoolShares,
            unrealizedLosses:   0,
            availableLiquidity: lateFundingAssets + netYield
        });

        assertPoolState({
            pool:               poolA,
            totalAssets:        principalAssets,
            totalSupply:        principalPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: principalAssets
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
            poolManager:      poolManagerB,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
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

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(fundsAsset.balanceOf(poolB),                        lateFundingAssets + netYield);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_allocationPrincipalExit_lateVestingYield_noBootstrapMint() external {
        uint256 delegateFee  = grossYield * delegateFeeRate / 1e6;      // 1_000e6
        uint256 protocolFee  = grossYield * protocolFeeRate / 1e6;      // 1_500e6
        uint256 netYield     = grossYield - delegateFee - protocolFee;  // 47_500e6
        uint256 halfwayYield = netYield / 2;                            // 23_750e6

        /**********************************************************************************************************************************/
        /*** Deploy and return the same principal, then redeem every Pool-owned strategy share                                          ***/
        /**********************************************************************************************************************************/

        deposit(poolA, lp, principalAssets);
        fundStrategyManager(poolManagerA, allocationStrategyManager, principalAssets);
        deployAssets(allocationUnderlyingStrategy, managedWallet, principalAssets);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), principalAssets);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(managedWallet),                principalAssets);

        vm.startPrank(managedWallet);
        fundsAsset.approve(allocationUnderlyingStrategy, principalAssets);
        IAllocationStrategy(allocationUnderlyingStrategy).returnAssets(principalAssets, managedWallet, "");
        vm.stopPrank();

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), principalAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           principalStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: principalAssets,
            availableToWithdraw:   principalAssets,
            unrealizedLosses:      0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: principalAssets,
            availableToWithdraw:   principalAssets,
            recordedAssets:        principalAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        requestRedeemFromStrategyManager(poolManagerA, allocationStrategyManager, principalStrategyShares);
        processRedemptionFromStrategyManager(poolManagerA, allocationStrategyManager, principalStrategyShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        principalAssets,
            totalSupply:        principalPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: principalAssets
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

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            yieldLastRealized:    0,
            realizedYield:        0
        });

        assertEq(fundsAsset.balanceOf(poolA),                        principalAssets);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);

        /**********************************************************************************************************************************/
        /*** Schedule late yield; fees are paid immediately while all net yield starts unvested                                         ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, grossYield, yieldDuration);

        assertPoolState({
            pool:               poolA,
            totalAssets:        principalAssets,
            totalSupply:        principalPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: principalAssets
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
            recordedAssets:        netYield,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Halfway through vesting, positive AUM exists but no account owns strategy shares                                           ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration / 2);

        assertPoolState({
            pool:               poolA,
            totalAssets:        principalAssets,
            totalSupply:        principalPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: principalAssets
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: halfwayYield,
            availableToWithdraw:   halfwayYield,
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
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: halfwayYield,
            availableToWithdraw:   halfwayYield,
            recordedAssets:        netYield,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        halfwayYield
        });

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), netYield);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Let a fresh Pool fund halfway through vesting and absorb both the vested and future shareless yield                        ***/
        /**********************************************************************************************************************************/

        ( poolB, poolManagerB ) = _createPoolSharingStrategy("latePoolDelegate", allocationStrategyManager);

        deposit(poolB, lateLp, lateFundingAssets);
        fundStrategyManager(poolManagerB, allocationStrategyManager, lateFundingAssets);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(lateStrategyShares), lateFundingAssets + halfwayYield);

        assertPoolState({
            pool:               poolA,
            totalAssets:        principalAssets,
            totalSupply:        principalPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: principalAssets
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        lateFundingAssets + halfwayYield,
            totalSupply:        latePoolShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           lateStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: lateFundingAssets + halfwayYield,
            availableToWithdraw:   lateFundingAssets + halfwayYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           lateFundingAssets + halfwayYield,
            shares:           lateStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
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
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: lateFundingAssets + halfwayYield,
            availableToWithdraw:   lateFundingAssets + halfwayYield,
            recordedAssets:        lateFundingAssets + netYield,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        halfwayYield
        });

        assertEq(fundsAsset.balanceOf(poolB),                        0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), lateFundingAssets + netYield);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** At the deadline, all remaining yield is claimable by the first funder                                                      ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               poolA,
            totalAssets:        principalAssets,
            totalSupply:        principalPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: principalAssets
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        lateFundingAssets + netYield,
            totalSupply:        latePoolShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           lateStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: lateFundingAssets + netYield,
            availableToWithdraw:   lateFundingAssets + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           lateFundingAssets + netYield,
            shares:           lateStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
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
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: lateFundingAssets + netYield,
            availableToWithdraw:   lateFundingAssets + netYield,
            recordedAssets:        lateFundingAssets + netYield,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(fundsAsset.balanceOf(poolB),                        0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), lateFundingAssets + netYield);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Redeem the fresh Pool's full position, including all late yield                                                            ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(poolManagerB, allocationStrategyManager, lateStrategyShares);
        processRedemptionFromStrategyManager(poolManagerB, allocationStrategyManager, lateStrategyShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        principalAssets,
            totalSupply:        principalPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: principalAssets
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        lateFundingAssets + netYield,
            totalSupply:        latePoolShares,
            unrealizedLosses:   0,
            availableLiquidity: lateFundingAssets + netYield
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
            poolManager:      poolManagerB,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
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

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(fundsAsset.balanceOf(poolB),                        lateFundingAssets + netYield);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

}

contract AllocationPrincipalExitLateYieldWithBootstrapTests is AllocationStrategyTestBase {

    address bootstrapDelegate = makeAddr("bootstrapDelegate");
    address lateLp            = makeAddr("lateLp");

    address poolA;
    address poolB;
    address poolManagerA;
    address poolManagerB;

    uint256 bootstrapAssets         = 100_000e6;
    uint256 bootstrapStrategyShares = 100_000e6;
    uint256 grossYield              = 50_000e6;
    uint256 lateImmediatePoolShares = 147_500e6;
    uint256 lateStrategyShares      = 100_000e6;
    uint256 lateVestingPoolShares   = 371_250e6;
    uint256 principalAssets         = 1_000_000e6;
    uint256 principalPoolShares     = 1_000_000e6;
    uint256 principalStrategyShares = 1_000_000e6;

    uint32 delegateFeeRate = 0.02e6;  // 2%
    uint32 protocolFeeRate = 0.03e6;  // 3%
    uint32 yieldDuration   = 10 days;

    function setUp() public override {
        super.setUp();

        poolA        = address(pool);
        poolManagerA = address(poolManager);

        removeStrategyManager(poolManagerA, allocationStrategyManager);

        strategyDelegate = bootstrapDelegate;

        ( allocationStrategyManager, allocationUnderlyingStrategy ) = _deployAllocationStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: delegateFeeRate,
            strategyProtocolFeeRate_: protocolFeeRate,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           bootstrapAssets
        });

        addStrategyManagerToPool(poolManagerA, allocationStrategyManager);

        setManagedWallet({
            strategy_:        allocationUnderlyingStrategy,
            managedWallet_:   managedWallet,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   type(uint256).max
        });
    }

    function test_allocationPrincipalExit_lateImmediateYield_withBootstrapMint() external {
        uint256 delegateFee = grossYield * delegateFeeRate / 1e6;      // 1_000e6
        uint256 protocolFee = grossYield * protocolFeeRate / 1e6;      // 1_500e6
        uint256 netYield    = grossYield - delegateFee - protocolFee;  // 47_500e6

        uint256 lateFundingAssets = bootstrapAssets + netYield;  // 147_500e6

        /**********************************************************************************************************************************/
        /*** Deploy and return the Pool principal, then redeem every Pool-owned share                                                   ***/
        /**********************************************************************************************************************************/

        deposit(poolA, lp, principalAssets);
        fundStrategyManager(poolManagerA, allocationStrategyManager, principalAssets);
        deployAssets(allocationUnderlyingStrategy, managedWallet, principalAssets);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), principalAssets);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), bootstrapAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                principalAssets);

        vm.startPrank(managedWallet);
        fundsAsset.approve(allocationUnderlyingStrategy, principalAssets);
        IAllocationStrategy(allocationUnderlyingStrategy).returnAssets(principalAssets, managedWallet, "");
        vm.stopPrank();

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), bootstrapAssets + principalAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           bootstrapStrategyShares + principalStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapAssets + principalAssets,
            availableToWithdraw:   bootstrapAssets + principalAssets,
            unrealizedLosses:      0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: bootstrapAssets + principalAssets,
            availableToWithdraw:   bootstrapAssets + principalAssets,
            recordedAssets:        bootstrapAssets + principalAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        requestRedeemFromStrategyManager(poolManagerA, allocationStrategyManager, principalStrategyShares);
        processRedemptionFromStrategyManager(poolManagerA, allocationStrategyManager, principalStrategyShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        principalAssets,
            totalSupply:        principalPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: principalAssets
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           bootstrapStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapAssets,
            availableToWithdraw:   bootstrapAssets,
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
            poolManager:      address(0),
            assets:           bootstrapAssets,
            shares:           bootstrapStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: bootstrapAssets,
            availableToWithdraw:   bootstrapAssets,
            recordedAssets:        bootstrapAssets,
            totalDeployedAssets:   0,
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

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), bootstrapAssets);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);

        /**********************************************************************************************************************************/
        /*** Realize immediate late yield and attribute all net yield to the unchanged bootstrap shares                                 ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, grossYield, 0);

        assertPoolState({
            pool:               poolA,
            totalAssets:        principalAssets,
            totalSupply:        principalPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: principalAssets
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           bootstrapStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapAssets + netYield,
            availableToWithdraw:   bootstrapAssets + netYield,
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
            poolManager:      address(0),
            assets:           bootstrapAssets + netYield,
            shares:           bootstrapStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: bootstrapAssets + netYield,
            availableToWithdraw:   bootstrapAssets + netYield,
            recordedAssets:        bootstrapAssets + netYield,
            totalDeployedAssets:   0,
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

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), bootstrapAssets + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Fund from a fresh Pool at the post-yield exchange rate                                                                     ***/
        /**********************************************************************************************************************************/

        ( poolB, poolManagerB ) = _createPoolSharingStrategy("latePoolDelegate", allocationStrategyManager);

        deposit(poolB, lateLp, lateFundingAssets);
        fundStrategyManager(poolManagerB, allocationStrategyManager, lateFundingAssets);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(lateStrategyShares), lateFundingAssets);

        assertPoolState({
            pool:               poolA,
            totalAssets:        principalAssets,
            totalSupply:        principalPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: principalAssets
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        lateFundingAssets,
            totalSupply:        lateImmediatePoolShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           bootstrapStrategyShares + lateStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapAssets + netYield + lateFundingAssets,
            availableToWithdraw:   bootstrapAssets + netYield + lateFundingAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(0),
            assets:           bootstrapAssets + netYield,
            shares:           bootstrapStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
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
            assets:           lateFundingAssets,
            shares:           lateStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: bootstrapAssets + netYield + lateFundingAssets,
            availableToWithdraw:   bootstrapAssets + netYield + lateFundingAssets,
            recordedAssets:        bootstrapAssets + netYield + lateFundingAssets,
            totalDeployedAssets:   0,
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

        assertEq(fundsAsset.balanceOf(poolB),                        0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), bootstrapAssets + netYield + lateFundingAssets);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Redeem the fresh Pool's full position without transferring any bootstrap-owned yield                                       ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(poolManagerB, allocationStrategyManager, lateStrategyShares);
        processRedemptionFromStrategyManager(poolManagerB, allocationStrategyManager, lateStrategyShares);

        assertPoolState({
            pool:               poolB,
            totalAssets:        lateFundingAssets,
            totalSupply:        lateImmediatePoolShares,
            unrealizedLosses:   0,
            availableLiquidity: lateFundingAssets
        });

        assertPoolState({
            pool:               poolA,
            totalAssets:        principalAssets,
            totalSupply:        principalPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: principalAssets
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           bootstrapStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapAssets + netYield,
            availableToWithdraw:   bootstrapAssets + netYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(0),
            assets:           bootstrapAssets + netYield,
            shares:           bootstrapStrategyShares,
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
            poolManager:      poolManagerA,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: bootstrapAssets + netYield,
            availableToWithdraw:   bootstrapAssets + netYield,
            recordedAssets:        bootstrapAssets + netYield,
            totalDeployedAssets:   0,
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

        assertEq(fundsAsset.balanceOf(poolB),                        lateFundingAssets);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), bootstrapAssets + netYield);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_allocationPrincipalExit_lateVestingYield_withBootstrapMint() external {
        uint256 delegateFee            = grossYield * delegateFeeRate / 1e6;      // 1_000e6
        uint256 protocolFee            = grossYield * protocolFeeRate / 1e6;      // 1_500e6
        uint256 netYield               = grossYield - delegateFee - protocolFee;  // 47_500e6
        uint256 halfwayYield           = netYield / 2;                            // 23_750e6
        uint256 futureYield            = netYield - halfwayYield;                 // 23_750e6
        uint256 halfwayBootstrapAssets = bootstrapAssets + halfwayYield;          // 123_750e6

        uint256 lateFundingAssets         = halfwayBootstrapAssets * 3;                     // 371_250e6
        uint256 lateVestingStrategyShares = bootstrapStrategyShares * 3;                    // 300_000e6
        uint256 futureBootstrapYield      = futureYield / 4;                                // 5_937.5e6
        uint256 futureLateYield           = futureYield - futureBootstrapYield;             // 17_812.5e6
        uint256 finalBootstrapAssets      = halfwayBootstrapAssets + futureBootstrapYield;  // 129_687.5e6
        uint256 finalLateAssets           = lateFundingAssets + futureLateYield;            // 389_062.5e6

        /**********************************************************************************************************************************/
        /*** Deploy and return the Pool principal, then redeem every Pool-owned share                                                   ***/
        /**********************************************************************************************************************************/

        deposit(poolA, lp, principalAssets);
        fundStrategyManager(poolManagerA, allocationStrategyManager, principalAssets);
        deployAssets(allocationUnderlyingStrategy, managedWallet, principalAssets);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), principalAssets);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), bootstrapAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                principalAssets);

        vm.startPrank(managedWallet);
        fundsAsset.approve(allocationUnderlyingStrategy, principalAssets);
        IAllocationStrategy(allocationUnderlyingStrategy).returnAssets(principalAssets, managedWallet, "");
        vm.stopPrank();

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), bootstrapAssets + principalAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           bootstrapStrategyShares + principalStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapAssets + principalAssets,
            availableToWithdraw:   bootstrapAssets + principalAssets,
            unrealizedLosses:      0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: bootstrapAssets + principalAssets,
            availableToWithdraw:   bootstrapAssets + principalAssets,
            recordedAssets:        bootstrapAssets + principalAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        requestRedeemFromStrategyManager(poolManagerA, allocationStrategyManager, principalStrategyShares);
        processRedemptionFromStrategyManager(poolManagerA, allocationStrategyManager, principalStrategyShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        principalAssets,
            totalSupply:        principalPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: principalAssets
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           bootstrapStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapAssets,
            availableToWithdraw:   bootstrapAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(0),
            assets:           bootstrapAssets,
            shares:           bootstrapStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerA,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: bootstrapAssets,
            availableToWithdraw:   bootstrapAssets,
            recordedAssets:        bootstrapAssets,
            totalDeployedAssets:   0,
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

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), bootstrapAssets);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);

        /**********************************************************************************************************************************/
        /*** Schedule late yield; fees are paid while the dead-share value remains at the bootstrap amount                              ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, grossYield, yieldDuration);

        assertPoolState({
            pool:               poolA,
            totalAssets:        principalAssets,
            totalSupply:        principalPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: principalAssets
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           bootstrapStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapAssets,
            availableToWithdraw:   bootstrapAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(0),
            assets:           bootstrapAssets,
            shares:           bootstrapStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerA,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: bootstrapAssets,
            availableToWithdraw:   bootstrapAssets,
            recordedAssets:        bootstrapAssets + netYield,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        0
        });

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), bootstrapAssets + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Halfway through vesting, half of the net yield increases the value of the bootstrap shares                                 ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration / 2);

        assertPoolState({
            pool:               poolA,
            totalAssets:        principalAssets,
            totalSupply:        principalPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: principalAssets
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           bootstrapStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapAssets + halfwayYield,
            availableToWithdraw:   bootstrapAssets + halfwayYield,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(0),
            assets:           bootstrapAssets + halfwayYield,
            shares:           bootstrapStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerA,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: bootstrapAssets + halfwayYield,
            availableToWithdraw:   bootstrapAssets + halfwayYield,
            recordedAssets:        bootstrapAssets + netYield,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        halfwayYield
        });

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), bootstrapAssets + netYield);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Fund from a fresh Pool halfway through vesting without diluting the yield already attributed to bootstrap shares           ***/
        /**********************************************************************************************************************************/

        ( poolB, poolManagerB ) = _createPoolSharingStrategy("latePoolDelegate", allocationStrategyManager);

        deposit(poolB, lateLp, lateFundingAssets);
        fundStrategyManager(poolManagerB, allocationStrategyManager, lateFundingAssets);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(lateVestingStrategyShares), lateFundingAssets);

        assertPoolState({
            pool:               poolA,
            totalAssets:        principalAssets,
            totalSupply:        principalPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: principalAssets
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        lateFundingAssets,
            totalSupply:        lateVestingPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           bootstrapStrategyShares + lateVestingStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapAssets + halfwayYield + lateFundingAssets,
            availableToWithdraw:   bootstrapAssets + halfwayYield + lateFundingAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(0),
            assets:           bootstrapAssets + halfwayYield,
            shares:           bootstrapStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
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
            assets:           lateFundingAssets,
            shares:           lateVestingStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: bootstrapAssets + halfwayYield + lateFundingAssets,
            availableToWithdraw:   bootstrapAssets + halfwayYield + lateFundingAssets,
            recordedAssets:        bootstrapAssets + netYield + lateFundingAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        halfwayYield
        });

        assertEq(fundsAsset.balanceOf(poolB),                        0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), bootstrapAssets + netYield + lateFundingAssets);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** At the deadline, the remaining yield is split 1:3 between the bootstrap and Pool-owned positions                          ***/
        /**********************************************************************************************************************************/

        vm.warp(startingTime + yieldDuration);

        assertPoolState({
            pool:               poolA,
            totalAssets:        principalAssets,
            totalSupply:        principalPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: principalAssets
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        finalLateAssets,
            totalSupply:        lateVestingPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           bootstrapStrategyShares + lateVestingStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapAssets + netYield + lateFundingAssets,
            availableToWithdraw:   bootstrapAssets + netYield + lateFundingAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(0),
            assets:           finalBootstrapAssets,
            shares:           bootstrapStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
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
            assets:           finalLateAssets,
            shares:           lateVestingStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: bootstrapAssets + netYield + lateFundingAssets,
            availableToWithdraw:   bootstrapAssets + netYield + lateFundingAssets,
            recordedAssets:        bootstrapAssets + netYield + lateFundingAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), bootstrapAssets + netYield + lateFundingAssets);
        assertEq(fundsAsset.balanceOf(managedWallet),                0);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Redeem the fresh Pool's full position while preserving the final value attributed to the bootstrap shares                  ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(poolManagerB, allocationStrategyManager, lateVestingStrategyShares);
        processRedemptionFromStrategyManager(poolManagerB, allocationStrategyManager, lateVestingStrategyShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        principalAssets,
            totalSupply:        principalPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: principalAssets
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        finalLateAssets,
            totalSupply:        lateVestingPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: finalLateAssets
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           bootstrapStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: finalBootstrapAssets,
            availableToWithdraw:   finalBootstrapAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(0),
            assets:           finalBootstrapAssets,
            shares:           bootstrapStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
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

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: finalBootstrapAssets,
            availableToWithdraw:   finalBootstrapAssets,
            recordedAssets:        finalBootstrapAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        netYield
        });

        assertEq(fundsAsset.balanceOf(poolB),                        finalLateAssets);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), finalBootstrapAssets);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

}
