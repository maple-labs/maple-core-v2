// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IBorrowerActions } from "../../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../../TestBase.sol";

contract MapleBorrowerActionsTests is TestBase {

    address borrower = makeAddr("borrower");

    address openTermLoan;

    IBorrowerActions mapleBorrowerActions;

    function setUp() public override {
        super.setUp();

        mapleBorrowerActions = IBorrowerActions(borrowerActions);

        vm.prank(governor);
        globals.setValidInstanceOf("BORROWER_ACTIONS", address(borrowerActions), true);

        openTermLoan = createOpenTermLoan({
            borrower:  borrower,
            lender:    poolManager.strategyList(0),
            asset:     address(fundsAsset),
            principal: 2_500_000e6,
            terms:     [uint32(5 days), uint32(3 days),  uint32(30 days)],
            rates:     [uint64(0.01e6), uint64(0.08e6), uint64(0.05e6), uint64(0.02e6)]
        });
    }

    function test_acceptLoanTerms_OTL_failIfNotBorrower() public {
        vm.expectRevert("MBA:NOT_BORROWER");
        mapleBorrowerActions.acceptLoanTerms(openTermLoan);
    }

    function test_acceptLoanTerms_OTL() public {
        vm.prank(borrower);
        mapleBorrowerActions.acceptLoanTerms(openTermLoan);
    }

}
