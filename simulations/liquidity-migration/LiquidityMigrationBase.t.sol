// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { console }   from "../../modules/contract-test-utils/contracts/log.sol";
import { Address, TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";

import { WithdrawalManager }            from "../../modules/withdrawal-manager/contracts/WithdrawalManager.sol";
import { WithdrawalManagerFactory }     from "../../modules/withdrawal-manager/contracts/WithdrawalManagerFactory.sol";
import { WithdrawalManagerInitializer } from "../../modules/withdrawal-manager/contracts/WithdrawalManagerInitializer.sol";

import { LoanManagerInitializer }                 from "../../modules/pool-v2/contracts/proxy/LoanManagerInitializer.sol";
import { PoolManagerFactory, MapleProxyFactory }  from "../../modules/pool-v2/contracts/proxy/PoolManagerFactory.sol";
import { PoolManagerInitializer }                 from "../../modules/pool-v2/contracts/proxy/PoolManagerInitializer.sol";
import { LoanManager }                            from "../../modules/pool-v2/contracts/LoanManager.sol";
import { Pool }                                   from "../../modules/pool-v2/contracts/Pool.sol";
import { PoolDeployer }                           from "../../modules/pool-v2/contracts/PoolDeployer.sol";
import { PoolManager }                            from "../../modules/pool-v2/contracts/PoolManager.sol";
import { LoanManagerFactory }                     from "../../modules/pool-v2/contracts/proxy/LoanManagerFactory.sol";
import { TransitionLoanManager }                  from "../../modules/pool-v2/contracts/TransitionLoanManager.sol";

import { MapleGlobals }        from "../../modules/globals-v2/contracts/MapleGlobals.sol";
import { NonTransparentProxy } from "../../modules/globals-v2/modules/non-transparent-proxy/contracts/NonTransparentProxy.sol";

import { DebtLocker as DebtLockerV4 } from "../../modules/debt-locker-v4/contracts/DebtLocker.sol";
import { DebtLockerV4Migrator }       from "../../modules/debt-locker-v4/contracts/DebtLockerV4Migrator.sol";

import { MapleLoan as LoanV4 } from "../../modules/loan/contracts/MapleLoan.sol";
import { MapleLoanV4Migrator } from "../../modules/loan/contracts/MapleLoanV4Migrator.sol";
import { MapleLoanFeeManager } from "../../modules/loan/contracts/MapleLoanFeeManager.sol";

import { MapleLoan as LoanV301 } from "../../modules/loan-v301/contracts/MapleLoan.sol";

import { DeactivationOracle } from "../../modules/migration-helpers/contracts/DeactivationOracle.sol";
import { MigrationHelper    } from "../../modules/migration-helpers/contracts/MigrationHelper.sol";

import { AddressRegistry } from "../AddressRegistry.sol";

import {
    IERC20Like,
    ILoanFactoryLike,
    ILoanInitializerLike,
    IMapleGlobalsLike,
    IMapleLoanLike,
    IMapleProxyFactoryLike,
    IMapleProxiedLike,
    IMplRewardsLike,
    IPoolLike,
    IStakeLockerLike
} from "./Interfaces.sol";


contract LiquidityMigrationBase is TestUtils, AddressRegistry {

    address TREASURY        = address(new Address());
    address MIGRATION_ADMIN = address(new Address());

    // PoolV2 Variables
    address poolDelegate;
    address asset;

    address poolManagerFactory;
    address poolManagerImplementation;
    address poolManagerInitializer;

    address loanManagerFactory;
    address loanManagerImplementation;
    address loanManagerInitializer;

    address withdrawalManagerFactory;
    address withdrawalManagerImplementation;
    address withdrawalManagerInitializer;

    uint256 start;

    IMapleGlobalsLike     globalsV1;
    IMapleLoanLike        cashLoan;
    IPoolLike             poolV1;
    IStakeLockerLike      stakeLocker;
    MapleGlobals          globals;
    MapleLoanFeeManager   feeManager;
    MigrationHelper       migrationHelper;
    PoolDeployer          poolDeployer;
    PoolManager           poolManager;
    TransitionLoanManager transitionLoanManager;

    uint256[6] configParams;

    function setUp() public virtual {
        migrationHelper = new MigrationHelper();

        start = block.timestamp;
    }

    /************************/
    /*** Helper Functions ***/
    /************************/

    function _addLoansToTransitionLM(address[] memory loans_) internal {
        for (uint i = 0; i < loans_.length; i++) {
            vm.prank(MIGRATION_ADMIN);
            transitionLoanManager.add(loans_[i]);
        }
    }

    function _airdropTokens(address source_, address asset_, address from_, address[] memory destinations_) internal {
        IPoolLike pool = IPoolLike(source_);
        uint256 totalLosses = pool.poolLosses();

        vm.startPrank(from_);
        for (uint i = 0; i < destinations_.length; i++) {
            uint256 losses = 0;
            if (totalLosses > 0) {
                losses = pool.recognizableLossesOf(destinations_[i]);
            }
            IERC20Like(asset_).transfer(destinations_[i], pool.balanceOf(destinations_[i]) + pool.withdrawableFundsOf(destinations_[i]) - losses);
        }
        vm.stopPrank();
    }

    function _createAndFundLoan(uint256 principalRequested, address v1Delegate) internal {
        address[2] memory assets = [asset, asset];
        uint256[3] memory termDetails = [
            uint256(10 days),  // 10 day grace period
            uint256(10 days),  // 30 day payment interval
            uint256(1)
        ];

        uint256[3] memory requests = [0, principalRequested, principalRequested];
        uint256[4] memory rates    = [uint256(0), uint256(0), uint256(0), uint256(0)];

        bytes memory arguments = ILoanInitializerLike(LOAN_INITIALIZER).encodeArguments(address(this), assets, termDetails, requests, rates);

        bytes32 salt = keccak256(abi.encodePacked("salt"));

        address loan_ = ILoanFactoryLike(address(LOAN_FACTORY)).createInstance(arguments, salt);

        cashLoan = IMapleLoanLike(loan_);

        vm.prank(v1Delegate);
        poolV1.fundLoan(loan_, DL_FACTORY, principalRequested);

        MAVEN11_LOANS.push(loan_);
    }

    function _createGlobals() internal {
        globals      = MapleGlobals(address(new NonTransparentProxy(GOVERNOR, address(new MapleGlobals(0, 0)))));
        poolDeployer = new PoolDeployer(address(globals));

        vm.startPrank(GOVERNOR);
        globals.setMapleTreasury(TREASURY);
        globals.setValidPoolAsset(address(asset), true);
        globals.setValidPoolDelegate(poolDelegate, true);
        globals.setValidPoolDeployer(address(poolDeployer), true);
        globals.setMigrationAdmin(address(MIGRATION_ADMIN));
        vm.stopPrank();
    }

    function _deactivatePool(address poolAddress_, address delegate_) internal {
        IPoolLike pool_ = IPoolLike(poolAddress_);
        address asset_  = pool_.liquidityAsset();

        // Replace the USDC oracle in globals for a dummy one
        DeactivationOracle oracle = new DeactivationOracle();

        vm.prank(GOVERNOR);
        globalsV1.setPriceOracle(asset_, address(oracle));

        vm.prank(delegate_);
        pool_.deactivate();
    }

    function _deployPoolV2() internal {
        string memory name   = "Pool";
        string memory symbol = "P2";

        address[3] memory factories = [
            poolManagerFactory,
            loanManagerFactory,
            withdrawalManagerFactory
        ];

        address[3] memory initializers = [
            poolManagerInitializer,
            loanManagerInitializer,
            withdrawalManagerInitializer
        ];

        uint256 initialSupply = _getPoolV1TotalValue();

        // Update PoolV2 configs
        configParams = [
            1_000_000e18,
            0.1e6,
            0,
            3 days,
            1 days,
            initialSupply
        ];

        vm.prank(poolDelegate);
        ( address poolManagerAddress, address loanManagerAddress, address withdrawalManagerAddress ) = PoolDeployer(poolDeployer).deployPool(
            factories,
            initializers,
            address(asset),
            name,
            symbol,
            configParams
        );

        poolManager           = PoolManager(poolManagerAddress);
        transitionLoanManager = TransitionLoanManager(loanManagerAddress);
    }

    function _getPoolV1TotalValue() internal view returns (uint256 supply_) {
        return IPoolLike(poolV1).totalSupply() + IPoolLike(poolV1).interestSum() - IPoolLike(poolV1).poolLosses();
    }

    function _lockPoolDeposits() internal {
        vm.prank(MAVEN11_PD);

        poolV1.setLiquidityCap(0);
    }

    function _payBackLoan() internal {
        ( uint256 principal, uint256 interest, uint256 fees ) = cashLoan.getClosingPaymentBreakdown();

        // Although we haven't spent any of the loaned amount, we did pay protocol fees
        erc20_mint(asset, 3, address(cashLoan), principal + interest + fees);
        cashLoan.closeLoan(0);
    }

    function _setUpPoolV2Deployment() internal {
        // Set up pool deployment
        _createGlobals();

        poolManagerFactory        = address(new PoolManagerFactory(address(globals)));
        poolManagerImplementation = address(new PoolManager());
        poolManagerInitializer    = address(new PoolManagerInitializer());

        loanManagerFactory        = address(new LoanManagerFactory(address(globals)));
        loanManagerImplementation = address(new LoanManager());
        loanManagerInitializer    = address(new LoanManagerInitializer());

        withdrawalManagerFactory        = address(new WithdrawalManagerFactory(address(globals)));
        withdrawalManagerImplementation = address(new WithdrawalManager());
        withdrawalManagerInitializer    = address(new WithdrawalManagerInitializer());

        vm.startPrank(GOVERNOR);

        globals.setValidFactory("LOAN_MANAGER",       loanManagerFactory,       true);
        globals.setValidFactory("POOL_MANAGER",       poolManagerFactory,       true);
        globals.setValidFactory("WITHDRAWAL_MANAGER", withdrawalManagerFactory, true);

        MapleProxyFactory(poolManagerFactory).registerImplementation(1, poolManagerImplementation, poolManagerInitializer);
        MapleProxyFactory(poolManagerFactory).setDefaultVersion(1);

        MapleProxyFactory(loanManagerFactory).registerImplementation(200, loanManagerImplementation, loanManagerInitializer);
        MapleProxyFactory(loanManagerFactory).setDefaultVersion(200);

        MapleProxyFactory(withdrawalManagerFactory).registerImplementation(1, withdrawalManagerImplementation, withdrawalManagerInitializer);
        MapleProxyFactory(withdrawalManagerFactory).setDefaultVersion(1);
        vm.stopPrank();
    }

    function _setUpTransitionLoanManagerFactory() internal {
        address implementation = address(new TransitionLoanManager());
        address initializer    = address(new LoanManagerInitializer());

        LoanManagerFactory factory = LoanManagerFactory(loanManagerFactory);

        vm.startPrank(GOVERNOR);
        factory.registerImplementation(100, implementation, initializer);
        factory.setDefaultVersion(100);
        factory.enableUpgradePath(100, 200, address(0));
        vm.stopPrank();
    }

    function _registerDebtLockerV4() internal {
        // Deploy new debtLocker v4 version
        address implementation     = address(new DebtLockerV4());
        address debtLockerMigrator = address(new DebtLockerV4Migrator());

        vm.startPrank(GOVERNOR);
        IMapleProxyFactoryLike factory = IMapleProxyFactoryLike(DL_FACTORY);

        factory.registerImplementation(400, implementation, DL_INITIALIZER);
        factory.enableUpgradePath(200, 400, debtLockerMigrator);
        factory.enableUpgradePath(300, 400, debtLockerMigrator);
        vm.stopPrank();
    }

    function _registerLoanVersions() internal {
        // Deploy new loan v4 version
        address implementation   = address(new LoanV4());
        address implementationV3 = address(new LoanV301());

        vm.startPrank(GOVERNOR);
        IMapleProxyFactoryLike factory = IMapleProxyFactoryLike(LOAN_FACTORY);

        address migrator = address(new MapleLoanV4Migrator());

        factory.registerImplementation(400, implementation,   LOAN_INITIALIZER);
        factory.registerImplementation(301, implementationV3, LOAN_INITIALIZER);

        factory.setDefaultVersion(301);

        factory.enableUpgradePath(200, 301, address(0));
        factory.enableUpgradePath(300, 301, address(0));
        factory.enableUpgradePath(301, 400, migrator);
        vm.stopPrank();

        // Deploy Fee Manager
        feeManager = new MapleLoanFeeManager(address(globals));
    }

    function _upgradeDebtLockers(address v1Delegate_, address[] memory loans, uint256 version) internal {
        vm.startPrank(v1Delegate_);
        for (uint256 i = 0; i < loans.length; i++) {
            // Get debt Locker
            address debtLocker = IMapleLoanLike(loans[i]).lender();

            IMapleProxiedLike(debtLocker).upgrade(version, abi.encode(migrationHelper));
        }
        vm.stopPrank();
    }

    function _upgradeLoansToV301(address[] memory loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            address borrower = IMapleLoanLike(loans[i]).borrower();
            vm.prank(borrower);
            IMapleProxiedLike(loans[i]).upgrade(301, new bytes(0));
        }
    }

    function _upgradeLoansToV4(address[] memory loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            vm.prank(GLOBAL_ADMIN);
            IMapleProxiedLike(loans[i]).upgrade(400, abi.encode(address(feeManager)));
        }
    }

}
