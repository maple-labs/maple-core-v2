// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address, TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

import { MockERC20 } from "../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { MapleGlobals }        from "../modules/globals/contracts/MapleGlobals.sol";
import { NonTransparentProxy } from "../modules/globals/modules/non-transparent-proxy/contracts/NonTransparentProxy.sol";

import { Liquidator }            from "../modules/liquidations/contracts/Liquidator.sol";
import { LiquidatorFactory }     from "../modules/liquidations/contracts/LiquidatorFactory.sol";
import { LiquidatorInitializer } from "../modules/liquidations/contracts/LiquidatorInitializer.sol";

import { MapleLoan }            from "../modules/loan/contracts/MapleLoan.sol";
import { MapleLoanFactory }     from "../modules/loan/contracts/MapleLoanFactory.sol";
import { MapleLoanFeeManager }  from "../modules/loan/contracts/MapleLoanFeeManager.sol";
import { MapleLoanInitializer } from "../modules/loan/contracts/MapleLoanInitializer.sol";

import { LoanManager }             from "../modules/pool/contracts/LoanManager.sol";
import { Pool }                    from "../modules/pool/contracts/Pool.sol";
import { PoolDelegateCover }       from "../modules/pool/contracts/PoolDelegateCover.sol";
import { PoolDeployer }            from "../modules/pool/contracts/PoolDeployer.sol";
import { PoolManager }             from "../modules/pool/contracts/PoolManager.sol";
import { LoanManagerFactory }      from "../modules/pool/contracts/proxy/LoanManagerFactory.sol";
import { LoanManagerInitializer }  from "../modules/pool/contracts/proxy/LoanManagerInitializer.sol";
import { PoolManagerFactory }      from "../modules/pool/contracts/proxy/PoolManagerFactory.sol";
import { PoolManagerInitializer }  from "../modules/pool/contracts/proxy/PoolManagerInitializer.sol";
import { MockLiquidationStrategy } from "../modules/pool/tests/mocks/Mocks.sol";

import { WithdrawalManager }            from "../modules/withdrawal-manager/contracts/WithdrawalManager.sol";
import { WithdrawalManagerFactory }     from "../modules/withdrawal-manager/contracts/WithdrawalManagerFactory.sol";
import { WithdrawalManagerInitializer } from "../modules/withdrawal-manager/contracts/WithdrawalManagerInitializer.sol";

import { ProtocolActions } from "../contracts/ProtocolActions.sol";

