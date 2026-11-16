// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console } from "../modules/forge-std/src/Test.sol";

import {
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
import { Utils } from "../contracts/Utils.sol";

contract TestBase is ProtocolActions, Utils {

    uint256 constant MAINNET_FORK_BLOCK = 25_523_119;
    uint256 constant SKY_ANNUAL_APY     = 0.036e6; // 3.6% over 365 days at MAINNET_FORK_BLOCK.

    uint256 constant MAX_TOKEN_AMOUNT = 1e29;

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
    address securityAdmin;
    address strategyDelegate;
    address strategyManager;
    address treasury;

    address aaveV3StrategyFactory;
    address liquidatorFactory;
    address openTermLoanFactory;
    address openTermLoanManagerFactory;
    address poolManagerFactory;
    address queueWMFactory;
    address skyStrategyFactory;
    address strategyManagerFactory;
    address allocationStrategyFactory;

    address aaveV3StrategyImplementation;
    address openTermLoanImplementation;
    address openTermLoanManagerImplementation;
    address poolManagerImplementation;
    address poolPermissionManagerImplementation;
    address queueWMImplementation;
    address skyStrategyImplementation;
    address strategyManagerImplementation;
    address allocationStrategyImplementation;

    address aaveV3StrategyInitializer;
    address openTermLoanInitializer;
    address openTermLoanManagerInitializer;
    address poolManagerInitializer;
    address poolPermissionManagerInitializer;
    address queueWMInitializer;
    address skyStrategyInitializer;
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

    uint32 startingTime;
    uint256 start;

    address[] managedWallets;
    address[] pools;
    address[] poolManagers;
    address[] strategyFactories;
    address[] strategyManagers;
    address[] withdrawalManagers;

    bytes32[] functionIds;

    // Avoid stack-too-deep error.
    bytes[] strategyDeploymentData_;

    IGlobals globals;
    IGovernorTimelock governorTimelock;
    IMapleLiquidityRouter liquidityRouter;
    IPool pool;
    IPoolDeployer poolDeployer;
    IPoolManager poolManager;
    IPoolPermissionManager poolPermissionManager;
    IStrategyDeployer strategyDeployer;
    IWithdrawalManagerQueue queueWM;
    IWithdrawalManagerQueue withdrawalManager;

    IMockERC20 collateralAsset;
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

        (pool_, pm_, wm_) =
            _createPoolWithMultipleStrategies(poolDelegate_, address(fundsAsset), POOL_NAME, strategyFactories, strategyData);
    }

    function _createPoolWithMultipleStrategies(
        address poolDelegate_,
        address fundsAsset_,
        string memory name_,
        address[] memory strategyFactories_,
        bytes[] memory strategyData_
    )
        internal
        returns (address pool_, address pm_, address wm_)
    {
        poolManager = IPoolManager(
            _deployPoolWithQueue({
                poolDelegate_: poolDelegate_,
                fundsAsset_: fundsAsset_,
                strategyFactories_: strategyFactories_,
                strategyData_: strategyData_,
                name_: name_,
                symbol_: POOL_SYMBOL,
                liquidityCap_: type(uint256).max,
                delegateManagementFeeRate_: 0
            })
        );

        pool    = IPool(poolManager.pool());
        queueWM = IWithdrawalManagerQueue(poolManager.withdrawalManager());

        pools.push(address(pool));
        poolManagers.push(address(poolManager));
        withdrawalManagers.push(address(queueWM));

        pool_ = address(pool);
        pm_   = address(poolManager);
        wm_   = address(queueWM);
    }

    function _configurePool() internal {
        activatePool(address(poolManager), HUNDRED_PERCENT);
        allowLender(address(poolManager), address(queueWM));
    }

    function _createPoolSharingStrategy(
        string memory delegateLabel_,
        address strategyManager_
    )
        internal
        returns (address pool_, address poolManager_)
    {
        address poolDelegate_ = makeAddr(delegateLabel_);

        vm.prank(governor);
        globals.setValidPoolDelegate(poolDelegate_, true);

        (pool_, poolManager_,) = _createPoolWithOTLM(poolDelegate_);

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
        uint32 strategyDelegateFeeRate_,
        uint32 strategyProtocolFeeRate_,
        uint256 strategyLiquidityCap_,
        uint256 bootstrapMint_
    )
        internal
        returns (address strategyManager_, address underlyingStrategy_)
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

        (strategyManager_, underlyingStrategy_) = strategyDeployer.deploy({
            strategyManagerFactory: strategyManagerFactory,
            strategyFactory:        allocationStrategyFactory,
            strategyLiquidityCap:   strategyLiquidityCap_,
            strategyDeploymentData: abi.encode(params),
            bootstrapFundingData:   ""
        });

        vm.prank(governor);
        globals.activateStrategyManager(strategyManager_);

        strategyManagers.push(strategyManager_);
    }

    function _setManagedWallet(
        address strategy_,
        address managedWallet_,
        bool canDeployAssets_,
        bool canReturnAssets_,
        bool canRealizeYield_,
        uint256 deploymentCap_
    )
        internal
    {
        setManagedWallet(strategy_, managedWallet_, canDeployAssets_, canReturnAssets_, canRealizeYield_, deploymentCap_);

        managedWallets.push(managedWallet_);
    }

    function _deployAaveV3Strategy(
        address strategyDelegate_,
        address aaveToken_,
        bool useVirtualUnderlyingBalance_,
        uint32 strategyDelegateFeeRate_,
        uint32 strategyProtocolFeeRate_,
        uint256 strategyLiquidityCap_,
        uint256 bootstrapMint_
    )
        internal
        returns (address strategyManager_, address underlyingStrategy_)
    {
        AaveV3StrategyInitializerParams memory params = AaveV3StrategyInitializerParams({
            aaveToken:                   aaveToken_,
            strategyDelegateFeeRate:     strategyDelegateFeeRate_,
            strategyProtocolFeeRate:     strategyProtocolFeeRate_,
            referralCode:                0,
            useVirtualUnderlyingBalance: useVirtualUnderlyingBalance_,
            strategyMetadata:            ""
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

        (strategyManager_, underlyingStrategy_) = strategyDeployer.deploy({
            strategyManagerFactory: strategyManagerFactory,
            strategyFactory:        aaveV3StrategyFactory,
            strategyLiquidityCap:   strategyLiquidityCap_,
            strategyDeploymentData: abi.encode(params),
            bootstrapFundingData:   ""
        });

        vm.prank(governor);
        globals.activateStrategyManager(strategyManager_);

        strategyManagers.push(strategyManager_);
    }

    function _deploySkyStrategy(
        address strategyDelegate_,
        address fundsAsset_,
        address savingsUsds_,
        address psm_,
        uint32 strategyDelegateFeeRate_,
        uint32 strategyProtocolFeeRate_,
        uint256 strategyLiquidityCap_,
        uint256 bootstrapMint_
    )
        internal
        returns (address strategyManager_, address underlyingStrategy_)
    {
        SkyStrategyInitializerParams memory params = SkyStrategyInitializerParams({
            fundsAsset:              fundsAsset_,
            psm:                     psm_,
            savingsUsds:             savingsUsds_,
            strategyDelegateFeeRate: strategyDelegateFeeRate_,
            strategyProtocolFeeRate: strategyProtocolFeeRate_,
            referralCode:            0,
            strategyMetadata:        ""
        });

        vm.startPrank(governor);
        globals.setValidStrategyDelegate(strategyDelegate_, true);
        globals.setValidInstanceOf("STRATEGY_VAULT", savingsUsds_, true);
        globals.setValidInstanceOf("PSM", psm_, true);
        globals.setBootstrapMint(fundsAsset_, bootstrapMint_);
        vm.stopPrank();

        if (bootstrapMint_ != 0) {
            erc20_mint(fundsAsset_, strategyDelegate_, bootstrapMint_);
            erc20_approve(fundsAsset_, strategyDelegate_, address(strategyDeployer), bootstrapMint_);
        }

        vm.prank(strategyDelegate_);

        (strategyManager_, underlyingStrategy_) = strategyDeployer.deploy({
            strategyManagerFactory: strategyManagerFactory,
            strategyFactory:        skyStrategyFactory,
            strategyLiquidityCap:   strategyLiquidityCap_,
            strategyDeploymentData: abi.encode(params),
            bootstrapFundingData:   ""
        });

        vm.prank(governor);
        globals.activateStrategyManager(strategyManager_);

        strategyManagers.push(strategyManager_);
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
        securityAdmin      = makeAddr("securityAdmin");
        strategyDelegate   = makeAddr("strategyDelegate");
        strategyManager    = makeAddr("strategyManager");
        treasury           = makeAddr("treasury");
    }

    function _createGlobals() internal {
        globals          = IGlobals(deployNTP(governor, deploy("MapleGlobals")));
        poolDeployer     = IPoolDeployer(deploy("MaplePoolDeployer", abi.encode(address(globals))));
        strategyDeployer = IStrategyDeployer(deployFromFile("Contracts@34", "StrategyDeployer", abi.encode(address(globals))));
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

    function _createAssets() internal virtual {
        collateralAsset = IMockERC20(deployMock("ConfigurableMockERC20", abi.encode("Wrapper Ether", "WETH", 18)));
        fundsAsset      = IMockERC20(deployMock("ConfigurableMockERC20", abi.encode("USD Coin", "USDC", 6)));
    }

    function _configureGlobals() internal {
        vm.startPrank(governor);
        globals.setMigrationAdmin(migrationAdmin);
        globals.setOperationalAdmin(operationalAdmin);
        globals.setSecurityAdmin(securityAdmin);
        globals.setValidPoolAsset(address(fundsAsset), true);
        globals.setValidPoolDelegate(poolDelegate, true);
        globals.setDefaultTimelockParameters(1 weeks, 2 days);
        globals.setMapleTreasury(treasury);
        vm.stopPrank();
    }

    function _createFactories() internal {
        liquidatorFactory          = makeAddr("liquidatorFactoryStub"); // Stub: PM:TD validation passport; OTLM ignores its value.
        openTermLoanFactory        = deployFromFile("Contracts@7", "OpenTermLoanFactory", abi.encode(address(globals)));
        openTermLoanManagerFactory = deployFromFile("Contracts@7", "OpenTermLoanManagerFactory", abi.encode(address(globals)));
        poolManagerFactory         = deployFromFile("Contracts@7", "PoolManagerFactory", abi.encode(address(globals)));
        queueWMFactory             = deployFromFile("Contracts@7", "WithdrawalManagerQueueFactory", abi.encode(address(globals)));

        openTermLoanImplementation        = deployFromFile("Contracts@7", "OpenTermLoan");
        openTermLoanManagerImplementation = deployFromFile("Contracts@7", "OpenTermLoanManager");
        poolManagerImplementation         = deployFromFile("Contracts@34", "PoolManager");
        queueWMImplementation             = deployFromFile("Contracts@34", "WithdrawalManagerQueue");

        openTermLoanInitializer        = deployFromFile("Contracts@7", "OpenTermLoanInitializer");
        openTermLoanManagerInitializer = deployFromFile("Contracts@7", "OpenTermLoanManagerInitializer");
        poolManagerInitializer         = deployFromFile("Contracts@34", "PoolManagerInitializer");
        queueWMInitializer             = deployFromFile("Contracts@34", "WithdrawalManagerQueueInitializer");

        openTermRefinancer = deployFromFile("Contracts@7", "OpenTermRefinancer");

        poolPermissionManagerImplementation = deployFromFile("Contracts@7", "PoolPermissionManager");
        poolPermissionManagerInitializer    = deployFromFile("Contracts@7", "PoolPermissionManagerInitializer");

        poolPermissionManager = IPoolPermissionManager(deployNTP(governor, poolPermissionManagerInitializer));

        aaveV3StrategyFactory            = deployFromFile("Contracts@34", "AaveV3StrategyFactory", abi.encode(address(globals)));
        skyStrategyFactory               = deployFromFile("Contracts@34", "SkyStrategyFactory", abi.encode(address(globals)));
        strategyManagerFactory           = deployFromFile("Contracts@34", "StrategyManagerFactory", abi.encode(address(globals)));
        allocationStrategyFactory        = deployFromFile("Contracts@34", "AllocationStrategyFactory", abi.encode(address(globals)));
        aaveV3StrategyImplementation     = deployFromFile("Contracts@34", "AaveV3Strategy");
        skyStrategyImplementation        = deployFromFile("Contracts@34", "SkyStrategy");
        strategyManagerImplementation    = deployFromFile("Contracts@34", "StrategyManager");
        allocationStrategyImplementation = deployFromFile("Contracts@34", "AllocationStrategy");
        aaveV3StrategyInitializer        = deployFromFile("Contracts@34", "AaveV3StrategyInitializer");
        skyStrategyInitializer           = deployFromFile("Contracts@34", "SkyStrategyInitializer");
        strategyManagerInitializer       = deployFromFile("Contracts@34", "StrategyManagerInitializer");
        allocationStrategyInitializer    = deployFromFile("Contracts@34", "AllocationStrategyInitializer");

        borrowerActions = deployNTP(securityAdmin, deployFromFile("Contracts@25", "BorrowerActions"));

        liquidityRouter = IMapleLiquidityRouter(deployFromFile("Contracts@34", "LiquidityRouter", abi.encode(address(globals))));

        vm.startPrank(governor);

        IPoolPermissionManagerInitializer(address(poolPermissionManager)).initialize(poolPermissionManagerImplementation, address(globals));
        poolPermissionManager.setPermissionAdmin(permissionAdmin, true);

        globals.setValidInstanceOf("LIQUIDATOR_FACTORY", liquidatorFactory, true);
        globals.setValidInstanceOf("LOAN_FACTORY", openTermLoanFactory, true);
        globals.setValidInstanceOf("OT_LOAN_FACTORY", openTermLoanFactory, true);
        globals.setValidInstanceOf("OT_LOAN_MANAGER_FACTORY", openTermLoanManagerFactory, true);
        globals.setValidInstanceOf("LOAN_MANAGER_FACTORY", openTermLoanManagerFactory, true);
        globals.setValidInstanceOf("STRATEGY_FACTORY", openTermLoanManagerFactory, true);
        globals.setValidInstanceOf("POOL_MANAGER_FACTORY", poolManagerFactory, true);
        globals.setValidInstanceOf("WITHDRAWAL_MANAGER_QUEUE_FACTORY", queueWMFactory, true);
        globals.setValidInstanceOf("WITHDRAWAL_MANAGER_FACTORY", queueWMFactory, true);
        globals.setValidInstanceOf("POOL_PERMISSION_MANAGER", address(poolPermissionManager), true);
        globals.setValidInstanceOf("REFINANCER", openTermRefinancer, true);
        globals.setValidInstanceOf("OT_REFINANCER", openTermRefinancer, true);
        globals.setValidInstanceOf("STRATEGY_MANAGER", strategyManager, true);
        globals.setValidInstanceOf("STRATEGY_MANAGER_FACTORY", strategyManagerFactory, true);
        globals.setValidInstanceOf("UNDERLYING_STRATEGY_FACTORY", aaveV3StrategyFactory, true);
        globals.setValidInstanceOf("UNDERLYING_STRATEGY_FACTORY", skyStrategyFactory, true);
        globals.setValidInstanceOf("UNDERLYING_STRATEGY_FACTORY", allocationStrategyFactory, true);
        globals.setValidInstanceOf("LIQUIDITY_BOT", liquidityBot, true);
        globals.setValidInstanceOf("LIQUIDITY_ROUTER", address(liquidityRouter), true);
        globals.setValidInstanceOf("LIQUIDITY_ROUTER_BOT", liquidityRouterBot, true);

        globals.setCanDeployFrom(poolManagerFactory, address(poolDeployer), true);
        globals.setCanDeployFrom(queueWMFactory, address(poolDeployer), true);
        globals.setCanDeployFrom(aaveV3StrategyFactory, address(strategyDeployer), true);
        globals.setCanDeployFrom(skyStrategyFactory, address(strategyDeployer), true);
        globals.setCanDeployFrom(strategyManagerFactory, address(strategyDeployer), true);
        globals.setCanDeployFrom(allocationStrategyFactory, address(strategyDeployer), true);

        globals.setValidStrategyDelegate(strategyDelegate, true);

        IMapleProxyFactory(openTermLoanFactory).registerImplementation(1, openTermLoanImplementation, openTermLoanInitializer);
        IMapleProxyFactory(openTermLoanFactory).setDefaultVersion(1);

        IMapleProxyFactory(openTermLoanManagerFactory)
            .registerImplementation(1, openTermLoanManagerImplementation, openTermLoanManagerInitializer);
        IMapleProxyFactory(openTermLoanManagerFactory).setDefaultVersion(1);

        IMapleProxyFactory(poolManagerFactory).registerImplementation(1, poolManagerImplementation, poolManagerInitializer);
        IMapleProxyFactory(poolManagerFactory).setDefaultVersion(1);

        IMapleProxyFactory(queueWMFactory).registerImplementation(1, queueWMImplementation, queueWMInitializer);
        IMapleProxyFactory(queueWMFactory).setDefaultVersion(1);

        IMapleProxyFactory(aaveV3StrategyFactory).registerImplementation(1, aaveV3StrategyImplementation, aaveV3StrategyInitializer);
        IMapleProxyFactory(aaveV3StrategyFactory).setDefaultVersion(1);

        IMapleProxyFactory(skyStrategyFactory).registerImplementation(1, skyStrategyImplementation, skyStrategyInitializer);
        IMapleProxyFactory(skyStrategyFactory).setDefaultVersion(1);

        IMapleProxyFactory(strategyManagerFactory).registerImplementation(1, strategyManagerImplementation, strategyManagerInitializer);
        IMapleProxyFactory(strategyManagerFactory).setDefaultVersion(1);

        IMapleProxyFactory(allocationStrategyFactory)
            .registerImplementation(1, allocationStrategyImplementation, allocationStrategyInitializer);
        IMapleProxyFactory(allocationStrategyFactory).setDefaultVersion(1);

        vm.stopPrank();

        strategyFactories.push(openTermLoanManagerFactory);
    }

    /**************************************************************************************************************************************/
    /*** Common: Pool Builder                                                                                                           ***/
    /**************************************************************************************************************************************/

    function _deployPoolWithQueue(
        address poolDelegate_,
        address fundsAsset_,
        address[] memory strategyFactories_,
        bytes[] memory strategyData_,
        string memory name_,
        string memory symbol_,
        uint256 liquidityCap_,
        uint256 delegateManagementFeeRate_
    )
        internal
        returns (address poolManager_)
    {
        vm.prank(poolDelegate_);
        poolManager_ = poolDeployer.deployPool({
            poolManagerFactory: poolManagerFactory,
            withdrawalManagerFactory: queueWMFactory,
            poolManagerInitParams: PoolManagerInitParams({ asset: fundsAsset_, initialSupply: 0, name: name_, symbol: symbol_ }),
            poolConfigParams: PoolConfigParams({
                poolPermissionManager: address(poolPermissionManager),
                delegateManagementFeeRate: delegateManagementFeeRate_,
                liquidityCap: liquidityCap_
            }),
            strategiesParams: _buildStrategyDeployParams(strategyFactories_, strategyData_, name_),
            strategyManagersParams: new StrategyManagerParams[](0)
        });
    }

    function _buildStrategyDeployParams(
        address[] memory strategyFactories_,
        bytes[] memory strategyData_,
        string memory name_
    )
        internal
        pure
        returns (StrategyDeployParams[] memory strategies_)
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
        address borrower,
        address lender,
        address asset,
        uint256 principal,
        uint32[3] memory terms,
        uint64[4] memory rates
    )
        internal
        returns (address loan)
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
    )
        internal
    {
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
