// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IERC20Like,
    IERC4626Like,
    IPSMLike,
    ISkyStrategy
} from "../../../contracts/interfaces/Interfaces.sol";

import { SkyStrategyTestBase } from "../../integration/sky-strategy/SkyStrategyTestBase.sol";

contract SkyPsmEntryFeeTests is SkyStrategyTestBase {

    address firstPool;
    address firstPoolManager;
    address secondPool;
    address secondPoolManager;

    uint256 fundAmount    = 100_000e6;
    uint256 poolLiquidity = 1_000_000e6;
    uint256 roundingLoss  = 1;        // The first USDC -> USDS -> sUSDS round-trip rounds down 1 wei at the fork block.
    uint256 tin           = 0.01e18;  // 1% PSM entry fee.

    function setUp() public override {
        super.setUp();

        firstPool        = address(pool);
        firstPoolManager = address(poolManager);

        deposit(firstPool, lp, poolLiquidity);

        ( secondPool, secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", skyStrategyManager);

        deposit(secondPool, lp, poolLiquidity);
    }

    function testFork_skyPsmEntryFee_eachPoolPaysWithoutDilution() external {
        uint256 entryFee       = fundAmount * tin / 1e18;               // 1_000e6.
        uint256 firstNetAssets = fundAmount - entryFee - roundingLoss;  // 99_000e6 - 1.
        uint256 firstShares    = firstNetAssets;                        // 99_000e6 - 1.

        /**********************************************************************************************************************************/
        /*** Enable the PSM entry fee with no exit fee and fund the first Pool                                                          ***/
        /**********************************************************************************************************************************/

        setSkyTin(tin);
        setSkyTout(0);

        address pocket              = IPSMLike(USDS_LITE_PSM).pocket();
        uint256 pocketBalanceBefore = fundsAsset.balanceOf(pocket);

        fundStrategyManager(firstPoolManager, skyStrategyManager, fundAmount);

        assertEq(IPSMLike(USDS_LITE_PSM).tin(),  tin);
        assertEq(IPSMLike(USDS_LITE_PSM).tout(), 0);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - fundAmount + firstNetAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              firstNetAssets,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: firstNetAssets
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           firstShares,
            totalPendingShares:    0,
            assetsUnderManagement: firstNetAssets,
            availableToWithdraw:   firstNetAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstNetAssets,
            shares:           firstShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(ISkyStrategy(skyUnderlyingStrategy).availableToWithdraw(), firstNetAssets);

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);

        /**********************************************************************************************************************************/
        /*** Fund the existing position from the second Pool and confirm each Pool bears only its own entry fee                         ***/
        /**********************************************************************************************************************************/

        uint256 secondNetAssets = fundAmount - entryFee;                           // 99_000e6.
        uint256 secondShares    = secondNetAssets * firstShares / firstNetAssets;  // 99_000e6.
        uint256 totalAum        = firstNetAssets + secondNetAssets;                // 198_000e6 - 1.
        uint256 totalShares     = firstShares + secondShares;                      // 198_000e6 - 1.

        fundStrategyManager(secondPoolManager, skyStrategyManager, fundAmount);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - fundAmount + firstNetAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity - fundAmount + secondNetAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              totalAum,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: totalAum
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: totalAum,
            availableToWithdraw:   totalAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstNetAssets,
            shares:           firstShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondNetAssets,
            shares:           secondShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(ISkyStrategy(skyUnderlyingStrategy).availableToWithdraw(), totalAum);

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);

        /**********************************************************************************************************************************/
        /*** Request every share from both Pools                                                                                        ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(firstPoolManager,  skyStrategyManager, firstShares);
        requestRedeemFromStrategyManager(secondPoolManager, skyStrategyManager, secondShares);

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalShares,
            totalPendingShares:    totalShares,
            assetsUnderManagement: totalAum,
            availableToWithdraw:   totalAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           firstNetAssets,
            shares:           firstShares,
            pendingShares:    firstShares,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           secondNetAssets,
            shares:           secondShares,
            pendingShares:    secondShares,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Redeem the first Pool in full without changing the second Pool's position                                                  ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(firstPoolManager, skyStrategyManager, firstShares);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - fundAmount + firstNetAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + firstNetAssets
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity - fundAmount + secondNetAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              secondNetAssets,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: secondNetAssets
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           secondShares,
            totalPendingShares:    secondShares,
            assetsUnderManagement: secondNetAssets,
            availableToWithdraw:   secondNetAssets,
            unrealizedLosses:      0
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
            assets:           secondNetAssets,
            shares:           secondShares,
            pendingShares:    secondShares,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);
        assertEq(fundsAsset.balanceOf(treasury),         0);

        /**********************************************************************************************************************************/
        /*** Redeem the second Pool and reconcile all assets, fees and conversion dust                                                  ***/
        /**********************************************************************************************************************************/

        uint256 retainedFeesAndRounding = 2 * entryFee + roundingLoss;  // 2_000e6 + 1.

        processRedemptionFromStrategyManager(secondPoolManager, skyStrategyManager, secondShares);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - fundAmount + firstNetAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + firstNetAssets
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity - fundAmount + secondNetAssets,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount + secondNetAssets
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: 0
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
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(0),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(IPSMLike(USDS_LITE_PSM).tin(),  tin);
        assertEq(IPSMLike(USDS_LITE_PSM).tout(), 0);

        assertEq(IERC20Like(USDS).balanceOf(skyUnderlyingStrategy), 0);

        assertEq(fundsAsset.balanceOf(pocket),                pocketBalanceBefore + retainedFeesAndRounding);
        assertEq(fundsAsset.balanceOf(skyUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(strategyDelegate),      0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        // Decimal conversion can leave sub-USDC sUSDS dust.
        assertLt(IERC4626Like(SAVINGS_USDS).previewRedeem(IERC4626Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy)), 1e12);
    }

}

