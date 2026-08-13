// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { Proxy } from "../../../contracts/Contracts@7.sol";

import { AllocationStrategyInitializerParams }  from "../../../contracts/interfaces/Interfaces.sol";
import { IMapleProxyFactory, IStrategyManager } from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract ActivateStrategyManagerFailureTests is TestBaseWithAssertions {

    address inactiveStrategyManager;

    function setUp() public override {
        _deployProtocol();

        AllocationStrategyInitializerParams memory params_ = AllocationStrategyInitializerParams({
            fundsAsset:              address(fundsAsset),
            strategyMetadata:        "Allocation Strategy",
            strategyDelegateFeeRate: 0,
            strategyProtocolFeeRate: 0,
            yieldCap:                type(uint256).max
        });

        vm.prank(strategyDelegate);
        ( inactiveStrategyManager, ) = strategyDeployer.deploy({
            strategyManagerFactory: strategyManagerFactory,
            strategyFactory:        allocationStrategyFactory,
            strategyLiquidityCap:   0,
            strategyDeploymentData: abi.encode(params_),
            bootstrapFundingData:   ""
        });
    }

    function test_activateStrategyManager_failIfNotGovernorOrOperationalAdmin() external {
        vm.expectRevert("MG:NOT_GOV_OR_OA");
        globals.activateStrategyManager(inactiveStrategyManager);
    }

    function test_activateStrategyManager_failIfInvalidFactory() external {
        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_MANAGER_FACTORY", strategyManagerFactory, false);

        vm.prank(governor);
        vm.expectRevert("MG:ASM:INVALID_FACTORY");
        globals.activateStrategyManager(inactiveStrategyManager);
    }

    function test_activateStrategyManager_failIfInvalidStrategyManager() external {
        address invalidStrategyManager = address(new Proxy(strategyManagerFactory, strategyManagerImplementation));

        vm.prank(governor);
        vm.expectRevert("MG:ASM:INVALID_STRATEGY_MANAGER");
        globals.activateStrategyManager(invalidStrategyManager);
    }

    function test_activateStrategyManager_failIfInvalidStrategyDelegate() external {
        vm.prank(governor);
        globals.setValidStrategyDelegate(strategyDelegate, false);

        vm.prank(governor);
        vm.expectRevert("MG:ASM:INVALID_DELEGATE");
        globals.activateStrategyManager(inactiveStrategyManager);
    }

    function test_activateStrategyManager_failIfStrategyDelegateAlreadyOwnsStrategyManager() external {
        vm.prank(governor);
        globals.activateStrategyManager(inactiveStrategyManager);

        vm.prank(governor);
        globals.setCanDeployFrom(strategyManagerFactory, address(this), true);

        address secondStrategyManager = IMapleProxyFactory(strategyManagerFactory).createInstance({
            arguments_: abi.encode(strategyDelegate),
            salt_:      keccak256("secondStrategyManager")
        });

        assertEq(IStrategyManager(secondStrategyManager).active(), false);

        vm.prank(governor);
        vm.expectRevert("MG:ASM:ALREADY_SET");
        globals.activateStrategyManager(secondStrategyManager);
    }

    function test_activateStrategyManager_failIfProtocolIsPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(governor);
        vm.expectRevert("MSM:PAUSED");
        globals.activateStrategyManager(inactiveStrategyManager);
    }

    function test_setActive_failIfNotGlobals() external {
        vm.expectRevert("MSM:SA:NOT_GLOBALS");
        IStrategyManager(inactiveStrategyManager).setActive(true);
    }

}

contract ActivateStrategyManagerTests is TestBaseWithAssertions {

    address inactiveStrategyManager;

    function setUp() public override {
        _deployProtocol();

        AllocationStrategyInitializerParams memory params_ = AllocationStrategyInitializerParams({
            fundsAsset:              address(fundsAsset),
            strategyMetadata:        "Allocation Strategy",
            strategyDelegateFeeRate: 0,
            strategyProtocolFeeRate: 0,
            yieldCap:                type(uint256).max
        });

        vm.prank(strategyDelegate);
        ( inactiveStrategyManager, ) = strategyDeployer.deploy({
            strategyManagerFactory: strategyManagerFactory,
            strategyFactory:        allocationStrategyFactory,
            strategyLiquidityCap:   0,
            strategyDeploymentData: abi.encode(params_),
            bootstrapFundingData:   ""
        });
    }

    function test_activateStrategyManager() external {
        assertEq(IStrategyManager(inactiveStrategyManager).active(), false);
        assertEq(globals.ownedStrategyManager(strategyDelegate),     address(0));

        vm.prank(governor);
        globals.activateStrategyManager(inactiveStrategyManager);

        assertEq(IStrategyManager(inactiveStrategyManager).active(), true);
        assertEq(globals.ownedStrategyManager(strategyDelegate),     inactiveStrategyManager);
    }

    function test_activateStrategyManager_asOperationalAdmin() external {
        assertEq(IStrategyManager(inactiveStrategyManager).active(), false);
        assertEq(globals.ownedStrategyManager(strategyDelegate),     address(0));

        vm.prank(operationalAdmin);
        globals.activateStrategyManager(inactiveStrategyManager);

        assertEq(IStrategyManager(inactiveStrategyManager).active(), true);
        assertEq(globals.ownedStrategyManager(strategyDelegate),     inactiveStrategyManager);
    }

}
