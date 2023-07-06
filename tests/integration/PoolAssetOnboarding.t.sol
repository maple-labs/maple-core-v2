// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IERC20Like,
    IGlobals,
    IPoolDeployer,
    IPoolManager,
    IWithdrawalManager
} from "../../contracts/interfaces/Interfaces.sol";

import { AddressRegistry, console2 as console } from "../../contracts/Contracts.sol";

import { ProtocolActions } from "../../contracts/ProtocolActions.sol";

import { FuzzedUtil } from "../fuzz/FuzzedSetup.sol";

contract PoolAssetOnboardingTests is AddressRegistry, ProtocolActions, FuzzedUtil {

    uint256 constant ACTION_COUNT   = 15;
    uint256 constant FTL_LOAN_COUNT = 3;
    uint256 constant OTL_LOAN_COUNT = 6;

    address poolDelegate = makeAddr("poolDelegate");

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

    /// forge-config: default.fuzz.runs = 10
    /// forge-config: deep.fuzz.runs = 100
    /// forge-config: super_deep.fuzz.runs = 1000
    function test_USDTPoolLifecycle(uint256 seed) external {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 17522400);

        uint256[6] memory configParams = [uint256(10_000_000e6), 0.01e6, 0, 5 days, 2 days, 0];

        address poolManager = _deployPoolWithNewAsset(USDT, configParams);

        _performFuzzedLifecycle(poolManager, seed);
    }

    function _configureGlobals(address poolAsset) internal {
        IGlobals globals = IGlobals(globals);

        vm.startPrank(governor);

        // Allow new pool asset
        globals.setValidPoolAsset(poolAsset, true);

        // Allow PD in Globals
        globals.setValidPoolDelegate(poolDelegate, true);

        vm.stopPrank();
    }

    function _deployPoolWithNewAsset(address poolAsset, uint256[6] memory configParams) internal returns (address newPoolManager) {
        _configureGlobals(poolAsset);

        address[] memory loanMangerFactories = new address[](2);
        loanMangerFactories[0] = fixedTermLoanManagerFactory;
        loanMangerFactories[1] = openTermLoanManagerFactory;

        newPoolManager = deployAndActivatePool(
            poolDeployerV2,
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

    function _performFuzzedLifecycle(address poolManager, uint256 seed) internal {
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

}
