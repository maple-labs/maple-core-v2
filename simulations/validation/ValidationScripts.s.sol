// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console, TestUtils } from "../../modules/contract-test-utils/contracts/test.sol";

import { AddressRegistry } from "./AddressRegistry.sol";

import {
    IDebtLockerLike,
    IERC20Like,
    ILoanLike,
    IMapleGlobalsV1Like,
    IMapleGlobalsV2Like,
    IMapleProxyFactoryLike,
    IMplRewardsLike,
    IPoolV1Like,
    IPoolV2Like,
    IPoolManagerLike,
    IStakeLockerLike,
    ITransitionLoanManagerLike
} from "./Interfaces.sol";

// TODO: move each validation run() into a properly named function in './simulations/mainnet/Validations', so they can be called individually. Each run() here can call them too.
// TODO: Add and update all bytecode hashes.
// TODO: And and update error messages for all assertions (use sentence case).

contract SetPoolAdmins is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedPoolV1);
        validate(mavenUsdcPoolV1);
        validate(mavenWethPoolV1);
        validate(orthogonalPoolV1);
        validate(icebreakerPoolV1);
    }

    function validate(IPoolV1Like poolV1) internal {
        assertTrue(poolV1.poolAdmins(migrationMultisig), "poolAdmins != migrationMultisig");
    }

}

contract SetInvestorAndTreasuryFee is AddressRegistry, TestUtils {

    function run() external {
        assertEq(mapleGlobalsV1.investorFee(), 0, "investorFee != 0");
        assertEq(mapleGlobalsV1.treasuryFee(), 0, "treasuryFee != 0");
    }

}

contract PayAndClaimUpcomingLoans is AddressRegistry, TestUtils {

    uint256 constant TOLERANCE = 5 days;

    function run() external {
        validate(mavenPermissionedLoans);
        validate(mavenUsdcLoans);
        validate(mavenWethLoans);
        validate(orthogonalLoans);
        validate(icebreakerLoans);
    }

    function validate(ILoanLike[] storage loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            uint256 nextPaymentDueDate = loans[i].nextPaymentDueDate();

            assertTrue(nextPaymentDueDate > block.timestamp && nextPaymentDueDate - block.timestamp >= TOLERANCE);
        }
    }

}

contract RemoveMaturedLoans is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedLoans);
        validate(mavenUsdcLoans);
        validate(mavenWethLoans);
        validate(orthogonalLoans);
        validate(icebreakerLoans);
    }

    function validate(ILoanLike[] storage loans) internal {
        for (uint i = 0; i < loans.length; i++) {
            if (loans[i].nextPaymentDueDate() == 0) {
                console.log("Matured loan: ", address(loans[i]));
            }
        }
    }

}

contract UpgradeLoansToV301 is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedLoans);
        validate(mavenUsdcLoans);
        validate(mavenWethLoans);
        validate(orthogonalLoans);
        validate(icebreakerLoans);
    }

    function validate(ILoanLike[] storage loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            assertVersion(loans[i], 301, "loan version != v301");
        }
    }

    function assertVersion(ILoanLike loan, uint256 version, string memory message) internal {
        assertEq(loan.implementation(), IMapleProxyFactoryLike(loan.factory()).implementationOf(version), message);
    }

}

