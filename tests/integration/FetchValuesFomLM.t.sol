// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestBase } from "../../contracts/utilities/TestBase.sol";

import { Address }           from "../../modules/contract-test-utils/contracts/test.sol";
import { MapleLoan as Loan } from "../../modules/loan/contracts/MapleLoan.sol";

contract LoanManagerAddressGetterTests is TestBase {

    function test_addressGetters() external {
        assertEq(loanManager.governor(),      governor);
        assertEq(loanManager.globals(),       address(globals));
        assertEq(loanManager.mapleTreasury(), treasury);
        assertEq(loanManager.poolDelegate(),  poolDelegate);
    }

}

contract LoanManagerIsLiquidationActiveGetterTests is TestBase {

    Loan loan;

    function setUp() public override {
        super.setUp();

        depositLiquidity(address(new Address()), 1_500_000e6);

        loan = fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e18), uint256(0), uint256(0.0001e18), uint256(0.031536e18 / 10)]
        });
    }

    function test_isLiquidationActive_beforeLiquidation() external {
        assertTrue(!loanManager.isLiquidationActive(address(loan)));
    }

    function test_isLiquidationActive_duringLiquidation() external {
        vm.warp(start + 1_000_000 + 5 days + 1);

        assertTrue(!loanManager.isLiquidationActive(address(loan)));

        vm.prank(poolDelegate);
        poolManager.triggerDefault(address(loan), address(liquidatorFactory));

        assertTrue(loanManager.isLiquidationActive(address(loan)));
    }

    function test_isLiquidationActive_afterLiquidation() external {
        vm.warp(start + 1_000_000 + 5 days + 1);

        vm.prank(poolDelegate);
        poolManager.triggerDefault(address(loan), address(liquidatorFactory));

        assertTrue(loanManager.isLiquidationActive(address(loan)));

        liquidateCollateral(loan);

        assertTrue(!loanManager.isLiquidationActive(address(loan)));
    }


    /// @TODO: Add test_isLiquidationActive_afterLiquidation

}
