// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAaveV3Strategy,
    IBitcoinStrategy,
    IERC20,
    IGovernorTimelock,
    ILoanLike,
    ILoanManagerLike,
    IOpenTermLoan,
    IOpenTermLoanManager,
    IOpenTermLoanManagerStructs,
    IPool,
    IPoolManager,
    IStrategyManager,
    ISkyStrategy,
    ITradingStrategy,
    IWithdrawalManagerQueue
} from "../contracts/interfaces/Interfaces.sol";

import { BalanceAssertions } from "./BalanceAssertions.sol";
import { TestBase }          from "./TestBase.sol";

contract TestBaseWithAssertions is TestBase, BalanceAssertions {

    /**************************************************************************************************************************************/
    /*** State Assertion Functions                                                                                                      ***/
    /**************************************************************************************************************************************/

    function assertAccounting(
        uint256 outstandingAssets,
        uint256 realizedFees,
        uint256 accruedYield,
        uint256 accruedFees,
        uint256 assetsUnderManagement
    )
        internal view
    {
        assertEq(bitcoinStrategy.outstandingAssets(),     outstandingAssets);
        assertEq(bitcoinStrategy.realizedFees(),          realizedFees);
        assertEq(bitcoinStrategy.accruedYield(),          accruedYield);
        assertEq(bitcoinStrategy.accruedFees(),           accruedFees);
        assertEq(bitcoinStrategy.assetsUnderManagement(), assetsUnderManagement);
    }

    function assertImpairment(uint256 impairedAssets, uint256 unrealizedLosses) internal view {
        assertEq(bitcoinStrategy.impairedAssets(),   impairedAssets);
        assertEq(bitcoinStrategy.unrealizedLosses(), unrealizedLosses);
    }

    function assertDeployedPool(
        address poolManager_,
        uint256 initialSupply_,
        uint256 liquidityCap_,
        uint256 delegateManagementFeeRate_,
        uint256 strategyListLength_
    )
        internal view returns (IPoolManager pm_, IPool pool_)
    {
        pm_                        = IPoolManager(poolManager_);
        pool_                      = IPool(pm_.pool());
        IWithdrawalManagerQueue wm = IWithdrawalManagerQueue(pm_.withdrawalManager());

        ( address expectedPoolManager, address expectedPool ) = poolDeployer.getPoolDeploymentAddresses(
            poolManagerFactory, poolDelegate, address(fundsAsset), initialSupply_, POOL_NAME, POOL_SYMBOL
        );

        address expectedWithdrawalManager =
            poolDeployer.getQueueWithdrawalManagerAddress(queueWMFactory, expectedPool, expectedPoolManager);

        assertEq(poolManager_,   expectedPoolManager);
        assertEq(address(pool_), expectedPool);
        assertEq(address(wm),    expectedWithdrawalManager);

        assertEq(pm_.globals(),                   address(globals));
        assertEq(pm_.poolDelegate(),              poolDelegate);
        assertEq(pm_.asset(),                     address(fundsAsset));
        assertEq(pm_.poolPermissionManager(),     address(poolPermissionManager));
        assertEq(pm_.withdrawalManager(),         address(wm));
        assertEq(pm_.liquidityCap(),              liquidityCap_);
        assertEq(pm_.delegateManagementFeeRate(), delegateManagementFeeRate_);

        assertEq(pm_.configured(),         true);
        assertEq(pm_.active(),             false);
        assertEq(pm_.hasSufficientCover(), true);

        assertEq(pool_.asset(),       address(fundsAsset));
        assertEq(pool_.name(),        POOL_NAME);
        assertEq(pool_.symbol(),      POOL_SYMBOL);
        assertEq(pool_.manager(),     poolManager_);
        assertEq(pool_.totalSupply(), initialSupply_);

        if (initialSupply_ != 0) {
            assertEq(pool_.balanceOf(globals.migrationAdmin()), initialSupply_);
        }

        assertEq(wm.pool(),        address(pool_));
        assertEq(wm.poolManager(), poolManager_);

        assertEq(pm_.strategyListLength(), strategyListLength_);

        assertPoolManager(poolManager_, 0, 0);
    }

    function assertOpenTermLoan(
        address loan,
        uint256 dateCalled,
        uint256 dateFunded,
        uint256 dateImpaired,
        uint256 datePaid,
        uint256 calledPrincipal,
        uint256 principal
    )
        internal view
    {
        assertEq(IOpenTermLoan(loan).calledPrincipal(), calledPrincipal);
        assertEq(IOpenTermLoan(loan).dateCalled(),      dateCalled);
        assertEq(IOpenTermLoan(loan).dateFunded(),      dateFunded);
        assertEq(IOpenTermLoan(loan).dateImpaired(),    dateImpaired);
        assertEq(IOpenTermLoan(loan).datePaid(),        datePaid);
        assertEq(ILoanLike(loan).principal(),           principal);
    }

    function assertOpenTermLoanPaymentState(
        address loan,
        uint256 paymentTimestamp,
        uint256 principal,
        uint256 interest,
        uint256 lateInterest,
        uint256 delegateServiceFee,
        uint256 platformServiceFee,
        uint256 paymentDueDate,
        uint256 defaultDate
    )
        internal view
    {
        ( uint256 principal_, uint256 interest_, uint256 lateInterest_, uint256 delegateServiceFee_, uint256 platformServiceFee_ )
            = IOpenTermLoan(loan).getPaymentBreakdown(uint40(paymentTimestamp));

        assertEq(principal_,          principal,          "principal");
        assertEq(interest_,           interest,           "interest");
        assertEq(lateInterest_,       lateInterest,       "lateInterest");
        assertEq(delegateServiceFee_, delegateServiceFee, "delegateServiceFee");
        assertEq(platformServiceFee_, platformServiceFee, "platformServiceFee");

        assertEq(IOpenTermLoan(loan).paymentDueDate(), paymentDueDate, "paymentDueDate");
        assertEq(IOpenTermLoan(loan).defaultDate(),    defaultDate,    "defaultDate");
    }

    function assertOpenTermPaymentInfo(
        address loan,
        uint256 platformFeeRate,
        uint256 delegateFeeRate,
        uint256 startDate,
        uint256 issuanceRate
    )
        internal view
    {
        IOpenTermLoanManagerStructs.Payment memory loanInfo =
            IOpenTermLoanManagerStructs(ILoanLike(loan).lender()).paymentFor(loan);

        assertEq(loanInfo.platformManagementFeeRate, platformFeeRate, "loanInfo.platformManagementFeeRate");
        assertEq(loanInfo.delegateManagementFeeRate, delegateFeeRate, "loanInfo.delegateManagementFeeRate");
        assertEq(loanInfo.startDate,                 startDate,       "loanInfo.startDate");
        assertEq(loanInfo.issuanceRate,              issuanceRate,    "loanInfo.issuanceRate");
    }

    function assertOpenTermPaymentInfo(address loan, uint256 startDate, uint256 issuanceRate) internal view {
        IOpenTermLoanManager loanManager = IOpenTermLoanManager(ILoanLike(loan).lender());

        ( , , uint40 startDate_, uint168 issuanceRate_ ) = loanManager.paymentFor(loan);

        assertEq(startDate_,    startDate);
        assertEq(issuanceRate_, issuanceRate);
    }

    function assertOpenTermLoanManager(
        address loanManager,
        uint256 accountedInterest,
        uint256 accruedInterest,
        uint256 domainStart,
        uint256 issuanceRate,
        uint256 principalOut,
        uint256 unrealizedLosses
    )
        internal view
    {
        assertEq(ILoanManagerLike(loanManager).accountedInterest(), accountedInterest, "accountedInterest");
        assertEq(ILoanManagerLike(loanManager).accruedInterest(),   accruedInterest,   "accruedInterest");
        assertEq(ILoanManagerLike(loanManager).domainStart(),       domainStart,       "domainStart");
        assertEq(ILoanManagerLike(loanManager).issuanceRate(),      issuanceRate,      "issuanceRate");
        assertEq(ILoanManagerLike(loanManager).principalOut(),      principalOut,      "principalOut");
        assertEq(ILoanManagerLike(loanManager).unrealizedLosses(),  unrealizedLosses,  "unrealizedLosses");

        assertEq(
            ILoanManagerLike(loanManager).assetsUnderManagement(),
            principalOut + accountedInterest + accruedInterest,
            "assetsUnderManagement"
        );
    }

    function assertOpenTermLoanManagerWithDiff(
        address loanManager,
        uint256 accountedInterest,
        uint256 accruedInterest,
        uint256 domainStart,
        uint256 issuanceRate,
        uint256 principalOut,
        uint256 unrealizedLosses,
        uint256 diff
    )
        internal view
    {
        assertApproxEqAbs(ILoanManagerLike(loanManager).accountedInterest(), accountedInterest, diff, "accountedInterest");
        assertApproxEqAbs(ILoanManagerLike(loanManager).accruedInterest(),   accruedInterest,   diff, "accruedInterest");
        assertApproxEqAbs(ILoanManagerLike(loanManager).domainStart(),       domainStart,       diff, "domainStart");
        assertApproxEqAbs(ILoanManagerLike(loanManager).issuanceRate(),      issuanceRate,      diff, "issuanceRate");
        assertApproxEqAbs(ILoanManagerLike(loanManager).principalOut(),      principalOut,      diff, "principalOut");
        assertApproxEqAbs(ILoanManagerLike(loanManager).unrealizedLosses(),  unrealizedLosses,  diff, "unrealizedLosses");

        assertApproxEqAbs(
            ILoanManagerLike(loanManager).assetsUnderManagement(),
            principalOut + accountedInterest + accruedInterest,
            diff,
            "assetsUnderManagement"
        );
    }

    function assertImpairment(address loan, uint256 impairedDate, bool impairedByGovernor) internal view {
        IOpenTermLoanManager loanManager = IOpenTermLoanManager(ILoanLike(loan).lender());

        ( uint40 impairedDate_, bool impairedByGovernor_ ) = loanManager.impairmentFor(loan);

        assertEq(impairedDate_, impairedDate);

        assertTrue(impairedByGovernor_ == impairedByGovernor);
    }

    function assertLastRequestId(address withdrawalManager_, address user_, uint256 requestId_) internal view {
        assertEq(IWithdrawalManagerQueue(withdrawalManager_).requestIds(user_), requestId_);
    }

    function assertPermissions(
        address account,
        bool    canDeploy,
        bool    canReconcile,
        bool    canSchedule
    )
        internal view
    {
        ( bool canDeploy_, bool canReconcile_, bool canSchedule_ ) = bitcoinStrategy.permissions(account);

        assertEq(canDeploy_,    canDeploy);
        assertEq(canReconcile_, canReconcile);
        assertEq(canSchedule_,  canSchedule);
    }

    function assertPoolState(
        address pool,
        uint256 totalAssets,
        uint256 totalSupply,
        uint256 unrealizedLosses,
        uint256 availableLiquidity
    )
        internal view
    {
        IPoolManager poolManager = IPoolManager(IPool(pool).manager());
        IERC20       asset       = IERC20(IPool(pool).asset());

        assertEq(IPool(pool).totalAssets(),      totalAssets,        "totalAssets");
        assertEq(IPool(pool).totalSupply(),      totalSupply,        "totalSupply");
        assertEq(IPool(pool).unrealizedLosses(), unrealizedLosses,   "unrealizedLosses");
        assertEq(poolManager.totalAssets(),      totalAssets,        "totalAssets");
        assertEq(poolManager.unrealizedLosses(), unrealizedLosses,   "unrealizedLosses");
        assertEq(asset.balanceOf(pool),          availableLiquidity, "availableLiquidity");
    }

    function assertPoolStateWithDiff(
        address pool,
        uint256 totalAssets,
        uint256 totalSupply,
        uint256 unrealizedLosses,
        uint256 availableLiquidity,
        uint256 diff
    )
        internal view
    {
        IPoolManager poolManager = IPoolManager(IPool(pool).manager());
        IERC20       asset       = IERC20(IPool(pool).asset());

        assertApproxEqAbs(IPool(pool).totalAssets(),      totalAssets,        diff, "totalAssets");
        assertApproxEqAbs(IPool(pool).totalSupply(),      totalSupply,        diff, "totalSupply");
        assertApproxEqAbs(IPool(pool).unrealizedLosses(), unrealizedLosses,   diff, "unrealizedLosses");
        assertApproxEqAbs(poolManager.totalAssets(),      totalAssets,        diff, "totalAssets");
        assertApproxEqAbs(poolManager.unrealizedLosses(), unrealizedLosses,   diff, "unrealizedLosses");
        assertApproxEqAbs(asset.balanceOf(pool),          availableLiquidity, diff, "availableLiquidity");
    }

    function assertPoolManager(address poolManager, uint256 totalAssets, uint256 unrealizedLosses) internal view {
        assertEq(IPoolManager(poolManager).totalAssets(),      totalAssets,      "totalAssets");
        assertEq(IPoolManager(poolManager).unrealizedLosses(), unrealizedLosses, "unrealizedLosses");
    }

    function assertQueue(address poolManager, uint256 nextRequestId, uint256 lastRequestId) internal view {
        address wm = IPoolManager(poolManager).withdrawalManager();

        ( uint256 nextRequestId_, uint256 lastRequestId_ ) = IWithdrawalManagerQueue(wm).queue();

        assertEq(nextRequestId_, nextRequestId);
        assertEq(lastRequestId_, lastRequestId);
    }

    function assertRequest(address poolManager, uint256 requestId, address owner, uint256 shares) internal view {
        address wm = IPoolManager(poolManager).withdrawalManager();

        ( address owner_, uint256 shares_ ) = IWithdrawalManagerQueue(wm).requests(requestId);

        assertEq(owner_,  owner);
        assertEq(shares_, shares);
    }

    function assertRequestOnWm(
        uint256 requestId,
        address owner,
        uint256 shares
    )
        internal view
    {
        // This function does the same as assertRequest but is named differently in order to make reading of some tests more intuitive.
        assertRequest(address(poolManager), requestId, owner, shares);
    }

    function assertRequestOnRouter(
        uint256 requestId,
        address asset,
        address owner,
        uint256 shares
    )
        internal view
    {
        ( address asset_, address owner_, uint256 shares_ ) = bitcoinRouter.redeemRequests(requestId);
        assertEq(asset_,  asset);
        assertEq(owner_,  owner);
        assertEq(shares_, shares);
    }

    function assertSchedule(
        uint256 remainingYield,
        uint32  remainingDuration,
        uint32  lastUpdated,
        uint256 yieldRate
    )
        internal view
    {
        ( uint256 remainingYield_, uint32 lastUpdated_, uint32 remainingDuration_ ) = bitcoinStrategy.schedules(0);

        uint256 yieldRate_ = bitcoinStrategy.yieldRate();

        assertEq(remainingYield_,    remainingYield);
        assertEq(remainingDuration_, remainingDuration);
        assertEq(lastUpdated_,       lastUpdated);
        assertEq(yieldRate_,         yieldRate);
    }

    function assertSyrupBtcSystemState(
        uint256 strategyManagerBalance,
        uint256 assetControllerBalance,
        uint256 poolTotalAssets,
        uint256 poolCompositeTokenBalance
    )
        internal view
    {
        assertEq(depositAsset.balanceOf(strategyManager),      strategyManagerBalance);
        assertEq(depositAsset.balanceOf(assetControllerProxy), assetControllerBalance);
        assertEq(compositeAsset.balanceOf(address(pool)),      poolCompositeTokenBalance);
        assertEq(pool.totalAssets(),                           poolTotalAssets);
    }

    function assertAaveV3Strategy(
        address strategyManager,
        uint256 aum,
        uint256 aTokenBalance,
        uint256 lastRecordedTotalAssets,
        uint256 unrealizedLosses
    )
        internal view
    {
        address strategy = IStrategyManager(strategyManager).underlyingStrategy();

        assertEq(IStrategyManager(strategyManager).assetsUnderManagement(),         aum ,                    "manager aum");
        assertEq(IAaveV3Strategy(strategy).assetsUnderManagement(),                 aum,                     "underlying aum");
        assertEq(IERC20(IAaveV3Strategy(strategy).aaveToken()).balanceOf(strategy), aTokenBalance,           "aTokenBalance");
        assertEq(IAaveV3Strategy(strategy).lastRecordedTotalAssets(),               lastRecordedTotalAssets, "lastRecordedTotalAssets");
        assertEq(IAaveV3Strategy(strategy).unrealizedLosses(),                      unrealizedLosses,        "unrealizedLosses");
    }

    function assertSkyStrategy(address strategyManager, uint256 aum, uint256 unrealizedLosses) internal view {
        address strategy = IStrategyManager(strategyManager).underlyingStrategy();

        assertEq(IStrategyManager(strategyManager).assetsUnderManagement(), aum);
        assertEq(ISkyStrategy(strategy).assetsUnderManagement(),            aum);
        assertEq(ISkyStrategy(strategy).unrealizedLosses(),                 unrealizedLosses);
    }

    function assertTradingStrategy(
        address tradingStrategy,
        uint256 assetsUnderManagement,
        uint256 availableToWithdraw,
        uint256 totalDeployedAssets,
        uint256 unrealizedLosses
    )
        internal view
    {
        assertEq(ITradingStrategy(tradingStrategy).assetsUnderManagement(), assetsUnderManagement);
        assertEq(ITradingStrategy(tradingStrategy).availableToWithdraw(),   availableToWithdraw);
        assertEq(ITradingStrategy(tradingStrategy).totalDeployedAssets(),   totalDeployedAssets);
        assertEq(ITradingStrategy(tradingStrategy).unrealizedLosses(),      unrealizedLosses);
    }

    function assertTradingStrategyYield(
        address tradingStrategy,
        uint256 scheduledYieldAssets,
        uint32  yieldStart,
        uint32  yieldDeadline,
        uint256 realizedYield
    )
        internal view
    {
        uint256 unrealizedYield = scheduledYieldAssets - realizedYield;

        assertEq(ITradingStrategy(tradingStrategy).scheduledYieldAssets(), scheduledYieldAssets);
        assertEq(ITradingStrategy(tradingStrategy).yieldStart(),           yieldStart);
        assertEq(ITradingStrategy(tradingStrategy).yieldDeadline(),        yieldDeadline);
        assertEq(ITradingStrategy(tradingStrategy).realizedYield(),        realizedYield);
        assertEq(ITradingStrategy(tradingStrategy).unrealizedYield(),      unrealizedYield);
    }

    function assertInitialStateWithTrading(address strategyManager, uint256 initialLiquidity) internal view {
        address tradingStrategy = IStrategyManager(strategyManager).underlyingStrategy();

        assertPoolState({
            pool:               address(pool),
            totalAssets:        initialLiquidity,
            totalSupply:        initialLiquidity,
            unrealizedLosses:   0,
            availableLiquidity: initialLiquidity
        });

        assertTradingStrategy({
            tradingStrategy:       tradingStrategy,
            assetsUnderManagement: 0,
            availableToWithdraw:   0,
            totalDeployedAssets:   0,
            unrealizedLosses:      0
        });

        assertTradingStrategyYield({
            tradingStrategy:      tradingStrategy,
            scheduledYieldAssets: 0,
            yieldStart:           0,
            yieldDeadline:        0,
            realizedYield:        0
        });

        assertStrategyManagerPosition({
            strategyManager:  strategyManager,
            poolManager:      address(poolManager),
            assets:           0,
            shares:           0,
            pendingShares:    0,
            unrealizedLosses: 0
        });

        assertStrategyManagerShares({
            strategyManager:    strategyManager,
            totalShares:        0,
            totalPendingShares: 0
        });
    }

    function assertStrategyManagerShares(address strategyManager, uint256 totalShares, uint256 totalPendingShares) internal view {
        assertEq(IStrategyManager(strategyManager).totalShares(),        totalShares);
        assertEq(IStrategyManager(strategyManager).totalPendingShares(), totalPendingShares);
    }

    function assertStrategyManager(
        address strategyManager,
        uint256 totalShares,
        uint256 totalPendingShares,
        uint256 assetsUnderManagement,
        uint256 availableToWithdraw,
        uint256 unrealizedLosses
    )
        internal view
    {
        assertEq(IStrategyManager(strategyManager).totalShares(),        totalShares);
        assertEq(IStrategyManager(strategyManager).totalPendingShares(), totalPendingShares);

        assertEq(IStrategyManager(strategyManager).assetsUnderManagement(), assetsUnderManagement);
        assertEq(IStrategyManager(strategyManager).availableToWithdraw(),   availableToWithdraw);
        assertEq(IStrategyManager(strategyManager).unrealizedLosses(),      unrealizedLosses);
    }

    function assertStrategyManagerPosition(
        address strategyManager,
        address poolManager,
        uint256 assets,
        uint256 shares,
        uint256 pendingShares,
        uint256 unrealizedLosses
    )
        internal view
    {
        assertEq(IStrategyManager(strategyManager).assetsOf(poolManager),           assets);
        assertEq(IStrategyManager(strategyManager).sharesOf(poolManager),           shares);
        assertEq(IStrategyManager(strategyManager).pendingSharesOf(poolManager),    pendingShares);
        assertEq(IStrategyManager(strategyManager).unrealizedLossesOf(poolManager), unrealizedLosses);
    }

    function assertBitcoinStrategyState(
        address strategy,
        uint256 assetsUnderManagement,
        uint256 accruedYield,
        uint256 accruedFees,
        uint256 impairedAssets
    )
        internal view
    {
        assertEq(IBitcoinStrategy(strategy).assetsUnderManagement(), assetsUnderManagement);
        assertEq(IBitcoinStrategy(strategy).accruedYield(),          accruedYield);
        assertEq(IBitcoinStrategy(strategy).accruedFees(),           accruedFees);
        assertEq(IBitcoinStrategy(strategy).outstandingAssets(),     assetsUnderManagement + accruedFees - accruedYield);
        assertEq(IBitcoinStrategy(strategy).impairedAssets(),        impairedAssets);
    }

    function assertUserRequests(address poolManager, address owner, uint256[] memory requestIds) internal view {
        address wm = IPoolManager(poolManager).withdrawalManager();

        ( uint256[] memory requests, ) = IWithdrawalManagerQueue(wm).requestsByOwner(owner);

        assertEq(requests.length, requestIds.length);

        for (uint256 i; i < requestIds.length; i++) {
            assertEq(requests[i], requestIds[i]);
        }
    }

    function assertUsersRequestsOnWm(address user, uint256[] memory requestIds) internal view {
        // This function does the same as assertUserRequests but is named differently in order to make reading of some tests more intuitive.
        assertUserRequests(address(poolManager), user, requestIds);
    }


    function assertProposal(address timelock, uint256 proposalId, IGovernorTimelock.Proposal memory proposal ) internal view {
        (
            bytes32 proposalHash,
            bool    isUnschedulable,
            uint32  scheduledAt,
            uint32  delayedUntil,
            uint32  validUntil
        ) = IGovernorTimelock(timelock).proposals(proposalId);

        assertEq(proposalHash,    proposal.proposalHash);
        assertEq(isUnschedulable, proposal.isUnschedulable);
        assertEq(scheduledAt,     proposal.scheduledAt);
        assertEq(delayedUntil,    proposal.delayedUntil);
        assertEq(validUntil,      proposal.validUntil);
    }

    function assertEmptyProposal(address timelock, uint256 proposalId) internal view {
        (
            bytes32 proposalHash,
            bool    isUnschedulable,
            uint32  scheduledAt,
            uint32  delayedUntil,
            uint32  validUntil
        ) = IGovernorTimelock(timelock).proposals(proposalId);

        assertEq(proposalHash,    bytes32(0));
        assertEq(isUnschedulable, false);
        assertEq(scheduledAt,     0);
        assertEq(delayedUntil,    0);
        assertEq(validUntil,      0);
    }

    function assertNotEmptyProposal(address timelock, uint256 proposalId) internal view {
        (
            bytes32 proposalHash,
            ,
            uint32  scheduledAt,
            uint32  delayedUntil,
            uint32  validUntil
        ) = IGovernorTimelock(timelock).proposals(proposalId);

        assertNotEq(proposalHash, bytes32(0));
        assertNotEq(scheduledAt,  uint32(0));
        assertNotEq(delayedUntil, uint32(0));
        assertNotEq(validUntil,   uint32(0));
    }

}
