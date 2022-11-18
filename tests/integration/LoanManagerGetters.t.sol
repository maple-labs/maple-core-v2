// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { TestBase } from "../../contracts/utilities/TestBase.sol";

import { Address }           from "../../modules/contract-test-utils/contracts/test.sol";
import { MapleLoan as Loan } from "../../modules/loan-v401/contracts/MapleLoan.sol";

contract LoanManagerGetterTests is TestBase {

    Loan loan;

    function setUp() public override {
        super.setUp();

        depositLiquidity(address(new Address()), 1_500_000e6);

        loan = fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e18), uint256(0), uint256(0.0001e18), uint256(0.031536e18 / 10)]
        });

        vm.startPrank(poolDelegate);
        poolManager.setMinRatio(address(loanManager), address(collateralAsset), 1e6);
        poolManager.setAllowedSlippage(address(loanManager), address(collateralAsset), 1e6);
        vm.stopPrank();
    }

    function test_loanManagerGetters_addresses() external {
        assertEq(loanManager.fundsAsset(),    address(fundsAsset));
        assertEq(loanManager.globals(),       address(globals));
        assertEq(loanManager.governor(),      address(governor));
        assertEq(loanManager.mapleTreasury(), address(treasury));
        assertEq(loanManager.pool(),          address(pool));
        assertEq(loanManager.poolDelegate(),  address(poolDelegate));
        assertEq(loanManager.poolManager(),   address(poolManager));
    }

    function test_loanManagerGetters_uints() external {
        assertEq(loanManager.accountedInterest(),          0);
        assertEq(loanManager.domainEnd(),                  start + 1_000_000);
        assertEq(loanManager.domainStart(),                start);
        assertEq(loanManager.issuanceRate(),               0.1e6 * 1e30);
        assertEq(loanManager.paymentCounter(),             1);
        assertEq(loanManager.paymentWithEarliestDueDate(), 1);
        assertEq(loanManager.principalOut(),               1_000_000e6);
        assertEq(loanManager.unrealizedLosses(),           0);
    }

    function test_loanManagerGetters_liquidationInformation() external {
        // Returns false when loan has not yet defaulted.
        assertTrue(!loanManager.isLiquidationActive(address(loan)));

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        // Since we round up days when it comes to late interest, this payment is 6 days late.
        vm.warp(start + 1_000_000 + 5 days + 1);

        vm.prank(poolDelegate);
        poolManager.triggerDefault(address(loan), address(liquidatorFactory));

        // Returns true when loan has defaulted.
        assertTrue(loanManager.isLiquidationActive(address(loan)));

        assertEq(loanManager.allowedSlippageFor(address(collateralAsset)), 1e6);
        assertEq(loanManager.minRatioFor(address(collateralAsset)),        1e6);

        liquidateCollateral(loan);

        vm.prank(poolDelegate);
        poolManager.finishCollateralLiquidation(address(loan));

        assertTrue(!loanManager.isLiquidationActive(address(loan)));
    }

    function test_loanManagerGetters_paymentInformation() external {
        assertEq(loanManager.paymentIdOf(address(loan)), 1);

        (
            uint24  platformManagementFeeRate,
            uint24  delegateManagementFeeRate,
            uint48  startDate,
            uint48  paymentDueDate,
            uint128 incomingNetInterest,
            uint128 refinanceInterest,
            uint256 issuanceRate
        ) = loanManager.payments(1);

            assertEq(platformManagementFeeRate, 0);
            assertEq(delegateManagementFeeRate, 0);
            assertEq(startDate,                 start);
            assertEq(paymentDueDate,            start + 1_000_000);
            assertEq(incomingNetInterest,       100_000e6);
            assertEq(refinanceInterest,         0);
            assertEq(issuanceRate,              0.1e6 * 1e30);
    }

    function test_loanManagerGetters_sortedPayments() external {
        // Fund another loan to populate the sortedPayments array.
        fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(5 days), uint256(3_000_000), uint256(3)],
            amounts:     [uint256(100e18), uint256(250_000e6), uint256(250_000e6)],
            rates:       [uint256(3.1536e18), uint256(0), uint256(0.0001e18), uint256(0.031536e18 / 10)]
        });

        ( uint256 previous, uint256 next, uint256 paymentDueDate) = loanManager.sortedPayments(1);

        assertEq(previous,       0);
        assertEq(next,           2);
        assertEq(paymentDueDate, start + 1_000_000);
    }

}
