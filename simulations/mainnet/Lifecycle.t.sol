// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { CSVWriter }        from "../../modules/contract-test-utils/contracts/csv.sol";
import { Address, console } from "../../modules/contract-test-utils/contracts/test.sol";

import { IERC20 }               from "../../modules/erc20/contracts/interfaces/IERC20.sol";
import { ILiquidator }          from "../../modules/liquidations/contracts/interfaces/ILiquidator.sol";
import { IMapleLoan }           from "../../modules/loan-v401/contracts/interfaces/IMapleLoan.sol";
import { IMapleLoanFeeManager } from "../../modules/loan-v401/contracts/interfaces/IMapleLoanFeeManager.sol";
import { IPool }                from "../../modules/pool-v2/contracts/interfaces/IPool.sol";
import { IPoolManager }         from "../../modules/pool-v2/contracts/interfaces/IPoolManager.sol";
import { IRefinancer }          from "../../modules/loan-v401/contracts/interfaces/IRefinancer.sol";
import { IWithdrawalManager }   from "../../modules/withdrawal-manager/contracts/interfaces/IWithdrawalManager.sol";

import { IERC20Like, ILoanManagerLike, IMapleLoanLike, IPoolManagerLike } from "./Interfaces.sol";

import { SimulationBase } from "./SimulationBase.sol";

