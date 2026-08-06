// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IMapleProxyFactory,
    IOpenTermLoanManager,
    IPoolManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { InvalidStrategyFactory } from "../../mocks/Mocks.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract AddStrategyRevertTests is TestBaseWithAssertions {

    function setUp() public override {
        _deployProtocol();

        poolManager = IPoolManager(_deployPoolWithQueue({
            poolDelegate_:              poolDelegate,
            fundsAsset_:                address(fundsAsset),
            strategyFactories_:         new address[](0),
            strategyData_:              new bytes[](0),
            name_:                      POOL_NAME,
            symbol_:                    POOL_SYMBOL,
            liquidityCap_:              type(uint256).max,
            delegateManagementFeeRate_: 0
        }));
    }

    function test_addStrategy_revert_paused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(governor);
        vm.expectRevert("PM:PAUSED");
        poolManager.addStrategy(openTermLoanManagerFactory, keccak256("openTermLoanManager"), new bytes(0));
    }

    function test_addStrategy_revert_poolManagerPaused() external {
        vm.prank(governor);
        globals.setContractPause(address(poolManager), true);

        vm.prank(governor);
        vm.expectRevert("PM:PAUSED");
        poolManager.addStrategy(openTermLoanManagerFactory, keccak256("openTermLoanManager"), new bytes(0));
    }

    function test_addStrategy_revert_notGovernorAndConfigured() external {
        vm.prank(poolDelegate);
        vm.expectRevert("PM:NOT_GOV_OR_NOT_CONFIGURED");
        poolManager.addStrategy(openTermLoanManagerFactory, keccak256("openTermLoanManager"), new bytes(0));
    }

    function test_addStrategy_revert_invalidFactory() external {
        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_FACTORY", openTermLoanManagerFactory, false);

        vm.prank(governor);
        vm.expectRevert("PM:AS:INVALID_FACTORY");
        poolManager.addStrategy(openTermLoanManagerFactory, keccak256("openTermLoanManager"), new bytes(0));
    }

    function test_addStrategy_revert_aumFailure() external {
        InvalidStrategyFactory invalidStrategyFactory_ = new InvalidStrategyFactory();

        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_FACTORY", address(invalidStrategyFactory_), true);

        vm.prank(governor);
        vm.expectRevert("PM:AS:AUM_FAILURE");
        poolManager.addStrategy(address(invalidStrategyFactory_), keccak256("invalidStrategy"), new bytes(0));
    }

    function test_addStrategy_revert_reusedSalt() external {
        bytes32 salt_ = keccak256("openTermLoanManager");

        vm.startPrank(governor);
        poolManager.addStrategy(openTermLoanManagerFactory, salt_, new bytes(0));

        vm.expectRevert();
        poolManager.addStrategy(openTermLoanManagerFactory, salt_, new bytes(0));

        vm.stopPrank();
    }

}

