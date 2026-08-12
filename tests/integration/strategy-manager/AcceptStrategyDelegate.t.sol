// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IStrategyManager } from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract StrategyManagerAcceptStrategyDelegateFailureTests is TestBaseWithAssertions {

    address newStrategyDelegate  = makeAddr("newStrategyDelegate");
    address unauthorizedCaller   = makeAddr("unauthorizedCaller");

    function setUp() public override {
        super.setUp();

        ( strategyManager, ) = _deployAllocationStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });
    }

    function test_acceptStrategyDelegate_revert_noPendingStrategyDelegate() external {
        vm.expectRevert("MSM:ASD:NOT_PENDING_SD");
        IStrategyManager(strategyManager).acceptStrategyDelegate();
    }

    function test_acceptStrategyDelegate_revert_notPendingStrategyDelegate() external {
        vm.prank(operationalAdmin);
        IStrategyManager(strategyManager).setPendingStrategyDelegate(newStrategyDelegate);

        vm.prank(unauthorizedCaller);
        vm.expectRevert("MSM:ASD:NOT_PENDING_SD");
        IStrategyManager(strategyManager).acceptStrategyDelegate();
    }

    function test_acceptStrategyDelegate_revert_invalidStrategyDelegate() external {
        vm.prank(operationalAdmin);
        IStrategyManager(strategyManager).setPendingStrategyDelegate(newStrategyDelegate);

        vm.prank(newStrategyDelegate);
        vm.expectRevert("MG:TOSM:NOT_STRATEGY_DELEGATE");
        IStrategyManager(strategyManager).acceptStrategyDelegate();
    }

    function test_acceptStrategyDelegate_revert_strategyDelegateAlreadyOwnsStrategyManager() external {
        _deployAllocationStrategy({
            strategyDelegate_:        newStrategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        vm.prank(operationalAdmin);
        IStrategyManager(strategyManager).setPendingStrategyDelegate(newStrategyDelegate);

        vm.prank(newStrategyDelegate);
        vm.expectRevert("MG:TOSM:ALREADY_SET");
        IStrategyManager(strategyManager).acceptStrategyDelegate();
    }

}

contract StrategyManagerAcceptStrategyDelegateSuccessTests is TestBaseWithAssertions {

    address newStrategyDelegate = makeAddr("newStrategyDelegate");

    function setUp() public override {
        super.setUp();

        ( strategyManager, ) = _deployAllocationStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });
    }

    function test_acceptStrategyDelegate_success() external {
        vm.prank(governor);
        globals.setValidStrategyDelegate(newStrategyDelegate, true);

        vm.prank(operationalAdmin);
        IStrategyManager(strategyManager).setPendingStrategyDelegate(newStrategyDelegate);

        assertEq(IStrategyManager(strategyManager).strategyDelegate(),        strategyDelegate);
        assertEq(IStrategyManager(strategyManager).pendingStrategyDelegate(), newStrategyDelegate);
        assertEq(globals.ownedStrategyManager(strategyDelegate),              strategyManager);
        assertEq(globals.ownedStrategyManager(newStrategyDelegate),           address(0));
        assertEq(globals.isStrategyDelegate(strategyDelegate),                true);
        assertEq(globals.isStrategyDelegate(newStrategyDelegate),             true);

        vm.prank(newStrategyDelegate);
        IStrategyManager(strategyManager).acceptStrategyDelegate();

        assertEq(IStrategyManager(strategyManager).strategyDelegate(),        newStrategyDelegate);
        assertEq(IStrategyManager(strategyManager).pendingStrategyDelegate(), address(0));
        assertEq(globals.ownedStrategyManager(strategyDelegate),              address(0));
        assertEq(globals.ownedStrategyManager(newStrategyDelegate),           strategyManager);
        assertEq(globals.isStrategyDelegate(strategyDelegate),                true);
        assertEq(globals.isStrategyDelegate(newStrategyDelegate),             true);
    }

}
