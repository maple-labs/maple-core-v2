// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console2 as console } from "../modules/forge-std/src/console2.sol";

import {
    IAssetController,
    IAssetControllerOracle,
    IBitcoinStrategy,
    ICompositeToken,
    IFeeManager,
    IFixedTermLoan,
    IFixedTermLoanManager,
    IFixedTermRefinancer,
    IGlobals,
    ILoanLike,
    IMapleProxyFactory,
    IMockERC20,
    IOpenTermRefinancer,
    IPool,
    IPoolDelegateCover,
    IPoolDeployer,
    IPoolManager,
    IPoolPermissionManager,
    IPoolPermissionManagerInitializer,
    ISyrupBitcoinRouter,
    IWithdrawalManagerCyclical,
    IWithdrawalManagerQueue
} from "../contracts/interfaces/Interfaces.sol";

import { ProtocolActions } from "../contracts/ProtocolActions.sol";

import { MockLiquidationStrategy } from "./mocks/Mocks.sol";

contract TestBase is ProtocolActions {

    uint256 constant MAX_TOKEN_AMOUNT = 1e29;

    uint256 constant ONE_DAY   = 1 days;
    uint256 constant ONE_MONTH = ONE_YEAR / 12;
    uint256 constant ONE_YEAR  = 365 days;

    string constant POOL_NAME   = "Maple Pool";
    string constant POOL_SYMBOL = "MP";

    address governor;
    address migrationAdmin;
    address operationalAdmin;
    address poolDelegate;
    address permissionAdmin;
    address securityAdmin;
    address strategyManager;
    address treasury;
    address redeemer;

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

    address aaveStrategyFactory;
    address basicStrategyFactory;
    address cyclicalWMFactory;
    address fixedTermLoanFactory;
    address fixedTermLoanManagerFactory;
    address liquidatorFactory;
    address openTermLoanFactory;
    address openTermLoanManagerFactory;
    address poolManagerFactory;
    address queueWMFactory;
    address skyStrategyFactory;
    address coreStrategyFactory;
    address bitcoinStrategyFactory;

    address aaveStrategyImplementation;
    address basicStrategyImplementation;
    address cyclicalWMImplementation;
    address fixedTermLoanImplementation;
    address fixedTermLoanManagerImplementation;
    address liquidatorImplementation;
    address openTermLoanImplementation;
    address openTermLoanManagerImplementation;
    address poolManagerImplementation;
    address queueWMImplementation;
    address skyStrategyImplementation;
    address coreStrategyImplementation;
    address bitcoinStrategyImplementation;

    address aaveStrategyInitializer;
    address basicStrategyInitializer;
    address fixedTermLoanInitializer;
    address fixedTermLoanManagerInitializer;
    address liquidatorInitializer;
    address openTermLoanInitializer;
    address openTermLoanManagerInitializer;
    address poolManagerInitializer;
    address poolPermissionManagerInitializer;
    address cyclicalWMInitializer;
    address queueWMInitializer;
    address skyStrategyInitializer;
    address coreStrategyInitializer;
    address bitcoinStrategyInitializer;

    address borrowerActions;

    uint256 nextDelegateOriginationFee;
    uint256 nextDelegateServiceFee;

    uint32  startingTime;
    uint256 start;

    address[] strategyFactories;
    address[] poolManagers;

    bytes32[] functionIds;

    // Avoid stack-too-deep error.
    bytes[] strategyDeploymentData_;

    IFeeManager                fixedTermFeeManager;
    IFixedTermRefinancer       fixedTermRefinancer;
    IGlobals                   globals;
    IOpenTermRefinancer        openTermRefinancer;
    IPool                      pool;
    IPoolDelegateCover         poolCover;
    IPoolDeployer              deployer;
    IPoolManager               poolManager;
    IPoolPermissionManager     poolPermissionManager;
    IWithdrawalManagerCyclical cyclicalWM;
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

    function setUp() public virtual {
        start = block.timestamp;

        _createAccounts();
        _createGlobals();
        _createAssets();
        _configureGlobals();
        _createFactories();
        _createAndConfigurePool(start, 1 weeks, 2 days);

        openPool(address(poolManager));
    }

    function _setupBitcoinPool() internal {
        start        = block.timestamp;
        startingTime = uint32(start);

        _createAccounts();
        _createGlobals();
        _createAssets();
        _configureGlobals();
        _createFactories();
        _createBitcoinPool();
        _createPeripheryContracts();
        _configurePeripheryContracts();
    }

    /**************************************************************************************************************************************/
    /*** Initialization Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    function _createAccounts() internal {
        governor         = makeAddr("governor");
        migrationAdmin   = makeAddr("migrationAdmin");
        operationalAdmin = makeAddr("operationalAdmin");
        poolDelegate     = makeAddr("poolDelegate");
        permissionAdmin  = makeAddr("permissionAdmin");
        securityAdmin    = makeAddr("securityAdmin");
        strategyManager  = makeAddr("strategyManager");
        treasury         = makeAddr("treasury");
        redeemer         = makeAddr("redeemer");
    }

    function _createGlobals() internal {
        globals  = IGlobals(deployNTP(governor, deploy("MapleGlobals")));
        deployer = IPoolDeployer(deploy("MaplePoolDeployer", abi.encode(address(globals))));
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
        globals.setValidCollateralAsset(address(collateralAsset), true);
        globals.setValidPoolDelegate(poolDelegate, true);
        globals.setManualOverridePrice(address(fundsAsset),      1e8);     // 1     USD / 1 USDC
        globals.setManualOverridePrice(address(collateralAsset), 1500e8);  // 1_500 USD / 1 WETH
        globals.setDefaultTimelockParameters(1 weeks, 2 days);
        globals.setMapleTreasury(treasury);
        vm.stopPrank();
    }

    function _createFactories() internal {
        cyclicalWMFactory           = deployFromFile("Contracts@7", "WithdrawalManagerCyclicalFactory", abi.encode(address(globals)));
        fixedTermLoanFactory        = deployFromFile("Contracts@7", "FixedTermLoanFactory",             abi.encode(address(globals), address(0)));
        fixedTermLoanManagerFactory = deployFromFile("Contracts@7", "FixedTermLoanManagerFactory",      abi.encode(address(globals)));
        liquidatorFactory           = deployFromFile("Contracts@7", "LiquidatorFactory",                abi.encode(address(globals)));
        openTermLoanFactory         = deployFromFile("Contracts@7", "OpenTermLoanFactory",              abi.encode(address(globals)));
        openTermLoanManagerFactory  = deployFromFile("Contracts@7", "OpenTermLoanManagerFactory",       abi.encode(address(globals)));
        poolManagerFactory          = deployFromFile("Contracts@7", "PoolManagerFactory",               abi.encode(address(globals)));
        queueWMFactory              = deployFromFile("Contracts@7", "WithdrawalManagerQueueFactory",    abi.encode(address(globals)));

        fixedTermLoanImplementation        = deployFromFile("Contracts@7",  "FixedTermLoan");
        fixedTermLoanManagerImplementation = deployFromFile("Contracts@7",  "FixedTermLoanManager");
        liquidatorImplementation           = deployFromFile("Contracts@7",  "Liquidator");
        openTermLoanImplementation         = deployFromFile("Contracts@7",  "OpenTermLoan");
        openTermLoanManagerImplementation  = deployFromFile("Contracts@7",  "OpenTermLoanManager");
        poolManagerImplementation          = deployFromFile("Contracts@25", "PoolManager");
        cyclicalWMImplementation           = deployFromFile("Contracts@7",  "WithdrawalManagerCyclical");
        queueWMImplementation              = deployFromFile("Contracts@7",  "WithdrawalManagerQueue");

        fixedTermLoanInitializer        = deployFromFile("Contracts@7",  "FixedTermLoanInitializer");
        fixedTermLoanManagerInitializer = deployFromFile("Contracts@7",  "FixedTermLoanManagerInitializer");
        liquidatorInitializer           = deployFromFile("Contracts@7",  "LiquidatorInitializer");
        openTermLoanInitializer         = deployFromFile("Contracts@7",  "OpenTermLoanInitializer");
        openTermLoanManagerInitializer  = deployFromFile("Contracts@7",  "OpenTermLoanManagerInitializer");
        poolManagerInitializer          = deployFromFile("Contracts@25", "PoolManagerInitializer");
        cyclicalWMInitializer           = deployFromFile("Contracts@7",  "WithdrawalManagerCyclicalInitializer");
        queueWMInitializer              = deployFromFile("Contracts@7",  "WithdrawalManagerQueueInitializer");

        fixedTermFeeManager = IFeeManager(deployFromFile("Contracts@7","FeeManager", abi.encode(address(globals))));
        fixedTermRefinancer = IFixedTermRefinancer(deployFromFile("Contracts@7","FixedTermRefinancer"));
        openTermRefinancer  = IOpenTermRefinancer(deployFromFile("Contracts@7","OpenTermRefinancer"));

        address poolPermissionManagerImplementation = deployFromFile("Contracts@7","PoolPermissionManager");
        poolPermissionManagerInitializer            = deployFromFile("Contracts@7","PoolPermissionManagerInitializer");

        poolPermissionManager = IPoolPermissionManager(deployNTP(governor, poolPermissionManagerInitializer));

        aaveStrategyFactory           = deployFromFile("Contracts@25", "StrategyFactory", abi.encode(address(globals)));
        basicStrategyFactory          = deployFromFile("Contracts@25", "StrategyFactory", abi.encode(address(globals)));
        skyStrategyFactory            = deployFromFile("Contracts@25", "StrategyFactory", abi.encode(address(globals)));
        coreStrategyFactory           = deployFromFile("Contracts@25", "StrategyFactory", abi.encode(address(globals)));
        bitcoinStrategyFactory        = deployFromFile("Contracts@25", "StrategyFactory", abi.encode(address(globals)));
        aaveStrategyImplementation    = deployFromFile("Contracts@25", "AaveStrategy");
        basicStrategyImplementation   = deployFromFile("Contracts@25", "BasicStrategy");
        skyStrategyImplementation     = deployFromFile("Contracts@25", "SkyStrategy");
        coreStrategyImplementation    = deployFromFile("Contracts@25", "CoreStrategy");
        bitcoinStrategyImplementation = deployFromFile("Contracts@25", "BitcoinStrategy");
        aaveStrategyInitializer       = deployFromFile("Contracts@25", "AaveStrategyInitializer");
        basicStrategyInitializer      = deployFromFile("Contracts@25", "BasicStrategyInitializer");
        skyStrategyInitializer        = deployFromFile("Contracts@25", "SkyStrategyInitializer");
        coreStrategyInitializer       = deployFromFile("Contracts@25", "CoreStrategyInitializer");
        bitcoinStrategyInitializer    = deployFromFile("Contracts@25", "BitcoinStrategyInitializer");

        borrowerActions = deployNTP(securityAdmin, deployFromFile("Contracts@25", "BorrowerActions"));

        vm.startPrank(governor);

        IPoolPermissionManagerInitializer(address(poolPermissionManager)).initialize(poolPermissionManagerImplementation, address(globals));
        poolPermissionManager.setPermissionAdmin(permissionAdmin, true);

        globals.setValidInstanceOf("LIQUIDATOR_FACTORY",               liquidatorFactory,             true);
        globals.setValidInstanceOf("LOAN_FACTORY",                     fixedTermLoanFactory,          true);
        globals.setValidInstanceOf("FT_LOAN_FACTORY",                  fixedTermLoanFactory,          true);
        globals.setValidInstanceOf("LOAN_FACTORY",                     openTermLoanFactory,           true);
        globals.setValidInstanceOf("OT_LOAN_FACTORY",                  openTermLoanFactory,           true);
        globals.setValidInstanceOf("LOAN_MANAGER_FACTORY",             fixedTermLoanManagerFactory,   true);
        globals.setValidInstanceOf("STRATEGY_FACTORY",                 fixedTermLoanManagerFactory,   true);
        globals.setValidInstanceOf("FT_LOAN_MANAGER_FACTORY",          fixedTermLoanManagerFactory,   true);
        globals.setValidInstanceOf("OT_LOAN_MANAGER_FACTORY",          openTermLoanManagerFactory,    true);
        globals.setValidInstanceOf("LOAN_MANAGER_FACTORY",             openTermLoanManagerFactory,    true);
        globals.setValidInstanceOf("STRATEGY_FACTORY",                 openTermLoanManagerFactory,    true);
        globals.setValidInstanceOf("POOL_MANAGER_FACTORY",             poolManagerFactory,            true);
        globals.setValidInstanceOf("WITHDRAWAL_MANAGER_CYCLE_FACTORY", cyclicalWMFactory,             true);
        globals.setValidInstanceOf("WITHDRAWAL_MANAGER_QUEUE_FACTORY", queueWMFactory,                true);
        globals.setValidInstanceOf("WITHDRAWAL_MANAGER_FACTORY",       cyclicalWMFactory,             true);
        globals.setValidInstanceOf("WITHDRAWAL_MANAGER_FACTORY",       queueWMFactory,                true);
        globals.setValidInstanceOf("STRATEGY_FACTORY",                 aaveStrategyFactory,           true);
        globals.setValidInstanceOf("STRATEGY_FACTORY",                 basicStrategyFactory,          true);
        globals.setValidInstanceOf("STRATEGY_FACTORY",                 skyStrategyFactory,            true);
        globals.setValidInstanceOf("STRATEGY_FACTORY",                 coreStrategyFactory,           true);
        globals.setValidInstanceOf("STRATEGY_FACTORY",                 bitcoinStrategyFactory,        true);
        globals.setValidInstanceOf("POOL_PERMISSION_MANAGER",          address(poolPermissionManager),true);
        globals.setValidInstanceOf("REFINANCER",                       address(openTermRefinancer),   true);
        globals.setValidInstanceOf("OT_REFINANCER",                    address(openTermRefinancer),   true);
        globals.setValidInstanceOf("REFINANCER",                       address(fixedTermRefinancer),  true);
        globals.setValidInstanceOf("FT_REFINANCER",                    address(fixedTermRefinancer),  true);
        globals.setValidInstanceOf("FEE_MANAGER",                      address(fixedTermFeeManager),  true);
        globals.setValidInstanceOf("STRATEGY_MANAGER",                 strategyManager,               true);
        globals.setValidInstanceOf("COMPOSITE_DEPOSIT_ASSET",          address(depositAsset),         true);
        globals.setValidInstanceOf("COMPOSITE_POOL_ASSET",             compositeTokenProxy,           true);
        globals.setValidInstanceOf("SYRUP_BTC_REDEEMER",                redeemer,                     true);

        globals.setCanDeployFrom(aaveStrategyFactory,         address(deployer), true);
        globals.setCanDeployFrom(basicStrategyFactory,        address(deployer), true);
        globals.setCanDeployFrom(fixedTermLoanManagerFactory, address(deployer), true);
        globals.setCanDeployFrom(poolManagerFactory,          address(deployer), true);
        globals.setCanDeployFrom(cyclicalWMFactory,           address(deployer), true);
        globals.setCanDeployFrom(queueWMFactory,              address(deployer), true);
        globals.setCanDeployFrom(skyStrategyFactory,          address(deployer), true);
        globals.setCanDeployFrom(coreStrategyFactory,         address(deployer), true);
        globals.setCanDeployFrom(bitcoinStrategyFactory,      address(deployer), true);

        IMapleProxyFactory(liquidatorFactory).registerImplementation(1, liquidatorImplementation, liquidatorInitializer);
        IMapleProxyFactory(liquidatorFactory).setDefaultVersion(1);

        IMapleProxyFactory(fixedTermLoanFactory).registerImplementation(1, fixedTermLoanImplementation, fixedTermLoanInitializer);
        IMapleProxyFactory(fixedTermLoanFactory).setDefaultVersion(1);

        IMapleProxyFactory(fixedTermLoanManagerFactory).registerImplementation(
            1,
            fixedTermLoanManagerImplementation,
            fixedTermLoanManagerInitializer
        );
        IMapleProxyFactory(fixedTermLoanManagerFactory).setDefaultVersion(1);

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

        IMapleProxyFactory(cyclicalWMFactory).registerImplementation(1, cyclicalWMImplementation, cyclicalWMInitializer);
        IMapleProxyFactory(cyclicalWMFactory).setDefaultVersion(1);

        IMapleProxyFactory(queueWMFactory).registerImplementation(1, queueWMImplementation, queueWMInitializer);
        IMapleProxyFactory(queueWMFactory).setDefaultVersion(1);

        IMapleProxyFactory(aaveStrategyFactory).registerImplementation(1, aaveStrategyImplementation, aaveStrategyInitializer);
        IMapleProxyFactory(aaveStrategyFactory).setDefaultVersion(1);

        IMapleProxyFactory(basicStrategyFactory).registerImplementation(1, basicStrategyImplementation, basicStrategyInitializer);
        IMapleProxyFactory(basicStrategyFactory).setDefaultVersion(1);

        IMapleProxyFactory(skyStrategyFactory).registerImplementation(1, skyStrategyImplementation, skyStrategyInitializer);
        IMapleProxyFactory(skyStrategyFactory).setDefaultVersion(1);

        IMapleProxyFactory(coreStrategyFactory).registerImplementation(1, coreStrategyImplementation, coreStrategyInitializer);
        IMapleProxyFactory(coreStrategyFactory).setDefaultVersion(1);

        IMapleProxyFactory(bitcoinStrategyFactory).registerImplementation(1, bitcoinStrategyImplementation, bitcoinStrategyInitializer);
        IMapleProxyFactory(bitcoinStrategyFactory).setDefaultVersion(1);

        vm.stopPrank();

        strategyFactories.push(fixedTermLoanManagerFactory);
        strategyFactories.push(openTermLoanManagerFactory);
    }

    function _createPoolWithCyclical(
        uint256 startTime,
        uint256 withdrawalCycle,
        uint256 windowDuration
    )
        internal returns (
            address pool_,
            address pm_,
            address wm_
        )
    {
        uint256[7] memory configParams_ = [type(uint256).max, 0, 0, withdrawalCycle, windowDuration, 0, startTime];

        _setupDeploymentData();

        poolManager = IPoolManager(deployPoolWithCyclical(
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
        ));

        poolManagers.push(address(poolManager));

        cyclicalWM = IWithdrawalManagerCyclical(poolManager.withdrawalManager());
        pool       = IPool(poolManager.pool());
        poolCover  = IPoolDelegateCover(poolManager.poolDelegateCover());

        pool_ = address(pool);
        pm_   = address(poolManager);
        wm_   = address(cyclicalWM);
    }

    // TODO: Update required to support non LM strategies.
    function _setupDeploymentData() internal {

        for (uint256 i = 0; i < strategyFactories.length; i++) {
            strategyDeploymentData_.push(abi.encode(new bytes(0)));
        }
    }

    function _createPoolWithQueue(address poolDelegate_, string memory poolName_) internal returns (address pool_, address pm_, address wm_) {
        string memory symbol_ = "MP";

        address poolManagerDeployment = IMapleProxyFactory(poolManagerFactory).getInstanceAddress(
            abi.encode(poolDelegate_, fundsAsset, 0, poolName_, symbol_), // 0 is the initial supply
            keccak256(abi.encode(poolDelegate_))
        );

        bytes[] memory strategyDeploymentData2_ = new bytes[](strategyFactories.length);
        for (uint256 i = 0; i < strategyFactories.length; i++) {
            strategyDeploymentData2_[i] = abi.encode(poolManagerDeployment);
        }

        poolManager = IPoolManager(deployPoolWithQueue(
            address(poolDelegate_),
            address(deployer),
            address(poolManagerFactory),
            address(queueWMFactory),
            strategyFactories,
            strategyDeploymentData2_,
            address(fundsAsset),
            address(poolPermissionManager),
            poolName_,
            symbol_,
            [type(uint256).max, 0, 0, 0]
        ));

        poolManagers.push(address(poolManager));

        queueWM   = IWithdrawalManagerQueue(poolManager.withdrawalManager());
        pool      = IPool(poolManager.pool());
        poolCover = IPoolDelegateCover(poolManager.poolDelegateCover());

        pool_ = address(pool);
        pm_   = address(poolManager);
        wm_   = address(queueWM);
    }

    function _createPoolWithQueue() internal {
        string memory name_   = "Maple Pool";
        string memory symbol_ = "MP";

        strategyDeploymentData_ = new bytes[](strategyFactories.length);
        for (uint256 i = 0; i < strategyFactories.length; i++) {
            strategyDeploymentData_[i] = abi.encode(new bytes(0));
        }

        poolManager = IPoolManager(deployPoolWithQueue(
            address(poolDelegate),
            address(deployer),
            address(poolManagerFactory),
            address(queueWMFactory),
            strategyFactories,
            strategyDeploymentData_,
            address(fundsAsset),
            address(poolPermissionManager),
            name_,
            symbol_,
            [type(uint256).max, 0, 0, 0]
        ));

        poolManagers.push(address(poolManager));

        queueWM   = IWithdrawalManagerQueue(poolManager.withdrawalManager());
        pool      = IPool(poolManager.pool());
        poolCover = IPoolDelegateCover(poolManager.poolDelegateCover());
    }

    function _createBitcoinPool() internal {
        address[] memory strategyFactories_  = new address[](4);
        bytes[]   memory additionalCalldata_ = new bytes[](4);

        // Creates 4 distinct bitcoin strategies.
        for (uint i; i < 4; i++) {
            strategyFactories_[i]  = address(bitcoinStrategyFactory);
            additionalCalldata_[i] = abi.encode("");
        }

        poolManager = IPoolManager(deployPoolWithQueue(
            address(poolDelegate),
            address(deployer),
            address(poolManagerFactory),
            address(queueWMFactory),
            strategyFactories_,
            additionalCalldata_,
            address(compositeAsset),
            address(poolPermissionManager),
            "Syrup BTC Pool",
            "syrupBTC",
            [type(uint256).max, 0, 0, 0]
        ));

        poolManagers.push(address(poolManager));

        pool              = IPool(poolManager.pool());
        withdrawalManager = IWithdrawalManagerQueue(poolManager.withdrawalManager());
        bitcoinStrategy   = IBitcoinStrategy(poolManager.strategyList(0));

        // Whitelist all of the bitcoin strategies on globals.
        for (uint i; i < 4; i++) {
            address strategy = poolManager.strategyList(i);

            vm.prank(governor);
            globals.setValidInstanceOf("BITCOIN_STRATEGY", address(strategy), true);
        }

        activatePool(address(poolManager), HUNDRED_PERCENT);
    }

    function _createPeripheryContracts() internal {
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
                    "initialize(address,address,address)",
                    priceOracleProxy,
                    compositeTokenProxy,
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

    function _configurePeripheryContracts() internal {
        // Allow usage of composite tokens only for the pool, router, controller, and all bitcoin strategies.
        address[] memory addresses = new address[](7);
        bool[]    memory allowed   = new bool[](7);

        addresses[0] = address(pool);
        addresses[1] = address(assetController);
        addresses[2] = address(bitcoinRouter);
        addresses[3] = poolManager.strategyList(0);
        addresses[4] = poolManager.strategyList(1);
        addresses[5] = poolManager.strategyList(2);
        addresses[6] = poolManager.strategyList(3);

        allowed[0] = true;
        allowed[1] = true;
        allowed[2] = true;
        allowed[3] = true;
        allowed[4] = true;
        allowed[5] = true;
        allowed[6] = true;

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
        addresses = new address[](4);
        allowed   = new bool[](4);

        addresses[0] = poolManager.strategyList(0);
        addresses[1] = poolManager.strategyList(1);
        addresses[2] = poolManager.strategyList(2);
        addresses[3] = poolManager.strategyList(3);

        allowed[0] = true;
        allowed[1] = true;
        allowed[2] = true;
        allowed[3] = true;

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

        for (uint i; i < 4; i++) {
            address strategy = poolManager.strategyList(i);

            vm.prank(governor);
            IBitcoinStrategy(strategy).setAssetController(address(depositAsset), address(assetController));
        }

        // Allow the strategy manager to deploy, schedule, and reconcile all strategies.
        addresses[0] = strategyManager;
        allowed[0]   = true;

        for (uint i; i < 4; i++) {
            address strategy = poolManager.strategyList(i);

            vm.prank(governor);
            IBitcoinStrategy(strategy).setPermissions(addresses, allowed, allowed, allowed);
        }

        // Allow only the router to interact with the pool.
        addresses = new address[](1);
        allowed   = new bool[](1);

        addresses[0] = address(bitcoinRouter);
        allowed[0]   = true;

        vm.prank(governor);
        poolPermissionManager.setLenderAllowlist(address(poolManager), addresses, allowed);

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
    }

    function _configurePool() internal {
        activatePool(address(poolManager), HUNDRED_PERCENT);
        allowLender(address(poolManager), address(cyclicalWM));
    }

    function _createAndConfigurePool(uint256 startTime, uint256 withdrawalCycle, uint256 windowDuration) internal {
        _createPoolWithCyclical(startTime, withdrawalCycle, windowDuration);
        activatePool(address(poolManager), HUNDRED_PERCENT);
        allowLender(address(poolManager), address(cyclicalWM));
    }

    function _createPoolWithQueueAndStrategies(
        address fundsAsset_,
        address[] memory strategiesFactories_,
        bytes[] memory strategiesData_
    )
        internal
    {
        poolManager = IPoolManager(deployPoolWithQueue(
            address(poolDelegate),
            address(deployer),
            address(poolManagerFactory),
            address(queueWMFactory),
            strategiesFactories_,
            strategiesData_,
            fundsAsset_,
            address(poolPermissionManager),
            POOL_NAME,
            POOL_SYMBOL,
            [type(uint256).max, 0, 0, 0]
        ));

        poolManagers.push(address(poolManager));

        queueWM   = IWithdrawalManagerQueue(poolManager.withdrawalManager());
        pool      = IPool(poolManager.pool());
        poolCover = IPoolDelegateCover(poolManager.poolDelegateCover());
    }

    function _createAdditionalPoolWithQueueAndStrategies(
        address fundsAsset_,
        address poolDelegate_,
        address[] memory strategiesFactories_,
        bytes[] memory strategiesData_
    )
        internal returns (address pool_, address pm_, address wm_)
    {
        IPoolManager poolManager_ = IPoolManager(deployPoolWithQueue(
            address(poolDelegate_),
            address(deployer),
            address(poolManagerFactory),
            address(queueWMFactory),
            strategiesFactories_,
            strategiesData_,
            fundsAsset_,
            address(poolPermissionManager),
            "NAME",
            "SYMBOL",
            [type(uint256).max, 0, 0, 0]
        ));

        wm_   = poolManager_.withdrawalManager();
        pool_ = poolManager_.pool();
        pm_   = address(poolManager_);
    }

    /**************************************************************************************************************************************/
    /*** Helper Functions                                                                                                               ***/
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

    /**
     *  @param termDetails Array of loan parameters:
     *                       [0]: gracePeriod
     *                       [1]: paymentInterval
     *                       [2]: numberOfPayments
     *  @param amounts     Requested amounts:
     *                       [0]: collateralRequired
     *                       [1]: principalRequested
     *                       [2]: endingPrincipal
     *  @param rates       Rates parameters:
     *                       [0]: interestRate
     *                       [1]: closingFeeRate
     *                       [2]: lateFeeRate
     *                       [3]: lateInterestPremium
     */
    function createFixedTermLoan(
        address           borrower,
        uint256[3] memory termDetails,
        uint256[3] memory amounts,
        uint256[4] memory rates,
        address           loanManager
    )
        internal returns (address loan)
    {
        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

        vm.prank(borrower);
        loan = IMapleProxyFactory(fixedTermLoanFactory).createInstance({
            arguments_: abi.encode(
                borrower,
                loanManager,
                address(fixedTermFeeManager),
                [address(collateralAsset), address(fundsAsset)],
                termDetails,
                amounts,
                rates,
                [nextDelegateOriginationFee, nextDelegateServiceFee]
            ),
            salt_: "SALT"
        });
    }

    function createFixedTermLoan(
        address           borrower,
        address           lender,
        address           feeManager,
        address[2] memory assets,
        uint256[3] memory terms,
        uint256[3] memory amounts,
        uint256[4] memory rates,
        uint256[2] memory fees
    )
        internal returns (address loan)
    {
        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

        vm.prank(borrower);
        loan = IMapleProxyFactory(fixedTermLoanFactory).createInstance({
            arguments_: abi.encode(borrower, lender, feeManager, assets, terms, amounts, rates, fees),
            salt_: "SALT"
        });
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
            salt_: "SALT"
        });
    }

    function encodeWithSignatureAndUint(string memory signature, uint256 arg) internal pure returns (bytes[] memory calls) {
        calls    = new bytes[](1);
        calls[0] = abi.encodeWithSignature(signature, arg);
    }

    function liquidateCollateral(address loan) internal {
        MockLiquidationStrategy mockLiquidationStrategy = MockLiquidationStrategy(deployMock("MockLiquidationStrategy"));

        ( , , , , , address liquidator ) = IFixedTermLoanManager(ILoanLike(loan).lender()).liquidationInfo(loan);

        mockLiquidationStrategy.flashBorrowLiquidation(
            liquidator,
            collateralAsset.balanceOf(address(liquidator)),
            address(collateralAsset),
            address(fundsAsset),
            loan
        );
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
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function defaultLoan(address loan) internal {
        triggerDefault(address(loan), address(liquidatorFactory));
    }

    function depositCover(uint256 cover) internal {
        depositCover(address(poolManager), cover);
    }

    function deposit(address lp, uint256 liquidity) internal returns (uint256 shares) {
        shares = deposit(address(pool), lp, liquidity);
    }

    function fundAndDrawdownLoan(
        address           borrower,
        uint256[3] memory termDetails,
        uint256[3] memory amounts,
        uint256[4] memory rates,
        address           loanManager
    )
        internal returns (address loan)
    {
        loan = createFixedTermLoan(borrower, termDetails, amounts, rates, loanManager);

        fundLoan(address(loan));

        drawdown(address(loan), IFixedTermLoan(loan).drawableFunds());
    }

    function requestRedeem(address lp, uint256 amount) internal {
        requestRedeem(address(pool), lp, amount);
    }

    function redeem(address lp, uint256 amount) internal returns (uint256 assets_) {
        assets_ = redeem(address(pool), lp, amount);
    }

}
