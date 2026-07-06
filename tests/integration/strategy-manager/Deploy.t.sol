// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAaveV3Strategy,
    IMockERC20,
    IMapleProxyFactory,
    ISkyStrategy,
    IStrategyManager,
    ITradingStrategy
} from "../../../contracts/interfaces/Interfaces.sol";

import {
    AaveV3StrategyInitializerParams,
    TradingStrategyInitializerParams,
    SkyStrategyInitializerParams
} from "../../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../../TestBase.sol";

contract StrategyDeployerRevertTests is TestBase {

    bytes deploymentData;

    function setUp() public override {
        super.setUp();

        deploymentData = abi.encode(TradingStrategyInitializerParams({
            fundsAsset:              address(fundsAsset),
            strategyMetadata:        "Trading Strategy",
            strategyDelegateFeeRate: 0,
            strategyProtocolFeeRate: 0
        }));
    }

    function test_deploy_revert_invalidStrategyDelegate() external {
        address notDelegate = makeAddr("notDelegate");

        vm.prank(notDelegate);
        vm.expectRevert("MSD:D:INVALID_SD");
        strategyDeployer.deploy(strategyManagerFactory, tradingStrategyFactory, deploymentData);
    }

    function test_deploy_revert_invalidStrategyManagerFactory() external {
        address invalidStrategyManagerFactory = makeAddr("invalidStrategyManagerFactory");

        vm.prank(strategyDelegate);
        vm.expectRevert("MSD:D:INVALID_SM_FACTORY");
        strategyDeployer.deploy(invalidStrategyManagerFactory, tradingStrategyFactory, deploymentData);
    }

    function test_deploy_revert_invalidStrategyFactory() external {
        address invalidStrategyFactory = makeAddr("invalidStrategyFactory");

        vm.prank(strategyDelegate);
        vm.expectRevert("MSD:D:INVALID_STRATEGY_FACTORY");
        strategyDeployer.deploy(strategyManagerFactory, invalidStrategyFactory, deploymentData);
    }

    function test_deploy_revert_cannotDeployStrategyManager() external {
        vm.prank(governor);
        globals.setCanDeployFrom(strategyManagerFactory, address(strategyDeployer), false);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSMF:CI:CANNOT_DEPLOY");
        strategyDeployer.deploy(strategyManagerFactory, tradingStrategyFactory, deploymentData);
    }

    function test_deploy_revert_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(strategyDelegate);
        vm.expectRevert("MPF:PROTOCOL_PAUSED");
        strategyDeployer.deploy(strategyManagerFactory, tradingStrategyFactory, deploymentData);
    }

    function test_deploy_revert_strategyManagerFactoryWithoutDefaultVersion() external {
        address freshFactory = deployFromFile("Contracts@28", "StrategyManagerFactory", abi.encode(address(globals)));

        vm.startPrank(governor);
        globals.setValidInstanceOf("STRATEGY_MANAGER_FACTORY", freshFactory, true);
        globals.setCanDeployFrom(freshFactory, address(strategyDeployer), true);
        vm.stopPrank();

        vm.prank(strategyDelegate);
        vm.expectRevert(freshFactory);
        strategyDeployer.deploy(freshFactory, tradingStrategyFactory, deploymentData);
    }

    function test_deploy_revert_duplicateDeployment() external {
        vm.prank(strategyDelegate);
        strategyDeployer.deploy(strategyManagerFactory, tradingStrategyFactory, deploymentData);

        vm.prank(strategyDelegate);
        vm.expectRevert(strategyManagerFactory);
        strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, deploymentData);
    }

    function test_deploy_revert_setUnderlyingStrategyPaused() external {
        ( address strategyManager, ) =
            strategyDeployer.getDeploymentAddresses(strategyDelegate, strategyManagerFactory, tradingStrategyFactory, deploymentData);

        vm.startPrank(governor);
        globals.setContractPause(strategyManager, true);
        globals.setFunctionUnpause(strategyManager, bytes4(keccak256("migrate(address,bytes)")),  true);
        vm.stopPrank();

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PAUSED");
        strategyDeployer.deploy(strategyManagerFactory, tradingStrategyFactory, deploymentData);
    }

    function test_deploy_revert_completeConfigurationPaused() external {
        ( address strategyManager, ) =
            strategyDeployer.getDeploymentAddresses(strategyDelegate, strategyManagerFactory, tradingStrategyFactory, deploymentData);

        vm.startPrank(governor);
        globals.setContractPause(strategyManager, true);
        globals.setFunctionUnpause(strategyManager, bytes4(keccak256("migrate(address,bytes)")),         true);
        globals.setFunctionUnpause(strategyManager, bytes4(keccak256("setUnderlyingStrategy(address)")), true);
        vm.stopPrank();

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:PAUSED");
        strategyDeployer.deploy(strategyManagerFactory, tradingStrategyFactory, deploymentData);
    }

}