contract SkyPsmExitFeeRemovalTests is SkyStrategyTestBase {

    uint32 delegateFeeRate = 0.1e6;   // 10% of accrued yield.
    uint32 protocolFeeRate = 0.05e6;  // 5% of accrued yield.

    uint256 additionalFunding = 100_850e6 + 1;  // +1 offsets floor division so each additional fund mints exactly 100_000e6 shares.
    uint256 fundAmount        = 505_000e6;
    uint256 poolLiquidity     = 1_000_000e6;
    uint256 roundingLoss      = 1;              // USDC -> USDS -> sUSDS round-trip rounds down 1 wei at the fork block.
    uint256 tout              = 0.01e18;        // 1% PSM exit fee.

    function setUp() public override {
        super.setUp();

        deposit(lp, poolLiquidity);
    }

    function testFork_skyPsmExitFeeRemoval_increasesAumAndChargesFeesOnce() external {
        /**********************************************************************************************************************************/
        /*** Enable strategy fees and fund Sky while the PSM charges a 1% exit fee                                                      ***/
        /**********************************************************************************************************************************/

        setStrategyDelegateFeeRate(skyUnderlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(skyUnderlyingStrategy, protocolFeeRate);
        setSkyTout(tout);

        fundStrategyManager(address(poolManager), skyStrategyManager, fundAmount);

        uint256 initialAum    = fundAmount * 1e18 / (1e18 + tout) - roundingLoss;  // 500_000e6 - 1.
        uint256 initialShares = initialAum;                                        // 500_000e6 - 1.

        assertEq(IPSMLike(USDS_LITE_PSM).tout(), tout);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + initialAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              initialAum,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: initialAum
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: initialAum,
            availableToWithdraw:   initialAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           initialAum,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(ISkyStrategy(skyUnderlyingStrategy).availableToWithdraw(),     initialAum);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyDelegateFeeRate(), delegateFeeRate);
        assertEq(ISkyStrategy(skyUnderlyingStrategy).strategyProtocolFeeRate(), protocolFeeRate);

        assertEq(fundsAsset.balanceOf(skyUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(strategyDelegate),      0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        uint256 savingsUsdsShares = IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy);

        assertGt(savingsUsdsShares, 0);

        /**********************************************************************************************************************************/
        /*** Remove the PSM exit fee without moving assets and recognize the valuation increase as fee-bearing yield                    ***/
        /**********************************************************************************************************************************/

        uint256 grossAumAfterRemoval   = fundAmount - roundingLoss;                                         // 505_000e6 - 1.
        uint256 removedExitFeeDiscount = grossAumAfterRemoval - initialAum;                                 // 5_000e6.
        uint256 expectedDelegateFee    = removedExitFeeDiscount * delegateFeeRate / 1e6;                    // 500e6.
        uint256 expectedProtocolFee    = removedExitFeeDiscount * protocolFeeRate / 1e6;                    // 250e6.
        uint256 netAumAfterRemoval     = grossAumAfterRemoval - expectedDelegateFee - expectedProtocolFee;  // 504_250e6 - 1.

        setSkyTout(0);

        assertEq(IPSMLike(USDS_LITE_PSM).tout(), 0);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount + netAumAfterRemoval,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              netAumAfterRemoval,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: initialAum
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           initialShares,
            totalPendingShares:    0,
            assetsUnderManagement: netAumAfterRemoval,
            availableToWithdraw:   netAumAfterRemoval,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           netAumAfterRemoval,
            shares:           initialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(ISkyStrategy(skyUnderlyingStrategy).availableToWithdraw(), netAumAfterRemoval);
        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), savingsUsdsShares);

        assertEq(fundsAsset.balanceOf(address(pool)),         poolLiquidity - fundAmount);
        assertEq(fundsAsset.balanceOf(skyUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(strategyDelegate),      0);
        assertEq(fundsAsset.balanceOf(treasury),              0);

        /**********************************************************************************************************************************/
        /*** Fund again to collect the fees and mint a round number of shares                                                           ***/
        /**********************************************************************************************************************************/

        uint256 additionalShares     = additionalFunding * initialShares / netAumAfterRemoval;  // 100_000e6.
        uint256 totalSharesAfterFund = initialShares + additionalShares;                        // 600_000e6 - 1.
        uint256 aumAfterFund         = netAumAfterRemoval + additionalFunding;                  // 605_100e6.

        fundStrategyManager(address(poolManager), skyStrategyManager, additionalFunding);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount - additionalFunding + aumAfterFund,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount - additionalFunding
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              aumAfterFund,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: aumAfterFund
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalSharesAfterFund,
            totalPendingShares:    0,
            assetsUnderManagement: aumAfterFund,
            availableToWithdraw:   aumAfterFund,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           aumAfterFund,
            shares:           totalSharesAfterFund,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(ISkyStrategy(skyUnderlyingStrategy).availableToWithdraw(), aumAfterFund);

        assertEq(fundsAsset.balanceOf(skyUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(strategyDelegate),      expectedDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),              expectedProtocolFee);

        /**********************************************************************************************************************************/
        /*** Repeat the funding and confirm the removed exit-fee discount is not charged again                                          ***/
        /**********************************************************************************************************************************/

        uint256 secondAdditionalShares = additionalFunding * totalSharesAfterFund / aumAfterFund;  // 100_000e6.
        uint256 finalTotalShares       = totalSharesAfterFund + secondAdditionalShares;            // 700_000e6 - 1.
        uint256 finalAum               = aumAfterFund + additionalFunding;                         // 705_950e6 + 1.

        fundStrategyManager(address(poolManager), skyStrategyManager, additionalFunding);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity - fundAmount - 2 * additionalFunding + finalAum,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - fundAmount - 2 * additionalFunding
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              finalAum,
            unrealizedLosses: 0
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        false,
            impairedAssets:          0,
            lastRecordedTotalAssets: finalAum
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           finalTotalShares,
            totalPendingShares:    0,
            assetsUnderManagement: finalAum,
            availableToWithdraw:   finalAum,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      address(poolManager),
            assets:           finalAum,
            shares:           finalTotalShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(ISkyStrategy(skyUnderlyingStrategy).availableToWithdraw(), finalAum);

        assertEq(fundsAsset.balanceOf(skyUnderlyingStrategy), 0);
        assertEq(fundsAsset.balanceOf(strategyDelegate),      expectedDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),              expectedProtocolFee);
    }

}
