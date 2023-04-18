// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IERC20,
    IFixedTermLoan,
    IFixedTermLoanManager,
    IGlobals,
    ILoanManagerLike,
    IOpenTermLoan,
    IPool,
    IPoolManager,
    IProxyFactoryLike,
    IWithdrawalManager
} from "../../contracts/interfaces/Interfaces.sol";

import { console } from "../../contracts/Contracts.sol";

import { ProtocolUpgradeBase } from "./ProtocolUpgradeBase.sol";

contract LifecycleBase is ProtocolUpgradeBase {

    mapping(address => uint256) lpExitTimestamps;

    mapping(address => address[]) public loansForPool;

    struct ExitTimestamp {
        address pool;
        uint256 timestamp;
    }

    /**************************************************************************************************************************************/
    /*** Generic Action Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    function performActionOnAllPools(function(address) internal action) internal {
        action(mavenPermissionedPool);
        action(mavenUsdcPool);
        action(mavenWethPool);
        action(orthogonalPool);
        action(icebreakerPool);
        action(aqruPool);
        action(mavenUsdc3Pool);
    }

    function performActionOnAllPools(function(address,address) internal action, address borrower_) internal {
        action(mavenPermissionedPool, borrower_);
        action(mavenUsdcPool,         borrower_);
        action(mavenWethPool,         borrower_);
        action(orthogonalPool,        borrower_);
        action(icebreakerPool,        borrower_);
        action(aqruPool,              borrower_);
        action(mavenUsdc3Pool,        borrower_);
    }

    function performActionOnAllPoolLps(function(address[] storage) internal action) internal {
        action(mavenPermissionedLps);
        action(mavenUsdcLps);
        action(mavenWethLps);
        action(orthogonalLps);
        action(icebreakerLps);
        action(aqruLps);
        action(mavenUsdc3Lps);
    }

    /**************************************************************************************************************************************/
    /*** Lifecycle Functions                                                                                                            ***/
    /**************************************************************************************************************************************/

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

        for (uint256 i; i < poolArray.length; ++i) {
            IWithdrawalManager withdrawalManager = IWithdrawalManager(IPoolManager(IPool(poolArray[i]).manager()).withdrawalManager());

            uint256 currentCycleId = withdrawalManager.getCurrentCycleId();

            for (uint256 j; j < 3; ++j) {
                exitTimestampArray[i * 3 + j] = ExitTimestamp(poolArray[i], withdrawalManager.getWindowStart(currentCycleId + j));
            }
        }

        exitTimestampArray = sortTimestamps(exitTimestampArray);

        for (uint256 i; i < exitTimestampArray.length; ++i) {
            vm.warp(exitTimestampArray[i].timestamp);

            address pool = exitTimestampArray[i].pool;

            if (pool == mavenPermissionedPool) redeemedAmounts[0] = redeemAll(mavenPermissionedPool, mavenPermissionedLps);
            if (pool == mavenUsdcPool)         redeemedAmounts[1] = redeemAll(mavenUsdcPool,         mavenUsdcLps);
            if (pool == mavenWethPool)         redeemedAmounts[2] = redeemAll(mavenWethPool,         mavenWethLps);
            if (pool == orthogonalPool)        redeemedAmounts[3] = redeemAll(orthogonalPool,        orthogonalLps);
            if (pool == icebreakerPool)        redeemedAmounts[4] = redeemAll(icebreakerPool,        icebreakerLps);
            if (pool == aqruPool)              redeemedAmounts[5] = redeemAll(aqruPool,              aqruLps);
            if (pool == mavenUsdc3Pool)        redeemedAmounts[6] = redeemAll(mavenUsdc3Pool,        mavenUsdc3Lps);
        }
    }

    function payOffAllLoansWhenDue() internal {
        address loan;

        while ((loan = getNextLoan()) != address(0)) {

            bool isOpenTermLoan = isOpenTermLoan(loan);

            uint256 nextPaymentDueDate = isOpenTermLoan
                ? IOpenTermLoan(loan).paymentDueDate()
                : IFixedTermLoan(loan).nextPaymentDueDate();

            // Call open terms after 5 payments on average
            if (isOpenTermLoan && uint256(keccak256(abi.encode(nextPaymentDueDate))) % 5 == 0) {
                callLoan(loan, IOpenTermLoan(loan).principal());
            }

            if (nextPaymentDueDate > block.timestamp) {
                vm.warp(nextPaymentDueDate);
            }

            makePayment(loan);
        }
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

            if (lockedShares == 0) continue;

            ( uint256 windowStart, uint256 windowEnd ) = withdrawalManager.getWindowAtId(withdrawalManager.exitCycleId(lp));

            if (block.timestamp < windowStart || block.timestamp > windowEnd) continue;

            redeemedAmounts_[i] = redeem(pool_, lp, lockedShares);

            assertEq(IPool(pool_).balanceOf(lp), 0);

            // NOTE: Since accountedInterest includes dust, lockedLiquidity > cash when AUM == 0. TA > cash in this case as well.
            //       Because of this, getRedeemableShares introduces a rounding error.
            assertApproxEqAbs(withdrawalManager.lockedShares(lp), 0, 1);
        }
    }

    function withdrawAllPoolCover(address pool_) internal {
        address poolManager = IPool(pool_).manager();

        uint256 amount = IERC20(IPool(pool_).asset()).balanceOf(IPoolManager(poolManager).poolDelegateCover());

        if (amount == 0) return;

        vm.prank(governor);
        IGlobals(mapleGlobalsV2Proxy).setMinCoverAmount(mavenPermissionedPoolManager, 0);

        withdrawCover(poolManager, amount);
    }

    /**************************************************************************************************************************************/
    /*** Utility Functions                                                                                                              ***/
    /**************************************************************************************************************************************/

    function addMainnetLoansToMapping(address pool_, address[] storage loans_) internal {
        for (uint256 i; i < loans_.length; ++i) {
            loansForPool[pool_].push(loans_[i]);
        }
    }

    function addAllMainnetLoansToAllMappings() internal {
        addMainnetLoansToMapping(mavenPermissionedPool, mavenPermissionedLoans);
        addMainnetLoansToMapping(mavenUsdcPool,         mavenUsdcLoans);
        addMainnetLoansToMapping(mavenWethPool,         mavenWethLoans);
        addMainnetLoansToMapping(orthogonalPool,        orthogonalLoans);
        addMainnetLoansToMapping(icebreakerPool,        icebreakerLoans);
        addMainnetLoansToMapping(aqruPool,              aqruLoans);
        addMainnetLoansToMapping(mavenUsdc3Pool,        mavenUsdc3Loans);
    }

    function getNextLoan() internal view returns (address nextLoan) {
        uint256 nextPaymentDueDate;

        ( nextLoan, nextPaymentDueDate ) = getNextLoanAndPaymentDueDate(icebreakerPool,        nextLoan, nextPaymentDueDate);
        ( nextLoan, nextPaymentDueDate ) = getNextLoanAndPaymentDueDate(mavenPermissionedPool, nextLoan, nextPaymentDueDate);
        ( nextLoan, nextPaymentDueDate ) = getNextLoanAndPaymentDueDate(mavenUsdcPool,         nextLoan, nextPaymentDueDate);
        ( nextLoan, nextPaymentDueDate ) = getNextLoanAndPaymentDueDate(mavenWethPool,         nextLoan, nextPaymentDueDate);
        ( nextLoan, nextPaymentDueDate ) = getNextLoanAndPaymentDueDate(orthogonalPool,        nextLoan, nextPaymentDueDate);
        ( nextLoan, nextPaymentDueDate ) = getNextLoanAndPaymentDueDate(aqruPool,              nextLoan, nextPaymentDueDate);
        ( nextLoan, nextPaymentDueDate ) = getNextLoanAndPaymentDueDate(mavenUsdc3Pool,        nextLoan, nextPaymentDueDate);
    }

    function getNextLoanAndPaymentDueDate(address pool_, address currentEarliestLoan_, uint256 currentEarliestDueDate_)
        internal view returns (address earliestLoan_, uint256 earliestDueDate_)
    {
        address[] storage loans_ = loansForPool[pool_];

        earliestLoan_    = currentEarliestLoan_;
        earliestDueDate_ = currentEarliestDueDate_;

        for (uint256 i; i < loans_.length; ++i) {
            uint256 dueDate_ = isOpenTermLoan(loans_[i])
                ? IOpenTermLoan(loans_[i]).paymentDueDate()
                : IFixedTermLoan(loans_[i]).nextPaymentDueDate();

            if (!isEarlierThan(dueDate_, earliestDueDate_)) continue;

            earliestLoan_    = loans_[i];
            earliestDueDate_ = dueDate_;
        }
    }

    function isEarlierThan(uint256 firstTimestamp_, uint256 secondTimestamp_) internal pure returns (bool isEarlier_) {
        if (firstTimestamp_  == 0) return false;

        if (secondTimestamp_ == 0) return true;

        return firstTimestamp_ < secondTimestamp_;
    }

    function sortTimestamps(ExitTimestamp[] memory exitTimestamps) internal pure returns (ExitTimestamp[] memory) {
        bool sorted;

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

    /**************************************************************************************************************************************/
    /*** Assertion Helpers                                                                                                              ***/
    /**************************************************************************************************************************************/

    function assertPoolIsEmpty(address pool_) internal {
        IPool pool = IPool(pool_);

        IPoolManager poolManager = IPoolManager(pool.manager());

        ILoanManagerLike fixedTermLoanManager = ILoanManagerLike(poolManager.loanManagerList(0));

        assertEq(fixedTermLoanManager.accruedInterest(),  0, "FT accruedInterest");
        assertEq(fixedTermLoanManager.principalOut(),     0, "FT principalOut");
        assertEq(fixedTermLoanManager.unrealizedLosses(), 0, "FT unrealizedLosses");

        assertApproxEqAbs(fixedTermLoanManager.assetsUnderManagement(), 0, 4, "FT assetsUnderManagement");
        assertApproxEqAbs(fixedTermLoanManager.accountedInterest(),     0, 4, "FT accountedInterest");

        if (poolManager.loanManagerListLength() > 1) {
            ILoanManagerLike openTermLoanManager = ILoanManagerLike(poolManager.loanManagerList(1));

            assertEq(openTermLoanManager.accruedInterest(),  0, "OT accruedInterest");
            assertEq(openTermLoanManager.principalOut(),     0, "OT principalOut");
            assertEq(openTermLoanManager.unrealizedLosses(), 0, "OT unrealizedLosses");

            assertApproxEqAbs(openTermLoanManager.assetsUnderManagement(), 0, 5, "OT assetsUnderManagement");
            assertApproxEqAbs(openTermLoanManager.accountedInterest(),     0, 5, "OT accountedInterest");
        }

        // TODO: Remove by getting dummy LP address
        if (pool_ == aqruPool || pool_ == mavenUsdc3Pool || pool_ == icebreakerPool) {
            assertApproxEqAbs(pool.totalSupply(), 0, 0.1e6, "totalSupply");

            assertApproxEqAbs(pool.totalAssets(), IERC20(pool.asset()).balanceOf(pool_), 7, "totalAssets <> cash mismatch");
            return;
        }

        assertApproxEqAbs(pool.totalSupply(), 0, 14, "totalSupply");

        assertEq(IERC20(pool.asset()).balanceOf(pool_), 0, "cash");

        assertApproxEqAbs(pool.totalAssets(), 0, 4, "totalAssets");
    }

}

