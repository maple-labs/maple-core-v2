// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IAaveStrategy, ISkyStrategy } from "contracts/interfaces/Interfaces.sol";

import { StrategyTestBase } from "./StrategyTestBase.sol";

contract AddStrategyToSyrupUSDCTests is StrategyTestBase {

    uint256 usdcIn = 200_00e6;

    function test_addStrategy_syrupUSDC_aaveStrategy() external {
        vm.prank(governor);
        syrupUsdcPoolManager.addStrategy(address(aaveStrategyFactory), abi.encode(address(aUsdc)));

        IAaveStrategy aaveStrategy = IAaveStrategy(syrupUsdcPoolManager.strategyList(2));

        assertEq(syrupUsdcPoolManager.isStrategy(address(aaveStrategy)), true);

        uint256 totalAssets = syrupUsdcPool.totalAssets();

        vm.prank(syrupUSDCPoolDelegate);
        aaveStrategy.fundStrategy(usdcIn);

        assertApproxEqAbs(syrupUsdcPool.totalAssets(),              totalAssets, 1);
        assertApproxEqAbs(aaveStrategy.assetsUnderManagement(), usdcIn,      1);

        // Accrue yield.
        vm.warp(start + 5 days);

        assertGt(aaveStrategy.assetsUnderManagement(), usdcIn);

        vm.prank(syrupUSDCPoolDelegate);
        aaveStrategy.withdrawFromStrategy(usdcIn);

        assertGt(aaveStrategy.assetsUnderManagement(), 0);
    }

    function test_addStrategy_syrupUSDC_skyStrategy() external {
        vm.prank(governor);
        syrupUsdcPoolManager.addStrategy(address(skyStrategyFactory), abi.encode(savingsUsds, usdsLitePSM));

        ISkyStrategy skyStrategy = ISkyStrategy(syrupUsdcPoolManager.strategyList(2));

        assertEq(syrupUsdcPoolManager.isStrategy(address(skyStrategy)), true);

        uint256 totalAssets = syrupUsdcPool.totalAssets();

        vm.prank(syrupUSDCPoolDelegate);
        skyStrategy.fundStrategy(usdcIn);

        assertApproxEqAbs(syrupUsdcPool.totalAssets(),             totalAssets, 1);
        assertApproxEqAbs(skyStrategy.assetsUnderManagement(), usdcIn,      1);

        // Accrue yield.
        vm.warp(start + 5 days);

        assertGt(skyStrategy.assetsUnderManagement(), usdcIn);

        vm.prank(syrupUSDCPoolDelegate);
        skyStrategy.withdrawFromStrategy(usdcIn);

        assertGt(skyStrategy.assetsUnderManagement(), 0);
    }

}
