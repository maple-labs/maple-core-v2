// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Action, ActionType } from "../../../modules/strategy-manager/contracts/interfaces/IMapleLiquidityRouter.sol";

import { IStrategyManager } from "../../../contracts/interfaces/Interfaces.sol";

import { AllocationStrategyTestBase } from "../../integration/allocation-strategy/AllocationStrategyTestBase.sol";

contract RemoveDelegatesFromAllowlistsTests is AllocationStrategyTestBase {

    address newPoolDelegate     = makeAddr("newPoolDelegate");
    address newStrategyDelegate = makeAddr("newStrategyDelegate");

    uint256 poolLiquidity    = 1_000_000e6;
    uint256 redemptionShares = 400_000e6;
    uint256 strategyFunding  = 600_000e6;

    function setUp() public override {
        super.setUp();

        deposit(lp, poolLiquidity);
        fundStrategyManager(address(poolManager), allocationStrategyManager, strategyFunding);
        requestRedeemFromStrategyManager(address(poolManager), allocationStrategyManager, redemptionShares);
    }

    function test_removeDelegates_success_successorDelegatesSettle() external {
        uint256 initialPoolLiquidity    = poolLiquidity - strategyFunding; // 1_000_000e6 - 600_000e6 = 400_000e6
        uint256 strategyShares          = 600_000e6;
        uint256 remainingStrategyAssets = 200_000e6;
        uint256 remainingStrategyShares = strategyShares - redemptionShares; // 600_000e6 - 400_000e6 = 200_000e6
        uint256 finalPoolLiquidity      = poolLiquidity - remainingStrategyAssets; // 1_000_000e6 - 200_000e6 = 800_000e6

        /**********************************************************************************************************************************/
        /*** Assert the funded position and pending partial redemption                                                                  ***/
        /**********************************************************************************************************************************/

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: initialPoolLiquidity
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyFunding,
            shares:           strategyShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        assertEq(globals.ownedPoolManager(poolDelegate),          address(poolManager));
        assertEq(globals.ownedStrategyManager(strategyDelegate),  allocationStrategyManager);
        assertEq(globals.isPoolDelegate(poolDelegate),            true);
        assertEq(globals.isPoolDelegate(newPoolDelegate),         false);
        assertEq(globals.isStrategyDelegate(strategyDelegate),    true);
        assertEq(globals.isStrategyDelegate(newStrategyDelegate), false);

        /**********************************************************************************************************************************/
        /*** Confirm neither owning delegate can be removed from its allowlist                                                          ***/
        /**********************************************************************************************************************************/

        vm.prank(operationalAdmin);
        vm.expectRevert("MG:SVPD:OWNS_POOL_MANAGER");
        globals.setValidPoolDelegate(poolDelegate, false);

        vm.prank(operationalAdmin);
        vm.expectRevert("MG:SVSD:OWNS_STRATEGY_MANAGER");
        globals.setValidStrategyDelegate(strategyDelegate, false);

        /**********************************************************************************************************************************/
        /*** Allowlist the successors and transfer both managers                                                                        ***/
        /**********************************************************************************************************************************/

        vm.startPrank(operationalAdmin);
        globals.setValidPoolDelegate(newPoolDelegate, true);
        globals.setValidStrategyDelegate(newStrategyDelegate, true);
        vm.stopPrank();

        vm.prank(operationalAdmin);
        poolManager.setPendingPoolDelegate(newPoolDelegate);

        assertEq(poolManager.poolDelegate(),        poolDelegate);
        assertEq(poolManager.pendingPoolDelegate(), newPoolDelegate);

        vm.prank(newPoolDelegate);
        poolManager.acceptPoolDelegate();

        vm.prank(operationalAdmin);
        IStrategyManager(allocationStrategyManager).setPendingStrategyDelegate(newStrategyDelegate);

        assertEq(IStrategyManager(allocationStrategyManager).strategyDelegate(),        strategyDelegate);
        assertEq(IStrategyManager(allocationStrategyManager).pendingStrategyDelegate(), newStrategyDelegate);

        vm.prank(newStrategyDelegate);
        IStrategyManager(allocationStrategyManager).acceptStrategyDelegate();

        assertEq(poolManager.poolDelegate(),        newPoolDelegate);
        assertEq(poolManager.pendingPoolDelegate(), address(0));

        assertEq(IStrategyManager(allocationStrategyManager).strategyDelegate(),        newStrategyDelegate);
        assertEq(IStrategyManager(allocationStrategyManager).pendingStrategyDelegate(), address(0));

        assertEq(globals.ownedPoolManager(poolDelegate),            address(0));
        assertEq(globals.ownedPoolManager(newPoolDelegate),         address(poolManager));
        assertEq(globals.ownedStrategyManager(strategyDelegate),    address(0));
        assertEq(globals.ownedStrategyManager(newStrategyDelegate), allocationStrategyManager);
        assertEq(globals.isPoolDelegate(poolDelegate),              true);
        assertEq(globals.isPoolDelegate(newPoolDelegate),           true);
        assertEq(globals.isStrategyDelegate(strategyDelegate),      true);
        assertEq(globals.isStrategyDelegate(newStrategyDelegate),   true);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: initialPoolLiquidity
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyFunding,
            shares:           strategyShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Remove the former delegates and confirm position accounting is unchanged                                                   ***/
        /**********************************************************************************************************************************/

        vm.startPrank(operationalAdmin);
        globals.setValidPoolDelegate(poolDelegate, false);
        globals.setValidStrategyDelegate(strategyDelegate, false);
        vm.stopPrank();

        assertEq(globals.ownedPoolManager(poolDelegate),            address(0));
        assertEq(globals.ownedPoolManager(newPoolDelegate),         address(poolManager));
        assertEq(globals.ownedStrategyManager(strategyDelegate),    address(0));
        assertEq(globals.ownedStrategyManager(newStrategyDelegate), allocationStrategyManager);
        assertEq(globals.isPoolDelegate(poolDelegate),              false);
        assertEq(globals.isPoolDelegate(newPoolDelegate),           true);
        assertEq(globals.isStrategyDelegate(strategyDelegate),      false);
        assertEq(globals.isStrategyDelegate(newStrategyDelegate),   true);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: initialPoolLiquidity
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyFunding,
            shares:           strategyShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Confirm the former delegates can no longer administer or operate the managers                                              ***/
        /**********************************************************************************************************************************/

        vm.prank(poolDelegate);
        vm.expectRevert("PM:NOT_OPERATIONAL_ADMIN");
        poolManager.setPendingPoolDelegate(poolDelegate);

        vm.prank(poolDelegate);
        vm.expectRevert("MSM:NOT_OPERATOR_OR_PD");
        IStrategyManager(allocationStrategyManager).cancelRedemption(address(poolManager), redemptionShares);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:NOT_ADMIN");
        IStrategyManager(allocationStrategyManager).setPoolManagerCap(address(poolManager), 0);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:NOT_OPERATOR_OR_OA");
        IStrategyManager(allocationStrategyManager).processRedemption(address(poolManager), redemptionShares, "");

        /**********************************************************************************************************************************/
        /*** Let the successor Pool Delegate recreate the request and the successor Strategy Delegate settle it                         ***/
        /**********************************************************************************************************************************/

        vm.prank(newPoolDelegate);
        IStrategyManager(allocationStrategyManager).cancelRedemption(address(poolManager), redemptionShares);

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyFunding,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        vm.prank(newPoolDelegate);
        IStrategyManager(allocationStrategyManager).requestRedeem(address(poolManager), redemptionShares);

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyFunding,
            shares:           strategyShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        vm.prank(newStrategyDelegate);
        IStrategyManager(allocationStrategyManager).processRedemption(address(poolManager), redemptionShares, "");

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: finalPoolLiquidity
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           remainingStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: remainingStrategyAssets,
            availableToWithdraw:   remainingStrategyAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingStrategyAssets,
            shares:           remainingStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function test_removeDelegates_success_liquidityBotSettles() external {
        uint256 initialPoolLiquidity    = poolLiquidity - strategyFunding; // 1_000_000e6 - 600_000e6 = 400_000e6
        uint256 strategyShares          = 600_000e6;
        uint256 remainingStrategyAssets = 200_000e6;
        uint256 remainingStrategyShares = strategyShares - redemptionShares; // 600_000e6 - 400_000e6 = 200_000e6
        uint256 finalPoolLiquidity      = poolLiquidity - remainingStrategyAssets; // 1_000_000e6 - 200_000e6 = 800_000e6

        /**********************************************************************************************************************************/
        /*** Allowlist the successors, transfer both managers and remove the former delegates                                           ***/
        /**********************************************************************************************************************************/

        vm.startPrank(operationalAdmin);
        globals.setValidPoolDelegate(newPoolDelegate, true);
        globals.setValidStrategyDelegate(newStrategyDelegate, true);
        vm.stopPrank();

        vm.prank(operationalAdmin);
        poolManager.setPendingPoolDelegate(newPoolDelegate);

        vm.prank(newPoolDelegate);
        poolManager.acceptPoolDelegate();

        vm.prank(operationalAdmin);
        IStrategyManager(allocationStrategyManager).setPendingStrategyDelegate(newStrategyDelegate);

        vm.prank(newStrategyDelegate);
        IStrategyManager(allocationStrategyManager).acceptStrategyDelegate();

        vm.startPrank(operationalAdmin);
        globals.setValidPoolDelegate(poolDelegate, false);
        globals.setValidStrategyDelegate(strategyDelegate, false);
        vm.stopPrank();

        assertEq(poolManager.poolDelegate(),        newPoolDelegate);
        assertEq(poolManager.pendingPoolDelegate(), address(0));

        assertEq(IStrategyManager(allocationStrategyManager).strategyDelegate(),        newStrategyDelegate);
        assertEq(IStrategyManager(allocationStrategyManager).pendingStrategyDelegate(), address(0));

        assertEq(globals.ownedPoolManager(poolDelegate),            address(0));
        assertEq(globals.ownedPoolManager(newPoolDelegate),         address(poolManager));
        assertEq(globals.ownedStrategyManager(strategyDelegate),    address(0));
        assertEq(globals.ownedStrategyManager(newStrategyDelegate), allocationStrategyManager);
        assertEq(globals.isPoolDelegate(poolDelegate),              false);
        assertEq(globals.isPoolDelegate(newPoolDelegate),           true);
        assertEq(globals.isStrategyDelegate(strategyDelegate),      false);
        assertEq(globals.isStrategyDelegate(newStrategyDelegate),   true);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: initialPoolLiquidity
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyFunding,
            shares:           strategyShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Let the direct liquidity bot settle the existing pending redemption                                                        ***/
        /**********************************************************************************************************************************/

        vm.prank(liquidityBot);
        IStrategyManager(allocationStrategyManager).processRedemption(address(poolManager), redemptionShares, "");

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: finalPoolLiquidity
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           remainingStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: remainingStrategyAssets,
            availableToWithdraw:   remainingStrategyAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingStrategyAssets,
            shares:           remainingStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function test_removeDelegates_success_liquidityRouterSettles() external {
        uint256 initialPoolLiquidity    = poolLiquidity - strategyFunding; // 1_000_000e6 - 600_000e6 = 400_000e6
        uint256 strategyShares          = 600_000e6;
        uint256 remainingStrategyAssets = 200_000e6;
        uint256 remainingStrategyShares = strategyShares - redemptionShares; // 600_000e6 - 400_000e6 = 200_000e6
        uint256 finalPoolLiquidity      = poolLiquidity - remainingStrategyAssets; // 1_000_000e6 - 200_000e6 = 800_000e6

        /**********************************************************************************************************************************/
        /*** Allowlist the successors, transfer both managers and remove the former delegates                                           ***/
        /**********************************************************************************************************************************/

        vm.startPrank(operationalAdmin);
        globals.setValidPoolDelegate(newPoolDelegate, true);
        globals.setValidStrategyDelegate(newStrategyDelegate, true);
        vm.stopPrank();

        vm.prank(operationalAdmin);
        poolManager.setPendingPoolDelegate(newPoolDelegate);

        vm.prank(newPoolDelegate);
        poolManager.acceptPoolDelegate();

        vm.prank(operationalAdmin);
        IStrategyManager(allocationStrategyManager).setPendingStrategyDelegate(newStrategyDelegate);

        vm.prank(newStrategyDelegate);
        IStrategyManager(allocationStrategyManager).acceptStrategyDelegate();

        vm.startPrank(operationalAdmin);
        globals.setValidPoolDelegate(poolDelegate, false);
        globals.setValidStrategyDelegate(strategyDelegate, false);
        vm.stopPrank();

        assertEq(poolManager.poolDelegate(),        newPoolDelegate);
        assertEq(poolManager.pendingPoolDelegate(), address(0));

        assertEq(IStrategyManager(allocationStrategyManager).strategyDelegate(),        newStrategyDelegate);
        assertEq(IStrategyManager(allocationStrategyManager).pendingStrategyDelegate(), address(0));

        assertEq(globals.ownedPoolManager(poolDelegate),            address(0));
        assertEq(globals.ownedPoolManager(newPoolDelegate),         address(poolManager));
        assertEq(globals.ownedStrategyManager(strategyDelegate),    address(0));
        assertEq(globals.ownedStrategyManager(newStrategyDelegate), allocationStrategyManager);
        assertEq(globals.isPoolDelegate(poolDelegate),              false);
        assertEq(globals.isPoolDelegate(newPoolDelegate),           true);
        assertEq(globals.isStrategyDelegate(strategyDelegate),      false);
        assertEq(globals.isStrategyDelegate(newStrategyDelegate),   true);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: initialPoolLiquidity
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    redemptionShares,
            assetsUnderManagement: strategyFunding,
            availableToWithdraw:   strategyFunding,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           strategyFunding,
            shares:           strategyShares,
            pendingShares:    redemptionShares,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Let the liquidity router settle the existing pending redemption                                                            ***/
        /**********************************************************************************************************************************/

        Action[] memory actions = new Action[](1);

        actions[0] = Action({
            actionType:      ActionType.PROCESS_REDEMPTION,
            strategyManager: allocationStrategyManager,
            poolManager:     address(poolManager),
            amount:          redemptionShares,
            strategyData:    ""
        });

        vm.prank(liquidityRouterBot);
        liquidityRouter.executeActions(actions, block.timestamp);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: finalPoolLiquidity
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           remainingStrategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: remainingStrategyAssets,
            availableToWithdraw:   remainingStrategyAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           remainingStrategyAssets,
            shares:           remainingStrategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

}
