// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console } from "../../modules/contract-test-utils/contracts/test.sol";

import { ILoanManager } from "../../modules/pool-v2/contracts/interfaces/ILoanManager.sol";

import { SimulationBase } from "./SimulationBase.sol";

import {
    IAccountingCheckerLike,
    IDebtLockerLike,
    IERC20Like,
    IFeeManagerLike,
    ILoanManagerLike,
    IMapleGlobalsV1Like,
    IMapleGlobalsV2Like,
    IMapleLoanLike,
    IMapleLoanV4Like,
    IMapleProxyFactoryLike,
    IMigrationHelperLike,
    IPoolDeployerLike,
    IPoolManagerLike,
    IPoolV1Like,
    IPoolV2Like,
    IStakeLockerLike
} from "./Interfaces.sol";

// TODO: Move each validation run() into a properly named function in './simulations/mainnet/Validations', so they can be called individually. Each run() here can call them too.
// TODO: Add and update error messages for all assertions (use sentence case).

contract ValidationBase is SimulationBase {

    uint256 constant loansAddedTimestamp_mainnet  = 1670552693;
    uint256 constant lastUpdatedTimestamp_mainnet = 1670558420;

    modifier validationConfig() {
        console.log("Block Number: ", block.number);
        _;
        require(!failed);
    }

}

contract CheckSumOfLoansWithPrincipalOut is ValidationBase {

    function run() external validationConfig {
        checkSumOfLoanPrincipalForAllPools();
    }

}

contract CheckSumOfLpsToTotalSupply is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedPoolV1, mavenPermissionedLps);
        validate(mavenUsdcPoolV1,         mavenUsdcLps);
        validate(mavenWethPoolV1,         mavenWethLps);
        validate(orthogonalPoolV1,        orthogonalLps);
        validate(icebreakerPoolV1,        icebreakerLps);
    }

    function validate(address poolV1, address[] storage lps) internal {
        uint256 totalValue = getPoolV1TotalValue(poolV1);
        uint256 sumValue   = getSumPosition(poolV1, lps);

        assertWithinDiff(totalValue, sumValue, lps.length * 2);
    }
}

contract SetPoolAdmins is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedPoolV1);
        validate(mavenUsdcPoolV1);
        validate(mavenWethPoolV1);
        validate(orthogonalPoolV1);
        validate(icebreakerPoolV1);
    }

    function validate(address poolV1) internal {
        assertTrue(IPoolV1Like(poolV1).poolAdmins(migrationMultisig), "poolAdmins != migrationMultisig");
    }

}

contract SetInvestorAndTreasuryFee is ValidationBase {

    function run() external validationConfig {
        assertEq(IMapleGlobalsV1Like(mapleGlobalsV1).investorFee(), 0, "investorFee != 0");
        assertEq(IMapleGlobalsV1Like(mapleGlobalsV1).treasuryFee(), 0, "treasuryFee != 0");
    }

}

contract PayAndClaimUpcomingLoans is ValidationBase {

    uint256 constant END_MIGRATION = 1671026400;  // Dec 14, 2022

    function run() external validationConfig {
        validate(mavenPermissionedLoans);
        validate(mavenUsdcLoans);
        validate(mavenWethLoans);
        validate(orthogonalLoans);
        validate(icebreakerLoans);
    }

    function validate(address[] storage loans) internal {
        if (loans.length == 0) return;

        for (uint256 i; i < loans.length; ++i) {
            assertTrue(IMapleLoanLike(loans[i]).nextPaymentDueDate() > END_MIGRATION);
        }
    }

}

contract RemoveMaturedLoans is ValidationBase {

    function run() external view validationConfig {
        validate(mavenPermissionedLoans);
        validate(mavenUsdcLoans);
        validate(mavenWethLoans);
        validate(orthogonalLoans);
        validate(icebreakerLoans);
    }

    function validate(address[] storage loans) internal view {
        for (uint256 i; i < loans.length; ++i) {
            if (IMapleLoanLike(loans[i]).nextPaymentDueDate() != 0) continue;

            console.log("Matured loan: ", loans[i]);
        }
    }

}

contract UpgradeLoansToV301 is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedLoans);
        validate(mavenUsdcLoans);
        validate(mavenWethLoans);
        validate(orthogonalLoans);
        validate(icebreakerLoans);
    }

    function validate(address[] storage loans) internal {
        for (uint256 i; i < loans.length; ++i) {
            console.log("loan    ", loans[i]);
            assertVersion(301, loans[i]);
        }
    }

}

