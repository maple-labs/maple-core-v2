// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAllocationStrategy,
    IERC20,
    IGlobals,
    IMockERC20,
    IOpenTermLoan,
    IOpenTermLoanManager,
    IPool,
    IPoolManager,
    IPoolPermissionManager,
    IStrategyManager,
    IWithdrawalManagerQueue
} from "../../../contracts/interfaces/Interfaces.sol";

import { AllocationStrategyHandler } from "../../invariants/handlers/AllocationStrategyHandler.sol";
import { OpenTermLoanHandler } from "../../invariants/handlers/OpenTermLoanHandler.sol";

import { BaseInvariants } from "../../invariants/BaseInvariants.t.sol";

import { SyrupUSD1Deployment } from "./SyrupUSD1Deployment.sol";

enum SyrupUSD1Action {
    Deposit,
    RequestPoolRedemption,
    ProcessPoolRedemption,
    FundLoan,
    CallLoan,
    MakePayment,
    FundStrategy,
    RequestStrategyRedemption,
    ProcessStrategyRedemption,
    DeployAssets,
    ReturnAssets,
    RealizeYield,
    ImpairStrategy,
    RecognizeLoss,
    SetStrategyDelegateFeeRate,
    SetStrategyProtocolFeeRate
}

contract SyrupUSD1LifecycleFuzzForkTests is BaseInvariants {

    uint256 constant ACTION_COUNT       = 50;
    uint256 constant ALLOWED_DIFF       = 1000;
    uint256 constant BORROWER_COUNT     = 2;
    uint256 constant FORK_BLOCK         = 26_096_404;
    uint256 constant INITIAL_DEPLOYMENT = 500_000e18;
    uint256 constant INITIAL_DEPOSIT    = 1_000_000e18;
    uint256 constant INITIAL_FUNDING    = 1_000_000e18;
    uint256 constant LENDER_COUNT       = 2;
    uint256 constant MAX_DEPOSIT_AMOUNT = 5_000_000e18;
    uint256 constant MAX_LOANS          = 10;
    uint256 constant MAX_TIME_TO_PASS   = 7 days;
    uint256 constant MAX_YIELD_AMOUNT   = 1_000_000e18;
    uint256 constant MAX_YIELD_DURATION = 30 days;
    uint256 constant MIN_ACTION_AMOUNT  = 1e18;
    uint256 constant MIN_TIME_TO_PASS   = 1 hours;

    address usd1AllocationStrategy;
    address usd1ManagedWallet;
    address usd1OpenTermLoanManager;
    address usd1Pool;
    address usd1PoolManager;
    address usd1StrategyManager;
    address usd1WithdrawalManager;

    uint256 totalDeployed;
    uint256 totalFees;
    uint256 totalFundings;
    uint256 totalLosses;
    uint256 totalReturned;
    uint256 totalWithdrawals;
    uint256 totalYield;

    uint256 seed;

    function setUp() public override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), FORK_BLOCK);

        SyrupUSD1Deployment deployment = new SyrupUSD1Deployment();

        deployment.upgradeProtocolAndDeploySyrupUSD1();

        loadDeployment(deployment);
        setupLenders(deployment);
        setupLoanHandler(deployment);
        setupInitialPositions();
    }

    function testFuzzFork_syrupUSD1_lifecycle_assertInvariants(uint256 seed_) external {
        seed = seed_;

        for (uint256 i; i < ACTION_COUNT; ++i) {
            warpSomeTime();
            performAction();
            assertInvariants();
        }

        windDown();
        assertInvariants();
        assertPositionsClosed();
    }

    /**************************************************************************************************************************************/
    /*** Setup                                                                                                                          ***/
    /**************************************************************************************************************************************/

    function loadDeployment(SyrupUSD1Deployment deployment_) internal {
        usd1AllocationStrategy  = deployment_.allocationStrategy();
        usd1ManagedWallet       = deployment_.managedWallet();
        usd1OpenTermLoanManager = deployment_.openTermLoanManager();
        usd1Pool                = deployment_.pool();
        usd1PoolManager         = deployment_.poolManager();
        usd1StrategyManager     = deployment_.strategyManager();
        usd1WithdrawalManager   = deployment_.withdrawalManager();

        fundsAsset = IMockERC20(USD1);

        totalFundings = IGlobals(deployment_.globals()).bootstrapMint(USD1);
    }

    function setupLenders(SyrupUSD1Deployment deployment_) internal {
        address[] memory lenders_ = new address[](LENDER_COUNT);
        uint256[] memory bitmaps_ = new uint256[](LENDER_COUNT);

        for (uint256 i; i < LENDER_COUNT; ++i) {
            lps.push(makeAddr(string(abi.encodePacked("usd1Lender", vm.toString(i)))));

            lenders_[i] = lps[i];
            bitmaps_[i] = 2 ** 4;
        }

        IPoolPermissionManager ppm = IPoolPermissionManager(deployment_.poolPermissionManager());

        vm.prank(deployment_.operationalAdmin());
        ppm.setLenderBitmaps(lenders_, bitmaps_);

        for (uint256 i; i < LENDER_COUNT; ++i) {
            depositAssets(lps[i], INITIAL_DEPOSIT);
        }
    }

    function setupLoanHandler(SyrupUSD1Deployment deployment_) internal {
        address[] memory poolManagers_ = new address[](1);
        address[] memory borrowers_    = new address[](BORROWER_COUNT);

        poolManagers_[0] = usd1PoolManager;

        for (uint256 i; i < BORROWER_COUNT; ++i) {
            borrowers_[i] = makeAddr(string(abi.encodePacked("usd1Borrower", vm.toString(i))));
        }

        otlHandler = new OpenTermLoanHandler({
            handlerName_:  "otlHandler",
            loanFactory_:  deployment_.openTermLoanFactory(),
            refinancer_:   deployment_.openTermRefinancer(),
            poolManagers_: poolManagers_,
            borrowers_:    borrowers_,
            maxLoans_:     MAX_LOANS
        });
    }

    function setupInitialPositions() internal {
        fundStrategyManager(usd1PoolManager, usd1StrategyManager, INITIAL_FUNDING);
        deployAssets(usd1AllocationStrategy, usd1ManagedWallet, INITIAL_DEPLOYMENT);

        totalFundings += INITIAL_FUNDING;
        totalDeployed += INITIAL_DEPLOYMENT;

        otlHandler.fundLoan(1);
        otlHandler.fundLoan(2);

        uint256 strategyShares = IStrategyManager(usd1StrategyManager).sharesOf(usd1PoolManager);
        uint256 lenderShares   = IPool(usd1Pool).balanceOf(lps[0]);

        requestRedeemFromStrategyManager(usd1PoolManager, usd1StrategyManager, strategyShares / 2);
        requestRedeem(usd1Pool, lps[0], lenderShares / 2);
    }

    /**************************************************************************************************************************************/
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function performAction() internal {
        SyrupUSD1Action action_ = SyrupUSD1Action(getSomeValue(0, uint256(SyrupUSD1Action.SetStrategyProtocolFeeRate)));

        if (action_ == SyrupUSD1Action.Deposit) {
            deposit();
        } else if (action_ == SyrupUSD1Action.RequestPoolRedemption) {
            requestPoolRedemption();
        } else if (action_ == SyrupUSD1Action.ProcessPoolRedemption) {
            processPoolRedemption();
        } else if (action_ == SyrupUSD1Action.FundLoan) {
            otlHandler.fundLoan(getSomeValue(0, type(uint256).max));
        } else if (action_ == SyrupUSD1Action.CallLoan) {
            otlHandler.callLoan(getSomeValue(0, type(uint256).max));
        } else if (action_ == SyrupUSD1Action.MakePayment) {
            otlHandler.makePayment(getSomeValue(0, type(uint256).max));
        } else if (action_ == SyrupUSD1Action.FundStrategy) {
            fundStrategy();
        } else if (action_ == SyrupUSD1Action.RequestStrategyRedemption) {
            requestStrategyRedemption();
        } else if (action_ == SyrupUSD1Action.ProcessStrategyRedemption) {
            processStrategyRedemption();
        } else if (action_ == SyrupUSD1Action.DeployAssets) {
            deployAssets();
        } else if (action_ == SyrupUSD1Action.ReturnAssets) {
            returnAssets();
        } else if (action_ == SyrupUSD1Action.RealizeYield) {
            realizeYield();
        } else if (action_ == SyrupUSD1Action.ImpairStrategy) {
            impairStrategy();
        } else if (action_ == SyrupUSD1Action.RecognizeLoss) {
            recognizeLoss();
        } else if (action_ == SyrupUSD1Action.SetStrategyDelegateFeeRate) {
            setStrategyDelegateFeeRate();
        } else if (action_ == SyrupUSD1Action.SetStrategyProtocolFeeRate) {
            setStrategyProtocolFeeRate();
        }
    }

    function deposit() internal {
        uint256 liquidityCap = IPoolManager(usd1PoolManager).liquidityCap();
        uint256 totalAssets  = IPoolManager(usd1PoolManager).totalAssets();

        if (totalAssets >= liquidityCap) return;

        uint256 maxDepositAmount = min(MAX_DEPOSIT_AMOUNT, liquidityCap - totalAssets);

        if (maxDepositAmount < MIN_ACTION_AMOUNT) return;

        address lender = lps[getSomeValue(0, lps.length - 1)];
        uint256 assets = getSomeValue(MIN_ACTION_AMOUNT, maxDepositAmount);

        depositAssets(lender, assets);
    }

    function requestPoolRedemption() internal {
        address lender = lps[getSomeValue(0, lps.length - 1)];
        uint256 shares = IPool(usd1Pool).balanceOf(lender);

        if (shares == 0) return;

        uint256 sharesToRedeem = getSomeValue(1, shares);

        vm.prank(lender);
        IPool(usd1Pool).requestRedeem(sharesToRedeem, lender);
    }

    function processPoolRedemption() internal {
        uint256 totalShares = IWithdrawalManagerQueue(usd1WithdrawalManager).totalShares();

        if (totalShares == 0) return;

        uint256 totalSupply      = IPool(usd1Pool).totalSupply();
        uint256 totalAssets      = IPoolManager(usd1PoolManager).totalAssets();
        uint256 unrealizedLosses = IPoolManager(usd1PoolManager).unrealizedLosses();
        uint256 idleAssets       = IERC20(USD1).balanceOf(usd1Pool);

        if (totalAssets <= unrealizedLosses || idleAssets == 0) return;

        uint256 maxProcessableShares = idleAssets * totalSupply / (totalAssets - unrealizedLosses);
        uint256 maxSharesToProcess   = min(totalShares, maxProcessableShares);

        if (maxSharesToProcess == 0) return;

        uint256 sharesToProcess = getSomeValue(1, maxSharesToProcess);

        processRedemptions(usd1Pool, sharesToProcess);
    }

    function fundStrategy() internal {
        uint256 idleAssets = IERC20(USD1).balanceOf(usd1Pool);

        if (idleAssets == 0) return;

        uint256 assets = getSomeValue(1, idleAssets);

        if (IStrategyManager(usd1StrategyManager).convertToShares(assets) == 0) return;

        fundStrategyManager(usd1PoolManager, usd1StrategyManager, assets);

        totalFundings += assets;
    }

    function requestStrategyRedemption() internal {
        IStrategyManager strategyManager = IStrategyManager(usd1StrategyManager);

        uint256 freeShares = strategyManager.sharesOf(usd1PoolManager) - strategyManager.pendingSharesOf(usd1PoolManager);

        if (freeShares == 0) return;

        uint256 shares = getSomeValue(1, freeShares);

        requestRedeemFromStrategyManager(usd1PoolManager, usd1StrategyManager, shares);
    }

    function processStrategyRedemption() internal {
        IStrategyManager strategyManager = IStrategyManager(usd1StrategyManager);

        uint256 pendingShares = strategyManager.pendingSharesOf(usd1PoolManager);

        if (pendingShares == 0) return;
        if (strategyManager.unrealizedLosses() >= strategyManager.assetsUnderManagement()) return;

        uint256 redeemableShares = min(pendingShares, strategyManager.convertToExitShares(strategyManager.availableToWithdraw()));

        if (redeemableShares == 0) return;

        uint256 shares = getSomeValue(1, redeemableShares);
        uint256 assets = strategyManager.convertToExitAssets(shares);

        if (assets == 0) return;

        processRedemptionFromStrategyManager(usd1PoolManager, usd1StrategyManager, shares);

        totalWithdrawals += assets;
    }

    function deployAssets() internal {
        uint256 availableAssets = IAllocationStrategy(usd1AllocationStrategy).availableToWithdraw();

        if (availableAssets == 0) return;

        uint256 assets = getSomeValue(1, availableAssets);

        deployAssets(usd1AllocationStrategy, usd1ManagedWallet, assets);

        totalDeployed += assets;
    }

    function returnAssets() internal {
        uint256 deployedAssets = IAllocationStrategy(usd1AllocationStrategy).deployedAssetsOf(usd1ManagedWallet);

        if (deployedAssets == 0) return;

        uint256 assets = getSomeValue(1, deployedAssets);

        returnAssets(usd1AllocationStrategy, usd1ManagedWallet, usd1ManagedWallet, assets);

        totalReturned += assets;
    }

    function realizeYield() internal {
        IAllocationStrategy strategy = IAllocationStrategy(usd1AllocationStrategy);

        if (strategy.yieldCooldown() != 0) return;

        uint256 yieldAssets = getSomeValue(0, MAX_YIELD_AMOUNT);
        uint256 duration    = getSomeValue(0, MAX_YIELD_DURATION);

        uint256 delegateFee = yieldAssets * strategy.strategyDelegateFeeRate() / 1e6;
        uint256 protocolFee = yieldAssets * strategy.strategyProtocolFeeRate() / 1e6;

        realizeYield(usd1AllocationStrategy, usd1ManagedWallet, yieldAssets, uint32(duration));

        totalYield += yieldAssets;
        totalFees  += delegateFee + protocolFee;
    }

    function impairStrategy() internal {
        uint256 assetsUnderManagement = IAllocationStrategy(usd1AllocationStrategy).assetsUnderManagement();
        uint256 currentImpairment     = IAllocationStrategy(usd1AllocationStrategy).impairedAssets();

        if (currentImpairment >= assetsUnderManagement) return;

        uint256 assets = getSomeValue(1, assetsUnderManagement - currentImpairment);

        impairAllocationStrategy(usd1AllocationStrategy, assets);
    }

    function recognizeLoss() internal {
        uint256 deployedAssets = IAllocationStrategy(usd1AllocationStrategy).deployedAssetsOf(usd1ManagedWallet);

        if (deployedAssets == 0) return;

        uint256 assets = getSomeValue(1, deployedAssets);

        recognizeLoss(usd1AllocationStrategy, usd1ManagedWallet, assets);

        totalLosses += assets;
    }

    function setStrategyDelegateFeeRate() internal {
        IAllocationStrategy strategy = IAllocationStrategy(usd1AllocationStrategy);

        uint256 feeRate = getSomeValue(0, 1e6 - strategy.strategyProtocolFeeRate());

        if (feeRate == strategy.strategyDelegateFeeRate()) return;

        setStrategyDelegateFeeRate(usd1AllocationStrategy, uint32(feeRate));
    }

    function setStrategyProtocolFeeRate() internal {
        IAllocationStrategy strategy = IAllocationStrategy(usd1AllocationStrategy);

        uint256 feeRate = getSomeValue(0, 1e6 - strategy.strategyDelegateFeeRate());

        if (feeRate == strategy.strategyProtocolFeeRate()) return;

        setStrategyProtocolFeeRate(usd1AllocationStrategy, uint32(feeRate));
    }

    /**************************************************************************************************************************************/
    /*** Wind Down                                                                                                                      ***/
    /**************************************************************************************************************************************/

    function windDown() internal {
        uint32 yieldDeadline = IAllocationStrategy(usd1AllocationStrategy).yieldDeadline();

        if (yieldDeadline > block.timestamp) vm.warp(yieldDeadline);

        repayAllLoans();
        exitStrategy();
        exitPool();
    }

    function repayAllLoans() internal {
        for (uint256 i; i < otlHandler.numLoans(); ++i) {
            address loan = otlHandler.loans(i);

            if (IOpenTermLoan(loan).dateFunded() == 0) continue;

            makePayment(loan, IOpenTermLoan(loan).principal());
        }
    }

    function exitStrategy() internal {
        IAllocationStrategy strategy        = IAllocationStrategy(usd1AllocationStrategy);
        IStrategyManager    strategyManager = IStrategyManager(usd1StrategyManager);

        uint256 deployedAssets = strategy.deployedAssetsOf(usd1ManagedWallet);

        if (deployedAssets > 0) {
            returnAssets(usd1AllocationStrategy, usd1ManagedWallet, usd1ManagedWallet, deployedAssets);

            totalReturned += deployedAssets;
        }

        uint256 impairedAssets = strategy.impairedAssets();

        if (impairedAssets > 0) removeStrategyImpairment(usd1AllocationStrategy, impairedAssets);

        if (strategyManager.assetsOf(usd1PoolManager) == 0) return;

        uint256 shares        = strategyManager.sharesOf(usd1PoolManager);
        uint256 pendingShares = strategyManager.pendingSharesOf(usd1PoolManager);

        if (shares > pendingShares) requestRedeemFromStrategyManager(usd1PoolManager, usd1StrategyManager, shares - pendingShares);

        uint256 assets = strategyManager.convertToExitAssets(shares);

        processRedemptionFromStrategyManager(usd1PoolManager, usd1StrategyManager, shares);

        totalWithdrawals += assets;
    }

    function exitPool() internal {
        for (uint256 i; i < lps.length; ++i) {
            uint256 shares = IPool(usd1Pool).balanceOf(lps[i]);

            if (shares > 0) requestRedeem(usd1Pool, lps[i], shares);
        }

        processRedemptions(usd1Pool, IWithdrawalManagerQueue(usd1WithdrawalManager).totalShares());
    }

    /**************************************************************************************************************************************/
    /*** Invariants                                                                                                                     ***/
    /**************************************************************************************************************************************/

    function assertInvariants() internal {
        address[] memory loans_        = _getActiveLoans();
        address[] memory poolManagers_ = new address[](1);

        poolManagers_[0] = usd1PoolManager;

        AllocationStrategyHandler.ManagedWalletInfo[] memory walletInfo_ = new AllocationStrategyHandler.ManagedWalletInfo[](1);

        walletInfo_[0] = AllocationStrategyHandler.ManagedWalletInfo({
            wallet:   usd1ManagedWallet,
            deployed: totalDeployed,
            returned: totalReturned,
            lost:     totalLosses
        });

        assert_pool_invariants(usd1Pool);
        assert_pool_manager_invariants(usd1PoolManager);
        assert_wm_invariants(usd1WithdrawalManager, lps);
        assert_otl_invariants(loans_);
        assert_otlm_invariants(usd1OpenTermLoanManager, loans_);
        assert_strategyManager_invariants(usd1StrategyManager, poolManagers_);
        assert_allocationStrategy_invariants({
            strategy_:    usd1AllocationStrategy,
            fundings_:    totalFundings,
            yield_:       totalYield,
            withdrawals_: totalWithdrawals,
            fees_:        totalFees,
            losses_:      totalLosses,
            walletInfo_:  walletInfo_
        });
    }

    function assertPositionsClosed() internal view {
        assertEq(IOpenTermLoanManager(usd1OpenTermLoanManager).principalOut(), 0);

        assertApproxEqAbs(IOpenTermLoanManager(usd1OpenTermLoanManager).assetsUnderManagement(), 0, ALLOWED_DIFF);

        assertEq(IAllocationStrategy(usd1AllocationStrategy).totalDeployedAssets(), 0);
        assertEq(IStrategyManager(usd1StrategyManager).assetsOf(usd1PoolManager),   0);
        assertEq(IWithdrawalManagerQueue(usd1WithdrawalManager).totalShares(),      0);
        assertEq(IPool(usd1Pool).totalSupply(),                                     IPool(usd1Pool).balanceOf(address(0)));

        for (uint256 i; i < lps.length; ++i) {
            assertEq(IPool(usd1Pool).balanceOf(lps[i]), 0);
        }

        assertApproxEqAbs(IPoolManager(usd1PoolManager).totalAssets(), IERC20(USD1).balanceOf(usd1Pool), ALLOWED_DIFF);
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function depositAssets(address lender_, uint256 assets_) internal {
        erc20_mint(USD1, lender_, assets_);
        erc20_approve(USD1, lender_, usd1Pool, assets_);

        vm.prank(lender_);
        IPool(usd1Pool).deposit(assets_, lender_);
    }

    function getSomeValue(uint256 min_, uint256 max_) internal returns (uint256 value_) {
        value_ = _bound(seed, min_, max_);
        seed   = uint256(keccak256(abi.encode(seed)));
    }

    function min(uint256 a_, uint256 b_) internal pure returns (uint256 min_) {
        min_ = a_ < b_ ? a_ : b_;
    }

    function warpSomeTime() internal {
        vm.warp(block.timestamp + getSomeValue(MIN_TIME_TO_PASS, MAX_TIME_TO_PASS));
    }

}
