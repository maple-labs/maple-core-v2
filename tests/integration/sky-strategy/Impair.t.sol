// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { ISkyStrategy } from "../../../contracts/interfaces/Interfaces.sol";

import { SkyStrategyTestBase } from "./SkyStrategyTestBase.sol";

contract SkyStrategyImpairFailureTests is SkyStrategyTestBase {

    uint256 impairment = 100_000e6;

    function testFork_impair_failWhenProtocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:PAUSED");
        ISkyStrategy(skyUnderlyingStrategy).impair(impairment);
    }

    function testFork_impair_failWhenStrategyPaused() external {
        vm.prank(governor);
        globals.setContractPause(skyUnderlyingStrategy, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:PAUSED");
        ISkyStrategy(skyUnderlyingStrategy).impair(impairment);
    }

    function testFork_impair_failWhenNotProtocolAdmin() external {
        vm.prank(governor);
        vm.expectRevert("MSS:NOT_AUTHORIZED");
        ISkyStrategy(skyUnderlyingStrategy).impair(impairment);
    }

    function testFork_impair_failWhenLossRecognized() external {
        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:LOSS_RECOGNIZED");
        ISkyStrategy(skyUnderlyingStrategy).impair(impairment);
    }

    function testFork_impair_failWithZeroAssets() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:I:ZERO");
        ISkyStrategy(skyUnderlyingStrategy).impair(0);
    }

}

