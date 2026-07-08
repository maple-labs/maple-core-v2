// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IAssetController } from "../../../modules/controller/contracts/interfaces/IAssetController.sol";
import { ICompositeToken }  from "../../../modules/controller/contracts/interfaces/ICompositeToken.sol";
import { IMapleGlobals }    from "../../../modules/globals/contracts/interfaces/IMapleGlobals.sol";

import {
    IBitcoinStrategy,
    IGlobals,
    IGovernorTimelock,
    IMapleProxyFactory,
    IPoolDeployer,
    IPoolManager,
    IPoolPermissionManager,
    ISyrupBitcoinRouter,
    IWithdrawalManagerQueue
} from "../../../contracts/interfaces/Interfaces.sol";

import {
    PoolConfigParams,
    PoolManagerInitParams,
    StrategyDeployParams,
    StrategyManagerParams
} from "../../../contracts/interfaces/Interfaces.sol";

import { Runner } from "../../../contracts/Runner.sol";

import { UpgradeAddressRegistry } from "../UpgradeAddressRegistry.sol";

contract SyrupBTCProtocolUpgradeBase is Runner, UpgradeAddressRegistry {

    address bitcoinRouterRedeemer = makeAddr("bitcoinRouterRedeemer");

    uint256 delegateManagementFeeRate = 0.333e6; // 3.33%
    uint256 liquidityCap              = 100e8;
    uint256 startingTime;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 23528541);

        startingTime = block.timestamp;

        upgradeProtocol();
    }

    // TODO: Update upgrade procedure after modular strategy release.
    function upgradeProtocol() internal {
        // Step -2: Deploy new pool deployer

        address poolDeployer = deployFromFile("Contracts@28", "PoolDeployer", abi.encode(globals));

        // Step -1: Whitelist the new pool deployer.

        vm.startPrank(governor);
        IMapleGlobals(globals).setCanDeployFrom(poolManagerFactory,            poolDeployer, true);
        IMapleGlobals(globals).setCanDeployFrom(withdrawalManagerQueueFactory, poolDeployer, true);
        IMapleGlobals(globals).setCanDeployFrom(bitcoinStrategyFactory,        poolDeployer, true);
        vm.stopPrank();

        // Step 0: Deploy new version of pool manager

        poolManagerV500Implementation = deployFromFile("Contracts@28", "PoolManager");
        poolManagerV500Initializer    = deployFromFile("Contracts@28", "PoolManagerInitializer");
        poolManagerV500Migrator       = deployFromFile("Contracts@28", "PoolManagerMigrator");

        // Step 1: Deploy new version of withdrawal manager queue

        mapleWithdrawalManagerV200Implementation = deployFromFile("Contracts@28", "WithdrawalManagerQueue");
        mapleWithdrawalManagerV200Initializer    = deployFromFile("Contracts@28", "WithdrawalManagerQueueInitializer");
        mapleWithdrawalManagerV200Migrator       = deployFromFile("Contracts@28", "WithdrawalManagerQueueMigrator");

        // Step 2: Deploy bitcoin strategy factory

        bitcoinStrategyFactory            = deployFromFile("Contracts@25", "StrategyFactory", abi.encode(globals));
        bitcoinStrategyV100Implementation = deployFromFile("Contracts@25", "BitcoinStrategy");
        bitcoinStrategyV100Initializer    = deployFromFile("Contracts@25", "BitcoinStrategyInitializer");

        // Step 3: Deploy composite token

        compositeTokenV100Implementation = deployFromFile("Contracts@25", "CompositeToken");
        compositeTokenV100Initializer    = deployFromFile("Contracts@25", "CompositeTokenInitializer");
        compositeTokenProxy              = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                globals,
                compositeTokenV100Implementation,
                compositeTokenV100Initializer,
                abi.encodeWithSignature("initialize(string,string,uint8)", "Synthetic Bitcoin", "synthBTC", 8)
            )
        );

        // Step 4: Operational admin whitelists contracts on globals

        vm.startPrank(operationalAdmin);
        IGlobals(globals).setValidPoolDelegate(syrupBitcoinPoolDelegate, true);

        IGlobals(globals).setValidInstanceOf("COMPOSITE_DEPOSIT_ASSET", wbtc,                   true);
        IGlobals(globals).setValidInstanceOf("COMPOSITE_POOL_ASSET",    compositeTokenProxy,    true);
        IGlobals(globals).setValidInstanceOf("STRATEGY_FACTORY",        bitcoinStrategyFactory, true);
        vm.stopPrank();

        // Step 5: Governor registers new pool manager version, enables upgrade path and sets default version.
        //         Governor registers new withdrawal manager version, enables upgrade path and sets default version.
        //         Governor registers new bitcoin strategy version and sets default version
        //         Governor whitelists composite token as pool asset

        address[] memory targets = new address[](9);
        bytes[]   memory data    = new bytes[](9);

        targets[0] = poolManagerFactory;
        targets[1] = poolManagerFactory;
        targets[2] = poolManagerFactory;
        targets[3] = withdrawalManagerQueueFactory;
        targets[4] = withdrawalManagerQueueFactory;
        targets[5] = withdrawalManagerQueueFactory;
        targets[6] = bitcoinStrategyFactory;
        targets[7] = bitcoinStrategyFactory;
        targets[8] = globals;

        data[0] = abi.encodeWithSelector(
            IMapleProxyFactory.registerImplementation.selector,
            500,
            poolManagerV500Implementation,
            poolManagerV500Initializer
        );

        data[1] = abi.encodeWithSelector(IMapleProxyFactory.enableUpgradePath.selector,
            400,
            500,
            poolManagerV500Migrator
        );

        data[2] = abi.encodeWithSelector(IMapleProxyFactory.setDefaultVersion.selector, 500);

        data[3] = abi.encodeWithSelector(
            IMapleProxyFactory.registerImplementation.selector,
            200,
            mapleWithdrawalManagerV200Implementation,
            mapleWithdrawalManagerV200Initializer
        );

        data[4] = abi.encodeWithSelector(
            IMapleProxyFactory.enableUpgradePath.selector,
            100,
            200,
            mapleWithdrawalManagerV200Migrator
        );

        data[5] = abi.encodeWithSelector(IMapleProxyFactory.setDefaultVersion.selector, 200);

        data[6] = abi.encodeWithSelector(
            IMapleProxyFactory.registerImplementation.selector,
            100,
            bitcoinStrategyV100Implementation,
            bitcoinStrategyV100Initializer
        );

        data[7] = abi.encodeWithSelector(IMapleProxyFactory.setDefaultVersion.selector, 100);
        data[8] = abi.encodeWithSelector(IMapleGlobals.setValidPoolAsset.selector, compositeTokenProxy, true);

        uint256[] memory proposalIds = scheduleProposals(targets, data);
        executeProposals(proposalIds, targets, data);

        // Step 6: Deploy MaplePool

        address[] memory strategyFactories      = new address[](3);
        bytes[]   memory strategyDeploymentData = new bytes[](3);

        strategyFactories[0]      = bitcoinStrategyFactory;
        strategyFactories[1]      = bitcoinStrategyFactory;
        strategyFactories[2]      = bitcoinStrategyFactory;
        strategyDeploymentData[0] = new bytes(0);
        strategyDeploymentData[1] = new bytes(0);
        strategyDeploymentData[2] = new bytes(0);

        vm.prank(syrupBitcoinPoolDelegate);
        syrupBitcoinPoolManager = IPoolDeployer(poolDeployer).deployPool({
            poolManagerFactory:       poolManagerFactory,
            withdrawalManagerFactory: withdrawalManagerQueueFactory,
            poolManagerInitParams:    PoolManagerInitParams({
                asset:         compositeTokenProxy,
                initialSupply: 0,
                name:          "Syrup Bitcoin",
                symbol:        "syrupBTC"
            }),
            poolConfigParams: PoolConfigParams({
                poolPermissionManager:     address(poolPermissionManager),
                delegateManagementFeeRate: delegateManagementFeeRate,
                liquidityCap:              liquidityCap
            }),
            strategiesParams:       buildStrategyDeployParams(strategyFactories, strategyDeploymentData, "Bitcoin Strategies"),
            strategyManagersParams: new StrategyManagerParams[](0)
        });

        syrupBitcoinPool = IPoolManager(syrupBitcoinPoolManager).pool();
        bitcoinStrategy1 = IPoolManager(syrupBitcoinPoolManager).strategyList(0);
        bitcoinStrategy2 = IPoolManager(syrupBitcoinPoolManager).strategyList(1);
        bitcoinStrategy3 = IPoolManager(syrupBitcoinPoolManager).strategyList(2);

        // Step 7: Deploy AssetControllerOracle

        assetPriceOracleV100Implementation = deployFromFile("Contracts@25", "AssetControllerOracle");
        assetPriceOracleProxy              = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                globals,
                assetPriceOracleV100Implementation,
                address(0),
                ""
            )
        );

        // Step 8: Deploy SyrupBitcoinRouter

        bitcoinRouterV100Implementation = deployFromFile("Contracts@25", "SyrupBitcoinRouter");
        bitcoinRouterV100Initializer    = deployFromFile("Contracts@25", "SyrupBitcoinRouterInitializer");
        bitcoinRouterProxy              = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                globals,
                bitcoinRouterV100Implementation,
                bitcoinRouterV100Initializer,
                abi.encodeWithSignature("initialize(address)", syrupBitcoinPoolManager)
            )
        );

        // Step 9: Operational admin whitelists contracts on globals

        vm.startPrank(operationalAdmin);
        IGlobals(globals).setValidInstanceOf("CONTROLLER_ORACLE",    assetPriceOracleProxy, true);
        IGlobals(globals).setValidInstanceOf("SYRUP_BTC_ROUTER",     bitcoinRouterProxy,    true);
        IGlobals(globals).setValidInstanceOf("BITCOIN_STRATEGY",     bitcoinStrategy1,      true);
        IGlobals(globals).setValidInstanceOf("BITCOIN_STRATEGY",     bitcoinStrategy2,      true);
        IGlobals(globals).setValidInstanceOf("BITCOIN_STRATEGY",     bitcoinStrategy3,      true);
        vm.stopPrank();

        // Step 10: Deploy AssetController

        assetControllerV100Implementation = deployFromFile("Contracts@25", "AssetController");
        assetControllerV100Initializer    = deployFromFile("Contracts@25", "AssetControllerInitializer");
        assetControllerProxy              = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                globals,
                assetControllerV100Implementation,
                assetControllerV100Initializer,
                abi.encodeWithSignature(
                    "initialize(address,address)",
                    assetPriceOracleProxy,
                    bitcoinRouterProxy
                )
            )
        );

        // Step 11: Operational admin whitelists asset controller on globals
        //          Operational admin sets WBTC as valid asset to be used by asset controller
        //          Operational admin sets asset controller on router and bitcoin strategies
        //          Operational admin sets permissions on the bitcoin strategies
        //          Operational admin sets pool permission level to be function level and sets bitmaps and lender bitmaps for the router
        //          Operational admin sets manual withdrawal for the router

        // Step 11.1: Operational admin whitelists asset controller on globals

        vm.startPrank(operationalAdmin);

        IGlobals(globals).setValidInstanceOf("ASSET_CONTROLLER", assetControllerProxy, true);

        // Step 11.2: Operational admin sets WBTC as valid asset to be used by asset controller

        address[] memory addresses = new address[](3);
        bool[]    memory allowed   = new bool[](3);

        addresses[0] = bitcoinStrategy1;
        addresses[1] = bitcoinStrategy2;
        addresses[2] = bitcoinStrategy3;
        allowed[0]   = true;
        allowed[1]   = true;
        allowed[2]   = true;

        IAssetController(assetControllerProxy).setStrategies(addresses, allowed);

        // Step 11.3: Operational admin sets asset controller on the router and bitcoin strategies

        ISyrupBitcoinRouter(bitcoinRouterProxy).setAssetController(wbtc, assetControllerProxy);
        IBitcoinStrategy(bitcoinStrategy1).setAssetController(wbtc, assetControllerProxy);
        IBitcoinStrategy(bitcoinStrategy2).setAssetController(wbtc, assetControllerProxy);
        IBitcoinStrategy(bitcoinStrategy3).setAssetController(wbtc, assetControllerProxy);

        // Step 11.4: Operational admin sets permissions on the bitcoin strategies

        // NOTE: To avoid stack too deep
        {
            address[] memory strategyManager1        = new address[](1);
            bool[]    memory allowedStrategyManager1 = new bool[](1);

            strategyManager1[0]        = bitcoinStrategy1Manager;
            allowedStrategyManager1[0] = true;

            address[] memory strategyManager2        = new address[](1);
            bool[]    memory allowedStrategyManager2 = new bool[](1);

            strategyManager2[0]        = bitcoinStrategy2Manager;
            allowedStrategyManager2[0] = true;

            address[] memory strategyManager3        = new address[](1);
            bool[]    memory allowedStrategyManager3 = new bool[](1);

            strategyManager3[0]        = bitcoinStrategy3Manager;
            allowedStrategyManager3[0] = true;

            IBitcoinStrategy(bitcoinStrategy1).setPermissions(
                strategyManager1,
                allowedStrategyManager1,
                allowedStrategyManager1,
                allowedStrategyManager1
            );

            IBitcoinStrategy(bitcoinStrategy2).setPermissions(
                strategyManager2,
                allowedStrategyManager2,
                allowedStrategyManager2,
                allowedStrategyManager2
            );

            IBitcoinStrategy(bitcoinStrategy3).setPermissions(
                strategyManager3,
                allowedStrategyManager3,
                allowedStrategyManager3,
                allowedStrategyManager3
            );
        }

        // Step 11.5: Operational admin sets pool permission level to be function level and sets bitmaps and lender bitmaps for the router

        IPoolPermissionManager(poolPermissionManager).setPoolPermissionLevel(syrupBitcoinPoolManager, 1);

        bytes32[] memory functionIdsToSet = new bytes32[](11);
        uint256[] memory bitmaps          = new uint256[](11);

        uint256 bitmap              = 2 ** 5;
        uint256 bitmapRequestRedeem = 2 ** 6;

        functionIdsToSet[0]  = "P:deposit";
        functionIdsToSet[1]  = "P:depositWithPermit";
        functionIdsToSet[2]  = "P:mint";
        functionIdsToSet[3]  = "P:mintWithPermit";
        functionIdsToSet[4]  = "P:redeem";
        functionIdsToSet[5]  = "P:withdraw";
        functionIdsToSet[6]  = "P:transfer";
        functionIdsToSet[7]  = "P:transferFrom";
        functionIdsToSet[8]  = "P:removeShares";
        functionIdsToSet[9]  = "P:requestRedeem";
        functionIdsToSet[10] = "P:requestWithdraw";

        bitmaps[0]  = bitmap;
        bitmaps[1]  = bitmap;
        bitmaps[2]  = bitmap;
        bitmaps[3]  = bitmap;
        bitmaps[4]  = bitmap;
        bitmaps[5]  = bitmap;
        bitmaps[6]  = 0;
        bitmaps[7]  = 0;
        bitmaps[8]  = bitmap;
        bitmaps[9]  = bitmapRequestRedeem;
        bitmaps[10] = bitmap;

        IPoolPermissionManager(poolPermissionManager).setPoolBitmaps(syrupBitcoinPoolManager, functionIdsToSet, bitmaps);

        addresses = new address[](1);
        bitmaps   = new uint256[](1);

        addresses[0] = bitcoinRouterProxy;
        bitmaps[0]   = bitmap;

        IPoolPermissionManager(poolPermissionManager).setLenderBitmaps(addresses, bitmaps);

        // Step 11.6: Operational admin sets manual withdrawal for the router

        address withdrawalManager = IPoolManager(syrupBitcoinPoolManager).withdrawalManager();
        IWithdrawalManagerQueue(withdrawalManager).setManualWithdrawal(bitcoinRouterProxy, true);

        vm.stopPrank();

        // Step 12: Timelock allows composite token to be held by pool, asset controller, bitcoin router and bitcoin strategies
        //          Timelock allows WBTC to be wrapped, unwrapped, deployed and reconciled
        //          Timelock sets asset controller on composite token

        targets = new address[](3);
        data    = new bytes[](3);

        targets[0] = compositeTokenProxy;
        targets[1] = assetControllerProxy;
        targets[2] = compositeTokenProxy;

        addresses = new address[](6);
        allowed   = new bool[](6);

        addresses[0] = syrupBitcoinPool;
        addresses[1] = assetControllerProxy;
        addresses[2] = bitcoinRouterProxy;
        addresses[3] = bitcoinStrategy1;
        addresses[4] = bitcoinStrategy2;
        addresses[5] = bitcoinStrategy3;

        allowed[0] = true;
        allowed[1] = true;
        allowed[2] = true;
        allowed[3] = true;
        allowed[4] = true;
        allowed[5] = true;

        data[0] = abi.encodeWithSelector(ICompositeToken.allowAddresses.selector, addresses, allowed);

        addresses = new address[](1);
        allowed   = new bool[](1);

        addresses[0] = wbtc;
        allowed[0]   = true;

        data[1] = abi.encodeWithSelector(IAssetController.setAssets.selector, addresses, allowed, allowed, allowed, allowed);

        addresses[0] = assetControllerProxy;
        allowed[0]   = true;

        data[2] = abi.encodeWithSelector(ICompositeToken.setAssetControllers.selector, addresses, allowed);

        proposalIds = scheduleProposals(targets, data);
        executeProposals(proposalIds, targets, data);
    }

    function scheduleProposals(address[] memory targets, bytes[] memory data) internal returns (uint256[] memory proposalIds) {
        uint256 latestProposalId = IGovernorTimelock(timelock).latestProposalId();

        vm.prank(daoMultisig);
        IGovernorTimelock(timelock).scheduleProposals(targets, data);

        proposalIds = new uint256[](targets.length);
        for (uint256 i = 0; i < targets.length; i++) {
            proposalIds[i] = latestProposalId + i + 1;
        }
    }

    function executeProposals(uint256[] memory proposalIds, address[] memory targets, bytes[] memory data) internal {
        uint256 currentTimestamp = block.timestamp;
        vm.warp(currentTimestamp + 3 days);

        vm.prank(executor);
        IGovernorTimelock(timelock).executeProposals(proposalIds, targets, data);
    }

    function buildStrategyDeployParams(
        address[] memory strategyFactories,
        bytes[]   memory strategyData,
        string    memory name
    )
        internal pure returns (StrategyDeployParams[] memory strategies)
    {
        strategies = new StrategyDeployParams[](strategyFactories.length);

        for (uint256 i; i < strategyFactories.length; i++) {
            strategies[i] = StrategyDeployParams({
                factory:        strategyFactories[i],
                cap:            type(uint256).max,
                salt:           keccak256(abi.encode(name, i)),
                deploymentData: strategyData[i]
            });
        }
    }

}
