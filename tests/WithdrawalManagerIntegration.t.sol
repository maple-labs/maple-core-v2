// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity 0.8.7;

// import { TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

// import { MockERC20 }                      from "../modules/erc20/contracts/test/mocks/MockERC20.sol";
// import { ConstructableMapleLoan as Loan } from "../modules/loan/contracts/test/harnesses/MapleLoanHarnesses.sol";
// import { MockFactory }                    from "../modules/loan/contracts/test/mocks/Mocks.sol";

// import { PB_ST_05 as InvestmentManager } from "../modules/poolV2/contracts/InvestmentManager.sol";
// import { Pool }                          from "../modules/poolV2/contracts/Pool.sol";
// import { WithdrawalManager }             from "../modules/withdrawal-manager/contracts/WithdrawalManager.sol";

// contract WithdrawalManagerIntegrationTest is TestUtils {

//     address internal constant BORROWER           = address(1);
//     address internal constant LIQUIDITY_PROVIDER = address(2);
//     address internal constant POOL_DELEGATE      = address(3);

//     uint256 internal constant COOLDOWN_MULTIPLIER  = WITHDRAWAL_COOLDOWN / WITHDRAWAL_FREQUENCY;
//     uint256 internal constant WITHDRAWAL_COOLDOWN  = 2 weeks;
//     uint256 internal constant WITHDRAWAL_DURATION  = 48 hours;
//     uint256 internal constant WITHDRAWAL_FREQUENCY = 1 weeks;
//     uint256 internal constant START                = 1641164400;  // 1st Monday of 2022

//     uint256 internal constant DEPOSIT           = 10e18;
//     uint256 internal constant INTEREST_PAYMENT  = PRINCIPAL * INTEREST_RATE * PAYMENT_INTERVAL / 365 days / 1e18;
//     uint256 internal constant INTEREST_RATE     = 0.12e18;
//     uint256 internal constant PAYMENT_INTERVAL  = 30 days;
//     uint256 internal constant PRINCIPAL         = 1e18;

//     InvestmentManager internal _investmentManager;
//     Loan              internal _loan;
//     MockERC20         internal _asset;
//     Pool              internal _pool;
//     WithdrawalManager internal _withdrawalManager;

//     function setUp() public {
//         _asset             = new MockERC20("Wrapped Ether", "WETH", 18);
//         _pool              = new Pool("MaplePool", "MP", address(POOL_DELEGATE), address(_asset), 1e30);
//         _investmentManager = new InvestmentManager(address(_pool));
//         _withdrawalManager = new WithdrawalManager({
//             asset_:              address(_asset),
//             pool_:               address(_pool),
//             periodStart_:        START,
//             periodDuration_:     WITHDRAWAL_DURATION,
//             periodFrequency_:    WITHDRAWAL_FREQUENCY,
//             cooldownMultiplier_: COOLDOWN_MULTIPLIER
//         });

//         // Inject dependencies into the pool.
//         _pool.setInvestmentManager(address(_investmentManager), true);
//         _pool.setWithdrawalManager(address(_withdrawalManager));

//         // Define and instantiate the bullet loan.
//         address[2] memory assets      = [address(0), address(_asset)];
//         uint256[3] memory termDetails = [0, PAYMENT_INTERVAL, 1];
//         uint256[3] memory amounts     = [0, PRINCIPAL, PRINCIPAL];
//         uint256[4] memory rates       = [INTEREST_RATE, 0, 0, 0];

//         _loan = new Loan(address(new MockFactory()), address(BORROWER), assets, termDetails, amounts, rates);

//         vm.warp(START);
//     }

//     function test_withdrawalManagerIntegration() external {

//         /*********************/
//         /*** Initial State ***/
//         /*********************/

//         assertEq(_pool.totalAssets(), 0);

//         assertEq(_pool.balanceOf(LIQUIDITY_PROVIDER),          0);
//         assertEq(_pool.balanceOf(address(_withdrawalManager)), 0);

