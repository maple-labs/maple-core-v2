// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC20 } from "../contracts/interfaces/Interfaces.sol";

import { console2 as console, Runner } from "../contracts/Runner.sol";

contract BalanceAssertions is Runner {

    /***********************************/
    /*** Balance Assertion Functions ***/
    /***********************************/

    mapping(address => mapping(address => uint256)) partialAssetBalances;  // Helper mapping to assert differences in balance.

    // NOTE: Overloading was used here to allow for tests to not need to cast values in arrays.

    function assertAssetBalance(address asset, address owner, uint256 amount, uint256 index) internal {
        bool isEqual = IERC20(asset).balanceOf(owner) == amount;

        if (!isEqual) {
            console.log("Balance wrong for", index);
        }

        assertTrue(isEqual);
    }

    function assertAssetBalancesIncrease(address asset, address[2] memory addresses, uint32[2] memory amounts) internal {
        for (uint256 i; i < addresses.length; ++i) {
            assertAssetBalance(asset, addresses[i], amounts[i] + partialAssetBalances[asset][addresses[i]], i);
        }
        checkpointBalance(asset, addresses);  // Mark a new checkpoint.
    }

    function assertAssetBalancesIncrease(address asset, address[2] memory addresses, uint40[2] memory amounts) internal {
        for (uint256 i; i < addresses.length; ++i) {
            assertAssetBalance(asset, addresses[i], amounts[i] + partialAssetBalances[asset][addresses[i]], i);
        }
        checkpointBalance(asset, addresses);  // Mark a new checkpoint.
    }

    function assertAssetBalancesIncrease(address asset, address[2] memory addresses, uint256[2] memory amounts) internal {
        for (uint256 i; i < addresses.length; ++i) {
            assertAssetBalance(asset, addresses[i], amounts[i] + partialAssetBalances[asset][addresses[i]], i);
        }
        checkpointBalance(asset, addresses);  // Mark a new checkpoint.
    }

    function assertAssetBalances(address asset, address[3] memory addresses, uint256[3] memory amounts) internal {
        for (uint256 i; i < addresses.length; ++i) {
            assertAssetBalance(asset, addresses[i], amounts[i], i);
        }
    }

    function assertAssetBalances(address asset, address[4] memory addresses, uint256[4] memory amounts) internal {
        for (uint256 i; i < addresses.length; ++i) {
            assertAssetBalance(asset, addresses[i], amounts[i], i);
        }
    }

    function assertAssetBalances(address asset, address[5] memory addresses, uint256[5] memory amounts) internal {
        for (uint256 i; i < addresses.length; ++i) {
            assertAssetBalance(asset, addresses[i], amounts[i], i);
        }
    }

    function assertAssetBalances(address asset, address[6] memory addresses, uint256[6] memory amounts) internal {
        for (uint256 i; i < addresses.length; ++i) {
            assertAssetBalance(asset, addresses[i], amounts[i], i);
        }
    }

    function checkpointBalance(address asset, address[2] memory addresses) internal {
        for (uint256 i; i < addresses.length; ++i) {
            partialAssetBalances[asset][addresses[i]] = IERC20(asset).balanceOf(addresses[i]);
        }
    }

}
