// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IFixedTermLoanManager, ILoanLike } from "../contracts/interfaces/Interfaces.sol";

import {
    FeeManager,
    FixedTermLoan,
    FixedTermLoanFactory,
    FixedTermLoanInitializer,
    FixedTermLoanManager,
    FixedTermLoanManagerFactory,
    FixedTermLoanManagerInitializer,
    FixedTermRefinancer,
    Globals,
    Liquidator,
    LiquidatorFactory,
    LiquidatorInitializer,
    MockERC20,
    NonTransparentProxy,
    OpenTermLoan,
    OpenTermLoanFactory,
    OpenTermLoanInitializer,
    OpenTermLoanManager,
    OpenTermLoanManagerFactory,
    OpenTermLoanManagerInitializer,
    OpenTermRefinancer,
    Pool,
    PoolDelegateCover,
    PoolDeployer,
    PoolManager,
    PoolManagerFactory,
    PoolManagerInitializer,
    PoolPermissionManager,
    PoolPermissionManagerInitializer,
    WithdrawalManagerCyclical,
    WithdrawalManagerCyclicalFactory,
    WithdrawalManagerCyclicalInitializer,
    WithdrawalManagerQueue,
    WithdrawalManagerQueueFactory,
    WithdrawalManagerQueueInitializer
} from "../contracts/Contracts.sol";

import { ProtocolActions } from "../contracts/ProtocolActions.sol";

import { MockLiquidationStrategy } from "./mocks/Mocks.sol";

