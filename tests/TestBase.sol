// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IFixedTermLoanManager, ILoanLike } from "../contracts/interfaces/Interfaces.sol";

import {
    Address,
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
    Pool,
    PoolDelegateCover,
    PoolDeployer,
    TestUtils
} from "../contracts/Contracts.sol";

import { PoolManager }             from "../modules/pool/contracts/PoolManager.sol";
import { PoolManagerFactory }      from "../modules/pool/contracts/proxy/PoolManagerFactory.sol";
import { PoolManagerInitializer }  from "../modules/pool/contracts/proxy/PoolManagerInitializer.sol";

import { WithdrawalManager }            from "../modules/withdrawal-manager/contracts/WithdrawalManager.sol";
import { WithdrawalManagerFactory }     from "../modules/withdrawal-manager/contracts/WithdrawalManagerFactory.sol";
import { WithdrawalManagerInitializer } from "../modules/withdrawal-manager/contracts/WithdrawalManagerInitializer.sol";

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

    address liquidatorFactory;
    address loanFactory;
    address loanManagerFactory;
    address poolManagerFactory;
    address withdrawalManagerFactory;

    address liquidatorImplementation;
    address loanImplementation;
    address loanManagerImplementation;
    address poolManagerImplementation;
    address withdrawalManagerImplementation;

    address liquidatorInitializer;
    address loanInitializer;
    address loanManagerInitializer;
    address poolManagerInitializer;
    address withdrawalManagerInitializer;

    uint256 nextDelegateOriginationFee;
    uint256 nextDelegateServiceFee;

    uint256 start;

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
        _createFactories();
        _createAndConfigurePool(1 weeks, 2 days);
        _openPool();

        start = block.timestamp;
    }

    /**************************************************************************************************************************************/
    /*** Initialization Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    function _createAccounts() internal {
        governor       = address(new Address());
        migrationAdmin = address(new Address());
        poolDelegate   = address(new Address());
        treasury       = address(new Address());
    }

    function _createAssets() internal {
        collateralAsset = new MockERC20("Wrapper Ether", "WETH", 18);
        fundsAsset      = new MockERC20("USD Coin",      "USDC", 6);
    }

    function _createFactories() internal {
        liquidatorFactory        = address(new LiquidatorFactory(address(globals)));
        loanFactory              = address(new FixedTermLoanFactory(address(globals)));
        loanManagerFactory       = address(new FixedTermLoanManagerFactory(address(globals)));
        poolManagerFactory       = address(new PoolManagerFactory(address(globals)));
        withdrawalManagerFactory = address(new WithdrawalManagerFactory(address(globals)));

        liquidatorImplementation        = address(new Liquidator());
        loanImplementation              = address(new FixedTermLoan());
        loanManagerImplementation       = address(new FixedTermLoanManager());
        poolManagerImplementation       = address(new PoolManager());
        withdrawalManagerImplementation = address(new WithdrawalManager());

        liquidatorInitializer        = address(new LiquidatorInitializer());
        loanInitializer              = address(new FixedTermLoanInitializer());
        loanManagerInitializer       = address(new FixedTermLoanManagerInitializer());
        poolManagerInitializer       = address(new PoolManagerInitializer());
        withdrawalManagerInitializer = address(new WithdrawalManagerInitializer());

        feeManager = new FeeManager(address(globals));
        refinancer = new FixedTermRefinancer();

        vm.startPrank(governor);

        globals.setValidFactory("LIQUIDATOR",         liquidatorFactory,        true);
        globals.setValidFactory("LOAN",               loanFactory,              true);
        globals.setValidFactory("LOAN_MANAGER",       loanManagerFactory,       true);
        globals.setValidFactory("POOL_MANAGER",       poolManagerFactory,       true);
        globals.setValidFactory("WITHDRAWAL_MANAGER", withdrawalManagerFactory, true);

        LiquidatorFactory(liquidatorFactory).registerImplementation(1, liquidatorImplementation, liquidatorInitializer);
        LiquidatorFactory(liquidatorFactory).setDefaultVersion(1);

        FixedTermLoanFactory(loanFactory).registerImplementation(1, loanImplementation, loanInitializer);
        FixedTermLoanFactory(loanFactory).setDefaultVersion(1);

        FixedTermLoanManagerFactory(loanManagerFactory).registerImplementation(1, loanManagerImplementation, loanManagerInitializer);
        FixedTermLoanManagerFactory(loanManagerFactory).setDefaultVersion(1);

        PoolManagerFactory(poolManagerFactory).registerImplementation(1, poolManagerImplementation, poolManagerInitializer);
        PoolManagerFactory(poolManagerFactory).setDefaultVersion(1);

        WithdrawalManagerFactory(withdrawalManagerFactory).registerImplementation(1, withdrawalManagerImplementation, withdrawalManagerInitializer);
        WithdrawalManagerFactory(withdrawalManagerFactory).setDefaultVersion(1);

        vm.stopPrank();
    }

    function _createGlobals() internal {
        globals = Globals(address(new NonTransparentProxy(governor, address(new Globals()))));

        deployer = new PoolDeployer(address(globals));

        vm.startPrank(governor);
        globals.setMapleTreasury(treasury);
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

    function _createPool(uint256 withdrawalCycle, uint256 windowDuration) internal {
        vm.prank(poolDelegate);
        ( address poolManager_, , address withdrawalManager_ ) = deployer.deployPool({
            factories_:    [poolManagerFactory,     loanManagerFactory,     withdrawalManagerFactory],
            initializers_: [poolManagerInitializer, loanManagerInitializer, withdrawalManagerInitializer],
            asset_:        address(fundsAsset),
            name_:         "Maple Pool",
            symbol_:       "MP",
            configParams_: [type(uint256).max, 0, 0, withdrawalCycle, windowDuration, 0]
        });

        poolManager       = PoolManager(poolManager_);
        withdrawalManager = WithdrawalManager(withdrawalManager_);
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

    /**************************************************************************************************************************************/
    /*** Helper Functions                                                                                                               ***/
    /**************************************************************************************************************************************/

    // TODO: Can be moved into ProtocolActions, but it a bit heavy on arguments if state variables need to be passed in as well.
    /**
     *  @param borrower    The address of the borrower.
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
    function createLoan(
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

        loan = FixedTermLoanFactory(loanFactory).createInstance({
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
        triggerDefault(address(poolManager), address(loan), address(liquidatorFactory));
    }

    function depositCover(uint256 cover) internal {
        depositCover(address(poolManager), cover);
    }

    function depositLiquidity(address lp, uint256 liquidity) internal returns (uint256 shares) {
        shares = depositLiquidity(address(pool), lp, liquidity);
    }

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

        loan = createLoan(borrower, termDetails, amounts, rates, loanManager);

        fundLoan(address(poolManager), address(loan));

        drawdown(address(loan), FixedTermLoan(loan).drawableFunds());
    }

    function impairLoan(address loan) internal {
        impairLoan(address(poolManager), address(loan));
    }

    function requestRedeem(address lp, uint256 amount) internal {
        requestRedeem(address(pool), lp, amount);
    }

    function redeem(address lp, uint256 amount) internal returns (uint256 assets_) {
        assets_ = redeem(address(pool), lp, amount);
    }

}
