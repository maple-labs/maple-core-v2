// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { FeeManager, FixedTermLoan, FixedTermLoanFactory } from "../../contracts/Contracts.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

contract DeployFixedTermLoanTests is TestBaseWithAssertions {

    address loanManager;

    address borrower = makeAddr("borrower");

    address[2] assets;

    uint256[3] terms   = [uint256(12 hours), uint256(1_000_000), uint256(3)];
    uint256[3] amounts = [uint256(0), uint256(1_500_000e6), uint256(1_500_000e6)];
    uint256[4] rates   = [uint256(3.1536e6), uint256(0), uint256(0), uint256(0)];
    uint256[2] fees    = [uint256(0), uint256(0)];

    function setUp() public override {
        super.setUp();

        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

        loanManager = poolManager.loanManagerList(0);

        assets = [address(collateralAsset), address(fundsAsset)];
    }

    function test_deployFixedTermLoan_feeManagerCheck() external {
        vm.prank(governor);
        globals.setValidInstanceOf("FEE_MANAGER", address(feeManager), false);

        vm.prank(borrower);
        vm.expectRevert("MPF:CI:FAILED");
        FixedTermLoanFactory(fixedTermLoanFactory).createInstance({
            arguments_: abi.encode(borrower, loanManager, address(feeManager), assets, terms, amounts, rates, fees),
            salt_:      "SALT"
        });

        vm.prank(governor);
        globals.setValidInstanceOf("FEE_MANAGER", address(feeManager), true);

        // Success
        vm.prank(borrower);
        FixedTermLoanFactory(fixedTermLoanFactory).createInstance({
            arguments_: abi.encode(borrower, loanManager, address(feeManager), assets, terms, amounts, rates, fees),
            salt_:      "SALT"
        });
    }

}