contract DeployProtocol is ValidationBase {

    function run() external validationConfig {
        // Step 1: Deploy Globals
        assertEq(hash(mapleGlobalsV2Implementation.code), 0x7f8f00f34d98cb9159eb610be220ddf8831f949a680a1a9235a165b44c10f358);
        assertEq(hash(mapleGlobalsV2Proxy.code),          0x68ef8494eef4cbddfd9186d28f4152465fbe01c7c7ca23f7ad55258a056a63c6);

        IMapleGlobalsV2Like mapleGlobalsV2 = IMapleGlobalsV2Like(mapleGlobalsV2Proxy);

        assertEq(mapleGlobalsV2.admin(),          deployer);
        assertEq(mapleGlobalsV2.implementation(), mapleGlobalsV2Implementation);

        // Step 2: Deploy FeeManager
        assertEq(hash(feeManager.code), 0xeda0b8a07ec772cc345d84caaac0a95591b8dd090179f03dd427f40f0ed2d181);

        assertEq(IFeeManagerLike(feeManager).globals(), mapleGlobalsV2Proxy);

        // Step 3: Deploy Loan contracts
        assertEq(hash(loanV302Implementation.code), 0x0ef7cb3cb917189811b8415f495a75f29ee86da37b3d11f9ebd016b1d91d2f91);
        assertEq(hash(loanV400Initializer.code),    0x46ccdebd96ffac13c7f0b8de92a685dbdc5f75ead38ebd9ea0cfa3b45f7a0476);
        assertEq(hash(loanV400Implementation.code), 0x3a4d877fc6684f8ecca69ddd8516a91f1e71364e7d25e5a832127e81bb7d13cc);
        assertEq(hash(loanV400Migrator.code),       0x2ee0a69cf65afd91fd8ecf359882f7092230b488abd5ea0f0f0ac1babdcca17e);

        // Step 4: Deploy DebtLocker contracts
        assertEq(hash(debtLockerV400Implementation.code), 0x2997c917c29bc186e6623f04809af7193ebccb9a5fb9c026911e255fb3177023);
        assertEq(hash(debtLockerV400Migrator.code),       0x52f85e9d6dd6f16069d227279bdfa32c92fe9042f6249399d3e9b23adae4831e);

        // // Step 5: Deploy PoolDeployer
        assertEq(hash(poolDeployer.code), 0x5d1673eb250e69d9e9626f1174d94302f2d79982fb4a91a2f95d20b6cd372e58);

        assertEq(IPoolDeployerLike(poolDeployer).globals(), mapleGlobalsV2Proxy);

        // Step 6: Set addresses in GlobalsV2
        assertEq(mapleGlobalsV2.mapleTreasury(), mapleTreasury);
        assertEq(mapleGlobalsV2.securityAdmin(), securityAdmin);

        // Step 7: Set valid PoolDeployer
        assertTrue(mapleGlobalsV2.isPoolDeployer(poolDeployer));

        // Step 8: Allowlist assets
        assertTrue(mapleGlobalsV2.isPoolAsset(usdc));
        assertTrue(mapleGlobalsV2.isPoolAsset(weth));

        assertTrue(mapleGlobalsV2.isCollateralAsset(wbtc));

        // Step 9: Set bootstrap mint amounts
        assertEq(mapleGlobalsV2.bootstrapMint(usdc), 0.100000e6);
        assertEq(mapleGlobalsV2.bootstrapMint(weth), 0.0001e18);

        // Step 10: Set timelock parameters
        ( uint256 delay, uint256 duration ) = mapleGlobalsV2.defaultTimelockParameters();

        assertEq(delay,    1 weeks);
        assertEq(duration, 2 days);

        // Step 11: Deploy factories
        assertEq(hash(liquidatorFactory.code),        0xdcb011ff44326687db40bf89317617d8d1bfa719792167c348f7cc18869ea00a);
        assertEq(hash(loanManagerFactory.code),       0xdbb33075e0c7b40708d91da2ff0b8079b3b10dbf7b1b4ed7ea361be9820853c9);
        assertEq(hash(poolManagerFactory.code),       0xcce0f3de8b59f96e8a8c3e2e2ef62c98471e9da7d3b3e7b67a797a7330683af5);
        assertEq(hash(withdrawalManagerFactory.code), 0x39c7708bb3c15bc3937ae195ff1165e48fea959884328267ceb05ff779c42cbb);

        // Step 12: Add factories to Globals
        assertTrue(mapleGlobalsV2.isFactory("LIQUIDATOR",         liquidatorFactory));
        assertTrue(mapleGlobalsV2.isFactory("LOAN",               loanFactory));
        assertTrue(mapleGlobalsV2.isFactory("LOAN_MANAGER",       loanManagerFactory));
        assertTrue(mapleGlobalsV2.isFactory("POOL_MANAGER",       poolManagerFactory));
        assertTrue(mapleGlobalsV2.isFactory("WITHDRAWAL_MANAGER", withdrawalManagerFactory));

        // Step 13: Deploy implementations
        assertEq(hash(liquidatorImplementation.code),            0x2228119726f9db19c9fb746b16eff3b4014e7bdf60cc8f69ae9065e53073fa2c);
        assertEq(hash(loanManagerImplementation.code),           0x9049add2e5987fea245b694a2d1df8e54cc10226fa24f653ec933bf20f824224);
        assertEq(hash(poolManagerImplementation.code),           0xc305580ec768baa5f8bb063a3c962f1a7b518dc2ad8f59ec2ea6511f23e4082b);
        assertEq(hash(transitionLoanManagerImplementation.code), 0x99705e3583d4cdc51a0239a438cba8fea7b983b0db05deac1f6427ec034fefc7);
        assertEq(hash(withdrawalManagerImplementation.code),     0x73cacd589ed3a3b1c983dfec5de3cd4b44aec9850c2bb7f770e32fdc7cac1ae7);

        // Step 14: Deploy initializers
        assertEq(hash(liquidatorInitializer.code),        0xc79fbf65c93e10e0a85a415bc04aba7f7bb8f652380577662a6587fa0a6c82be);
        assertEq(hash(loanManagerInitializer.code),       0x8d983de33cbf96ca54e9a564e0a96ef46a29da300720998c7529eb9a2c58049a);
        assertEq(hash(poolManagerInitializer.code),       0x5cd8109a2339d5543ed65425029d620a927df3c13b9652ed69520d6313d2eb93);
        assertEq(hash(withdrawalManagerInitializer.code), 0xd28a2368f9fa100442ee9fd209035721180c2c75e1ca0244f5c1a5d013f28313);

        // Step 15: Configure LiquidatorFactory
        assertEq(IMapleProxyFactoryLike(liquidatorFactory).versionOf(liquidatorImplementation), 200);
        assertEq(IMapleProxyFactoryLike(liquidatorFactory).migratorForPath(200, 200), liquidatorInitializer);

        assertEq(IMapleProxyFactoryLike(liquidatorFactory).defaultVersion(), 200);

        // Step 16: Configure LoanManagerFactory
        IMapleProxyFactoryLike loanManagerFactory_ = IMapleProxyFactoryLike(loanManagerFactory);

        assertEq(loanManagerFactory_.versionOf(transitionLoanManagerImplementation), 100);
        assertEq(loanManagerFactory_.migratorForPath(100, 100), loanManagerInitializer);

        assertEq(loanManagerFactory_.versionOf(loanManagerImplementation), 200);
        assertEq(loanManagerFactory_.migratorForPath(200, 200), loanManagerInitializer);

        assertEq(loanManagerFactory_.migratorForPath(100, 200), address(0));
        assertTrue(loanManagerFactory_.upgradeEnabledForPath(100, 200));

        assertEq(loanManagerFactory_.defaultVersion(), 100);

        // Step 17: Configure PoolManagerFactory
        assertEq(IMapleProxyFactoryLike(poolManagerFactory).versionOf(poolManagerImplementation), 100);
        assertEq(IMapleProxyFactoryLike(poolManagerFactory).migratorForPath(100, 100), poolManagerInitializer);

        assertEq(IMapleProxyFactoryLike(poolManagerFactory).defaultVersion(), 100);

        // Step 18: Configure WithdrawalManagerFactory
        assertEq(IMapleProxyFactoryLike(withdrawalManagerFactory).versionOf(withdrawalManagerImplementation), 100);
        assertEq(IMapleProxyFactoryLike(withdrawalManagerFactory).migratorForPath(100, 100), withdrawalManagerInitializer);

        assertEq(IMapleProxyFactoryLike(withdrawalManagerFactory).defaultVersion(), 100);

        // Step 19: Allowlist Temporary Pool Delegate Multisigs
        assertTrue(mapleGlobalsV2.isPoolDelegate(icebreakerTemporaryPd));
        assertTrue(mapleGlobalsV2.isPoolDelegate(mavenPermissionedTemporaryPd));
        assertTrue(mapleGlobalsV2.isPoolDelegate(mavenUsdcTemporaryPd));
        assertTrue(mapleGlobalsV2.isPoolDelegate(mavenWethTemporaryPd));
        assertTrue(mapleGlobalsV2.isPoolDelegate(orthogonalTemporaryPd));

        // Step 20: Deploy MigrationHelper and AccountingChecker
        assertEq(hash(accountingChecker.code),             0xe45c193af3ed73882badc9b2adb464e88cb6a8c389651d9036a45360f51df841);
        assertEq(hash(deactivationOracle.code),            0xe44025c6c2dd15f6c3877ea5d5e5a2629597056f4042b3c9dda3728ff8547e72);
        assertEq(hash(migrationHelperImplementation.code), 0x8c38c3346296f6193ea7033fb2df2b6aada2d69dea50aadc30474b7323942cd8);
        assertEq(hash(migrationHelperProxy.code),          0xe01426b1af69fc6df8bcae5d9da313c2bb16b54b4ba70d7907406e242b072b75);

        assertEq(IAccountingCheckerLike(accountingChecker).globals(), mapleGlobalsV2Proxy);

        assertEq(IMigrationHelperLike(migrationHelperProxy).admin(),          deployer);
        assertEq(IMigrationHelperLike(migrationHelperProxy).implementation(), migrationHelperImplementation);

        // Step 21: Configure MigrationHelper
        assertEq(IMigrationHelperLike(migrationHelperProxy).pendingAdmin(), migrationMultisig);
        assertEq(IMigrationHelperLike(migrationHelperProxy).globalsV2(),    mapleGlobalsV2Proxy);

        // Step 22: Set the MigrationHelper in Globals
        assertEq(mapleGlobalsV2.migrationAdmin(), migrationHelperProxy);

        // Step 23: Transfer governor
        assertEq(mapleGlobalsV2.pendingGovernor(), tempGovernor);

        // Step 24: Check refinancer bytecode hash
        assertEq(hash(refinancer.code), 0x0bb294e63bd6018fa9b2465c6e7ecc9cef967bb91d5cb36d5f3882ebe08486ee);

    }

    function hash(bytes memory code) internal pure returns (bytes32 bytecodeHash) {
        bytecodeHash = keccak256(abi.encode(code));
    }

}

