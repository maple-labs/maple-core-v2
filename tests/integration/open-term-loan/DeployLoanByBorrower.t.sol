// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IMapleProxyFactory, IOpenTermLoan } from "../../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../../TestBase.sol";

contract DeployLoanByBorrowerTests is TestBase {

    address loanManagerOTL;

    address borrower = makeAddr("borrower");

    address[2] assets;

    uint256[3] terms   = [uint256(12 hours), uint256(1_000_000), uint256(3)];
    uint256[3] amounts = [uint256(0), uint256(1_500_000e6), uint256(1_500_000e6)];
    uint256[4] rates   = [uint256(3.1536e6), uint256(0), uint256(0), uint256(0)];

    function setUp() public override {
        super.setUp();

        loanManagerOTL = poolManager.strategyList(0);

        assets = [address(collateralAsset), address(fundsAsset)];

        vm.startPrank(governor);
        globals.setCanDeployFrom(openTermLoanFactory, borrower, false);

        globals.setValidInstanceOf("LOAN_FACTORY", openTermLoanFactory, false);

        globals.setValidBorrower(borrower, false);
        vm.stopPrank();
    }

    function test_deployLoan_OTL_invalidBorrower() external {
        vm.prank(governor);
        globals.setValidInstanceOf("LOAN_FACTORY", openTermLoanFactory, true);

        vm.prank(borrower);
        vm.expectRevert("LF:CI:CANNOT_DEPLOY");
        IMapleProxyFactory(openTermLoanFactory).createInstance({
            arguments_: abi.encode(borrower, loanManagerOTL, assets[1], amounts[1], terms, rates),
            salt_:      "SALT"
        });

        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

        vm.prank(borrower);
        IMapleProxyFactory(openTermLoanFactory).createInstance({
            arguments_: abi.encode(borrower, loanManagerOTL, assets[1], amounts[1], terms, rates),
            salt_:      "SALT"
        });
    }

    function test_deployLoan_OTL_invalidInstance() external {
        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

        vm.prank(borrower);
        vm.expectRevert("LF:CI:CANNOT_DEPLOY");
        IMapleProxyFactory(openTermLoanFactory).createInstance({
            arguments_: abi.encode(borrower, loanManagerOTL, assets[1], amounts[1], terms, rates),
            salt_:      "SALT"
        });

        vm.prank(governor);
        globals.setValidInstanceOf("LOAN_FACTORY", openTermLoanFactory, true);

        vm.prank(borrower);
        IMapleProxyFactory(openTermLoanFactory).createInstance({
            arguments_: abi.encode(borrower, loanManagerOTL, assets[1], amounts[1], terms, rates),
            salt_:      "SALT"
        });
    }

    function test_deployLoan_OTL_success() external {
        vm.startPrank(governor);
        globals.setValidBorrower(borrower, true);
        globals.setValidInstanceOf("LOAN_FACTORY", openTermLoanFactory, true);
        vm.stopPrank();

        vm.prank(borrower);
        address instance_ = IMapleProxyFactory(openTermLoanFactory).createInstance({
            arguments_: abi.encode(borrower, loanManagerOTL, assets[1], amounts[1], terms, rates),
            salt_:      "SALT"
        });

        assertTrue(IMapleProxyFactory(openTermLoanFactory).isInstance(instance_));

        assertEq(IOpenTermLoan(instance_).factory(), openTermLoanFactory);
    }

}
