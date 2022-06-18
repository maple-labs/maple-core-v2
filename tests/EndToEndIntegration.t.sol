// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { console }   from "../modules/contract-test-utils/contracts/log.sol";
import { TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

import { MockERC20 }                          from "../modules/erc20/contracts/test/mocks/MockERC20.sol";
import { ConstructableMapleLoan as MockLoan } from "../modules/loan/contracts/test/harnesses/MapleLoanHarnesses.sol";
import { MockFactory }                        from "../modules/loan/contracts/test/mocks/Mocks.sol";
import { MockAuctioneer }                     from "../modules/pool-cover/tests/mocks/MockAuctioneer.sol";
import { MockConverter }                      from "../modules/pool-cover/tests/mocks/MockConverter.sol";

import { PB_ST_01 as InvestmentManager }       from "../modules/poolV2/contracts/PB_ST_01.sol";
import { PoolV2 as Pool }                      from "../modules/poolV2/contracts/PoolV2.sol";
import { PoolCover }                           from "../modules/pool-cover/contracts/PoolCover.sol";
import { IPoolCoverManager, PoolCoverManager } from "../modules/pool-cover/contracts/PoolCoverManager.sol";
import { WithdrawalManager }                   from "../modules/withdrawal-manager/contracts/WithdrawalManager.sol";

contract EndToEndIntegrationTest is TestUtils {

    /*****************/
    /*** End Users ***/
    /*****************/

    address constant BORROWER      = address(1);
    address constant POOL_DELEGATE = address(2);
    address constant OTHER_LPs     = address(3);
    address constant OTHER_CPs     = address(4);

    address constant LIQUIDITY_PROVIDER  = address(5);
    address constant USDC_COVER_PROVIDER = address(6);
    address constant WBTC_COVER_PROVIDER = address(7);
    address constant WETH_COVER_PROVIDER = address(8);
    address constant XMPL_COVER_PROVIDER = address(9);

    /**********************************/
    /*** Liquidity and Cover Assets ***/
    /**********************************/

    MockERC20 _usdc = new MockERC20("USD Coin",      "USDC", 6);
    MockERC20 _wbtc = new MockERC20("Wrapped BTC",   "WBTC", 8);
    MockERC20 _weth = new MockERC20("Wrapped Ether", "WETH", 18);
    MockERC20 _xmpl = new MockERC20("xMPL",          "xMPL", 18);

    /********************/
    /*** Lending Pool ***/
    /********************/

    uint256 constant INITIAL_LIQUIDITY = 10_000_000e6;

    Pool _pool = new Pool({
        name_:      "Lending Pool - USD Coin",
        symbol_:    "MPL-LP-USDC",
        owner_:     address(POOL_DELEGATE),
        asset_:     address(_usdc),
        precision_: 1e30
    });

    /**************************/
    /*** Pool Cover Manager ***/
    /**************************/

    uint256 constant USDC_WEIGHT = 15_00;  // 15.00% -> USDC
    uint256 constant WBTC_WEIGHT = 20_00;  // 20.00% -> WBTC
    uint256 constant WETH_WEIGHT = 60_00;  // 60.00% -> WETH
    uint256 constant XMPL_WEIGHT =  5_00;  // 5.00%  -> XMPL

    uint256 constant VESTING_PERIOD = 30 days;

    PoolCoverManager _poolCoverManager = new PoolCoverManager(address(_usdc), POOL_DELEGATE, VESTING_PERIOD);

    /**************************/
    /*** Investment Manager ***/
    /**************************/

    InvestmentManager _investmentManager = new InvestmentManager(address(_pool), address(_poolCoverManager));

    /**************************/
    /*** Withdrawal Manager ***/
    /**************************/

    uint256 constant START = 1641164400;  // 1st Monday of 2022

    uint256 constant WITHDRAWAL_COOLDOWN  = 2 weeks;
    uint256 constant WITHDRAWAL_DURATION  = 2 days;
    uint256 constant WITHDRAWAL_FREQUENCY = 1 weeks;

    WithdrawalManager _withdrawalManager = new WithdrawalManager({
        asset_:              address(_usdc),
        pool_:               address(_pool),
        periodStart_:        START,
        periodDuration_:     WITHDRAWAL_DURATION,
        periodFrequency_:    WITHDRAWAL_FREQUENCY,
        cooldownMultiplier_: WITHDRAWAL_COOLDOWN / WITHDRAWAL_FREQUENCY
    });

    /******************/
    /*** Pool Cover ***/
    /******************/

    uint256 constant LOCKUP_DURATION = 2 weeks;
    uint256 constant REDEEM_WINDOW   = 2 days;

    uint256 constant INITIAL_USDC_COVER = 1_500_000e6;
    uint256 constant INITIAL_WBTC_COVER = 4e8;
    uint256 constant INITIAL_WETH_COVER = 60e18;
    uint256 constant INITIAL_XMPL_COVER = 2_500e18;

    PoolCover _usdcPoolCover = new PoolCover({
        name_:           "Pool Cover - USD Coin",
        symbol_:         "MPL-CP-USDC",
        owner_:          address(_poolCoverManager),
        asset_:          address(_usdc),
        lockupDuration_: LOCKUP_DURATION,
        redeemWindow_:   REDEEM_WINDOW,
        precision_:      1e30
    });

    PoolCover _wbtcPoolCover = new PoolCover({
        name_:           "Pool Cover - Wrapped BTC",
        symbol_:         "MPL-CP-WBTC",
        owner_:          address(_poolCoverManager),
        asset_:          address(_wbtc),
        lockupDuration_: LOCKUP_DURATION,
        redeemWindow_:   REDEEM_WINDOW,
        precision_:      1e30
    });

    PoolCover _wethPoolCover = new PoolCover({
        name_:           "Pool Cover - Wrapped Ether",
        symbol_:         "MPL-CP-WETH",
        owner_:          address(_poolCoverManager),
        asset_:          address(_weth),
        lockupDuration_: LOCKUP_DURATION,
        redeemWindow_:   REDEEM_WINDOW,
        precision_:      1e30
    });

    PoolCover _xmplPoolCover = new PoolCover({
        name_:           "Pool Cover - xMPL",
        symbol_:         "MPL-CP-xMPL",
        owner_:          address(_poolCoverManager),
        asset_:          address(_xmpl),
        lockupDuration_: LOCKUP_DURATION,
        redeemWindow_:   REDEEM_WINDOW,
        precision_:      1e30
    });

    /*******************************/
    /*** Fixed-Price Auctioneers ***/
    /*******************************/

    MockAuctioneer _wbtcAuctioneer = new MockAuctioneer(1e8,  30_107.22e6);  // 1 WBTC = 30,107.22 USDC
    MockAuctioneer _wethAuctioneer = new MockAuctioneer(1e18, 1_761.14e6);   // 1 WETH = 1,761.14 USDC
    MockAuctioneer _xmplAuctioneer = new MockAuctioneer(1e18, 28.77e6);      // 1 xMPL = 28.77 USDC

    /******************************/
    /*** Third Party Converters ***/
    /******************************/

    MockConverter _wbtcConverter = new MockConverter(address(_usdc), address(_wbtc), address(_wbtcAuctioneer));
    MockConverter _wethConverter = new MockConverter(address(_usdc), address(_weth), address(_wethAuctioneer));
    MockConverter _xmplConverter = new MockConverter(address(_usdc), address(_xmpl), address(_xmplAuctioneer));

    function setUp() public {
        _updateSettings();
        _injectDependencies();
        _depositLiquidity(OTHER_LPs, INITIAL_LIQUIDITY);
        _depositCover(OTHER_CPs, _usdcPoolCover, INITIAL_USDC_COVER);
        _depositCover(OTHER_CPs, _wbtcPoolCover, INITIAL_WBTC_COVER);
        _depositCover(OTHER_CPs, _wethPoolCover, INITIAL_WETH_COVER);
        _depositCover(OTHER_CPs, _xmplPoolCover, INITIAL_XMPL_COVER);
    }

    function test_endToEndIntegration() external {

        /****************/
        /*** Timeline ***/
        /****************/

        // A cover provider joins the USDC pool cover before any loans are funded.
        // He will be fully exposed to interest from all loans funded here on after.
        vm.warp(START);
        uint256 usdcCoverShares = _depositCover(USDC_COVER_PROVIDER, _usdcPoolCover, 1_000_000e6);

        // The first loan is funded.
        vm.warp(START + 1.85 days);
        MockLoan firstLoan = _fundAndDrawdownLoan(1_000_000e6, 0.08e18);

        // A liquidity provider joins the pool half a day after the first loan was funded.
        // He will miss out on 0.5 days of interest from the first loan.
        vm.warp(START + 2.35 days);
        uint256 poolShares = _depositLiquidity(LIQUIDITY_PROVIDER, 1_500_000e6);

        vm.warp(START + 30.85 days);
        _payClaimAndConvert(firstLoan);

        // A cover provider joins the xMPL pool cover 9 days after the vesting schedule started for the first time.
        // He will miss out on 9 days of interest from the first loan.
        vm.warp(START + 39.85 days);
        uint256 xmplCoverShares = _depositCover(XMPL_COVER_PROVIDER, _xmplPoolCover, 675e18);

        // The second loan is funded.
        vm.warp(START + 40 days);
        MockLoan secondLoan = _fundAndDrawdownLoan(1_500_000e6, 0.075e18);

        vm.warp(START + 59.87 days);
        _payClaimAndConvert(firstLoan);

        // A cover provider joins the WBTC pool cover 9.12 days after the second vesting schedule update.
        // He will miss out on 29.02 days of interest from the first loan.
        // The 0.98 days of interest of the first loan will be aggregated with 30 days of interest of the second loan.
        // He will additionally miss out on 9.12 days of interest of the above mentioned aggregation.
        vm.warp(START + 68.99 days);
        uint256 wbtcCoverShares = _depositCover(WBTC_COVER_PROVIDER, _wbtcPoolCover, 1e8);

        vm.warp(START + 69 days);
        _payClaimAndConvert(secondLoan);

        vm.warp(START + 91.55 days);
        _payClaimAndConvert(firstLoan);

        vm.warp(START + 99.99 days);
        _payClaimAndConvert(secondLoan);

        // The third loan is funded.
        vm.warp(START + 100 days);
        MockLoan thirdLoan = _fundAndDrawdownLoan(2_500_000e6, 0.06e18);

        vm.warp(START + 120.05 days);
        _payClaimAndConvert(firstLoan);

        vm.warp(START + 126.23 days);
        _payClaimAndConvert(secondLoan);

        vm.warp(START + 129 days);
        _payClaimAndConvert(thirdLoan);

        vm.warp(START + 150 days);
        _payClaimAndConvert(firstLoan);

        vm.warp(START + 158.11 days);
        _payClaimAndConvert(secondLoan);

        vm.warp(START + 158.5 days);
        _payClaimAndConvert(thirdLoan);

        vm.warp(START + 181.02 days);
        _payClaimAndConvert(secondLoan);

        vm.warp(START + 181.84 days);
        _payClaimAndConvert(firstLoan);

        vm.warp(START + 188.17 days);
        _payClaimAndConvert(thirdLoan);

        vm.warp(START + 217.66 days);
        _payClaimAndConvert(thirdLoan);

        vm.warp(START + 219.85 days);
        _payClaimAndConvert(secondLoan);

        vm.warp(START + 249.99 days);
        _payClaimAndConvert(thirdLoan);

        vm.warp(START + 276.42 days);
        _payClaimAndConvert(thirdLoan);

        // A cover provider joins the WETH pool cover 1 day after the last vesting schedule was updated.
        // He will be exposed to only 29 days of interest from the third loan.
        vm.warp(START + 277.42 days);
        uint256 wethCoverShares = _depositCover(WETH_COVER_PROVIDER, _wethPoolCover, 20e18);

        /*******************/
        /*** Withdrawals ***/
        /*******************/

        // Wait an extra 30 days for all pool cover vesting to finish.
        vm.warp(START + 280 days + 30 days);
        _requestLiquidityWithdrawal(LIQUIDITY_PROVIDER, poolShares);
        _requestCoverWithdrawal(USDC_COVER_PROVIDER, _usdcPoolCover, usdcCoverShares);
        _requestCoverWithdrawal(WBTC_COVER_PROVIDER, _wbtcPoolCover, wbtcCoverShares);
        _requestCoverWithdrawal(WETH_COVER_PROVIDER, _wethPoolCover, wethCoverShares);
        _requestCoverWithdrawal(XMPL_COVER_PROVIDER, _xmplPoolCover, xmplCoverShares);

        // Wait until the withdrawal period starts to withdraw liquidity.
        vm.warp(START + 280 days + 30 days + 1.75 weeks);
        _withdrawLiquidity(LIQUIDITY_PROVIDER);

        // Wait 2 weeks to allow all pool cover lockup periods to elapse.
        vm.warp(START + 280 days + 30 days + 2 weeks);
        _withdrawCover(USDC_COVER_PROVIDER, _usdcPoolCover, usdcCoverShares);
        _withdrawCover(WBTC_COVER_PROVIDER, _wbtcPoolCover, wbtcCoverShares);
        _withdrawCover(WETH_COVER_PROVIDER, _wethPoolCover, wethCoverShares);
        _withdrawCover(XMPL_COVER_PROVIDER, _xmplPoolCover, xmplCoverShares);

        /******************/
        /*** Assertions ***/
        /******************/

        // Revenue received:
        //   1st loan: 1,000,000 USDC * 8.0% * 180 / 365 =  39,452.05 USDC
        //   2nd loan: 1,500,000 USDC * 7.5% * 180 / 365 =  55,479.45 USDC
        //   3rd loan: 2,500,000 USDC * 6.0% * 180 / 365 =  73,972.60 USDC
        //                                         TOTAL = 168,904.11 USDC

        // Revenue routing:
        //   LPs: 168,904.11 USDC * 80% = 135,123.29 USDC
        //   CPs: 168,904.11 USDC * 20% =  33,780.82 USDC
        //     USDC CPs: 33,780.82 USDC * 15% =  5,067.12 USDC
        //     WBTC CPs: 33,780.82 USDC * 20% =  6,756.16 USDC ->  6,756.16 / 30,107.22 =  0.22 WBTC
        //     WETH CPs: 33,780.82 USDC * 60% = 20,268.49 USDC -> 20,268.49 /  1,761.14 = 11.51 WETH
        //     xMPL CPs: 33,780.82 USDC * 5%  =  1,689.04 USDC ->  1,689.04 /     28.77 = 58.71 xMPL

        // Revenue exposure:
        //   Pool LP: [168,904.11 - (0.5/180) * 39,452.05] * 80% = 135,035.62 USDC
        //            -> 135,035.62 / 135,123.29 = 99.94%
        //   USDC CP: 100%
        //   WBTC CP: [168,904.11 - (29.02/180) * 39,452.05 - (9.12/30) * [(0.98/180) * 39,452.05 + (30/180) * 55,479.45]] * 20% * 20% = 6,386.69 USDC
        //            -> 6,386.69 / 6,756.12 = 94.53%
        //   WETH CP: (29/180) * 73,972.60 * 20% * 60% = 1,430.14 USDC
        //            -> 1,430.14 / 20,268.49 = 7.06%
        //   xMPL CP: [168,904.11 - (9/30) * (30/180 * 39,452.05)] * 20% * 5% = 1,669.32 USDC
        //            -> 1,669.32 / 1,689.04 = 98.83%

        // Interest received: Revenue * Exposure * Equity
        //   Pool LP: 135,123.29 USDC *  99.94% * (1,500,000 / 11,500,000) = 17,613.20 USDC
        //   USDC CP:   5,067.12 USDC * 100.00% * (1,000,000 / 2,500,000 ) =  2,026.85 USDC
        //   WBTC CP:       0.22 WBTC *  94.53% * (        1 / 5         ) =      0.04 WBTC
        //   WETH CP:      11.51 WETH *   7.06% * (       20 / 80        ) =      0.20 WETH
        //   xMPL CP:      58.71 xMPL *  98.83% * (      675 / 3,175     ) =     12.34 xMPL

        assertWithinDiff(_usdc.balanceOf(LIQUIDITY_PROVIDER),  1_500_000e6 + 17_613.20e6,  0.01e6);
        assertWithinDiff(_usdc.balanceOf(USDC_COVER_PROVIDER), 1_000_000e6 +  2_026.85e6,  0.01e6);
        assertWithinDiff(_wbtc.balanceOf(WBTC_COVER_PROVIDER),         1e8 +      0.04e8,  0.01e8);
        assertWithinDiff(_weth.balanceOf(WETH_COVER_PROVIDER),       20e18 +      0.20e18, 0.01e18);
        assertWithinDiff(_xmpl.balanceOf(XMPL_COVER_PROVIDER),      675e18 +     12.34e18, 0.01e18);
    }

    /*************************/
    /*** Utility Functions ***/
    /*************************/

    function _claimLoan(MockLoan loan_) internal {
        vm.prank(BORROWER);
        _pool.claim(address(loan_));
    }

    function _convertLiquidity(address converter_, PoolCover poolCover_) internal {
        uint256 liquidity = _poolCoverManager.liquidity(address(poolCover_));

        vm.prank(converter_);
        _poolCoverManager.convertLiquidity(address(poolCover_), liquidity, type(uint256).max, "");
    }

    function _depositCover(address account_, PoolCover poolCover_, uint256 assets_) internal returns (uint256 shares_) {
        MockERC20 asset = MockERC20(poolCover_.asset());
        asset.mint(account_, assets_);

        vm.startPrank(account_);
        asset.approve(address(poolCover_), assets_);
        shares_ = poolCover_.deposit(assets_, account_);
        vm.stopPrank();
    }

    function _depositLiquidity(address account_, uint256 assets_) internal returns (uint256 shares_) {
        _usdc.mint(account_, assets_);

        vm.startPrank(account_);
        _usdc.approve(address(_pool), assets_);
        shares_ = _pool.deposit(assets_, account_);
        vm.stopPrank();
    }

    function _fundAndDrawdownLoan(uint256 principal_, uint256 interestRate_) internal returns (MockLoan loan_) {
        address[2] memory assets      = [address(0), address(_usdc)];
        uint256[3] memory termDetails = [uint256(5 days), 30 days, 6];
        uint256[3] memory amounts     = [0, principal_, principal_];
        uint256[4] memory rates       = [interestRate_, 0, 0, 0];

        loan_ = new MockLoan(address(new MockFactory()), address(BORROWER), assets, termDetails, amounts, rates);

        vm.prank(POOL_DELEGATE);
        _pool.fund(principal_, address(loan_), address(_investmentManager));

        vm.prank(BORROWER);
        loan_.drawdownFunds(principal_, BORROWER);
    }

    function _injectDependencies() internal {
        vm.startPrank(POOL_DELEGATE);
        _pool.setInvestmentManager(address(_investmentManager), true);
        _pool.setPoolCoverManager(address(_poolCoverManager));
        _pool.setWithdrawalManager(address(_withdrawalManager));
        vm.stopPrank();
    }

    function _makePayment(MockLoan loan_) internal {
        ( uint256 principal, uint256 interest ) = loan_.getNextPaymentBreakdown();
        uint256 payment = principal + interest;
        _usdc.mint(address(BORROWER), payment);

        vm.startPrank(BORROWER);
        _usdc.approve(address(loan_), payment);
        loan_.makePayment(payment);
        vm.stopPrank();
    }

    function _payClaimAndConvert(MockLoan loan_) internal {
        _makePayment(loan_);
        _claimLoan(loan_);

        _convertLiquidity(address(_wbtcConverter), _wbtcPoolCover);
        _convertLiquidity(address(_wethConverter), _wethPoolCover);
        _convertLiquidity(address(_xmplConverter), _xmplPoolCover);
    }

    function _requestCoverWithdrawal(address account_, PoolCover poolCover_, uint256 shares_) internal {
        vm.startPrank(account_);
        poolCover_.approve(poolCover_.escrow(), shares_);
        poolCover_.makeExitRequest(shares_, account_);
        vm.stopPrank();
    }

    function _requestLiquidityWithdrawal(address account_, uint256 shares_) internal {
        vm.startPrank(account_);
        _pool.approve(address(_withdrawalManager), shares_);
        shares_ = _withdrawalManager.lockShares(shares_);
        vm.stopPrank();
    }

    function _updateSettings() internal {
        IPoolCoverManager.Settings[] memory settings = new PoolCoverManager.Settings[](4);
        settings[0] = IPoolCoverManager.Settings(address(_usdcPoolCover), address(0),               USDC_WEIGHT);
        settings[1] = IPoolCoverManager.Settings(address(_wbtcPoolCover), address(_wbtcAuctioneer), WBTC_WEIGHT);
        settings[2] = IPoolCoverManager.Settings(address(_wethPoolCover), address(_wethAuctioneer), WETH_WEIGHT);
        settings[3] = IPoolCoverManager.Settings(address(_xmplPoolCover), address(_xmplAuctioneer), XMPL_WEIGHT);

        vm.prank(POOL_DELEGATE);
        _poolCoverManager.updateSettings(settings);
    }

    function _withdrawCover(address account_, PoolCover poolCover_, uint256 shares_) internal returns (uint256 assets_) {
        vm.prank(account_);
        assets_ = poolCover_.redeem(shares_, account_, account_);
    }

    function _withdrawLiquidity(address account_) internal returns (uint256 assets_) {
        vm.prank(account_);
        ( assets_, , ) = _withdrawalManager.redeemPosition(0);
    }

}
