// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    ILoanManagerLike,
    IPool,
    IPoolManager,
    IProxyFactoryLike,
    IPoolPermissionManager,
    IWithdrawalManagerCyclical as IWithdrawalManager,
    IWithdrawalManagerQueue
} from "../../contracts/interfaces/Interfaces.sol";

import { TestBase, TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

contract DeployPoolTests is TestBaseWithAssertions {

    function setUp() public override {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
    }

    function test_deployPool_failWithInvalidPD() external {
        vm.expectRevert("PD:DP:INVALID_PD");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: cyclicalWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 2 days, 0, start]
        });
    }

    function test_deployPool_failWithInvalidPMFactory() external {
        vm.prank(address(governor));
        globals.setValidInstanceOf("POOL_MANAGER_FACTORY", poolManagerFactory, false);

        vm.prank(poolDelegate);
        vm.expectRevert("PD:DP:INVALID_PM_FACTORY");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: cyclicalWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 2 days, 0, start]
        });
    }

    function test_deployPool_failWithInvalidLMFactory() external {
        vm.prank(address(governor));
        globals.setValidInstanceOf("LOAN_MANAGER_FACTORY", fixedTermLoanManagerFactory, false);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:ALM:INVALID_FACTORY");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: cyclicalWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 2 days, 0, start]
        });
    }

    function test_deployPool_failWithInvalidWMCyclicalFactory() external {
        vm.prank(address(governor));
        globals.setValidInstanceOf("WITHDRAWAL_MANAGER_CYCLE_FACTORY", cyclicalWMFactory, false);

        vm.prank(poolDelegate);
        vm.expectRevert("PD:DP:INVALID_WM_FACTORY");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: cyclicalWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 2 days, 0, start]
        });
    }

    function test_deployPool_failWithZeroAsset() external {
        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: cyclicalWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(0),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 2 days, 0, start]
        });
    }

    function test_deployPool_failWithOwnedPoolManager() external {
        // Fund first pool successfully
        vm.prank(poolDelegate);
        address poolManager = deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: cyclicalWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 2 days, 0, start]
        });

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        // Fail when funding a second pool with the same Pool Delegate
        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: cyclicalWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool 2",
            symbol_:                   "MP 2",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 2 days, 0, start]
        });
    }

    function test_deployPool_failWithAssetNotAllowed() external {
        vm.prank(address(governor));
        globals.setValidPoolAsset(address(fundsAsset), false);

        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: cyclicalWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 2 days, 0, start]
        });
    }

    function test_deployPool_failWithInvalidAsset() external {
        address asset = makeAddr("asset");
        vm.prank(address(governor));
        globals.setValidPoolAsset(address(asset), true);

        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: cyclicalWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(asset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 2 days, 0, start]
        });
    }

    function test_deployPool_failWithNonZeroSupplyAndZeroMigrationAdmin() external {
        vm.prank(governor);
        globals.setMigrationAdmin(address(0));

        fundsAsset.mint(poolDelegate, 1_000_000e6);

        vm.startPrank(poolDelegate);

        fundsAsset.approve(address(deployer), 1_000_000e6);

        vm.expectRevert("MPF:CI:FAILED");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: cyclicalWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_500_000e6), 0.2e6, 1_000_000e6, 1 weeks, 2 days, 2_000_000e6, start]
        });

        vm.stopPrank();
    }

    function test_deployPool_failWithInvalidStart() external {
        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: cyclicalWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 2 days, 0, start - 1 seconds]
        });
    }

    function test_deployPool_failWithZeroWindowDuration() external {
        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: cyclicalWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 0, 0, start]
        });
    }

    function test_deployPool_failWithWindowDurationGtCycleDuration() external {
        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: cyclicalWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 1 weeks + 1 seconds, 0, start]
        });
    }

    function test_deployPool_failWithInvalidManagementFee() external {
        vm.prank(poolDelegate);
        vm.expectRevert("PM:SDMFR:OOB");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: cyclicalWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 1e6 + 1, 0, 1 weeks, 2 days, 0, start]
        });
    }

    function test_deployPool_failWithInsufficientPDApproval() external {
        vm.prank(poolDelegate);
        vm.expectRevert("PD:DP:TRANSFER_FAILED");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: cyclicalWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 1000e6, 1 weeks, 2 days, 0, start]
        });
    }

    function test_deployPool_failIfCalledPMFactoryDirectly() external {
        vm.expectRevert("PMF:CI:NOT_DEPLOYER");
        IProxyFactoryLike(poolManagerFactory).createInstance(new bytes(0), "salt");
    }

    function test_deployPool_failIfCalledWMFactoryDirectly() external {
        vm.expectRevert("WMF:CI:NOT_DEPLOYER");
        IProxyFactoryLike(cyclicalWMFactory).createInstance(new bytes(0), "salt");
    }

    function test_deployPool_successWithZeroMigrationAdmin() external {
        vm.prank(governor);
        globals.setMigrationAdmin(address(0));

        fundsAsset.mint(poolDelegate, 1_000_000e6);

        vm.startPrank(poolDelegate);

        fundsAsset.approve(address(deployer), 1_000_000e6);

        address poolManager_ = deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: cyclicalWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_500_000e6), 0.2e6, 1_000_000e6, 1 weeks, 2 days, 0, start]
        });

        vm.stopPrank();

        assertTrue(poolManager_ != address(0));
    }

    function test_deployPool_successWithInitialSupply() external {
        fundsAsset.mint(poolDelegate, 1_000_000e6);

        vm.startPrank(poolDelegate);

        fundsAsset.approve(address(deployer), 1_000_000e6);

        address poolManager_ = deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: cyclicalWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_500_000e6), 0.2e6, 1_000_000e6, 1 weeks, 2 days, 1_000_000e6, start]
        });

        vm.stopPrank();

        // Just testing that the deployment succeeded, the full assertion are made in the tests below.
        assertTrue(poolManager_ != address(0));
    }

    function test_deployPool_success_validPDSetByOA() external {
        vm.prank(operationalAdmin);
        globals.setValidPoolDelegate(poolDelegate, false);

        vm.prank(poolDelegate);
        vm.expectRevert("PD:DP:INVALID_PD");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: cyclicalWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 2 days, 0, start]
        });

        vm.prank(operationalAdmin);
        globals.setValidPoolDelegate(poolDelegate, true);

        fundsAsset.mint(poolDelegate, 1_000_000e6);

        vm.startPrank(poolDelegate);

        fundsAsset.approve(address(deployer), 1_000_000e6);

        address poolManager_ = deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: cyclicalWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_500_000e6), 0.2e6, 1_000_000e6, 1 weeks, 2 days, 1_000_000e6, start]
        });

        vm.stopPrank();

        // Just testing that the deployment succeeded, the full assertion are made in the tests below.
        assertTrue(poolManager_ != address(0));
    }

    function test_deployPool_success() external {
        fundsAsset.mint(poolDelegate, 1_000_000e6);

        vm.startPrank(poolDelegate);

        fundsAsset.approve(address(deployer), 1_000_000e6);

        address poolManager_ = deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: cyclicalWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_500_000e6), 0.2e6, 1_000_000e6, 1 weeks, 2 days, 2_000_000e6, start]
        });

        vm.stopPrank();

        IPoolManager       poolManager = IPoolManager(poolManager_);
        IPool              pool        = IPool(poolManager.pool());
        ILoanManagerLike   loanManager = ILoanManagerLike(poolManager.loanManagerList(0));
        IWithdrawalManager cyclicalWM  = IWithdrawalManager(poolManager.withdrawalManager());

        assertEq(poolManager.poolDelegate(),              poolDelegate);
        assertEq(poolManager.asset(),                     address(fundsAsset));
        assertEq(poolManager.withdrawalManager(),         address(cyclicalWM));
        assertEq(poolManager.liquidityCap(),              1_500_000e6);
        assertEq(poolManager.delegateManagementFeeRate(), 0.2e6);
        assertEq(poolManager.loanManagerList(0),          address(loanManager));

        assertTrue(poolManager.configured());
        assertTrue(poolManager.isLoanManager(address(loanManager)));
        assertTrue(poolManager.pool().code.length              > 0);
        assertTrue(poolManager.poolDelegateCover().code.length > 0);

        assertEq(pool.name(),                              "Maple Pool");
        assertEq(pool.symbol(),                            "MP");
        assertEq(pool.asset(),                             address(fundsAsset));
        assertEq(pool.manager(),                           poolManager_);
        assertEq(pool.totalSupply(),                       2_000_000e6);
        assertEq(pool.balanceOf(globals.migrationAdmin()), 2_000_000e6);

        assertEq(fundsAsset.allowance(address(pool), poolManager_),     type(uint256).max);
        assertEq(fundsAsset.balanceOf(poolManager.poolDelegateCover()), 1_000_000e6);

        assertEq(loanManager.fundsAsset(),  address(fundsAsset));
        assertEq(loanManager.poolManager(), poolManager_);

        assertEq(cyclicalWM.pool(),        address(pool));
        assertEq(cyclicalWM.poolManager(), poolManager_);

        (
            uint64 initialCycleId_,
            uint64 initialCycleTime_,
            uint64 cycleDuration_,
            uint64 windowDuration_
        ) = cyclicalWM.cycleConfigs(0);

        assertEq(initialCycleId_,   1);
        assertEq(initialCycleTime_, block.timestamp);
        assertEq(cycleDuration_,    1 weeks);
        assertEq(windowDuration_,   2 days);
    }

}

