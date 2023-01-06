// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { TestBase } from "../../contracts/utilities/TestBase.sol";

contract GetExpectedAmountTests is TestBase {

    address internal weth           = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address internal wethAggregator = address(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);

    string internal url = vm.envString("ETH_RPC_URL");

    uint256 internal blockNumber = 15_588_766;  // WETH price at the time: 1311.75777214e8

    function setUp() public virtual override {
        vm.createSelectFork(url, blockNumber);

        super.setUp();
    }

    function test_getExpectedAmount_oracleNotSet() external {
        vm.expectRevert("MG:GLP:ZERO_ORACLE");
        loanManager.getExpectedAmount(weth, 1);
    }

    function test_getExpectedAmount_zeroAmount() external {
        vm.prank(governor);
        globals.setPriceOracle(weth, wethAggregator);

        assertEq(loanManager.getExpectedAmount(weth, 0), 0);
    }

    function test_getExpectedAmount_manualOverride() external {
        vm.prank(governor);
        globals.setManualOverridePrice(weth, 1500.17e8);

        uint256 swapAmount   = 1.2345e18;
        uint256 returnAmount = 1851.959865e6;  // 1.2345 * 1500.17

        assertEq(loanManager.getExpectedAmount(weth, swapAmount), returnAmount);
    }

    function test_getExpectedAmount_currentPrice() external {
        vm.prank(governor);
        globals.setPriceOracle(weth, wethAggregator);

        uint256 swapAmount   = 13.7234925e18;
        uint256 returnAmount = 18001.897947e6;  // 13.7234925 * 1311.75777214

        assertEq(loanManager.getExpectedAmount(weth, swapAmount), returnAmount);
    }

    function test_getExpectedAmount_withSlippage() external {
        vm.startPrank(governor);
        globals.setPriceOracle(weth, wethAggregator);
        poolManager.setAllowedSlippage(address(loanManager), address(weth), 0.113e6);  // Slippage of 11.3%
        vm.stopPrank();

        uint256 swapAmount   = 13.7234925e18;
        uint256 returnAmount = 15967.683479e6;  // 13.7234925 * 1311.75777214 * 88.7%

        assertEq(loanManager.getExpectedAmount(weth, swapAmount), returnAmount);
    }

    function test_getExpectedAmount_withMinRatio() external {
        vm.startPrank(governor);
        globals.setPriceOracle(weth, wethAggregator);
        poolManager.setMinRatio(address(loanManager), address(weth), 2000e6);  // Minimum price of 2000 USDC
        vm.stopPrank();

        uint256 swapAmount = 13.7234925e18;

        // Maximum of these:
        // - oracleAmount:   13.7234925 * 1311.75777214 = 18001.897947
        // - minRatioAmount: 13.7234925 * 2000          = 27446.985

        assertEq(loanManager.getExpectedAmount(weth, swapAmount), 27446.985000e6);
    }

    function test_getExpectedAmount_withSlippageAndMinRatio_minRatioHigher() external {
        vm.startPrank(governor);
        globals.setPriceOracle(weth, wethAggregator);
        poolManager.setAllowedSlippage(address(loanManager), address(weth), 0.113e6);  // Slippage of 11.3%
        poolManager.setMinRatio(address(loanManager), address(weth), 1200e6);          // Minimum price of 1200 USDC
        vm.stopPrank();

        uint256 swapAmount = 13.7234925e18;

        // Maximum of these:
        // - oracleAmount:   13.7234925 * 1311.75777214 * 88.7% = 15967.683479
        // - minRatioAmount: 13.7234925 * 1200                  = 16468.191

        assertEq(loanManager.getExpectedAmount(weth, swapAmount), 16468.191000e6);
    }

    function test_getExpectedAmount_withSlippageAndMinRatio_slippageHigher() external {
        vm.startPrank(governor);
        globals.setPriceOracle(weth, wethAggregator);
        poolManager.setAllowedSlippage(address(loanManager), address(weth), 0.013e6);  // Slippage of 1.3%
        poolManager.setMinRatio(address(loanManager), address(weth), 1200e6);          // Minimum price of 1200 USDC
        vm.stopPrank();

        uint256 swapAmount = 13.7234925e18;

        // Maximum of these:
        // - oracleAmount:   13.7234925 * 1311.75777214 * 98.7% = 17767.873274
        // - minRatioAmount: 13.7234925 * 1200                  = 16468.191

        assertEq(loanManager.getExpectedAmount(weth, swapAmount), 17767.873274e6);
    }

}
