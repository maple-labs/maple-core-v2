// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IAllocationStrategy, IPool, IStrategyManager } from "../../../contracts/interfaces/Interfaces.sol";

import { AllocationStrategyTestBase } from "./AllocationStrategyTestBase.sol";

contract AllocationStrategyRecognizeLossAndRemoveImpairmentFailureTests is AllocationStrategyTestBase {

    uint256 assetsLost        = 100_000e6;
    uint256 assetsUnimpaired  = 100_000e6;
    uint256 impairment        = 250_000e6;
    uint256 initialAssets     = 1_000_000e6;
    uint256 initialDeployment = 400_000e6;

    function setUp() public virtual override {
        super.setUp();

        deposit(lp, initialAssets);
        fundStrategyManager(address(poolManager), allocationStrategyManager, initialAssets);
        deployAssets(allocationUnderlyingStrategy, managedWallet, initialDeployment);
        impairAllocationStrategy(allocationUnderlyingStrategy, impairment);
    }

    function test_recognizeLossAndRemoveImpairment_revert_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:PAUSED");
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(assetsLost, assetsUnimpaired, managedWallet);
    }

    function test_recognizeLossAndRemoveImpairment_revert_contractPaused() external {
        vm.prank(governor);
        globals.setContractPause(allocationUnderlyingStrategy, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:PAUSED");
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(assetsLost, assetsUnimpaired, managedWallet);
    }

    function test_recognizeLossAndRemoveImpairment_revert_notAuthorized() external {
        address notAdmin = makeAddr("notAdmin");

        vm.prank(notAdmin);
        vm.expectRevert("MAS:NOT_AUTHORIZED");
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(assetsLost, assetsUnimpaired, managedWallet);
    }

    function test_recognizeLossAndRemoveImpairment_revert_notAuthorized_managedWallet() external {
        vm.prank(managedWallet);
        vm.expectRevert("MAS:NOT_AUTHORIZED");
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(assetsLost, assetsUnimpaired, managedWallet);
    }

    function test_recognizeLossAndRemoveImpairment_revert_notAuthorized_governor() external {
        vm.prank(governor);
        vm.expectRevert("MAS:NOT_AUTHORIZED");
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(assetsLost, assetsUnimpaired, managedWallet);
    }

    function test_recognizeLossAndRemoveImpairment_revert_notAuthorized_securityAdmin() external {
        vm.prank(securityAdmin);
        vm.expectRevert("MAS:NOT_AUTHORIZED");
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(assetsLost, assetsUnimpaired, managedWallet);
    }

    function test_recognizeLossAndRemoveImpairment_revert_zeroAssetsLost() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:RL:ZERO_ASSETS");
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(0, assetsUnimpaired, managedWallet);
    }

    function test_recognizeLossAndRemoveImpairment_revert_exceedsDeployed() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:RL:EXCEEDS_DEPLOYED");
        IAllocationStrategy(allocationUnderlyingStrategy)
            .recognizeLossAndRemoveImpairment(initialDeployment + 1, assetsUnimpaired, managedWallet);
    }

    function test_recognizeLossAndRemoveImpairment_revert_deployerNeverDeployed() external {
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(lp), 0);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:RL:EXCEEDS_DEPLOYED");
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(1, assetsUnimpaired, lp);
    }

    function test_recognizeLossAndRemoveImpairment_revert_afterFullLossAlreadyRecognized() external {
        recognizeLoss(allocationUnderlyingStrategy, managedWallet, initialDeployment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:RL:EXCEEDS_DEPLOYED");
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(1, assetsUnimpaired, managedWallet);
    }

    function test_recognizeLossAndRemoveImpairment_revert_zeroAssetsUnimpaired() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:RI:ZERO_ASSETS");
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(assetsLost, 0, managedWallet);
    }

    function test_recognizeLossAndRemoveImpairment_revert_exceedsImpairment() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:RI:EXCEEDS_IMPAIRMENT");
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(assetsLost, impairment + 1, managedWallet);
    }

    function test_recognizeLossAndRemoveImpairment_revert_exceedsImpairment_maxConvention() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:RI:EXCEEDS_IMPAIRMENT");
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(assetsLost, type(uint256).max, managedWallet);
    }

    function test_recognizeLossAndRemoveImpairment_revert_exceedsImpairment_afterFullRemoval() external {
        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).removeImpairment(impairment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), 0);

        vm.prank(operationalAdmin);
        vm.expectRevert("MAS:RI:EXCEEDS_IMPAIRMENT");
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(assetsLost, 1, managedWallet);
    }

}

