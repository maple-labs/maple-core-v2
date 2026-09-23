// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IAllocationStrategy, IStrategyManager } from "../../../contracts/interfaces/Interfaces.sol";

import { AllocationStrategyTestBase } from "./AllocationStrategyTestBase.sol";

contract AllocationStrategyRecognizeLossTestBase is AllocationStrategyTestBase {

    uint256 initialAssets     = 1_000_000e6;
    uint256 initialDeployment = 400_000e6;
    uint256 initialShares     = 1_000_000e6;
    uint256 lossAmount        = 150_000e6;

    function setUp() public virtual override {
        super.setUp();

        deposit(lp, initialAssets);
        fundStrategyManager(address(poolManager), allocationStrategyManager, initialAssets);
        deployAssets(allocationUnderlyingStrategy, managedWallet, initialDeployment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

}

contract AllocationStrategyRecognizeLossFailureTests is AllocationStrategyRecognizeLossTestBase {

    function test_recognizeLoss_revert_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:PAUSED");
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLoss(lossAmount, managedWallet);
    }

    function test_recognizeLoss_revert_contractPaused() external {
        vm.prank(governor);
        globals.setContractPause(allocationUnderlyingStrategy, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:PAUSED");
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLoss(lossAmount, managedWallet);
    }

    function test_recognizeLoss_revert_notAuthorized() external {
        address notAdmin = makeAddr("notAdmin");

        vm.prank(notAdmin);
        vm.expectRevert("MAS:NOT_AUTHORIZED");
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLoss(lossAmount, managedWallet);
    }

    function test_recognizeLoss_revert_notAuthorized_managedWallet() external {
        vm.prank(managedWallet);
        vm.expectRevert("MAS:NOT_AUTHORIZED");
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLoss(lossAmount, managedWallet);
    }

    function test_recognizeLoss_revert_notAuthorized_governor() external {
        vm.prank(governor);
        vm.expectRevert("MAS:NOT_AUTHORIZED");
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLoss(lossAmount, managedWallet);
    }

    function test_recognizeLoss_revert_zeroAssets() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:RL:ZERO_ASSETS");
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLoss(0, managedWallet);
    }

    function test_recognizeLoss_revert_exceedsDeployed() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:RL:EXCEEDS_DEPLOYED");
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLoss(initialDeployment + 1, managedWallet);
    }

    function test_recognizeLoss_revert_deployerNeverDeployed() external {
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(lp), 0);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:RL:EXCEEDS_DEPLOYED");
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLoss(1, lp);
    }

    function test_recognizeLoss_revert_afterFullLossAlreadyRecognized() external {
        recognizeLoss(allocationUnderlyingStrategy, managedWallet, initialDeployment);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:RL:EXCEEDS_DEPLOYED");
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLoss(1, managedWallet);
    }

}