contract Lifecycle is SimulationBase, CSVWriter {

    mapping(uint256 => address) internal withdrawalQueue;
    uint256 earliestWithdrawal = 1;
    uint256 latestWithdrawal = 0;

    /******************************************************************************************************************************/
    /*** Lifecycle Helpers                                                                                                      ***/
    /******************************************************************************************************************************/

    function getRealAmount(uint256 value_, address poolManager_) internal view returns (uint256 amount_) {
        amount_ = value_ * (10 ** IERC20(IPoolManager(poolManager_).asset()).decimals());
    }

    function getRandomSensibleAmount(address poolManager_, uint256 seed_) internal view returns (uint256 amount_) {
        uint256 tenPercentOfPool = IPoolManager(poolManager_).totalAssets() / 10;
        uint256 onePercentOfPool = tenPercentOfPool / 10;
        amount_                  = (getRandomNumber(seed_++) % tenPercentOfPool) + onePercentOfPool;
    }

    function getRandomNumber(uint256 seed_) internal view returns (uint256 number_) {
        number_ = uint256(keccak256(abi.encode(seed_++)));
    }

    function requestAllRedemptions(address pool_, address[] storage lps_) internal returns (uint256 exitTimestamp_) {
        for (uint256 i; i < lps_.length; ++i) {
            address lp     = lps_[i];
            uint256 shares = IPool(pool_).balanceOf(lp);

            if (shares == 0) {
                console.log("WARNING: requestRedeem of zero shares", pool_, lp);
                continue;
            }

            requestRedeem(pool_, lp, shares);
        }

        IWithdrawalManager withdrawalManager = IWithdrawalManager(
            IPoolManager(
                IPool(pool_).manager()
            ).withdrawalManager()
        );

        exitTimestamp_ = withdrawalManager.getWindowStart(withdrawalManager.getCurrentCycleId() + 2);
    }

    function redeemAll(address pool_, address[] storage lps_) internal {
        for (uint256 i; i < lps_.length; ++i) {
            address lp = lps_[i];

            uint256 lockedShares = IWithdrawalManager(
                IPoolManager(
                    IPool(pool_).manager()
                ).withdrawalManager()
            ).lockedShares(lp);

            if (lockedShares == 0) {
                console.log("WARNING: redeem of zero lockedShares", pool_, lp);
                continue;
            }

            redeem(pool_, lp, lockedShares);
        }
    }

    function getIndexOfEarliest(uint256[] memory timestamps_) internal pure returns (int256 earliestIndex_) {
        earliestIndex_ = -1;
        uint256 earliest;

        for (uint256 i; i < timestamps_.length; ++i) {
            uint256 timestamp = timestamps_[i];

            if (timestamp == 0) continue;

            if (earliest == 0 || timestamp < earliest) {
                earliest = timestamp;
                earliestIndex_ = int256(i);
            }
        }
    }

    function withdrawAllPoolCover(address poolManager_) internal {
        IPoolManager poolManager = IPoolManager(poolManager_);
        uint256      amount      = IERC20Like(IPool(poolManager.pool()).asset()).balanceOf(poolManager.poolDelegateCover());

        if (amount == 0) return;

        withdrawCover(poolManager_, amount);
    }

    function getBalances(address asset_, address[] storage accounts_) internal view returns (int256[] memory balances_) {
        balances_ = new int256[](accounts_.length);

        for (uint256 i; i < accounts_.length; ++i) {
            balances_[i] = int256(IERC20(asset_).balanceOf(accounts_[i]));
        }
    }

    function getBalanceChanges(address asset_, address[] storage accounts_, int256[] memory startingBalances_) internal view returns (int256[] memory balancesChanges_) {
        balancesChanges_ = new int256[](accounts_.length);

        for (uint256 i; i < accounts_.length; ++i) {
            balancesChanges_[i] = int256(IERC20(asset_).balanceOf(accounts_[i])) - startingBalances_[i];
        }
    }

    function writeBalanceChanges(string memory path_, address[] storage lps_, int256[] memory balancesChanges_) internal {
        string[] memory row = new string[](2);
        row[0] = "account";
        row[1] = "balance change";

        initCSV(path_, row);

        for (uint256 i; i < lps_.length; ++i) {
            row[0] = vm.toString(lps_[i]);
            row[1] = vm.toString(balancesChanges_[i]);

            addRow(path_, row);
        }

        writeFile(path_);
    }

    function performRefinance(address poolManager_, address loan_) internal {
        bytes[] memory refinanceCalls_ = new bytes[](1);
        refinanceCalls_[0] = abi.encodeWithSelector(IRefinancer.setPaymentsRemaining.selector, IMapleLoan(loan_).paymentsRemaining() + 2);

        proposeRefinance(loan_, address(refinancer), block.timestamp, refinanceCalls_, 0, 0);
        acceptRefinance(poolManager_, loan_, address(refinancer), block.timestamp, refinanceCalls_, 0);
    }

    function increaseDepositor(address poolManager_, address lp_, uint256 amount_) internal {
        uint256 requiredLiquidityCap_ = amount_ + IPoolManager(poolManager_).totalAssets();

        if (IPoolManager(poolManager_).liquidityCap() < requiredLiquidityCap_) {
            console.log(block.timestamp, "Setting Liquidity Cap", requiredLiquidityCap_);
            setLiquidityCap(poolManager_, requiredLiquidityCap_);
        }

        console.log(block.timestamp, "Liquidity Increased  ", lp_, amount_);
        depositLiquidity(IPoolManager(poolManager_).pool(), lp_, amount_);
    }

    function increaseDepositorByRandomAmount(address poolManager_, address lp_, uint256 seed_) internal {
        increaseDepositor(poolManager_, lp_, getRandomSensibleAmount(poolManager_, seed_++));
    }

    function increaseRandomDepositor(address poolManager_, address[] storage lps_, uint256 amount_, uint256 seed_) internal {
        increaseDepositor(poolManager_, lps_[getRandomNumber(seed_++) % lps_.length], amount_);
    }

    function increaseRandomDepositorRandomly(address poolManager_, address[] storage lps_, uint256 seed_) internal {
        increaseRandomDepositor(poolManager_, lps_, getRandomSensibleAmount(poolManager_, seed_++), seed_++);
    }

    function createDepositorRandomly(address poolManager_, address[] storage lps_, uint256 seed_) internal {
        address lp_ = address(new Address());
        allowLender(poolManager_, lp_);
        increaseDepositorByRandomAmount(poolManager_, lp_, seed_++);
        lps_.push(lp_);
    }

    function createDepositor(address poolManager_, address[] storage lps_, uint256 amount_) internal {
        address lp_ = address(new Address());
        allowLender(poolManager_, lp_);
        increaseDepositor(poolManager_, lp_, amount_);
        lps_.push(lp_);
    }

    function fundNewLoan(address poolManager_, IMapleLoanLike[] storage loans_, address[] storage lps_, uint256 seed_) internal {
        address borrower_ = address(new Address());

        vm.startPrank(governor);
        mapleGlobalsV2.setValidBorrower(borrower_, true);
        vm.stopPrank();

        uint256 principal_ = 3 * getRandomSensibleAmount(poolManager_, seed_++);
        address asset = IPoolManager(poolManager_).asset();

        address[2] memory assets_      = [asset, asset];
        uint256[3] memory termDetails_ = [uint256(0), uint256(30 days), uint256(4)];
        uint256[3] memory amounts_     = [0, principal_, 0];
        uint256[4] memory rates_       = [uint256(0.05e18), uint256(0.05e18), uint256(0.05e18), uint256(0.05e18)];
        uint256[2] memory fees_        = [getRealAmount(1, poolManager_), getRealAmount(1, poolManager_)];

        address loan_ = loanFactory.createInstance(
            abi.encode(borrower_, address(feeManager), assets_, termDetails_, amounts_, rates_, fees_),
            bytes32(getRandomNumber(seed_++))
        );

        address pool = IPoolManager(poolManager_).pool();
        IWithdrawalManager withdrawalManager = IWithdrawalManager(
            IPoolManager(poolManager_).withdrawalManager()
        );

        if (IERC20(asset).balanceOf(pool) < withdrawalManager.lockedLiquidity() + principal_) {
            createDepositor(
                poolManager_,
                lps_,
                (withdrawalManager.lockedLiquidity() + principal_) - IERC20(asset).balanceOf(pool)
            );
        }

        // TODO: check hasSufficientCover?

        console.log(block.timestamp, "Funding Loan         ", loan_, principal_);
        fundLoan(poolManager_, loan_);
        loans_.push(IMapleLoanLike(loan_));
    }

    function makeRandomRedeemRequest(address pool_, address[] storage lps_, uint256 seed_) internal {
        address lp_             = lps_[getRandomNumber(seed_++) % lps_.length];
        uint256 balanceOfAssets = IPool(pool_).balanceOfAssets(lp_);
        uint256 amount_         = getRandomNumber(seed_++) % balanceOfAssets;

        amount_ = ((9 * amount_) / 10) + (balanceOfAssets / 10);  // Effectively, amount is between 10% and 100% of balanceOfAssets.

        console.log(block.timestamp, "Requesting Redeem    ", lp_, amount_);
        requestRedeem(pool_, lp_, amount_);
        withdrawalQueue[++latestWithdrawal] = lp_;
    }

    function handleWithdrawalQueue(address poolManager_) internal {
        IWithdrawalManager withdrawalManager = IWithdrawalManager(
            IPoolManager(poolManager_).withdrawalManager()
        );

        while (withdrawalManager.isInExitWindow(withdrawalQueue[earliestWithdrawal])) {
            address lp_     = withdrawalQueue[earliestWithdrawal];
            uint256 amount_ = withdrawalManager.lockedShares(lp_);

            console.log(block.timestamp, "Redeeming            ", lp_, amount_);
            redeem(IPoolManager(poolManager_).pool(), lp_, amount_);
            delete withdrawalQueue[earliestWithdrawal++];
        }
    }

    function liquidateLoan(address poolManager_, address loan_) internal {
        uint256 lateTime = IMapleLoan(loan_).nextPaymentDueDate() + IMapleLoan(loan_).gracePeriod() + 1 hours;

        if (lateTime > block.timestamp) vm.warp(lateTime);

        console.log(block.timestamp, "Triggering Default   ", loan_);
        triggerDefault(poolManager_, loan_, address(liquidatorFactory));

        // ( , , , , , address liquidator_ ) = ILoanManagerLike(IPoolManager(poolManager_).loanManagerList(0)).liquidationInfo(loan_);
    }

    function createActionCsv(string memory path_) internal {
        string[] memory headers = new string[](4);
        headers[1] = "timestamp";
        headers[0] = "action";
        headers[2] = "subject";
        headers[3] = "details";

        initCSV(path_, headers);
    }

    function _logOutSortedPayments(IPoolManagerLike poolManager_) internal {
        console.log(" --- SortedPayments --- ");

        ILoanManagerLike loanManager_ = ILoanManagerLike(poolManager_.loanManagerList(0));

        uint24 paymentId = loanManager_.paymentWithEarliestDueDate();

        while (true) {
            console.log(paymentId);

            if (paymentId == 0) break;

            ( , paymentId, ) = loanManager_.sortedPayments(paymentId);
        }

        console.log(" --- -------------- --- ");
    }

    function performComplexLifecycle(IPoolManagerLike poolManager_, IMapleLoanLike[] storage loans_, address[] storage lps_, uint256 seed_) internal {
        // Divide seed by 2 so we can increment "infinitely".
        seed_ /= 2;

        // createActionCsv(path_);

        address loan;

        // Run this loop until all loans are repaid
        while ((loan = getNextLoan(loans_)) != address(0)) {
            handleWithdrawalQueue(address(poolManager_));

            if (IMapleLoan(loan).nextPaymentDueDate() > block.timestamp) {
                // Warp to the halfway point between "now" and when the next payment is due
                vm.warp(block.timestamp + (IMapleLoan(loan).nextPaymentDueDate() - block.timestamp) / 2);
            }

            // Perform a "random" action
            uint256 random = getRandomNumber(seed_++) % 100;

            if (random < 5) {  // 5% chance loan closes
                // TODO: maybe any open loan
                console.log(block.timestamp, "Closing              ", loan);
                closeLoan(loan);
                continue;  // Since loan is paid
            } else if (random < 10) {  // 5% chance loan refinanced
                // TODO: maybe any open loan
                console.log(block.timestamp, "Refinancing          ", loan);
                performRefinance(address(poolManager_), loan);
                continue;  // Since loan is refinanced
            } else if (random < 30) {  // 20% chance new depositor
                createDepositorRandomly(address(poolManager_), lps_, seed_++);
            } else if (random < 45) {  // 15% chance increased depositor
                increaseRandomDepositorRandomly(address(poolManager_), lps_, seed_++);
            } else if (random < 75) {  // 30% chance withdrawal
                makeRandomRedeemRequest(poolManager_.pool(), lps_, seed_++);
            } else if (random < 85) {  // 10% chance funding new loan
                fundNewLoan(address(poolManager_), loans_, lps_, seed_++);
            } else if (random < 95) {  // 10% chance impairing loan
                console.log(block.timestamp, "Impairing            ", loan);
                impairLoan(address(poolManager_), loan);
            } else if (random < 100) {  // 5% chance liquidating refinanced
                liquidateLoan(address(poolManager_), loan);
                continue;  // Since loan is defaulted
            }

            // 75% chance of going back to start.
            if ((getRandomNumber(seed_++) % 4) == 0) {
                // If the loan was impaired, warp and trigger default first
                // NOTE: Need to do this because impaired loan will not be seen by `getNextLoan`.
                if (random < 95) liquidateLoan(address(poolManager_), loan);

                continue;
            }

            handleWithdrawalQueue(address(poolManager_));

            // Warp to some time (early or late by up to 15 days) of the payment due date.
            uint256 someTime = IMapleLoan(loan).nextPaymentDueDate() - 15 days + (getRandomNumber(seed_++) % 30 days);

            if (someTime > block.timestamp) vm.warp(someTime);

            console.log(block.timestamp, "Paying               ", loan);
            makePayment(loan);
        }

        handleWithdrawalQueue(address(poolManager_));

        vm.warp(requestAllRedemptions(poolManager_.pool(), lps_));

        redeemAll(poolManager_.pool(), lps_);

        withdrawAllPoolCover(address(poolManager_));
    }

    /******************************************************************************************************************************/
    /*** Lifecycle Tests                                                                                                        ***/
    /******************************************************************************************************************************/

    function test_simpleLifecycle() external {
        int256[][5] memory balances;
        balances[0] = getBalances(USDC, icebreakerLps);
        balances[1] = getBalances(USDC, mavenPermissionedLps);
        balances[2] = getBalances(USDC, mavenUsdcLps);
        balances[3] = getBalances(WETH, mavenWethLps);
        balances[4] = getBalances(USDC, orthogonalLps);

        performEntireMigration();

        performAdditionalGlobalsSettings();

        address loan;

        while ((loan = getNextLoan()) != address(0)) {
            vm.warp(IMapleLoan(loan).nextPaymentDueDate());
            makePayment(loan);
        }

        uint256[] memory exitTimestamps = new uint256[](5);

        exitTimestamps[0] = requestAllRedemptions(icebreakerPoolManager.pool(),        icebreakerLps);
        exitTimestamps[1] = requestAllRedemptions(mavenPermissionedPoolManager.pool(), mavenPermissionedLps);
        exitTimestamps[2] = requestAllRedemptions(mavenUsdcPoolManager.pool(),         mavenUsdcLps);
        exitTimestamps[3] = requestAllRedemptions(mavenWethPoolManager.pool(),         mavenWethLps);
        exitTimestamps[4] = requestAllRedemptions(orthogonalPoolManager.pool(),        orthogonalLps);

        int256 earliest;

        while ((earliest = getIndexOfEarliest(exitTimestamps)) >= 0) {
            vm.warp(exitTimestamps[uint256(earliest)]);
            exitTimestamps[uint256(earliest)] = 0;

            if      (earliest == 0) redeemAll(icebreakerPoolManager.pool(),        icebreakerLps);
            else if (earliest == 1) redeemAll(mavenPermissionedPoolManager.pool(), mavenPermissionedLps);
            else if (earliest == 2) redeemAll(mavenUsdcPoolManager.pool(),         mavenUsdcLps);
            else if (earliest == 3) redeemAll(mavenWethPoolManager.pool(),         mavenWethLps);
            else if (earliest == 4) redeemAll(orthogonalPoolManager.pool(),        orthogonalLps);
        }

        vm.startPrank(governor);
        mapleGlobalsV2.setMinCoverAmount(address(icebreakerPoolManager),        0);
        mapleGlobalsV2.setMinCoverAmount(address(mavenPermissionedPoolManager), 0);
        mapleGlobalsV2.setMinCoverAmount(address(mavenUsdcPoolManager),         0);
        mapleGlobalsV2.setMinCoverAmount(address(mavenWethPoolManager),         0);
        mapleGlobalsV2.setMinCoverAmount(address(orthogonalPoolManager),        0);
        vm.stopPrank();

        withdrawAllPoolCover(address(icebreakerPoolManager));
        withdrawAllPoolCover(address(mavenPermissionedPoolManager));
        withdrawAllPoolCover(address(mavenUsdcPoolManager));
        withdrawAllPoolCover(address(mavenWethPoolManager));
        withdrawAllPoolCover(address(orthogonalPoolManager));

        makeDir("./output/simple-lifecycle");

        writeBalanceChanges("./output/simple-lifecycle/icebreaker-lp-balance-changes.csv",        icebreakerLps,        getBalanceChanges(USDC, icebreakerLps,        balances[0]));
        writeBalanceChanges("./output/simple-lifecycle/mavenPermissioned-lp-balance-changes.csv", mavenPermissionedLps, getBalanceChanges(USDC, mavenPermissionedLps, balances[1]));
        writeBalanceChanges("./output/simple-lifecycle/mavenUsdc-lp-balance-changes.csv",         mavenUsdcLps,         getBalanceChanges(USDC, mavenUsdcLps,         balances[2]));
        writeBalanceChanges("./output/simple-lifecycle/mavenWeth-lp-balance-changes.csv",         mavenWethLps,         getBalanceChanges(WETH, mavenWethLps,         balances[3]));
        writeBalanceChanges("./output/simple-lifecycle/orthogonal-lp-balance-changes.csv",        orthogonalLps,        getBalanceChanges(USDC, orthogonalLps,        balances[4]));
    }

    // function test_complexLifecycle_icebreaker() external {
    //     migrateAllPools();
    //     performComplexLifecycle(icebreakerPoolManager, icebreakerLoans, icebreakerLps, 0);
    // }

    // function test_complexLifecycle_mavenPermissioned() external {
    //     migrateAllPools();
    //     performComplexLifecycle(mavenPermissionedPoolManager, mavenPermissionedLoans, mavenPermissionedLps, 0);
    // }

    // function test_complexLifecycle_mavenUsdc() external {
    //     int256[] memory balances = getBalances(USDC, mavenUsdcLps);

    //     migrateAllPools();
    //     performComplexLifecycle(mavenUsdcPoolManager, mavenUsdcLoans, mavenUsdcLps, 2);

    //     makeDir("./output/complex-lifecycle");
    //     writeBalanceChanges("./output/complex-lifecycle/mavenUsdc-lp-balance-changes.csv", mavenUsdcLps, getBalanceChanges(USDC, mavenUsdcLps, balances));
    // }

    // function test_complexLifecycle_mavenWeth() external {
    //     migrateAllPools();
    //     performComplexLifecycle(mavenWethPoolManager, mavenWethLoans, mavenWethLps, 0);
    // }

    // function test_complexLifecycle_orthogonal() external {
    //     migrateAllPools();
    //     performComplexLifecycle(orthogonalPoolManager, orthogonalLoans, orthogonalLps, 0);
    // }

}
