// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { TestBase } from "../../TestBase.sol";

contract GetLatestPriceTests is TestBase {

    address weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    address chainlinkWethAggregator = address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    string url = vm.envString("ETH_RPC_URL");

    uint256 blockNumber = 15_588_766;
    uint256 wethPrice   = 1311.75777214e8;
    uint96  maxDelay    = 86400 seconds;

    function setUp() public virtual override {
        vm.createSelectFork(url, blockNumber);

        super.setUp();
    }

    function test_getLatestPrice_unknownAsset() external {
        vm.expectRevert("MG:GLP:ZERO_ORACLE");
        globals.getLatestPrice(weth);
    }

    function test_getLatestPrice_manualOverride() external {
        vm.prank(governor);
        globals.setManualOverridePrice(weth, 1337e8);

        assertEq(globals.getLatestPrice(weth), 1337e8);
    }

    function test_getLatestPrice_currentPrice() external {
        vm.prank(governor);
        globals.setPriceOracle(weth, chainlinkWethAggregator, maxDelay);

        assertEq(globals.getLatestPrice(weth), wethPrice);
    }

    function test_getLatestPrice_stalePrice() external {
        vm.prank(governor);
        globals.setPriceOracle(weth, chainlinkWethAggregator, maxDelay);

        vm.expectRevert("MG:GLP:STALE_PRICE");
        vm.warp(block.timestamp + maxDelay);
        globals.getLatestPrice(weth);

        rewind(maxDelay);

        assertEq(globals.getLatestPrice(weth), wethPrice);
    }

}
