// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IAaveV3Strategy,
    IERC20,
    IERC20Like,
    IPoolManager,
    IStrategyManager,
    ISkyStrategy
} from "../../../contracts/interfaces/Interfaces.sol";

import { AaveV3StrategyTestBase } from "../../integration/aave-v3-strategy/AaveV3StrategyTestBase.sol";
import { SkyStrategyTestBase }    from "../../integration/sky-strategy/SkyStrategyTestBase.sol";

contract AaveV3StrategyRecoveryTests is AaveV3StrategyTestBase {

    address firstOpenTermLoanManager;
    address firstPool;
    address firstPoolManager;
    address secondOpenTermLoanManager;
    address secondPool;
    address secondPoolManager;

    uint256 firstPoolFunding  = 600_000e6;
    uint256 poolLiquidity     = 1_000_000e6;
    uint256 roundingError     = 1;
    uint256 secondPoolFunding = 400_000e6;

    uint256 firstPoolShares;
    uint256 pendingShares;
    uint256 secondPoolShares;
    uint256 totalStrategyShares;

    function test_recoverPosition_afterEveryPoolRemovesStrategyManager() external {
        /**********************************************************************************************************************************/
        /*** Fund the shared strategy from two Pools and leave one redemption pending                                                   ***/
        /**********************************************************************************************************************************/

        firstPool        = address(pool);
        firstPoolManager = address(poolManager);

        ( secondPool, secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", aaveV3StrategyManager);

        firstOpenTermLoanManager  = IPoolManager(firstPoolManager).strategyList(0);
        secondOpenTermLoanManager = IPoolManager(secondPoolManager).strategyList(0);

        deposit(firstPool,  lp, firstPoolFunding + secondPoolFunding);
        deposit(secondPool, lp, firstPoolFunding + secondPoolFunding);

        fundStrategyManager(firstPoolManager,  aaveV3StrategyManager, firstPoolFunding);
        fundStrategyManager(secondPoolManager, aaveV3StrategyManager, secondPoolFunding);

        firstPoolShares     = firstPoolFunding - 2 * roundingError;  // 600_000e6 - 2
        secondPoolShares    = secondPoolFunding;                     // 400_000e6
        totalStrategyShares = firstPoolShares + secondPoolShares;    // 1_000_000e6 - 2
        pendingShares       = firstPoolShares / 4;                   // (600_000e6 - 2) / 4

        requestRedeemFromStrategyManager(firstPoolManager, aaveV3StrategyManager, pendingShares);

        assertEq(IPoolManager(firstPoolManager).isStrategyManager(aaveV3StrategyManager), true);
        assertEq(IPoolManager(firstPoolManager).strategyCapOf(aaveV3StrategyManager),     type(uint256).max);
        assertEq(IPoolManager(firstPoolManager).strategyListLength(),                     2);
        assertEq(IPoolManager(firstPoolManager).strategyList(0),                          firstOpenTermLoanManager);
        assertEq(IPoolManager(firstPoolManager).strategyList(1),                          aaveV3StrategyManager);

        assertEq(IPoolManager(secondPoolManager).isStrategyManager(aaveV3StrategyManager), true);
        assertEq(IPoolManager(secondPoolManager).strategyCapOf(aaveV3StrategyManager),     type(uint256).max);
        assertEq(IPoolManager(secondPoolManager).strategyListLength(),                     2);
        assertEq(IPoolManager(secondPoolManager).strategyList(0),                          secondOpenTermLoanManager);
        assertEq(IPoolManager(secondPoolManager).strategyList(1),                          aaveV3StrategyManager);

        /**********************************************************************************************************************************/
        /*** Recognize the complete loss and confirm both Pools value the strategy at zero                                              ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recognizeLoss();

        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).isLossRecognized(), true);
        assertEq(IAaveV3Strategy(aaveV3UnderlyingStrategy).impairedAssets(),   0);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - firstPoolFunding,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - firstPoolFunding
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
            aTokenBalance:           totalStrategyShares,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           totalStrategyShares,
            totalPendingShares:    pendingShares,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           firstPoolShares,
            pendingShares:    pendingShares,
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

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:LOSS_RECOGNIZED");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(firstPoolManager, 1, "");

        /**********************************************************************************************************************************/
        /*** Remove the Strategy Manager from the first Pool while both positions retain their shares                                   ***/
        /**********************************************************************************************************************************/

        removeStrategyManager(firstPoolManager, aaveV3StrategyManager);

        assertEq(IPoolManager(firstPoolManager).isStrategyManager(aaveV3StrategyManager), false);
        assertEq(IPoolManager(firstPoolManager).strategyCapOf(aaveV3StrategyManager),     0);
        assertEq(IPoolManager(firstPoolManager).strategyListLength(),                     1);
        assertEq(IPoolManager(firstPoolManager).strategyList(0),                          firstOpenTermLoanManager);

        assertEq(IPoolManager(secondPoolManager).isStrategyManager(aaveV3StrategyManager), true);
        assertEq(IPoolManager(secondPoolManager).strategyCapOf(aaveV3StrategyManager),     type(uint256).max);
        assertEq(IPoolManager(secondPoolManager).strategyListLength(),                     2);
        assertEq(IPoolManager(secondPoolManager).strategyList(0),                          secondOpenTermLoanManager);
        assertEq(IPoolManager(secondPoolManager).strategyList(1),                          aaveV3StrategyManager);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - firstPoolFunding,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - firstPoolFunding
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
            aTokenBalance:           totalStrategyShares,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           totalStrategyShares,
            totalPendingShares:    pendingShares,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           firstPoolShares,
            pendingShares:    pendingShares,
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

        /**********************************************************************************************************************************/
        /*** Remove the Strategy Manager from the second Pool and confirm no Pool remains allocated                                     ***/
        /**********************************************************************************************************************************/

        removeStrategyManager(secondPoolManager, aaveV3StrategyManager);

        assertEq(IPoolManager(firstPoolManager).isStrategyManager(aaveV3StrategyManager), false);
        assertEq(IPoolManager(firstPoolManager).strategyCapOf(aaveV3StrategyManager),     0);
        assertEq(IPoolManager(firstPoolManager).strategyListLength(),                     1);
        assertEq(IPoolManager(firstPoolManager).strategyList(0),                          firstOpenTermLoanManager);

        assertEq(IPoolManager(secondPoolManager).isStrategyManager(aaveV3StrategyManager), false);
        assertEq(IPoolManager(secondPoolManager).strategyCapOf(aaveV3StrategyManager),     0);
        assertEq(IPoolManager(secondPoolManager).strategyListLength(),                     1);
        assertEq(IPoolManager(secondPoolManager).strategyList(0),                          secondOpenTermLoanManager);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - firstPoolFunding,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - firstPoolFunding
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
            aTokenBalance:           totalStrategyShares,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           totalStrategyShares,
            totalPendingShares:    pendingShares,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           firstPoolShares,
            pendingShares:    pendingShares,
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

        /**********************************************************************************************************************************/
        /*** Recover every aToken to the Maple treasury without reviving either Pool                                                    ***/
        /**********************************************************************************************************************************/

        uint256 treasuryAssetsBefore_     = fundsAsset.balanceOf(treasury);
        uint256 treasuryAaveSharesBefore_ = IERC20(aaveToken).balanceOf(treasury);

        vm.prank(strategyDelegate);
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recoverPosition();

        assertEq(fundsAsset.balanceOf(treasury),        treasuryAssetsBefore_);
        assertEq(IERC20(aaveToken).balanceOf(treasury), treasuryAaveSharesBefore_ + totalStrategyShares);

        assertEq(IPoolManager(firstPoolManager).isStrategyManager(aaveV3StrategyManager), false);
        assertEq(IPoolManager(firstPoolManager).strategyCapOf(aaveV3StrategyManager),     0);
        assertEq(IPoolManager(firstPoolManager).strategyListLength(),                     1);
        assertEq(IPoolManager(firstPoolManager).strategyList(0),                          firstOpenTermLoanManager);

        assertEq(IPoolManager(secondPoolManager).isStrategyManager(aaveV3StrategyManager), false);
        assertEq(IPoolManager(secondPoolManager).strategyCapOf(aaveV3StrategyManager),     0);
        assertEq(IPoolManager(secondPoolManager).strategyListLength(),                     1);
        assertEq(IPoolManager(secondPoolManager).strategyList(0),                          secondOpenTermLoanManager);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - firstPoolFunding,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - firstPoolFunding
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
            aTokenBalance:           0,
            lastRecordedTotalAssets: 0,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           totalStrategyShares,
            totalPendingShares:    pendingShares,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           firstPoolShares,
            pendingShares:    pendingShares,
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

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3S:RP:ZERO_BALANCE");
        IAaveV3Strategy(aaveV3UnderlyingStrategy).recoverPosition();

        vm.prank(strategyDelegate);
        vm.expectRevert("PM:RF:INVALID_STRATEGY_OR_MANAGER");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(firstPoolManager, 1, "");

        vm.prank(strategyDelegate);
        vm.expectRevert("PM:RF:INVALID_STRATEGY_OR_MANAGER");
        IStrategyManager(aaveV3StrategyManager).fundStrategyManager(secondPoolManager, 1, "");
    }

}

contract SparkLendStrategyRecoveryTests is AaveV3StrategyRecoveryTests {

    function setUp() public override {
        aaveToken                   = SPARK_USDC;
        roundingError               = 0;  // Spark reports the full nominal supply at this fork block.
        useVirtualUnderlyingBalance = false;

        super.setUp();
    }

}

contract SkyStrategyRecoveryTests is SkyStrategyTestBase {

    address firstOpenTermLoanManager;
    address firstPool;
    address firstPoolManager;
    address secondOpenTermLoanManager;
    address secondPool;
    address secondPoolManager;

    uint256 firstPoolFunding  = 600_000e6;
    uint256 poolLiquidity     = 1_000_000e6;
    uint256 roundingError     = 1;
    uint256 secondPoolFunding = 400_000e6;

    uint256 firstPoolShares;
    uint256 pendingShares;
    uint256 secondPoolShares;
    uint256 totalStrategyShares;

    function test_recoverPosition_afterEveryPoolRemovesStrategyManager() external {
        /**********************************************************************************************************************************/
        /*** Fund the shared strategy from two Pools and leave one redemption pending                                                   ***/
        /**********************************************************************************************************************************/

        firstPool        = address(pool);
        firstPoolManager = address(poolManager);

        ( secondPool, secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", skyStrategyManager);

        firstOpenTermLoanManager  = IPoolManager(firstPoolManager).strategyList(0);
        secondOpenTermLoanManager = IPoolManager(secondPoolManager).strategyList(0);

        deposit(firstPool,  lp, firstPoolFunding + secondPoolFunding);
        deposit(secondPool, lp, firstPoolFunding + secondPoolFunding);

        fundStrategyManager(firstPoolManager,  skyStrategyManager, firstPoolFunding);
        fundStrategyManager(secondPoolManager, skyStrategyManager, secondPoolFunding);

        firstPoolShares     = firstPoolFunding - roundingError;    // 600_000e6 - 1
        secondPoolShares    = secondPoolFunding;                   // 400_000e6
        totalStrategyShares = firstPoolShares + secondPoolShares;  // 1_000_000e6 - 1
        pendingShares       = firstPoolShares / 4;                 // (600_000e6 - 1) / 4

        requestRedeemFromStrategyManager(firstPoolManager, skyStrategyManager, pendingShares);

        assertEq(IPoolManager(firstPoolManager).isStrategyManager(skyStrategyManager), true);
        assertEq(IPoolManager(firstPoolManager).strategyCapOf(skyStrategyManager),     type(uint256).max);
        assertEq(IPoolManager(firstPoolManager).strategyListLength(),                  2);
        assertEq(IPoolManager(firstPoolManager).strategyList(0),                       firstOpenTermLoanManager);
        assertEq(IPoolManager(firstPoolManager).strategyList(1),                       skyStrategyManager);

        assertEq(IPoolManager(secondPoolManager).isStrategyManager(skyStrategyManager), true);
        assertEq(IPoolManager(secondPoolManager).strategyCapOf(skyStrategyManager),     type(uint256).max);
        assertEq(IPoolManager(secondPoolManager).strategyListLength(),                  2);
        assertEq(IPoolManager(secondPoolManager).strategyList(0),                       secondOpenTermLoanManager);
        assertEq(IPoolManager(secondPoolManager).strategyList(1),                       skyStrategyManager);

        uint256 savingsUsdsShares_ = IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy);

        /**********************************************************************************************************************************/
        /*** Recognize the complete loss and confirm both Pools value the strategy at zero                                              ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).recognizeLoss();

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        true,
            impairedAssets:          0,
            lastRecordedTotalAssets: 0
        });

        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), savingsUsdsShares_);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - firstPoolFunding,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - firstPoolFunding
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity - secondPoolFunding,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - secondPoolFunding
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalStrategyShares,
            totalPendingShares:    pendingShares,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           firstPoolShares,
            pendingShares:    pendingShares,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           0,
            shares:           secondPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:LOSS_RECOGNIZED");
        IStrategyManager(skyStrategyManager).fundStrategyManager(firstPoolManager, 1, "");

        /**********************************************************************************************************************************/
        /*** Remove the Strategy Manager from the first Pool while both positions retain their shares                                   ***/
        /**********************************************************************************************************************************/

        removeStrategyManager(firstPoolManager, skyStrategyManager);

        assertEq(IPoolManager(firstPoolManager).isStrategyManager(skyStrategyManager), false);
        assertEq(IPoolManager(firstPoolManager).strategyCapOf(skyStrategyManager),     0);
        assertEq(IPoolManager(firstPoolManager).strategyListLength(),                  1);
        assertEq(IPoolManager(firstPoolManager).strategyList(0),                       firstOpenTermLoanManager);

        assertEq(IPoolManager(secondPoolManager).isStrategyManager(skyStrategyManager), true);
        assertEq(IPoolManager(secondPoolManager).strategyCapOf(skyStrategyManager),     type(uint256).max);
        assertEq(IPoolManager(secondPoolManager).strategyListLength(),                  2);
        assertEq(IPoolManager(secondPoolManager).strategyList(0),                       secondOpenTermLoanManager);
        assertEq(IPoolManager(secondPoolManager).strategyList(1),                       skyStrategyManager);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - firstPoolFunding,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - firstPoolFunding
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity - secondPoolFunding,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - secondPoolFunding
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalStrategyShares,
            totalPendingShares:    pendingShares,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           firstPoolShares,
            pendingShares:    pendingShares,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           0,
            shares:           secondPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), savingsUsdsShares_);

        /**********************************************************************************************************************************/
        /*** Remove the Strategy Manager from the second Pool and confirm no Pool remains allocated                                     ***/
        /**********************************************************************************************************************************/

        removeStrategyManager(secondPoolManager, skyStrategyManager);

        assertEq(IPoolManager(firstPoolManager).isStrategyManager(skyStrategyManager), false);
        assertEq(IPoolManager(firstPoolManager).strategyCapOf(skyStrategyManager),     0);
        assertEq(IPoolManager(firstPoolManager).strategyListLength(),                  1);
        assertEq(IPoolManager(firstPoolManager).strategyList(0),                       firstOpenTermLoanManager);

        assertEq(IPoolManager(secondPoolManager).isStrategyManager(skyStrategyManager), false);
        assertEq(IPoolManager(secondPoolManager).strategyCapOf(skyStrategyManager),     0);
        assertEq(IPoolManager(secondPoolManager).strategyListLength(),                  1);
        assertEq(IPoolManager(secondPoolManager).strategyList(0),                       secondOpenTermLoanManager);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - firstPoolFunding,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - firstPoolFunding
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity - secondPoolFunding,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - secondPoolFunding
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalStrategyShares,
            totalPendingShares:    pendingShares,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           firstPoolShares,
            pendingShares:    pendingShares,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           0,
            shares:           secondPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), savingsUsdsShares_);

        /**********************************************************************************************************************************/
        /*** Recover every sUSDS share to the Maple treasury without reviving either Pool                                               ***/
        /**********************************************************************************************************************************/

        uint256 treasuryAssetsBefore_            = fundsAsset.balanceOf(treasury);
        uint256 treasurySavingsUsdsSharesBefore_ = IERC20Like(SAVINGS_USDS).balanceOf(treasury);

        vm.prank(strategyDelegate);
        ISkyStrategy(skyUnderlyingStrategy).recoverPosition();

        assertEq(fundsAsset.balanceOf(treasury),                            treasuryAssetsBefore_);
        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(treasury),              treasurySavingsUsdsSharesBefore_ + savingsUsdsShares_);
        assertEq(IERC20Like(SAVINGS_USDS).balanceOf(skyUnderlyingStrategy), 0);

        assertEq(IPoolManager(firstPoolManager).isStrategyManager(skyStrategyManager), false);
        assertEq(IPoolManager(firstPoolManager).strategyCapOf(skyStrategyManager),     0);
        assertEq(IPoolManager(firstPoolManager).strategyListLength(),                  1);
        assertEq(IPoolManager(firstPoolManager).strategyList(0),                       firstOpenTermLoanManager);

        assertEq(IPoolManager(secondPoolManager).isStrategyManager(skyStrategyManager), false);
        assertEq(IPoolManager(secondPoolManager).strategyCapOf(skyStrategyManager),     0);
        assertEq(IPoolManager(secondPoolManager).strategyListLength(),                  1);
        assertEq(IPoolManager(secondPoolManager).strategyList(0),                       secondOpenTermLoanManager);

        assertPoolState({
            pool:               firstPool,
            totalAssets:        poolLiquidity - firstPoolFunding,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - firstPoolFunding
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        poolLiquidity - secondPoolFunding,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - secondPoolFunding
        });

        assertSkyStrategyStorage({
            strategy:                skyUnderlyingStrategy,
            isLossRecognized:        true,
            impairedAssets:          0,
            lastRecordedTotalAssets: 0
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              0,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           totalStrategyShares,
            totalPendingShares:    pendingShares,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           firstPoolShares,
            pendingShares:    pendingShares,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      secondPoolManager,
            assets:           0,
            shares:           secondPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        vm.prank(strategyDelegate);
        vm.expectRevert("MSS:RP:ZERO_BALANCE");
        ISkyStrategy(skyUnderlyingStrategy).recoverPosition();

        vm.prank(strategyDelegate);
        vm.expectRevert("PM:RF:INVALID_STRATEGY_OR_MANAGER");
        IStrategyManager(skyStrategyManager).fundStrategyManager(firstPoolManager, 1, "");

        vm.prank(strategyDelegate);
        vm.expectRevert("PM:RF:INVALID_STRATEGY_OR_MANAGER");
        IStrategyManager(skyStrategyManager).fundStrategyManager(secondPoolManager, 1, "");
    }

}
