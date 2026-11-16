// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { Action, ActionType } from "../../../modules/strategy-manager/contracts/interfaces/IMapleLiquidityRouter.sol";

import { Proxy } from "../../../contracts/Contracts@7.sol";

import { IPoolManager } from "../../../contracts/interfaces/Interfaces.sol";

import { AllocationStrategyTestBase } from "../allocation-strategy/AllocationStrategyTestBase.sol";
import { AaveV3StrategyTestBase } from "../aave-v3-strategy/AaveV3StrategyTestBase.sol";
import { SkyStrategyTestBase } from "../sky-strategy/SkyStrategyTestBase.sol";

contract ExecuteActionsFailureTests is AllocationStrategyTestBase {

    function test_executeActions_revert_functionPaused() external {
        Action[] memory actions = new Action[](1);

        actions[0] = Action({
            actionType:      ActionType.REQUEST_REDEEM,
            strategyManager: allocationStrategyManager,
            poolManager:     address(poolManager),
            amount:          1,
            strategyData:    ""
        });

        vm.prank(governor);
        globals.setContractPause(address(liquidityRouter), true);

        vm.prank(liquidityRouterBot);
        vm.expectRevert("MLR:PAUSED");
        liquidityRouter.executeActions(actions, block.timestamp);
    }

    function test_executeActions_revert_notLiquidityBot() external {
        Action[] memory actions = new Action[](1);

        actions[0] = Action({
            actionType:      ActionType.REQUEST_REDEEM,
            strategyManager: allocationStrategyManager,
            poolManager:     address(poolManager),
            amount:          1,
            strategyData:    ""
        });

        vm.expectRevert("MLR:NOT_LIQUIDITY_BOT");
        liquidityRouter.executeActions(actions, block.timestamp);
    }

    function test_executeActions_revert_expired() external {
        Action[] memory actions = new Action[](1);

        actions[0] = Action({
            actionType:      ActionType.REQUEST_REDEEM,
            strategyManager: allocationStrategyManager,
            poolManager:     address(poolManager),
            amount:          1,
            strategyData:    ""
        });

        vm.prank(liquidityRouterBot);
        vm.expectRevert("MLR:EA:EXPIRED");
        liquidityRouter.executeActions(actions, block.timestamp - 1 seconds);
    }

    function test_executeActions_revert_emptyActions() external {
        Action[] memory actions = new Action[](0);

        vm.prank(liquidityRouterBot);
        vm.expectRevert("MLR:EA:EMPTY_ACTIONS");
        liquidityRouter.executeActions(actions, block.timestamp);
    }

    function test_executeActions_revert_zeroStrategyManager() external {
        Action[] memory actions = new Action[](1);

        actions[0] = Action({
            actionType:      ActionType.FUND_STRATEGY,
            strategyManager: address(0),
            poolManager:     address(poolManager),
            amount:          1,
            strategyData:    ""
        });

        vm.prank(liquidityRouterBot);
        vm.expectRevert("MLR:EA:ZERO_SM");
        liquidityRouter.executeActions(actions, block.timestamp);
    }

    function test_executeActions_revert_zeroPoolManager() external {
        Action[] memory actions = new Action[](1);

        actions[0] = Action({
            actionType:      ActionType.FUND_STRATEGY,
            strategyManager: allocationStrategyManager,
            poolManager:     address(0),
            amount:          1,
            strategyData:    ""
        });

        vm.prank(liquidityRouterBot);
        vm.expectRevert("MLR:EA:ZERO_PM");
        liquidityRouter.executeActions(actions, block.timestamp);
    }

    function test_executeActions_revert_invalidStrategyManagerFactory() external {
        address invalidStrategyManager = address(new Proxy(makeAddr("invalidStrategyManagerFactory"), strategyManagerImplementation));

        Action[] memory actions = new Action[](1);

        actions[0] = Action({
            actionType:      ActionType.REQUEST_REDEEM,
            strategyManager: invalidStrategyManager,
            poolManager:     address(poolManager),
            amount:          1,
            strategyData:    ""
        });

        vm.prank(liquidityRouterBot);
        vm.expectRevert("MLR:EA:INVALID_SM_FACTORY");
        liquidityRouter.executeActions(actions, block.timestamp);
    }

    function test_executeActions_revert_invalidStrategyManager() external {
        address invalidStrategyManager = address(new Proxy(strategyManagerFactory, strategyManagerImplementation));

        Action[] memory actions = new Action[](1);

        actions[0] = Action({
            actionType:      ActionType.REQUEST_REDEEM,
            strategyManager: invalidStrategyManager,
            poolManager:     address(poolManager),
            amount:          1,
            strategyData:    ""
        });

        vm.prank(liquidityRouterBot);
        vm.expectRevert("MLR:EA:INVALID_SM");
        liquidityRouter.executeActions(actions, block.timestamp);
    }

}

