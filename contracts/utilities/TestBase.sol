// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { Address, TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";

import { MockERC20 as Asset } from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { MapleGlobals as Globals } from "../../modules/globals-v2/contracts/MapleGlobals.sol";
import { NonTransparentProxy     } from "../../modules/globals-v2/modules/non-transparent-proxy/contracts/NonTransparentProxy.sol";

import { Liquidator            } from "../../modules/liquidations/contracts/Liquidator.sol";
import { LiquidatorFactory     } from "../../modules/liquidations/contracts/LiquidatorFactory.sol";
import { LiquidatorInitializer } from "../../modules/liquidations/contracts/LiquidatorInitializer.sol";

import { MapleLoan as Loan                       } from "../../modules/loan/contracts/MapleLoan.sol";
import { MapleLoanFactory as LoanFactory         } from "../../modules/loan/contracts/MapleLoanFactory.sol";
import { MapleLoanFeeManager as FeeManager       } from "../../modules/loan/contracts/MapleLoanFeeManager.sol";
import { MapleLoanInitializer as LoanInitializer } from "../../modules/loan/contracts/MapleLoanInitializer.sol";

import { LoanManager             } from "../../modules/pool-v2/contracts/LoanManager.sol";
import { Pool                    } from "../../modules/pool-v2/contracts/Pool.sol";
import { PoolDelegateCover       } from "../../modules/pool-v2/contracts/PoolDelegateCover.sol";
import { PoolDeployer            } from "../../modules/pool-v2/contracts/PoolDeployer.sol";
import { PoolManager             } from "../../modules/pool-v2/contracts/PoolManager.sol";
import { LoanManagerFactory      } from "../../modules/pool-v2/contracts/proxy/LoanManagerFactory.sol";
import { LoanManagerInitializer  } from "../../modules/pool-v2/contracts/proxy/LoanManagerInitializer.sol";
import { PoolManagerFactory      } from "../../modules/pool-v2/contracts/proxy/PoolManagerFactory.sol";
import { PoolManagerInitializer  } from "../../modules/pool-v2/contracts/proxy/PoolManagerInitializer.sol";
import { MockLiquidationStrategy } from "../../modules/pool-v2/tests/mocks/Mocks.sol";

import { WithdrawalManager            } from "../../modules/withdrawal-manager/contracts/WithdrawalManager.sol";
import { WithdrawalManagerFactory     } from "../../modules/withdrawal-manager/contracts/WithdrawalManagerFactory.sol";
import { WithdrawalManagerInitializer } from "../../modules/withdrawal-manager/contracts/WithdrawalManagerInitializer.sol";

