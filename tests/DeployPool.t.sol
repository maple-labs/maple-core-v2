// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestBaseWithAssertions } from "../contracts/utilities/TestBaseWithAssertions.sol";

import { Address, console } from "../modules/contract-test-utils/contracts/test.sol";

import { IMapleProxyFactory } from "../modules/pool-v2/modules/maple-proxy-factory/contracts/interfaces/IMapleProxyFactory.sol";

contract DeployPoolFailureTests is TestBaseWithAssertions {

    function setUp() public override {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _createFactories();
    }

    function test_deployPool_failWithInvalidPD() external {
        vm.expectRevert("PD:DP:INVALID_PD");
        deployer.deployPool({
            factories_:    [poolManagerFactory,     loanManagerFactory,     withdrawalManagerFactory],
            initializers_: [poolManagerInitializer, loanManagerInitializer, withdrawalManagerInitializer],
            asset_:        address(fundsAsset),
            name_:         "Maple Pool",
            symbol_:       "MP",
            configParams_: [type(uint256).max, 0, 0, 1 weeks, 2 days, 0]
        });
    }

    function test_deployPool_failWithInvalidPMFactory() external {
        vm.prank(address(governor));
        globals.setValidFactory("POOL_MANAGER", poolManagerFactory, false);

        vm.prank(poolDelegate);
        vm.expectRevert("PD:DP:INVALID_PM_FACTORY");
        deployer.deployPool({
            factories_:    [poolManagerFactory,     loanManagerFactory,     withdrawalManagerFactory],
            initializers_: [poolManagerInitializer, loanManagerInitializer, withdrawalManagerInitializer],
            asset_:        address(fundsAsset),
            name_:         "Maple Pool",
            symbol_:       "MP",
            configParams_: [type(uint256).max, 0, 0, 1 weeks, 2 days, 0]
        });
    }

    function test_deployPool_failWithInvalidLMFactory() external {
        vm.prank(address(governor));
        globals.setValidFactory("LOAN_MANAGER", loanManagerFactory, false);

        vm.prank(poolDelegate);
        vm.expectRevert("PD:DP:INVALID_LM_FACTORY");
        deployer.deployPool({
            factories_:    [poolManagerFactory,     loanManagerFactory,     withdrawalManagerFactory],
            initializers_: [poolManagerInitializer, loanManagerInitializer, withdrawalManagerInitializer],
            asset_:        address(fundsAsset),
            name_:         "Maple Pool",
            symbol_:       "MP",
            configParams_: [type(uint256).max, 0, 0, 1 weeks, 2 days, 0]
        });
    }

    function test_deployPool_failWithInvalidWMFactory() external {
        vm.prank(address(governor));
        globals.setValidFactory("WITHDRAWAL_MANAGER", withdrawalManagerFactory, false);

        vm.prank(poolDelegate);
        vm.expectRevert("PD:DP:INVALID_WM_FACTORY");
        deployer.deployPool({
            factories_:    [poolManagerFactory,     loanManagerFactory,     withdrawalManagerFactory],
            initializers_: [poolManagerInitializer, loanManagerInitializer, withdrawalManagerInitializer],
            asset_:        address(fundsAsset),
            name_:         "Maple Pool",
            symbol_:       "MP",
            configParams_: [type(uint256).max, 0, 0, 1 weeks, 2 days, 0]
        });
    }

    function test_deployPool_failWithZeroAsset() external {
        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        deployer.deployPool({
            factories_:    [poolManagerFactory,     loanManagerFactory,     withdrawalManagerFactory],
            initializers_: [poolManagerInitializer, loanManagerInitializer, withdrawalManagerInitializer],
            asset_:        address(0),
            name_:         "Maple Pool",
            symbol_:       "MP",
            configParams_: [type(uint256).max, 0, 0, 1 weeks, 2 days, 0]
        });
    }

    function test_deployPool_failWithOwnedPoolManager() external {
        // Fund first pool successfully
        vm.prank(poolDelegate);
        ( address poolManager_, ,  ) = deployer.deployPool({
            factories_:    [poolManagerFactory,     loanManagerFactory,     withdrawalManagerFactory],
            initializers_: [poolManagerInitializer, loanManagerInitializer, withdrawalManagerInitializer],
            asset_:        address(fundsAsset),
            name_:         "Maple Pool",
            symbol_:       "MP",
            configParams_: [type(uint256).max, 0, 0, 1 weeks, 2 days, 0]
        });

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager_));

        // Fail when funding a second pool with the same Pool Delegate
        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        deployer.deployPool({
            factories_:    [poolManagerFactory,     loanManagerFactory,     withdrawalManagerFactory],
            initializers_: [poolManagerInitializer, loanManagerInitializer, withdrawalManagerInitializer],
            asset_:        address(fundsAsset),
            name_:         "Maple Pool 2",
            symbol_:       "MP 2",
            configParams_: [type(uint256).max - 1000, 0, 0, 2 weeks, 4 days, 0]
        });
    }

    function test_deployPool_failWithAssetNotAllowed() external {
        vm.prank(address(governor));
        globals.setValidPoolAsset(address(fundsAsset), false);

        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        deployer.deployPool({
            factories_:    [poolManagerFactory,     loanManagerFactory,     withdrawalManagerFactory],
            initializers_: [poolManagerInitializer, loanManagerInitializer, withdrawalManagerInitializer],
            asset_:        address(fundsAsset),
            name_:         "Maple Pool",
            symbol_:       "MP",
            configParams_: [type(uint256).max, 0, 0, 1 weeks, 2 days, 0]
        });
    }

    function test_deployPool_failWithInvalidAsset() external {
        address asset = address(new Address());
        vm.prank(address(governor));
        globals.setValidPoolAsset(address(asset), true);

        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        deployer.deployPool({
            factories_:    [poolManagerFactory,     loanManagerFactory,     withdrawalManagerFactory],
            initializers_: [poolManagerInitializer, loanManagerInitializer, withdrawalManagerInitializer],
            asset_:        address(asset),
            name_:         "Maple Pool",
            symbol_:       "MP",
            configParams_: [type(uint256).max, 0, 0, 1 weeks, 2 days, 0]
        });
    }

    function test_deployPool_failWithZeroWindowDuration() external {
        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        deployer.deployPool({
            factories_:    [poolManagerFactory,     loanManagerFactory,     withdrawalManagerFactory],
            initializers_: [poolManagerInitializer, loanManagerInitializer, withdrawalManagerInitializer],
            asset_:        address(fundsAsset),
            name_:         "Maple Pool",
            symbol_:       "MP",
            configParams_: [type(uint256).max, 0, 0, 1 weeks, 0, 0]
        });
    }

    function test_deployPool_failWithWindowDurationGtCycleDuration() external {
        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        deployer.deployPool({
            factories_:    [poolManagerFactory,     loanManagerFactory,     withdrawalManagerFactory],
            initializers_: [poolManagerInitializer, loanManagerInitializer, withdrawalManagerInitializer],
            asset_:        address(fundsAsset),
            name_:         "Maple Pool",
            symbol_:       "MP",
            configParams_: [type(uint256).max, 0, 0, 1 weeks, 1 weeks + 1, 0]
        });
    }

    function test_deployPool_failWithInvalidManagementFee() external {
        vm.prank(poolDelegate);
        vm.expectRevert("PM:CO:OOB");
        deployer.deployPool({
            factories_:    [poolManagerFactory,     loanManagerFactory,     withdrawalManagerFactory],
            initializers_: [poolManagerInitializer, loanManagerInitializer, withdrawalManagerInitializer],
            asset_:        address(fundsAsset),
            name_:         "Maple Pool",
            symbol_:       "MP",
            configParams_: [type(uint256).max, 1e6 + 1, 0, 1 weeks, 2 days, 0]
        });
    }

    function test_deployPool_failWithInsufficientPDApproval() external {
        vm.prank(poolDelegate);
        vm.expectRevert("PD:DP:TRANSFER_FAILED");
        deployer.deployPool({
            factories_:    [poolManagerFactory,     loanManagerFactory,     withdrawalManagerFactory],
            initializers_: [poolManagerInitializer, loanManagerInitializer, withdrawalManagerInitializer],
            asset_:        address(fundsAsset),
            name_:         "Maple Pool",
            symbol_:       "MP",
            configParams_: [type(uint256).max, 0, 1000e6, 1 weeks, 2 days, 0]
        });
    }

    function test_deployPool_failIfCalledPMFactoryDirectly() external {
        vm.expectRevert("PMF:CI:NOT_DEPLOYER");
        IMapleProxyFactory(poolManagerFactory).createInstance(new bytes(0), "salt");
    }

    function test_deployPool_failIfCalledLMFactoryDirectly() external {
        vm.expectRevert("LMF:CI:NOT_DEPLOYER");
        IMapleProxyFactory(loanManagerFactory).createInstance(new bytes(0), "salt");
    }

    function test_deployPool_failIfCalledWMFactoryDirectly() external {
        vm.expectRevert("WMF:CI:NOT_DEPLOYER");
        IMapleProxyFactory(withdrawalManagerFactory).createInstance(new bytes(0), "salt");
    }

}
