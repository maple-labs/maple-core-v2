// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address } from "../../../modules/contract-test-utils/contracts/test.sol";

import { Liquidator }            from "../../../modules/liquidations/contracts/Liquidator.sol";
import { LiquidatorInitializer } from "../../../modules/liquidations/contracts/LiquidatorInitializer.sol";

import { MapleLoan as Loan }    from "../../../modules/loan-v400/contracts/MapleLoan.sol";
import { MapleLoanInitializer } from "../../../modules/loan-v400/contracts/MapleLoanInitializer.sol";

import { ILoanManagerInitializer } from "../../../modules/pool-v2/contracts/interfaces/ILoanManagerInitializer.sol";
import { IMapleProxyFactory }      from "../../../modules/pool-v2/modules/maple-proxy-factory/contracts/interfaces/IMapleProxyFactory.sol";
import { IPoolManagerInitializer } from "../../../modules/pool-v2/contracts/interfaces/IPoolManagerInitializer.sol";

import { IWithdrawalManagerInitializer } from "../../../modules/withdrawal-manager/contracts/interfaces/IWithdrawalManagerInitializer.sol";

import { TestBaseWithAssertions } from "../../utilities/TestBaseWithAssertions.sol";

contract PauseTests is TestBaseWithAssertions {

    address internal borrower          = address(new Address());
    address internal pausePoolDelegate = address(new Address());

    bytes[] internal data;

    Liquidator internal liquidator;
    Loan       internal loan;

    function setUp() public override {
        super.setUp();

        // Create new implementations for upgrades
        address liquidatorImplementationForUpgrade        = address(new Address());
        address loanImplementationForUpgrade              = address(new Address());
        address loanManagerImplementationForUpgrade       = address(new Address());
        address poolManagerImplementationForUpgrade       = address(new Address());
        address withdrawalManagerImplementationForUpgrade = address(new Address());

        // Register implementation and upgrade paths
        vm.startPrank(governor);

        IMapleProxyFactory(liquidatorFactory).registerImplementation(2, liquidatorImplementationForUpgrade, address(0));
        IMapleProxyFactory(liquidatorFactory).enableUpgradePath(1, 2, address(0));

        IMapleProxyFactory(loanFactory).registerImplementation(2, loanImplementationForUpgrade, address(0));
        IMapleProxyFactory(loanFactory).enableUpgradePath(1, 2, address(0));

        IMapleProxyFactory(loanManagerFactory).registerImplementation(2, loanManagerImplementationForUpgrade, address(0));
        IMapleProxyFactory(loanManagerFactory).enableUpgradePath(1, 2, address(0));

        IMapleProxyFactory(poolManagerFactory).registerImplementation(2, poolManagerImplementationForUpgrade, address(0));
        IMapleProxyFactory(poolManagerFactory).enableUpgradePath(1, 2, address(0));

        IMapleProxyFactory(withdrawalManagerFactory).registerImplementation(2, withdrawalManagerImplementationForUpgrade, address(0));
        IMapleProxyFactory(withdrawalManagerFactory).enableUpgradePath(1, 2, address(0));

        vm.stopPrank();

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
        bytes memory arguments = IPoolManagerInitializer(poolManagerInitializer).encodeArguments(
            pausePoolDelegate,
            address(fundsAsset),
            0,
            "Maple Pool",
            "MP"
        );

        // vm.prank(address(deployer));
        // vm.expectRevert("MPF:PROTOCOL_PAUSED");
        // IMapleProxyFactory(poolManagerFactory).createInstance(arguments, salt_);

        // Loan Manager
        arguments = ILoanManagerInitializer(loanManagerInitializer).encodeArguments(address(pool));

        // vm.prank(address(deployer));
        // vm.expectRevert("MPF:PROTOCOL_PAUSED");
        // IMapleProxyFactory(loanManagerFactory).createInstance(arguments, salt_);

        // Withdrawal Manager
        arguments = IWithdrawalManagerInitializer(withdrawalManagerInitializer).encodeArguments(address(pool), 1 weeks, 1 days);

        // vm.expectRevert("MPF:PROTOCOL_PAUSED");
        // vm.prank(address(deployer));
        // IMapleProxyFactory(withdrawalManagerFactory).createInstance(arguments, salt_);

        // Liquidator
        arguments = LiquidatorInitializer(liquidatorInitializer).encodeArguments(
            address(loanManager),
            address(collateralAsset),
            address(fundsAsset)
        );

        // vm.expectRevert("MPF:PROTOCOL_PAUSED");
        // vm.prank(address(loanManager));
        // IMapleProxyFactory(liquidatorFactory).createInstance(arguments, salt_);

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
        loan.upgrade(2, "");

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

        /**********************************************************************************************************************************/
        /*** Loan Manager                                                                                                               ***/
        /**********************************************************************************************************************************/

        // vm.prank(governor);
        // vm.expectRevert("MPF:PROTOCOL_PAUSED");
        // loanManager.upgrade(2, "");

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
        poolManager.processRedeem(0, address(0), address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.removeLoanImpairment(address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.removeLoanManager(address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.removeShares(0, address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.requestRedeem(0, address(0), address(0));

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.setActive(true);

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.setAllowedLender(address(0), false);

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.setAllowedSlippage(address(0), address(0), 0);

        vm.expectRevert("PM:PROTOCOL_PAUSED");
        poolManager.setDelegateManagementFeeRate(0);

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
