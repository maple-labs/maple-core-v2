// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract PreviewDeployTests is SyrupBitcoinTestBase {

    function test_previewDeploy_identicalOutput() external {
        uint256 amount = 1e8;
        uint256 output = assetController.previewDeploy(address(depositAsset), amount);

        assertEq(output, amount);
    }

    function test_previewDeploy_zero() external {
        uint256 output = assetController.previewDeploy(address(depositAsset), 0);

        assertEq(output, 0);
    }

}
