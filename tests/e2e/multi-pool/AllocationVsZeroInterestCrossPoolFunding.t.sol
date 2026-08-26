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

contract AllocationVsZeroInterestCrossPoolFundingTests is TestBaseWithAssertions {

    address borrower       = makeAddr("borrower");
    address managedWallet  = makeAddr("managedWallet");
    address poolALp        = makeAddr("poolALp");
    address poolBDelegate  = makeAddr("poolBDelegate");
    address poolBDepositor = makeAddr("poolBDepositor");

    address poolA;
    address poolAManager;
    address poolAWithdrawalManager;
    address poolB;
    address poolBManager;
    address poolBWithdrawalManager;

    IMockERC20 usdc;

    IOpenTermLoan        crossPoolLoan;
    IOpenTermLoan        loan;
    IOpenTermLoanManager poolALoanManager;
    IOpenTermLoanManager poolBLoanManager;

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

    uint256 allocationFinalAssets;
    uint256 borrowerTopUp;
    uint256 delegateManagementFee;
    uint256 delegateServiceFee;
    uint256 grossLoanInterest;
    uint256 grossStrategyYield;
    uint256 issuanceRate;
    uint256 netLoanInterest;
    uint256 platformManagementFee;
    uint256 platformServiceFee;
    uint256 poolBFinalAssets;
    uint256 strategyDelegateFee;
    uint256 strategyNetYield;
    uint256 strategyProtocolFee;
    uint256 zeroInterestLoanFinalAssets;

    uint256 crossPoolDelegateServiceFeePaid;
    uint256 crossPoolInterestPaid;
    uint256 crossPoolLateInterestPaid;
    uint256 crossPoolPlatformServiceFeePaid;
    uint256 delegateServiceFeePaid;
    uint256 interestPaid;
    uint256 lateInterestPaid;
    uint256 platformServiceFeePaid;

    function setUp() public override {
        super.setUp();

        grossLoanInterest     = loanPrincipal * interestRate * paymentInterval / (365 days * 1e6);            // 1_000e6
        delegateManagementFee = grossLoanInterest * delegateManagementFeeRate / 1e6;                          // 50e6
        delegateServiceFee    = loanPrincipal * delegateServiceFeeRate * paymentInterval / (365 days * 1e6);  // 200e6
        platformManagementFee = grossLoanInterest * platformManagementFeeRate / 1e6;                          // 100e6
        platformServiceFee    = loanPrincipal * platformServiceFeeRate * paymentInterval / (365 days * 1e6);  // 400e6

        netLoanInterest  = grossLoanInterest - delegateManagementFee - platformManagementFee;  // 850e6
        issuanceRate     = netLoanInterest * 1e27 / paymentInterval;                           // Ray-scaled USDC per second.
        poolBFinalAssets = poolAFunding + netLoanInterest;                                     // 1_000_850e6
        borrowerTopUp    = grossLoanInterest + delegateServiceFee + platformServiceFee;        // 1_600e6

        grossStrategyYield          = netLoanInterest;                                                 // 850e6
        strategyDelegateFee         = grossStrategyYield * strategyDelegateFeeRate / 1e6;              // 34e6
        strategyProtocolFee         = grossStrategyYield * strategyProtocolFeeRate / 1e6;              // 51e6
        strategyNetYield            = grossStrategyYield - strategyDelegateFee - strategyProtocolFee;  // 765e6
        allocationFinalAssets       = poolAFunding + strategyNetYield;                                 // 1_000_765e6
        zeroInterestLoanFinalAssets = poolAFunding + netLoanInterest;                                  // 1_000_850e6

        usdc                   = fundsAsset;
        poolA                  = address(pool);
        poolAManager           = address(poolManager);
        poolAWithdrawalManager = address(queueWM);
        poolALoanManager       = IOpenTermLoanManager(IPoolManager(poolAManager).strategyList(0));

        vm.prank(governor);
        globals.setValidPoolDelegate(poolBDelegate, true);
    }

    function test_crossPoolFunding_withAllocation() external {
        ( allocationStrategyManager, allocationUnderlyingStrategy ) = _deployAllocationStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(usdc),
            strategyDelegateFeeRate_: strategyDelegateFeeRate,
            strategyProtocolFeeRate_: strategyProtocolFeeRate,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        addStrategyManagerToPool(poolAManager, allocationStrategyManager);

        setManagedWallet({
            strategy_:        allocationUnderlyingStrategy,
            managedWallet_:   managedWallet,
            canDeployAssets_: true,
            canReturnAssets_: true,
            canRealizeYield_: true,
            deploymentCap_:   poolAFunding
        });

        ( poolB, poolBManager, poolBWithdrawalManager ) = _createPoolWithOTLM(poolBDelegate);

        _configurePool();
        openPool(poolBManager);

        vm.startPrank(governor);
        globals.setPlatformManagementFeeRate(poolBManager, platformManagementFeeRate);
        globals.setPlatformServiceFeeRate(poolBManager, platformServiceFeeRate);
        vm.stopPrank();

        setDelegateManagementFeeRate(poolBManager, delegateManagementFeeRate);

        poolBLoanManager = IOpenTermLoanManager(IPoolManager(poolBManager).strategyList(0));

        loan = IOpenTermLoan(createOpenTermLoan(
            openTermLoanFactory,
            borrower,
            address(poolBLoanManager),
            address(usdc),
            loanPrincipal,
            [uint256(gracePeriod), uint256(noticePeriod), uint256(paymentInterval)],
            [uint256(delegateServiceFeeRate), uint256(interestRate), uint256(0), uint256(0)]
        ));

        /**********************************************************************************************************************************/
        /*** Deploy Pool A assets through the Allocation strategy and deposit them into Pool B                                          ***/
        /**********************************************************************************************************************************/

        deposit(poolA, poolALp, poolAFunding);
        fundStrategyManager(poolAManager, allocationStrategyManager, poolAFunding);

        deployAssets(allocationUnderlyingStrategy, managedWallet, poolAFunding);

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
            poolManager:      poolAManager,
            assets:           poolAFunding,
            shares:           poolAFunding,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), poolAFunding);

        assertEq(usdc.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(usdc.balanceOf(managedWallet),                poolAFunding);

        erc20_approve(address(usdc), managedWallet, poolB, poolAFunding);

        vm.prank(managedWallet);
        IPool(poolB).deposit(poolAFunding, managedWallet);

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolAFunding,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolAFunding
        });

        assertEq(IPool(poolB).balanceOf(managedWallet), poolAFunding);
        assertEq(usdc.balanceOf(managedWallet),         0);

        /**********************************************************************************************************************************/
        /*** Queue the Pool A withdrawal while the Allocation route is illiquid                                                         ***/
        /**********************************************************************************************************************************/

        requestRedeem(poolA, poolALp, poolAFunding);

        vm.prank(poolDelegate);
        vm.expectRevert("WM:PR:LOW_LIQUIDITY");
        IWithdrawalManagerQueue(poolAWithdrawalManager).processRedemptions(poolAFunding);

        assertQueue({
            poolManager:   poolAManager,
            nextRequestId: 1,
            lastRequestId: 1
        });

        assertRequest({
            poolManager: poolAManager,
            requestId:   1,
            owner:       poolALp,
            shares:      poolAFunding
        });

        assertEq(IWithdrawalManagerQueue(poolAWithdrawalManager).totalShares(),                  poolAFunding);
        assertEq(IWithdrawalManagerQueue(poolAWithdrawalManager).userEscrowedShares(poolALp),    poolAFunding);
        assertEq(IWithdrawalManagerQueue(poolAWithdrawalManager).manualSharesAvailable(poolALp), 0);
        assertEq(IPool(poolA).balanceOf(poolALp),                                                0);
        assertEq(IPool(poolA).balanceOf(poolAWithdrawalManager),                                 poolAFunding);

        /**********************************************************************************************************************************/
        /*** Fund, accrue and repay Pool B's open-term loan                                                                             ***/
        /**********************************************************************************************************************************/

        vm.prank(borrower);
        loan.acceptLoanTerms();

        vm.prank(poolBDelegate);
        poolBLoanManager.fund(address(loan));

        assertEq(block.timestamp, start);

        assertEq(loan.borrower(),                borrower);
        assertEq(loan.delegateServiceFeeRate(),  delegateServiceFeeRate);
        assertEq(loan.fundsAsset(),              address(usdc));
        assertEq(loan.gracePeriod(),             gracePeriod);
        assertEq(loan.interestRate(),            interestRate);
        assertEq(loan.lateFeeRate(),             0);
        assertEq(loan.lateInterestPremiumRate(), 0);
        assertEq(loan.lender(),                  address(poolBLoanManager));
        assertEq(loan.noticePeriod(),            noticePeriod);
        assertEq(loan.paymentInterval(),         paymentInterval);
        assertEq(loan.platformServiceFeeRate(),  platformServiceFeeRate);
        assertEq(loan.principal(),               loanPrincipal);

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolAFunding,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolAFunding - loanPrincipal
        });

        assertOpenTermLoanManager({
            loanManager:       address(poolBLoanManager),
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

        assertEq(usdc.balanceOf(borrower), loanPrincipal);

        uint256 paymentTimestamp_ = start + paymentInterval;

        vm.warp(paymentTimestamp_);

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBFinalAssets - interestAccrualRounding,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolAFunding - loanPrincipal
        });

        assertOpenTermLoanPaymentState({
            loan:               address(loan),
            paymentTimestamp:   paymentTimestamp_,
            principal:          0,
            interest:           grossLoanInterest,
            lateInterest:       0,
            delegateServiceFee: delegateServiceFee,
            platformServiceFee: platformServiceFee,
            paymentDueDate:     paymentTimestamp_,
            defaultDate:        paymentTimestamp_ + gracePeriod
        });

        assertOpenTermLoanManager({
            loanManager:       address(poolBLoanManager),
            accountedInterest: 0,
            accruedInterest:   netLoanInterest - interestAccrualRounding,
            domainStart:       start,
            issuanceRate:      issuanceRate,
            principalOut:      loanPrincipal,
            unrealizedLosses:  0
        });

        usdc.mint(borrower, borrowerTopUp);
        erc20_approve(address(usdc), borrower, address(loan), loanPrincipal + borrowerTopUp);

        vm.prank(borrower);
        ( interestPaid, lateInterestPaid, delegateServiceFeePaid, platformServiceFeePaid ) = loan.makePayment(loanPrincipal);

        assertEq(interestPaid,           grossLoanInterest);
        assertEq(lateInterestPaid,       0);
        assertEq(delegateServiceFeePaid, delegateServiceFee);
        assertEq(platformServiceFeePaid, platformServiceFee);

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBFinalAssets,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolBFinalAssets
        });

        assertOpenTermLoanManager({
            loanManager:       address(poolBLoanManager),
            accountedInterest: 0,
            accruedInterest:   0,
            domainStart:       paymentTimestamp_,
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

        assertEq(usdc.balanceOf(poolBDelegate), delegateServiceFee + delegateManagementFee);
        assertEq(usdc.balanceOf(treasury),      platformServiceFee + platformManagementFee);
        assertEq(usdc.balanceOf(borrower),      0);
        assertEq(usdc.balanceOf(address(loan)), 0);

        /**********************************************************************************************************************************/
        /*** Redeem Pool B, return Allocation principal and realize strategy yield                                                      ***/
        /**********************************************************************************************************************************/

        requestRedeem(poolB, managedWallet, poolAFunding);
        processRedemptions(poolB, poolAFunding);

        assertPoolState({
            pool:               poolB,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertQueue({
            poolManager:   poolBManager,
            nextRequestId: 2,
            lastRequestId: 1
        });

        assertRequest({
            poolManager: poolBManager,
            requestId:   1,
            owner:       address(0),
            shares:      0
        });

        assertEq(IWithdrawalManagerQueue(poolBWithdrawalManager).totalShares(),                        0);
        assertEq(IWithdrawalManagerQueue(poolBWithdrawalManager).userEscrowedShares(managedWallet),    0);
        assertEq(IWithdrawalManagerQueue(poolBWithdrawalManager).manualSharesAvailable(managedWallet), 0);
        assertEq(IPool(poolB).balanceOf(managedWallet),                                                0);
        assertEq(IPool(poolB).balanceOf(poolBWithdrawalManager),                                       0);
        assertEq(usdc.balanceOf(managedWallet),                                                        poolBFinalAssets);

        vm.startPrank(managedWallet);
        usdc.approve(allocationUnderlyingStrategy, poolBFinalAssets);
        IAllocationStrategy(allocationUnderlyingStrategy).returnAssets(poolAFunding, managedWallet, "");
        IAllocationStrategy(allocationUnderlyingStrategy).realizeYield(grossStrategyYield, 0, "");
        vm.stopPrank();

        assertPoolState({
            pool:               poolA,
            totalAssets:        allocationFinalAssets,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertAllocationStrategy({
            allocationStrategy:    allocationUnderlyingStrategy,
            assetsUnderManagement: allocationFinalAssets,
            availableToWithdraw:   allocationFinalAssets,
            recordedAssets:        allocationFinalAssets,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertAllocationStrategyYield({
            allocationStrategy:   allocationUnderlyingStrategy,
            scheduledYieldAssets: strategyNetYield,
            yieldStart:           uint32(paymentTimestamp_),
            yieldDeadline:        uint32(paymentTimestamp_),
            yieldLastRealized:    uint32(paymentTimestamp_),
            realizedYield:        strategyNetYield
        });

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           poolAFunding,
            totalPendingShares:    0,
            assetsUnderManagement: allocationFinalAssets,
            availableToWithdraw:   allocationFinalAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolAManager,
            assets:           allocationFinalAssets,
            shares:           poolAFunding,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertEq(IAllocationStrategy(allocationUnderlyingStrategy).deployedAssetsOf(managedWallet), 0);

        assertEq(usdc.balanceOf(allocationUnderlyingStrategy), allocationFinalAssets);
        assertEq(usdc.balanceOf(managedWallet),                0);
        assertEq(usdc.balanceOf(strategyDelegate),             strategyDelegateFee);
        assertEq(usdc.balanceOf(treasury),                     platformServiceFee + platformManagementFee + strategyProtocolFee);

        /**********************************************************************************************************************************/
        /*** Restore Pool A liquidity, process its pending withdrawal and prove no route assets remain                                  ***/
        /**********************************************************************************************************************************/

        requestRedeemFromStrategyManager(poolAManager, allocationStrategyManager, poolAFunding);

        assertStrategyManager({
            strategyManager:       allocationStrategyManager,
            totalShares:           poolAFunding,
            totalPendingShares:    poolAFunding,
            assetsUnderManagement: allocationFinalAssets,
            availableToWithdraw:   allocationFinalAssets,
            unrealizedLosses:      0
        });

        assertStrategyManagerPosition({
            strategyManager:  allocationStrategyManager,
            poolManager:      poolAManager,
            assets:           allocationFinalAssets,
            shares:           poolAFunding,
            pendingShares:    poolAFunding,
            unrealizedLosses: 0
        });

        processRedemptionFromStrategyManager(poolAManager, allocationStrategyManager, poolAFunding);

        assertPoolState({
            pool:               poolA,
            totalAssets:        allocationFinalAssets,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: allocationFinalAssets
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
            scheduledYieldAssets: strategyNetYield,
            yieldStart:           uint32(paymentTimestamp_),
            yieldDeadline:        uint32(paymentTimestamp_),
            yieldLastRealized:    uint32(paymentTimestamp_),
            realizedYield:        strategyNetYield
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
            poolManager:      poolAManager,
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        processRedemptions(poolA, poolAFunding);

        assertPoolState({
            pool:               poolA,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertQueue({
            poolManager:   poolAManager,
            nextRequestId: 2,
            lastRequestId: 1
        });

        assertRequest({
            poolManager: poolAManager,
            requestId:   1,
            owner:       address(0),
            shares:      0
        });

        assertEq(IWithdrawalManagerQueue(poolAWithdrawalManager).totalShares(),                  0);
        assertEq(IWithdrawalManagerQueue(poolAWithdrawalManager).userEscrowedShares(poolALp),    0);
        assertEq(IWithdrawalManagerQueue(poolAWithdrawalManager).manualSharesAvailable(poolALp), 0);

        assertEq(IPool(poolA).balanceOf(poolAWithdrawalManager), 0);
        assertEq(usdc.balanceOf(poolALp),                        allocationFinalAssets);

        assertEq(zeroInterestLoanFinalAssets - usdc.balanceOf(poolALp), strategyDelegateFee + strategyProtocolFee);

        assertEq(IPool(poolA).totalSupply(), 0);
        assertEq(IPool(poolB).totalSupply(), 0);
        assertEq(loan.principal(),           0);

        assertEq(usdc.balanceOf(poolA), 0);
        assertEq(usdc.balanceOf(poolB), 0);

        assertEq(usdc.balanceOf(allocationStrategyManager),    0);
        assertEq(usdc.balanceOf(allocationUnderlyingStrategy), 0);
        assertEq(usdc.balanceOf(address(poolALoanManager)),    0);
        assertEq(usdc.balanceOf(address(poolBLoanManager)),    0);
        assertEq(usdc.balanceOf(address(loan)),                0);
        assertEq(usdc.balanceOf(poolAWithdrawalManager),       0);
        assertEq(usdc.balanceOf(poolBWithdrawalManager),       0);

        assertEq(usdc.balanceOf(borrower),      0);
        assertEq(usdc.balanceOf(managedWallet), 0);
        assertEq(usdc.balanceOf(poolDelegate),  0);
    }

    function test_crossPoolFunding_withZeroInterestLoan() external {
        ( poolB, poolBManager, poolBWithdrawalManager ) = _createPoolWithOTLM(poolBDelegate);

        _configurePool();
        openPool(poolBManager);

        vm.startPrank(governor);
        globals.setPlatformManagementFeeRate(poolBManager, platformManagementFeeRate);
        globals.setPlatformServiceFeeRate(poolBManager, platformServiceFeeRate);
        vm.stopPrank();

        setDelegateManagementFeeRate(poolBManager, delegateManagementFeeRate);

        poolBLoanManager = IOpenTermLoanManager(IPoolManager(poolBManager).strategyList(0));

        crossPoolLoan = IOpenTermLoan(createOpenTermLoan(
            openTermLoanFactory,
            poolBDepositor,
            address(poolALoanManager),
            address(usdc),
            poolAFunding,
            [uint256(gracePeriod), uint256(noticePeriod), uint256(paymentInterval)],
            [uint256(0), uint256(0), uint256(0), uint256(0)]
        ));

        loan = IOpenTermLoan(createOpenTermLoan(
            openTermLoanFactory,
            borrower,
            address(poolBLoanManager),
            address(usdc),
            loanPrincipal,
            [uint256(gracePeriod), uint256(noticePeriod), uint256(paymentInterval)],
            [uint256(delegateServiceFeeRate), uint256(interestRate), uint256(0), uint256(0)]
        ));

        /**********************************************************************************************************************************/
        /*** Lend Pool A assets to Pool B's depositor at zero interest and deposit them into Pool B                                     ***/
        /**********************************************************************************************************************************/

        deposit(poolA, poolALp, poolAFunding);

        assertEq(crossPoolLoan.borrower(),                poolBDepositor);
        assertEq(crossPoolLoan.delegateServiceFeeRate(),  0);
        assertEq(crossPoolLoan.fundsAsset(),              address(usdc));
        assertEq(crossPoolLoan.gracePeriod(),             gracePeriod);
        assertEq(crossPoolLoan.interestRate(),            0);
        assertEq(crossPoolLoan.lateFeeRate(),             0);
        assertEq(crossPoolLoan.lateInterestPremiumRate(), 0);
        assertEq(crossPoolLoan.lender(),                  address(poolALoanManager));
        assertEq(crossPoolLoan.noticePeriod(),            noticePeriod);
        assertEq(crossPoolLoan.paymentInterval(),         paymentInterval);
        assertEq(crossPoolLoan.platformServiceFeeRate(),  0);
        assertEq(crossPoolLoan.principal(),               poolAFunding);

        vm.prank(poolBDepositor);
        crossPoolLoan.acceptLoanTerms();

        vm.prank(poolDelegate);
        poolALoanManager.fund(address(crossPoolLoan));

        assertPoolState({
            pool:               poolA,
            totalAssets:        poolAFunding,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertOpenTermLoanManager({
            loanManager:       address(poolALoanManager),
            accountedInterest: 0,
            accruedInterest:   0,
            domainStart:       start,
            issuanceRate:      0,
            principalOut:      poolAFunding,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            address(crossPoolLoan),
            platformFeeRate: 0,
            delegateFeeRate: 0,
            startDate:       start,
            issuanceRate:    0
        });

        assertOpenTermLoan({
            loan:            address(crossPoolLoan),
            dateCalled:      0,
            dateFunded:      start,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       poolAFunding
        });

        assertEq(usdc.balanceOf(poolBDepositor),            poolAFunding);
        assertEq(usdc.balanceOf(address(poolALoanManager)), 0);

        erc20_approve(address(usdc), poolBDepositor, poolB, poolAFunding);

        vm.prank(poolBDepositor);
        IPool(poolB).deposit(poolAFunding, poolBDepositor);

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolAFunding,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolAFunding
        });

        assertEq(IPool(poolB).balanceOf(poolBDepositor), poolAFunding);
        assertEq(usdc.balanceOf(poolBDepositor),         0);

        /**********************************************************************************************************************************/
        /*** Queue the Pool A withdrawal while the zero-interest loan is outstanding                                                    ***/
        /**********************************************************************************************************************************/

        requestRedeem(poolA, poolALp, poolAFunding);

        vm.prank(poolDelegate);
        vm.expectRevert("WM:PR:LOW_LIQUIDITY");
        IWithdrawalManagerQueue(poolAWithdrawalManager).processRedemptions(poolAFunding);

        assertQueue({
            poolManager:   poolAManager,
            nextRequestId: 1,
            lastRequestId: 1
        });

        assertRequest({
            poolManager: poolAManager,
            requestId:   1,
            owner:       poolALp,
            shares:      poolAFunding
        });

        assertEq(IWithdrawalManagerQueue(poolAWithdrawalManager).totalShares(),                    poolAFunding);
        assertEq(IWithdrawalManagerQueue(poolAWithdrawalManager).userEscrowedShares(poolALp),      poolAFunding);
        assertEq(IWithdrawalManagerQueue(poolAWithdrawalManager).manualSharesAvailable(poolALp),   0);
        assertEq(IPool(poolA).balanceOf(poolALp),                                                  0);
        assertEq(IPool(poolA).balanceOf(poolAWithdrawalManager),                                   poolAFunding);

        /**********************************************************************************************************************************/
        /*** Fund, accrue and repay Pool B's open-term loan                                                                             ***/
        /**********************************************************************************************************************************/

        vm.prank(borrower);
        loan.acceptLoanTerms();

        vm.prank(poolBDelegate);
        poolBLoanManager.fund(address(loan));

        assertEq(block.timestamp, start);

        assertEq(loan.borrower(),                borrower);
        assertEq(loan.delegateServiceFeeRate(),  delegateServiceFeeRate);
        assertEq(loan.fundsAsset(),              address(usdc));
        assertEq(loan.gracePeriod(),             gracePeriod);
        assertEq(loan.interestRate(),            interestRate);
        assertEq(loan.lateFeeRate(),             0);
        assertEq(loan.lateInterestPremiumRate(), 0);
        assertEq(loan.lender(),                  address(poolBLoanManager));
        assertEq(loan.noticePeriod(),            noticePeriod);
        assertEq(loan.paymentInterval(),         paymentInterval);
        assertEq(loan.platformServiceFeeRate(),  platformServiceFeeRate);
        assertEq(loan.principal(),               loanPrincipal);

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolAFunding,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolAFunding - loanPrincipal
        });

        assertOpenTermLoanManager({
            loanManager:       address(poolBLoanManager),
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

        assertEq(usdc.balanceOf(borrower), loanPrincipal);

        uint256 paymentTimestamp_ = start + paymentInterval;

        vm.warp(paymentTimestamp_);

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBFinalAssets - interestAccrualRounding,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolAFunding - loanPrincipal
        });

        assertOpenTermLoanPaymentState({
            loan:               address(loan),
            paymentTimestamp:   paymentTimestamp_,
            principal:          0,
            interest:           grossLoanInterest,
            lateInterest:       0,
            delegateServiceFee: delegateServiceFee,
            platformServiceFee: platformServiceFee,
            paymentDueDate:     paymentTimestamp_,
            defaultDate:        paymentTimestamp_ + gracePeriod
        });

        assertOpenTermLoanManager({
            loanManager:       address(poolBLoanManager),
            accountedInterest: 0,
            accruedInterest:   netLoanInterest - interestAccrualRounding,
            domainStart:       start,
            issuanceRate:      issuanceRate,
            principalOut:      loanPrincipal,
            unrealizedLosses:  0
        });

        usdc.mint(borrower, borrowerTopUp);
        erc20_approve(address(usdc), borrower, address(loan), loanPrincipal + borrowerTopUp);

        vm.prank(borrower);
        ( interestPaid, lateInterestPaid, delegateServiceFeePaid, platformServiceFeePaid ) = loan.makePayment(loanPrincipal);

        assertEq(interestPaid,           grossLoanInterest);
        assertEq(lateInterestPaid,       0);
        assertEq(delegateServiceFeePaid, delegateServiceFee);
        assertEq(platformServiceFeePaid, platformServiceFee);

        assertPoolState({
            pool:               poolB,
            totalAssets:        poolBFinalAssets,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: poolBFinalAssets
        });

        assertOpenTermLoanManager({
            loanManager:       address(poolBLoanManager),
            accountedInterest: 0,
            accruedInterest:   0,
            domainStart:       paymentTimestamp_,
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

        assertEq(usdc.balanceOf(poolBDelegate), delegateServiceFee + delegateManagementFee);
        assertEq(usdc.balanceOf(treasury),      platformServiceFee + platformManagementFee);
        assertEq(usdc.balanceOf(borrower),      0);
        assertEq(usdc.balanceOf(address(loan)), 0);

        /**********************************************************************************************************************************/
        /*** Redeem Pool B, repay only the cross-Pool principal and transfer the loan profit                                            ***/
        /**********************************************************************************************************************************/

        requestRedeem(poolB, poolBDepositor, poolAFunding);
        processRedemptions(poolB, poolAFunding);

        assertPoolState({
            pool:               poolB,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertQueue({
            poolManager:   poolBManager,
            nextRequestId: 2,
            lastRequestId: 1
        });

        assertRequest({
            poolManager: poolBManager,
            requestId:   1,
            owner:       address(0),
            shares:      0
        });

        assertEq(IWithdrawalManagerQueue(poolBWithdrawalManager).totalShares(),                         0);
        assertEq(IWithdrawalManagerQueue(poolBWithdrawalManager).userEscrowedShares(poolBDepositor),    0);
        assertEq(IWithdrawalManagerQueue(poolBWithdrawalManager).manualSharesAvailable(poolBDepositor), 0);
        assertEq(IPool(poolB).balanceOf(poolBDepositor),                                                0);
        assertEq(IPool(poolB).balanceOf(poolBWithdrawalManager),                                        0);
        assertEq(usdc.balanceOf(poolBDepositor),                                                        poolBFinalAssets);

        erc20_approve(address(usdc), poolBDepositor, address(crossPoolLoan), poolAFunding);

        vm.prank(poolBDepositor);
        (
            crossPoolInterestPaid,
            crossPoolLateInterestPaid,
            crossPoolDelegateServiceFeePaid,
            crossPoolPlatformServiceFeePaid
        ) = crossPoolLoan.makePayment(poolAFunding);

        assertEq(crossPoolInterestPaid,           0);
        assertEq(crossPoolLateInterestPaid,       0);
        assertEq(crossPoolDelegateServiceFeePaid, 0);
        assertEq(crossPoolPlatformServiceFeePaid, 0);

        erc20_transfer(address(usdc), poolBDepositor, poolA, netLoanInterest);

        assertPoolState({
            pool:               poolA,
            totalAssets:        zeroInterestLoanFinalAssets,
            totalSupply:        poolAFunding,
            unrealizedLosses:   0,
            availableLiquidity: zeroInterestLoanFinalAssets
        });

        assertOpenTermLoanManager({
            loanManager:       address(poolALoanManager),
            accountedInterest: 0,
            accruedInterest:   0,
            domainStart:       paymentTimestamp_,
            issuanceRate:      0,
            principalOut:      0,
            unrealizedLosses:  0
        });

        assertOpenTermPaymentInfo({
            loan:            address(crossPoolLoan),
            platformFeeRate: 0,
            delegateFeeRate: 0,
            startDate:       0,
            issuanceRate:    0
        });

        assertOpenTermLoan({
            loan:            address(crossPoolLoan),
            dateCalled:      0,
            dateFunded:      0,
            dateImpaired:    0,
            datePaid:        0,
            calledPrincipal: 0,
            principal:       0
        });

        assertEq(usdc.balanceOf(poolBDepositor),            0);
        assertEq(usdc.balanceOf(address(crossPoolLoan)),    0);
        assertEq(usdc.balanceOf(address(poolALoanManager)), 0);
        assertEq(usdc.balanceOf(poolDelegate),              0);

        /**********************************************************************************************************************************/
        /*** Process Pool A's pending withdrawal and prove no route assets remain                                                       ***/
        /**********************************************************************************************************************************/

        processRedemptions(poolA, poolAFunding);

        assertPoolState({
            pool:               poolA,
            totalAssets:        0,
            totalSupply:        0,
            unrealizedLosses:   0,
            availableLiquidity: 0
        });

        assertQueue({
            poolManager:   poolAManager,
            nextRequestId: 2,
            lastRequestId: 1
        });

        assertRequest({
            poolManager: poolAManager,
            requestId:   1,
            owner:       address(0),
            shares:      0
        });

        assertEq(IWithdrawalManagerQueue(poolAWithdrawalManager).totalShares(),                  0);
        assertEq(IWithdrawalManagerQueue(poolAWithdrawalManager).userEscrowedShares(poolALp),    0);
        assertEq(IWithdrawalManagerQueue(poolAWithdrawalManager).manualSharesAvailable(poolALp), 0);

        assertEq(IPool(poolA).balanceOf(poolAWithdrawalManager), 0);
        assertEq(usdc.balanceOf(poolALp),                        zeroInterestLoanFinalAssets);

        assertEq(usdc.balanceOf(poolALp) - allocationFinalAssets, strategyDelegateFee + strategyProtocolFee);

        assertEq(IPool(poolA).totalSupply(), 0);
        assertEq(IPool(poolB).totalSupply(), 0);
        assertEq(crossPoolLoan.principal(),  0);
        assertEq(loan.principal(),           0);

        assertEq(usdc.balanceOf(poolA), 0);
        assertEq(usdc.balanceOf(poolB), 0);

        assertEq(usdc.balanceOf(address(crossPoolLoan)),    0);
        assertEq(usdc.balanceOf(address(loan)),             0);
        assertEq(usdc.balanceOf(address(poolALoanManager)), 0);
        assertEq(usdc.balanceOf(address(poolBLoanManager)), 0);
        assertEq(usdc.balanceOf(poolAWithdrawalManager),    0);
        assertEq(usdc.balanceOf(poolBWithdrawalManager),    0);

        assertEq(usdc.balanceOf(borrower),       0);
        assertEq(usdc.balanceOf(poolBDepositor), 0);
        assertEq(usdc.balanceOf(poolDelegate),   0);
    }

}
