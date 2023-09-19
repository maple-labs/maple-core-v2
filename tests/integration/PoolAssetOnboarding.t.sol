// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IERC20Like,
    IGlobals,
    IKycERC20Like,
    IPool,
    IPoolDeployer,
    IPoolManager,
    IWithdrawalManager
} from "../../contracts/interfaces/Interfaces.sol";

import { AddressRegistry, console2 as console, PoolDeployer } from "../../contracts/Contracts.sol";

import { FuzzedUtil } from "../fuzz/FuzzedSetup.sol";

import { ProtocolHealthChecker } from "../health-checkers/ProtocolHealthChecker.sol";

import { HealthCheckerAssertions } from "../HealthCheckerAssertions.sol";

contract PoolAssetOnboardingTests is AddressRegistry, FuzzedUtil {

    uint256 constant ACTION_COUNT   = 15;
    uint256 constant FTL_LOAN_COUNT = 3;
    uint256 constant OTL_LOAN_COUNT = 6;

    address poolDelegate = makeAddr("poolDelegate");

    address poolDeployer;
    address poolManager;

    address[] newLps;

    function setUp() external {
        newLps.push(makeAddr("lp1"));
        newLps.push(makeAddr("lp2"));
        newLps.push(makeAddr("lp3"));

        _collateralAsset      = address(weth);
        _feeManager           = address(fixedTermFeeManagerV1);
        _fixedTermLoanFactory = address(fixedTermLoanFactory);
        _liquidatorFactory    = address(liquidatorFactory);
        _openTermLoanFactory  = address(openTermLoanFactory);
    }

    /**************************************************************************************************************************************/
    /*** Setup Functions                                                                                                                ***/
    /**************************************************************************************************************************************/

    function _configureGlobals(address poolAsset) internal {
        vm.startPrank(governor);
        IGlobals(globals).setCanDeployFrom(poolManagerFactory, poolDeployer, true);
        IGlobals(globals).setCanDeployFrom(withdrawalManagerFactory, poolDeployer, true);
        IGlobals(globals).setValidPoolAsset(poolAsset, true);
        IGlobals(globals).setValidPoolDelegate(poolDelegate, true);
        vm.stopPrank();
    }

    function _deployPoolWithNewAsset(address poolAsset, uint256[7] memory configParams) internal returns (address newPoolManager) {
        _configureGlobals(poolAsset);

        address[] memory loanMangerFactories = new address[](2);
        loanMangerFactories[0] = fixedTermLoanManagerFactory;
        loanMangerFactories[1] = openTermLoanManagerFactory;

        newPoolManager = deployAndActivatePool(
            poolDeployer,
            poolAsset,
            globals,
            poolDelegate,
            poolManagerFactory,
            withdrawalManagerFactory,
            "Generic Maple Pool",
            "MP-Generic",
            loanMangerFactories,
            configParams
        );
    }

    function _performFuzzedLifecycle(uint256 seed) internal {
        address pool = IPoolManager(poolManager).pool();

        setAddresses(pool);

        vm.prank(poolDelegate);
        IPoolManager(poolManager).setOpenToPublic();

        deposit(pool, newLps[0], 4_000_000e6);
        deposit(pool, newLps[1], 2_000_000e6);
        deposit(pool, newLps[2], 3_000_000e6);

        fuzzedSetup(FTL_LOAN_COUNT, OTL_LOAN_COUNT, ACTION_COUNT, seed);

        // Make the LP withdraw
        requestRedeem(pool, newLps[0], 4_000_000e6);
        requestRedeem(pool, newLps[1], 2_000_000e6);
        requestRedeem(pool, newLps[2], 3_000_000e6);

        IWithdrawalManager wm = IWithdrawalManager(IPoolManager(poolManager).withdrawalManager());

        vm.warp(wm.getWindowStart(wm.exitCycleId(newLps[0])) + 1);

        redeem(pool, newLps[0], 4_000_000e6);
        redeem(pool, newLps[1], 2_000_000e6);
        redeem(pool, newLps[2], 3_000_000e6);
    }

    /**************************************************************************************************************************************/
    /*** Lifecycle Tests                                                                                                                ***/
    /**************************************************************************************************************************************/

    /// forge-config: default.fuzz.runs = 10
    /// forge-config: deep.fuzz.runs = 100
    /// forge-config: super_deep.fuzz.runs = 1000
    function test_USDTPoolLifecycle(uint256 seed) external {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 17522400);

        // NOTE: The new version of the PoolDeployer is not deployed on mainnet yet.
        poolDeployer = address(new PoolDeployer(globals));

        uint256[7] memory configParams = [uint256(10_000_000e6), 0.01e6, 0, 5 days, 2 days, 0, block.timestamp];

        poolManager = _deployPoolWithNewAsset(USDT, configParams);

        _performFuzzedLifecycle(seed);
    }

}

