// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address }   from "../../modules/contract-test-utils/contracts/test.sol";
import { MapleLoan } from "../../modules/loan/contracts/MapleLoan.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

contract TriggerDefaultFailureTests is TestBaseWithAssertions {

    MapleLoan internal loan;

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

    function test_triggerDefault_notAuthorized() external {
        vm.expectRevert("PM:TD:NOT_AUTHORIZED");
        poolManager.triggerDefault(address(loan), address(liquidatorFactory));
    }

    function test_triggerDefault_notFactory() external {
        vm.prank(address(poolDelegate));
        vm.expectRevert("PM:TD:NOT_FACTORY");
        poolManager.triggerDefault(address(loan), address(1));
    }

    function test_triggerDefault_notPoolManager() external {
        vm.prank(address(loanManager));
        vm.expectRevert("LM:TD:NOT_PM");
        loanManager.triggerDefault(address(loan), address(liquidatorFactory));
    }

}
