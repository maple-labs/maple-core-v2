// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address }   from "../../modules/contract-test-utils/contracts/test.sol";
import { MapleLoan } from "../../modules/loan/contracts/MapleLoan.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

contract FinishCollateralLiquidationFailureTests is TestBaseWithAssertions {

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
            amounts:     [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.075e18), uint256(0), uint256(0), uint256(0)]
        });
    }

    function test_finishCollateralLiquidation_notAuthorized() external {
        vm.expectRevert("PM:FCL:NOT_AUTHORIZED");
        poolManager.finishCollateralLiquidation(address(loan));
    }

    function test_finishCollateralLiquidation_notPoolManager() external {
        vm.prank(address(1));
        vm.expectRevert("LM:FCL:NOT_PM");
        loanManager.finishCollateralLiquidation(address(loan));
    }

    function test_finishCollateralLiquidation_notFinished() external {
        // Warp to end of grace period and initiate liquidation.
        vm.warp(start + 30 days + 5 days + 1);

        vm.prank(address(poolDelegate));
        poolManager.triggerDefault(address(loan), address(liquidatorFactory));

        vm.prank(address(poolDelegate));
        vm.expectRevert("LM:FCL:LIQ_ACTIVE");
        poolManager.finishCollateralLiquidation(address(loan));
    }

}