contract DeployPoolWMQueueTests is TestBase {

    function setUp() public override {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _createFactories();

        fundsAsset.mint(poolDelegate, 10e6);
    }

    function test_deployPoolWMQueue_success() external {
        vm.startPrank(poolDelegate);
        fundsAsset.approve(address(deployer), 10e6);

        address poolManager_ = deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: queueWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_000_000e6), 0.1e6, 10e6, 1_000e6]
        });

        vm.stopPrank();

        IPoolManager            poolManager          = IPoolManager(poolManager_);
        IPool                   pool                 = IPool(poolManager.pool());
        IPoolPermissionManager  ppm                  = IPoolPermissionManager(poolManager.poolPermissionManager());
        ILoanManagerLike        fixedTermLoanManager = ILoanManagerLike(poolManager.loanManagerList(0));
        ILoanManagerLike        openTermLoanManager  = ILoanManagerLike(poolManager.loanManagerList(1));
        IWithdrawalManagerQueue withdrawalManager    = IWithdrawalManagerQueue(poolManager.withdrawalManager());

        assertEq(poolManager.asset(),                 address(fundsAsset));
        assertEq(poolManager.globals(),               address(globals));
        assertEq(poolManager.poolDelegate(),          poolDelegate);
        assertEq(poolManager.poolPermissionManager(), address(ppm));
        assertEq(poolManager.withdrawalManager(),     address(withdrawalManager));

        assertEq(poolManager.delegateManagementFeeRate(), 0.1e6);
        assertEq(poolManager.liquidityCap(),              1_000_000e6);

        assertTrue(!poolManager.active());
        assertTrue(poolManager.configured());
        assertTrue(poolManager.hasSufficientCover());
        assertTrue(poolManager.isLoanManager(poolManager.loanManagerList(0)));
        assertTrue(poolManager.isLoanManager(poolManager.loanManagerList(1)));

        assertEq(pool.asset(),       address(fundsAsset));
        assertEq(pool.name(),        "Maple Pool");
        assertEq(pool.manager(),     poolManager_);
        assertEq(pool.symbol(),      "MP");
        assertEq(pool.totalSupply(), 1_000e6);

        assertEq(fundsAsset.allowance(poolDelegate, address(deployer)), 0);
        assertEq(fundsAsset.balanceOf(poolManager.poolDelegateCover()), 10e6);

        assertEq(fixedTermLoanManager.fundsAsset(),  address(fundsAsset));
        assertEq(fixedTermLoanManager.poolManager(), poolManager_);

        assertEq(openTermLoanManager.fundsAsset(),  address(fundsAsset));
        assertEq(openTermLoanManager.poolManager(), poolManager_);

        assertEq(withdrawalManager.asset(),       address(fundsAsset));
        assertEq(withdrawalManager.pool(),        address(pool));
        assertEq(withdrawalManager.poolManager(), poolManager_);
    }

    function test_deployPoolWMQueue_withoutCoverAmount() external {
        vm.prank(poolDelegate);
        address poolManager_ = deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: queueWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_000_000e6), 0.1e6, 0, 1_000e6]
        });

        assertEq(IPoolManager(poolManager_).poolDelegate(), poolDelegate);
    }

}

