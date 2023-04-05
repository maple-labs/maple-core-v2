// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { ILoanManagerLike, IProxyFactoryLike, IPool, IPoolManager, IWithdrawalManager } from "../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

contract DeployPoolTests is TestBaseWithAssertions {

    function setUp() public override {
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
            withdrawalManagerFactory_: withdrawalManagerFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 2 days, 0]
        });
    }

    function test_deployPool_failWithInvalidPMFactory() external {
        vm.prank(address(governor));
        globals.setValidInstanceOf("POOL_MANAGER_FACTORY", poolManagerFactory, false);

        vm.prank(poolDelegate);
        vm.expectRevert("PD:DP:INVALID_PM_FACTORY");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: withdrawalManagerFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 2 days, 0]
        });
    }

    function test_deployPool_failWithInvalidLMFactory() external {
        vm.prank(address(governor));
        globals.setValidInstanceOf("LOAN_MANAGER_FACTORY", fixedTermLoanManagerFactory, false);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:ALM:INVALID_FACTORY");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: withdrawalManagerFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 2 days, 0]
        });
    }

    function test_deployPool_failWithInvalidWMFactory() external {
        vm.prank(address(governor));
        globals.setValidInstanceOf("WITHDRAWAL_MANAGER_FACTORY", withdrawalManagerFactory, false);

        vm.prank(poolDelegate);
        vm.expectRevert("PD:DP:INVALID_WM_FACTORY");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: withdrawalManagerFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 2 days, 0]
        });
    }

    function test_deployPool_failWithZeroAsset() external {
        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: withdrawalManagerFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(0),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 2 days, 0]
        });
    }

    function test_deployPool_failWithOwnedPoolManager() external {
        // Fund first pool successfully
        vm.prank(poolDelegate);
        address poolManager = deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: withdrawalManagerFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 2 days, 0]
        });

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));

        // Fail when funding a second pool with the same Pool Delegate
        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: withdrawalManagerFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            name_:                     "Maple Pool 2",
            symbol_:                   "MP 2",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 2 days, 0]
        });
    }

    function test_deployPool_failWithAssetNotAllowed() external {
        vm.prank(address(governor));
        globals.setValidPoolAsset(address(fundsAsset), false);

        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: withdrawalManagerFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 2 days, 0]
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
            withdrawalManagerFactory_: withdrawalManagerFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(asset),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 2 days, 0]
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
            withdrawalManagerFactory_: withdrawalManagerFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_500_000e6), 0.2e6, 1_000_000e6, 1 weeks, 2 days, 2_000_000e6]
        });

        vm.stopPrank();
    }

    function test_deployPool_failWithZeroWindowDuration() external {
        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: withdrawalManagerFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 0, 0]
        });
    }

    function test_deployPool_failWithWindowDurationGtCycleDuration() external {
        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: withdrawalManagerFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 1 weeks, 1 weeks + 1 seconds, 0]
        });
    }

    function test_deployPool_failWithInvalidManagementFee() external {
        vm.prank(poolDelegate);
        vm.expectRevert("PM:SDMFR:OOB");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: withdrawalManagerFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 1e6 + 1, 0, 1 weeks, 2 days, 0]
        });
    }

    function test_deployPool_failWithInsufficientPDApproval() external {
        vm.prank(poolDelegate);
        vm.expectRevert("PD:DP:TRANSFER_FAILED");
        deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: withdrawalManagerFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 1000e6, 1 weeks, 2 days, 0]
        });
    }

    function test_deployPool_failIfCalledPMFactoryDirectly() external {
        vm.expectRevert("PMF:CI:NOT_DEPLOYER");
        IProxyFactoryLike(poolManagerFactory).createInstance(new bytes(0), "salt");
    }

    function test_deployPool_failIfCalledWMFactoryDirectly() external {
        vm.expectRevert("WMF:CI:NOT_DEPLOYER");
        IProxyFactoryLike(withdrawalManagerFactory).createInstance(new bytes(0), "salt");
    }

    function test_deployPool_successWithZeroMigrationAdmin() external {
        vm.prank(governor);
        globals.setMigrationAdmin(address(0));

        fundsAsset.mint(poolDelegate, 1_000_000e6);

        vm.startPrank(poolDelegate);

        fundsAsset.approve(address(deployer), 1_000_000e6);

        address poolManager_ = deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: withdrawalManagerFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_500_000e6), 0.2e6, 1_000_000e6, 1 weeks, 2 days, 0]
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
            withdrawalManagerFactory_: withdrawalManagerFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_500_000e6), 0.2e6, 1_000_000e6, 1 weeks, 2 days, 1_000_000e6]
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
            withdrawalManagerFactory_: withdrawalManagerFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [uint256(1_500_000e6), 0.2e6, 1_000_000e6, 1 weeks, 2 days, 2_000_000e6]
        });

        vm.stopPrank();

        IPoolManager       poolManager       = IPoolManager(poolManager_);
        IPool              pool              = IPool(poolManager.pool());
        ILoanManagerLike   loanManager       = ILoanManagerLike(poolManager.loanManagerList(0));
        IWithdrawalManager withdrawalManager = IWithdrawalManager(poolManager.withdrawalManager());

        assertEq(poolManager.poolDelegate(),              poolDelegate);
        assertEq(poolManager.asset(),                     address(fundsAsset));
        assertEq(poolManager.withdrawalManager(),         address(withdrawalManager));
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

        assertEq(withdrawalManager.pool(),        address(pool));
        assertEq(withdrawalManager.poolManager(), poolManager_);

        (
            uint64 initialCycleId_,
            uint64 initialCycleTime_,
            uint64 cycleDuration_,
            uint64 windowDuration_
        ) = withdrawalManager.cycleConfigs(0);

        assertEq(initialCycleId_,   1);
        assertEq(initialCycleTime_, block.timestamp);
        assertEq(cycleDuration_,    1 weeks);
        assertEq(windowDuration_,   2 days);
    }

}
