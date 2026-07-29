// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { Test } from "../modules/forge-std/src/Test.sol";

contract Utils is Test {

    function array(address value1) internal pure returns (address[] memory values) {
        values    = new address[](1);
        values[0] = value1;
    }

    function array(address value1, address value2) internal pure returns (address[] memory values) {
        values    = new address[](2);
        values[0] = value1;
        values[1] = value2;
    }

    function array(
        address value1,
        address value2,
        address value3
    )
        internal pure returns (address[] memory values)
    {
        values    = new address[](3);
        values[0] = value1;
        values[1] = value2;
        values[2] = value3;
    }

    function array(
        address value1,
        address value2,
        address value3,
        address value4
    )
        internal pure returns (address[] memory values)
    {
        values    = new address[](4);
        values[0] = value1;
        values[1] = value2;
        values[2] = value3;
        values[3] = value4;
    }

    function array(uint256 value1) internal pure returns (uint256[] memory values) {
        values    = new uint256[](1);
        values[0] = value1;
    }

    function array(uint256 value1, uint256 value2) internal pure returns (uint256[] memory values) {
        values    = new uint256[](2);
        values[0] = value1;
        values[1] = value2;
    }

    function array(
        uint256 value1,
        uint256 value2,
        uint256 value3
    )
        internal pure returns (uint256[] memory values)
    {
        values    = new uint256[](3);
        values[0] = value1;
        values[1] = value2;
        values[2] = value3;
    }

    function array(
        uint256 value1,
        uint256 value2,
        uint256 value3,
        uint256 value4
    )
        internal pure returns (uint256[] memory values)
    {
        values    = new uint256[](4);
        values[0] = value1;
        values[1] = value2;
        values[2] = value3;
        values[3] = value4;
    }

    function array(
        uint256 value1,
        uint256 value2,
        uint256 value3,
        uint256 value4,
        uint256 value5
    )
        internal pure returns (uint256[] memory values)
    {
        values    = new uint256[](5);
        values[0] = value1;
        values[1] = value2;
        values[2] = value3;
        values[3] = value4;
        values[4] = value5;
    }

    function divRoundUp(uint256 numerator_, uint256 divisor_) internal pure returns (uint256 result_) {
        result_ = (numerator_ + divisor_ - 1) / divisor_;
    }

    /// @dev Returns `count` pseudo-random values sampled from `values` without selecting the same index twice.
    ///      Mutates `values` in memory while building the subset.
    function randomSubset(
        uint256 seed,
        uint256 count,
        uint256[] memory values
    )
        internal pure returns (uint256[] memory randomValues)
    {
        require(count <= values.length, "UTILS:COUNT_GT_VALUES_LENGTH");

        randomValues = new uint256[](count);

        for (uint256 i; i < count; ++i) {
            uint256 randomIndex = bound(uint256(keccak256(abi.encode(seed, i))), i, values.length - 1);

            randomValues[i] = values[randomIndex];

            // Remove the selected value from the remaining range by replacing it with the current boundary value.
            values[randomIndex] = values[i];
        }
    }

}
