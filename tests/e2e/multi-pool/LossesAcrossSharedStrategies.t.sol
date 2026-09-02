// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IAllocationStrategy,
    IPool,
    IPoolManager,
    IStrategyManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { AllocationStrategyTestBase } from "../../integration/allocation-strategy/AllocationStrategyTestBase.sol";

contract LossesAcrossSharedStrategiesTests is AllocationStrategyTestBase {

    address managedWalletY    = makeAddr("managedWalletY");
    address poolALp           = makeAddr("poolALp");
    address poolBLp           = makeAddr("poolBLp");
    address poolCLp           = makeAddr("poolCLp");
    address strategyDelegateY = makeAddr("strategyDelegateY");

    address poolA;
    address poolB;
    address poolC;
    address poolManagerA;
    address poolManagerB;
    address poolManagerC;
    address strategyManagerX;
    address strategyManagerY;
    address strategyX;
    address strategyY;

    uint256 firstImpairmentX      = 200_000e6;
    uint256 firstImpairmentY      = 300_000e6;
    uint256 firstLossX            = 100_000e6;
    uint256 firstLossY            = 200_000e6;
    uint256 poolAFunding          = 400_000e6;
    uint256 poolAStrategyXFunding = 400_000e6;
    uint256 poolBFunding          = 1_200_000e6;
    uint256 poolBStrategyXFunding = 600_000e6;
    uint256 poolBStrategyYFunding = 600_000e6;
    uint256 poolCFunding          = 400_000e6;
    uint256 poolCStrategyYFunding = 400_000e6;
    uint256 secondImpairmentX     = 90_000e6;
    uint256 secondImpairmentY     = 80_000e6;
    uint256 secondLossX           = 40_000e6;
    uint256 secondLossY           = 20_000e6;
    uint256 strategyDeployment    = 500_000e6;

    uint256 finalPoolBAssetsX;
    uint256 finalPoolBAssetsY;
    uint256 firstPoolALoss;
    uint256 firstPoolBLossX;
    uint256 firstPoolBLossY;
    uint256 firstPoolCLoss;
    uint256 poolAAssetsAfterLoss;
    uint256 poolBAssetsAfterLossX;
    uint256 poolBAssetsAfterLossY;
    uint256 poolCAssetsAfterLoss;
    uint256 strategyXAssetsAfterLoss;
    uint256 strategyXAvailableAfterRedemption;
    uint256 strategyXInitialAssets;
    uint256 strategyXInitialAvailable;
    uint256 strategyYAssetsAfterLoss;
    uint256 strategyYAvailableAfterRedemption;
    uint256 strategyYInitialAssets;
    uint256 strategyYInitialAvailable;

    function setUp() public override {
        super.setUp();

        poolA            = address(pool);
        poolManagerA     = address(poolManager);
        strategyManagerX = allocationStrategyManager;
        strategyX        = allocationUnderlyingStrategy;

        ( strategyManagerY, strategyY ) = _deployAllocationStrategy({
            strategyDelegate_:        strategyDelegateY,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        setManagedWallet({
            strategy_:        strategyY,
            managedWallet_:   managedWalletY,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   type(uint256).max
        });

        ( poolB, poolManagerB ) = _createPoolSharingStrategy("poolBDelegate", strategyManagerX);

        addStrategyManagerToPool(poolManagerB, strategyManagerY);
        openPool(poolManagerB);

        ( poolC, poolManagerC ) = _createPoolSharingStrategy("poolCDelegate", strategyManagerY);

        openPool(poolManagerC);
    }

    function test_lossesAcrossSharedStrategies_onlyAffectAllocatedShareholders() external {
        strategyXInitialAssets = poolAStrategyXFunding + poolBStrategyXFunding;  // 1_000_000e6
        strategyYInitialAssets = poolBStrategyYFunding + poolCStrategyYFunding;  // 1_000_000e6

        strategyXInitialAvailable = strategyXInitialAssets - strategyDeployment;  // 500_000e6
        strategyYInitialAvailable = strategyYInitialAssets - strategyDeployment;  // 500_000e6

        firstPoolALoss  = poolAStrategyXFunding * firstImpairmentX / strategyXInitialAssets;  // 80_000e6
        firstPoolBLossX = poolBStrategyXFunding * firstImpairmentX / strategyXInitialAssets;  // 120_000e6
        firstPoolBLossY = poolBStrategyYFunding * firstImpairmentY / strategyYInitialAssets;  // 180_000e6
        firstPoolCLoss  = poolCStrategyYFunding * firstImpairmentY / strategyYInitialAssets;  // 120_000e6

        strategyXAssetsAfterLoss = strategyXInitialAssets - firstLossX;  // 900_000e6
        strategyYAssetsAfterLoss = strategyYInitialAssets - firstLossY;  // 800_000e6

        poolAAssetsAfterLoss  = poolAStrategyXFunding * strategyXAssetsAfterLoss / strategyXInitialAssets;  // 360_000e6
        poolBAssetsAfterLossX = poolBStrategyXFunding * strategyXAssetsAfterLoss / strategyXInitialAssets;  // 540_000e6
        poolBAssetsAfterLossY = poolBStrategyYFunding * strategyYAssetsAfterLoss / strategyYInitialAssets;  // 480_000e6
        poolCAssetsAfterLoss  = poolCStrategyYFunding * strategyYAssetsAfterLoss / strategyYInitialAssets;  // 320_000e6

        strategyXAvailableAfterRedemption = strategyXInitialAvailable - poolAAssetsAfterLoss;  // 140_000e6
        strategyYAvailableAfterRedemption = strategyYInitialAvailable - poolCAssetsAfterLoss;  // 180_000e6

        finalPoolBAssetsX = poolBAssetsAfterLossX - secondLossX;  // 500_000e6
        finalPoolBAssetsY = poolBAssetsAfterLossY - secondLossY;  // 460_000e6

        /**********************************************************************************************************************************/
        /*** Fund Pool A into X, Pool B into X and Y, and Pool C into Y                                                                 ***/
        /**********************************************************************************************************************************/

        assertEq(IPoolManager(poolManagerA).strategyListLength(),                2);
        assertEq(IPoolManager(poolManagerA).strategyList(1),                     strategyManagerX);
        assertEq(IPoolManager(poolManagerA).isStrategyManager(strategyManagerX), true);
        assertEq(IPoolManager(poolManagerA).isStrategyManager(strategyManagerY), false);

        assertEq(IPoolManager(poolManagerB).strategyListLength(),                3);
        assertEq(IPoolManager(poolManagerB).strategyList(1),                     strategyManagerX);
        assertEq(IPoolManager(poolManagerB).strategyList(2),                     strategyManagerY);
        assertEq(IPoolManager(poolManagerB).isStrategyManager(strategyManagerX), true);
        assertEq(IPoolManager(poolManagerB).isStrategyManager(strategyManagerY), true);

        assertEq(IPoolManager(poolManagerC).strategyListLength(),                2);
        assertEq(IPoolManager(poolManagerC).strategyList(1),                     strategyManagerY);
        assertEq(IPoolManager(poolManagerC).isStrategyManager(strategyManagerX), false);
        assertEq(IPoolManager(poolManagerC).isStrategyManager(strategyManagerY), true);

        deposit(poolA, poolALp, poolAFunding);
        deposit(poolB, poolBLp, poolBFunding);
        deposit(poolC, poolCLp, poolCFunding);

        fundStrategyManager(poolManagerA, strategyManagerX, poolAStrategyXFunding);
        fundStrategyManager(poolManagerB, strategyManagerX, poolBStrategyXFunding);
        fundStrategyManager(poolManagerB, strategyManagerY, poolBStrategyYFunding);
        fundStrategyManager(poolManagerC, strategyManagerY, poolCStrategyYFunding);

        deployAssets(strategyX, managedWallet,  strategyDeployment);
        deployAssets(strategyY, managedWalletY, strategyDeployment);

        requestRedeemFromStrategyManager(poolManagerA, strategyManagerX, poolAStrategyXFunding);
        requestRedeemFromStrategyManager(poolManagerC, strategyManagerY, poolCStrategyYFunding);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAFunding,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBFunding,
            totalSupply:        poolBFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolC,
            totalAssets:        poolCFunding,
            totalSupply:        poolCFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding), poolAFunding);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding), poolBFunding);
        assertEq(IPool(poolC).convertToExitAssets(poolCFunding), poolCFunding);

        assertStrategyManager({
            strategyManager:       strategyManagerX,
            totalShares:           strategyXInitialAssets,
            totalPendingShares:    poolAStrategyXFunding,
            assetsUnderManagement: strategyXInitialAssets,
            availableToWithdraw:   strategyXInitialAvailable,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerX,
            poolManager:      poolManagerA,
            assets:           poolAStrategyXFunding,
            shares:           poolAStrategyXFunding,
            pendingShares:    poolAStrategyXFunding,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerX,
            poolManager:      poolManagerB,
            assets:           poolBStrategyXFunding,
            shares:           poolBStrategyXFunding,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerX,
            poolManager:      poolManagerC,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerX,
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    strategyX,
            assetsUnderManagement: strategyXInitialAssets,
            availableToWithdraw:   strategyXInitialAvailable,
            recordedAssets:        strategyXInitialAvailable,
            totalDeployedAssets:   strategyDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManagerY,
            totalShares:           strategyYInitialAssets,
            totalPendingShares:    poolCStrategyYFunding,
            assetsUnderManagement: strategyYInitialAssets,
            availableToWithdraw:   strategyYInitialAvailable,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerY,
            poolManager:      poolManagerA,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerY,
            poolManager:      poolManagerB,
            assets:           poolBStrategyYFunding,
            shares:           poolBStrategyYFunding,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerY,
            poolManager:      poolManagerC,
            assets:           poolCStrategyYFunding,
            shares:           poolCStrategyYFunding,
            pendingShares:    poolCStrategyYFunding,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerY,
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    strategyY,
            assetsUnderManagement: strategyYInitialAssets,
            availableToWithdraw:   strategyYInitialAvailable,
            recordedAssets:        strategyYInitialAvailable,
            totalDeployedAssets:   strategyDeployment,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(strategyX).impairedAssets(),                 0);
        assertEq(IAllocationStrategy(strategyX).deployedAssetsOf(managedWallet),  strategyDeployment);
        assertEq(IAllocationStrategy(strategyY).impairedAssets(),                 0);
        assertEq(IAllocationStrategy(strategyY).deployedAssetsOf(managedWalletY), strategyDeployment);

        assertEq(fundsAsset.balanceOf(strategyX),      strategyXInitialAvailable);
        assertEq(fundsAsset.balanceOf(strategyY),      strategyYInitialAvailable);
        assertEq(fundsAsset.balanceOf(managedWallet),  strategyDeployment);
        assertEq(fundsAsset.balanceOf(managedWalletY), strategyDeployment);
        assertEq(fundsAsset.balanceOf(poolA),          0);
        assertEq(fundsAsset.balanceOf(poolB),          0);
        assertEq(fundsAsset.balanceOf(poolC),          0);

        /**********************************************************************************************************************************/
        /*** Impair X and Y while Pool A's X shares and Pool C's Y shares remain pending                                                ***/
        /**********************************************************************************************************************************/

        impairAllocationStrategy(strategyX, firstImpairmentX);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAFunding,
            totalSupply:        poolAFunding,
            unrealizedLosses:   firstPoolALoss,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBFunding,
            totalSupply:        poolBFunding,
            unrealizedLosses:   firstPoolBLossX,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolC,
            totalAssets:        poolCFunding,
            totalSupply:        poolCFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding), poolAFunding - firstPoolALoss);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding), poolBFunding - firstPoolBLossX);
        assertEq(IPool(poolC).convertToExitAssets(poolCFunding), poolCFunding);

        assertEq(IStrategyManager(strategyManagerX).unrealizedLosses(), firstImpairmentX);
        assertEq(IStrategyManager(strategyManagerY).unrealizedLosses(), 0);

        impairAllocationStrategy(strategyY, firstImpairmentY);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAFunding,
            totalSupply:        poolAFunding,
            unrealizedLosses:   firstPoolALoss,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBFunding,
            totalSupply:        poolBFunding,
            unrealizedLosses:   firstPoolBLossX + firstPoolBLossY,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolC,
            totalAssets:        poolCFunding,
            totalSupply:        poolCFunding,
            unrealizedLosses:   firstPoolCLoss,
            availableLiquidity: 0
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding), poolAFunding - firstPoolALoss);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding), poolBFunding - firstPoolBLossX - firstPoolBLossY);
        assertEq(IPool(poolC).convertToExitAssets(poolCFunding), poolCFunding - firstPoolCLoss);

        assertStrategyManager({
            strategyManager:       strategyManagerX,
            totalShares:           strategyXInitialAssets,
            totalPendingShares:    poolAStrategyXFunding,
            assetsUnderManagement: strategyXInitialAssets,
            availableToWithdraw:   strategyXInitialAvailable,
            unrealizedLosses:      firstImpairmentX
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerX,
            poolManager:      poolManagerA,
            assets:           poolAStrategyXFunding,
            shares:           poolAStrategyXFunding,
            pendingShares:    poolAStrategyXFunding,
            unrealizedLosses: firstPoolALoss
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerX,
            poolManager:      poolManagerB,
            assets:           poolBStrategyXFunding,
            shares:           poolBStrategyXFunding,
            pendingShares:    0,
            unrealizedLosses: firstPoolBLossX
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerX,
            poolManager:      poolManagerC,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    strategyX,
            assetsUnderManagement: strategyXInitialAssets,
            availableToWithdraw:   strategyXInitialAvailable,
            recordedAssets:        strategyXInitialAvailable,
            totalDeployedAssets:   strategyDeployment,
            unrealizedLosses:      firstImpairmentX
        });

        assertStrategyManager({
            strategyManager:       strategyManagerY,
            totalShares:           strategyYInitialAssets,
            totalPendingShares:    poolCStrategyYFunding,
            assetsUnderManagement: strategyYInitialAssets,
            availableToWithdraw:   strategyYInitialAvailable,
            unrealizedLosses:      firstImpairmentY
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerY,
            poolManager:      poolManagerA,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerY,
            poolManager:      poolManagerB,
            assets:           poolBStrategyYFunding,
            shares:           poolBStrategyYFunding,
            pendingShares:    0,
            unrealizedLosses: firstPoolBLossY
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerY,
            poolManager:      poolManagerC,
            assets:           poolCStrategyYFunding,
            shares:           poolCStrategyYFunding,
            pendingShares:    poolCStrategyYFunding,
            unrealizedLosses: firstPoolCLoss
        });

        assertAllocationStrategy({
            allocationStrategy:    strategyY,
            assetsUnderManagement: strategyYInitialAssets,
            availableToWithdraw:   strategyYInitialAvailable,
            recordedAssets:        strategyYInitialAvailable,
            totalDeployedAssets:   strategyDeployment,
            unrealizedLosses:      firstImpairmentY
        });

        assertEq(IStrategyManager(strategyManagerX).convertToExitAssets(poolAStrategyXFunding), poolAFunding - firstPoolALoss);
        assertEq(IStrategyManager(strategyManagerY).convertToExitAssets(poolCStrategyYFunding), poolCFunding - firstPoolCLoss);

        assertEq(IAllocationStrategy(strategyX).impairedAssets(), firstImpairmentX);
        assertEq(IAllocationStrategy(strategyY).impairedAssets(), firstImpairmentY);

        assertEq(IAllocationStrategy(strategyX).deployedAssetsOf(managedWallet),  strategyDeployment);
        assertEq(IAllocationStrategy(strategyY).deployedAssetsOf(managedWalletY), strategyDeployment);

        assertEq(fundsAsset.balanceOf(strategyX),      strategyXInitialAvailable);
        assertEq(fundsAsset.balanceOf(strategyY),      strategyYInitialAvailable);
        assertEq(fundsAsset.balanceOf(managedWallet),  strategyDeployment);
        assertEq(fundsAsset.balanceOf(managedWalletY), strategyDeployment);
        assertEq(fundsAsset.balanceOf(poolA),          0);
        assertEq(fundsAsset.balanceOf(poolB),          0);
        assertEq(fundsAsset.balanceOf(poolC),          0);

        /**********************************************************************************************************************************/
        /*** Remove both impairments and restore every pending shareholder's value                                                      ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        IAllocationStrategy(strategyX).removeImpairment(firstImpairmentX);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAFunding,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBFunding,
            totalSupply:        poolBFunding,
            unrealizedLosses:   firstPoolBLossY,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolC,
            totalAssets:        poolCFunding,
            totalSupply:        poolCFunding,
            unrealizedLosses:   firstPoolCLoss,
            availableLiquidity: 0
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding), poolAFunding);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding), poolBFunding - firstPoolBLossY);
        assertEq(IPool(poolC).convertToExitAssets(poolCFunding), poolCFunding - firstPoolCLoss);

        assertEq(IStrategyManager(strategyManagerX).unrealizedLosses(), 0);
        assertEq(IStrategyManager(strategyManagerY).unrealizedLosses(), firstImpairmentY);

        vm.prank(strategyDelegateY);
        IAllocationStrategy(strategyY).removeImpairment(firstImpairmentY);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAFunding,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBFunding,
            totalSupply:        poolBFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolC,
            totalAssets:        poolCFunding,
            totalSupply:        poolCFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding), poolAFunding);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding), poolBFunding);
        assertEq(IPool(poolC).convertToExitAssets(poolCFunding), poolCFunding);

        assertStrategyManager({
            strategyManager:       strategyManagerX,
            totalShares:           strategyXInitialAssets,
            totalPendingShares:    poolAStrategyXFunding,
            assetsUnderManagement: strategyXInitialAssets,
            availableToWithdraw:   strategyXInitialAvailable,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerX,
            poolManager:      poolManagerA,
            assets:           poolAStrategyXFunding,
            shares:           poolAStrategyXFunding,
            pendingShares:    poolAStrategyXFunding,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerX,
            poolManager:      poolManagerB,
            assets:           poolBStrategyXFunding,
            shares:           poolBStrategyXFunding,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       strategyManagerY,
            totalShares:           strategyYInitialAssets,
            totalPendingShares:    poolCStrategyYFunding,
            assetsUnderManagement: strategyYInitialAssets,
            availableToWithdraw:   strategyYInitialAvailable,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerY,
            poolManager:      poolManagerB,
            assets:           poolBStrategyYFunding,
            shares:           poolBStrategyYFunding,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerY,
            poolManager:      poolManagerC,
            assets:           poolCStrategyYFunding,
            shares:           poolCStrategyYFunding,
            pendingShares:    poolCStrategyYFunding,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    strategyX,
            assetsUnderManagement: strategyXInitialAssets,
            availableToWithdraw:   strategyXInitialAvailable,
            recordedAssets:        strategyXInitialAvailable,
            totalDeployedAssets:   strategyDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategy({
            allocationStrategy:    strategyY,
            assetsUnderManagement: strategyYInitialAssets,
            availableToWithdraw:   strategyYInitialAvailable,
            recordedAssets:        strategyYInitialAvailable,
            totalDeployedAssets:   strategyDeployment,
            unrealizedLosses:      0
        });

        assertEq(IStrategyManager(strategyManagerX).convertToExitAssets(poolAStrategyXFunding), poolAFunding);
        assertEq(IStrategyManager(strategyManagerY).convertToExitAssets(poolCStrategyYFunding), poolCFunding);

        assertEq(IAllocationStrategy(strategyX).impairedAssets(), 0);
        assertEq(IAllocationStrategy(strategyY).impairedAssets(), 0);

        assertEq(IAllocationStrategy(strategyX).deployedAssetsOf(managedWallet),  strategyDeployment);
        assertEq(IAllocationStrategy(strategyY).deployedAssetsOf(managedWalletY), strategyDeployment);

        assertEq(fundsAsset.balanceOf(strategyX),      strategyXInitialAvailable);
        assertEq(fundsAsset.balanceOf(strategyY),      strategyYInitialAvailable);
        assertEq(fundsAsset.balanceOf(managedWallet),  strategyDeployment);
        assertEq(fundsAsset.balanceOf(managedWalletY), strategyDeployment);
        assertEq(fundsAsset.balanceOf(poolA),          0);
        assertEq(fundsAsset.balanceOf(poolB),          0);
        assertEq(fundsAsset.balanceOf(poolC),          0);

        /**********************************************************************************************************************************/
        /*** Recognize permanent losses on X and Y while the outgoing shares remain pending                                             ***/
        /**********************************************************************************************************************************/

        recognizeLoss(strategyX, managedWallet, firstLossX);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssetsAfterLoss,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBAssetsAfterLossX + poolBStrategyYFunding,
            totalSupply:        poolBFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolC,
            totalAssets:        poolCFunding,
            totalSupply:        poolCFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding), poolAAssetsAfterLoss);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding), poolBAssetsAfterLossX + poolBStrategyYFunding);
        assertEq(IPool(poolC).convertToExitAssets(poolCFunding), poolCFunding);

        assertEq(IStrategyManager(strategyManagerX).assetsUnderManagement(), strategyXAssetsAfterLoss);
        assertEq(IStrategyManager(strategyManagerY).assetsUnderManagement(), strategyYInitialAssets);

        recognizeLoss(strategyY, managedWalletY, firstLossY);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssetsAfterLoss,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBAssetsAfterLossX + poolBAssetsAfterLossY,
            totalSupply:        poolBFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolC,
            totalAssets:        poolCAssetsAfterLoss,
            totalSupply:        poolCFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding), poolAAssetsAfterLoss);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding), poolBAssetsAfterLossX + poolBAssetsAfterLossY);
        assertEq(IPool(poolC).convertToExitAssets(poolCFunding), poolCAssetsAfterLoss);

        assertStrategyManager({
            strategyManager:       strategyManagerX,
            totalShares:           strategyXInitialAssets,
            totalPendingShares:    poolAStrategyXFunding,
            assetsUnderManagement: strategyXAssetsAfterLoss,
            availableToWithdraw:   strategyXInitialAvailable,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerX,
            poolManager:      poolManagerA,
            assets:           poolAAssetsAfterLoss,
            shares:           poolAStrategyXFunding,
            pendingShares:    poolAStrategyXFunding,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerX,
            poolManager:      poolManagerB,
            assets:           poolBAssetsAfterLossX,
            shares:           poolBStrategyXFunding,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerX,
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    strategyX,
            assetsUnderManagement: strategyXAssetsAfterLoss,
            availableToWithdraw:   strategyXInitialAvailable,
            recordedAssets:        strategyXInitialAvailable,
            totalDeployedAssets:   strategyDeployment - firstLossX,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManagerY,
            totalShares:           strategyYInitialAssets,
            totalPendingShares:    poolCStrategyYFunding,
            assetsUnderManagement: strategyYAssetsAfterLoss,
            availableToWithdraw:   strategyYInitialAvailable,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerY,
            poolManager:      poolManagerB,
            assets:           poolBAssetsAfterLossY,
            shares:           poolBStrategyYFunding,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerY,
            poolManager:      poolManagerC,
            assets:           poolCAssetsAfterLoss,
            shares:           poolCStrategyYFunding,
            pendingShares:    poolCStrategyYFunding,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerY,
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    strategyY,
            assetsUnderManagement: strategyYAssetsAfterLoss,
            availableToWithdraw:   strategyYInitialAvailable,
            recordedAssets:        strategyYInitialAvailable,
            totalDeployedAssets:   strategyDeployment - firstLossY,
            unrealizedLosses:      0
        });

        assertEq(IStrategyManager(strategyManagerX).convertToExitAssets(poolAStrategyXFunding), poolAAssetsAfterLoss);
        assertEq(IStrategyManager(strategyManagerY).convertToExitAssets(poolCStrategyYFunding), poolCAssetsAfterLoss);

        assertEq(IAllocationStrategy(strategyX).deployedAssetsOf(managedWallet),  strategyDeployment - firstLossX);
        assertEq(IAllocationStrategy(strategyY).deployedAssetsOf(managedWalletY), strategyDeployment - firstLossY);

        assertEq(IAllocationStrategy(strategyX).impairedAssets(), 0);
        assertEq(IAllocationStrategy(strategyY).impairedAssets(), 0);

        assertEq(fundsAsset.balanceOf(strategyX),      strategyXInitialAvailable);
        assertEq(fundsAsset.balanceOf(strategyY),      strategyYInitialAvailable);
        assertEq(fundsAsset.balanceOf(managedWallet),  strategyDeployment);
        assertEq(fundsAsset.balanceOf(managedWalletY), strategyDeployment);
        assertEq(fundsAsset.balanceOf(poolA),          0);
        assertEq(fundsAsset.balanceOf(poolB),          0);
        assertEq(fundsAsset.balanceOf(poolC),          0);

        /**********************************************************************************************************************************/
        /*** Burn pending shares to remove Pool A from X and Pool C from Y, leaving Pool B as sole holder of both                       ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(poolManagerA, strategyManagerX, poolAStrategyXFunding);
        processRedemptionFromStrategyManager(poolManagerC, strategyManagerY, poolCStrategyYFunding);

        assertEq(IPoolManager(poolManagerA).strategyListLength(),                2);
        assertEq(IPoolManager(poolManagerA).strategyList(1),                     strategyManagerX);
        assertEq(IPoolManager(poolManagerA).isStrategyManager(strategyManagerX), true);
        assertEq(IPoolManager(poolManagerA).isStrategyManager(strategyManagerY), false);

        assertEq(IPoolManager(poolManagerB).strategyListLength(),                3);
        assertEq(IPoolManager(poolManagerB).strategyList(1),                     strategyManagerX);
        assertEq(IPoolManager(poolManagerB).strategyList(2),                     strategyManagerY);
        assertEq(IPoolManager(poolManagerB).isStrategyManager(strategyManagerX), true);
        assertEq(IPoolManager(poolManagerB).isStrategyManager(strategyManagerY), true);

        assertEq(IPoolManager(poolManagerC).strategyListLength(),                2);
        assertEq(IPoolManager(poolManagerC).strategyList(1),                     strategyManagerY);
        assertEq(IPoolManager(poolManagerC).isStrategyManager(strategyManagerX), false);
        assertEq(IPoolManager(poolManagerC).isStrategyManager(strategyManagerY), true);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssetsAfterLoss,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolAAssetsAfterLoss
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBAssetsAfterLossX + poolBAssetsAfterLossY,
            totalSupply:        poolBFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolC,
            totalAssets:        poolCAssetsAfterLoss,
            totalSupply:        poolCFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolCAssetsAfterLoss
        });

        assertStrategyManager({
            strategyManager:       strategyManagerX,
            totalShares:           poolBStrategyXFunding,
            totalPendingShares:    0,
            assetsUnderManagement: poolBAssetsAfterLossX,
            availableToWithdraw:   strategyXAvailableAfterRedemption,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerX,
            poolManager:      poolManagerA,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerX,
            poolManager:      poolManagerB,
            assets:           poolBAssetsAfterLossX,
            shares:           poolBStrategyXFunding,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerX,
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    strategyX,
            assetsUnderManagement: poolBAssetsAfterLossX,
            availableToWithdraw:   strategyXAvailableAfterRedemption,
            recordedAssets:        strategyXAvailableAfterRedemption,
            totalDeployedAssets:   strategyDeployment - firstLossX,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManagerY,
            totalShares:           poolBStrategyYFunding,
            totalPendingShares:    0,
            assetsUnderManagement: poolBAssetsAfterLossY,
            availableToWithdraw:   strategyYAvailableAfterRedemption,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerY,
            poolManager:      poolManagerB,
            assets:           poolBAssetsAfterLossY,
            shares:           poolBStrategyYFunding,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerY,
            poolManager:      poolManagerC,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerY,
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    strategyY,
            assetsUnderManagement: poolBAssetsAfterLossY,
            availableToWithdraw:   strategyYAvailableAfterRedemption,
            recordedAssets:        strategyYAvailableAfterRedemption,
            totalDeployedAssets:   strategyDeployment - firstLossY,
            unrealizedLosses:      0
        });

        assertEq(fundsAsset.balanceOf(poolA),          poolAAssetsAfterLoss);
        assertEq(fundsAsset.balanceOf(poolB),          0);
        assertEq(fundsAsset.balanceOf(poolC),          poolCAssetsAfterLoss);
        assertEq(fundsAsset.balanceOf(strategyX),      strategyXAvailableAfterRedemption);
        assertEq(fundsAsset.balanceOf(strategyY),      strategyYAvailableAfterRedemption);
        assertEq(fundsAsset.balanceOf(managedWallet),  strategyDeployment);
        assertEq(fundsAsset.balanceOf(managedWalletY), strategyDeployment);

        /**********************************************************************************************************************************/
        /*** Impair X and Y again and prove only Pool B remains exposed                                                                 ***/
        /**********************************************************************************************************************************/

        impairAllocationStrategy(strategyX, secondImpairmentX);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssetsAfterLoss,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolAAssetsAfterLoss
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBAssetsAfterLossX + poolBAssetsAfterLossY,
            totalSupply:        poolBFunding,
            unrealizedLosses:   secondImpairmentX,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolC,
            totalAssets:        poolCAssetsAfterLoss,
            totalSupply:        poolCFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolCAssetsAfterLoss
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding), poolAAssetsAfterLoss);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding), poolBAssetsAfterLossX + poolBAssetsAfterLossY - secondImpairmentX);
        assertEq(IPool(poolC).convertToExitAssets(poolCFunding), poolCAssetsAfterLoss);

        assertEq(IStrategyManager(strategyManagerX).unrealizedLosses(), secondImpairmentX);
        assertEq(IStrategyManager(strategyManagerY).unrealizedLosses(), 0);

        impairAllocationStrategy(strategyY, secondImpairmentY);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssetsAfterLoss,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolAAssetsAfterLoss
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBAssetsAfterLossX + poolBAssetsAfterLossY,
            totalSupply:        poolBFunding,
            unrealizedLosses:   secondImpairmentX + secondImpairmentY,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolC,
            totalAssets:        poolCAssetsAfterLoss,
            totalSupply:        poolCFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolCAssetsAfterLoss
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding), poolAAssetsAfterLoss);
        assertEq(
            IPool(poolB).convertToExitAssets(poolBFunding),
            poolBAssetsAfterLossX + poolBAssetsAfterLossY - secondImpairmentX - secondImpairmentY
        );
        assertEq(IPool(poolC).convertToExitAssets(poolCFunding), poolCAssetsAfterLoss);

        assertStrategyManager({
            strategyManager:       strategyManagerX,
            totalShares:           poolBStrategyXFunding,
            totalPendingShares:    0,
            assetsUnderManagement: poolBAssetsAfterLossX,
            availableToWithdraw:   strategyXAvailableAfterRedemption,
            unrealizedLosses:      secondImpairmentX
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerX,
            poolManager:      poolManagerA,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerX,
            poolManager:      poolManagerB,
            assets:           poolBAssetsAfterLossX,
            shares:           poolBStrategyXFunding,
            pendingShares:    0,
            unrealizedLosses: secondImpairmentX
        });

        assertAllocationStrategy({
            allocationStrategy:    strategyX,
            assetsUnderManagement: poolBAssetsAfterLossX,
            availableToWithdraw:   strategyXAvailableAfterRedemption,
            recordedAssets:        strategyXAvailableAfterRedemption,
            totalDeployedAssets:   strategyDeployment - firstLossX,
            unrealizedLosses:      secondImpairmentX
        });

        assertStrategyManager({
            strategyManager:       strategyManagerY,
            totalShares:           poolBStrategyYFunding,
            totalPendingShares:    0,
            assetsUnderManagement: poolBAssetsAfterLossY,
            availableToWithdraw:   strategyYAvailableAfterRedemption,
            unrealizedLosses:      secondImpairmentY
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerY,
            poolManager:      poolManagerB,
            assets:           poolBAssetsAfterLossY,
            shares:           poolBStrategyYFunding,
            pendingShares:    0,
            unrealizedLosses: secondImpairmentY
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerY,
            poolManager:      poolManagerC,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    strategyY,
            assetsUnderManagement: poolBAssetsAfterLossY,
            availableToWithdraw:   strategyYAvailableAfterRedemption,
            recordedAssets:        strategyYAvailableAfterRedemption,
            totalDeployedAssets:   strategyDeployment - firstLossY,
            unrealizedLosses:      secondImpairmentY
        });

        assertEq(IAllocationStrategy(strategyX).impairedAssets(), secondImpairmentX);
        assertEq(IAllocationStrategy(strategyY).impairedAssets(), secondImpairmentY);

        assertEq(IAllocationStrategy(strategyX).deployedAssetsOf(managedWallet),  strategyDeployment - firstLossX);
        assertEq(IAllocationStrategy(strategyY).deployedAssetsOf(managedWalletY), strategyDeployment - firstLossY);

        assertEq(fundsAsset.balanceOf(poolA),          poolAAssetsAfterLoss);
        assertEq(fundsAsset.balanceOf(poolB),          0);
        assertEq(fundsAsset.balanceOf(poolC),          poolCAssetsAfterLoss);
        assertEq(fundsAsset.balanceOf(strategyX),      strategyXAvailableAfterRedemption);
        assertEq(fundsAsset.balanceOf(strategyY),      strategyYAvailableAfterRedemption);
        assertEq(fundsAsset.balanceOf(managedWallet),  strategyDeployment);
        assertEq(fundsAsset.balanceOf(managedWalletY), strategyDeployment);

        /**********************************************************************************************************************************/
        /*** Remove the second impairments and restore value only to Pool B                                                             ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        IAllocationStrategy(strategyX).removeImpairment(secondImpairmentX);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssetsAfterLoss,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolAAssetsAfterLoss
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBAssetsAfterLossX + poolBAssetsAfterLossY,
            totalSupply:        poolBFunding,
            unrealizedLosses:   secondImpairmentY,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolC,
            totalAssets:        poolCAssetsAfterLoss,
            totalSupply:        poolCFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolCAssetsAfterLoss
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding), poolAAssetsAfterLoss);
        assertEq(
            IPool(poolB).convertToExitAssets(poolBFunding),
            poolBAssetsAfterLossX + poolBAssetsAfterLossY - secondImpairmentY
        );
        assertEq(IPool(poolC).convertToExitAssets(poolCFunding), poolCAssetsAfterLoss);

        assertEq(IStrategyManager(strategyManagerX).unrealizedLosses(), 0);
        assertEq(IStrategyManager(strategyManagerY).unrealizedLosses(), secondImpairmentY);

        vm.prank(strategyDelegateY);
        IAllocationStrategy(strategyY).removeImpairment(secondImpairmentY);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssetsAfterLoss,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolAAssetsAfterLoss
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBAssetsAfterLossX + poolBAssetsAfterLossY,
            totalSupply:        poolBFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolC,
            totalAssets:        poolCAssetsAfterLoss,
            totalSupply:        poolCFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolCAssetsAfterLoss
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding), poolAAssetsAfterLoss);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding), poolBAssetsAfterLossX + poolBAssetsAfterLossY);
        assertEq(IPool(poolC).convertToExitAssets(poolCFunding), poolCAssetsAfterLoss);

        assertStrategyManager({
            strategyManager:       strategyManagerX,
            totalShares:           poolBStrategyXFunding,
            totalPendingShares:    0,
            assetsUnderManagement: poolBAssetsAfterLossX,
            availableToWithdraw:   strategyXAvailableAfterRedemption,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerX,
            poolManager:      poolManagerB,
            assets:           poolBAssetsAfterLossX,
            shares:           poolBStrategyXFunding,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       strategyManagerY,
            totalShares:           poolBStrategyYFunding,
            totalPendingShares:    0,
            assetsUnderManagement: poolBAssetsAfterLossY,
            availableToWithdraw:   strategyYAvailableAfterRedemption,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerY,
            poolManager:      poolManagerB,
            assets:           poolBAssetsAfterLossY,
            shares:           poolBStrategyYFunding,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    strategyX,
            assetsUnderManagement: poolBAssetsAfterLossX,
            availableToWithdraw:   strategyXAvailableAfterRedemption,
            recordedAssets:        strategyXAvailableAfterRedemption,
            totalDeployedAssets:   strategyDeployment - firstLossX,
            unrealizedLosses:      0
        });

        assertAllocationStrategy({
            allocationStrategy:    strategyY,
            assetsUnderManagement: poolBAssetsAfterLossY,
            availableToWithdraw:   strategyYAvailableAfterRedemption,
            recordedAssets:        strategyYAvailableAfterRedemption,
            totalDeployedAssets:   strategyDeployment - firstLossY,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(strategyX).impairedAssets(), 0);
        assertEq(IAllocationStrategy(strategyY).impairedAssets(), 0);

        assertEq(IAllocationStrategy(strategyX).deployedAssetsOf(managedWallet),  strategyDeployment - firstLossX);
        assertEq(IAllocationStrategy(strategyY).deployedAssetsOf(managedWalletY), strategyDeployment - firstLossY);

        assertEq(fundsAsset.balanceOf(poolA),          poolAAssetsAfterLoss);
        assertEq(fundsAsset.balanceOf(poolB),          0);
        assertEq(fundsAsset.balanceOf(poolC),          poolCAssetsAfterLoss);
        assertEq(fundsAsset.balanceOf(strategyX),      strategyXAvailableAfterRedemption);
        assertEq(fundsAsset.balanceOf(strategyY),      strategyYAvailableAfterRedemption);
        assertEq(fundsAsset.balanceOf(managedWallet),  strategyDeployment);
        assertEq(fundsAsset.balanceOf(managedWalletY), strategyDeployment);

        /**********************************************************************************************************************************/
        /*** Recognize more losses on X and Y and leave only Pool B with reduced value                                                  ***/
        /**********************************************************************************************************************************/

        recognizeLoss(strategyX, managedWallet, secondLossX);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssetsAfterLoss,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolAAssetsAfterLoss
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        finalPoolBAssetsX + poolBAssetsAfterLossY,
            totalSupply:        poolBFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolC,
            totalAssets:        poolCAssetsAfterLoss,
            totalSupply:        poolCFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolCAssetsAfterLoss
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding), poolAAssetsAfterLoss);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding), finalPoolBAssetsX + poolBAssetsAfterLossY);
        assertEq(IPool(poolC).convertToExitAssets(poolCFunding), poolCAssetsAfterLoss);

        assertEq(IStrategyManager(strategyManagerX).assetsUnderManagement(), finalPoolBAssetsX);
        assertEq(IStrategyManager(strategyManagerY).assetsUnderManagement(), poolBAssetsAfterLossY);

        recognizeLoss(strategyY, managedWalletY, secondLossY);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssetsAfterLoss,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolAAssetsAfterLoss
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        finalPoolBAssetsX + finalPoolBAssetsY,
            totalSupply:        poolBFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolC,
            totalAssets:        poolCAssetsAfterLoss,
            totalSupply:        poolCFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolCAssetsAfterLoss
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding), poolAAssetsAfterLoss);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding), finalPoolBAssetsX + finalPoolBAssetsY);
        assertEq(IPool(poolC).convertToExitAssets(poolCFunding), poolCAssetsAfterLoss);

        assertStrategyManager({
            strategyManager:       strategyManagerX,
            totalShares:           poolBStrategyXFunding,
            totalPendingShares:    0,
            assetsUnderManagement: finalPoolBAssetsX,
            availableToWithdraw:   strategyXAvailableAfterRedemption,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerX,
            poolManager:      poolManagerA,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerX,
            poolManager:      poolManagerB,
            assets:           finalPoolBAssetsX,
            shares:           poolBStrategyXFunding,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerX,
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    strategyX,
            assetsUnderManagement: finalPoolBAssetsX,
            availableToWithdraw:   strategyXAvailableAfterRedemption,
            recordedAssets:        strategyXAvailableAfterRedemption,
            totalDeployedAssets:   strategyDeployment - firstLossX - secondLossX,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManagerY,
            totalShares:           poolBStrategyYFunding,
            totalPendingShares:    0,
            assetsUnderManagement: finalPoolBAssetsY,
            availableToWithdraw:   strategyYAvailableAfterRedemption,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerY,
            poolManager:      poolManagerB,
            assets:           finalPoolBAssetsY,
            shares:           poolBStrategyYFunding,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerY,
            poolManager:      poolManagerC,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerY,
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    strategyY,
            assetsUnderManagement: finalPoolBAssetsY,
            availableToWithdraw:   strategyYAvailableAfterRedemption,
            recordedAssets:        strategyYAvailableAfterRedemption,
            totalDeployedAssets:   strategyDeployment - firstLossY - secondLossY,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(strategyX).impairedAssets(),                 0);
        assertEq(IAllocationStrategy(strategyX).deployedAssetsOf(managedWallet),  strategyDeployment - firstLossX - secondLossX);
        assertEq(IAllocationStrategy(strategyY).impairedAssets(),                 0);
        assertEq(IAllocationStrategy(strategyY).deployedAssetsOf(managedWalletY), strategyDeployment - firstLossY - secondLossY);

        assertEq(fundsAsset.balanceOf(poolA),          poolAAssetsAfterLoss);
        assertEq(fundsAsset.balanceOf(poolB),          0);
        assertEq(fundsAsset.balanceOf(poolC),          poolCAssetsAfterLoss);
        assertEq(fundsAsset.balanceOf(strategyX),      strategyXAvailableAfterRedemption);
        assertEq(fundsAsset.balanceOf(strategyY),      strategyYAvailableAfterRedemption);
        assertEq(fundsAsset.balanceOf(managedWallet),  strategyDeployment);
        assertEq(fundsAsset.balanceOf(managedWalletY), strategyDeployment);

        /**********************************************************************************************************************************/
        /*** Remove X from Pool A and Y from Pool C                                                                                     ***/
        /**********************************************************************************************************************************/

        removeStrategyManager(poolManagerA, strategyManagerX);
        removeStrategyManager(poolManagerC, strategyManagerY);

        assertEq(IPoolManager(poolManagerA).strategyListLength(),                1);
        assertEq(IPoolManager(poolManagerA).isStrategyManager(strategyManagerX), false);
        assertEq(IPoolManager(poolManagerA).isStrategyManager(strategyManagerY), false);

        assertEq(IPoolManager(poolManagerB).strategyListLength(),                3);
        assertEq(IPoolManager(poolManagerB).strategyList(1),                     strategyManagerX);
        assertEq(IPoolManager(poolManagerB).strategyList(2),                     strategyManagerY);
        assertEq(IPoolManager(poolManagerB).isStrategyManager(strategyManagerX), true);
        assertEq(IPoolManager(poolManagerB).isStrategyManager(strategyManagerY), true);

        assertEq(IPoolManager(poolManagerC).strategyListLength(),                1);
        assertEq(IPoolManager(poolManagerC).isStrategyManager(strategyManagerX), false);
        assertEq(IPoolManager(poolManagerC).isStrategyManager(strategyManagerY), false);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssetsAfterLoss,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolAAssetsAfterLoss
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        finalPoolBAssetsX + finalPoolBAssetsY,
            totalSupply:        poolBFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolC,
            totalAssets:        poolCAssetsAfterLoss,
            totalSupply:        poolCFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolCAssetsAfterLoss
        });

        assertEq(IPool(poolA).convertToExitAssets(poolAFunding), poolAAssetsAfterLoss);
        assertEq(IPool(poolB).convertToExitAssets(poolBFunding), finalPoolBAssetsX + finalPoolBAssetsY);
        assertEq(IPool(poolC).convertToExitAssets(poolCFunding), poolCAssetsAfterLoss);
    }

}