contract DeployProtocol is AddressRegistry, TestUtils {

    function run() external {
        // Step 1: Deploy Globals
        assertEq(hash(address(mapleGlobalsV2Implementation).code), 0x7f8f00f34d98cb9159eb610be220ddf8831f949a680a1a9235a165b44c10f358);
        assertEq(hash(address(mapleGlobalsV2Proxy).code),          0x68ef8494eef4cbddfd9186d28f4152465fbe01c7c7ca23f7ad55258a056a63c6);

        assertEq(mapleGlobalsV2Proxy.admin(),          deployer);
        assertEq(mapleGlobalsV2Proxy.implementation(), mapleGlobalsV2Implementation);

        // Step 2: Deploy FeeManager
        assertEq(hash(address(feeManager).code), 0xeda0b8a07ec772cc345d84caaac0a95591b8dd090179f03dd427f40f0ed2d181);

        assertEq(feeManager.globals(), address(mapleGlobalsV2Proxy));

        // Step 3: Deploy Loan contracts
        assertEq(hash(address(loanV302Implementation).code), 0x0ef7cb3cb917189811b8415f495a75f29ee86da37b3d11f9ebd016b1d91d2f91);
        assertEq(hash(address(loanV400Initializer).code),    0x46ccdebd96ffac13c7f0b8de92a685dbdc5f75ead38ebd9ea0cfa3b45f7a0476);
        assertEq(hash(address(loanV400Implementation).code), 0x3a4d877fc6684f8ecca69ddd8516a91f1e71364e7d25e5a832127e81bb7d13cc);
        assertEq(hash(address(loanV400Migrator).code),       0x2ee0a69cf65afd91fd8ecf359882f7092230b488abd5ea0f0f0ac1babdcca17e);

        // Step 4: Deploy DebtLocker contracts
        assertEq(hash(address(debtLockerV400Implementation).code), 0x2997c917c29bc186e6623f04809af7193ebccb9a5fb9c026911e255fb3177023);
        assertEq(hash(address(debtLockerV400Migrator).code),       0x52f85e9d6dd6f16069d227279bdfa32c92fe9042f6249399d3e9b23adae4831e);

        // // Step 5: Deploy PoolDeployer
        assertEq(hash(address(poolDeployer).code), 0x5d1673eb250e69d9e9626f1174d94302f2d79982fb4a91a2f95d20b6cd372e58);

        assertEq(poolDeployer.globals(), address(mapleGlobalsV2Proxy));

        // Step 6: Set addresses in GlobalsV2
        assertEq(mapleGlobalsV2Proxy.mapleTreasury(), mapleTreasury);
        assertEq(mapleGlobalsV2Proxy.securityAdmin(), securityAdmin);

        // Step 7: Set valid PoolDeployer
        assertTrue(mapleGlobalsV2Proxy.isPoolDeployer(address(poolDeployer)));

        // Step 8: Allowlist assets
        assertTrue(mapleGlobalsV2Proxy.isPoolAsset(address(usdc)));
        assertTrue(mapleGlobalsV2Proxy.isPoolAsset(address(weth)));

        assertTrue(mapleGlobalsV2Proxy.isCollateralAsset(address(wbtc)));

        // Step 9: Set bootstrap mint amounts
        assertEq(mapleGlobalsV2Proxy.bootstrapMint(address(usdc)), 0.100000e6);
        assertEq(mapleGlobalsV2Proxy.bootstrapMint(address(weth)), 0.0001e18);

        // Step 10: Set timelock parameters
        ( uint256 delay, uint256 duration ) = mapleGlobalsV2Proxy.defaultTimelockParameters();

        assertEq(delay,    1 weeks);
        assertEq(duration, 2 days);

        // Step 11: Deploy factories
        assertEq(hash(address(liquidatorFactory).code),        0xdcb011ff44326687db40bf89317617d8d1bfa719792167c348f7cc18869ea00a);
        assertEq(hash(address(loanManagerFactory).code),       0xdbb33075e0c7b40708d91da2ff0b8079b3b10dbf7b1b4ed7ea361be9820853c9);
        assertEq(hash(address(poolManagerFactory).code),       0xcce0f3de8b59f96e8a8c3e2e2ef62c98471e9da7d3b3e7b67a797a7330683af5);
        assertEq(hash(address(withdrawalManagerFactory).code), 0x39c7708bb3c15bc3937ae195ff1165e48fea959884328267ceb05ff779c42cbb);

        // Step 12: Add factories to Globals
        assertTrue(mapleGlobalsV2Proxy.isFactory("LIQUIDATOR",         address(liquidatorFactory)));
        assertTrue(mapleGlobalsV2Proxy.isFactory("LOAN",               address(loanFactory)));
        assertTrue(mapleGlobalsV2Proxy.isFactory("LOAN_MANAGER",       address(loanManagerFactory)));
        assertTrue(mapleGlobalsV2Proxy.isFactory("POOL_MANAGER",       address(poolManagerFactory)));
        assertTrue(mapleGlobalsV2Proxy.isFactory("WITHDRAWAL_MANAGER", address(withdrawalManagerFactory)));

        // Step 13: Deploy implementations
        assertEq(hash(address(liquidatorImplementation).code),            0x2228119726f9db19c9fb746b16eff3b4014e7bdf60cc8f69ae9065e53073fa2c);
        assertEq(hash(address(loanManagerImplementation).code),           0x9049add2e5987fea245b694a2d1df8e54cc10226fa24f653ec933bf20f824224);
        assertEq(hash(address(poolManagerImplementation).code),           0xc305580ec768baa5f8bb063a3c962f1a7b518dc2ad8f59ec2ea6511f23e4082b);
        assertEq(hash(address(transitionLoanManagerImplementation).code), 0x99705e3583d4cdc51a0239a438cba8fea7b983b0db05deac1f6427ec034fefc7);
        assertEq(hash(address(withdrawalManagerImplementation).code),     0x73cacd589ed3a3b1c983dfec5de3cd4b44aec9850c2bb7f770e32fdc7cac1ae7);

        // Step 14: Deploy initializers
        assertEq(hash(address(liquidatorInitializer).code),        0xc79fbf65c93e10e0a85a415bc04aba7f7bb8f652380577662a6587fa0a6c82be);
        assertEq(hash(address(loanManagerInitializer).code),       0x8d983de33cbf96ca54e9a564e0a96ef46a29da300720998c7529eb9a2c58049a);
        assertEq(hash(address(poolManagerInitializer).code),       0x5cd8109a2339d5543ed65425029d620a927df3c13b9652ed69520d6313d2eb93);
        assertEq(hash(address(withdrawalManagerInitializer).code), 0xd28a2368f9fa100442ee9fd209035721180c2c75e1ca0244f5c1a5d013f28313);

        // Step 15: Configure LiquidatorFactory
        assertEq(liquidatorFactory.versionOf(liquidatorImplementation), 200);
        assertEq(liquidatorFactory.migratorForPath(200, 200), liquidatorInitializer);

        assertEq(liquidatorFactory.defaultVersion(), 200);

        // Step 16: Configure LoanManagerFactory
        assertEq(loanManagerFactory.versionOf(transitionLoanManagerImplementation), 100);
        assertEq(loanManagerFactory.migratorForPath(100, 100), loanManagerInitializer);

        assertEq(loanManagerFactory.versionOf(loanManagerImplementation), 200);
        assertEq(loanManagerFactory.migratorForPath(200, 200), loanManagerInitializer);

        assertEq(loanManagerFactory.migratorForPath(100, 200), address(0));
        assertTrue(loanManagerFactory.upgradeEnabledForPath(100, 200));

        assertEq(loanManagerFactory.defaultVersion(), 100);

        // Step 17: Configure PoolManagerFactory
        assertEq(poolManagerFactory.versionOf(poolManagerImplementation), 100);
        assertEq(poolManagerFactory.migratorForPath(100, 100), poolManagerInitializer);

        assertEq(poolManagerFactory.defaultVersion(), 100);

        // Step 18: Configure WithdrawalManagerFactory
        assertEq(withdrawalManagerFactory.versionOf(withdrawalManagerImplementation), 100);
        assertEq(withdrawalManagerFactory.migratorForPath(100, 100), withdrawalManagerInitializer);

        assertEq(withdrawalManagerFactory.defaultVersion(), 100);

        // Step 19: Allowlist Temporary Pool Delegate Multisigs
        assertTrue(mapleGlobalsV2Proxy.isPoolDelegate(icebreakerTemporaryPd));
        assertTrue(mapleGlobalsV2Proxy.isPoolDelegate(mavenPermissionedTemporaryPd));
        assertTrue(mapleGlobalsV2Proxy.isPoolDelegate(mavenUsdcTemporaryPd));
        assertTrue(mapleGlobalsV2Proxy.isPoolDelegate(mavenWethTemporaryPd));
        assertTrue(mapleGlobalsV2Proxy.isPoolDelegate(orthogonalTemporaryPd));

        // Step 20: Deploy MigrationHelper and AccountingChecker
        assertEq(hash(address(accountingChecker).code),             0xe45c193af3ed73882badc9b2adb464e88cb6a8c389651d9036a45360f51df841);
        assertEq(hash(address(deactivationOracle).code),            0xe44025c6c2dd15f6c3877ea5d5e5a2629597056f4042b3c9dda3728ff8547e72);
        assertEq(hash(address(migrationHelperImplementation).code), 0x8c38c3346296f6193ea7033fb2df2b6aada2d69dea50aadc30474b7323942cd8);
        assertEq(hash(address(migrationHelperProxy).code),          0xe01426b1af69fc6df8bcae5d9da313c2bb16b54b4ba70d7907406e242b072b75);

        assertEq(accountingChecker.globals(), address(mapleGlobalsV2Proxy));

        assertEq(migrationHelperProxy.admin(),          deployer);
        assertEq(migrationHelperProxy.implementation(), migrationHelperImplementation);

        // Step 21: Configure MigrationHelper
        assertEq(migrationHelperProxy.pendingAdmin(), migrationMultisig);
        assertEq(migrationHelperProxy.globalsV2(),    address(mapleGlobalsV2Proxy));

        // Step 22: Set the MigrationHelper in Globals
        assertEq(mapleGlobalsV2Proxy.migrationAdmin(), address(migrationHelperProxy));

        // Step 23: Transfer governor
        assertEq(mapleGlobalsV2Proxy.pendingGovernor(), tempGovernor);

        // Step 24: Check refinancer bytecode hash
        assertEq(hash(address(refinancer).code), 0x0bb294e63bd6018fa9b2465c6e7ecc9cef967bb91d5cb36d5f3882ebe08486ee);

        // TODO: Include validation of oracles after they are included in the deployment.
    }

    function hash(bytes memory code) internal pure returns (bytes32 bytecodeHash) {
        bytecodeHash = keccak256(abi.encode(code));
    }

}

