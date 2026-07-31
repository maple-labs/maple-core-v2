// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAllocationStrategy,
    IAaveV3Strategy,
    IMockERC20,
    IMapleProxyFactory,
    ISkyStrategy,
    IStrategyManager
} from "../../../contracts/interfaces/Interfaces.sol";

import {
    AllocationStrategyInitializerParams,
    AaveV3StrategyInitializerParams,
    SkyStrategyInitializerParams
} from "../../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../../TestBase.sol";

contract StrategyDeployerRevertTests is TestBase {

    bytes deploymentData;

    function setUp() public override {
        super.setUp();

        deploymentData = abi.encode(AllocationStrategyInitializerParams({
            fundsAsset:              address(fundsAsset),
            strategyMetadata:        "Allocation Strategy",
            strategyDelegateFeeRate: 0,
            strategyProtocolFeeRate: 0,
            yieldCap:                type(uint256).max
        }));
    }

    function test_deploy_revert_invalidStrategyDelegate() external {
        address notDelegate = makeAddr("notDelegate");

        vm.prank(notDelegate);
        vm.expectRevert("MSD:D:INVALID_SD");
        strategyDeployer.deploy(strategyManagerFactory, allocationStrategyFactory, 0, deploymentData, "");
    }

    function test_deploy_revert_invalidStrategyManagerFactory() external {
        address invalidStrategyManagerFactory = makeAddr("invalidStrategyManagerFactory");

        vm.prank(strategyDelegate);
        vm.expectRevert("MSD:D:INVALID_SM_FACTORY");
        strategyDeployer.deploy(invalidStrategyManagerFactory, allocationStrategyFactory, 0, deploymentData, "");
    }

    function test_deploy_revert_invalidStrategyFactory() external {
        address invalidStrategyFactory = makeAddr("invalidStrategyFactory");

        vm.prank(strategyDelegate);
        vm.expectRevert("MSD:D:INVALID_STRATEGY_FACTORY");
        strategyDeployer.deploy(strategyManagerFactory, invalidStrategyFactory, 0, deploymentData, "");
    }

    function test_deploy_revert_cannotDeployStrategyManager() external {
        vm.prank(governor);
        globals.setCanDeployFrom(strategyManagerFactory, address(strategyDeployer), false);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSMF:CI:CANNOT_DEPLOY");
        strategyDeployer.deploy(strategyManagerFactory, allocationStrategyFactory, 0, deploymentData, "");
    }

    function test_deploy_revert_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MPF:PROTOCOL_PAUSED");
        strategyDeployer.deploy(strategyManagerFactory, allocationStrategyFactory, 0, deploymentData, "");
    }

    function test_deploy_revert_strategyManagerFactoryWithoutDefaultVersion() external {
        address freshFactory = deployFromFile("Contracts@28", "StrategyManagerFactory", abi.encode(address(globals)));

        vm.startPrank(governor);
        globals.setValidInstanceOf("STRATEGY_MANAGER_FACTORY", freshFactory, true);
        globals.setCanDeployFrom(freshFactory, address(strategyDeployer), true);
        vm.stopPrank();

        vm.prank(strategyDelegate);
        vm.expectRevert(freshFactory);
        strategyDeployer.deploy(freshFactory, allocationStrategyFactory, 0, deploymentData, "");
    }

    function test_deploy_revert_duplicateDeployment() external {
        vm.prank(strategyDelegate);
        strategyDeployer.deploy(strategyManagerFactory, allocationStrategyFactory, 0, deploymentData, "");

        vm.prank(strategyDelegate);
        vm.expectRevert(strategyManagerFactory);
        strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, 0, deploymentData, "");
    }

    function test_deploy_revert_setUnderlyingStrategyPaused() external {
        ( address strategyManager, ) =
            strategyDeployer.getDeploymentAddresses(strategyDelegate, strategyManagerFactory, allocationStrategyFactory, deploymentData);

        vm.startPrank(governor);
        globals.setContractPause(strategyManager, true);
        globals.setFunctionUnpause(strategyManager, bytes4(keccak256("migrate(address,bytes)")),  true);
        vm.stopPrank();

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PAUSED");
        strategyDeployer.deploy(strategyManagerFactory, allocationStrategyFactory, 0, deploymentData, "");
    }

    function test_deploy_revert_completeConfigurationPaused() external {
        ( address strategyManager, ) =
            strategyDeployer.getDeploymentAddresses(strategyDelegate, strategyManagerFactory, allocationStrategyFactory, deploymentData);

        vm.startPrank(governor);
        globals.setContractPause(strategyManager, true);
        globals.setFunctionUnpause(strategyManager, bytes4(keccak256("migrate(address,bytes)")),         true);
        globals.setFunctionUnpause(strategyManager, bytes4(keccak256("setUnderlyingStrategy(address)")), true);
        vm.stopPrank();

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PAUSED");
        strategyDeployer.deploy(strategyManagerFactory, allocationStrategyFactory, 0, deploymentData, "");
    }

}

