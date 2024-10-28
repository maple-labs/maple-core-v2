// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IOpenTermLoan, IOpenTermLoanManager } from "../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

// NOTE: Highlights previous bug where if +ve principal increase then UL decreases too much by the Δ amount
//       If -ve principal decrease then UL increases too much by the Δ amount
contract RefinanceScenariosTests is TestBaseWithAssertions {

    address immutable borrower1 = makeAddr("borrower1");
    address immutable borrower2 = makeAddr("borrower2");
    address immutable lp        = makeAddr("lp");

    uint256 constant initialDeposit = 5_000_000e6;

    // Loan Parameters
    uint256 constant interestRate1            = 0.02e6;
    uint256 constant interestRate2            = 0.04e6;
    uint256 constant lateInterestPremiumRate1 = interestRate1;
    uint256 constant lateInterestPremiumRate2 = interestRate2;

    uint256 constant gracePeriod     = 3 days;
    uint256 constant noticePeriod    = 5 days;
    uint256 constant paymentInterval = 30 days;

    uint256 constant principal1 = 1_000_000e6;
    uint256 constant principal2 = 1_500_000e6;

    // Fees
    uint256 constant delegateServiceFeeRate    = 0.04e6;
    uint256 constant delegateManagementFeeRate = 0.02e6;
    uint256 constant platformServiceFeeRate    = 0.01e6;
    uint256 constant platformManagementFeeRate = 0.08e6;
    uint256 constant managementFeeRate         = delegateManagementFeeRate + platformManagementFeeRate;

    // Expected Values
    uint256 cash = initialDeposit - principal1 - principal2;

    uint256 grossInterest1 = principal1 * interestRate1 * paymentInterval / 365 days / 1e6;
    uint256 grossInterest2 = principal2 * interestRate2 * paymentInterval / 365 days / 1e6;

    uint256 netInterest1 = grossInterest1 - (grossInterest1 * managementFeeRate / 1e6);
    uint256 netInterest2 = grossInterest2 - (grossInterest2 * managementFeeRate / 1e6);

    uint256 issuanceRate1 = netInterest1 * 1e27 / paymentInterval;
    uint256 issuanceRate2 = netInterest2 * 1e27 / paymentInterval;

    uint256 cashPaidToPool;
    uint256 delegateManagementFee;
    uint256 platformManagementFee;

    IOpenTermLoanManager otLoanManager;

    IOpenTermLoan otLoan1;
    IOpenTermLoan otLoan2;

    function setUp() override public {
        super.setUp();

        vm.startPrank(governor);
        globals.setPlatformServiceFeeRate(address(poolManager), platformServiceFeeRate);
        globals.setPlatformManagementFeeRate(address(poolManager), platformManagementFeeRate);
        vm.stopPrank();

        setDelegateManagementFeeRate(address(poolManager), delegateManagementFeeRate);

        otLoanManager = IOpenTermLoanManager(poolManager.loanManagerList(1));

        // NOTE: No lateFeeRate and lateInterestPremiumRate is the same as the interestRate
        otLoan1 = IOpenTermLoan(createOpenTermLoan({
            borrower:  address(borrower1),
            lender:    address(otLoanManager),
            asset:     address(fundsAsset),
            principal: uint256(principal1),
            terms:     [uint32(gracePeriod), uint32(noticePeriod), uint32(paymentInterval)],
            rates:     [uint64(delegateServiceFeeRate), uint64(interestRate1), uint64(0), uint64(lateInterestPremiumRate1)]
        }));

        otLoan2 = IOpenTermLoan(createOpenTermLoan({
            borrower:  address(borrower2),
            lender:    address(otLoanManager),
            asset:     address(fundsAsset),
            principal: uint256(principal2),
            terms:     [uint32(gracePeriod), uint32(noticePeriod), uint32(paymentInterval)],
            rates:     [uint64(delegateServiceFeeRate), uint64(interestRate2), uint64(0), uint64(lateInterestPremiumRate2)]
        }));

        deposit(address(pool), lp, initialDeposit);
    }

    function test_impairOTL_refinanceToLowerPrincipal_singleLoanImpaired() external {
        // Fund the loans
        fundLoan(address(otLoan1));
        fundLoan(address(otLoan2));

        vm.warp(start + 15 days);

        uint256 expectedInterest = (issuanceRate1 + issuanceRate2) * 15 days / 1e27;

        // Impair the loan
        impairLoan(address(otLoan1));

        uint256 otLoan1UnrealizedLosses = principal1 + issuanceRate1 * 15 days / 1e27;

        assertPoolState({
            pool:               address(pool),
            totalSupply:        initialDeposit,
            totalAssets:        initialDeposit + ((issuanceRate1 + issuanceRate2) * 15 days / 1e27),
            unrealizedLosses:   otLoan1UnrealizedLosses,
            availableLiquidity: cash
        });

        assertOpenTermLoan({
            loan:            address(otLoan1),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    start + 15 days,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal1
        });

        assertOpenTermLoan({
            loan:            address(otLoan2),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal2
        });

        assertOpenTermLoanManager({
            loanManager:       address(otLoanManager),
            domainStart:       start + 15 days,
            issuanceRate:      issuanceRate2,
            accountedInterest: expectedInterest,
            accruedInterest:   0,
            principalOut:      principal1 + principal2,
            unrealizedLosses:  otLoan1UnrealizedLosses
        });

        assertOpenTermPaymentInfo({
            loan:            address(otLoan1),
            platformFeeRate: platformManagementFeeRate,
            delegateFeeRate: delegateManagementFeeRate,
            startDate:       start,
            issuanceRate:    issuanceRate1
        });

        assertOpenTermPaymentInfo({
            loan:            address(otLoan2),
            platformFeeRate: platformManagementFeeRate,
            delegateFeeRate: delegateManagementFeeRate,
            startDate:       start,
            issuanceRate:    issuanceRate2
        });

        assertImpairment({
            loan:               address(otLoan1),
            impairedDate:       start + 15 days,
            impairedByGovernor: false
        });

        // Warp to day 20 and refinance loan 1 to a lower principal
        vm.warp(start + 20 days);

        uint256 decreasePrincipalBy = 600_000e6;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("decreasePrincipal(uint256)",  decreasePrincipalBy);

        uint256 interestPayment      = principal1 * interestRate1 * 20 days / 365 days / 1e6;
        uint256 lateInterestPayment  = principal1 * lateInterestPremiumRate1 * 5 days / 365 days / 1e6;
        uint256 totalInterestPayment = interestPayment + lateInterestPayment;
        uint256 serviceFees          = principal1 * (delegateServiceFeeRate + platformServiceFeeRate) * 20 days / 365 days / 1e6;

        // Borrower must send enough to cover the principal + interest + fees
        fundsAsset.mint(address(borrower1), decreasePrincipalBy + interestPayment + lateInterestPayment + serviceFees);

        vm.prank(borrower1);
        fundsAsset.approve(address(otLoan1), decreasePrincipalBy + interestPayment + lateInterestPayment + serviceFees);

        proposeRefinance(address(otLoan1), address(openTermRefinancer), block.timestamp + 1, calls);

        acceptRefinanceOT(address(otLoan1), address(openTermRefinancer), block.timestamp + 1, calls);

        // Calculate new issuance rate for otLoan1
        grossInterest1 = (principal1 - decreasePrincipalBy) * interestRate1 * paymentInterval / 365 days / 1e6;
        netInterest1   = grossInterest1 - (grossInterest1 * managementFeeRate / 1e6);
        issuanceRate1  = netInterest1 * 1e27 / paymentInterval;

        // Assert Pool, LM, and Loan state
        platformManagementFee = totalInterestPayment * platformManagementFeeRate / 1e6;
        delegateManagementFee = totalInterestPayment * delegateManagementFeeRate / 1e6;
        cashPaidToPool        = totalInterestPayment - (platformManagementFee + delegateManagementFee);

        expectedInterest = issuanceRate2 * 20 days / 1e27;

        assertPoolState({
            pool:               address(pool),
            totalSupply:        initialDeposit,
            totalAssets:        initialDeposit + expectedInterest + cashPaidToPool,
            unrealizedLosses:   0,
            availableLiquidity: cash + decreasePrincipalBy + cashPaidToPool
        });

        assertOpenTermLoan({
            loan:            address(otLoan1),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    0,
            datePaid:        start + 20 days,
            calledPrincipal: 0,
            principal:       principal1 - decreasePrincipalBy
        });

        assertOpenTermLoan({
            loan:            address(otLoan2),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal2
        });

        assertOpenTermLoanManager({
            loanManager:       address(otLoanManager),
            domainStart:       start + 20 days,
            issuanceRate:      issuanceRate1 + issuanceRate2,
            accountedInterest: expectedInterest,
            accruedInterest:   0,
            principalOut:      principal1 - decreasePrincipalBy + principal2,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            address(otLoan1),
            platformFeeRate: platformManagementFeeRate,
            delegateFeeRate: delegateManagementFeeRate,
            startDate:       start + 20 days,
            issuanceRate:    issuanceRate1
        });

        assertOpenTermPaymentInfo({
            loan:            address(otLoan2),
            platformFeeRate: platformManagementFeeRate,
            delegateFeeRate: delegateManagementFeeRate,
            startDate:       start,
            issuanceRate:    issuanceRate2
        });

        assertImpairment({
            loan:               address(otLoan1),
            impairedDate:       0,
            impairedByGovernor: false
        });
    }

    // NOTE: Same assertions as test_impairOTL_refinanceToLowerPrincipal_singleLoanImpaired until refinance
    function test_impairOTL_refinanceToHigherPrincipal_oneLoanImpaired_underflow() external {
        // Fund the loans
        fundLoan(address(otLoan1));
        fundLoan(address(otLoan2));

        vm.warp(start + 15 days);

        uint256 expectedInterest;

        // Impair the loan
        impairLoan(address(otLoan1));

        // Warp to day 20 and refinance loan 1 to a higher principal
        vm.warp(start + 20 days);

        uint256 increasePrincipalBy = 600_000e6;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("increasePrincipal(uint256)",  increasePrincipalBy);

        uint256 interestPayment      = principal1 * interestRate1 * 20 days / 365 days / 1e6;
        uint256 lateInterestPayment  = principal1 * lateInterestPremiumRate1 * 5 days / 365 days / 1e6;
        uint256 totalInterestPayment = interestPayment + lateInterestPayment;
        uint256 serviceFees          = principal1 * (delegateServiceFeeRate + platformServiceFeeRate) * 20 days / 365 days / 1e6;

        // Borrower must send enough to cover the principal + interest + fees
        fundsAsset.mint(address(borrower1), interestPayment + lateInterestPayment + serviceFees);

        vm.prank(borrower1);
        fundsAsset.approve(address(otLoan1), interestPayment + lateInterestPayment + serviceFees);

        proposeRefinance(address(otLoan1), address(openTermRefinancer), block.timestamp + 1, calls);

        acceptRefinanceOT(address(otLoan1), address(openTermRefinancer), block.timestamp + 1, calls);

        // Calculate new issuance rate for otLoan1
        grossInterest1 = (principal1 + increasePrincipalBy) * interestRate1 * paymentInterval / 365 days / 1e6;
        netInterest1   = grossInterest1 - (grossInterest1 * managementFeeRate / 1e6);
        issuanceRate1  = netInterest1 * 1e27 / paymentInterval;

        // Assert Pool, LM, and Loan state
        platformManagementFee = totalInterestPayment * platformManagementFeeRate / 1e6;
        delegateManagementFee = totalInterestPayment * delegateManagementFeeRate / 1e6;
        cashPaidToPool        = totalInterestPayment - (platformManagementFee + delegateManagementFee);

        expectedInterest = issuanceRate2 * 20 days / 1e27;

        assertPoolState({
            pool:               address(pool),
            totalSupply:        initialDeposit,
            totalAssets:        initialDeposit + expectedInterest + cashPaidToPool,
            unrealizedLosses:   0,  // NOTE: Unrealized losses get clamped to zero if risk of underflow
            availableLiquidity: cash - increasePrincipalBy + cashPaidToPool
        });

        assertOpenTermLoan({
            loan:            address(otLoan1),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    0,
            datePaid:        start + 20 days,
            calledPrincipal: 0,
            principal:       principal1 + increasePrincipalBy
        });

        assertOpenTermLoan({
            loan:            address(otLoan2),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal2
        });

        assertOpenTermLoanManager({
            loanManager:       address(otLoanManager),
            domainStart:       start + 20 days,
            issuanceRate:      issuanceRate1 + issuanceRate2,
            accountedInterest: expectedInterest,
            accruedInterest:   0,
            principalOut:      principal1 + increasePrincipalBy + principal2,
            unrealizedLosses:  0  // NOTE: This went "negative" and got clamped to zero when bug was present
        });

        assertOpenTermPaymentInfo({
            loan:            address(otLoan1),
            platformFeeRate: platformManagementFeeRate,
            delegateFeeRate: delegateManagementFeeRate,
            startDate:       start + 20 days,
            issuanceRate:    issuanceRate1
        });

        assertOpenTermPaymentInfo({
            loan:            address(otLoan2),
            platformFeeRate: platformManagementFeeRate,
            delegateFeeRate: delegateManagementFeeRate,
            startDate:       start,
            issuanceRate:    issuanceRate2
        });

        assertImpairment({
            loan:               address(otLoan1),
            impairedDate:       0,
            impairedByGovernor: false
        });
    }

    function test_impairOTL_refinanceToHigherPrincipal_twoLoansImpaired() external {
        // Fund the loans
        fundLoan(address(otLoan1));
        fundLoan(address(otLoan2));

        vm.warp(start + 15 days);

        uint256 expectedInterest = (issuanceRate1 + issuanceRate2) * 15 days / 1e27;

        // Impair both loans
        impairLoan(address(otLoan1));
        impairLoan(address(otLoan2));

        uint256 otLoan1UnrealizedLosses = principal1 + issuanceRate1 * 15 days / 1e27;
        uint256 otLoan2UnrealizedLosses = principal2 + issuanceRate2 * 15 days / 1e27;

        assertPoolState({
            pool:               address(pool),
            totalSupply:        initialDeposit,
            totalAssets:        initialDeposit + ((issuanceRate1 + issuanceRate2) * 15 days / 1e27),
            unrealizedLosses:   otLoan1UnrealizedLosses + otLoan2UnrealizedLosses,
            availableLiquidity: cash
        });

        assertOpenTermLoan({
            loan:            address(otLoan1),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    start + 15 days,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal1
        });

        assertOpenTermLoan({
            loan:            address(otLoan2),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    start + 15 days,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal2
        });

        assertOpenTermLoanManager({
            loanManager:       address(otLoanManager),
            domainStart:       start + 15 days,
            issuanceRate:      0,
            accountedInterest: expectedInterest,
            accruedInterest:   0,
            principalOut:      principal1 + principal2,
            unrealizedLosses:  otLoan1UnrealizedLosses + otLoan2UnrealizedLosses
        });

        assertOpenTermPaymentInfo({
            loan:            address(otLoan1),
            platformFeeRate: platformManagementFeeRate,
            delegateFeeRate: delegateManagementFeeRate,
            startDate:       start,
            issuanceRate:    issuanceRate1
        });

        assertOpenTermPaymentInfo({
            loan:            address(otLoan2),
            platformFeeRate: platformManagementFeeRate,
            delegateFeeRate: delegateManagementFeeRate,
            startDate:       start,
            issuanceRate:    issuanceRate2
        });

        assertImpairment({
            loan:               address(otLoan1),
            impairedDate:       start + 15 days,
            impairedByGovernor: false
        });

        assertImpairment({
            loan:               address(otLoan2),
            impairedDate:       start + 15 days,
            impairedByGovernor: false
        });

        // Warp to day 20 and refinance loan 1 to a higher principal
        vm.warp(start + 20 days);

        uint256 increasePrincipalBy = 600_000e6;

        bytes[] memory calls = new bytes[](1);
        calls[0] = abi.encodeWithSignature("increasePrincipal(uint256)",  increasePrincipalBy);

        uint256 interestPayment      = principal1 * interestRate1 * 20 days / 365 days / 1e6;
        uint256 lateInterestPayment  = principal1 * lateInterestPremiumRate1 * 5 days / 365 days / 1e6;
        uint256 totalInterestPayment = interestPayment + lateInterestPayment;
        uint256 serviceFees          = principal1 * (delegateServiceFeeRate + platformServiceFeeRate) * 20 days / 365 days / 1e6;

        // Borrower must send enough to cover the principal + interest + fees
        fundsAsset.mint(address(borrower1), interestPayment + lateInterestPayment + serviceFees);

        vm.prank(borrower1);
        fundsAsset.approve(address(otLoan1), interestPayment + lateInterestPayment + serviceFees);

        proposeRefinance(address(otLoan1), address(openTermRefinancer), block.timestamp + 1, calls);

        acceptRefinanceOT(address(otLoan1), address(openTermRefinancer), block.timestamp + 1, calls);

        // Calculate new issuance rate for otLoan1
        grossInterest1 = (principal1 + increasePrincipalBy) * interestRate1 * paymentInterval / 365 days / 1e6;
        netInterest1   = grossInterest1 - (grossInterest1 * managementFeeRate / 1e6);
        issuanceRate1  = netInterest1 * 1e27 / paymentInterval;

        // Assert Pool, LM, and Loan state
        platformManagementFee = totalInterestPayment * platformManagementFeeRate / 1e6;
        delegateManagementFee = totalInterestPayment * delegateManagementFeeRate / 1e6;
        cashPaidToPool        = totalInterestPayment - (platformManagementFee + delegateManagementFee);

        expectedInterest = issuanceRate2 * 15 days / 1e27;

        // NOTE: When the bug was present the UL was reduced by the principal + principal increase amount, resulting in a smaller UL.
        assertPoolState({
            pool:               address(pool),
            totalSupply:        initialDeposit,
            totalAssets:        initialDeposit + expectedInterest + cashPaidToPool,
            unrealizedLosses:   otLoan2UnrealizedLosses,
            availableLiquidity: cash - increasePrincipalBy + cashPaidToPool
        });

        assertOpenTermLoan({
            loan:            address(otLoan1),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    0,
            datePaid:        start + 20 days,
            calledPrincipal: 0,
            principal:       principal1 + increasePrincipalBy
        });

        assertOpenTermLoan({
            loan:            address(otLoan2),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    start + 15 days,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       principal2
        });

        assertOpenTermLoanManager({
            loanManager:       address(otLoanManager),
            domainStart:       start + 20 days,
            issuanceRate:      issuanceRate1,
            accountedInterest: expectedInterest,
            accruedInterest:   0,
            principalOut:      principal1 + increasePrincipalBy + principal2,
            unrealizedLosses:  otLoan2UnrealizedLosses
        });

        assertOpenTermPaymentInfo({
            loan:            address(otLoan1),
            platformFeeRate: platformManagementFeeRate,
            delegateFeeRate: delegateManagementFeeRate,
            startDate:       start + 20 days,
            issuanceRate:    issuanceRate1
        });

        assertOpenTermPaymentInfo({
            loan:            address(otLoan2),
            platformFeeRate: platformManagementFeeRate,
            delegateFeeRate: delegateManagementFeeRate,
            startDate:       start,
            issuanceRate:    issuanceRate2
        });

        assertImpairment({
            loan:               address(otLoan1),
            impairedDate:       0,
            impairedByGovernor: false
        });
    }

}
