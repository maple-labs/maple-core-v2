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
    WithdrawalManager,
    WithdrawalManagerFactory,
    WithdrawalManagerInitializer
} from "../contracts/Contracts.sol";

import { ProtocolActions } from "../contracts/ProtocolActions.sol";

import { MockLiquidationStrategy } from "./mocks/Mocks.sol";

contract TestBase is ProtocolActions {

    uint256 constant MAX_TOKEN_AMOUNT = 1e29;

    uint256 constant ONE_DAY   = 1 days;
    uint256 constant ONE_MONTH = ONE_YEAR / 12;
    uint256 constant ONE_YEAR  = 365 days;

    address governor;
    address poolDelegate;
    address treasury;
    address migrationAdmin;

    address fixedTermLoanFactory;
    address fixedTermLoanManagerFactory;
    address liquidatorFactory;
    address openTermLoanFactory;
    address openTermLoanManagerFactory;
    address poolManagerFactory;
    address withdrawalManagerFactory;

    address fixedTermLoanImplementation;
    address fixedTermLoanManagerImplementation;
    address liquidatorImplementation;
    address openTermLoanImplementation;
    address openTermLoanManagerImplementation;
    address poolManagerImplementation;
    address withdrawalManagerImplementation;

    address fixedTermLoanInitializer;
    address fixedTermLoanManagerInitializer;
    address liquidatorInitializer;
    address openTermLoanInitializer;
    address openTermLoanManagerInitializer;
    address poolManagerInitializer;
    address withdrawalManagerInitializer;

    uint256 nextDelegateOriginationFee;
    uint256 nextDelegateServiceFee;

    uint256 start;

    address[] loanManagerFactories;

    // Helper mapping to assert differences in balance
    mapping(address => uint256) partialAssetBalances;

    MockERC20    collateralAsset;
    MockERC20    fundsAsset;
    Globals      globals;
    PoolDeployer deployer;

    FeeManager           feeManager;
    FixedTermRefinancer  refinancer;
    Pool                 pool;
    PoolDelegateCover    poolCover;
    PoolManager          poolManager;
    WithdrawalManager    withdrawalManager;

    function setUp() public virtual {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createAndConfigurePool(1 weeks, 2 days);
        _openPool();

        start = block.timestamp;
    }

    /**************************************************************************************************************************************/
    /*** Initialization Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    function _createAccounts() internal {
        governor       = makeAddr("governor");
        migrationAdmin = makeAddr("migrationAdmin");
        poolDelegate   = makeAddr("poolDelegate");
        treasury       = makeAddr("treasury");
    }

    function _createAssets() internal {
        collateralAsset = new MockERC20("Wrapper Ether", "WETH", 18);
        fundsAsset      = new MockERC20("USD Coin",      "USDC", 6);
    }

    function _createFactories() internal {
        fixedTermLoanFactory        = address(new FixedTermLoanFactory(address(globals)));
        fixedTermLoanManagerFactory = address(new FixedTermLoanManagerFactory(address(globals)));
        liquidatorFactory           = address(new LiquidatorFactory(address(globals)));
        openTermLoanFactory         = address(new OpenTermLoanFactory(address(globals)));
        openTermLoanManagerFactory  = address(new OpenTermLoanManagerFactory(address(globals)));
        poolManagerFactory          = address(new PoolManagerFactory(address(globals)));
        withdrawalManagerFactory    = address(new WithdrawalManagerFactory(address(globals)));

        fixedTermLoanImplementation        = address(new FixedTermLoan());
        fixedTermLoanManagerImplementation = address(new FixedTermLoanManager());
        liquidatorImplementation           = address(new Liquidator());
        openTermLoanImplementation         = address(new OpenTermLoan());
        openTermLoanManagerImplementation  = address(new OpenTermLoanManager());
        poolManagerImplementation          = address(new PoolManager());
        withdrawalManagerImplementation    = address(new WithdrawalManager());

        fixedTermLoanInitializer        = address(new FixedTermLoanInitializer());
        fixedTermLoanManagerInitializer = address(new FixedTermLoanManagerInitializer());
        liquidatorInitializer           = address(new LiquidatorInitializer());
        openTermLoanInitializer         = address(new OpenTermLoanInitializer());
        openTermLoanManagerInitializer  = address(new OpenTermLoanManagerInitializer());
        poolManagerInitializer          = address(new PoolManagerInitializer());
        withdrawalManagerInitializer    = address(new WithdrawalManagerInitializer());

        feeManager = new FeeManager(address(globals));
        refinancer = new FixedTermRefinancer();

        vm.startPrank(governor);

        globals.setValidFactory("LIQUIDATOR",         liquidatorFactory,           true);
        globals.setValidFactory("FT_LOAN",            fixedTermLoanFactory,        true);
        globals.setValidFactory("OT_LOAN",            openTermLoanFactory,         true);
        globals.setValidFactory("LOAN_MANAGER",       fixedTermLoanManagerFactory, true);
        globals.setValidFactory("LOAN_MANAGER",       openTermLoanManagerFactory,  true);
        globals.setValidFactory("POOL_MANAGER",       poolManagerFactory,          true);
        globals.setValidFactory("WITHDRAWAL_MANAGER", withdrawalManagerFactory,    true);

        globals.setValidInstanceOf("FT_REFINANCER", address(refinancer), true);

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

        WithdrawalManagerFactory(withdrawalManagerFactory).registerImplementation(1, withdrawalManagerImplementation, withdrawalManagerInitializer);
        WithdrawalManagerFactory(withdrawalManagerFactory).setDefaultVersion(1);

        vm.stopPrank();

        loanManagerFactories.push(fixedTermLoanManagerFactory);
        loanManagerFactories.push(openTermLoanManagerFactory);
    }

    function _createGlobals() internal {
        globals = Globals(address(new NonTransparentProxy(governor, address(new Globals()))));

        deployer = new PoolDeployer(address(globals));

        vm.startPrank(governor);
        globals.setMigrationAdmin(migrationAdmin);
        globals.setSecurityAdmin(governor);
        globals.setValidPoolAsset(address(fundsAsset), true);
        globals.setValidCollateralAsset(address(collateralAsset), true);
        globals.setValidPoolDelegate(poolDelegate, true);
        globals.setValidPoolDeployer(address(deployer), true);
        globals.setManualOverridePrice(address(fundsAsset),      1e8);     // 1     USD / 1 USDC
        globals.setManualOverridePrice(address(collateralAsset), 1500e8);  // 1_500 USD / 1 WETH
        globals.setDefaultTimelockParameters(1 weeks, 2 days);
        vm.stopPrank();
    }

    // TODO: Add all config params here
    function _createPool(uint256 withdrawalCycle, uint256 windowDuration) internal {
        vm.prank(poolDelegate);
        poolManager = PoolManager(deployer.deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: withdrawalManagerFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    address(fundsAsset),
            name_:                     "Maple Pool",
            symbol_:                   "MP",
            configParams_:             [type(uint256).max, 0, 0, withdrawalCycle, windowDuration, 0]
        }));

        withdrawalManager = WithdrawalManager(poolManager.withdrawalManager());
        pool              = Pool(poolManager.pool());
        poolCover         = PoolDelegateCover(poolManager.poolDelegateCover());
    }

    function _configurePool() internal {
        vm.startPrank(governor);
        globals.activatePoolManager(address(poolManager));
        globals.setMaxCoverLiquidationPercent(address(poolManager), globals.HUNDRED_PERCENT());
        vm.stopPrank();
    }

    function _createAndConfigurePool(uint256 withdrawalCycle, uint256 windowDuration) internal {
        _createPool(withdrawalCycle, windowDuration);
        _configurePool();
    }

    function _openPool() internal {
        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();
    }

    function _setTreasury() internal {
        vm.startPrank(governor);
        globals.setMapleTreasury(treasury);
        vm.stopPrank();
    }

    /**************************************************************************************************************************************/
    /*** Helper Functions                                                                                                               ***/
    /**************************************************************************************************************************************/

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
        address borrower,
        uint256[3] memory termDetails,
        uint256[3] memory amounts,
        uint256[4] memory rates,
        address loanManager   // TODO: Move to top of params.
    )
        internal returns (address loan)
    {
        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

        loan = FixedTermLoanFactory(fixedTermLoanFactory).createInstance({
            arguments_: abi.encode(
                borrower,
                loanManager,
                address(feeManager),
                [address(collateralAsset), address(fundsAsset)],
                termDetails,
                amounts,
                rates,
                [nextDelegateOriginationFee, nextDelegateServiceFee]
            ),
            salt_: "SALT"
        });
    }

    function createOpenTermLoan(
        address borrower,
        address lender,
        address asset,
        uint256 principal,
        uint32[3] memory terms,
        uint64[4] memory rates
    )
        internal returns (address loan)
    {
        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

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

        vm.startPrank(poolDelegate);
        nextDelegateOriginationFee = delegateOriginationFee;
        nextDelegateServiceFee     = delegateServiceFee;
        poolManager.setDelegateManagementFeeRate(delegateManagementFeeRate);
        vm.stopPrank();
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

    function depositLiquidity(address lp, uint256 liquidity) internal returns (uint256 shares) {
        shares = depositLiquidity(address(pool), lp, liquidity);
    }

    // TODO: Move all of these to ProtocolActions.
    function fundAndDrawdownLoan(
        address borrower,
        uint256[3] memory termDetails,
        uint256[3] memory amounts,
        uint256[4] memory rates,
        address loanManager
    )
        internal returns (address loan)
    {
        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

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