contract AllocationStrategyDeployTests is TestBase {

    function test_deploy_revert_cannotDeployUnderlyingStrategy() external {
        vm.prank(governor);
        globals.setCanDeployFrom(allocationStrategyFactory, address(strategyDeployer), false);

        bytes memory data = abi.encode(AllocationStrategyInitializerParams({
            fundsAsset:              address(fundsAsset),
            strategyMetadata:        "Allocation Strategy",
            strategyDelegateFeeRate: 0,
            strategyProtocolFeeRate: 0,
            yieldCap:                type(uint256).max
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MASF:CI:CANNOT_DEPLOY");
        strategyDeployer.deploy(strategyManagerFactory, allocationStrategyFactory, 0, data, "");
    }

    function test_deploy_revert_invalidAsset() external {
        bytes memory data = abi.encode(AllocationStrategyInitializerParams({
            fundsAsset:              makeAddr("notPoolAsset"),
            strategyMetadata:        "Allocation Strategy",
            strategyDelegateFeeRate: 0,
            strategyProtocolFeeRate: 0,
            yieldCap:                type(uint256).max
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        strategyDeployer.deploy(strategyManagerFactory, allocationStrategyFactory, 0, data, "");
    }

    function test_deploy_revert_invalidFeeRateSum() external {
        bytes memory data = abi.encode(AllocationStrategyInitializerParams({
            fundsAsset:              address(fundsAsset),
            strategyMetadata:        "Allocation Strategy",
            strategyDelegateFeeRate: 0.5e6,      // 50% Fee
            strategyProtocolFeeRate: 0.5e6 + 1,  // 50.0001% Fee
            yieldCap:                type(uint256).max
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        strategyDeployer.deploy(strategyManagerFactory, allocationStrategyFactory, 0, data, "");
    }

    function test_deploy_success() external {
        bytes memory data = abi.encode(AllocationStrategyInitializerParams({
            fundsAsset:              address(fundsAsset),
            strategyMetadata:        "Allocation Strategy",
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6,  // 0.2% Fee
            yieldCap:                type(uint256).max
        }));

        ( address expectedStrategyManager, address expectedUnderlyingStrategy ) =
            strategyDeployer.getDeploymentAddresses(strategyDelegate, strategyManagerFactory, allocationStrategyFactory, data);

        vm.prank(strategyDelegate);

        ( address allocationStrategyManager_, address allocationUnderlyingStrategy_ ) =
            strategyDeployer.deploy(strategyManagerFactory, allocationStrategyFactory, 0, data, "");

        assertEq(allocationStrategyManager_,    expectedStrategyManager);
        assertEq(allocationUnderlyingStrategy_, expectedUnderlyingStrategy);

        assertEq(IMapleProxyFactory(strategyManagerFactory).isInstance(allocationStrategyManager_),       true);
        assertEq(IMapleProxyFactory(allocationStrategyFactory).isInstance(allocationUnderlyingStrategy_), true);

        assertEq(IStrategyManager(allocationStrategyManager_).globals(),                 address(globals));
        assertEq(IStrategyManager(allocationStrategyManager_).factory(),                 strategyManagerFactory);
        assertEq(IStrategyManager(allocationStrategyManager_).strategyDelegate(),        strategyDelegate);
        assertEq(IStrategyManager(allocationStrategyManager_).pendingStrategyDelegate(), address(0));
        assertEq(IStrategyManager(allocationStrategyManager_).underlyingStrategy(),      allocationUnderlyingStrategy_);
        assertEq(IStrategyManager(allocationStrategyManager_).strategyLiquidityCap(),    0);
        assertEq(IStrategyManager(allocationStrategyManager_).totalShares(),             0);
        assertEq(IStrategyManager(allocationStrategyManager_).totalPendingShares(),      0);
        assertEq(IStrategyManager(allocationStrategyManager_).assetsUnderManagement(),   0);

        assertEq(IStrategyManager(allocationStrategyManager_).configured(), true);
        assertEq(IStrategyManager(allocationStrategyManager_).active(),     false);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).strategyManager(),         allocationStrategyManager_);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).fundsAsset(),              address(fundsAsset));
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).strategyMetadata(),        "Allocation Strategy");
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).strategyDelegateFeeRate(), 0.001e6);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).strategyProtocolFeeRate(), 0.002e6);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).impairedAssets(),          0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).scheduledYieldAssets(),    0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).totalDeployedAssets(),     0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).yieldDeadline(),           0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).yieldStart(),              0);
    }

    function test_deploy_success_withBootstrapMint() external {
        uint256 bootstrapMint = 1e6;

        vm.prank(governor);
        globals.setBootstrapMint(address(fundsAsset), bootstrapMint);

        bytes memory data = abi.encode(AllocationStrategyInitializerParams({
            fundsAsset:              address(fundsAsset),
            strategyMetadata:        "Allocation Strategy",
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6,  // 0.2% Fee
            yieldCap:                type(uint256).max
        }));

        ( address expectedStrategyManager, address expectedUnderlyingStrategy ) =
            strategyDeployer.getDeploymentAddresses(strategyDelegate, strategyManagerFactory, allocationStrategyFactory, data);

        erc20_mint(address(fundsAsset), strategyDelegate, bootstrapMint);

        vm.prank(strategyDelegate);
        fundsAsset.approve(address(strategyDeployer), bootstrapMint);

        vm.prank(strategyDelegate);

        ( address allocationStrategyManager_, address allocationUnderlyingStrategy_ ) =
            strategyDeployer.deploy(strategyManagerFactory, allocationStrategyFactory, 0, data, "");

        assertEq(allocationStrategyManager_,    expectedStrategyManager);
        assertEq(allocationUnderlyingStrategy_, expectedUnderlyingStrategy);

        assertEq(fundsAsset.balanceOf(strategyDelegate),              0);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy_), bootstrapMint);

        assertEq(IMapleProxyFactory(strategyManagerFactory).isInstance(allocationStrategyManager_),       true);
        assertEq(IMapleProxyFactory(allocationStrategyFactory).isInstance(allocationUnderlyingStrategy_), true);

        assertEq(IStrategyManager(allocationStrategyManager_).globals(),                 address(globals));
        assertEq(IStrategyManager(allocationStrategyManager_).factory(),                 strategyManagerFactory);
        assertEq(IStrategyManager(allocationStrategyManager_).strategyDelegate(),        strategyDelegate);
        assertEq(IStrategyManager(allocationStrategyManager_).pendingStrategyDelegate(), address(0));
        assertEq(IStrategyManager(allocationStrategyManager_).underlyingStrategy(),      allocationUnderlyingStrategy_);
        assertEq(IStrategyManager(allocationStrategyManager_).strategyLiquidityCap(),    0);
        assertEq(IStrategyManager(allocationStrategyManager_).totalShares(),             bootstrapMint);
        assertEq(IStrategyManager(allocationStrategyManager_).totalPendingShares(),      0);
        assertEq(IStrategyManager(allocationStrategyManager_).sharesOf(address(0)),      bootstrapMint);
        assertEq(IStrategyManager(allocationStrategyManager_).assetsUnderManagement(),   bootstrapMint);

        assertEq(IStrategyManager(allocationStrategyManager_).configured(), true);
        assertEq(IStrategyManager(allocationStrategyManager_).active(),     false);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).strategyManager(),         allocationStrategyManager_);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).fundsAsset(),              address(fundsAsset));
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).strategyMetadata(),        "Allocation Strategy");
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).strategyDelegateFeeRate(), 0.001e6);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).strategyProtocolFeeRate(), 0.002e6);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).impairedAssets(),          0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).scheduledYieldAssets(),    0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).totalDeployedAssets(),     0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).yieldDeadline(),           0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).yieldStart(),              0);
    }

    function test_deploy_success_withStrategyLiquidityCap() external {
        uint256 strategyLiquidityCap = 1_000_000e6;

        bytes memory data = abi.encode(AllocationStrategyInitializerParams({
            fundsAsset:              address(fundsAsset),
            strategyMetadata:        "Allocation Strategy",
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6,  // 0.2% Fee
            yieldCap:                type(uint256).max
        }));

        ( address expectedStrategyManager, address expectedUnderlyingStrategy ) =
            strategyDeployer.getDeploymentAddresses(strategyDelegate, strategyManagerFactory, allocationStrategyFactory, data);

        vm.prank(strategyDelegate);

        ( address allocationStrategyManager_, address allocationUnderlyingStrategy_ ) =
            strategyDeployer.deploy(strategyManagerFactory, allocationStrategyFactory, strategyLiquidityCap, data, "");

        assertEq(allocationStrategyManager_,    expectedStrategyManager);
        assertEq(allocationUnderlyingStrategy_, expectedUnderlyingStrategy);

        assertEq(IMapleProxyFactory(strategyManagerFactory).isInstance(allocationStrategyManager_),       true);
        assertEq(IMapleProxyFactory(allocationStrategyFactory).isInstance(allocationUnderlyingStrategy_), true);

        assertEq(IStrategyManager(allocationStrategyManager_).globals(),                 address(globals));
        assertEq(IStrategyManager(allocationStrategyManager_).factory(),                 strategyManagerFactory);
        assertEq(IStrategyManager(allocationStrategyManager_).strategyDelegate(),        strategyDelegate);
        assertEq(IStrategyManager(allocationStrategyManager_).pendingStrategyDelegate(), address(0));
        assertEq(IStrategyManager(allocationStrategyManager_).underlyingStrategy(),      allocationUnderlyingStrategy_);
        assertEq(IStrategyManager(allocationStrategyManager_).strategyLiquidityCap(),    strategyLiquidityCap);
        assertEq(IStrategyManager(allocationStrategyManager_).totalShares(),             0);
        assertEq(IStrategyManager(allocationStrategyManager_).totalPendingShares(),      0);
        assertEq(IStrategyManager(allocationStrategyManager_).assetsUnderManagement(),   0);

        assertEq(IStrategyManager(allocationStrategyManager_).configured(), true);
        assertEq(IStrategyManager(allocationStrategyManager_).active(),     false);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).strategyManager(),         allocationStrategyManager_);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).fundsAsset(),              address(fundsAsset));
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).strategyMetadata(),        "Allocation Strategy");
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).strategyDelegateFeeRate(), 0.001e6);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).strategyProtocolFeeRate(), 0.002e6);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).impairedAssets(),          0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).scheduledYieldAssets(),    0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).totalDeployedAssets(),     0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).yieldDeadline(),           0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy_).yieldStart(),              0);
    }

    function test_deploy_success_multipleDelegates() external {
        address strategyDelegate1 = makeAddr("strategyDelegate1");
        address strategyDelegate2 = makeAddr("strategyDelegate2");

        vm.startPrank(governor);
        globals.setValidStrategyDelegate(strategyDelegate1, true);
        globals.setValidStrategyDelegate(strategyDelegate2, true);
        vm.stopPrank();

        bytes memory data = abi.encode(AllocationStrategyInitializerParams({
            fundsAsset:              address(fundsAsset),
            strategyMetadata:        "Allocation Strategy",
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6,  // 0.2% Fee
            yieldCap:                type(uint256).max
        }));

        ( address expectedStrategyManager1, address expectedUnderlyingStrategy1 ) =
            strategyDeployer.getDeploymentAddresses(strategyDelegate1, strategyManagerFactory, allocationStrategyFactory, data);

        ( address expectedStrategyManager2, address expectedUnderlyingStrategy2 ) =
            strategyDeployer.getDeploymentAddresses(strategyDelegate2, strategyManagerFactory, allocationStrategyFactory, data);

        vm.prank(strategyDelegate1);

        ( address allocationStrategyManager1, address allocationUnderlyingStrategy1 ) =
            strategyDeployer.deploy(strategyManagerFactory, allocationStrategyFactory, 0, data, "");

        vm.prank(strategyDelegate2);

        ( address allocationStrategyManager2, address allocationUnderlyingStrategy2 ) =
            strategyDeployer.deploy(strategyManagerFactory, allocationStrategyFactory, 0, data, "");

        assertEq(allocationStrategyManager1,    expectedStrategyManager1);
        assertEq(allocationStrategyManager2,    expectedStrategyManager2);
        assertEq(allocationUnderlyingStrategy1, expectedUnderlyingStrategy1);
        assertEq(allocationUnderlyingStrategy2, expectedUnderlyingStrategy2);

        assertNotEq(allocationStrategyManager1,    allocationStrategyManager2);
        assertNotEq(allocationUnderlyingStrategy1, allocationUnderlyingStrategy2);

        assertEq(IMapleProxyFactory(strategyManagerFactory).isInstance(allocationStrategyManager1),       true);
        assertEq(IMapleProxyFactory(strategyManagerFactory).isInstance(allocationStrategyManager2),       true);
        assertEq(IMapleProxyFactory(allocationStrategyFactory).isInstance(allocationUnderlyingStrategy1), true);
        assertEq(IMapleProxyFactory(allocationStrategyFactory).isInstance(allocationUnderlyingStrategy2), true);

        assertEq(IStrategyManager(allocationStrategyManager1).strategyDelegate(),      strategyDelegate1);
        assertEq(IStrategyManager(allocationStrategyManager1).underlyingStrategy(),    allocationUnderlyingStrategy1);
        assertEq(IStrategyManager(allocationStrategyManager1).configured(),            true);
        assertEq(IStrategyManager(allocationStrategyManager1).active(),                false);
        assertEq(IStrategyManager(allocationStrategyManager1).assetsUnderManagement(), 0);

        assertEq(IStrategyManager(allocationStrategyManager2).strategyDelegate(),      strategyDelegate2);
        assertEq(IStrategyManager(allocationStrategyManager2).underlyingStrategy(),    allocationUnderlyingStrategy2);
        assertEq(IStrategyManager(allocationStrategyManager2).configured(),            true);
        assertEq(IStrategyManager(allocationStrategyManager2).active(),                false);
        assertEq(IStrategyManager(allocationStrategyManager2).assetsUnderManagement(), 0);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy1).strategyManager(),         allocationStrategyManager1);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy1).fundsAsset(),              address(fundsAsset));
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy1).strategyMetadata(),        "Allocation Strategy");
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy1).strategyDelegateFeeRate(), 0.001e6);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy1).strategyProtocolFeeRate(), 0.002e6);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy1).impairedAssets(),          0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy1).scheduledYieldAssets(),    0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy1).totalDeployedAssets(),     0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy1).yieldDeadline(),           0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy1).yieldStart(),              0);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy2).strategyManager(),         allocationStrategyManager2);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy2).fundsAsset(),              address(fundsAsset));
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy2).strategyMetadata(),        "Allocation Strategy");
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy2).strategyDelegateFeeRate(), 0.001e6);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy2).strategyProtocolFeeRate(), 0.002e6);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy2).impairedAssets(),          0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy2).scheduledYieldAssets(),    0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy2).totalDeployedAssets(),     0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy2).yieldDeadline(),           0);
        assertEq(IAllocationStrategy(allocationUnderlyingStrategy2).yieldStart(),              0);
    }

}

