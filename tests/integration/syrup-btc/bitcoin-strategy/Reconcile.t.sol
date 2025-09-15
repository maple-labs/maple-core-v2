// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../SyrupBitcoinTestBase.sol";

contract ReconcileTestBase is SyrupBitcoinTestBase {

    address poolDepositor = makeAddr("poolDepositor");

    uint32 deadline;
    uint32 fullDuration    = 19 days;
    uint32 partialDuration = 13 days;

    uint256 feeRate   = 0.015e6;  // 1.5% fee rate
    uint256 precision = 1e30;

    uint256 deployAmount    = 125e8;
    uint256 reconcileAmount = 60e8;
    uint256 yieldAmount     = 4.5e8;

    uint256 partialYield = yieldAmount * partialDuration / fullDuration;
    uint256 partialFees  = partialYield * feeRate / 1e6;
    uint256 totalFees    = yieldAmount * feeRate / 1e6;

    address[] assets;
    address[] controllers;
    address[] pools;
    address[] strategies;

    bool[] allowed   = [true];
    bool[] forbidden = [false];

    function setUp() public virtual override {
        super.setUp();

        deadline = startingTime + fullDuration;

        // Populate utility arrays.
        assets.push(address(depositAsset));
        controllers.push(address(assetController));
        pools.push(address(pool));
        strategies.push(address(bitcoinStrategy));

        // Set the strategy fee rate.
        vm.prank(governor);
        bitcoinStrategy.setFeeRate(feeRate);

        // Prepare for the reconciliation.
        vm.prank(strategyManager);
        depositAsset.approve(address(bitcoinStrategy), deployAmount + yieldAmount);
        depositAsset.mint(strategyManager, deployAmount + yieldAmount);
    }

}