contract SetTemporaryGovernor is ValidationBase {

    function run() external validationConfig {
        assertEq(IMapleGlobalsV2Like(mapleGlobalsV2Proxy).pendingGovernor(), address(0),   "pendingGovernor != zero");
        assertEq(IMapleGlobalsV2Like(mapleGlobalsV2Proxy).governor(),        tempGovernor, "governor != tempGovernor");
    }

}

contract SetMigrationMultisig is ValidationBase {

    function run() external validationConfig {
        assertEq(IMigrationHelperLike(migrationHelperProxy).pendingAdmin(), address(0),        "pendingAdmin != zero");
        assertEq(IMigrationHelperLike(migrationHelperProxy).admin(),        migrationMultisig, "admin != migrationMultisig");
    }

}

contract RegisterDebtLockers is ValidationBase {

    function run() external validationConfig {
        assertEq(IMapleProxyFactoryLike(debtLockerFactory).versionOf(debtLockerV400Implementation), 400,         "debt locker v400 implementation not set");
        assertEq(IMapleProxyFactoryLike(debtLockerFactory).migratorForPath(400, 400), debtLockerV300Initializer, "debt locker v400 initializer not set");

        assertEq(IMapleProxyFactoryLike(debtLockerFactory).migratorForPath(300, 400), debtLockerV400Migrator, "debt locker v300 to v400 migrator not set");
        assertTrue(IMapleProxyFactoryLike(debtLockerFactory).upgradeEnabledForPath(300, 400),                 "debt locker v300 to v400 upgrade disabled");
    }

}

contract RegisterLoans is ValidationBase {

    function run() external validationConfig {
        assertEq(IMapleProxyFactoryLike(loanFactory).versionOf(loanV302Implementation), 302,         "loan v302 implementation not set");
        assertEq(IMapleProxyFactoryLike(loanFactory).migratorForPath(302, 302), loanV300Initializer, "loan v302 initializer not set");

        assertEq(IMapleProxyFactoryLike(loanFactory).versionOf(loanV400Implementation), 400,         "loan v400 implementation not set");
        assertEq(IMapleProxyFactoryLike(loanFactory).migratorForPath(400, 400), loanV400Initializer, "loan v400 initializer not set");

        assertEq(IMapleProxyFactoryLike(loanFactory).migratorForPath(301, 302), address(0), "loan v301 to v302 migrator is not zero");
        assertTrue(IMapleProxyFactoryLike(loanFactory).upgradeEnabledForPath(301, 302),     "loan v301 to v302 upgrade disabled");

        assertEq(IMapleProxyFactoryLike(loanFactory).migratorForPath(302, 400), loanV400Migrator, "loan v302 to v400 migrator not set");
        assertTrue(IMapleProxyFactoryLike(loanFactory).upgradeEnabledForPath(302, 400),           "loan v302 to v400 upgrade disabled");
    }

}

contract UpgradeDebtLockersToV400 is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedLoans);
        validate(mavenUsdcLoans);
        validate(mavenWethLoans);
        validate(orthogonalLoans);
        validate(icebreakerLoans);
    }

    function validate(address[] storage loans) internal {
        for (uint256 i; i < loans.length; ++i) {
            address debtLocker = IMapleLoanLike(loans[i]).lender();

            assertVersion(400, debtLocker);

            assertEq(IDebtLockerLike(debtLocker).loanMigrator(), migrationHelperProxy);
        }
    }

}

contract ClaimAllLoans is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedLoans);
        validate(mavenUsdcLoans);
        validate(mavenWethLoans);
        validate(orthogonalLoans);
        validate(icebreakerLoans);
    }

    function validate(address[] storage loans) internal {
        for (uint256 i; i < loans.length; i++) {
            IMapleLoanLike loan = IMapleLoanLike(loans[i]);

            assertEq(loan.claimableFunds(), 0);

            IERC20Like asset = IERC20Like(loan.fundsAsset());
            address debtLocker = loan.lender();

            assertEq(asset.balanceOf(address(loan)), 0);
            assertEq(asset.balanceOf(debtLocker),    0);
        }
    }

}

contract UpgradeLoansToV302 is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedLoans);
        validate(mavenUsdcLoans);
        validate(mavenWethLoans);
        validate(orthogonalLoans);
        validate(icebreakerLoans);
    }

    function validate(address[] storage loans) internal {
        for (uint256 i; i < loans.length; ++i) {
            assertVersion(302, loans[i]);
        }
    }

}

contract SetLiquidityCapsToZero is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedPoolV1);
        validate(mavenUsdcPoolV1);
        validate(mavenWethPoolV1);
        validate(orthogonalPoolV1);
        validate(icebreakerPoolV1);
    }

    function validate(address poolV1) internal {
        assertEq(IPoolV1Like(poolV1).liquidityCap(), 0);
    }

}

contract QueryLoanManagerState is ValidationBase {
    function run() external validationConfig {
        console.log("mavenPermissionedPoolV2");
        validate(mavenPermissionedLoanManager);

        console.log("");
        console.log("mavenUsdcLoanManager");
        validate(mavenUsdcLoanManager);

        console.log("");
        console.log("mavenWethLoanManager");
        validate(mavenWethLoanManager);

        console.log("");
        console.log("orthogonalLoanManager");
        validate(orthogonalLoanManager);

        console.log("");
        console.log("icebreakerLoanManager");
        validate(icebreakerLoanManager);
    }

    // Write a function to get the issuanceRate, domainStart and domainEnd for each LoanManager
    function validate(address loanManager) internal {
        if (loanManager == address(0)) return;

        console.log("issuanceRate: ", ILoanManager(loanManager).issuanceRate());
        console.log("domainStart:  ", ILoanManager(loanManager).domainStart());
        console.log("domainEnd:    ", ILoanManager(loanManager).domainEnd());
    }

}