contract TestBase is ProtocolActions {

    uint256 internal constant MAX_TOKEN_AMOUNT = 1e29;

    uint256 internal constant ONE_DAY   = 1 days;
    uint256 internal constant ONE_MONTH = ONE_YEAR / 12;
    uint256 internal constant ONE_YEAR  = 365 days;

    address internal governor;
    address internal poolDelegate;
    address internal treasury;
    address internal migrationAdmin;

    address internal liquidatorFactory;
    address internal loanFactory;
    address internal loanManagerFactory;
    address internal poolManagerFactory;
    address internal withdrawalManagerFactory;

    address internal liquidatorImplementation;
    address internal loanImplementation;
    address internal loanManagerImplementation;
    address internal poolManagerImplementation;
    address internal withdrawalManagerImplementation;

    address internal liquidatorInitializer;
    address internal loanInitializer;
    address internal loanManagerInitializer;
    address internal poolManagerInitializer;
    address internal withdrawalManagerInitializer;

    uint256 internal nextDelegateOriginationFee;
    uint256 internal nextDelegateServiceFee;

    uint256 internal start;

    // Helper mapping to assert differences in balance
    mapping(address => uint256) internal partialAssetBalances;

    MockERC20    internal collateralAsset;
    MockERC20    internal fundsAsset;
    MapleGlobals internal globals;
    PoolDeployer internal deployer;

    MapleLoanFeeManager internal feeManager;
    LoanManager         internal loanManager;
    Pool                internal pool;
    PoolDelegateCover   internal poolCover;
    PoolManager         internal poolManager;
    WithdrawalManager   internal withdrawalManager;

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
        loanFactory              = address(new MapleLoanFactory(address(globals)));
        loanManagerFactory       = address(new LoanManagerFactory(address(globals)));
        poolManagerFactory       = address(new PoolManagerFactory(address(globals)));
        withdrawalManagerFactory = address(new WithdrawalManagerFactory(address(globals)));

        liquidatorImplementation        = address(new Liquidator());
        loanImplementation              = address(new MapleLoan());
        loanManagerImplementation       = address(new LoanManager());
        poolManagerImplementation       = address(new PoolManager());
        withdrawalManagerImplementation = address(new WithdrawalManager());

        liquidatorInitializer        = address(new LiquidatorInitializer());
        loanInitializer              = address(new MapleLoanInitializer());
        loanManagerInitializer       = address(new LoanManagerInitializer());
        poolManagerInitializer       = address(new PoolManagerInitializer());
        withdrawalManagerInitializer = address(new WithdrawalManagerInitializer());

        feeManager = new MapleLoanFeeManager(address(globals));

        vm.startPrank(governor);

        globals.setValidFactory("LIQUIDATOR",         liquidatorFactory,        true);
        globals.setValidFactory("LOAN",               loanFactory,              true);
        globals.setValidFactory("LOAN_MANAGER",       loanManagerFactory,       true);
        globals.setValidFactory("POOL_MANAGER",       poolManagerFactory,       true);
        globals.setValidFactory("WITHDRAWAL_MANAGER", withdrawalManagerFactory, true);

        LiquidatorFactory(liquidatorFactory).registerImplementation(1, liquidatorImplementation, liquidatorInitializer);
        LiquidatorFactory(liquidatorFactory).setDefaultVersion(1);

        MapleLoanFactory(loanFactory).registerImplementation(1, loanImplementation, loanInitializer);
        MapleLoanFactory(loanFactory).setDefaultVersion(1);

        LoanManagerFactory(loanManagerFactory).registerImplementation(1, loanManagerImplementation, loanManagerInitializer);
        LoanManagerFactory(loanManagerFactory).setDefaultVersion(1);

        PoolManagerFactory(poolManagerFactory).registerImplementation(1, poolManagerImplementation, poolManagerInitializer);
        PoolManagerFactory(poolManagerFactory).setDefaultVersion(1);

        WithdrawalManagerFactory(withdrawalManagerFactory).registerImplementation(1, withdrawalManagerImplementation, withdrawalManagerInitializer);
        WithdrawalManagerFactory(withdrawalManagerFactory).setDefaultVersion(1);

        vm.stopPrank();
    }

    function _createGlobals() internal {
        globals = MapleGlobals(address(new NonTransparentProxy(governor, address(new MapleGlobals()))));

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
        ( address poolManager_, address loanManager_, address withdrawalManager_ ) = deployer.deployPool({
            factories_:    [poolManagerFactory,     loanManagerFactory,     withdrawalManagerFactory],
            initializers_: [poolManagerInitializer, loanManagerInitializer, withdrawalManagerInitializer],
            asset_:        address(fundsAsset),
            name_:         "Maple Pool",
            symbol_:       "MP",
            configParams_: [type(uint256).max, 0, 0, withdrawalCycle, windowDuration, 0]
        });

        poolManager       = PoolManager(poolManager_);
        loanManager       = LoanManager(loanManager_);
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
        uint256[4] memory rates
    )
        internal returns (MapleLoan loan)
    {
        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

        loan = MapleLoan(MapleLoanFactory(loanFactory).createInstance({
            arguments_: new MapleLoanInitializer().encodeArguments({
                borrower_:    borrower,
                lender_:      address(loanManager),
                feeManager_:  address(feeManager),
                assets_:      [address(collateralAsset), address(fundsAsset)],
                termDetails_: termDetails,
                amounts_:     amounts,
                rates_:       rates,
                fees_:        [nextDelegateOriginationFee, nextDelegateServiceFee]
            }),
            salt_: "SALT"
        }));
    }

    function encodeWithSignatureAndUint(string memory signature, uint256 arg) internal pure returns (bytes[] memory calls) {
        calls    = new bytes[](1);
        calls[0] = abi.encodeWithSignature(signature, arg);
    }

    function liquidateCollateral(MapleLoan loan) internal {
        MockLiquidationStrategy mockLiquidationStrategy = new MockLiquidationStrategy(address(loanManager));

        ( , , , , , address liquidator ) = loanManager.liquidationInfo(address(loan));

        mockLiquidationStrategy.flashBorrowLiquidation(
            liquidator,
            collateralAsset.balanceOf(address(liquidator)),
            address(collateralAsset),
            address(fundsAsset),
            address(loan)
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

    function defaultLoan(MapleLoan loan) internal {
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
        uint256[4] memory rates
    )
        internal returns (MapleLoan loan)
    {
        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

        loan = createLoan(borrower, termDetails, amounts, rates);

        fundLoan(address(poolManager), address(loan));

        drawdown(address(loan), loan.drawableFunds());
    }

    function impairLoan(MapleLoan loan) internal {
        impairLoan(address(poolManager), address(loan));
    }

    function requestRedeem(address lp, uint256 amount) internal {
        requestRedeem(address(pool), lp, amount);
    }

    function redeem(address lp, uint256 amount) internal returns (uint256 assets_) {
        assets_ = redeem(address(pool), lp, amount);
    }

}