contract SetTemporaryGovernor is AddressRegistry, TestUtils {

    function run() external {
        assertEq(mapleGlobalsV2Proxy.pendingGovernor(), address(0),            "pendingGovernor != zero");
        assertEq(mapleGlobalsV2Proxy.governor(),        address(tempGovernor), "governor != tempGovernor");
    }

}

contract SetMigrationMultisig is AddressRegistry, TestUtils {

    function run() external {
        assertEq(migrationHelperProxy.pendingAdmin(), address(0),                 "pendingAdmin != zero");
        assertEq(migrationHelperProxy.admin(),        address(migrationMultisig), "admin != migrationMultisig");
    }

}

contract RegisterDebtLockers is AddressRegistry, TestUtils {

    function run() external {
        assertEq(debtLockerFactory.versionOf(debtLockerV400Implementation), 400, "debt locker v400 implementation not set");
        assertEq(debtLockerFactory.migratorForPath(400, 400), debtLockerV300Initializer, "debt locker v400 initializer not set");

        assertEq(debtLockerFactory.migratorForPath(300, 400), debtLockerV400Migrator, "debt locker v300 to v400 migrator not set");
        assertTrue(debtLockerFactory.upgradeEnabledForPath(300, 400), "debt locker v300 to v400 upgrade disabled");
    }

}

contract RegisterLoans is AddressRegistry, TestUtils {

    function run() external {
        assertEq(loanFactory.versionOf(loanV302Implementation), 302, "loan v302 implementation not set");
        assertEq(loanFactory.migratorForPath(302, 302), loanV300Initializer, "loan v302 initializer not set");

        assertEq(loanFactory.versionOf(loanV400Implementation), 400, "loan v400 implementation not set");
        assertEq(loanFactory.migratorForPath(400, 400), loanV400Initializer, "loan v400 initializer not set");

        // assertEq(loanFactory.versionOf(loanV401Implementation), 401, "loan v401 implementation not set");
        // assertEq(loanFactory.migratorForPath(401, 401), loanV400Initializer, "loan v401 initializer not set");

        assertEq(loanFactory.migratorForPath(301, 302), address(0), "loan v301 to v302 migrator is not zero");
        assertTrue(loanFactory.upgradeEnabledForPath(301, 302), "loan v301 to v302 upgrade disabled");

        assertEq(loanFactory.migratorForPath(302, 400), loanV400Migrator, "loan v302 to v400 migrator not set");
        assertTrue(loanFactory.upgradeEnabledForPath(302, 400), "loan v302 to v400 upgrade disabled");

        // assertEq(loanFactory.migratorForPath(400, 401), address(0), "loan v400 to v401 migrator is not zero");
        // assertTrue(loanFactory.upgradeEnabledForPath(400, 401), "loan v400 to v401 upgrade disabled");
    }

}