contract AaveV3StrategyDeployTests is TestBase {

    address aaveToken                   = AAVE_USDC;
    bool    useVirtualUnderlyingBalance = true;

    function setUp() public virtual override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 21073000);

        start      = block.timestamp;
        fundsAsset = IMockERC20(USDC);

        _createAccounts();
        _createGlobals();
        _configureGlobals();
        _createFactories();
    }

    function test_deploy_revert_cannotDeployUnderlyingStrategy() external {
        vm.prank(governor);
        globals.setCanDeployFrom(aaveV3StrategyFactory, address(strategyDeployer), false);

        bytes memory data = abi.encode(AaveV3StrategyInitializerParams({
            aaveToken:                   aaveToken,
            strategyDelegateFeeRate:     0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate:     0.002e6,  // 0.2% Fee
            referralCode:                0,
            useVirtualUnderlyingBalance: useVirtualUnderlyingBalance
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3SF:CI:CANNOT_DEPLOY");
        strategyDeployer.deploy(strategyManagerFactory, aaveV3StrategyFactory, 0, data, "");
    }

    function test_deploy_revert_zeroAaveToken() external {
        bytes memory data = abi.encode(AaveV3StrategyInitializerParams({
            aaveToken:                   address(0),
            strategyDelegateFeeRate:     0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate:     0.002e6,  // 0.2% Fee
            referralCode:                0,
            useVirtualUnderlyingBalance: useVirtualUnderlyingBalance
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        strategyDeployer.deploy(strategyManagerFactory, aaveV3StrategyFactory, 0, data, "");
    }

    function test_deploy_revert_invalidFeeRateSum() external {
        bytes memory data = abi.encode(AaveV3StrategyInitializerParams({
            aaveToken:                   aaveToken,
            strategyDelegateFeeRate:     0.5e6,      // 50% Fee
            strategyProtocolFeeRate:     0.5e6 + 1,  // 50.0001% Fee
            referralCode:                0,
            useVirtualUnderlyingBalance: useVirtualUnderlyingBalance
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        strategyDeployer.deploy(strategyManagerFactory, aaveV3StrategyFactory, 0, data, "");
    }

    function test_deploy_revert_invalidStrategyVault() external {
        bytes memory data = abi.encode(AaveV3StrategyInitializerParams({
            aaveToken:                   aaveToken,
            strategyDelegateFeeRate:     0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate:     0.002e6,  // 0.2% Fee
            referralCode:                0,
            useVirtualUnderlyingBalance: useVirtualUnderlyingBalance
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        strategyDeployer.deploy(strategyManagerFactory, aaveV3StrategyFactory, 0, data, "");
    }

    function test_deploy_revert_invalidAsset() external {
        vm.startPrank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", aaveToken, true);
        globals.setValidPoolAsset(USDC, false);
        vm.stopPrank();

        bytes memory data = abi.encode(AaveV3StrategyInitializerParams({
            aaveToken:                   aaveToken,
            strategyDelegateFeeRate:     0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate:     0.002e6,  // 0.2% Fee
            referralCode:                0,
            useVirtualUnderlyingBalance: useVirtualUnderlyingBalance
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        strategyDeployer.deploy(strategyManagerFactory, aaveV3StrategyFactory, 0, data, "");
    }

    function test_deploy_success() external {
        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", aaveToken, true);

        bytes memory data = abi.encode(AaveV3StrategyInitializerParams({
            aaveToken:                   aaveToken,
            strategyDelegateFeeRate:     0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate:     0.002e6,  // 0.2% Fee
            referralCode:                7,
            useVirtualUnderlyingBalance: useVirtualUnderlyingBalance
        }));

        ( address expectedStrategyManager, address expectedUnderlyingStrategy ) =
            strategyDeployer.getDeploymentAddresses(strategyDelegate, strategyManagerFactory, aaveV3StrategyFactory, data);

        vm.prank(strategyDelegate);

        ( address aaveStrategyManager_, address aaveUnderlyingStrategy_ ) =
            strategyDeployer.deploy(strategyManagerFactory, aaveV3StrategyFactory, 0, data, "");

        assertEq(aaveStrategyManager_,    expectedStrategyManager);
        assertEq(aaveUnderlyingStrategy_, expectedUnderlyingStrategy);

        assertEq(IMapleProxyFactory(strategyManagerFactory).isInstance(aaveStrategyManager_),   true);
        assertEq(IMapleProxyFactory(aaveV3StrategyFactory).isInstance(aaveUnderlyingStrategy_), true);

        assertEq(IStrategyManager(aaveStrategyManager_).globals(),                 address(globals));
        assertEq(IStrategyManager(aaveStrategyManager_).factory(),                 strategyManagerFactory);
        assertEq(IStrategyManager(aaveStrategyManager_).strategyDelegate(),        strategyDelegate);
        assertEq(IStrategyManager(aaveStrategyManager_).pendingStrategyDelegate(), address(0));
        assertEq(IStrategyManager(aaveStrategyManager_).underlyingStrategy(),      aaveUnderlyingStrategy_);
        assertEq(IStrategyManager(aaveStrategyManager_).strategyLiquidityCap(),    0);
        assertEq(IStrategyManager(aaveStrategyManager_).totalShares(),             0);
        assertEq(IStrategyManager(aaveStrategyManager_).totalPendingShares(),      0);
        assertEq(IStrategyManager(aaveStrategyManager_).assetsUnderManagement(),   0);

        assertEq(IStrategyManager(aaveStrategyManager_).configured(), true);
        assertEq(IStrategyManager(aaveStrategyManager_).active(),     false);

        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).strategyManager(),             aaveStrategyManager_);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).aaveToken(),                   aaveToken);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).fundsAsset(),                  USDC);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).strategyDelegateFeeRate(),     0.001e6);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).strategyProtocolFeeRate(),     0.002e6);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).referralCode(),                7);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).impairedAssets(),              0);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).lastRecordedTotalAssets(),     0);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).isLossRecognized(),            false);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).useVirtualUnderlyingBalance(), useVirtualUnderlyingBalance);

        assertNotEq(IAaveV3Strategy(aaveUnderlyingStrategy_).aavePool(), address(0));
    }

    function test_deploy_success_withBootstrapMint() external {
        uint256 bootstrapMint = 1e6;

        vm.startPrank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", aaveToken, true);
        globals.setBootstrapMint(address(fundsAsset), bootstrapMint);
        vm.stopPrank();

        bytes memory data = abi.encode(AaveV3StrategyInitializerParams({
            aaveToken:                   aaveToken,
            strategyDelegateFeeRate:     0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate:     0.002e6,  // 0.2% Fee
            referralCode:                7,
            useVirtualUnderlyingBalance: useVirtualUnderlyingBalance
        }));

        ( address expectedStrategyManager, address expectedUnderlyingStrategy ) =
            strategyDeployer.getDeploymentAddresses(strategyDelegate, strategyManagerFactory, aaveV3StrategyFactory, data);

        erc20_mint(address(fundsAsset), strategyDelegate, bootstrapMint);

        vm.prank(strategyDelegate);
        fundsAsset.approve(address(strategyDeployer), bootstrapMint);

        vm.prank(strategyDelegate);

        ( address aaveStrategyManager_, address aaveUnderlyingStrategy_ ) =
            strategyDeployer.deploy(strategyManagerFactory, aaveV3StrategyFactory, 0, data, "");

        uint256 assetsDeposited = IStrategyManager(aaveStrategyManager_).assetsUnderManagement();

        assertEq(aaveStrategyManager_,    expectedStrategyManager);
        assertEq(aaveUnderlyingStrategy_, expectedUnderlyingStrategy);

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);

        assertApproxEqAbs(assetsDeposited, bootstrapMint, 1);

        assertEq(IMapleProxyFactory(strategyManagerFactory).isInstance(aaveStrategyManager_),   true);
        assertEq(IMapleProxyFactory(aaveV3StrategyFactory).isInstance(aaveUnderlyingStrategy_), true);

        assertEq(IStrategyManager(aaveStrategyManager_).globals(),                 address(globals));
        assertEq(IStrategyManager(aaveStrategyManager_).factory(),                 strategyManagerFactory);
        assertEq(IStrategyManager(aaveStrategyManager_).strategyDelegate(),        strategyDelegate);
        assertEq(IStrategyManager(aaveStrategyManager_).pendingStrategyDelegate(), address(0));
        assertEq(IStrategyManager(aaveStrategyManager_).underlyingStrategy(),      aaveUnderlyingStrategy_);
        assertEq(IStrategyManager(aaveStrategyManager_).strategyLiquidityCap(),    0);
        assertEq(IStrategyManager(aaveStrategyManager_).totalShares(),             assetsDeposited);
        assertEq(IStrategyManager(aaveStrategyManager_).totalPendingShares(),      0);
        assertEq(IStrategyManager(aaveStrategyManager_).sharesOf(address(0)),      assetsDeposited);
        assertEq(IStrategyManager(aaveStrategyManager_).assetsUnderManagement(),   assetsDeposited);

        assertEq(IStrategyManager(aaveStrategyManager_).configured(), true);
        assertEq(IStrategyManager(aaveStrategyManager_).active(),     false);

        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).strategyManager(),             aaveStrategyManager_);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).aaveToken(),                   aaveToken);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).fundsAsset(),                  USDC);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).strategyDelegateFeeRate(),     0.001e6);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).strategyProtocolFeeRate(),     0.002e6);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).referralCode(),                7);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).impairedAssets(),              0);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).lastRecordedTotalAssets(),     assetsDeposited);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).isLossRecognized(),            false);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).useVirtualUnderlyingBalance(), useVirtualUnderlyingBalance);

        assertNotEq(IAaveV3Strategy(aaveUnderlyingStrategy_).aavePool(), address(0));
    }

    function test_deploy_success_withStrategyLiquidityCap() external {
        uint256 strategyLiquidityCap = 1_000_000e6;

        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", aaveToken, true);

        bytes memory data = abi.encode(AaveV3StrategyInitializerParams({
            aaveToken:                   aaveToken,
            strategyDelegateFeeRate:     0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate:     0.002e6,  // 0.2% Fee
            referralCode:                7,
            useVirtualUnderlyingBalance: useVirtualUnderlyingBalance
        }));

        ( address expectedStrategyManager, address expectedUnderlyingStrategy ) =
            strategyDeployer.getDeploymentAddresses(strategyDelegate, strategyManagerFactory, aaveV3StrategyFactory, data);

        vm.prank(strategyDelegate);

        ( address aaveStrategyManager_, address aaveUnderlyingStrategy_ ) =
            strategyDeployer.deploy(strategyManagerFactory, aaveV3StrategyFactory, strategyLiquidityCap, data, "");

        assertEq(aaveStrategyManager_,    expectedStrategyManager);
        assertEq(aaveUnderlyingStrategy_, expectedUnderlyingStrategy);

        assertEq(IMapleProxyFactory(strategyManagerFactory).isInstance(aaveStrategyManager_),   true);
        assertEq(IMapleProxyFactory(aaveV3StrategyFactory).isInstance(aaveUnderlyingStrategy_), true);

        assertEq(IStrategyManager(aaveStrategyManager_).globals(),                 address(globals));
        assertEq(IStrategyManager(aaveStrategyManager_).factory(),                 strategyManagerFactory);
        assertEq(IStrategyManager(aaveStrategyManager_).strategyDelegate(),        strategyDelegate);
        assertEq(IStrategyManager(aaveStrategyManager_).pendingStrategyDelegate(), address(0));
        assertEq(IStrategyManager(aaveStrategyManager_).underlyingStrategy(),      aaveUnderlyingStrategy_);
        assertEq(IStrategyManager(aaveStrategyManager_).strategyLiquidityCap(),    strategyLiquidityCap);
        assertEq(IStrategyManager(aaveStrategyManager_).totalShares(),             0);
        assertEq(IStrategyManager(aaveStrategyManager_).totalPendingShares(),      0);
        assertEq(IStrategyManager(aaveStrategyManager_).assetsUnderManagement(),   0);

        assertEq(IStrategyManager(aaveStrategyManager_).configured(), true);
        assertEq(IStrategyManager(aaveStrategyManager_).active(),     false);

        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).strategyManager(),             aaveStrategyManager_);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).aaveToken(),                   aaveToken);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).fundsAsset(),                  USDC);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).strategyDelegateFeeRate(),     0.001e6);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).strategyProtocolFeeRate(),     0.002e6);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).referralCode(),                7);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).impairedAssets(),              0);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).lastRecordedTotalAssets(),     0);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).isLossRecognized(),            false);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).useVirtualUnderlyingBalance(), useVirtualUnderlyingBalance);

        assertNotEq(IAaveV3Strategy(aaveUnderlyingStrategy_).aavePool(), address(0));
    }

    function test_deploy_success_multipleDelegates() external {
        address strategyDelegate1 = makeAddr("strategyDelegate1");
        address strategyDelegate2 = makeAddr("strategyDelegate2");

        vm.startPrank(governor);
        globals.setValidStrategyDelegate(strategyDelegate1, true);
        globals.setValidStrategyDelegate(strategyDelegate2, true);
        globals.setValidInstanceOf("STRATEGY_VAULT", aaveToken, true);
        vm.stopPrank();

        bytes memory data = abi.encode(AaveV3StrategyInitializerParams({
            aaveToken:                   aaveToken,
            strategyDelegateFeeRate:     0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate:     0.002e6,  // 0.2% Fee
            referralCode:                7,
            useVirtualUnderlyingBalance: useVirtualUnderlyingBalance
        }));

        ( address expectedStrategyManager1, address expectedUnderlyingStrategy1 ) =
            strategyDeployer.getDeploymentAddresses(strategyDelegate1, strategyManagerFactory, aaveV3StrategyFactory, data);

        ( address expectedStrategyManager2, address expectedUnderlyingStrategy2 ) =
            strategyDeployer.getDeploymentAddresses(strategyDelegate2, strategyManagerFactory, aaveV3StrategyFactory, data);

        vm.prank(strategyDelegate1);

        ( address aaveStrategyManager1, address aaveUnderlyingStrategy1 ) =
            strategyDeployer.deploy(strategyManagerFactory, aaveV3StrategyFactory, 0, data, "");

        vm.prank(strategyDelegate2);

        ( address aaveStrategyManager2, address aaveUnderlyingStrategy2 ) =
            strategyDeployer.deploy(strategyManagerFactory, aaveV3StrategyFactory, 0, data, "");

        assertEq(aaveStrategyManager1,    expectedStrategyManager1);
        assertEq(aaveStrategyManager2,    expectedStrategyManager2);
        assertEq(aaveUnderlyingStrategy1, expectedUnderlyingStrategy1);
        assertEq(aaveUnderlyingStrategy2, expectedUnderlyingStrategy2);

        assertNotEq(aaveStrategyManager1,    aaveStrategyManager2);
        assertNotEq(aaveUnderlyingStrategy1, aaveUnderlyingStrategy2);

        assertEq(IMapleProxyFactory(strategyManagerFactory).isInstance(aaveStrategyManager1),   true);
        assertEq(IMapleProxyFactory(strategyManagerFactory).isInstance(aaveStrategyManager2),   true);
        assertEq(IMapleProxyFactory(aaveV3StrategyFactory).isInstance(aaveUnderlyingStrategy1), true);
        assertEq(IMapleProxyFactory(aaveV3StrategyFactory).isInstance(aaveUnderlyingStrategy2), true);

        assertEq(IStrategyManager(aaveStrategyManager1).strategyDelegate(),      strategyDelegate1);
        assertEq(IStrategyManager(aaveStrategyManager1).underlyingStrategy(),    aaveUnderlyingStrategy1);
        assertEq(IStrategyManager(aaveStrategyManager1).configured(),            true);
        assertEq(IStrategyManager(aaveStrategyManager1).active(),                false);
        assertEq(IStrategyManager(aaveStrategyManager1).assetsUnderManagement(), 0);

        assertEq(IStrategyManager(aaveStrategyManager2).strategyDelegate(),      strategyDelegate2);
        assertEq(IStrategyManager(aaveStrategyManager2).underlyingStrategy(),    aaveUnderlyingStrategy2);
        assertEq(IStrategyManager(aaveStrategyManager2).configured(),            true);
        assertEq(IStrategyManager(aaveStrategyManager2).active(),                false);
        assertEq(IStrategyManager(aaveStrategyManager2).assetsUnderManagement(), 0);

        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy1).strategyManager(),             aaveStrategyManager1);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy1).aaveToken(),                   aaveToken);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy1).fundsAsset(),                  USDC);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy1).strategyDelegateFeeRate(),     0.001e6);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy1).strategyProtocolFeeRate(),     0.002e6);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy1).referralCode(),                7);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy1).impairedAssets(),              0);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy1).lastRecordedTotalAssets(),     0);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy1).isLossRecognized(),            false);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy1).useVirtualUnderlyingBalance(), useVirtualUnderlyingBalance);

        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy2).strategyManager(),             aaveStrategyManager2);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy2).aaveToken(),                   aaveToken);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy2).fundsAsset(),                  USDC);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy2).strategyDelegateFeeRate(),     0.001e6);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy2).strategyProtocolFeeRate(),     0.002e6);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy2).referralCode(),                7);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy2).impairedAssets(),              0);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy2).lastRecordedTotalAssets(),     0);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy2).isLossRecognized(),            false);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy2).useVirtualUnderlyingBalance(), useVirtualUnderlyingBalance);
    }

}