contract SkyStrategyImpairTests is SkyStrategyTestBase {

    uint256 expectedRoundingLoss = 1;
    uint256 fundAmount           = 500_000e6;
    uint256 poolLiquidity        = 1_000_000e6;

    function setUp() public virtual override {
        super.setUp();

        deposit(lp, poolLiquidity);
        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundAmount - expectedRoundingLoss,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    skyStrategyManager,
            totalShares:        fundAmount - expectedRoundingLoss,
            totalPendingShares: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundAmount - expectedRoundingLoss,
            shares:           fundAmount - expectedRoundingLoss,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_impair_accumulatesAcrossAllAdmins() external {
        uint256 delegateImpairment = 100_000e6;
        uint256 opAdminImpairment  = 150_000e6;

        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).impair(delegateImpairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   delegateImpairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundAmount - expectedRoundingLoss,
            unrealizedLosses: delegateImpairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundAmount - expectedRoundingLoss,
            totalPendingShares:    0,
            assetsUnderManagement: fundAmount - expectedRoundingLoss,
            availableToWithdraw:   fundAmount - expectedRoundingLoss,
            unrealizedLosses:      delegateImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundAmount - expectedRoundingLoss,
            shares:           fundAmount - expectedRoundingLoss,
            pendingShares:    0,
            unrealizedLosses: delegateImpairment
        });

        vm.prank(operationalAdmin);
        ISkyStrategy(skyUnderlyingStrategy).impair(opAdminImpairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   delegateImpairment + opAdminImpairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundAmount - expectedRoundingLoss,
            unrealizedLosses: delegateImpairment + opAdminImpairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundAmount - expectedRoundingLoss,
            totalPendingShares:    0,
            assetsUnderManagement: fundAmount - expectedRoundingLoss,
            availableToWithdraw:   fundAmount - expectedRoundingLoss,
            unrealizedLosses:      delegateImpairment + opAdminImpairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundAmount - expectedRoundingLoss,
            shares:           fundAmount - expectedRoundingLoss,
            pendingShares:    0,
            unrealizedLosses: delegateImpairment + opAdminImpairment
        });
    }

    function testFork_impair_clampsToAssetsUnderManagement() external {
        uint256 impairment = fundAmount + 250_000e6;

        impairStrategy(skyUnderlyingStrategy, impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   fundAmount - expectedRoundingLoss,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundAmount - expectedRoundingLoss,
            unrealizedLosses: fundAmount - expectedRoundingLoss
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundAmount - expectedRoundingLoss,
            totalPendingShares:    0,
            assetsUnderManagement: fundAmount - expectedRoundingLoss,
            availableToWithdraw:   fundAmount - expectedRoundingLoss,
            unrealizedLosses:      fundAmount - expectedRoundingLoss
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundAmount - expectedRoundingLoss,
            shares:           fundAmount - expectedRoundingLoss,
            pendingShares:    0,
            unrealizedLosses: fundAmount - expectedRoundingLoss
        });

        vm.warp(block.timestamp + 365 days);

        uint256 expectedYield = fundAmount * SKY_ANNUAL_APY / HUNDRED_PERCENT;
        uint256 expectedAum   = fundAmount - expectedRoundingLoss + expectedYield;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss + expectedYield,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   expectedAum,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              expectedAum,
            unrealizedLosses: expectedAum
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundAmount - expectedRoundingLoss,
            totalPendingShares:    0,
            assetsUnderManagement: expectedAum,
            availableToWithdraw:   expectedAum,
            unrealizedLosses:      expectedAum
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           expectedAum,
            shares:           fundAmount - expectedRoundingLoss,
            pendingShares:    0,
            unrealizedLosses: expectedAum
        });
    }

    function testFork_impair_unrealizedLossGrowsToImpairmentAsAumIncreases() external {
        uint256 impairment = fundAmount + 100e6;

        impairStrategy(skyUnderlyingStrategy, impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   fundAmount - expectedRoundingLoss,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundAmount - expectedRoundingLoss,
            unrealizedLosses: fundAmount - expectedRoundingLoss
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundAmount - expectedRoundingLoss,
            totalPendingShares:    0,
            assetsUnderManagement: fundAmount - expectedRoundingLoss,
            availableToWithdraw:   fundAmount - expectedRoundingLoss,
            unrealizedLosses:      fundAmount - expectedRoundingLoss
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundAmount - expectedRoundingLoss,
            shares:           fundAmount - expectedRoundingLoss,
            pendingShares:    0,
            unrealizedLosses: fundAmount - expectedRoundingLoss
        });

        vm.warp(block.timestamp + 365 days);

        uint256 expectedYield = fundAmount * SKY_ANNUAL_APY / HUNDRED_PERCENT;
        uint256 expectedAum   = fundAmount - expectedRoundingLoss + expectedYield;

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss + expectedYield,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              expectedAum,
            unrealizedLosses: impairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundAmount - expectedRoundingLoss,
            totalPendingShares:    0,
            assetsUnderManagement: expectedAum,
            availableToWithdraw:   expectedAum,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           expectedAum,
            shares:           fundAmount - expectedRoundingLoss,
            pendingShares:    0,
            unrealizedLosses: impairment
        });
    }

    function testFork_impair_splitsAcrossPoolManagers() external {
        uint256 secondFund = 450_000e6;
        uint256 impairment = 100_000e6;

        address firstPool        = address(pool);
        address firstPoolManager = address(poolManager);

        (address secondPool, address secondPoolManager) = _createPoolSharingStrategy("secondPoolDelegate", skyStrategyManager);

        deposit(secondPool, lp, poolLiquidity);
        fundStrategyManager(secondPoolManager, skyStrategyManager, secondFund);

        uint256 firstShares  = fundAmount - expectedRoundingLoss;
        uint256 secondShares = secondFund;
        uint256 totalShares  = firstShares + secondShares;

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - secondFund
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              totalShares,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalShares,
            availableToWithdraw:   totalShares,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstShares,
            shares:           firstShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondShares,
            shares:           secondShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        uint256 firstLoss  = firstShares * impairment / totalShares + 1; // Round up
        uint256 secondLoss = secondShares * impairment / totalShares + 1; // Round up

        impairStrategy(skyUnderlyingStrategy, impairment);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   firstLoss,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   secondLoss,
            availableLiquidity: poolLiquidity - secondFund
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              totalShares,
            unrealizedLosses: impairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalShares,
            availableToWithdraw:   totalShares,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstShares,
            shares:           firstShares,
            pendingShares:    0,
            unrealizedLosses: firstLoss
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondShares,
            shares:           secondShares,
            pendingShares:    0,
            unrealizedLosses: secondLoss
        });
    }

    function testFork_impair_withHaltedPsmAndZeroFallbackTout() external {
        uint256 fundedAssets = fundAmount - expectedRoundingLoss;
        uint256 impairment   = 100_000e6;

        setSkyTout(type(uint256).max);

        assertEq(ISkyStrategy(skyUnderlyingStrategy).fallbackTout(), 0);

        impairStrategy(skyUnderlyingStrategy, impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingLoss,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              fundedAssets,
            unrealizedLosses: impairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedAssets,
            totalPendingShares:    0,
            assetsUnderManagement: fundedAssets,
            availableToWithdraw:   0,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           fundedAssets,
            shares:           fundedAssets,
            pendingShares:    0,
            unrealizedLosses: impairment
        });
    }

    function testFork_impair_withHaltedPsmAndNonZeroFallbackTout() external {
        uint256 fallbackTout = 0.01e18; // 1% fallback PSM exit fee.
        uint256 impairment   = 100_000e6;

        // Discount the USDS position by the fallback PSM exit fee to calculate its USDC-equivalent AUM.
        uint256 expectedAum = fundAmount * 1e18 / (1e18 + fallbackTout);

        setSkyTout(type(uint256).max);
        setFallbackTout(skyUnderlyingStrategy, fallbackTout);

        assertEq(ISkyStrategy(skyUnderlyingStrategy).fallbackTout(), fallbackTout);
        assertGt(expectedAum, impairment);

        impairStrategy(skyUnderlyingStrategy, impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + expectedAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              expectedAum,
            unrealizedLosses: impairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundAmount - expectedRoundingLoss,
            totalPendingShares:    0,
            assetsUnderManagement: expectedAum,
            availableToWithdraw:   0,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           expectedAum,
            shares:           fundAmount - expectedRoundingLoss,
            pendingShares:    0,
            unrealizedLosses: impairment
        });
    }

    function testFork_impair_withFeesAndYield() external {
        uint32 delegateFeeRate = 0.1e6; // 10% of accrued yield.
        uint32 protocolFeeRate = 0.05e6; // 5% of accrued yield.

        uint256 fundedAssets = fundAmount - expectedRoundingLoss;
        uint256 impairment   = 100_000e6;

        setStrategyDelegateFeeRate(skyUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(skyUnderlyingStrategy, protocolFeeRate);

        vm.warp(block.timestamp + 365 days);

        uint256 grossYield          = fundAmount * SKY_ANNUAL_APY / HUNDRED_PERCENT;
        uint256 expectedDelegateFee = grossYield * delegateFeeRate / HUNDRED_PERCENT;
        uint256 expectedProtocolFee = grossYield * protocolFeeRate / HUNDRED_PERCENT;
        uint256 netAum              = fundedAssets + grossYield - expectedDelegateFee - expectedProtocolFee;

        assertGt(grossYield, 0);
        assertGt(expectedDelegateFee, 0);
        assertGt(expectedProtocolFee, 0);
        assertGt(netAum, impairment);

        impairStrategy(skyUnderlyingStrategy, impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              netAum,
            unrealizedLosses: impairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedAssets,
            totalPendingShares:    0,
            assetsUnderManagement: netAum,
            availableToWithdraw:   netAum,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           netAum,
            shares:           fundedAssets,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);
    }

    function testFork_impair_withFeesYieldAndPsmExitFee() external {
        uint256 tout            = 0.01e18; // 1% PSM exit fee.
        uint32  delegateFeeRate = 0.1e6; // 10% of accrued yield.
        uint32  protocolFeeRate = 0.05e6; // 5% of accrued yield.

        uint256 fundedAssets = fundAmount - expectedRoundingLoss;
        uint256 impairment   = 100_000e6;

        setStrategyDelegateFeeRate(skyUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(skyUnderlyingStrategy, protocolFeeRate);

        setSkyTout(tout);

        vm.warp(block.timestamp + 365 days);

        // Apply one year of Sky yield, then discount the USDS position by the PSM exit fee
        // to calculate AUM before strategy fees.
        uint256 grossAum = fundAmount * (HUNDRED_PERCENT + SKY_ANNUAL_APY) * 1e18 / (HUNDRED_PERCENT * (1e18 + tout));

        // Strategy fees accrue on the post-tout increase over the strategy's recorded asset baseline.
        uint256 feeBearingYield     = grossAum - fundedAssets;
        uint256 expectedDelegateFee = feeBearingYield * delegateFeeRate / HUNDRED_PERCENT;
        uint256 expectedProtocolFee = feeBearingYield * protocolFeeRate / HUNDRED_PERCENT;
        uint256 netAum              = grossAum - expectedDelegateFee - expectedProtocolFee;

        assertGt(feeBearingYield, 0);
        assertGt(expectedDelegateFee, 0);
        assertGt(expectedProtocolFee, 0);
        assertGt(netAum, impairment);

        impairStrategy(skyUnderlyingStrategy, impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              netAum,
            unrealizedLosses: impairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           fundedAssets,
            totalPendingShares:    0,
            assetsUnderManagement: netAum,
            availableToWithdraw:   netAum,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           netAum,
            shares:           fundedAssets,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);
    }

    function testFork_impair_withFullyExitedPoolManager() external {
        uint256 impairment = 100_000e6;
        uint256 secondFund = 450_000e6;

        address firstPool        = address(pool);
        address firstPoolManager = address(poolManager);

        (address secondPool, address secondPoolManager) = _createPoolSharingStrategy("secondPoolDelegate", skyStrategyManager);

        deposit(secondPool, lp, poolLiquidity);
        fundStrategyManager(secondPoolManager, skyStrategyManager, secondFund);

        uint256 firstShares  = fundAmount - expectedRoundingLoss;
        uint256 secondShares = secondFund;

        requestRedeemFromStrategyManager(firstPoolManager, skyStrategyManager, firstShares);
        processRedemptionFromStrategyManager(firstPoolManager, skyStrategyManager, firstShares);

        uint256 firstPoolAssets = fundsAsset.balanceOf(firstPool);
        uint256 positionValue   = secondFund;

        assertGt(positionValue, impairment);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        firstPoolAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: firstPoolAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        impairStrategy(skyUnderlyingStrategy, impairment);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        firstPoolAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: firstPoolAssets
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity - secondFund + positionValue,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - secondFund
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              positionValue,
            unrealizedLosses: impairment
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           secondShares,
            totalPendingShares:    0,
            assetsUnderManagement: positionValue,
            availableToWithdraw:   positionValue,
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
            assets:           positionValue,
            shares:           secondShares,
            pendingShares:    0,
            unrealizedLosses: impairment
        });
    }

}