contract UpgradeDebtLockersToV400 is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedLoans);
        validate(mavenUsdcLoans);
        validate(mavenWethLoans);
        validate(orthogonalLoans);
        validate(icebreakerLoans);
    }

    function validate(ILoanLike[] storage loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            assertVersion(IDebtLockerLike(loans[i].lender()), 400);
        }
    }

    function assertVersion(IDebtLockerLike debtLocker, uint256 version) internal {
        assertEq(debtLocker.implementation(), IMapleProxyFactoryLike(debtLocker.factory()).implementationOf(version));
    }

}

contract ClaimAllLoans is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedLoans);
        validate(mavenUsdcLoans);
        validate(mavenWethLoans);
        validate(orthogonalLoans);
        validate(icebreakerLoans);
    }

    function validate(ILoanLike[] storage loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            assertEq(loans[i].claimableFunds(), 0);

            IERC20Like asset = IERC20Like(loans[i].fundsAsset());
            address debtLocker = loans[i].lender();

            assertEq(asset.balanceOf(address(loans[i])),   0);
            assertEq(asset.balanceOf(address(debtLocker)), 0);
        }
    }

}

contract UpgradeLoansToV302 is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedLoans);
        validate(mavenUsdcLoans);
        validate(mavenWethLoans);
        validate(orthogonalLoans);
        validate(icebreakerLoans);
    }

    function validate(ILoanLike[] storage loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            assertVersion(loans[i], 302, "loan version != v302");
        }
    }

    function assertVersion(ILoanLike loan, uint256 version, string memory message) internal {
        assertEq(loan.implementation(), IMapleProxyFactoryLike(loan.factory()).implementationOf(version), message);
    }

}

contract SetLiquidityCapsToZero is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedPoolV1);
        validate(mavenUsdcPoolV1);
        validate(mavenWethPoolV1);
        validate(orthogonalPoolV1);
        validate(icebreakerPoolV1);
    }

    function validate(IPoolV1Like poolV1) internal {
        assertEq(poolV1.liquidityCap(), 0);
    }

}

contract QueryLiquidityLockers is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedPoolV1);
        validate(mavenUsdcPoolV1);
        validate(mavenWethPoolV1);
        validate(orthogonalPoolV1);
        validate(icebreakerPoolV1);
    }

    function validate(IPoolV1Like poolV1) internal {
        IERC20Like asset = IERC20Like(poolV1.liquidityAsset());

        console.log(asset.balanceOf(poolV1.liquidityLocker()));
    }

}

// NOTE: Don't forget to include the migration loan in all further loan checks.
contract CreateMigrationLoans is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedPoolV1, mavenPermissionedMigrationLoan, 0);
        validate(mavenUsdcPoolV1,         mavenUsdcMigrationLoan,         10078904.109590e6);
        validate(mavenWethPoolV1,         mavenWethMigrationLoan,         5015.161383043639410457e18);
        validate(orthogonalPoolV1,        orthogonalMigrationLoan,        39973865.060340e6);
        validate(icebreakerPoolV1,        icebreakerMigrationLoan,        5649999.999995e6);
    }

    function validate(IPoolV1Like poolV1, ILoanLike migrationLoan, uint256 principalRequested) internal {
        if (address(migrationLoan) != address(0)) {
            IERC20Like asset = IERC20Like(poolV1.liquidityAsset());

            assertEq(asset.balanceOf(poolV1.liquidityLocker()), principalRequested);
            assertEq(migrationLoan.principalRequested(),        principalRequested);
        }
    }

}

contract FundMigrationLoans is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedPoolV1, mavenPermissionedMigrationLoan, 0);
        validate(mavenUsdcPoolV1,         mavenUsdcMigrationLoan,         10078904.109590e6);
        validate(mavenWethPoolV1,         mavenWethMigrationLoan,         5015.161383043639410457e18);
        validate(orthogonalPoolV1,        orthogonalMigrationLoan,        39973865.060340e6);
        validate(icebreakerPoolV1,        icebreakerMigrationLoan,        5649999.999995e6);
    }

    function validate(IPoolV1Like poolV1, ILoanLike migrationLoan, uint256 funds) internal {
        if (address(migrationLoan) != address(0)) {
            IERC20Like asset = IERC20Like(migrationLoan.fundsAsset());

            assertEq(migrationLoan.drawableFunds(), funds);

            assertEq(asset.balanceOf(address(migrationLoan)),   funds);
            assertEq(asset.balanceOf(poolV1.liquidityLocker()), 0);
        }
    }

}

contract UpgradeMigrationLoans is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedMigrationLoan);
        validate(mavenUsdcMigrationLoan);
        validate(mavenWethMigrationLoan);
        validate(orthogonalMigrationLoan);
        validate(icebreakerMigrationLoan);
    }

    function validate(ILoanLike migrationLoan) internal {
        assertEq(migrationLoan.implementation(), IMapleProxyFactoryLike(migrationLoan.factory()).implementationOf(400));
    }

}

