// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IOpenTermLoan, IOpenTermLoanManager } from "../../contracts/interfaces/Interfaces.sol";

import { FuzzedSetup }     from "./FuzzedSetup.sol";
import { StorageSnapshot } from "./StorageSnapshot.sol";

contract OpenTermLoanFuzz is FuzzedSetup, StorageSnapshot {

    uint256 constant ACTION_COUNT   = 10;
    uint256 constant FTL_LOAN_COUNT = 5;
    uint256 constant OTL_LOAN_COUNT = 5;

    IOpenTermLoan        loan;
    IOpenTermLoanManager loanManager;

    OpenTermLoanManagerStorage loanManagerStorage;
    OpenTermLoanStorage        loanStorage;
    OpenTermPaymentStorage     paymentStorage;
    PoolManagerStorage         poolManagerStorage;

    function setUp() public override {
        super.setUp();

        loanManager = IOpenTermLoanManager(_openTermLoanManager);
    }

    function testFuzz_call_otl(uint256 seed) external {
        fuzzedSetup(FTL_LOAN_COUNT, OTL_LOAN_COUNT, ACTION_COUNT, seed);

        loan = IOpenTermLoan(getSomeActiveOpenTermLoan());

        // Do nothing if no loan is available.
        if (address(loan) == address(0)) return;

        // Cache the state.
        uint256 borrowerBalance = fundsAsset.balanceOf(loan.borrower());
        uint256 delegateBalance = fundsAsset.balanceOf(address(poolManager.poolDelegate()));
        uint256 poolBalance     = fundsAsset.balanceOf(address(pool));
        uint256 treasuryBalance = fundsAsset.balanceOf(address(treasury));

        loanManagerStorage = _snapshotOpenTermLoanManager(loanManager);
        loanStorage        = _snapshotOpenTermLoan(loan);
        paymentStorage     = _snapshotOpenTermPayment(loan);
        poolManagerStorage = _snapshotPoolManager(poolManager);

        // Perform the action.
        address poolDelegate    = poolManager.poolDelegate();
        uint256 calledPrincipal = bound(seed, 1, loan.principal());

        vm.prank(poolDelegate);
        loanManager.callPrincipal(address(loan), calledPrincipal);

        ( uint256 principal, , , , ) = loan.getPaymentBreakdown(block.timestamp + loan.gracePeriod());

        // Perform the assertions.
        assertEq(loan.dateCalled(),      block.timestamp);
        assertEq(principal,              calledPrincipal);
        assertEq(loan.calledPrincipal(), calledPrincipal);

        assertEq(fundsAsset.balanceOf(loan.borrower()),                     borrowerBalance);
        assertEq(fundsAsset.balanceOf(address(pool)),                       poolBalance);
        assertEq(fundsAsset.balanceOf(address(treasury)),                   treasuryBalance);
        assertEq(fundsAsset.balanceOf(address(poolManager.poolDelegate())), delegateBalance);

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      block.timestamp,
            dateFunded:      loanStorage.previousDateFunded,
            dateImpaired:    loanStorage.previousDateImpaired,
            datePaid:        loanStorage.previousDatePaid,
            calledPrincipal: calledPrincipal,
            principal:       loanStorage.previousPrincipal
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            platformFeeRate: paymentStorage.previousPlatformManagementFeeRate,
            delegateFeeRate: paymentStorage.previousDelegateManagementFeeRate,
            startDate:       paymentStorage.previousStartDate,
            issuanceRate:    paymentStorage.previousIssuanceRate
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: loanManagerStorage.previousAccountedInterest,
            accruedInterest:   loanManagerStorage.previousAccruedInterest,
            domainStart:       loanManagerStorage.previousDomainStart,
            issuanceRate:      loanManagerStorage.previousIssuanceRate,
            principalOut:      loanManagerStorage.previousPrincipalOut,
            unrealizedLosses:  loanManagerStorage.previousUnrealizedLosses
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolManagerStorage.previousTotalAssets,
            totalSupply:        poolManagerStorage.previousTotalSupply,
            unrealizedLosses:   poolManagerStorage.previousUnrealizedLosses,
            availableLiquidity: poolManagerStorage.previousFundsAssetBalance
        });
    }

    function testFuzz_removeCall_otl(uint256 seed) external {
        fuzzedSetup(FTL_LOAN_COUNT, OTL_LOAN_COUNT, ACTION_COUNT, seed);

        loan = IOpenTermLoan(getSomeCalledOpenTermLoan());

        // Do nothing if no called loans exist.
        if (address(loan) == address(0)) return;

        // Cache the state.
        uint256 borrowerBalance = fundsAsset.balanceOf(loan.borrower());
        uint256 delegateBalance = fundsAsset.balanceOf(address(poolManager.poolDelegate()));
        uint256 poolBalance     = fundsAsset.balanceOf(address(pool));
        uint256 treasuryBalance = fundsAsset.balanceOf(address(treasury));

        loanManagerStorage = _snapshotOpenTermLoanManager(loanManager);
        loanStorage        = _snapshotOpenTermLoan(loan);
        paymentStorage     = _snapshotOpenTermPayment(loan);
        poolManagerStorage = _snapshotPoolManager(poolManager);

        // Perform the action.
        vm.prank(poolManager.poolDelegate());
        loanManager.removeCall(address(loan));

        ( uint256 principal, , , , ) = loan.getPaymentBreakdown(block.timestamp + loan.gracePeriod());

        // Perform the assertions.
        assertEq(loan.dateCalled(),      0);
        assertEq(principal,              0);
        assertEq(loan.calledPrincipal(), 0);

        assertEq(fundsAsset.balanceOf(loan.borrower()),                     borrowerBalance);
        assertEq(fundsAsset.balanceOf(address(pool)),                       poolBalance);
        assertEq(fundsAsset.balanceOf(address(treasury)),                   treasuryBalance);
        assertEq(fundsAsset.balanceOf(address(poolManager.poolDelegate())), delegateBalance);

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      0,
            dateFunded:      loanStorage.previousDateFunded,
            dateImpaired:    loanStorage.previousDateImpaired,
            datePaid:        loanStorage.previousDatePaid,
            calledPrincipal: 0,
            principal:       loanStorage.previousPrincipal
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            platformFeeRate: paymentStorage.previousPlatformManagementFeeRate,
            delegateFeeRate: paymentStorage.previousDelegateManagementFeeRate,
            startDate:       paymentStorage.previousStartDate,
            issuanceRate:    paymentStorage.previousIssuanceRate
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: loanManagerStorage.previousAccountedInterest,
            accruedInterest:   loanManagerStorage.previousAccruedInterest,
            domainStart:       loanManagerStorage.previousDomainStart,
            issuanceRate:      loanManagerStorage.previousIssuanceRate,
            principalOut:      loanManagerStorage.previousPrincipalOut,
            unrealizedLosses:  loanManagerStorage.previousUnrealizedLosses
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolManagerStorage.previousTotalAssets,
            totalSupply:        poolManagerStorage.previousTotalSupply,
            unrealizedLosses:   poolManagerStorage.previousUnrealizedLosses,
            availableLiquidity: poolManagerStorage.previousFundsAssetBalance
        });
    }

}
