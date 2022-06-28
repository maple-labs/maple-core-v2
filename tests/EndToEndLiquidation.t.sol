// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { console }   from "../modules/contract-test-utils/contracts/log.sol";
import { TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

import { MockERC20 }                               from "../modules/erc20/contracts/test/mocks/MockERC20.sol";
import { ConstructablePoolManager as PoolManager } from "../modules/poolV2/tests/mocks/Mocks.sol";

import { ConstructableMapleLoan as MockLoan } from "../modules/loan/contracts/test/harnesses/MapleLoanHarnesses.sol";
import { MockFactory }                        from "../modules/loan/contracts/test/mocks/Mocks.sol";

import { PB_ST_05 as InvestmentManager } from "../modules/poolV2/contracts/InvestmentManager.sol";
import { DefaultHandler }                from "../modules/poolV2/contracts/DefaultHandler.sol";
import { Pool }                          from "../modules/poolV2/contracts/Pool.sol";
import { IPoolManager }                  from "../modules/poolV2/contracts/PoolManager.sol";
import { MockLiquidationStrategy }       from "../modules/poolV2/tests/mocks/Mocks.sol";

import { ConstructablePoolCoverManager as PoolCoverManager } from "../modules/pool-cover/tests/mocks/Mocks.sol";
import { IPoolCover, PoolCover }                             from "../modules/pool-cover/contracts/PoolCover.sol";
import { IPoolCoverManager }                                 from "../modules/pool-cover/contracts/PoolCoverManager.sol";
import { MockAuctioneer }                                    from "../modules/pool-cover/tests/mocks/MockAuctioneer.sol";
import { MockConverter }                                     from "../modules/pool-cover/tests/mocks/MockConverter.sol";
import { MockOracle }                                        from "../modules/pool-cover/tests/mocks/MockOracle.sol";
import { EscrowFactoryBootstrapper }                         from "../modules/pool-cover/tests/testBase/EscrowFactoryBootstrapper.sol";

import { WithdrawalManager } from "../modules/withdrawal-manager/contracts/WithdrawalManager.sol";

import { Harness } from "./harness/Harness.sol";

import { MockEOA } from "./mocks/MockEOA.sol";

contract EndToEndLiquidationTest is Harness, EscrowFactoryBootstrapper {

    /*****************/
    /*** End Users ***/
    /*****************/

    address   poolDelegate;
    address[] borrowers;
    address[] coverProviders;
    address[] liquidityProviders;

    /**********************************/
    /*** Liquidity and Cover Assets ***/
    /**********************************/

    address   liquidityAsset;
    address[] coverAssets;

    /********************/
    /*** Lending Pool ***/
    /********************/

    uint256 initialLiquidity;
    address poolManager;
    address pool;

    /**************************/
    /*** Pool Cover Manager ***/
    /**************************/

    uint16[]  weights;
    uint256   vestingPeriod;
    address   poolCoverManager;

    /**************************/
    /*** Investment Manager ***/
    /**************************/

    address investmentManager;

    /**************************/
    /*** Withdrawal Manager ***/
    /**************************/

    uint256 startTime;

    uint256 withdrawalCooldown;
    uint256 withdrawalDuration;
    uint256 withdrawalFrequency;

    address withdrawalManager;

    /******************/
    /*** Pool Cover ***/
    /******************/

    uint256   lockupDuration;
    uint256   redeemWindow;
    uint256[] initialCoverAmounts;
    address[] poolCovers;

    /*******************************/
    /*** Fixed-Price Auctioneers ***/
    /*******************************/

    address[] converterAuctioneers;
    address[] liquidatorAuctioneers;

    /******************************/
    /*** Third Party Converters ***/
    /******************************/

    address[] converters;
    address[] liquidators;

    /***************************/
    /*** Liquidation Oracles ***/
    /***************************/

    address[] oracles;

    // function setUp() external {}

    function test_endToEndIntegration_liquidation() external {
        _configureTest();

        _updatePCMSettings({
            poolCoverManager_:     poolCoverManager,
            poolDelegate_:         poolDelegate,
            poolCovers_:           poolCovers,
            converterAuctioneers_: converterAuctioneers,
            weights_:              weights
        });

        _updatePCMLiquidationSettings({
            poolCoverManager_:       poolCoverManager,
            poolDelegate_:           poolDelegate,
            poolManager_:            poolManager,
            poolCovers_:             poolCovers,
            liquidationAuctioneers_: liquidatorAuctioneers,
            oracles_:                oracles
       });

        _setManagersOnPoolManager({
            poolManager_:       poolManager,
            poolDelegate_:      poolDelegate,
            investmentManager_: investmentManager,
            poolCoverManager_:  poolCoverManager,
            withdrawalManager_: withdrawalManager
        });

        address lp1 = liquidityProviders[1];  // Initial liquidity provider before test begins.
        _depositLiquidity({
            pool_:        pool,
            account_:     lp1, 
            assetAmount_: initialLiquidity
        });

        address cp4 = coverProviders[4];  // Initial Cover provider before test begins.
        for (uint256 i = 0; i < poolCovers.length; i++) {
            _depositCover({
                poolCover_:   poolCovers[i],
                account_:     cp4,
                assetAmount_: initialCoverAmounts[i]
            });
        }

        /****************/
        /*** Timeline ***/
        /****************/

        // A cover provider joins the USDC pool cover before any loans are funded.
        // He will be fully exposed to interest from all loans funded here on after.
        vm.warp(startTime);
        uint256 usdcCoverShares = _depositCover({
            poolCover_:   poolCovers[0],
            account_:     coverProviders[0],
            assetAmount_: 1_000e6  // Worth 1_000 USD
        });

        // The first loan is funded.
        vm.warp(startTime);
        address firstLoan = _fundAndDrawdownLoan({
            poolManager_:       poolManager,
            poolDelegate_:      poolDelegate,
            borrower_:          borrowers[0],
            investmentManager_: investmentManager,
            collateralAsset_:   coverAssets[1],     // WBTC
            collateralAmount_:  0.1e8,              // 0.1 WBTC, worth 1000 USD
            liquidityAsset_:    liquidityAsset,     // USDC
            principalAmount_:   1_000_000e6,        // 1_000_000 USDC
            interestRate_:      0.10e18             // 10% interest rate
        });

        // A liquidity provider joins the pool half a day after the first loan was funded.
        // He will miss out on 0.5 days of interest from the first loan.
        vm.warp(startTime + 0.5 days);
        address lp0 = liquidityProviders[0];
        uint256 poolShares = _depositLiquidity({
            pool_:        pool,
            account_:     lp0, 
            assetAmount_: 1_000_000e6
        });

        // Loan 1, payment 1.
        vm.warp(startTime + 30 days);
        address borrower = borrowers[0];
        _payClaimAndConvert({
            loan_:             firstLoan,
            poolManager_:      poolManager,
            poolCoverManager_: poolCoverManager,
            borrower_:         borrower,
            converters_:       converters,
            poolCovers_:       poolCovers
        });

        // A cover provider joins the xMPL pool cover 9 days after the vesting schedule started for the first time.
        // He will miss out on 5 days of interest from the first loan.
        vm.warp(startTime + 35 days);
        uint256 xmplCoverShares = _depositCover({
            poolCover_:   poolCovers[3],
            account_:     coverProviders[3],
            assetAmount_: 100e18  // Worth 1_000 USD
        });

        // The second loan is funded.
        vm.warp(startTime + 40 days);
        address secondLoan = _fundAndDrawdownLoan({
            poolManager_:       poolManager,
            poolDelegate_:      poolDelegate,
            borrower_:          borrowers[0],
            investmentManager_: investmentManager,
            collateralAsset_:   coverAssets[1],     // WBTC
            collateralAmount_:  0.1e8,              // 0.1 WBTC, worth 1000 USD
            liquidityAsset_:    liquidityAsset,     // USDC
            principalAmount_:   1_000_000e6,        // 1_000_000 USDC
            interestRate_:      0.10e18             // 10% interest rate
        });

        // Loan 1, payment 2.
        vm.warp(startTime + 60 days);
        _payClaimAndConvert({
            loan_:             firstLoan,
            poolManager_:      poolManager,
            poolCoverManager_: poolCoverManager,
            borrower_:         borrower,
            converters_:       converters,
            poolCovers_:       poolCovers
        });

        // A cover provider joins the WBTC pool cover 30 days after the second vesting schedule update.
        vm.warp(startTime + 60 days);
        uint256 wbtcCoverShares = _depositCover({
            poolCover_:   poolCovers[1],
            account_:     coverProviders[1],
            assetAmount_: 0.1e8  // Worth 1_000 USD
        });

        // Loan 2, payment 1.
        vm.warp(startTime + 70 days);
        _payClaimAndConvert({
            loan_:             secondLoan,
            poolManager_:      poolManager,
            poolCoverManager_: poolCoverManager,
            borrower_:         borrower,
            converters_:       converters,
            poolCovers_:       poolCovers
        });

        // Loan 1, payment 3
        vm.warp(startTime + 90 days);
        _payClaimAndConvert({
            loan_:             firstLoan,
            poolManager_:      poolManager,
            poolCoverManager_: poolCoverManager,
            borrower_:         borrower,
            converters_:       converters,
            poolCovers_:       poolCovers
        });

        // Loan 2, payment 2.
        vm.warp(startTime + 100 days);
        _payClaimAndConvert({
            loan_:             secondLoan,
            poolManager_:      poolManager,
            poolCoverManager_: poolCoverManager,
            borrower_:         borrower,
            converters_:       converters,
            poolCovers_:       poolCovers
        });

        // The third loan is funded.
        vm.warp(startTime + 110 days);
        uint256 thirdLoanCollateral =  0.1e8;
        address thirdLoan = _fundAndDrawdownLoan({
            poolManager_:       poolManager,
            poolDelegate_:      poolDelegate,
            borrower_:          borrowers[0],
            investmentManager_: investmentManager,
            collateralAsset_:   coverAssets[1],       // WBTC
            collateralAmount_:  thirdLoanCollateral,  // 0.1 WBTC, worth 1000 USD
            liquidityAsset_:    liquidityAsset,       // USDC
            principalAmount_:   1_000_000e6,          // 1_000_000 USDC
            interestRate_:      0.10e18               // 10% interest rate
        });

        vm.warp(startTime + 125 days);
        uint256 wethCoverShares = _depositCover({
            poolCover_:   poolCovers[2],
            account_:     coverProviders[2],
            assetAmount_: 1e18  // Worth 1_000 USD
        });

        // Loan 2, payment 3.
        vm.warp(startTime + 130 days);
        _payClaimAndConvert({
            loan_:             secondLoan,
            poolManager_:      poolManager,
            poolCoverManager_: poolCoverManager,
            borrower_:         borrower,
            converters_:       converters,
            poolCovers_:       poolCovers
        });

        // Loan 3, payment 1
        vm.warp(startTime + 140 days);
        _payClaimAndConvert({
            loan_:             thirdLoan,
            poolManager_:      poolManager,
            poolCoverManager_: poolCoverManager,
            borrower_:         borrower,
            converters_:       converters,
            poolCovers_:       poolCovers
        });

        // Loan 3, payment 2
        vm.warp(startTime + 170 days);
        _payClaimAndConvert({
            loan_:             thirdLoan,
            poolManager_:      poolManager,
            poolCoverManager_: poolCoverManager,
            borrower_:         borrower,
            converters_:       converters,
            poolCovers_:       poolCovers
        });

        // Loan 3, missed payment 3, past grace period, default 
        vm.warp(startTime + 205 days + 1 seconds);

        IPoolManager(poolManager).triggerCollateralLiquidation(thirdLoan);

        // Liquidate all collateral.
        _liquidateCollateral({
            investmentManager_: investmentManager,
            loan_:              thirdLoan,
            liquidator_:        liquidators[1],
            swapAmount_:        thirdLoanCollateral,
            collateralAsset_:   coverAssets[1],
            fundsAsset_:        liquidityAsset
        });


        // Finish collateral liquidation, and due to remaining shortfall, trigger pool cover liquidation.
        uint256 remainingLossesToCover = IPoolManager(poolManager).finishCollateralLiquidation(thirdLoan);
        assertTrue(remainingLossesToCover != 0);

        _liquidatePoolCover({
            liquidator_:       liquidators[1],
            poolCoverManager_: poolCoverManager,
            poolCover_:        poolCovers[1],
            coverAssetAmount_: MockAuctioneer(converterAuctioneers[1]).getExpectedAmount(IPoolCoverManager(poolCoverManager).coverToLiquidate(poolCovers[1]))  // Kinda hacky way to get the full liquidity amount
        });

        _liquidatePoolCover({
            liquidator_:       liquidators[2],
            poolCoverManager_: poolCoverManager,
            poolCover_:        poolCovers[2],
            coverAssetAmount_: MockAuctioneer(converterAuctioneers[2]).getExpectedAmount(IPoolCoverManager(poolCoverManager).coverToLiquidate(poolCovers[2]))
        });

        _liquidatePoolCover({
            liquidator_:       liquidators[3],
            poolCoverManager_: poolCoverManager,
            poolCover_:        poolCovers[3],
            coverAssetAmount_: MockAuctioneer(converterAuctioneers[3]).getExpectedAmount(IPoolCoverManager(poolCoverManager).coverToLiquidate(poolCovers[3]))
        });

        vm.prank(poolDelegate);
        IPoolCoverManager(poolCoverManager).endLiquidation(poolCovers[1]); // dust left in WBTC due to rounding errors.

        // /*******************/
        // /*** Withdrawals ***/
        // /*******************/

        // Wait an extra 30 days for all pool cover vesting to finish.
        vm.warp(startTime + 200 days + 30 days);
        _requestLiquidityWithdrawal({
            pool_:              pool,
            withdrawalManager_: withdrawalManager,
            account_:           lp0,
            shares_:            poolShares
        });
        _requestCoverWithdrawal({
            poolCover_: poolCovers[0],
            account_:   coverProviders[0],
            shares_:    usdcCoverShares
        });
        _requestCoverWithdrawal({
            poolCover_: poolCovers[1],
            account_:   coverProviders[1],
            shares_:    wbtcCoverShares
        });
        _requestCoverWithdrawal({
            poolCover_: poolCovers[2],
            account_:   coverProviders[2],
            shares_:    wethCoverShares
        });
        _requestCoverWithdrawal({
            poolCover_: poolCovers[3],
            account_:   coverProviders[3],
            shares_:    xmplCoverShares
        });

        // Wait until the withdrawal period starts to withdraw liquidity.
        vm.warp(startTime + 200 days + 30 days + 1.75 weeks);
        _withdrawLiquidity({
            withdrawalManager_: withdrawalManager,
            account_:           lp0
        });

        // Wait 2 weeks to allow all pool cover lockup periods to elapse.
        vm.warp(startTime + 200 days + 30 days + 2 weeks);

        uint256[] memory finalAssets = new uint256[](4);

        finalAssets[0] = _withdrawCover({
            poolCover_: poolCovers[0],
            account_:   coverProviders[0],
            shares_:    usdcCoverShares
        });
        finalAssets[1] = _withdrawCover({
            poolCover_: poolCovers[1],
            account_:   coverProviders[1],
            shares_:    wbtcCoverShares
        });
        finalAssets[2] = _withdrawCover({
            poolCover_: poolCovers[2],
            account_:   coverProviders[2],
            shares_:    wethCoverShares
        });
        finalAssets[3] = _withdrawCover({
            poolCover_: poolCovers[3],
            account_:   coverProviders[3],
            shares_:    xmplCoverShares
        });

        /******************/
        /*** Assertions ***/
        /******************/

        // For now, assert withdrawn is less than deposited due to liquidation.
        assertTrue(finalAssets[0] < 1_000e6);
        assertTrue(finalAssets[1] < 0.1e8);
        assertTrue(finalAssets[2] < 1e18);
        assertTrue(finalAssets[3] < 100e18);

    }

    /*****************************/
    /*** Test Config Functions ***/
    /*****************************/

    // Configure default values for test. Should be able to add params to this to create tests with different configs more easily.
    function _configureTest() internal {

        poolDelegate = address(new MockEOA());
        borrowers    = new address[](1);
        for (uint256 i = 0; i < borrowers.length; i++) {
            borrowers[i] = address(new MockEOA());
        }

        coverProviders = new address[](5);
        for (uint256 i = 0; i < coverProviders.length; i++) {
            coverProviders[i] = address(new MockEOA());
        }

        liquidityProviders = new address[](2);
        for (uint256 i = 0; i < liquidityProviders.length; i++) {
            liquidityProviders[i] = address(new MockEOA());
        }

        uint256 numberOfCovers = 4;

        coverAssets = new address[](numberOfCovers);

        coverAssets[0] = address(new MockERC20("USD Coin",      "USDC", 6));
        coverAssets[1] = address(new MockERC20("Wrapped BTC",   "WBTC", 8));
        coverAssets[2] = address(new MockERC20("Wrapped Ether", "WETH", 18));
        coverAssets[3] = address(new MockERC20("xMPL",          "xMPL", 18));

        liquidityAsset   = coverAssets[0];
        initialLiquidity = 1_000_000e6;

        poolManager      = address(new PoolManager(poolDelegate, 1e30));
        pool             = address(new Pool({
            name_:      "Lending Pool - USD Coin",
            symbol_:    "MPL-LP-USDC",
            manager_:   poolManager,
            asset_:     liquidityAsset
        }));

        IPoolManager(poolManager).setPool(pool);

        weights = new uint16[](numberOfCovers);

        weights[0] = 15_00;  // 15.00% -> USDC
        weights[1] = 20_00;  // 20.00% -> WBTC
        weights[2] = 60_00;  // 60.00% -> WETH
        weights[3] = 5_00;  // 5.00%  -> XMPL

        vestingPeriod    = 30 days;
        poolCoverManager = address(new PoolCoverManager(liquidityAsset, poolDelegate, vestingPeriod));

        investmentManager = address(new InvestmentManager(pool));

        startTime = 1641164400;

        withdrawalCooldown  = 2 weeks;
        withdrawalDuration  = 2 days;
        withdrawalFrequency = 1 weeks;

        withdrawalManager = address(new WithdrawalManager({
            asset_:              liquidityAsset,
            pool_:               pool,
            periodStart_:        startTime,
            periodDuration_:     withdrawalDuration,
            periodFrequency_:    withdrawalFrequency,
            cooldownMultiplier_: withdrawalCooldown / withdrawalFrequency
        }));

        lockupDuration         = 2 weeks;
        redeemWindow           = 2 days;

        initialCoverAmounts = new uint256[](numberOfCovers);

        initialCoverAmounts[0] = 1_500_000e6;
        initialCoverAmounts[1] = 4e8;
        initialCoverAmounts[2] = 60e18;
        initialCoverAmounts[3] = 2_500e18;

        ( address escrowFactory, address escrowInitializer ) = _setupEscrowFactory();

        poolCovers = new address[](numberOfCovers);
        uint256 precision = 1e30;

        poolCovers[0] = address(new PoolCover({
            name_:              "Pool Cover - USD Coin",
            symbol_:            "MPL-CP-USDC",
            owner_:             poolCoverManager,
            asset_:             coverAssets[0],
            precision_:         precision,
            escrowFactory_:     escrowFactory,
            escrowInitializer_: escrowInitializer,
            lockupDuration_:    lockupDuration,
            redeemWindow_:      redeemWindow
        }));

        poolCovers[1] = address(new PoolCover({
            name_:              "Pool Cover - Wrapped BTC",
            symbol_:            "MPL-CP-WBTC",
            owner_:             poolCoverManager,
            asset_:             coverAssets[1],
            precision_:         precision,
            escrowFactory_:     escrowFactory,
            escrowInitializer_: escrowInitializer,
            lockupDuration_:    lockupDuration,
            redeemWindow_:      redeemWindow
        }));

        poolCovers[2] = address(new PoolCover({
            name_:              "Pool Cover - Wrapped Ether",
            symbol_:            "MPL-CP-WETH",
            owner_:             poolCoverManager,
            asset_:             coverAssets[2],
            precision_:         precision,
            escrowFactory_:     escrowFactory,
            escrowInitializer_: escrowInitializer,
            lockupDuration_:    lockupDuration,
            redeemWindow_:      redeemWindow
        }));

        poolCovers[3] = address(new PoolCover({
            name_:              "Pool Cover - xMPL",
            symbol_:            "MPL-CP-xMPL",
            owner_:             poolCoverManager,
            asset_:             coverAssets[3],
            precision_:         precision,
            escrowFactory_:     escrowFactory,
            escrowInitializer_: escrowInitializer,
            lockupDuration_:    lockupDuration,
            redeemWindow_:      redeemWindow
        }));

        converterAuctioneers = new address[](numberOfCovers);

        converterAuctioneers[0] = address(0);                                  // Needs to be address(0), checked in updateSettings() on PCM
        converterAuctioneers[1] = address(new MockAuctioneer(1e8,  10_000e6)); // 1 WBTC = 10_000 USDC
        converterAuctioneers[2] = address(new MockAuctioneer(1e18, 1_000e6));  // 1 WETH =  1_000 USDC
        converterAuctioneers[3] = address(new MockAuctioneer(1e18, 10e6));     // 1 XMPL =     10 USDC

        liquidatorAuctioneers = new address[](numberOfCovers);

        liquidatorAuctioneers[0] = address(new MockEOA());
        liquidatorAuctioneers[1] = address(new MockAuctioneer(10_000e6, 1e8));   // 1 WBTC = 10_000 USDC
        liquidatorAuctioneers[2] = address(new MockAuctioneer(1_000e6,  1e18));  // 1 WETH =  1_000 USDC
        liquidatorAuctioneers[3] = address(new MockAuctioneer(10e6,     1e18));  // 1 XMPL =     10 USDC

        converters = new address[](numberOfCovers);

        converters[0] = address(new MockEOA());
        converters[1] = address(new MockConverter(liquidityAsset, coverAssets[1], converterAuctioneers[1]));
        converters[2] = address(new MockConverter(liquidityAsset, coverAssets[2], converterAuctioneers[2]));
        converters[3] = address(new MockConverter(liquidityAsset, coverAssets[3], converterAuctioneers[3]));

        liquidators = new address[](numberOfCovers);

        liquidators[0] = address(new MockEOA());
        liquidators[1] = address(new MockConverter(coverAssets[1], liquidityAsset, liquidatorAuctioneers[1]));
        liquidators[2] = address(new MockConverter(coverAssets[2], liquidityAsset, liquidatorAuctioneers[2]));
        liquidators[3] = address(new MockConverter(coverAssets[3], liquidityAsset, liquidatorAuctioneers[3]));

        oracles = new address[](numberOfCovers);

        oracles[0] = address(new MockOracle(coverAssets[0], 8, 1e8));      // 1 USDC =      1 USD)
        oracles[1] = address(new MockOracle(coverAssets[1], 8, 10_000e8)); // 1 WBTC = 10_000 USD)
        oracles[2] = address(new MockOracle(coverAssets[2], 8, 1_000e8));  // 1 WETH =  1_000 USD)
        oracles[3] = address(new MockOracle(coverAssets[3], 8, 10e8));     // 1 XMPL =     10 USD)

        DefaultHandler(investmentManager).setAuctioneer(liquidatorAuctioneers[1]);

    }
    
}
