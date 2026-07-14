// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IMapleProxyFactory,
    IPoolManager,
    ITradingStrategy,
    PoolConfigParams,
    PoolManagerInitParams,
    StrategyDeployParams,
    StrategyManagerParams
} from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract DeployPoolTestBase is TestBaseWithAssertions {

    uint256 constant INITIAL_SUPPLY = 1_000e6;
    uint256 constant LIQUIDITY_CAP  = 1_000_000e6;
    uint256 constant MANAGEMENT_FEE = 0.1e6;  // 10% fee

    function setUp() public virtual override {
        _deployProtocol();
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function createPoolManagerInitParams(address asset, uint256 initialSupply) internal pure returns (PoolManagerInitParams memory params) {
        params = PoolManagerInitParams({
            asset:         asset,
            initialSupply: initialSupply,
            name:          POOL_NAME,
            symbol:        POOL_SYMBOL
        });
    }

    function createPoolConfigParams() internal view returns (PoolConfigParams memory params) {
        params = PoolConfigParams({
            poolPermissionManager:     address(poolPermissionManager),
            delegateManagementFeeRate: MANAGEMENT_FEE,
            liquidityCap:              LIQUIDITY_CAP
        });
    }

    function createOtlmStrategyParam(uint256 cap, bytes32 salt) internal view returns (StrategyDeployParams memory strategy) {
        strategy = StrategyDeployParams({
            factory:        openTermLoanManagerFactory,
            cap:            cap,
            salt:           salt,
            deploymentData: abi.encode(new bytes(0))
        });
    }

    function createOtlmStrategyParams(uint256 cap) internal view returns (StrategyDeployParams[] memory strategies) {
        strategies    = new StrategyDeployParams[](1);
        strategies[0] = createOtlmStrategyParam(cap, keccak256(abi.encode(POOL_NAME, uint256(0))));
    }

    function createStrategyManagerParams(address strategyManager, uint256 cap) internal pure
        returns (StrategyManagerParams[] memory managers)
    {
        managers    = new StrategyManagerParams[](1);
        managers[0] = StrategyManagerParams({
            instance: strategyManager,
            cap:      cap
        });
    }

    function createStrategyManagerParams(
        address strategyManager0,
        uint256 cap0,
        address strategyManager1,
        uint256 cap1
    )
        internal pure returns (StrategyManagerParams[] memory managers)
    {
        managers    = new StrategyManagerParams[](2);
        managers[0] = StrategyManagerParams({
            instance: strategyManager0,
            cap:      cap0
        });
        managers[1] = StrategyManagerParams({
            instance: strategyManager1,
            cap:      cap1
        });
    }

}

contract DeployPoolRevertTests is DeployPoolTestBase {

    function test_deployPool_revert_invalidPD() external {
        vm.prank(makeAddr("invalidPD"));
        vm.expectRevert("PD:DP:INVALID_PD");
        poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), 0),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         new StrategyDeployParams[](0),
            strategyManagersParams:   new StrategyManagerParams[](0)
        });
    }

    function test_deployPool_revert_notPoolDeployer() external {
        vm.prank(governor);
        globals.setCanDeployFrom(poolManagerFactory, address(poolDeployer), false);

        vm.prank(poolDelegate);
        vm.expectRevert("PMF:CI:NOT_DEPLOYER");
        poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), 0),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         new StrategyDeployParams[](0),
            strategyManagersParams:   new StrategyManagerParams[](0)
        });
    }

    function test_deployPool_revert_protocolPaused() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(poolDelegate);
        vm.expectRevert("MPF:PROTOCOL_PAUSED");
        poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), 0),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         new StrategyDeployParams[](0),
            strategyManagersParams:   new StrategyManagerParams[](0)
        });
    }

    function test_createInstance_revert_directPoolManagerFactoryCall() external {
        vm.expectRevert("PMF:CI:NOT_DEPLOYER");
        IMapleProxyFactory(poolManagerFactory).createInstance(
            abi.encode(poolDelegate, address(fundsAsset), 0, POOL_NAME, POOL_SYMBOL),
            keccak256(abi.encode(poolDelegate))
        );
    }

    function test_createInstance_revert_directWithdrawalManagerFactoryCall() external {
        vm.expectRevert("WMF:CI:CANNOT_DEPLOY");
        IMapleProxyFactory(queueWMFactory).createInstance(abi.encode(makeAddr("pool")), "SALT");
    }

    function test_createInstance_revert_directOpenTermLoanManagerFactoryCall() external {
        ( address tradingStrategyManager_, ) = _deployTradingStrategyFor(strategyDelegate);

        vm.prank(tradingStrategyManager_);
        vm.expectRevert("LMF:CI:CANNOT_DEPLOY");
        IMapleProxyFactory(openTermLoanManagerFactory).createInstance(abi.encode(makeAddr("poolManager")), "SALT");
    }

    function test_deployPool_revert_invalidPMFactory() external {
        vm.prank(governor);
        globals.setValidInstanceOf("POOL_MANAGER_FACTORY", poolManagerFactory, false);

        vm.prank(poolDelegate);
        vm.expectRevert("PD:DP:INVALID_PM_FACTORY");
        poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), 0),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         new StrategyDeployParams[](0),
            strategyManagersParams:   new StrategyManagerParams[](0)
        });
    }

    function test_deployPool_revert_invalidWMFactory() external {
        vm.prank(governor);
        globals.setValidInstanceOf("WITHDRAWAL_MANAGER_QUEUE_FACTORY", queueWMFactory, false);

        vm.prank(poolDelegate);
        vm.expectRevert("PD:DP:INVALID_WM_FACTORY");
        poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), 0),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         new StrategyDeployParams[](0),
            strategyManagersParams:   new StrategyManagerParams[](0)
        });
    }

    function test_deployPool_revert_wmCannotDeploy() external {
        vm.prank(governor);
        globals.setCanDeployFrom(queueWMFactory, address(poolDeployer), false);

        vm.prank(poolDelegate);
        vm.expectRevert("WMF:CI:CANNOT_DEPLOY");
        poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), 0),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         new StrategyDeployParams[](0),
            strategyManagersParams:   new StrategyManagerParams[](0)
        });
    }

    function test_deployPool_revert_invalidPPM() external {
        vm.prank(governor);
        globals.setValidInstanceOf("POOL_PERMISSION_MANAGER", address(poolPermissionManager), false);

        vm.prank(poolDelegate);
        vm.expectRevert("PD:DP:INVALID_PPM");
        poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), 0),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         new StrategyDeployParams[](0),
            strategyManagersParams:   new StrategyManagerParams[](0)
        });
    }

    function test_deployPool_revert_zeroAsset() external {
        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(0), 0),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         new StrategyDeployParams[](0),
            strategyManagersParams:   new StrategyManagerParams[](0)
        });
    }

    function test_deployPool_revert_poolDelegateAlreadyOwnsAnotherPool() external {
        address secondPoolManagerFactory = deployFromFile("Contracts@7", "PoolManagerFactory", abi.encode(address(globals)));

        vm.startPrank(governor);
        globals.setValidInstanceOf("POOL_MANAGER_FACTORY", secondPoolManagerFactory, true);
        globals.setCanDeployFrom(secondPoolManagerFactory, address(poolDeployer), true);
        IMapleProxyFactory(secondPoolManagerFactory).registerImplementation(1, poolManagerImplementation, poolManagerInitializer);
        IMapleProxyFactory(secondPoolManagerFactory).setDefaultVersion(1);
        vm.stopPrank();

        vm.prank(poolDelegate);
        address firstPoolManager = poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), 0),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         new StrategyDeployParams[](0),
            strategyManagersParams:   new StrategyManagerParams[](0)
        });

        activatePoolManager(firstPoolManager);

        assertEq(globals.ownedPoolManager(poolDelegate), firstPoolManager);

        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        poolDeployer.deployPool({
            poolManagerFactory:       secondPoolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), 0),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         new StrategyDeployParams[](0),
            strategyManagersParams:   new StrategyManagerParams[](0)
        });
    }

    function test_deployPool_revert_poolManagerSaltCollision() external {
        vm.prank(poolDelegate);
        poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), 0),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         new StrategyDeployParams[](0),
            strategyManagersParams:   new StrategyManagerParams[](0)
        });

        vm.prank(poolDelegate);
        vm.expectRevert();
        poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), 0),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         new StrategyDeployParams[](0),
            strategyManagersParams:   new StrategyManagerParams[](0)
        });
    }

    function test_deployPool_revert_poolAssetNotAllowed() external {
        vm.prank(governor);
        globals.setValidPoolAsset(address(fundsAsset), false);

        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), 0),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         new StrategyDeployParams[](0),
            strategyManagersParams:   new StrategyManagerParams[](0)
        });
    }

    function test_deployPool_revert_nonZeroSupplyAndZeroMigrationAdmin() external {
        vm.prank(governor);
        globals.setMigrationAdmin(address(0));

        vm.prank(poolDelegate);
        vm.expectRevert("MPF:CI:FAILED");
        poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), INITIAL_SUPPLY),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         new StrategyDeployParams[](0),
            strategyManagersParams:   new StrategyManagerParams[](0)
        });
    }

    function test_deployPool_revert_invalidStrategyFactory() external {
        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_FACTORY", openTermLoanManagerFactory, false);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:AS:INVALID_FACTORY");
        poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), 0),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         createOtlmStrategyParams(type(uint256).max),
            strategyManagersParams:   new StrategyManagerParams[](0)
        });
    }

    function test_deployPool_revert_invalidStrategyManager() external {
        ( address tradingStrategyManager_, ) = _deployTradingStrategyFor(strategyDelegate);

        vm.prank(governor);
        globals.setValidInstanceOf("STRATEGY_MANAGER_FACTORY", strategyManagerFactory, false);

        StrategyManagerParams[] memory managers = createStrategyManagerParams(tradingStrategyManager_, type(uint256).max);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:ASM:INVALID_STRATEGY_MANAGER");
        poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), 0),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         new StrategyDeployParams[](0),
            strategyManagersParams:   managers
        });
    }

    function test_deployPool_revert_duplicateStrategyManager() external {
        ( address tradingStrategyManager_, ) = _deployTradingStrategyFor(strategyDelegate);

        StrategyManagerParams[] memory managers = createStrategyManagerParams(
            tradingStrategyManager_,
            type(uint256).max,
            tradingStrategyManager_,
            type(uint256).max
        );

        vm.prank(poolDelegate);
        vm.expectRevert("PM:ASM:ALREADY_STRATEGY_MANAGER");
        poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), 0),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         new StrategyDeployParams[](0),
            strategyManagersParams:   managers
        });
    }

    function test_deployPool_revert_strategyManagerAssetNotSupported() external {
        ( address tradingStrategyManager_, address underlyingStrategy ) = _deployTradingStrategyFor(strategyDelegate);

        assertEq(ITradingStrategy(underlyingStrategy).fundsAsset(), address(fundsAsset));

        vm.prank(governor);
        globals.setValidPoolAsset(address(collateralAsset), true);

        StrategyManagerParams[] memory managers = createStrategyManagerParams(tradingStrategyManager_, type(uint256).max);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:ASM:ASSET_NOT_SUPPORTED");
        poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(collateralAsset), 0),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         new StrategyDeployParams[](0),
            strategyManagersParams:   managers
        });
    }

    function test_deployPool_revert_invalidManagementFeeRate() external {
        uint256 invalidManagementFee = HUNDRED_PERCENT + 1;  // >100% fee

        vm.prank(poolDelegate);
        vm.expectRevert("PM:SDMFR:OOB");
        poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), 0),
            poolConfigParams:         PoolConfigParams({
                poolPermissionManager:     address(poolPermissionManager),
                delegateManagementFeeRate: invalidManagementFee,
                liquidityCap:              LIQUIDITY_CAP
            }),
            strategiesParams:         new StrategyDeployParams[](0),
            strategyManagersParams:   new StrategyManagerParams[](0)
        });
    }

    function test_deployPool_revert_zeroGlobals() external {
        vm.expectRevert("PD:C:ZERO_ADDRESS");
        deploy("MaplePoolDeployer", abi.encode(address(0)));
    }

}

