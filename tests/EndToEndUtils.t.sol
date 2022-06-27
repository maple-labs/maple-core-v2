// // SPDX-License-Identifier: AGPL-3.0-only
// pragma solidity 0.8.7;

// import { TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

// import { MockERC20 }                          from "../modules/erc20/contracts/test/mocks/MockERC20.sol";
// import { ConstructableMapleLoan as MockLoan } from "../modules/loan/contracts/test/harnesses/MapleLoanHarnesses.sol";
// import { MockFactory }                        from "../modules/loan/contracts/test/mocks/Mocks.sol";
// import { MockAuctioneer }                     from "../modules/pool-cover/tests/mocks/MockAuctioneer.sol";
// import { MockConverter }                      from "../modules/pool-cover/tests/mocks/MockConverter.sol";
// import { MockLiquidationStrategy}             from "../modules/poolV2/tests/mocks/Mocks.sol";

// import { PB_ST_05 as InvestmentManager }       from "../modules/poolV2/contracts/InvestmentManager.sol";
// import { Pool }                                from "../modules/poolV2/contracts/Pool.sol";
// import { PoolCover }                           from "../modules/pool-cover/contracts/PoolCover.sol";
// import { IPoolCoverManager, PoolCoverManager } from "../modules/pool-cover/contracts/PoolCoverManager.sol";
// import { WithdrawalManager }                   from "../modules/withdrawal-manager/contracts/WithdrawalManager.sol";

// contract EndToEndUtils is TestUtils {

//     /*****************/
//     /*** End Users ***/
//     /*****************/

//     address constant BORROWER        = address(69);
//     address constant POOL_DELEGATE   = address(420);
//     address constant OTHER_PROVIDERS = address(1337);

//     address constant LIQUIDITY_PROVIDER  = address(1);
//     address constant USDC_COVER_PROVIDER = address(2);
//     address constant WBTC_COVER_PROVIDER = address(3);
//     address constant WETH_COVER_PROVIDER = address(4);
//     address constant XMPL_COVER_PROVIDER = address(5);

//     /**********************************/
//     /*** Liquidity and Cover Assets ***/
//     /**********************************/

//     MockERC20 _usdc = new MockERC20("USD Coin",      "USDC", 6);
//     MockERC20 _wbtc = new MockERC20("Wrapped BTC",   "WBTC", 8);
//     MockERC20 _weth = new MockERC20("Wrapped Ether", "WETH", 18);
//     MockERC20 _xmpl = new MockERC20("xMPL",          "xMPL", 18);

//     /********************/
//     /*** Lending Pool ***/
//     /********************/

//     uint256 constant INITIAL_LIQUIDITY = 10_000_000e6;

//     Pool _pool = new Pool({
//         name_:      "Lending Pool - USD Coin",
//         symbol_:    "MPL-LP-USDC",
//         owner_:     address(POOL_DELEGATE),
//         asset_:     address(_usdc),
//         precision_: 1e30
//     });

//     /**************************/
//     /*** Pool Cover Manager ***/
//     /**************************/

//     uint256 constant USDC_WEIGHT = 15_00;  // 15.00% -> USDC
//     uint256 constant WBTC_WEIGHT = 20_00;  // 20.00% -> WBTC
//     uint256 constant WETH_WEIGHT = 60_00;  // 60.00% -> WETH
//     uint256 constant XMPL_WEIGHT =  5_00;  // 5.00%  -> XMPL

//     uint256 constant VESTING_PERIOD = 30 days;

//     PoolCoverManager _poolCoverManager = new PoolCoverManager(address(_usdc), POOL_DELEGATE, VESTING_PERIOD);

//     /**************************/
//     /*** Investment Manager ***/
//     /**************************/

//     InvestmentManager _investmentManager = new InvestmentManager(address(_pool), address(_poolCoverManager));

//     /**************************/
//     /*** Withdrawal Manager ***/
//     /**************************/

//     uint256 constant START = 1641164400;  // 1st Monday of 2022

//     uint256 constant WITHDRAWAL_COOLDOWN  = 2 weeks;
//     uint256 constant WITHDRAWAL_DURATION  = 2 days;
//     uint256 constant WITHDRAWAL_FREQUENCY = 1 weeks;

//     WithdrawalManager _withdrawalManager = new WithdrawalManager({
//         asset_:              address(_usdc),
//         pool_:               address(_pool),
//         periodStart_:        START,
//         periodDuration_:     WITHDRAWAL_DURATION,
//         periodFrequency_:    WITHDRAWAL_FREQUENCY,
//         cooldownMultiplier_: WITHDRAWAL_COOLDOWN / WITHDRAWAL_FREQUENCY
//     });

//     /******************/
//     /*** Pool Cover ***/
//     /******************/