contract DeployPoolWMQueueFailureTests is TestBase {

    function setUp() public override {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _createFactories();
    }

    function test_deployPoolWMQueue_failIfInvalidPD() external {
        vm.expectRevert("PD:DP:INVALID_PD");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: queueWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_000_000e6), 0.1e6, 10e6, 1_000e6]
        });
    }

    function test_deployPoolWMQueue_failIfInvalidPMFactory() external {
        vm.prank(governor);
        globals.setValidInstanceOf("POOL_MANAGER_FACTORY", poolManagerFactory, false);

        vm.prank(poolDelegate);
        vm.expectRevert("PD:DP:INVALID_PM_FACTORY");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: queueWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_000_000e6), 0.1e6, 0, 1_000e6]
        });

        vm.prank(governor);
        globals.setValidInstanceOf("POOL_MANAGER_FACTORY", poolManagerFactory, true);

        vm.prank(poolDelegate);
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: queueWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_000_000e6), 0.1e6, 0, 1_000e6]
        });
    }

    function test_deployPoolWMQueue_failIfInvalidWMFactory() external {
        vm.prank(governor);
        globals.setValidInstanceOf("WITHDRAWAL_MANAGER_QUEUE_FACTORY", queueWMFactory, false);

        vm.prank(poolDelegate);
        vm.expectRevert("PD:DP:INVALID_WM_FACTORY");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: queueWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_000_000e6), 0.1e6, 0, 1_000e6]
        });

        vm.prank(governor);
        globals.setValidInstanceOf("WITHDRAWAL_MANAGER_QUEUE_FACTORY", queueWMFactory, true);

        vm.prank(poolDelegate);
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: queueWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_000_000e6), 0.1e6, 0, 1_000e6]
        });
    }

    function test_deployPoolWMQueue_failIfInvalidWMQFactory() external {
        assertTrue(globals.isInstanceOf("WITHDRAWAL_MANAGER_CYCLE_FACTORY", cyclicalWMFactory));

        vm.prank(poolDelegate);
        vm.expectRevert("PD:DP:INVALID_WM_FACTORY");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: cyclicalWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_000_000e6), 0.1e6, 0, 1_000e6]
        });
    }

    function test_deployPoolWMQueue_failIfInvalidPPM() external {
        vm.prank(governor);
        globals.setValidInstanceOf("POOL_PERMISSION_MANAGER", address(poolPermissionManager), false);

        vm.prank(poolDelegate);
        vm.expectRevert("PD:DP:INVALID_PPM");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: queueWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_000_000e6), 0.1e6, 0, 1_000e6]
        });

        vm.prank(governor);
        globals.setValidInstanceOf("POOL_PERMISSION_MANAGER", address(poolPermissionManager), true);

        vm.prank(poolDelegate);
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: queueWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_000_000e6), 0.1e6, 0, 1_000e6]
        });
    }

    function test_deployPoolWMQueue_failIfInvalidPoolAsset() external {
        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: queueWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(1),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_000_000e6), 0.1e6, 0, 1_000e6]
        });

        vm.prank(governor);
        globals.setValidPoolAsset(address(1), true);

        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: queueWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(1),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_000_000e6), 0.1e6, 0, 1_000e6]
        });
    }

    function test_deployPoolWMQueue_failIfPoolAssetNotAllowed() external {
        vm.prank(governor);
        globals.setValidPoolAsset(address(fundsAsset), false);

        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: queueWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_000_000e6), 0.1e6, 0, 1_000e6]
        });
    }

    function test_deployPoolWMQueue_failIfInsufficientApproval() external {
        fundsAsset.mint(poolDelegate, 10e6);

        vm.startPrank(poolDelegate);
        fundsAsset.approve(address(deployer), 10e4);

        vm.expectRevert("PD:DP:TRANSFER_FAILED");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: queueWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_000_000e6), 0.1e6, 10e6, 1_000e6]
        });

        vm.stopPrank();
    }

    function test_deployPoolWMQueue_failIfInsufficientAmount() external {
        fundsAsset.mint(poolDelegate, 10e4);

        vm.startPrank(poolDelegate);
        fundsAsset.approve(address(deployer), 10e4);

        vm.expectRevert("PD:DP:TRANSFER_FAILED");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: queueWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_000_000e6), 0.1e6, 10e6, 1_000e6]
        });

        vm.stopPrank();
    }

    function test_deployPoolWMQueue_failIfInvalidManagementFeeRate() external {
        vm.prank(poolDelegate);
        vm.expectRevert("PM:SDMFR:OOB");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: queueWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_000_000e6), 1e6 + 1, 0, 1_000e6]
        });
    }

    function test_deployPoolWMQueue_failIfSaltCollision() external {
        vm.prank(poolDelegate);
        address poolManager_ = deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: queueWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_000_000e6), 0.1e6, 0, 1_000e6]
        });

        assertTrue(IPoolManager(poolManager_).configured());

        vm.prank(poolDelegate);
        vm.expectRevert();
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: queueWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_000_000e6), 0.1e6, 0, 1_000e6]
        });
    }

    function test_deployPoolWMQueue_failIfAlreadyOwned() external {
        vm.prank(poolDelegate);
        address poolManager_ = deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: queueWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool 1",
            symbol_:                   "MP1",
            configParams_:             [uint256(1_000_000e6), 0.1e6, 0, 1_000e6]
        });

        vm.prank(governor);
        globals.activatePoolManager(poolManager_);

        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: queueWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool 2",
            symbol_:                   "MP2",
            configParams_:             [uint256(1_000_000e6), 0.1e6, 0, 1_000e6]
        });
    }

}
