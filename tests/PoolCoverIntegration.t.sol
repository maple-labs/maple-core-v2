// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

import { MockERC20 }             from "../modules/erc20/contracts/test/mocks/MockERC20.sol";
import { MockInvestmentVehicle } from "../modules/poolV2/tests/mocks/MockInvestmentVehicle.sol";

import { PoolV2 as Pool }           from "../modules/poolV2/contracts/PoolV2.sol";
import { GenericInvestmentManager } from "../modules/poolV2/contracts/GenericInvestmentManager.sol";
import { PoolCoverManager }         from "../modules/pool-cover/contracts/PoolCoverManager.sol";

contract PoolCoverIntegrationTest is TestUtils {

    address internal constant LIQUIDITY_PROVIDER = address(1);
    address internal constant POOL_DELEGATE      = address(2);

    address internal constant MPL_LIQUIDATOR  = address(3);
    address internal constant WBTC_LIQUIDATOR = address(4);
    address internal constant WETH_LIQUIDATOR = address(5);

    uint256 internal constant COVER_PORTION    = 0.2e18 * INTEREST / 1e18;
    uint256 internal constant DEPOSIT          = 10_000e6;
    uint256 internal constant INTEREST         = PRINCIPAL * INTEREST_RATE * PAYMENT_INTERVAL / 365 days / 1e18;
    uint256 internal constant INTEREST_RATE    = 0.19e18;
    uint256 internal constant ISSUANCE_RATE    = INTEREST * 1e30 / 1e6;
    uint256 internal constant PAYMENT_INTERVAL = 1_000_000 seconds;
    uint256 internal constant PRINCIPAL        = 1_000e6;

    uint256 internal immutable START = block.timestamp;

    MockERC20 internal immutable MPL  = new MockERC20("Maple Token",   "MPL",  18);
    MockERC20 internal immutable USDC = new MockERC20("USD Coin",      "USDC", 6);
    MockERC20 internal immutable WBTC = new MockERC20("Wrapped BTC",   "WBTC", 8);
    MockERC20 internal immutable WETH = new MockERC20("Wrapped Ether", "WETH", 18);

    MockInvestmentVehicle    internal _loan;
    Pool                     internal _pool;
    PoolCoverManager         internal _poolCoverManager;

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
        GenericInvestmentManager investmentManager = new GenericInvestmentManager();
        _pool.setInvestmentManager(address(investmentManager));

        // Define, create, and inject the pool cover manager.
        address[] memory recipients = new address[](3);
        uint256[] memory weights    = new uint256[](3);

        recipients[0] = WETH_LIQUIDATOR;  // wETH
        recipients[1] = WBTC_LIQUIDATOR;  // wBTC
        recipients[2] = MPL_LIQUIDATOR;   // MPL

        weights[0] = 2_500;  // 25.00%
        weights[1] = 2_500;  // 25.00%
        weights[2] = 5_000;  // 50.00%

        _poolCoverManager = new PoolCoverManager({
            owner_:      address(_pool),
            asset_:      address(USDC),
            recipients_: recipients,
            weights_:    weights
        });

        _pool.setPoolCoverManager(address(_poolCoverManager));

        // Deposit initial liquidity into the pool.
        vm.startPrank(LIQUIDITY_PROVIDER);

        USDC.mint(LIQUIDITY_PROVIDER, DEPOSIT);
        USDC.approve(address(_pool), DEPOSIT);
        _pool.deposit(DEPOSIT, LIQUIDITY_PROVIDER);

        vm.stopPrank();

        // Define the terms of the loan and instantiate it.
        _loan = new MockInvestmentVehicle({
            principal_:         PRINCIPAL,
            interestRate_:      INTEREST_RATE,
            paymentInterval_:   PAYMENT_INTERVAL,
            pool_:              address(_pool),
            asset_:             address(USDC), 
            investmentManager_: address(investmentManager)
        });
    }

    function test_poolCoverIntegration() external {
        assertEq(_pool.freeAssets(),          DEPOSIT);
        assertEq(_pool.interestOut(),         0);
        assertEq(_pool.issuanceRate(),        0);
        assertEq(_pool.lastUpdated(),         START);
        assertEq(_pool.principalOut(),        0);
        assertEq(_pool.totalAssets(),         DEPOSIT);
        assertEq(_pool.vestingPeriodFinish(), 0);        

        assertEq(USDC.balanceOf(address(_loan)),             0);
        assertEq(USDC.balanceOf(address(_poolCoverManager)), 0);
        assertEq(USDC.balanceOf(address(_pool)),             DEPOSIT);

        // Fund the investment.
        vm.prank(POOL_DELEGATE);
        _pool.fund(PRINCIPAL, address(_loan));

        assertEq(_pool.freeAssets(),          DEPOSIT);
        assertEq(_pool.interestOut(),         INTEREST);
        assertEq(_pool.issuanceRate(),        ISSUANCE_RATE);
        assertEq(_pool.lastUpdated(),         START);
        assertEq(_pool.principalOut(),        PRINCIPAL);
        assertEq(_pool.totalAssets(),         DEPOSIT);
        assertEq(_pool.vestingPeriodFinish(), START + PAYMENT_INTERVAL);

        assertEq(USDC.balanceOf(address(_loan)),             PRINCIPAL);
        assertEq(USDC.balanceOf(address(_poolCoverManager)), 0);
        assertEq(USDC.balanceOf(address(_pool)),             DEPOSIT - PRINCIPAL);

        assertEq(USDC.balanceOf(address(MPL_LIQUIDATOR)),  0);
        assertEq(USDC.balanceOf(address(WBTC_LIQUIDATOR)), 0);
        assertEq(USDC.balanceOf(address(WETH_LIQUIDATOR)), 0);

        vm.warp(block.timestamp + PAYMENT_INTERVAL);

        // Claim the interest.
        vm.prank(POOL_DELEGATE);
        _pool.claim(address(_loan));

        assertEq(_pool.freeAssets(),          DEPOSIT + INTEREST);
        assertEq(_pool.interestOut(),         INTEREST);
        assertEq(_pool.issuanceRate(),        ISSUANCE_RATE);
        assertEq(_pool.lastUpdated(),         START + PAYMENT_INTERVAL);
        assertEq(_pool.principalOut(),        PRINCIPAL);
        assertEq(_pool.totalAssets(),         DEPOSIT + INTEREST);
        assertEq(_pool.vestingPeriodFinish(), START + 2 * PAYMENT_INTERVAL);

        assertEq(USDC.balanceOf(address(_loan)),             PRINCIPAL - INTEREST);
        assertEq(USDC.balanceOf(address(_poolCoverManager)), 0);
        assertEq(USDC.balanceOf(address(_pool)),             DEPOSIT - PRINCIPAL + INTEREST - COVER_PORTION);

        assertEq(USDC.balanceOf(address(MPL_LIQUIDATOR)),  COVER_PORTION / 2);  // 50.00%
        assertEq(USDC.balanceOf(address(WBTC_LIQUIDATOR)), COVER_PORTION / 4);  // 25.00%
        assertEq(USDC.balanceOf(address(WETH_LIQUIDATOR)), COVER_PORTION / 4);  // 25.00%
    }

}
