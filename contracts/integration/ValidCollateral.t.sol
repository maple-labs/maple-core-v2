// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address } from "../../modules/contract-test-utils/contracts/test.sol";

import { MapleLoan as Loan }                       from "../../modules/loan-v400/contracts/MapleLoan.sol";
import { MapleLoanFactory as LoanFactory }         from "../../modules/loan-v400/contracts/MapleLoanFactory.sol";
import { MapleLoanInitializer as LoanInitializer } from "../../modules/loan-v400/contracts/MapleLoanInitializer.sol";

import { TestBase } from "../utilities/TestBase.sol";

contract ValidCollateralTests is TestBase {

    function test_setValidCollateral_invalidCollateral() external {
        address borrower = address(new Address());

        vm.prank(governor);
        globals.setValidCollateralAsset(address(collateralAsset), false);

        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

        bytes memory arguments = new LoanInitializer().encodeArguments({
            borrower_:    borrower,
            feeManager_:  address(feeManager),
            assets_:      [address(collateralAsset), address(fundsAsset)],
            termDetails_: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts_:     [uint256(0), uint256(1_500_000e6), uint256(1_500_000e6)],
            rates_:       [uint256(3.1536e18), uint256(0), uint256(0), uint256(0)],
            fees_:        [nextDelegateOriginationFee, nextDelegateServiceFee]
        });

        vm.expectRevert("MPF:CI:FAILED");
        Loan(LoanFactory(loanFactory).createInstance({
            arguments_: arguments,
            salt_: "SALT"
        }));

        vm.prank(governor);
        globals.setValidCollateralAsset(address(collateralAsset), true);

        Loan(LoanFactory(loanFactory).createInstance({
            arguments_: arguments,
            salt_: "SALT"
        }));
    }

}