//     uint256 constant LOCKUP_DURATION = 2 weeks;
//     uint256 constant REDEEM_WINDOW   = 2 days;

//     uint256 constant INITIAL_USDC_COVER = 1_500_000e6;
//     uint256 constant INITIAL_WBTC_COVER = 4e8;
//     uint256 constant INITIAL_WETH_COVER = 60e18;
//     uint256 constant INITIAL_XMPL_COVER = 2_500e18;

//     PoolCover _usdcPoolCover = new PoolCover({
//         name_:           "Pool Cover - USD Coin",
//         symbol_:         "MPL-CP-USDC",
//         owner_:          address(_poolCoverManager),
//         asset_:          address(_usdc),
//         lockupDuration_: LOCKUP_DURATION,
//         redeemWindow_:   REDEEM_WINDOW,
//         precision_:      1e30
//     });

//     PoolCover _wbtcPoolCover = new PoolCover({
//         name_:           "Pool Cover - Wrapped BTC",
//         symbol_:         "MPL-CP-WBTC",
//         owner_:          address(_poolCoverManager),
//         asset_:          address(_wbtc),
//         lockupDuration_: LOCKUP_DURATION,
//         redeemWindow_:   REDEEM_WINDOW,
//         precision_:      1e30
//     });

//     PoolCover _wethPoolCover = new PoolCover({
//         name_:           "Pool Cover - Wrapped Ether",
//         symbol_:         "MPL-CP-WETH",
//         owner_:          address(_poolCoverManager),
//         asset_:          address(_weth),
//         lockupDuration_: LOCKUP_DURATION,
//         redeemWindow_:   REDEEM_WINDOW,
//         precision_:      1e30
//     });

//     PoolCover _xmplPoolCover = new PoolCover({
//         name_:           "Pool Cover - xMPL",
//         symbol_:         "MPL-CP-xMPL",
//         owner_:          address(_poolCoverManager),
//         asset_:          address(_xmpl),
//         lockupDuration_: LOCKUP_DURATION,
//         redeemWindow_:   REDEEM_WINDOW,
//         precision_:      1e30
//     });

//     /*******************************/
//     /*** Fixed-Price Auctioneers ***/
//     /*******************************/

//     MockAuctioneer _wbtcAuctioneer = new MockAuctioneer(1e8,  30_107.22e6);  // 1 WBTC = 30,107.22 USDC
//     MockAuctioneer _wethAuctioneer = new MockAuctioneer(1e18, 1_761.14e6);   // 1 WETH = 1,761.14 USDC
//     MockAuctioneer _xmplAuctioneer = new MockAuctioneer(1e18, 28.77e6);      // 1 xMPL = 28.77 USDC

//     /******************************/
//     /*** Third Party Converters ***/
//     /******************************/

//     MockConverter _wbtcConverter = new MockConverter(address(_usdc), address(_wbtc), address(_wbtcAuctioneer));
//     MockConverter _wethConverter = new MockConverter(address(_usdc), address(_weth), address(_wethAuctioneer));
//     MockConverter _xmplConverter = new MockConverter(address(_usdc), address(_xmpl), address(_xmplAuctioneer));

//     function setUp() public virtual {
//         _updateSettings();
//         _injectDependencies();
//         _depositLiquidity(OTHER_PROVIDERS, INITIAL_LIQUIDITY);
//         _depositCover(OTHER_PROVIDERS, _usdcPoolCover, INITIAL_USDC_COVER);
//         _depositCover(OTHER_PROVIDERS, _wbtcPoolCover, INITIAL_WBTC_COVER);
//         _depositCover(OTHER_PROVIDERS, _wethPoolCover, INITIAL_WETH_COVER);
//         _depositCover(OTHER_PROVIDERS, _xmplPoolCover, INITIAL_XMPL_COVER);
//     }

//      /*************************/
//     /*** Utility Functions ***/
//     /*************************/

//     function _claimLoan(MockLoan loan_) internal {
//         vm.prank(BORROWER);
//         _pool.claim(address(loan_));
//     }

//     function _convertLiquidity(address converter_, PoolCover poolCover_) internal {
//         uint256 liquidity = _poolCoverManager.liquidity(address(poolCover_));

//         vm.prank(converter_);
//         _poolCoverManager.convertLiquidity(address(poolCover_), liquidity, type(uint256).max, "");
//     }

//     function _depositCover(address account_, PoolCover poolCover_, uint256 assets_) internal returns (uint256 shares_) {
//         MockERC20 asset = MockERC20(poolCover_.asset());
//         asset.mint(account_, assets_);

//         vm.startPrank(account_);
//         asset.approve(address(poolCover_), assets_);
//         shares_ = poolCover_.deposit(assets_, account_);
//         vm.stopPrank();
//     }

//     function _depositLiquidity(address account_, uint256 assets_) internal returns (uint256 shares_) {
//         _usdc.mint(account_, assets_);

