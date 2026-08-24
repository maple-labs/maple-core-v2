// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IAllocationStrategy,
    IMockERC20,
    IPool,
    IPoolManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract SharedAllocationStrategyTests is TestBaseWithAssertions {

    address aaveStrategyDelegate       = makeAddr("aaveStrategyDelegate");
    address allocationStrategyDelegate = makeAddr("allocationStrategyDelegate");
    address managedWallet              = makeAddr("managedWallet");
    address poolALp                    = makeAddr("poolALp");
    address poolBLp                    = makeAddr("poolBLp");
    address skyStrategyDelegate        = makeAddr("skyStrategyDelegate");

    address poolA;
    address poolB;
    address poolManagerA;
    address poolManagerB;

    uint256 aaveFunding         = 300_000e6;
    uint256 aaveRounding        = 2;  // Aave funding through this exact Pool topology rounds down two asset units at this fork block.
    uint256 allocationDeploy    = 800_000e6;
    uint256 allocationFundingA  = 600_000e6;
    uint256 allocationFundingB  = 400_000e6;
    uint256 allocationReturn    = 300_000e6;
    uint256 allocationYield     = 100_000e6;
    uint256 impairmentAmount    = 200_000e6;
    uint256 poolADeposit        = 1_200_000e6;
    uint256 poolBDeposit        = 400_000e6;
    uint256 skyFunding          = 300_000e6;
    uint256 skyRounding         = 1;  // Sky loses one funds-asset unit in the USDC-to-sUSDS conversion at this fork block.

    uint256 aaveAssets;
    uint256 aaveShares;
    uint256 allocationAssetsAfterYield;
    uint256 allocationAssetsA;
    uint256 allocationAssetsB;
    uint256 allocationExitAssetsA;
    uint256 allocationLossA;
    uint256 allocationLossB;
    uint256 allocationNetAssetsA;
    uint256 allocationNetAssetsB;
    uint256 allocationSharesA;
    uint256 allocationSharesB;
    uint256 allocationTotalShares;
    uint256 deployedAssetsAfterReturn;
    uint256 finalAllocationAssetsB;
    uint256 finalAllocationLiquidity;
    uint256 finalPoolALiquidity;
    uint256 initialPoolAAssets;
    uint256 poolAAssetsAfterYield;
    uint256 skyAssets;
    uint256 skyShares;

    function setUp() public override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), MAINNET_FORK_BLOCK);

        startingTime = uint32(block.timestamp);
        fundsAsset   = IMockERC20(USDC);

        _createAccounts();
        _createGlobals();
        _configureGlobals();
        _createFactories();

        ( aaveV3StrategyManager, aaveV3UnderlyingStrategy ) = _deployAaveV3Strategy({
            strategyDelegate_:            aaveStrategyDelegate,
            aaveToken_:                   AAVE_USDC,
            useVirtualUnderlyingBalance_: true,
            strategyDelegateFeeRate_:     0,
            strategyProtocolFeeRate_:     0,
            strategyLiquidityCap_:        0,
            bootstrapMint_:               0
        });

        ( skyStrategyManager, skyUnderlyingStrategy ) = _deploySkyStrategy({
            strategyDelegate_:        skyStrategyDelegate,
            fundsAsset_:              address(fundsAsset),
            savingsUsds_:             SAVINGS_USDS,
            psm_:                     USDS_LITE_PSM,
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        ( allocationStrategyManager, allocationUnderlyingStrategy ) = _deployAllocationStrategy({
            strategyDelegate_:        allocationStrategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        setManagedWallet({
            strategy_:        allocationUnderlyingStrategy,
            managedWallet_:   managedWallet,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   type(uint256).max
        });

        vm.prank(governor);
        globals.setValidPoolDelegate(makeAddr("poolADelegate"), true);

        ( poolA, poolManagerA, ) = _createPoolWithMultipleStrategies({
            poolDelegate_:      makeAddr("poolADelegate"),
            fundsAsset_:        address(fundsAsset),
            name_:              "Pool A",
            strategyFactories_: new address[](0),
            strategyData_:      new bytes[](0)
        });

        _configurePool();
        openPool(poolManagerA);

        addStrategyManagerToPool(poolManagerA, aaveV3StrategyManager);
        addStrategyManagerToPool(poolManagerA, skyStrategyManager);
        addStrategyManagerToPool(poolManagerA, allocationStrategyManager);

        vm.prank(governor);
        globals.setValidPoolDelegate(makeAddr("poolBDelegate"), true);

        ( poolB, poolManagerB, ) = _createPoolWithMultipleStrategies({
            poolDelegate_:      makeAddr("poolBDelegate"),
            fundsAsset_:        address(fundsAsset),
            name_:              "Pool B",
            strategyFactories_: new address[](0),
            strategyData_:      new bytes[](0)
        });

        _configurePool();
        openPool(poolManagerB);

        vm.startPrank(governor);
        IPoolManager(poolManagerB).addStrategyManager(allocationStrategyManager);
        IPoolManager(poolManagerB).setStrategyCap(allocationStrategyManager, type(uint256).max);
        vm.stopPrank();
    }

    function testFork_sharedAllocationStrategy_acrossPoolTopologies() external {
        /**********************************************************************************************************************************/
        /*** Assert Pool A has three strategies and Pool B has only the shared Allocation strategy                                      ***/
        /**********************************************************************************************************************************/

        assertEq(IPoolManager(poolManagerA).strategyListLength(), 3);
        assertEq(IPoolManager(poolManagerA).strategyList(0),      aaveV3StrategyManager);
        assertEq(IPoolManager(poolManagerA).strategyList(1),      skyStrategyManager);
        assertEq(IPoolManager(poolManagerA).strategyList(2),      allocationStrategyManager);

        assertEq(IPoolManager(poolManagerB).strategyListLength(), 1);
        assertEq(IPoolManager(poolManagerB).strategyList(0),      allocationStrategyManager);

        /**********************************************************************************************************************************/
        /*** Fund Aave, Sky and Allocation from Pool A, and fund the shared Allocation strategy from Pool B                             ***/
        /**********************************************************************************************************************************/

        deposit(poolA, poolALp, poolADeposit);
        deposit(poolB, poolBLp, poolBDeposit);

        aaveAssets            = aaveFunding - aaveRounding;                  // 300_000e6 - 2
        aaveShares            = aaveAssets;                                  // 300_000e6 - 2
        skyAssets             = skyFunding - skyRounding;                    // 300_000e6 - 1
        skyShares             = skyAssets;                                   // 300_000e6 - 1
        allocationAssetsA     = allocationFundingA;                          // 600_000e6
        allocationAssetsB     = allocationFundingB;                          // 400_000e6
        allocationSharesA     = allocationFundingA;                          // 600_000e6
        allocationSharesB     = allocationFundingB;                          // 400_000e6
        allocationTotalShares = allocationSharesA + allocationSharesB;       // 1_000_000e6
        initialPoolAAssets    = aaveAssets + skyAssets + allocationAssetsA;  // 1_200_000e6 - 3

        fundStrategyManager(poolManagerA, aaveV3StrategyManager, aaveFunding);
        fundStrategyManager(poolManagerA, skyStrategyManager, skyFunding);
        fundStrategyManager(poolManagerA, allocationStrategyManager, allocationFundingA);
        fundStrategyManager(poolManagerB, allocationStrategyManager, allocationFundingB);

        assertPoolState({
            pool:               poolA,
            totalAssets:        initialPoolAAssets,
            totalSupply:        poolADeposit,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        allocationAssetsB,
            totalSupply:        poolBDeposit,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAaveV3Strategy({
            strategyManager:         aaveV3StrategyManager,
            aum:                     aaveAssets,
            aTokenBalance:           aaveAssets,
            lastRecordedTotalAssets: aaveAssets,
            unrealizedLosses:        0
        });

        assertStrategyManager({
            strategyManager:       aaveV3StrategyManager,
            totalShares:           aaveShares,
            totalPendingShares:    0,
            assetsUnderManagement: aaveAssets,
            availableToWithdraw:   aaveAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerA,
            assets:           aaveAssets,
            shares:           aaveShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertSkyStrategy({
            strategyManager:  skyStrategyManager,
            aum:              skyAssets,
            unrealizedLosses: 0
        });

        assertStrategyManager({
            strategyManager:       skyStrategyManager,
            totalShares:           skyShares,
            totalPendingShares:    0,
            assetsUnderManagement: skyAssets,
            availableToWithdraw:   skyAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      poolManagerA,
            assets:           skyAssets,
            shares:           skyShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: allocationTotalShares,
            availableToWithdraw:   allocationTotalShares,
            recordedAssets:        allocationTotalShares,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           allocationTotalShares,
            totalPendingShares:    0,
            assetsUnderManagement: allocationTotalShares,
            availableToWithdraw:   allocationTotalShares,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerA,
            assets:           allocationAssetsA,
            shares:           allocationSharesA,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           allocationAssetsB,
            shares:           allocationSharesB,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);
        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy),                                    0);
        assertEq(fundsAsset.balanceOf(skyUnderlyingStrategy),                                       0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy),                                allocationTotalShares);
        assertEq(fundsAsset.balanceOf(managedWallet),                                               0);

        /**********************************************************************************************************************************/
        /*** Deploy shared Allocation assets without changing either Pool's ownership                                                   ***/
        /**********************************************************************************************************************************/

        deployAssets(allocationUnderlyingStrategy, managedWallet, allocationDeploy);

        assertPoolState({
            pool:               poolA,
            totalAssets:        initialPoolAAssets,
            totalSupply:        poolADeposit,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        allocationAssetsB,
            totalSupply:        poolBDeposit,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: allocationTotalShares,
            availableToWithdraw:   allocationTotalShares - allocationDeploy,
            recordedAssets:        allocationTotalShares - allocationDeploy,
            totalDeployedAssets:   allocationDeploy,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           allocationTotalShares,
            totalPendingShares:    0,
            assetsUnderManagement: allocationTotalShares,
            availableToWithdraw:   allocationTotalShares - allocationDeploy,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerA,
            assets:           allocationAssetsA,
            shares:           allocationSharesA,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           allocationAssetsB,
            shares:           allocationSharesB,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), allocationDeploy);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), allocationTotalShares - allocationDeploy);
        assertEq(fundsAsset.balanceOf(managedWallet),                allocationDeploy);

        /**********************************************************************************************************************************/
        /*** Return part of the deployment without changing either Pool's ownership                                                     ***/
        /**********************************************************************************************************************************/

        deployedAssetsAfterReturn = allocationDeploy - allocationReturn;  // 500_000e6

        returnAssets(allocationUnderlyingStrategy, managedWallet, managedWallet, allocationReturn);

        assertPoolState({
            pool:               poolA,
            totalAssets:        initialPoolAAssets,
            totalSupply:        poolADeposit,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        allocationAssetsB,
            totalSupply:        poolBDeposit,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: allocationTotalShares,
            availableToWithdraw:   allocationTotalShares - deployedAssetsAfterReturn,
            recordedAssets:        allocationTotalShares - deployedAssetsAfterReturn,
            totalDeployedAssets:   deployedAssetsAfterReturn,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           allocationTotalShares,
            totalPendingShares:    0,
            assetsUnderManagement: allocationTotalShares,
            availableToWithdraw:   allocationTotalShares - deployedAssetsAfterReturn,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerA,
            assets:           allocationAssetsA,
            shares:           allocationSharesA,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           allocationAssetsB,
            shares:           allocationSharesB,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), deployedAssetsAfterReturn);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), allocationTotalShares - deployedAssetsAfterReturn);
        assertEq(fundsAsset.balanceOf(managedWallet),                allocationDeploy);

        /**********************************************************************************************************************************/
        /*** Realize instant yield and prove that both Pools receive it pro rata                                                        ***/
        /**********************************************************************************************************************************/

        allocationAssetsAfterYield = allocationTotalShares + allocationYield;                                 // 1_100_000e6
        allocationAssetsA          = allocationSharesA * allocationAssetsAfterYield / allocationTotalShares;  // 660_000e6
        allocationAssetsB          = allocationSharesB * allocationAssetsAfterYield / allocationTotalShares;  // 440_000e6
        poolAAssetsAfterYield      = aaveAssets + skyAssets + allocationAssetsA;                              // 1_260_000e6 - 3

        realizeYield(allocationUnderlyingStrategy, managedWallet, allocationYield, 0);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssetsAfterYield,
            totalSupply:        poolADeposit,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        allocationAssetsB,
            totalSupply:        poolBDeposit,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: allocationAssetsAfterYield,
            availableToWithdraw:   allocationAssetsAfterYield - deployedAssetsAfterReturn,
            recordedAssets:        allocationAssetsAfterYield - deployedAssetsAfterReturn,
            totalDeployedAssets:   deployedAssetsAfterReturn,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: allocationYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime,
            yieldLastRealized:    startingTime,
            realizedYield:        allocationYield
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           allocationTotalShares,
            totalPendingShares:    0,
            assetsUnderManagement: allocationAssetsAfterYield,
            availableToWithdraw:   allocationAssetsAfterYield - deployedAssetsAfterReturn,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerA,
            assets:           allocationAssetsA,
            shares:           allocationSharesA,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           allocationAssetsB,
            shares:           allocationSharesB,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), deployedAssetsAfterReturn);

        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), allocationAssetsAfterYield - deployedAssetsAfterReturn);
        assertEq(fundsAsset.balanceOf(managedWallet),                allocationDeploy);

        /**********************************************************************************************************************************/
        /*** Impair the shared Allocation strategy and split the loss according to Pool ownership                                       ***/
        /**********************************************************************************************************************************/

        allocationLossA      = divRoundUp(allocationSharesA * impairmentAmount, allocationTotalShares);  // 120_000e6
        allocationLossB      = divRoundUp(allocationSharesB * impairmentAmount, allocationTotalShares);  // 80_000e6
        allocationNetAssetsA = allocationAssetsA - allocationLossA;                                      // 540_000e6
        allocationNetAssetsB = allocationAssetsB - allocationLossB;                                      // 360_000e6

        impairAllocationStrategy(allocationUnderlyingStrategy, impairmentAmount);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssetsAfterYield,
            totalSupply:        poolADeposit,
            unrealizedLosses:   allocationLossA,
            availableLiquidity: 0
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        allocationAssetsB,
            totalSupply:        poolBDeposit,
            unrealizedLosses:   allocationLossB,
            availableLiquidity: 0
        });

        assertEq(IPool(poolA).convertToExitAssets(poolADeposit), poolAAssetsAfterYield - allocationLossA);
        assertEq(IPool(poolB).convertToExitAssets(poolBDeposit), allocationNetAssetsB);

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: allocationAssetsAfterYield,
            availableToWithdraw:   allocationAssetsAfterYield - deployedAssetsAfterReturn,
            recordedAssets:        allocationAssetsAfterYield - deployedAssetsAfterReturn,
            totalDeployedAssets:   deployedAssetsAfterReturn,
            unrealizedLosses:      impairmentAmount
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           allocationTotalShares,
            totalPendingShares:    0,
            assetsUnderManagement: allocationAssetsAfterYield,
            availableToWithdraw:   allocationAssetsAfterYield - deployedAssetsAfterReturn,
            unrealizedLosses:      impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerA,
            assets:           allocationAssetsA,
            shares:           allocationSharesA,
            pendingShares:    0,
            unrealizedLosses: allocationLossA
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           allocationAssetsB,
            shares:           allocationSharesB,
            pendingShares:    0,
            unrealizedLosses: allocationLossB
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                impairmentAmount);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), deployedAssetsAfterReturn);

        /**********************************************************************************************************************************/
        /*** Exit Pool A's unrelated Aave position without modifying Pool B's Allocation position                                       ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(poolManagerA, aaveV3StrategyManager, aaveShares);

        assertStrategyManagerPosition({
            strategyManager:  aaveV3StrategyManager,
            poolManager:      poolManagerA,
            assets:           aaveAssets,
            shares:           aaveShares,
            pendingShares:    aaveShares,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           allocationAssetsB,
            shares:           allocationSharesB,
            pendingShares:    0,
            unrealizedLosses: allocationLossB
        });

        assertEq(IPool(poolB).convertToExitAssets(poolBDeposit), allocationNetAssetsB);

        processRedemptionFromStrategyManager(poolManagerA, aaveV3StrategyManager, aaveShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssetsAfterYield,
            totalSupply:        poolADeposit,
            unrealizedLosses:   allocationLossA,
            availableLiquidity: aaveAssets
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        allocationAssetsB,
            totalSupply:        poolBDeposit,
            unrealizedLosses:   allocationLossB,
            availableLiquidity: 0
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
            poolManager:      poolManagerA,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           allocationAssetsB,
            shares:           allocationSharesB,
            pendingShares:    0,
            unrealizedLosses: allocationLossB
        });

        assertEq(IPool(poolA).balanceOf(poolALp),                poolADeposit);
        assertEq(IPool(poolB).balanceOf(poolBLp),                poolBDeposit);
        assertEq(IPool(poolB).convertToExitAssets(poolBDeposit), allocationNetAssetsB);

        assertEq(fundsAsset.balanceOf(aaveV3UnderlyingStrategy), 0);

        /**********************************************************************************************************************************/
        /*** Exit Pool A's unrelated Sky position without modifying Pool B's Allocation position                                        ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(poolManagerA, skyStrategyManager, skyShares);

        assertStrategyManagerPosition({
            strategyManager:  skyStrategyManager,
            poolManager:      poolManagerA,
            assets:           skyAssets,
            shares:           skyShares,
            pendingShares:    skyShares,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           allocationAssetsB,
            shares:           allocationSharesB,
            pendingShares:    0,
            unrealizedLosses: allocationLossB
        });

        assertEq(IPool(poolB).convertToExitAssets(poolBDeposit), allocationNetAssetsB);

        processRedemptionFromStrategyManager(poolManagerA, skyStrategyManager, skyShares);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAAssetsAfterYield,
            totalSupply:        poolADeposit,
            unrealizedLosses:   allocationLossA,
            availableLiquidity: aaveAssets + skyAssets
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        allocationAssetsB,
            totalSupply:        poolBDeposit,
            unrealizedLosses:   allocationLossB,
            availableLiquidity: 0
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
            poolManager:      poolManagerA,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           allocationAssetsB,
            shares:           allocationSharesB,
            pendingShares:    0,
            unrealizedLosses: allocationLossB
        });

        assertEq(IPool(poolB).convertToExitAssets(poolBDeposit), allocationNetAssetsB);
        assertEq(fundsAsset.balanceOf(skyUnderlyingStrategy),    0);

        /**********************************************************************************************************************************/
        /*** Fully exit Pool A's impaired Allocation position while preserving Pool B's shares and net exit value                       ***/
        /**********************************************************************************************************************************/

        allocationExitAssetsA    = allocationNetAssetsA;                                // 540_000e6
        finalAllocationAssetsB   = allocationAssetsAfterYield - allocationExitAssetsA;  // 560_000e6
        finalAllocationLiquidity = finalAllocationAssetsB - deployedAssetsAfterReturn;  // 60_000e6
        finalPoolALiquidity      = aaveAssets + skyAssets + allocationExitAssetsA;      // 1_140_000e6 - 3

        requestRedeemFromStrategyManager(poolManagerA, allocationStrategyManager, allocationSharesA);

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           allocationTotalShares,
            totalPendingShares:    allocationSharesA,
            assetsUnderManagement: allocationAssetsAfterYield,
            availableToWithdraw:   allocationAssetsAfterYield - deployedAssetsAfterReturn,
            unrealizedLosses:      impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerA,
            assets:           allocationAssetsA,
            shares:           allocationSharesA,
            pendingShares:    allocationSharesA,
            unrealizedLosses: allocationLossA
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           allocationAssetsB,
            shares:           allocationSharesB,
            pendingShares:    0,
            unrealizedLosses: allocationLossB
        });

        assertEq(IPool(poolB).convertToExitAssets(poolBDeposit), allocationNetAssetsB);

        processRedemptionFromStrategyManager(poolManagerA, allocationStrategyManager, allocationSharesA);

        assertPoolState({
            pool:               poolA,
            totalAssets:        finalPoolALiquidity,
            totalSupply:        poolADeposit,
            unrealizedLosses:   0,
            availableLiquidity: finalPoolALiquidity
        });

        assertPoolState({
            pool:               poolB,
            totalAssets:        finalAllocationAssetsB,
            totalSupply:        poolBDeposit,
            unrealizedLosses:   impairmentAmount,
            availableLiquidity: 0
        });

        assertEq(IPool(poolA).convertToExitAssets(poolADeposit), finalPoolALiquidity);
        assertEq(IPool(poolB).convertToExitAssets(poolBDeposit), allocationNetAssetsB);

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: finalAllocationAssetsB,
            availableToWithdraw:   finalAllocationLiquidity,
            recordedAssets:        finalAllocationLiquidity,
            totalDeployedAssets:   deployedAssetsAfterReturn,
            unrealizedLosses:      impairmentAmount
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: allocationYield,
            yieldStart:           startingTime,
            yieldDeadline:        startingTime,
            yieldLastRealized:    startingTime,
            realizedYield:        allocationYield
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           allocationSharesB,
            totalPendingShares:    0,
            assetsUnderManagement: finalAllocationAssetsB,
            availableToWithdraw:   finalAllocationLiquidity,
            unrealizedLosses:      impairmentAmount
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerA,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerB,
            assets:           finalAllocationAssetsB,
            shares:           allocationSharesB,
            pendingShares:    0,
            unrealizedLosses: impairmentAmount
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).impairedAssets(),                impairmentAmount);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), deployedAssetsAfterReturn);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy),                                finalAllocationLiquidity);
        assertEq(fundsAsset.balanceOf(managedWallet),                                               allocationDeploy);
    }

}
