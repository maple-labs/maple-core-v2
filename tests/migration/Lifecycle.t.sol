// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IERC20,
    IFixedTermLoan,
    IFixedTermLoanManager,
    IGlobals,
    ILoanManagerLike,
    IPool,
    IPoolManager,
    IProxyFactoryLike,
    IWithdrawalManager
} from "../../contracts/interfaces/Interfaces.sol";

import { console } from "../../contracts/Contracts.sol";

import { UpgradeSimulation } from "./Upgrade.t.sol";

contract LifecycleSimulation is UpgradeSimulation {

    mapping(address => uint256) lpExitTimestamps;

    struct ExitTimestamp {
        address pool;
        uint256 timestamp;
    }

    function test_simpleLifecycle() external {
        performEntireMigration();
        payOffAllLoansWhenDue();

        exitFromAllPoolsWhenPossible();
        withdrawAllPoolCoverFromAllPools();

        assertAllPoolsAreEmpty();
    }

    /**************************************************************************************************************************************/
    /*** Lifecycle Functions                                                                                                            ***/
    /**************************************************************************************************************************************/

    function performEntireMigration() internal {
        _deployNewContracts();
        _upgradeGlobals();
        _setupFactories();
        _upgradeContracts();
        _addLoanManagers();

        // TODO: Whitelist the withdrawal managers for AQRU and Maven 03 on mainnet.
        vm.prank(IPoolManager(mavenUsdc3PoolManager).poolDelegate());
        IPoolManager(mavenUsdc3PoolManager).setAllowedLender(mavenUsdc3WithdrawalManager, true);

        vm.prank(IPoolManager(aqruPoolManager).poolDelegate());
        IPoolManager(aqruPoolManager).setAllowedLender(aqruWithdrawalManager, true);
    }

    function payOffAllLoansWhenDue() internal {
        address loan;

        while ((loan = getNextLoan()) != address(0)) {

            uint256 nextPaymentDueDate = IFixedTermLoan(loan).nextPaymentDueDate();

            if (nextPaymentDueDate > block.timestamp) vm.warp(nextPaymentDueDate);

            makePayment(loan);
        }
    }

    function exitFromAllPoolsWhenPossible() internal returns (uint256[][7] memory redeemedAmounts) {
        requestAllRedemptions(mavenPermissionedPool, mavenPermissionedLps);
        requestAllRedemptions(mavenUsdcPool,         mavenUsdcLps);
        requestAllRedemptions(mavenWethPool,         mavenWethLps);
        requestAllRedemptions(orthogonalPool,        orthogonalLps);
        requestAllRedemptions(icebreakerPool,        icebreakerLps);
        requestAllRedemptions(aqruPool,              aqruLps);
        requestAllRedemptions(mavenUsdc3Pool,        mavenUsdc3Lps);

        ExitTimestamp[] memory exitTimestampArray = new ExitTimestamp[](7 * 3);

        address[] memory poolArray = new address[](7);
        poolArray[0] = mavenPermissionedPool;
        poolArray[1] = mavenUsdcPool;
        poolArray[2] = mavenWethPool;
        poolArray[3] = orthogonalPool;
        poolArray[4] = icebreakerPool;
        poolArray[5] = aqruPool;
        poolArray[6] = mavenUsdc3Pool;

        for (uint256 i = 0; i < poolArray.length; i++) {
            IWithdrawalManager withdrawalManager = IWithdrawalManager(IPoolManager(IPool(poolArray[i]).manager()).withdrawalManager());

            uint256 currentCycleId = withdrawalManager.getCurrentCycleId();

            for (uint256 j = 0; j < 3; j++) {
                exitTimestampArray[i * 3 + j] = ExitTimestamp(poolArray[i], withdrawalManager.getWindowStart(currentCycleId + j));
            }
        }

        exitTimestampArray = sortTimestamps(exitTimestampArray);

        for (uint256 i = 0; i < exitTimestampArray.length; i++) {
            vm.warp(exitTimestampArray[i].timestamp);

            if (exitTimestampArray[i].pool == mavenPermissionedPool) {
                redeemedAmounts[0] = redeemAll(mavenPermissionedPool, mavenPermissionedLps);
            }

            else if (exitTimestampArray[i].pool == mavenUsdcPool)  redeemedAmounts[1] = redeemAll(mavenUsdcPool,  mavenUsdcLps);
            else if (exitTimestampArray[i].pool == mavenWethPool)  redeemedAmounts[2] = redeemAll(mavenWethPool,  mavenWethLps);
            else if (exitTimestampArray[i].pool == orthogonalPool) redeemedAmounts[3] = redeemAll(orthogonalPool, orthogonalLps);
            else if (exitTimestampArray[i].pool == icebreakerPool) redeemedAmounts[4] = redeemAll(icebreakerPool, icebreakerLps);
            else if (exitTimestampArray[i].pool == aqruPool)       redeemedAmounts[5] = redeemAll(aqruPool,       aqruLps);
            else if (exitTimestampArray[i].pool == mavenUsdc3Pool) redeemedAmounts[6] = redeemAll(mavenUsdc3Pool, mavenUsdc3Lps);
        }
    }



    function withdrawAllPoolCoverFromAllPools() internal {
        vm.startPrank(governor);
        IGlobals(mapleGlobalsV2Proxy).setMinCoverAmount(mavenPermissionedPoolManager, 0);
        IGlobals(mapleGlobalsV2Proxy).setMinCoverAmount(mavenUsdcPoolManager,         0);
        IGlobals(mapleGlobalsV2Proxy).setMinCoverAmount(mavenWethPoolManager,         0);
        IGlobals(mapleGlobalsV2Proxy).setMinCoverAmount(orthogonalPoolManager,        0);
        IGlobals(mapleGlobalsV2Proxy).setMinCoverAmount(icebreakerPoolManager,        0);
        IGlobals(mapleGlobalsV2Proxy).setMinCoverAmount(aqruPoolManager,              0);
        IGlobals(mapleGlobalsV2Proxy).setMinCoverAmount(mavenUsdc3PoolManager,        0);
        vm.stopPrank();

        withdrawAllPoolCover(icebreakerPoolManager);
        withdrawAllPoolCover(mavenPermissionedPoolManager);
        withdrawAllPoolCover(mavenUsdcPoolManager);
        withdrawAllPoolCover(mavenWethPoolManager);
        withdrawAllPoolCover(orthogonalPoolManager);
        withdrawAllPoolCover(aqruPoolManager);
        withdrawAllPoolCover(mavenUsdc3PoolManager);
    }

    /**************************************************************************************************************************************/
    /*** Lifecycle Helpers                                                                                                              ***/
    /**************************************************************************************************************************************/

    function assertAllPoolsAreEmpty() internal {
        assertPoolIsEmpty(mavenPermissionedPool);
        assertPoolIsEmpty(mavenUsdcPool);
        assertPoolIsEmpty(mavenWethPool);
        assertPoolIsEmpty(orthogonalPool);
        assertPoolIsEmpty(icebreakerPool);
        assertPoolIsEmpty(aqruPool);
        assertPoolIsEmpty(mavenUsdc3Pool);
    }

    function assertPoolIsEmpty(address pool_) internal {
        IPool pool = IPool(pool_);

        ILoanManagerLike fixedTermLoanManager = ILoanManagerLike(IPoolManager(IPool(pool_).manager()).loanManagerList(0));

        assertEq(fixedTermLoanManager.accruedInterest(),  0, "accruedInterest");
        assertEq(fixedTermLoanManager.principalOut(),     0, "principalOut");
        assertEq(fixedTermLoanManager.unrealizedLosses(), 0, "unrealizedLosses");

        // TODO: Remove by getting dummy LP address
        if (pool_ == aqruPool || pool_ == mavenUsdc3Pool) {
            assertApproxEqAbs(fixedTermLoanManager.assetsUnderManagement(), 0, 3, "assetsUnderManagement");
            assertApproxEqAbs(fixedTermLoanManager.accountedInterest(),     0, 3, "accountedInterest");

            assertApproxEqAbs(pool.totalAssets(), IERC20(pool.asset()).balanceOf(pool_), 3, "cash totalAssets mismatch");

            assertEq(pool.totalSupply(), 0.1e6, "totalSupply");
            return;
        }

        assertEq(fixedTermLoanManager.assetsUnderManagement(), 0, "assetsUnderManagement");
        assertEq(fixedTermLoanManager.accountedInterest(),     0, "accountedInterest");

        assertEq(pool.totalAssets(), 0, "totalSupply");
        assertEq(pool.totalSupply(), 0, "totalSupply");

        assertEq(IERC20(pool.asset()).balanceOf(pool_), 0, "cash");
    }

    function requestAllRedemptions(address pool_, address[] storage lps_) internal {
        IWithdrawalManager withdrawalManager = IWithdrawalManager(IPoolManager(IPool(pool_).manager()).withdrawalManager());

        for (uint256 i; i < lps_.length; ++i) {
            address lp     = lps_[i];
            uint256 shares = IPool(pool_).balanceOf(lp);

            // User has no shares in system
            if (shares == 0 && withdrawalManager.lockedShares(lp) == 0) continue;

            uint256 cycleId = withdrawalManager.exitCycleId(lps_[i]);

            if (cycleId > 0) {
                ( , uint256 windowEnd ) = withdrawalManager.getWindowAtId(cycleId);

                // User has already requested redemption
                // NOTE: Using windowEnd to prevent unnecessary re-requests
                if (block.timestamp < windowEnd) continue;
            }

            requestRedeem(pool_, lp, shares);  // TODO: This will break if there is a partial redemption in place.

            assertEq(IPool(pool_).balanceOf(lp), 0);
        }
    }

    function redeemAll(address pool_, address[] storage lps_) internal returns (uint256[] memory redeemedAmounts_) {
        redeemedAmounts_ = new uint256[](lps_.length);

        IWithdrawalManager withdrawalManager = IWithdrawalManager(IPoolManager(IPool(pool_).manager()).withdrawalManager());

        for (uint256 i; i < lps_.length; ++i) {
            address lp = lps_[i];
            uint256 lockedShares = withdrawalManager.lockedShares(lp);

            if (lockedShares == 0) {
                continue;
            }

            ( uint256 windowStart, uint256 windowEnd ) = withdrawalManager.getWindowAtId(withdrawalManager.exitCycleId(lps_[i]));

            if (block.timestamp < windowStart || block.timestamp > windowEnd) continue;

            redeemedAmounts_[i] = redeem(pool_, lp, lockedShares);

            assertEq(IPool(pool_).balanceOf(lp),         0);
            assertEq(withdrawalManager.lockedShares(lp), 0);
        }
    }

    function getNextLoan() internal view returns (address loan) {
        uint256 nextPaymentDueDate;
        address tempLoan;
        uint256 tempNextPaymentDueDate;

        ( tempLoan, tempNextPaymentDueDate ) = getNextLoanAndPaymentDueDate(icebreakerLoans);

        if (isEarlierThan(tempNextPaymentDueDate, nextPaymentDueDate)) {
            loan               = tempLoan;
            nextPaymentDueDate = tempNextPaymentDueDate;
        }

        ( tempLoan, tempNextPaymentDueDate ) = getNextLoanAndPaymentDueDate(mavenPermissionedLoans);

        if (isEarlierThan(tempNextPaymentDueDate, nextPaymentDueDate)) {
            loan               = tempLoan;
            nextPaymentDueDate = tempNextPaymentDueDate;
        }

        ( tempLoan, tempNextPaymentDueDate ) = getNextLoanAndPaymentDueDate(mavenUsdcLoans);

        if (isEarlierThan(tempNextPaymentDueDate, nextPaymentDueDate)) {
            loan               = tempLoan;
            nextPaymentDueDate = tempNextPaymentDueDate;
        }

        ( tempLoan, tempNextPaymentDueDate ) = getNextLoanAndPaymentDueDate(mavenWethLoans);

        if (isEarlierThan(tempNextPaymentDueDate, nextPaymentDueDate)) {
            loan               = tempLoan;
            nextPaymentDueDate = tempNextPaymentDueDate;
        }

        ( tempLoan, tempNextPaymentDueDate ) = getNextLoanAndPaymentDueDate(orthogonalLoans);

        if (isEarlierThan(tempNextPaymentDueDate, nextPaymentDueDate)) {
            loan               = tempLoan;
            nextPaymentDueDate = tempNextPaymentDueDate;
        }

        ( tempLoan, tempNextPaymentDueDate ) = getNextLoanAndPaymentDueDate(aqruLoans);

        if (isEarlierThan(tempNextPaymentDueDate, nextPaymentDueDate)) {
            loan               = tempLoan;
            nextPaymentDueDate = tempNextPaymentDueDate;
        }

        ( tempLoan, tempNextPaymentDueDate ) = getNextLoanAndPaymentDueDate(mavenUsdc3Loans);

        if (isEarlierThan(tempNextPaymentDueDate, nextPaymentDueDate)) {
            loan               = tempLoan;
            nextPaymentDueDate = tempNextPaymentDueDate;
        }

    }

    function getNextLoanAndPaymentDueDate(address[] storage loans) internal view returns (address loan, uint256 nextPaymentDueDate) {
        for (uint256 i; i < loans.length; ++i) {

            uint256 dueDate = IFixedTermLoan(loans[i]).nextPaymentDueDate();

            if (!isEarlierThan(dueDate, nextPaymentDueDate)) continue;

            loan               = loans[i];
            nextPaymentDueDate = dueDate;
        }
    }

    function isEarlierThan(uint256 timestamp, uint256 threshold) internal pure returns (bool isEarlier) {
        if (timestamp == 0) return false;

        if (threshold == 0) return true;

        return timestamp < threshold;
    }

    function sortTimestamps(ExitTimestamp[] memory exitTimestamps) internal pure returns (ExitTimestamp[] memory) {
        bool sorted = false;

        ExitTimestamp memory temp;

        while (!sorted) {
            sorted = true;

            for (uint256 i = 0; i < exitTimestamps.length - 1; i++) {
                if (exitTimestamps[i].timestamp > exitTimestamps[i + 1].timestamp) {
                    temp                  = exitTimestamps[i];
                    exitTimestamps[i]     = exitTimestamps[i + 1];
                    exitTimestamps[i + 1] = temp;
                    sorted = false;
                }
            }
        }

        return exitTimestamps;
    }

    function withdrawAllPoolCover(address poolManager_) internal {
        IPoolManager poolManager = IPoolManager(poolManager_);
        uint256      amount      = IERC20(IPool(poolManager.pool()).asset()).balanceOf(poolManager.poolDelegateCover());

        if (amount == 0) return;

        withdrawCover(poolManager_, amount);
    }

}
