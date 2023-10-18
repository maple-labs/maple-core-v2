// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { FixedTermLoanFactory, OpenTermLoanFactory, FixedTermLoan, OpenTermLoan } from "../../contracts/Contracts.sol";

import { TestBase } from "../TestBase.sol";

contract DeployLoanByBorrowerTests is TestBase {

    address loanManagerFTL;
    address loanManagerOTL;

    address borrower = makeAddr("borrower");

    address[2] assets;

    uint256[3] terms   = [uint256(12 hours), uint256(1_000_000), uint256(3)];
    uint256[3] amounts = [uint256(0), uint256(1_500_000e6), uint256(1_500_000e6)];
    uint256[4] rates   = [uint256(3.1536e6), uint256(0), uint256(0), uint256(0)];
    uint256[2] fees    = [uint256(0), uint256(0)];

    function setUp() public override {
        super.setUp();

        loanManagerFTL = poolManager.loanManagerList(0);
        loanManagerOTL = poolManager.loanManagerList(1);

        assets = [address(collateralAsset), address(fundsAsset)];

        vm.startPrank(governor);
        globals.setCanDeployFrom(fixedTermLoanFactory, borrower, false);
        globals.setCanDeployFrom(openTermLoanFactory,  borrower, false);

        globals.setValidInstanceOf("LOAN_FACTORY", fixedTermLoanFactory, false);
        globals.setValidInstanceOf("LOAN_FACTORY", openTermLoanFactory,  false);

        globals.setValidBorrower(borrower, false);
        vm.stopPrank();
    }

    function test_deployLoan_FTL_setCanDeployFromByOA() external {
        assertEq(globals.canDeployFrom(fixedTermLoanFactory, borrower), false);

        vm.expectRevert("MG:NOT_GOV_OR_OA");
        globals.setCanDeployFrom(fixedTermLoanFactory, borrower, true);

        vm.prank(operationalAdmin);
        globals.setCanDeployFrom(fixedTermLoanFactory, borrower, true);

        assertEq(globals.canDeployFrom(fixedTermLoanFactory, borrower), true);
    }

    function test_deployLoan_FTL_invalidBorrower() external {
        vm.prank(governor);
        globals.setValidInstanceOf("LOAN_FACTORY", fixedTermLoanFactory, true);

        vm.prank(borrower);
        vm.expectRevert("MLF:CI:CANNOT_DEPLOY");
        FixedTermLoanFactory(fixedTermLoanFactory).createInstance({
            arguments_: abi.encode(borrower, loanManagerFTL, address(fixedTermFeeManager), assets, terms, amounts, rates, fees),
            salt_:      "SALT"
        });

        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

        vm.prank(borrower);
        FixedTermLoanFactory(fixedTermLoanFactory).createInstance({
            arguments_: abi.encode(borrower, loanManagerFTL, address(fixedTermFeeManager), assets, terms, amounts, rates, fees),
            salt_:      "SALT"
        });
    }

    function test_deployLoan_FTL_validBorrowerSetByOA() external {
        vm.prank(governor);
        globals.setValidInstanceOf("LOAN_FACTORY", fixedTermLoanFactory, true);

        vm.prank(borrower);
        vm.expectRevert("MLF:CI:CANNOT_DEPLOY");
        FixedTermLoanFactory(fixedTermLoanFactory).createInstance({
            arguments_: abi.encode(borrower, loanManagerFTL, address(fixedTermFeeManager), assets, terms, amounts, rates, fees),
            salt_:      "SALT"
        });

        vm.prank(operationalAdmin);
        globals.setValidBorrower(borrower, true);

        vm.prank(borrower);
        FixedTermLoanFactory(fixedTermLoanFactory).createInstance({
            arguments_: abi.encode(borrower, loanManagerFTL, address(fixedTermFeeManager), assets, terms, amounts, rates, fees),
            salt_:      "SALT"
        });
    }

    function test_deployLoan_FTL_invalidInstance() external {
        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

        vm.prank(borrower);
        vm.expectRevert("MLF:CI:CANNOT_DEPLOY");
        FixedTermLoanFactory(fixedTermLoanFactory).createInstance({
            arguments_: abi.encode(borrower, loanManagerFTL, address(fixedTermFeeManager), assets, terms, amounts, rates, fees),
            salt_:      "SALT"
        });

        vm.prank(governor);
        globals.setValidInstanceOf("LOAN_FACTORY", fixedTermLoanFactory, true);

        vm.prank(borrower);
        FixedTermLoanFactory(fixedTermLoanFactory).createInstance({
            arguments_: abi.encode(borrower, loanManagerFTL, address(fixedTermFeeManager), assets, terms, amounts, rates, fees),
            salt_:      "SALT"
        });
    }

    function test_deployLoan_FTL_validInstanceSetByOA() external {
        vm.prank(operationalAdmin);
        globals.setValidBorrower(borrower, true);

        vm.prank(borrower);
        vm.expectRevert("MLF:CI:CANNOT_DEPLOY");
        FixedTermLoanFactory(fixedTermLoanFactory).createInstance({
            arguments_: abi.encode(borrower, loanManagerFTL, address(fixedTermFeeManager), assets, terms, amounts, rates, fees),
            salt_:      "SALT"
        });

        vm.prank(operationalAdmin);
        globals.setValidInstanceOf("LOAN_FACTORY", fixedTermLoanFactory, true);

        vm.prank(borrower);
        FixedTermLoanFactory(fixedTermLoanFactory).createInstance({
            arguments_: abi.encode(borrower, loanManagerFTL, address(fixedTermFeeManager), assets, terms, amounts, rates, fees),
            salt_:      "SALT"
        });
    }

    function test_deployLoan_FTL_success() external {
        vm.startPrank(governor);
        globals.setValidBorrower(borrower, true);
        globals.setValidInstanceOf("LOAN_FACTORY", fixedTermLoanFactory, true);
        vm.stopPrank();

        vm.prank(borrower);
        address instance_ = FixedTermLoanFactory(fixedTermLoanFactory).createInstance({
            arguments_: abi.encode(borrower, loanManagerFTL, address(fixedTermFeeManager), assets, terms, amounts, rates, fees),
            salt_:      "SALT"
        });

        assertTrue(FixedTermLoanFactory(fixedTermLoanFactory).isLoan(instance_));

        assertEq(FixedTermLoan(instance_).factory(), fixedTermLoanFactory);
    }

    function test_deployLoan_OTL_invalidBorrower() external {
        vm.prank(governor);
        globals.setValidInstanceOf("LOAN_FACTORY", openTermLoanFactory, true);

        vm.prank(borrower);
        vm.expectRevert("LF:CI:CANNOT_DEPLOY");
        OpenTermLoanFactory(openTermLoanFactory).createInstance({
            arguments_: abi.encode(borrower, loanManagerOTL, assets[1], amounts[1], terms, rates),
            salt_:      "SALT"
        });

        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

        vm.prank(borrower);
        OpenTermLoanFactory(openTermLoanFactory).createInstance({
            arguments_: abi.encode(borrower, loanManagerOTL, assets[1], amounts[1], terms, rates),
            salt_:      "SALT"
        });
    }

    function test_deployLoan_OTL_invalidInstance() external {
        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

        vm.prank(borrower);
        vm.expectRevert("LF:CI:CANNOT_DEPLOY");
        OpenTermLoanFactory(openTermLoanFactory).createInstance({
            arguments_: abi.encode(borrower, loanManagerOTL, assets[1], amounts[1], terms, rates),
            salt_:      "SALT"
        });

        vm.prank(governor);
        globals.setValidInstanceOf("LOAN_FACTORY", openTermLoanFactory, true);

        vm.prank(borrower);
        OpenTermLoanFactory(openTermLoanFactory).createInstance({
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
        address instance_ = OpenTermLoanFactory(openTermLoanFactory).createInstance({
            arguments_: abi.encode(borrower, loanManagerOTL, assets[1], amounts[1], terms, rates),
            salt_:      "SALT"
        });

        assertTrue(OpenTermLoanFactory(openTermLoanFactory).isLoan(instance_));

        assertEq(OpenTermLoan(instance_).factory(), openTermLoanFactory);
    }

}