contract AllocationStrategyRecognizeLossAndRemoveImpairmentSuccessTests is AllocationStrategyTestBase {

    address attacker;
    address bootstrapManagedWallet;
    address bootstrapPool;
    address bootstrapPoolManager;
    address bootstrapStrategyDelegate;
    address bootstrapStrategyManager;
    address bootstrapUnderlyingStrategy;
    address firstPool;
    address firstPoolManager;
    address managedWallet2;
    address secondPool;
    address secondPoolManager;

    uint256 assetsLost;
    uint256 assetsOut;
    uint256 assetsUnimpaired;
    uint256 bootstrapDeployment;
    uint256 bootstrapImpairment;
    uint256 bootstrapImpairmentRemoval;
    uint256 bootstrapLossAmount;
    uint256 bootstrapMint;
    uint256 bootstrapPoolAssets;
    uint256 bootstrapPoolExitAssets;
    uint256 bootstrapPoolGrossAssets;
    uint256 bootstrapPoolShares;
    uint256 bootstrapPoolUnrealizedLoss;
    uint256 bootstrapPositionAssets;
    uint256 bootstrapPositionExitAssets;
    uint256 bootstrapPositionUnrealizedLoss;
    uint256 bootstrapRecordedAssets;
    uint256 bootstrapRemainingImpairment;
    uint256 bootstrapTotalAssets;
    uint256 bootstrapTotalShares;
    uint256 delegateFee;
    uint256 deployerImpairmentRemoval;
    uint256 donation;
    uint256 elapsedDuration;
    uint256 firstAssets;
    uint256 firstExitAssets;
    uint256 firstShares;
    uint256 firstUnrealizedLoss;
    uint256 impairment;
    uint256 initialAssets;
    uint256 initialDeployment;
    uint256 initialExitAssets;
    uint256 initialShares;
    uint256 netYield;
    uint256 protocolFee;
    uint256 realizedYield;
    uint256 remainingImpairment;
    uint256 secondAssets;
    uint256 secondDeployment;
    uint256 secondExitAssets;
    uint256 secondFund;
    uint256 secondShares;
    uint256 secondUnrealizedLoss;
    uint256 sharesToRedeem;
    uint256 splitAmount;
    uint256 totalAssets;
    uint256 totalShares;
    uint256 yieldAssets;

    uint32 delegateFeeRate;
    uint32 protocolFeeRate;
    uint32 yieldDuration;

    function setUp() public virtual override {
        super.setUp();

        impairment        = 250_000e6;
        initialAssets     = 1_000_000e6;
        initialDeployment = 400_000e6;
        initialShares     = 1_000_000e6;

        deposit(lp, initialAssets);
        fundStrategyManager(address(poolManager), allocationStrategyManager, initialAssets);
        deployAssets(allocationUnderlyingStrategy, managedWallet, initialDeployment);
        impairAllocationStrategy(allocationUnderlyingStrategy, impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   impairment,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairment
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                impairment);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), initialAssets - impairment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);
    }

    function test_recognizeLossAndRemoveImpairment_success_withPendingRedemption() external {
        assetsLost        = 200_000e6;
        assetsOut         = 325_000e6;
        assetsUnimpaired  = 100_000e6;
        initialExitAssets = 375_000e6;
        sharesToRedeem    = 500_000e6;

        /**********************************************************************************************************************************/
        /*** Request half of the strategy manager position while the strategy is impaired                                               ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), allocationStrategyManager, sharesToRedeem);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   impairment,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    sharesToRedeem,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    sharesToRedeem,
            unrealizedLosses: impairment
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairment
        });

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(sharesToRedeem), initialExitAssets);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                impairment);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(allocationStrategyManager),    0);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);

        /**********************************************************************************************************************************/
        /*** Recognize a loss and remove impairment while the redemption remains pending                                                ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(assetsLost, assetsUnimpaired, managedWallet);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets - assetsLost,
            totalSupply:        initialShares,
            unrealizedLosses:   impairment - assetsUnimpaired,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    sharesToRedeem,
            assetsUnderManagement: initialAssets - assetsLost,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      impairment - assetsUnimpaired
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets - assetsLost,
            shares:           initialShares,
            pendingShares:    sharesToRedeem,
            unrealizedLosses: impairment - assetsUnimpaired
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets - assetsLost,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment - assetsLost,
            unrealizedLosses:      impairment - assetsUnimpaired
        });

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(sharesToRedeem), assetsOut);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                impairment - assetsUnimpaired);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - assetsLost);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(allocationStrategyManager),    0);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);

        /**********************************************************************************************************************************/
        /*** Process the pending shares at the updated exit value                                                                       ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), allocationStrategyManager, sharesToRedeem);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets - assetsLost,
            totalSupply:        initialShares,
            unrealizedLosses:   impairment - assetsUnimpaired,
            availableLiquidity: assetsOut
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares - sharesToRedeem,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets - assetsLost - assetsOut,
            availableToWithdraw:   initialAssets - initialDeployment - assetsOut,
            unrealizedLosses:      impairment - assetsUnimpaired
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets - assetsLost - assetsOut,
            shares:           initialShares - sharesToRedeem,
            pendingShares:    0,
            unrealizedLosses: impairment - assetsUnimpaired
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets - assetsLost - assetsOut,
            availableToWithdraw:   initialAssets - initialDeployment - assetsOut,
            recordedAssets:        initialAssets - initialDeployment - assetsOut,
            totalDeployedAssets:   initialDeployment - assetsLost,
            unrealizedLosses:      impairment - assetsUnimpaired
        });

        assertEq(
            IStrategyManager(allocationStrategyManager).convertToAssets(initialShares - sharesToRedeem),
            initialAssets - assetsLost - assetsOut
        );

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                impairment - assetsUnimpaired);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - assetsLost);

        assertEq(fundsAsset.balanceOf(address(pool)),                assetsOut);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment - assetsOut);
        assertEq(fundsAsset.balanceOf(allocationStrategyManager),    0);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);
    }

    function test_recognizeLossAndRemoveImpairment_success_equalAmountsAcrossAdmins() external {
        /**********************************************************************************************************************************/
        /*** Recognize a partial loss and remove an equal impairment amount via the strategy delegate                                   ***/
        /**********************************************************************************************************************************/

        uint256 firstAmount = 100_000e6;

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(firstAmount, firstAmount, managedWallet);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets - firstAmount,
            totalSupply:        initialShares,
            unrealizedLosses:   impairment - firstAmount,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets - firstAmount,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      impairment - firstAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets - firstAmount,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairment - firstAmount
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets - firstAmount,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment - firstAmount,
            unrealizedLosses:      impairment - firstAmount
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), impairment - firstAmount);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - firstAmount);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), initialAssets - impairment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);

        /**********************************************************************************************************************************/
        /*** Repeat via the operational admin: both changes accumulate on top of the first                                              ***/
        /**********************************************************************************************************************************/

        uint256 secondAmount = 50_000e6;

        vm.prank(operationalAdmin);
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(secondAmount, secondAmount, managedWallet);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets - firstAmount - secondAmount,
            totalSupply:        initialShares,
            unrealizedLosses:   impairment - firstAmount - secondAmount,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets - firstAmount - secondAmount,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      impairment - firstAmount - secondAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets - firstAmount - secondAmount,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairment - firstAmount - secondAmount
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets - firstAmount - secondAmount,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment - firstAmount - secondAmount,
            unrealizedLosses:      impairment - firstAmount - secondAmount
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), impairment - firstAmount - secondAmount);

        assertEq(
            IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet),
            initialDeployment - firstAmount - secondAmount
        );

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), initialAssets - impairment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);
    }

    function test_recognizeLossAndRemoveImpairment_success_lossExceedsRemoval() external {
        /**********************************************************************************************************************************/
        /*** Recognize a loss larger than the impairment removal                                                                        ***/
        /**********************************************************************************************************************************/

        uint256 impairmentAmount = 100_000e6;
        uint256 lossAmount       = 150_000e6;

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(lossAmount, impairmentAmount, managedWallet);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets - lossAmount,
            totalSupply:        initialShares,
            unrealizedLosses:   impairment - impairmentAmount,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets - lossAmount,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      impairment - impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets - lossAmount,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairment - impairmentAmount
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets - lossAmount,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment - lossAmount,
            unrealizedLosses:      impairment - impairmentAmount
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), impairment - impairmentAmount);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - lossAmount);

        assertEq(
            IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares),
            initialAssets - impairment - lossAmount + impairmentAmount
        );

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);
    }

    function test_recognizeLossAndRemoveImpairment_success_removalExceedsLoss() external {
        /**********************************************************************************************************************************/
        /*** Recognize a loss smaller than the impairment removal                                                                       ***/
        /**********************************************************************************************************************************/

        uint256 impairmentAmount = 150_000e6;
        uint256 lossAmount       = 100_000e6;

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(lossAmount, impairmentAmount, managedWallet);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets - lossAmount,
            totalSupply:        initialShares,
            unrealizedLosses:   impairment - impairmentAmount,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets - lossAmount,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      impairment - impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets - lossAmount,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairment - impairmentAmount
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets - lossAmount,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment - lossAmount,
            unrealizedLosses:      impairment - impairmentAmount
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), impairment - impairmentAmount);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - lossAmount);

        assertEq(
            IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares),
            initialAssets - impairment - lossAmount + impairmentAmount
        );

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);
    }

    function test_recognizeLossAndRemoveImpairment_success_withScheduledYield() external {
        /**********************************************************************************************************************************/
        /*** Schedule yield and warp partway through it                                                                                 ***/
        /**********************************************************************************************************************************/

        delegateFeeRate = 0.02e6; // 2%
        protocolFeeRate = 0.03e6; // 3%
        yieldAssets     = 50_000e6;
        yieldDuration   = 31 days;

        delegateFee = yieldAssets * delegateFeeRate / 1e6;
        protocolFee = yieldAssets * protocolFeeRate / 1e6;
        netYield    = yieldAssets - delegateFee - protocolFee;

        setStrategyDelegateFeeRate(allocationUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(allocationUnderlyingStrategy, protocolFeeRate);
        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        elapsedDuration = 10 days;
        realizedYield   = netYield * elapsedDuration / yieldDuration;

        vm.warp(startingTime + elapsedDuration);

        /**********************************************************************************************************************************/
        /*** Recognize a loss and remove impairment while yield is vesting: the yield schedule and accrued fees are unaffected          ***/
        /**********************************************************************************************************************************/

        uint256 impairmentRemoval = 75_000e6;
        uint256 lossAmount        = 100_000e6;

        remainingImpairment = impairment - impairmentRemoval;
        totalAssets         = initialAssets + realizedYield - lossAmount;

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(lossAmount, impairmentRemoval, managedWallet);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        totalAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   remainingImpairment,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            unrealizedLosses:      remainingImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           totalAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: remainingImpairment
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   initialAssets - initialDeployment + realizedYield,
            recordedAssets:        initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment - lossAmount,
            unrealizedLosses:      remainingImpairment
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedYield
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), remainingImpairment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - lossAmount);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), totalAssets - remainingImpairment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_recognizeLossAndRemoveImpairment_success_donationDoesNotInflateAum() external {
        /**********************************************************************************************************************************/
        /*** An external actor donates raw assets directly to the strategy, bypassing deployAssets()/returnAssets()                     ***/
        /**********************************************************************************************************************************/

        attacker = makeAddr("attacker");
        donation = 500_000e6;

        erc20_mint(address(fundsAsset), attacker, donation);

        vm.prank(attacker);
        fundsAsset.transfer(allocationUnderlyingStrategy, donation);

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      impairment
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).unrecordedAssets(), donation);

        /**********************************************************************************************************************************/
        /*** Recognize a loss and remove impairment: the donation remains unrecorded and does not inflate AUM                           ***/
        /**********************************************************************************************************************************/

        uint256 impairmentRemoval = 50_000e6;
        uint256 lossAmount        = 100_000e6;

        remainingImpairment = impairment - impairmentRemoval;
        totalAssets         = initialAssets - lossAmount;

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(lossAmount, impairmentRemoval, managedWallet);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        totalAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   remainingImpairment,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      remainingImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           totalAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: remainingImpairment
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment - lossAmount,
            unrealizedLosses:      remainingImpairment
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),   remainingImpairment);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).unrecordedAssets(), donation);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - lossAmount);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), totalAssets - remainingImpairment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + donation);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);
    }

    function test_recognizeLossAndRemoveImpairment_success_totalAmounts() external {
        /**********************************************************************************************************************************/
        /*** Recognize the entire deployed position as lost and remove the entire impairment                                            ***/
        /**********************************************************************************************************************************/

        vm.prank(operationalAdmin);
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(initialDeployment, impairment, managedWallet);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets - initialDeployment,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets - initialDeployment,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets - initialDeployment,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets - initialDeployment,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), initialAssets - initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);
    }

    function test_recognizeLossAndRemoveImpairment_success_clampsRemainingImpairmentToReducedAum() external {
        /**********************************************************************************************************************************/
        /*** Impair for the full AUM                                                                                                    ***/
        /**********************************************************************************************************************************/

        uint256 additionalImpairment = initialAssets - impairment;

        impairAllocationStrategy(allocationUnderlyingStrategy, additionalImpairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   initialAssets,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      initialAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: initialAssets
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      initialAssets
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), initialAssets);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);

        /**********************************************************************************************************************************/
        /*** Recognize the entire deployment as lost while removing too little impairment to release the AUM clamp                      ***/
        /**********************************************************************************************************************************/

        uint256 impairmentRemoval = 350_000e6;
        uint256 reducedAum        = initialAssets - initialDeployment;
        uint256 storedImpairment  = initialAssets - impairmentRemoval;

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy)
            .recognizeLossAndRemoveImpairment(initialDeployment, impairmentRemoval, managedWallet);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        reducedAum,
            totalSupply:        initialShares,
            unrealizedLosses:   reducedAum,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: reducedAum,
            availableToWithdraw:   reducedAum,
            unrealizedLosses:      reducedAum
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           reducedAum,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: reducedAum
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: reducedAum,
            availableToWithdraw:   reducedAum,
            recordedAssets:        reducedAum,
            totalDeployedAssets:   0,
            unrealizedLosses:      reducedAum
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), storedImpairment);
        assertGt(storedImpairment, reducedAum);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);
    }

    function test_recognizeLossAndRemoveImpairment_success_aumGrowthReleasesClamp() external {
        /**********************************************************************************************************************************/
        /*** Impair beyond the AUM so unrealized losses clamp to the AUM                                                                ***/
        /**********************************************************************************************************************************/

        uint256 additionalImpairment = 900_000e6;
        uint256 impairmentRemoval    = 100_000e6;
        uint256 lossAmount           = 100_000e6;
        uint256 yieldAmount          = 200_000e6;

        uint256 storedImpairment = impairment + additionalImpairment;

        impairAllocationStrategy(allocationUnderlyingStrategy, additionalImpairment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),   storedImpairment);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).unrealizedLosses(), initialAssets);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), 0);

        /**********************************************************************************************************************************/
        /*** Realize yield instantly so AUM grows above the stored impairment and releases the clamp                                    ***/
        /**********************************************************************************************************************************/

        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAmount, 0);

        uint256 aumAfterYield = initialAssets + yieldAmount;

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).assetsUnderManagement(), aumAfterYield);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).unrealizedLosses(),      storedImpairment);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), aumAfterYield - storedImpairment);

        /**********************************************************************************************************************************/
        /*** Recognize a loss and remove impairment after the clamp has released                                                        ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(lossAmount, impairmentRemoval, managedWallet);

        uint256 finalAum        = aumAfterYield - lossAmount;
        uint256 finalImpairment = storedImpairment - impairmentRemoval;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        finalAum,
            totalSupply:        initialShares,
            unrealizedLosses:   finalImpairment,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: finalAum,
            availableToWithdraw:   initialAssets - initialDeployment + yieldAmount,
            unrealizedLosses:      finalImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           finalAum,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: finalImpairment
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: finalAum,
            availableToWithdraw:   initialAssets - initialDeployment + yieldAmount,
            recordedAssets:        initialAssets - initialDeployment + yieldAmount,
            totalDeployedAssets:   initialDeployment - lossAmount,
            unrealizedLosses:      finalImpairment
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: yieldAmount,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime,
            yieldLastRealized:    startingTime,
            realizedYield:        yieldAmount
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), finalImpairment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - lossAmount);

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares), finalAum - finalImpairment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + yieldAmount);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);
    }

    function test_recognizeLossAndRemoveImpairment_success_multipleDeployersIndependent() external {
        /**********************************************************************************************************************************/
        /*** Onboard a second managed wallet and deploy assets to it                                                                    ***/
        /**********************************************************************************************************************************/

        managedWallet2 = makeAddr("managedWallet2");

        setManagedWallet({
            strategy_:        allocationUnderlyingStrategy,
            managedWallet_:   managedWallet2,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   type(uint256).max
        });

        secondDeployment = 200_000e6;

        deployAssets(allocationUnderlyingStrategy, managedWallet2, secondDeployment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet),  initialDeployment);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet2), secondDeployment);

        /**********************************************************************************************************************************/
        /*** Recognize a loss against the first deployer and remove impairment: the second deployer's books are untouched               ***/
        /**********************************************************************************************************************************/

        deployerImpairmentRemoval = 100_000e6;
        splitAmount               = 150_000e6;

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy)
            .recognizeLossAndRemoveImpairment(splitAmount, deployerImpairmentRemoval, managedWallet);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets - splitAmount,
            totalSupply:        initialShares,
            unrealizedLosses:   impairment - deployerImpairmentRemoval,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets - splitAmount,
            availableToWithdraw:   initialAssets - initialDeployment - secondDeployment,
            unrealizedLosses:      impairment - deployerImpairmentRemoval
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets - splitAmount,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairment - deployerImpairmentRemoval
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets - splitAmount,
            availableToWithdraw:   initialAssets - initialDeployment - secondDeployment,
            recordedAssets:        initialAssets - initialDeployment - secondDeployment,
            totalDeployedAssets:   initialDeployment + secondDeployment - splitAmount,
            unrealizedLosses:      impairment - deployerImpairmentRemoval
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), impairment - deployerImpairmentRemoval);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - splitAmount);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet2), secondDeployment);

        assertEq(
            IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares),
            initialAssets - impairment - splitAmount + deployerImpairmentRemoval
        );

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment - secondDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet2),               secondDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);
    }

    function test_recognizeLossAndRemoveImpairment_success_afterPermissionsRevoked() external {
        /**********************************************************************************************************************************/
        /*** Revoke the managed wallet's permissions entirely, e.g. after it is found to be compromised                                 ***/
        /**********************************************************************************************************************************/

        (bool canDeployAssets_, bool canReturnAssets_, bool canRealizeYield_) =
            IAllocationStrategy(allocationUnderlyingStrategy).permissions(managedWallet);

        assertTrue(canDeployAssets_);
        assertTrue(canReturnAssets_);
        assertTrue(canRealizeYield_);

        address[] memory accounts        = new address[](1);
        bool[] memory    canDeployAssets = new bool[](1);
        bool[] memory    canReturnAssets = new bool[](1);
        bool[] memory    canRealizeYield = new bool[](1);

        accounts[0] = managedWallet;

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).setPermissions(accounts, canDeployAssets, canReturnAssets, canRealizeYield);

        (canDeployAssets_, canReturnAssets_, canRealizeYield_) =
            IAllocationStrategy(allocationUnderlyingStrategy).permissions(managedWallet);

        assertFalse(canDeployAssets_);
        assertFalse(canReturnAssets_);
        assertFalse(canRealizeYield_);

        /**********************************************************************************************************************************/
        /*** Recognize a loss against the revoked wallet and remove impairment                                                          ***/
        /**********************************************************************************************************************************/

        uint256 impairmentRemoval = 100_000e6;
        uint256 lossAmount        = 150_000e6;

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(lossAmount, impairmentRemoval, managedWallet);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets - lossAmount,
            totalSupply:        initialShares,
            unrealizedLosses:   impairment - impairmentRemoval,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets - lossAmount,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      impairment - impairmentRemoval
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets - lossAmount,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: impairment - impairmentRemoval
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets - lossAmount,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment - lossAmount,
            unrealizedLosses:      impairment - impairmentRemoval
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), impairment - impairmentRemoval);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - lossAmount);

        assertEq(
            IStrategyManager(allocationStrategyManager).convertToExitAssets(initialShares),
            initialAssets - impairment - lossAmount + impairmentRemoval
        );

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);
    }

    function test_recognizeLossAndRemoveImpairment_success_splitsAcrossPoolManagers() external {
        /**********************************************************************************************************************************/
        /*** Set up a second pool sharing the strategy                                                                                  ***/
        /**********************************************************************************************************************************/

        firstPool        = address(pool);
        firstPoolManager = address(poolManager);
        firstShares      = initialShares;

        (secondPool, secondPoolManager) = _createPoolSharingStrategy("secondPoolDelegate", allocationStrategyManager);

        secondFund   = 500_000e6;
        secondShares = secondFund;
        totalShares  = firstShares + secondShares;

        deposit(secondPool, lp, initialAssets);
        fundStrategyManager(secondPoolManager, allocationStrategyManager, secondFund);

        firstExitAssets  = IPool(firstPool).convertToExitAssets(initialShares);
        secondExitAssets = IPool(secondPool).convertToExitAssets(initialShares);

        /**********************************************************************************************************************************/
        /*** Recognize a loss and remove impairment: both effects split proportionally across the pool managers                         ***/
        /**********************************************************************************************************************************/

        splitAmount         = 100_000e6;
        remainingImpairment = impairment - splitAmount;
        totalAssets         = initialAssets + secondFund - splitAmount;

        firstAssets  = firstShares * totalAssets / totalShares;
        secondAssets = secondShares * totalAssets / totalShares;

        firstUnrealizedLoss  = divRoundUp(firstShares * remainingImpairment, totalShares);
        secondUnrealizedLoss = divRoundUp(secondShares * remainingImpairment, totalShares);

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLossAndRemoveImpairment(splitAmount, splitAmount, managedWallet);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        firstAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   firstUnrealizedLoss,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        secondAssets + initialAssets - secondFund,
            totalSupply:        initialShares,
            unrealizedLosses:   secondUnrealizedLoss,
            availableLiquidity: initialAssets - secondFund
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   initialAssets - initialDeployment + secondFund,
            unrealizedLosses:      remainingImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstAssets,
            shares:           firstShares,
            pendingShares:    0,
            unrealizedLosses: firstUnrealizedLoss
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondAssets,
            shares:           secondShares,
            pendingShares:    0,
            unrealizedLosses: secondUnrealizedLoss
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   initialAssets - initialDeployment + secondFund,
            recordedAssets:        initialAssets - initialDeployment + secondFund,
            totalDeployedAssets:   initialDeployment - splitAmount,
            unrealizedLosses:      remainingImpairment
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(), remainingImpairment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - splitAmount);

        assertEq(IPool(firstPool).convertToExitAssets(initialShares),  firstExitAssets);
        assertEq(IPool(secondPool).convertToExitAssets(initialShares), secondExitAssets);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + secondFund);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
        assertEq(fundsAsset.balanceOf(treasury),                     0);
    }

    function test_recognizeLossAndRemoveImpairment_success_withBootstrapMint() external {
        /**********************************************************************************************************************************/
        /*** Deploy a fresh allocation strategy funded with a bootstrap mint and attach a pool                                          ***/
        /**********************************************************************************************************************************/

        bootstrapStrategyDelegate = makeAddr("bootstrapStrategyDelegate");
        bootstrapMint             = 10e6;

        (bootstrapStrategyManager, bootstrapUnderlyingStrategy) = _deployAllocationStrategy({
            strategyDelegate_:        bootstrapStrategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    type(uint256).max,
            bootstrapMint_:           bootstrapMint
        });

        (bootstrapPool, bootstrapPoolManager) = _createPoolSharingStrategy("bootstrapPoolDelegate", bootstrapStrategyManager);

        bootstrapManagedWallet = makeAddr("bootstrapManagedWallet");

        setManagedWallet({
            strategy_:        bootstrapUnderlyingStrategy,
            managedWallet_:   bootstrapManagedWallet,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   type(uint256).max
        });

        /**********************************************************************************************************************************/
        /*** Fund, deploy from, and impair the bootstrap strategy                                                                       ***/
        /**********************************************************************************************************************************/

        bootstrapPoolAssets = 1_000_000e6;
        bootstrapPoolShares = bootstrapPoolAssets;

        deposit(bootstrapPool, lp, bootstrapPoolAssets);
        fundStrategyManager(bootstrapPoolManager, bootstrapStrategyManager, bootstrapPoolAssets);

        bootstrapDeployment = 400_000e6;

        deployAssets(bootstrapUnderlyingStrategy, bootstrapManagedWallet, bootstrapDeployment);

        bootstrapImpairment = 250_000e6;

        impairAllocationStrategy(bootstrapUnderlyingStrategy, bootstrapImpairment);

        bootstrapPoolExitAssets     = IPool(bootstrapPool).convertToExitAssets(bootstrapPoolShares);
        bootstrapPositionExitAssets = IStrategyManager(bootstrapStrategyManager).convertToExitAssets(bootstrapMint);

        /**********************************************************************************************************************************/
        /*** Recognize a loss and remove impairment: both effects split across the pool and bootstrap position                          ***/
        /**********************************************************************************************************************************/

        bootstrapImpairmentRemoval = 100_000e6;
        bootstrapLossAmount        = 100_000e6;

        bootstrapRecordedAssets      = bootstrapMint + bootstrapPoolAssets - bootstrapDeployment;
        bootstrapRemainingImpairment = bootstrapImpairment - bootstrapImpairmentRemoval;
        bootstrapTotalAssets         = bootstrapMint + bootstrapPoolAssets - bootstrapLossAmount;
        bootstrapTotalShares         = bootstrapMint + bootstrapPoolShares;

        bootstrapPoolGrossAssets = bootstrapPoolShares * bootstrapTotalAssets / bootstrapTotalShares;
        bootstrapPositionAssets  = bootstrapMint * bootstrapTotalAssets / bootstrapTotalShares;

        bootstrapPoolUnrealizedLoss     = divRoundUp(bootstrapPoolShares * bootstrapRemainingImpairment, bootstrapTotalShares);
        bootstrapPositionUnrealizedLoss = divRoundUp(bootstrapMint * bootstrapRemainingImpairment, bootstrapTotalShares);

        vm.prank(bootstrapStrategyDelegate);
        IAllocationStrategy(bootstrapUnderlyingStrategy)
            .recognizeLossAndRemoveImpairment(bootstrapLossAmount, bootstrapImpairmentRemoval, bootstrapManagedWallet);

        assertPoolState({
            pool:               bootstrapPool,
            totalAssets:        bootstrapPoolGrossAssets,
            totalSupply:        bootstrapPoolShares,
            unrealizedLosses:   bootstrapPoolUnrealizedLoss,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       bootstrapStrategyManager,
            totalShares:           bootstrapTotalShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapTotalAssets,
            availableToWithdraw:   bootstrapRecordedAssets,
            unrealizedLosses:      bootstrapRemainingImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  bootstrapStrategyManager,
            poolManager:      bootstrapPoolManager,
            assets:           bootstrapPoolGrossAssets,
            shares:           bootstrapPoolShares,
            pendingShares:    0,
            unrealizedLosses: bootstrapPoolUnrealizedLoss
        });

        assertStrategyManagerPosition({
            strategyManager:  bootstrapStrategyManager,
            poolManager:      address(0),
            assets:           bootstrapPositionAssets,
            shares:           bootstrapMint,
            pendingShares:    0,
            unrealizedLosses: bootstrapPositionUnrealizedLoss
        });

        assertAllocationStrategy({
            allocationStrategy:    bootstrapUnderlyingStrategy,
            assetsUnderManagement: bootstrapTotalAssets,
            availableToWithdraw:   bootstrapRecordedAssets,
            recordedAssets:        bootstrapRecordedAssets,
            totalDeployedAssets:   bootstrapDeployment - bootstrapLossAmount,
            unrealizedLosses:      bootstrapRemainingImpairment
        });

        assertEq(IAllocationStrategy(bootstrapUnderlyingStrategy).impairedAssets(), bootstrapRemainingImpairment);

        assertEq(
            IAllocationStrategy(bootstrapUnderlyingStrategy).deployedAssetsOf(bootstrapManagedWallet),
            bootstrapDeployment - bootstrapLossAmount
        );

        assertEq(IPool(bootstrapPool).convertToExitAssets(bootstrapPoolShares), bootstrapPoolExitAssets);

        assertEq(IStrategyManager(bootstrapStrategyManager).convertToExitAssets(bootstrapMint), bootstrapPositionExitAssets);

        assertEq(fundsAsset.balanceOf(bootstrapUnderlyingStrategy), bootstrapRecordedAssets);
        assertEq(fundsAsset.balanceOf(bootstrapManagedWallet),      bootstrapDeployment);
        assertEq(fundsAsset.balanceOf(bootstrapStrategyDelegate),   0);
        assertEq(fundsAsset.balanceOf(treasury),                    0);
    }

    function test_recognizeLossAndRemoveImpairment_success_bootstrapMint_afterPoolExit() external {
        /**********************************************************************************************************************************/
        /*** Deploy a fresh allocation strategy funded with a bootstrap mint and attach two pools                                       ***/
        /**********************************************************************************************************************************/

        bootstrapStrategyDelegate = makeAddr("bootstrapStrategyDelegate");
        bootstrapManagedWallet    = makeAddr("bootstrapManagedWallet");
        bootstrapMint             = 10e6;

        (bootstrapStrategyManager, bootstrapUnderlyingStrategy) = _deployAllocationStrategy({
            strategyDelegate_:        bootstrapStrategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    type(uint256).max,
            bootstrapMint_:           bootstrapMint
        });

        (firstPool, firstPoolManager)   = _createPoolSharingStrategy("bootstrapFirstPoolDelegate", bootstrapStrategyManager);
        (secondPool, secondPoolManager) = _createPoolSharingStrategy("bootstrapSecondPoolDelegate", bootstrapStrategyManager);

        setManagedWallet({
            strategy_:        bootstrapUnderlyingStrategy,
            managedWallet_:   bootstrapManagedWallet,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   type(uint256).max
        });

        /**********************************************************************************************************************************/
        /*** Fund both pools, deploy assets, and impair the strategy                                                                    ***/
        /**********************************************************************************************************************************/

        bootstrapPoolAssets = 1_000_000e6;
        secondFund          = 500_000e6;

        bootstrapPoolShares = bootstrapPoolAssets;
        secondShares        = secondFund;

        deposit(firstPool, lp, bootstrapPoolAssets);
        deposit(secondPool, lp, secondFund);

        fundStrategyManager(firstPoolManager, bootstrapStrategyManager, bootstrapPoolAssets);
        fundStrategyManager(secondPoolManager, bootstrapStrategyManager, secondFund);

        bootstrapDeployment = 400_000e6;

        deployAssets(bootstrapUnderlyingStrategy, bootstrapManagedWallet, bootstrapDeployment);

        bootstrapImpairment = 150_000e6;

        impairAllocationStrategy(bootstrapUnderlyingStrategy, bootstrapImpairment);

        /**********************************************************************************************************************************/
        /*** First pool fully exits the strategy, taking a haircut at the impaired price                                                ***/
        /**********************************************************************************************************************************/

        bootstrapTotalAssets = bootstrapMint + bootstrapPoolAssets + secondFund;
        bootstrapTotalShares = bootstrapMint + bootstrapPoolShares + secondShares;

        bootstrapPoolExitAssets = IPool(firstPool).convertToExitAssets(bootstrapPoolShares);

        assertEq(bootstrapPoolExitAssets, bootstrapPoolShares * (bootstrapTotalAssets - bootstrapImpairment) / bootstrapTotalShares);

        requestRedeemFromStrategyManager(firstPoolManager, bootstrapStrategyManager, bootstrapPoolShares);
        processRedemptionFromStrategyManager(firstPoolManager, bootstrapStrategyManager, bootstrapPoolShares);

        bootstrapTotalAssets   -= bootstrapPoolExitAssets;
        bootstrapTotalShares   -= bootstrapPoolShares;
        bootstrapRecordedAssets = bootstrapTotalAssets - bootstrapDeployment;

        /**********************************************************************************************************************************/
        /*** Recognize a loss and remove the entire impairment: the released value stays with the remaining pool and bootstrap position ***/
        /**********************************************************************************************************************************/

        bootstrapLossAmount        = 100_000e6;
        bootstrapImpairmentRemoval = bootstrapImpairment;

        vm.prank(bootstrapStrategyDelegate);
        IAllocationStrategy(bootstrapUnderlyingStrategy)
            .recognizeLossAndRemoveImpairment(bootstrapLossAmount, bootstrapImpairmentRemoval, bootstrapManagedWallet);

        bootstrapTotalAssets   -= bootstrapLossAmount;
        secondAssets            = secondShares * bootstrapTotalAssets / bootstrapTotalShares;
        bootstrapPositionAssets = bootstrapMint * bootstrapTotalAssets / bootstrapTotalShares;

        assertPoolState({
            pool:               firstPool,
            totalAssets:        bootstrapPoolExitAssets,
            totalSupply:        bootstrapPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: bootstrapPoolExitAssets
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        secondAssets,
            totalSupply:        secondShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       bootstrapStrategyManager,
            totalShares:           bootstrapTotalShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapTotalAssets,
            availableToWithdraw:   bootstrapRecordedAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  bootstrapStrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  bootstrapStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondAssets,
            shares:           secondShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  bootstrapStrategyManager,
            poolManager:      address(0),
            assets:           bootstrapPositionAssets,
            shares:           bootstrapMint,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    bootstrapUnderlyingStrategy,
            assetsUnderManagement: bootstrapTotalAssets,
            availableToWithdraw:   bootstrapRecordedAssets,
            recordedAssets:        bootstrapRecordedAssets,
            totalDeployedAssets:   bootstrapDeployment - bootstrapLossAmount,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(bootstrapUnderlyingStrategy).impairedAssets(), 0);

        assertEq(
            IAllocationStrategy(bootstrapUnderlyingStrategy).deployedAssetsOf(bootstrapManagedWallet),
            bootstrapDeployment - bootstrapLossAmount
        );

        assertEq(IPool(firstPool).convertToExitAssets(bootstrapPoolShares), bootstrapPoolExitAssets);
        assertEq(IPool(secondPool).convertToExitAssets(secondShares),       secondAssets);

        assertEq(IStrategyManager(bootstrapStrategyManager).convertToExitAssets(secondShares), secondAssets);

        assertEq(fundsAsset.balanceOf(bootstrapUnderlyingStrategy), bootstrapRecordedAssets);
        assertEq(fundsAsset.balanceOf(bootstrapManagedWallet),      bootstrapDeployment);
        assertEq(fundsAsset.balanceOf(bootstrapStrategyDelegate),   0);
        assertEq(fundsAsset.balanceOf(treasury),                    0);
    }

}