contract QueryLiquidityLockers is ValidationBase {

    function run() external view validationConfig {
        console.log("mavenPermissionedPoolV1");
        validate(mavenPermissionedPoolV1);

        console.log("");
        console.log("mavenUsdcPoolV1");
        validate(mavenUsdcPoolV1);

        console.log("");
        console.log("mavenWethPoolV1");
        validate(mavenWethPoolV1);

        console.log("");
        console.log("orthogonalPoolV1");
        validate(orthogonalPoolV1);

        console.log("");
        console.log("icebreakerPoolV1");
        validate(icebreakerPoolV1);
    }

    function validate(address poolV1) internal view {
        console.log(
            IERC20Like(
                IPoolV1Like(poolV1).liquidityAsset()
            ).balanceOf(
                IPoolV1Like(poolV1).liquidityLocker()
            )
        );
    }

}

contract QueryMigrationLoans is ValidationBase {

    function run() external view validationConfig {
        for (uint256 i; i < unorderedMigrationLoans.length; ++i) {
            console.log("");
            console.log("address           ", unorderedMigrationLoans[i]);
            console.log("principalRequested", IMapleLoanLike(unorderedMigrationLoans[i]).principalRequested());
            console.log("fundsAsset        ", IMapleLoanLike(unorderedMigrationLoans[i]).fundsAsset());
        }
    }

    function validate(address poolV1, address migrationLoan, uint256 principalRequested) internal {
        if (migrationLoan == address(0)) return;

        IERC20Like asset = IERC20Like(IPoolV1Like(poolV1).liquidityAsset());

        assertEq(asset.balanceOf(IPoolV1Like(poolV1).liquidityLocker()),          principalRequested);
        assertEq(IMapleLoanLike(migrationLoan).principalRequested(), principalRequested);
    }

}

// NOTE: Don't forget to include the migration loan in all further loan checks.
contract CreateMigrationLoans is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedPoolV1, mavenPermissionedMigrationLoan, 8_765_965.068493e6);
        validate(mavenUsdcPoolV1,         mavenUsdcMigrationLoan,         1.246150e6);
        validate(mavenWethPoolV1,         mavenWethMigrationLoan,         1_399.613706431366646518e18);
        validate(orthogonalPoolV1,        orthogonalMigrationLoan,        17_008_319.288392e6);
        validate(icebreakerPoolV1,        icebreakerMigrationLoan,        5_649_999.999995e6);
    }

    function validate(address poolV1, address migrationLoan, uint256 principalRequested) internal {
        if (migrationLoan == address(0)) return;

        IERC20Like asset = IERC20Like(IPoolV1Like(poolV1).liquidityAsset());

        assertEq(asset.balanceOf(IPoolV1Like(poolV1).liquidityLocker()), principalRequested);
        assertEq(IMapleLoanLike(migrationLoan).principalRequested(),     principalRequested);
    }

}

abstract contract FundMigrationLoans is ValidationBase {

    function validate(address poolV1, address migrationLoan, uint256 funds) internal {
        if (migrationLoan == address(0)) return;

        IERC20Like asset = IERC20Like(IMapleLoanLike(migrationLoan).fundsAsset());

        assertEq(IMapleLoanLike(migrationLoan).drawableFunds(), funds);

        assertEq(asset.balanceOf(migrationLoan),                         funds);
        assertEq(asset.balanceOf(IPoolV1Like(poolV1).liquidityLocker()), 0);
    }

}

contract FundMigrationLoansMavenPermissioned is FundMigrationLoans {

    function run() external validationConfig {
        validate(mavenPermissionedPoolV1, mavenPermissionedMigrationLoan, 8_765_965.068493e6);
    }

}

contract FundMigrationLoansMavenUsdc is FundMigrationLoans {

    function run() external validationConfig {
        validate(mavenUsdcPoolV1, mavenUsdcMigrationLoan, 1.246150e6);
    }

}

contract FundMigrationLoansMavenWeth is FundMigrationLoans {

    function run() external validationConfig {
        validate(mavenWethPoolV1, mavenWethMigrationLoan, 1399.613706431366646518e18);
    }

}

contract FundMigrationLoansOrthogonal is FundMigrationLoans {

    function run() external validationConfig {
        validate(orthogonalPoolV1, orthogonalMigrationLoan, 17_008_319.288392e6);
    }

}

contract FundMigrationLoansIcebreaker is FundMigrationLoans {

    function run() external validationConfig {
        validate(icebreakerPoolV1, icebreakerMigrationLoan, 5_649_999.999995e6);
    }

}

contract UpgradeMigrationLoansTo302 is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedMigrationLoan);
        validate(mavenUsdcMigrationLoan);
        validate(mavenWethMigrationLoan);
        validate(orthogonalMigrationLoan);
        validate(icebreakerMigrationLoan);
    }

    function validate(address migrationLoan) internal {
        if (migrationLoan == address(0)) return;

        assertVersion(302, migrationLoan);
    }

}

contract UpgradeMigrationDebtLockers is ValidationBase {

    function validate(address migrationLoan) internal {
        if (migrationLoan == address(0)) return;

        address debtLocker = IMapleLoanLike(migrationLoan).lender();

        assertVersion(400, debtLocker);

        assertEq(IDebtLockerLike(debtLocker).loanMigrator(), migrationHelperProxy);
    }

}

contract UpgradeMigrationDebtLockersMavenPermissioned is UpgradeMigrationDebtLockers {

    function run() external validationConfig {
        validate(mavenPermissionedMigrationLoan);
    }

}

contract UpgradeMigrationDebtLockersMavenUsdc is UpgradeMigrationDebtLockers {

    function run() external validationConfig {
        validate(mavenUsdcMigrationLoan);
    }

}

contract UpgradeMigrationDebtLockersMavenWeth is UpgradeMigrationDebtLockers {

    function run() external validationConfig {
        validate(mavenWethMigrationLoan);
    }

}

contract UpgradeMigrationDebtLockersOrthogonal is UpgradeMigrationDebtLockers {

    function run() external validationConfig {
        validate(orthogonalMigrationLoan);
    }

}

contract UpgradeMigrationDebtLockersIcebreaker is UpgradeMigrationDebtLockers {

    function run() external validationConfig {
        validate(icebreakerMigrationLoan);
    }

}

contract PauseProtocol is ValidationBase {

    function run() external validationConfig {
        assertTrue(IMapleGlobalsV1Like(mapleGlobalsV1).protocolPaused());
    }

}

contract QueryLPsForContracts is ValidationBase {

    function run() external validationConfig {
        query(mavenPermissionedLps);
        query(mavenUsdcLps);
        query(mavenWethLps);
        query(orthogonalLps);
        query(icebreakerLps);
    }

    function query(address[] storage lps) internal {
        for (uint256 i = 0; i < lps.length; i++) {
            if (lps[i].code.length > 0) {
                console.log(lps[i], lps[i].code.length);
            }
        }
    }
}

