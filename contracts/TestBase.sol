// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

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

import { Address, TestUtils } from "../modules/test-utilities/contracts/test.sol";

import { WithdrawalManager            } from "../modules/withdrawal-manager/contracts/WithdrawalManager.sol";
import { WithdrawalManagerFactory     } from "../modules/withdrawal-manager/contracts/WithdrawalManagerFactory.sol";
import { WithdrawalManagerInitializer } from "../modules/withdrawal-manager/contracts/WithdrawalManagerInitializer.sol";

contract TestBase is TestUtils {

    address governor;
    address mapleTreasury;
    address poolDelegate;

    uint256 nextDelegateOriginationFee;
    uint256 nextDelegateServiceFee;
    uint256 start;

    Asset collateralAsset;
    Asset fundsAsset;

    Globals globals;

    LoanFactory              loanFactory;
    LoanManagerFactory       loanManagerFactory;
    PoolManagerFactory       poolManagerFactory;
    WithdrawalManagerFactory withdrawalManagerFactory;

    PoolDeployer deployer;

    FeeManager        feeManager;
    LoanManager       loanManager;
    Pool              pool;
    PoolDelegateCover poolCover;
    PoolManager       poolManager;
    WithdrawalManager withdrawalManager;

    function setUp() public virtual {
        createAccounts();
        createAssets();
        createGlobals();
        createFactories();
        createPool();

        start = block.timestamp;
    }

    /********************************/
    /*** Initialization Functions ***/
    /********************************/

    function createAccounts() internal {
        governor      = address(new Address());
        mapleTreasury = address(new Address());
        poolDelegate  = address(new Address());
    }

    function createAssets() internal {
        collateralAsset = new Asset("Wrapper Ether", "WETH", 18);
        fundsAsset      = new Asset("USD Coin", "USDC", 6);
    }

    function createFactories() internal {
        vm.startPrank(governor);

        loanFactory = new LoanFactory(address(globals));
        loanFactory.registerImplementation(1, address(new Loan()), address(new LoanInitializer()));
        loanFactory.setDefaultVersion(1);

        loanManagerFactory = new LoanManagerFactory(address(globals));
        loanManagerFactory.registerImplementation(1, address(new LoanManager()), address(new LoanManagerInitializer()));
        loanManagerFactory.setDefaultVersion(1);

        poolManagerFactory = new PoolManagerFactory(address(globals));
        poolManagerFactory.registerImplementation(1, address(new PoolManager()), address(new PoolManagerInitializer()));
        poolManagerFactory.setDefaultVersion(1);

        withdrawalManagerFactory = new WithdrawalManagerFactory(address(globals));
        withdrawalManagerFactory.registerImplementation(1, address(new WithdrawalManager()), address(new WithdrawalManagerInitializer()));
        withdrawalManagerFactory.setDefaultVersion(1);

        vm.stopPrank();
    }

    function createGlobals() internal {
        globals  = Globals(address(new NonTransparentProxy(governor, address(new Globals()))));
        deployer = new PoolDeployer(address(globals));

        vm.startPrank(governor);
        globals.setMapleTreasury(mapleTreasury);
        globals.setValidPoolAsset(address(fundsAsset), true);
        globals.setValidPoolDelegate(poolDelegate, true);
        globals.setValidPoolDeployer(address(deployer), true);
        vm.stopPrank();
    }

    function createPool() internal {
        vm.startPrank(poolDelegate);

        ( address poolManager_, address loanManager_, address withdrawalManager_ ) = deployer.deployPool({
            factories_:    [address(poolManagerFactory),           address(loanManagerFactory),           address(withdrawalManagerFactory)],
            initializers_: [address(new PoolManagerInitializer()), address(new LoanManagerInitializer()), address(new WithdrawalManagerInitializer())],
            asset_:        address(fundsAsset),
            name_:         "Maple Pool",
            symbol_:       "MP",
            configParams_: [type(uint256).max, 0, 0, 1 weeks, 2 days]
        });

        vm.stopPrank();

        poolManager       = PoolManager(poolManager_);
        loanManager       = LoanManager(loanManager_);
        withdrawalManager = WithdrawalManager(withdrawalManager_);
        feeManager        = new FeeManager(address(globals));  // TODO: Do we include the fee manager into the deployer as well?

        pool       = Pool(poolManager.pool());
        poolCover  = PoolDelegateCover(poolManager.poolDelegateCover());

        vm.prank(governor);
        globals.activatePool(address(poolManager));

        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();
    }

    /***********************/
    /*** Setup Functions ***/
    /***********************/

    function depositCover(uint256 coverage) internal {
        // TODO
    }

    function depositLiquidity(address depositor, uint256 liquidity) internal returns (uint256 shares) {
        fundsAsset.mint(depositor, liquidity);

        vm.startPrank(depositor);
        fundsAsset.approve(address(pool), liquidity);
        shares = Pool(pool).deposit(liquidity, depositor);
        vm.stopPrank();
    }

    function fundAndDrawdownLoan(
        address borrower,
        uint256 principal,
        uint256 interestRate,
        uint256 paymentInterval,
        uint256 numberOfPayments
    )
        internal returns (Loan loan)
    {
        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

        loan = Loan(LoanFactory(loanFactory).createInstance({
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
        poolManager.fund(principal, address(loan), address(loanManager));

        vm.startPrank(borrower);
        loan.drawdownFunds(loan.drawableFunds(), borrower);
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
        uint256 delegateOriginationFee,
        uint256 delegateServiceFee,
        uint256 delegateManagementFeeRate,
        uint256 platformOriginationFeeRate,
        uint256 platformServiceFeeRate,
        uint256 platformManagementFeeRate
    ) internal {
        vm.startPrank(poolDelegate);
        nextDelegateOriginationFee = delegateOriginationFee;
        nextDelegateServiceFee     = delegateServiceFee;
        poolManager.setDelegateManagementFeeRate(delegateManagementFeeRate);
        vm.stopPrank();

        vm.startPrank(governor);
        globals.setPlatformOriginationFeeRate(address(poolManager), platformOriginationFeeRate);
        globals.setPlatformServiceFeeRate(address(poolManager),     platformServiceFeeRate);
        globals.setPlatformManagementFeeRate(address(poolManager),  platformManagementFeeRate);
        vm.stopPrank();
    }

    function updateWithdrawal(address lp, uint256 sharesToTransfer) internal {
        // TODO
    }

    function withdraw(address lp, uint256 sharesToTransfer) internal {
        // TODO
    }

}
