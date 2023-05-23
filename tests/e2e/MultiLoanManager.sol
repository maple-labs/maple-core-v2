// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IFixedTermLoan,
    IFixedTermLoanManager,
    IOpenTermLoan,
    IOpenTermLoanManager
} from "../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

contract MultiLoanManagerTests is TestBaseWithAssertions {

    address immutable borrower1 = makeAddr("borrower1");
    address immutable borrower2 = makeAddr("borrower2");
    address immutable borrower3 = makeAddr("borrower3");
    address immutable borrower4 = makeAddr("borrower4");

    address immutable lp0 = makeAddr("lp0");
    address immutable lp1 = makeAddr("lp1");
    address immutable lp2 = makeAddr("lp2");
    address immutable lp3 = makeAddr("lp3");

    uint256 constant deposit0 = 35_000_000e6;
    uint256 constant deposit1 = 1_000_000e6;
    uint256 constant deposit2 = 500_000e6;
    uint256 constant deposit3 = 1_500_000e6;
    uint256 constant deposits = deposit0 + deposit1 + deposit2 + deposit3;

    uint256 constant gracePeriod      = 5 days;
    uint256 constant noticePeriod     = 5 days;
    uint256 constant numberOfPayments = 9;
    uint256 constant paymentInterval  = 30 days;

    uint256 constant principal1 = 1_000_000e6;
    uint256 constant principal2 = 1_500_000e6;
    uint256 constant principal3 = 750_000e6;
    uint256 constant principal4 = 1_205_000e6;

    uint256 constant interestRate1 = 0.02e6;
    uint256 constant interestRate2 = 0.04e6;
    uint256 constant interestRate3 = 0.09e6;
    uint256 constant interestRate4 = 0.027e6;

    uint256 constant closingFeeRate      = 0;
    uint256 constant lateFeeRate         = 0;
    uint256 constant lateInterestPremium = 0.01e6;

    uint256 constant delegateServiceFeeRate = 0.015e6;
    uint256 constant platformServiceFeeRate = 0.035e6;

    uint256 constant delegateManagementFeeRate = 0.02e6;
    uint256 constant platformManagementFeeRate = 0.08e6;
    uint256 constant managementFeeRate         = delegateManagementFeeRate + platformManagementFeeRate;

    uint256 constant delegateServiceFee1 = principal1 * delegateServiceFeeRate * paymentInterval / 365 days / 1e6;
    uint256 constant delegateServiceFee2 = principal2 * delegateServiceFeeRate * paymentInterval / 365 days / 1e6;

    uint256 constant grossInterest1 = principal1 * interestRate1 * paymentInterval / 365 days / 1e6;
    uint256 constant grossInterest2 = principal2 * interestRate2 * paymentInterval / 365 days / 1e6;
    uint256 constant grossInterest3 = principal3 * interestRate3 * paymentInterval / 365 days / 1e6;
    uint256 constant grossInterest4 = principal4 * interestRate4 * paymentInterval / 365 days / 1e6;

    uint256 constant interest1 = grossInterest1 - grossInterest1 * managementFeeRate / 1e6;
    uint256 constant interest2 = grossInterest2 - grossInterest2 * managementFeeRate / 1e6;
    uint256 constant interest3 = grossInterest3 - grossInterest3 * managementFeeRate / 1e6;
    uint256 constant interest4 = grossInterest4 - grossInterest4 * managementFeeRate / 1e6;

    uint256 runningDeposits = 0;

    uint256 interestToDistribute = 0;

    uint256 runningInterest0 = 0;
    uint256 runningInterest1 = 0;
    uint256 runningInterest2 = 0;
    uint256 runningInterest3 = 0;

    IFixedTermLoanManager ftLoanManager;
    IOpenTermLoanManager  otLoanManager;

    IFixedTermLoan ftLoan1;
    IFixedTermLoan ftLoan2;
    IOpenTermLoan  otLoan3;
    IOpenTermLoan  otLoan4;

    // TODO: Pay off and Call all loans, compare cash balance to total assets.
    // TODO: Revisit this test as a whole, update theoretical values, and add more assertions.

    function setUp() public override {
        super.setUp();

        vm.startPrank(governor);
        globals.setPlatformServiceFeeRate(address(poolManager), platformServiceFeeRate);
        globals.setPlatformManagementFeeRate(address(poolManager), platformManagementFeeRate);
        vm.stopPrank();

        setDelegateManagementFeeRate(address(poolManager), delegateManagementFeeRate);

        ftLoanManager = IFixedTermLoanManager(poolManager.loanManagerList(0));
        otLoanManager = IOpenTermLoanManager(poolManager.loanManagerList(1));

        ftLoan1 = IFixedTermLoan(createFixedTermLoan({
            borrower:   address(borrower1),
            lender:     address(ftLoanManager),
            feeManager: address(fixedTermFeeManager),
            assets:     [address(collateralAsset), address(fundsAsset)],
            terms:      [uint256(gracePeriod), uint256(paymentInterval), uint256(numberOfPayments)],
            amounts:    [uint256(0), uint256(principal1), uint256(principal1)],
            rates:      [uint256(interestRate1), uint256(closingFeeRate), uint256(lateFeeRate), uint256(lateInterestPremium)],
            fees:       [uint256(0), uint256(delegateServiceFee1)]
        }));

        ftLoan2 = IFixedTermLoan(createFixedTermLoan({
            borrower:   address(borrower2),
            lender:     address(ftLoanManager),
            feeManager: address(fixedTermFeeManager),
            assets:     [address(collateralAsset), address(fundsAsset)],
            terms:      [uint256(gracePeriod), uint256(paymentInterval), uint256(numberOfPayments)],
            amounts:    [uint256(0), uint256(principal2), uint256(principal2)],
            rates:      [uint256(interestRate2), uint256(closingFeeRate), uint256(lateFeeRate), uint256(lateInterestPremium)],
            fees:       [uint256(0), uint256(delegateServiceFee2)]
        }));

        otLoan3 = IOpenTermLoan(createOpenTermLoan({
            borrower:  address(borrower3),
            lender:    address(otLoanManager),
            asset:     address(fundsAsset),
            principal: uint256(principal3),
            terms:     [uint32(gracePeriod), uint32(noticePeriod), uint32(paymentInterval)],
            rates:     [uint64(delegateServiceFeeRate), uint64(interestRate3), uint64(lateFeeRate), uint64(lateInterestPremium)]
        }));

        otLoan4 = IOpenTermLoan(createOpenTermLoan({
            borrower:  address(borrower4),
            lender:    address(otLoanManager),
            asset:     address(fundsAsset),
            principal: uint256(principal4),
            terms:     [uint32(gracePeriod), uint32(noticePeriod), uint32(paymentInterval)],
            rates:     [uint64(delegateServiceFeeRate), uint64(interestRate4), uint64(lateFeeRate), uint64(lateInterestPremium)]
        }));
    }

    function test_4loans_3lps() external {
        // 0th month
        vm.warp(start + 0 * paymentInterval);

        deposit(address(pool), lp0, deposit0);
        runningDeposits += deposit0;

        fundLoan(address(ftLoan1));
        interestToDistribute += interest1;

        assertApproxEqAbs(ftLoanManager.assetsUnderManagement(), principal1, 0);
        assertApproxEqAbs(otLoanManager.assetsUnderManagement(), 0,          0);

        assertApproxEqAbs(poolManager.totalAssets(), deposit0, 0);

        // 1st month
        vm.warp(start + 1 * paymentInterval);

        makePayment(address(ftLoan1));
        runningInterest0 += interestToDistribute;

        deposit(address(pool), lp1, deposit1);
        runningDeposits += deposit1;

        fundLoan(address(otLoan3));
        interestToDistribute += interest3;

        assertApproxEqAbs(ftLoanManager.assetsUnderManagement(), principal1, 0);
        assertApproxEqAbs(otLoanManager.assetsUnderManagement(), principal3, 0);

        assertApproxEqAbs(poolManager.totalAssets(), deposit0 + deposit1 + 1 * interest1, 0);

        // 2nd month
        vm.warp(start + 2 * paymentInterval);

        makePayment(address(ftLoan1));
        makePayment(address(otLoan3));
        runningInterest0 += interestToDistribute * deposit0 / runningDeposits;
        runningInterest1 += interestToDistribute * deposit1 / runningDeposits;

        deposit(address(pool), lp2, deposit2);
        runningDeposits += deposit2;

        fundLoan(address(ftLoan2));
        interestToDistribute += interest2;

        assertApproxEqAbs(ftLoanManager.assetsUnderManagement(), principal1 + principal2, 0);
        assertApproxEqAbs(otLoanManager.assetsUnderManagement(), principal3,              0);

        assertApproxEqAbs(poolManager.totalAssets(), deposit0 + deposit1 + deposit2 + 2 * interest1 + 1 * interest3, 0);

        // 3rd month
        vm.warp(start + 3 * paymentInterval);

        makePayment(address(ftLoan1));
        makePayment(address(ftLoan2));
        makePayment(address(otLoan3));

        runningInterest0 += interestToDistribute * deposit0 / runningDeposits;
        runningInterest1 += interestToDistribute * deposit1 / runningDeposits;
        runningInterest2 += interestToDistribute * deposit2 / runningDeposits;

        deposit(address(pool), lp3, deposit3);
        runningDeposits += deposit3;

        fundLoan(address(otLoan4));
        interestToDistribute += interest4;

        assertApproxEqAbs(ftLoanManager.assetsUnderManagement(), principal1 + principal2, 1);
        assertApproxEqAbs(otLoanManager.assetsUnderManagement(), principal3 + principal4, 0);

        assertApproxEqAbs(poolManager.totalAssets(), deposits + 3 * interest1 + 1 * interest2 + 2 * interest3, 2);

        // 4th month
        vm.warp(start + 4 * paymentInterval);

        makePayment(address(ftLoan1));
        makePayment(address(ftLoan2));
        makePayment(address(otLoan3));
        makePayment(address(otLoan4));

        runningInterest0 += interestToDistribute * deposit0 / runningDeposits;
        runningInterest1 += interestToDistribute * deposit1 / runningDeposits;
        runningInterest2 += interestToDistribute * deposit2 / runningDeposits;
        runningInterest3 += interestToDistribute * deposit3 / runningDeposits;

        assertApproxEqAbs(ftLoanManager.assetsUnderManagement(), principal1 + principal2, 2);
        assertApproxEqAbs(otLoanManager.assetsUnderManagement(), principal3 + principal4, 1);

        assertApproxEqAbs(poolManager.totalAssets(), deposits + 4 * interest1 + 2 * interest2 + 3 * interest3 + 1 * interest4, 5);

        // 5th month
        vm.warp(start + 5 * paymentInterval);

        makePayment(address(ftLoan1));
        makePayment(address(ftLoan2));
        makePayment(address(otLoan3));
        makePayment(address(otLoan4));

        runningInterest0 += interestToDistribute * deposit0 / runningDeposits;
        runningInterest1 += interestToDistribute * deposit1 / runningDeposits;
        runningInterest2 += interestToDistribute * deposit2 / runningDeposits;
        runningInterest3 += interestToDistribute * deposit3 / runningDeposits;

        assertApproxEqAbs(ftLoanManager.assetsUnderManagement(), principal1 + principal2, 3);
        assertApproxEqAbs(otLoanManager.assetsUnderManagement(), principal3 + principal4, 2);

        assertApproxEqAbs(poolManager.totalAssets(), deposits + 5 * interest1 + 3 * interest2 + 4 * interest3 + 2 * interest4, 8);

        // 6th month
        vm.warp(start + 6 * paymentInterval);

        makePayment(address(ftLoan1));
        makePayment(address(ftLoan2));
        makePayment(address(otLoan3));
        makePayment(address(otLoan4));

        runningInterest0 += interestToDistribute * deposit0 / runningDeposits;
        runningInterest1 += interestToDistribute * deposit1 / runningDeposits;
        runningInterest2 += interestToDistribute * deposit2 / runningDeposits;
        runningInterest3 += interestToDistribute * deposit3 / runningDeposits;

        assertApproxEqAbs(ftLoanManager.assetsUnderManagement(), principal1 + principal2, 4);
        assertApproxEqAbs(otLoanManager.assetsUnderManagement(), principal3 + principal4, 3);

        assertApproxEqAbs(poolManager.totalAssets(), deposits + 6 * interest1 + 4 * interest2 + 5 * interest3 + 3 * interest4, 11);

        // Request all withdrawals.
        requestRedeem(address(pool), lp1, pool.balanceOf(lp1));
        requestRedeem(address(pool), lp2, pool.balanceOf(lp2));
        requestRedeem(address(pool), lp3, pool.balanceOf(lp3));

        // Perform all redemptions.
        vm.warp(start + 6 * paymentInterval + 10 days);

        runningInterest0 += interestToDistribute / 3 * deposit0 / runningDeposits;
        runningInterest1 += interestToDistribute / 3 * deposit1 / runningDeposits;
        runningInterest2 += interestToDistribute / 3 * deposit2 / runningDeposits;
        runningInterest3 += interestToDistribute / 3 * deposit3 / runningDeposits;

        redeem(address(pool), lp1, withdrawalManager.lockedShares(lp1));
        redeem(address(pool), lp2, withdrawalManager.lockedShares(lp2));
        redeem(address(pool), lp3, withdrawalManager.lockedShares(lp3));

        assertEq(pool.balanceOf(lp1), 0);
        assertEq(pool.balanceOf(lp2), 0);
        assertEq(pool.balanceOf(lp3), 0);

        assertApproxEqAbs(fundsAsset.balanceOf(lp1), deposit1 + runningInterest1, 1e6);
        assertApproxEqAbs(fundsAsset.balanceOf(lp2), deposit2 + runningInterest2, 1e6);
        assertApproxEqAbs(fundsAsset.balanceOf(lp3), deposit3 + runningInterest3, 1e6);
    }

}
