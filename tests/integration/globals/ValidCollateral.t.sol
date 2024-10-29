// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IProxyFactoryLike } from "../../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../../TestBase.sol";

contract ValidCollateralTests is TestBase {

    function test_setIsCollateral_invalidCollateral() external {
        address borrower = makeAddr("borrower");

        vm.prank(governor);
        globals.setValidCollateralAsset(address(collateralAsset), false);

        vm.prank(governor);
        globals.setValidBorrower(borrower, true);

        bytes memory arguments = abi.encode(
            borrower,
            address(poolManager.strategyList(0)),
            address(fixedTermFeeManager),
            [address(collateralAsset), address(fundsAsset)],
            [uint256(12 hours), uint256(1_000_000), uint256(3)],
            [uint256(0), uint256(1_500_000e6), uint256(1_500_000e6)],
            [uint256(3.1536e6), uint256(0), uint256(0), uint256(0)],
            [nextDelegateOriginationFee, nextDelegateServiceFee]
        );

        vm.prank(borrower);
        vm.expectRevert("MPF:CI:FAILED");
        IProxyFactoryLike(fixedTermLoanFactory).createInstance({
            arguments_: arguments,
            salt_: "SALT"
        });

        vm.prank(governor);
        globals.setValidCollateralAsset(address(collateralAsset), true);

        vm.prank(borrower);
        IProxyFactoryLike(fixedTermLoanFactory).createInstance({
            arguments_: arguments,
            salt_: "SALT"
        });
    }

}
