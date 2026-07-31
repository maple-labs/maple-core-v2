// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { Proxy } from "../../../contracts/Contracts@7.sol";
import {
    IGovernorTimelock,
    IMapleProxyFactory,
    IMockERC20,
    IPool,
    IPoolManager,
    IStrategyManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract AddStrategyManagerTestBase is TestBaseWithAssertions {

    function setUp() public virtual override {
        super.setUp();

        ( allocationStrategyManager, allocationUnderlyingStrategy ) = _deployAllocationStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });
    }

    function assertEmptyStrategyManager(address strategyManager, bool strategyManagerAdded) internal view {
        IStrategyManager strategyManagerContract = IStrategyManager(strategyManager);

        assertEq(poolManager.isStrategy(strategyManager),        false);
        assertEq(poolManager.isStrategyManager(strategyManager), strategyManagerAdded);

        assertEq(IMapleProxyFactory(strategyManagerFactory).isInstance(strategyManager), true);
        assertEq(strategyManagerContract.isAssetSupported(address(fundsAsset)),          true);

        assertEq(strategyManagerContract.totalShares(),           0);
        assertEq(strategyManagerContract.assetsUnderManagement(), 0);

        assertEq(strategyManagerContract.assetsOf(address(poolManager)), 0);
        assertEq(strategyManagerContract.sharesOf(address(poolManager)), 0);
    }

    function assertBootstrapSystemState(
        address strategyManager,
        address underlyingStrategy,
        address strategyDelegate_,
        address existingLegacyStrategy,
        uint256 bootstrapMint,
        bool    strategyManagerAdded
    )
        internal view
    {
        IStrategyManager strategyManagerContract = IStrategyManager(strategyManager);

        assertEq(poolManager.configured(),                       true);
        assertEq(poolManager.globals(),                          address(globals));
        assertEq(poolManager.pool(),                             address(pool));
        assertEq(poolManager.asset(),                            address(fundsAsset));
        assertEq(poolManager.isStrategy(strategyManager),        false);
        assertEq(poolManager.isStrategyManager(strategyManager), strategyManagerAdded);
        assertEq(poolManager.strategyCapOf(strategyManager),     0);
        assertEq(poolManager.strategyListLength(),               strategyManagerAdded ? 2 : 1);
        assertEq(poolManager.strategyList(0),                    existingLegacyStrategy);

        if (strategyManagerAdded) {
            assertEq(poolManager.strategyList(1), strategyManager);
        }

        assertEq(strategyManagerContract.active(),                               true);
        assertEq(strategyManagerContract.configured(),                           true);
        assertEq(strategyManagerContract.isAssetSupported(address(fundsAsset)),  true);
        assertEq(strategyManagerContract.poolManagerCapOf(address(poolManager)), 0);
        assertEq(strategyManagerContract.strategyDelegate(),                     strategyDelegate_);
        assertEq(strategyManagerContract.strategyLiquidityCap(),                 0);
        assertEq(strategyManagerContract.underlyingStrategy(),                   underlyingStrategy);

        assertEq(pool.totalAssets(),                  0);
        assertEq(pool.totalSupply(),                  0);
        assertEq(pool.unrealizedLosses(),             0);
        assertEq(poolManager.totalAssets(),           0);
        assertEq(poolManager.unrealizedLosses(),      0);
        assertEq(fundsAsset.balanceOf(address(pool)), 0);

        assertEq(strategyManagerContract.totalShares(),           bootstrapMint);
        assertEq(strategyManagerContract.totalPendingShares(),    0);
        assertEq(strategyManagerContract.assetsUnderManagement(), bootstrapMint);
        assertEq(strategyManagerContract.availableToWithdraw(),   bootstrapMint);
        assertEq(strategyManagerContract.unrealizedLosses(),      0);

        assertEq(strategyManagerContract.assetsOf(address(0)),                     bootstrapMint);
        assertEq(strategyManagerContract.sharesOf(address(0)),                     bootstrapMint);
        assertEq(strategyManagerContract.assetsOf(address(poolManager)),           0);
        assertEq(strategyManagerContract.sharesOf(address(poolManager)),           0);
        assertEq(strategyManagerContract.pendingSharesOf(address(poolManager)),    0);
        assertEq(strategyManagerContract.unrealizedLossesOf(address(poolManager)), 0);
    }

    function assertSharedFundedSystemState(
        address targetPool,
        address targetPoolManager,
        address fundingPool,
        address fundingPoolManager,
        address existingLegacyStrategy,
        uint256 fundAssets,
        bool    strategyManagerAdded
    )
        internal view
    {
        IPoolManager     targetPoolManagerContract  = IPoolManager(targetPoolManager);
        IPoolManager     fundingPoolManagerContract = IPoolManager(fundingPoolManager);
        IStrategyManager strategyManagerContract    = IStrategyManager(allocationStrategyManager);

        assertEq(targetPoolManagerContract.configured(),                                 true);
        assertEq(targetPoolManagerContract.globals(),                                    address(globals));
        assertEq(targetPoolManagerContract.asset(),                                      address(fundsAsset));
        assertEq(targetPoolManagerContract.isStrategy(allocationStrategyManager),        false);
        assertEq(targetPoolManagerContract.isStrategyManager(allocationStrategyManager), strategyManagerAdded);

        assertEq(targetPoolManagerContract.strategyListLength(), strategyManagerAdded ? 2 : 1);
        assertEq(targetPoolManagerContract.strategyList(0),      existingLegacyStrategy);

        assertEq(fundingPoolManagerContract.isStrategyManager(allocationStrategyManager), true);

        if (strategyManagerAdded) {
            assertEq(targetPoolManagerContract.strategyList(1), allocationStrategyManager);
        }

        assertEq(IPool(targetPool).totalAssets(),         0);
        assertEq(IPool(targetPool).totalSupply(),         0);
        assertEq(targetPoolManagerContract.totalAssets(), 0);
        assertEq(fundsAsset.balanceOf(targetPool),        0);

        assertEq(IPool(fundingPool).totalAssets(),         fundAssets);
        assertEq(IPool(fundingPool).totalSupply(),         fundAssets);
        assertEq(fundingPoolManagerContract.totalAssets(), fundAssets);
        assertEq(fundsAsset.balanceOf(fundingPool),        0);

        assertEq(strategyManagerContract.totalShares(),           fundAssets);
        assertEq(strategyManagerContract.assetsUnderManagement(), fundAssets);

        assertEq(strategyManagerContract.assetsOf(targetPoolManager), 0);
        assertEq(strategyManagerContract.sharesOf(targetPoolManager), 0);

        assertEq(strategyManagerContract.assetsOf(fundingPoolManager), fundAssets);
        assertEq(strategyManagerContract.sharesOf(fundingPoolManager), fundAssets);
    }

}