contract UpgradeMigrationDebtLockers is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedMigrationLoan);
        validate(mavenUsdcMigrationLoan);
        validate(mavenWethMigrationLoan);
        validate(orthogonalMigrationLoan);
        validate(icebreakerMigrationLoan);
    }

    function validate(ILoanLike loan) internal {
        IDebtLockerLike debtLocker = IDebtLockerLike(loan.lender());
        assertEq(debtLocker.implementation(), IMapleProxyFactoryLike(debtLocker.factory()).implementationOf(302));
    }

}

contract PauseProtocol is AddressRegistry, TestUtils {

    function run() external {
        assertTrue(mapleGlobalsV1.protocolPaused());
    }

}

contract DeployPools is AddressRegistry, TestUtils {

    struct PoolConfiguration {
        address poolDelegate;
        address asset;
        address pool;
        address loanManager;
        address poolDelegateCover;
        address withdrawalManager;
        bool    active;
        bool    configured;
        bool    openToPublic;
        uint256 liquidityCap;
        uint256 delegateManagementFeeRate;
    }

    function run() external {

        // TODO separate per pool?

        // Maven Permissioned Pool
        validatePool(mavenPermissionedPoolV2, mavenPermissionedPoolV1, address(mavenPermissionedPoolManager), address(usdc));
        validatePoolManager(
            mavenPermissionedPoolManager,
                PoolConfiguration({
                poolDelegate:              address(mavenPermissionedTemporaryPd),
                asset:                     address(usdc),
                pool:                      address(mavenPermissionedPoolV2),
                loanManager:               address(mavenPermissionedTransitionLoanManager),
                poolDelegateCover:         address(mavenPermissionedPoolDelegateCover),
                withdrawalManager:         address(mavenPermissionedWithdrawalManager),
                active:                    true,
                configured:                true,
                openToPublic:              false,
                liquidityCap:              0,
                delegateManagementFeeRate: 0.1e6
        }));

        // Maven Usdc Pool
        validatePool(mavenUsdcPoolV2, mavenUsdcPoolV1, address(mavenUsdcPoolManager), address(usdc));
        validatePoolManager(
                mavenUsdcPoolManager,
                PoolConfiguration({
                poolDelegate:              address(mavenUsdcTemporaryPd),
                asset:                     address(usdc),
                pool:                      address(mavenUsdcPoolV2),
                loanManager:               address(mavenUsdcTransitionLoanManager),
                poolDelegateCover:         address(mavenUsdcPoolDelegateCover),
                withdrawalManager:         address(mavenUsdcWithdrawalManager),
                active:                    true,
                configured:                true,
                openToPublic:              true,
                liquidityCap:              0,
                delegateManagementFeeRate: 0.1e6
        }));

        // Maven Weth Pool
        validatePool(mavenWethPoolV2, mavenWethPoolV1, address(mavenWethPoolManager), address(usdc));
        validatePoolManager(
                mavenWethPoolManager,
                PoolConfiguration({
                poolDelegate:              address(mavenWethTemporaryPd),
                asset:                     address(weth),
                pool:                      address(mavenWethPoolV2),
                loanManager:               address(mavenWethTransitionLoanManager),
                poolDelegateCover:         address(mavenWethPoolDelegateCover),
                withdrawalManager:         address(mavenWethWithdrawalManager),
                active:                    true,
                configured:                true,
                openToPublic:              true,
                liquidityCap:              0,
                delegateManagementFeeRate: 0.1e6
        }));

        // Orthogonal Pool
        validatePool(orthogonalPoolV2, orthogonalPoolV1, address(orthogonalPoolManager), address(usdc));
        validatePoolManager(
                orthogonalPoolManager,
                PoolConfiguration({
                poolDelegate:              address(orthogonalTemporaryPd),
                asset:                     address(usdc),
                pool:                      address(orthogonalPoolV2),
                loanManager:               address(orthogonalTransitionLoanManager),
                poolDelegateCover:         address(orthogonalPoolDelegateCover),
                withdrawalManager:         address(orthogonalWithdrawalManager),
                active:                    true,
                configured:                true,
                openToPublic:              true,
                liquidityCap:              0,
                delegateManagementFeeRate: 0.1e6
        }));


        // Icebreaker
        validatePool(icebreakerPoolV2, icebreakerPoolV1, address(icebreakerPoolManager), address(usdc));
        validatePoolManager(
                icebreakerPoolManager,
                PoolConfiguration({
                poolDelegate:              address(icebreakerTemporaryPd),
                asset:                     address(usdc),
                pool:                      address(icebreakerPoolV2),
                loanManager:               address(icebreakerTransitionLoanManager),
                poolDelegateCover:         address(icebreakerPoolDelegateCover),
                withdrawalManager:         address(icebreakerWithdrawalManager),
                active:                    true,
                configured:                true,
                openToPublic:              true,
                liquidityCap:              0,
                delegateManagementFeeRate: 0.1e6
        }));

    }

    function validatePool(IPoolV2Like poolV2, IPoolV1Like poolV1, address poolManager_, address asset_) internal {
        assertEq(hash(address(poolV2).code), 0);

        // Pool Assertions
        assertEq(poolV2.totalSupply(), getPoolV1TotalValue(poolV1));
        assertEq(poolV2.asset(),       poolV1.liquidityAsset());
        assertEq(poolV2.asset(),       asset_);
        assertEq(poolV2.manager(),     poolManager_);
    }

    function validatePoolManager(IPoolManagerLike poolManager_, PoolConfiguration memory poolConfig) internal {
        assertEq(poolManager_.poolDelegate(),              poolConfig.poolDelegate);
        assertEq(poolManager_.asset(),                     poolConfig.asset);
        assertEq(poolManager_.pool(),                      poolConfig.pool);
        assertEq(poolManager_.poolDelegateCover(),         poolConfig.poolDelegateCover);
        assertEq(poolManager_.withdrawalManager(),         poolConfig.withdrawalManager);
        assertEq(poolManager_.liquidityCap(),              poolConfig.liquidityCap);
        assertEq(poolManager_.delegateManagementFeeRate(), poolConfig.delegateManagementFeeRate);

        assertTrue(poolManager_.configured() == poolConfig.openToPublic);
        assertTrue(poolManager_.active()     == poolConfig.active);

        // Loan Manager
        assertTrue(poolManager_.isLoanManager());
        assertEq(poolManager_.loanManagerList(0), poolConfig.loanManager);

        // Fixed Value
        assertEq(poolManager_.pendingPoolDelegate(), address(0));
    }

    function getPoolV1TotalValue(IPoolV1Like poolV1) internal view returns (uint256 totalValue) {
        IERC20Like asset = IERC20Like(poolV1.liquidityAsset());

        totalValue = poolV1.totalSupply() * 10 ** asset.decimals() / 1e18 + poolV1.interestSum() - poolV1.poolLosses();
    }

    function hash(bytes memory code) internal pure returns (bytes32 bytecodeHash) {
        bytecodeHash = keccak256(abi.encode(code));
    }

}

