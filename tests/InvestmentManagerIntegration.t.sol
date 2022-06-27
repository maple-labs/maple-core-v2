// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity 0.8.7;

// import { TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

// import { MockERC20 }                      from "../modules/erc20/contracts/test/mocks/MockERC20.sol";
// import { ConstructableMapleLoan as Loan } from "../modules/loan/contracts/test/harnesses/MapleLoanHarnesses.sol";
// import { MockFactory }                    from "../modules/loan/contracts/test/mocks/Mocks.sol";

// import { PB_ST_05 as InvestmentManager } from "../modules/poolV2/contracts/InvestmentManager.sol";
// import { Pool }                          from "../modules/poolV2/contracts/Pool.sol";

// contract InvestmentManagerIntegrationTest is TestUtils {

//     address internal constant BORROWER           = address(1);
//     address internal constant LIQUIDITY_PROVIDER = address(2);
//     address internal constant POOL_DELEGATE      = address(3);

//     uint256 internal constant DEPOSIT          = 10_000_000e6;
//     uint256 internal constant PAYMENT_INTERVAL = 1_000_000 seconds;
//     uint256 internal constant INTEREST_RATE    = 0.1e18;
//     uint256 internal constant PRINCIPAL        = 1_000_000e6;
//     uint256 internal constant INTEREST_PAYMENT = PRINCIPAL * INTEREST_RATE * PAYMENT_INTERVAL / 365 days / 1e18;
//     uint256 internal constant ISSUANCE_RATE    = INTEREST_PAYMENT * 1e30 / PAYMENT_INTERVAL;

//     uint256 internal immutable START = block.timestamp;

//     InvestmentManager internal _investmentManager;
//     Loan              internal _loan;
//     MockERC20         internal _asset;
//     Pool              internal _pool;

//     function setUp() public {
//         _asset             = new MockERC20("USD Coin", "USDC", 6);
//         _pool              = new Pool("MaplePool", "MP", address(POOL_DELEGATE), address(_asset), 1e30);
//         _investmentManager = new InvestmentManager(address(_pool), address(0));

//         _pool.setInvestmentManager(address(_investmentManager), true);

//         // Define the terms of the loan and instantiate it.
//         address[2] memory assets      = [address(0), address(_asset)];
//         uint256[3] memory termDetails = [10 days, PAYMENT_INTERVAL, 2];
//         uint256[3] memory amounts     = [0, PRINCIPAL, PRINCIPAL];
//         uint256[4] memory rates       = [INTEREST_RATE, 0, 0, 0];

//         _loan = new Loan(address(new MockFactory()), address(BORROWER), assets, termDetails, amounts, rates);

//         vm.warp(START);
//     }

//     function test_investmentManagerIntegration() external {

//         /*********************/
//         /*** Initial State ***/
//         /*********************/

//         // TODO: Replace pool assertions with investment manager assertions once design is finalized.

//         assertEq(_pool.freeAssets(),          0);
//         assertEq(_pool.issuanceRate(),        0);
//         assertEq(_pool.lastUpdated(),         0);
//         assertEq(_pool.totalAssets(),         0);
//         assertEq(_pool.vestingPeriodFinish(), 0);

//         assertEq(_pool.balanceOf(LIQUIDITY_PROVIDER), 0);

//         assertEq(_asset.balanceOf(BORROWER),           0);
//         assertEq(_asset.balanceOf(LIQUIDITY_PROVIDER), 0);
//         assertEq(_asset.balanceOf(address(_loan)),     0);
//         assertEq(_asset.balanceOf(address(_pool)),     0);

//         /**********************/
//         /*** Deposit Assets ***/
//         /**********************/

//         vm.startPrank(LIQUIDITY_PROVIDER);
//         _asset.mint(LIQUIDITY_PROVIDER, DEPOSIT);
//         _asset.approve(address(_pool), DEPOSIT);
//         uint256 shares = _pool.deposit(DEPOSIT, LIQUIDITY_PROVIDER);
//         vm.stopPrank();

//         assertEq(_pool.freeAssets(),          DEPOSIT);
//         assertEq(_pool.issuanceRate(),        0);
//         assertEq(_pool.lastUpdated(),         START);
//         assertEq(_pool.totalAssets(),         DEPOSIT);
//         assertEq(_pool.vestingPeriodFinish(), 0);

