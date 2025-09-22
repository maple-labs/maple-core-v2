// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract PreviewReconcileTests is SyrupBitcoinTestBase {

    function test_previewReconcile_identicalOutput() external {
        uint256 amount = 2e8;
        uint256 output = assetController.previewReconcile(address(depositAsset), amount);

        assertEq(output, amount);
    }

    function test_previewReconcile_zero() external {
        uint256 output = assetController.previewReconcile(address(depositAsset), 0);

        assertEq(output, 0);
    }

}