contract AllocationStrategyRecognizeLossSuccessTests is AllocationStrategyRecognizeLossTestBase {

    address attacker;
    address firstPool;
    address firstPoolManager;
    address managedWallet2;
    address secondPool;
    address secondPoolManager;

    uint256 delegateFee;
    uint256 donation;
    uint256 elapsedDuration;
    uint256 firstAssets;
    uint256 firstLoss;
    uint256 firstShares;
    uint256 netYield;
    uint256 protocolFee;
    uint256 realizedAtLoss;
    uint256 reducedAum;
    uint256 remainingDeployment;
    uint256 secondAssets;
    uint256 secondFund;
    uint256 secondLoss;
    uint256 secondShares;
    uint256 splitLoss;
    uint256 totalAssets;
    uint256 totalShares;
    uint256 yieldAssets;

    uint32 delegateFeeRate;
    uint32 protocolFeeRate;
    uint32 yieldDuration;

    function test_recognizeLoss_success_partialLoss_accumulatesAcrossAdmins() external {
        /**********************************************************************************************************************************/
        /*** Recognize a partial loss via the strategy delegate                                                                         ***/
        /**********************************************************************************************************************************/

        firstLoss           = lossAmount;
        reducedAum          = initialAssets - firstLoss;
        remainingDeployment = initialDeployment - firstLoss;

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLoss(firstLoss, managedWallet);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        reducedAum,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: reducedAum,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           reducedAum,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: reducedAum,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   remainingDeployment,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), remainingDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Recognize a second loss via the operational admin: it accumulates on top of the first                                      ***/
        /**********************************************************************************************************************************/

        secondLoss           = 50_000e6;
        reducedAum          -= secondLoss;
        remainingDeployment -= secondLoss;

        vm.prank(operationalAdmin);
        IAllocationStrategy(allocationUnderlyingStrategy).recognizeLoss(secondLoss, managedWallet);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        reducedAum,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: reducedAum,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           reducedAum,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: reducedAum,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   remainingDeployment,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), remainingDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

    function test_recognizeLoss_success_partialLossAfterRedemptionRequest() external {
        uint256 loss                    = 200_000e6;
        uint256 sharesToRedeem          = 500_000e6;
        uint256 assetsAfterLoss         = initialAssets - loss;
        uint256 assetsOut               = 400_000e6;
        uint256 remainingDeployedAssets = initialDeployment - loss;

        /**********************************************************************************************************************************/
        /*** Request shares at an exchange rate of one                                                                                  ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), allocationStrategyManager, sharesToRedeem);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    sharesToRedeem,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    sharesToRedeem,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(allocationStrategyManager),    0);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Recognize a partial loss while the redemption is pending                                                                   ***/
        /**********************************************************************************************************************************/

        recognizeLoss(allocationUnderlyingStrategy, managedWallet, loss);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assetsAfterLoss,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    sharesToRedeem,
            assetsUnderManagement: assetsAfterLoss,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           assetsAfterLoss,
            shares:           initialShares,
            pendingShares:    sharesToRedeem,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: assetsAfterLoss,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   remainingDeployedAssets,
            unrealizedLosses:      0
        });

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(sharesToRedeem), assetsOut);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), remainingDeployedAssets);

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(allocationStrategyManager),    0);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Process the pending shares at the reduced exchange rate                                                                    ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), allocationStrategyManager, sharesToRedeem);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assetsAfterLoss,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: assetsOut
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares - sharesToRedeem,
            totalPendingShares:    0,
            assetsUnderManagement: assetsAfterLoss - assetsOut,
            availableToWithdraw:   initialAssets - initialDeployment - assetsOut,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           assetsAfterLoss - assetsOut,
            shares:           initialShares - sharesToRedeem,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: assetsAfterLoss - assetsOut,
            availableToWithdraw:   initialAssets - initialDeployment - assetsOut,
            recordedAssets:        initialAssets - initialDeployment - assetsOut,
            totalDeployedAssets:   remainingDeployedAssets,
            unrealizedLosses:      0
        });

        assertEq(IStrategyManager(allocationStrategyManager).convertToAssets(initialShares - sharesToRedeem), assetsAfterLoss - assetsOut);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), remainingDeployedAssets);

        assertEq(fundsAsset.balanceOf(address(pool)),                assetsOut);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment - assetsOut);
        assertEq(fundsAsset.balanceOf(allocationStrategyManager),    0);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

    function test_recognizeLoss_success_partialLossBeforeRedemptionRequest() external {
        uint256 loss                    = 200_000e6;
        uint256 sharesToRedeem          = 500_000e6;
        uint256 assetsAfterLoss         = initialAssets - loss;
        uint256 assetsOut               = 400_000e6;
        uint256 remainingDeployedAssets = initialDeployment - loss;

        /**********************************************************************************************************************************/
        /*** Recognize a partial loss                                                                                                   ***/
        /**********************************************************************************************************************************/

        recognizeLoss(allocationUnderlyingStrategy, managedWallet, loss);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assetsAfterLoss,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: assetsAfterLoss,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           assetsAfterLoss,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: assetsAfterLoss,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   remainingDeployedAssets,
            unrealizedLosses:      0
        });

        assertEq(IStrategyManager(allocationStrategyManager).convertToExitAssets(sharesToRedeem), assetsOut);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), remainingDeployedAssets);

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(allocationStrategyManager),    0);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Request shares at the reduced exchange rate                                                                                ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), allocationStrategyManager, sharesToRedeem);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assetsAfterLoss,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    sharesToRedeem,
            assetsUnderManagement: assetsAfterLoss,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           assetsAfterLoss,
            shares:           initialShares,
            pendingShares:    sharesToRedeem,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: assetsAfterLoss,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   remainingDeployedAssets,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), remainingDeployedAssets);

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(allocationStrategyManager),    0);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Process the requested shares at the reduced exchange rate                                                                  ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), allocationStrategyManager, sharesToRedeem);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        assetsAfterLoss,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: assetsOut
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares - sharesToRedeem,
            totalPendingShares:    0,
            assetsUnderManagement: assetsAfterLoss - assetsOut,
            availableToWithdraw:   initialAssets - initialDeployment - assetsOut,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           assetsAfterLoss - assetsOut,
            shares:           initialShares - sharesToRedeem,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: assetsAfterLoss - assetsOut,
            availableToWithdraw:   initialAssets - initialDeployment - assetsOut,
            recordedAssets:        initialAssets - initialDeployment - assetsOut,
            totalDeployedAssets:   remainingDeployedAssets,
            unrealizedLosses:      0
        });

        assertEq(IStrategyManager(allocationStrategyManager).convertToAssets(initialShares - sharesToRedeem), assetsAfterLoss - assetsOut);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), remainingDeployedAssets);

        assertEq(fundsAsset.balanceOf(address(pool)),                assetsOut);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment - assetsOut);
        assertEq(fundsAsset.balanceOf(allocationStrategyManager),    0);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

    function test_recognizeLoss_success_partialLossAndReturnAssetsDoNotCreateSkimmableAssets() external {
        uint256 loss                    = 200_000e6;
        uint256 remainingDeployedAssets = initialDeployment - loss;

        /**********************************************************************************************************************************/
        /*** Recognize a partial loss on the deployed assets                                                                            ***/
        /**********************************************************************************************************************************/

        recognizeLoss(allocationUnderlyingStrategy, managedWallet, loss);

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets - loss,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   remainingDeployedAssets,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), remainingDeployedAssets);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).unrecordedAssets(),              0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);

        /**********************************************************************************************************************************/
        /*** Confirm the recognized loss did not create assets that can be skimmed to the strategy delegate                             ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:S:ZERO_ASSETS");
        IAllocationStrategy(allocationUnderlyingStrategy).skim(strategyDelegate);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);

        /**********************************************************************************************************************************/
        /*** Return the remaining deployed assets through the recorded flow                                                             ***/
        /**********************************************************************************************************************************/

        returnAssets(allocationUnderlyingStrategy, managedWallet, managedWallet, remainingDeployedAssets);

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets - loss,
            availableToWithdraw:   initialAssets - loss,
            recordedAssets:        initialAssets - loss,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).unrecordedAssets(),              0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - loss);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);

        /**********************************************************************************************************************************/
        /*** Confirm the returned assets are recorded and cannot be skimmed to the strategy delegate                                    ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        vm.expectRevert("MAS:S:ZERO_ASSETS");
        IAllocationStrategy(allocationUnderlyingStrategy).skim(strategyDelegate);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - loss);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             0);
    }

    function test_recognizeLoss_success_totalLoss() external {
        /**********************************************************************************************************************************/
        /*** Recognize the entire deployed position as lost                                                                             ***/
        /**********************************************************************************************************************************/

        reducedAum = initialAssets - initialDeployment;

        recognizeLoss(allocationUnderlyingStrategy, managedWallet, initialDeployment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        reducedAum,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: reducedAum,
            availableToWithdraw:   reducedAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           reducedAum,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: reducedAum,
            availableToWithdraw:   reducedAum,
            recordedAssets:        reducedAum,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), reducedAum);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

    function test_recognizeLoss_success_doesNotAffectYieldSchedule() external {
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

        elapsedDuration = 10 days;
        realizedAtLoss  = netYield * elapsedDuration / yieldDuration;
        totalAssets     = initialAssets + realizedAtLoss;

        setStrategyDelegateFeeRate(allocationUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(allocationUnderlyingStrategy, protocolFeeRate);
        realizeYield(allocationUnderlyingStrategy, managedWallet, yieldAssets, yieldDuration);

        vm.warp(startingTime + elapsedDuration);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        totalAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           totalAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedAtLoss
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);

        /**********************************************************************************************************************************/
        /*** Recognize a loss on the deployed assets: the yield schedule is unaffected                                                  ***/
        /**********************************************************************************************************************************/

        reducedAum = totalAssets - lossAmount;

        recognizeLoss(allocationUnderlyingStrategy, managedWallet, lossAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        reducedAum,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: reducedAum,
            availableToWithdraw:   totalAssets - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           reducedAum,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: reducedAum,
            availableToWithdraw:   totalAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment + netYield,
            totalDeployedAssets:   initialDeployment - lossAmount,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime + yieldDuration,
            yieldLastRealized:    startingTime,
            realizedYield:        realizedAtLoss
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - lossAmount);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + netYield);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
        assertEq(fundsAsset.balanceOf(strategyDelegate),             delegateFee);
        assertEq(fundsAsset.balanceOf(treasury),                     protocolFee);
    }

    function test_recognizeLoss_success_clampsUnrealizedLossesToReducedAum() external {
        /**********************************************************************************************************************************/
        /*** Impair for the full AUM                                                                                                    ***/
        /**********************************************************************************************************************************/

        impairAllocationStrategy(allocationUnderlyingStrategy, initialAssets);

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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                initialAssets);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Recognize a loss on the deployed assets: the AUM shrinks and the unrealized loss clamps to it                              ***/
        /**********************************************************************************************************************************/

        reducedAum = initialAssets - initialDeployment;

        recognizeLoss(allocationUnderlyingStrategy, managedWallet, initialDeployment);

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

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                initialAssets);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), reducedAum);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

    function test_recognizeLoss_success_multipleDeployersIndependent() external {
        /**********************************************************************************************************************************/
        /*** Onboard a second managed wallet and deploy assets to it as well                                                            ***/
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

        remainingDeployment = 200_000e6;

        deployAssets(allocationUnderlyingStrategy, managedWallet2, remainingDeployment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment - remainingDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment - remainingDeployment,
            recordedAssets:        initialAssets - initialDeployment - remainingDeployment,
            totalDeployedAssets:   initialDeployment + remainingDeployment,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet),  initialDeployment);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet2), remainingDeployment);

        assertEq(fundsAsset.balanceOf(managedWallet),  initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet2), remainingDeployment);

        /**********************************************************************************************************************************/
        /*** Recognize a loss against the first deployer only: the second deployer's books are untouched                                ***/
        /**********************************************************************************************************************************/

        reducedAum = initialAssets - initialDeployment;

        recognizeLoss(allocationUnderlyingStrategy, managedWallet, initialDeployment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        reducedAum,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: reducedAum,
            availableToWithdraw:   reducedAum - remainingDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           reducedAum,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: reducedAum,
            availableToWithdraw:   reducedAum - remainingDeployment,
            recordedAssets:        reducedAum - remainingDeployment,
            totalDeployedAssets:   remainingDeployment,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet),  0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet2), remainingDeployment);

        assertEq(fundsAsset.balanceOf(managedWallet),  initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet2), remainingDeployment);
    }

    function test_recognizeLoss_success_afterPermissionsRevoked() external {
        /**********************************************************************************************************************************/
        /*** Revoke the managed wallet's permissions entirely, e.g. after it is found to be compromised                                 ***/
        /**********************************************************************************************************************************/

        address[] memory accounts        = new address[](1);
        bool[] memory    canDeployAssets = new bool[](1);
        bool[] memory    canReturnAssets = new bool[](1);
        bool[] memory    canRealizeYield = new bool[](1);

        accounts[0] = managedWallet;

        vm.prank(strategyDelegate);
        IAllocationStrategy(allocationUnderlyingStrategy).setPermissions(accounts, canDeployAssets, canReturnAssets, canRealizeYield);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** The admin can still recognize the loss against the revoked wallet's outstanding deployment                                 ***/
        /**********************************************************************************************************************************/

        reducedAum = initialAssets - initialDeployment;

        recognizeLoss(allocationUnderlyingStrategy, managedWallet, initialDeployment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        reducedAum,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: reducedAum,
            availableToWithdraw:   reducedAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           reducedAum,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: reducedAum,
            availableToWithdraw:   reducedAum,
            recordedAssets:        reducedAum,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), reducedAum);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

    function test_recognizeLoss_success_splitsAcrossPoolManagers() external {
        /**********************************************************************************************************************************/
        /*** Set up a second pool sharing the strategy                                                                                  ***/
        /**********************************************************************************************************************************/

        firstPool        = address(pool);
        firstPoolManager = address(poolManager);
        firstShares      = initialShares;

        (secondPool, secondPoolManager) = _createPoolSharingStrategy("secondPoolDelegate", allocationStrategyManager);

        secondFund   = 450_000e6;
        secondShares = secondFund;

        totalShares = firstShares + secondShares;

        deposit(secondPool, lp, initialAssets);
        fundStrategyManager(secondPoolManager, allocationStrategyManager, secondFund);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: initialAssets - secondFund
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets + secondFund,
            availableToWithdraw:   initialAssets + secondFund - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstShares,
            shares:           firstShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondShares,
            shares:           secondShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets + secondFund,
            availableToWithdraw:   initialAssets + secondFund - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment + secondFund,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + secondFund);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** Recognize a loss on the shared deployment: the AUM reduction splits proportionally by shares across both pool managers     ***/
        /**********************************************************************************************************************************/

        splitLoss   = 100_000e6;
        totalAssets = initialAssets + secondFund - splitLoss;

        firstAssets  = firstShares * totalAssets / totalShares;
        secondAssets = secondShares * totalAssets / totalShares;

        recognizeLoss(allocationUnderlyingStrategy, managedWallet, splitLoss);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        firstAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        secondAssets + (initialAssets - secondFund),
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: initialAssets - secondFund
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - (initialDeployment - splitLoss),
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstAssets,
            shares:           firstShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondAssets,
            shares:           secondShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: totalAssets,
            availableToWithdraw:   totalAssets - (initialDeployment - splitLoss),
            recordedAssets:        initialAssets - initialDeployment + secondFund,
            totalDeployedAssets:   initialDeployment - splitLoss,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment - splitLoss);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + secondFund);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

    function test_recognizeLoss_success_donationDoesNotInflateAum() external {
        /**********************************************************************************************************************************/
        /*** An external actor donates raw assets directly to the strategy, bypassing deployAssets()/returnAssets()                     ***/
        /**********************************************************************************************************************************/

        attacker = makeAddr("attacker");
        donation = 500_000e6;

        erc20_mint(address(fundsAsset), attacker, donation);

        vm.prank(attacker);
        fundsAsset.transfer(allocationUnderlyingStrategy, donation);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialAssets,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAssets,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: initialAssets,
            availableToWithdraw:   initialAssets - initialDeployment,
            recordedAssets:        initialAssets - initialDeployment,
            totalDeployedAssets:   initialDeployment,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).unrecordedAssets(),              donation);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), initialDeployment);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), initialAssets - initialDeployment + donation);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);

        /**********************************************************************************************************************************/
        /*** recognizeLoss() behaves identically regardless of the donation sitting in the contract                                     ***/
        /**********************************************************************************************************************************/

        reducedAum = initialAssets - initialDeployment;

        recognizeLoss(allocationUnderlyingStrategy, managedWallet, initialDeployment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        reducedAum,
            totalSupply:        initialShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: reducedAum,
            availableToWithdraw:   reducedAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           reducedAum,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: reducedAum,
            availableToWithdraw:   reducedAum,
            recordedAssets:        reducedAum,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).unrecordedAssets(),              donation);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), reducedAum + donation);
        assertEq(fundsAsset.balanceOf(managedWallet),                initialDeployment);
    }

}
