// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IERC20Like,
    IGlobals,
    ILoanManagerLike,
    IPool,
    IPoolManager,
    IProxyFactoryLike,
    IWithdrawalManager
} from "../../contracts/interfaces/Interfaces.sol";

import { console, TestUtils } from "../../contracts/Contracts.sol";

import { AddressRegistry } from "./AddressRegistry.sol";

// TODO: Move each validation run() into a properly named function in './simulations/mainnet/Validations', so they can be called individually. Each run() here can call them too.
// TODO: Add and update error messages for all assertions (use sentence case).

contract ValidationBase is TestUtils, AddressRegistry {

    uint256 constant loansAddedTimestamp_mainnet  = 1670777148;
    uint256 constant lastUpdatedTimestamp_mainnet = 1670804207;

    modifier validationConfig() {
        console.log("Block Number: ", block.number);
        _;
        require(!failed);
    }

    address[] lps = [
        0x42d2a126C19577B82AfA6020Bd0D89fc48D8A94C,
        0x5ba9C24A7092886a31E474A9Ed0B1D672B3f8829,
        0x9323441091F39BE7F1F9331013eA245b04168e78,
        0xD321Ee41540822CcA0C136F651DB81C4AF303bEa,
        0xD56f06ff5FF1beEa43cFFFC227757F1E2Bae6126,
        0xD8aCA3Fd7ad5bfBb9f82a43E88A36f00a0E680b3
    ];

}

contract QueryLoanManagerState is ValidationBase {
    function run() external validationConfig {
        console.log("mavenPermissionedPool");
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
    function validate(address loanManager) internal view {
        if (loanManager == address(0)) return;

        console.log("issuanceRate: ", ILoanManagerLike(loanManager).issuanceRate());
        console.log("domainStart:  ", ILoanManagerLike(loanManager).domainStart());
        console.log("domainEnd:    ", ILoanManagerLike(loanManager).domainEnd());
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

    function query(address[] storage lps) internal view {
        for (uint256 i; i < lps.length; ++i) {
            if (lps[i].code.length > 0) {
                console.log(lps[i], lps[i].code.length);
            }
        }
    }
}

contract QueryPoolInfo is ValidationBase {

    function logPoolInfo(address pool) internal view {
        IPoolManager poolManager = IPoolManager(IPool(pool).manager());

        console.log("Name", IPool(pool).name());
        console.log("Pool", pool);
        console.log("PM  ", address(poolManager));
        console.log("LM  ", poolManager.loanManagerList(0));
        console.log("WM  ", poolManager.withdrawalManager());
        console.log("PC  ", poolManager.poolDelegateCover());
    }

}

contract QueryMavenPermPoolAddresses is QueryPoolInfo {

    function run() external view validationConfig {
        logPoolInfo(mavenPermissionedPool);
    }

}

contract QueryMavenUsdcPoolAddresses is QueryPoolInfo {

    function run() external view validationConfig {
        logPoolInfo(mavenUsdcPool);
    }

}

contract QueryMavenWethPoolAddresses is QueryPoolInfo {

    function run() external view validationConfig {
        logPoolInfo(mavenWethPool);
    }

}

contract QueryOrthogonalPoolAddresses is QueryPoolInfo {

    function run() external view validationConfig {
        logPoolInfo(orthogonalPool);
    }

}

contract QueryIcebreakerPoolAddresses is QueryPoolInfo {

    function run() external view validationConfig {
        logPoolInfo(icebreakerPool);
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
        IGlobals globals = IGlobals(mapleGlobalsV2Proxy);

        assertEq(globals.platformManagementFeeRate(poolManager),  managementFeeRate);
        assertEq(globals.platformServiceFeeRate(poolManager),     serviceFeeRate);
        assertEq(globals.platformOriginationFeeRate(poolManager), originationFeeRate);
        assertEq(globals.maxCoverLiquidationPercent(poolManager), maxLiqPct);
    }

}

contract OpenPools is ValidationBase {

    function run() external validationConfig {
        validate(mavenUsdcPoolManager);
        validate(mavenWethPoolManager);
        validate(orthogonalPoolManager);
    }

    function validate(address poolManager) internal {
        assertTrue(IPoolManager(poolManager).openToPublic(), "pool not open to public");
    }

}

contract PermissionPools is ValidationBase {

    function run() external validationConfig {
        validate(mavenPermissionedPoolManager, mavenPermissionedLps);
        validate(icebreakerPoolManager,        icebreakerLps);
    }

    function validate(address poolManager, address[] storage lps) internal {
        IPoolManager poolManager_ = IPoolManager(poolManager);

        assertTrue(!poolManager_.openToPublic(), "pool open to public");

        for (uint256 i; i < lps.length; ++i) {
            assertTrue(poolManager_.isValidLender(lps[i]));
        }

        assertTrue(poolManager_.isValidLender(poolManager_.withdrawalManager()));
    }

}

contract ValidateDefaultVersionsAreSet is ValidationBase {

    function run() external {
        assertEq(IProxyFactoryLike(loanFactory).defaultVersion(),        400);
        assertEq(IProxyFactoryLike(loanManagerFactory).defaultVersion(), 200);
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
                IPoolManager(poolManager).asset()
            ).balanceOf(
                IPoolManager(poolManager).poolDelegateCover()
            ),
            amount
        );
    }

}

contract QueryWindowEnds is ValidationBase {

    function run() external view validationConfig {
        ( uint256 windowStart, uint256 windowEnd ) = IWithdrawalManager(mavenPermissionedWithdrawalManager).getWindowAtId(1);
        console.log("Maven Perm Cycle 1 - start: %s, end: %s", windowStart, windowEnd);

        ( windowStart, windowEnd ) = IWithdrawalManager(mavenPermissionedWithdrawalManager).getWindowAtId(2);
        console.log("Maven Perm Cycle 2 - start: %s, end: %s", windowStart, windowEnd);

        ( windowStart, windowEnd ) = IWithdrawalManager(mavenPermissionedWithdrawalManager).getWindowAtId(3);
        console.log("Maven Perm Cycle 3 - start: %s, end: %s", windowStart, windowEnd);

        console.log("");

        ( windowStart, windowEnd ) = IWithdrawalManager(mavenUsdcWithdrawalManager).getWindowAtId(1);
        console.log("Maven Usdc Cycle 1 - start: %s, end: %s", windowStart, windowEnd);

        ( windowStart, windowEnd ) = IWithdrawalManager(mavenUsdcWithdrawalManager).getWindowAtId(2);
        console.log("Maven Usdc Cycle 2 - start: %s, end: %s", windowStart, windowEnd);

        ( windowStart, windowEnd ) = IWithdrawalManager(mavenUsdcWithdrawalManager).getWindowAtId(3);
        console.log("Maven Usdc Cycle 3 - start: %s, end: %s", windowStart, windowEnd);

        console.log("");

        ( windowStart, windowEnd ) = IWithdrawalManager(mavenWethWithdrawalManager).getWindowAtId(1);
        console.log("Maven Weth Cycle 1 - start: %s, end: %s", windowStart, windowEnd);

        ( windowStart, windowEnd ) = IWithdrawalManager(mavenWethWithdrawalManager).getWindowAtId(2);
        console.log("Maven Weth Cycle 2 - start: %s, end: %s", windowStart, windowEnd);

        ( windowStart, windowEnd ) = IWithdrawalManager(mavenWethWithdrawalManager).getWindowAtId(3);
        console.log("Maven Weth Cycle 3 - start: %s, end: %s", windowStart, windowEnd);
    }

}