contract TestBase is TestUtils {

    uint256 constant MAX_TOKEN_AMOUNT = 1e29;

    uint256 constant ONE_DAY   = 1 days;
    uint256 constant ONE_MONTH = ONE_YEAR / 12;
    uint256 constant ONE_YEAR  = 365 days;

    address governor;
    address poolDelegate;
    address treasury;

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

    // Helper Mapping to assert differenes in balace
    mapping(address => uint256) partialAssetBalances;

    Asset        collateralAsset;
    Asset        fundsAsset;
    Globals      globals;
    PoolDeployer deployer;

    FeeManager        feeManager;
    LoanManager       loanManager;
    Pool              pool;
    PoolDelegateCover poolCover;
    PoolManager       poolManager;
    WithdrawalManager withdrawalManager;

    function setUp() public virtual {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _createFactories();
        _createAndConfigurePool(1 weeks, 2 days);
        _openPool();

        start = block.timestamp;
    }

    /********************************/
    /*** Initialization Functions ***/
    /********************************/

    function _createAccounts() internal {
        governor     = address(new Address());
        poolDelegate = address(new Address());
        treasury     = address(new Address());
    }

    function _createAssets() internal {
        collateralAsset = new Asset("Wrapper Ether", "WETH", 18);
        fundsAsset      = new Asset("USD Coin",      "USDC", 6);
    }

    function _createFactories() internal {
        liquidatorFactory        = address(new LiquidatorFactory(address(globals)));
        loanFactory              = address(new LoanFactory(address(globals)));
        loanManagerFactory       = address(new LoanManagerFactory(address(globals)));
        poolManagerFactory       = address(new PoolManagerFactory(address(globals)));
        withdrawalManagerFactory = address(new WithdrawalManagerFactory(address(globals)));

        liquidatorImplementation        = address(new Liquidator());
        loanImplementation              = address(new Loan());
        loanManagerImplementation       = address(new LoanManager());
        poolManagerImplementation       = address(new PoolManager());
        withdrawalManagerImplementation = address(new WithdrawalManager());

        liquidatorInitializer        = address(new LiquidatorInitializer());
        loanInitializer              = address(new LoanInitializer());
        loanManagerInitializer       = address(new LoanManagerInitializer());
        poolManagerInitializer       = address(new PoolManagerInitializer());
        withdrawalManagerInitializer = address(new WithdrawalManagerInitializer());

        vm.startPrank(governor);

        globals.setValidFactory("LIQUIDATOR",         liquidatorFactory,        true);
        globals.setValidFactory("LOAN_MANAGER",       loanManagerFactory,       true);
        globals.setValidFactory("POOL_MANAGER",       poolManagerFactory,       true);
        globals.setValidFactory("WITHDRAWAL_MANAGER", withdrawalManagerFactory, true);

        LiquidatorFactory(liquidatorFactory).registerImplementation(1, liquidatorImplementation, liquidatorInitializer);
        LiquidatorFactory(liquidatorFactory).setDefaultVersion(1);

        LoanFactory(loanFactory).registerImplementation(1, loanImplementation, loanInitializer);
        LoanFactory(loanFactory).setDefaultVersion(1);

        LoanManagerFactory(loanManagerFactory).registerImplementation(1, loanManagerImplementation, loanManagerInitializer);
        LoanManagerFactory(loanManagerFactory).setDefaultVersion(1);

        PoolManagerFactory(poolManagerFactory).registerImplementation(1, poolManagerImplementation, poolManagerInitializer);
        PoolManagerFactory(poolManagerFactory).setDefaultVersion(1);

        WithdrawalManagerFactory(withdrawalManagerFactory).registerImplementation(1, withdrawalManagerImplementation, withdrawalManagerInitializer);
        WithdrawalManagerFactory(withdrawalManagerFactory).setDefaultVersion(1);

        vm.stopPrank();
    }

    function _createGlobals() internal {
        uint128 delay    = 1 weeks;
        uint128 duration = 2 days;

        globals = Globals(address(new NonTransparentProxy(governor, address(new Globals()))));

        deployer = new PoolDeployer(address(globals));

        vm.startPrank(governor);
        globals.setMapleTreasury(treasury);
        globals.setSecurityAdmin(governor);
        globals.setValidPoolAsset(address(fundsAsset), true);
        globals.setValidPoolDelegate(poolDelegate, true);
        globals.setValidPoolDeployer(address(deployer), true);
        globals.setManualOverridePrice(address(fundsAsset),      1e8);     // 1     USD / 1 USDC
        globals.setManualOverridePrice(address(collateralAsset), 1500e8);  // 1_500 USD / 1 WETH
        globals.setDefaultTimelockParameters(delay, duration);
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
        feeManager        = new FeeManager(address(globals));
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

    /***********************/
    /*** Setup Functions ***/
    /***********************/

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
    ) internal returns (Loan loan) {
        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

        loan = Loan(LoanFactory(loanFactory).createInstance({
            arguments_: new LoanInitializer().encodeArguments({
                borrower_:    borrower,
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

    function depositCover(uint256 cover) internal {
        vm.startPrank(poolDelegate);
        fundsAsset.approve(address(poolManager), cover);
        fundsAsset.mint(poolDelegate, cover);

        poolManager.depositCover(cover);
        vm.stopPrank();
    }

    function depositLiquidity(address lp, uint256 liquidity) internal returns (uint256 shares) {
        fundsAsset.mint(lp, liquidity);

        vm.startPrank(lp);
        fundsAsset.approve(address(pool), liquidity);
        shares = Pool(pool).deposit(liquidity, lp);
        vm.stopPrank();
    }

    function encodeWithSignatureAndUint(string memory signature_, uint256 arg_) internal pure returns (bytes[] memory calls) {
        calls    = new bytes[](1);
        calls[0] = abi.encodeWithSignature(signature_, arg_);
    }

    function fundAndDrawdownLoan(
        address borrower,
        uint256[3] memory termDetails,
        uint256[3] memory amounts,
        uint256[4] memory rates
    )
        internal returns (Loan loan)
    {
        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

        loan = createLoan(borrower, termDetails, amounts, rates);

        vm.prank(poolDelegate);
        poolManager.fund(amounts[1], address(loan), address(loanManager));

        vm.startPrank(borrower);
        collateralAsset.mint(address(loan), amounts[0]);
        loan.drawdownFunds(loan.drawableFunds(), borrower);
        vm.stopPrank();
    }

    function makePayment(Loan loan) internal {
        ( uint256 principal, uint256 interest, uint256 fees ) = loan.getNextPaymentBreakdown();

        uint256 payment = principal + interest + fees;

        vm.startPrank(loan.borrower());
        fundsAsset.mint(loan.borrower(), payment);
        fundsAsset.approve(address(loan), payment);
        loan.makePayment(payment);
        vm.stopPrank();
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

    function liquidateCollateral(Loan loan) internal {
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

    function requestRedeem(address lp, uint256 amount) internal {
        vm.prank(lp);
        pool.requestRedeem(amount);
    }

    function redeem(address lp, uint256 amount) internal returns (uint256 assets_) {
        vm.prank(lp);
        assets_ = pool.redeem(amount, lp, lp);
    }

    function updateWithdrawal(address lp, uint256 sharesToTransfer) internal {
        // TODO
    }

    function withdraw(address lp, uint256 sharesToTransfer) internal {
        // TODO
    }

}