contract KeyringOnboardingTests is AddressRegistry, FuzzedUtil, HealthCheckerAssertions {

    address poolDelegate = makeAddr("poolDelegate");

    address healthChecker;
    address pool;
    address poolDeployer;
    address poolManager;
    address withdrawalManager;

    function setUp() external {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 17914006);

        healthChecker = address(new ProtocolHealthChecker());

        setupPoolDeployer();
        deployPool();
        addPoolExemptions();
        setupFuzzing();
    }

    /**************************************************************************************************************************************/
    /*** Setup Functions                                                                                                                ***/
    /**************************************************************************************************************************************/

    function setupPoolDeployer() internal {
        poolDeployer = address(new PoolDeployer(globals));

        vm.startPrank(governor);
        IGlobals(globals).setCanDeployFrom(poolManagerFactory, poolDeployer, true);
        IGlobals(globals).setCanDeployFrom(withdrawalManagerFactory, poolDeployer, true);
        vm.stopPrank();
    }

    function deployPool() internal {
        vm.startPrank(governor);
        IGlobals(globals).setValidPoolAsset(USDC_K1, true);
        IGlobals(globals).setValidPoolDelegate(poolDelegate, true);
        vm.stopPrank();

        address[] memory loanManagerFactories = new address[](2);
        loanManagerFactories[0] = fixedTermLoanManagerFactory;
        loanManagerFactories[1] = openTermLoanManagerFactory;

        // TODO: Include pool cover and set bootstrap mint.
        vm.prank(poolDelegate);
        poolManager = IPoolDeployer(poolDeployer).deployPool({
            poolManagerFactory_:       poolManagerFactory,
            withdrawalManagerFactory_: withdrawalManagerFactory,
            loanManagerFactories_:     loanManagerFactories,
            asset_:                    USDC_K1,
            name_:                     "Keyring Pool",
            symbol_:                   "KP",
            configParams_:             [type(uint256).max, 0, 0, 7 days, 2 days, 0, block.timestamp]
        });

        setDelegateManagementFeeRate(poolManager, 0.02e6);
        setPlatformManagementFeeRate(globals, poolManager, 0.03e6);

        pool = IPoolManager(poolManager).pool();
        withdrawalManager = IPoolManager(poolManager).withdrawalManager();

        vm.prank(governor);
        IGlobals(globals).activatePoolManager(poolManager);

        vm.prank(poolDelegate);
        IPoolManager(poolManager).setOpenToPublic();
    }

    function addPoolExemptions() internal {

        // Transfer rules:
        // 1. If the policy is disabled:
        //    - if both parties consent: allow, block otherwise
        // 2. If the policy is enabled:
        //    - if both parties are exempt: allow
        //    - if counterparty approval is enabled: allow if each non-exempt party is approved
        //    - otherwise: `checkTraderWallet()` && `checkZKPIICache()`

        addKeyringExemption(poolManager);

        addKeyringExemption(IPoolManager(poolManager).pool());
        addKeyringExemption(IPoolManager(poolManager).poolDelegate());
        addKeyringExemption(IPoolManager(poolManager).poolDelegateCover());
        addKeyringExemption(IPoolManager(poolManager).withdrawalManager());
        addKeyringExemption(IPoolManager(poolManager).loanManagerList(0));
        addKeyringExemption(IPoolManager(poolManager).loanManagerList(1));

        addKeyringExemption(IGlobals(globals).mapleTreasury());

        // To prevent `erc20_mint()` from failing.
        addKeyringExemption(USDC_K1_SOURCE);
    }

    function setupFuzzing() internal {
        _collateralAsset      = address(weth);
        _feeManager           = address(fixedTermFeeManagerV1);
        _fixedTermLoanFactory = address(fixedTermLoanFactory);
        _liquidatorFactory    = address(liquidatorFactory);
        _openTermLoanFactory  = address(openTermLoanFactory);

        setAddresses(pool);

        uint256 mintAmount = 100_000_000e6;

        erc20_mint(USDC, USDC_K1_SOURCE, mintAmount);

        vm.startPrank(USDC_K1_SOURCE);
        IERC20Like(USDC).approve(USDC_K1, mintAmount);
        IKycERC20Like(USDC_K1).depositFor(USDC_K1_SOURCE, mintAmount);
        vm.stopPrank();
    }

    /**************************************************************************************************************************************/
    /*** Lifecycle Tests                                                                                                                ***/
    /**************************************************************************************************************************************/

    // TODO: Include off-chain liquidations and refinancing.

    /// forge-config: default.fuzz.runs = 10
    /// forge-config: deep.fuzz.runs = 100
    /// forge-config: super_deep.fuzz.runs = 1000
    function test_keyring_lifecycle(uint256 seed) external {
        address lp1 = makeAddr("lp1");
        address lp2 = makeAddr("lp2");
        address lp3 = makeAddr("lp3");

        addKeyringExemption(lp1);
        addKeyringExemption(lp2);
        addKeyringExemption(lp3);

        deposit(pool, lp1, 3_500_000e6);
        deposit(pool, lp2, 1_700_000e6);
        deposit(pool, lp3, 4_000_000e6);

        fuzzedSetup({ fixedTermLoans: 3, openTermLoans: 6, actionCount: 15, seed_: seed });

        requestRedeem(pool, lp1, 3_500_000e6);
        requestRedeem(pool, lp2, 1_700_000e6);
        requestRedeem(pool, lp3, 4_000_000e6);

        uint256 exitCycleId = IWithdrawalManager(withdrawalManager).exitCycleId(lp1);
        uint256 windowStart = IWithdrawalManager(withdrawalManager).getWindowStart(exitCycleId);

        vm.warp(windowStart);

        redeem(pool, lp1, 3_500_000e6);
        redeem(pool, lp2, 1_700_000e6);
        redeem(pool, lp3, 4_000_000e6);

        assertProtocolInvariants(poolManager, address(healthChecker));
    }

}
