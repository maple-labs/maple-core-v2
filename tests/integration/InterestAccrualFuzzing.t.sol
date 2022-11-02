// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { Address, console  } from "../../modules/contract-test-utils/contracts/test.sol";
import { MapleLoan as Loan } from "../../modules/loan/contracts/MapleLoan.sol";

import { TestBaseWithAssertions } from "../../contracts/utilities/TestBaseWithAssertions.sol";

import { LoanActionGenerator } from "../../contracts/actions/LoanActionGenerator.sol";

import { ActionHandler } from "../../contracts/ActionHandler.sol";
import { LoanScenario  } from "../../contracts/LoanScenario.sol";

import { ILoanLike, ILoanActionLike } from "../../contracts/interfaces/Interfaces.sol";

contract ClaimTestsSingleLoanInterestOnly is ActionHandler, TestBaseWithAssertions {

    address borrower;
    address lp;

    uint256 lastUpdated;

    LoanScenario[] scenarios;

    mapping(address => uint256) lateInterestAmount;
    mapping(address => uint256) scenarioForLoan;

    mapping(uint256 => uint256[]) paymentTimestamps;  // Scenario ID => Payment timestamps TODO Change to loan address

    function setUp() public override {
        super.setUp();

        borrower = address(new Address());
        lp       = address(new Address());
    }

    function testFuzz_interestAccrual(uint256 seed) public {

        seed = constrictToRange(seed, 0, 1e29);

        vm.startPrank(governor);
        globals.setPlatformOriginationFeeRate(address(poolManager), constrictToRange(hashed(seed + 1), 0, 0.5e6));
        globals.setPlatformServiceFeeRate(address(poolManager),     constrictToRange(hashed(seed + 2), 0, 0.5e6));
        globals.setPlatformManagementFeeRate(address(poolManager),  constrictToRange(hashed(seed + 3), 0, 0.5e6));
        vm.stopPrank();

        vm.prank(poolDelegate);
        poolManager.setDelegateManagementFeeRate(constrictToRange(hashed(seed + 4), 0, 0.5e6));

        uint256 numberOfLoans = constrictToRange(hashed(seed + 5), 1, 70);

        // 1. Create all loans, with fuzzed terms and fuzzed payment schedules.
        for (uint256 scenario; scenario < numberOfLoans; ++scenario) {
            ILoanLike loan = ILoanLike(_createLoan(hashed(seed + scenario)));

            scenarioForLoan[address(loan)] = scenario;

            // Create the loan
            scenarios.push(new LoanScenario({
                loan_:              address(loan),
                poolManager_:       address(poolManager),
                liquidatorFactory_: address(liquidatorFactory),
                fundingTime_:       start + constrictToRange(hashed(seed + scenario), 0, 365 days),
                name_:              string(abi.encodePacked("loan-", convertUintToString(scenario + 1)))
            }));

            // Set all the payment offsets, saving the timestamps for the test
            for (uint256 payment = 1; payment <= loan.paymentsRemaining(); ++payment) {
                int256 paymentOffset = int256(constrictToRange(hashed(hashed(seed + scenario) + payment), 0, loan.paymentInterval() / 2 - 1));  // TODO: Do larger range later, investigate limiting negative to paymentInterval

                paymentOffset = payment & 1 == 0 ? paymentOffset : -paymentOffset;  // 50% chance of negative

                scenarios[scenario].setPaymentOffset(payment, paymentOffset);

                paymentTimestamps[scenario].push(uint256(int256(scenarios[scenario].fundingTime() + loan.paymentInterval() * payment) + paymentOffset));
            }
        }

        LoanActionGenerator generator_ = new LoanActionGenerator();

        uint256 totalLiquidityRequired = 0;

        // 2. Calculate the total amount of liquidity required for all loans.
        for (uint256 i; i < scenarios.length; i++) {
            add(generator_.generateActions(scenarios[i]));
            totalLiquidityRequired += scenarios[i].loan().principalRequested();
        }

        // 3. Deposit into pool.
        depositLiquidity(lp, totalLiquidityRequired);

        // 4. Sort all loan actions by timestamp.
        _sort();

        // 5. Execute all loan actions, asserting that the loan state is correct after each action.
        for (uint256 i; i < actions.length; i++) {
            ILoanActionLike action = ILoanActionLike(address(actions[i]));

            vm.warp(action.timestamp());

            ILoanLike loan = action.loan();

            uint256 outstandingInterest;
            uint256 earliestPaymentDueDate;

            // Calculate the earliest payment in the sorted list naively.
            for (uint256 j; j < scenarios.length; ++j) {
                uint256 nextPaymentDueDate = scenarios[j].loan().nextPaymentDueDate();

                // If the due date is past the last updated timestamp, is earlier than cached and is not 0, cache it.
                if (
                    nextPaymentDueDate > 0 &&
                    (earliestPaymentDueDate == 0 || nextPaymentDueDate < earliestPaymentDueDate) &&
                    nextPaymentDueDate >= lastUpdated
                ) {
                    earliestPaymentDueDate = nextPaymentDueDate;
                }
            }

            // For each loan, calculate the theoretical interest that should have been accrued and aggregate it.
            for (uint256 j; j < scenarios.length; ++j) {
                outstandingInterest += getCurrentOutstandingInterest(address(scenarios[j].loan()), earliestPaymentDueDate);
            }

            // Assert that the theoretical interest is equal to the actual interest, within a small delta.
            assertWithinDiff(loanManager.getAccruedInterest() + loanManager.accountedInterest(), outstandingInterest, actions.length);  // TODO: Better define acceptable diff, potentially add positive/negative assertion

            uint256 previousPaymentDueDate = loan.nextPaymentDueDate();

            bool isLate = loan.nextPaymentDueDate() != 0 && action.timestamp() > loan.nextPaymentDueDate();

            action.act();

            lastUpdated = block.timestamp;  // Save the last updated timestamp locally.

            if (!isLate || loan.nextPaymentDueDate() == 0) {
                lateInterestAmount[address(loan)] = 0;
                continue;
            }

            // If the loan is late, calculate the theoretical interest that should have been accrued into the next interval and save it.
            ( , uint256[3] memory interestArray, ) = loan.getNextPaymentDetailedBreakdown();

            uint256 netInterest = interestArray[0] * (1e6 - globals.platformManagementFeeRate(address(poolManager)) - poolManager.delegateManagementFeeRate()) / 1e6;

            lateInterestAmount[address(loan)] =
                action.timestamp() - previousPaymentDueDate > loan.paymentInterval()
                    ? netInterest
                    : netInterest * (action.timestamp() - previousPaymentDueDate) / loan.paymentInterval();

            assertWithinDiff(loanManager.getAccruedInterest(), 0, 1);
        }
    }

    function _createLoan(uint256 seed_) internal returns (address loan_) {
        uint256 paymentInterval     = constrictToRange(hashed(seed_),     1 days, 60 days);
        uint256 numberOfPayments    = constrictToRange(hashed(seed_ + 1), 1,      10);
        uint256 startingPrincipal   = constrictToRange(hashed(seed_ + 2), 1e6,    1e29);
        uint256 endingPrincipal     = constrictToRange(hashed(seed_ + 3), 0,      startingPrincipal);
        uint256 interestRate        = constrictToRange(hashed(seed_ + 4), 0,      0.3e18);
        uint256 lateInterestPremium = constrictToRange(hashed(seed_ + 5), 0,      0.1e18);
        uint256 lateFeeRate         = constrictToRange(hashed(seed_ + 6), 0,      0.1e18);

        nextDelegateOriginationFee = constrictToRange(hashed(seed_ + 7), 0, startingPrincipal / 10);
        nextDelegateServiceFee     = constrictToRange(hashed(seed_ + 8), 0, startingPrincipal / 100);

        return address(createLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(0), paymentInterval, numberOfPayments],
            amounts:     [uint256(0), startingPrincipal, endingPrincipal],
            rates:       [interestRate, uint256(0), lateFeeRate, lateInterestPremium]
        }));
    }

    function getCurrentOutstandingInterest(address loan_, uint256 earliestPaymentDueDate) internal view returns (uint256 interestAccrued_) {
        ILoanLike loan = ILoanLike(loan_);

        if (loan.nextPaymentDueDate() == 0) return 0;

        ( , uint256[3] memory interestArray, ) = loan.getNextPaymentDetailedBreakdown();

        uint256 fundingTime = scenarios[scenarioForLoan[loan_]].fundingTime();

        uint256 numberOfPaymentsMade = (loan.nextPaymentDueDate() - fundingTime) / loan.paymentInterval() - 1;

        uint256 netInterest = interestArray[0] * (1e6 - globals.platformManagementFeeRate(address(poolManager)) - poolManager.delegateManagementFeeRate()) / 1e6;

        uint256 startDate;

        // If no payments have been made yet, set start date to funding time.
        if (numberOfPaymentsMade == 0) {
            startDate = fundingTime;
        } else {
            startDate = paymentTimestamps[scenarioForLoan[loan_]][numberOfPaymentsMade - 1];  // Payments are 0-indexed (i.e., Payment 1 is at index 0).
        }

        uint256 endDate = min(block.timestamp, min(earliestPaymentDueDate, loan.nextPaymentDueDate()));

        uint256 intervalLength = max(loan.nextPaymentDueDate() - startDate, loan.paymentInterval());

        interestAccrued_ =
            endDate < startDate
                ? netInterest
                : netInterest * (endDate - startDate) / intervalLength;

        interestAccrued_ += lateInterestAmount[address(loan)];
    }

    function hashed(uint256 value_) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(value_)));
    }

    function max(uint256 a_, uint256 b_) internal pure returns (uint256 maximum_) {
        maximum_ = a_ > b_ ? a_ : b_;
    }

    function min(uint256 a_, uint256 b_) internal pure returns (uint256 minimum_) {
        minimum_ = a_ < b_ ? a_ : b_;
    }

}
