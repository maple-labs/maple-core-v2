// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IAavePoolLike, IAaveV3Strategy, IERC20, IStrategyManager } from "../../../contracts/interfaces/Interfaces.sol";

import { AaveV3StrategyTestBase } from "./AaveV3StrategyTestBase.sol";

contract AaveV3StrategyRecognizeLossFailureTests is AaveV3StrategyTestBase {

    function testFork_recognizeLoss_failWhenProtocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:PAUSED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();
    }

    function testFork_recognizeLoss_failWhenStrategyPaused() external {
        vm.prank(governor);
        globals.setContractPause(aaveV3UnderlyingStrategy, true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:PAUSED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();
    }

    function testFork_recognizeLoss_failWhenNotProtocolAdmin() external {
        vm.prank(makeAddr("notProtocolAdmin"));
        vm.expectRevert("MAV3S:NOT_AUTHORIZED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();
    }

    function testFork_recognizeLoss_failWhenGovernor() external {
        vm.prank(governor);
        vm.expectRevert("MAV3S:NOT_AUTHORIZED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();
    }

    function testFork_recognizeLoss_failWhenLossAlreadyRecognized() external {
        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:LOSS_RECOGNIZED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();
    }

    function testFork_recognizeLoss_failWhenLossAlreadyRecognized_asOperationalAdmin() external {
        vm.prank(operationalAdmin);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        vm.prank(operationalAdmin);
        vm.expectRevert("MAV3S:LOSS_RECOGNIZED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();
    }

    function testFork_setMetadata_failWhenLossRecognized() external {
        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:LOSS_RECOGNIZED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).setMetadata("new metadata");
    }

    function testFork_setReferralCode_failWhenLossRecognized() external {
        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:LOSS_RECOGNIZED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).setReferralCode(1);
    }

    function testFork_setStrategyDelegateFeeRate_failWhenLossRecognized() external {
        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:LOSS_RECOGNIZED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).setStrategyDelegateFeeRate(1);
    }

    function testFork_setStrategyProtocolFeeRate_failWhenLossRecognized() external {
        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        vm.prank(governor);
        vm.expectRevert("MAV3S:LOSS_RECOGNIZED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).setStrategyProtocolFeeRate(1);
    }

    function testFork_setUseVirtualUnderlyingBalance_failWhenLossRecognized() external {
        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        vm.prank(governor);
        vm.expectRevert("MAV3S:LOSS_RECOGNIZED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).setUseVirtualUnderlyingBalance(!useVirtualUnderlyingBalance);
    }

    function testFork_withdrawFromUnderlyingStrategy_failWhenLossRecognized() external {
        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        vm.prank(aaveV3StrategyManager);
        vm.expectRevert("MAV3S:LOSS_RECOGNIZED");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).withdrawFromUnderlyingStrategy(makeAddr("destination"), 1, "");
    }

}

contract SparkLendStrategyRecognizeLossFailureTests is AaveV3StrategyRecognizeLossFailureTests {

    function setUp() public override {
        aaveToken                   = SPARK_USDC;
        useVirtualUnderlyingBalance = false;

        super.setUp();
    }

}

contract AaveV3StrategyRecognizeLossTests is AaveV3StrategyTestBase {

    uint32 delegateFeeRate = 0.1e6; // 10% of accrued yield.
    uint32 protocolFeeRate = 0.05e6; // 5% of accrued yield.

    uint256 expectedRoundingError = 1; // Aave reports 1 asset unit below the nominal supply at this fork block.
    uint256 fundAmount            = 500_000e6;
    uint256 poolLiquidity         = 1_000_000e6;

    function setUp() public virtual override {
        super.setUp();

        deposit(lp, poolLiquidity);
        fundStrategyManager(address(poolManager), aaveV3StrategyManager, fundAmount);
        setStrategyDelegateFeeRate(aaveV3UnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(aaveV3UnderlyingStrategy, protocolFeeRate);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     fundAmount - expectedRoundingError,
            aTokenBalance:           fundAmount - expectedRoundingError,
            lastRecordedTotalAssets: fundAmount - expectedRoundingError,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           fundAmount - expectedRoundingError,
            totalPendingShares:    0,
            assetsUnderManagement: fundAmount - expectedRoundingError,
            availableToWithdraw:   fundAmount - expectedRoundingError,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           fundAmount - expectedRoundingError,
            shares:           fundAmount - expectedRoundingError,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_recognizeLoss_asStrategyDelegate() external {
        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).isLossRecognized(), true);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            aTokenBalance:           fundAmount - expectedRoundingError,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           fundAmount - expectedRoundingError,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           fundAmount - expectedRoundingError,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_recognizeLoss_asOperationalAdmin() external {
        vm.prank(operationalAdmin);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).isLossRecognized(), true);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            aTokenBalance:           fundAmount - expectedRoundingError,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           fundAmount - expectedRoundingError,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           fundAmount - expectedRoundingError,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_recognizeLoss_clearsImpairment() external {
        uint256 impairment = 100_000e6;

        impairStrategy(aaveV3UnderlyingStrategy, impairment);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   impairment,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     fundAmount - expectedRoundingError,
            aTokenBalance:           fundAmount - expectedRoundingError,
            lastRecordedTotalAssets: fundAmount - expectedRoundingError,
            unrealizedLosses:        impairment
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           fundAmount - expectedRoundingError,
            totalPendingShares:    0,
            assetsUnderManagement: fundAmount - expectedRoundingError,
            availableToWithdraw:   fundAmount - expectedRoundingError,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           fundAmount - expectedRoundingError,
            shares:           fundAmount - expectedRoundingError,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).isLossRecognized(), true);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            aTokenBalance:           fundAmount - expectedRoundingError,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           fundAmount - expectedRoundingError,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           fundAmount - expectedRoundingError,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_recognizeLoss_doesNotCollectAccruedFees() external {
        uint256 fundedAssets = fundAmount - expectedRoundingError;

        vm.warp(block.timestamp + 365 days);

        uint256 grossAum     = IERC20(aaveToken).balanceOf(aaveV3UnderlyingStrategy);
        uint256 yieldAccrued = grossAum - fundedAssets;
        uint256 delegateFee  = yieldAccrued * delegateFeeRate / HUNDRED_PERCENT;
        uint256 protocolFee  = yieldAccrued * protocolFeeRate / HUNDRED_PERCENT;
        uint256 netAum       = grossAum - delegateFee - protocolFee;

        assertGt(grossAum, fundedAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     netAum,
            aTokenBalance:           grossAum,
            lastRecordedTotalAssets: fundedAssets,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           fundedAssets,
            totalPendingShares:    0,
            assetsUnderManagement: netAum,
            availableToWithdraw:   netAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           netAum,
            shares:           fundedAssets,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).isLossRecognized(), true);

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            aTokenBalance:           grossAum,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           fundedAssets,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           fundedAssets,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_recognizeLoss_strandsOutstandingRedemptionRequest() external {
        uint256 redeemShares = (fundAmount - expectedRoundingError) / 4;

        requestRedeemFromStrategyManager(address(poolManager), aaveV3StrategyManager, redeemShares);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - expectedRoundingError,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     fundAmount - expectedRoundingError,
            aTokenBalance:           fundAmount - expectedRoundingError,
            lastRecordedTotalAssets: fundAmount - expectedRoundingError,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           fundAmount - expectedRoundingError,
            totalPendingShares:    redeemShares,
            assetsUnderManagement: fundAmount - expectedRoundingError,
            availableToWithdraw:   fundAmount - expectedRoundingError,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           fundAmount - expectedRoundingError,
            shares:           fundAmount - expectedRoundingError,
            pendingShares:    redeemShares,
            unrealizedLosses: 0
        });

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).isLossRecognized(), true);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            aTokenBalance:           fundAmount - expectedRoundingError,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           fundAmount - expectedRoundingError,
            totalPendingShares:    redeemShares,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           fundAmount - expectedRoundingError,
            pendingShares:    redeemShares,
            unrealizedLosses: 0
        });

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PR:ZERO_ASSETS");
        IStrategyManager(aaveV3StrategyManager).processRedemption(address(poolManager), redeemShares, "");
    }

    function testFork_recognizeLoss_donationDoesNotReviveAum() external {
        uint256 donationAssets = 100_000e6;

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).isLossRecognized(), true);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            aTokenBalance:           fundAmount - expectedRoundingError,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           fundAmount - expectedRoundingError,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           fundAmount - expectedRoundingError,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        address aavePool = IAaveV3Strategy(aaveV3UnderlyingStrategy).aavePool();

        deal(address(fundsAsset), address(this), donationAssets);
        fundsAsset.approve(aavePool, donationAssets);
        IAavePoolLike(aavePool).supply(address(fundsAsset), donationAssets, address(this), 0);

        uint256 donatedTokens = IERC20(aaveToken).balanceOf(address(this));
        IERC20(aaveToken).transfer(aaveV3UnderlyingStrategy, donatedTokens);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            aTokenBalance:           fundAmount - expectedRoundingError + donatedTokens,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           fundAmount - expectedRoundingError,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           fundAmount - expectedRoundingError,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function testFork_recognizeLoss_appliesToAllSharingPools() external {
        uint256 secondPoolFunding = 400_000e6;

        address firstPool        = address(pool);
        address firstPoolManager = address(poolManager);

        (address secondPool, address secondPoolManager) = _createPoolSharingStrategy("secondPoolDelegate", aaveV3StrategyManager);

        deposit(secondPool, lp, poolLiquidity);
        fundStrategyManager(secondPoolManager, aaveV3StrategyManager, secondPoolFunding);

        uint256 firstPoolShares  = fundAmount - expectedRoundingError;
        uint256 secondPoolShares = secondPoolFunding;
        uint256 totalShares      = firstPoolShares + secondPoolShares;

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - fundAmount + firstPoolShares,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity - secondPoolFunding + secondPoolShares,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - secondPoolFunding
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     totalShares,
            aTokenBalance:           totalShares,
            lastRecordedTotalAssets: totalShares,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalShares,
            availableToWithdraw:   totalShares,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstPoolShares,
            shares:           firstPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondPoolShares,
            shares:           secondPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).isLossRecognized(), true);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - fundAmount,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity - secondPoolFunding,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - secondPoolFunding
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     0,
            aTokenBalance:           totalShares,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           firstPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      secondPoolManager,
            assets:           0,
            shares:           secondPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

}

contract SparkLendStrategyRecognizeLossTests is AaveV3StrategyRecognizeLossTests {

    function setUp() public override {
        aaveToken                   = SPARK_USDC;
        expectedRoundingError       = 0;
        useVirtualUnderlyingBalance = false;

        super.setUp();
    }

}