contract ExecuteActionsAllocationStrategyCoreFlowTests is AllocationStrategyTestBase {

    uint256 constant initialLiquidity = 1_000_000e6;

    function test_executeActions_success_coreLifecycle() external {
        uint256 cancelledShares   = 100_000e6;
        uint256 initialPoolShares = 1_000_000e6; // Initial empty-pool deposit mints shares 1:1.
        uint256 processedAssets   = 500_000e6;
        uint256 processedShares   = 500_000e6;
        uint256 requestedShares   = 600_000e6; // Cancelled shares plus processed shares.
        uint256 remainingAssets   = 500_000e6; // Initial assets minus processed assets.
        uint256 remainingShares   = 500_000e6; // Initial shares minus processed shares.

        deposit(address(pool), lp, initialLiquidity);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: initialLiquidity
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            recordedAssets:        0,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
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
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(allocationStrategyManager),    0);
        assertEq(fundsAsset.balanceOf(address(liquidityRouter)),     0);

        /**********************************************************************************************************************************/
        /*** Execute the allocation strategy lifecycle in one call                                                                      ***/
        /**********************************************************************************************************************************/

        Action[] memory actions = new Action[](4);

        actions[0] = Action({
            actionType:      ActionType.FUND_STRATEGY,
            strategyManager: allocationStrategyManager,
            poolManager:     address(poolManager),
            amount:          initialLiquidity,
            strategyData:    ""
        });

        actions[1] = Action({
            actionType:      ActionType.REQUEST_REDEEM,
            strategyManager: allocationStrategyManager,
            poolManager:     address(poolManager),
            amount:          requestedShares,
            strategyData:    ""
        });

        actions[2] = Action({
            actionType:      ActionType.CANCEL_REDEMPTION,
            strategyManager: allocationStrategyManager,
            poolManager:     address(poolManager),
            amount:          cancelledShares,
            strategyData:    ""
        });

        actions[3] = Action({
            actionType:      ActionType.PROCESS_REDEMPTION,
            strategyManager: allocationStrategyManager,
            poolManager:     address(poolManager),
            amount:          processedShares,
            strategyData:    ""
        });

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions, block.timestamp);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: processedAssets
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: remainingAssets,
            availableToWithdraw:   remainingAssets,
            recordedAssets:        remainingAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           remainingShares,
            totalPendingShares:    0,
            assetsUnderManagement: remainingAssets,
            availableToWithdraw:   remainingAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           remainingShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), remainingAssets);
        assertEq(fundsAsset.balanceOf(allocationStrategyManager),    0);
        assertEq(fundsAsset.balanceOf(address(liquidityRouter)),     0);
    }

}