contract FixedTermLifecycle is LifecycleBase {

    function test_fixedTermLifecycle() external {
        _addWithdrawalManagersToAllowlists();  // TODO: Remove once this is done on mainnet.

        _performProtocolUpgrade();

        addAllMainnetLoansToAllMappings();

        payOffAllLoansWhenDue();

        exitFromAllPoolsWhenPossible();

        performActionOnAllPools(withdrawAllPoolCover);

        performActionOnAllPools(assertPoolIsEmpty);
    }

}

contract OpenTermOnboardLifecycle is LifecycleBase {

    address[] newBorrowers;
    address[] newLps;

    function setUp() public override  {
        super.setUp();

        for (uint256 i; i < 3; ++i) {
            newBorrowers.push(makeAddr(vm.toString(i)));
            newLps.push(makeAddr(vm.toString(i)));
        }
    }

    function test_openTermOnboardLifecycle() external {
        _addWithdrawalManagersToAllowlists();  // TODO: Remove once this is done on mainnet.

        _performProtocolUpgrade();

        _addLoanManagers();

        performActionOnAllPools(depositNewLps);

        performActionOnAllPoolLps(addNewLps);

        for(uint256 i; i < newBorrowers.length; ++i) {
            vm.warp(block.timestamp + 3 days);
            performActionOnAllPools(createAndFundOpenTermLoan, newBorrowers[i]);
        }

        addAllMainnetLoansToAllMappings();

        payOffAllLoansWhenDue();

        exitFromAllPoolsWhenPossible();

        performActionOnAllPools(withdrawAllPoolCover);

        performActionOnAllPools(assertPoolIsEmpty);
    }

    /**************************************************************************************************************************************/
    /*** Open Term Loan Helper Functions                                                                                                ***/
    /**************************************************************************************************************************************/

    function addNewLps(address[] storage lpArray_) internal {
        for (uint256 i; i < newLps.length; ++i) {
            lpArray_.push(newLps[i]);
        }
    }

    function createAndFundOpenTermLoan(address pool_, address borrower_) internal {
        IPoolManager poolManager = IPoolManager(IPool(pool_).manager());

        address loan = createOpenTermLoan(
            openTermLoanFactory,
            borrower_,
            poolManager.loanManagerList(1),
            address(IPool(pool_).asset()),
            1_000_000e6,
            [uint256(5 days), uint256(3 days), uint256(30 days)],
            [uint256(0.01e6), uint256(0.12e6), 0, uint256(0.05e6)]
        );

        loansForPool[pool_].push(loan);

        fundLoan(loan);
    }

    function depositNewLps(address pool) internal {
        IPoolManager poolManager = IPoolManager(IPool(pool).manager());

        uint256 baseAmount = IPool(pool).asset() == WETH ? 10_000e18 : 1_000_000e6;

        vm.startPrank(poolManager.poolDelegate());
        poolManager.setLiquidityCap(poolManager.totalAssets() + baseAmount * 6);
        vm.stopPrank();

        deposit(pool, newLps[0], baseAmount);
        deposit(pool, newLps[1], baseAmount * 2);
        deposit(pool, newLps[2], baseAmount * 3);
    }

    function logPoolState(address pool_) internal view {
        IPoolManager poolManager = IPoolManager(IPool(pool_).manager());

        ILoanManagerLike fixedTermLoanManager = ILoanManagerLike(poolManager.loanManagerList(0));
        ILoanManagerLike openTermLoanManager  = ILoanManagerLike(poolManager.loanManagerList(1));

        console.log("\npool", pool_);

        console.log("totalSupply    ", IPool(pool_).totalSupply());
        console.log("totalAssets    ", poolManager.totalAssets());
        console.log("FT AUM         ", fixedTermLoanManager.assetsUnderManagement());
        console.log("OT AUM         ", openTermLoanManager.assetsUnderManagement());
        console.log("FT principalOut", fixedTermLoanManager.principalOut());
        console.log("OT principalOut", openTermLoanManager.principalOut());
    }

}
