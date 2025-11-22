// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IMG as IMapleGlobals } from "../../../../contracts/interfaces/Interfaces.sol";

import { MockFactory, MockPoolManager } from "../../../mocks/Mocks.sol";

import { GovernorTimelockUpgradeTestsBase } from "./GovernorTimelockUpgradeTestsBase.t.sol";

contract MapleGlobalsFunctionsUpgradeTests is GovernorTimelockUpgradeTestsBase {

    function testFork_setPendingGovernor() public {
        address newPendingGovernor = makeAddr("newPendingGovernor");

        assertEq(IMapleGlobals(globals).pendingGovernor(), address(0));

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setPendingGovernor.selector,
            abi.encode(newPendingGovernor)
        );

        assertEq(IMapleGlobals(globals).pendingGovernor(), newPendingGovernor);

        vm.prank(newPendingGovernor);
        IMapleGlobals(globals).acceptGovernor();

        assertEq(IMapleGlobals(globals).governor(),        newPendingGovernor);
        assertEq(IMapleGlobals(globals).pendingGovernor(), address(0));
    }

    function testFork_activatePoolManager() public {
        address poolDelegate = makeAddr("newPoolDelegate");
        _executeThroughTimelock(globals, IMapleGlobals.setValidPoolDelegate.selector, abi.encode(poolDelegate, true));

        MockFactory     factory     = new MockFactory();
        MockPoolManager poolManager = new MockPoolManager(address(factory), poolDelegate);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setValidInstanceOf.selector,
            abi.encode(bytes32("POOL_MANAGER_FACTORY"), address(factory), true)
        );

        assertEq(IMapleGlobals(globals).ownedPoolManager(poolDelegate), address(0));
        assertEq(poolManager.active(),                                  false);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.activatePoolManager.selector,
            abi.encode(address(poolManager))
        );

        assertEq(IMapleGlobals(globals).ownedPoolManager(poolDelegate), address(poolManager));
        assertEq(poolManager.active(),                                  true);
    }

    function testFork_setBootstrapMint() public {
        address asset  = makeAddr("asset");
        uint256 amount = 100e18;

        assertEq(IMapleGlobals(globals).bootstrapMint(asset), 0);

        _executeThroughTimelock(globals, IMapleGlobals.setBootstrapMint.selector, abi.encode(asset, amount));

        assertEq(IMapleGlobals(globals).bootstrapMint(asset), amount);
    }

    function testFork_setDefaultTimelockParameters() public {
        uint128 newDefaultDelay    = 3;
        uint128 newDefaultDuration = 8;

        ( uint128 delay, uint128 duration ) = IMapleGlobals(globals).defaultTimelockParameters();

        assertEq(delay,    1 weeks);
        assertEq(duration, 2 days);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setDefaultTimelockParameters.selector,
            abi.encode(newDefaultDelay, newDefaultDuration)
        );

        ( delay, duration ) = IMapleGlobals(globals).defaultTimelockParameters();

        assertEq(delay,    newDefaultDelay);
        assertEq(duration, newDefaultDuration);
    }

    function testFork_setMapleTreasury() public {
        address newMapleTreasury = makeAddr("newMapleTreasury");

        assertEq(IMapleGlobals(globals).mapleTreasury(), treasury);

        _executeThroughTimelock(globals, IMapleGlobals.setMapleTreasury.selector, abi.encode(newMapleTreasury));

        assertEq(IMapleGlobals(globals).mapleTreasury(), newMapleTreasury);
    }

    function testFork_setMigrationAdmin() public {
        address newMigrationAdmin = makeAddr("newMigrationAdmin");

        assertNotEq(IMapleGlobals(globals).migrationAdmin(), newMigrationAdmin);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setMigrationAdmin.selector,
            abi.encode(newMigrationAdmin)
        );

        assertEq(IMapleGlobals(globals).migrationAdmin(), newMigrationAdmin);
    }

    function testFork_setOperationalAdmin() public {
        address newOperationalAdmin = makeAddr("newOperationalAdmin");

        assertEq(IMapleGlobals(globals).operationalAdmin(), operationalAdmin);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setOperationalAdmin.selector,
            abi.encode(newOperationalAdmin)
        );

        assertEq(IMapleGlobals(globals).operationalAdmin(), newOperationalAdmin);
    }

    function testFork_setPriceOracle() public {
        address asset       = makeAddr("asset");
        address newOracle   = makeAddr("newOracle");
        uint96  newMaxDelay = 100;

        ( address oracle, uint96 maxDelay ) = IMapleGlobals(globals).priceOracleOf(asset);

        assertEq(oracle,   address(0));
        assertEq(maxDelay, 0);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setPriceOracle.selector,
            abi.encode(asset, newOracle, newMaxDelay)
        );

        ( oracle, maxDelay ) = IMapleGlobals(globals).priceOracleOf(asset);

        assertEq(oracle,   newOracle);
        assertEq(maxDelay, newMaxDelay);
    }

    function testFork_setSecurityAdmin() public {
        address newSecurityAdmin = makeAddr("newSecurityAdmin");

        assertEq(IMapleGlobals(globals).securityAdmin(),    securityAdmin);

        _executeThroughTimelock(globals, IMapleGlobals.setSecurityAdmin.selector, abi.encode(newSecurityAdmin));

        assertEq(IMapleGlobals(globals).securityAdmin(), newSecurityAdmin);
    }

    function testFork_setContractPause() public {
        address contractAddress = makeAddr("contract");
        bool    contractPaused  = true;

        assertEq(IMapleGlobals(globals).isContractPaused(contractAddress), !contractPaused);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setContractPause.selector,
            abi.encode(contractAddress, contractPaused)
        );

        assertEq(IMapleGlobals(globals).isContractPaused(contractAddress), contractPaused);

        contractPaused = false;

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setContractPause.selector,
            abi.encode(contractAddress, contractPaused)
        );

        assertEq(IMapleGlobals(globals).isContractPaused(contractAddress), contractPaused);
    }

    function testFork_setFunctionUnpause() public {
        address contractAddress  = makeAddr("contract");
        bytes4  sig              = bytes4(keccak256("functionUnpause(address,bytes4,bool)"));
        bool    functionUnpaused = true;

        assertEq(IMapleGlobals(globals).isFunctionUnpaused(contractAddress, sig), !functionUnpaused);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setFunctionUnpause.selector,
            abi.encode(contractAddress, sig, functionUnpaused)
        );

        assertEq(IMapleGlobals(globals).isFunctionUnpaused(contractAddress, sig), functionUnpaused);

        functionUnpaused = false;

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setFunctionUnpause.selector,
            abi.encode(contractAddress, sig, functionUnpaused)
        );

        assertEq(IMapleGlobals(globals).isFunctionUnpaused(contractAddress, sig), functionUnpaused);
    }

    function testFork_setProtocolPause() public {
        bool protocolPaused = true;

        assertEq(IMapleGlobals(globals).protocolPaused(), !protocolPaused);

        _executeThroughTimelock(globals, IMapleGlobals.setProtocolPause.selector, abi.encode(protocolPaused));

        assertEq(IMapleGlobals(globals).protocolPaused(), protocolPaused);

        protocolPaused = false;

        _executeThroughTimelock(globals, IMapleGlobals.setProtocolPause.selector, abi.encode(protocolPaused));

        assertEq(IMapleGlobals(globals).protocolPaused(), protocolPaused);
    }

    function testFork_setCanDeployFrom() public {
        address factory       = makeAddr("factory");
        address account       = makeAddr("account");
        bool    canDeployFrom = true;

        assertEq(IMapleGlobals(globals).canDeployFrom(factory, account), !canDeployFrom);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setCanDeployFrom.selector,
            abi.encode(factory, account, canDeployFrom)
        );

        assertEq(IMapleGlobals(globals).canDeployFrom(factory, account), canDeployFrom);

        canDeployFrom = false;

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setCanDeployFrom.selector,
            abi.encode(factory, account, canDeployFrom)
        );

        assertEq(IMapleGlobals(globals).canDeployFrom(factory, account), canDeployFrom);
    }

    function testFork_setValidBorrower() public {
        address borrower = makeAddr("borrower");
        bool    isValid  = true;

        assertEq(IMapleGlobals(globals).isBorrower(borrower), !isValid);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setValidBorrower.selector,
            abi.encode(borrower, isValid)
        );

        assertEq(IMapleGlobals(globals).isBorrower(borrower), isValid);

        isValid = false;

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setValidBorrower.selector,
            abi.encode(borrower, isValid)
        );

        assertEq(IMapleGlobals(globals).isBorrower(borrower), isValid);
    }

    function testFork_setValidCollateralAsset() public {
        address collateralAsset = makeAddr("collateralAsset");
        bool    isValid         = true;

        assertEq(IMapleGlobals(globals).isCollateralAsset(collateralAsset), !isValid);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setValidCollateralAsset.selector,
            abi.encode(collateralAsset, isValid)
        );

        assertEq(IMapleGlobals(globals).isCollateralAsset(collateralAsset), isValid);

        isValid = false;

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setValidCollateralAsset.selector,
            abi.encode(collateralAsset, isValid)
        );

        assertEq(IMapleGlobals(globals).isCollateralAsset(collateralAsset), isValid);
    }

    function testFork_setValidInstanceOf() public {
        bytes32 instanceKey = keccak256("instanceKey");
        address instance    = makeAddr("instance");

        assertEq(IMapleGlobals(globals).isInstanceOf(instanceKey, instance), false);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setValidInstanceOf.selector,
            abi.encode(instanceKey, instance, true)
        );

        assertEq(IMapleGlobals(globals).isInstanceOf(instanceKey, instance), true);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setValidInstanceOf.selector,
            abi.encode(instanceKey, instance, false)
        );

        assertEq(IMapleGlobals(globals).isInstanceOf(instanceKey, instance), false);
    }

    function testFork_setValidPoolAsset() public {
        address newPoolAsset = makeAddr("poolAsset");

        assertEq(IMapleGlobals(globals).isPoolAsset(newPoolAsset), false);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setValidPoolAsset.selector,
            abi.encode(newPoolAsset, true)
        );

        assertEq(IMapleGlobals(globals).isPoolAsset(newPoolAsset), true);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setValidPoolAsset.selector,
            abi.encode(newPoolAsset, false)
        );

        assertEq(IMapleGlobals(globals).isPoolAsset(newPoolAsset), false);
    }

    function testFork_setValidPoolDelegate() public {
        address account = makeAddr("account");

        assertEq(IMapleGlobals(globals).isPoolDelegate(account), false);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setValidPoolDelegate.selector,
            abi.encode(account, true)
        );

        assertEq(IMapleGlobals(globals).isPoolDelegate(account), true);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setValidPoolDelegate.selector,
            abi.encode(account, false)
        );

        assertEq(IMapleGlobals(globals).isPoolDelegate(account), false);
    }

    function testFork_setManualOverridePrice() public {
        address asset = makeAddr("asset");
        uint256 price = 100e18;

        assertEq(IMapleGlobals(globals).manualOverridePrice(asset), 0);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setManualOverridePrice.selector,
            abi.encode(asset, price)
        );

        assertEq(IMapleGlobals(globals).manualOverridePrice(asset), price);
    }

    function testFork_setMaxCoverLiquidationPercent() public {
        address poolManager                = makeAddr("poolManager");
        uint256 maxCoverLiquidationPercent = 3;

        assertEq(IMapleGlobals(globals).maxCoverLiquidationPercent(poolManager), 0);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setMaxCoverLiquidationPercent.selector,
            abi.encode(poolManager, maxCoverLiquidationPercent)
        );

        assertEq(IMapleGlobals(globals).maxCoverLiquidationPercent(poolManager), maxCoverLiquidationPercent);
    }

    function testFork_setMinCoverAmount() public {
        address poolManager    = makeAddr("poolManager");
        uint256 minCoverAmount = 100e18;

        assertEq(IMapleGlobals(globals).minCoverAmount(poolManager), 0);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setMinCoverAmount.selector,
            abi.encode(poolManager, minCoverAmount)
        );

        assertEq(IMapleGlobals(globals).minCoverAmount(poolManager), minCoverAmount);
    }

    function testFork_setPlatformManagementFeeRate() public {
        address poolManager                  = makeAddr("poolManager");
        uint256 newPlatformManagementFeeRate = 100;

        assertEq(IMapleGlobals(globals).platformManagementFeeRate(poolManager),    0);
        assertNotEq(IMapleGlobals(globals).platformManagementFeeRate(poolManager), newPlatformManagementFeeRate);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setPlatformManagementFeeRate.selector,
            abi.encode(poolManager, newPlatformManagementFeeRate)
        );

        assertEq(IMapleGlobals(globals).platformManagementFeeRate(poolManager), newPlatformManagementFeeRate);
    }

    function testFork_setPlatformOriginationFeeRate() public {
        address poolManager                   = makeAddr("poolManager");
        uint256 newPlatformOriginationFeeRate = 100;

        assertEq(IMapleGlobals(globals).platformOriginationFeeRate(poolManager),    0);
        assertNotEq(IMapleGlobals(globals).platformOriginationFeeRate(poolManager), newPlatformOriginationFeeRate);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setPlatformOriginationFeeRate.selector,
            abi.encode(poolManager, newPlatformOriginationFeeRate)
        );

        assertEq(IMapleGlobals(globals).platformOriginationFeeRate(poolManager), newPlatformOriginationFeeRate);
    }

    function testFork_setPlatformServiceFeeRate() public {
        address poolManager               = makeAddr("poolManager");
        uint256 newPlatformServiceFeeRate = 100;

        assertEq(IMapleGlobals(globals).platformServiceFeeRate(poolManager),    0);
        assertNotEq(IMapleGlobals(globals).platformServiceFeeRate(poolManager), newPlatformServiceFeeRate);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setPlatformServiceFeeRate.selector,
            abi.encode(poolManager, newPlatformServiceFeeRate)
        );

        assertEq(IMapleGlobals(globals).platformServiceFeeRate(poolManager), newPlatformServiceFeeRate);
    }

    function testFork_setTimelockWindow() public {
        address contractAddress = makeAddr("contract");
        bytes32 functionId      = keccak256("functionId");
        uint128 newDelay        = 100;
        uint128 newDuration     = 200;

        ( uint128 delay, uint128 duration ) = IMapleGlobals(globals).timelockParametersOf(contractAddress, functionId);

        assertEq(delay,    0);
        assertEq(duration, 0);

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setTimelockWindow.selector,
            abi.encode(contractAddress, functionId, newDelay, newDuration)
        );

        ( delay, duration ) = IMapleGlobals(globals).timelockParametersOf(contractAddress, functionId);

        assertEq(delay,    newDelay);
        assertEq(duration, newDuration);
    }

    function testFork_setTimelockWindows() public {
        address contractAddress      = makeAddr("contract");
        bytes32[] memory functionIds = new bytes32[](2);
        uint128[] memory delays      = new uint128[](2);
        uint128[] memory durations   = new uint128[](2);

        functionIds[0] = keccak256("functionId0");
        functionIds[1] = keccak256("functionId1");

        delays[0] = 100;
        delays[1] = 200;

        durations[0] = 300;
        durations[1] = 400;

        for (uint256 i = 0; i < functionIds.length; i++) {
            ( uint128 delay, uint128 duration ) = IMapleGlobals(globals).timelockParametersOf(contractAddress, functionIds[i]);

            assertNotEq(delay,    delays[i]);
            assertNotEq(duration, durations[i]);
        }

        _executeThroughTimelock(
            globals,
            IMapleGlobals.setTimelockWindows.selector,
            abi.encode(contractAddress, functionIds, delays, durations)
        );

        for (uint256 i = 0; i < functionIds.length; i++) {
            ( uint128 delay, uint128 duration ) = IMapleGlobals(globals).timelockParametersOf(contractAddress, functionIds[i]);

            assertEq(delay,    delays[i]);
            assertEq(duration, durations[i]);
        }
    }

    function testFork_unscheduleCall() public {
        address contractAddress = makeAddr("randomContract");
        bytes32 functionId      = keccak256("functionId");
        bytes memory data       = abi.encode("");

        vm.prank(securityAdmin);
        IMapleGlobals(globals).scheduleCall(
            contractAddress,
            functionId,
            data
        );

        ( uint256 callTimestamp, bytes32 callDataHash ) = IMapleGlobals(globals).scheduledCalls(securityAdmin, contractAddress, functionId);

        assertEq(callTimestamp, block.timestamp);
        assertEq(callDataHash,  keccak256(abi.encode(data)));

        // Manual calculation needed as unscheduleCall is overloaded on globals
        bytes4 selector = bytes4(keccak256("unscheduleCall(address,address,bytes32,bytes)"));

        _executeThroughTimelock(
            globals,
            selector,
            abi.encode(securityAdmin, contractAddress, functionId, data)
        );

        ( callTimestamp, callDataHash ) = IMapleGlobals(globals).scheduledCalls(securityAdmin, contractAddress, functionId);

        assertEq(callTimestamp, 0);
        assertEq(callDataHash,  0);
    }

}
