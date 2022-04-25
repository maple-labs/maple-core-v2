// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

import { MockERC20 }              from "../modules/erc20/contracts/test/mocks/MockERC20.sol";
import { ConstructableMapleLoan } from "../modules/loan/contracts/test/harnesses/MapleLoanHarnesses.sol";
import { MockFactory }            from "../modules/loan/contracts/test/mocks/Mocks.sol";

import { MapleLoan as Loan }     from "../modules/loan/contracts/MapleLoan.sol";
import { LoanInvestmentManager } from "../modules/poolV2/contracts/LoanInvestmentManager.sol";
import { PoolV2 as Pool }        from "../modules/poolV2/contracts/PoolV2.sol";

contract LoanIntegrationTest is TestUtils {

    address internal constant BORROWER           = address(1);
    address internal constant LIQUIDITY_PROVIDER = address(2);
    address internal constant POOL_DELEGATE      = address(3);

    uint256 internal constant DEPOSIT          = 10_000_000e6;
    uint256 internal constant INTEREST         = PRINCIPAL * INTEREST_RATE * PAYMENT_INTERVAL / 365 days / 1e18;
    uint256 internal constant INTEREST_RATE    = 0.1e18;
    uint256 internal constant ISSUANCE_RATE    = INTEREST * 1e30 / 1e6;
    uint256 internal constant PAYMENT_INTERVAL = 1_000_000 seconds;
    uint256 internal constant PRINCIPAL        = 1_000_000e6;

    uint256 internal immutable START = block.timestamp;

    MockERC20 internal immutable USDC = new MockERC20("USD Coin",    "USDC", 6);
    MockERC20 internal immutable WBTC = new MockERC20("Wrapped BTC", "WBTC", 8);

    Loan                  internal _loan;
    LoanInvestmentManager internal _investmentManager;
    Pool                  internal _pool;

    function setUp() public {
        // Create the pool contract.
        _pool = new Pool({
            name_:      "Maple Pool V2",
            symbol_:    "MPv2",
            owner_:     POOL_DELEGATE,
            asset_:     address(USDC),
            precision_: 1e30
        });

        // Inject the investment manager.
        _investmentManager = new LoanInvestmentManager(address(_pool));
        _pool.setInvestmentManager(address(_investmentManager));

        // Deposit initial liquidity into the pool.
        vm.startPrank(LIQUIDITY_PROVIDER);

        USDC.mint(LIQUIDITY_PROVIDER, DEPOSIT);
        USDC.approve(address(_pool), DEPOSIT);
        _pool.deposit(DEPOSIT, LIQUIDITY_PROVIDER);

        vm.stopPrank();

        // Define the terms of the loan and instantiate it.
        address[2] memory assets      = [address(WBTC), address(USDC)];
        uint256[3] memory termDetails = [10 days, PAYMENT_INTERVAL, 2];
        uint256[3] memory amounts     = [0, PRINCIPAL, PRINCIPAL];
        uint256[4] memory rates       = [INTEREST_RATE, 0, 0, 0];

        MockFactory factory = new MockFactory();
        _loan = new ConstructableMapleLoan(address(factory), address(BORROWER), assets, termDetails, amounts, rates);
    }

    function test_loanIntegration() external {
        assertEq(_loan.claimableFunds(),     0);
        assertEq(_loan.drawableFunds(),      0);
        assertEq(_loan.nextPaymentDueDate(), 0);
        assertEq(_loan.paymentsRemaining(),  2);
        assertEq(_loan.principal(),          0);

        ( uint256 lastClaim, uint256 nextClaim, uint256 pendingInterest, uint256 principalOut ) = _investmentManager.investments(address(_loan));

        assertEq(lastClaim,       0);
        assertEq(nextClaim,       0);
        assertEq(pendingInterest, 0);
        assertEq(principalOut,    0);

        assertEq(_pool.freeAssets(),          DEPOSIT);
        assertEq(_pool.interestOut(),         0);
        assertEq(_pool.issuanceRate(),        0);
        assertEq(_pool.lastUpdated(),         START);
        assertEq(_pool.principalOut(),        0);
        assertEq(_pool.totalAssets(),         DEPOSIT);
        assertEq(_pool.vestingPeriodFinish(), 0);

        assertEq(USDC.balanceOf(BORROWER),      0);
        assertEq(USDC.balanceOf(POOL_DELEGATE), 0);

        assertEq(USDC.balanceOf(address(_loan)),              0);
        assertEq(USDC.balanceOf(address(_investmentManager)), 0);
        assertEq(USDC.balanceOf(address(_pool)),              DEPOSIT);

        /*********************/
        /*** Fund the Loan ***/
        /*********************/

        vm.prank(POOL_DELEGATE);
        _pool.fund(PRINCIPAL, address(_loan));

        assertEq(_loan.claimableFunds(),     0);
        assertEq(_loan.drawableFunds(),      PRINCIPAL);
        assertEq(_loan.nextPaymentDueDate(), START + PAYMENT_INTERVAL);
        assertEq(_loan.paymentsRemaining(),  2);
        assertEq(_loan.principal(),          PRINCIPAL);

        ( lastClaim, nextClaim, pendingInterest, principalOut ) = _investmentManager.investments(address(_loan));

        assertEq(lastClaim,       START);
        assertEq(nextClaim,       START + PAYMENT_INTERVAL);
        assertEq(pendingInterest, INTEREST);
        assertEq(principalOut,    PRINCIPAL);

        assertEq(_pool.freeAssets(),          DEPOSIT);
        assertEq(_pool.interestOut(),         INTEREST);
        assertEq(_pool.issuanceRate(),        ISSUANCE_RATE);
        assertEq(_pool.lastUpdated(),         START);
        assertEq(_pool.principalOut(),        PRINCIPAL);
        assertEq(_pool.totalAssets(),         DEPOSIT);
        assertEq(_pool.vestingPeriodFinish(), START + PAYMENT_INTERVAL);

        assertEq(USDC.balanceOf(BORROWER),      0);
        assertEq(USDC.balanceOf(POOL_DELEGATE), 0);

        assertEq(USDC.balanceOf(address(_loan)),              PRINCIPAL);
        assertEq(USDC.balanceOf(address(_investmentManager)), 0);
        assertEq(USDC.balanceOf(address(_pool)),              DEPOSIT - PRINCIPAL);

        /*******************************/
        /*** Draw down the principal ***/
        /*******************************/

        vm.prank(BORROWER);
        _loan.drawdownFunds(PRINCIPAL, BORROWER);

        assertEq(_loan.claimableFunds(),     0);
        assertEq(_loan.drawableFunds(),      0);
        assertEq(_loan.nextPaymentDueDate(), START + PAYMENT_INTERVAL);
        assertEq(_loan.paymentsRemaining(),  2);
        assertEq(_loan.principal(),          PRINCIPAL);

        ( lastClaim, nextClaim, pendingInterest, principalOut ) = _investmentManager.investments(address(_loan));

        assertEq(lastClaim,       START);
        assertEq(nextClaim,       START + PAYMENT_INTERVAL);
        assertEq(pendingInterest, INTEREST);
        assertEq(principalOut,    PRINCIPAL);

        assertEq(_pool.freeAssets(),          DEPOSIT);
        assertEq(_pool.interestOut(),         INTEREST);
        assertEq(_pool.issuanceRate(),        ISSUANCE_RATE);
        assertEq(_pool.lastUpdated(),         START);
        assertEq(_pool.principalOut(),        PRINCIPAL);
        assertEq(_pool.totalAssets(),         DEPOSIT);
        assertEq(_pool.vestingPeriodFinish(), START + PAYMENT_INTERVAL);

        assertEq(USDC.balanceOf(BORROWER),      PRINCIPAL);
        assertEq(USDC.balanceOf(POOL_DELEGATE), 0);

        assertEq(USDC.balanceOf(address(_loan)),              0);
        assertEq(USDC.balanceOf(address(_investmentManager)), 0);
        assertEq(USDC.balanceOf(address(_pool)),              DEPOSIT - PRINCIPAL);

        vm.warp(START + PAYMENT_INTERVAL);

        // Simulate the loan being utilized by the borrower to get 10% returns.
        USDC.mint(BORROWER, PRINCIPAL / 10);

        ( uint256 principal, uint256 interest ) = _loan.getNextPaymentBreakdown();

        assertEq(principal, 0);
        assertEq(interest,  INTEREST);

        /**********************/
        /*** Make a payment ***/
        /**********************/

        vm.startPrank(BORROWER);
        USDC.approve(address(_loan), interest);
        _loan.makePayment(interest);
        vm.stopPrank();

        assertEq(_loan.claimableFunds(),     INTEREST);
        assertEq(_loan.drawableFunds(),      0);
        assertEq(_loan.nextPaymentDueDate(), START + 2 * PAYMENT_INTERVAL);
        assertEq(_loan.paymentsRemaining(),  1);
        assertEq(_loan.principal(),          PRINCIPAL);

        ( lastClaim, nextClaim, pendingInterest, principalOut ) = _investmentManager.investments(address(_loan));

        assertEq(lastClaim,       START);
        assertEq(nextClaim,       START + PAYMENT_INTERVAL);
        assertEq(pendingInterest, INTEREST);
        assertEq(principalOut,    PRINCIPAL);

        assertEq(_pool.freeAssets(),          DEPOSIT);
        assertEq(_pool.interestOut(),         INTEREST);
        assertEq(_pool.issuanceRate(),        ISSUANCE_RATE);
        assertEq(_pool.lastUpdated(),         START);
        assertEq(_pool.principalOut(),        PRINCIPAL);
        assertEq(_pool.totalAssets(),         DEPOSIT + INTEREST);
        assertEq(_pool.vestingPeriodFinish(), START + PAYMENT_INTERVAL);

        assertEq(USDC.balanceOf(BORROWER),      PRINCIPAL + PRINCIPAL / 10 - INTEREST);
        assertEq(USDC.balanceOf(POOL_DELEGATE), 0);

        assertEq(USDC.balanceOf(address(_loan)),              INTEREST);
        assertEq(USDC.balanceOf(address(_investmentManager)), 0);
        assertEq(USDC.balanceOf(address(_pool)),              DEPOSIT - PRINCIPAL);

        ( principal, interest ) = _loan.getNextPaymentBreakdown();

        assertEq(principal, PRINCIPAL);
        assertEq(interest,  INTEREST);

        /***********************************/
        /*** Claim interest for the pool ***/
        /***********************************/

        vm.prank(POOL_DELEGATE);
        _pool.claim(address(_loan));

        assertEq(_loan.claimableFunds(),     0);
        assertEq(_loan.drawableFunds(),      0);
        assertEq(_loan.nextPaymentDueDate(), START + 2 * PAYMENT_INTERVAL);
        assertEq(_loan.paymentsRemaining(),  1);
        assertEq(_loan.principal(),          PRINCIPAL);

        ( lastClaim, nextClaim, pendingInterest, principalOut ) = _investmentManager.investments(address(_loan));

        assertEq(lastClaim,       START + PAYMENT_INTERVAL);
        assertEq(nextClaim,       START + 2 * PAYMENT_INTERVAL);
        assertEq(pendingInterest, INTEREST);
        assertEq(principalOut,    PRINCIPAL);

        assertEq(_pool.freeAssets(),          DEPOSIT + INTEREST);
        assertEq(_pool.interestOut(),         INTEREST);
        assertEq(_pool.issuanceRate(),        ISSUANCE_RATE);
        assertEq(_pool.lastUpdated(),         START + PAYMENT_INTERVAL);
        assertEq(_pool.principalOut(),        PRINCIPAL);
        assertEq(_pool.totalAssets(),         DEPOSIT + INTEREST);  // Should this be 2x interest?
        assertEq(_pool.vestingPeriodFinish(), START + 2 * PAYMENT_INTERVAL);

        assertEq(USDC.balanceOf(BORROWER),      PRINCIPAL + PRINCIPAL / 10 - INTEREST);
        assertEq(USDC.balanceOf(POOL_DELEGATE), 0);

        assertEq(USDC.balanceOf(address(_loan)),              0);
        assertEq(USDC.balanceOf(address(_investmentManager)), 0);
        assertEq(USDC.balanceOf(address(_pool)),              DEPOSIT - PRINCIPAL + INTEREST);
    }

}
