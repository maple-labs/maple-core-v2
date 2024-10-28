// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IFixedTermLoanManager } from "../../../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../../../TestBase.sol";

contract LoanManagerIsLiquidationActiveGetterTests is TestBase {

    address loan;

    IFixedTermLoanManager loanManager;

    function setUp() public override {
        super.setUp();

        loanManager = IFixedTermLoanManager(poolManager.loanManagerList(0));

        deposit(makeAddr("depositor"), 1_500_000e6);

        loan = fundAndDrawdownLoan({
            borrower:    makeAddr("borrower"),
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(100e6), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e6), uint256(0), uint256(0.0001e6), uint256(0.031536e6)],
            loanManager: poolManager.loanManagerList(0)
        });
    }

    function test_isLiquidationActive_beforeLiquidation() external {
        assertTrue(!loanManager.isLiquidationActive(loan));
    }

    function test_isLiquidationActive_duringLiquidation() external {
        vm.warp(start + 1_000_000 + 5 days + 1);

        assertTrue(!loanManager.isLiquidationActive(loan));

        triggerDefault(loan, address(liquidatorFactory));

        assertTrue(loanManager.isLiquidationActive(loan));
    }

    function test_isLiquidationActive_afterLiquidation() external {
        vm.warp(start + 1_000_000 + 5 days + 1);

        triggerDefault(loan, address(liquidatorFactory));

        assertTrue(loanManager.isLiquidationActive(loan));

        liquidateCollateral(loan);

        assertTrue(!loanManager.isLiquidationActive(loan));
    }

}