//         assertEq(_asset.balanceOf(BORROWER),                    0);
//         assertEq(_asset.balanceOf(LIQUIDITY_PROVIDER),          0);
//         assertEq(_asset.balanceOf(address(_loan)),              0);
//         assertEq(_asset.balanceOf(address(_pool)),              0);
//         assertEq(_asset.balanceOf(address(_withdrawalManager)), 0);

//         /**********************/
//         /*** Deposit Assets ***/
//         /**********************/

//         vm.startPrank(LIQUIDITY_PROVIDER);
//         _asset.mint(LIQUIDITY_PROVIDER, DEPOSIT);
//         _asset.approve(address(_pool), DEPOSIT);
//         uint256 shares = _pool.deposit(DEPOSIT, LIQUIDITY_PROVIDER);
//         vm.stopPrank();

//         assertEq(_pool.totalAssets(), DEPOSIT);

//         assertEq(_pool.balanceOf(LIQUIDITY_PROVIDER),          shares);
//         assertEq(_pool.balanceOf(address(_withdrawalManager)), 0);

//         assertEq(_asset.balanceOf(BORROWER),                    0);
//         assertEq(_asset.balanceOf(LIQUIDITY_PROVIDER),          0);
//         assertEq(_asset.balanceOf(address(_loan)),              0);
//         assertEq(_asset.balanceOf(address(_pool)),              DEPOSIT);
//         assertEq(_asset.balanceOf(address(_withdrawalManager)), 0);

//         /*********************/
//         /*** Fund the Loan ***/
//         /*********************/

//         vm.prank(POOL_DELEGATE);
//         _pool.fund(PRINCIPAL, address(_loan), address(_investmentManager));

//         vm.prank(BORROWER);
//         _loan.drawdownFunds(PRINCIPAL, BORROWER);

//         assertEq(_pool.totalAssets(), DEPOSIT);

//         assertEq(_pool.balanceOf(LIQUIDITY_PROVIDER),          shares);
//         assertEq(_pool.balanceOf(address(_withdrawalManager)), 0);

//         assertEq(_asset.balanceOf(BORROWER),                    PRINCIPAL);
//         assertEq(_asset.balanceOf(LIQUIDITY_PROVIDER),          0);
//         assertEq(_asset.balanceOf(address(_loan)),              0);
//         assertEq(_asset.balanceOf(address(_pool)),              DEPOSIT - PRINCIPAL);
//         assertEq(_asset.balanceOf(address(_withdrawalManager)), 0);

//         /********************/
//         /*** Make Payment ***/
//         /********************/

//         vm.warp(START + PAYMENT_INTERVAL);

//         uint256 payment = PRINCIPAL + INTEREST_PAYMENT;

//         vm.startPrank(BORROWER);
//         _asset.mint(address(BORROWER), INTEREST_PAYMENT);
//         _asset.approve(address(_loan), payment);
//         _loan.makePayment(payment);
//         vm.stopPrank();

//         assertEq(_pool.totalAssets(), DEPOSIT + INTEREST_PAYMENT);

//         assertEq(_pool.balanceOf(LIQUIDITY_PROVIDER),          shares);
//         assertEq(_pool.balanceOf(address(_withdrawalManager)), 0);

//         assertEq(_asset.balanceOf(BORROWER),                    0);
//         assertEq(_asset.balanceOf(LIQUIDITY_PROVIDER),          0);
//         assertEq(_asset.balanceOf(address(_loan)),              PRINCIPAL + INTEREST_PAYMENT);
//         assertEq(_asset.balanceOf(address(_pool)),              DEPOSIT - PRINCIPAL);
//         assertEq(_asset.balanceOf(address(_withdrawalManager)), 0);

//         /********************/
//         /*** Claim Assets ***/
//         /********************/

//         vm.prank(BORROWER);
//         _pool.claim(address(_loan));

//         assertEq(_pool.totalAssets(), DEPOSIT + INTEREST_PAYMENT);