contract AddLoansToTLM is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedTransitionLoanManager);
        validate(mavenUsdcTransitionLoanManager);
        validate(mavenWethTransitionLoanManager);
        validate(orthogonalTransitionLoanManager);
        validate(icebreakerTransitionLoanManager);
    }

    function validate(ITransitionLoanManagerLike tlm) internal {
        // TODO
    }

}

contract ActivatePools is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedPoolManager);
        validate(mavenUsdcPoolManager);
        validate(mavenWethPoolManager);
        validate(orthogonalPoolManager);
        validate(icebreakerPoolManager);
    }

    function validate(IPoolManagerLike poolManager) internal {
        assertTrue(poolManager.active(), "pool not active");

        // TODO: Add MapleGlobalsV2 assertions
    }

}

contract OpenPools is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenUsdcPoolManager);
        validate(mavenWethPoolManager);
        validate(orthogonalPoolManager);
        validate(icebreakerPoolManager);
    }

    function validate(IPoolManagerLike poolManager) internal {
        assertTrue(poolManager.openToPublic(), "pool not open to public");

        // TODO: Add MapleGlobalsV2 assertions
    }

}

contract PermissionPools is AddressRegistry, TestUtils {

    function run() external {
        assertTrue(!mavenPermissionedPoolManager.openToPublic(), "pool open to public");

        for (uint256 i = 0; i < mavenPermissionedLps.length; i++) {
            assertTrue(mavenPermissionedPoolManager.isValidLender(mavenPermissionedLps[i]));
        }

        assertTrue(mavenPermissionedPoolManager.isValidLender(address(mavenPermissionedWithdrawalManager)));
    }

}

contract WhitelistBorrowers is AddressRegistry, TestUtils {

    // TODO

}

contract AirdropTokens is AddressRegistry, TestUtils {

    function run() external {
        // validate(mavenWethPoolManager,         );
        // validate(mavenUsdcPoolManager,         );
        // validate(mavenPermissionedPoolManager, );
        // validate(orthogonalPoolManager,        );
        // validate(icebreakerPoolManager,        );
    }

    function validate() internal {
        // TODO: // migrationHelper.airdropTokens(address(poolV1), address(poolManager), lps, lps, lps.length * 2);
    }

}

contract SetPendingLenders is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedLoans, mavenPermissionedTransitionLoanManager);
        validate(mavenUsdcLoans,         mavenUsdcTransitionLoanManager);
        validate(mavenWethLoans,         mavenWethTransitionLoanManager);
        validate(orthogonalLoans,        orthogonalTransitionLoanManager);
        validate(icebreakerLoans,        icebreakerTransitionLoanManager);
    }

    function validate(ILoanLike[] storage loans, ITransitionLoanManagerLike tlm) internal {
        for (uint i = 0; i < loans.length; i++) {
            assertEq(loans[i].pendingLender(), address(tlm), "pending lender != tlm");
            // TODO: Assert lender
        }
    }

}

contract AcceptPendingLenders is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedLoans, mavenPermissionedTransitionLoanManager);
        validate(mavenUsdcLoans,         mavenUsdcTransitionLoanManager);
        validate(mavenWethLoans,         mavenWethTransitionLoanManager);
        validate(orthogonalLoans,        orthogonalTransitionLoanManager);
        validate(icebreakerLoans,        icebreakerTransitionLoanManager);
    }

    function validate(ILoanLike[] storage loans, ITransitionLoanManagerLike tlm) internal {
        for (uint i = 0; i < loans.length; i++) {
            assertEq(loans[i].lender(),        address(tlm), "lender != tlm");
            assertEq(loans[i].pendingLender(), address(0),   "pending lender != 0");
        }
    }

}

contract UpgradeTLM is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedTransitionLoanManager);
        validate(mavenUsdcTransitionLoanManager);
        validate(mavenWethTransitionLoanManager);
        validate(orthogonalTransitionLoanManager);
        validate(icebreakerTransitionLoanManager);
    }

    function validate(ITransitionLoanManagerLike tlm) internal {
        assertEq(tlm.implementation(), IMapleProxyFactoryLike(tlm.factory()).implementationOf(200));
    }

}