contract TradingStrategyDeployTests is TestBase {

    function test_deploy_revert_cannotDeployUnderlyingStrategy() external {
        vm.prank(governor);
        globals.setCanDeployFrom(tradingStrategyFactory, address(strategyDeployer), false);

        bytes memory data = abi.encode(TradingStrategyInitializerParams({
            fundsAsset:              address(fundsAsset),
            strategyMetadata:        "Trading Strategy",
            strategyDelegateFeeRate: 0,
            strategyProtocolFeeRate: 0
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MTSF:CI:CANNOT_DEPLOY");
        strategyDeployer.deploy(strategyManagerFactory, tradingStrategyFactory, data);
    }

    function test_deploy_revert_invalidAsset() external {
        bytes memory data = abi.encode(TradingStrategyInitializerParams({
            fundsAsset:              makeAddr("notPoolAsset"),
            strategyMetadata:        "Trading Strategy",
            strategyDelegateFeeRate: 0,
            strategyProtocolFeeRate: 0
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        strategyDeployer.deploy(strategyManagerFactory, tradingStrategyFactory, data);
    }

    function test_deploy_revert_invalidFeeRateSum() external {
        bytes memory data = abi.encode(TradingStrategyInitializerParams({
            fundsAsset:              address(fundsAsset),
            strategyMetadata:        "Trading Strategy",
            strategyDelegateFeeRate: 0.5e6,      // 50% Fee
            strategyProtocolFeeRate: 0.5e6 + 1   // 50.0001% Fee
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        strategyDeployer.deploy(strategyManagerFactory, tradingStrategyFactory, data);
    }

    function test_deploy_success() external {
        bytes memory data = abi.encode(TradingStrategyInitializerParams({
            fundsAsset:              address(fundsAsset),
            strategyMetadata:        "Trading Strategy",
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6   // 0.2% Fee
        }));

        (
            address expectedStrategyManager,
            address expectedUnderlyingStrategy
        ) = strategyDeployer.getDeploymentAddresses(strategyDelegate, strategyManagerFactory, tradingStrategyFactory, data);

        vm.prank(strategyDelegate);

        (
            address tradingStrategyManager_,
            address tradingUnderlyingStrategy_ 
        ) = strategyDeployer.deploy(strategyManagerFactory, tradingStrategyFactory, data);

        assertEq(tradingStrategyManager_,    expectedStrategyManager);
        assertEq(tradingUnderlyingStrategy_, expectedUnderlyingStrategy);

        assertEq(IMapleProxyFactory(strategyManagerFactory).isInstance(tradingStrategyManager_),    true);
        assertEq(IMapleProxyFactory(tradingStrategyFactory).isInstance(tradingUnderlyingStrategy_), true);

        assertEq(IStrategyManager(tradingStrategyManager_).globals(),                 address(globals));
        assertEq(IStrategyManager(tradingStrategyManager_).factory(),                 strategyManagerFactory);
        assertEq(IStrategyManager(tradingStrategyManager_).strategyDelegate(),        strategyDelegate);
        assertEq(IStrategyManager(tradingStrategyManager_).pendingStrategyDelegate(), address(0));
        assertEq(IStrategyManager(tradingStrategyManager_).underlyingStrategy(),      tradingUnderlyingStrategy_);
        assertEq(IStrategyManager(tradingStrategyManager_).strategyLiquidityCap(),    0);
        assertEq(IStrategyManager(tradingStrategyManager_).totalShares(),             0);
        assertEq(IStrategyManager(tradingStrategyManager_).totalPendingShares(),      0);
        assertEq(IStrategyManager(tradingStrategyManager_).assetsUnderManagement(),   0);

        assertEq(IStrategyManager(tradingStrategyManager_).configured(), true);
        assertEq(IStrategyManager(tradingStrategyManager_).active(),     false);

        assertEq(ITradingStrategy(tradingUnderlyingStrategy_).strategyManager(),         tradingStrategyManager_);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy_).fundsAsset(),              address(fundsAsset));
        assertEq(ITradingStrategy(tradingUnderlyingStrategy_).strategyMetadata(),        "Trading Strategy");
        assertEq(ITradingStrategy(tradingUnderlyingStrategy_).strategyDelegateFeeRate(), 0.001e6);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy_).strategyProtocolFeeRate(), 0.002e6);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy_).impairedAssets(),          0);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy_).scheduledYieldAssets(),    0);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy_).totalDeployedAssets(),     0);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy_).yieldDeadline(),           0);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy_).yieldStart(),              0);
    }

    function test_deploy_success_multipleDelegates() external {
        address strategyDelegate1 = makeAddr("strategyDelegate1");
        address strategyDelegate2 = makeAddr("strategyDelegate2");

        vm.startPrank(governor);
        globals.setValidStrategyDelegate(strategyDelegate1, true);
        globals.setValidStrategyDelegate(strategyDelegate2, true);
        vm.stopPrank();

        bytes memory data = abi.encode(TradingStrategyInitializerParams({
            fundsAsset:              address(fundsAsset),
            strategyMetadata:        "Trading Strategy",
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6   // 0.2% Fee
        }));

        (
            address expectedStrategyManager1,
            address expectedUnderlyingStrategy1
        ) = strategyDeployer.getDeploymentAddresses(strategyDelegate1, strategyManagerFactory, tradingStrategyFactory, data);

        (
            address expectedStrategyManager2,
            address expectedUnderlyingStrategy2
        ) = strategyDeployer.getDeploymentAddresses(strategyDelegate2, strategyManagerFactory, tradingStrategyFactory, data);

        vm.prank(strategyDelegate1);

        (
            address tradingStrategyManager1,
            address tradingUnderlyingStrategy1
        ) = strategyDeployer.deploy(strategyManagerFactory, tradingStrategyFactory, data);

        vm.prank(strategyDelegate2);

        (
            address tradingStrategyManager2,
            address tradingUnderlyingStrategy2
        ) = strategyDeployer.deploy(strategyManagerFactory, tradingStrategyFactory, data);

        assertEq(tradingStrategyManager1,    expectedStrategyManager1);
        assertEq(tradingStrategyManager2,    expectedStrategyManager2);
        assertEq(tradingUnderlyingStrategy1, expectedUnderlyingStrategy1);
        assertEq(tradingUnderlyingStrategy2, expectedUnderlyingStrategy2);

        assertNotEq(tradingStrategyManager1,    tradingStrategyManager2);
        assertNotEq(tradingUnderlyingStrategy1, tradingUnderlyingStrategy2);

        assertEq(IMapleProxyFactory(strategyManagerFactory).isInstance(tradingStrategyManager1),    true);
        assertEq(IMapleProxyFactory(strategyManagerFactory).isInstance(tradingStrategyManager2),    true);
        assertEq(IMapleProxyFactory(tradingStrategyFactory).isInstance(tradingUnderlyingStrategy1), true);
        assertEq(IMapleProxyFactory(tradingStrategyFactory).isInstance(tradingUnderlyingStrategy2), true);

        assertEq(IStrategyManager(tradingStrategyManager1).strategyDelegate(),      strategyDelegate1);
        assertEq(IStrategyManager(tradingStrategyManager1).underlyingStrategy(),    tradingUnderlyingStrategy1);
        assertEq(IStrategyManager(tradingStrategyManager1).configured(),            true);
        assertEq(IStrategyManager(tradingStrategyManager1).active(),                false);
        assertEq(IStrategyManager(tradingStrategyManager1).assetsUnderManagement(), 0);

        assertEq(IStrategyManager(tradingStrategyManager2).strategyDelegate(),      strategyDelegate2);
        assertEq(IStrategyManager(tradingStrategyManager2).underlyingStrategy(),    tradingUnderlyingStrategy2);
        assertEq(IStrategyManager(tradingStrategyManager2).configured(),            true);
        assertEq(IStrategyManager(tradingStrategyManager2).active(),                false);
        assertEq(IStrategyManager(tradingStrategyManager2).assetsUnderManagement(), 0);

        assertEq(ITradingStrategy(tradingUnderlyingStrategy1).strategyManager(),         tradingStrategyManager1);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy1).fundsAsset(),              address(fundsAsset));
        assertEq(ITradingStrategy(tradingUnderlyingStrategy1).strategyMetadata(),        "Trading Strategy");
        assertEq(ITradingStrategy(tradingUnderlyingStrategy1).strategyDelegateFeeRate(), 0.001e6);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy1).strategyProtocolFeeRate(), 0.002e6);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy1).impairedAssets(),          0);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy1).scheduledYieldAssets(),    0);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy1).totalDeployedAssets(),     0);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy1).yieldDeadline(),           0);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy1).yieldStart(),              0);

        assertEq(ITradingStrategy(tradingUnderlyingStrategy2).strategyManager(),         tradingStrategyManager2);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy2).fundsAsset(),              address(fundsAsset));
        assertEq(ITradingStrategy(tradingUnderlyingStrategy2).strategyMetadata(),        "Trading Strategy");
        assertEq(ITradingStrategy(tradingUnderlyingStrategy2).strategyDelegateFeeRate(), 0.001e6);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy2).strategyProtocolFeeRate(), 0.002e6);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy2).impairedAssets(),          0);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy2).scheduledYieldAssets(),    0);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy2).totalDeployedAssets(),     0);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy2).yieldDeadline(),           0);
        assertEq(ITradingStrategy(tradingUnderlyingStrategy2).yieldStart(),              0);
    }

}