abstract contract QueryPoolV1ValueBase is ValidationBase {

    function getPoolState(address poolV1, address[] storage lps) internal {
        IPoolV1Like poolV1_ = IPoolV1Like(poolV1);

        IERC20Like fundsAsset = IERC20Like(poolV1_.liquidityAsset());

        address liquidityLocker = poolV1_.liquidityLocker();

        uint256 cash = fundsAsset.balanceOf(liquidityLocker);

        console.log("cash + principalOut (LHS)");
        console.log("-------------------------");
        console.log("cash        ", cash);
        console.log("principalOut", poolV1_.principalOut());

        uint256 totalValue = getPoolV1TotalValue(poolV1);
        uint256 sumValue   = getSumPosition(poolV1, lps);

        console.log("");
        console.log("totalSupply + interestSum - poolLosses (RHS)");
        console.log("--------------------------------------------");
        console.log("INITIAL SUPPLY:", totalValue);

        console.log("");
        console.log("Sanity Check on LP Positions and Dust");
        console.log("-------------------------------------");
        console.log("Sum of LP Positions", sumValue);
        console.log("LP dust", totalValue - sumValue);

        bool dustAcceptable = totalValue - sumValue < lps.length * 2;
        bool zeroCash       = cash == 0;

        console.log("");
        console.log("Safety checks");
        console.log("-------------------------------------");
        console.log("Cash zero:      ", zeroCash);
        console.log("Dust acceptable:", dustAcceptable);
        console.log("LHS - RHS:      ", (cash + poolV1_.principalOut()) - totalValue);

        assertTrue(zeroCash && dustAcceptable);
    }

}

contract QueryPoolV1Value_AllPools is QueryPoolV1ValueBase {

    function run() external validationConfig {
        console.log("\n\n");
        console.log("***************");
        console.log("Maven Permissioned Pool");
        console.log("***************");

        getPoolState(mavenPermissionedPoolV1, mavenPermissionedLps);

        console.log("\n\n");
        console.log("***************");
        console.log("Maven USDC Pool");
        console.log("***************");

        getPoolState(mavenUsdcPoolV1, mavenUsdcLps);

        console.log("\n\n");
        console.log("***************");
        console.log("Maven WETH Pool");
        console.log("***************");

        getPoolState(mavenWethPoolV1, mavenWethLps);

        console.log("\n\n");
        console.log("***************");
        console.log("Orthogonal Pool");
        console.log("***************");

        getPoolState(orthogonalPoolV1, orthogonalLps);

        console.log("\n\n");
        console.log("***************");
        console.log("Icebreaker Pool");
        console.log("***************");

        getPoolState(icebreakerPoolV1, icebreakerLps);
    }

}

contract QueryPoolV1Value_MavenPermissioned is QueryPoolV1ValueBase {

    function run() external validationConfig {
        getPoolState(mavenPermissionedPoolV1, mavenPermissionedLps);
    }

}

contract QueryPoolV1Value_MavenUsdc is QueryPoolV1ValueBase {

    function run() external validationConfig {
        getPoolState(mavenUsdcPoolV1, mavenUsdcLps);
    }

}

contract QueryPoolV1Value_MavenWeth is QueryPoolV1ValueBase {

    function run() external validationConfig {
        getPoolState(mavenWethPoolV1, mavenWethLps);
    }

}

contract QueryPoolV1Value_Orthogonal is QueryPoolV1ValueBase {

    function run() external validationConfig {
        getPoolState(orthogonalPoolV1, orthogonalLps);
    }

}

contract QueryPoolV1Value_Icebreaker is QueryPoolV1ValueBase {

    function run() external validationConfig {
        getPoolState(icebreakerPoolV1, icebreakerLps);
    }

}

contract QueryPoolV2Info is ValidationBase {

    function logPoolV2Info(address poolV2) internal view {
        IPoolManagerLike poolManager = IPoolManagerLike(IPoolV2Like(poolV2).manager());
        console.log("Name", IPoolV2Like(poolV2).name());
        console.log("Pool", poolV2);
        console.log("PM  ", address(poolManager));
        console.log("LM  ", poolManager.loanManagerList(0));
        console.log("WM  ", poolManager.withdrawalManager());
        console.log("PC  ", poolManager.poolDelegateCover());
    }

}

contract QueryMavenPermPoolV2Addresses is QueryPoolV2Info {

    function run() external view validationConfig {
        logPoolV2Info(mavenPermissionedPoolV2);
    }

}

contract QueryMavenUsdcPoolV2Addresses is QueryPoolV2Info {

    function run() external view validationConfig {
        logPoolV2Info(mavenUsdcPoolV2);
    }

}

contract QueryMavenWethPoolV2Addresses is QueryPoolV2Info {

    function run() external view validationConfig {
        logPoolV2Info(mavenWethPoolV2);
    }

}

contract QueryOrthogonalPoolV2Addresses is QueryPoolV2Info {

    function run() external view validationConfig {
        logPoolV2Info(orthogonalPoolV2);
    }

}

contract QueryIcebreakerPoolV2Addresses is QueryPoolV2Info {

    function run() external view validationConfig {
        logPoolV2Info(icebreakerPoolV2);
    }

}

abstract contract DeployPools is ValidationBase {

    struct PoolConfiguration {
        address poolDelegate;
        address asset;
        address pool;
        address loanManager;
        address poolDelegateCover;
        address withdrawalManager;
        uint256 delegateManagementFeeRate;
    }

    function validatePool(address poolV2, address poolV1, address poolManager_, address asset_) internal {
        // assertEq(hash(poolV2.code), 0);

        IPoolV2Like poolV2_ = IPoolV2Like(poolV2);

        // Pool Assertions
        assertEq(poolV2_.totalSupply(), getPoolV1TotalValue(poolV1));
        assertEq(poolV2_.asset(),       IPoolV1Like(poolV1).liquidityAsset());
        assertEq(poolV2_.asset(),       asset_);
        assertEq(poolV2_.manager(),     poolManager_);
    }

    function validatePoolManager(address poolManager, PoolConfiguration memory poolConfig) internal {
        IPoolManagerLike poolManager_ = IPoolManagerLike(poolManager);

        assertEq(poolManager_.poolDelegate(),              poolConfig.poolDelegate);
        assertEq(poolManager_.asset(),                     poolConfig.asset);
        assertEq(poolManager_.pool(),                      poolConfig.pool);
        assertEq(poolManager_.poolDelegateCover(),         poolConfig.poolDelegateCover);
        assertEq(poolManager_.withdrawalManager(),         poolConfig.withdrawalManager);
        assertEq(poolManager_.delegateManagementFeeRate(), poolConfig.delegateManagementFeeRate);

        assertEq(poolManager_.liquidityCap(), 0);

        assertTrue(poolManager_.configured());
        assertTrue(!poolManager_.active());
        assertTrue(!poolManager_.openToPublic());

        // Loan Manager
        assertTrue(poolManager_.isLoanManager(poolConfig.loanManager));
        assertEq(poolManager_.loanManagerList(0), poolConfig.loanManager);

        // Fixed Value
        assertEq(poolManager_.pendingPoolDelegate(), address(0));
    }

    function hash(bytes memory code) internal pure returns (bytes32 bytecodeHash) {
        bytecodeHash = keccak256(abi.encode(code));
    }

}