contract SetCoverAndLiquidationAmounts is AddressRegistry, TestUtils {

    function run() external {
        validate(mapleGlobalsV2Proxy, mavenWethPoolManager,         750e18);
        validate(mapleGlobalsV2Proxy, mavenUsdcPoolManager,         1_000_000e6);
        validate(mapleGlobalsV2Proxy, mavenPermissionedPoolManager, 1_750_000e6);
        validate(mapleGlobalsV2Proxy, orthogonalPoolManager,        2_500_000e6);
        validate(mapleGlobalsV2Proxy, icebreakerPoolManager,        500_000e6);
    }

    function validate(IMapleGlobalsV2Like mapleGlobalsV2Proxy, IPoolManagerLike poolManager, uint256 minCoverAmount) internal {
        assertEq(mapleGlobalsV2Proxy.minCoverAmount(address(poolManager)),             minCoverAmount);
        assertEq(mapleGlobalsV2Proxy.maxCoverLiquidationPercent(address(poolManager)), 0.5e6);
    }

}

contract UpgradeLoansToV400 is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedLoans);
        validate(mavenUsdcLoans);
        validate(mavenWethLoans);
        validate(orthogonalLoans);
        validate(icebreakerLoans);
    }

    function validate(ILoanLike[] storage loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            assertVersion(loans[i], 400, "loan version != v400");
        }
    }

    function assertVersion(ILoanLike loan, uint256 version, string memory message) internal {
        assertEq(loan.implementation(), IMapleProxyFactoryLike(loan.factory()).implementationOf(version), message);
    }

}

contract CheckLpPositions is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedPoolV1, mavenPermissionedPoolV2, mavenPermissionedLps);
        validate(mavenUsdcPoolV1,         mavenUsdcPoolV2,         mavenUsdcLps);
        validate(mavenWethPoolV1,         mavenWethPoolV2,         mavenWethLps);
        validate(orthogonalPoolV1,        orthogonalPoolV2,        orthogonalLps);
        validate(icebreakerPoolV1,        icebreakerPoolV2,        icebreakerLps);
    }

    function validate(IPoolV1Like poolV1, IPoolV2Like poolV2, address[] storage lps) internal {
        uint256 poolV1TotalValue  = getPoolV1TotalValue(poolV1);
        uint256 poolV2TotalSupply = poolV2.totalSupply();
        uint256 sumPosition       = getSumPosition(poolV1, lps);

        for (uint256 i; i < lps.length; i++) {
            uint256 v1Position = getV1Position(poolV1, lps[i]);
            uint256 v2Position = poolV2.balanceOf(lps[i]);

            if (i == 0) {
                v1Position += poolV1TotalValue - sumPosition;
            }

            uint256 v1Equity = v1Position * 1e18 / poolV1TotalValue;
            uint256 v2Equity = v2Position * 1e18 / poolV2TotalSupply;

            assertEq(v1Position, v2Position);
            assertEq(v1Equity,   v2Equity);
        }
    }

    function getPoolV1TotalValue(IPoolV1Like poolV1) internal view returns (uint256 totalValue) {
        IERC20Like asset = IERC20Like(poolV1.liquidityAsset());
        totalValue = poolV1.totalSupply() * 10 ** asset.decimals() / 1e18 + poolV1.interestSum() - poolV1.poolLosses();
    }

    function getSumPosition(IPoolV1Like poolV1, address[] storage lps) internal view returns (uint256 positionValue) {
        for (uint256 i = 0; i < lps.length; i++) {
            positionValue += getV1Position(poolV1, lps[i]);
        }
    }

    function getV1Position(IPoolV1Like poolV1, address lp) internal view returns (uint256 positionValue) {
        IERC20Like asset = IERC20Like(poolV1.liquidityAsset());
        positionValue = poolV1.balanceOf(lp) * 10 ** asset.decimals() / 1e18 + poolV1.withdrawableFundsOf(lp) - poolV1.recognizableLossesOf(lp);
    }
}

contract CloseMigrationLoans is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedMigrationLoan);
        validate(mavenUsdcMigrationLoan);
        validate(mavenWethMigrationLoan);
        validate(orthogonalMigrationLoan);
        validate(icebreakerMigrationLoan);
    }

    function validate(ILoanLike migrationLoan) internal {
        assertEq(migrationLoan.nextPaymentDueDate(), 0);
        assertEq(migrationLoan.paymentsRemaining(),  0);
    }

}

contract UpgradeLoansToV401 is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedLoans);
        validate(mavenUsdcLoans);
        validate(mavenWethLoans);
        validate(orthogonalLoans);
        validate(icebreakerLoans);
    }

    function validate(ILoanLike[] storage loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            assertVersion(loans[i], 401, "loan version is not v401");
        }
    }

    function assertVersion(ILoanLike loan, uint256 version, string memory message) internal {
        assertEq(loan.implementation(), IMapleProxyFactoryLike(loan.factory()).implementationOf(version), message);
    }

}

contract TransferPoolDelegates is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedPoolManager, mavenPermissionedFinalPd);
        validate(mavenUsdcPoolManager,         mavenUsdcFinalPd);
        validate(mavenWethPoolManager,         mavenWethFinalPd);
        validate(orthogonalPoolManager,        orthogonalFinalPd);
        validate(icebreakerPoolManager,        icebreakerFinalPd);
    }

    function validate(IPoolManagerLike poolManager, address finalPoolDelegate) internal {
        assertEq(poolManager.poolDelegate(), finalPoolDelegate);
    }

}