contract TestBase is ProtocolActions {

    uint256 constant MAX_TOKEN_AMOUNT = 1e29;

    uint256 constant ONE_DAY   = 1 days;
    uint256 constant ONE_MONTH = ONE_YEAR / 12;
    uint256 constant ONE_YEAR  = 365 days;

    address governor;
    address migrationAdmin;
    address operationalAdmin;
    address poolDelegate;
    address permissionAdmin;
    address securityAdmin;
    address treasury;

    address fixedTermLoanFactory;
    address fixedTermLoanManagerFactory;
    address liquidatorFactory;
    address openTermLoanFactory;
    address openTermLoanManagerFactory;
    address poolManagerFactory;
    address cyclicalWMFactory;
    address queueWMFactory;

    address fixedTermLoanImplementation;
    address fixedTermLoanManagerImplementation;
    address liquidatorImplementation;
    address openTermLoanImplementation;
    address openTermLoanManagerImplementation;
    address poolManagerImplementation;
    address cyclicalWMImplementation;
    address queueWMImplementation;

    address fixedTermLoanInitializer;
    address fixedTermLoanManagerInitializer;
    address liquidatorInitializer;
    address openTermLoanInitializer;
    address openTermLoanManagerInitializer;
    address poolManagerInitializer;
    address poolPermissionManagerInitializer;
    address cyclicalWMInitializer;
    address queueWMInitializer;

    uint256 nextDelegateOriginationFee;
    uint256 nextDelegateServiceFee;

    uint256 start;

    address[] loanManagerFactories;

    FeeManager                fixedTermFeeManager;
    FixedTermRefinancer       fixedTermRefinancer;
    Globals                   globals;
    MockERC20                 collateralAsset;
    MockERC20                 fundsAsset;
    OpenTermRefinancer        openTermRefinancer;
    Pool                      pool;
    PoolDelegateCover         poolCover;
    PoolDeployer              deployer;
    PoolManager               poolManager;
    PoolPermissionManager     poolPermissionManager;
    WithdrawalManagerCyclical cyclicalWM;
    WithdrawalManagerQueue    queueWM;

    function setUp() public virtual {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createAndConfigurePool(start, 1 weeks, 2 days);

        openPool(address(poolManager));
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
        treasury         = makeAddr("treasury");
    }

    function _createAssets() internal {
        collateralAsset = new MockERC20("Wrapper Ether", "WETH", 18);
        fundsAsset      = new MockERC20("USD Coin",      "USDC", 6);
    }

    function _createFactories() internal {
        fixedTermLoanFactory        = address(new FixedTermLoanFactory(address(globals), address(0)));
        fixedTermLoanManagerFactory = address(new FixedTermLoanManagerFactory(address(globals)));
        liquidatorFactory           = address(new LiquidatorFactory(address(globals)));
        openTermLoanFactory         = address(new OpenTermLoanFactory(address(globals)));
        openTermLoanManagerFactory  = address(new OpenTermLoanManagerFactory(address(globals)));
        poolManagerFactory          = address(new PoolManagerFactory(address(globals)));
        cyclicalWMFactory           = address(new WithdrawalManagerCyclicalFactory(address(globals)));
        queueWMFactory              = address(new WithdrawalManagerQueueFactory(address(globals)));

        fixedTermLoanImplementation        = address(new FixedTermLoan());
        fixedTermLoanManagerImplementation = address(new FixedTermLoanManager());
        liquidatorImplementation           = address(new Liquidator());
        openTermLoanImplementation         = address(new OpenTermLoan());
        openTermLoanManagerImplementation  = address(new OpenTermLoanManager());
        poolManagerImplementation          = address(new PoolManager());
        cyclicalWMImplementation           = address(new WithdrawalManagerCyclical());
        queueWMImplementation              = address(new WithdrawalManagerQueue());

        fixedTermLoanInitializer        = address(new FixedTermLoanInitializer());
        fixedTermLoanManagerInitializer = address(new FixedTermLoanManagerInitializer());
        liquidatorInitializer           = address(new LiquidatorInitializer());
        openTermLoanInitializer         = address(new OpenTermLoanInitializer());
        openTermLoanManagerInitializer  = address(new OpenTermLoanManagerInitializer());
        poolManagerInitializer          = address(new PoolManagerInitializer());
        cyclicalWMInitializer           = address(new WithdrawalManagerCyclicalInitializer());
        queueWMInitializer              = address(new WithdrawalManagerQueueInitializer());

        // TODO: Update to addresses
        fixedTermFeeManager = new FeeManager(address(globals));
        fixedTermRefinancer = new FixedTermRefinancer();
        openTermRefinancer  = new OpenTermRefinancer();

        address poolPermissionManagerImplementation = address(new PoolPermissionManager());
        poolPermissionManagerInitializer            = address(new PoolPermissionManagerInitializer());

        poolPermissionManager = PoolPermissionManager(address(new NonTransparentProxy(governor, poolPermissionManagerInitializer)));

        vm.startPrank(governor);

        PoolPermissionManagerInitializer(address(poolPermissionManager)).initialize(poolPermissionManagerImplementation, address(globals));
        poolPermissionManager.setPermissionAdmin(permissionAdmin, true);

        globals.setValidInstanceOf("LIQUIDATOR_FACTORY",               liquidatorFactory,             true);
        globals.setValidInstanceOf("LOAN_FACTORY",                     fixedTermLoanFactory,          true);
        globals.setValidInstanceOf("FT_LOAN_FACTORY",                  fixedTermLoanFactory,          true);
        globals.setValidInstanceOf("LOAN_FACTORY",                     openTermLoanFactory,           true);
        globals.setValidInstanceOf("OT_LOAN_FACTORY",                  openTermLoanFactory,           true);
        globals.setValidInstanceOf("LOAN_MANAGER_FACTORY",             fixedTermLoanManagerFactory,   true);
        globals.setValidInstanceOf("FT_LOAN_MANAGER_FACTORY",          fixedTermLoanManagerFactory,   true);
        globals.setValidInstanceOf("OT_LOAN_MANAGER_FACTORY",          openTermLoanManagerFactory,    true);
        globals.setValidInstanceOf("LOAN_MANAGER_FACTORY",             openTermLoanManagerFactory,    true);
        globals.setValidInstanceOf("POOL_MANAGER_FACTORY",             poolManagerFactory,            true);
        globals.setValidInstanceOf("WITHDRAWAL_MANAGER_CYCLE_FACTORY", cyclicalWMFactory,             true);
        globals.setValidInstanceOf("WITHDRAWAL_MANAGER_QUEUE_FACTORY", queueWMFactory,                true);
        globals.setValidInstanceOf("WITHDRAWAL_MANAGER_FACTORY",       cyclicalWMFactory,             true);
        globals.setValidInstanceOf("WITHDRAWAL_MANAGER_FACTORY",       queueWMFactory,                true);
        globals.setValidInstanceOf("POOL_PERMISSION_MANAGER",          address(poolPermissionManager),true);
        globals.setValidInstanceOf("REFINANCER",                       address(openTermRefinancer),   true);
        globals.setValidInstanceOf("OT_REFINANCER",                    address(openTermRefinancer),   true);
        globals.setValidInstanceOf("REFINANCER",                       address(fixedTermRefinancer),  true);
        globals.setValidInstanceOf("FT_REFINANCER",                    address(fixedTermRefinancer),  true);
        globals.setValidInstanceOf("FEE_MANAGER",                      address(fixedTermFeeManager),  true);

        globals.setCanDeployFrom(fixedTermLoanManagerFactory, address(deployer), true);
        globals.setCanDeployFrom(poolManagerFactory,          address(deployer), true);
        globals.setCanDeployFrom(cyclicalWMFactory,           address(deployer), true);
        globals.setCanDeployFrom(queueWMFactory,              address(deployer), true);

        LiquidatorFactory(liquidatorFactory).registerImplementation(1, liquidatorImplementation, liquidatorInitializer);
        LiquidatorFactory(liquidatorFactory).setDefaultVersion(1);

        FixedTermLoanFactory(fixedTermLoanFactory).registerImplementation(1, fixedTermLoanImplementation, fixedTermLoanInitializer);
        FixedTermLoanFactory(fixedTermLoanFactory).setDefaultVersion(1);

        FixedTermLoanManagerFactory(fixedTermLoanManagerFactory).registerImplementation(
            1,
            fixedTermLoanManagerImplementation,
            fixedTermLoanManagerInitializer
        );
        FixedTermLoanManagerFactory(fixedTermLoanManagerFactory).setDefaultVersion(1);

        OpenTermLoanFactory(openTermLoanFactory).registerImplementation(1, openTermLoanImplementation, openTermLoanInitializer);
        OpenTermLoanFactory(openTermLoanFactory).setDefaultVersion(1);

        OpenTermLoanManagerFactory(openTermLoanManagerFactory).registerImplementation(
            1,
            openTermLoanManagerImplementation,
            openTermLoanManagerInitializer
        );
        OpenTermLoanManagerFactory(openTermLoanManagerFactory).setDefaultVersion(1);

        PoolManagerFactory(poolManagerFactory).registerImplementation(1, poolManagerImplementation, poolManagerInitializer);
        PoolManagerFactory(poolManagerFactory).setDefaultVersion(1);

        WithdrawalManagerCyclicalFactory(cyclicalWMFactory).registerImplementation(1, cyclicalWMImplementation, cyclicalWMInitializer);
        WithdrawalManagerCyclicalFactory(cyclicalWMFactory).setDefaultVersion(1);

        WithdrawalManagerQueueFactory(queueWMFactory).registerImplementation(1, queueWMImplementation, queueWMInitializer);
        WithdrawalManagerQueueFactory(queueWMFactory).setDefaultVersion(1);

        vm.stopPrank();

        loanManagerFactories.push(fixedTermLoanManagerFactory);
        loanManagerFactories.push(openTermLoanManagerFactory);
    }

    function _createGlobals() internal {
        globals = Globals(address(new NonTransparentProxy(governor, address(new Globals()))));

        deployer = new PoolDeployer(address(globals));

        vm.startPrank(governor);
        globals.setMigrationAdmin(migrationAdmin);
        globals.setOperationalAdmin(operationalAdmin);
        globals.setSecurityAdmin(governor);
        globals.setValidPoolAsset(address(fundsAsset), true);
        globals.setValidCollateralAsset(address(collateralAsset), true);
        globals.setValidPoolDelegate(poolDelegate, true);
        globals.setManualOverridePrice(address(fundsAsset),      1e8);     // 1     USD / 1 USDC
        globals.setManualOverridePrice(address(collateralAsset), 1500e8);  // 1_500 USD / 1 WETH
        globals.setDefaultTimelockParameters(1 weeks, 2 days);
        vm.stopPrank();
    }

    // TODO: Add all config params here
    function _createPool(uint256 startTime, uint256 withdrawalCycle, uint256 windowDuration) internal {
        vm.prank(poolDelegate);
        poolManager = PoolManager(deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: cyclicalWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, withdrawalCycle, windowDuration, 0, startTime]
        }));

        cyclicalWM = WithdrawalManagerCyclical(poolManager.withdrawalManager());
        pool       = Pool(poolManager.pool());
        poolCover  = PoolDelegateCover(poolManager.poolDelegateCover());
    }

    function _createPoolWithQueue() internal {
        vm.prank(poolDelegate);
        poolManager = PoolManager(deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: queueWMFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            poolPermissionManager_:    address(poolPermissionManager),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, 0]
        }));

        queueWM    = WithdrawalManagerQueue(poolManager.withdrawalManager());
        pool       = Pool(poolManager.pool());
        poolCover  = PoolDelegateCover(poolManager.poolDelegateCover());
    }

    function _configurePool() internal {
        vm.startPrank(governor);
        globals.activatePoolManager(address(poolManager));
        globals.setMaxCoverLiquidationPercent(address(poolManager), globals.HUNDRED_PERCENT());
        vm.stopPrank();

        allowLender(address(poolManager), address(cyclicalWM));
    }

    function _createAndConfigurePool(uint256 startTime, uint256 withdrawalCycle, uint256 windowDuration) internal {
        _createPool(startTime, withdrawalCycle, windowDuration);
        _configurePool();
    }

    function _setTreasury() internal {
        vm.startPrank(governor);
        globals.setMapleTreasury(treasury);
        vm.stopPrank();
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

    // TODO: Can be moved into ProtocolActions, but it a bit heavy on arguments if state variables need to be passed in as well.
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
        address           loanManager   // TODO: Move to top of params.
    )
        internal returns (address loan)
    {
        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

        vm.prank(borrower);
        loan = FixedTermLoanFactory(fixedTermLoanFactory).createInstance({
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
        loan = FixedTermLoanFactory(fixedTermLoanFactory).createInstance({
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
        loan = OpenTermLoanFactory(openTermLoanFactory).createInstance({
            arguments_: abi.encode(borrower, lender, asset, principal, terms, rates),
            salt_: "SALT"
        });
    }

    function encodeWithSignatureAndUint(string memory signature, uint256 arg) internal pure returns (bytes[] memory calls) {
        calls    = new bytes[](1);
        calls[0] = abi.encodeWithSignature(signature, arg);
    }

    function liquidateCollateral(address loan) internal {
        MockLiquidationStrategy mockLiquidationStrategy = new MockLiquidationStrategy();

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

    // TODO: Move all of these to ProtocolActions. Not sure if they belong there because they are "complex" actions that involve many steps.
    function fundAndDrawdownLoan(
        address           borrower,
        uint256[3] memory termDetails,
        uint256[3] memory amounts,
        uint256[4] memory rates,
        address           loanManager
    )
        internal returns (address loan)
    {
        loan = createFixedTermLoan(borrower, termDetails, amounts, rates, loanManager);  // TODO: Remove create from this function.

        fundLoan(address(loan));

        drawdown(address(loan), FixedTermLoan(loan).drawableFunds());
    }

    function requestRedeem(address lp, uint256 amount) internal {
        requestRedeem(address(pool), lp, amount);
    }

    function redeem(address lp, uint256 amount) internal returns (uint256 assets_) {
        assets_ = redeem(address(pool), lp, amount);
    }

}
