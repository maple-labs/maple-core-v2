// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IOpenTermLoan, IOpenTermLoanManager } from "../../contracts/interfaces/Interfaces.sol";

import { FuzzedSetup }     from "./FuzzedSetup.sol";
import { StorageSnapshot } from "./StorageSnapshot.sol";

contract OpenTermLoanFuzz is FuzzedSetup, StorageSnapshot {

    uint256 constant ACTION_COUNT   = 10;
    uint256 constant FTL_LOAN_COUNT = 5;
    uint256 constant OTL_LOAN_COUNT = 5;

    uint256 borrowerBalance;
    uint256 pdBalance;
    uint256 poolBalance;
    uint256 treasuryBalance;

    IOpenTermLoan        loan;
    IOpenTermLoanManager loanManager;

    OpenTermLoanImpairmentStorage impairmentStorage;
    OpenTermLoanManagerStorage    loanManagerStorage;
    OpenTermLoanStorage           loanStorage;
    OpenTermPaymentStorage        paymentStorage;
    PoolManagerStorage            poolManagerStorage;

    function setUp() public override {
        super.setUp();

        loanManager = IOpenTermLoanManager(_openTermLoanManager);
    }

    function testFuzz_impair_otl(uint256 seed) external {
        fuzzedSetup(FTL_LOAN_COUNT, OTL_LOAN_COUNT, ACTION_COUNT, seed);

        loan = IOpenTermLoan(getSomeActiveOpenTermLoan());

        // Do nothing if no loan is available.
        if (address(loan) == address(0)) return;

        // Cache the token balances.
        borrowerBalance = fundsAsset.balanceOf(loan.borrower());
        pdBalance       = fundsAsset.balanceOf(address(poolManager.poolDelegate()));
        poolBalance     = fundsAsset.balanceOf(address(pool));
        treasuryBalance = fundsAsset.balanceOf(address(treasury));

        // Cache the contract states.
        impairmentStorage  = _snapshotOpenTermImpairment(address(loan));
        loanManagerStorage = _snapshotOpenTermLoanManager(address(loanManager));
        loanStorage        = _snapshotOpenTermLoan(address(loan));
        paymentStorage     = _snapshotOpenTermPayment(address(loan));
        poolManagerStorage = _snapshotPoolManager(address(poolManager));

        // Decide if the delegate or governor will perform the impairment.
        address caller = seed % 2 == 0 ? poolManager.poolDelegate() : globals.governor();

        // Perform the action.
        vm.prank(caller);
        loanManager.impairLoan(address(loan));

        // Perform the assertions.
        assertEq(fundsAsset.balanceOf(loan.borrower()),                     borrowerBalance);
        assertEq(fundsAsset.balanceOf(address(pool)),                       poolBalance);
        assertEq(fundsAsset.balanceOf(address(treasury)),                   treasuryBalance);
        assertEq(fundsAsset.balanceOf(address(poolManager.poolDelegate())), pdBalance);

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      loanStorage.previousDateCalled,
            dateFunded:      loanStorage.previousDateFunded,
            dateImpaired:    block.timestamp,
            datePaid:        loanStorage.previousDatePaid,
            calledPrincipal: loanStorage.previousCalledPrincipal,
            principal:       loanStorage.previousPrincipal
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            platformFeeRate: paymentStorage.previousPlatformManagementFeeRate,
            delegateFeeRate: paymentStorage.previousDelegateManagementFeeRate,
            startDate:       paymentStorage.previousStartDate,
            issuanceRate:    paymentStorage.previousIssuanceRate
        });

        // If the loan was not already impaired.
        if (impairmentStorage.previousDateImpaired == 0) {
            assertImpairment({
                loan:               address(loan),
                impairedDate:       block.timestamp,
                impairedByGovernor: caller == globals.governor()
            });

            uint256 impairedInterest  = paymentStorage.previousIssuanceRate * (block.timestamp - paymentStorage.previousStartDate) / 1e27;
            uint256 impairedPrincipal = loanStorage.previousPrincipal;

            assertOpenTermLoanManagerWithDiff({
                loanManager:       address(loanManager),
                accountedInterest: loanManagerStorage.previousAccountedInterest + loanManagerStorage.previousAccruedInterest,
                accruedInterest:   0,
                domainStart:       block.timestamp,
                issuanceRate:      loanManagerStorage.previousIssuanceRate - paymentStorage.previousIssuanceRate,
                principalOut:      loanManagerStorage.previousPrincipalOut,
                unrealizedLosses:  loanManagerStorage.previousUnrealizedLosses + impairedPrincipal + impairedInterest,
                diff:              3
            });

            assertPoolStateWithDiff({
                pool:               address(pool),
                totalAssets:        poolManagerStorage.previousTotalAssets,
                totalSupply:        poolManagerStorage.previousTotalSupply,
                unrealizedLosses:   poolManagerStorage.previousUnrealizedLosses + impairedPrincipal + impairedInterest,
                availableLiquidity: poolManagerStorage.previousFundsAssetBalance,
                diff:               3
            });
        }

        // If the loan was already impaired.
        else {
            assertImpairment({
                loan:               address(loan),
                impairedDate:       impairmentStorage.previousDateImpaired,
                impairedByGovernor: impairmentStorage.previousImpairedByGovernor
            });

            uint256 elapsedTime     = block.timestamp - loanManagerStorage.previousDomainStart;
            uint256 accruedInterest = loanManagerStorage.previousIssuanceRate * elapsedTime / 1e27;

            assertOpenTermLoanManagerWithDiff({
                loanManager:       address(loanManager),
                accountedInterest: loanManagerStorage.previousAccountedInterest,
                accruedInterest:   accruedInterest,
                domainStart:       loanManagerStorage.previousDomainStart,
                issuanceRate:      loanManagerStorage.previousIssuanceRate,
                principalOut:      loanManagerStorage.previousPrincipalOut,
                unrealizedLosses:  loanManagerStorage.previousUnrealizedLosses,
                diff:              3
            });

            assertPoolStateWithDiff({
                pool:               address(pool),
                totalAssets:        poolManagerStorage.previousTotalAssets,
                totalSupply:        poolManagerStorage.previousTotalSupply,
                unrealizedLosses:   poolManagerStorage.previousUnrealizedLosses,
                availableLiquidity: poolManagerStorage.previousFundsAssetBalance,
                diff:               3
            });
        }
    }

    function testFuzz_removeImpairment_otl(uint256 seed) external {
        fuzzedSetup(FTL_LOAN_COUNT, OTL_LOAN_COUNT, ACTION_COUNT, seed);

        loan = IOpenTermLoan(getSomeImpairedOpenTermLoan());

        // Do nothing if no loan is available.
        if (address(loan) == address(0)) return;

        // Cache the state.
        borrowerBalance = fundsAsset.balanceOf(loan.borrower());
        pdBalance       = fundsAsset.balanceOf(address(poolManager.poolDelegate()));
        poolBalance     = fundsAsset.balanceOf(address(pool));
        treasuryBalance = fundsAsset.balanceOf(address(treasury));

        impairmentStorage  = _snapshotOpenTermImpairment(address(loan));
        loanManagerStorage = _snapshotOpenTermLoanManager(address(loanManager));
        loanStorage        = _snapshotOpenTermLoan(address(loan));
        paymentStorage     = _snapshotOpenTermPayment(address(loan));
        poolManagerStorage = _snapshotPoolManager(address(poolManager));

        // Perform the action.
        vm.prank(globals.governor());
        loanManager.removeLoanImpairment(address(loan));

        // Perform the assertions.
        assertEq(fundsAsset.balanceOf(loan.borrower()),                     borrowerBalance);
        assertEq(fundsAsset.balanceOf(address(pool)),                       poolBalance);
        assertEq(fundsAsset.balanceOf(address(treasury)),                   treasuryBalance);
        assertEq(fundsAsset.balanceOf(address(poolManager.poolDelegate())), pdBalance);

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      loanStorage.previousDateCalled,
            dateFunded:      loanStorage.previousDateFunded,
            dateImpaired:    0,
            datePaid:        loanStorage.previousDatePaid,
            calledPrincipal: loanStorage.previousCalledPrincipal,
            principal:       loanStorage.previousPrincipal
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            platformFeeRate: paymentStorage.previousPlatformManagementFeeRate,
            delegateFeeRate: paymentStorage.previousDelegateManagementFeeRate,
            startDate:       paymentStorage.previousStartDate,
            issuanceRate:    paymentStorage.previousIssuanceRate
        });

        assertImpairment({
            loan:               address(loan),
            impairedDate:       0,
            impairedByGovernor: false
        });

        uint256 unvestedTimeSpan = block.timestamp - impairmentStorage.previousDateImpaired;
        uint256 extraInterest    = paymentStorage.previousIssuanceRate * unvestedTimeSpan / 1e27;

        uint256 impairmentTimeSpan = impairmentStorage.previousDateImpaired - paymentStorage.previousStartDate;
        uint256 impairedInterest   = paymentStorage.previousIssuanceRate * impairmentTimeSpan / 1e27;
        uint256 impairedPrincipal  = loanStorage.previousPrincipal;

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: loanManagerStorage.previousAccountedInterest + loanManagerStorage.previousAccruedInterest + extraInterest,
            accruedInterest:   0,
            domainStart:       block.timestamp,
            issuanceRate:      loanManagerStorage.previousIssuanceRate + paymentStorage.previousIssuanceRate,
            principalOut:      loanManagerStorage.previousPrincipalOut,
            unrealizedLosses:  loanManagerStorage.previousUnrealizedLosses - impairedPrincipal - impairedInterest
        });

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolManagerStorage.previousTotalAssets + extraInterest,
            totalSupply:        poolManagerStorage.previousTotalSupply,
            unrealizedLosses:   poolManagerStorage.previousUnrealizedLosses - impairedPrincipal - impairedInterest,
            availableLiquidity: poolManagerStorage.previousFundsAssetBalance
        });
    }

}