contract DeprecatePools is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedPoolV1);
        validate(mavenUsdcPoolV1);
        validate(mavenWethPoolV1);
        validate(orthogonalPoolV1);
        validate(icebreakerPoolV1);
    }

    function validate(IPoolV1Like poolV1) internal {
        address asset = poolV1.liquidityAsset();
        IStakeLockerLike stakeLocker = IStakeLockerLike(poolV1.stakeLocker());

        assertEq(mapleGlobalsV1.getLatestPrice(asset),  1e8);  // TODO: Is this always the returned value?
        assertEq(mapleGlobalsV1.stakerCooldownPeriod(), 0);
        assertEq(mapleGlobalsV1.stakerUnstakeWindow(),  0);

        // Initialized: 0, Finalized: 1, Deactivated: 2
        assertEq(poolV1.poolState(),         2);
        assertEq(stakeLocker.lockupPeriod(), 0);
    }

}

// TODO: Add a subgraph query to fetch cover providers
contract WithdrawCover is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedStakeLocker, mavenPermissionedRewards, mavenPermissionedCoverProviders);
        validate(mavenUsdcStakeLocker,         mavenUsdcRewards,         mavenUsdcCoverProviders);
        validate(mavenWethStakeLocker,         mavenWethRewards,         mavenWethCoverProviders);
        validate(orthogonalStakeLocker,        orthogonalRewards,        orthogonalCoverProviders);
        validate(icebreakerStakeLocker,        icebreakerRewards,        icebreakerCoverProviders);
    }

    function validate(IStakeLockerLike, IMplRewardsLike, address[] storage coverProviders) internal {
        // TODO
    }

}

contract DepositCover is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedPoolManager, 1_750_000e6);
        validate(mavenUsdcPoolManager,         1_000_000e6);
        validate(mavenWethPoolManager,         750e18);
        validate(orthogonalPoolManager,        2_500_000e6);
        validate(icebreakerPoolManager,        500_000e6);
    }

    function validate(IPoolManagerLike poolManager, uint256 amount) internal {
        address poolDelegateCover = poolManager.poolDelegateCover();
        IERC20Like asset = IERC20Like(poolManager.asset());

        assertEq(asset.balanceOf(poolDelegateCover), amount);
    }

}

contract IncreaseLiquidityCaps is AddressRegistry, TestUtils {

    function run() external {
        validate(mavenPermissionedPoolManager, 100_000_000e6);
        validate(mavenUsdcPoolManager,         100_000_000e6);
        validate(mavenWethPoolManager,         100_000e18);
        validate(orthogonalPoolManager,        100_000_000e6);
        validate(icebreakerPoolManager,        100_000_000e6);
    }

    function validate(IPoolManagerLike poolManager, uint256 liquidityCap) internal {
        assertEq(poolManager.liquidityCap(), liquidityCap);
    }

}

contract UnpauseProtocol is AddressRegistry, TestUtils {

    function run() external {
        assertTrue(!mapleGlobalsV1.protocolPaused());
    }

}

// TODO: Add post migration validation

// contract RequestUnstakeValidationScript is AddressRegistry, TestUtils {

//     function run() external {
//         validate(mavenPermissionedStakeLocker, mavenPermissionedPoolV1.poolDelegate(), 1_622_400_000);
//         validate(mavenUsdcStakeLocker,         mavenUsdcPoolV1.poolDelegate(),         1_622_400_000);
//         validate(mavenWethStakeLocker,         mavenWethPoolV1.poolDelegate(),         1_622_400_000);
//         validate(orthogonalStakeLocker,        orthogonalPoolV1.poolDelegate(),        1_622_400_000);
//         validate(icebreakerStakeLocker,        icebreakerPoolV1.poolDelegate(),        1_622_400_000);
//     }

//     function validate(IStakeLockerLike stakeLocker, address poolDelegate, uint256 timestamp) internal {
//         assertEq(stakeLocker.unstakeCooldown(poolDelegate), timestamp);
//     }

// }

// contract ValidateDefaultVersionsAreSet is AddressRegistry, TestUtils {

//     function run() external {
//         // assertEq()
//     }

// }

// contract UnstakeDelegateCoverValidationScript is AddressRegistry, TestUtils {

//     function run() external {
//         validate(mavenWethStakeLocker,         mavenWethPoolV1.poolDelegate(),         125_049.87499e18,          0, 0, 0);
//         validate(mavenUsdcStakeLocker,         mavenUsdcPoolV1.poolDelegate(),         153.022e18,                0, 0, 0);
//         validate(mavenPermissionedStakeLocker, mavenPermissionedPoolV1.poolDelegate(), 16.319926286804447168e18,  0, 0, 0);
//         validate(orthogonalStakeLocker,        orthogonalPoolV1.poolDelegate(),        175.122243323160822654e18, 0, 0, 0);
//         validate(icebreakerStakeLocker,        icebreakerPoolV1.poolDelegate(),        104.254119288711119987e18, 0, 0, 0);
//     }

//     function validate(
//         uint256 losses
//     ) internal {
//         IERC20Like bpt = IERC20Like(stakeLocker.stakeAsset());

//         uint256 endStakeLockerBPTBalance  = bpt.balanceOf(address(stakeLocker));
//         uint256 endPoolDelegateBPTBalance = bpt.balanceOf(address(poolDelegate));

//         assertEq(delegateBalance - losses, endPoolDelegateBPTBalance - initialPoolDelegateBPTBalance);
//         assertEq(delegateBalance - losses, initialStakeLockerBPTBalance - endStakeLockerBPTBalance);

//         assertEq(stakeLocker.balanceOf(poolDelegate), 0);
//     }

// }

// TODO: Compare LPs balances from the graph query with the on-chain query for each LP as well as the total pool V1 value.
// TODO: Utilize accounting checker