//         assertEq(_pool.balanceOf(LIQUIDITY_PROVIDER), shares);

//         assertEq(_asset.balanceOf(BORROWER),           0);
//         assertEq(_asset.balanceOf(LIQUIDITY_PROVIDER), 0);
//         assertEq(_asset.balanceOf(address(_loan)),     0);
//         assertEq(_asset.balanceOf(address(_pool)),     DEPOSIT);

//         /*********************/
//         /*** Fund the Loan ***/
//         /*********************/

//         vm.prank(POOL_DELEGATE);
//         _pool.fund(PRINCIPAL, address(_loan), address(_investmentManager));

//         vm.prank(BORROWER);
//         _loan.drawdownFunds(PRINCIPAL, BORROWER);

//         assertEq(_pool.freeAssets(),          DEPOSIT);
//         assertEq(_pool.issuanceRate(),        ISSUANCE_RATE);
//         assertEq(_pool.lastUpdated(),         START);
//         assertEq(_pool.totalAssets(),         DEPOSIT);
//         assertEq(_pool.vestingPeriodFinish(), START + PAYMENT_INTERVAL);

//         assertEq(_pool.balanceOf(LIQUIDITY_PROVIDER), shares);

//         assertEq(_asset.balanceOf(BORROWER),           PRINCIPAL);
//         assertEq(_asset.balanceOf(LIQUIDITY_PROVIDER), 0);
//         assertEq(_asset.balanceOf(address(_loan)),     0);
//         assertEq(_asset.balanceOf(address(_pool)),     DEPOSIT - PRINCIPAL);

//         /********************/
//         /*** Make Payment ***/
//         /********************/

//         vm.warp(START + PAYMENT_INTERVAL);

//         vm.startPrank(BORROWER);
//         _asset.mint(address(BORROWER), INTEREST_PAYMENT);
//         _asset.approve(address(_loan), INTEREST_PAYMENT);
//         _loan.makePayment(INTEREST_PAYMENT);
//         vm.stopPrank();

//         assertEq(_pool.freeAssets(),          DEPOSIT);
//         assertEq(_pool.issuanceRate(),        ISSUANCE_RATE);
//         assertEq(_pool.lastUpdated(),         START);
//         assertEq(_pool.totalAssets(),         DEPOSIT + INTEREST_PAYMENT);
//         assertEq(_pool.vestingPeriodFinish(), START + PAYMENT_INTERVAL);

//         assertEq(_pool.balanceOf(LIQUIDITY_PROVIDER), shares);

//         assertEq(_asset.balanceOf(BORROWER),           PRINCIPAL);
//         assertEq(_asset.balanceOf(LIQUIDITY_PROVIDER), 0);
//         assertEq(_asset.balanceOf(address(_loan)),     INTEREST_PAYMENT);
//         assertEq(_asset.balanceOf(address(_pool)),     DEPOSIT - PRINCIPAL);

//         /********************/
//         /*** Claim Assets ***/
//         /********************/

//         vm.prank(BORROWER);
//         _pool.claim(address(_loan));

//         assertEq(_pool.freeAssets(),          DEPOSIT + INTEREST_PAYMENT);
//         assertEq(_pool.issuanceRate(),        ISSUANCE_RATE);
//         assertEq(_pool.lastUpdated(),         START + PAYMENT_INTERVAL);
//         assertEq(_pool.totalAssets(),         DEPOSIT + INTEREST_PAYMENT);
//         assertEq(_pool.vestingPeriodFinish(), START + 2 * PAYMENT_INTERVAL);

//         assertEq(_pool.balanceOf(LIQUIDITY_PROVIDER), shares);

//         assertEq(_asset.balanceOf(BORROWER),           PRINCIPAL);
//         assertEq(_asset.balanceOf(LIQUIDITY_PROVIDER), 0);
//         assertEq(_asset.balanceOf(address(_loan)),     0);
//         assertEq(_asset.balanceOf(address(_pool)),     DEPOSIT - PRINCIPAL + INTEREST_PAYMENT);
//     }

// }
