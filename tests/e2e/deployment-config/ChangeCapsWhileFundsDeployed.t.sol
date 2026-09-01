// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IOpenTermLoan,
    IOpenTermLoanManager,
    IStrategyManager
} from "../../../contracts/interfaces/Interfaces.sol";

import { AllocationStrategyTestBase } from "../../integration/allocation-strategy/AllocationStrategyTestBase.sol";

contract ChangeCapsWhileFundsDeployedTests is AllocationStrategyTestBase {

    address firstBorrower  = makeAddr("firstBorrower");
    address fourthBorrower = makeAddr("fourthBorrower");
    address secondBorrower = makeAddr("secondBorrower");
    address thirdBorrower  = makeAddr("thirdBorrower");

    uint256 allocationAssetsAfterExit   = 400_000e6;
    uint256 allocationBoundaryFunding   = 100_000e6;
    uint256 allocationFinalAssets       = 600_000e6;
    uint256 allocationFinalShares       = 600_000e6;
    uint256 allocationFiniteCap         = 500_000e6;
    uint256 allocationInitialAssets     = 400_000e6;
    uint256 allocationInitialShares     = 400_000e6;
    uint256 allocationLoweredCap        = 300_000e6;
    uint256 allocationMaximumCapFunding = 100_000e6;
    uint256 allocationRaisedCap         = 500_000e6;
    uint256 allocationRaisedFunding     = 100_000e6;
    uint256 allocationRedemptionShares  = 100_000e6;
    uint256 allocationSharesAfterExit   = 400_000e6;
    uint256 finalPrincipalOut           = 600_000e6;
    uint256 finiteLoanManagerCap        = 500_000e6;
    uint256 firstPrincipal              = 300_000e6;
    uint256 fourthPrincipal             = 100_000e6;
    uint256 loanAssetsAfterReturn       = 400_000e6;
    uint256 loweredLoanManagerCap       = 300_000e6;
    uint256 poolLiquidity               = 1_000_000e6;
    uint256 principalAfterReturn        = 100_000e6;
    uint256 principalToReturn           = 100_000e6;
    uint256 raisedLoanManagerCap        = 500_000e6;
    uint256 secondPrincipal             = 200_000e6;
    uint256 thirdPrincipal              = 100_000e6;

    IOpenTermLoan firstLoan;
    IOpenTermLoan fourthLoan;
    IOpenTermLoan secondLoan;
    IOpenTermLoan thirdLoan;

    IOpenTermLoanManager loanManager;

    function setUp() public override {
        super.setUp();

        deposit(lp, poolLiquidity);
    }

    function test_changePoolManagerCap_whileAllocationFundsDeployed() external {
        /**********************************************************************************************************************************/
        /*** Fund an initial position with the Pool Manager cap at its maximum                                                          ***/
        /**********************************************************************************************************************************/

        fundStrategyManager(address(poolManager), allocationStrategyManager, allocationInitialAssets);

        assertEq(poolManager.strategyCapOf(allocationStrategyManager),                               type(uint256).max);
        assertEq(IStrategyManager(allocationStrategyManager).poolManagerCapOf(address(poolManager)), 0);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - allocationInitialAssets
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: allocationInitialAssets,
            availableToWithdraw:   allocationInitialAssets,
            recordedAssets:        allocationInitialAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           allocationInitialShares,
            totalPendingShares:    0,
            assetsUnderManagement: allocationInitialAssets,
            availableToWithdraw:   allocationInitialAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           allocationInitialAssets,
            shares:           allocationInitialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                poolLiquidity - allocationInitialAssets);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), allocationInitialAssets);
        assertEq(fundsAsset.balanceOf(allocationStrategyManager),    0);

        /**********************************************************************************************************************************/
        /*** Set the Pool Manager cap to zero and confirm new funding is blocked atomically                                             ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        poolManager.setStrategyCap(allocationStrategyManager, 0);

        vm.prank(strategyDelegate);
        vm.expectRevert("PM:RF:STRATEGY_CAP");
        IStrategyManager(allocationStrategyManager).fundStrategyManager(address(poolManager), allocationBoundaryFunding, "");

        /**********************************************************************************************************************************/
        /*** Fund exactly to a finite cap and confirm one unit over the cap does not change state                                       ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        poolManager.setStrategyCap(allocationStrategyManager, allocationFiniteCap);

        fundStrategyManager(address(poolManager), allocationStrategyManager, allocationBoundaryFunding);

        vm.prank(strategyDelegate);
        vm.expectRevert("PM:RF:STRATEGY_CAP");
        IStrategyManager(allocationStrategyManager).fundStrategyManager(address(poolManager), 1, "");

        /**********************************************************************************************************************************/
        /*** Lower the cap below deployed assets, block funding and process a withdrawal                                                ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        poolManager.setStrategyCap(allocationStrategyManager, allocationLoweredCap);

        vm.prank(strategyDelegate);
        vm.expectRevert("PM:RF:STRATEGY_CAP");
        IStrategyManager(allocationStrategyManager).fundStrategyManager(address(poolManager), 1, "");

        requestRedeemFromStrategyManager(address(poolManager), allocationStrategyManager, allocationRedemptionShares);
        processRedemptionFromStrategyManager(address(poolManager), allocationStrategyManager, allocationRedemptionShares);

        assertEq(poolManager.strategyCapOf(allocationStrategyManager), allocationLoweredCap);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - allocationAssetsAfterExit
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: allocationAssetsAfterExit,
            availableToWithdraw:   allocationAssetsAfterExit,
            recordedAssets:        allocationAssetsAfterExit,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           allocationSharesAfterExit,
            totalPendingShares:    0,
            assetsUnderManagement: allocationAssetsAfterExit,
            availableToWithdraw:   allocationAssetsAfterExit,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           allocationAssetsAfterExit,
            shares:           allocationSharesAfterExit,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                poolLiquidity - allocationAssetsAfterExit);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), allocationAssetsAfterExit);
        assertEq(fundsAsset.balanceOf(allocationStrategyManager),    0);

        /**********************************************************************************************************************************/
        /*** Raise the finite cap to restore funding, then use the maximum cap to fund again                                            ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        poolManager.setStrategyCap(allocationStrategyManager, allocationRaisedCap);

        fundStrategyManager(address(poolManager), allocationStrategyManager, allocationRaisedFunding);

        vm.prank(governor);
        poolManager.setStrategyCap(allocationStrategyManager, type(uint256).max);

        fundStrategyManager(address(poolManager), allocationStrategyManager, allocationMaximumCapFunding);

        assertEq(poolManager.strategyCapOf(allocationStrategyManager), type(uint256).max);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - allocationFinalAssets
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: allocationFinalAssets,
            availableToWithdraw:   allocationFinalAssets,
            recordedAssets:        allocationFinalAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           allocationFinalShares,
            totalPendingShares:    0,
            assetsUnderManagement: allocationFinalAssets,
            availableToWithdraw:   allocationFinalAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           allocationFinalAssets,
            shares:           allocationFinalShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                poolLiquidity - allocationFinalAssets);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), allocationFinalAssets);
        assertEq(fundsAsset.balanceOf(allocationStrategyManager),    0);
    }

    function test_changeStrategyManagerCap_whileAllocationFundsDeployed() external {
        /**********************************************************************************************************************************/
        /*** Confirm a zero Strategy Manager cap is unlimited by funding an initial position                                            ***/
        /**********************************************************************************************************************************/

        assertEq(IStrategyManager(allocationStrategyManager).poolManagerCapOf(address(poolManager)), 0);

        fundStrategyManager(address(poolManager), allocationStrategyManager, allocationInitialAssets);

        assertEq(poolManager.strategyCapOf(allocationStrategyManager),                               type(uint256).max);
        assertEq(IStrategyManager(allocationStrategyManager).poolManagerCapOf(address(poolManager)), 0);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - allocationInitialAssets
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           allocationInitialAssets,
            shares:           allocationInitialShares,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        /**********************************************************************************************************************************/
        /*** Fund exactly to a finite cap and confirm one unit over the cap does not change state                                       ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        IStrategyManager(allocationStrategyManager).setPoolManagerCap(address(poolManager), allocationFiniteCap);

        fundStrategyManager(address(poolManager), allocationStrategyManager, allocationBoundaryFunding);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:POOL_MANAGER_CAP");
        IStrategyManager(allocationStrategyManager).fundStrategyManager(address(poolManager), 1, "");

        /**********************************************************************************************************************************/
        /*** Lower the cap below deployed assets, block funding and process a withdrawal                                                ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        IStrategyManager(allocationStrategyManager).setPoolManagerCap(address(poolManager), allocationLoweredCap);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:POOL_MANAGER_CAP");
        IStrategyManager(allocationStrategyManager).fundStrategyManager(address(poolManager), 1, "");

        requestRedeemFromStrategyManager(address(poolManager), allocationStrategyManager, allocationRedemptionShares);
        processRedemptionFromStrategyManager(address(poolManager), allocationStrategyManager, allocationRedemptionShares);

        assertEq(IStrategyManager(allocationStrategyManager).poolManagerCapOf(address(poolManager)), allocationLoweredCap);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - allocationAssetsAfterExit
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: allocationAssetsAfterExit,
            availableToWithdraw:   allocationAssetsAfterExit,
            recordedAssets:        allocationAssetsAfterExit,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           allocationSharesAfterExit,
            totalPendingShares:    0,
            assetsUnderManagement: allocationAssetsAfterExit,
            availableToWithdraw:   allocationAssetsAfterExit,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      address(poolManager),
            assets:           allocationAssetsAfterExit,
            shares:           allocationSharesAfterExit,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(fundsAsset.balanceOf(address(pool)),                poolLiquidity - allocationAssetsAfterExit);
        assertEq(fundsAsset.balanceOf(allocationUnderlyingStrategy), allocationAssetsAfterExit);
        assertEq(fundsAsset.balanceOf(allocationStrategyManager),    0);

        /**********************************************************************************************************************************/
        /*** Raise the finite cap to restore funding, then use the maximum cap to block funding                                         ***/
        /**********************************************************************************************************************************/

        vm.prank(strategyDelegate);
        IStrategyManager(allocationStrategyManager).setPoolManagerCap(address(poolManager), allocationRaisedCap);

        fundStrategyManager(address(poolManager), allocationStrategyManager, allocationRaisedFunding);

        vm.prank(strategyDelegate);
        IStrategyManager(allocationStrategyManager).setPoolManagerCap(address(poolManager), type(uint256).max);

        vm.prank(strategyDelegate);
        vm.expectRevert("MSM:FSM:POOL_MANAGER_CAP");
        IStrategyManager(allocationStrategyManager).fundStrategyManager(address(poolManager), 1, "");
    }

    function test_changePoolManagerCap_whileOpenTermLoanFundsDeployed() external {
        loanManager = IOpenTermLoanManager(poolManager.strategyList(0));

        firstLoan = IOpenTermLoan(createOpenTermLoan(
            openTermLoanFactory,
            firstBorrower,
            address(loanManager),
            address(fundsAsset),
            firstPrincipal,
            [uint256(5 days), uint256(5 days), uint256(30 days)],
            [uint256(0), uint256(0), uint256(0), uint256(0)]
        ));

        secondLoan = IOpenTermLoan(createOpenTermLoan(
            openTermLoanFactory,
            secondBorrower,
            address(loanManager),
            address(fundsAsset),
            secondPrincipal,
            [uint256(5 days), uint256(5 days), uint256(30 days)],
            [uint256(0), uint256(0), uint256(0), uint256(0)]
        ));

        thirdLoan = IOpenTermLoan(createOpenTermLoan(
            openTermLoanFactory,
            thirdBorrower,
            address(loanManager),
            address(fundsAsset),
            thirdPrincipal,
            [uint256(5 days), uint256(5 days), uint256(30 days)],
            [uint256(0), uint256(0), uint256(0), uint256(0)]
        ));

        fourthLoan = IOpenTermLoan(createOpenTermLoan(
            openTermLoanFactory,
            fourthBorrower,
            address(loanManager),
            address(fundsAsset),
            fourthPrincipal,
            [uint256(5 days), uint256(5 days), uint256(30 days)],
            [uint256(0), uint256(0), uint256(0), uint256(0)]
        ));

        vm.prank(firstBorrower);
        firstLoan.acceptLoanTerms();

        vm.prank(secondBorrower);
        secondLoan.acceptLoanTerms();

        vm.prank(thirdBorrower);
        thirdLoan.acceptLoanTerms();

        vm.prank(fourthBorrower);
        fourthLoan.acceptLoanTerms();

        /**********************************************************************************************************************************/
        /*** Fund the initial loan with the Loan Manager cap at its maximum                                                             ***/
        /**********************************************************************************************************************************/

        vm.prank(poolDelegate);
        loanManager.fund(address(firstLoan));

        assertEq(poolManager.strategyCapOf(address(loanManager)), type(uint256).max);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - firstPrincipal
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: 0,
            accruedInterest:   0,
            domainStart:       start,
            issuanceRate:      0,
            principalOut:      firstPrincipal,
            unrealizedLosses:  0
        });

        assertOpenTermLoan({
            loan:            address(firstLoan),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       firstPrincipal
        });

        assertEq(firstLoan.loanTermsAccepted(),  true);
        assertEq(secondLoan.loanTermsAccepted(), true);
        assertEq(thirdLoan.loanTermsAccepted(),  true);
        assertEq(fourthLoan.loanTermsAccepted(), true);

        assertEq(fundsAsset.balanceOf(address(pool)),        poolLiquidity - firstPrincipal);
        assertEq(fundsAsset.balanceOf(address(loanManager)), 0);
        assertEq(fundsAsset.balanceOf(firstBorrower),        firstPrincipal);
        assertEq(fundsAsset.balanceOf(secondBorrower),       0);

        /**********************************************************************************************************************************/
        /*** Set the Loan Manager cap to zero and confirm a new loan cannot be funded                                                   ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        poolManager.setStrategyCap(address(loanManager), 0);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:RF:STRATEGY_CAP");
        loanManager.fund(address(secondLoan));

        /**********************************************************************************************************************************/
        /*** Fund exactly to a finite cap and confirm a new loan over the cap does not change state                                     ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        poolManager.setStrategyCap(address(loanManager), finiteLoanManagerCap);

        vm.prank(poolDelegate);
        loanManager.fund(address(secondLoan));

        vm.prank(poolDelegate);
        vm.expectRevert("PM:RF:STRATEGY_CAP");
        loanManager.fund(address(thirdLoan));

        assertEq(poolManager.strategyCapOf(address(loanManager)), finiteLoanManagerCap);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - finiteLoanManagerCap
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: 0,
            accruedInterest:   0,
            domainStart:       start,
            issuanceRate:      0,
            principalOut:      finiteLoanManagerCap,
            unrealizedLosses:  0
        });

        assertOpenTermLoan({
            loan:            address(secondLoan),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       secondPrincipal
        });

        assertOpenTermLoan({
            loan:            address(thirdLoan),
            dateCalled:      0,
            dateFunded:      0,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       thirdPrincipal
        });

        assertEq(fundsAsset.balanceOf(address(pool)),        poolLiquidity - finiteLoanManagerCap);
        assertEq(fundsAsset.balanceOf(address(loanManager)), 0);
        assertEq(fundsAsset.balanceOf(secondBorrower),       secondPrincipal);
        assertEq(fundsAsset.balanceOf(thirdBorrower),        0);
        assertEq(fundsAsset.balanceOf(address(thirdLoan)),   0);

        /**********************************************************************************************************************************/
        /*** Lower the cap below principal out, keep funding blocked and return principal                                               ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        poolManager.setStrategyCap(address(loanManager), loweredLoanManagerCap);

        vm.prank(poolDelegate);
        vm.expectRevert("PM:RF:STRATEGY_CAP");
        loanManager.fund(address(thirdLoan));

        vm.startPrank(secondBorrower);
        fundsAsset.approve(address(secondLoan), principalToReturn);
        secondLoan.makePayment(principalToReturn);
        vm.stopPrank();

        vm.prank(poolDelegate);
        vm.expectRevert("PM:RF:STRATEGY_CAP");
        loanManager.fund(address(thirdLoan));

        assertEq(poolManager.strategyCapOf(address(loanManager)), loweredLoanManagerCap);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - loanAssetsAfterReturn
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: 0,
            accruedInterest:   0,
            domainStart:       start,
            issuanceRate:      0,
            principalOut:      loanAssetsAfterReturn,
            unrealizedLosses:  0
        });

        assertOpenTermLoan({
            loan:            address(secondLoan),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    0,
            datePaid:        start,
            calledPrincipal: 0,
            principal:       principalAfterReturn
        });

        assertOpenTermLoan({
            loan:            address(thirdLoan),
            dateCalled:      0,
            dateFunded:      0,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       thirdPrincipal
        });

        assertEq(fundsAsset.balanceOf(address(pool)),        poolLiquidity - loanAssetsAfterReturn);
        assertEq(fundsAsset.balanceOf(address(loanManager)), 0);
        assertEq(fundsAsset.balanceOf(secondBorrower),       principalAfterReturn);
        assertEq(fundsAsset.balanceOf(thirdBorrower),        0);

        /**********************************************************************************************************************************/
        /*** Raise the finite cap to fund the pending loan, then use the maximum cap to fund another loan                               ***/
        /**********************************************************************************************************************************/

        vm.prank(governor);
        poolManager.setStrategyCap(address(loanManager), raisedLoanManagerCap);

        vm.prank(poolDelegate);
        loanManager.fund(address(thirdLoan));

        vm.prank(governor);
        poolManager.setStrategyCap(address(loanManager), type(uint256).max);

        vm.prank(poolDelegate);
        loanManager.fund(address(fourthLoan));

        assertEq(poolManager.strategyCapOf(address(loanManager)), type(uint256).max);

        assertPoolState({
            pool:               address(pool),
            totalAssets:        poolLiquidity,
            totalSupply:        poolLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: poolLiquidity - finalPrincipalOut
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManager),
            accountedInterest: 0,
            accruedInterest:   0,
            domainStart:       start,
            issuanceRate:      0,
            principalOut:      finalPrincipalOut,
            unrealizedLosses:  0
        });

        assertOpenTermLoan({
            loan:            address(thirdLoan),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       thirdPrincipal
        });

        assertOpenTermLoan({
            loan:            address(fourthLoan),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       fourthPrincipal
        });

        assertEq(fundsAsset.balanceOf(address(pool)),        poolLiquidity - finalPrincipalOut);
        assertEq(fundsAsset.balanceOf(address(loanManager)), 0);
        assertEq(fundsAsset.balanceOf(firstBorrower),        firstPrincipal);
        assertEq(fundsAsset.balanceOf(secondBorrower),       principalAfterReturn);
        assertEq(fundsAsset.balanceOf(thirdBorrower),        thirdPrincipal);
        assertEq(fundsAsset.balanceOf(fourthBorrower),       fourthPrincipal);
        assertEq(fundsAsset.balanceOf(address(firstLoan)),   0);
        assertEq(fundsAsset.balanceOf(address(secondLoan)),  0);
        assertEq(fundsAsset.balanceOf(address(thirdLoan)),   0);
        assertEq(fundsAsset.balanceOf(address(fourthLoan)),  0);
    }

}
