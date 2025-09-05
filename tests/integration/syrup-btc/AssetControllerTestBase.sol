// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../../TestBase.sol";

contract AssetControllerTestBase is TestBase {

    function setUp() public virtual override {
        super.setUp();

        _setupBitcoinPool();
    }

}
