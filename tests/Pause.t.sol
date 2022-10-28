// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestBaseWithAssertions } from "../contracts/utilities/TestBaseWithAssertions.sol";

import { Address }           from "../modules/contract-test-utils/contracts/test.sol";
import { Liquidator }        from "../modules/liquidations/contracts/Liquidator.sol";
import { MapleLoan as Loan } from "../modules/loan/contracts/MapleLoan.sol";

contract PauseTests is TestBaseWithAssertions {

    bytes[] data;

    Liquidator liquidator;
    Loan       loan;

    function setUp() public override {
        super.setUp();

        depositLiquidity({
            lp:        address(new Address()),
            liquidity: 1_500_000e6
        });

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,  // 10k after 1m seconds
            platformManagementFeeRate:  0.08e6
        });

        loan = fundAndDrawdownLoan({
            borrower:    address(new Address()),
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e18), uint256(0), uint256(0), uint256(0)]
        });

        vm.warp(start + 1_005_001);

        vm.prank(poolDelegate);
        poolManager.triggerDefault(address(loan), address(liquidatorFactory));

        ( , , , , , address liquidator_ ) = loanManager.liquidationInfo(address(loan));

        liquidator = Liquidator(liquidator_);

        vm.prank(governor);
        globals.setProtocolPause(true);
    }

    function test_pauseProtocol() external {

        /******************************************************************************************************************************/
        /*** Pool                                                                                                                   ***/
        /******************************************************************************************************************************/

        // TODO: Uncomment after submodules are updated.
        // vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        // pool.approve(address(0), 0);

        // TODO: Uncomment after submodules are updated.
        // vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        // pool.decreaseAllowance(address(0), 0);

        vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        pool.deposit(0, address(0));

        vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        pool.depositWithPermit(0, address(0), 0, 0, 0, 0);

        // TODO: Uncomment after submodules are updated.
        // vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        // pool.increaseAllowance(address(0), 0);

        vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        pool.mint(0, address(0));

        vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        pool.mintWithPermit(0, address(0), 0, 0, 0, 0, 0);

        // TODO: Uncomment after submodules are updated.
        // vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        // pool.permit(address(0), address(0), 0, 0, 0, 0, 0);

        vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        pool.redeem(0, address(0), address(0));

        vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        pool.removeShares(0, address(0));

        vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        pool.requestRedeem(0, address(0));

        vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        pool.requestWithdraw(0, address(0));

        vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        pool.transfer(address(0), 0);

        vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        pool.transferFrom(address(0), address(0), 0);

        vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        pool.withdraw(0, address(0), address(0));

        /******************************************************************************************************************************/
        /*** Pool Manager                                                                                                           ***/
        /******************************************************************************************************************************/

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.acceptNewTerms(address(0), address(0), 0, data, 0);

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.acceptPendingPoolDelegate();

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.addLoanManager(address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.depositCover(0);

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.finishCollateralLiquidation(address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.fund(0, address(0), address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.impairLoan(address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.processRedeem(0, address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.removeLoanImpairment(address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.removeLoanManager(address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.removeShares(0, address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.requestRedeem(0, address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.setActive(true);

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.setAllowedLender(address(0), false);

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.setAllowedSlippage(address(0), address(0), 0);

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.setDelegateManagementFeeRate(0);

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.setImplementation(address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.setLiquidityCap(0);

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.setMinRatio(address(0), address(0), 0);

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.setOpenToPublic();

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.setPendingPoolDelegate(address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.setWithdrawalManager(address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.triggerDefault(address(0), address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.upgrade(0, "");

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.withdrawCover(0, address(0));

        /******************************************************************************************************************************/
        /*** Withdrawal Manager                                                                                                     ***/
        /******************************************************************************************************************************/

        vm.expectRevert("WM:PROTOCOL_PAUSED");
        withdrawalManager.upgrade(0, "");

        vm.expectRevert("WM:PROTOCOL_PAUSED");
        withdrawalManager.setExitConfig(0, 0);

        /******************************************************************************************************************************/
        /*** Loan                                                                                                                   ***/
        /******************************************************************************************************************************/

        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.upgrade(0, "");

        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.acceptBorrower();

        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.closeLoan(0);

        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.drawdownFunds(0, address(0));

        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.makePayment(0);

        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.postCollateral(0);

        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.proposeNewTerms(address(0), 0, data);

        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.removeCollateral(0, address(0));

        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.returnFunds(0);

        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.setPendingBorrower(address(0));

        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.acceptLender();

        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.rejectNewTerms(address(0), 0, data);

        vm.expectRevert("L:PROTOCOL_PAUSED");
        loan.skim(address(0), address(0));

        /******************************************************************************************************************************/
        /*** Liquidator                                                                                                             ***/
        /******************************************************************************************************************************/

        vm.expectRevert("LIQ:PROTOCOL_PAUSED");
        liquidator.upgrade(0, "");

        vm.expectRevert("LIQ:PROTOCOL_PAUSED");
        liquidator.liquidatePortion(0, 0, "");
    }

}
