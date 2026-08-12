// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IStrategyManager } from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract StrategyManagerSetPendingStrategyDelegateFailureTests is TestBaseWithAssertions {

    address newStrategyDelegate = makeAddr("newStrategyDelegate");
    address unauthorizedCaller  = makeAddr("unauthorizedCaller");

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

    function test_setPendingStrategyDelegate_revert_unauthorizedCaller() external {
        vm.prank(unauthorizedCaller);
        vm.expectRevert("MSM:SPSD:NOT_OPERATIONAL_ADMIN");
        IStrategyManager(strategyManager).setPendingStrategyDelegate(newStrategyDelegate);
    }

    function test_setPendingStrategyDelegate_revert_strategyDelegate() external {
        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:SPSD:NOT_OPERATIONAL_ADMIN");
        IStrategyManager(strategyManager).setPendingStrategyDelegate(newStrategyDelegate);
    }

    function test_setPendingStrategyDelegate_revert_strategyDelegateCannotClearPendingDelegate() external {
        vm.prank(operationalAdmin);
        IStrategyManager(strategyManager).setPendingStrategyDelegate(newStrategyDelegate);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:SPSD:NOT_OPERATIONAL_ADMIN");
        IStrategyManager(strategyManager).setPendingStrategyDelegate(address(0));
    }

}

contract StrategyManagerSetPendingStrategyDelegateSuccessTests is TestBaseWithAssertions {

    address newStrategyDelegate  = makeAddr("newStrategyDelegate");
    address nextStrategyDelegate = makeAddr("nextStrategyDelegate");

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

    function test_setPendingStrategyDelegate_success_operationalAdmin() external {
        assertEq(IStrategyManager(strategyManager).strategyDelegate(),        strategyDelegate);
        assertEq(IStrategyManager(strategyManager).pendingStrategyDelegate(), address(0));
        assertEq(globals.ownedStrategyManager(strategyDelegate),              strategyManager);
        assertEq(globals.ownedStrategyManager(newStrategyDelegate),           address(0));
        assertEq(globals.isStrategyDelegate(strategyDelegate),                true);
        assertEq(globals.isStrategyDelegate(newStrategyDelegate),             false);

        vm.prank(operationalAdmin);
        IStrategyManager(strategyManager).setPendingStrategyDelegate(newStrategyDelegate);

        assertEq(IStrategyManager(strategyManager).strategyDelegate(),        strategyDelegate);
        assertEq(IStrategyManager(strategyManager).pendingStrategyDelegate(), newStrategyDelegate);
        assertEq(globals.ownedStrategyManager(strategyDelegate),              strategyManager);
        assertEq(globals.ownedStrategyManager(newStrategyDelegate),           address(0));
        assertEq(globals.isStrategyDelegate(strategyDelegate),                true);
        assertEq(globals.isStrategyDelegate(newStrategyDelegate),             false);
    }

    function test_setPendingStrategyDelegate_success_overwriteAndClear() external {
        vm.prank(operationalAdmin);
        IStrategyManager(strategyManager).setPendingStrategyDelegate(newStrategyDelegate);

        assertEq(IStrategyManager(strategyManager).strategyDelegate(),        strategyDelegate);
        assertEq(IStrategyManager(strategyManager).pendingStrategyDelegate(), newStrategyDelegate);
        assertEq(globals.ownedStrategyManager(strategyDelegate),              strategyManager);
        assertEq(globals.ownedStrategyManager(newStrategyDelegate),           address(0));
        assertEq(globals.ownedStrategyManager(nextStrategyDelegate),          address(0));

        vm.prank(operationalAdmin);
        IStrategyManager(strategyManager).setPendingStrategyDelegate(nextStrategyDelegate);

        assertEq(IStrategyManager(strategyManager).strategyDelegate(),        strategyDelegate);
        assertEq(IStrategyManager(strategyManager).pendingStrategyDelegate(), nextStrategyDelegate);
        assertEq(globals.ownedStrategyManager(strategyDelegate),              strategyManager);
        assertEq(globals.ownedStrategyManager(newStrategyDelegate),           address(0));
        assertEq(globals.ownedStrategyManager(nextStrategyDelegate),          address(0));

        vm.prank(operationalAdmin);
        IStrategyManager(strategyManager).setPendingStrategyDelegate(address(0));

        assertEq(IStrategyManager(strategyManager).strategyDelegate(),        strategyDelegate);
        assertEq(IStrategyManager(strategyManager).pendingStrategyDelegate(), address(0));
        assertEq(globals.ownedStrategyManager(strategyDelegate),              strategyManager);
        assertEq(globals.ownedStrategyManager(newStrategyDelegate),           address(0));
        assertEq(globals.ownedStrategyManager(nextStrategyDelegate),          address(0));
    }

}
