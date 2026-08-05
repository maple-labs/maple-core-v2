// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC20Like,
    IStrategyManager,
    ISkyStrategy
} from "../../../contracts/interfaces/Interfaces.sol";

import { SkyStrategyTestBase } from "./SkyStrategyTestBase.sol";

contract SkyStrategyRemoveImpairmentFailureTests is SkyStrategyTestBase {

    uint256 impairment = 100_000e6;

    function testFork_removeImpairment_failWhenProtocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:PAUSED");
        ISkyStrategy(skyUnderlyingStrategy).removeImpairment(impairment);
    }

    function testFork_removeImpairment_failWhenStrategyPaused() external {
        vm.prank(governor);
        globals.setContractPause(skyUnderlyingStrategy, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:PAUSED");
        ISkyStrategy(skyUnderlyingStrategy).removeImpairment(impairment);
    }

    function testFork_removeImpairment_failWhenNotAdmin() external {
        vm.prank(governor);
        vm.expectRevert("MSS:NOT_AUTHORIZED");
        ISkyStrategy(skyUnderlyingStrategy).removeImpairment(impairment);
    }

    function testFork_removeImpairment_failWhenLossRecognized() external {
        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:LOSS_RECOGNIZED");
        ISkyStrategy(skyUnderlyingStrategy).removeImpairment(impairment);
    }

    function testFork_removeImpairment_failWithZeroAssets() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:RI:ZERO");
        ISkyStrategy(skyUnderlyingStrategy).removeImpairment(0);
    }

    function testFork_removeImpairment_failWhenExceedingImpairment() external {
        impairStrategy(skyUnderlyingStrategy, impairment);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:RI:EXCEEDS_IMPAIRMENT");
        ISkyStrategy(skyUnderlyingStrategy).removeImpairment(impairment + 1);
    }

}

