// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC20Like,
    ISkyStrategy
} from "../../../contracts/interfaces/Interfaces.sol";

import { SkyStrategyTestBase } from "./SkyStrategyTestBase.sol";

contract SkyStrategyRecoverPositionFailureTests is SkyStrategyTestBase {

    function testFork_recoverPosition_failWhenProtocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(governor);
        vm.expectRevert("MSS:PAUSED");
        ISkyStrategy(skyUnderlyingStrategy).recoverPosition();
    }

    function testFork_recoverPosition_failWhenStrategyPaused() external {
        vm.prank(governor);
        globals.setContractPause(skyUnderlyingStrategy, true);

        vm.prank(governor);
        vm.expectRevert("MSS:PAUSED");
        ISkyStrategy(skyUnderlyingStrategy).recoverPosition();
    }

    function testFork_recoverPosition_failWhenNotProtocolAdmin() external {
        vm.prank(makeAddr("notProtocolAdmin"));
        vm.expectRevert("MSS:NOT_ADMIN");
        ISkyStrategy(skyUnderlyingStrategy).recoverPosition();
    }

    function testFork_recoverPosition_failWhenNotProtocolAdmin_strategyDelegate() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:NOT_ADMIN");
        ISkyStrategy(skyUnderlyingStrategy).recoverPosition();
    }

    function testFork_recoverPosition_failWhenLossNotRecognized() external {
        vm.prank(governor);
        vm.expectRevert("MSS:RP:LOSS_NOT_RECOGNIZED");
        ISkyStrategy(skyUnderlyingStrategy).recoverPosition();
    }

    function testFork_recoverPosition_failWithZeroBalance() external {
        vm.prank(governor);
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();

        vm.prank(governor);
        vm.expectRevert("MSS:RP:ZERO_BALANCE");
        ISkyStrategy(skyUnderlyingStrategy).recoverPosition();
    }

}

contract SkyStrategyRecoverPositionTests is SkyStrategyTestBase {

    uint256 fundAmount     = 500_000e6;
    uint256 poolLiquidity  = 1_000_000e6;
    uint256 poolShares     = 1_000_000e6;
    uint256 strategyShares = 500_000e6 - 1;  // USDC -> USDS -> sUSDS round-trip rounds down 1 wei at the fork block.

    uint256 recoveredShares;

    function setUp() public virtual override {
        super.setUp();

        deposit(lp, poolLiquidity);
        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        recoveredShares = IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy);
    }

    function testFork_recoverPosition_asGovernor() external {
        vm.prank(governor);
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();

        uint256 treasuryAssetsBefore            = fundsAsset.balanceOf(treasury);
        uint256 treasurySavingsUsdsSharesBefore = IERC20Like(SAVINGS_USDS).balanceOf(treasury);

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        true,
            impairedAssets:          0,
            lastRecordedTotalAssets: 0
        });

        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), recoveredShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        vm.prank(governor);
        ISkyStrategy(skyUnderlyingStrategy).recoverPosition();

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        true,
            impairedAssets:          0,
            lastRecordedTotalAssets: 0
        });

        assertEq(fundsAsset.balanceOf(treasury),                            treasuryAssetsBefore);
        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(treasury),              treasurySavingsUsdsSharesBefore + recoveredShares);
        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), 0);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_recoverPosition_asOperationalAdmin() external {
        vm.prank(operationalAdmin);
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();

        uint256 treasuryAssetsBefore            = fundsAsset.balanceOf(treasury);
        uint256 treasurySavingsUsdsSharesBefore = IERC20Like(SAVINGS_USDS).balanceOf(treasury);

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        true,
            impairedAssets:          0,
            lastRecordedTotalAssets: 0
        });

        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), recoveredShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        vm.prank(operationalAdmin);
        ISkyStrategy(skyUnderlyingStrategy).recoverPosition();

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        true,
            impairedAssets:          0,
            lastRecordedTotalAssets: 0
        });

        assertEq(fundsAsset.balanceOf(treasury),                            treasuryAssetsBefore);
        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(treasury),              treasurySavingsUsdsSharesBefore + recoveredShares);
        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), 0);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolShares,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           strategyShares,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           strategyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

}
