// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { console } from "../modules/contract-test-utils/contracts/log.sol";

import { MockERC20 as Asset  } from "../modules/erc20/contracts/test/mocks/MockERC20.sol";
import { TestBase } from "./TestBase.sol";

contract BalanceAssertions is TestBase {

    /***********************************/
    /*** Balance Assertion Functions ***/
    /***********************************/

    // NOTE: Overloading was used here to allow for tests to not need to cast values in arrays.

    function assertAssetBalances(address[3] memory addresses, uint40[3] memory assets) internal {
        for (uint i; i < addresses.length; i++) {
            _assertAssetBalance(addresses[i], assets[i], i);
        }
    }

    function assertAssetBalances(address[3] memory addresses, uint48[3] memory assets) internal {
        for (uint i; i < addresses.length; i++) {
            _assertAssetBalance(addresses[i], assets[i], i);
        }
    }

    function assertAssetBalances(address[4] memory addresses, uint40[4] memory assets) internal {
        for (uint i; i < addresses.length; i++) {
            _assertAssetBalance(addresses[i], assets[i], i);
        }
    }

    function assertAssetBalances(address[5] memory addresses, uint40[5] memory assets) internal {
        for (uint i; i < addresses.length; i++) {
            _assertAssetBalance(addresses[i], assets[i], i);
        }
    }

    function assertAssetBalances(address[6] memory addresses, uint40[6] memory assets) internal {
        for (uint i; i < addresses.length; i++) {
            _assertAssetBalance(addresses[i], assets[i], i);
        }
    }

    function assertAssetBalances(address[6] memory addresses, uint48[6] memory assets) internal {
        for (uint i; i < addresses.length; i++) {
            _assertAssetBalance(addresses[i], assets[i], i);
        }
    }

    function assertAssetBalances(address[6] memory addresses, uint256[6] memory assets) internal {
        for (uint i; i < addresses.length; i++) {
            _assertAssetBalance(addresses[i], assets[i], i);
        }
    }

    function assertShareBalances(address[] memory addresses, uint256[] memory shares) internal {
        for (uint i; i < addresses.length; i++) {
            assertEq(pool.balanceOf(addresses[i]), shares[i]);
        }
    }

    function _assertAssetBalance(address owner, uint256 asset, uint256 index) internal {
        bool isTrue = fundsAsset.balanceOf(owner) == asset;
        if (!isTrue) {
            console.log("Balance wrong for", index);
        }
        assertEq(fundsAsset.balanceOf(owner), asset);
    }

}