contract DeployPoolMavenPermissioned is DeployPools {

    function run() external validationConfig {
        // Maven Permissioned Pool
        validatePool(mavenPermissionedPoolV2, mavenPermissionedPoolV1, address(mavenPermissionedPoolManager), address(usdc));
        validatePoolManager(
            mavenPermissionedPoolManager,
                PoolConfiguration({
                poolDelegate:              address(mavenPermissionedTemporaryPd),
                asset:                     address(usdc),
                pool:                      address(mavenPermissionedPoolV2),
                loanManager:               address(mavenPermissionedLoanManager),
                poolDelegateCover:         address(mavenPermissionedPoolDelegateCover),
                withdrawalManager:         address(mavenPermissionedWithdrawalManager),
                delegateManagementFeeRate: 0.135e6
        }));

    }
}

contract DeployPoolMavenUsdc is DeployPools {

    function run() external validationConfig {

        // Maven Usdc Pool
        validatePool(mavenUsdcPoolV2, mavenUsdcPoolV1, address(mavenUsdcPoolManager), address(usdc));
        validatePoolManager(
                mavenUsdcPoolManager,
                PoolConfiguration({
                poolDelegate:              address(mavenUsdcTemporaryPd),
                asset:                     address(usdc),
                pool:                      address(mavenUsdcPoolV2),
                loanManager:               address(mavenUsdcLoanManager),
                poolDelegateCover:         address(mavenUsdcPoolDelegateCover),
                withdrawalManager:         address(mavenUsdcWithdrawalManager),
                delegateManagementFeeRate: 0.135e6
        }));
    }

}

contract DeployPoolMavenWeth is DeployPools {

    function run() external validationConfig {
        // Maven Weth Pool
        validatePool(mavenWethPoolV2, mavenWethPoolV1, address(mavenWethPoolManager), address(weth));
        validatePoolManager(
                mavenWethPoolManager,
                PoolConfiguration({
                poolDelegate:              address(mavenWethTemporaryPd),
                asset:                     address(weth),
                pool:                      address(mavenWethPoolV2),
                loanManager:               address(mavenWethLoanManager),
                poolDelegateCover:         address(mavenWethPoolDelegateCover),
                withdrawalManager:         address(mavenWethWithdrawalManager),
                delegateManagementFeeRate: 0.135e6
        }));
    }

}


contract DeployPoolOrthogonal is DeployPools {

    function run() external validationConfig {
        // Orthogonal Pool
        validatePool(orthogonalPoolV2, orthogonalPoolV1, address(orthogonalPoolManager), address(usdc));
        validatePoolManager(
                orthogonalPoolManager,
                PoolConfiguration({
                poolDelegate:              address(orthogonalTemporaryPd),
                asset:                     address(usdc),
                pool:                      address(orthogonalPoolV2),
                loanManager:               address(orthogonalLoanManager),
                poolDelegateCover:         address(orthogonalPoolDelegateCover),
                withdrawalManager:         address(orthogonalWithdrawalManager),
                delegateManagementFeeRate: 0
        }));

    }

}

contract DeployPoolIcebreaker is DeployPools {

    function run() external validationConfig {
        // Icebreaker
        validatePool(icebreakerPoolV2, icebreakerPoolV1, address(icebreakerPoolManager), address(usdc));
        validatePoolManager(
                icebreakerPoolManager,
                PoolConfiguration({
                poolDelegate:              address(icebreakerTemporaryPd),
                asset:                     address(usdc),
                pool:                      address(icebreakerPoolV2),
                loanManager:               address(icebreakerLoanManager),
                poolDelegateCover:         address(icebreakerPoolDelegateCover),
                withdrawalManager:         address(icebreakerWithdrawalManager),
                delegateManagementFeeRate: 0.2e6
        }));

    }

}

contract AssertPoolAccounting is ValidationBase {

    function run() external validationConfig {
        // mavenPermissionedLoans.push(mavenPermissionedMigrationLoan);
        // mavenUsdcLoans.push(mavenUsdcMigrationLoan);
        // mavenWethLoans.push(mavenWethMigrationLoan);
        // orthogonalLoans.push(orthogonalMigrationLoan);
        // icebreakerLoans.push(icebreakerMigrationLoan);

        loansAddedTimestamps[mavenPermissionedPoolManager] = loansAddedTimestamp_mainnet;
        loansAddedTimestamps[mavenUsdcPoolManager]         = loansAddedTimestamp_mainnet;
        loansAddedTimestamps[mavenWethPoolManager]         = loansAddedTimestamp_mainnet;
        loansAddedTimestamps[orthogonalPoolManager]        = loansAddedTimestamp_mainnet;
        loansAddedTimestamps[icebreakerPoolManager]        = loansAddedTimestamp_mainnet;

        lastUpdatedTimestamps[mavenPermissionedPoolManager] = lastUpdatedTimestamp_mainnet;
        lastUpdatedTimestamps[mavenUsdcPoolManager]         = lastUpdatedTimestamp_mainnet;
        lastUpdatedTimestamps[mavenWethPoolManager]         = lastUpdatedTimestamp_mainnet;
        lastUpdatedTimestamps[orthogonalPoolManager]        = lastUpdatedTimestamp_mainnet;
        lastUpdatedTimestamps[icebreakerPoolManager]        = lastUpdatedTimestamp_mainnet;

        assertAllPoolAccounting(1200);
    }

}

contract ConfigurePlatformFees is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedPoolManager, 2_5000, 6600, 0,    50_0000);
        validate(mavenUsdcPoolManager,         2_5000, 6600, 0,    100_0000);
        validate(mavenWethPoolManager,         2_5000, 6600, 0,    100_0000);
        validate(orthogonalPoolManager,        2_5000, 6600, 0,    50_0000);
        validate(icebreakerPoolManager,        0,      6600, 5000, 50_0000);

    }

    function validate(address poolManager, uint256 managementFeeRate, uint256 serviceFeeRate, uint256 originationFeeRate, uint256 maxLiqPct) internal {
        IMapleGlobalsV2Like globals = IMapleGlobalsV2Like(mapleGlobalsV2Proxy);

        assertEq(globals.platformManagementFeeRate(poolManager),  managementFeeRate);
        assertEq(globals.platformServiceFeeRate(poolManager),     serviceFeeRate);
        assertEq(globals.platformOriginationFeeRate(poolManager), originationFeeRate);
        assertEq(globals.maxCoverLiquidationPercent(poolManager), maxLiqPct);
    }

}

contract ActivatePools is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedPoolManager);
        validate(mavenUsdcPoolManager);
        validate(mavenWethPoolManager);
        validate(orthogonalPoolManager);
        validate(icebreakerPoolManager);
    }

    function validate(address poolManager) internal {
        assertTrue(IPoolManagerLike(poolManager).active(), "pool not active");
    }

}