contract AddStrategySuccessTests is TestBaseWithAssertions {

    function setUp() public override {
        _deployProtocol();
    }

    function test_addStrategy_success_emptyPool() external {
        poolManager = IPoolManager(_deployPoolWithQueue({
            poolDelegate_:              poolDelegate,
            fundsAsset_:                address(fundsAsset),
            strategyFactories_:         new address[](0),
            strategyData_:              new bytes[](0),
            name_:                      POOL_NAME,
            symbol_:                    POOL_SYMBOL,
            liquidityCap_:              type(uint256).max,
            delegateManagementFeeRate_: 0
        }));

        assertEq(poolManager.configured(),         true);
        assertEq(poolManager.strategyListLength(), 0);

        vm.startPrank(governor);
        address firstOpenTermLoanManager_ = poolManager.addStrategy(
            openTermLoanManagerFactory,
            keccak256("firstOpenTermLoanManager"),
            new bytes(0)
        );
        address secondOpenTermLoanManager_ = poolManager.addStrategy(
            openTermLoanManagerFactory,
            keccak256("secondOpenTermLoanManager"),
            new bytes(0)
        );
        vm.stopPrank();

        assertNotEq(firstOpenTermLoanManager_, secondOpenTermLoanManager_);

        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).isInstance(firstOpenTermLoanManager_),  true);
        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).isInstance(secondOpenTermLoanManager_), true);

        assertEq(poolManager.isStrategy(firstOpenTermLoanManager_),         true);
        assertEq(poolManager.isStrategy(secondOpenTermLoanManager_),        true);
        assertEq(poolManager.isStrategyManager(firstOpenTermLoanManager_),  false);
        assertEq(poolManager.isStrategyManager(secondOpenTermLoanManager_), false);
        assertEq(poolManager.strategyCapOf(firstOpenTermLoanManager_),      0);
        assertEq(poolManager.strategyCapOf(secondOpenTermLoanManager_),     0);
        assertEq(poolManager.strategyListLength(),                          2);
        assertEq(poolManager.strategyList(0),                               firstOpenTermLoanManager_);
        assertEq(poolManager.strategyList(1),                               secondOpenTermLoanManager_);

        assertOpenTermLoanManager({
            loanManager:       firstOpenTermLoanManager_,
            accountedInterest: 0,
            accruedInterest:   0,
            domainStart:       0,
            issuanceRate:      0,
            principalOut:      0,
            unrealizedLosses:  0
        });

        assertOpenTermLoanManager({
            loanManager:       secondOpenTermLoanManager_,
            accountedInterest: 0,
            accruedInterest:   0,
            domainStart:       0,
            issuanceRate:      0,
            principalOut:      0,
            unrealizedLosses:  0
        });
    }

    function test_addStrategy_success_poolWithLegacyStrategy() external {
        address[] memory strategyFactories_ = new address[](1);
        bytes[]   memory strategyData_      = new bytes[](1);

        strategyFactories_[0] = openTermLoanManagerFactory;
        strategyData_[0]      = new bytes(0);

        poolManager = IPoolManager(_deployPoolWithQueue({
            poolDelegate_:              poolDelegate,
            fundsAsset_:                address(fundsAsset),
            strategyFactories_:         strategyFactories_,
            strategyData_:              strategyData_,
            name_:                      POOL_NAME,
            symbol_:                    POOL_SYMBOL,
            liquidityCap_:              type(uint256).max,
            delegateManagementFeeRate_: 0
        }));

        address existingOpenTermLoanManager_ = poolManager.strategyList(0);

        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).isInstance(existingOpenTermLoanManager_), true);

        assertEq(poolManager.configured(),                                    true);
        assertEq(poolManager.isStrategy(existingOpenTermLoanManager_),        true);
        assertEq(poolManager.isStrategyManager(existingOpenTermLoanManager_), false);
        assertEq(poolManager.strategyCapOf(existingOpenTermLoanManager_),     type(uint256).max);
        assertEq(poolManager.strategyListLength(),                            1);
        assertEq(poolManager.strategyList(0),                                 existingOpenTermLoanManager_);

        assertOpenTermLoanManager({
            loanManager:       existingOpenTermLoanManager_,
            accountedInterest: 0,
            accruedInterest:   0,
            domainStart:       0,
            issuanceRate:      0,
            principalOut:      0,
            unrealizedLosses:  0
        });

        vm.prank(governor);
        address openTermLoanManager_ = poolManager.addStrategy(
            openTermLoanManagerFactory,
            keccak256("openTermLoanManager"),
            new bytes(0)
        );

        assertNotEq(existingOpenTermLoanManager_, openTermLoanManager_);

        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).isInstance(existingOpenTermLoanManager_), true);
        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).isInstance(openTermLoanManager_),         true);

        assertEq(poolManager.configured(),                                    true);
        assertEq(poolManager.isStrategy(existingOpenTermLoanManager_),        true);
        assertEq(poolManager.isStrategy(openTermLoanManager_),                true);
        assertEq(poolManager.isStrategyManager(existingOpenTermLoanManager_), false);
        assertEq(poolManager.isStrategyManager(openTermLoanManager_),         false);
        assertEq(poolManager.strategyCapOf(existingOpenTermLoanManager_),     type(uint256).max);
        assertEq(poolManager.strategyCapOf(openTermLoanManager_),             0);
        assertEq(poolManager.strategyListLength(),                            2);
        assertEq(poolManager.strategyList(0),                                 existingOpenTermLoanManager_);
        assertEq(poolManager.strategyList(1),                                 openTermLoanManager_);

        assertOpenTermLoanManager({
            loanManager:       existingOpenTermLoanManager_,
            accountedInterest: 0,
            accruedInterest:   0,
            domainStart:       0,
            issuanceRate:      0,
            principalOut:      0,
            unrealizedLosses:  0
        });

        assertOpenTermLoanManager({
            loanManager:       openTermLoanManager_,
            accountedInterest: 0,
            accruedInterest:   0,
            domainStart:       0,
            issuanceRate:      0,
            principalOut:      0,
            unrealizedLosses:  0
        });
    }

    function test_addStrategy_success_poolWithStrategyManager() external {
        poolManager = IPoolManager(_deployPoolWithQueue({
            poolDelegate_:              poolDelegate,
            fundsAsset_:                address(fundsAsset),
            strategyFactories_:         new address[](0),
            strategyData_:              new bytes[](0),
            name_:                      POOL_NAME,
            symbol_:                    POOL_SYMBOL,
            liquidityCap_:              type(uint256).max,
            delegateManagementFeeRate_: 0
        }));

        ( allocationStrategyManager, ) = _deployAllocationStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        vm.prank(governor);
        poolManager.addStrategyManager(allocationStrategyManager);

        assertEq(poolManager.configured(),                                 true);
        assertEq(poolManager.isStrategy(allocationStrategyManager),        false);
        assertEq(poolManager.isStrategyManager(allocationStrategyManager), true);
        assertEq(poolManager.strategyCapOf(allocationStrategyManager),     0);
        assertEq(poolManager.strategyListLength(),                         1);
        assertEq(poolManager.strategyList(0),                              allocationStrategyManager);

        vm.prank(governor);
        address openTermLoanManager_ = poolManager.addStrategy(
            openTermLoanManagerFactory,
            keccak256("openTermLoanManager"),
            new bytes(0)
        );

        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).isInstance(openTermLoanManager_), true);

        assertEq(poolManager.configured(),                                 true);
        assertEq(poolManager.isStrategy(allocationStrategyManager),        false);
        assertEq(poolManager.isStrategy(openTermLoanManager_),             true);
        assertEq(poolManager.isStrategyManager(allocationStrategyManager), true);
        assertEq(poolManager.isStrategyManager(openTermLoanManager_),      false);
        assertEq(poolManager.strategyCapOf(allocationStrategyManager),     0);
        assertEq(poolManager.strategyCapOf(openTermLoanManager_),          0);
        assertEq(poolManager.strategyListLength(),                         2);
        assertEq(poolManager.strategyList(0),                              allocationStrategyManager);
        assertEq(poolManager.strategyList(1),                              openTermLoanManager_);

        assertOpenTermLoanManager({
            loanManager:       openTermLoanManager_,
            accountedInterest: 0,
            accruedInterest:   0,
            domainStart:       0,
            issuanceRate:      0,
            principalOut:      0,
            unrealizedLosses:  0
        });
    }

    function test_addStrategy_success_sameSaltDifferentPools() external {
        address secondPoolDelegate_ = makeAddr("secondPoolDelegate");
        bytes32 salt_               = keccak256("openTermLoanManager");

        vm.prank(governor);
        globals.setValidPoolDelegate(secondPoolDelegate_, true);

        IPoolManager firstPoolManager_ = IPoolManager(_deployPoolWithQueue({
            poolDelegate_:              poolDelegate,
            fundsAsset_:                address(fundsAsset),
            strategyFactories_:         new address[](0),
            strategyData_:              new bytes[](0),
            name_:                      POOL_NAME,
            symbol_:                    POOL_SYMBOL,
            liquidityCap_:              type(uint256).max,
            delegateManagementFeeRate_: 0
        }));

        IPoolManager secondPoolManager_ = IPoolManager(_deployPoolWithQueue({
            poolDelegate_:              secondPoolDelegate_,
            fundsAsset_:                address(fundsAsset),
            strategyFactories_:         new address[](0),
            strategyData_:              new bytes[](0),
            name_:                      POOL_NAME,
            symbol_:                    POOL_SYMBOL,
            liquidityCap_:              type(uint256).max,
            delegateManagementFeeRate_: 0
        }));

        vm.startPrank(governor);
        address firstOpenTermLoanManager_ = firstPoolManager_.addStrategy(
            openTermLoanManagerFactory,
            salt_,
            new bytes(0)
        );
        address secondOpenTermLoanManager_ = secondPoolManager_.addStrategy(
            openTermLoanManagerFactory,
            salt_,
            new bytes(0)
        );
        vm.stopPrank();

        assertNotEq(address(firstPoolManager_), address(secondPoolManager_));
        assertNotEq(firstOpenTermLoanManager_,  secondOpenTermLoanManager_);

        assertEq(firstPoolManager_.isStrategy(firstOpenTermLoanManager_),  true);
        assertEq(firstPoolManager_.isStrategy(secondOpenTermLoanManager_), false);
        assertEq(firstPoolManager_.strategyListLength(),                   1);
        assertEq(firstPoolManager_.strategyList(0),                        firstOpenTermLoanManager_);

        assertEq(secondPoolManager_.isStrategy(firstOpenTermLoanManager_),  false);
        assertEq(secondPoolManager_.isStrategy(secondOpenTermLoanManager_), true);
        assertEq(secondPoolManager_.strategyListLength(),                   1);
        assertEq(secondPoolManager_.strategyList(0),                        secondOpenTermLoanManager_);

        assertEq(IOpenTermLoanManager(firstOpenTermLoanManager_).poolManager(),  address(firstPoolManager_));
        assertEq(IOpenTermLoanManager(secondOpenTermLoanManager_).poolManager(), address(secondPoolManager_));

        assertOpenTermLoanManager({
            loanManager:       firstOpenTermLoanManager_,
            accountedInterest: 0,
            accruedInterest:   0,
            domainStart:       0,
            issuanceRate:      0,
            principalOut:      0,
            unrealizedLosses:  0
        });

        assertOpenTermLoanManager({
            loanManager:       secondOpenTermLoanManager_,
            accountedInterest: 0,
            accruedInterest:   0,
            domainStart:       0,
            issuanceRate:      0,
            principalOut:      0,
            unrealizedLosses:  0
        });
    }

    function test_addStrategy_success_governorTimelock() external {
        poolManager = IPoolManager(_deployPoolWithQueue({
            poolDelegate_:              poolDelegate,
            fundsAsset_:                address(fundsAsset),
            strategyFactories_:         new address[](0),
            strategyData_:              new bytes[](0),
            name_:                      POOL_NAME,
            symbol_:                    POOL_SYMBOL,
            liquidityCap_:              type(uint256).max,
            delegateManagementFeeRate_: 0
        }));

        _deployTimelockAndReassignGovernor();

        assertEq(poolManager.configured(), true);
        assertEq(poolManager.governor(),   address(governorTimelock));

        bytes memory callData_ = abi.encodeWithSignature(
            "addStrategy(address,bytes32,bytes)",
            openTermLoanManagerFactory,
            keccak256("openTermLoanManager"),
            new bytes(0)
        );

        uint256 proposalId_ = executeThroughTimelock({
            timelock_: address(governorTimelock),
            proposer_: governorTimelockProposer,
            executor_: operationalAdmin,
            target_:   address(poolManager),
            callData_: callData_
        });

        address openTermLoanManager_ = poolManager.strategyList(0);

        assertEmptyProposal({
            timelock:   address(governorTimelock),
            proposalId: proposalId_
        });

        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).isInstance(openTermLoanManager_), true);

        assertEq(poolManager.isStrategy(openTermLoanManager_),        true);
        assertEq(poolManager.isStrategyManager(openTermLoanManager_), false);
        assertEq(poolManager.strategyCapOf(openTermLoanManager_),     0);
        assertEq(poolManager.strategyListLength(),                    1);

        assertOpenTermLoanManager({
            loanManager:       openTermLoanManager_,
            accountedInterest: 0,
            accruedInterest:   0,
            domainStart:       0,
            issuanceRate:      0,
            principalOut:      0,
            unrealizedLosses:  0
        });
    }

}