contract SkyStrategyRemoveImpairmentTests is SkyStrategyTestBase {

    uint256 expectedRoundingLoss = 1;

    // `bootstrapMint` is the funds asset amount supplied at deployment, while `bootstrapAssets` is the resulting
    // strategy position after the Sky conversion rounding loss.
    uint256 bootstrapMint     = 100_000e6;
    uint256 bootstrapAssets   = 100_000e6 - expectedRoundingLoss;
    uint256 bootstrapShares   = 100_000e6 - expectedRoundingLoss;
    uint256 fundAmount        = 500_000e6;
    uint256 firstPoolShares   = 500_000e6;
    uint256 impairment        = 250_000e6;
    uint256 impairmentRemoval = 100_000e6;
    uint256 poolLiquidity     = 1_000_000e6;
    uint256 poolShares        = 1_000_000e6;
    uint256 strategyAssets    = 500_000e6 - expectedRoundingLoss;
    uint256 strategyShares    = 500_000e6 - expectedRoundingLoss;
    uint256 secondFundAmount  = 450_000e6;
    uint256 secondFundShares  = 450_000e6;

    function setUp() public override {
        super.setUp();

        deposit(lp, poolLiquidity);
        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);
    }

    function testFork_removeImpairment_acrossAllAdmins() external {
        uint256 remainingImpairment = impairment - impairmentRemoval;  // 150k.

        /**********************************************************************************************************************************/
        /*** Impair the strategy                                                                                                        ***/
        /**********************************************************************************************************************************/

        impairStrategy(skyUnderlyingStrategy, impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolShares,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          impairment,
            lastRecordedTotalAssets: strategyAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              strategyAssets,
            unrealizedLosses: impairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: strategyAssets,
            availableToWithdraw:   strategyAssets,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssets,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        /**********************************************************************************************************************************/
        /*** Remove part of the impairment as the operational admin                                                                     ***/
        /**********************************************************************************************************************************/

        vm.prank(operationalAdmin);
        ISkyStrategy(skyUnderlyingStrategy).removeImpairment(impairmentRemoval);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolShares,
            unrealizedLosses:   remainingImpairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          remainingImpairment,
            lastRecordedTotalAssets: strategyAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              strategyAssets,
            unrealizedLosses: remainingImpairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: strategyAssets,
            availableToWithdraw:   strategyAssets,
            unrealizedLosses:      remainingImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssets,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: remainingImpairment
        });

        /**********************************************************************************************************************************/
        /*** Remove the remaining impairment as the strategy delegate                                                                   ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).removeImpairment(remainingImpairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: strategyAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              strategyAssets,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: strategyAssets,
            availableToWithdraw:   strategyAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssets,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_removeImpairment_restoresStrategyManagerExitAssets() external {
        uint256 initialExitAssets = IStrategyManager(skyStrategyManager).convertToExitAssets(strategyShares);

        assertEq(initialExitAssets, strategyAssets);

        /**********************************************************************************************************************************/
        /*** Impair the strategy and reduce the exit assets                                                                             ***/
        /**********************************************************************************************************************************/

        impairStrategy(skyUnderlyingStrategy, impairment);

        uint256 impairedExitAssets = IStrategyManager(skyStrategyManager).convertToExitAssets(strategyShares);

        assertEq(impairedExitAssets, strategyAssets - impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolShares,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          impairment,
            lastRecordedTotalAssets: strategyAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              strategyAssets,
            unrealizedLosses: impairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: strategyAssets,
            availableToWithdraw:   strategyAssets,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssets,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        /**********************************************************************************************************************************/
        /*** Remove the impairment and restore the exit assets                                                                          ***/
        /**********************************************************************************************************************************/

        removeStrategyImpairment(skyUnderlyingStrategy, impairment);

        uint256 restoredExitAssets = IStrategyManager(skyStrategyManager).convertToExitAssets(strategyShares);

        assertEq(restoredExitAssets, initialExitAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: strategyAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              strategyAssets,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: strategyAssets,
            availableToWithdraw:   strategyAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssets,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_removeImpairment_restoresPendingRedemptionExitAssets() external {
        uint256 redemptionShares          = 100_000e6;
        uint256 expectedInitialExitAssets = strategyAssets * redemptionShares / strategyShares;

        /**********************************************************************************************************************************/
        /*** Request a redemption                                                                                                       ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), skyStrategyManager, redemptionShares);

        uint256 initialExitAssets = IStrategyManager(skyStrategyManager).convertToExitAssets(redemptionShares);

        assertEq(initialExitAssets, expectedInitialExitAssets);

        /**********************************************************************************************************************************/
        /*** Impair the strategy and reduce the pending redemption exit assets                                                          ***/
        /**********************************************************************************************************************************/

        impairStrategy(skyUnderlyingStrategy, impairment);

        uint256 impairedExitAssets = IStrategyManager(skyStrategyManager).convertToExitAssets(redemptionShares);

        uint256 expectedImpairedExitAssets = redemptionShares * (strategyAssets - impairment) / strategyShares;

        assertEq(impairedExitAssets, expectedImpairedExitAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolShares,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          impairment,
            lastRecordedTotalAssets: strategyAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              strategyAssets,
            unrealizedLosses: impairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: strategyAssets,
            availableToWithdraw:   strategyAssets,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssets,
            shares:           strategyShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: impairment
        });

        /**********************************************************************************************************************************/
        /*** Remove the impairment and restore the pending redemption exit assets                                                       ***/
        /**********************************************************************************************************************************/

        removeStrategyImpairment(skyUnderlyingStrategy, impairment);

        uint256 restoredExitAssets = IStrategyManager(skyStrategyManager).convertToExitAssets(redemptionShares);

        assertEq(restoredExitAssets, initialExitAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: strategyAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              strategyAssets,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: strategyAssets,
            availableToWithdraw:   strategyAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssets,
            shares:           strategyShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Process the pending redemption                                                                                             ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), skyStrategyManager, redemptionShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + restoredExitAssets
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: strategyAssets - restoredExitAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              strategyAssets - restoredExitAssets,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           strategyShares - redemptionShares,
            totalPendingShares:    0,
            assetsUnderManagement: strategyAssets - restoredExitAssets,
            availableToWithdraw:   strategyAssets - restoredExitAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssets - restoredExitAssets,
            shares:           strategyShares - redemptionShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_removeImpairment_aboveAndBelowAumClamp() external {
        uint256 storedImpairment  = fundAmount + impairment;            // 750k.
        uint256 removalAboveClamp = storedImpairment - strategyAssets;  // 250k + 1.

        /**********************************************************************************************************************************/
        /*** Impair the strategy above the AUM clamp                                                                                    ***/
        /**********************************************************************************************************************************/

        impairStrategy(skyUnderlyingStrategy, storedImpairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolShares,
            unrealizedLosses:   strategyAssets,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          storedImpairment,
            lastRecordedTotalAssets: strategyAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              strategyAssets,
            unrealizedLosses: strategyAssets
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: strategyAssets,
            availableToWithdraw:   strategyAssets,
            unrealizedLosses:      strategyAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssets,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: strategyAssets
        });

        /**********************************************************************************************************************************/
        /*** Remove impairment above the AUM clamp                                                                                      ***/
        /**********************************************************************************************************************************/

        removeStrategyImpairment(skyUnderlyingStrategy, removalAboveClamp);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolShares,
            unrealizedLosses:   strategyAssets,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          strategyAssets,
            lastRecordedTotalAssets: strategyAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              strategyAssets,
            unrealizedLosses: strategyAssets
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: strategyAssets,
            availableToWithdraw:   strategyAssets,
            unrealizedLosses:      strategyAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssets,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: strategyAssets
        });

        /**********************************************************************************************************************************/
        /*** Remove impairment below the AUM clamp                                                                                      ***/
        /**********************************************************************************************************************************/

        removeStrategyImpairment(skyUnderlyingStrategy, impairmentRemoval);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolShares,
            unrealizedLosses:   strategyAssets - impairmentRemoval,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          strategyAssets - impairmentRemoval,
            lastRecordedTotalAssets: strategyAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              strategyAssets,
            unrealizedLosses: strategyAssets - impairmentRemoval
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: strategyAssets,
            availableToWithdraw:   strategyAssets,
            unrealizedLosses:      strategyAssets - impairmentRemoval
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssets,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: strategyAssets - impairmentRemoval
        });
    }

    function testFork_removeImpairment_withYieldAfterFullImpairment() external {
        /**********************************************************************************************************************************/
        /*** Fully impair the strategy                                                                                                  ***/
        /**********************************************************************************************************************************/

        impairStrategy(skyUnderlyingStrategy, strategyAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolShares,
            unrealizedLosses:   strategyAssets,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          strategyAssets,
            lastRecordedTotalAssets: strategyAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              strategyAssets,
            unrealizedLosses: strategyAssets
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: strategyAssets,
            availableToWithdraw:   strategyAssets,
            unrealizedLosses:      strategyAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyAssets,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: strategyAssets
        });

        /**********************************************************************************************************************************/
        /*** Accrue yield in the fully impaired strategy                                                                                ***/
        /**********************************************************************************************************************************/

        vm.warp(start + 365 days);

        uint256 expectedYield = fundAmount * SKY_ANNUAL_APY / HUNDRED_PERCENT;
        uint256 expectedAum   = strategyAssets + expectedYield;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss + expectedYield,
            totalSupply:        poolShares,
            unrealizedLosses:   strategyAssets,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          strategyAssets,
            lastRecordedTotalAssets: strategyAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              expectedAum,
            unrealizedLosses: strategyAssets
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: expectedAum,
            availableToWithdraw:   expectedAum,
            unrealizedLosses:      strategyAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           expectedAum,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: strategyAssets
        });

        /**********************************************************************************************************************************/
        /*** Remove the full impairment without affecting the accrued yield                                                            ***/
        /**********************************************************************************************************************************/

        removeStrategyImpairment(skyUnderlyingStrategy, strategyAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss + expectedYield,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: strategyAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              expectedAum,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: expectedAum,
            availableToWithdraw:   expectedAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           expectedAum,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_removeImpairment_splitsAcrossPoolManagers() external {
        address firstPool        = address(pool);
        address firstPoolManager = address(poolManager);

        /**********************************************************************************************************************************/
        /*** Fund a second pool that shares the strategy                                                                                ***/
        /**********************************************************************************************************************************/

        ( address secondPool, address secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", skyStrategyManager);

        deposit(secondPool, lp, poolLiquidity);
        fundStrategyManager(secondPoolManager, skyStrategyManager, secondFundAmount);

        uint256 firstAssets  = strategyAssets;
        uint256 secondAssets = secondFundAmount;
        uint256 totalAssets  = firstAssets + secondAssets;  // 950k - 1.

        uint256 firstShares  = strategyShares;
        uint256 secondShares = secondFundShares;
        uint256 totalShares  = firstShares + secondShares;

        uint256 firstUnrealizedLoss  = divRoundUp(firstShares  * impairment, totalShares);
        uint256 secondUnrealizedLoss = divRoundUp(secondShares * impairment, totalShares);

        /**********************************************************************************************************************************/
        /*** Impair the strategy across both pools                                                                                      ***/
        /**********************************************************************************************************************************/

        impairStrategy(skyUnderlyingStrategy, impairment);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolShares,
            unrealizedLosses:   firstUnrealizedLoss,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity,
            totalSupply:        poolShares,
            unrealizedLosses:   secondUnrealizedLoss,
            availableLiquidity: poolLiquidity - secondFundAmount
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          impairment,
            lastRecordedTotalAssets: totalAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              totalAssets,
            unrealizedLosses: impairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstAssets,
            shares:           firstShares,
            pendingShares:    0,
            unrealizedLosses: firstUnrealizedLoss
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondAssets,
            shares:           secondShares,
            pendingShares:    0,
            unrealizedLosses: secondUnrealizedLoss
        });

        /**********************************************************************************************************************************/
        /*** Remove part of the impairment across both pools                                                                            ***/
        /**********************************************************************************************************************************/

        removeStrategyImpairment(skyUnderlyingStrategy, impairmentRemoval);

        uint256 remainingImpairment = impairment - impairmentRemoval;  // 150k.

        firstUnrealizedLoss  = divRoundUp(firstShares  * remainingImpairment, totalShares);
        secondUnrealizedLoss = divRoundUp(secondShares * remainingImpairment, totalShares);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolShares,
            unrealizedLosses:   firstUnrealizedLoss,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity,
            totalSupply:        poolShares,
            unrealizedLosses:   secondUnrealizedLoss,
            availableLiquidity: poolLiquidity - secondFundAmount
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          remainingImpairment,
            lastRecordedTotalAssets: totalAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              totalAssets,
            unrealizedLosses: remainingImpairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets,
            unrealizedLosses:      remainingImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstAssets,
            shares:           firstShares,
            pendingShares:    0,
            unrealizedLosses: firstUnrealizedLoss
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondAssets,
            shares:           secondShares,
            pendingShares:    0,
            unrealizedLosses: secondUnrealizedLoss
        });
    }

    function testFork_removeImpairment_doesNotCollectAccruedFees() external {
        uint32 delegateFeeRate = 0.1e6;   // 10% of accrued yield.
        uint32 protocolFeeRate = 0.05e6;  // 5% of accrued yield.

        /**********************************************************************************************************************************/
        /*** Accrue yield and confirm the outstanding fees                                                                              ***/
        /**********************************************************************************************************************************/

        setStrategyDelegateFeeRate(skyUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(skyUnderlyingStrategy, protocolFeeRate);

        vm.warp(start + 365 days);

        uint256 grossYield          = fundAmount * SKY_ANNUAL_APY / HUNDRED_PERCENT;
        uint256 grossAum            = strategyAssets + grossYield;
        uint256 expectedDelegateFee = (grossAum - strategyAssets) * delegateFeeRate / HUNDRED_PERCENT;
        uint256 expectedProtocolFee = (grossAum - strategyAssets) * protocolFeeRate / HUNDRED_PERCENT;
        uint256 netAum              = grossAum - expectedDelegateFee - expectedProtocolFee;
        uint256 susdsBalance        = IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: strategyAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              netAum,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: netAum,
            availableToWithdraw:   netAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           netAum,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), susdsBalance);
        assertEq(fundsAsset.balanceOf(strategyDelegate),                    0);
        assertEq(fundsAsset.balanceOf(treasury),                            0);

        /**********************************************************************************************************************************/
        /*** Impair the strategy without collecting the accrued fees                                                                    ***/
        /**********************************************************************************************************************************/

        impairStrategy(skyUnderlyingStrategy, impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolShares,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          impairment,
            lastRecordedTotalAssets: strategyAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              netAum,
            unrealizedLosses: impairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: netAum,
            availableToWithdraw:   netAum,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           netAum,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), susdsBalance);
        assertEq(fundsAsset.balanceOf(strategyDelegate),                    0);
        assertEq(fundsAsset.balanceOf(treasury),                            0);

        /**********************************************************************************************************************************/
        /*** Remove part of the impairment without collecting the accrued fees                                                          ***/
        /**********************************************************************************************************************************/

        removeStrategyImpairment(skyUnderlyingStrategy, impairmentRemoval);

        uint256 remainingImpairment = impairment - impairmentRemoval;  // 150k.

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolShares,
            unrealizedLosses:   remainingImpairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          remainingImpairment,
            lastRecordedTotalAssets: strategyAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              netAum,
            unrealizedLosses: remainingImpairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: netAum,
            availableToWithdraw:   netAum,
            unrealizedLosses:      remainingImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           netAum,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: remainingImpairment
        });

        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), susdsBalance);
        assertEq(fundsAsset.balanceOf(strategyDelegate),                    0);
        assertEq(fundsAsset.balanceOf(treasury),                            0);
    }

    function testFork_removeImpairment_withFullyExitedPoolManager() external {
        address firstPool        = address(pool);
        address firstPoolManager = address(poolManager);

        /**********************************************************************************************************************************/
        /*** Fund a second pool and fully exit the first pool manager                                                                   ***/
        /**********************************************************************************************************************************/

        ( address secondPool, address secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", skyStrategyManager);

        deposit(secondPool, lp, poolLiquidity);
        fundStrategyManager(secondPoolManager, skyStrategyManager, secondFundAmount);

        requestRedeemFromStrategyManager(firstPoolManager, skyStrategyManager, strategyShares);
        processRedemptionFromStrategyManager(firstPoolManager, skyStrategyManager, strategyShares);

        /**********************************************************************************************************************************/
        /*** Impair the strategy with a fully exited pool manager                                                                       ***/
        /**********************************************************************************************************************************/

        impairStrategy(skyUnderlyingStrategy, impairment);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - expectedRoundingLoss
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity,
            totalSupply:        poolShares,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - secondFundAmount
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          impairment,
            lastRecordedTotalAssets: secondFundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              secondFundAmount,
            unrealizedLosses: impairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           secondFundShares,
            totalPendingShares:    0,
            assetsUnderManagement: secondFundAmount,
            availableToWithdraw:   secondFundAmount,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondFundAmount,
            shares:           secondFundShares,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        /**********************************************************************************************************************************/
        /*** Remove part of the impairment with a fully exited pool manager                                                             ***/
        /**********************************************************************************************************************************/

        removeStrategyImpairment(skyUnderlyingStrategy, impairmentRemoval);

        uint256 remainingImpairment = impairment - impairmentRemoval;  // 150k.

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - expectedRoundingLoss
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity,
            totalSupply:        poolShares,
            unrealizedLosses:   remainingImpairment,
            availableLiquidity: poolLiquidity - secondFundAmount
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          remainingImpairment,
            lastRecordedTotalAssets: secondFundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              secondFundAmount,
            unrealizedLosses: remainingImpairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           secondFundShares,
            totalPendingShares:    0,
            assetsUnderManagement: secondFundAmount,
            availableToWithdraw:   secondFundAmount,
            unrealizedLosses:      remainingImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondFundAmount,
            shares:           secondFundShares,
            pendingShares:    0,
            unrealizedLosses: remainingImpairment
        });
    }

    function testFork_removeImpairment_withFullyExitedPoolManagerAndBootstrapMint() external {
        /**********************************************************************************************************************************/
        /*** Deploy a bootstrapped strategy and fund two pools                                                                          ***/
        /**********************************************************************************************************************************/

        ( skyStrategyManager, skyUnderlyingStrategy ) = _deploySkyStrategy({
            strategyDelegate_:        makeAddr("bootstrapStrategyDelegate"),
            fundsAsset_:              address(fundsAsset),
            savingsUsds_:             SAVINGS_USDS,
            psm_:                     USDS_LITE_PSM,
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    bootstrapMint + fundAmount + secondFundAmount,
            bootstrapMint_:           bootstrapMint
        });

        ( address firstPool,  address firstPoolManager )  = _createPoolSharingStrategy("bootstrapPoolDelegate", skyStrategyManager);
        ( address secondPool, address secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", skyStrategyManager);

        deposit(firstPool, lp, poolLiquidity);
        deposit(secondPool, lp, poolLiquidity);
        fundStrategyManager(firstPoolManager, skyStrategyManager, fundAmount);
        fundStrategyManager(secondPoolManager, skyStrategyManager, secondFundAmount);

        /**********************************************************************************************************************************/
        /*** Fully exit the first pool manager                                                                                          ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(firstPoolManager, skyStrategyManager, firstPoolShares);
        processRedemptionFromStrategyManager(firstPoolManager, skyStrategyManager, firstPoolShares);

        uint256 positionValue = bootstrapAssets + secondFundAmount;  // 550k - 1.
        uint256 totalShares   = bootstrapShares + secondFundShares;

        uint256 bootstrapImpairment  = divRoundUp(bootstrapShares  * impairment, totalShares);
        uint256 secondPoolImpairment = divRoundUp(secondFundShares * impairment, totalShares);

        /**********************************************************************************************************************************/
        /*** Impair the bootstrapped strategy with a fully exited pool manager                                                          ***/
        /**********************************************************************************************************************************/

        impairStrategy(skyUnderlyingStrategy, impairment);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity,
            totalSupply:        poolShares,
            unrealizedLosses:   secondPoolImpairment,
            availableLiquidity: poolLiquidity - secondFundAmount
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          impairment,
            lastRecordedTotalAssets: positionValue
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              positionValue,
            unrealizedLosses: impairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: positionValue,
            availableToWithdraw:   positionValue,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(0),
            assets:           bootstrapAssets,
            shares:           bootstrapShares,
            pendingShares:    0,
            unrealizedLosses: bootstrapImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondFundAmount,
            shares:           secondFundShares,
            pendingShares:    0,
            unrealizedLosses: secondPoolImpairment
        });

        /**********************************************************************************************************************************/
        /*** Remove part of the impairment from the bootstrapped strategy                                                               ***/
        /**********************************************************************************************************************************/

        removeStrategyImpairment(skyUnderlyingStrategy, impairmentRemoval);

        uint256 remainingImpairment = impairment - impairmentRemoval;  // 150k.

        uint256 bootstrapRemainingImpairment  = divRoundUp(bootstrapShares * remainingImpairment, totalShares);
        uint256 secondPoolRemainingImpairment = divRoundUp(secondFundShares * remainingImpairment, totalShares);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity,
            totalSupply:        poolShares,
            unrealizedLosses:   secondPoolRemainingImpairment,
            availableLiquidity: poolLiquidity - secondFundAmount
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          remainingImpairment,
            lastRecordedTotalAssets: positionValue
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              positionValue,
            unrealizedLosses: remainingImpairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: positionValue,
            availableToWithdraw:   positionValue,
            unrealizedLosses:      remainingImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(0),
            assets:           bootstrapAssets,
            shares:           bootstrapShares,
            pendingShares:    0,
            unrealizedLosses: bootstrapRemainingImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondFundAmount,
            shares:           secondFundShares,
            pendingShares:    0,
            unrealizedLosses: secondPoolRemainingImpairment
        });
    }

}
