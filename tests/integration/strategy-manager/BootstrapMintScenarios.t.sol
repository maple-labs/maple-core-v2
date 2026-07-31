// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAllocationStrategy,
    IMapleProxyFactory,
    IPool,
    IStrategyManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { AllocationStrategyInitializerParams } from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract StrategyManagerBootstrapMintDeploymentTests is TestBaseWithAssertions {

    uint256 constant POOL_LIQUIDITY = 1_000_000e6;

    address lp = makeAddr("lp");

    function test_fundStrategyManager_success_noBootstrapMintWithFrontrunDonation() external {
        uint256 donationAssets = 500_000e6;
        uint256 fundAssets     = 1_000e6;
        uint256 expectedShares = fundAssets;

        bytes memory data = abi.encode(AllocationStrategyInitializerParams({
            fundsAsset:              address(fundsAsset),
            strategyMetadata:        "Allocation Strategy",
            strategyDelegateFeeRate: 0,
            strategyProtocolFeeRate: 0,
            yieldCap:                type(uint256).max
        }));

        ( address expectedStrategyManager, address expectedUnderlyingStrategy ) =
            strategyDeployer.getDeploymentAddresses(strategyDelegate, strategyManagerFactory, allocationStrategyFactory, data);

        /**********************************************************************************************************************************/
        /*** Attacker donates to the predicted underlying strategy address before deployment                                            ***/
        /**********************************************************************************************************************************/

        erc20_mint(address(fundsAsset), expectedUnderlyingStrategy, donationAssets);

        assertEq(fundsAsset.balanceOf(expectedUnderlyingStrategy), donationAssets);

        /**********************************************************************************************************************************/
        /*** Deployment without bootstrap mint leaves the donation sitting in the strategy against zero shares                          ***/
        /**********************************************************************************************************************************/

        ( address strategyManager_, address underlyingStrategy_ ) = _deployAllocationStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        assertEq(strategyManager_,    expectedStrategyManager);
        assertEq(underlyingStrategy_, expectedUnderlyingStrategy);

        assertEq(IMapleProxyFactory(strategyManagerFactory).isInstance(strategyManager_),       true);
        assertEq(IMapleProxyFactory(allocationStrategyFactory).isInstance(underlyingStrategy_), true);

        assertEq(IStrategyManager(strategyManager_).configured(), true);
        assertEq(IStrategyManager(strategyManager_).active(),     true);

        assertAllocationStrategy({
            allocationStrategy:    underlyingStrategy_,
            assetsUnderManagement: donationAssets,
            availableToWithdraw:   donationAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager_,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: donationAssets,
            availableToWithdraw:   donationAssets,
            unrealizedLosses:      0
        });

        /**********************************************************************************************************************************/
        /*** First fund mints one-to-one because total shares are zero and captures the donation                                        ***/
        /**********************************************************************************************************************************/

        addStrategyManagerToPool(address(poolManager), strategyManager_);
        deposit(lp, POOL_LIQUIDITY);
        fundStrategyManager(address(poolManager), strategyManager_, fundAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        POOL_LIQUIDITY + donationAssets,
            totalSupply:        POOL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: POOL_LIQUIDITY - fundAssets
        });

        assertAllocationStrategy({
            allocationStrategy:    underlyingStrategy_,
            assetsUnderManagement: donationAssets + fundAssets,
            availableToWithdraw:   donationAssets + fundAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager_,
            totalShares:           expectedShares,
            totalPendingShares:    0,
            assetsUnderManagement: donationAssets + fundAssets,
            availableToWithdraw:   donationAssets + fundAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager_,
            poolManager:      address(poolManager),
            assets:           donationAssets + fundAssets,
            shares:           expectedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

    function test_deploy_success_bootstrapMintWithFrontrunDonation() external {
        uint256 bootstrapMint  = 10e6;
        uint256 donationAssets = 500_000e6;
        uint256 fundAssets     = (bootstrapMint + donationAssets) / 4;
        uint256 expectedShares = bootstrapMint / 4;

        bytes memory data = abi.encode(AllocationStrategyInitializerParams({
            fundsAsset:              address(fundsAsset),
            strategyMetadata:        "Allocation Strategy",
            strategyDelegateFeeRate: 0,
            strategyProtocolFeeRate: 0,
            yieldCap:                type(uint256).max
        }));

        ( address expectedStrategyManager, address expectedUnderlyingStrategy ) =
            strategyDeployer.getDeploymentAddresses(strategyDelegate, strategyManagerFactory, allocationStrategyFactory, data);

        /**********************************************************************************************************************************/
        /*** Attacker donates to the predicted underlying strategy address before deployment                                            ***/
        /**********************************************************************************************************************************/

        erc20_mint(address(fundsAsset), expectedUnderlyingStrategy, donationAssets);

        assertEq(fundsAsset.balanceOf(expectedUnderlyingStrategy), donationAssets);

        /**********************************************************************************************************************************/
        /*** Deployment with bootstrap mint completes successfully and the dead shares absorb the donation                              ***/
        /**********************************************************************************************************************************/

        ( address strategyManager_, address underlyingStrategy_ ) = _deployAllocationStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           bootstrapMint
        });

        assertEq(strategyManager_,    expectedStrategyManager);
        assertEq(underlyingStrategy_, expectedUnderlyingStrategy);

        assertEq(IMapleProxyFactory(strategyManagerFactory).isInstance(strategyManager_),       true);
        assertEq(IMapleProxyFactory(allocationStrategyFactory).isInstance(underlyingStrategy_), true);

        assertEq(IStrategyManager(strategyManager_).configured(), true);
        assertEq(IStrategyManager(strategyManager_).active(),     true);

        assertAllocationStrategy({
            allocationStrategy:    underlyingStrategy_,
            assetsUnderManagement: donationAssets + bootstrapMint,
            availableToWithdraw:   donationAssets + bootstrapMint,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager_,
            totalShares:           bootstrapMint,
            totalPendingShares:    0,
            assetsUnderManagement: donationAssets + bootstrapMint,
            availableToWithdraw:   donationAssets + bootstrapMint,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager_,
            poolManager:      address(0),
            assets:           donationAssets + bootstrapMint,
            shares:           bootstrapMint,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Funding the deployed strategy works normally and the dead shares keep holding the donation                                 ***/
        /**********************************************************************************************************************************/

        addStrategyManagerToPool(address(poolManager), strategyManager_);
        deposit(lp, POOL_LIQUIDITY);
        fundStrategyManager(address(poolManager), strategyManager_, fundAssets);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        POOL_LIQUIDITY,
            totalSupply:        POOL_LIQUIDITY,
            unrealizedLosses:   0,
            availableLiquidity: POOL_LIQUIDITY - fundAssets
        });

        assertAllocationStrategy({
            allocationStrategy:    underlyingStrategy_,
            assetsUnderManagement: donationAssets + bootstrapMint + fundAssets,
            availableToWithdraw:   donationAssets + bootstrapMint + fundAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       strategyManager_,
            totalShares:           bootstrapMint + expectedShares,
            totalPendingShares:    0,
            assetsUnderManagement: donationAssets + bootstrapMint + fundAssets,
            availableToWithdraw:   donationAssets + bootstrapMint + fundAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager_,
            poolManager:      address(poolManager),
            assets:           fundAssets,
            shares:           expectedShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager_,
            poolManager:      address(0),
            assets:           donationAssets + bootstrapMint,
            shares:           bootstrapMint,
            pendingShares:    0,
            unrealizedLosses: 0
        });
    }

}

