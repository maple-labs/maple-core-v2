// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IAaveStrategy,
    IMapleProxyFactory,
    IPool,
    IPoolManager,
    ISkyStrategy
} from "../../contracts/interfaces/Interfaces.sol";

import { ProtocolUpgradeBase } from "./ProtocolUpgradeBase.sol";

contract AddStrategyToSyrupUSDCTests is ProtocolUpgradeBase {

    address syrupUSDCPD;

    uint256 start;
    uint256 usdcIn;

    IPool        syrupUsdcPool;
    IPoolManager syrupUsdcPoolManager;

    function setUp() external {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 21185932);

        syrupUsdcPool         = IPool(syrupUSDCPool);                // NOTE: Address registry address is uppercase USDC
        syrupUsdcPoolManager  = IPoolManager(syrupUSDCPoolManager);  // NOTE: Address registry address is uppercase USDC
        syrupUSDCPD           = syrupUsdcPoolManager.poolDelegate();

        setupStrategies();
        setupPoolManagers();
        setupGlobals();

        start  = block.timestamp;
        usdcIn = 200_000e6;
    }

    function test_addStrategy_syrupUSDC_aaveStrategy() external {
        vm.prank(governor);
        syrupUsdcPoolManager.addStrategy(address(aaveStrategyFactory_), abi.encode(address(aUsdc)));

        IAaveStrategy aaveStrategy = IAaveStrategy(syrupUsdcPoolManager.strategyList(2));

        assertEq(syrupUsdcPoolManager.isStrategy(address(aaveStrategy)), true);

        uint256 totalAssets = syrupUsdcPool.totalAssets();

        vm.prank(syrupUSDCPD);
        aaveStrategy.fundStrategy(usdcIn);

        assertApproxEqAbs(syrupUsdcPool.totalAssets(),          totalAssets, 1);
        assertApproxEqAbs(aaveStrategy.assetsUnderManagement(), usdcIn,      1);

        // Accrue yield.
        vm.warp(start + 5 days);

        assertGt(aaveStrategy.assetsUnderManagement(), usdcIn);

        vm.prank(syrupUSDCPD);
        aaveStrategy.withdrawFromStrategy(usdcIn);

        assertGt(aaveStrategy.assetsUnderManagement(), 0);
    }

    function test_addStrategy_syrupUSDC_skyStrategy() external {
        vm.prank(governor);
        syrupUsdcPoolManager.addStrategy(address(skyStrategyFactory_), abi.encode(savingsUsds, usdsLitePSM));

        ISkyStrategy skyStrategy = ISkyStrategy(syrupUsdcPoolManager.strategyList(2));

        assertEq(syrupUsdcPoolManager.isStrategy(address(skyStrategy)), true);

        uint256 totalAssets = syrupUsdcPool.totalAssets();

        vm.prank(syrupUSDCPD);
        skyStrategy.fundStrategy(usdcIn);

        assertApproxEqAbs(syrupUsdcPool.totalAssets(),         totalAssets, 1);
        assertApproxEqAbs(skyStrategy.assetsUnderManagement(), usdcIn,      1);

        // Accrue yield.
        vm.warp(start + 5 days);

        assertGt(skyStrategy.assetsUnderManagement(), usdcIn);

        vm.prank(syrupUSDCPD);
        skyStrategy.withdrawFromStrategy(usdcIn);

        assertGt(skyStrategy.assetsUnderManagement(), 0);
    }

}
