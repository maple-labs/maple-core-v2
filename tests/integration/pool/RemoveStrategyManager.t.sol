// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAavePoolLike,
    IAaveV3Strategy,
    IDefiStrategyLike,
    IERC4626Like,
    IMockERC20,
    IMapleProxyFactory,
    IPoolManager,
    IStrategyManager,
    IUnderlyingStrategyLike
} from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

abstract contract RemoveStrategyManagerTestBase is TestBaseWithAssertions {

    address aavePool;
    address allocationLossDeployer;
    address allocationYieldDeployer;
    address bootstrapStrategyManager;
    address liquidityProvider = makeAddr("liquidityProvider");
    address openTermLoanManager;
    address strategyManagerToRemove;
    address strategyToken;
    address underlyingStrategy;
    address yieldBearingToken;

    bool isSkyStrategy;

    uint256 expectedBootstrapAssets;
    uint256 expectedBootstrapShares;
    uint256 expectedFirstPoolAssets;
    uint256 expectedFirstPoolShares;
    uint256 expectedPartialImpairmentPoolAssets;
    uint256 expectedPartialImpairmentStrategyAssets;
    uint256 expectedPartialImpairmentStrategyLosses;
    uint256 expectedSecondPoolAssets;
    uint256 expectedSecondPoolShares;
    uint256 expectedStrategyManagerAssets;
    uint256 expectedStrategyManagerShares;
    uint256 expectedYieldAssets;
    uint256 expectedYieldDelegateFee;
    uint256 expectedYieldProtocolFee;

    function setUp() public virtual override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), MAINNET_FORK_BLOCK);

        fundsAsset = IMockERC20(USDC);

        _createAccounts();
        _createGlobals();
        _configureGlobals();
        _createFactories();
        _createPoolWithOTLM(poolDelegate);
        _configurePool();

        assertEq(poolManager.strategyListLength(), 1);

        openTermLoanManager = poolManager.strategyList(0);

        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).isInstance(openTermLoanManager), true);
    }

    function _setUpStrategyManager() internal {
        addStrategyManagerToPool(address(poolManager), strategyManagerToRemove);

        assertEq(poolManager.isStrategyManager(strategyManagerToRemove), true);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),     type(uint256).max);
        assertEq(poolManager.strategyListLength(),                       2);
        assertEq(poolManager.strategyList(0),                            openTermLoanManager);
        assertEq(poolManager.strategyList(1),                            strategyManagerToRemove);
    }

}

abstract contract RemoveStrategyManagerFailureTestBase is RemoveStrategyManagerTestBase {

    function testFork_removeStrategyManager_revert_contractPaused() external {
        vm.prank(governor);
        globals.setContractPause(address(poolManager), true);

        vm.prank(operationalAdmin);
        vm.expectRevert("PM:PAUSED");
        poolManager.removeStrategyManager(strategyManagerToRemove);
    }

    function testFork_removeStrategyManager_revert_nonZeroAssets() external {
        uint256 fundAssets = 100_000e6;

        deposit(address(pool), liquidityProvider, fundAssets);
        fundStrategyManager(address(poolManager), strategyManagerToRemove, fundAssets);

        assertEq(IStrategyManager(strategyManagerToRemove).assetsOf(address(poolManager)),           expectedFirstPoolAssets);
        assertEq(IStrategyManager(strategyManagerToRemove).unrealizedLossesOf(address(poolManager)), 0);

        vm.prank(operationalAdmin);
        vm.expectRevert("PM:RSM:NON_ZERO_ASSETS");
        poolManager.removeStrategyManager(strategyManagerToRemove);
    }

    function testFork_removeStrategyManager_revert_nonZeroAssetsAndLosses() external {
        uint256 fundAssets = 100_000e6;
        uint256 impairment = 10_000e6;

        deposit(address(pool), liquidityProvider, fundAssets);
        fundStrategyManager(address(poolManager), strategyManagerToRemove, fundAssets);

        impairStrategy(underlyingStrategy, impairment);

        assertEq(IStrategyManager(strategyManagerToRemove).assetsOf(address(poolManager)),           expectedFirstPoolAssets);
        assertEq(IStrategyManager(strategyManagerToRemove).unrealizedLossesOf(address(poolManager)), impairment);

        vm.prank(operationalAdmin);
        vm.expectRevert("PM:RSM:NON_ZERO_ASSETS");
        poolManager.removeStrategyManager(strategyManagerToRemove);
    }

    function testFork_removeStrategyManager_revert_notOperationalAdmin() external {
        vm.expectRevert("PM:NOT_OPERATIONAL_ADMIN");
        poolManager.removeStrategyManager(strategyManagerToRemove);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:NOT_OPERATIONAL_ADMIN");
        poolManager.removeStrategyManager(strategyManagerToRemove);

        vm.prank(governor);
        vm.expectRevert("PM:NOT_OPERATIONAL_ADMIN");
        poolManager.removeStrategyManager(strategyManagerToRemove);

        vm.prank(securityAdmin);
        vm.expectRevert("PM:NOT_OPERATIONAL_ADMIN");
        poolManager.removeStrategyManager(strategyManagerToRemove);
    }

    function testFork_removeStrategyManager_revert_notStrategyManager() external {
        vm.prank(operationalAdmin);
        vm.expectRevert("PM:RSM:NOT_STRATEGY_MANAGER");
        poolManager.removeStrategyManager(makeAddr("notStrategyManager"));
    }

    function testFork_removeStrategyManager_revert_openTermLoanManager() external {
        assertEq(poolManager.isStrategyManager(openTermLoanManager), false);
        assertEq(poolManager.strategyList(0),                        openTermLoanManager);

        vm.prank(operationalAdmin);
        vm.expectRevert("PM:RSM:NOT_STRATEGY_MANAGER");
        poolManager.removeStrategyManager(openTermLoanManager);
    }

    function testFork_removeStrategyManager_revert_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(operationalAdmin);
        vm.expectRevert("PM:PAUSED");
        poolManager.removeStrategyManager(strategyManagerToRemove);
    }

    function testFork_removeStrategyManager_revert_afterRemoval() external {
        assertEq(poolManager.isStrategyManager(strategyManagerToRemove), true);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),     type(uint256).max);
        assertEq(poolManager.strategyListLength(),                       2);
        assertEq(poolManager.strategyList(0),                            openTermLoanManager);
        assertEq(poolManager.strategyList(1),                            strategyManagerToRemove);

        removeStrategyManager(address(poolManager), strategyManagerToRemove);

        assertEq(poolManager.isStrategyManager(strategyManagerToRemove), false);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),     0);
        assertEq(poolManager.strategyListLength(),                       1);
        assertEq(poolManager.strategyList(0),                            openTermLoanManager);

        vm.prank(operationalAdmin);
        vm.expectRevert("PM:RSM:NOT_STRATEGY_MANAGER");
        poolManager.removeStrategyManager(strategyManagerToRemove);
    }

}

