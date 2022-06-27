// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity 0.8.7;

// import { TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

// import { MockERC20 }                      from "../modules/erc20/contracts/test/mocks/MockERC20.sol";
// import { ConstructableMapleLoan as Loan } from "../modules/loan/contracts/test/harnesses/MapleLoanHarnesses.sol";
// import { MockFactory }                    from "../modules/loan/contracts/test/mocks/Mocks.sol";
// import { MockAuctioneer }                 from "../modules/pool-cover/tests/mocks/MockAuctioneer.sol";
// import { MockPoolCover }                  from "../modules/pool-cover/tests/mocks/MockPoolCover.sol";
// import { MockConverter }                  from "../modules/pool-cover/tests/mocks/MockConverter.sol";

// import { PB_ST_05 as InvestmentManager }       from "../modules/poolV2/contracts/InvestmentManager.sol";
// import { Pool }                                from "../modules/poolV2/contracts/Pool.sol";
// import { IPoolCoverManager, PoolCoverManager } from "../modules/pool-cover/contracts/PoolCoverManager.sol";

// contract PoolCoverManagerIntegrationTest is TestUtils {

//     address internal constant BORROWER           = address(1);
//     address internal constant LIQUIDITY_PROVIDER = address(3);
//     address internal constant POOL_DELEGATE      = address(4);

//     uint256 internal constant COVER_INTEREST   = INTEREST_PAYMENT / 5;
//     uint256 internal constant DEPOSIT          = 10_000_000e6;
//     uint256 internal constant INTEREST_PAYMENT = PRINCIPAL * INTEREST_RATE * PAYMENT_INTERVAL / 365 days / 1e18;
//     uint256 internal constant INTEREST_RATE    = 1.0e18;
//     uint256 internal constant PAYMENT_INTERVAL = 365 days;
//     uint256 internal constant PRINCIPAL        = 500_000e6;

//     uint256 internal constant USDC_WEIGHT = 15_00;
//     uint256 internal constant WBTC_WEIGHT = 20_00;
//     uint256 internal constant WETH_WEIGHT = 60_00;
//     uint256 internal constant XMPL_WEIGHT =  5_00;

//     uint256 internal constant USDC_ALLOCATION = COVER_INTEREST * USDC_WEIGHT / 10_000;
//     uint256 internal constant WBTC_ALLOCATION = COVER_INTEREST * WBTC_WEIGHT / 10_000;
//     uint256 internal constant WETH_ALLOCATION = COVER_INTEREST * WETH_WEIGHT / 10_000;
//     uint256 internal constant XMPL_ALLOCATION = COVER_INTEREST * XMPL_WEIGHT / 10_000;

//     uint256 internal immutable START = block.timestamp;

//     MockERC20 internal USDC = new MockERC20("USD Coin",      "USDC", 6);
//     MockERC20 internal WBTC = new MockERC20("Wrapped BTC",   "WBTC", 8);
//     MockERC20 internal WETH = new MockERC20("Wrapped Ether", "WETH", 18);
//     MockERC20 internal XMPL = new MockERC20("xMPL",          "xMPL", 18);

//     MockPoolCover internal USDC_POOL_COVER = new MockPoolCover("Maple Pool Cover", "MPC-USDC", USDC.decimals(), address(USDC));
//     MockPoolCover internal WBTC_POOL_COVER = new MockPoolCover("Maple Pool Cover", "MPC-WBTC", WBTC.decimals(), address(WBTC));
//     MockPoolCover internal WETH_POOL_COVER = new MockPoolCover("Maple Pool Cover", "MPC-WETH", WETH.decimals(), address(WETH));
//     MockPoolCover internal XMPL_POOL_COVER = new MockPoolCover("Maple Pool Cover", "MPC-XMPL", XMPL.decimals(), address(XMPL));

//     MockAuctioneer internal WBTC_AUCTIONEER = new MockAuctioneer(1e8,  30_107.22e6);
//     MockAuctioneer internal WETH_AUCTIONEER = new MockAuctioneer(1e18, 1_761.14e6);
//     MockAuctioneer internal XMPL_AUCTIONEER = new MockAuctioneer(1e18, 28.77e6);

