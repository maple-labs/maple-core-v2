// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC20,
    ILoanLike,
    IOpenTermLoan,
    IOpenTermLoanManager,
    IPool,
    IPoolManager,
    ISyrupRouter,
    IWithdrawalManagerQueue,
    IWithdrawalManagerQueueV200Like
} from "../../../contracts/interfaces/Interfaces.sol";

import { OpenTermLoanHealthChecker } from "../../health-checkers/OpenTermLoanHealthChecker.sol";
import { ProtocolHealthChecker }     from "../../health-checkers/ProtocolHealthChecker.sol";

import { HealthCheckerAssertions } from "../../HealthCheckerAssertions.sol";

import { SyrupUSDGDeploymentBase } from "./SyrupUSDGDeploymentBase.t.sol";

enum SyrupUSDGAction {
    Deposit,
    RequestRedeem,
    RemoveSharesById,
    ProcessRedemptions,
    CreateAndFundLoan,
    CallLoan,
    MakePayment,
    Warp
}

contract SyrupUSDGFuzzForkTests is SyrupUSDGDeploymentBase, HealthCheckerAssertions {

    uint256 constant ACTION_COUNT       = 50;
    uint256 constant MAX_DEPOSIT_AMOUNT = 5_000_000e6;
    uint256 constant MAX_LOAN_PRINCIPAL = 10_000_000e6;
    uint256 constant MAX_TIME_TO_PASS   = 30 days;
    uint256 constant MIN_ACTION_AMOUNT  = 1e6;

    address[] lenders;
    address[] loans;

    address usdgOpenTermLoanHealthChecker;
    address usdgProtocolHealthChecker;

    uint256 seed;

    function setUp() public override {
        super.setUp();

        lenders.push(makeAddr("usdgFuzzLender1"));
        lenders.push(makeAddr("usdgFuzzLender2"));
        lenders.push(makeAddr("usdgFuzzLender3"));

        for (uint256 i; i < lenders.length; ++i) {
            _setLenderBitmap(lenders[i]);
        }

        usdgOpenTermLoanHealthChecker = address(new OpenTermLoanHealthChecker());
        usdgProtocolHealthChecker     = address(new ProtocolHealthChecker());
    }

    function testFuzzFork_syrupUSDG_lifecycle_assertInvariants(uint256 seed_) external {
        vm.skip(true);
        
        seed = seed_;

        for (uint256 i; i < ACTION_COUNT; ++i) {
            SyrupUSDGAction action = SyrupUSDGAction(getSomeValue(0, uint256(SyrupUSDGAction.Warp)));

            performAction(action);
            assertInvariants();
            assertProtocolInvariants(usdgPoolManager, usdgProtocolHealthChecker, new address[](0));
            assertOpenTermLoanInvariants(usdgPoolManager, loans, usdgOpenTermLoanHealthChecker);
        }
    }

    function performAction(SyrupUSDGAction action_) internal {
        if (action_ == SyrupUSDGAction.Deposit) {
            deposit();
        } else if (action_ == SyrupUSDGAction.RequestRedeem) {
            requestRedeem();
        } else if (action_ == SyrupUSDGAction.RemoveSharesById) {
            removeSharesById();
        } else if (action_ == SyrupUSDGAction.ProcessRedemptions) {
            processRedemptions();
        } else if (action_ == SyrupUSDGAction.CreateAndFundLoan) {
            createAndFundOpenTermLoan();
        } else if (action_ == SyrupUSDGAction.CallLoan) {
            callOpenTermLoan();
        } else if (action_ == SyrupUSDGAction.MakePayment) {
            makeOpenTermLoanPayment();
        } else if (action_ == SyrupUSDGAction.Warp) {
            vm.warp(block.timestamp + getSomeValue(1 hours, MAX_TIME_TO_PASS));
        }
    }

    function deposit() internal {
        uint256 totalAssets = IPoolManager(usdgPoolManager).totalAssets();

        if (totalAssets >= LIQUIDITY_CAP) return;

        uint256 maxDepositAmount = _min(MAX_DEPOSIT_AMOUNT, LIQUIDITY_CAP - totalAssets);

        if (maxDepositAmount < MIN_ACTION_AMOUNT) return;

        address lender = lenders[getSomeValue(0, lenders.length - 1)];
        uint256 amount = getSomeValue(MIN_ACTION_AMOUNT, maxDepositAmount);

        deal(USDG, lender, IERC20(USDG).balanceOf(lender) + amount);

        vm.startPrank(lender);
        IERC20(USDG).approve(usdgSyrupRouter, amount);
        ISyrupRouter(usdgSyrupRouter).deposit(amount, DEPOSIT_DATA);
        vm.stopPrank();
    }

    function requestRedeem() internal {
        address lender = lenders[getSomeValue(0, lenders.length - 1)];
        uint256 shares = IPool(usdgPool).balanceOf(lender);

        if (shares == 0) return;

        uint256 sharesToRedeem = getSomeValue(1, shares);

        vm.prank(lender);
        IPool(usdgPool).requestRedeem(sharesToRedeem, lender);
    }

    function removeSharesById() internal {
        address lender = lenders[getSomeValue(0, lenders.length - 1)];

        (
            uint256[] memory requestIds,
            uint256[] memory shares
        ) = IWithdrawalManagerQueue(usdgWithdrawalManager).requestsByOwner(lender);

        if (requestIds.length == 0) return;

        uint256 index          = getSomeValue(0, requestIds.length - 1);
        uint256 sharesToRemove = getSomeValue(1, shares[index]);

        vm.prank(lender);
        IWithdrawalManagerQueue(usdgWithdrawalManager).removeSharesById(requestIds[index], sharesToRemove);
    }

    function processRedemptions() internal {
        uint256 totalShares = IWithdrawalManagerQueue(usdgWithdrawalManager).totalShares();

        if (totalShares == 0) return;

        uint256 totalSupply           = IPool(usdgPool).totalSupply();
        uint256 totalAssets           = IPoolManager(usdgPoolManager).totalAssets();
        uint256 unrealizedLosses      = IPoolManager(usdgPoolManager).unrealizedLosses();
        uint256 totalAssetsWithLosses = totalAssets - unrealizedLosses;
        uint256 idleAssets            = IERC20(USDG).balanceOf(usdgPool);

        if (totalSupply == 0 || totalAssetsWithLosses == 0 || idleAssets == 0) return;

        uint256 maxProcessableShares = idleAssets * totalSupply / totalAssetsWithLosses;
        uint256 maxSharesToProcess   = _min(totalShares, maxProcessableShares);

        if (maxSharesToProcess == 0) return;

        uint256 sharesToProcess = getSomeValue(1, maxSharesToProcess);

        vm.prank(poolDelegate);
        IWithdrawalManagerQueueV200Like(usdgWithdrawalManager).processRedemptions(sharesToProcess);
    }

    function createAndFundOpenTermLoan() internal {
        uint256 idleAssets = IERC20(USDG).balanceOf(usdgPool);

        if (idleAssets < MIN_ACTION_AMOUNT) return;

        uint256 maxPrincipal = _min(MAX_LOAN_PRINCIPAL, idleAssets);

        if (maxPrincipal < MIN_ACTION_AMOUNT) return;

        uint256 principal = getSomeValue(MIN_ACTION_AMOUNT, maxPrincipal);
        address borrower  = makeAddr(string(abi.encodePacked("usdgFuzzBorrower", loans.length)));

        uint256[3] memory terms = [
            getSomeValue(1 hours, 10 days),
            getSomeValue(1 hours, 10 days),
            getSomeValue(10 days, 90 days)
        ];

        uint256[4] memory rates = [
            getSomeValue(0,      0.1e6),
            getSomeValue(0.01e6, 0.25e6),
            getSomeValue(0,      0.1e6),
            getSomeValue(0,      0.1e6)
        ];

        address loan = createOpenTermLoan(
            openTermLoanFactory,
            borrower,
            usdgOpenTermLoanManager,
            USDG,
            principal,
            terms,
            rates
        );

        loans.push(loan);

        fundLoan(loan);
    }

    function callOpenTermLoan() internal {
        address loan = getSomeActiveLoan(false);

        if (loan == address(0)) {
            createAndFundOpenTermLoan();

            loan = getSomeActiveLoan(false);
        }

        if (loan == address(0)) return;

        uint256 principal = IOpenTermLoan(loan).principal();

        if (principal == 0) return;

        callLoan(loan, getSomeValue(1, principal));
    }

    function makeOpenTermLoanPayment() internal {
        address loan = getSomeActiveLoan(true);

        if (loan == address(0)) return;

        (
            uint256 principalDue,
            uint256 interest,
            uint256 lateInterest,
            uint256 delegateServiceFee,
            uint256 platformServiceFee
        ) = IOpenTermLoan(loan).getPaymentBreakdown(block.timestamp);

        uint256 principalToReturn = principalDue == 0 ? getSomeValue(0, IOpenTermLoan(loan).principal()) : principalDue;
        uint256 paymentAmount = principalToReturn + interest + lateInterest + delegateServiceFee + platformServiceFee;

        if (paymentAmount == 0) return;

        address borrower = ILoanLike(loan).borrower();

        deal(USDG, borrower, IERC20(USDG).balanceOf(borrower) + paymentAmount);

        vm.startPrank(borrower);
        IERC20(USDG).approve(loan, paymentAmount);
        IOpenTermLoan(loan).makePayment(principalToReturn);
        vm.stopPrank();
    }

    function assertInvariants() internal view {
        uint256 loanAssetsUnderManagement = IOpenTermLoanManager(usdgOpenTermLoanManager).assetsUnderManagement();
        uint256 principalOut              = IOpenTermLoanManager(usdgOpenTermLoanManager).principalOut();
        uint256 poolBalance               = IERC20(USDG).balanceOf(usdgPool);
        uint256 expectedTotalAssets       = poolBalance + loanAssetsUnderManagement;
        uint256 escrowedShares            = IPool(usdgPool).balanceOf(usdgWithdrawalManager);
        uint256 totalQueuedShares         = IWithdrawalManagerQueue(usdgWithdrawalManager).totalShares();

        assertEq(IPool(usdgPool).totalAssets(),               expectedTotalAssets);
        assertEq(IPoolManager(usdgPoolManager).totalAssets(), expectedTotalAssets);
        assertEq(IERC20(USDG).balanceOf(usdgSyrupRouter),     0);
        assertEq(IPool(usdgPool).balanceOf(usdgSyrupRouter),  0);
        assertEq(escrowedShares,                              totalQueuedShares);
        assertEq(IPool(usdgPool).balanceOf(address(0)),       INITIAL_DEPOSIT);
        assertEq(sumLoanPrincipal(),                          principalOut);
        assertGe(loanAssetsUnderManagement,                   principalOut);
    }

    function getSomeActiveLoan(bool allowCalled_) internal returns (address loan_) {
        if (loans.length == 0) return address(0);

        uint256 startIndex = getSomeValue(0, loans.length - 1);

        for (uint256 i; i < loans.length; ++i) {
            address loan = loans[(startIndex + i) % loans.length];

            if (IOpenTermLoan(loan).principal() == 0) continue;
            if (IOpenTermLoan(loan).isInDefault()) continue;
            if (!allowCalled_ && IOpenTermLoan(loan).isCalled()) continue;

            return loan;
        }
    }

    function sumLoanPrincipal() internal view returns (uint256 principal_) {
        for (uint256 i; i < loans.length; ++i) {
            principal_ += IOpenTermLoan(loans[i]).principal();
        }
    }

    function getSomeValue(uint256 min_, uint256 max_) internal returns (uint256 value_) {
        value_ = _bound(seed = uint256(keccak256(abi.encode(seed))), min_, max_);
    }

    function _min(uint256 a_, uint256 b_) internal pure returns (uint256 min_) {
        min_ = a_ < b_ ? a_ : b_;
    }

}
