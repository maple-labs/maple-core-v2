// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IFixedTermLoan } from "../../contracts/interfaces/Interfaces.sol";

import { Address } from "../../contracts/Contracts.sol";

import { TestBase } from "../TestBase.sol";

contract RemoveLoanImpairmentFailureTests is TestBase {

    address loan;

    function setUp() public virtual override {
        super.setUp();

        depositLiquidity({
            lp: address(new Address()),
            liquidity: 1_500_000e6
        });

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
            rates:       [uint256(0.075e18), uint256(0), uint256(0), uint256(0)]
        });
    }

    function test_removeLoanImpairment_notAuthorized() external {
        vm.expectRevert("PM:RLI:NOT_AUTHORIZED");
        poolManager.removeLoanImpairment(loan);
    }

    function test_removeLoanImpairment_notPoolManager() external {
        vm.expectRevert("LM:RLI:NOT_PM");
        loanManager.removeLoanImpairment(loan, false);
    }

    function test_removeLoanImpairment_notGovernor() external {
        vm.prank(address(governor));
        poolManager.impairLoan(loan);

        vm.prank(address(poolDelegate));
        vm.expectRevert("LM:RLI:NO_AUTH");
        poolManager.removeLoanImpairment(loan);
    }

    function test_removeLoanImpairment_notLender() external {
        vm.expectRevert("ML:RLI:NOT_LENDER");
        IFixedTermLoan(loan).removeLoanImpairment();
    }

    function test_removeLoanImpairment_notImpaired() external {
        vm.prank(address(poolDelegate));
        vm.expectRevert("LM:RLI:PAST_DATE");
        poolManager.removeLoanImpairment(loan);
    }

    function test_removeLoanImpairment_pastDate() external {
        vm.prank(address(poolDelegate));
        poolManager.impairLoan(loan);

        vm.warp(start + 30 days + 1);
        vm.prank(address(poolDelegate));
        vm.expectRevert("LM:RLI:PAST_DATE");
        poolManager.removeLoanImpairment(loan);

        vm.warp(start + 30 days);
        vm.prank(address(poolDelegate));
        poolManager.removeLoanImpairment(loan);
    }

}
