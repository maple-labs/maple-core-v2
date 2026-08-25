// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAllocationStrategy,
    IMockERC20,
    IOpenTermLoan,
    IOpenTermLoanManager,
    IPool,
    IPoolManager,
    IWithdrawalManagerQueue
} from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract CrossPoolFundingTests is TestBaseWithAssertions {

    address borrower               = makeAddr("borrower");
    address borrowerFundsRecipient = makeAddr("borrowerFundsRecipient");
    address managedWallet          = makeAddr("managedWallet");
    address poolALp                = makeAddr("poolALp");
    address poolBDelegate          = makeAddr("poolBDelegate");

    address poolA;
    address poolB;
    address poolManagerA;
    address poolManagerB;
    address withdrawalManagerB;

    IMockERC20 usdc;
    IMockERC20 usdt;

    IOpenTermLoan        loan;
    IOpenTermLoanManager loanManagerB;

    uint32 gracePeriod             = 5 days;
    uint32 noticePeriod            = 5 days;
    uint32 paymentInterval         = 10 days;
    uint32 strategyDelegateFeeRate = 0.04e6;  // 4%
    uint32 strategyProtocolFeeRate = 0.06e6;  // 6%

    uint64 delegateServiceFeeRate = 0.01e6;  // 1%
    uint64 interestRate           = 0.05e6;  // 5%
    uint64 platformServiceFeeRate = 0.02e6;  // 2%

    uint256 delegateManagementFeeRate = 0.05e6;  // 5%
    uint256 interestAccrualRounding   = 1;
    uint256 loanPrincipal             = 730_000e6;
    uint256 platformManagementFeeRate = 0.10e6;  // 10%
    uint256 poolAFunding              = 1_000_000e6;
    uint256 swapSlippage              = 50e6;    // Per swap.

    uint256 delegateManagementFee;
    uint256 delegateServiceFee;
    uint256 finalPoolAAssets;
    uint256 grossLoanInterest;
    uint256 grossStrategyYield;
    uint256 issuanceRate;
    uint256 netLoanInterest;
    uint256 netStrategyYield;
    uint256 platformManagementFee;
    uint256 platformServiceFee;
    uint256 poolBDeposit;
    uint256 poolBExitAssets;
    uint256 returnSwapAssets;
    uint256 strategyDelegateFee;
    uint256 strategyProtocolFee;

    function setUp() public override {
        super.setUp();

        grossLoanInterest     = loanPrincipal * interestRate * paymentInterval / (365 days * 1e6);            // 1_000e6
        delegateManagementFee = grossLoanInterest * delegateManagementFeeRate / 1e6;                          // 50e6
        delegateServiceFee    = loanPrincipal * delegateServiceFeeRate * paymentInterval / (365 days * 1e6);  // 200e6
        platformManagementFee = grossLoanInterest * platformManagementFeeRate / 1e6;                          // 100e6
        platformServiceFee    = loanPrincipal * platformServiceFeeRate * paymentInterval / (365 days * 1e6);  // 400e6

        netLoanInterest = grossLoanInterest - delegateManagementFee - platformManagementFee;  // 850e6
        issuanceRate    = netLoanInterest * 1e27 / paymentInterval;                           // Ray-scaled USDT per second.

        poolBDeposit     = poolAFunding - swapSlippage;     // 999_950e6
        poolBExitAssets  = poolBDeposit + netLoanInterest;  // 1_000_800e6
        returnSwapAssets = poolBExitAssets - swapSlippage;  // 1_000_750e6

        grossStrategyYield  = returnSwapAssets - poolAFunding;                                 // 750e6
        strategyDelegateFee = grossStrategyYield * strategyDelegateFeeRate / 1e6;              // 30e6
        strategyProtocolFee = grossStrategyYield * strategyProtocolFeeRate / 1e6;              // 45e6
        netStrategyYield    = grossStrategyYield - strategyDelegateFee - strategyProtocolFee;  // 675e6
        finalPoolAAssets    = poolAFunding + netStrategyYield;                                 // 1_000_675e6

        usdc         = fundsAsset;
        poolA        = address(pool);
        poolManagerA = address(poolManager);

        ( allocationStrategyManager, allocationUnderlyingStrategy ) = _deployAllocationStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(usdc),
            strategyDelegateFeeRate_: strategyDelegateFeeRate,
            strategyProtocolFeeRate_: strategyProtocolFeeRate,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        addStrategyManagerToPool(poolManagerA, allocationStrategyManager);

        setManagedWallet({
            strategy_:        allocationUnderlyingStrategy,
            managedWallet_:   managedWallet,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   poolAFunding
        });

        usdt = IMockERC20(deployMock("ConfigurableMockERC20", abi.encode("Tether USD", "USDT", 6)));

        vm.startPrank(governor);
        globals.setValidPoolAsset(address(usdt), true);
        globals.setValidPoolDelegate(poolBDelegate, true);
        vm.stopPrank();

        fundsAsset = usdt;

        ( poolB, poolManagerB, withdrawalManagerB ) = _createPoolWithOTLM(poolBDelegate);

        _configurePool();
        openPool(poolManagerB);

        vm.startPrank(governor);
        globals.setPlatformManagementFeeRate(poolManagerB, platformManagementFeeRate);
        globals.setPlatformServiceFeeRate(poolManagerB, platformServiceFeeRate);
        vm.stopPrank();

        setDelegateManagementFeeRate(poolManagerB, delegateManagementFeeRate);

        loanManagerB = IOpenTermLoanManager(IPoolManager(poolManagerB).strategyList(0));

        loan = IOpenTermLoan(createOpenTermLoan(
            openTermLoanFactory,
            borrower,
            address(loanManagerB),
            address(usdt),
            loanPrincipal,
            [uint256(gracePeriod), uint256(noticePeriod), uint256(paymentInterval)],
            [uint256(delegateServiceFeeRate), uint256(interestRate), uint256(0), uint256(0)]
        ));
    }

    function test_crossPoolFunding_differentAssets_roundTrip() external {
        /**********************************************************************************************************************************/
        /*** Deploy Pool A's USDC and swap it into USDT                                                                                 ***/
        /**********************************************************************************************************************************/

        deposit(poolA, poolALp, poolAFunding);
        fundStrategyManager(poolManagerA, allocationStrategyManager, poolAFunding);
        deployAssets(allocationUnderlyingStrategy, managedWallet, poolAFunding);

        // Emulate swap
        usdc.burn(managedWallet, poolAFunding);
        usdt.mint(managedWallet, poolBDeposit);

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAFunding,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: poolAFunding,
            availableToWithdraw:   0,
            recordedAssets:        0,
            totalDeployedAssets:   poolAFunding,
            unrealizedLosses:      0
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           poolAFunding,
            totalPendingShares:    0,
            assetsUnderManagement: poolAFunding,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerA,
            assets:           poolAFunding,
            shares:           poolAFunding,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), poolAFunding);

        assertEq(usdc.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(usdc.balanceOf(managedWallet),                0);
        assertEq(usdt.balanceOf(managedWallet),                poolBDeposit);

        /**********************************************************************************************************************************/
        /*** Deposit into Pool B and fund its open-term loan                                                                            ***/
        /**********************************************************************************************************************************/

        erc20_approve(address(usdt), managedWallet, poolB, poolBDeposit);

        vm.prank(managedWallet);
        IPool(poolB).deposit(poolBDeposit, managedWallet);

        fundLoan(address(loan));
        erc20_transfer(address(usdt), borrower, borrowerFundsRecipient, loanPrincipal);

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBDeposit,
            totalSupply:        poolBDeposit,
            unrealizedLosses:   0,
            availableLiquidity: poolBDeposit - loanPrincipal
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManagerB),
            accountedInterest: 0,
            accruedInterest:   0,
            domainStart:       start,
            issuanceRate:      issuanceRate,
            principalOut:      loanPrincipal,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            platformFeeRate: platformManagementFeeRate,
            delegateFeeRate: delegateManagementFeeRate,
            startDate:       start,
            issuanceRate:    issuanceRate
        });

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       loanPrincipal
        });

        assertEq(IPool(poolB).balanceOf(managedWallet), poolBDeposit);

        assertEq(usdt.balanceOf(managedWallet),          0);
        assertEq(usdt.balanceOf(borrower),               0);
        assertEq(usdt.balanceOf(borrowerFundsRecipient), loanPrincipal);

        /**********************************************************************************************************************************/
        /*** Accrue and repay the loan                                                                                                  ***/
        /**********************************************************************************************************************************/

        uint256 paymentTimestamp = start + paymentInterval;

        vm.warp(paymentTimestamp);

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBExitAssets - interestAccrualRounding,
            totalSupply:        poolBDeposit,
            unrealizedLosses:   0,
            availableLiquidity: poolBDeposit - loanPrincipal
        });

        assertOpenTermLoanPaymentState({
            loan:               address(loan),
            paymentTimestamp:   paymentTimestamp,
            principal:          0,
            interest:           grossLoanInterest,
            lateInterest:       0,
            delegateServiceFee: delegateServiceFee,
            platformServiceFee: platformServiceFee,
            paymentDueDate:     paymentTimestamp,
            defaultDate:        paymentTimestamp + gracePeriod
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManagerB),
            accountedInterest: 0,
            accruedInterest:   netLoanInterest - interestAccrualRounding,
            domainStart:       start,
            issuanceRate:      issuanceRate,
            principalOut:      loanPrincipal,
            unrealizedLosses:  0
        });

        ( uint256 principalPaid, uint256 interestPaid, uint256 serviceFeesPaid ) = makePayment(address(loan), loanPrincipal);

        assertEq(principalPaid,   loanPrincipal);
        assertEq(interestPaid,    grossLoanInterest);
        assertEq(serviceFeesPaid, delegateServiceFee + platformServiceFee);

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBExitAssets,
            totalSupply:        poolBDeposit,
            unrealizedLosses:   0,
            availableLiquidity: poolBExitAssets
        });

        assertOpenTermLoanManager({
            loanManager:       address(loanManagerB),
            accountedInterest: 0,
            accruedInterest:   0,
            domainStart:       paymentTimestamp,
            issuanceRate:      0,
            principalOut:      0,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            address(loan),
            platformFeeRate: 0,
            delegateFeeRate: 0,
            startDate:       0,
            issuanceRate:    0
        });

        assertOpenTermLoan({
            loan:            address(loan),
            dateCalled:      0,
            dateFunded:      0,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       0
        });

        assertEq(usdt.balanceOf(poolBDelegate), delegateServiceFee + delegateManagementFee);
        assertEq(usdt.balanceOf(treasury),      platformServiceFee + platformManagementFee);
        assertEq(usdt.balanceOf(borrower),      0);
        assertEq(usdt.balanceOf(address(loan)), 0);

        /**********************************************************************************************************************************/
        /*** Fully exit Pool B and swap the USDT proceeds back into USDC                                                                ***/
        /**********************************************************************************************************************************/

        requestRedeem(poolB, managedWallet, poolBDeposit);
        processRedemptions(poolB, poolBDeposit);

        assertPoolState({
            pool:               poolB,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertQueue({
            poolManager:   poolManagerB,
            nextRequestId: 2,
            lastRequestId: 1
        });

        assertRequest({
            poolManager: poolManagerB,
            requestId:   1,
            owner:       address(0),
            shares:      0
        });

        assertEq(IWithdrawalManagerQueue(withdrawalManagerB).totalShares(),                        0);
        assertEq(IWithdrawalManagerQueue(withdrawalManagerB).userEscrowedShares(managedWallet),    0);
        assertEq(IWithdrawalManagerQueue(withdrawalManagerB).manualSharesAvailable(managedWallet), 0);

        assertEq(IPool(poolB).balanceOf(managedWallet), 0);

        assertEq(usdt.balanceOf(poolB),                 0);
        assertEq(usdt.balanceOf(address(loanManagerB)), 0);
        assertEq(usdt.balanceOf(managedWallet),         poolBExitAssets);

        // Emulate swap
        usdt.burn(managedWallet, poolBExitAssets);
        usdc.mint(managedWallet, returnSwapAssets);

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: poolAFunding,
            availableToWithdraw:   0,
            recordedAssets:        0,
            totalDeployedAssets:   poolAFunding,
            unrealizedLosses:      0
        });

        assertEq(usdt.balanceOf(managedWallet), 0);
        assertEq(usdc.balanceOf(managedWallet), returnSwapAssets);

        /**********************************************************************************************************************************/
        /*** Return principal, realize yield, and fully exit the Allocation Strategy                                                    ***/
        /**********************************************************************************************************************************/

        vm.startPrank(managedWallet);
        usdc.approve(allocationUnderlyingStrategy, returnSwapAssets);
        IAllocationStrategy(allocationUnderlyingStrategy).returnAssets(poolAFunding, managedWallet, "");
        IAllocationStrategy(allocationUnderlyingStrategy).realizeYield(grossStrategyYield, 0, "");
        vm.stopPrank();

        assertPoolState({
            pool:               poolA,
            totalAssets:        finalPoolAAssets,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: finalPoolAAssets,
            availableToWithdraw:   finalPoolAAssets,
            recordedAssets:        finalPoolAAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netStrategyYield,
            yieldStart:           uint32(paymentTimestamp),
            yieldDeadline:        uint32(paymentTimestamp),
            yieldLastRealized:    uint32(paymentTimestamp),
            realizedYield:        netStrategyYield
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           poolAFunding,
            totalPendingShares:    0,
            assetsUnderManagement: finalPoolAAssets,
            availableToWithdraw:   finalPoolAAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerA,
            assets:           finalPoolAAssets,
            shares:           poolAFunding,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(usdc.balanceOf(allocationUnderlyingStrategy), finalPoolAAssets);
        assertEq(usdc.balanceOf(managedWallet),                0);
        assertEq(usdc.balanceOf(strategyDelegate),             strategyDelegateFee);
        assertEq(usdc.balanceOf(treasury),                     strategyProtocolFee);

        requestRedeemFromStrategyManager(poolManagerA, allocationStrategyManager, poolAFunding);
        processRedemptionFromStrategyManager(poolManagerA, allocationStrategyManager, poolAFunding);

        assertPoolState({
            pool:               poolA,
            totalAssets:        finalPoolAAssets,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: finalPoolAAssets
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            recordedAssets:        0,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: netStrategyYield,
            yieldStart:           uint32(paymentTimestamp),
            yieldDeadline:        uint32(paymentTimestamp),
            yieldLastRealized:    uint32(paymentTimestamp),
            realizedYield:        netStrategyYield
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           0,
            totalPendingShares:    0,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolManagerA,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(IPool(poolA).balanceOf(poolALp),                poolAFunding);
        assertEq(IPool(poolA).convertToExitAssets(poolAFunding), finalPoolAAssets);

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(usdc.balanceOf(poolA),                        finalPoolAAssets);
        assertEq(usdc.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(usdc.balanceOf(allocationStrategyManager),    0);
        assertEq(usdc.balanceOf(managedWallet),                0);
        assertEq(usdc.balanceOf(poolB),                        0);
        assertEq(usdc.balanceOf(address(loan)),                0);
        assertEq(usdc.balanceOf(address(loanManagerB)),        0);
        assertEq(usdt.balanceOf(poolA),                        0);
        assertEq(usdt.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(usdt.balanceOf(allocationStrategyManager),    0);
        assertEq(usdt.balanceOf(poolB),                        0);
        assertEq(usdt.balanceOf(address(loan)),                0);
        assertEq(usdt.balanceOf(address(loanManagerB)),        0);
        assertEq(usdt.balanceOf(managedWallet),                0);
    }

}