contract DeployPoolSuccessTests is DeployPoolTestBase {

    function test_deployPool_success_otlmOnly() external {
        StrategyDeployParams[] memory strategies = createOtlmStrategyParams(type(uint256).max);

        vm.prank(poolDelegate);
        address poolManager_ = poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), 0),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         strategies,
            strategyManagersParams:   new StrategyManagerParams[](0)
        });

        ( IPoolManager pm, ) = assertDeployedPool({
            poolManager_:               poolManager_,
            initialSupply_:             0,
            liquidityCap_:              LIQUIDITY_CAP,
            delegateManagementFeeRate_: MANAGEMENT_FEE,
            strategyListLength_:        1
        });

        address otlm = pm.strategyList(0);

        address[] memory factories      = new address[](1);
        bytes[]   memory deploymentData = new bytes[](1);
        bytes32[] memory salts          = new bytes32[](1);

        factories[0]      = openTermLoanManagerFactory;
        deploymentData[0] = abi.encode(new bytes(0));
        salts[0]          = keccak256(abi.encode(POOL_NAME, uint256(0)));

        address[] memory expectedStrategies = poolDeployer.getStrategiesAddresses(poolManager_, factories, deploymentData, salts);

        assertEq(otlm, expectedStrategies[0]);

        assertEq(pm.isStrategy(otlm),        true);
        assertEq(pm.isStrategyManager(otlm), false);
        assertEq(pm.strategyCapOf(otlm),     type(uint256).max);

        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).isInstance(otlm), true);
    }

    function test_deployPool_success_multipleOtlms() external {
        uint256 finiteCap = 500_000e6;

        bytes32 salt0 = keccak256(abi.encode(POOL_NAME, uint256(0)));
        bytes32 salt1 = keccak256(abi.encode(POOL_NAME, uint256(1)));

        StrategyDeployParams[] memory strategies = new StrategyDeployParams[](2);

        strategies[0] = createOtlmStrategyParam(type(uint256).max, salt0);
        strategies[1] = createOtlmStrategyParam(finiteCap, salt1);

        vm.prank(poolDelegate);
        address poolManager_ = poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), 0),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         strategies,
            strategyManagersParams:   new StrategyManagerParams[](0)
        });

        ( IPoolManager pm, ) = assertDeployedPool({
            poolManager_:               poolManager_,
            initialSupply_:             0,
            liquidityCap_:              LIQUIDITY_CAP,
            delegateManagementFeeRate_: MANAGEMENT_FEE,
            strategyListLength_:        2
        });

        address otlm0 = pm.strategyList(0);
        address otlm1 = pm.strategyList(1);

        address[] memory factories      = new address[](2);
        bytes[]   memory deploymentData = new bytes[](2);
        bytes32[] memory salts          = new bytes32[](2);

        factories[0]      = openTermLoanManagerFactory;
        factories[1]      = openTermLoanManagerFactory;
        deploymentData[0] = abi.encode(new bytes(0));
        deploymentData[1] = abi.encode(new bytes(0));
        salts[0]          = salt0;
        salts[1]          = salt1;

        address[] memory expectedStrategies = poolDeployer.getStrategiesAddresses(poolManager_, factories, deploymentData, salts);

        assertEq(otlm0, expectedStrategies[0]);
        assertEq(otlm1, expectedStrategies[1]);

        assertEq(pm.isStrategy(otlm0),        true);
        assertEq(pm.isStrategy(otlm1),        true);
        assertEq(pm.isStrategyManager(otlm0), false);
        assertEq(pm.isStrategyManager(otlm1), false);
        assertEq(pm.strategyCapOf(otlm0),     type(uint256).max);
        assertEq(pm.strategyCapOf(otlm1),     finiteCap);

        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).isInstance(otlm0), true);
        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).isInstance(otlm1), true);
    }

    function test_deployPool_success_otlmAndModularStrategy() external {
        ( address tradingStrategyManager_, ) = _deployTradingStrategyFor(strategyDelegate);

        StrategyDeployParams[]  memory strategies = createOtlmStrategyParams(type(uint256).max);
        StrategyManagerParams[] memory managers   = createStrategyManagerParams(tradingStrategyManager_, type(uint256).max);

        vm.prank(poolDelegate);
        address poolManager_ = poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), 0),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         strategies,
            strategyManagersParams:   managers
        });

        ( IPoolManager pm, ) = assertDeployedPool({
            poolManager_:               poolManager_,
            initialSupply_:             0,
            liquidityCap_:              LIQUIDITY_CAP,
            delegateManagementFeeRate_: MANAGEMENT_FEE,
            strategyListLength_:        2
        });

        address otlm = pm.strategyList(0);

        assertEq(pm.isStrategy(otlm),        true);
        assertEq(pm.isStrategyManager(otlm), false);
        assertEq(pm.strategyCapOf(otlm),     type(uint256).max);

        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).isInstance(otlm), true);

        assertEq(pm.strategyList(1),                        tradingStrategyManager_);
        assertEq(pm.strategyCapOf(tradingStrategyManager_), type(uint256).max);

        assertEq(pm.isStrategyManager(tradingStrategyManager_), true);
        assertEq(pm.isStrategy(tradingStrategyManager_),        false);

        assertTradingStrategy({
            strategyManager:  tradingStrategyManager_,
            aum:              0,
            deployedAssets:   0,
            unrealizedYield:  0,
            unrealizedLosses: 0
        });
    }

    function test_deployPool_success_otlmAndMultipleModularStrategies() external {
        ( address tradingStrategyManager0, ) = _deployTradingStrategyFor(makeAddr("strategyDelegate0"));
        ( address tradingStrategyManager1, ) = _deployTradingStrategyFor(makeAddr("strategyDelegate1"));

        assertNotEq(tradingStrategyManager0, tradingStrategyManager1);

        StrategyDeployParams[] memory strategies = createOtlmStrategyParams(type(uint256).max);

        StrategyManagerParams[] memory managers = createStrategyManagerParams(
            tradingStrategyManager0,
            type(uint256).max,
            tradingStrategyManager1,
            type(uint256).max
        );

        vm.prank(poolDelegate);
        address poolManager_ = poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), 0),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         strategies,
            strategyManagersParams:   managers
        });

        ( IPoolManager pm, ) = assertDeployedPool({
            poolManager_:               poolManager_,
            initialSupply_:             0,
            liquidityCap_:              LIQUIDITY_CAP,
            delegateManagementFeeRate_: MANAGEMENT_FEE,
            strategyListLength_:        3
        });

        address otlm = pm.strategyList(0);

        assertEq(pm.isStrategy(otlm),        true);
        assertEq(pm.isStrategyManager(otlm), false);
        assertEq(pm.strategyCapOf(otlm),     type(uint256).max);

        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).isInstance(otlm), true);

        assertEq(pm.strategyList(1), tradingStrategyManager0);
        assertEq(pm.strategyList(2), tradingStrategyManager1);

        assertEq(pm.strategyCapOf(tradingStrategyManager0), type(uint256).max);
        assertEq(pm.strategyCapOf(tradingStrategyManager1), type(uint256).max);

        assertEq(pm.isStrategyManager(tradingStrategyManager0), true);
        assertEq(pm.isStrategyManager(tradingStrategyManager1), true);
        assertEq(pm.isStrategy(tradingStrategyManager0),        false);
        assertEq(pm.isStrategy(tradingStrategyManager1),        false);

        assertTradingStrategy({
            strategyManager:  tradingStrategyManager0,
            aum:              0,
            deployedAssets:   0,
            unrealizedYield:  0,
            unrealizedLosses: 0
        });

        assertTradingStrategy({
            strategyManager:  tradingStrategyManager1,
            aum:              0,
            deployedAssets:   0,
            unrealizedYield:  0,
            unrealizedLosses: 0
        });
    }

    function test_deployPool_success_modularStrategyOnly() external {
        ( address tradingStrategyManager_, ) = _deployTradingStrategyFor(strategyDelegate);

        StrategyManagerParams[] memory managers = createStrategyManagerParams(tradingStrategyManager_, 0);

        vm.prank(poolDelegate);
        address poolManager_ = poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), 0),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         new StrategyDeployParams[](0),
            strategyManagersParams:   managers
        });

        ( IPoolManager pm, ) = assertDeployedPool({
            poolManager_:               poolManager_,
            initialSupply_:             0,
            liquidityCap_:              LIQUIDITY_CAP,
            delegateManagementFeeRate_: MANAGEMENT_FEE,
            strategyListLength_:        1
        });

        assertEq(pm.strategyList(0),                        tradingStrategyManager_);
        assertEq(pm.strategyCapOf(tradingStrategyManager_), 0);

        assertEq(pm.isStrategyManager(tradingStrategyManager_), true);
        assertEq(pm.isStrategy(tradingStrategyManager_),        false);

        assertTradingStrategy({
            strategyManager:  tradingStrategyManager_,
            aum:              0,
            deployedAssets:   0,
            unrealizedYield:  0,
            unrealizedLosses: 0
        });
    }

    function test_deployPool_success_withInitialSupply() external {
        StrategyDeployParams[] memory strategies = createOtlmStrategyParams(type(uint256).max);

        vm.prank(poolDelegate);
        address poolManager_ = poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), INITIAL_SUPPLY),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         strategies,
            strategyManagersParams:   new StrategyManagerParams[](0)
        });

        ( IPoolManager pm, ) = assertDeployedPool({
            poolManager_:               poolManager_,
            initialSupply_:             INITIAL_SUPPLY,
            liquidityCap_:              LIQUIDITY_CAP,
            delegateManagementFeeRate_: MANAGEMENT_FEE,
            strategyListLength_:        1
        });

        address otlm = pm.strategyList(0);

        assertEq(pm.isStrategy(otlm),        true);
        assertEq(pm.isStrategyManager(otlm), false);
        assertEq(pm.strategyCapOf(otlm),     type(uint256).max);

        assertEq(IMapleProxyFactory(openTermLoanManagerFactory).isInstance(otlm), true);
    }

    function test_deployPool_success_zeroMigrationAdmin() external {
        vm.prank(governor);
        globals.setMigrationAdmin(address(0));

        vm.prank(poolDelegate);
        address poolManager_ = poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    createPoolManagerInitParams(address(fundsAsset), 0),
            poolConfigParams:         createPoolConfigParams(),
            strategiesParams:         new StrategyDeployParams[](0),
            strategyManagersParams:   new StrategyManagerParams[](0)
        });

        assertEq(globals.migrationAdmin(), address(0));

        assertDeployedPool({
            poolManager_:               poolManager_,
            initialSupply_:             0,
            liquidityCap_:              LIQUIDITY_CAP,
            delegateManagementFeeRate_: MANAGEMENT_FEE,
            strategyListLength_:        0
        });
    }

}