contract AaveV3StrategyDeployTests is TestBase {

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
        globals.setCanDeployFrom(aaveV3StrategyFactory, address(strategyDeployer), false);

        bytes memory data = abi.encode(AaveV3StrategyInitializerParams({
            aaveToken:               AAVE_USDC,
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6,  // 0.2% Fee
            referralCode:            0
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MAV3SF:CI:CANNOT_DEPLOY");
        strategyDeployer.deploy(strategyManagerFactory, aaveV3StrategyFactory, data);
    }

    function test_deploy_revert_zeroAaveToken() external {
        bytes memory data = abi.encode(AaveV3StrategyInitializerParams({
            aaveToken:               address(0),
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6,  // 0.2% Fee
            referralCode:            0
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        strategyDeployer.deploy(strategyManagerFactory, aaveV3StrategyFactory, data);
    }

    function test_deploy_revert_invalidFeeRateSum() external {
        bytes memory data = abi.encode(AaveV3StrategyInitializerParams({
            aaveToken:               AAVE_USDC,
            strategyDelegateFeeRate: 0.5e6,      // 50% Fee
            strategyProtocolFeeRate: 0.5e6 + 1,  // 50.0001% Fee
            referralCode:            0
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        strategyDeployer.deploy(strategyManagerFactory, aaveV3StrategyFactory, data);
    }

    function test_deploy_revert_invalidStrategyVault() external {
        bytes memory data = abi.encode(AaveV3StrategyInitializerParams({
            aaveToken:               AAVE_USDC,
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6,  // 0.2% Fee
            referralCode:            0
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        strategyDeployer.deploy(strategyManagerFactory, aaveV3StrategyFactory, data);
    }

    function test_deploy_revert_invalidAsset() external {
        vm.startPrank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", AAVE_USDC, true);
        globals.setValidPoolAsset(USDC, false);
        vm.stopPrank();

        bytes memory data = abi.encode(AaveV3StrategyInitializerParams({
            aaveToken:               AAVE_USDC,
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6,  // 0.2% Fee
            referralCode:            0
        }));

        vm.prank(strategyDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        strategyDeployer.deploy(strategyManagerFactory, aaveV3StrategyFactory, data);
    }

    function test_deploy_success() external {
        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", AAVE_USDC, true);

        bytes memory data = abi.encode(AaveV3StrategyInitializerParams({
            aaveToken:               AAVE_USDC,
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6,  // 0.2% Fee
            referralCode:            7
        }));

        (
            address expectedStrategyManager,
            address expectedUnderlyingStrategy
        ) = strategyDeployer.getDeploymentAddresses(strategyDelegate, strategyManagerFactory, aaveV3StrategyFactory, data);

        vm.prank(strategyDelegate);

        (
            address aaveStrategyManager_,
            address aaveUnderlyingStrategy_ 
        ) = strategyDeployer.deploy(strategyManagerFactory, aaveV3StrategyFactory, data);

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

        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).strategyManager(),         aaveStrategyManager_);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).aaveToken(),               AAVE_USDC);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).fundsAsset(),              USDC);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).strategyDelegateFeeRate(), 0.001e6);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).strategyProtocolFeeRate(), 0.002e6);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).referralCode(),            7);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).impairedAssets(),          0);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).lastRecordedTotalAssets(), 0);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy_).isLossRecognized(),        false);

        assertNotEq(IAaveV3Strategy(aaveUnderlyingStrategy_).aavePool(), address(0));
    }

    function test_deploy_success_multipleDelegates() external {
        address strategyDelegate1 = makeAddr("strategyDelegate1");
        address strategyDelegate2 = makeAddr("strategyDelegate2");

        vm.startPrank(governor);
        globals.setValidStrategyDelegate(strategyDelegate1, true);
        globals.setValidStrategyDelegate(strategyDelegate2, true);
        globals.setValidInstanceOf("STRATEGY_VAULT", AAVE_USDC, true);
        vm.stopPrank();

        bytes memory data = abi.encode(AaveV3StrategyInitializerParams({
            aaveToken:               AAVE_USDC,
            strategyDelegateFeeRate: 0.001e6,  // 0.1% Fee
            strategyProtocolFeeRate: 0.002e6,  // 0.2% Fee
            referralCode:            7
        }));

        (
            address expectedStrategyManager1,
            address expectedUnderlyingStrategy1
        ) = strategyDeployer.getDeploymentAddresses(strategyDelegate1, strategyManagerFactory, aaveV3StrategyFactory, data);

        (
            address expectedStrategyManager2,
            address expectedUnderlyingStrategy2
        ) = strategyDeployer.getDeploymentAddresses(strategyDelegate2, strategyManagerFactory, aaveV3StrategyFactory, data);

        vm.prank(strategyDelegate1);

        (
            address aaveStrategyManager1,
            address aaveUnderlyingStrategy1 
        ) = strategyDeployer.deploy(strategyManagerFactory, aaveV3StrategyFactory, data);

        vm.prank(strategyDelegate2);

        (
            address aaveStrategyManager2,
            address aaveUnderlyingStrategy2
        ) = strategyDeployer.deploy(strategyManagerFactory, aaveV3StrategyFactory, data);

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

        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy1).strategyManager(),         aaveStrategyManager1);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy1).aaveToken(),               AAVE_USDC);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy1).fundsAsset(),              USDC);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy1).strategyDelegateFeeRate(), 0.001e6);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy1).strategyProtocolFeeRate(), 0.002e6);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy1).referralCode(),            7);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy1).impairedAssets(),          0);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy1).lastRecordedTotalAssets(), 0);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy1).isLossRecognized(),        false);

        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy2).strategyManager(),         aaveStrategyManager2);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy2).aaveToken(),               AAVE_USDC);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy2).fundsAsset(),              USDC);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy2).strategyDelegateFeeRate(), 0.001e6);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy2).strategyProtocolFeeRate(), 0.002e6);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy2).referralCode(),            7);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy2).impairedAssets(),          0);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy2).lastRecordedTotalAssets(), 0);
        assertEq(IAaveV3Strategy(aaveUnderlyingStrategy2).isLossRecognized(),        false);
    }

}

