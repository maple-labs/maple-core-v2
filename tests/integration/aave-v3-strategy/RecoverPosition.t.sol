// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAaveV3Strategy,
    IERC20
} from "../../../contracts/interfaces/Interfaces.sol";

import { AaveV3StrategyTestBase } from "./AaveV3StrategyTestBase.sol";

contract AaveV3StrategyRecoverPositionFailureTests is AaveV3StrategyTestBase {

    function testFork_recoverPosition_failWhenProtocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(governor);
        vm.expectRevert("MAV3S:PAUSED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recoverPosition();
    }

    function testFork_recoverPosition_failWhenStrategyPaused() external {
        vm.prank(governor);
        globals.setContractPause(aaveV3UnderlyingStrategy, true);

        vm.prank(governor);
        vm.expectRevert("MAV3S:PAUSED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recoverPosition();
    }

    function testFork_recoverPosition_failWhenNotProtocolAdmin() external {
        vm.prank(makeAddr("notProtocolAdmin"));
        vm.expectRevert("MAV3S:NOT_ADMIN");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recoverPosition();
    }

    function testFork_recoverPosition_failWhenNotProtocolAdmin_strategyDelegate() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:NOT_ADMIN");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recoverPosition();
    }

    function testFork_recoverPosition_failWhenLossNotRecognized() external {
        vm.prank(governor);
        vm.expectRevert("MAV3S:RP:LOSS_NOT_RECOGNIZED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recoverPosition();
    }

    function testFork_recoverPosition_failWithZeroBalance() external {
        vm.prank(governor);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        vm.prank(governor);
        vm.expectRevert("MAV3S:RP:ZERO_BALANCE");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recoverPosition();
    }

    function testFork_recoverPosition_failWhenTransferFails() external {
        uint256 fundAmount = 100e6;

        deposit(lp, fundAmount);
        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);

        vm.prank(governor);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        setAaveV3ReservePause(true);

        vm.prank(governor);
        vm.expectRevert("MAV3S:RP:TRANSFER_FAILED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recoverPosition();
    }

}

contract SparkLendStrategyRecoverPositionFailureTests is AaveV3StrategyRecoverPositionFailureTests {

    function setUp() public override {
        aaveToken                   = SPARK_USDC;
        useVirtualUnderlyingBalance = false;

        super.setUp();
    }

}

contract AaveV3StrategyRecoverPositionTests is AaveV3StrategyTestBase {

    uint256 fundAmount      = 500_000e6;
    uint256 poolLiquidity   = 1_000_000e6;
    uint256 poolShares      = 1_000_000e6;
    uint256 recoveredShares = 500_000e6 - 1;  // Aave reports 1 asset unit below the nominal supply at this fork block.
    uint256 strategyShares  = 500_000e6 - 1;

    function setUp() public virtual override {
        super.setUp();

        deposit(lp, poolLiquidity);
        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);
    }

    function testFork_recoverPosition_asGovernor() external {
        vm.prank(governor);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        uint256 treasuryAssetsBefore     = fundsAsset.balanceOf(treasury);
        uint256 treasuryAaveSharesBefore = IERC20(aaveToken).balanceOf(treasury);

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).isLossRecognized(), true);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(),   0);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            aTokenBalance:           recoveredShares,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        vm.prank(governor);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recoverPosition();

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).isLossRecognized(), true);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(),   0);

        assertEq(fundsAsset.balanceOf(treasury),        treasuryAssetsBefore);
        assertEq(IERC20(aaveToken).balanceOf(treasury), treasuryAaveSharesBefore + recoveredShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
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
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_recoverPosition_asOperationalAdmin() external {
        vm.prank(operationalAdmin);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        uint256 treasuryAssetsBefore     = fundsAsset.balanceOf(treasury);
        uint256 treasuryAaveSharesBefore = IERC20(aaveToken).balanceOf(treasury);

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).isLossRecognized(), true);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(),   0);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            aTokenBalance:           recoveredShares,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        vm.prank(operationalAdmin);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recoverPosition();

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).isLossRecognized(), true);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(),   0);

        assertEq(fundsAsset.balanceOf(treasury),        treasuryAssetsBefore);
        assertEq(IERC20(aaveToken).balanceOf(treasury), treasuryAaveSharesBefore + recoveredShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
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
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

}

contract SparkLendStrategyRecoverPositionTests is AaveV3StrategyRecoverPositionTests {

    function setUp() public override {
        aaveToken                   = SPARK_USDC;
        recoveredShares             = 500_000e6;
        strategyShares              = 500_000e6;
        useVirtualUnderlyingBalance = false;

        super.setUp();
    }

}
