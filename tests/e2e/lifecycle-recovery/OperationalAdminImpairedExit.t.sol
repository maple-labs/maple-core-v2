// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IStrategyManager, IWithdrawalManagerQueue } from "../../../contracts/interfaces/Interfaces.sol";

import { MockMultisig } from "../../mocks/Mocks.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract OperationalAdminImpairedExitTests is TestBaseWithAssertions {

    address exitingLp   = makeAddr("exitingLp");
    address remainingLp = makeAddr("remainingLp");

    uint256 exitingLpDeposit   = 800_000e6;
    uint256 remainingLpDeposit = 200_000e6;
    uint256 poolLiquidity      = exitingLpDeposit + remainingLpDeposit;  // 1_000_000e6
    uint256 impairment         = 200_000e6;

    function setUp() public override {
        /**********************************************************************************************************************************/
        /*** Setup pool                                                                                                                 ***/
        /**********************************************************************************************************************************/

        startingTime = uint32(block.timestamp);

        _setUpClosedPool();

        setPoolPermissionLevel(address(poolManager), 1);  // FUNCTION_LEVEL

        operationalAdmin = address(new MockMultisig());

        vm.prank(governor);
        globals.setOperationalAdmin(operationalAdmin);

        ( allocationStrategyManager, allocationUnderlyingStrategy ) = _deployAllocationStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        strategyManager = allocationStrategyManager;

        addStrategyManagerToPool(address(poolManager), strategyManager);

        /**********************************************************************************************************************************/
        /*** Mint LP tokens, fund, impair and request redeem on a pool and assert state                                                 ***/
        /**********************************************************************************************************************************/

        mint(address(pool), exitingLp,   exitingLpDeposit);
        mint(address(pool), remainingLp, remainingLpDeposit);

        fundStrategyManager(address(poolManager), strategyManager, poolLiquidity);
        impairAllocationStrategy(allocationUnderlyingStrategy, impairment);
        requestRedeem(address(pool), exitingLp, exitingLpDeposit);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: poolLiquidity,
            availableToWithdraw:   poolLiquidity,
            recordedAssets:        poolLiquidity,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairment
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           poolLiquidity,
            totalPendingShares:    0,
            assetsUnderManagement: poolLiquidity,
            availableToWithdraw:   poolLiquidity,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           poolLiquidity,
            shares:           poolLiquidity,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        assertRequestOnWm({ requestId: 1, owner: exitingLp, shares: exitingLpDeposit });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });

        assertEq(pool.balanceOf(exitingLp),        0);
        assertEq(pool.balanceOf(remainingLp),      remainingLpDeposit);
        assertEq(pool.balanceOf(address(queueWM)), exitingLpDeposit);

        assertEq(fundsAsset.balanceOf(address(pool)),                0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), poolLiquidity);
    }

    function test_processRedemption_operationalAdminExitsImpairedLpWithCancellationPaused() external {
        /**********************************************************************************************************************************/
        /*** Queue the strategy manager redemption                                                                                      ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManager, poolLiquidity);

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           poolLiquidity,
            shares:           poolLiquidity,
            pendingShares:    poolLiquidity,
            unrealizedLosses: impairment
        });

        /**********************************************************************************************************************************/
        /*** Regular processing reverts                                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.prank(operationalAdmin);
        vm.expectRevert("WM:PR:LOW_LIQUIDITY");
        queueWM.processRedemptions(exitingLpDeposit);

        vm.prank(liquidityBot);
        vm.expectRevert("MSM:NOT_OPERATOR_OR_OA");
        IStrategyManager(strategyManager).processRedemption(address(poolManager), poolLiquidity, "");

        /**********************************************************************************************************************************/
        /*** Ops admin pauses cancellation of LP withdrawals on the pool permission manager                                             ***/
        /**********************************************************************************************************************************/

        bytes32[] memory functionIds = new bytes32[](2);
        uint256[] memory bitmaps     = new uint256[](2);

        functionIds[0] = "P:removeShares";
        functionIds[1] = "WM:removeSharesById";
        bitmaps[0]     = 1;
        bitmaps[1]     = 1;

        vm.prank(operationalAdmin);
        poolPermissionManager.setPoolBitmaps(address(poolManager), functionIds, bitmaps);

        assertEq(poolPermissionManager.poolBitmaps(address(poolManager), "P:removeShares"),      1);
        assertEq(poolPermissionManager.poolBitmaps(address(poolManager), "WM:removeSharesById"), 1);

        vm.prank(exitingLp);
        vm.expectRevert("PM:CC:NOT_ALLOWED");
        pool.removeShares(exitingLpDeposit, exitingLp);

        vm.prank(exitingLp);
        vm.expectRevert("WM:RSBI:NOT_ALLOWED");
        queueWM.removeSharesById(1, exitingLpDeposit);

        assertRequestOnWm({ requestId: 1, owner: exitingLp, shares: exitingLpDeposit });

        /**********************************************************************************************************************************/
        /*** Ops admin batches the strategy withdrawal and the pool redemption into a single transaction                                ***/
        /**********************************************************************************************************************************/

        uint256 netAssets  = poolLiquidity - impairment;                    // 800_000e6
        uint256 exitAssets = exitingLpDeposit * netAssets / poolLiquidity;  // 640_000e6

        address[] memory targets = new address[](2);
        bytes[]   memory calls   = new bytes[](2);

        targets[0] = strategyManager;
        targets[1] = address(queueWM);

        calls[0] = abi.encodeWithSelector(
            IStrategyManager(strategyManager).processRedemption.selector,
            address(poolManager),
            poolLiquidity,
            ""
        );

        calls[1] = abi.encodeWithSelector(
            IWithdrawalManagerQueue(address(queueWM)).processRedemptions.selector,
            exitingLpDeposit
        );

        MockMultisig(operationalAdmin).execute(targets, calls);

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: impairment,
            availableToWithdraw:   impairment,
            recordedAssets:        impairment,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairment
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: impairment,
            availableToWithdraw:   impairment,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        netAssets - exitAssets,
            totalSupply:        remainingLpDeposit,
            unrealizedLosses:   0,
            availableLiquidity: netAssets - exitAssets
        });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 1 });

        assertEq(fundsAsset.balanceOf(exitingLp),  exitAssets);
        assertEq(pool.balanceOf(exitingLp),        0);
        assertEq(pool.balanceOf(address(queueWM)), 0);

        assertEq(pool.balanceOf(remainingLp),                  remainingLpDeposit);
        assertEq(pool.convertToExitAssets(remainingLpDeposit), netAssets - exitAssets);  // 160_000e6

        /**********************************************************************************************************************************/
        /*** Ops admin restores the withdrawal permissions                                                                              ***/
        /**********************************************************************************************************************************/

        bitmaps[0] = 0;
        bitmaps[1] = 0;

        vm.prank(operationalAdmin);
        poolPermissionManager.setPoolBitmaps(address(poolManager), functionIds, bitmaps);

        assertEq(poolPermissionManager.poolBitmaps(address(poolManager), "P:removeShares"),      0);
        assertEq(poolPermissionManager.poolBitmaps(address(poolManager), "WM:removeSharesById"), 0);

        /**********************************************************************************************************************************/
        /*** A remaining LP can queue and cancel a withdrawal again                                                                     ***/
        /**********************************************************************************************************************************/

        requestRedeem(address(pool), remainingLp, remainingLpDeposit);

        assertRequestOnWm({ requestId: 2, owner: remainingLp, shares: remainingLpDeposit });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 2 });

        assertEq(pool.balanceOf(remainingLp),      0);
        assertEq(pool.balanceOf(address(queueWM)), remainingLpDeposit);

        removeShares(address(pool), remainingLp, remainingLpDeposit);

        assertRequestOnWm({ requestId: 2, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 2 });

        assertEq(pool.balanceOf(remainingLp),      remainingLpDeposit);
        assertEq(pool.balanceOf(address(queueWM)), 0);
    }

    function test_processRedemption_operationalAdminBatchesPermissionChangesAroundImpairedExit() external {
        /**********************************************************************************************************************************/
        /*** The strategy delegate queues the strategy manager redemption                                                               ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManager, poolLiquidity);

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           poolLiquidity,
            totalPendingShares:    poolLiquidity,
            assetsUnderManagement: poolLiquidity,
            availableToWithdraw:   poolLiquidity,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           poolLiquidity,
            shares:           poolLiquidity,
            pendingShares:    poolLiquidity,
            unrealizedLosses: impairment
        });

        assertEq(poolPermissionManager.poolBitmaps(address(poolManager), "WM:removeSharesById"), 0);
        assertEq(poolPermissionManager.poolBitmaps(address(poolManager), "P:removeShares"),      0);

        /**********************************************************************************************************************************/
        /*** One atomic batch pauses the exits, drains the strategy, processes the queue and restores the exits                         ***/
        /**********************************************************************************************************************************/

        uint256 netAssets  = poolLiquidity - impairment;                    // 800_000e6
        uint256 exitAssets = exitingLpDeposit * netAssets / poolLiquidity;  // 640_000e6

        bytes32[] memory functionIds   = new bytes32[](2);
        uint256[] memory pausedBitmaps = new uint256[](2);
        uint256[] memory openBitmaps   = new uint256[](2);

        functionIds[0]   = "WM:removeSharesById";
        functionIds[1]   = "P:removeShares";
        pausedBitmaps[0] = 1;
        pausedBitmaps[1] = 1;

        address[] memory targets = new address[](4);
        bytes[]   memory calls   = new bytes[](4);

        targets[0] = address(poolPermissionManager);
        targets[1] = strategyManager;
        targets[2] = address(queueWM);
        targets[3] = address(poolPermissionManager);

        calls[0] = abi.encodeWithSelector(
            poolPermissionManager.setPoolBitmaps.selector,
            address(poolManager),
            functionIds,
            pausedBitmaps
        );

        calls[1] = abi.encodeWithSelector(
            IStrategyManager(strategyManager).processRedemption.selector,
            address(poolManager),
            poolLiquidity,
            ""
        );

        calls[2] = abi.encodeWithSelector(
            IWithdrawalManagerQueue(address(queueWM)).processRedemptions.selector,
            exitingLpDeposit
        );

        calls[3] = abi.encodeWithSelector(
            poolPermissionManager.setPoolBitmaps.selector,
            address(poolManager),
            functionIds,
            openBitmaps
        );

        MockMultisig(operationalAdmin).execute(targets, calls);

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: impairment,
            availableToWithdraw:   impairment,
            recordedAssets:        impairment,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairment
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: impairment,
            availableToWithdraw:   impairment,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        netAssets - exitAssets,
            totalSupply:        remainingLpDeposit,
            unrealizedLosses:   0,
            availableLiquidity: netAssets - exitAssets
        });

        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 1 });

        assertEq(fundsAsset.balanceOf(exitingLp),  exitAssets);
        assertEq(pool.balanceOf(exitingLp),        0);
        assertEq(pool.balanceOf(address(queueWM)), 0);

        assertEq(pool.balanceOf(remainingLp),                  remainingLpDeposit);
        assertEq(pool.convertToExitAssets(remainingLpDeposit), netAssets - exitAssets);  // 160_000e6

        assertEq(poolPermissionManager.poolBitmaps(address(poolManager), "WM:removeSharesById"), 0);
        assertEq(poolPermissionManager.poolBitmaps(address(poolManager), "P:removeShares"),      0);

        /**********************************************************************************************************************************/
        /*** A remaining LP can queue and cancel a withdrawal by request identifier after the batch                                     ***/
        /**********************************************************************************************************************************/

        requestRedeem(address(pool), remainingLp, remainingLpDeposit);

        assertRequestOnWm({ requestId: 2, owner: remainingLp, shares: remainingLpDeposit });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 2 });

        assertEq(pool.balanceOf(remainingLp),      0);
        assertEq(pool.balanceOf(address(queueWM)), remainingLpDeposit);

        vm.prank(remainingLp);
        queueWM.removeSharesById(2, remainingLpDeposit);

        assertRequestOnWm({ requestId: 2, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 2, lastRequestId: 2 });

        assertEq(pool.balanceOf(remainingLp),      remainingLpDeposit);
        assertEq(pool.balanceOf(address(queueWM)), 0);
    }

    function test_processRedemption_cancellingAfterStrategyWithdrawalMakesTheImpairmentUnrecoverable() external {
        /**********************************************************************************************************************************/
        /*** Queue the strategy manager redemption                                                                                      ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManager, poolLiquidity);

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           poolLiquidity,
            totalPendingShares:    poolLiquidity,
            assetsUnderManagement: poolLiquidity,
            availableToWithdraw:   poolLiquidity,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           poolLiquidity,
            shares:           poolLiquidity,
            pendingShares:    poolLiquidity,
            unrealizedLosses: impairment
        });

        /**********************************************************************************************************************************/
        /*** Ops admin withdraws the whole strategy position without pausing cancellations                                              ***/
        /**********************************************************************************************************************************/

        uint256 netAssets = poolLiquidity - impairment;  // 800_000e6

        vm.prank(operationalAdmin);
        IStrategyManager(strategyManager).processRedemption(address(poolManager), poolLiquidity, "");

        assertPoolState({
            pool:               address(pool),
            totalAssets:        netAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: netAssets
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: impairment,
            availableToWithdraw:   impairment,
            recordedAssets:        impairment,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairment
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: impairment,
            availableToWithdraw:   impairment,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                netAssets);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), impairment);

        /**********************************************************************************************************************************/
        /*** The exiting LP cancels, so the drained strategy buys no exit at all                                                        ***/
        /**********************************************************************************************************************************/

        removeShares(address(pool), exitingLp, exitingLpDeposit);

        assertRequestOnWm({ requestId: 1, owner: address(0), shares: 0 });
        assertQueue({ poolManager: address(poolManager), nextRequestId: 1, lastRequestId: 1 });

        assertEq(pool.balanceOf(exitingLp),        exitingLpDeposit);
        assertEq(pool.balanceOf(address(queueWM)), 0);
        assertEq(fundsAsset.balanceOf(exitingLp),  0);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        netAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: netAssets
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: impairment,
            availableToWithdraw:   impairment,
            recordedAssets:        impairment,
            totalDeployedAssets:   0,
            unrealizedLosses:      impairment
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: impairment,
            availableToWithdraw:   impairment,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Removing the impairment no longer reaches the pool, so the loss stays with every LP                                        ***/
        /**********************************************************************************************************************************/

        removeStrategyImpairment(allocationUnderlyingStrategy, impairment);

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: impairment,
            availableToWithdraw:   impairment,
            recordedAssets:        impairment,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: impairment,
            availableToWithdraw:   impairment,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        netAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: netAssets
        });

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), impairment);

        uint256 expectedExitingLpAssets   = exitingLpDeposit * netAssets / poolLiquidity;    // 640_000e6
        uint256 expectedRemainingLpAssets = remainingLpDeposit * netAssets / poolLiquidity;  // 160_000e6

        assertEq(pool.convertToExitAssets(exitingLpDeposit),   expectedExitingLpAssets);
        assertEq(pool.convertToExitAssets(remainingLpDeposit), expectedRemainingLpAssets);
    }

}
