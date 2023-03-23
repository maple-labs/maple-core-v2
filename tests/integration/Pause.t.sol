// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IFixedTermLoan,
    IFixedTermLoanManager,
    ILiquidator,
    ILoanLike,
    ILoanManagerLike,
    IProxyFactoryLike
} from "../../contracts/interfaces/Interfaces.sol";

import { EmptyContract } from "../../contracts/Contracts.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

contract PauseTests is TestBaseWithAssertions {

    address borrower          = makeAddr("borrower");
    address pausePoolDelegate = makeAddr("pausePoolDelegate");

    address loan;
    address loanManager;

    bytes[] data;

    ILiquidator liquidator;

    function setUp() public override {
        super.setUp();

        // Create new implementations for upgrades
        address liquidatorImplementationForUpgrade        = address(new EmptyContract());
        address loanImplementationForUpgrade              = address(new EmptyContract());
        address loanManagerImplementationForUpgrade       = address(new EmptyContract());
        address poolManagerImplementationForUpgrade       = address(new EmptyContract());
        address withdrawalManagerImplementationForUpgrade = address(new EmptyContract());

        // Register implementation and upgrade paths
        vm.startPrank(governor);

        IProxyFactoryLike(liquidatorFactory).registerImplementation(2, liquidatorImplementationForUpgrade, address(0));
        IProxyFactoryLike(liquidatorFactory).enableUpgradePath(1, 2, address(0));

        IProxyFactoryLike(fixedTermLoanFactory).registerImplementation(2, loanImplementationForUpgrade, address(0));
        IProxyFactoryLike(fixedTermLoanFactory).enableUpgradePath(1, 2, address(0));

        IProxyFactoryLike(fixedTermLoanManagerFactory).registerImplementation(2, loanManagerImplementationForUpgrade, address(0));
        IProxyFactoryLike(fixedTermLoanManagerFactory).enableUpgradePath(1, 2, address(0));

        IProxyFactoryLike(poolManagerFactory).registerImplementation(2, poolManagerImplementationForUpgrade, address(0));
        IProxyFactoryLike(poolManagerFactory).enableUpgradePath(1, 2, address(0));

        IProxyFactoryLike(withdrawalManagerFactory).registerImplementation(2, withdrawalManagerImplementationForUpgrade, address(0));
        IProxyFactoryLike(withdrawalManagerFactory).enableUpgradePath(1, 2, address(0));

        vm.stopPrank();

        depositLiquidity(makeAddr("depositor"), 1_500_000e6);

        setupFees({
            delegateOriginationFee:     500e6,
            delegateServiceFee:         300e6,
            delegateManagementFeeRate:  0.02e6,
            platformOriginationFeeRate: 0.001e6,
            platformServiceFeeRate:     0.31536e6,  // 10k after 1m seconds
            platformManagementFeeRate:  0.08e6
        });

        loanManager = poolManager.loanManagerList(0);

        loan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(5_000), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(3.1536e18), uint256(0), uint256(0), uint256(0)],
            loanManager: loanManager
        });

        vm.warp(start + 1_005_001);

        triggerDefault(loan, address(liquidatorFactory));

        ( , , , , , address liquidator_ ) = IFixedTermLoanManager(loanManager).liquidationInfo(loan);

        liquidator = ILiquidator(liquidator_);

        vm.startPrank(governor);

        globals.setValidPoolDelegate(pausePoolDelegate, true);
        globals.setProtocolPause(true);
        globals.setValidBorrower(borrower, true);

        vm.stopPrank();
    }

    // TODO: Check if anything should be uncommented.
    function test_pauseProtocol() external {

        /**********************************************************************************************************************************/
        /*** Initializations                                                                                                            ***/
        /**********************************************************************************************************************************/

        // Pool Manager
        bytes memory arguments = abi.encode(
            pausePoolDelegate,
            address(fundsAsset),
            0,
            "Maple Pool",
            "MP"
        );

        // vm.prank(address(deployer));
        // vm.expectRevert("MPF:PROTOCOL_PAUSED");
        // IProxyFactoryLike(poolManagerFactory).createInstance(arguments, salt_);

        // Loan Manager
        arguments = abi.encode(address(pool));

        // vm.prank(address(deployer));
        // vm.expectRevert("MPF:PROTOCOL_PAUSED");
        // IProxyFactoryLike(fixedTermLoanManagerFactory).createInstance(arguments, salt_);

        // Withdrawal Manager
        arguments = abi.encode(address(pool), 1 weeks, 1 days);

        // vm.expectRevert("MPF:PROTOCOL_PAUSED");
        // vm.prank(address(deployer));
        // IProxyFactoryLike(withdrawalManagerFactory).createInstance(arguments, salt_);

        // Liquidator
        arguments = abi.encode(
            poolManager.loanManagerList(0),
            address(collateralAsset),
            address(fundsAsset)
        );

        // vm.expectRevert("MPF:PROTOCOL_PAUSED");
        // vm.prank(poolManager.loanManagerList(0));
        // IProxyFactoryLike(liquidatorFactory).createInstance(arguments, salt_);

        /**********************************************************************************************************************************/
        /*** Liquidator                                                                                                                 ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        vm.expectRevert("MPF:PROTOCOL_PAUSED");
        liquidator.upgrade(2, "");

        vm.expectRevert("LIQ:PROTOCOL_PAUSED");
        liquidator.liquidatePortion(0, 0, "");


        /**********************************************************************************************************************************/
        /*** Loan                                                                                                                       ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        vm.expectRevert("L:PROTOCOL_PAUSED");
        ILoanLike(loan).upgrade(2, "");

        vm.expectRevert("L:PROTOCOL_PAUSED");
        ILoanLike(loan).acceptBorrower();

        vm.expectRevert("L:PROTOCOL_PAUSED");
        IFixedTermLoan(loan).closeLoan(0);

        vm.expectRevert("L:PROTOCOL_PAUSED");
        IFixedTermLoan(loan).drawdownFunds(0, address(0));

        vm.expectRevert("L:PROTOCOL_PAUSED");
        IFixedTermLoan(loan).makePayment(0);

        vm.expectRevert("L:PROTOCOL_PAUSED");
        IFixedTermLoan(loan).postCollateral(0);

        vm.expectRevert("L:PROTOCOL_PAUSED");
        ILoanLike(loan).proposeNewTerms(address(0), 0, data);

        vm.expectRevert("L:PROTOCOL_PAUSED");
        IFixedTermLoan(loan).removeCollateral(0, address(0));

        vm.expectRevert("L:PROTOCOL_PAUSED");
        IFixedTermLoan(loan).returnFunds(0);

        vm.expectRevert("L:PROTOCOL_PAUSED");
        ILoanLike(loan).setPendingBorrower(address(0));

        vm.expectRevert("L:PROTOCOL_PAUSED");
        ILoanLike(loan).acceptLender();

        vm.expectRevert("L:PROTOCOL_PAUSED");
        ILoanLike(loan).rejectNewTerms(address(0), 0, data);

        vm.expectRevert("L:PROTOCOL_PAUSED");
        ILoanLike(loan).skim(address(0), address(0));

        /**********************************************************************************************************************************/
        /*** LoanManager                                                                                                                ***/
        /**********************************************************************************************************************************/

        vm.expectRevert("LM:PAUSED");
        IFixedTermLoanManager(loanManager).impairLoan(address(0));

        vm.expectRevert("LM:PAUSED");
        IFixedTermLoanManager(loanManager).removeLoanImpairment(address(0));

        vm.expectRevert("LM:PAUSED");
        IFixedTermLoanManager(loanManager).setAllowedSlippage(address(0), 0);

        vm.expectRevert("LM:PAUSED");
        IFixedTermLoanManager(loanManager).setMinRatio(address(0), 0);

        /**********************************************************************************************************************************/
        /*** Pool                                                                                                                       ***/
        /**********************************************************************************************************************************/

        vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        pool.deposit(0, address(0));

        vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        pool.depositWithPermit(0, address(0), 0, 0, 0, 0);

        vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        pool.mint(0, address(0));

        vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        pool.mintWithPermit(0, address(0), 0, 0, 0, 0, 0);

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

        /**********************************************************************************************************************************/
        /*** Pool Manager                                                                                                               ***/
        /**********************************************************************************************************************************/

        // TODO: Replace `poolManager` with `loanManager`
        // vm.expectRevert("PM:PROTOCOL_PAUSED");
        // poolManager.acceptNewTerms(address(0), address(0), 0, data, 0);

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.acceptPendingPoolDelegate();

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.addLoanManager(address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.depositCover(0);

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.finishCollateralLiquidation(address(0));

        // TODO: Replace `poolManager` with `loanManager`
        // vm.expectRevert("PM:PROTOCOL_PAUSED");
        // poolManager.fund(0, address(0), address(0));

        // TODO: Replace `poolManager` with `loanManager`
        // vm.expectRevert("PM:PROTOCOL_PAUSED");
        // poolManager.impairLoan(address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.processRedeem(0, address(0), address(0));

        // TODO: Replace `poolManager` with `loanManager`
        // vm.expectRevert("PM:PROTOCOL_PAUSED");
        // poolManager.removeLoanImpairment(address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.removeShares(0, address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.requestRedeem(0, address(0), address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.setActive(true);

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.setAllowedLender(address(0), false);

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.setDelegateManagementFeeRate(0);

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.setLiquidityCap(0);

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.setOpenToPublic();

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.setPendingPoolDelegate(address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.setWithdrawalManager(address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.triggerDefault(address(0), address(0));

        // vm.prank(governor);
        // vm.expectRevert("MPF:PROTOCOL_PAUSED");
        // poolManager.upgrade(2, "");

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.withdrawCover(0, address(0));

        /**********************************************************************************************************************************/
        /*** Withdrawal Manager                                                                                                         ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        vm.expectRevert("MPF:PROTOCOL_PAUSED");
        withdrawalManager.upgrade(2, "");

        vm.expectRevert("WM:PROTOCOL_PAUSED");
        withdrawalManager.setExitConfig(0, 0);
    }

}
