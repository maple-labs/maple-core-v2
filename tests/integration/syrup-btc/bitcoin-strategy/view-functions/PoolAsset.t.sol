// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract PoolAssetTests is SyrupBitcoinTestBase {

    function test_poolAsset_getter() external view {
        assertEq(bitcoinStrategy.poolAsset(), address(compositeAsset));
    }

}
