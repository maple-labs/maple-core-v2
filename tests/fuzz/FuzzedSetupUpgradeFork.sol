// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IGlobals,
    IMapleProxyFactory,
    IMockERC20,
    IPool,
    IPoolDeployer,
    IPoolManager,
    IPoolPermissionManager,
    IStrategyManager
} from "../../contracts/interfaces/Interfaces.sol";

import { ModularReleaseBase } from "../protocol-upgrade/modular-release/ModularReleaseBase.sol";

import { FuzzedSetupFork } from "./FuzzedSetupFork.sol";

contract FuzzedSetupUpgradeFork is FuzzedSetupFork {

    string constant AAVE_STRATEGY_NAME       = "Aave Strategy USDC";
    string constant SKY_STRATEGY_NAME        = "Sky Strategy USDC";
    string constant ALLOCATION_STRATEGY_NAME = "DEX LP - USDC";

    uint256 constant UPGRADE_FORK_BLOCK = 26_185_500;

    function _setupUpgradeForkEnvironment() internal {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), UPGRADE_FORK_BLOCK);

        /**********************************************************************************************************************************/
        /*** Upgrade the protocol                                                                                                       ***/
        /**********************************************************************************************************************************/

        start = block.timestamp;

        ModularReleaseBase upgrade = new ModularReleaseBase();

        upgrade.upgradeProtocol({
            attachAaveAndSkyStrategies: true
        });

        /**********************************************************************************************************************************/
        /*** Take the upgraded pool as the first one, along with every strategy manager the release attached to it                      ***/
        /**********************************************************************************************************************************/

        poolManager1 = upgrade.poolManagers(0);
        pool1        = IPoolManager(poolManager1).pool();

        managedWalletShared                = upgrade.managedWallets(ALLOCATION_STRATEGY_NAME, 0);
        aaveStrategyManagerShared          = upgrade.strategyManagers(AAVE_STRATEGY_NAME);
        skyStrategyManagerShared           = upgrade.strategyManagers(SKY_STRATEGY_NAME);
        allocationStrategyManagerShared    = upgrade.strategyManagers(ALLOCATION_STRATEGY_NAME);
        aaveUnderlyingStrategyShared       = IStrategyManager(aaveStrategyManagerShared).underlyingStrategy();
        skyUnderlyingStrategyShared        = IStrategyManager(skyStrategyManagerShared).underlyingStrategy();
        allocationUnderlyingStrategyShared = IStrategyManager(allocationStrategyManagerShared).underlyingStrategy();

        /**********************************************************************************************************************************/
        /*** The local deployment is skipped, so the addresses the actions prank with have to come from the live protocol               ***/
        /**********************************************************************************************************************************/

        openTermLoanFactory  = upgrade.openTermLoanFactory();
        globals              = IGlobals(IMapleProxyFactory(openTermLoanFactory).mapleGlobals());
        governor             = globals.governor();
        operationalAdmin     = globals.operationalAdmin();
        treasury             = globals.mapleTreasury();
        fundsAsset           = IMockERC20(IPool(pool1).asset());
        poolDelegate         = IPoolManager(poolManager1).poolDelegate();
        aaveStrategyDelegate = IStrategyManager(aaveStrategyManagerShared).strategyDelegate();
        skyStrategyDelegate  = IStrategyManager(skyStrategyManagerShared).strategyDelegate();
        strategyDelegate     = IStrategyManager(allocationStrategyManagerShared).strategyDelegate();

        /**********************************************************************************************************************************/
        /*** Deploy the second pool on the upgraded protocol and attach the same strategy managers to it                                ***/
        /**********************************************************************************************************************************/

        poolManagerFactory    = upgrade.poolManagerFactory();
        queueWMFactory        = upgrade.withdrawalManagerQueueFactory();
        poolDeployer          = IPoolDeployer(upgrade.poolDeployerV5());
        poolPermissionManager = IPoolPermissionManager(upgrade.poolPermissionManager());

        strategyFactories.push(upgrade.openTermLoanManagerFactory());

        (pool2, poolManager2) = _createPoolSharingStrategy("poolDelegate2", aaveStrategyManagerShared);

        _addSharedStrategyManager(poolManager2, skyStrategyManagerShared);
        _addSharedStrategyManager(poolManager2, allocationStrategyManagerShared);

        openTermLoanManagerPool1 = IPoolManager(poolManager1).strategyList(0);
        openTermLoanManagerPool2 = IPoolManager(poolManager2).strategyList(0);

        /**********************************************************************************************************************************/
        /*** Seed both pools and lift the release caps the fuzzed amounts would otherwise run into                                      ***/
        /**********************************************************************************************************************************/

        lpDeposit = 1_000_000e6;

        setLiquidityCap(poolManager1, type(uint256).max);

        vm.startPrank(governor);
        IPoolManager(poolManager1).setStrategyCap(aaveStrategyManagerShared, type(uint256).max);
        IPoolManager(poolManager1).setStrategyCap(skyStrategyManagerShared, type(uint256).max);
        IPoolManager(poolManager1).setStrategyCap(allocationStrategyManagerShared, type(uint256).max);
        vm.stopPrank();

        vm.startPrank(operationalAdmin);
        IStrategyManager(aaveStrategyManagerShared).setStrategyLiquidityCap(type(uint256).max);
        IStrategyManager(skyStrategyManagerShared).setStrategyLiquidityCap(type(uint256).max);
        IStrategyManager(allocationStrategyManagerShared).setStrategyLiquidityCap(type(uint256).max);
        vm.stopPrank();

        setPermissions(allocationUnderlyingStrategyShared, managedWalletShared, true, true, true);
        setDeploymentCap(allocationUnderlyingStrategyShared, managedWalletShared, type(uint256).max);

        for (uint256 i; i < 5; ++i) {
            address lp = makeAddr(string(abi.encodePacked("lp", vm.toString(i))));

            lps.push(lp);

            deposit(pool1, lp, lpDeposit);
            deposit(pool2, lp, lpDeposit);
        }
    }

}
