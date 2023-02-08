// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address } from "../../modules/contract-test-utils/contracts/test.sol";

import { MapleLoan }            from "../../modules/fixed-term-loan/contracts/MapleLoan.sol";
import { MapleLoanFactory }     from "../../modules/fixed-term-loan/contracts/MapleLoanFactory.sol";
import { MapleLoanInitializer } from "../../modules/fixed-term-loan/contracts/MapleLoanInitializer.sol";

import { TestBase } from "../TestBase.sol";

contract ValidCollateralTests is TestBase {

    function test_setValidCollateral_invalidCollateral() external {
        address borrower = address(new Address());

        vm.prank(governor);
        globals.setValidCollateralAsset(address(collateralAsset), false);

        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

        bytes memory arguments = new MapleLoanInitializer().encodeArguments({
            borrower_:    borrower,
            lender_:      address(loanManager),
            feeManager_:  address(feeManager),
            assets_:      [address(collateralAsset), address(fundsAsset)],
            termDetails_: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts_:     [uint256(0), uint256(1_500_000e6), uint256(1_500_000e6)],
            rates_:       [uint256(3.1536e18), uint256(0), uint256(0), uint256(0)],
            fees_:        [nextDelegateOriginationFee, nextDelegateServiceFee]
        });

        vm.expectRevert("MPF:CI:FAILED");
        MapleLoan(MapleLoanFactory(loanFactory).createInstance({
            arguments_: arguments,
            salt_: "SALT"
        }));

        vm.prank(governor);
        globals.setValidCollateralAsset(address(collateralAsset), true);

        MapleLoan(MapleLoanFactory(loanFactory).createInstance({
            arguments_: arguments,
            salt_: "SALT"
        }));
    }

}