contract ReconcileFailureTests is ReconcileTestBase {

    function test_reconcile_strategyPaused() external {
        vm.prank(governor);
        globals.setContractPause(address(bitcoinStrategy), true);

        vm.prank(strategyManager);
        vm.expectRevert("MBS:PAUSED");
        bitcoinStrategy.reconcile(address(depositAsset), reconcileAmount);
    }

    function test_reconcile_notReconciler() external {
        vm.expectRevert("MBS:NOT_ALLOWED");
        bitcoinStrategy.reconcile(address(depositAsset), reconcileAmount);
    }

    function test_reconcile_zeroDepositAmount() external {
        vm.prank(strategyManager);
        vm.expectRevert("MBS:R:ZERO_AMOUNT");
        bitcoinStrategy.reconcile(address(depositAsset), 0);
    }

    function test_reconcile_missingController() external {
        vm.prank(governor);
        bitcoinStrategy.setAssetController(address(depositAsset), address(0));

        vm.prank(strategyManager);
        vm.expectRevert("MBS:R:NO_CONTROLLER");
        bitcoinStrategy.reconcile(address(depositAsset), reconcileAmount);
    }

    function test_reconcile_cantPullFromReconciler() external {
        vm.prank(strategyManager);
        depositAsset.approve(address(bitcoinStrategy), 0);

        vm.prank(strategyManager);
        vm.expectRevert("MBS:R:TRANSFER_FROM_FAILED");
        bitcoinStrategy.reconcile(address(depositAsset), reconcileAmount);
    }

    function test_reconcile_controllerPaused() external {
        vm.prank(governor);
        globals.setContractPause(address(assetController), true);

        vm.prank(strategyManager);
        vm.expectRevert("AC:PAUSED");
        bitcoinStrategy.reconcile(address(depositAsset), reconcileAmount);
    }

    function test_reconcile_notStrategy() external {
        vm.prank(governor);
        assetController.setStrategies(strategies, forbidden);

        vm.prank(strategyManager);
        vm.expectRevert("AC:NOT_STRATEGY");
        bitcoinStrategy.reconcile(address(depositAsset), reconcileAmount);
    }

    function test_reconcile_unsupportedAsset() external {
        vm.prank(governor);
        assetController.setAssets(assets, allowed, allowed, allowed, forbidden);

        vm.prank(strategyManager);
        vm.expectRevert("AC:R:INVALID_ASSET");
        bitcoinStrategy.reconcile(address(depositAsset), reconcileAmount);
    }

    function test_reconcile_compositePaused() external {
        vm.prank(governor);
        globals.setContractPause(address(compositeAsset), true);

        vm.prank(strategyManager);
        vm.expectRevert("CT:PAUSED");
        bitcoinStrategy.reconcile(address(depositAsset), reconcileAmount);
    }

    function test_reconcile_notController() external {
        vm.prank(governor);
        compositeAsset.setAssetControllers(controllers, forbidden);

        vm.prank(strategyManager);
        vm.expectRevert("CT:NOT_CONTROLLER");
        bitcoinStrategy.reconcile(address(depositAsset), reconcileAmount);
    }

    function test_reconcile_notWhitelisted() external {
        vm.prank(governor);
        compositeAsset.allowAddresses(controllers, forbidden);

        vm.prank(strategyManager);
        vm.expectRevert("CT:NOT_ALLOWED");
        bitcoinStrategy.reconcile(address(depositAsset), reconcileAmount);
    }

    // Mocked since price oracle always mints at a 1:1 exchange rate.
    function test_reconcile_zeroMintAmount() external {
        vm.prank(strategyManager);
        vm.mockCall(
            address(priceOracle),
            abi.encodeWithSignature(
                "convert(address,address,uint256,bytes32)",
                address(depositAsset),
                address(compositeAsset),
                reconcileAmount,
                bytes32("")
            ),
            abi.encode(0)
        );
        vm.expectRevert("CT:M:ZERO_AMOUNT");
        bitcoinStrategy.reconcile(address(depositAsset), reconcileAmount);
    }

    function test_reconcile_cantPullFromStrategy() external {
        vm.prank(address(bitcoinStrategy));
        depositAsset.approve(address(assetController), 0);

        vm.prank(strategyManager);
        vm.expectRevert("AC:R:DEPOSIT_ASSET_FAILURE");
        bitcoinStrategy.reconcile(address(depositAsset), reconcileAmount);
    }

    function test_reconcile_cantPushToStrategy() external {
        vm.prank(governor);
        compositeAsset.allowAddresses(strategies, forbidden);

        vm.prank(strategyManager);
        vm.expectRevert("AC:R:COMPOSITE_ASSET_FAILURE");
        bitcoinStrategy.reconcile(address(depositAsset), reconcileAmount);
    }

    function test_reconcile_cantPushToPool() external {
        vm.prank(governor);
        compositeAsset.allowAddresses(pools, forbidden);

        vm.prank(strategyManager);
        vm.expectRevert("MBS:R:TRANSFER_FAILED");
        bitcoinStrategy.reconcile(address(depositAsset), reconcileAmount);
    }

    function test_reconcile_accountingUnderflow() external {
        vm.prank(strategyManager);
        vm.expectRevert(arithmeticError);  // NOTE: Underflow in updateAUM() when outstandingAssets < reconciledAmount.
        bitcoinStrategy.reconcile(address(depositAsset), reconcileAmount);
    }

}