contract SparkLendStrategyDeployTests is AaveV3StrategyDeployTests {

    function setUp() public override {
        aaveToken                   = SPARK_USDC;
        useVirtualUnderlyingBalance = false;

        super.setUp();
    }

}

contract SkyStrategyDeployTests is TestBase {

    // sDAI (asset: DAI), a real ERC4626 whose asset differs from the PSM's usds.
    address constant SDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;

    function setUp() public override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 21073000);

        start      = block.timestamp;
        fundsAsset = IMockERC20(USDC);

        _createAccounts();
        _createGlobals();
        _configureGlobals();
        _createFactories();
    }

    function test_deploy_revert_cannotDeployUnderlyingStrategy() external {
        vm.prank(governor);
        globals.setCanDeployFrom(skyStrategyFactory, address(strategyDeployer), false);

        bytes memory data = abi.encode(SkyStrategyInitializerParams({
            fundsAsset:              USDC,
            psm:                     USDS_LITE_PSM,
            savingsUsds:             SAVINGS_USDS,
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6,  // 0.2% Fee
            referralCode:            0
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MSSF:CI:CANNOT_DEPLOY");
        strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, 0, data, "");
    }

    function test_deploy_revert_zeroSavingsUsds() external {
        bytes memory data = abi.encode(SkyStrategyInitializerParams({
            fundsAsset:              USDC,
            psm:                     USDS_LITE_PSM,
            savingsUsds:             address(0),
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6,  // 0.2% Fee
            referralCode:            0
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, 0, data, "");
    }

    function test_deploy_revert_zeroPsm() external {
        bytes memory data = abi.encode(SkyStrategyInitializerParams({
            fundsAsset:              USDC,
            psm:                     address(0),
            savingsUsds:             SAVINGS_USDS,
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6,  // 0.2% Fee
            referralCode:            0
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, 0, data, "");
    }

    function test_deploy_revert_invalidFeeRateSum() external {
        bytes memory data = abi.encode(SkyStrategyInitializerParams({
            fundsAsset:              USDC,
            psm:                     USDS_LITE_PSM,
            savingsUsds:             SAVINGS_USDS,
            strategyDelegateFeeRate: 0.5e6,      // 50% Fee
            strategyProtocolFeeRate: 0.5e6 + 1,  // 50.0001% Fee
            referralCode:            0
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, 0, data, "");
    }

    function test_deploy_revert_invalidAsset() external {
        bytes memory data = abi.encode(SkyStrategyInitializerParams({
            fundsAsset:              makeAddr("notPoolAsset"),
            psm:                     USDS_LITE_PSM,
            savingsUsds:             SAVINGS_USDS,
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6,  // 0.2% Fee
            referralCode:            0
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, 0, data, "");
    }

    function test_deploy_revert_invalidStrategyVault() external {
        vm.prank(governor);
        globals.setValidInstanceOf("PSM", USDS_LITE_PSM, true);

        bytes memory data = abi.encode(SkyStrategyInitializerParams({
            fundsAsset:              USDC,
            psm:                     USDS_LITE_PSM,
            savingsUsds:             SAVINGS_USDS,
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6,  // 0.2% Fee
            referralCode:            0
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, 0, data, "");
    }

    function test_deploy_revert_invalidPsm() external {
        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", SAVINGS_USDS, true);

        bytes memory data = abi.encode(SkyStrategyInitializerParams({
            fundsAsset:              USDC,
            psm:                     USDS_LITE_PSM,
            savingsUsds:             SAVINGS_USDS,
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6,  // 0.2% Fee
            referralCode:            0
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, 0, data, "");
    }

    function test_deploy_revert_invalidGemPsm() external {
        vm.startPrank(governor);
        globals.setValidPoolAsset(USDT, true);
        globals.setValidInstanceOf("STRATEGY_VAULT", SAVINGS_USDS, true);
        globals.setValidInstanceOf("PSM", USDS_LITE_PSM, true);
        vm.stopPrank();

        bytes memory data = abi.encode(SkyStrategyInitializerParams({
            fundsAsset:              USDT,
            psm:                     USDS_LITE_PSM,
            savingsUsds:             SAVINGS_USDS,
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6,  // 0.2% Fee
            referralCode:            0
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, 0, data, "");
    }

    function test_deploy_revert_invalidUsdsPsm() external {
        vm.startPrank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", SDAI,          true);
        globals.setValidInstanceOf("PSM",            USDS_LITE_PSM, true);
        vm.stopPrank();

        bytes memory data = abi.encode(SkyStrategyInitializerParams({
            fundsAsset:              USDC,
            psm:                     USDS_LITE_PSM,
            savingsUsds:             SDAI,
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6,  // 0.2% Fee
            referralCode:            0
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, 0, data, "");
    }

    function test_deploy_success() external {
        vm.startPrank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", SAVINGS_USDS,  true);
        globals.setValidInstanceOf("PSM",            USDS_LITE_PSM, true);
        vm.stopPrank();

        bytes memory data = abi.encode(SkyStrategyInitializerParams({
            fundsAsset:              USDC,
            psm:                     USDS_LITE_PSM,
            savingsUsds:             SAVINGS_USDS,
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6,  // 0.2% Fee
            referralCode:            7
        }));

        ( address expectedStrategyManager, address expectedUnderlyingStrategy ) =
            strategyDeployer.getDeploymentAddresses(strategyDelegate, strategyManagerFactory, skyStrategyFactory, data);

        vm.prank(strategyDelegate);

        ( address skyStrategyManager_, address skyUnderlyingStrategy_ ) =
            strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, 0, data, "");

        assertEq(skyStrategyManager_,    expectedStrategyManager);
        assertEq(skyUnderlyingStrategy_, expectedUnderlyingStrategy);

        assertEq(IMapleProxyFactory(strategyManagerFactory).isInstance(skyStrategyManager_), true);
        assertEq(IMapleProxyFactory(skyStrategyFactory).isInstance(skyUnderlyingStrategy_),  true);

        assertEq(IStrategyManager(skyStrategyManager_).globals(),                 address(globals));
        assertEq(IStrategyManager(skyStrategyManager_).factory(),                 strategyManagerFactory);
        assertEq(IStrategyManager(skyStrategyManager_).strategyDelegate(),        strategyDelegate);
        assertEq(IStrategyManager(skyStrategyManager_).pendingStrategyDelegate(), address(0));
        assertEq(IStrategyManager(skyStrategyManager_).underlyingStrategy(),      skyUnderlyingStrategy_);
        assertEq(IStrategyManager(skyStrategyManager_).strategyLiquidityCap(),    0);
        assertEq(IStrategyManager(skyStrategyManager_).totalShares(),             0);
        assertEq(IStrategyManager(skyStrategyManager_).totalPendingShares(),      0);
        assertEq(IStrategyManager(skyStrategyManager_).assetsUnderManagement(),   0);

        assertEq(IStrategyManager(skyStrategyManager_).configured(), true);
        assertEq(IStrategyManager(skyStrategyManager_).active(),     false);

        assertEq(ISkyStrategy(skyUnderlyingStrategy_).strategyManager(),         skyStrategyManager_);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).fundsAsset(),              USDC);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).psm(),                     USDS_LITE_PSM);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).savingsUsds(),             SAVINGS_USDS);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).usds(),                    USDS);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).strategyDelegateFeeRate(), 0.001e6);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).strategyProtocolFeeRate(), 0.002e6);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).referralCode(),            7);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).fallbackTout(),            0);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).impairedAssets(),          0);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).lastRecordedTotalAssets(), 0);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).isLossRecognized(),        false);
    }

    function test_deploy_success_withBootstrapMint() external {
        uint256 bootstrapMint = 1e6;

        vm.startPrank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", SAVINGS_USDS,  true);
        globals.setValidInstanceOf("PSM",            USDS_LITE_PSM, true);
        globals.setBootstrapMint(address(fundsAsset), bootstrapMint);
        vm.stopPrank();

        bytes memory data = abi.encode(SkyStrategyInitializerParams({
            fundsAsset:              USDC,
            psm:                     USDS_LITE_PSM,
            savingsUsds:             SAVINGS_USDS,
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6,  // 0.2% Fee
            referralCode:            7
        }));

        ( address expectedStrategyManager, address expectedUnderlyingStrategy ) =
            strategyDeployer.getDeploymentAddresses(strategyDelegate, strategyManagerFactory, skyStrategyFactory, data);

        erc20_mint(address(fundsAsset), strategyDelegate, bootstrapMint);

        vm.prank(strategyDelegate);
        fundsAsset.approve(address(strategyDeployer), bootstrapMint);

        vm.prank(strategyDelegate);

        ( address skyStrategyManager_, address skyUnderlyingStrategy_ ) =
            strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, 0, data, "");

        uint256 assetsDeposited = IStrategyManager(skyStrategyManager_).assetsUnderManagement();

        assertEq(skyStrategyManager_,    expectedStrategyManager);
        assertEq(skyUnderlyingStrategy_, expectedUnderlyingStrategy);

        assertEq(fundsAsset.balanceOf(strategyDelegate), 0);

        assertApproxEqAbs(assetsDeposited, bootstrapMint, 1);

        assertEq(IMapleProxyFactory(strategyManagerFactory).isInstance(skyStrategyManager_), true);
        assertEq(IMapleProxyFactory(skyStrategyFactory).isInstance(skyUnderlyingStrategy_),  true);

        assertEq(IStrategyManager(skyStrategyManager_).globals(),                 address(globals));
        assertEq(IStrategyManager(skyStrategyManager_).factory(),                 strategyManagerFactory);
        assertEq(IStrategyManager(skyStrategyManager_).strategyDelegate(),        strategyDelegate);
        assertEq(IStrategyManager(skyStrategyManager_).pendingStrategyDelegate(), address(0));
        assertEq(IStrategyManager(skyStrategyManager_).underlyingStrategy(),      skyUnderlyingStrategy_);
        assertEq(IStrategyManager(skyStrategyManager_).strategyLiquidityCap(),    0);
        assertEq(IStrategyManager(skyStrategyManager_).totalShares(),             assetsDeposited);
        assertEq(IStrategyManager(skyStrategyManager_).totalPendingShares(),      0);
        assertEq(IStrategyManager(skyStrategyManager_).sharesOf(address(0)),      assetsDeposited);
        assertEq(IStrategyManager(skyStrategyManager_).assetsUnderManagement(),   assetsDeposited);

        assertEq(IStrategyManager(skyStrategyManager_).configured(), true);
        assertEq(IStrategyManager(skyStrategyManager_).active(),     false);

        assertEq(ISkyStrategy(skyUnderlyingStrategy_).strategyManager(),         skyStrategyManager_);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).fundsAsset(),              USDC);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).psm(),                     USDS_LITE_PSM);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).savingsUsds(),             SAVINGS_USDS);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).usds(),                    USDS);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).strategyDelegateFeeRate(), 0.001e6);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).strategyProtocolFeeRate(), 0.002e6);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).referralCode(),            7);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).fallbackTout(),            0);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).impairedAssets(),          0);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).lastRecordedTotalAssets(), assetsDeposited);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).isLossRecognized(),        false);
    }

    function test_deploy_success_withStrategyLiquidityCap() external {
        uint256 strategyLiquidityCap = 1_000_000e6;

        vm.startPrank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", SAVINGS_USDS,  true);
        globals.setValidInstanceOf("PSM",            USDS_LITE_PSM, true);
        vm.stopPrank();

        bytes memory data = abi.encode(SkyStrategyInitializerParams({
            fundsAsset:              USDC,
            psm:                     USDS_LITE_PSM,
            savingsUsds:             SAVINGS_USDS,
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6,  // 0.2% Fee
            referralCode:            7
        }));

        ( address expectedStrategyManager, address expectedUnderlyingStrategy ) =
            strategyDeployer.getDeploymentAddresses(strategyDelegate, strategyManagerFactory, skyStrategyFactory, data);

        vm.prank(strategyDelegate);

        ( address skyStrategyManager_, address skyUnderlyingStrategy_ ) =
            strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, strategyLiquidityCap, data, "");

        assertEq(skyStrategyManager_,    expectedStrategyManager);
        assertEq(skyUnderlyingStrategy_, expectedUnderlyingStrategy);

        assertEq(IMapleProxyFactory(strategyManagerFactory).isInstance(skyStrategyManager_), true);
        assertEq(IMapleProxyFactory(skyStrategyFactory).isInstance(skyUnderlyingStrategy_),  true);

        assertEq(IStrategyManager(skyStrategyManager_).globals(),                 address(globals));
        assertEq(IStrategyManager(skyStrategyManager_).factory(),                 strategyManagerFactory);
        assertEq(IStrategyManager(skyStrategyManager_).strategyDelegate(),        strategyDelegate);
        assertEq(IStrategyManager(skyStrategyManager_).pendingStrategyDelegate(), address(0));
        assertEq(IStrategyManager(skyStrategyManager_).underlyingStrategy(),      skyUnderlyingStrategy_);
        assertEq(IStrategyManager(skyStrategyManager_).strategyLiquidityCap(),    strategyLiquidityCap);
        assertEq(IStrategyManager(skyStrategyManager_).totalShares(),             0);
        assertEq(IStrategyManager(skyStrategyManager_).totalPendingShares(),      0);
        assertEq(IStrategyManager(skyStrategyManager_).assetsUnderManagement(),   0);

        assertEq(IStrategyManager(skyStrategyManager_).configured(), true);
        assertEq(IStrategyManager(skyStrategyManager_).active(),     false);

        assertEq(ISkyStrategy(skyUnderlyingStrategy_).strategyManager(),         skyStrategyManager_);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).fundsAsset(),              USDC);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).psm(),                     USDS_LITE_PSM);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).savingsUsds(),             SAVINGS_USDS);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).usds(),                    USDS);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).strategyDelegateFeeRate(), 0.001e6);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).strategyProtocolFeeRate(), 0.002e6);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).referralCode(),            7);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).fallbackTout(),            0);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).impairedAssets(),          0);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).lastRecordedTotalAssets(), 0);
        assertEq(ISkyStrategy(skyUnderlyingStrategy_).isLossRecognized(),        false);
    }

    function test_deploy_success_multipleDelegates() external {
        address strategyDelegate1 = makeAddr("strategyDelegate1");
        address strategyDelegate2 = makeAddr("strategyDelegate2");

        vm.startPrank(governor);
        globals.setValidStrategyDelegate(strategyDelegate1, true);
        globals.setValidStrategyDelegate(strategyDelegate2, true);
        globals.setValidInstanceOf("STRATEGY_VAULT", SAVINGS_USDS,  true);
        globals.setValidInstanceOf("PSM",            USDS_LITE_PSM, true);
        vm.stopPrank();

        bytes memory data = abi.encode(SkyStrategyInitializerParams({
            fundsAsset:              USDC,
            psm:                     USDS_LITE_PSM,
            savingsUsds:             SAVINGS_USDS,
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6,  // 0.2% Fee
            referralCode:            7
        }));

        ( address expectedStrategyManager1, address expectedUnderlyingStrategy1 ) =
            strategyDeployer.getDeploymentAddresses(strategyDelegate1, strategyManagerFactory, skyStrategyFactory, data);

        ( address expectedStrategyManager2, address expectedUnderlyingStrategy2 ) =
            strategyDeployer.getDeploymentAddresses(strategyDelegate2, strategyManagerFactory, skyStrategyFactory, data);

        vm.prank(strategyDelegate1);

        ( address skyStrategyManager1, address skyUnderlyingStrategy1 ) =
            strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, 0, data, "");

        vm.prank(strategyDelegate2);

        ( address skyStrategyManager2, address skyUnderlyingStrategy2 ) =
            strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, 0, data, "");

        assertEq(skyStrategyManager1,    expectedStrategyManager1);
        assertEq(skyStrategyManager2,    expectedStrategyManager2);
        assertEq(skyUnderlyingStrategy1, expectedUnderlyingStrategy1);
        assertEq(skyUnderlyingStrategy2, expectedUnderlyingStrategy2);

        assertNotEq(skyStrategyManager1,    skyStrategyManager2);
        assertNotEq(skyUnderlyingStrategy1, skyUnderlyingStrategy2);

        assertEq(IMapleProxyFactory(strategyManagerFactory).isInstance(skyStrategyManager1), true);
        assertEq(IMapleProxyFactory(strategyManagerFactory).isInstance(skyStrategyManager2), true);
        assertEq(IMapleProxyFactory(skyStrategyFactory).isInstance(skyUnderlyingStrategy1),  true);
        assertEq(IMapleProxyFactory(skyStrategyFactory).isInstance(skyUnderlyingStrategy2),  true);

        assertEq(IStrategyManager(skyStrategyManager1).strategyDelegate(),      strategyDelegate1);
        assertEq(IStrategyManager(skyStrategyManager1).underlyingStrategy(),    skyUnderlyingStrategy1);
        assertEq(IStrategyManager(skyStrategyManager1).configured(),            true);
        assertEq(IStrategyManager(skyStrategyManager1).active(),                false);
        assertEq(IStrategyManager(skyStrategyManager1).assetsUnderManagement(), 0);

        assertEq(IStrategyManager(skyStrategyManager2).strategyDelegate(),      strategyDelegate2);
        assertEq(IStrategyManager(skyStrategyManager2).underlyingStrategy(),    skyUnderlyingStrategy2);
        assertEq(IStrategyManager(skyStrategyManager2).configured(),            true);
        assertEq(IStrategyManager(skyStrategyManager2).active(),                false);
        assertEq(IStrategyManager(skyStrategyManager2).assetsUnderManagement(), 0);

        assertEq(ISkyStrategy(skyUnderlyingStrategy1).strategyManager(),         skyStrategyManager1);
        assertEq(ISkyStrategy(skyUnderlyingStrategy1).fundsAsset(),              USDC);
        assertEq(ISkyStrategy(skyUnderlyingStrategy1).psm(),                     USDS_LITE_PSM);
        assertEq(ISkyStrategy(skyUnderlyingStrategy1).savingsUsds(),             SAVINGS_USDS);
        assertEq(ISkyStrategy(skyUnderlyingStrategy1).usds(),                    USDS);
        assertEq(ISkyStrategy(skyUnderlyingStrategy1).strategyDelegateFeeRate(), 0.001e6);
        assertEq(ISkyStrategy(skyUnderlyingStrategy1).strategyProtocolFeeRate(), 0.002e6);
        assertEq(ISkyStrategy(skyUnderlyingStrategy1).referralCode(),            7);
        assertEq(ISkyStrategy(skyUnderlyingStrategy1).fallbackTout(),            0);
        assertEq(ISkyStrategy(skyUnderlyingStrategy1).impairedAssets(),          0);
        assertEq(ISkyStrategy(skyUnderlyingStrategy1).lastRecordedTotalAssets(), 0);
        assertEq(ISkyStrategy(skyUnderlyingStrategy1).isLossRecognized(),        false);

        assertEq(ISkyStrategy(skyUnderlyingStrategy2).strategyManager(),         skyStrategyManager2);
        assertEq(ISkyStrategy(skyUnderlyingStrategy2).fundsAsset(),              USDC);
        assertEq(ISkyStrategy(skyUnderlyingStrategy2).psm(),                     USDS_LITE_PSM);
        assertEq(ISkyStrategy(skyUnderlyingStrategy2).savingsUsds(),             SAVINGS_USDS);
        assertEq(ISkyStrategy(skyUnderlyingStrategy2).usds(),                    USDS);
        assertEq(ISkyStrategy(skyUnderlyingStrategy2).strategyDelegateFeeRate(), 0.001e6);
        assertEq(ISkyStrategy(skyUnderlyingStrategy2).strategyProtocolFeeRate(), 0.002e6);
        assertEq(ISkyStrategy(skyUnderlyingStrategy2).referralCode(),            7);
        assertEq(ISkyStrategy(skyUnderlyingStrategy2).fallbackTout(),            0);
        assertEq(ISkyStrategy(skyUnderlyingStrategy2).impairedAssets(),          0);
        assertEq(ISkyStrategy(skyUnderlyingStrategy2).lastRecordedTotalAssets(), 0);
        assertEq(ISkyStrategy(skyUnderlyingStrategy2).isLossRecognized(),        false);
    }

}
