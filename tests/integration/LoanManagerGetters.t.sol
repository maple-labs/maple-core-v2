// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IFixedTermLoanManager, ILoanManagerLike } from "../../contracts/interfaces/Interfaces.sol";

import { Address } from "../../contracts/Contracts.sol";

import { TestBase } from "../TestBase.sol";

contract LoanManagerGetterTests is TestBase {

    address loan;
    address loanManager;

    function setUp() public override {
        super.setUp();

        depositLiquidity(address(new Address()), 1_500_000e6);

        loanManager = poolManager.loanManagerList(0);

        loan = fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e18), uint256(0), uint256(0.0001e18), uint256(0.031536e18 / 10)],
            loanManager: loanManager
        });

        vm.startPrank(poolDelegate);
        poolManager.setMinRatio(loanManager, address(collateralAsset), 1e6);
        poolManager.setAllowedSlippage(loanManager, address(collateralAsset), 1e6);
        vm.stopPrank();
    }

    function test_loanManagerGetters_addresses() external {
        ILoanManagerLike loanManager_ = ILoanManagerLike(loanManager);

        assertEq(loanManager_.fundsAsset(),    address(fundsAsset));
        assertEq(loanManager_.globals(),       address(globals));
        assertEq(loanManager_.governor(),      address(governor));
        assertEq(loanManager_.mapleTreasury(), address(treasury));
        assertEq(loanManager_.pool(),          address(pool));
        assertEq(loanManager_.poolDelegate(),  address(poolDelegate));
        assertEq(loanManager_.poolManager(),   address(poolManager));
    }

    function test_loanManagerGetters_uints() external {
        ILoanManagerLike loanManager_ = ILoanManagerLike(loanManager);

        assertEq(loanManager_.accountedInterest(),          0);
        assertEq(loanManager_.domainEnd(),                  start + 1_000_000);
        assertEq(loanManager_.domainStart(),                start);
        assertEq(loanManager_.issuanceRate(),               0.1e6 * 1e30);
        assertEq(loanManager_.paymentCounter(),             1);
        assertEq(loanManager_.paymentWithEarliestDueDate(), 1);
        assertEq(loanManager_.principalOut(),               1_000_000e6);
        assertEq(loanManager_.unrealizedLosses(),           0);
    }

    function test_loanManagerGetters_liquidationInformation() external {
        IFixedTermLoanManager loanManager_ = IFixedTermLoanManager(loanManager);

        // Returns false when loan has not yet defaulted.
        assertTrue(!loanManager_.isLiquidationActive(loan));

        /***********************************************/
        /*** Warp to end of 1nd Payment grace period ***/
        /***********************************************/

        // Since we round up days when it comes to late interest, this payment is 6 days late.
        vm.warp(start + 1_000_000 + 5 days + 1);

        triggerDefault(loan, address(liquidatorFactory));

        // Returns true when loan has defaulted.
        assertTrue(loanManager_.isLiquidationActive(loan));

        assertEq(loanManager_.allowedSlippageFor(address(collateralAsset)), 1e6);
        assertEq(loanManager_.minRatioFor(address(collateralAsset)),        1e6);

        liquidateCollateral(loan);

        finishCollateralLiquidation(loan);

        assertTrue(!loanManager_.isLiquidationActive(loan));
    }

    function test_loanManagerGetters_paymentInformation() external {
        assertEq(ILoanManagerLike(loanManager).paymentIdOf(loan), 1);

        (
            uint24  platformManagementFeeRate,
            uint24  delegateManagementFeeRate,
            uint48  startDate,
            uint48  paymentDueDate,
            uint128 incomingNetInterest,
            uint128 refinanceInterest,
            uint256 issuanceRate
        ) = ILoanManagerLike(loanManager).payments(1);

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
            rates:       [uint256(3.1536e18), uint256(0), uint256(0.0001e18), uint256(0.031536e18 / 10)],
            loanManager: loanManager
        });

        ( uint256 previous, uint256 next, uint256 paymentDueDate) = ILoanManagerLike(loanManager).sortedPayments(1);

        assertEq(previous,       0);
        assertEq(next,           2);
        assertEq(paymentDueDate, start + 1_000_000);
    }

}