//         vm.startPrank(account_);
//         _usdc.approve(address(_pool), assets_);
//         shares_ = _pool.deposit(assets_, account_);
//         vm.stopPrank();
//     }

//     function _fundAndDrawdownLoan(uint256 principal_, uint256 interestRate_) internal returns (MockLoan loan_) {
//         return _fundAndDrawdownLoan(address(_usdc), address(_wbtc), principal_, 0, interestRate_);
//     }

//     function _fundAndDrawdownLoan(address fundsAsset, address collateralAsset, uint256 principal_, uint256 collateral_, uint256 interestRate_) internal returns (MockLoan loan_) {
//         address[2] memory assets      = [collateralAsset, address(fundsAsset)];
//         uint256[3] memory termDetails = [uint256(5 days), 30 days, 6];
//         uint256[3] memory amounts     = [collateral_, principal_, principal_];
//         uint256[4] memory rates       = [interestRate_, 0, 0, 0];

//         loan_ = new MockLoan(address(new MockFactory()), address(BORROWER), assets, termDetails, amounts, rates);

//         vm.prank(POOL_DELEGATE);
//         _pool.fund(principal_, address(loan_), address(_investmentManager));

//         vm.startPrank(BORROWER);
//         MockERC20(collateralAsset).mint(address(BORROWER), collateral_);
//         MockERC20(collateralAsset).approve(address(loan_),  collateral_);

//         loan_.drawdownFunds(principal_, BORROWER);

//         vm.stopPrank();
//     }

//     function _injectDependencies() internal {
//         vm.startPrank(POOL_DELEGATE);
//         _pool.setInvestmentManager(address(_investmentManager), true);
//         _pool.setPoolCoverManager(address(_poolCoverManager));
//         _pool.setWithdrawalManager(address(_withdrawalManager));
//         vm.stopPrank();
//     }

//     function _makePayment(MockLoan loan_) internal {
//         ( uint256 principal, uint256 interest ) = loan_.getNextPaymentBreakdown();
//         uint256 payment = principal + interest;
//         _usdc.mint(address(BORROWER), payment);

//         vm.startPrank(BORROWER);
//         _usdc.approve(address(loan_), payment);
//         loan_.makePayment(payment);
//         vm.stopPrank();
//     }

//     function _payClaimAndConvert(MockLoan loan_) internal {
//         _makePayment(loan_);
//         _claimLoan(loan_);

//         _convertLiquidity(address(_wbtcConverter), _wbtcPoolCover);
//         _convertLiquidity(address(_wethConverter), _wethPoolCover);
//         _convertLiquidity(address(_xmplConverter), _xmplPoolCover);
//     }

//     function _requestCoverWithdrawal(address account_, PoolCover poolCover_, uint256 shares_) internal {
//         vm.startPrank(account_);
//         poolCover_.approve(poolCover_.escrow(), shares_);
//         poolCover_.makeExitRequest(shares_, account_);
//         vm.stopPrank();
//     }

//     function _requestLiquidityWithdrawal(address account_, uint256 shares_) internal {
//         vm.startPrank(account_);
//         _pool.approve(address(_withdrawalManager), shares_);
//         shares_ = _withdrawalManager.lockShares(shares_);
//         vm.stopPrank();
//     }

//     function _updateSettings() internal {
//         IPoolCoverManager.Settings[] memory settings = new PoolCoverManager.Settings[](4);

//         settings[0] = IPoolCoverManager.Settings({
//             poolCover:  address(_usdcPoolCover),
//             auctioneer: address(0),
//             weight:     USDC_WEIGHT
//         });

//         settings[1] = IPoolCoverManager.Settings({
//             poolCover:  address(_wbtcPoolCover),
//             auctioneer: address(_wbtcAuctioneer),
//             weight:     WBTC_WEIGHT
//         });

//         settings[2] = IPoolCoverManager.Settings({
//             poolCover:  address(_wethPoolCover),
//             auctioneer: address(_wethAuctioneer),
//             weight:     WETH_WEIGHT
//         });

//         settings[3] = IPoolCoverManager.Settings({
//             poolCover:  address(_xmplPoolCover),
//             auctioneer: address(_xmplAuctioneer),
//             weight:     XMPL_WEIGHT
//         });

//         vm.prank(POOL_DELEGATE);
//         _poolCoverManager.updateSettings(settings);
//     }

//     function _withdrawCover(address account_, PoolCover poolCover_, uint256 shares_) internal returns (uint256 assets_) {
//         vm.prank(account_);
//         assets_ = poolCover_.redeem(shares_, account_, account_);
//     }

//     function _withdrawLiquidity(address account_) internal returns (uint256 assets_) {
//         vm.prank(account_);
//         ( assets_, , ) = _withdrawalManager.redeemPosition(0);
//     }

// }