contract StrategyManagerBootstrapMintRedemptionInflationTests is TestBaseWithAssertions {

    uint256 bootstrapMint = 10e6;
    uint256 depositAmount = 1_000_000e6;
    uint256 impairment    = 400_000e6;
    uint256 newFunding    = 100_000e6;

    address lpA = makeAddr("lpA");
    address lpB = makeAddr("lpB");

    address delegateA = makeAddr("strategyDelegateA");
    address delegateB = makeAddr("strategyDelegateB");

    address noBootstrapManager;
    address noBootstrapStrategy;
    address bootstrapManager;
    address bootstrapStrategy;

    address poolA;
    address poolManagerA;
    address poolB;
    address poolManagerB;

    function setUp() public override {
        super.setUp();

        ( noBootstrapManager, noBootstrapStrategy ) = _deployAllocationStrategy({
            strategyDelegate_:        delegateA,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        ( bootstrapManager, bootstrapStrategy ) = _deployAllocationStrategy({
            strategyDelegate_:        delegateB,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           bootstrapMint
        });

        ( poolA, poolManagerA ) = _createPoolSharingStrategy("poolDelegateA", noBootstrapManager);
        ( poolB, poolManagerB ) = _createPoolSharingStrategy("poolDelegateB", bootstrapManager);

        openPool(poolManagerA);
        openPool(poolManagerB);

        vm.prank(delegateA);
        IStrategyManager(noBootstrapManager).setStrategyLiquidityCap(type(uint256).max);

        vm.prank(delegateB);
        IStrategyManager(bootstrapManager).setStrategyLiquidityCap(type(uint256).max);

        deposit(poolA, lpA, depositAmount);
        deposit(poolB, lpB, depositAmount);

        fundStrategyManager(poolManagerA, noBootstrapManager, depositAmount);
        fundStrategyManager(poolManagerB, bootstrapManager,   depositAmount);
    }

    function test_redemptionInflation_bootstrapMintPreventsFundingDoS() external {

        assertStrategyManager({
            strategyManager:       noBootstrapManager,
            totalShares:           depositAmount,
            totalPendingShares:    0,
            assetsUnderManagement: depositAmount,
            availableToWithdraw:   depositAmount,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       bootstrapManager,
            totalShares:           depositAmount + bootstrapMint,
            totalPendingShares:    0,
            assetsUnderManagement: depositAmount + bootstrapMint,
            availableToWithdraw:   depositAmount + bootstrapMint,
            unrealizedLosses:      0
        });

        /**********************************************************************************************************************************/
        /*** Impair both strategies                                                                                                     ***/
        /**********************************************************************************************************************************/

        vm.prank(delegateA);
        IAllocationStrategy(noBootstrapStrategy).impair(impairment);

        vm.prank(delegateB);
        IAllocationStrategy(bootstrapStrategy).impair(impairment);

        assertStrategyManager({
            strategyManager:       noBootstrapManager,
            totalShares:           depositAmount,
            totalPendingShares:    0,
            assetsUnderManagement: depositAmount,
            availableToWithdraw:   depositAmount,
            unrealizedLosses:      impairment
        });

        assertStrategyManager({
            strategyManager:       bootstrapManager,
            totalShares:           depositAmount + bootstrapMint,
            totalPendingShares:    0,
            assetsUnderManagement: depositAmount + bootstrapMint,
            availableToWithdraw:   depositAmount + bootstrapMint,
            unrealizedLosses:      impairment
        });

        /**********************************************************************************************************************************/
        /*** Each pool redeems down to the strategy's minimum share supply                                                              ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(poolManagerA, noBootstrapManager, depositAmount - 1);
        requestRedeemFromStrategyManager(poolManagerB, bootstrapManager,   depositAmount);

        processRedemptionFromStrategyManager(poolManagerA, noBootstrapManager, depositAmount - 1);
        processRedemptionFromStrategyManager(poolManagerB, bootstrapManager,   depositAmount);

        uint256 bootstrapStrInitialFunding     = depositAmount + bootstrapMint;
        uint256 bootstrapStrExpectedReceived   = depositAmount * (bootstrapStrInitialFunding - impairment) / bootstrapStrInitialFunding;
        uint256 bootstrapStrAumAfterRedemption = depositAmount + bootstrapMint - bootstrapStrExpectedReceived;

        assertStrategyManager({
            strategyManager:       noBootstrapManager,
            totalShares:           1,
            totalPendingShares:    0,
            assetsUnderManagement: impairment + 1,
            availableToWithdraw:   impairment + 1,
            unrealizedLosses:      impairment
        });

        assertStrategyManager({
            strategyManager:       bootstrapManager,
            totalShares:           bootstrapMint,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapStrAumAfterRedemption,
            availableToWithdraw:   bootstrapStrAumAfterRedemption,
            unrealizedLosses:      impairment
        });

        /**********************************************************************************************************************************/
        /*** Funding resumes and is only blocked on the strategy without a bootstrap mint                                               ***/
        /**********************************************************************************************************************************/

        uint256 mintedShares = newFunding * bootstrapMint / bootstrapStrAumAfterRedemption;

        vm.prank(delegateA);
        vm.expectRevert("MSM:FSM:ZERO_SHARES");
        IStrategyManager(noBootstrapManager).fundStrategyManager(poolManagerA, newFunding, "");

        fundStrategyManager(poolManagerB, bootstrapManager, newFunding);

        assertStrategyManager({
            strategyManager:       bootstrapManager,
            totalShares:           bootstrapMint + mintedShares,
            totalPendingShares:    0,
            assetsUnderManagement: bootstrapStrAumAfterRedemption + newFunding,
            availableToWithdraw:   bootstrapStrAumAfterRedemption + newFunding,
            unrealizedLosses:      impairment
        });
    }

}

contract StrategyManagerBootstrapMintUnderpricedMintTests is TestBaseWithAssertions {

    uint256 bootstrapMint   = 10e6;
    uint256 attackerDeposit = 1_000_000e6;
    uint256 impairment      = 500_000e6;
    uint256 victimDeposit   = 750_000e6;
    uint256 roundUpError    = 1;

    address attackerLp = makeAddr("attackerLp");
    address victimLp   = makeAddr("victimLp");

    address delegateA = makeAddr("strategyDelegateA");
    address delegateB = makeAddr("strategyDelegateB");

    address noBootstrapManager;
    address noBootstrapStrategy;
    address bootstrapManager;
    address bootstrapStrategy;

    address attackerPool;
    address attackerPoolManager;
    address victimPool;
    address victimPoolManager;

    function setUp() public override {
        super.setUp();

        ( noBootstrapManager, noBootstrapStrategy ) = _deployAllocationStrategy({
            strategyDelegate_:        delegateA,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        ( bootstrapManager, bootstrapStrategy ) = _deployAllocationStrategy({
            strategyDelegate_:        delegateB,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           bootstrapMint
        });

        ( attackerPool, attackerPoolManager ) = _createPoolSharingStrategy("attackerDelegate", noBootstrapManager);
        ( victimPool,   victimPoolManager )   = _createPoolSharingStrategy("victimDelegate",   bootstrapManager);

        addStrategyManagerToPool(attackerPoolManager, bootstrapManager);
        addStrategyManagerToPool(victimPoolManager,   noBootstrapManager);

        openPool(attackerPoolManager);
        openPool(victimPoolManager);

        deposit(attackerPool, attackerLp, 2 * attackerDeposit);

        fundStrategyManager(attackerPoolManager, noBootstrapManager, attackerDeposit);
        fundStrategyManager(attackerPoolManager, bootstrapManager,   attackerDeposit);
    }

    function test_redemptionInflation_underpricedMint() external {

        assertStrategyManager({
            strategyManager:       noBootstrapManager,
            totalShares:           attackerDeposit,
            totalPendingShares:    0,
            assetsUnderManagement: attackerDeposit,
            availableToWithdraw:   attackerDeposit,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       bootstrapManager,
            totalShares:           attackerDeposit + bootstrapMint,
            totalPendingShares:    0,
            assetsUnderManagement: attackerDeposit + bootstrapMint,
            availableToWithdraw:   attackerDeposit + bootstrapMint,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  noBootstrapManager,
            poolManager:      attackerPoolManager,
            assets:           attackerDeposit,
            shares:           attackerDeposit,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  bootstrapManager,
            poolManager:      attackerPoolManager,
            assets:           attackerDeposit,
            shares:           attackerDeposit,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  bootstrapManager,
            poolManager:      address(0),
            assets:           bootstrapMint,
            shares:           bootstrapMint,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Both strategies are impaired                                                                                               ***/
        /**********************************************************************************************************************************/

        vm.prank(delegateA);
        IAllocationStrategy(noBootstrapStrategy).impair(impairment);

        vm.prank(delegateB);
        IAllocationStrategy(bootstrapStrategy).impair(impairment);

        assertStrategyManager({
            strategyManager:       noBootstrapManager,
            totalShares:           attackerDeposit,
            totalPendingShares:    0,
            assetsUnderManagement: attackerDeposit,
            availableToWithdraw:   attackerDeposit,
            unrealizedLosses:      impairment
        });

        assertStrategyManager({
            strategyManager:       bootstrapManager,
            totalShares:           attackerDeposit + bootstrapMint,
            totalPendingShares:    0,
            assetsUnderManagement: attackerDeposit + bootstrapMint,
            availableToWithdraw:   attackerDeposit + bootstrapMint,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  noBootstrapManager,
            poolManager:      attackerPoolManager,
            assets:           attackerDeposit,
            shares:           attackerDeposit,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  bootstrapManager,
            poolManager:      attackerPoolManager,
            assets:           attackerDeposit,
            shares:           attackerDeposit,
            pendingShares:    0,
            unrealizedLosses: impairment * attackerDeposit / (attackerDeposit + bootstrapMint) + roundUpError
        });

        assertStrategyManagerPosition({
            strategyManager:  bootstrapManager,
            poolManager:      address(0),
            assets:           bootstrapMint,
            shares:           bootstrapMint,
            pendingShares:    0,
            unrealizedLosses: impairment * bootstrapMint / (attackerDeposit + bootstrapMint) + roundUpError
        });

        /**********************************************************************************************************************************/
        /*** Attacker requests redemption of all but the strategy's minimum shares                                                      ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(attackerPoolManager, noBootstrapManager, attackerDeposit - 1);
        requestRedeemFromStrategyManager(attackerPoolManager, bootstrapManager,   attackerDeposit);

        assertStrategyManager({
            strategyManager:       noBootstrapManager,
            totalShares:           attackerDeposit,
            totalPendingShares:    attackerDeposit - 1,
            assetsUnderManagement: attackerDeposit,
            availableToWithdraw:   attackerDeposit,
            unrealizedLosses:      impairment
        });

        assertStrategyManager({
            strategyManager:       bootstrapManager,
            totalShares:           attackerDeposit + bootstrapMint,
            totalPendingShares:    attackerDeposit,
            assetsUnderManagement: attackerDeposit + bootstrapMint,
            availableToWithdraw:   attackerDeposit + bootstrapMint,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  noBootstrapManager,
            poolManager:      attackerPoolManager,
            assets:           attackerDeposit,
            shares:           attackerDeposit,
            pendingShares:    attackerDeposit - 1,
            unrealizedLosses: impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  bootstrapManager,
            poolManager:      attackerPoolManager,
            assets:           attackerDeposit,
            shares:           attackerDeposit,
            pendingShares:    attackerDeposit,
            unrealizedLosses: impairment * attackerDeposit / (attackerDeposit + bootstrapMint) + roundUpError
        });

        assertStrategyManagerPosition({
            strategyManager:  bootstrapManager,
            poolManager:      address(0),
            assets:           bootstrapMint,
            shares:           bootstrapMint,
            pendingShares:    0,
            unrealizedLosses: impairment * bootstrapMint / (attackerDeposit + bootstrapMint) + roundUpError
        });

        /**********************************************************************************************************************************/
        /*** Operator processes the redemptions, concentrating the share supply                                                         ***/
        /**********************************************************************************************************************************/

        processRedemptionFromStrategyManager(attackerPoolManager, noBootstrapManager, attackerDeposit - 1);
        processRedemptionFromStrategyManager(attackerPoolManager, bootstrapManager,   attackerDeposit);

        uint256 expectedAssetsOut = attackerDeposit * (attackerDeposit + bootstrapMint - impairment) / (attackerDeposit + bootstrapMint);

        assertStrategyManager({
            strategyManager:       noBootstrapManager,
            totalShares:           1,
            totalPendingShares:    0,
            assetsUnderManagement: impairment + 1,
            availableToWithdraw:   impairment + 1,
            unrealizedLosses:      impairment
        });

        assertStrategyManager({
            strategyManager:       bootstrapManager,
            totalShares:           bootstrapMint,
            totalPendingShares:    0,
            assetsUnderManagement: attackerDeposit + bootstrapMint - expectedAssetsOut,
            availableToWithdraw:   attackerDeposit + bootstrapMint - expectedAssetsOut,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  noBootstrapManager,
            poolManager:      attackerPoolManager,
            assets:           impairment + 1,
            shares:           1,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  bootstrapManager,
            poolManager:      attackerPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  bootstrapManager,
            poolManager:      address(0),
            assets:           attackerDeposit + bootstrapMint - expectedAssetsOut,
            shares:           bootstrapMint,
            pendingShares:    0,
            unrealizedLosses: impairment
        });

        /**********************************************************************************************************************************/
        /*** Victim funds the same amount, but only the strategy without a bootstrap mint underprices the mint                          ***/
        /**********************************************************************************************************************************/

        uint256 victimAssetsOf        = 625_000e6;
        uint256 sharedLossOf          = 250_000e6;
        uint256 bootstrapVictimShares = victimDeposit * bootstrapMint / (attackerDeposit + bootstrapMint - expectedAssetsOut);

        deposit(victimPool, victimLp, 2 * victimDeposit);
        fundStrategyManager(victimPoolManager, noBootstrapManager, victimDeposit);
        fundStrategyManager(victimPoolManager, bootstrapManager,   victimDeposit);

        assertStrategyManager({
            strategyManager:       noBootstrapManager,
            totalShares:           2,
            totalPendingShares:    0,
            assetsUnderManagement: impairment + victimDeposit + roundUpError,
            availableToWithdraw:   impairment + victimDeposit + roundUpError,
            unrealizedLosses:      impairment
        });

        assertStrategyManager({
            strategyManager:       bootstrapManager,
            totalShares:           bootstrapMint + bootstrapVictimShares,
            totalPendingShares:    0,
            assetsUnderManagement: attackerDeposit + bootstrapMint - expectedAssetsOut + victimDeposit,
            availableToWithdraw:   attackerDeposit + bootstrapMint - expectedAssetsOut + victimDeposit,
            unrealizedLosses:      impairment
        });

        assertStrategyManagerPosition({
            strategyManager:  noBootstrapManager,
            poolManager:      attackerPoolManager,
            assets:           victimAssetsOf,
            shares:           1,
            pendingShares:    0,
            unrealizedLosses: sharedLossOf
        });

        assertStrategyManagerPosition({
            strategyManager:  bootstrapManager,
            poolManager:      attackerPoolManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerPosition({
            strategyManager:  bootstrapManager,
            poolManager:      address(0),
            assets:           attackerDeposit + bootstrapMint - expectedAssetsOut,
            shares:           bootstrapMint,
            pendingShares:    0,
            unrealizedLosses: bootstrapMint * impairment / (bootstrapMint + bootstrapVictimShares) + roundUpError
        });

        assertStrategyManagerPosition({
            strategyManager:  noBootstrapManager,
            poolManager:      victimPoolManager,
            assets:           victimAssetsOf,
            shares:           1,
            pendingShares:    0,
            unrealizedLosses: sharedLossOf
        });

        assertStrategyManagerPosition({
            strategyManager:  bootstrapManager,
            poolManager:      victimPoolManager,
            assets:           victimDeposit - roundUpError,
            shares:           bootstrapVictimShares,
            pendingShares:    0,
            unrealizedLosses: bootstrapVictimShares * impairment / (bootstrapMint + bootstrapVictimShares) + roundUpError
        });
    }

}