contract ReconcileSuccessTests is ReconcileTestBase {

    function setUp() public virtual override {
        super.setUp();

        // Deposit assets.
        vm.prank(poolDepositor);
        depositAsset.approve(address(bitcoinRouter), deployAmount);
        depositAsset.mint(address(poolDepositor), deployAmount);

        vm.prank(poolDepositor);
        bitcoinRouter.deposit(address(depositAsset), deployAmount, EMPTY_METADATA, emptyPermit());

        // Deploy assets.
        vm.prank(strategyManager);
        bitcoinStrategy.deploy(address(depositAsset), deployAmount);

        vm.prank(strategyManager);
        depositAsset.transfer(address(1337), deployAmount);
    }

    function test_reconcile_emptySchedule_minimum() external {
        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(strategyManager)), deployAmount + yieldAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            0);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), 0);
        assertEq(assetController.poolAssets(address(depositAsset)),    0);

        assertAccounting({
            outstandingAssets:     deployAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: deployAmount
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            yieldRate:         0,
            lastUpdated:       0
        });

        vm.prank(strategyManager);
        bitcoinStrategy.reconcile(address(depositAsset), 1);

        assertEq(depositAsset.balanceOf(address(assetController)), 1);
        assertEq(depositAsset.balanceOf(address(strategyManager)), deployAmount + yieldAmount - 1);

        assertEq(compositeAsset.balanceOf(address(pool)),            1);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), 1);
        assertEq(assetController.poolAssets(address(depositAsset)),    1);

        assertAccounting({
            outstandingAssets:     deployAmount - 1,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: deployAmount - 1
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            yieldRate:         0,
            lastUpdated:       0
        });
    }

    function test_reconcile_emptySchedule_partial() external {
        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(strategyManager)), deployAmount + yieldAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            0);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), 0);
        assertEq(assetController.poolAssets(address(depositAsset)),    0);

        assertAccounting({
            outstandingAssets:     deployAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: deployAmount
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            yieldRate:         0,
            lastUpdated:       0
        });

        vm.prank(strategyManager);
        bitcoinStrategy.reconcile(address(depositAsset), reconcileAmount);

        assertEq(depositAsset.balanceOf(address(assetController)), reconcileAmount);
        assertEq(depositAsset.balanceOf(address(strategyManager)), deployAmount + yieldAmount - reconcileAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            reconcileAmount);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), reconcileAmount);
        assertEq(assetController.poolAssets(address(depositAsset)),    reconcileAmount);

        assertAccounting({
            outstandingAssets:     deployAmount - reconcileAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: deployAmount - reconcileAmount
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            yieldRate:         0,
            lastUpdated:       0
        });
    }

    function test_reconcile_emptySchedule_maximum() external {
        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(strategyManager)), deployAmount + yieldAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            0);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), 0);
        assertEq(assetController.poolAssets(address(depositAsset)),    0);

        assertAccounting({
            outstandingAssets:     deployAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: deployAmount
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            yieldRate:         0,
            lastUpdated:       0
        });

        vm.prank(strategyManager);
        bitcoinStrategy.reconcile(address(depositAsset), deployAmount);

        assertEq(depositAsset.balanceOf(address(assetController)), deployAmount);
        assertEq(depositAsset.balanceOf(address(strategyManager)), yieldAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            deployAmount);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), deployAmount);
        assertEq(assetController.poolAssets(address(depositAsset)),    deployAmount);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            yieldRate:         0,
            lastUpdated:       0
        });
    }

    function test_reconcile_newSchedule_minimum() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(strategyManager)), deployAmount + yieldAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            0);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), 0);
        assertEq(assetController.poolAssets(address(depositAsset)),    0);

        assertAccounting({
            outstandingAssets:     deployAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: deployAmount
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            yieldRate:         precision * yieldAmount / fullDuration,
            lastUpdated:       startingTime
        });

        vm.prank(strategyManager);
        bitcoinStrategy.reconcile(address(depositAsset), 1);

        assertEq(depositAsset.balanceOf(address(assetController)), 1);
        assertEq(depositAsset.balanceOf(address(strategyManager)), deployAmount + yieldAmount - 1);

        assertEq(compositeAsset.balanceOf(address(pool)),            1);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), 1);
        assertEq(assetController.poolAssets(address(depositAsset)),    1);

        assertAccounting({
            outstandingAssets:     deployAmount - 1,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: deployAmount - 1
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            yieldRate:         precision * yieldAmount / fullDuration,
            lastUpdated:       startingTime
        });
    }

    function test_reconcile_newSchedule_partial() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(strategyManager)), deployAmount + yieldAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            0);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), 0);
        assertEq(assetController.poolAssets(address(depositAsset)),    0);

        assertAccounting({
            outstandingAssets:     deployAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: deployAmount
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            yieldRate:         precision * yieldAmount / fullDuration,
            lastUpdated:       startingTime
        });

        vm.prank(strategyManager);
        bitcoinStrategy.reconcile(address(depositAsset), reconcileAmount);

        assertEq(depositAsset.balanceOf(address(assetController)), reconcileAmount);
        assertEq(depositAsset.balanceOf(address(strategyManager)), deployAmount + yieldAmount - reconcileAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            reconcileAmount);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), reconcileAmount);
        assertEq(assetController.poolAssets(address(depositAsset)),    reconcileAmount);

        assertAccounting({
            outstandingAssets:     deployAmount - reconcileAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: deployAmount - reconcileAmount
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            yieldRate:         precision * yieldAmount / fullDuration,
            lastUpdated:       startingTime
        });
    }

    function test_reconcile_newSchedule_maximum() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(strategyManager)), deployAmount + yieldAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            0);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), 0);
        assertEq(assetController.poolAssets(address(depositAsset)),    0);

        assertAccounting({
            outstandingAssets:     deployAmount,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: deployAmount
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            yieldRate:         precision * yieldAmount / fullDuration,
            lastUpdated:       startingTime
        });

        vm.prank(strategyManager);
        bitcoinStrategy.reconcile(address(depositAsset), deployAmount);

        assertEq(depositAsset.balanceOf(address(assetController)), deployAmount);
        assertEq(depositAsset.balanceOf(address(strategyManager)), yieldAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            deployAmount);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), deployAmount);
        assertEq(assetController.poolAssets(address(depositAsset)),    deployAmount);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          0,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            yieldRate:         precision * yieldAmount / fullDuration,
            lastUpdated:       startingTime
        });
    }

    function test_reconcile_duringSchedule_minimum() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        vm.warp(startingTime + partialDuration);

        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(strategyManager)), deployAmount + yieldAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            0);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), 0);
        assertEq(assetController.poolAssets(address(depositAsset)),    0);

        assertAccounting({
            outstandingAssets:     deployAmount,
            realizedFees:          0,
            accruedYield:          partialYield,
            accruedFees:           partialFees,
            assetsUnderManagement: deployAmount + partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            yieldRate:         precision * yieldAmount / fullDuration,
            lastUpdated:       startingTime
        });

        vm.prank(strategyManager);
        bitcoinStrategy.reconcile(address(depositAsset), 1);

        assertEq(depositAsset.balanceOf(address(assetController)), 1);
        assertEq(depositAsset.balanceOf(address(strategyManager)), deployAmount + yieldAmount - 1);

        assertEq(compositeAsset.balanceOf(address(pool)),            1);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), 1);
        assertEq(assetController.poolAssets(address(depositAsset)),    1);

        assertAccounting({
            outstandingAssets:     deployAmount + partialYield - partialFees - 1,
            realizedFees:          partialFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: deployAmount + partialYield - partialFees - 1
        });

        assertSchedule({
            remainingYield:    yieldAmount - partialYield,
            remainingDuration: fullDuration - partialDuration,
            yieldRate:         precision * (yieldAmount - partialYield) / (fullDuration - partialDuration),
            lastUpdated:       startingTime + partialDuration
        });
    }

    function test_reconcile_duringSchedule_partial() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        vm.warp(startingTime + partialDuration);

        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(strategyManager)), deployAmount + yieldAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            0);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), 0);
        assertEq(assetController.poolAssets(address(depositAsset)),    0);

        assertAccounting({
            outstandingAssets:     deployAmount,
            realizedFees:          0,
            accruedYield:          partialYield,
            accruedFees:           partialFees,
            assetsUnderManagement: deployAmount + partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            yieldRate:         precision * yieldAmount / fullDuration,
            lastUpdated:       startingTime
        });

        vm.prank(strategyManager);
        bitcoinStrategy.reconcile(address(depositAsset), reconcileAmount);

        assertEq(depositAsset.balanceOf(address(assetController)), reconcileAmount);
        assertEq(depositAsset.balanceOf(address(strategyManager)), deployAmount + yieldAmount - reconcileAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            reconcileAmount);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), reconcileAmount);
        assertEq(assetController.poolAssets(address(depositAsset)),    reconcileAmount);

        assertAccounting({
            outstandingAssets:     deployAmount + partialYield - partialFees - reconcileAmount,
            realizedFees:          partialFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: deployAmount + partialYield - partialFees - reconcileAmount
        });

        assertSchedule({
            remainingYield:    yieldAmount - partialYield,
            remainingDuration: fullDuration - partialDuration,
            yieldRate:         precision * (yieldAmount - partialYield) / (fullDuration - partialDuration),
            lastUpdated:       startingTime + partialDuration
        });
    }

    function test_reconcile_duringSchedule_yield() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        vm.warp(startingTime + partialDuration);

        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(strategyManager)), deployAmount + yieldAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            0);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), 0);
        assertEq(assetController.poolAssets(address(depositAsset)),    0);

        assertAccounting({
            outstandingAssets:     deployAmount,
            realizedFees:          0,
            accruedYield:          partialYield,
            accruedFees:           partialFees,
            assetsUnderManagement: deployAmount + partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            yieldRate:         precision * yieldAmount / fullDuration,
            lastUpdated:       startingTime
        });

        vm.prank(strategyManager);
        bitcoinStrategy.reconcile(address(depositAsset), deployAmount + 1);

        assertEq(depositAsset.balanceOf(address(assetController)), deployAmount + 1);
        assertEq(depositAsset.balanceOf(address(strategyManager)), yieldAmount - 1);

        assertEq(compositeAsset.balanceOf(address(pool)),            deployAmount + 1);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), deployAmount + 1);
        assertEq(assetController.poolAssets(address(depositAsset)),    deployAmount + 1);

        assertAccounting({
            outstandingAssets:     partialYield - partialFees - 1,
            realizedFees:          partialFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: partialYield - partialFees - 1
        });

        assertSchedule({
            remainingYield:    yieldAmount - partialYield,
            remainingDuration: fullDuration - partialDuration,
            yieldRate:         precision * (yieldAmount - partialYield) / (fullDuration - partialDuration),
            lastUpdated:       startingTime + partialDuration
        });
    }

    function test_reconcile_duringSchedule_maximum() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        vm.warp(startingTime + partialDuration);

        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(strategyManager)), deployAmount + yieldAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            0);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), 0);
        assertEq(assetController.poolAssets(address(depositAsset)),    0);

        assertAccounting({
            outstandingAssets:     deployAmount,
            realizedFees:          0,
            accruedYield:          partialYield,
            accruedFees:           partialFees,
            assetsUnderManagement: deployAmount + partialYield - partialFees
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            yieldRate:         precision * yieldAmount / fullDuration,
            lastUpdated:       startingTime
        });

        vm.prank(strategyManager);
        bitcoinStrategy.reconcile(address(depositAsset), deployAmount + partialYield - partialFees);

        assertEq(depositAsset.balanceOf(address(assetController)), deployAmount + partialYield - partialFees);
        assertEq(depositAsset.balanceOf(address(strategyManager)), yieldAmount - partialYield + partialFees);

        assertEq(compositeAsset.balanceOf(address(pool)),            deployAmount + partialYield - partialFees);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), deployAmount + partialYield - partialFees);
        assertEq(assetController.poolAssets(address(depositAsset)),    deployAmount + partialYield - partialFees);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          partialFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    yieldAmount - partialYield,
            remainingDuration: fullDuration - partialDuration,
            yieldRate:         precision * (yieldAmount - partialYield) / (fullDuration - partialDuration),
            lastUpdated:       startingTime + partialDuration
        });
    }

    function test_reconcile_pastSchedule_minimum() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        vm.warp(startingTime + fullDuration + 1 hours);

        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(strategyManager)), deployAmount + yieldAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            0);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), 0);
        assertEq(assetController.poolAssets(address(depositAsset)),    0);

        assertAccounting({
            outstandingAssets:     deployAmount,
            realizedFees:          0,
            accruedYield:          yieldAmount,
            accruedFees:           totalFees,
            assetsUnderManagement: deployAmount + yieldAmount - totalFees
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            yieldRate:         0,
            lastUpdated:       startingTime
        });

        vm.prank(strategyManager);
        bitcoinStrategy.reconcile(address(depositAsset), 1);

        assertEq(depositAsset.balanceOf(address(assetController)), 1);
        assertEq(depositAsset.balanceOf(address(strategyManager)), deployAmount + yieldAmount - 1);

        assertEq(compositeAsset.balanceOf(address(pool)),            1);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), 1);
        assertEq(assetController.poolAssets(address(depositAsset)),    1);

        assertAccounting({
            outstandingAssets:     deployAmount + yieldAmount - totalFees - 1,
            realizedFees:          totalFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: deployAmount + yieldAmount - totalFees - 1
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            yieldRate:         0,
            lastUpdated:       0
        });
    }

    function test_reconcile_pastSchedule_partial() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        vm.warp(startingTime + fullDuration + 1 hours);

        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(strategyManager)), deployAmount + yieldAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            0);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), 0);
        assertEq(assetController.poolAssets(address(depositAsset)),    0);

        assertAccounting({
            outstandingAssets:     deployAmount,
            realizedFees:          0,
            accruedYield:          yieldAmount,
            accruedFees:           totalFees,
            assetsUnderManagement: deployAmount + yieldAmount - totalFees
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            yieldRate:         0,
            lastUpdated:       startingTime
        });

        vm.prank(strategyManager);
        bitcoinStrategy.reconcile(address(depositAsset), reconcileAmount);

        assertEq(depositAsset.balanceOf(address(assetController)), reconcileAmount);
        assertEq(depositAsset.balanceOf(address(strategyManager)), deployAmount + yieldAmount - reconcileAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            reconcileAmount);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), reconcileAmount);
        assertEq(assetController.poolAssets(address(depositAsset)),    reconcileAmount);

        assertAccounting({
            outstandingAssets:     deployAmount + yieldAmount - totalFees - reconcileAmount,
            realizedFees:          totalFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: deployAmount + yieldAmount - totalFees - reconcileAmount
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            yieldRate:         0,
            lastUpdated:       0
        });
    }

    function test_reconcile_pastSchedule_yield() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        vm.warp(startingTime + fullDuration + 1 hours);

        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(strategyManager)), deployAmount + yieldAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            0);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), 0);
        assertEq(assetController.poolAssets(address(depositAsset)),    0);

        assertAccounting({
            outstandingAssets:     deployAmount,
            realizedFees:          0,
            accruedYield:          yieldAmount,
            accruedFees:           totalFees,
            assetsUnderManagement: deployAmount + yieldAmount - totalFees
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            yieldRate:         0,
            lastUpdated:       startingTime
        });

        vm.prank(strategyManager);
        bitcoinStrategy.reconcile(address(depositAsset), deployAmount + 1);

        assertEq(depositAsset.balanceOf(address(assetController)), deployAmount + 1);
        assertEq(depositAsset.balanceOf(address(strategyManager)), yieldAmount - 1);

        assertEq(compositeAsset.balanceOf(address(pool)),            deployAmount + 1);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), deployAmount + 1);
        assertEq(assetController.poolAssets(address(depositAsset)),    deployAmount + 1);

        assertAccounting({
            outstandingAssets:     yieldAmount - totalFees - 1,
            realizedFees:          totalFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: yieldAmount - totalFees - 1
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            yieldRate:         0,
            lastUpdated:       0
        });
    }

    function test_reconcile_pastSchedule_maximum() external {
        vm.prank(strategyManager);
        bitcoinStrategy.schedule(yieldAmount, deadline);

        vm.warp(startingTime + fullDuration + 1 hours);

        assertEq(depositAsset.balanceOf(address(assetController)), 0);
        assertEq(depositAsset.balanceOf(address(strategyManager)), deployAmount + yieldAmount);

        assertEq(compositeAsset.balanceOf(address(pool)),            0);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), 0);
        assertEq(assetController.poolAssets(address(depositAsset)),    0);

        assertAccounting({
            outstandingAssets:     deployAmount,
            realizedFees:          0,
            accruedYield:          yieldAmount,
            accruedFees:           totalFees,
            assetsUnderManagement: deployAmount + yieldAmount - totalFees
        });

        assertSchedule({
            remainingYield:    yieldAmount,
            remainingDuration: fullDuration,
            yieldRate:         0,
            lastUpdated:       startingTime
        });

        vm.prank(strategyManager);
        bitcoinStrategy.reconcile(address(depositAsset), deployAmount + yieldAmount - totalFees);

        assertEq(depositAsset.balanceOf(address(assetController)), deployAmount + yieldAmount - totalFees);
        assertEq(depositAsset.balanceOf(address(strategyManager)), totalFees);

        assertEq(compositeAsset.balanceOf(address(pool)),            deployAmount + yieldAmount - totalFees);
        assertEq(compositeAsset.balanceOf(address(bitcoinStrategy)), 0);
        assertEq(compositeAsset.balanceOf(address(assetController)), 0);

        assertEq(assetController.depositAssets(address(depositAsset)), deployAmount + yieldAmount - totalFees);
        assertEq(assetController.poolAssets(address(depositAsset)),    deployAmount + yieldAmount - totalFees);

        assertAccounting({
            outstandingAssets:     0,
            realizedFees:          totalFees,
            accruedYield:          0,
            accruedFees:           0,
            assetsUnderManagement: 0
        });

        assertSchedule({
            remainingYield:    0,
            remainingDuration: 0,
            yieldRate:         0,
            lastUpdated:       0
        });
    }

}