contract GlobalsPoolManagerActivated is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedPoolManager);
        validate(mavenUsdcPoolManager);
        validate(mavenWethPoolManager);
        validate(orthogonalPoolManager);
        validate(icebreakerPoolManager);
    }

    function validate(address poolManager_) internal {
        IMapleGlobalsV2Like globals_ = IMapleGlobalsV2Like(mapleGlobalsV2Proxy);

        ( address ownedPoolManager, ) = globals_.poolDelegates(IPoolManagerLike(poolManager_).poolDelegate());

        assertEq(ownedPoolManager, poolManager_, "pool manager not activated");
    }

}

contract OpenPools is ValidationBase {

    function run() external validationConfig {
        validate(mavenUsdcPoolManager);
        validate(mavenWethPoolManager);
        validate(orthogonalPoolManager);
    }

    function validate(address poolManager) internal {
        assertTrue(IPoolManagerLike(poolManager).openToPublic(), "pool not open to public");
    }

}

contract PermissionPools is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedPoolManager, mavenPermissionedLps);
        validate(icebreakerPoolManager,        icebreakerLps);
    }

    function validate(address poolManager, address[] storage lps) internal {
        IPoolManagerLike poolManager_ = IPoolManagerLike(poolManager);

        assertTrue(!poolManager_.openToPublic(), "pool open to public");

        for (uint256 i = 0; i < lps.length; i++) {
            assertTrue(poolManager_.isValidLender(lps[i]));
        }

        assertTrue(poolManager_.isValidLender(poolManager_.withdrawalManager()));
    }

}

contract Airdrop is ValidationBase {

    function run() external validationConfig {
        console.log("mavenPermissionedPoolV1");
        validate(mavenPermissionedPoolV1, mavenPermissionedPoolV2, mavenPermissionedLps);

        console.log("mavenUsdcPoolV1");
        validate(mavenUsdcPoolV1,         mavenUsdcPoolV2,         mavenUsdcLps);

        console.log("mavenWethPoolV1");
        validate(mavenWethPoolV1,         mavenWethPoolV2,         mavenWethLps);

        console.log("orthogonalPoolV1");
        validate(orthogonalPoolV1,        orthogonalPoolV2,        orthogonalLps);

        console.log("icebreakerPoolV1");
        validate(icebreakerPoolV1,        icebreakerPoolV2,        icebreakerLps);
    }

    function validate(address poolV1, address poolV2, address[] storage lps) internal {
        uint256 poolV1TotalValue  = getPoolV1TotalValue(poolV1);
        uint256 poolV2TotalSupply = IPoolV2Like(poolV2).totalSupply();
        uint256 sumPosition       = getSumPosition(poolV1, lps);

        for (uint256 i; i < lps.length; ++i) {
            uint256 v1Position = getV1Position(poolV1, lps[i]);
            uint256 v2Position = IPoolV2Like(poolV2).balanceOf(lps[i]);

            if (lps[i] == 0xB2acd0214F87d217A2eF148aA4a5ABA71d3F7956) {
                v2Position = IPoolV2Like(poolV2).balanceOf(0x666B8EbFbF4D5f0CE56962a25635CfF563F13161);
            }

            if (i == 0) {
                v1Position += poolV1TotalValue - sumPosition;
            }

            uint256 v1Equity = v1Position * 1e18 / poolV1TotalValue;
            uint256 v2Equity = v2Position * 1e18 / poolV2TotalSupply;

            assertEq(v1Position, v2Position);
            assertEq(v1Equity,   v2Equity);
        }

        assertEq(IPoolV2Like(poolV2).balanceOf(migrationHelperProxy), 0);
    }

}

contract SetPendingLenders is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedLoans, mavenPermissionedLoanManager);
        validate(mavenUsdcLoans,         mavenUsdcLoanManager);
        validate(mavenWethLoans,         mavenWethLoanManager);
        validate(orthogonalLoans,        orthogonalLoanManager);
        validate(icebreakerLoans,        icebreakerLoanManager);
    }

    function validate(address[] storage loans, address tlm) internal {
        for (uint256 i; i < loans.length; ++i) {
            assertEq(IMapleLoanLike(loans[i]).pendingLender(), tlm, "pending lender != tlm");
            // TODO: Assert lender
        }
    }

}

contract AcceptPendingLenders is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedLoans, mavenPermissionedLoanManager);
        validate(mavenUsdcLoans,         mavenUsdcLoanManager);
        validate(mavenWethLoans,         mavenWethLoanManager);
        validate(orthogonalLoans,        orthogonalLoanManager);
        validate(icebreakerLoans,        icebreakerLoanManager);
    }

    function validate(address[] storage loans, address tlm) internal {
        for (uint256 i; i < loans.length; ++i) {
            assertEq(IMapleLoanLike(loans[i]).lender(),        tlm,        "lender != tlm");
            assertEq(IMapleLoanLike(loans[i]).pendingLender(), address(0), "pending lender != 0");
        }
    }

}

contract UpgradeTLM is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedLoanManager);
        validate(mavenUsdcLoanManager);
        validate(mavenWethLoanManager);
        validate(orthogonalLoanManager);
        validate(icebreakerLoanManager);
    }

    function validate(address tlm) internal {
        assertVersion(200, tlm);
    }

}

contract UpgradeLoansToV400 is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedLoans);
        validate(mavenUsdcLoans);
        validate(mavenWethLoans);
        validate(orthogonalLoans);
        validate(icebreakerLoans);
    }

    function validate(address[] storage loans) internal {
        for (uint256 i; i < loans.length; ++i) {
            assertVersion(400, loans[i]);
        }
    }

}

contract UpgradeMigrationLoansTo400 is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedMigrationLoan);
        validate(mavenUsdcMigrationLoan);
        validate(mavenWethMigrationLoan);
        validate(orthogonalMigrationLoan);
        validate(icebreakerMigrationLoan);
    }

    function validate(address migrationLoan) internal {
        if (migrationLoan == address(0)) return;

        assertVersion(400, migrationLoan);
    }

}

contract LoanFactoryNewGlobalsSet is ValidationBase {

    function run() external validationConfig {
        validate(loanFactory);
    }

    function validate(address loanFactory_) internal {
        assertEq(IMapleProxyFactoryLike(loanFactory_).mapleGlobals(), mapleGlobalsV2Proxy);
    }

}

contract QueryMigrationLoanFees is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedMigrationLoan);
        validate(mavenUsdcMigrationLoan);
        validate(mavenWethMigrationLoan);
        validate(orthogonalMigrationLoan);
        validate(icebreakerMigrationLoan);
    }

    function validate(address migrationLoan) internal {
        if (migrationLoan == address(0)) return;

        ( , , uint256[2] memory fees ) = IMapleLoanV4Like(migrationLoan).getNextPaymentDetailedBreakdown();

        console.log("Migration Loan: %s", migrationLoan);
        console.log("Delegate Fees:  %s", fees[0]);
        console.log("Platform Fees:  %s", fees[1]);
    }

}

contract CloseMigrationLoans is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedMigrationLoan);
        validate(mavenUsdcMigrationLoan);
        validate(mavenWethMigrationLoan);
        validate(orthogonalMigrationLoan);
        validate(icebreakerMigrationLoan);
    }

    function validate(address migrationLoan) internal {
        assertEq(IMapleLoanLike(migrationLoan).nextPaymentDueDate(), 0);
        assertEq(IMapleLoanLike(migrationLoan).paymentsRemaining(),  0);
    }

}