contract ExecuteActionsAaveV3StrategyCoreFlowTests is AaveV3StrategyTestBase {

    uint256 constant initialLiquidity = 1_000_000e6;

    function testFork_executeActions_success_coreLifecycle() external {
        uint256 cancelledShares   = 100_000e6;
        uint256 initialPoolShares = 1_000_000e6; // Initial empty-pool deposit mints shares 1:1.
        uint256 processedAssets   = 500_000e6;
        uint256 processedShares   = 500_000e6;
        uint256 requestedShares   = 600_000e6; // Cancelled shares plus processed shares.
        uint256 fundedAssets      = 1_000_000e6 - 1; // The aToken conversion rounds down by one asset unit.
        uint256 remainingAssets   = 500_000e6 - 1; // Funded assets minus processed assets.
        uint256 remainingShares   = 500_000e6 - 1; // Funded shares minus processed shares.

        deposit(address(pool), lp, initialLiquidity);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: initialLiquidity
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            aTokenBalance:           0,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(aaveV3StrategyManager),    0);
        assertEq(fundsAsset.balanceOf(address(liquidityRouter)), 0);

        /**********************************************************************************************************************************/
        /*** Execute the Aave strategy lifecycle in one call                                                                            ***/
        /**********************************************************************************************************************************/

        Action[] memory actions = new Action[](4);

        actions[0] = Action({
            actionType:      ActionType.FUND_STRATEGY,
            strategyManager: aaveV3StrategyManager,
            poolManager:     address(poolManager),
            amount:          initialLiquidity,
            strategyData:    ""
        });

        actions[1] = Action({
            actionType:      ActionType.REQUEST_REDEEM,
            strategyManager: aaveV3StrategyManager,
            poolManager:     address(poolManager),
            amount:          requestedShares,
            strategyData:    ""
        });

        actions[2] = Action({
            actionType:      ActionType.CANCEL_REDEMPTION,
            strategyManager: aaveV3StrategyManager,
            poolManager:     address(poolManager),
            amount:          cancelledShares,
            strategyData:    ""
        });

        actions[3] = Action({
            actionType:      ActionType.PROCESS_REDEMPTION,
            strategyManager: aaveV3StrategyManager,
            poolManager:     address(poolManager),
            amount:          processedShares,
            strategyData:    ""
        });

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions, block.timestamp);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        fundedAssets,
            totalSupply:        initialPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: processedAssets
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     remainingAssets,
            aTokenBalance:           remainingAssets,
            lastRecordedTotalAssets: remainingAssets,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           remainingShares,
            totalPendingShares:    0,
            assetsUnderManagement: remainingAssets,
            availableToWithdraw:   remainingAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           remainingShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(aaveV3StrategyManager),    0);
        assertEq(fundsAsset.balanceOf(address(liquidityRouter)), 0);
    }

}

contract ExecuteActionsSkyStrategyCoreFlowTests is SkyStrategyTestBase {

    uint256 constant initialLiquidity = 1_000_000e6;

    function testFork_executeActions_success_coreLifecycle() external {
        uint256 cancelledShares   = 100_000e6;
        uint256 initialPoolShares = 1_000_000e6; // Initial empty-pool deposit mints shares 1:1.
        uint256 processedAssets   = 500_000e6;
        uint256 processedShares   = 500_000e6;
        uint256 requestedShares   = 600_000e6; // Cancelled shares plus processed shares.
        uint256 fundedAssets      = 1_000_000e6 - 1; // The sUSDS conversion rounds down by one asset unit.
        uint256 remainingAssets   = 500_000e6 - 1; // Funded assets minus processed assets.
        uint256 remainingShares   = 500_000e6 - 1; // Funded shares minus processed shares.

        deposit(address(pool), lp, initialLiquidity);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: initialLiquidity
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(skyUnderlyingStrategy),    0);
        assertEq(fundsAsset.balanceOf(skyStrategyManager),       0);
        assertEq(fundsAsset.balanceOf(address(liquidityRouter)), 0);

        /**********************************************************************************************************************************/
        /*** Execute the Sky strategy lifecycle in one call                                                                             ***/
        /**********************************************************************************************************************************/

        Action[] memory actions = new Action[](4);

        actions[0] = Action({
            actionType:      ActionType.FUND_STRATEGY,
            strategyManager: skyStrategyManager,
            poolManager:     address(poolManager),
            amount:          initialLiquidity,
            strategyData:    ""
        });

        actions[1] = Action({
            actionType:      ActionType.REQUEST_REDEEM,
            strategyManager: skyStrategyManager,
            poolManager:     address(poolManager),
            amount:          requestedShares,
            strategyData:    ""
        });

        actions[2] = Action({
            actionType:      ActionType.CANCEL_REDEMPTION,
            strategyManager: skyStrategyManager,
            poolManager:     address(poolManager),
            amount:          cancelledShares,
            strategyData:    ""
        });

        actions[3] = Action({
            actionType:      ActionType.PROCESS_REDEMPTION,
            strategyManager: skyStrategyManager,
            poolManager:     address(poolManager),
            amount:          processedShares,
            strategyData:    ""
        });

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions, block.timestamp);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        fundedAssets,
            totalSupply:        initialPoolShares,
            unrealizedLosses:   0,
            availableLiquidity: processedAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              remainingAssets,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           remainingShares,
            totalPendingShares:    0,
            assetsUnderManagement: remainingAssets,
            availableToWithdraw:   remainingAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingAssets,
            shares:           remainingShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(skyUnderlyingStrategy),    0);
        assertEq(fundsAsset.balanceOf(skyStrategyManager),       0);
        assertEq(fundsAsset.balanceOf(address(liquidityRouter)), 0);
    }

}