contract AddStrategyManagerRevertTests is AddStrategyManagerTestBase {

    function test_addStrategyManager_paused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(governor);
        vm.expectRevert("PM:PAUSED");
        poolManager.addStrategyManager(allocationStrategyManager);
    }

    function test_addStrategyManager_poolManagerPaused() external {
        vm.prank(governor);
        globals.setContractPause(address(poolManager), true);

        vm.prank(governor);
        vm.expectRevert("PM:PAUSED");
        poolManager.addStrategyManager(allocationStrategyManager);
    }

    function test_addStrategyManager_notGovernorAndConfigured() external {
        vm.prank(makeAddr("notGovernor"));
        vm.expectRevert("PM:NOT_GOV_OR_NOT_CONFIGURED");
        poolManager.addStrategyManager(allocationStrategyManager);
    }

    function test_addStrategyManager_alreadyStrategy() external {
        address existingStrategy = poolManager.strategyList(0);

        vm.prank(governor);
        vm.expectRevert("PM:ASM:ALREADY_STRATEGY");
        poolManager.addStrategyManager(existingStrategy);
    }

    function test_addStrategyManager_alreadyStrategyManager() external {
        vm.prank(governor);
        poolManager.addStrategyManager(allocationStrategyManager);

        vm.prank(governor);
        vm.expectRevert("PM:ASM:ALREADY_STRATEGY_MANAGER");
        poolManager.addStrategyManager(allocationStrategyManager);
    }

    function test_addStrategyManager_invalidStrategyManager_zeroAddress() external {
        vm.prank(governor);
        vm.expectRevert("PM:ASM:INVALID_STRATEGY_MANAGER");
        poolManager.addStrategyManager(address(0));
    }

    function test_addStrategyManager_invalidStrategyManager_factoryNotRegistered() external {
        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_MANAGER_FACTORY", strategyManagerFactory, false);

        vm.prank(governor);
        vm.expectRevert("PM:ASM:INVALID_STRATEGY_MANAGER");
        poolManager.addStrategyManager(allocationStrategyManager);
    }

    function test_addStrategyManager_invalidStrategyManager_invalidInstance() external {
        address invalidStrategyManager = address(new Proxy(strategyManagerFactory, strategyManagerImplementation));

        vm.prank(governor);
        vm.expectRevert("PM:ASM:INVALID_STRATEGY_MANAGER");
        poolManager.addStrategyManager(invalidStrategyManager);
    }

    function test_addStrategyManager_assetNotSupported() external {
        address otherDelegate = makeAddr("otherStrategyDelegate");
        address otherAsset    = deployMock({
            mockName: "ConfigurableMockERC20",
            data:     abi.encode("Dai", "DAI", 18)
        });

        vm.prank(governor);
        globals.setValidPoolAsset(otherAsset, true);

        // Strategy manager backed by an asset that does not match the pool's asset.
        ( address otherAssetStrategyManager, ) = _deployAllocationStrategy({
            strategyDelegate_:        otherDelegate,
            fundsAsset_:              otherAsset,
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        vm.prank(governor);
        vm.expectRevert("PM:ASM:ASSET_NOT_SUPPORTED");
        poolManager.addStrategyManager(otherAssetStrategyManager);
    }

}

contract AddStrategyManagerAllocationStrategyTests is AddStrategyManagerTestBase {

    function test_addStrategyManager_success_multipleStrategyManagers() external {
        address existingLegacyStrategy = poolManager.strategyList(0);
        address secondStrategyDelegate = makeAddr("secondStrategyDelegate");

        ( address secondStrategyManager, ) = _deployAllocationStrategy({
            strategyDelegate_:        secondStrategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        /**********************************************************************************************************************************/
        /*** Assert the configured pool manager state                                                                                   ***/
        /**********************************************************************************************************************************/

        assertEq(poolManager.strategyListLength(), 1);
        assertEq(poolManager.strategyList(0),      existingLegacyStrategy);

        assertEmptyStrategyManager({
            strategyManager:      allocationStrategyManager,
            strategyManagerAdded: false
        });

        assertEmptyStrategyManager({
            strategyManager:      secondStrategyManager,
            strategyManagerAdded: false
        });

        /**********************************************************************************************************************************/
        /*** Add the first strategy manager                                                                                    ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        poolManager.addStrategyManager(allocationStrategyManager);

        assertEq(poolManager.strategyListLength(), 2);
        assertEq(poolManager.strategyList(0),      existingLegacyStrategy);
        assertEq(poolManager.strategyList(1),      allocationStrategyManager);

        assertEmptyStrategyManager({
            strategyManager:      allocationStrategyManager,
            strategyManagerAdded: true
        });

        assertEmptyStrategyManager({
            strategyManager:      secondStrategyManager,
            strategyManagerAdded: false
        });

        /**********************************************************************************************************************************/
        /*** Add another strategy manager                                                                                      ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        poolManager.addStrategyManager(secondStrategyManager);

        assertEq(poolManager.strategyListLength(), 3);
        assertEq(poolManager.strategyList(0),      existingLegacyStrategy);
        assertEq(poolManager.strategyList(1),      allocationStrategyManager);
        assertEq(poolManager.strategyList(2),      secondStrategyManager);

        assertEmptyStrategyManager({
            strategyManager:      allocationStrategyManager,
            strategyManagerAdded: true
        });

        assertEmptyStrategyManager({
            strategyManager:      secondStrategyManager,
            strategyManagerAdded: true
        });
    }

    function test_addStrategyManager_success_previouslyRemovedStrategyManager() external {
        address existingLegacyStrategy = poolManager.strategyList(0);

        assertEq(poolManager.strategyListLength(), 1);
        assertEq(poolManager.strategyList(0),      existingLegacyStrategy);

        assertEmptyStrategyManager({
            strategyManager:      allocationStrategyManager,
            strategyManagerAdded: false
        });

        /**********************************************************************************************************************************/
        /*** Add the strategy manager                                                                                                    ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        poolManager.addStrategyManager(allocationStrategyManager);

        assertEq(poolManager.strategyListLength(), 2);
        assertEq(poolManager.strategyList(0),      existingLegacyStrategy);
        assertEq(poolManager.strategyList(1),      allocationStrategyManager);

        assertEmptyStrategyManager({
            strategyManager:      allocationStrategyManager,
            strategyManagerAdded: true
        });

        /**********************************************************************************************************************************/
        /*** Remove the strategy manager                                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        poolManager.removeStrategyManager(allocationStrategyManager);

        assertEq(poolManager.strategyListLength(), 1);
        assertEq(poolManager.strategyList(0),      existingLegacyStrategy);

        assertEmptyStrategyManager({
            strategyManager:      allocationStrategyManager,
            strategyManagerAdded: false
        });

        /**********************************************************************************************************************************/
        /*** Re-add the strategy manager                                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        poolManager.addStrategyManager(allocationStrategyManager);

        assertEq(poolManager.strategyListLength(), 2);
        assertEq(poolManager.strategyList(0),      existingLegacyStrategy);
        assertEq(poolManager.strategyList(1),      allocationStrategyManager);

        assertEmptyStrategyManager({
            strategyManager:      allocationStrategyManager,
            strategyManagerAdded: true
        });
    }

    function test_addStrategyManager_success_withSharedFundedStrategyManager() external {
        address targetPool        = address(pool);
        address targetPoolManager = address(poolManager);

        uint256 fundAssets = 100_000e6;

        address existingLegacyStrategy = IPoolManager(targetPoolManager).strategyList(0);
        address liquidityProvider      = makeAddr("liquidityProvider");

        ( address fundingPool, address fundingPoolManager ) = _createPoolSharingStrategy({
            delegateLabel_:   "fundingPoolDelegate",
            strategyManager_: allocationStrategyManager
        });

        vm.prank(strategyDelegate);
        IStrategyManager(allocationStrategyManager).setStrategyLiquidityCap(type(uint256).max);

        deposit({
            pool_:    fundingPool,
            account_: liquidityProvider,
            assets_:  fundAssets
        });

        fundStrategyManager({
            poolManager_:     fundingPoolManager,
            strategyManager_: allocationStrategyManager,
            assetsIn_:        fundAssets
        });

        /**********************************************************************************************************************************/
        /*** Assert the funded shared strategy manager baseline state                                                                   ***/
        /**********************************************************************************************************************************/

        assertSharedFundedSystemState({
            targetPool:             targetPool,
            targetPoolManager:      targetPoolManager,
            fundingPool:            fundingPool,
            fundingPoolManager:     fundingPoolManager,
            existingLegacyStrategy: existingLegacyStrategy,
            fundAssets:             fundAssets,
            strategyManagerAdded:   false
        });

        /**********************************************************************************************************************************/
        /*** Add the funded shared strategy manager                                                                                     ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        IPoolManager(targetPoolManager).addStrategyManager(allocationStrategyManager);

        assertSharedFundedSystemState({
            targetPool:             targetPool,
            targetPoolManager:      targetPoolManager,
            fundingPool:            fundingPool,
            fundingPoolManager:     fundingPoolManager,
            existingLegacyStrategy: existingLegacyStrategy,
            fundAssets:             fundAssets,
            strategyManagerAdded:   true
        });
    }

    function test_addStrategyManager_success_withBootstrapStrategyManager() external {
        uint256 bootstrapMint = 10e6;

        address bootstrapStrategyDelegate = makeAddr("bootstrapStrategyDelegate");
        address existingLegacyStrategy    = poolManager.strategyList(0);

        ( address bootstrapStrategyManager, address bootstrapUnderlyingStrategy ) = _deployAllocationStrategy({
            strategyDelegate_:        bootstrapStrategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           bootstrapMint
        });

        /**********************************************************************************************************************************/
        /*** Assert the bootstrap strategy manager baseline state                                                                       ***/
        /**********************************************************************************************************************************/

        assertBootstrapSystemState({
            strategyManager:        bootstrapStrategyManager,
            underlyingStrategy:     bootstrapUnderlyingStrategy,
            strategyDelegate_:      bootstrapStrategyDelegate,
            existingLegacyStrategy: existingLegacyStrategy,
            bootstrapMint:          bootstrapMint,
            strategyManagerAdded:   false
        });

        /**********************************************************************************************************************************/
        /*** Add the bootstrap strategy manager                                                                                         ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        poolManager.addStrategyManager(bootstrapStrategyManager);

        assertBootstrapSystemState({
            strategyManager:        bootstrapStrategyManager,
            underlyingStrategy:     bootstrapUnderlyingStrategy,
            strategyDelegate_:      bootstrapStrategyDelegate,
            existingLegacyStrategy: existingLegacyStrategy,
            bootstrapMint:          bootstrapMint,
            strategyManagerAdded:   true
        });
    }

}

contract AddStrategyManagerGovernorTimelockTests is AddStrategyManagerTestBase {

    function setUp() public override {
        super.setUp();

        _deployTimelockAndReassignGovernor();
    }

    function test_addStrategyManager_success_withExistingLegacyStrategy() external {
        uint256 initialProposalId      = governorTimelock.latestProposalId();
        address existingLegacyStrategy = poolManager.strategyList(0);

        IStrategyManager strategyManagerContract = IStrategyManager(allocationStrategyManager);

        address[] memory targets = new address[](1);
        bytes[]   memory data    = new bytes[](1);

        targets[0] = address(poolManager);
        data[0]    = abi.encodeWithSignature("addStrategyManager(address)", allocationStrategyManager);

        /**********************************************************************************************************************************/
        /*** Assert the configured pool manager baseline state                                                                          ***/
        /**********************************************************************************************************************************/

        assertEq(poolManager.configured(),                             true);
        assertEq(poolManager.globals(),                                address(globals));
        assertEq(poolManager.pool(),                                   address(pool));
        assertEq(poolManager.asset(),                                  address(fundsAsset));
        assertEq(poolManager.strategyCapOf(allocationStrategyManager), 0);

        assertEq(strategyManagerContract.active(),                               true);
        assertEq(strategyManagerContract.configured(),                           true);
        assertEq(strategyManagerContract.poolManagerCapOf(address(poolManager)), 0);
        assertEq(strategyManagerContract.strategyDelegate(),                     strategyDelegate);
        assertEq(strategyManagerContract.strategyLiquidityCap(),                 0);
        assertEq(strategyManagerContract.underlyingStrategy(),                   allocationUnderlyingStrategy);

        assertEmptyStrategyManager({
            strategyManager:      allocationStrategyManager,
            strategyManagerAdded: false
        });

        assertEq(poolManager.strategyListLength(), 1);
        assertEq(poolManager.strategyList(0),      existingLegacyStrategy);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        /**********************************************************************************************************************************/
        /*** Schedule the addStrategyManager proposal                                                                                   ***/
        /**********************************************************************************************************************************/

        uint32 scheduledAt = uint32(block.timestamp);

        ( uint32 delay, uint32 executionWindow ) = governorTimelock.defaultTimelockParameters();

        uint256 proposalId = scheduleProposal({
            timelock_: address(governorTimelock),
            caller_:   governorTimelockProposer,
            target_:   address(poolManager),
            callData_: data[0]
        });

        assertEq(proposalId, initialProposalId + 1);

        IGovernorTimelock.Proposal memory proposal;

        proposal.proposalHash    = keccak256(abi.encode(targets[0], data[0]));
        proposal.isUnschedulable = true;
        proposal.scheduledAt     = scheduledAt;
        proposal.delayedUntil    = scheduledAt + delay;
        proposal.validUntil      = scheduledAt + delay + executionWindow;

        assertProposal({
            timelock:   address(governorTimelock),
            proposalId: proposalId,
            proposal:   proposal
        });

        assertEq(governorTimelock.latestProposalId(),       proposalId);
        assertEq(governorTimelock.isExecutable(proposalId), false);

        assertEmptyStrategyManager({
            strategyManager:      allocationStrategyManager,
            strategyManagerAdded: false
        });

        assertEq(poolManager.strategyListLength(), 1);
        assertEq(poolManager.strategyList(0),      existingLegacyStrategy);

        /**********************************************************************************************************************************/
        /*** Advance to the proposal execution time                                                                                     ***/
        /**********************************************************************************************************************************/

        vm.warp(proposal.delayedUntil);

        assertProposal({
            timelock:   address(governorTimelock),
            proposalId: proposalId,
            proposal:   proposal
        });

        assertEq(governorTimelock.isExecutable(proposalId), true);

        assertEmptyStrategyManager({
            strategyManager:      allocationStrategyManager,
            strategyManagerAdded: false
        });

        assertEq(poolManager.strategyListLength(), 1);
        assertEq(poolManager.strategyList(0),      existingLegacyStrategy);

        /**********************************************************************************************************************************/
        /*** Execute the proposal through the governor timelock                                                                         ***/
        /**********************************************************************************************************************************/

        executeProposal({
            timelock_:   address(governorTimelock),
            caller_:     operationalAdmin,
            proposalId_: proposalId,
            target_:     address(poolManager),
            callData_:   data[0]
        });

        assertEmptyProposal({
            timelock:   address(governorTimelock),
            proposalId: proposalId
        });

        assertEq(governorTimelock.isExecutable(proposalId), false);

        assertEq(poolManager.configured(),                             true);
        assertEq(poolManager.globals(),                                address(globals));
        assertEq(poolManager.pool(),                                   address(pool));
        assertEq(poolManager.asset(),                                  address(fundsAsset));
        assertEq(poolManager.strategyCapOf(allocationStrategyManager), 0);

        assertEq(strategyManagerContract.active(),                               true);
        assertEq(strategyManagerContract.configured(),                           true);
        assertEq(strategyManagerContract.poolManagerCapOf(address(poolManager)), 0);
        assertEq(strategyManagerContract.strategyDelegate(),                     strategyDelegate);
        assertEq(strategyManagerContract.strategyLiquidityCap(),                 0);
        assertEq(strategyManagerContract.underlyingStrategy(),                   allocationUnderlyingStrategy);

        assertEmptyStrategyManager({
            strategyManager:      allocationStrategyManager,
            strategyManagerAdded: true
        });

        assertEq(poolManager.strategyListLength(), 2);
        assertEq(poolManager.strategyList(0),      existingLegacyStrategy);
        assertEq(poolManager.strategyList(1),      allocationStrategyManager);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });
    }

}

contract AddStrategyManagerForkTestBase is TestBaseWithAssertions {

    uint256 fundAssets = 100_000e6;
    uint256 forkBlock;

    address fundingPool;
    address fundingPoolManager;

    function _setUpForkedPool() internal {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), forkBlock);

        start      = block.timestamp;
        fundsAsset = IMockERC20(USDC);

        _createAccounts();
        _createGlobals();
        _configureGlobals();
        _createFactories();

        address fundingPoolDelegate = makeAddr("fundingPoolDelegate");

        vm.prank(governor);
        globals.setValidPoolDelegate(fundingPoolDelegate, true);

        ( fundingPool, fundingPoolManager, ) = _createPoolWithOTLM(fundingPoolDelegate);

        activatePool(fundingPoolManager, HUNDRED_PERCENT);

        _createPoolWithOTLM(poolDelegate);
        _configurePool();
    }

    function assertStrategyRegistration(
        IPoolManager targetPoolManager_,
        address      strategyManager_,
        address      existingLegacyStrategy_,
        bool         strategyManagerAdded_
    )
        internal view
    {
        assertEq(targetPoolManager_.isStrategy(strategyManager_),        false);
        assertEq(targetPoolManager_.isStrategyManager(strategyManager_), strategyManagerAdded_);
        assertEq(targetPoolManager_.strategyCapOf(strategyManager_),     0);
        assertEq(targetPoolManager_.strategyListLength(),                strategyManagerAdded_ ? 2 : 1);
        assertEq(targetPoolManager_.strategyList(0),                     existingLegacyStrategy_);

        if (strategyManagerAdded_) {
            assertEq(targetPoolManager_.strategyList(1), strategyManager_);
        }
    }

}

