// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

import { MockERC20 }             from "../modules/erc20/contracts/test/mocks/MockERC20.sol";
import { MockInvestmentVehicle } from "../modules/poolV2/tests/mocks/MockInvestmentVehicle.sol";

import { GenericInvestmentManager } from "../modules/poolV2/contracts/GenericInvestmentManager.sol";
import { PoolV2 as Pool }           from "../modules/poolV2/contracts/PoolV2.sol";
import { WithdrawalManager }        from "../modules/withdrawal-manager/contracts/WithdrawalManager.sol";

contract WithdrawalIntegrationTest is TestUtils {

    MockERC20                asset;

    GenericInvestmentManager investmentManager;
    Pool                     pool;
    WithdrawalManager        withdrawalManager;

    uint256 constant COOLDOWN  = 2 weeks;
    uint256 constant DURATION  = 48 hours;
    uint256 constant FREQUENCY = 1 weeks;
    uint256 constant START     = 1641164400;  // 1st Monday of 2022

    uint256 constant MAX_ASSETS = 1e36;
    uint256 constant MAX_DELAY  = 52 weeks;
    uint256 constant MAX_SHARES = 1e40;

    address constant POOL_STAKER = address(222);

    function setUp() public {
        asset             = new MockERC20("MockAsset", "MA", 18);
        investmentManager = new GenericInvestmentManager();
        pool              = new Pool("Pool", "Pool", address(this), address(asset), 1e30);
        withdrawalManager = new WithdrawalManager(address(asset), address(pool), START, DURATION, FREQUENCY, COOLDOWN / FREQUENCY);

        pool.setInvestmentManager(address(investmentManager));
        pool.setWithdrawalManager(address(withdrawalManager));

        vm.warp(START);
    }

    function test_fullDepositAndWithdrawal() external {

        uint256 deposit = 1000e18;

        asset.mint(address(POOL_STAKER), deposit);

        assertEq(pool.freeAssets(),   0);
        assertEq(pool.totalAssets(),  0);
        assertEq(pool.principalOut(), 0);
        assertEq(pool.interestOut(),  0);
        assertEq(pool.issuanceRate(), 0);

        assertEq(asset.balanceOf(address(POOL_STAKER)), deposit);
        assertEq(asset.balanceOf(address(pool)),   0);

        vm.startPrank(POOL_STAKER);
        asset.approve(address(pool), deposit);
        uint256 shares = pool.deposit(deposit, POOL_STAKER);
        vm.stopPrank();

        assertEq(pool.freeAssets(),   deposit);
        assertEq(pool.totalAssets(),  deposit);
        assertEq(pool.principalOut(), 0);
        assertEq(pool.interestOut(),  0);
        assertEq(pool.issuanceRate(), 0);

        assertEq(asset.balanceOf(address(POOL_STAKER)), 0);
        assertEq(asset.balanceOf(address(pool)),        deposit);

        // Fund an investment
        uint256 principal    = 1e18;
        uint256 interestRate = 0.12e18; // 12% a year for easy calculations
        uint256 interval     = 90 days;

        MockInvestmentVehicle investment = new MockInvestmentVehicle({
            principal_:         principal,
            interestRate_:      interestRate,
            paymentInterval_:   interval,
            pool_:              address(pool),
            asset_:             address(asset), 
            investmentManager_: address(investmentManager)
        });

        // Fund a investment on address(this)
        pool.fund(principal, address(investment));

        assertEq(pool.principalOut(), principal);
        assertEq(pool.interestOut(),  0.029589041095890410e18);  // roughly 90 days of 12% over a 1e18 principal
        assertEq(pool.freeAssets(),   deposit);
        assertEq(pool.totalAssets(),  deposit);

        // Warp to when investment matures
        vm.warp(block.timestamp + interval);

        // Get Investment back
        asset.mint(address(investment), 1e18);
        investment.setLastPayment(true);

        pool.claim(address(investment));

        assertEq(pool.vestingPeriodFinish(), block.timestamp);
        assertEq(pool.interestOut(),         0);
        assertEq(pool.principalOut(),        0);
        assertEq(pool.issuanceRate(),        0);

        // Lock staker share
        vm.startPrank(POOL_STAKER);
        pool.approve(address(withdrawalManager), shares);
        withdrawalManager.lockShares(shares);
        vm.stopPrank();

        assertEq(pool.balanceOf(address(POOL_STAKER)),       0);
        assertEq(pool.balanceOf(address(withdrawalManager)), shares);

        assertEq(asset.balanceOf(address(POOL_STAKER)),       0);
        assertEq(asset.balanceOf(address(withdrawalManager)), 0);

        assertEq(withdrawalManager.lockedShares(address(POOL_STAKER)),     shares);
        assertEq(withdrawalManager.withdrawalPeriod(address(POOL_STAKER)), 14);

        assertEq(withdrawalManager.totalShares(14),        shares);
        assertEq(withdrawalManager.pendingWithdrawals(14), 1);
        assertTrue(!withdrawalManager.isProcessed(14));

        // Using hardcoded timestamp because there's no way to know when a period will end
        vm.warp(1649804399);

        vm.prank(POOL_STAKER);
        withdrawalManager.redeemPosition(shares);

        assertEq(pool.balanceOf(address(POOL_STAKER)),       0);
        assertEq(pool.balanceOf(address(withdrawalManager)), 0);

        assertWithinDiff(asset.balanceOf(address(POOL_STAKER)), deposit + 0.029589041095890410e18, 1);

        assertEq(asset.balanceOf(address(withdrawalManager)), 0);

        assertEq(withdrawalManager.lockedShares(address(POOL_STAKER)),     0);
        assertEq(withdrawalManager.withdrawalPeriod(address(POOL_STAKER)), 0);

        assertEq(withdrawalManager.totalShares(14),        0);
        assertEq(withdrawalManager.pendingWithdrawals(14), 0);
        assertTrue(withdrawalManager.isProcessed(14));
    }

}
