// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console } from "../contracts/Contracts.sol";

import { TestBase } from "./TestBase.sol";

contract BalanceAssertions is TestBase {

    /***********************************/
    /*** Balance Assertion Functions ***/
    /***********************************/

    // NOTE: Overloading was used here to allow for tests to not need to cast values in arrays.

    function assertAssetBalance(address owner, uint256 asset, uint256 index) internal {
        bool isTrue = fundsAsset.balanceOf(owner) == asset;
        if (!isTrue) {
            console.log("Balance wrong for", index);
        }
        assertEq(fundsAsset.balanceOf(owner), asset);
    }

    function assertAssetBalancesIncrease(address[2] memory addresses, uint32[2] memory assets) internal {
        for (uint256 i; i < addresses.length; ++i) {
            assertAssetBalance(addresses[i], assets[i] + partialAssetBalances[addresses[i]], i);
        }
        checkpointBalance(addresses);  // Mark a new checkpoint.
    }

    function assertAssetBalancesIncrease(address[2] memory addresses, uint40[2] memory assets) internal {
        for (uint256 i; i < addresses.length; ++i) {
            assertAssetBalance(addresses[i], assets[i] + partialAssetBalances[addresses[i]], i);
        }
        checkpointBalance(addresses);  // Mark a new checkpoint.
    }

    function assertAssetBalancesIncrease(address[2] memory addresses, uint256[2] memory assets) internal {
        for (uint256 i; i < addresses.length; ++i) {
            assertAssetBalance(addresses[i], assets[i] + partialAssetBalances[addresses[i]], i);
        }
        checkpointBalance(addresses);  // Mark a new checkpoint.
    }

    function assertAssetBalances(address[3] memory addresses, uint256[3] memory assets) internal {
        for (uint256 i; i < addresses.length; ++i) {
            assertAssetBalance(addresses[i], assets[i], i);
        }
    }

    function assertAssetBalances(address[4] memory addresses, uint256[4] memory assets) internal {
        for (uint256 i; i < addresses.length; ++i) {
            assertAssetBalance(addresses[i], assets[i], i);
        }
    }

    function assertAssetBalances(address[5] memory addresses, uint256[5] memory assets) internal {
        for (uint256 i; i < addresses.length; ++i) {
            assertAssetBalance(addresses[i], assets[i], i);
        }
    }

    function assertAssetBalances(address[6] memory addresses, uint256[6] memory assets) internal {
        for (uint256 i; i < addresses.length; ++i) {
            assertAssetBalance(addresses[i], assets[i], i);
        }
    }

    function checkpointBalance(address[2] memory addresses) internal {
        for (uint256 i; i < addresses.length; ++i) {
            partialAssetBalances[addresses[i]] = fundsAsset.balanceOf(addresses[i]);
        }
    }

}
