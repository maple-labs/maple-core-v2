// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IOpenTermLoan, IOpenTermLoanManager } from "../../contracts/interfaces/Interfaces.sol";

import { console } from "../../contracts/Contracts.sol";

import { LpHandler }           from "./actors/LpHandler.sol";
import { OpenTermLoanHandler } from "./actors/OpenTermLoanHandler.sol";

import { BaseInvariants } from "./BaseInvariants.t.sol";

contract OpenTermInvariants is BaseInvariants {

    // TODO: Remove excludeAllContracts from all files
    // TODO: Convert all invariants to assert_ functions in BaseInvariants, rename existing functions (e.g., assert_loan => assert_fixedTermLoan)
    // TODO: Consolidate all loan for loop invariants into a single invariant_ function
    // TODO: Move helper functions into base invariants
    // TODO: Make invariant file that includes all three handlers, consider inheriting all three to introduce uniform probability of function calls
    // TODO: Add governor handler
    // TODO: Update fees

    function setUp() public override {
        super.setUp();

        // TODO: Remove this
        _excludeAllContracts();

        // TODO: Check if all timestamp accounting can be removed.
        currentTimestamp = block.timestamp;

        vm.startPrank(governor);
        globals.setPlatformServiceFeeRate(address(poolManager),    0.025e6);
        globals.setPlatformManagementFeeRate(address(poolManager), 0.08e6);
        vm.stopPrank();

        vm.prank(poolDelegate);
        poolManager.setDelegateManagementFeeRate(0.02e6);

        lpHandler  = new LpHandler({
            pool_:         address(pool),
            testContract_: address(this),
            numLps_:       10
        });

        otlHandler = new OpenTermLoanHandler({
            loanFactory_:       address(openTermLoanFactory),
            liquidatorFactory_: address(liquidatorFactory),
            poolManager_:       address(poolManager),
            maxBorrowers_:      5,
            maxLoans_:          10
        });

        targetContract(address(lpHandler));
        targetContract(address(otlHandler));
    }

    /**************************************************************************************************************************************/
    /*** Open Term Loan Invariants                                                                                                      ***/
    /**************************************************************************************************************************************/

    // OTL Invariant A: dateFunded <= datePaid
    // OTL Invariant B: dateFunded <= dateImpaired
    // OTL Invariant C: dateFunded <= dateCalled
    // OTL Invariant D: datePaid <= dateImpaired
    // OTL Invariant E: datePaid <= dateCalled
    function invariant_otl_A_B_C_D_E() external useCurrentTimestamp {
        IOpenTermLoan[] memory loans = getActiveLoans();

        for (uint256 i; i < loans.length; ++i) {
            if (loans[i].datePaid() != 0) {
                assertLe(loans[i].dateFunded(), loans[i].datePaid(), "OTL Invariant A");
            }

            if (loans[i].dateImpaired() != 0) {
                assertLe(loans[i].dateFunded(), loans[i].dateImpaired(), "OTL Invariant B");
            }

            if (loans[i].dateCalled() != 0) {
                assertLe(loans[i].dateFunded(), loans[i].dateCalled(), "OTL Invariant C");
            }

            if (loans[i].datePaid() != 0 && loans[i].dateImpaired() != 0) {
                assertLe(loans[i].datePaid(), loans[i].dateImpaired(), "OTL Invariant D");
            }

            if (loans[i].datePaid() != 0 && loans[i].dateCalled() != 0) {
                assertLe(loans[i].datePaid(), loans[i].dateCalled(),   "OTL Invariant E");
            }
        }
    }

    // OTL Invariant F: calledPrincipal <= principal
    // OTL Invariant G: dateCalled != 0 -> calledPrincipal != 0
    function invariant_otl_F_G() external useCurrentTimestamp {
        IOpenTermLoan[] memory loans = getActiveLoans();

        for (uint256 i; i < loans.length; ++i) {
            assertLe(loans[i].calledPrincipal(), loans[i].principal(), "OTL Invariant F");
            assertTrue(
                loans[i].dateCalled() == 0 && loans[i].calledPrincipal() == 0 ||
                loans[i].dateCalled() != 0 && loans[i].calledPrincipal() != 0,
                "OTL Invariant G"
            );
        }
    }

    // OTL Invariant H: paymentDueDate() <= defaultDate()
    function invariant_otl_H() external useCurrentTimestamp {
        IOpenTermLoan[] memory loans = getActiveLoans();

        for (uint256 i; i < loans.length; ++i) {
            assertLe(loans[i].paymentDueDate(), loans[i].defaultDate(), "OTL Invariant H");
        }
    }

    // OTL Invariant I: getPaymentBreakdown(block.timestamp) ~= theoretical calculation
    function invariant_otl_I() external useCurrentTimestamp {
        IOpenTermLoan[] memory loans = getActiveLoans();

        for (uint256 i; i < loans.length; ++i) {
            (
                uint256 principal,
                uint256 interest,
                uint256 lateInterest,
                uint256 delegateServiceFee,
                uint256 platformServiceFee
            ) = loans[i].getPaymentBreakdown(block.timestamp);

            (
                uint256 expectedPrincipal,
                uint256 expectedInterest,
                uint256 expectedLateInterest,
                uint256 expectedDelegateServiceFee,
                uint256 expectedPlatformServiceFee
            ) = getExpectedPaymentBreakdown(loans[i]);

            assertEq(principal,          expectedPrincipal,          "OTL Invariant I (principal)");
            assertEq(interest,           expectedInterest,           "OTL Invariant I (interest)");
            assertEq(lateInterest,       expectedLateInterest,       "OTL Invariant I (lateInterest)");
            assertEq(delegateServiceFee, expectedDelegateServiceFee, "OTL Invariant I (delegateServiceFee)");
            assertEq(platformServiceFee, expectedPlatformServiceFee, "OTL Invariant I (platformServiceFee)");
        }
    }

    /**************************************************************************************************************************************/
    /*** Open Term Loan Manager Invariants                                                                                              ***/
    /**************************************************************************************************************************************/

    // OTLM Invariant G: AUM() ~= ∑loan.principal() + ∑loan.getPaymentBreakdown(block.timestamp) (without late interest and fees)
    function invariant_otlm_A() external useCurrentTimestamp {
        IOpenTermLoan[] memory loans = getActiveLoans();

        uint256 assetsUnderManagement = getLoanManager().assetsUnderManagement();
        uint256 expectedAssetsUnderManagement;

        for (uint256 i; i < loans.length; ++i) {
            expectedAssetsUnderManagement += loans[i].principal() + getExpectedNetInterest(loans[i]);
        }

        // TODO: Checkout difference in real and expected AUM.
        assertApproxEqAbs(assetsUnderManagement, expectedAssetsUnderManagement, 100, "OTLM Invariant A");
    }

    // OTLM Invariant B: no payments exist -> AUM == 0
    function invariant_otlm_B() external useCurrentTimestamp {
        IOpenTermLoan[] memory loans = getActiveLoans();

        uint256 assetsUnderManagement = getLoanManager().assetsUnderManagement();

        for (uint256 i; i < loans.length; ++i) {
            ( , , uint40 startDate, ) = getLoanManager().paymentFor(address(loans[i]));

            if (startDate != 0) return;
        }

        assertApproxEqAbs(assetsUnderManagement, 0, otlHandler.numLoans(), "OTLM Invariant B");
    }

    // OTLM Invariant C: principalOut = ∑loan.principal()
    function invariant_otlm_C() external useCurrentTimestamp {
        IOpenTermLoan[] memory loans = getActiveLoans();

        uint256 principalOut = getLoanManager().principalOut();
        uint256 expectedPrincipalOut;

        for (uint256 i; i < loans.length; ++i) {
            expectedPrincipalOut += loans[i].principal();
        }

        assertEq(principalOut, expectedPrincipalOut, "OTLM Invariant C");
    }

    // OTLM Invariant D: issuanceRate = ∑payment.issuanceRate
    function invariant_otlm_D() external useCurrentTimestamp {
        IOpenTermLoan[] memory loans = getActiveLoans();

        uint256 issuanceRate = getLoanManager().issuanceRate();
        uint256 expectedIssuanceRate;

        for (uint256 i; i < loans.length; ++i) {
            ( , , , uint168 issuanceRate ) = getLoanManager().paymentFor(address(loans[i]));
            expectedIssuanceRate += issuanceRate;
        }

        assertEq(issuanceRate, expectedIssuanceRate, "OTLM Invariant D");
    }

    // OTLM Invariant E: unrealizedLosses <= assetsUnderManagement()
    function invariant_otlm_E() external useCurrentTimestamp {
        uint256 unrealizedLosses      = getLoanManager().unrealizedLosses();
        uint256 assetsUnderManagement = getLoanManager().assetsUnderManagement();

        assertLe(unrealizedLosses, assetsUnderManagement, "OTLM Invariant E");
    }

    // OTLM Invariant F: no impairments exist -> unrealizedLosses == 0
    function invariant_otlm_F() external useCurrentTimestamp {
        IOpenTermLoan[] memory loans = getActiveLoans();

        uint256 unrealizedLosses = getLoanManager().unrealizedLosses();

        for (uint256 i; i < loans.length; ++i) {
            ( uint40 impairmentDate, ) = getLoanManager().impairmentFor(address(loans[i]));

            if (impairmentDate != 0) return;
        }

        assertEq(unrealizedLosses, 0, "OTLM Invariant F");
    }

    // OTLM Invariant G: block.timestamp >= domainStart
    function invariant_otlm_G() external useCurrentTimestamp {
        uint256 domainStart = getLoanManager().domainStart();

        assertGe(block.timestamp, domainStart, "OTLM Invariant G");
    }

    // OTLM Invariant H: payment.startDate == loan.dateFunded() || payment.startDate == loan.datePaid()
    function invariant_otlm_H() external useCurrentTimestamp {
        IOpenTermLoan[] memory loans = getActiveLoans();

        for (uint256 i; i < loans.length; ++i) {
            ( , , uint40 startDate, ) = getLoanManager().paymentFor(address(loans[i]));

            assertTrue(
                startDate == loans[i].dateFunded() ||
                startDate == loans[i].datePaid(),
                "OTLM Invariant H"
            );
        }
    }

    // OTLM Invariant I: payment.issuanceRate ~= theoretical calculation
    function invariant_otlm_I() external useCurrentTimestamp {
        IOpenTermLoan[] memory loans = getActiveLoans();

        for (uint256 i; i < loans.length; ++i) {
            ( , , , uint168 issuanceRate ) = getLoanManager().paymentFor(address(loans[i]));
            uint256 expectedIssuanceRate = getExpectedIssuanceRate(loans[i]);

            assertEq(issuanceRate, expectedIssuanceRate, "OTLM Invariant I");
        }
    }

    // OTLM Invariant J: ∑payment.impairedDate >= ∑payment.startDate
    function invariant_otlm_J() external useCurrentTimestamp {
        IOpenTermLoan[] memory loans = getActiveLoans();

        for (uint256 i; i < loans.length; ++i) {
            ( uint40 impairmentDate, ) = getLoanManager().impairmentFor(address(loans[i]));
            ( , , uint40 startDate, ) = getLoanManager().paymentFor(address(loans[i]));

            if (impairmentDate != 0) {
                assertGe(impairmentDate, startDate, "OTLM Invariant J");
            }
        }
    }

    /**************************************************************************************************************************************/
    /*** Helper Functions                                                                                                               ***/
    /**************************************************************************************************************************************/

    function getActiveLoans() internal view returns (IOpenTermLoan[] memory loans) {
        uint256 index;
        uint256 length;

        for (uint256 i; i < otlHandler.numLoans(); ++i) {
            if (IOpenTermLoan(otlHandler.loans(i)).dateFunded() != 0) length++;
        }

        loans = new IOpenTermLoan[](length);

        for (uint256 i; i < otlHandler.numLoans(); ++i) {
            IOpenTermLoan loan = IOpenTermLoan(otlHandler.loans(i));
            if (loan.dateFunded() != 0) {
                loans[index++] = loan;
            }
        }
    }

    function getExpectedIssuanceRate(IOpenTermLoan loan) internal view returns (uint256 expectedIssuanceRate) {
        ( uint24 platformManagementFeeRate, uint24 delegateManagementFeeRate, , ) = getLoanManager().paymentFor(address(loan));

        uint256 grossInterest  = getProRatedAmount(loan.principal(), loan.interestRate(), loan.paymentInterval());
        uint256 managementFees = grossInterest * (delegateManagementFeeRate + platformManagementFeeRate) / 1e6;

        expectedIssuanceRate = (grossInterest - managementFees) * 1e27 / loan.paymentInterval();
    }

    function getExpectedNetInterest(IOpenTermLoan loan) internal view returns (uint256 netInterest) {
        ( , uint256 grossInterest, , , ) = loan.getPaymentBreakdown(block.timestamp);
        ( uint24 platformManagementFeeRate, uint24 delegateManagementFeeRate, , ) = getLoanManager().paymentFor(address(loan));

        uint256 managementFees = grossInterest * (delegateManagementFeeRate + platformManagementFeeRate) / 1e6;

        netInterest = grossInterest - managementFees;
    }

    function getExpectedPaymentBreakdown(IOpenTermLoan loan) internal view
        returns (
            uint256 expectedPrincipal,
            uint256 expectedInterest,
            uint256 expectedLateInterest,
            uint256 expectedDelegateServiceFee,
            uint256 expectedPlatformServiceFee
        )
    {
        uint256 startTime    = loan.datePaid() == 0 ? loan.dateFunded() : loan.datePaid();
        uint256 interval     = block.timestamp - startTime;
        uint256 lateInterval = interval > loan.paymentInterval() ? interval - loan.paymentInterval() : 0;

        expectedPrincipal          = loan.dateCalled() == 0 ? 0 : loan.calledPrincipal();
        expectedInterest           = getProRatedAmount(loan.principal(), loan.interestRate(), interval);
        expectedLateInterest       = 0;
        expectedDelegateServiceFee = getProRatedAmount(loan.principal(), loan.delegateServiceFeeRate(), interval);
        expectedPlatformServiceFee = getProRatedAmount(loan.principal(), loan.platformServiceFeeRate(), interval);

        if (lateInterval > 0) {
            expectedLateInterest += getProRatedAmount(loan.principal(), loan.lateInterestPremiumRate(), lateInterval);
            expectedLateInterest += loan.principal() * loan.lateFeeRate() / 1e6;
        }
    }

    function getLoanManager() internal view returns (IOpenTermLoanManager loanManager) {
        loanManager = IOpenTermLoanManager(otlHandler.loanManager());
    }

    function getProRatedAmount(uint256 amount_, uint256 rate_, uint256 interval_) internal pure returns (uint256 proRatedAmount_) {
        proRatedAmount_ = (amount_ * rate_ * interval_) / (365 days * 1e6);
    }

}
