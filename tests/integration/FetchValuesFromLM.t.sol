// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IFixedTermLoanManager } from "../../contracts/interfaces/Interfaces.sol";

import { Address } from "../../contracts/Contracts.sol";

import { TestBase } from "../TestBase.sol";

contract LoanManagerAddressGetterTests is TestBase {

    function test_addressGetters() external {
        IFixedTermLoanManager loanManager = IFixedTermLoanManager(poolManager.loanManagerList(0));

        assertEq(loanManager.governor(),      governor);
        assertEq(loanManager.globals(),       address(globals));
        assertEq(loanManager.mapleTreasury(), treasury);
        assertEq(loanManager.poolDelegate(),  poolDelegate);
    }

}

contract LoanManagerIsLiquidationActiveGetterTests is TestBase {

    address loan;

    IFixedTermLoanManager loanManager;

    function setUp() public override {
        super.setUp();

        loanManager = IFixedTermLoanManager(poolManager.loanManagerList(0));

        depositLiquidity(address(new Address()), 1_500_000e6);

        loan = fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(5 days), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.031536e18), uint256(0), uint256(0.0001e18), uint256(0.031536e18 / 10)],
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

    /// @TODO: Add test_isLiquidationActive_afterLiquidation

}