contract SkyStrategyDeployTests is TestBase {

    address constant SDAI = 0x83F20F44975D03b1b09e64809B757c47f942BEeA;  // sDAI (asset: DAI), a real ERC4626 whose asset differs from the PSM's usds.

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
        strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, data);
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
        strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, data);
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
        strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, data);
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
        strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, data);
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
        strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, data);
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
        strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, data);
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
        strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, data);
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
        strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, data);
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
        strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, data);
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

        (
            address expectedStrategyManager,
            address expectedUnderlyingStrategy
        ) = strategyDeployer.getDeploymentAddresses(strategyDelegate, strategyManagerFactory, skyStrategyFactory, data);

        vm.prank(strategyDelegate);

        (
            address skyStrategyManager_,
            address skyUnderlyingStrategy_ 
        ) = strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, data);

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

        (
            address expectedStrategyManager1,
            address expectedUnderlyingStrategy1
        ) = strategyDeployer.getDeploymentAddresses(strategyDelegate1, strategyManagerFactory, skyStrategyFactory, data);

        (
            address expectedStrategyManager2,
            address expectedUnderlyingStrategy2
        ) = strategyDeployer.getDeploymentAddresses(strategyDelegate2, strategyManagerFactory, skyStrategyFactory, data);

        vm.prank(strategyDelegate1);

        (
            address skyStrategyManager1,
            address skyUnderlyingStrategy1
        ) = strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, data);

        vm.prank(strategyDelegate2);

        (
            address skyStrategyManager2,
            address skyUnderlyingStrategy2
        ) = strategyDeployer.deploy(strategyManagerFactory, skyStrategyFactory, data);

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

        assertEq(ISkyStrategy(skyUnderlyingStrategy1).strategyManager(),          skyStrategyManager1);
        assertEq(ISkyStrategy(skyUnderlyingStrategy1).fundsAsset(),               USDC);
        assertEq(ISkyStrategy(skyUnderlyingStrategy1).psm(),                      USDS_LITE_PSM);
        assertEq(ISkyStrategy(skyUnderlyingStrategy1).savingsUsds(),              SAVINGS_USDS);
        assertEq(ISkyStrategy(skyUnderlyingStrategy1).usds(),                     USDS);
        assertEq(ISkyStrategy(skyUnderlyingStrategy1).strategyDelegateFeeRate(),  0.001e6);
        assertEq(ISkyStrategy(skyUnderlyingStrategy1).strategyProtocolFeeRate(),  0.002e6);
        assertEq(ISkyStrategy(skyUnderlyingStrategy1).referralCode(),             7);
        assertEq(ISkyStrategy(skyUnderlyingStrategy1).fallbackTout(),             0);
        assertEq(ISkyStrategy(skyUnderlyingStrategy1).impairedAssets(),           0);
        assertEq(ISkyStrategy(skyUnderlyingStrategy1).lastRecordedTotalAssets(),  0);
        assertEq(ISkyStrategy(skyUnderlyingStrategy1).isLossRecognized(),         false);

        assertEq(ISkyStrategy(skyUnderlyingStrategy2).strategyManager(),          skyStrategyManager2);
        assertEq(ISkyStrategy(skyUnderlyingStrategy2).fundsAsset(),               USDC);
        assertEq(ISkyStrategy(skyUnderlyingStrategy2).psm(),                      USDS_LITE_PSM);
        assertEq(ISkyStrategy(skyUnderlyingStrategy2).savingsUsds(),              SAVINGS_USDS);
        assertEq(ISkyStrategy(skyUnderlyingStrategy2).usds(),                     USDS);
        assertEq(ISkyStrategy(skyUnderlyingStrategy2).strategyDelegateFeeRate(),  0.001e6);
        assertEq(ISkyStrategy(skyUnderlyingStrategy2).strategyProtocolFeeRate(),  0.002e6);
        assertEq(ISkyStrategy(skyUnderlyingStrategy2).referralCode(),             7);
        assertEq(ISkyStrategy(skyUnderlyingStrategy2).fallbackTout(),             0);
        assertEq(ISkyStrategy(skyUnderlyingStrategy2).impairedAssets(),           0);
        assertEq(ISkyStrategy(skyUnderlyingStrategy2).lastRecordedTotalAssets(),  0);
        assertEq(ISkyStrategy(skyUnderlyingStrategy2).isLossRecognized(),         false);
    }

}
