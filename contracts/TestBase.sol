// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { Address, TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

import { MockERC20 as Asset } from "../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { MapleGlobals as Globals } from "../modules/globals-v2/contracts/MapleGlobals.sol";
import { NonTransparentProxy     } from "../modules/globals-v2/modules/non-transparent-proxy/contracts/NonTransparentProxy.sol";

import { MapleLoan as Loan                       } from "../modules/loan/contracts/MapleLoan.sol";
import { MapleLoanFactory as LoanFactory         } from "../modules/loan/contracts/MapleLoanFactory.sol";
import { MapleLoanFeeManager as FeeManager       } from "../modules/loan/contracts/MapleLoanFeeManager.sol";
import { MapleLoanInitializer as LoanInitializer } from "../modules/loan/contracts/MapleLoanInitializer.sol";

import { LoanManager            } from "../modules/pool-v2/contracts/LoanManager.sol";
import { Pool                   } from "../modules/pool-v2/contracts/Pool.sol";
import { PoolDelegateCover      } from "../modules/pool-v2/contracts/PoolDelegateCover.sol";
import { PoolDeployer           } from "../modules/pool-v2/contracts/PoolDeployer.sol";
import { PoolManager            } from "../modules/pool-v2/contracts/PoolManager.sol";
import { LoanManagerFactory     } from "../modules/pool-v2/contracts/proxy/LoanManagerFactory.sol";
import { LoanManagerInitializer } from "../modules/pool-v2/contracts/proxy/LoanManagerInitializer.sol";
import { PoolManagerFactory     } from "../modules/pool-v2/contracts/proxy/PoolManagerFactory.sol";
import { PoolManagerInitializer } from "../modules/pool-v2/contracts/proxy/PoolManagerInitializer.sol";

import { WithdrawalManager            } from "../modules/withdrawal-manager/contracts/WithdrawalManager.sol";
import { WithdrawalManagerFactory     } from "../modules/withdrawal-manager/contracts/WithdrawalManagerFactory.sol";
import { WithdrawalManagerInitializer } from "../modules/withdrawal-manager/contracts/WithdrawalManagerInitializer.sol";

contract TestBase is TestUtils {

    uint256 MAX_TOKEN_AMOUNT = 1e29;

    address governor;
    address poolDelegate;
    address treasury;

    address loanFactory;
    address loanManagerFactory;
    address poolManagerFactory;
    address withdrawalManagerFactory;

    address loanImplementation;
    address loanManagerImplementation;
    address poolManagerImplementation;
    address withdrawalManagerImplementation;

    address loanInitializer;
    address loanManagerInitializer;
    address poolManagerInitializer;
    address withdrawalManagerInitializer;

    uint256 nextDelegateOriginationFee;
    uint256 nextDelegateServiceFee;

    uint256 start;

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
        _createPool();
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
        fundsAsset      = new Asset("USD Coin", "USDC", 6);
    }

    function _createFactories() internal {
        loanFactory              = address(new LoanFactory(address(globals)));
        loanManagerFactory       = address(new LoanManagerFactory(address(globals)));
        poolManagerFactory       = address(new PoolManagerFactory(address(globals)));
        withdrawalManagerFactory = address(new WithdrawalManagerFactory(address(globals)));

        loanImplementation              = address(new Loan());
        loanManagerImplementation       = address(new LoanManager());
        poolManagerImplementation       = address(new PoolManager());
        withdrawalManagerImplementation = address(new WithdrawalManager());

        loanInitializer              = address(new LoanInitializer());
        loanManagerInitializer       = address(new LoanManagerInitializer());
        poolManagerInitializer       = address(new PoolManagerInitializer());
        withdrawalManagerInitializer = address(new WithdrawalManagerInitializer());

        vm.startPrank(governor);
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
        globals  = Globals(address(new NonTransparentProxy(governor, address(new Globals(1 weeks, 2 days)))));
        deployer = new PoolDeployer(address(globals));

        vm.startPrank(governor);
        globals.setMapleTreasury(treasury);
        globals.setValidPoolAsset(address(fundsAsset), true);
        globals.setValidPoolDelegate(poolDelegate, true);
        globals.setValidPoolDeployer(address(deployer), true);
        vm.stopPrank();
    }

    function _createPool() internal {
        vm.prank(poolDelegate);
        ( address poolManager_, address loanManager_, address withdrawalManager_ ) = deployer.deployPool({
            factories_:    [poolManagerFactory,     loanManagerFactory,     withdrawalManagerFactory],
            initializers_: [poolManagerInitializer, loanManagerInitializer, withdrawalManagerInitializer],
            asset_:        address(fundsAsset),
            name_:         "Maple Pool",
            symbol_:       "MP",
            configParams_: [type(uint256).max, 0, 0, 1 weeks, 2 days]
        });

        poolManager       = PoolManager(poolManager_);
        loanManager       = LoanManager(loanManager_);
        withdrawalManager = WithdrawalManager(withdrawalManager_);
        pool              = Pool(poolManager.pool());
        poolCover         = PoolDelegateCover(poolManager.poolDelegateCover());
        feeManager        = new FeeManager(address(globals));

        vm.prank(governor);
        globals.activatePoolManager(address(poolManager));
    }

    function _openPool() internal {
        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();
    }

    /***********************/
    /*** Setup Functions ***/
    /***********************/

    function depositCover(uint256 coverage) internal {
        // TODO
    }

    function depositLiquidity(address lp, uint256 liquidity) internal returns (uint256 shares) {
        fundsAsset.mint(lp, liquidity);

        vm.startPrank(lp);
        fundsAsset.approve(address(pool), liquidity);
        shares = Pool(pool).deposit(liquidity, lp);
        vm.stopPrank();
    }

    function fundAndDrawdownLoan(
        address borrower,
        uint256 principal,
        uint256 interestRate,
        uint256 paymentInterval,
        uint256 numberOfPayments
    )
        internal returns (Loan loan_)
    {
        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

        loan_ = Loan(LoanFactory(loanFactory).createInstance({
            arguments_: new LoanInitializer().encodeArguments({
                globals_:        address(globals),
                borrower_:       borrower,
                feeManager_:     address(feeManager),
                assets_:         [address(collateralAsset), address(fundsAsset)],
                termDetails_:    [uint256(5 days), paymentInterval, numberOfPayments],
                amounts_:        [0, principal, principal],
                rates_:          [interestRate, 0, 0, 0],
                fees_:           [nextDelegateOriginationFee, nextDelegateServiceFee]
            }),
            salt_: "SALT"
        }));

        vm.prank(poolDelegate);
        poolManager.fund(principal, address(loan_), address(loanManager));

        vm.startPrank(borrower);
        loan_.drawdownFunds(loan_.drawableFunds(), borrower);
        vm.stopPrank();
    }

    function makePayment(Loan loan) internal {
        ( uint256 principal, uint256 interest, uint256 fees ) = loan.getNextPaymentBreakdown();
        uint256 payment = principal + interest + fees;

        vm.startPrank(loan.borrower());
        fundsAsset.mint(address(loan.borrower()), payment);
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

    function updateWithdrawal(address lp, uint256 sharesToTransfer) internal {
        // TODO
    }

    function withdraw(address lp, uint256 sharesToTransfer) internal {
        // TODO
    }

    /***************************/
    /*** Assertion Functions ***/
    /***************************/

    // TODO:

}