contract ExecuteActionsRebalanceSuccessTests is AaveV3StrategyTestBase {

    uint256 constant initialPool1Assets = 1_200_000e6;
    uint256 constant initialPool1Shares = 1_200_000e6;
    uint256 constant initialPool2Assets = 800_000e6;
    uint256 constant initialPool2Shares = 800_000e6;

    uint256 constant pool1AaveAssets = 720_000e6;
    uint256 constant pool1SkyAssets  = 480_000e6;

    uint256 constant initialPool1TotalAssets = 1_200_000e6 - 2; // One conversion unit from each strategy.
    uint256 constant initialAaveAssets       = 720_000e6 - 1; // The aToken conversion rounds down.
    uint256 constant initialAaveShares       = 720_000e6 - 1; // Shares mirror the rounded assets.
    uint256 constant initialSkyAssets        = 480_000e6 - 1; // The sUSDS conversion rounds down.
    uint256 constant initialSkyShares        = 480_000e6 - 1; // Shares mirror the rounded assets.

    uint256 constant aaveSharesToRedeem       = 240_000e6;
    uint256 constant allocationSharesToRedeem = 240_000e6;

    uint256 constant finalPool1TotalAssets = 1_200_000e6 - 3; // Two funding units plus one redemption unit.
    uint256 constant finalAaveAssets       = 480_000e6 - 2; // Funding and redemption each add one aToken rounding unit.
    uint256 constant finalAaveShares       = 480_000e6 - 1; // Shares retain only the initial funding rounding unit.
    uint256 constant pool1AllocationAssets = 240_000e6;
    uint256 constant pool1AllocationShares = 240_000e6;
    uint256 constant pool2AllocationAssets = 560_000e6;
    uint256 constant pool2AllocationShares = 560_000e6;
    uint256 constant pool2SkyAssets        = 240_000e6;
    uint256 constant pool2SkyShares        = 240_000e6;
    uint256 constant finalSkyAssets        = 720_000e6 - 1; // The initial sUSDS conversion rounding remains.
    uint256 constant finalAllocationAssets = 800_000e6;

    address allocationStrategyDelegate = makeAddr("allocationStrategyDelegate");
    address skyStrategyDelegate        = makeAddr("skyStrategyDelegate");

    address pool1;
    address pool2;
    address poolManager1;
    address poolManager2;

    function setUp() public override {
        super.setUp();

        pool1        = address(pool);
        poolManager1 = address(poolManager);

        (skyStrategyManager, skyUnderlyingStrategy) = _deploySkyStrategy({
            strategyDelegate_:        skyStrategyDelegate,
            fundsAsset_:              address(fundsAsset),
            savingsUsds_:             SAVINGS_USDS,
            psm_:                     USDS_LITE_PSM,
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        (allocationStrategyManager, allocationUnderlyingStrategy) = _deployAllocationStrategy({
            strategyDelegate_:        allocationStrategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        addStrategyManagerToPool(poolManager1, skyStrategyManager);
        addStrategyManagerToPool(poolManager1, allocationStrategyManager);

        (pool2, poolManager2) = _createPoolSharingStrategy("poolDelegate2", aaveV3StrategyManager);

        vm.startPrank(governor);
        IPoolManager(poolManager2).addStrategyManager(skyStrategyManager);
        IPoolManager(poolManager2).setStrategyCap(skyStrategyManager, type(uint256).max);
        IPoolManager(poolManager2).addStrategyManager(allocationStrategyManager);
        IPoolManager(poolManager2).setStrategyCap(allocationStrategyManager, type(uint256).max);
        vm.stopPrank();

        deposit(pool1, lp, initialPool1Assets);
        deposit(pool2, lp, initialPool2Assets);
    }

    function testFork_executeActions_success_changeAllocationAcrossPoolsAndStrategies() external {
        /**********************************************************************************************************************************/
        /*** Fund all three strategies across both pools                                                                                ***/
        /**********************************************************************************************************************************/

        Action[] memory actions = new Action[](3);

        actions[0] = Action({
            actionType:      ActionType.FUND_STRATEGY,
            strategyManager: aaveV3StrategyManager,
            poolManager:     poolManager1,
            amount:          pool1AaveAssets,
            strategyData:    ""
        });

        actions[1] = Action({
            actionType:      ActionType.FUND_STRATEGY,
            strategyManager: skyStrategyManager,
            poolManager:     poolManager1,
            amount:          pool1SkyAssets,
            strategyData:    ""
        });

        actions[2] = Action({
            actionType:      ActionType.FUND_STRATEGY,
            strategyManager: allocationStrategyManager,
            poolManager:     poolManager2,
            amount:          initialPool2Assets,
            strategyData:    ""
        });

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions, block.timestamp);

        assertPoolState({
            pool:               pool1,
            totalAssets:        initialPool1TotalAssets,
            totalSupply:        initialPool1Shares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               pool2,
            totalAssets:        initialPool2Assets,
            totalSupply:        initialPool2Shares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManager1,
            assets:           initialAaveAssets,
            shares:           initialAaveShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      poolManager1,
            assets:           initialSkyAssets,
            shares:           initialSkyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManager2,
            assets:           initialPool2Assets,
            shares:           initialPool2Shares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Rebalance liquidity across both pools and all three strategies                                                             ***/
        /**********************************************************************************************************************************/

        actions = new Action[](6);

        actions[0] = Action({
            actionType:      ActionType.REQUEST_REDEEM,
            strategyManager: aaveV3StrategyManager,
            poolManager:     poolManager1,
            amount:          aaveSharesToRedeem,
            strategyData:    ""
        });

        actions[1] = Action({
            actionType:      ActionType.PROCESS_REDEMPTION,
            strategyManager: aaveV3StrategyManager,
            poolManager:     poolManager1,
            amount:          aaveSharesToRedeem,
            strategyData:    ""
        });

        actions[2] = Action({
            actionType:      ActionType.FUND_STRATEGY,
            strategyManager: allocationStrategyManager,
            poolManager:     poolManager1,
            amount:          pool1AllocationAssets,
            strategyData:    ""
        });

        actions[3] = Action({
            actionType:      ActionType.REQUEST_REDEEM,
            strategyManager: allocationStrategyManager,
            poolManager:     poolManager2,
            amount:          allocationSharesToRedeem,
            strategyData:    ""
        });

        actions[4] = Action({
            actionType:      ActionType.PROCESS_REDEMPTION,
            strategyManager: allocationStrategyManager,
            poolManager:     poolManager2,
            amount:          allocationSharesToRedeem,
            strategyData:    ""
        });

        actions[5] = Action({
            actionType:      ActionType.FUND_STRATEGY,
            strategyManager: skyStrategyManager,
            poolManager:     poolManager2,
            amount:          pool2SkyAssets,
            strategyData:    ""
        });

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions, block.timestamp);

        assertPoolState({
            pool:               pool1,
            totalAssets:        finalPool1TotalAssets,
            totalSupply:        initialPool1Shares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               pool2,
            totalAssets:        initialPool2Assets,
            totalSupply:        initialPool2Shares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     finalAaveAssets,
            aTokenBalance:           finalAaveAssets,
            lastRecordedTotalAssets: finalAaveAssets,
            unrealizedLosses:        0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManager1,
            assets:           finalAaveAssets,
            shares:           finalAaveShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              finalSkyAssets,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      poolManager1,
            assets:           initialSkyAssets,
            shares:           initialSkyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      poolManager2,
            assets:           pool2SkyAssets,
            shares:           pool2SkyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: finalAllocationAssets,
            availableToWithdraw:   finalAllocationAssets,
            recordedAssets:        finalAllocationAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManager1,
            assets:           pool1AllocationAssets,
            shares:           pool1AllocationShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManager2,
            assets:           pool2AllocationAssets,
            shares:           pool2AllocationShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(liquidityRouter)), 0);
    }

}