contract ConfirmPoolV2Cash is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedPoolV2, 8_765_965.068493e6);
        validate(mavenUsdcPoolV2,         1.246150e6);
        validate(mavenWethPoolV2,         1399.613706431366646518e18);
        validate(orthogonalPoolV2,        17_008_319.288392e6);
        validate(icebreakerPoolV2,        5_649_999.999995e6);
    }

    function validate(address pool_, uint256 cash) internal {
        address fundsAsset_ = IPoolV2Like(pool_).asset();

        assertEq(IERC20Like(fundsAsset_).balanceOf(pool_), cash);
    }

}

contract UpgradeLoansToV401 is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedLoans);
        validate(mavenUsdcLoans);
        validate(mavenWethLoans);
        validate(orthogonalLoans);
        validate(icebreakerLoans);
    }

    function validate(address[] storage loans) internal {
        for (uint256 i; i < loans.length; ++i) {
            assertVersion(401, loans[i]);
        }
    }

}

contract TransferPoolDelegates is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedPoolManager, mavenPermissionedFinalPd);
        validate(mavenUsdcPoolManager,         mavenUsdcFinalPd);
        validate(mavenWethPoolManager,         mavenWethFinalPd);
        validate(orthogonalPoolManager,        orthogonalFinalPd);
        validate(icebreakerPoolManager,        icebreakerFinalPd);
    }

    function validate(address poolManager, address finalPoolDelegate) internal {
        assertEq(IPoolManagerLike(poolManager).poolDelegate(), finalPoolDelegate);
    }

}

contract DeprecatePools is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedPoolV1);
        validate(mavenUsdcPoolV1);
        validate(mavenWethPoolV1);
        validate(orthogonalPoolV1);
        validate(icebreakerPoolV1);
    }

    function validate(address poolV1) internal {
        IPoolV1Like pool = IPoolV1Like(poolV1);

        // Initialized: 0, Finalized: 1, Deactivated: 2
        assertEq(pool.poolState(), 2);
    }

}

contract PriceOraclesSet is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedPoolV1);
        validate(mavenUsdcPoolV1);
        validate(mavenWethPoolV1);
        validate(orthogonalPoolV1);
        validate(icebreakerPoolV1);
    }

    function validate(address poolV1) internal {
        IPoolV1Like pool = IPoolV1Like(poolV1);

        address asset = pool.liquidityAsset();

        assertEq(IMapleGlobalsV1Like(mapleGlobalsV1).getLatestPrice(asset), 1e8);  // TODO: Is this always the returned value?
    }

}

contract StakeLockersCooldownSet is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedPoolV1);
        validate(mavenUsdcPoolV1);
        validate(mavenWethPoolV1);
        validate(orthogonalPoolV1);
        validate(icebreakerPoolV1);
    }

    function validate(address poolV1) internal {
        IPoolV1Like pool = IPoolV1Like(poolV1);

        IStakeLockerLike stakeLocker = IStakeLockerLike(pool.stakeLocker());

        assertEq(IMapleGlobalsV1Like(mapleGlobalsV1).stakerCooldownPeriod(), 0);
    }

}

// TODO: Add a subgraph query to fetch cover providers
contract WithdrawCover is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedStakeLocker, mavenPermissionedRewards, mavenPermissionedCoverProviders);
        validate(mavenUsdcStakeLocker,         mavenUsdcRewards,         mavenUsdcCoverProviders);
        validate(mavenWethStakeLocker,         mavenWethRewards,         mavenWethCoverProviders);
        validate(orthogonalStakeLocker,        orthogonalRewards,        orthogonalCoverProviders);
        validate(icebreakerStakeLocker,        icebreakerRewards,        icebreakerCoverProviders);
    }

    function validate(address stakeLocker, address rewards, address[] storage coverProviders) internal {
        // TODO
    }

}

contract DepositCover is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedPoolManager, 1_750_000e6);
        validate(mavenUsdcPoolManager,         1_000_000e6);
        validate(mavenWethPoolManager,         750e18);
        validate(orthogonalPoolManager,        2_500_000e6);
        validate(icebreakerPoolManager,        500_000e6);
    }

    function validate(address poolManager, uint256 amount) internal {
        assertEq(
            IERC20Like(
                IPoolManagerLike(poolManager).asset()
            ).balanceOf(
                IPoolManagerLike(poolManager).poolDelegateCover()
            ),
            amount
        );
    }

}

contract IncreaseLiquidityCaps is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedPoolManager, 100_000_000e6);
        validate(mavenUsdcPoolManager,         100_000_000e6);
        validate(mavenWethPoolManager,         100_000e18);
        validate(orthogonalPoolManager,        100_000_000e6);
        validate(icebreakerPoolManager,        100_000_000e6);
    }

    function validate(address poolManager, uint256 liquidityCap) internal {
        assertEq(IPoolManagerLike(poolManager).liquidityCap(), liquidityCap);
    }

}

contract UnpauseProtocol is ValidationBase {

    function run() external validationConfig {
        assertTrue(!IMapleGlobalsV1Like(mapleGlobalsV1).protocolPaused());
    }

}

// TODO: Add post migration validation

// contract RequestUnstakeValidationScript is SimulationBase {

//     function run() external validationConfig {
//         validate(mavenPermissionedStakeLocker, mavenPermissionedPoolV1.poolDelegate(), 1_622_400_000);
//         validate(mavenUsdcStakeLocker,         mavenUsdcPoolV1.poolDelegate(),         1_622_400_000);
//         validate(mavenWethStakeLocker,         mavenWethPoolV1.poolDelegate(),         1_622_400_000);
//         validate(orthogonalStakeLocker,        orthogonalPoolV1.poolDelegate(),        1_622_400_000);
//         validate(icebreakerStakeLocker,        icebreakerPoolV1.poolDelegate(),        1_622_400_000);
//     }

//     function validate(address stakeLocker, address poolDelegate, uint256 timestamp) internal {
//         assertEq(IStakeLockerLike(stakeLocker).unstakeCooldown(poolDelegate), timestamp);
//     }

// }

// contract ValidateDefaultVersionsAreSet is SimulationBase {

//     function run() external validationConfig {
//         // assertEq()
//     }

// }

// contract UnstakeDelegateCoverValidationScript is SimulationBase {

//     function run() external validationConfig {
//         validate(mavenWethStakeLocker,         mavenWethPoolV1.poolDelegate(),         125_049.87499e18,          0, 0, 0);
//         validate(mavenUsdcStakeLocker,         mavenUsdcPoolV1.poolDelegate(),         153.022e18,                0, 0, 0);
//         validate(mavenPermissionedStakeLocker, mavenPermissionedPoolV1.poolDelegate(), 16.319926286804447168e18,  0, 0, 0);
//         validate(orthogonalStakeLocker,        orthogonalPoolV1.poolDelegate(),        175.122243323160822654e18, 0, 0, 0);
//         validate(icebreakerStakeLocker,        icebreakerPoolV1.poolDelegate(),        104.254119288711119987e18, 0, 0, 0);
//     }

//     function validate(uint256 losses) internal {
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