//         assertEq(_pool.balanceOf(LIQUIDITY_PROVIDER),          shares);
//         assertEq(_pool.balanceOf(address(_withdrawalManager)), 0);

//         assertEq(_asset.balanceOf(BORROWER),                    0);
//         assertEq(_asset.balanceOf(LIQUIDITY_PROVIDER),          0);
//         assertEq(_asset.balanceOf(address(_loan)),              0);
//         assertEq(_asset.balanceOf(address(_pool)),              DEPOSIT + INTEREST_PAYMENT);
//         assertEq(_asset.balanceOf(address(_withdrawalManager)), 0);

//         assertEq(_withdrawalManager.lockedShares(LIQUIDITY_PROVIDER),     0);
//         assertEq(_withdrawalManager.withdrawalPeriod(LIQUIDITY_PROVIDER), 0);

//         /*******************/
//         /*** Lock Shares ***/
//         /*******************/

//         vm.startPrank(LIQUIDITY_PROVIDER);
//         _pool.approve(address(_withdrawalManager), shares);
//         _withdrawalManager.lockShares(shares);
//         vm.stopPrank();

//         assertEq(_pool.totalAssets(), DEPOSIT + INTEREST_PAYMENT);

//         assertEq(_pool.balanceOf(LIQUIDITY_PROVIDER),          0);
//         assertEq(_pool.balanceOf(address(_withdrawalManager)), shares);

//         assertEq(_asset.balanceOf(BORROWER),                    0);
//         assertEq(_asset.balanceOf(LIQUIDITY_PROVIDER),          0);
//         assertEq(_asset.balanceOf(address(_loan)),              0);
//         assertEq(_asset.balanceOf(address(_pool)),              DEPOSIT + INTEREST_PAYMENT);
//         assertEq(_asset.balanceOf(address(_withdrawalManager)), 0);

//         assertEq(_withdrawalManager.lockedShares(LIQUIDITY_PROVIDER),     shares);
//         assertEq(_withdrawalManager.withdrawalPeriod(LIQUIDITY_PROVIDER), 6);

//         assertEq(_withdrawalManager.totalShares(6),        shares);
//         assertEq(_withdrawalManager.pendingWithdrawals(6), 1);
//         assertEq(_withdrawalManager.availableAssets(6),    0);
//         assertEq(_withdrawalManager.leftoverShares(6),     0);
//         assertTrue(!_withdrawalManager.isProcessed(6));

//         /*********************/
//         /*** Redeem Shares ***/
//         /*********************/

//         vm.warp(START + PAYMENT_INTERVAL + WITHDRAWAL_FREQUENCY * 7 / 4);

//         vm.prank(LIQUIDITY_PROVIDER);
//         _withdrawalManager.redeemPosition(shares);

//         assertEq(_pool.totalAssets(), 0);

//         assertEq(_pool.balanceOf(LIQUIDITY_PROVIDER),          0);
//         assertEq(_pool.balanceOf(address(_withdrawalManager)), 0);

//         assertEq(_asset.balanceOf(BORROWER),                    0);
//         assertEq(_asset.balanceOf(LIQUIDITY_PROVIDER),          DEPOSIT + INTEREST_PAYMENT);
//         assertEq(_asset.balanceOf(address(_loan)),              0);
//         assertEq(_asset.balanceOf(address(_pool)),              0);
//         assertEq(_asset.balanceOf(address(_withdrawalManager)), 0);

//         assertEq(_withdrawalManager.lockedShares(LIQUIDITY_PROVIDER),     0);
//         assertEq(_withdrawalManager.withdrawalPeriod(LIQUIDITY_PROVIDER), 0);

//         assertEq(_withdrawalManager.totalShares(6),        0);
//         assertEq(_withdrawalManager.pendingWithdrawals(6), 0);
//         assertEq(_withdrawalManager.availableAssets(6),    0);
//         assertEq(_withdrawalManager.leftoverShares(6),     0);
//         assertTrue(_withdrawalManager.isProcessed(6));
//     }

// }
