// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IAssetController,
    IERC20,
    IERC20Like,
    IPool,
    ISyrupBitcoinRouter,
    IWithdrawalManagerQueue
} from "../../../contracts/interfaces/Interfaces.sol";

import { SyrupBTCHealthChecker } from "../../health-checkers/SyrupBTCHealthChecker.sol";

import { HealthCheckerAssertions } from "../../HealthCheckerAssertions.sol";

import { Action, FuzzedSetup } from "./FuzzedSetup.sol";

contract SyrupBTCFuzz is FuzzedSetup, HealthCheckerAssertions {

    uint256 public constant ACTION_COUNT = 100;

    address public syrupBTCHealthChecker;

    function setUp() public override {
        super.setUp();

        syrupBTCHealthChecker = address(new SyrupBTCHealthChecker());
    }

    function testFuzz_syrupBTC_fuzzedSetup_assertInvariants(uint256 seed_) external {
        seed = seed_;

        Action[] memory actions = new Action[](ACTION_COUNT);
        for (uint256 i = 0; i < ACTION_COUNT; i++) {
            actions[i] = Action(getSomeValue(0, 11));
        }

        fuzzedSetup(actions);

        address[] memory depositAssets = new address[](1);
        depositAssets[0]               = address(depositAsset);

        assertSyrupBTCInvariants(syrupBTCHealthChecker, address(bitcoinRouter), depositAssets);
    }

}
