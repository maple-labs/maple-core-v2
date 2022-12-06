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

        // assertEq(hash(address(mapleGlobalsV2Implementation).code), 0);
        // assertEq(hash(address(mapleGlobalsV2Proxy).code),          0);

        assertEq(mapleGlobalsV2Proxy.admin(),          deployer);
        assertEq(mapleGlobalsV2Proxy.implementation(), mapleGlobalsV2Implementation);

        // // Step 2: Deploy FeeManager
        // require(hash(address(feeManager).code) == 0xba9931fd98fcf13e2ae2d1d8c94bf4d3f99f9c41444caf50adec02a02a34b383);

        assertEq(feeManager.globals(), address(mapleGlobalsV2Proxy));

        // // Step 3: Deploy Loan contracts
        // require(hash(address(loanV302Implementation).code) == 0xc526afbf4b792ad95c30128d640a6dae29c0bfb0b6b0674baa135701554b3bc8);
        // require(hash(address(loanV400Initializer).code)    == 0xf7d8ef4874396425b88f486351ad93e8a06a193c51bd718b0718e4a5deff49b8);
        // require(hash(address(loanV400Implementation).code) == 0x797f19d08098cf6ca5051692cf2b073682dae6ef83a361477e86fa949534090f);
        // require(hash(address(loanV401Implementation).code) == 0xa424f4b71909b5042fb7e23137e4cc91f0e33a9f62bc2dec0dc037a6ae0785c4);
        // require(hash(address(loanV400Migrator).code)       == 0xcb89d7d5948b60ff5caa3724753fc375d1af62f14a38e13cfb35e772b25d7235);

        // // Step 4: Deploy DebtLocker contracts
        // require(hash(address(debtLockerV400Implementation).code) == 0x8758bf19e2d5b77c009a098e2dad73a58969878b9c2a88099d49f7a3ae16564c);
        // require(hash(address(debtLockerV400Migrator).code)       == 0x6cb68800cd4fe71531c292ace7ed3f948cf61b842e8348aec12949902304dcda);

        // // Step 5: Deploy PoolDeployer
        // require(hash(address(poolDeployer).code) == 0x80ca5753d81f8ba0b0139db619eb9d5062d442b503c43b273895ec9611d8f836);
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

        // // Step 11: Deploy factories
        // require(hash(address(liquidatorFactory).code)        == 0x433ce0af096b3c31c8c58199fdbf61b31b3349ab814c93357796abf19541afa3);
        // require(hash(address(loanManagerFactory).code)       == 0x5186459623fa2a11ac7ef2b67ecc5422ae89db285f52067f5c184c296980a710);
        // require(hash(address(poolManagerFactory).code)       == 0xbccd77d181035dd68ac7d2cccec92fd2255d92caed710b808da68319d3671b48);
        // require(hash(address(withdrawalManagerFactory).code) == 0x511c9e987be73335e8e1a731de673425b8e604b499f34153beea696f22f7c820);

        // Step 12: Add factories to Globals
        assertTrue(mapleGlobalsV2Proxy.isFactory("LIQUIDATOR",         address(liquidatorFactory)));
        assertTrue(mapleGlobalsV2Proxy.isFactory("LOAN",               address(loanFactory)));
        assertTrue(mapleGlobalsV2Proxy.isFactory("LOAN_MANAGER",       address(loanManagerFactory)));
        assertTrue(mapleGlobalsV2Proxy.isFactory("POOL_MANAGER",       address(poolManagerFactory)));
        assertTrue(mapleGlobalsV2Proxy.isFactory("WITHDRAWAL_MANAGER", address(withdrawalManagerFactory)));

        // // Step 13: Deploy implementations
        // require(hash(address(liquidatorImplementation).code)            == 0x99903ea508b26095b559a5c4fe47fa97c41f92a6aa6e40e8003a71bbb8055a02);
        // require(hash(address(loanManagerImplementation).code)           == 0xed07ea66d7e96b1533b9df97e5feaa1601c287e8571ee0b14d39e16dc0031340);
        // require(hash(address(poolManagerImplementation).code)           == 0x8f127c7c4c3a4d9feeb6f05daff9d7aab872f1d6a074e70095712a932615b67b);
        // require(hash(address(transitionLoanManagerImplementation).code) == 0x30267fd06310b45f57411ce9fc4956d6d084c20c7a0fd8a4c741bebcdd92a413);
        // require(hash(address(withdrawalManagerImplementation).code)     == 0xba1f7e2ed6282cc6019bd17a1bb7b652c680a7bf9a01ebfaeaa66dfab7347e23);

        // // Step 14: Deploy initializers
        // require(hash(address(liquidatorInitializer).code)        == 0xd41d6fb51c9272f9f454901da9c81c49627ed2272d6b5a3f4304247b9cdad4a6);
        // require(hash(address(loanManagerInitializer).code)       == 0xdbdf2a37fb0fb0462dba734855f48f6c6e8e8e78c8e76b4fa669dfb2ba52c900);
        // require(hash(address(poolManagerInitializer).code)       == 0x776f445dc1aad31345cb0a7fd8fe82caf86862658f0115bc7fa5267e64decb93);
        // require(hash(address(withdrawalManagerInitializer).code) == 0x757e74bb9b28dd9fa7be32d6c683965aee3aa252eb67491e7a0a510ab33d696e);

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

        // // Step 20: Deploy MigrationHelper and AccountingChecker
        // require(hash(address(accountingChecker).code)             == 0x631c02bf196ab7c425ac3cfe9e9cb9e18c28f851ce7ad1b37ae8a4613eeb4432);
        // require(hash(address(deactivationOracle).code)            == 0x56211ef942d9bc7d3bd6bf04ef92215b93325103f0bc865673fe7edfa60941ea);
        // require(hash(address(migrationHelperImplementation).code) == 0xccddff32ff633bd388be9ae1bc4e475bac316e37fa1d23e12a6079cafbec1705);
        // require(hash(address(migrationHelperProxy).code)          == 0x6de3ee7ca258dcd4e4e4510d50b85fc7b39adb97f614a483d1708cdd89f9389e);

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

        // TODO: Include validation of oracles after they are included in the deployment.
        // TODO: Include validation of refinancer after it's included in the deployment.
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

        assertEq(loanFactory.versionOf(loanV401Implementation), 401, "loan v401 implementation not set");
        assertEq(loanFactory.migratorForPath(401, 401), loanV400Initializer, "loan v401 initializer not set");

        assertEq(loanFactory.migratorForPath(301, 302), address(0), "loan v301 to v302 migrator is not zero");
        assertTrue(loanFactory.upgradeEnabledForPath(301, 302), "loan v301 to v302 upgrade disabled");

        assertEq(loanFactory.migratorForPath(302, 400), loanV400Migrator, "loan v302 to v400 migrator not set");
        assertTrue(loanFactory.upgradeEnabledForPath(302, 400), "loan v302 to v400 upgrade disabled");

        assertEq(loanFactory.migratorForPath(400, 401), address(0), "loan v400 to v401 migrator is not zero");
        assertTrue(loanFactory.upgradeEnabledForPath(400, 401), "loan v400 to v401 upgrade disabled");
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
