// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IMG as IMapleGlobals, IMPM as IMaplePoolManager } from "../../../contracts/interfaces/Interfaces.sol";

import { GovernorTimelockTestBase } from "./GovernorTimelockTestBase.t.sol";

contract MapleGlobalsFunctionsTests is GovernorTimelockTestBase {

    function test_setPendingGovernor() public {
        address newPendingGovernor = makeAddr("newPendingGovernor");

        assertEq(globals.pendingGovernor(), address(0));

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setPendingGovernor.selector,
            abi.encode(newPendingGovernor)
        );

        assertEq(globals.pendingGovernor(), newPendingGovernor);

        vm.prank(newPendingGovernor);
        globals.acceptGovernor();

        assertEq(globals.governor(),        newPendingGovernor);
        assertEq(globals.pendingGovernor(), address(0));
    }

    function test_activatePoolManager() public {
        address poolDelegate = makeAddr("newPoolDelegate");
        _executeThroughTimelock(address(globals), IMapleGlobals.setValidPoolDelegate.selector, abi.encode(poolDelegate, true));

        uint256 startTime       = block.timestamp;
        uint256 withdrawalCycle = 1;
        uint256 windowDuration  = 1;

        uint256[7] memory configParams_ = [type(uint256).max, 0, 0, withdrawalCycle, windowDuration, 1, startTime];
        address poolManager = deployPoolWithCyclical(
            poolDelegate,
            address(deployer),
            poolManagerFactory,
            cyclicalWMFactory,
            strategyFactories,
            strategyDeploymentData_,
            address(fundsAsset),
            address(poolPermissionManager),
            POOL_NAME,
            POOL_SYMBOL,
            configParams_
        );

        assertEq(globals.ownedPoolManager(poolDelegate),  address(0));
        assertEq(IMaplePoolManager(poolManager).active(), false);

        _executeThroughTimelock(address(globals), IMapleGlobals.activatePoolManager.selector, abi.encode(poolManager));

        assertEq(globals.ownedPoolManager(poolDelegate),  poolManager);
        assertEq(IMaplePoolManager(poolManager).active(), true);
    }

    function test_setBootstrapMint() public {
        address asset  = makeAddr("asset");
        uint256 amount = 100e18;

        assertEq(globals.bootstrapMint(asset), 0);

        _executeThroughTimelock(address(globals), IMapleGlobals.setBootstrapMint.selector, abi.encode(asset, amount));

        assertEq(globals.bootstrapMint(asset), amount);
    }

    function test_setDefaultTimelockParameters() public {
        uint128 newDefaultDelay    = 3;
        uint128 newDefaultDuration = 8;

        ( uint128 delay, uint128 duration ) = globals.defaultTimelockParameters();

        assertEq(delay,    1 weeks);
        assertEq(duration, 2 days);

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setDefaultTimelockParameters.selector,
            abi.encode(newDefaultDelay, newDefaultDuration)
        );

        ( delay, duration ) = globals.defaultTimelockParameters();

        assertEq(delay,    newDefaultDelay);
        assertEq(duration, newDefaultDuration);
    }

    function test_setMapleTreasury() public {
        address newMapleTreasury = makeAddr("newMapleTreasury");

        assertEq(globals.mapleTreasury(), treasury);

        _executeThroughTimelock(address(globals), IMapleGlobals.setMapleTreasury.selector, abi.encode(newMapleTreasury));

        assertEq(globals.mapleTreasury(), newMapleTreasury);
    }

    function test_setMigrationAdmin() public {
        address newMigrationAdmin = makeAddr("newMigrationAdmin");

        assertEq(globals.migrationAdmin(),    migrationAdmin);

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setMigrationAdmin.selector,
            abi.encode(newMigrationAdmin)
        );

        assertEq(globals.migrationAdmin(), newMigrationAdmin);
    }

    function test_setOperationalAdmin() public {
        address newOperationalAdmin = makeAddr("newOperationalAdmin");

        assertEq(globals.operationalAdmin(), operationalAdmin);

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setOperationalAdmin.selector,
            abi.encode(newOperationalAdmin)
        );

        assertEq(globals.operationalAdmin(), newOperationalAdmin);
    }

    function test_setPriceOracle() public {
        address asset       = makeAddr("asset");
        address newOracle   = makeAddr("newOracle");
        uint96  newMaxDelay = 100;

        ( address oracle, uint96 maxDelay ) = globals.priceOracleOf(asset);

        assertEq(oracle,   address(0));
        assertEq(maxDelay, 0);

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setPriceOracle.selector,
            abi.encode(asset, newOracle, newMaxDelay)
        );

        ( oracle, maxDelay ) = globals.priceOracleOf(asset);

        assertEq(oracle,   newOracle);
        assertEq(maxDelay, newMaxDelay);
    }

    function test_setSecurityAdmin() public {
        address newSecurityAdmin = makeAddr("newSecurityAdmin");

        assertEq(globals.securityAdmin(),    securityAdmin);

        _executeThroughTimelock(address(globals), IMapleGlobals.setSecurityAdmin.selector, abi.encode(newSecurityAdmin));

        assertEq(globals.securityAdmin(), newSecurityAdmin);
    }

    function test_setContractPause() public {
        address contractAddress = makeAddr("contract");
        bool    contractPaused  = true;

        assertEq(globals.isContractPaused(contractAddress), !contractPaused);

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setContractPause.selector,
            abi.encode(contractAddress, contractPaused)
        );

        assertEq(globals.isContractPaused(contractAddress), contractPaused);

        contractPaused = false;

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setContractPause.selector,
            abi.encode(contractAddress, contractPaused)
        );

        assertEq(globals.isContractPaused(contractAddress), contractPaused);
    }

    function test_setFunctionUnpause() public {
        address contractAddress  = makeAddr("contract");
        bytes4  sig              = bytes4(keccak256("functionUnpause(address,bytes4,bool)"));
        bool    functionUnpaused = true;

        assertEq(globals.isFunctionUnpaused(contractAddress, sig), !functionUnpaused);

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setFunctionUnpause.selector,
            abi.encode(contractAddress, sig, functionUnpaused)
        );

        assertEq(globals.isFunctionUnpaused(contractAddress, sig), functionUnpaused);

        functionUnpaused = false;

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setFunctionUnpause.selector,
            abi.encode(contractAddress, sig, functionUnpaused)
        );

        assertEq(globals.isFunctionUnpaused(contractAddress, sig), functionUnpaused);
    }

    function test_setProtocolPause() public {
        bool protocolPaused = true;

        assertEq(globals.protocolPaused(), !protocolPaused);

        _executeThroughTimelock(address(globals), IMapleGlobals.setProtocolPause.selector, abi.encode(protocolPaused));

        assertEq(globals.protocolPaused(), protocolPaused);

        protocolPaused = false;

        _executeThroughTimelock(address(globals), IMapleGlobals.setProtocolPause.selector, abi.encode(protocolPaused));

        assertEq(globals.protocolPaused(), protocolPaused);
    }

    function test_setCanDeployFrom() public {
        address factory       = makeAddr("factory");
        address account       = makeAddr("account");
        bool    canDeployFrom = true;

        assertEq(globals.canDeployFrom(factory, account), !canDeployFrom);

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setCanDeployFrom.selector,
            abi.encode(factory, account, canDeployFrom)
        );

        assertEq(globals.canDeployFrom(factory, account), canDeployFrom);

        canDeployFrom = false;

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setCanDeployFrom.selector,
            abi.encode(factory, account, canDeployFrom)
        );

        assertEq(globals.canDeployFrom(factory, account), canDeployFrom);
    }

    function test_setValidBorrower() public {
        address borrower = makeAddr("borrower");
        bool    isValid  = true;

        assertEq(globals.isBorrower(borrower), !isValid);

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setValidBorrower.selector,
            abi.encode(borrower, isValid)
        );

        assertEq(globals.isBorrower(borrower), isValid);

        isValid = false;

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setValidBorrower.selector,
            abi.encode(borrower, isValid)
        );

        assertEq(globals.isBorrower(borrower), isValid);
    }

    function test_setValidCollateralAsset() public {
        address collateralAsset = makeAddr("collateralAsset");
        bool    isValid         = true;

        assertEq(globals.isCollateralAsset(collateralAsset), !isValid);

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setValidCollateralAsset.selector,
            abi.encode(collateralAsset, isValid)
        );

        assertEq(globals.isCollateralAsset(collateralAsset), isValid);

        isValid = false;

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setValidCollateralAsset.selector,
            abi.encode(collateralAsset, isValid)
        );

        assertEq(globals.isCollateralAsset(collateralAsset), isValid);
    }

    function test_setValidInstanceOf() public {
        bytes32 instanceKey = keccak256("instanceKey");
        address instance    = makeAddr("instance");

        assertEq(globals.isInstanceOf(instanceKey, instance), false);

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setValidInstanceOf.selector,
            abi.encode(instanceKey, instance, true)
        );

        assertEq(globals.isInstanceOf(instanceKey, instance), true);

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setValidInstanceOf.selector,
            abi.encode(instanceKey, instance, false)
        );

        assertEq(globals.isInstanceOf(instanceKey, instance), false);
    }

    function test_setValidPoolAsset() public {
        address newPoolAsset = makeAddr("poolAsset");

        assertEq(globals.isPoolAsset(newPoolAsset), false);

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setValidPoolAsset.selector,
            abi.encode(newPoolAsset, true)
        );

        assertEq(globals.isPoolAsset(newPoolAsset), true);

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setValidPoolAsset.selector,
            abi.encode(newPoolAsset, false)
        );

        assertEq(globals.isPoolAsset(newPoolAsset), false);
    }

    function test_setValidPoolDelegate() public {
        address account = makeAddr("account");

        assertEq(globals.isPoolDelegate(account), false);

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setValidPoolDelegate.selector,
            abi.encode(account, true)
        );

        assertEq(globals.isPoolDelegate(account), true);

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setValidPoolDelegate.selector,
            abi.encode(account, false)
        );

        assertEq(globals.isPoolDelegate(account), false);
    }

    function test_setManualOverridePrice() public {
        address asset = makeAddr("asset");
        uint256 price = 100e18;

        assertEq(globals.manualOverridePrice(asset), 0);

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setManualOverridePrice.selector,
            abi.encode(asset, price)
        );

        assertEq(globals.manualOverridePrice(asset), price);
    }

    function test_setMaxCoverLiquidationPercent() public {
        address poolManager                = makeAddr("poolManager");
        uint256 maxCoverLiquidationPercent = 3;

        assertEq(globals.maxCoverLiquidationPercent(poolManager), 0);

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setMaxCoverLiquidationPercent.selector,
            abi.encode(poolManager, maxCoverLiquidationPercent)
        );

        assertEq(globals.maxCoverLiquidationPercent(poolManager), maxCoverLiquidationPercent);
    }

    function test_setMinCoverAmount() public {
        address poolManager    = makeAddr("poolManager");
        uint256 minCoverAmount = 100e18;

        assertEq(globals.minCoverAmount(poolManager), 0);

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setMinCoverAmount.selector,
            abi.encode(poolManager, minCoverAmount)
        );

        assertEq(globals.minCoverAmount(poolManager), minCoverAmount);
    }

    function test_setPlatformManagementFeeRate() public {
        address poolManager                  = makeAddr("poolManager");
        uint256 newPlatformManagementFeeRate = 100;

        assertEq(globals.platformManagementFeeRate(poolManager),    0);
        assertNotEq(globals.platformManagementFeeRate(poolManager), newPlatformManagementFeeRate);

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setPlatformManagementFeeRate.selector,
            abi.encode(poolManager, newPlatformManagementFeeRate)
        );

        assertEq(globals.platformManagementFeeRate(poolManager), newPlatformManagementFeeRate);
    }

    function test_setPlatformOriginationFeeRate() public {
        address poolManager                   = makeAddr("poolManager");
        uint256 newPlatformOriginationFeeRate = 100;

        assertEq(globals.platformOriginationFeeRate(poolManager),    0);
        assertNotEq(globals.platformOriginationFeeRate(poolManager), newPlatformOriginationFeeRate);

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setPlatformOriginationFeeRate.selector,
            abi.encode(poolManager, newPlatformOriginationFeeRate)
        );

        assertEq(globals.platformOriginationFeeRate(poolManager), newPlatformOriginationFeeRate);
    }

    function test_setPlatformServiceFeeRate() public {
        address poolManager               = makeAddr("poolManager");
        uint256 newPlatformServiceFeeRate = 100;

        assertEq(globals.platformServiceFeeRate(poolManager),    0);
        assertNotEq(globals.platformServiceFeeRate(poolManager), newPlatformServiceFeeRate);

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setPlatformServiceFeeRate.selector,
            abi.encode(poolManager, newPlatformServiceFeeRate)
        );

        assertEq(globals.platformServiceFeeRate(poolManager), newPlatformServiceFeeRate);
    }

    function test_setTimelockWindow() public {
        address contractAddress = makeAddr("contract");
        bytes32 functionId      = keccak256("functionId");
        uint128 newDelay        = 100;
        uint128 newDuration     = 200;

        ( uint128 delay, uint128 duration ) = globals.timelockParametersOf(contractAddress, functionId);

        assertEq(delay,    0);
        assertEq(duration, 0);

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setTimelockWindow.selector,
            abi.encode(contractAddress, functionId, newDelay, newDuration)
        );

        ( delay, duration ) = globals.timelockParametersOf(contractAddress, functionId);

        assertEq(delay,    newDelay);
        assertEq(duration, newDuration);
    }

    function test_setTimelockWindows() public {
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
            ( uint128 delay, uint128 duration ) = globals.timelockParametersOf(contractAddress, functionIds[i]);

            assertNotEq(delay,    delays[i]);
            assertNotEq(duration, durations[i]);
        }

        _executeThroughTimelock(
            address(globals),
            IMapleGlobals.setTimelockWindows.selector,
            abi.encode(contractAddress, functionIds, delays, durations)
        );

        for (uint256 i = 0; i < functionIds.length; i++) {
            ( uint128 delay, uint128 duration ) = globals.timelockParametersOf(contractAddress, functionIds[i]);

            assertEq(delay,    delays[i]);
            assertEq(duration, durations[i]);
        }
    }

    function test_unscheduleCall() public {
        address contractAddress = makeAddr("randomContract");
        bytes32 functionId      = keccak256("functionId");
        bytes memory data       = abi.encode("");

        vm.prank(securityAdmin);
        globals.scheduleCall(
            contractAddress,
            functionId,
            data
        );

        ( uint256 callTimestamp, bytes32 callDataHash ) = globals.scheduledCalls(securityAdmin, contractAddress, functionId);

        assertEq(callTimestamp, block.timestamp);
        assertEq(callDataHash,  keccak256(abi.encode(data)));

        // Manual calculation needed as unscheduleCall is overloaded on globals
        bytes4 selector = bytes4(keccak256("unscheduleCall(address,address,bytes32,bytes)"));

        _executeThroughTimelock(
            address(globals),
            selector,
            abi.encode(securityAdmin, contractAddress, functionId, data)
        );

        ( callTimestamp, callDataHash ) = globals.scheduledCalls(securityAdmin, contractAddress, functionId);

        assertEq(callTimestamp, 0);
        assertEq(callDataHash,  0);
    }

}
