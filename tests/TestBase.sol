// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console } from "../modules/forge-std/src/Test.sol";

import {
    IAssetController,
    IAssetControllerOracle,
    IBitcoinStrategy,
    ICompositeToken,
    IGlobals,
    IGovernorTimelock,
    IMapleLiquidityRouter,
    IMapleProxyFactory,
    IMockERC20,
    IPool,
    IPoolDeployer,
    IPoolManager,
    IPoolPermissionManager,
    IPoolPermissionManagerInitializer,
    ISyrupBitcoinRouter,
    IStrategyDeployer,
    IStrategyManager,
    IWithdrawalManagerQueue
} from "../contracts/interfaces/Interfaces.sol";

import {
    AllocationStrategyInitializerParams,
    AaveV3StrategyInitializerParams,
    PoolConfigParams,
    PoolManagerInitParams,
    StrategyDeployParams,
    StrategyManagerParams,
    SkyStrategyInitializerParams
} from "../contracts/interfaces/Interfaces.sol";

import { ProtocolActions } from "../contracts/ProtocolActions.sol";
import { Utils }           from "../contracts/Utils.sol";

contract TestBase is ProtocolActions, Utils {

    uint256 constant AAVE_V3_FORK_BLOCK = 25523119;
    uint256 constant MAINNET_FORK_BLOCK = 21073000;

    uint256 constant MAX_TOKEN_AMOUNT         = 1e29;
    uint256 constant DEFAULT_STRATEGIES_COUNT = 4;

    uint256 constant ONE_DAY   = 1 days;
    uint256 constant ONE_MONTH = ONE_YEAR / 12;
    uint256 constant ONE_YEAR  = 365 days;

    string constant POOL_NAME   = "Maple Pool";
    string constant POOL_SYMBOL = "MP";

    address governor;
    address governorTimelockProposer;
    address governorTimelockRoleAdmin;
    address liquidityBot;
    address liquidityRouterBot;
    address migrationAdmin;
    address operationalAdmin;
    address permissionAdmin;
    address poolDelegate;
    address redeemer;
    address securityAdmin;
    address strategyDelegate;
    address strategyManager;
    address treasury;

    address assetControllerImplementation;
    address assetControllerInitializer;
    address assetControllerProxy;

    address compositeTokenImplementation;
    address compositeTokenInitializer;
    address compositeTokenProxy;

    address priceOracleImplementation;
    address priceOracleProxy;

    address bitcoinRouterImplementation;
    address bitcoinRouterInitializer;
    address bitcoinRouterProxy;

    address aaveV3StrategyFactory;
    address liquidatorFactory;
    address openTermLoanFactory;
    address openTermLoanManagerFactory;
    address poolManagerFactory;
    address queueWMFactory;
    address skyStrategyFactory;
    address bitcoinStrategyFactory;
    address strategyManagerFactory;
    address allocationStrategyFactory;

    address aaveV3StrategyImplementation;
    address openTermLoanImplementation;
    address openTermLoanManagerImplementation;
    address poolManagerImplementation;
    address poolPermissionManagerImplementation;
    address queueWMImplementation;
    address skyStrategyImplementation;
    address bitcoinStrategyImplementation;
    address strategyManagerImplementation;
    address allocationStrategyImplementation;

    address aaveV3StrategyInitializer;
    address openTermLoanInitializer;
    address openTermLoanManagerInitializer;
    address poolManagerInitializer;
    address poolPermissionManagerInitializer;
    address queueWMInitializer;
    address skyStrategyInitializer;
    address bitcoinStrategyInitializer;
    address strategyManagerInitializer;
    address allocationStrategyInitializer;

    address aaveV3StrategyManager;
    address skyStrategyManager;
    address allocationStrategyManager;

    address aaveV3UnderlyingStrategy;
    address skyUnderlyingStrategy;
    address allocationUnderlyingStrategy;

    address borrowerActions;
    address openTermRefinancer;

    uint256 nextDelegateOriginationFee;
    uint256 nextDelegateServiceFee;

    uint32  startingTime;
    uint256 start;
    uint256 initialStrategiesCount;

    address[] strategyFactories;
    address[] poolManagers;

    bytes32[] functionIds;

    // Avoid stack-too-deep error.
    bytes[] strategyDeploymentData_;

    IGlobals                   globals;
    IGovernorTimelock          governorTimelock;
    IMapleLiquidityRouter      liquidityRouter;
    IPool                      pool;
    IPoolDeployer              poolDeployer;
    IPoolManager               poolManager;
    IPoolPermissionManager     poolPermissionManager;
    IStrategyDeployer          strategyDeployer;
    IWithdrawalManagerQueue    queueWM;
    IWithdrawalManagerQueue    withdrawalManager;

    IAssetController       assetController;
    IAssetControllerOracle priceOracle;
    IBitcoinStrategy       bitcoinStrategy;
    ICompositeToken        compositeAsset;
    ISyrupBitcoinRouter    bitcoinRouter;

    IMockERC20 collateralAsset;
    IMockERC20 depositAsset;
    IMockERC20 fundsAsset;

    /**************************************************************************************************************************************/
    /*** Test Setups                                                                                                                    ***/
    /**************************************************************************************************************************************/

    function setUp() public virtual {
        startingTime = uint32(block.timestamp);

        _setUpOpenPool();
    }

    function _setUpOpenPool() internal {
        _setUpClosedPool();
        openPool(address(poolManager));
    }

    function _setUpClosedPool() internal {
        _deployProtocol();
        _createPoolWithOTLM(poolDelegate);
        _configurePool();
    }

    /**************************************************************************************************************************************/
    /*** Pool Deployment                                                                                                                ***/
    /**************************************************************************************************************************************/

    function _createPoolWithOTLM(address poolDelegate_) internal returns (address pool_, address pm_, address wm_) {
        bytes[] memory strategyData = new bytes[](strategyFactories.length);
        for (uint256 i; i < strategyFactories.length; i++) {
            strategyData[i] = abi.encode(new bytes(0));
        }

        (
            pool_,
            pm_,
            wm_
        ) = _createPoolWithMultipleStrategies(poolDelegate_, address(fundsAsset), POOL_NAME, strategyFactories, strategyData);
    }

    function _createPoolWithMultipleStrategies(
        address          poolDelegate_,
        address          fundsAsset_,
        string    memory name_,
        address[] memory strategyFactories_,
        bytes[]   memory strategyData_
    )
        internal returns (address pool_, address pm_, address wm_)
    {
        poolManager = IPoolManager(_deployPoolWithQueue({
            poolDelegate_:              poolDelegate_,
            fundsAsset_:                fundsAsset_,
            strategyFactories_:         strategyFactories_,
            strategyData_:              strategyData_,
            name_:                      name_,
            symbol_:                    POOL_SYMBOL,
            liquidityCap_:              type(uint256).max,
            delegateManagementFeeRate_: 0
        }));

        poolManagers.push(address(poolManager));

        queueWM = IWithdrawalManagerQueue(poolManager.withdrawalManager());
        pool    = IPool(poolManager.pool());

        pool_ = address(pool);
        pm_   = address(poolManager);
        wm_   = address(queueWM);
    }

    function _configurePool() internal {
        activatePool(address(poolManager), HUNDRED_PERCENT);
        allowLender(address(poolManager), address(queueWM));
    }

    function _createPoolSharingStrategy(string memory delegateLabel_, address strategyManager_)
        internal returns (address pool_, address poolManager_)
    {
        address poolDelegate_ = makeAddr(delegateLabel_);

        vm.prank(governor);
        globals.setValidPoolDelegate(poolDelegate_, true);

        ( pool_, poolManager_, ) = _createPoolWithOTLM(poolDelegate_);

        activatePool(poolManager_, HUNDRED_PERCENT);

        vm.startPrank(governor);
        IPoolManager(poolManager_).addStrategyManager(strategyManager_);
        IPoolManager(poolManager_).setStrategyCap(strategyManager_, type(uint256).max);
        vm.stopPrank();
    }

    /**************************************************************************************************************************************/
    /*** Strategy Manager Deployment                                                                                                    ***/
    /**************************************************************************************************************************************/

    function _deployAllocationStrategy(
        address strategyDelegate_,
        address fundsAsset_,
        uint32  strategyDelegateFeeRate_,
        uint32  strategyProtocolFeeRate_,
        uint256 strategyLiquidityCap_,
        uint256 bootstrapMint_
    )
        internal returns (address strategyManager_, address underlyingStrategy_)
    {
        AllocationStrategyInitializerParams memory params = AllocationStrategyInitializerParams({
            fundsAsset:              fundsAsset_,
            strategyMetadata:        "Allocation Strategy",
            strategyDelegateFeeRate: strategyDelegateFeeRate_,
            strategyProtocolFeeRate: strategyProtocolFeeRate_,
            yieldCap:                type(uint256).max
        });

        vm.startPrank(governor);
        globals.setValidStrategyDelegate(strategyDelegate_, true);
        globals.setBootstrapMint(fundsAsset_, bootstrapMint_);
        vm.stopPrank();

        if (bootstrapMint_ != 0) {
            erc20_mint(fundsAsset_, strategyDelegate_, bootstrapMint_);
            erc20_approve(fundsAsset_, strategyDelegate_, address(strategyDeployer), bootstrapMint_);
        }

        vm.prank(strategyDelegate_);

        ( strategyManager_, underlyingStrategy_ ) = strategyDeployer.deploy({
            strategyManagerFactory: strategyManagerFactory,
            strategyFactory:        allocationStrategyFactory,
            strategyLiquidityCap:   strategyLiquidityCap_,
            strategyDeploymentData: abi.encode(params),
            bootstrapFundingData:   ""
        });

        vm.prank(governor);
        globals.activateStrategyManager(strategyManager_);
    }

    function _deployAaveV3Strategy(
        address strategyDelegate_,
        address aaveToken_,
        bool    useVirtualUnderlyingBalance_,
        uint32  strategyDelegateFeeRate_,
        uint32  strategyProtocolFeeRate_,
        uint256 strategyLiquidityCap_,
        uint256 bootstrapMint_
    )
        internal returns (address strategyManager_, address underlyingStrategy_)
    {
        AaveV3StrategyInitializerParams memory params = AaveV3StrategyInitializerParams({
            aaveToken:                   aaveToken_,
            strategyDelegateFeeRate:     strategyDelegateFeeRate_,
            strategyProtocolFeeRate:     strategyProtocolFeeRate_,
            referralCode:                0,
            useVirtualUnderlyingBalance: useVirtualUnderlyingBalance_
        });

        vm.startPrank(governor);
        globals.setValidStrategyDelegate(strategyDelegate_, true);
        globals.setValidInstanceOf("STRATEGY_VAULT", aaveToken_, true);
        globals.setBootstrapMint(address(fundsAsset), bootstrapMint_);
        vm.stopPrank();

        if (bootstrapMint_ != 0) {
            erc20_mint(address(fundsAsset), strategyDelegate_, bootstrapMint_);
            erc20_approve(address(fundsAsset), strategyDelegate_, address(strategyDeployer), bootstrapMint_);
        }

        vm.prank(strategyDelegate_);

        ( strategyManager_, underlyingStrategy_ ) = strategyDeployer.deploy({
            strategyManagerFactory: strategyManagerFactory,
            strategyFactory:        aaveV3StrategyFactory,
            strategyLiquidityCap:   strategyLiquidityCap_,
            strategyDeploymentData: abi.encode(params),
            bootstrapFundingData:   ""
        });

        vm.prank(governor);
        globals.activateStrategyManager(strategyManager_);
    }

    function _deploySkyStrategy(
        address strategyDelegate_,
        address fundsAsset_,
        address savingsUsds_,
        address psm_,
        uint32  strategyDelegateFeeRate_,
        uint32  strategyProtocolFeeRate_,
        uint256 strategyLiquidityCap_,
        uint256 bootstrapMint_
    )
        internal returns (address strategyManager_, address underlyingStrategy_)
    {
        SkyStrategyInitializerParams memory params = SkyStrategyInitializerParams({
            fundsAsset:              fundsAsset_,
            psm:                     psm_,
            savingsUsds:             savingsUsds_,
            strategyDelegateFeeRate: strategyDelegateFeeRate_,
            strategyProtocolFeeRate: strategyProtocolFeeRate_,
            referralCode:            0
        });

        vm.startPrank(governor);
        globals.setValidStrategyDelegate(strategyDelegate_, true);
        globals.setValidInstanceOf("STRATEGY_VAULT", savingsUsds_, true);
        globals.setValidInstanceOf("PSM",            psm_,         true);
        globals.setBootstrapMint(fundsAsset_, bootstrapMint_);
        vm.stopPrank();

        if (bootstrapMint_ != 0) {
            erc20_mint(fundsAsset_, strategyDelegate_, bootstrapMint_);
            erc20_approve(fundsAsset_, strategyDelegate_, address(strategyDeployer), bootstrapMint_);
        }

        vm.prank(strategyDelegate_);

        ( strategyManager_, underlyingStrategy_ ) = strategyDeployer.deploy({
            strategyManagerFactory: strategyManagerFactory,
            strategyFactory:        skyStrategyFactory,
            strategyLiquidityCap:   strategyLiquidityCap_,
            strategyDeploymentData: abi.encode(params),
            bootstrapFundingData:   ""
        });

        vm.prank(governor);
        globals.activateStrategyManager(strategyManager_);
    }

    /**************************************************************************************************************************************/
    /*** Bitcoin Pool Deployment                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _setUpBitcoinPool() internal {
        startingTime = uint32(block.timestamp);

        _deployProtocol();
        _createBitcoinPool();
        _createBitcoinPeriphery();
        _configureBitcoinPeriphery();
    }

    function _createBitcoinPool() internal {
        initialStrategiesCount = initialStrategiesCount == 0 ? DEFAULT_STRATEGIES_COUNT : initialStrategiesCount;

        address[] memory strategyFactories_  = new address[](initialStrategiesCount);
        bytes[]   memory additionalCalldata_ = new bytes[](initialStrategiesCount);

        // Creates 4 distinct bitcoin strategies.
        for (uint i; i < initialStrategiesCount; i++) {
            strategyFactories_[i]  = address(bitcoinStrategyFactory);
            additionalCalldata_[i] = abi.encode("");
        }

        poolManager = IPoolManager(_deployPoolWithQueue({
            poolDelegate_:              address(poolDelegate),
            fundsAsset_:                address(compositeAsset),
            strategyFactories_:         strategyFactories_,
            strategyData_:              additionalCalldata_,
            name_:                      "Syrup BTC Pool",
            symbol_:                    "syrupBTC",
            liquidityCap_:              type(uint256).max,
            delegateManagementFeeRate_: 0
        }));

        poolManagers.push(address(poolManager));

        pool              = IPool(poolManager.pool());
        withdrawalManager = IWithdrawalManagerQueue(poolManager.withdrawalManager());
        bitcoinStrategy   = IBitcoinStrategy(poolManager.strategyList(0));

        // Whitelist all of the bitcoin strategies on globals.
        for (uint i; i < initialStrategiesCount; i++) {
            address strategy = poolManager.strategyList(i);

            vm.prank(governor);
            globals.setValidInstanceOf("BITCOIN_STRATEGY", address(strategy), true);
        }

        activatePool(address(poolManager), HUNDRED_PERCENT);
    }

    function _createBitcoinPeriphery() internal {
        priceOracleImplementation = deployFromFile("Contracts@25", "AssetControllerOracle");

        priceOracleProxy = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                address(priceOracleImplementation),
                address(0),
                ""
            )
        );

        vm.prank(governor);
        globals.setValidInstanceOf("CONTROLLER_ORACLE", priceOracleProxy, true);

        bitcoinRouterImplementation = deployFromFile("Contracts@25", "SyrupBitcoinRouter");
        bitcoinRouterInitializer = deployFromFile("Contracts@25", "SyrupBitcoinRouterInitializer");
        bitcoinRouterProxy = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                address(bitcoinRouterImplementation),
                address(bitcoinRouterInitializer),
                abi.encodeWithSignature("initialize(address)", address(poolManager))
            )
        );

        vm.prank(governor);
        globals.setValidInstanceOf("SYRUP_BTC_ROUTER", bitcoinRouterProxy, true);

        assetControllerImplementation = deployFromFile("Contracts@25", "AssetController");
        assetControllerInitializer = deployFromFile("Contracts@25", "AssetControllerInitializer");
        assetControllerProxy = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                address(assetControllerImplementation),
                address(assetControllerInitializer),
                abi.encodeWithSignature(
                    "initialize(address,address)",
                    priceOracleProxy,
                    bitcoinRouterProxy
                )
            )
        );

        vm.prank(governor);
        globals.setValidInstanceOf("ASSET_CONTROLLER", assetControllerProxy, true);

        assetController = IAssetController(assetControllerProxy);
        bitcoinRouter   = ISyrupBitcoinRouter(bitcoinRouterProxy);
        priceOracle     = IAssetControllerOracle(priceOracleProxy);
    }

    function _configureBitcoinPeriphery() internal {
        // Allow usage of composite tokens only for the pool, router, controller, and all bitcoin strategies.
        address[] memory addresses = new address[](3 + initialStrategiesCount);
        bool[]    memory allowed   = new bool[](3 + initialStrategiesCount);

        addresses[0] = address(pool);
        addresses[1] = address(assetController);
        addresses[2] = address(bitcoinRouter);

        for (uint i; i < initialStrategiesCount; i++) {
            addresses[3 + i] = poolManager.strategyList(i);
        }

        allowed[0] = true;
        allowed[1] = true;
        allowed[2] = true;

        for (uint i; i < initialStrategiesCount; i++) {
            allowed[3 + i] = true;
        }

        vm.prank(governor);
        compositeAsset.allowAddresses(addresses, allowed);

        // Set which deposit assets are allowed to be deposited and withdrawn.
        addresses = new address[](1);
        allowed   = new bool[](1);

        addresses[0] = address(depositAsset);
        allowed[0]   = true;

        vm.prank(governor);
        assetController.setAssets(addresses, allowed, allowed, allowed, allowed);

        // Set the bitcoin router to manual withdrawal.
        vm.prank(operationalAdmin);
        withdrawalManager.setManualWithdrawal(address(bitcoinRouter), true);

        // Set all bitcoin strategies on the asset controller.
        addresses = new address[](initialStrategiesCount);
        allowed   = new bool[](initialStrategiesCount);

        for (uint i; i < initialStrategiesCount; i++) {
            addresses[i] = poolManager.strategyList(i);
            allowed[i]   = true;
        }

        vm.prank(governor);
        assetController.setStrategies(addresses, allowed);

        // Set the asset controller on the token, router, and all bitcoin strategies.
        addresses = new address[](1);
        allowed   = new bool[](1);

        addresses[0] = address(assetController);
        allowed[0]   = true;

        vm.prank(governor);
        compositeAsset.setAssetControllers(addresses, allowed);

        vm.prank(governor);
        bitcoinRouter.setAssetController(address(depositAsset), address(assetController));

        for (uint i; i < initialStrategiesCount; i++) {
            address strategy = poolManager.strategyList(i);

            vm.prank(governor);
            IBitcoinStrategy(strategy).setAssetController(address(depositAsset), address(assetController));
        }

        // Allow the strategy manager to deploy, schedule, and reconcile all strategies.
        addresses[0] = strategyManager;
        allowed[0]   = true;

        for (uint i; i < initialStrategiesCount; i++) {
            address strategy = poolManager.strategyList(i);

            vm.prank(governor);
            IBitcoinStrategy(strategy).setPermissions(addresses, allowed, allowed, allowed);
        }

        // Allow everyone else to only transfer the pool token around.
        bytes32[] memory functionIdsToSet = new bytes32[](11);
        uint256[] memory bitmaps          = new uint256[](11);

        uint256 bitmap = 2 ** 5;

        functionIdsToSet[0]  = "P:deposit";
        functionIdsToSet[1]  = "P:depositWithPermit";
        functionIdsToSet[2]  = "P:mint";
        functionIdsToSet[3]  = "P:mintWithPermit";
        functionIdsToSet[4]  = "P:redeem";
        functionIdsToSet[5]  = "P:withdraw";
        functionIdsToSet[6]  = "P:transfer";
        functionIdsToSet[7]  = "P:transferFrom";
        functionIdsToSet[8]  = "P:removeShares";
        functionIdsToSet[9]  = "P:requestRedeem";
        functionIdsToSet[10] = "P:requestWithdraw";

        bitmaps[0]  = bitmap;
        bitmaps[1]  = bitmap;
        bitmaps[2]  = bitmap;
        bitmaps[3]  = bitmap;
        bitmaps[4]  = bitmap;
        bitmaps[5]  = bitmap;
        bitmaps[6]  = 0;
        bitmaps[7]  = 0;
        bitmaps[8]  = bitmap;
        bitmaps[9]  = bitmap;
        bitmaps[10] = bitmap;

        vm.prank(governor);
        poolPermissionManager.setPoolPermissionLevel(address(poolManager), 1);

        vm.prank(governor);
        poolPermissionManager.setPoolBitmaps(address(poolManager), functionIdsToSet, bitmaps);

        addresses = new address[](1);
        bitmaps   = new uint256[](1);

        addresses[0] = address(bitcoinRouter);
        bitmaps[0]   = bitmap;

        vm.prank(governor);
        poolPermissionManager.setLenderBitmaps(addresses, bitmaps);
    }

    /**************************************************************************************************************************************/
    /*** Common: Protocol Deployment                                                                                                    ***/
    /**************************************************************************************************************************************/

    function _deployProtocol() internal {
        start = block.timestamp;

        _createAccounts();
        _createGlobals();
        _createAssets();
        _configureGlobals();
        _createFactories();
    }

    function _createAccounts() internal {
        governor           = makeAddr("governor");
        liquidityBot       = makeAddr("liquidityBot");
        liquidityRouterBot = makeAddr("liquidityRouterBot");
        migrationAdmin     = makeAddr("migrationAdmin");
        operationalAdmin   = makeAddr("operationalAdmin");
        permissionAdmin    = makeAddr("permissionAdmin");
        poolDelegate       = makeAddr("poolDelegate");
        redeemer           = makeAddr("redeemer");
        securityAdmin      = makeAddr("securityAdmin");
        strategyDelegate   = makeAddr("strategyDelegate");
        strategyManager    = makeAddr("strategyManager");
        treasury           = makeAddr("treasury");
    }

    function _createGlobals() internal {
        globals          = IGlobals(deployNTP(governor, deploy("MapleGlobals")));
        poolDeployer     = IPoolDeployer(deploy("MaplePoolDeployer", abi.encode(address(globals))));
        strategyDeployer = IStrategyDeployer(deployFromFile("Contracts@28", "StrategyDeployer", abi.encode(address(globals))));
    }

    // Deploys a governor timelock and reassigns the globals governor to it. Only for use in the setup of tests
    // that specifically exercise governance through the timelock.
    function _deployTimelockAndReassignGovernor() internal {
        governorTimelockProposer  = makeAddr("governorTimelockProposer");
        governorTimelockRoleAdmin = makeAddr("governorTimelockRoleAdmin");

        governorTimelock = IGovernorTimelock(
            deployFromFile(
                "Contracts@25",
                "Timelock",
                abi.encode(governor, governorTimelockProposer, operationalAdmin, securityAdmin, governorTimelockRoleAdmin)
            )
        );

        vm.prank(governor);
        globals.setPendingGovernor(address(governorTimelock));

        executeThroughTimelock({
            timelock_: address(governorTimelock),
            proposer_: governorTimelockProposer,
            executor_: operationalAdmin,
            target_:   address(globals),
            callData_: abi.encodeWithSignature("acceptGovernor()")
        });

        governor = address(governorTimelock);
    }

    function _createAssets() internal {
        collateralAsset = IMockERC20(deployMock("ConfigurableMockERC20", abi.encode("Wrapper Ether",   "WETH", 18)));
        fundsAsset      = IMockERC20(deployMock("ConfigurableMockERC20", abi.encode("USD Coin",        "USDC", 6)));
        depositAsset    = IMockERC20(deployMock("ConfigurableMockERC20", abi.encode("Wrapped Bitcoin", "WBTC", 8)));

        compositeTokenImplementation = deployFromFile("Contracts@25", "CompositeToken");
        compositeTokenInitializer = deployFromFile("Contracts@25", "CompositeTokenInitializer");
        compositeTokenProxy = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                address(compositeTokenImplementation),
                address(compositeTokenInitializer),
                abi.encodeWithSignature("initialize(string,string,uint8)", "Synthetic Bitcoin", "synthBTC", 8)
            )
        );

        compositeAsset = ICompositeToken(compositeTokenProxy);
    }

    function _configureGlobals() internal {
        vm.startPrank(governor);
        globals.setMigrationAdmin(migrationAdmin);
        globals.setOperationalAdmin(operationalAdmin);
        globals.setSecurityAdmin(securityAdmin);
        globals.setValidPoolAsset(address(fundsAsset), true);
        globals.setValidPoolAsset(address(compositeAsset), true);
        globals.setValidPoolDelegate(poolDelegate, true);
        globals.setDefaultTimelockParameters(1 weeks, 2 days);
        globals.setMapleTreasury(treasury);
        vm.stopPrank();
    }

    function _createFactories() internal {
        liquidatorFactory          = makeAddr("liquidatorFactoryStub");  // Stub: PM:TD validation passport; OTLM ignores its value.
        openTermLoanFactory        = deployFromFile("Contracts@7", "OpenTermLoanFactory",           abi.encode(address(globals)));
        openTermLoanManagerFactory = deployFromFile("Contracts@7", "OpenTermLoanManagerFactory",    abi.encode(address(globals)));
        poolManagerFactory         = deployFromFile("Contracts@7", "PoolManagerFactory",            abi.encode(address(globals)));
        queueWMFactory             = deployFromFile("Contracts@7", "WithdrawalManagerQueueFactory", abi.encode(address(globals)));

        openTermLoanImplementation        = deployFromFile("Contracts@7",  "OpenTermLoan");
        openTermLoanManagerImplementation = deployFromFile("Contracts@7",  "OpenTermLoanManager");
        poolManagerImplementation         = deployFromFile("Contracts@28", "PoolManager");
        queueWMImplementation             = deployFromFile("Contracts@28", "WithdrawalManagerQueue");

        openTermLoanInitializer        = deployFromFile("Contracts@7",  "OpenTermLoanInitializer");
        openTermLoanManagerInitializer = deployFromFile("Contracts@7",  "OpenTermLoanManagerInitializer");
        poolManagerInitializer         = deployFromFile("Contracts@28", "PoolManagerInitializer");
        queueWMInitializer             = deployFromFile("Contracts@28", "WithdrawalManagerQueueInitializer");

        openTermRefinancer = deployFromFile("Contracts@7", "OpenTermRefinancer");

        poolPermissionManagerImplementation = deployFromFile("Contracts@7","PoolPermissionManager");
        poolPermissionManagerInitializer    = deployFromFile("Contracts@7","PoolPermissionManagerInitializer");

        poolPermissionManager = IPoolPermissionManager(deployNTP(governor, poolPermissionManagerInitializer));

        bitcoinStrategyFactory        = deployFromFile("Contracts@25", "StrategyFactory", abi.encode(address(globals)));
        bitcoinStrategyImplementation = deployFromFile("Contracts@25", "BitcoinStrategy");
        bitcoinStrategyInitializer    = deployFromFile("Contracts@25", "BitcoinStrategyInitializer");

        aaveV3StrategyFactory            = deployFromFile("Contracts@28", "AaveV3StrategyFactory", abi.encode(address(globals)));
        skyStrategyFactory               = deployFromFile("Contracts@28", "SkyStrategyFactory", abi.encode(address(globals)));
        strategyManagerFactory           = deployFromFile("Contracts@28", "StrategyManagerFactory", abi.encode(address(globals)));
        allocationStrategyFactory        = deployFromFile("Contracts@28", "AllocationStrategyFactory", abi.encode(address(globals)));
        aaveV3StrategyImplementation     = deployFromFile("Contracts@28", "AaveV3Strategy");
        skyStrategyImplementation        = deployFromFile("Contracts@28", "SkyStrategy");
        strategyManagerImplementation    = deployFromFile("Contracts@28", "StrategyManager");
        allocationStrategyImplementation = deployFromFile("Contracts@28", "AllocationStrategy");
        aaveV3StrategyInitializer        = deployFromFile("Contracts@28", "AaveV3StrategyInitializer");
        skyStrategyInitializer           = deployFromFile("Contracts@28", "SkyStrategyInitializer");
        strategyManagerInitializer       = deployFromFile("Contracts@28", "StrategyManagerInitializer");
        allocationStrategyInitializer    = deployFromFile("Contracts@28", "AllocationStrategyInitializer");

        borrowerActions = deployNTP(securityAdmin, deployFromFile("Contracts@25", "BorrowerActions"));

        liquidityRouter = IMapleLiquidityRouter(
            deployFromFile("Contracts@28", "LiquidityRouter", abi.encode(address(globals)))
        );

        vm.startPrank(governor);

        IPoolPermissionManagerInitializer(address(poolPermissionManager)).initialize(poolPermissionManagerImplementation, address(globals));
        poolPermissionManager.setPermissionAdmin(permissionAdmin, true);

        globals.setValidInstanceOf("LIQUIDATOR_FACTORY",               liquidatorFactory,              true);
        globals.setValidInstanceOf("LOAN_FACTORY",                     openTermLoanFactory,            true);
        globals.setValidInstanceOf("OT_LOAN_FACTORY",                  openTermLoanFactory,            true);
        globals.setValidInstanceOf("OT_LOAN_MANAGER_FACTORY",          openTermLoanManagerFactory,     true);
        globals.setValidInstanceOf("LOAN_MANAGER_FACTORY",             openTermLoanManagerFactory,     true);
        globals.setValidInstanceOf("STRATEGY_FACTORY",                 openTermLoanManagerFactory,     true);
        globals.setValidInstanceOf("POOL_MANAGER_FACTORY",             poolManagerFactory,             true);
        globals.setValidInstanceOf("WITHDRAWAL_MANAGER_QUEUE_FACTORY", queueWMFactory,                 true);
        globals.setValidInstanceOf("WITHDRAWAL_MANAGER_FACTORY",       queueWMFactory,                 true);
        globals.setValidInstanceOf("STRATEGY_FACTORY",                 bitcoinStrategyFactory,         true);
        globals.setValidInstanceOf("POOL_PERMISSION_MANAGER",          address(poolPermissionManager), true);
        globals.setValidInstanceOf("REFINANCER",                       openTermRefinancer,             true);
        globals.setValidInstanceOf("OT_REFINANCER",                    openTermRefinancer,             true);
        globals.setValidInstanceOf("STRATEGY_MANAGER",                 strategyManager,                true);
        globals.setValidInstanceOf("STRATEGY_MANAGER_FACTORY",         strategyManagerFactory,         true);
        globals.setValidInstanceOf("UNDERLYING_STRATEGY_FACTORY",      aaveV3StrategyFactory,          true);
        globals.setValidInstanceOf("UNDERLYING_STRATEGY_FACTORY",      skyStrategyFactory,             true);
        globals.setValidInstanceOf("UNDERLYING_STRATEGY_FACTORY",      allocationStrategyFactory,      true);
        globals.setValidInstanceOf("COMPOSITE_DEPOSIT_ASSET",          address(depositAsset),          true);
        globals.setValidInstanceOf("COMPOSITE_POOL_ASSET",             compositeTokenProxy,            true);
        globals.setValidInstanceOf("SYRUP_BTC_REDEEMER",               redeemer,                       true);
        globals.setValidInstanceOf("LIQUIDITY_BOT",                    liquidityBot,                   true);
        globals.setValidInstanceOf("LIQUIDITY_ROUTER",                 address(liquidityRouter),       true);
        globals.setValidInstanceOf("LIQUIDITY_ROUTER_BOT",             liquidityRouterBot,             true);

        globals.setCanDeployFrom(poolManagerFactory,        address(poolDeployer),     true);
        globals.setCanDeployFrom(queueWMFactory,            address(poolDeployer),     true);
        globals.setCanDeployFrom(bitcoinStrategyFactory,    address(poolDeployer),     true);
        globals.setCanDeployFrom(aaveV3StrategyFactory,     address(strategyDeployer), true);
        globals.setCanDeployFrom(skyStrategyFactory,        address(strategyDeployer), true);
        globals.setCanDeployFrom(strategyManagerFactory,    address(strategyDeployer), true);
        globals.setCanDeployFrom(allocationStrategyFactory, address(strategyDeployer), true);

        globals.setValidStrategyDelegate(strategyDelegate, true);

        IMapleProxyFactory(openTermLoanFactory).registerImplementation(1, openTermLoanImplementation, openTermLoanInitializer);
        IMapleProxyFactory(openTermLoanFactory).setDefaultVersion(1);

        IMapleProxyFactory(openTermLoanManagerFactory).registerImplementation(
            1,
            openTermLoanManagerImplementation,
            openTermLoanManagerInitializer
        );
        IMapleProxyFactory(openTermLoanManagerFactory).setDefaultVersion(1);

        IMapleProxyFactory(poolManagerFactory).registerImplementation(1, poolManagerImplementation, poolManagerInitializer);
        IMapleProxyFactory(poolManagerFactory).setDefaultVersion(1);


        IMapleProxyFactory(queueWMFactory).registerImplementation(1, queueWMImplementation, queueWMInitializer);
        IMapleProxyFactory(queueWMFactory).setDefaultVersion(1);

        IMapleProxyFactory(bitcoinStrategyFactory).registerImplementation(1, bitcoinStrategyImplementation, bitcoinStrategyInitializer);
        IMapleProxyFactory(bitcoinStrategyFactory).setDefaultVersion(1);

        IMapleProxyFactory(aaveV3StrategyFactory).registerImplementation(1, aaveV3StrategyImplementation, aaveV3StrategyInitializer);
        IMapleProxyFactory(aaveV3StrategyFactory).setDefaultVersion(1);

        IMapleProxyFactory(skyStrategyFactory).registerImplementation(1, skyStrategyImplementation, skyStrategyInitializer);
        IMapleProxyFactory(skyStrategyFactory).setDefaultVersion(1);

        IMapleProxyFactory(strategyManagerFactory).registerImplementation(1, strategyManagerImplementation, strategyManagerInitializer);
        IMapleProxyFactory(strategyManagerFactory).setDefaultVersion(1);

        IMapleProxyFactory(allocationStrategyFactory).registerImplementation(
            1,
            allocationStrategyImplementation,
            allocationStrategyInitializer
        );
        IMapleProxyFactory(allocationStrategyFactory).setDefaultVersion(1);

        vm.stopPrank();

        strategyFactories.push(openTermLoanManagerFactory);
    }

    /**************************************************************************************************************************************/
    /*** Common: Pool Builder                                                                                                           ***/
    /**************************************************************************************************************************************/

    function _deployPoolWithQueue(
        address           poolDelegate_,
        address           fundsAsset_,
        address[]  memory strategyFactories_,
        bytes[]    memory strategyData_,
        string     memory name_,
        string     memory symbol_,
        uint256           liquidityCap_,
        uint256           delegateManagementFeeRate_
    )
        internal returns (address poolManager_)
    {
        vm.prank(poolDelegate_);
        poolManager_ = poolDeployer.deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams:    PoolManagerInitParams({
                asset:         fundsAsset_,
                initialSupply: 0,
                name:          name_,
                symbol:        symbol_
            }),
            poolConfigParams: PoolConfigParams({
                poolPermissionManager:     address(poolPermissionManager),
                delegateManagementFeeRate: delegateManagementFeeRate_,
                liquidityCap:              liquidityCap_
            }),
            strategiesParams:       _buildStrategyDeployParams(strategyFactories_, strategyData_, name_),
            strategyManagersParams: new StrategyManagerParams[](0)
        });
    }

    function _buildStrategyDeployParams(
        address[] memory strategyFactories_,
        bytes[]   memory strategyData_,
        string    memory name_
    )
        internal pure returns (StrategyDeployParams[] memory strategies_)
    {
        strategies_ = new StrategyDeployParams[](strategyFactories_.length);

        for (uint256 i; i < strategyFactories_.length; i++) {
            strategies_[i] = StrategyDeployParams({
                factory:        strategyFactories_[i],
                cap:            type(uint256).max,
                salt:           keccak256(abi.encode(name_, i)),
                deploymentData: strategyData_[i]
            });
        }
    }

    /**************************************************************************************************************************************/
    /*** Common: Helpers                                                                                                                ***/
    /**************************************************************************************************************************************/

    function createBitmap(uint8[1] memory indices_) internal pure returns (uint256 bitmap_) {
        for (uint8 i = 0; i < indices_.length; i++) {
            bitmap_ |= (1 << indices_[i]);
        }
    }

    function createBitmap(uint8[2] memory indices_) internal pure returns (uint256 bitmap_) {
        for (uint8 i = 0; i < indices_.length; i++) {
            bitmap_ |= (1 << indices_[i]);
        }
    }

    function createOpenTermLoan(
        address          borrower,
        address          lender,
        address          asset,
        uint256          principal,
        uint32[3] memory terms,
        uint64[4] memory rates
    )
        internal returns (address loan)
    {
        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

        vm.prank(borrower);
        loan = IMapleProxyFactory(openTermLoanFactory).createInstance({
            arguments_: abi.encode(borrower, lender, asset, principal, terms, rates),
            salt_:      "SALT"
        });
    }

    function encodeWithSignatureAndUint(string memory signature, uint256 arg) internal pure returns (bytes[] memory calls) {
        calls    = new bytes[](1);
        calls[0] = abi.encodeWithSignature(signature, arg);
    }

    function setupFees(
        uint256 platformOriginationFeeRate,
        uint256 platformServiceFeeRate,
        uint256 platformManagementFeeRate,
        uint256 delegateOriginationFee,
        uint256 delegateServiceFee,
        uint256 delegateManagementFeeRate
    ) internal {
        vm.startPrank(governor);
        globals.setPlatformOriginationFeeRate(address(poolManager), platformOriginationFeeRate);
        globals.setPlatformServiceFeeRate(address(poolManager), platformServiceFeeRate);
        globals.setPlatformManagementFeeRate(address(poolManager), platformManagementFeeRate);
        vm.stopPrank();

        nextDelegateOriginationFee = delegateOriginationFee;
        nextDelegateServiceFee     = delegateServiceFee;

        setDelegateManagementFeeRate(address(poolManager), delegateManagementFeeRate);
    }

    /**************************************************************************************************************************************/
    /*** Common: Actions                                                                                                                ***/
    /**************************************************************************************************************************************/

    // TODO: Remove those helpers and use the ones from ProtocolActions directly.

    function deposit(address lp, uint256 liquidity) internal returns (uint256 shares) {
        shares = deposit(address(pool), lp, liquidity);
    }

    function requestRedeem(address lp, uint256 amount) internal {
        requestRedeem(address(pool), lp, amount);
    }

    function redeem(address lp, uint256 amount) internal returns (uint256 assets_) {
        assets_ = redeem(address(pool), lp, amount);
    }

}