//     MockConverter internal WBTC_CONVERTER = new MockConverter(address(USDC), address(WBTC), address(WBTC_AUCTIONEER));
//     MockConverter internal WETH_CONVERTER = new MockConverter(address(USDC), address(WETH), address(WETH_AUCTIONEER));
//     MockConverter internal XMPL_CONVERTER = new MockConverter(address(USDC), address(XMPL), address(XMPL_AUCTIONEER));

//     InvestmentManager internal _investmentManager;
//     Loan              internal _loan;
//     Pool              internal _pool;
//     PoolCoverManager  internal _poolCoverManager;

//     function setUp() public {
//         _pool = new Pool("Maple Pool", "MP-USDC", address(POOL_DELEGATE), address(USDC), 1e30);

//         // Define and create the pool cover manager.
//         _poolCoverManager = new PoolCoverManager(address(USDC), POOL_DELEGATE, 30 days);

//         PoolCoverManager.Settings[] memory settings = new PoolCoverManager.Settings[](4);

//         settings[0] = IPoolCoverManager.Settings({
//             poolCover:  address(USDC_POOL_COVER),
//             auctioneer: address(0),
//             weight:     USDC_WEIGHT
//         });

//         settings[1] = IPoolCoverManager.Settings({
//             poolCover:  address(WBTC_POOL_COVER),
//             auctioneer: address(WBTC_AUCTIONEER),
//             weight:     WBTC_WEIGHT
//         });

//         settings[2] = IPoolCoverManager.Settings({
//             poolCover:  address(WETH_POOL_COVER),
//             auctioneer: address(WETH_AUCTIONEER),
//             weight:     WETH_WEIGHT
//         });

//         settings[3] = IPoolCoverManager.Settings({
//             poolCover:  address(XMPL_POOL_COVER),
//             auctioneer: address(XMPL_AUCTIONEER),
//             weight:     XMPL_WEIGHT
//         });

//         vm.prank(POOL_DELEGATE);
//         _poolCoverManager.updateSettings(settings);

//         _investmentManager = new InvestmentManager(address(_pool), address(_poolCoverManager));

//         // Inject dependencies into the pool.
//         _pool.setInvestmentManager(address(_investmentManager), true);
//         _pool.setPoolCoverManager(address(_poolCoverManager));

//         // Define the terms of the loan and instantiate it.
//         address[2] memory assets      = [address(0), address(USDC)];
//         uint256[3] memory termDetails = [10 days, PAYMENT_INTERVAL, 3];
//         uint256[3] memory amounts     = [0, PRINCIPAL, PRINCIPAL];
//         uint256[4] memory rates       = [INTEREST_RATE, 0, 0, 0];

//         _loan = new Loan(address(new MockFactory()), address(BORROWER), assets, termDetails, amounts, rates);

//         vm.warp(START);
//     }

//     function test_poolCoverManagerIntegration() external {

//         /**********************/
//         /*** Deposit Assets ***/
//         /**********************/

//         vm.startPrank(LIQUIDITY_PROVIDER);
//         USDC.mint(LIQUIDITY_PROVIDER, DEPOSIT);
//         USDC.approve(address(_pool), DEPOSIT);
//         _pool.deposit(DEPOSIT, LIQUIDITY_PROVIDER);
//         vm.stopPrank();

//         /*********************/
//         /*** Fund the Loan ***/
//         /*********************/

//         vm.prank(POOL_DELEGATE);
//         _pool.fund(PRINCIPAL, address(_loan), address(_investmentManager));

//         vm.prank(BORROWER);
//         _loan.drawdownFunds(PRINCIPAL, BORROWER);

//         /********************/
//         /*** Make Payment ***/
//         /********************/

//         vm.warp(START + PAYMENT_INTERVAL);