contract AddStrategyManagerAaveV3StrategyForkTests is AddStrategyManagerForkTestBase {

    function setUp() public override {
        forkBlock = AAVE_V3_FORK_BLOCK;

        _setUpForkedPool();
    }

    function test_addStrategyManager_new_withoutBootstrapMint() external {
        ( address strategyManager, ) = _deployAaveV3Strategy({
            strategyDelegate_:            strategyDelegate,
            aaveToken_:                   AAVE_USDC,
            useVirtualUnderlyingBalance_: true,
            strategyDelegateFeeRate_:     0,
            strategyProtocolFeeRate_:     0,
            strategyLiquidityCap_:        0,
            bootstrapMint_:               0
        });

        address existingLegacyStrategy = poolManager.strategyList(0);

        assertStrategyRegistration({
            targetPoolManager_:      poolManager,
            strategyManager_:        strategyManager,
            existingLegacyStrategy_: existingLegacyStrategy,
            strategyManagerAdded_:   false
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        vm.prank(governor);
        poolManager.addStrategyManager(strategyManager);

        assertStrategyRegistration({
            targetPoolManager_:      poolManager,
            strategyManager_:        strategyManager,
            existingLegacyStrategy_: existingLegacyStrategy,
            strategyManagerAdded_:   true
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      0,
            unrealizedLosses: 0
        });
    }

    function test_addStrategyManager_new_withBootstrapMint() external {
        uint256 bootstrapMint = 10e6;

        ( address strategyManager, ) = _deployAaveV3Strategy({
            strategyDelegate_:            strategyDelegate,
            aaveToken_:                   AAVE_USDC,
            useVirtualUnderlyingBalance_: true,
            strategyDelegateFeeRate_:     0,
            strategyProtocolFeeRate_:     0,
            strategyLiquidityCap_:        0,
            bootstrapMint_:               bootstrapMint
        });

        address existingLegacyStrategy = poolManager.strategyList(0);

        uint256 totalShares           = IStrategyManager(strategyManager).totalShares();
        uint256 assetsUnderManagement = IStrategyManager(strategyManager).assetsUnderManagement();
        uint256 availableToWithdraw   = IStrategyManager(strategyManager).availableToWithdraw();

        assertApproxEqAbs(assetsUnderManagement, bootstrapMint, 1);

        assertEq(IStrategyManager(strategyManager).sharesOf(address(0)), totalShares);
        assertEq(IStrategyManager(strategyManager).assetsOf(address(0)), assetsUnderManagement);

        assertStrategyRegistration({
            targetPoolManager_:      poolManager,
            strategyManager_:        strategyManager,
            existingLegacyStrategy_: existingLegacyStrategy,
            strategyManagerAdded_:   false
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        vm.prank(governor);
        poolManager.addStrategyManager(strategyManager);

        assertStrategyRegistration({
            targetPoolManager_:      poolManager,
            strategyManager_:        strategyManager,
            existingLegacyStrategy_: existingLegacyStrategy,
            strategyManagerAdded_:   true
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: assetsUnderManagement,
            availableToWithdraw:   availableToWithdraw,
            unrealizedLosses:      0
        });

        assertEq(IStrategyManager(strategyManager).sharesOf(address(0)), totalShares);
        assertEq(IStrategyManager(strategyManager).assetsOf(address(0)), assetsUnderManagement);

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      0,
            unrealizedLosses: 0
        });
    }

    function test_addStrategyManager_withAssetsFromAnotherPool() external {
        ( address strategyManager, ) = _deployAaveV3Strategy({
            strategyDelegate_:            strategyDelegate,
            aaveToken_:                   AAVE_USDC,
            useVirtualUnderlyingBalance_: true,
            strategyDelegateFeeRate_:     0,
            strategyProtocolFeeRate_:     0,
            strategyLiquidityCap_:        0,
            bootstrapMint_:               0
        });

        vm.startPrank(governor);
        IPoolManager(fundingPoolManager).addStrategyManager(strategyManager);
        IPoolManager(fundingPoolManager).setStrategyCap(strategyManager, type(uint256).max);
        vm.stopPrank();

        vm.prank(strategyDelegate);
        IStrategyManager(strategyManager).setStrategyLiquidityCap(type(uint256).max);

        deposit({
            pool_:    fundingPool,
            account_: makeAddr("fundingLiquidityProvider"),
            assets_:  fundAssets
        });

        fundStrategyManager({
            poolManager_:     fundingPoolManager,
            strategyManager_: strategyManager,
            assetsIn_:        fundAssets
        });

        address existingLegacyStrategy = poolManager.strategyList(0);

        uint256 totalShares           = IStrategyManager(strategyManager).totalShares();
        uint256 assetsUnderManagement = IStrategyManager(strategyManager).assetsUnderManagement();
        uint256 availableToWithdraw   = IStrategyManager(strategyManager).availableToWithdraw();

        // Aave supply rounding leaves assets under management 1 unit shy of the funded assets.
        assertApproxEqAbs(assetsUnderManagement, fundAssets, 1);

        assertStrategyRegistration({
            targetPoolManager_:      poolManager,
            strategyManager_:        strategyManager,
            existingLegacyStrategy_: existingLegacyStrategy,
            strategyManagerAdded_:   false
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        vm.prank(governor);
        poolManager.addStrategyManager(strategyManager);

        assertStrategyRegistration({
            targetPoolManager_:      poolManager,
            strategyManager_:        strategyManager,
            existingLegacyStrategy_: existingLegacyStrategy,
            strategyManagerAdded_:   true
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: assetsUnderManagement,
            availableToWithdraw:   availableToWithdraw,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      0,
            unrealizedLosses: 0
        });
    }

}

contract AddStrategyManagerSkyStrategyForkTests is AddStrategyManagerForkTestBase {

    function setUp() public override {
        // TODO: Consider updating the MAINNET_FORK_BLOCK to something more recent
        forkBlock = MAINNET_FORK_BLOCK;

        _setUpForkedPool();
    }

    function test_addStrategyManager_new_withoutBootstrapMint() external {
        ( address strategyManager, ) = _deploySkyStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            savingsUsds_:             SAVINGS_USDS,
            psm_:                     USDS_LITE_PSM,
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        address existingLegacyStrategy = poolManager.strategyList(0);

        assertStrategyRegistration({
            targetPoolManager_:      poolManager,
            strategyManager_:        strategyManager,
            existingLegacyStrategy_: existingLegacyStrategy,
            strategyManagerAdded_:   false
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        vm.prank(governor);
        poolManager.addStrategyManager(strategyManager);

        assertStrategyRegistration({
            targetPoolManager_:      poolManager,
            strategyManager_:        strategyManager,
            existingLegacyStrategy_: existingLegacyStrategy,
            strategyManagerAdded_:   true
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      0,
            unrealizedLosses: 0
        });
    }

    function test_addStrategyManager_new_withBootstrapMint() external {
        uint256 bootstrapMint = 10e6;

        ( address strategyManager, ) = _deploySkyStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            savingsUsds_:             SAVINGS_USDS,
            psm_:                     USDS_LITE_PSM,
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           bootstrapMint
        });

        address existingLegacyStrategy = poolManager.strategyList(0);

        // Sky PSM/sUSDS conversion rounding can leave assets under management up to 1 unit shy of the bootstrap mint.
        uint256 totalShares           = IStrategyManager(strategyManager).totalShares();
        uint256 assetsUnderManagement = IStrategyManager(strategyManager).assetsUnderManagement();
        uint256 availableToWithdraw   = IStrategyManager(strategyManager).availableToWithdraw();

        assertApproxEqAbs(assetsUnderManagement, bootstrapMint, 1);

        assertEq(IStrategyManager(strategyManager).sharesOf(address(0)), totalShares);
        assertEq(IStrategyManager(strategyManager).assetsOf(address(0)), assetsUnderManagement);

        assertStrategyRegistration({
            targetPoolManager_:      poolManager,
            strategyManager_:        strategyManager,
            existingLegacyStrategy_: existingLegacyStrategy,
            strategyManagerAdded_:   false
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        vm.prank(governor);
        poolManager.addStrategyManager(strategyManager);

        assertStrategyRegistration({
            targetPoolManager_:      poolManager,
            strategyManager_:        strategyManager,
            existingLegacyStrategy_: existingLegacyStrategy,
            strategyManagerAdded_:   true
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: assetsUnderManagement,
            availableToWithdraw:   availableToWithdraw,
            unrealizedLosses:      0
        });

        assertEq(IStrategyManager(strategyManager).sharesOf(address(0)), totalShares);
        assertEq(IStrategyManager(strategyManager).assetsOf(address(0)), assetsUnderManagement);

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      0,
            unrealizedLosses: 0
        });
    }

    function test_addStrategyManager_withAssetsFromAnotherPool() external {
        ( address strategyManager, ) = _deploySkyStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            savingsUsds_:             SAVINGS_USDS,
            psm_:                     USDS_LITE_PSM,
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        // Fund the strategy manager through the pre-created funding pool.
        vm.startPrank(governor);
        IPoolManager(fundingPoolManager).addStrategyManager(strategyManager);
        IPoolManager(fundingPoolManager).setStrategyCap(strategyManager, type(uint256).max);
        vm.stopPrank();

        vm.prank(strategyDelegate);
        IStrategyManager(strategyManager).setStrategyLiquidityCap(type(uint256).max);

        deposit({
            pool_:    fundingPool,
            account_: makeAddr("fundingLiquidityProvider"),
            assets_:  fundAssets
        });

        fundStrategyManager({
            poolManager_:     fundingPoolManager,
            strategyManager_: strategyManager,
            assetsIn_:        fundAssets
        });

        address existingLegacyStrategy = poolManager.strategyList(0);

        uint256 totalShares           = IStrategyManager(strategyManager).totalShares();
        uint256 assetsUnderManagement = IStrategyManager(strategyManager).assetsUnderManagement();
        uint256 availableToWithdraw   = IStrategyManager(strategyManager).availableToWithdraw();

        // Sky PSM/sUSDS conversion rounding leaves assets under management 1 unit shy of the funded assets.
        assertApproxEqAbs(assetsUnderManagement, fundAssets, 1);

        assertStrategyRegistration({
            targetPoolManager_:      poolManager,
            strategyManager_:        strategyManager,
            existingLegacyStrategy_: existingLegacyStrategy,
            strategyManagerAdded_:   false
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        vm.prank(governor);
        poolManager.addStrategyManager(strategyManager);

        assertStrategyRegistration({
            targetPoolManager_:      poolManager,
            strategyManager_:        strategyManager,
            existingLegacyStrategy_: existingLegacyStrategy,
            strategyManagerAdded_:   true
        });

        assertStrategyManager({
            strategyManager:       strategyManager,
            totalShares:           totalShares,
            totalPendingShares:    0,
            assetsUnderManagement: assetsUnderManagement,
            availableToWithdraw:   availableToWithdraw,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertPoolManager({
            poolManager:      address(poolManager),
            totalAssets:      0,
            unrealizedLosses: 0
        });
    }

}
