// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { ILoanManagerLike } from "../../contracts/interfaces/Interfaces.sol";

import { Address } from "../../contracts/Contracts.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

contract TriggerDefaultFailureTests is TestBaseWithAssertions {

    address loan;

    function setUp() public virtual override {
        super.setUp();

        depositLiquidity(address(new Address()), 1_500_000e6);

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         275e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.0066e6,
            platformManagementFeeRate:  0.08e6
        });

        loan = fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(5 days), uint256(30 days), uint256(3)],
            amounts:     [uint256(0), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.075e18), uint256(0), uint256(0), uint256(0)],
            loanManager: poolManager.loanManagerList(0)
        });
    }

    function test_triggerDefault_notAuthorized() external {
        vm.expectRevert("PM:TD:NOT_AUTHORIZED");
        poolManager.triggerDefault(loan, address(liquidatorFactory));
    }

    function test_triggerDefault_notFactory() external {
        vm.prank(address(poolDelegate));
        vm.expectRevert("PM:TD:NOT_FACTORY");
        poolManager.triggerDefault(loan, address(1));
    }

    function test_triggerDefault_notPoolManager() external {
        ILoanManagerLike loanManager = ILoanManagerLike(poolManager.loanManagerList(0));

        vm.expectRevert("LM:TD:NOT_PM");
        loanManager.triggerDefault(loan, address(liquidatorFactory));
    }

}