//         vm.startPrank(BORROWER);
//         USDC.mint(address(BORROWER), INTEREST_PAYMENT);
//         USDC.approve(address(_loan), INTEREST_PAYMENT);
//         _loan.makePayment(INTEREST_PAYMENT);
//         vm.stopPrank();

//         assertEq(_poolCoverManager.liquidity(address(USDC_POOL_COVER)), 0);
//         assertEq(_poolCoverManager.liquidity(address(WBTC_POOL_COVER)), 0);
//         assertEq(_poolCoverManager.liquidity(address(WETH_POOL_COVER)), 0);
//         assertEq(_poolCoverManager.liquidity(address(XMPL_POOL_COVER)), 0);

//         assertEq(USDC.balanceOf(address(_poolCoverManager)), 0);

//         assertEq(USDC.balanceOf(address(USDC_POOL_COVER)), 0);
//         assertEq(WBTC.balanceOf(address(WBTC_POOL_COVER)), 0);
//         assertEq(WETH.balanceOf(address(WETH_POOL_COVER)), 0);
//         assertEq(XMPL.balanceOf(address(XMPL_POOL_COVER)), 0);

//         /********************/
//         /*** Claim Assets ***/
//         /********************/

//         vm.prank(BORROWER);
//         _pool.claim(address(_loan));

//         assertEq(_poolCoverManager.liquidity(address(USDC_POOL_COVER)), 0);
//         assertEq(_poolCoverManager.liquidity(address(WBTC_POOL_COVER)), WBTC_ALLOCATION);
//         assertEq(_poolCoverManager.liquidity(address(WETH_POOL_COVER)), WETH_ALLOCATION);
//         assertEq(_poolCoverManager.liquidity(address(XMPL_POOL_COVER)), XMPL_ALLOCATION);

//         assertEq(USDC.balanceOf(address(_poolCoverManager)), COVER_INTEREST - USDC_ALLOCATION);

//         assertEq(USDC.balanceOf(address(USDC_POOL_COVER)), USDC_ALLOCATION);
//         assertEq(WBTC.balanceOf(address(WBTC_POOL_COVER)), 0);
//         assertEq(WETH.balanceOf(address(WETH_POOL_COVER)), 0);
//         assertEq(XMPL.balanceOf(address(XMPL_POOL_COVER)), 0);

//         /*************************/
//         /*** Convert Liquidity ***/
//         /*************************/

//         vm.prank(address(WBTC_CONVERTER));
//         _poolCoverManager.convertLiquidity(address(WBTC_POOL_COVER), WBTC_ALLOCATION, type(uint256).max, "");
//         vm.prank(address(WETH_CONVERTER));
//         _poolCoverManager.convertLiquidity(address(WETH_POOL_COVER), WETH_ALLOCATION, type(uint256).max, "");
//         vm.prank(address(XMPL_CONVERTER));
//         _poolCoverManager.convertLiquidity(address(XMPL_POOL_COVER), XMPL_ALLOCATION, type(uint256).max, "");

//         assertEq(_poolCoverManager.liquidity(address(USDC_POOL_COVER)), 0);
//         assertEq(_poolCoverManager.liquidity(address(WBTC_POOL_COVER)), 0);
//         assertEq(_poolCoverManager.liquidity(address(WETH_POOL_COVER)), 0);
//         assertEq(_poolCoverManager.liquidity(address(XMPL_POOL_COVER)), 0);

//         assertEq(USDC.balanceOf(address(_poolCoverManager)), 0);

//         assertEq(USDC.balanceOf(address(USDC_POOL_COVER)), USDC_ALLOCATION);
//         assertEq(WBTC.balanceOf(address(WBTC_POOL_COVER)), WBTC_AUCTIONEER.getExpectedAmount(WBTC_ALLOCATION));
//         assertEq(WETH.balanceOf(address(WETH_POOL_COVER)), WETH_AUCTIONEER.getExpectedAmount(WETH_ALLOCATION));
//         assertEq(XMPL.balanceOf(address(XMPL_POOL_COVER)), XMPL_AUCTIONEER.getExpectedAmount(XMPL_ALLOCATION));
//     }

// }
