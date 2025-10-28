// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {console2 as console} from "../../../modules/forge-std/src/console2.sol";

import {
    IAssetController,
    IBitcoinStrategy,
    IERC20,
    IERC20Like,
    IGlobals,
    IPool,
    IPoolManager,
    IPoolPermissionManager,
    ISyrupBitcoinRouter,
    IWithdrawalManagerQueue
} from "../../../contracts/interfaces/Interfaces.sol";

import { SyrupBTCHealthChecker } from "../../health-checkers/SyrupBTCHealthChecker.sol";

import { Action, FuzzedUtils } from "../../fuzz/syrup-btc/FuzzedSetup.sol";

import { HealthCheckerAssertions } from "../../HealthCheckerAssertions.sol";

import { SyrupBTCProtocolUpgradeBase } from "./SyrupBTCProtocolUpgradeBase.t.sol";

contract SyrupBTCFuzz is SyrupBTCProtocolUpgradeBase, FuzzedUtils, HealthCheckerAssertions {

    uint256 public constant ACTION_COUNT = 100;

    address public syrupBTCHealthChecker;

    function setUp() public override {
        super.setUp();

        _depositAsset      = wbtc;
        _pool              = syrupBitcoinPool;
        _poolAsset         = compositeTokenProxy;
        _bitcoinRouter     = bitcoinRouterProxy;
        _poolDelegate      = syrupBitcoinPoolDelegate;
        _redeemer          = bitcoinRouterRedeemer;
        _strategyManager   = bitcoinStrategy1Manager;
        _withdrawalManager = IPoolManager(IPool(_pool).manager()).withdrawalManager();

        lps.push(makeAddr("lp1"));
        lps.push(makeAddr("lp2"));
        lps.push(makeAddr("lp3"));

        uint256 strategyCount = IPoolManager(syrupBitcoinPoolManager).strategyListLength();

        for (uint256 i; i < strategyCount; i++) {
            strategies.push(IPoolManager(IPool(_pool).manager()).strategyList(i));
        }

        vm.prank(operationalAdmin);
        IGlobals(globals).activatePoolManager(syrupBitcoinPoolManager);

        uint256 bitmap = 2 ** 5;

        bytes32[] memory functionIdsToSet = new bytes32[](1);
        uint256[] memory bitmaps          = new uint256[](1);

        functionIdsToSet[0] = "P:requestRedeem";
        bitmaps[0]          = bitmap;

        vm.startPrank(operationalAdmin);
        IPoolPermissionManager(poolPermissionManager).setPoolBitmaps(syrupBitcoinPoolManager, functionIdsToSet, bitmaps);
        IGlobals(globals).setValidInstanceOf("SYRUP_BTC_REDEEMER", bitcoinRouterRedeemer, true);

        // Note: For Fork let one BTC Strategy manager call all strategies for simplicity
        address[] memory strategyManager1        = new address[](1);
        bool[]    memory allowedStrategyManager1 = new bool[](1);

        strategyManager1[0]        = bitcoinStrategy1Manager;
        allowedStrategyManager1[0] = true;

        IBitcoinStrategy(bitcoinStrategy2).setPermissions(
            strategyManager1,
            allowedStrategyManager1,
            allowedStrategyManager1,
            allowedStrategyManager1
        );

        IBitcoinStrategy(bitcoinStrategy3).setPermissions(
            strategyManager1,
            allowedStrategyManager1,
            allowedStrategyManager1,
            allowedStrategyManager1
        );

        vm.stopPrank();

        syrupBTCHealthChecker = address(new SyrupBTCHealthChecker());
    }

    function testFuzzFork_syrupBTC_fuzzedSetup_assertInvariants(uint256 seed_) external {
        seed = seed_;

        Action[] memory actions = new Action[](ACTION_COUNT);
        for (uint256 i = 0; i < ACTION_COUNT; i++) {
            actions[i] = Action(getSomeValue(0, 11));
        }

        fuzzedSetup(actions);

        address[] memory depositAssets = new address[](1);
        depositAssets[0]               = wbtc;

        assertSyrupBTCInvariants(syrupBTCHealthChecker, bitcoinRouterProxy, depositAssets);
    }

}