abstract contract RemoveStrategyManagerSuccessTestBase is RemoveStrategyManagerTestBase {

    function testFork_removeStrategyManager_success_afterFullRedemption() external {
        uint256 fundAssets = 100_000e6;
        uint256 fundShares = 100_000e6;

        /**********************************************************************************************************************************/
        /*** Deposit liquidity and fund the strategy manager                                                                            ***/
        /**********************************************************************************************************************************/

        deposit(address(pool), liquidityProvider, fundAssets);

        fundStrategyManager(address(poolManager), strategyManagerToRemove, fundAssets);

        assertStrategyManager({
            strategyManager:       strategyManagerToRemove,
            totalShares:           expectedFirstPoolShares,
            totalPendingShares:    0,
            assetsUnderManagement: expectedFirstPoolAssets,
            availableToWithdraw:   expectedFirstPoolAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      address(poolManager),
            assets:           expectedFirstPoolAssets,
            shares:           expectedFirstPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertUnderlyingStrategy({
            strategy:              underlyingStrategy,
            assetsUnderManagement: expectedFirstPoolAssets,
            availableToWithdraw:   expectedFirstPoolAssets,
            unrealizedLosses:      0
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        expectedFirstPoolAssets,
            totalSupply:        fundShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        /**********************************************************************************************************************************/
        /*** Request redemption of all strategy manager shares                                                                          ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManagerToRemove, expectedFirstPoolShares);

        assertStrategyManager({
            strategyManager:       strategyManagerToRemove,
            totalShares:           expectedFirstPoolShares,
            totalPendingShares:    expectedFirstPoolShares,
            assetsUnderManagement: expectedFirstPoolAssets,
            availableToWithdraw:   expectedFirstPoolAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      address(poolManager),
            assets:           expectedFirstPoolAssets,
            shares:           expectedFirstPoolShares,
            pendingShares:    expectedFirstPoolShares,
            unrealizedLosses: 0
        });

        assertUnderlyingStrategy({
            strategy:              underlyingStrategy,
            assetsUnderManagement: expectedFirstPoolAssets,
            availableToWithdraw:   expectedFirstPoolAssets,
            unrealizedLosses:      0
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        expectedFirstPoolAssets,
            totalSupply:        fundShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        /**********************************************************************************************************************************/
        /*** Process the full strategy manager redemption                                                                               ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), strategyManagerToRemove, expectedFirstPoolShares);

        assertEq(poolManager.isStrategyManager(strategyManagerToRemove), true);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),     type(uint256).max);
        assertEq(poolManager.strategyListLength(),                       2);
        assertEq(poolManager.strategyList(0),                            openTermLoanManager);
        assertEq(poolManager.strategyList(1),                            strategyManagerToRemove);

        assertStrategyManager({
            strategyManager:       strategyManagerToRemove,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertUnderlyingStrategy({
            strategy:              underlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        expectedFirstPoolAssets,
            totalSupply:        fundShares,
            unrealizedLosses:   0,
            availableLiquidity: expectedFirstPoolAssets
        });

        /**********************************************************************************************************************************/
        /*** Remove the strategy manager from the pool                                                                                  ***/
        /**********************************************************************************************************************************/

        removeStrategyManager(address(poolManager), strategyManagerToRemove);

        assertEq(poolManager.isStrategyManager(strategyManagerToRemove), false);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),     0);
        assertEq(poolManager.strategyListLength(),                       1);
        assertEq(poolManager.strategyList(0),                            openTermLoanManager);

        assertStrategyManager({
            strategyManager:       strategyManagerToRemove,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertUnderlyingStrategy({
            strategy:              underlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        expectedFirstPoolAssets,
            totalSupply:        fundShares,
            unrealizedLosses:   0,
            availableLiquidity: expectedFirstPoolAssets
        });
    }

    function testFork_removeStrategyManager_success_afterPartialImpairmentAndFullRedemption() external {
        uint256 fundAssets = 100_000e6;
        uint256 fundShares = 100_000e6;
        uint256 impairment = 10_000e6;

        /**********************************************************************************************************************************/
        /*** Fund and partially impair the strategy                                                                                     ***/
        /**********************************************************************************************************************************/

        deposit(address(pool), liquidityProvider, fundAssets);
        fundStrategyManager(address(poolManager), strategyManagerToRemove, fundAssets);
        impairStrategy(underlyingStrategy, impairment);

        /**********************************************************************************************************************************/
        /*** Request redemption of all strategy manager shares                                                                          ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManagerToRemove, expectedFirstPoolShares);

        assertEq(poolManager.isStrategyManager(strategyManagerToRemove), true);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),     type(uint256).max);
        assertEq(poolManager.strategyListLength(),                       2);
        assertEq(poolManager.strategyList(0),                            openTermLoanManager);
        assertEq(poolManager.strategyList(1),                            strategyManagerToRemove);

        assertStrategyManager({
            strategyManager:       strategyManagerToRemove,
            totalShares:           expectedFirstPoolShares,
            totalPendingShares:    expectedFirstPoolShares,
            assetsUnderManagement: expectedFirstPoolAssets,
            availableToWithdraw:   expectedFirstPoolAssets,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      address(poolManager),
            assets:           expectedFirstPoolAssets,
            shares:           expectedFirstPoolShares,
            pendingShares:    expectedFirstPoolShares,
            unrealizedLosses: impairment
        });

        assertUnderlyingStrategy({
            strategy:              underlyingStrategy,
            assetsUnderManagement: expectedFirstPoolAssets,
            availableToWithdraw:   expectedFirstPoolAssets,
            unrealizedLosses:      impairment
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        expectedFirstPoolAssets,
            totalSupply:        fundShares,
            unrealizedLosses:   impairment,
            availableLiquidity: 0
        });

        /**********************************************************************************************************************************/
        /*** Process the full redemption with a partial impairment                                                                      ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), strategyManagerToRemove, expectedFirstPoolShares);

        assertEq(poolManager.isStrategyManager(strategyManagerToRemove), true);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),     type(uint256).max);
        assertEq(poolManager.strategyListLength(),                       2);
        assertEq(poolManager.strategyList(0),                            openTermLoanManager);
        assertEq(poolManager.strategyList(1),                            strategyManagerToRemove);

        assertStrategyManager({
            strategyManager:       strategyManagerToRemove,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: expectedPartialImpairmentStrategyAssets,
            availableToWithdraw:   expectedPartialImpairmentStrategyAssets,
            unrealizedLosses:      expectedPartialImpairmentStrategyLosses
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertUnderlyingStrategy({
            strategy:              underlyingStrategy,
            assetsUnderManagement: expectedPartialImpairmentStrategyAssets,
            availableToWithdraw:   expectedPartialImpairmentStrategyAssets,
            unrealizedLosses:      expectedPartialImpairmentStrategyLosses
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        expectedPartialImpairmentPoolAssets,
            totalSupply:        fundShares,
            unrealizedLosses:   0,
            availableLiquidity: expectedPartialImpairmentPoolAssets
        });

        /**********************************************************************************************************************************/
        /*** Remove the strategy manager with residual impaired assets                                                                  ***/
        /**********************************************************************************************************************************/

        removeStrategyManager(address(poolManager), strategyManagerToRemove);

        assertEq(poolManager.isStrategyManager(strategyManagerToRemove), false);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),     0);
        assertEq(poolManager.strategyListLength(),                       1);
        assertEq(poolManager.strategyList(0),                            openTermLoanManager);

        assertStrategyManager({
            strategyManager:       strategyManagerToRemove,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: expectedPartialImpairmentStrategyAssets,
            availableToWithdraw:   expectedPartialImpairmentStrategyAssets,
            unrealizedLosses:      expectedPartialImpairmentStrategyLosses
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertUnderlyingStrategy({
            strategy:              underlyingStrategy,
            assetsUnderManagement: expectedPartialImpairmentStrategyAssets,
            availableToWithdraw:   expectedPartialImpairmentStrategyAssets,
            unrealizedLosses:      expectedPartialImpairmentStrategyLosses
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        expectedPartialImpairmentPoolAssets,
            totalSupply:        fundShares,
            unrealizedLosses:   0,
            availableLiquidity: expectedPartialImpairmentPoolAssets
        });
    }

    function testFork_removeStrategyManager_success_afterRecognizedLossWithOutstandingShares() external {
        uint256 fundAssets   = 100_000e6;
        uint256 fundShares   = 100_000e6;
        uint256 redeemShares = expectedFirstPoolShares / 4;

        /**********************************************************************************************************************************/
        /*** Fund the strategy manager and request a partial redemption                                                                 ***/
        /**********************************************************************************************************************************/

        deposit(address(pool), liquidityProvider, fundAssets);

        fundStrategyManager(address(poolManager), strategyManagerToRemove, fundAssets);
        requestRedeemFromStrategyManager(address(poolManager), strategyManagerToRemove, redeemShares);

        /**********************************************************************************************************************************/
        /*** Recognize the full underlying strategy loss                                                                                ***/
        /**********************************************************************************************************************************/

        // Allocation recognizes a specific deployer's loss, while DeFi strategies recognize the entire position.
        if (allocationLossDeployer == address(0)) {
            vm.prank(operationalAdmin);
            IDefiStrategyLike(underlyingStrategy).recognizeLoss();
        } else {
            setManagedWallet({
                strategy_:        underlyingStrategy,
                managedWallet_:   allocationLossDeployer,
                canDeployAssets_: true,
                canReturnAssets_: false,
                canRealizeYield_: false,
                deploymentCap_:   fundAssets
            });

            deployAssets(underlyingStrategy, allocationLossDeployer, fundAssets);
            recognizeLoss(underlyingStrategy, allocationLossDeployer, fundAssets);
        }

        assertEq(poolManager.isStrategyManager(strategyManagerToRemove), true);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),     type(uint256).max);
        assertEq(poolManager.strategyListLength(),                       2);
        assertEq(poolManager.strategyList(0),                            openTermLoanManager);
        assertEq(poolManager.strategyList(1),                            strategyManagerToRemove);

        assertStrategyManager({
            strategyManager:       strategyManagerToRemove,
            totalShares:           expectedFirstPoolShares,
            totalPendingShares:    redeemShares,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           expectedFirstPoolShares,
            pendingShares:    redeemShares,
            unrealizedLosses: 0
        });

        assertUnderlyingStrategy({
            strategy:              underlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        0,
            totalSupply:        fundShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        /**********************************************************************************************************************************/
        /*** Remove the strategy manager with outstanding shares                                                                        ***/
        /**********************************************************************************************************************************/

        removeStrategyManager(address(poolManager), strategyManagerToRemove);

        assertEq(poolManager.isStrategyManager(strategyManagerToRemove), false);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),     0);
        assertEq(poolManager.strategyListLength(),                       1);
        assertEq(poolManager.strategyList(0),                            openTermLoanManager);

        assertStrategyManager({
            strategyManager:       strategyManagerToRemove,
            totalShares:           expectedFirstPoolShares,
            totalPendingShares:    redeemShares,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           expectedFirstPoolShares,
            pendingShares:    redeemShares,
            unrealizedLosses: 0
        });

        assertUnderlyingStrategy({
            strategy:              underlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        0,
            totalSupply:        fundShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });
    }

    function testFork_removeStrategyManager_success_afterRecognizedLossAndDust() external {
        uint256 fundAssets = 100_000e6;

        /**********************************************************************************************************************************/
        /*** Fund the strategy manager and recognize the full underlying strategy loss                                                  ***/
        /**********************************************************************************************************************************/

        deposit(address(pool), liquidityProvider, fundAssets);
        fundStrategyManager(address(poolManager), strategyManagerToRemove, fundAssets);

        // Allocation recognizes a specific deployer's loss, while DeFi strategies recognize the entire position.
        if (allocationLossDeployer == address(0)) {
            vm.prank(operationalAdmin);
            IDefiStrategyLike(underlyingStrategy).recognizeLoss();
        } else {
            setManagedWallet({
                strategy_:        underlyingStrategy,
                managedWallet_:   allocationLossDeployer,
                canDeployAssets_: true,
                canReturnAssets_: false,
                canRealizeYield_: false,
                deploymentCap_:   fundAssets
            });

            deployAssets(underlyingStrategy, allocationLossDeployer, fundAssets);
            recognizeLoss(underlyingStrategy, allocationLossDeployer, fundAssets);
        }

        if (allocationLossDeployer == address(0)) {
            assertEq(IDefiStrategyLike(underlyingStrategy).isLossRecognized(), true);
        }

        assertStrategyManager({
            strategyManager:       strategyManagerToRemove,
            totalShares:           expectedFirstPoolShares,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           expectedFirstPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertUnderlyingStrategy({
            strategy:              underlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        0,
            totalSupply:        fundAssets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        /**********************************************************************************************************************************/
        /*** Dust the underlying strategy with its strategy token                                                                       ***/
        /**********************************************************************************************************************************/

        address donor = makeAddr("donor");

        uint256 fundsAssetDust             = 1e6;
        uint256 strategyTokenBalanceBefore = IMockERC20(strategyToken).balanceOf(underlyingStrategy);

        if (aavePool != address(0)) {
            deal(address(fundsAsset), donor, fundsAssetDust, true);

            vm.startPrank(donor);
            fundsAsset.approve(aavePool, fundsAssetDust);
            IAavePoolLike(aavePool).supply(address(fundsAsset), fundsAssetDust, donor, 0);
            vm.stopPrank();
        } else if (isSkyStrategy) {
            uint256 usdsDust = fundsAssetDust * 1e12;  // Convert USDC precision to USDS precision.

            deal(USDS, donor, usdsDust, true);

            vm.startPrank(donor);
            IMockERC20(USDS).approve(SAVINGS_USDS, usdsDust);
            IERC4626Like(SAVINGS_USDS).deposit(usdsDust, donor);
            vm.stopPrank();
        } else {
            deal(strategyToken, donor, fundsAssetDust, true);
        }

        uint256 strategyTokenDust = IMockERC20(strategyToken).balanceOf(donor);

        assertNotEq(strategyTokenDust, 0);
        assertEq(IMockERC20(strategyToken).balanceOf(underlyingStrategy), strategyTokenBalanceBefore);

        vm.prank(donor);
        IMockERC20(strategyToken).transfer(underlyingStrategy, strategyTokenDust);

        // Aave and Spark aToken balance conversions can round by one unit.
        assertApproxEqAbs(
            IMockERC20(strategyToken).balanceOf(underlyingStrategy),
            strategyTokenBalanceBefore + strategyTokenDust,
            1
        );

        uint256 strategyTokenBalanceAfter = IMockERC20(strategyToken).balanceOf(underlyingStrategy);

        assertEq(poolManager.isStrategyManager(strategyManagerToRemove), true);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),     type(uint256).max);
        assertEq(poolManager.strategyListLength(),                       2);
        assertEq(poolManager.strategyList(0),                            openTermLoanManager);
        assertEq(poolManager.strategyList(1),                            strategyManagerToRemove);

        assertStrategyManager({
            strategyManager:       strategyManagerToRemove,
            totalShares:           expectedFirstPoolShares,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           expectedFirstPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertUnderlyingStrategy({
            strategy:              underlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        0,
            totalSupply:        fundAssets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        /**********************************************************************************************************************************/
        /*** Remove the strategy manager without affecting the dust                                                                     ***/
        /**********************************************************************************************************************************/

        removeStrategyManager(address(poolManager), strategyManagerToRemove);

        assertEq(poolManager.isStrategyManager(strategyManagerToRemove), false);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),     0);
        assertEq(poolManager.strategyListLength(),                       1);
        assertEq(poolManager.strategyList(0),                            openTermLoanManager);

        assertEq(IMockERC20(strategyToken).balanceOf(underlyingStrategy), strategyTokenBalanceAfter);

        assertStrategyManager({
            strategyManager:       strategyManagerToRemove,
            totalShares:           expectedFirstPoolShares,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           expectedFirstPoolShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertUnderlyingStrategy({
            strategy:              underlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        0,
            totalSupply:        fundAssets,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });
    }

    function testFork_removeStrategyManager_success_afterYieldAndFeesAndFullRedemption() external {
        uint32 delegateFeeRate = 0.1e6;   // 10% of accrued yield.
        uint32 protocolFeeRate = 0.05e6;  // 5% of accrued yield.

        uint256 accruedYield;
        uint256 fundAssets = 100_000e6;
        uint256 fundShares = 100_000e6;
        uint256 grossAssets;

        /**********************************************************************************************************************************/
        /*** Configure fees and fund the strategy manager                                                                               ***/
        /**********************************************************************************************************************************/

        setStrategyDelegateFeeRate(underlyingStrategy, delegateFeeRate);
        setStrategyProtocolFeeRate(underlyingStrategy, protocolFeeRate);

        deposit(address(pool), liquidityProvider, fundAssets);
        fundStrategyManager(address(poolManager), strategyManagerToRemove, fundAssets);

        /**********************************************************************************************************************************/
        /*** Accrue yield in the underlying strategy                                                                                    ***/
        /**********************************************************************************************************************************/

        if (allocationYieldDeployer != address(0)) {
            // Allocation strategy.
            accruedYield = 20_000e6;
            grossAssets  = fundAssets + accruedYield;

            setManagedWallet({
                strategy_:        underlyingStrategy,
                managedWallet_:   allocationYieldDeployer,
                canDeployAssets_: false,
                canReturnAssets_: false,
                canRealizeYield_: true,
                deploymentCap_:   0
            });

            realizeYield(underlyingStrategy, allocationYieldDeployer, accruedYield, 365 days);

            vm.warp(block.timestamp + 365 days);
        } else if (yieldBearingToken != address(0)) {
            // Aave V3 and SparkLend strategies.
            uint256 assetsBeforeYield = IMockERC20(yieldBearingToken).balanceOf(underlyingStrategy);

            vm.warp(block.timestamp + 365 days);

            grossAssets  = IMockERC20(yieldBearingToken).balanceOf(underlyingStrategy);
            accruedYield = grossAssets - assetsBeforeYield;
        } else {
            // Sky strategy.
            uint256 annualYieldRate = 0.036e6;  // 3.6% annual yield at the fork block.

            accruedYield = fundAssets * annualYieldRate / HUNDRED_PERCENT;
            grossAssets  = expectedFirstPoolAssets + accruedYield;

            vm.warp(block.timestamp + 365 days);
        }

        expectedYieldDelegateFee = accruedYield * delegateFeeRate / HUNDRED_PERCENT;
        expectedYieldProtocolFee = accruedYield * protocolFeeRate / HUNDRED_PERCENT;
        expectedYieldAssets      = grossAssets - expectedYieldDelegateFee - expectedYieldProtocolFee;

        /**********************************************************************************************************************************/
        /*** Request redemption of all strategy manager shares                                                                          ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(address(poolManager), strategyManagerToRemove, expectedFirstPoolShares);

        assertEq(poolManager.isStrategyManager(strategyManagerToRemove), true);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),     type(uint256).max);
        assertEq(poolManager.strategyListLength(),                       2);
        assertEq(poolManager.strategyList(0),                            openTermLoanManager);
        assertEq(poolManager.strategyList(1),                            strategyManagerToRemove);

        assertStrategyManager({
            strategyManager:       strategyManagerToRemove,
            totalShares:           expectedFirstPoolShares,
            totalPendingShares:    expectedFirstPoolShares,
            assetsUnderManagement: expectedYieldAssets,
            availableToWithdraw:   expectedYieldAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      address(poolManager),
            assets:           expectedYieldAssets,
            shares:           expectedFirstPoolShares,
            pendingShares:    expectedFirstPoolShares,
            unrealizedLosses: 0
        });

        assertUnderlyingStrategy({
            strategy:              underlyingStrategy,
            assetsUnderManagement: expectedYieldAssets,
            availableToWithdraw:   expectedYieldAssets,
            unrealizedLosses:      0
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        expectedYieldAssets,
            totalSupply:        fundShares,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        /**********************************************************************************************************************************/
        /*** Process the full redemption and distribute fees                                                                            ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(address(poolManager), strategyManagerToRemove, expectedFirstPoolShares);

        assertEq(poolManager.isStrategyManager(strategyManagerToRemove), true);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),     type(uint256).max);
        assertEq(poolManager.strategyListLength(),                       2);
        assertEq(poolManager.strategyList(0),                            openTermLoanManager);
        assertEq(poolManager.strategyList(1),                            strategyManagerToRemove);

        assertStrategyManager({
            strategyManager:       strategyManagerToRemove,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertUnderlyingStrategy({
            strategy:              underlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        expectedYieldAssets,
            totalSupply:        fundShares,
            unrealizedLosses:   0,
            availableLiquidity: expectedYieldAssets
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), expectedYieldDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         expectedYieldProtocolFee);

        /**********************************************************************************************************************************/
        /*** Remove the strategy manager after yield realization                                                                        ***/
        /**********************************************************************************************************************************/

        removeStrategyManager(address(poolManager), strategyManagerToRemove);

        assertEq(poolManager.isStrategyManager(strategyManagerToRemove), false);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),     0);
        assertEq(poolManager.strategyListLength(),                       1);
        assertEq(poolManager.strategyList(0),                            openTermLoanManager);

        assertStrategyManager({
            strategyManager:       strategyManagerToRemove,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertUnderlyingStrategy({
            strategy:              underlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        expectedYieldAssets,
            totalSupply:        fundShares,
            unrealizedLosses:   0,
            availableLiquidity: expectedYieldAssets
        });

        assertEq(fundsAsset.balanceOf(strategyDelegate), expectedYieldDelegateFee);
        assertEq(fundsAsset.balanceOf(treasury),         expectedYieldProtocolFee);
    }

    function testFork_removeStrategyManager_success_clearsStrategyCapAndCanReAdd() external {
        assertEq(poolManager.isStrategyManager(strategyManagerToRemove), true);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),     type(uint256).max);
        assertEq(poolManager.strategyListLength(),                       2);
        assertEq(poolManager.strategyList(0),                            openTermLoanManager);
        assertEq(poolManager.strategyList(1),                            strategyManagerToRemove);

        /**********************************************************************************************************************************/
        /*** Remove the strategy manager and clear its cap                                                                              ***/
        /**********************************************************************************************************************************/

        removeStrategyManager(address(poolManager), strategyManagerToRemove);

        assertEq(poolManager.isStrategyManager(strategyManagerToRemove), false);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),     0);
        assertEq(poolManager.strategyListLength(),                       1);
        assertEq(poolManager.strategyList(0),                            openTermLoanManager);

        /**********************************************************************************************************************************/
        /*** Re-add the strategy manager with a zero cap                                                                                ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        poolManager.addStrategyManager(strategyManagerToRemove);

        assertEq(poolManager.isStrategyManager(strategyManagerToRemove), true);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),     0);
        assertEq(poolManager.strategyListLength(),                       2);
        assertEq(poolManager.strategyList(0),                            openTermLoanManager);
        assertEq(poolManager.strategyList(1),                            strategyManagerToRemove);

        /**********************************************************************************************************************************/
        /*** Remove the re-added strategy manager                                                                                       ***/
        /**********************************************************************************************************************************/

        removeStrategyManager(address(poolManager), strategyManagerToRemove);

        assertEq(poolManager.isStrategyManager(strategyManagerToRemove), false);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),     0);
        assertEq(poolManager.strategyListLength(),                       1);
        assertEq(poolManager.strategyList(0),                            openTermLoanManager);
    }

    function testFork_removeStrategyManager_success_nonZeroUnrealizedLosses() external {
        uint256 firstFund      = 100_000e6;
        uint256 secondFund     = 200_000e6;
        uint256 unrealizedLoss = 1;

        address firstPool        = address(pool);
        address firstPoolManager = address(poolManager);

        /**********************************************************************************************************************************/
        /*** Create two pools and fund the shared strategy manager                                                                      ***/
        /**********************************************************************************************************************************/

        ( address secondPool, address secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", strategyManagerToRemove);

        address secondOpenTermLoanManager = IPoolManager(secondPoolManager).strategyList(0);

        deposit(firstPool,  liquidityProvider,                   firstFund);
        deposit(secondPool, makeAddr("secondLiquidityProvider"), secondFund);

        fundStrategyManager(firstPoolManager,  strategyManagerToRemove, firstFund);
        fundStrategyManager(secondPoolManager, strategyManagerToRemove, secondFund);

        impairStrategy(underlyingStrategy, unrealizedLoss);

        /**********************************************************************************************************************************/
        /*** Withdraw all assets except the unrealized loss                                                                             ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyManagerToRemove);
        IUnderlyingStrategyLike(underlyingStrategy).withdrawFromUnderlyingStrategy(
            makeAddr("lossReceiver"),
            expectedStrategyManagerAssets - unrealizedLoss,
            ""
        );

        assertEq(IPoolManager(firstPoolManager).isStrategyManager(strategyManagerToRemove), true);
        assertEq(IPoolManager(firstPoolManager).strategyCapOf(strategyManagerToRemove),     type(uint256).max);
        assertEq(IPoolManager(firstPoolManager).strategyListLength(),                       2);
        assertEq(IPoolManager(firstPoolManager).strategyList(0),                            openTermLoanManager);
        assertEq(IPoolManager(firstPoolManager).strategyList(1),                            strategyManagerToRemove);

        assertEq(IPoolManager(secondPoolManager).isStrategyManager(strategyManagerToRemove), true);
        assertEq(IPoolManager(secondPoolManager).strategyCapOf(strategyManagerToRemove),     type(uint256).max);
        assertEq(IPoolManager(secondPoolManager).strategyListLength(),                       2);
        assertEq(IPoolManager(secondPoolManager).strategyList(0),                            secondOpenTermLoanManager);
        assertEq(IPoolManager(secondPoolManager).strategyList(1),                            strategyManagerToRemove);

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           expectedFirstPoolShares,
            pendingShares:    0,
            unrealizedLosses: unrealizedLoss
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      secondPoolManager,
            assets:           0,
            shares:           expectedSecondPoolShares,
            pendingShares:    0,
            unrealizedLosses: unrealizedLoss
        });

        assertStrategyManager({
            strategyManager:       strategyManagerToRemove,
            totalShares:           expectedStrategyManagerShares,
            totalPendingShares:    0,
            assetsUnderManagement: unrealizedLoss,
            availableToWithdraw:   unrealizedLoss,
            unrealizedLosses:      unrealizedLoss
        });

        assertUnderlyingStrategy({
            strategy:              underlyingStrategy,
            assetsUnderManagement: unrealizedLoss,
            availableToWithdraw:   unrealizedLoss,
            unrealizedLosses:      unrealizedLoss
        });

        assertPoolState({
            pool:               firstPool,
            totalAssets:        0,
            totalSupply:        firstFund,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        0,
            totalSupply:        secondFund,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        /**********************************************************************************************************************************/
        /*** Remove the strategy manager from the first pool                                                                            ***/
        /**********************************************************************************************************************************/

        removeStrategyManager(firstPoolManager, strategyManagerToRemove);

        assertEq(IPoolManager(firstPoolManager).isStrategyManager(strategyManagerToRemove), false);
        assertEq(IPoolManager(firstPoolManager).strategyCapOf(strategyManagerToRemove),     0);
        assertEq(IPoolManager(firstPoolManager).strategyListLength(),                       1);
        assertEq(IPoolManager(firstPoolManager).strategyList(0),                            openTermLoanManager);

        assertEq(IPoolManager(secondPoolManager).isStrategyManager(strategyManagerToRemove), true);
        assertEq(IPoolManager(secondPoolManager).strategyCapOf(strategyManagerToRemove),     type(uint256).max);
        assertEq(IPoolManager(secondPoolManager).strategyListLength(),                       2);
        assertEq(IPoolManager(secondPoolManager).strategyList(0),                            secondOpenTermLoanManager);
        assertEq(IPoolManager(secondPoolManager).strategyList(1),                            strategyManagerToRemove);

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           expectedFirstPoolShares,
            pendingShares:    0,
            unrealizedLosses: unrealizedLoss
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      secondPoolManager,
            assets:           0,
            shares:           expectedSecondPoolShares,
            pendingShares:    0,
            unrealizedLosses: unrealizedLoss
        });

        assertStrategyManager({
            strategyManager:       strategyManagerToRemove,
            totalShares:           expectedStrategyManagerShares,
            totalPendingShares:    0,
            assetsUnderManagement: unrealizedLoss,
            availableToWithdraw:   unrealizedLoss,
            unrealizedLosses:      unrealizedLoss
        });

        assertUnderlyingStrategy({
            strategy:              underlyingStrategy,
            assetsUnderManagement: unrealizedLoss,
            availableToWithdraw:   unrealizedLoss,
            unrealizedLosses:      unrealizedLoss
        });

        assertPoolState({
            pool:               firstPool,
            totalAssets:        0,
            totalSupply:        firstFund,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        0,
            totalSupply:        secondFund,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });
    }

    function testFork_removeStrategyManager_success_whenStrategyListBecomesEmpty() external {
        address emptyPoolDelegate = makeAddr("emptyPoolDelegate");

        address[] memory strategyFactories = new address[](0);
        bytes[]   memory strategyData      = new bytes[](0);

        uint256 bootstrapAssets         = 10e6;
        uint256 bootstrapShares         = 10e6;
        uint256 depositAssets           = 100_000e6;
        uint256 depositShares           = 100_000e6;
        uint256 liquidityProviderAssets = depositAssets - bootstrapAssets;
        uint256 liquidityProviderShares = depositShares - bootstrapShares;

        /**********************************************************************************************************************************/
        /*** Create and configure a pool with an empty strategy list                                                                    ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        globals.setValidPoolDelegate(emptyPoolDelegate, true);

        _createPoolWithMultipleStrategies({
            poolDelegate_:      emptyPoolDelegate,
            fundsAsset_:        address(fundsAsset),
            name_:              "Empty Strategy Pool",
            strategyFactories_: strategyFactories,
            strategyData_:      strategyData
        });

        _configurePool();
        openPool(address(poolManager));

        assertEq(poolManager.strategyListLength(), 0);

        /**********************************************************************************************************************************/
        /*** Add the strategy manager as the only strategy                                                                              ***/
        /**********************************************************************************************************************************/

        vm.startPrank(governor);
        poolManager.addStrategyManager(strategyManagerToRemove);
        poolManager.setStrategyCap(strategyManagerToRemove, type(uint256).max);
        vm.stopPrank();

        assertEq(poolManager.isStrategyManager(strategyManagerToRemove), true);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),     type(uint256).max);
        assertEq(poolManager.strategyListLength(),                       1);
        assertEq(poolManager.strategyList(0),                            strategyManagerToRemove);

        assertStrategyManager({
            strategyManager:       strategyManagerToRemove,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertUnderlyingStrategy({
            strategy:              underlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        /**********************************************************************************************************************************/
        /*** Remove the final strategy manager from the pool                                                                            ***/
        /**********************************************************************************************************************************/

        removeStrategyManager(address(poolManager), strategyManagerToRemove);

        assertEq(poolManager.isStrategyManager(strategyManagerToRemove), false);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),     0);
        assertEq(poolManager.strategyListLength(),                       0);

        assertStrategyManager({
            strategyManager:       strategyManagerToRemove,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertUnderlyingStrategy({
            strategy:              underlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        /**********************************************************************************************************************************/
        /*** Deposit liquidity while the strategy list is empty                                                                         ***/
        /**********************************************************************************************************************************/

        deposit(address(pool), liquidityProvider, depositAssets);

        assertEq(poolManager.strategyListLength(), 0);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        depositAssets,
            totalSupply:        depositShares,
            unrealizedLosses:   0,
            availableLiquidity: depositAssets
        });

        /**********************************************************************************************************************************/
        /*** Redeem liquidity while the strategy list is empty                                                                          ***/
        /**********************************************************************************************************************************/

        requestRedeem(address(pool), liquidityProvider, liquidityProviderShares);
        processRedemptions(address(pool), liquidityProviderShares);

        assertEq(poolManager.strategyListLength(),        0);
        assertEq(pool.balanceOf(liquidityProvider),       0);
        assertEq(fundsAsset.balanceOf(liquidityProvider), liquidityProviderAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        bootstrapAssets,
            totalSupply:        bootstrapShares,
            unrealizedLosses:   0,
            availableLiquidity: bootstrapAssets
        });
    }

    function testFork_removeStrategyManager_success_withBootstrapAssets() external {
        address bootstrapUnderlyingStrategy = IStrategyManager(bootstrapStrategyManager).underlyingStrategy();

        /**********************************************************************************************************************************/
        /*** Add a strategy manager containing bootstrap assets                                                                         ***/
        /**********************************************************************************************************************************/

        addStrategyManagerToPool(address(poolManager), bootstrapStrategyManager);

        assertEq(poolManager.isStrategyManager(strategyManagerToRemove),  true);
        assertEq(poolManager.isStrategyManager(bootstrapStrategyManager), true);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),      type(uint256).max);
        assertEq(poolManager.strategyCapOf(bootstrapStrategyManager),     type(uint256).max);
        assertEq(poolManager.strategyListLength(),                        3);
        assertEq(poolManager.strategyList(0),                             openTermLoanManager);
        assertEq(poolManager.strategyList(1),                             strategyManagerToRemove);
        assertEq(poolManager.strategyList(2),                             bootstrapStrategyManager);

        assertStrategyManager({
            strategyManager:       bootstrapStrategyManager,
            totalShares:           expectedBootstrapShares,
            totalPendingShares:    0,
            assetsUnderManagement: expectedBootstrapAssets,
            availableToWithdraw:   expectedBootstrapAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  bootstrapStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertUnderlyingStrategy({
            strategy:              bootstrapUnderlyingStrategy,
            assetsUnderManagement: expectedBootstrapAssets,
            availableToWithdraw:   expectedBootstrapAssets,
            unrealizedLosses:      0
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        /**********************************************************************************************************************************/
        /*** Remove the strategy manager with no pool position                                                                          ***/
        /**********************************************************************************************************************************/

        removeStrategyManager(address(poolManager), strategyManagerToRemove);

        assertEq(poolManager.isStrategyManager(strategyManagerToRemove),  false);
        assertEq(poolManager.isStrategyManager(bootstrapStrategyManager), true);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),      0);
        assertEq(poolManager.strategyCapOf(bootstrapStrategyManager),     type(uint256).max);
        assertEq(poolManager.strategyListLength(),                        2);
        assertEq(poolManager.strategyList(0),                             openTermLoanManager);
        assertEq(poolManager.strategyList(1),                             bootstrapStrategyManager);

        assertStrategyManager({
            strategyManager:       bootstrapStrategyManager,
            totalShares:           expectedBootstrapShares,
            totalPendingShares:    0,
            assetsUnderManagement: expectedBootstrapAssets,
            availableToWithdraw:   expectedBootstrapAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  bootstrapStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertUnderlyingStrategy({
            strategy:              bootstrapUnderlyingStrategy,
            assetsUnderManagement: expectedBootstrapAssets,
            availableToWithdraw:   expectedBootstrapAssets,
            unrealizedLosses:      0
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        /**********************************************************************************************************************************/
        /*** Remove the bootstrap strategy manager with no pool position                                                                ***/
        /**********************************************************************************************************************************/

        removeStrategyManager(address(poolManager), bootstrapStrategyManager);

        assertEq(poolManager.isStrategyManager(strategyManagerToRemove),  false);
        assertEq(poolManager.isStrategyManager(bootstrapStrategyManager), false);
        assertEq(poolManager.strategyCapOf(strategyManagerToRemove),      0);
        assertEq(poolManager.strategyCapOf(bootstrapStrategyManager),     0);
        assertEq(poolManager.strategyListLength(),                        1);
        assertEq(poolManager.strategyList(0),                             openTermLoanManager);

        assertStrategyManager({
            strategyManager:       bootstrapStrategyManager,
            totalShares:           expectedBootstrapShares,
            totalPendingShares:    0,
            assetsUnderManagement: expectedBootstrapAssets,
            availableToWithdraw:   expectedBootstrapAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  bootstrapStrategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertUnderlyingStrategy({
            strategy:              bootstrapUnderlyingStrategy,
            assetsUnderManagement: expectedBootstrapAssets,
            availableToWithdraw:   expectedBootstrapAssets,
            unrealizedLosses:      0
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });
    }

    function testFork_removeStrategyManager_success_withOtherPoolAssetsAndUnrealizedLosses() external {
        uint256 firstFund        = 100_000e6;
        uint256 firstFundShares  = 100_000e6;
        uint256 secondFund       = 200_000e6;
        uint256 secondFundShares = 200_000e6;
        uint256 impairment       = 50_000e6;

        address firstPool        = address(pool);
        address firstPoolManager = address(poolManager);

        /**********************************************************************************************************************************/
        /*** Deposit liquidity and fund the first pool position                                                                         ***/
        /**********************************************************************************************************************************/

        deposit(firstPool, liquidityProvider, firstFund);

        fundStrategyManager(firstPoolManager, strategyManagerToRemove, firstFund);

        /**********************************************************************************************************************************/
        /*** Create and fund a second pool sharing the strategy manager                                                                 ***/
        /**********************************************************************************************************************************/

        ( address secondPool, address secondPoolManager ) = _createPoolSharingStrategy("secondPoolDelegate", strategyManagerToRemove);

        address secondOpenTermLoanManager = IPoolManager(secondPoolManager).strategyList(0);

        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).isInstance(secondOpenTermLoanManager), true);

        deposit(secondPool, makeAddr("secondLiquidityProvider"), secondFund);

        fundStrategyManager(secondPoolManager, strategyManagerToRemove, secondFund);

        /**********************************************************************************************************************************/
        /*** Fully redeem the first pool position                                                                                       ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(firstPoolManager, strategyManagerToRemove, expectedFirstPoolShares);
        processRedemptionFromStrategyManager(firstPoolManager, strategyManagerToRemove, expectedFirstPoolShares);

        /**********************************************************************************************************************************/
        /*** Impair the remaining second pool position                                                                                  ***/
        /**********************************************************************************************************************************/

        impairStrategy(underlyingStrategy, impairment);

        assertEq(IPoolManager(firstPoolManager).isStrategyManager(strategyManagerToRemove), true);
        assertEq(IPoolManager(firstPoolManager).strategyCapOf(strategyManagerToRemove),     type(uint256).max);
        assertEq(IPoolManager(firstPoolManager).strategyListLength(),                       2);
        assertEq(IPoolManager(firstPoolManager).strategyList(0),                            openTermLoanManager);
        assertEq(IPoolManager(firstPoolManager).strategyList(1),                            strategyManagerToRemove);

        assertEq(IPoolManager(secondPoolManager).isStrategyManager(strategyManagerToRemove), true);
        assertEq(IPoolManager(secondPoolManager).strategyCapOf(strategyManagerToRemove),     type(uint256).max);
        assertEq(IPoolManager(secondPoolManager).strategyListLength(),                       2);
        assertEq(IPoolManager(secondPoolManager).strategyList(0),                            secondOpenTermLoanManager);
        assertEq(IPoolManager(secondPoolManager).strategyList(1),                            strategyManagerToRemove);

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      secondPoolManager,
            assets:           expectedSecondPoolAssets,
            shares:           expectedSecondPoolShares,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        assertStrategyManager({
            strategyManager:       strategyManagerToRemove,
            totalShares:           expectedSecondPoolShares,
            totalPendingShares:    0,
            assetsUnderManagement: expectedSecondPoolAssets,
            availableToWithdraw:   expectedSecondPoolAssets,
            unrealizedLosses:      impairment
        });

        assertUnderlyingStrategy({
            strategy:              underlyingStrategy,
            assetsUnderManagement: expectedSecondPoolAssets,
            availableToWithdraw:   expectedSecondPoolAssets,
            unrealizedLosses:      impairment
        });

        assertPoolState({
            pool:               firstPool,
            totalAssets:        expectedFirstPoolAssets,
            totalSupply:        firstFundShares,
            unrealizedLosses:   0,
            availableLiquidity: expectedFirstPoolAssets
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        expectedSecondPoolAssets,
            totalSupply:        secondFundShares,
            unrealizedLosses:   impairment,
            availableLiquidity: 0
        });

        /**********************************************************************************************************************************/
        /*** Remove the strategy manager from the fully redeemed first pool                                                             ***/
        /**********************************************************************************************************************************/

        removeStrategyManager(firstPoolManager, strategyManagerToRemove);

        assertEq(IPoolManager(firstPoolManager).isStrategyManager(strategyManagerToRemove), false);
        assertEq(IPoolManager(firstPoolManager).strategyCapOf(strategyManagerToRemove),     0);
        assertEq(IPoolManager(firstPoolManager).strategyListLength(),                       1);
        assertEq(IPoolManager(firstPoolManager).strategyList(0),                            openTermLoanManager);

        assertEq(IPoolManager(secondPoolManager).isStrategyManager(strategyManagerToRemove), true);
        assertEq(IPoolManager(secondPoolManager).strategyCapOf(strategyManagerToRemove),     type(uint256).max);
        assertEq(IPoolManager(secondPoolManager).strategyListLength(),                       2);
        assertEq(IPoolManager(secondPoolManager).strategyList(0),                            secondOpenTermLoanManager);
        assertEq(IPoolManager(secondPoolManager).strategyList(1),                            strategyManagerToRemove);

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      firstPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManagerToRemove,
            poolManager:      secondPoolManager,
            assets:           expectedSecondPoolAssets,
            shares:           expectedSecondPoolShares,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        assertStrategyManager({
            strategyManager:       strategyManagerToRemove,
            totalShares:           expectedSecondPoolShares,
            totalPendingShares:    0,
            assetsUnderManagement: expectedSecondPoolAssets,
            availableToWithdraw:   expectedSecondPoolAssets,
            unrealizedLosses:      impairment
        });

        assertUnderlyingStrategy({
            strategy:              underlyingStrategy,
            assetsUnderManagement: expectedSecondPoolAssets,
            availableToWithdraw:   expectedSecondPoolAssets,
            unrealizedLosses:      impairment
        });

        assertPoolState({
            pool:               firstPool,
            totalAssets:        expectedFirstPoolAssets,
            totalSupply:        firstFundShares,
            unrealizedLosses:   0,
            availableLiquidity: expectedFirstPoolAssets
        });

        assertPoolState({
            pool:               secondPool,
            totalAssets:        expectedSecondPoolAssets,
            totalSupply:        secondFundShares,
            unrealizedLosses:   impairment,
            availableLiquidity: 0
        });
    }

}

contract RemoveStrategyManagerAllocationStrategyFailureTests is RemoveStrategyManagerFailureTestBase {

    function setUp() public override {
        expectedFirstPoolAssets = 100_000e6;

        super.setUp();

        ( allocationStrategyManager, allocationUnderlyingStrategy ) = _deployAllocationStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        strategyManagerToRemove = allocationStrategyManager;
        underlyingStrategy      = allocationUnderlyingStrategy;

        _setUpStrategyManager();
    }

}

contract RemoveStrategyManagerAaveV3StrategyFailureTests is RemoveStrategyManagerFailureTestBase {

    function setUp() public override {
        expectedFirstPoolAssets = 100_000e6 - 1;

        super.setUp();

        ( aaveV3StrategyManager, aaveV3UnderlyingStrategy ) = _deployAaveV3Strategy({
            strategyDelegate_:            strategyDelegate,
            aaveToken_:                   AAVE_USDC,
            useVirtualUnderlyingBalance_: true,
            strategyDelegateFeeRate_:     0,
            strategyProtocolFeeRate_:     0,
            strategyLiquidityCap_:        0,
            bootstrapMint_:               0
        });

        strategyManagerToRemove = aaveV3StrategyManager;
        underlyingStrategy      = aaveV3UnderlyingStrategy;

        _setUpStrategyManager();
    }

}

contract RemoveStrategyManagerSkyStrategyFailureTests is RemoveStrategyManagerFailureTestBase {

    function setUp() public override {
        expectedFirstPoolAssets = 100_000e6 - 1;

        super.setUp();

        ( skyStrategyManager, skyUnderlyingStrategy ) = _deploySkyStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            savingsUsds_:             SAVINGS_USDS,
            psm_:                     USDS_LITE_PSM,
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        strategyManagerToRemove = skyStrategyManager;
        underlyingStrategy      = skyUnderlyingStrategy;

        _setUpStrategyManager();
    }

}

contract RemoveStrategyManagerSparkLendStrategyFailureTests is RemoveStrategyManagerFailureTestBase {

    function setUp() public override {
        expectedFirstPoolAssets = 100_000e6 + 1;

        super.setUp();

        ( aaveV3StrategyManager, aaveV3UnderlyingStrategy ) = _deployAaveV3Strategy({
            strategyDelegate_:            strategyDelegate,
            aaveToken_:                   SPARK_USDC,
            useVirtualUnderlyingBalance_: false,
            strategyDelegateFeeRate_:     0,
            strategyProtocolFeeRate_:     0,
            strategyLiquidityCap_:        0,
            bootstrapMint_:               0
        });

        strategyManagerToRemove = aaveV3StrategyManager;
        underlyingStrategy      = aaveV3UnderlyingStrategy;

        _setUpStrategyManager();
    }

}

contract RemoveStrategyManagerAllocationStrategyTests is RemoveStrategyManagerSuccessTestBase {

    function setUp() public override {
        expectedBootstrapAssets                 = 10e6;
        expectedBootstrapShares                 = 10e6;
        expectedFirstPoolAssets                 = 100_000e6;
        expectedFirstPoolShares                 = 100_000e6;
        expectedPartialImpairmentPoolAssets     = 90_000e6;
        expectedPartialImpairmentStrategyAssets = 10_000e6;
        expectedPartialImpairmentStrategyLosses = 10_000e6;
        expectedSecondPoolAssets                = 200_000e6;
        expectedSecondPoolShares                = 200_000e6;
        expectedStrategyManagerAssets           = 300_000e6;
        expectedStrategyManagerShares           = 300_000e6;

        allocationLossDeployer  = makeAddr("allocationLossDeployer");
        allocationYieldDeployer = makeAddr("allocationYieldDeployer");

        super.setUp();

        ( allocationStrategyManager, allocationUnderlyingStrategy ) = _deployAllocationStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        ( bootstrapStrategyManager, ) = _deployAllocationStrategy({
            strategyDelegate_:        makeAddr("bootstrapStrategyDelegate"),
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           10e6
        });

        strategyManagerToRemove = allocationStrategyManager;
        strategyToken           = address(fundsAsset);
        underlyingStrategy      = allocationUnderlyingStrategy;

        _setUpStrategyManager();
    }

}

contract RemoveStrategyManagerAaveV3StrategyForkTests is RemoveStrategyManagerSuccessTestBase {

    function setUp() public override {
        expectedBootstrapAssets                 = 10e6      - 1;
        expectedBootstrapShares                 = 10e6      - 1;
        expectedFirstPoolAssets                 = 100_000e6 - 1;
        expectedFirstPoolShares                 = 100_000e6 - 1;
        expectedPartialImpairmentPoolAssets     = 90_000e6  - 1;
        expectedPartialImpairmentStrategyAssets = 10_000e6  - 1;
        expectedPartialImpairmentStrategyLosses = 10_000e6  - 1;
        expectedSecondPoolAssets                = 200_000e6 - 1;
        expectedSecondPoolShares                = 200_000e6 - 1;
        expectedStrategyManagerAssets           = 300_000e6 - 2;
        expectedStrategyManagerShares           = 300_000e6 - 2;

        super.setUp();

        ( aaveV3StrategyManager, aaveV3UnderlyingStrategy ) = _deployAaveV3Strategy({
            strategyDelegate_:            strategyDelegate,
            aaveToken_:                   AAVE_USDC,
            useVirtualUnderlyingBalance_: true,
            strategyDelegateFeeRate_:     0,
            strategyProtocolFeeRate_:     0,
            strategyLiquidityCap_:        0,
            bootstrapMint_:               0
        });

        ( bootstrapStrategyManager, ) = _deployAaveV3Strategy({
            strategyDelegate_:            makeAddr("bootstrapStrategyDelegate"),
            aaveToken_:                   AAVE_USDC,
            useVirtualUnderlyingBalance_: true,
            strategyDelegateFeeRate_:     0,
            strategyProtocolFeeRate_:     0,
            strategyLiquidityCap_:        0,
            bootstrapMint_:               10e6
        });

        aavePool                = IAaveV3Strategy(aaveV3UnderlyingStrategy).aavePool();
        strategyManagerToRemove = aaveV3StrategyManager;
        strategyToken           = AAVE_USDC;
        underlyingStrategy      = aaveV3UnderlyingStrategy;
        yieldBearingToken       = AAVE_USDC;

        _setUpStrategyManager();
    }

}

contract RemoveStrategyManagerSkyStrategyForkTests is RemoveStrategyManagerSuccessTestBase {

    function setUp() public override {
        expectedBootstrapAssets                 = 10e6      - 1;
        expectedBootstrapShares                 = 10e6      - 1;
        expectedFirstPoolAssets                 = 100_000e6 - 1;
        expectedFirstPoolShares                 = 100_000e6 - 1;
        expectedPartialImpairmentPoolAssets     = 90_000e6  - 1;
        expectedPartialImpairmentStrategyAssets = 10_000e6;
        expectedPartialImpairmentStrategyLosses = 10_000e6;
        expectedSecondPoolAssets                = 200_000e6;
        expectedSecondPoolShares                = 200_000e6;
        expectedStrategyManagerAssets           = 300_000e6 - 1;
        expectedStrategyManagerShares           = 300_000e6 - 1;

        super.setUp();

        ( skyStrategyManager, skyUnderlyingStrategy ) = _deploySkyStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            savingsUsds_:             SAVINGS_USDS,
            psm_:                     USDS_LITE_PSM,
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        ( bootstrapStrategyManager, ) = _deploySkyStrategy({
            strategyDelegate_:        makeAddr("bootstrapStrategyDelegate"),
            fundsAsset_:              address(fundsAsset),
            savingsUsds_:             SAVINGS_USDS,
            psm_:                     USDS_LITE_PSM,
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           10e6
        });

        isSkyStrategy           = true;
        strategyManagerToRemove = skyStrategyManager;
        strategyToken           = SAVINGS_USDS;
        underlyingStrategy      = skyUnderlyingStrategy;

        _setUpStrategyManager();
    }

}

contract RemoveStrategyManagerSparkLendStrategyForkTests is RemoveStrategyManagerSuccessTestBase {

    function setUp() public override {
        expectedBootstrapAssets                 = 10e6;
        expectedBootstrapShares                 = 10e6;
        expectedFirstPoolAssets                 = 100_000e6 + 1;
        expectedFirstPoolShares                 = 100_000e6 + 1;
        expectedPartialImpairmentPoolAssets     = 90_000e6  + 1;
        expectedPartialImpairmentStrategyAssets = 10_000e6  - 1;
        expectedPartialImpairmentStrategyLosses = 10_000e6  - 1;
        expectedSecondPoolAssets                = 200_000e6;
        expectedSecondPoolShares                = 200_000e6 - 1;
        expectedStrategyManagerAssets           = 300_000e6;
        expectedStrategyManagerShares           = 300_000e6;

        super.setUp();

        ( aaveV3StrategyManager, aaveV3UnderlyingStrategy ) = _deployAaveV3Strategy({
            strategyDelegate_:            strategyDelegate,
            aaveToken_:                   SPARK_USDC,
            useVirtualUnderlyingBalance_: false,
            strategyDelegateFeeRate_:     0,
            strategyProtocolFeeRate_:     0,
            strategyLiquidityCap_:        0,
            bootstrapMint_:               0
        });

        ( bootstrapStrategyManager, ) = _deployAaveV3Strategy({
            strategyDelegate_:            makeAddr("bootstrapStrategyDelegate"),
            aaveToken_:                   SPARK_USDC,
            useVirtualUnderlyingBalance_: false,
            strategyDelegateFeeRate_:     0,
            strategyProtocolFeeRate_:     0,
            strategyLiquidityCap_:        0,
            bootstrapMint_:               10e6
        });

        aavePool                = IAaveV3Strategy(aaveV3UnderlyingStrategy).aavePool();
        strategyManagerToRemove = aaveV3StrategyManager;
        strategyToken           = SPARK_USDC;
        underlyingStrategy      = aaveV3UnderlyingStrategy;
        yieldBearingToken       = SPARK_USDC;

        _setUpStrategyManager();
    }

}
