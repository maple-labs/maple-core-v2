// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { Runner } from "../../../contracts/Runner.sol";

import {
    IAssetController,
    IBitcoinStrategy,
    ICompositeToken,
    IGlobals,
    IMapleProxyFactory,
    IPoolDeployer,
    IPoolManager,
    IPoolPermissionManager,
    ISyrupBitcoinRouter
} from "../../../contracts/interfaces/Interfaces.sol";

import { UpgradeAddressRegistry } from "../UpgradeAddressRegistry.sol";

contract SyrupBTCProtocolUpgradeBase is Runner, UpgradeAddressRegistry {

    address bitcoinRouterRedeemer     = makeAddr("bitcoinRouterRedeemer");
    address poolDelegate              = makeAddr("poolDelegate");
    address strategyManager           = makeAddr("strategyManager");

    uint256 bootstrapMint             = 0.0001e8;
    uint256 delegateManagementFeeRate = 0.333e6;  // 3.33%
    uint256 liquidityCap              = 100e8;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"));

        upgradeProtocol();
    }

    function upgradeProtocol() internal {
        registerNewWithdrawalManagerVersion();
        deployAndSetupSyrupBTC();
    }

    function registerNewWithdrawalManagerVersion() internal {
        mapleWithdrawalManagerV200Implementation = deployFromFile("Contracts@7", "WithdrawalManagerQueue");
        mapleWithdrawalManagerV200Initializer    = deployFromFile("Contracts@7", "WithdrawalManagerQueueInitializer");
        mapleWithdrawalManagerV200Migrator       = deployFromFile("Contracts@7", "WithdrawalManagerQueueMigrator");

        vm.startPrank(governor);

        IMapleProxyFactory(withdrawalManagerQueueFactory).registerImplementation(
            200,
            mapleWithdrawalManagerV200Implementation,
            mapleWithdrawalManagerV200Initializer
        );

        IMapleProxyFactory(withdrawalManagerQueueFactory).enableUpgradePath(100, 200, mapleWithdrawalManagerV200Migrator);
        IMapleProxyFactory(withdrawalManagerQueueFactory).setDefaultVersion(200);

        vm.stopPrank();

        assertEq(IMapleProxyFactory(withdrawalManagerQueueFactory).defaultVersion(), 200);
        assertEq(IMapleProxyFactory(withdrawalManagerQueueFactory).migratorForPath(100, 200), mapleWithdrawalManagerV200Migrator);
    }

    function deployAndSetupSyrupBTC() internal {
        // Step 1: Deploy BitcoinStrategyFactory

        bitcoinStrategyFactory        = deployFromFile("Contracts@25", "StrategyFactory", abi.encode(globals));
        bitcoinStrategyImplementation = deployFromFile("Contracts@25", "BitcoinStrategy");
        bitcoinStrategyInitializer    = deployFromFile("Contracts@25", "BitcoinStrategyInitializer");

        vm.startPrank(governor);
        IMapleProxyFactory(bitcoinStrategyFactory).registerImplementation(100, bitcoinStrategyImplementation, bitcoinStrategyInitializer);
        IMapleProxyFactory(bitcoinStrategyFactory).setDefaultVersion(100);
        vm.stopPrank();

        // Step 2: Deploy Composite Token

        compositeTokenImplementation = deployFromFile("Contracts@25", "CompositeToken");
        compositeTokenInitializer    = deployFromFile("Contracts@25", "CompositeTokenInitializer");
        compositeTokenProxy          = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                globals,
                compositeTokenImplementation,
                compositeTokenInitializer,
                abi.encodeWithSignature("initialize(string,string,uint8)", "Synthetic Bitcoin", "synthBTC", 8)
            )
        );

        // Step 3: Whitelist composite token on globals, whitelist pool delegate, whitelist WBTC and bitcoin strategy factory
        //         and set bootstrap mint

        vm.prank(governor);
        IGlobals(globals).setValidPoolAsset(compositeTokenProxy, true);

        vm.startPrank(operationalAdmin);
        IGlobals(globals).setValidPoolDelegate(poolDelegate, true);

        IGlobals(globals).setValidInstanceOf("COMPOSITE_DEPOSIT_ASSET", wbtc,                   true);
        IGlobals(globals).setValidInstanceOf("COMPOSITE_POOL_ASSET",    compositeTokenProxy,    true);
        IGlobals(globals).setValidInstanceOf("STRATEGY_FACTORY",        bitcoinStrategyFactory, true);
        IGlobals(globals).setValidInstanceOf("SYRUP_BTC_REDEEMER",      bitcoinRouterRedeemer,  true);

        IGlobals(globals).setBootstrapMint(compositeTokenProxy, bootstrapMint);
        vm.stopPrank();

        // Step 4: Deploy MaplePool

        address[] memory strategyFactories      = new address[](2);
        bytes[]   memory strategyDeploymentData = new bytes[](2);

        strategyFactories[0]      = bitcoinStrategyFactory;
        strategyFactories[1]      = bitcoinStrategyFactory;
        strategyDeploymentData[0] = new bytes(0);
        strategyDeploymentData[1] = new bytes(0);

        uint256[4] memory configParams = [liquidityCap, delegateManagementFeeRate, uint256(0), uint256(0)];

        vm.prank(poolDelegate);
        syrupBitcoinPoolManager = IPoolDeployer(poolDeployerV4).deployPool(
            poolManagerFactory,
            withdrawalManagerQueueFactory,
            strategyFactories,
            strategyDeploymentData,
            compositeTokenProxy,
            poolPermissionManager,
            "Syrup Bitcoin",
            "syrupBTC",
            configParams
        );

        syrupBitcoinPool = IPoolManager(syrupBitcoinPoolManager).pool();
        bitcoinStrategy1 = IPoolManager(syrupBitcoinPoolManager).strategyList(0);
        bitcoinStrategy2 = IPoolManager(syrupBitcoinPoolManager).strategyList(1);

        // Step 5: Deploy AssetControllerOracle

        assetPriceOracleImplementation = deployFromFile("Contracts@25", "AssetControllerOracle");
        assetPriceOracleProxy          = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                globals,
                assetPriceOracleImplementation,
                address(0),
                ""
            )
        );

        // Step 6: Deploy SyrupBitcoinRouter

        bitcoinRouterImplementation = deployFromFile("Contracts@25", "SyrupBitcoinRouter");
        bitcoinRouterInitializer    = deployFromFile("Contracts@25", "SyrupBitcoinRouterInitializer");
        bitcoinRouterProxy          = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                globals,
                bitcoinRouterImplementation,
                bitcoinRouterInitializer,
                abi.encodeWithSignature("initialize(address)", syrupBitcoinPoolManager)
            )
        );

        // Step 7: Whitelist contracts on globals

        vm.startPrank(operationalAdmin);
        IGlobals(globals).setValidInstanceOf("CONTROLLER_ORACLE",    assetPriceOracleProxy, true);
        IGlobals(globals).setValidInstanceOf("COMPOSITE_POOL_ASSET", compositeTokenProxy,   true);
        IGlobals(globals).setValidInstanceOf("SYRUP_BTC_ROUTER",     bitcoinRouterProxy,    true);
        IGlobals(globals).setValidInstanceOf("BITCOIN_STRATEGY",     bitcoinStrategy1,      true);
        IGlobals(globals).setValidInstanceOf("BITCOIN_STRATEGY",     bitcoinStrategy2,      true);
        vm.stopPrank();

        // Step 8: Deploy AssetController

        assetControllerImplementation = deployFromFile("Contracts@25", "AssetController");
        assetControllerInitializer    = deployFromFile("Contracts@25", "AssetControllerInitializer");
        assetControllerProxy          = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                globals,
                assetControllerImplementation,
                assetControllerInitializer,
                abi.encodeWithSignature(
                    "initialize(address,address)",
                    assetPriceOracleProxy,
                    bitcoinRouterProxy
                )
            )
        );

        // Step 9: Whitelist asset controller on globals

        vm.prank(operationalAdmin);
        IGlobals(globals).setValidInstanceOf("ASSET_CONTROLLER", assetControllerProxy, true);

        // Step 10: Allow composite token to be held by pool, asset controller, bitcoin router and bitcoin strategy

        address[] memory addresses = new address[](5);
        bool[]    memory allowed   = new bool[](5);

        addresses[0] = syrupBitcoinPool;
        addresses[1] = assetControllerProxy;
        addresses[2] = bitcoinRouterProxy;
        addresses[3] = bitcoinStrategy1;
        addresses[4] = bitcoinStrategy2;

        allowed[0] = true;
        allowed[1] = true;
        allowed[2] = true;
        allowed[3] = true;
        allowed[4] = true;

        vm.prank(governor);
        ICompositeToken(compositeTokenProxy).allowAddresses(addresses, allowed);

        // Step 11: Allow WBTC to be wrapped, unwrapped, deployed and reconciled

        addresses = new address[](1);
        allowed   = new bool[](1);

        addresses[0] = wbtc;
        allowed[0]   = true;

        vm.prank(governor);
        IAssetController(assetControllerProxy).setAssets(addresses, allowed, allowed, allowed, allowed);

        // Step 12: Whitelist bitcoin strategy on asset controller

        addresses = new address[](2);
        allowed   = new bool[](2);

        addresses[0] = bitcoinStrategy1;
        addresses[1] = bitcoinStrategy2;
        allowed[0]   = true;
        allowed[1]   = true;

        vm.prank(operationalAdmin);
        IAssetController(assetControllerProxy).setStrategies(addresses, allowed);

        // Step 13: Set asset controller on composite token, bitcoin router and bitcoin strategy

        addresses = new address[](1);
        allowed   = new bool[](1);

        addresses[0] = assetControllerProxy;
        allowed[0]   = true;

        vm.prank(governor);
        ICompositeToken(compositeTokenProxy).setAssetControllers(addresses, allowed);

        vm.startPrank(operationalAdmin);
        ISyrupBitcoinRouter(bitcoinRouterProxy).setAssetController(wbtc, assetControllerProxy);
        IBitcoinStrategy(bitcoinStrategy1).setAssetController(wbtc, assetControllerProxy);
        IBitcoinStrategy(bitcoinStrategy2).setAssetController(wbtc, assetControllerProxy);
        vm.stopPrank();

        // Step 14: Allow strategy manager to deploy, schedule and reconcile all strategies

        addresses[0] = strategyManager;
        allowed[0]   = true;

        vm.startPrank(operationalAdmin);
        IBitcoinStrategy(bitcoinStrategy1).setPermissions(addresses, allowed, allowed, allowed);
        IBitcoinStrategy(bitcoinStrategy2).setPermissions(addresses, allowed, allowed, allowed);
        vm.stopPrank();

        // Step 15: Whitelist strategy manager on pool permission manager

        addresses = new address[](1);
        allowed   = new bool[](1);

        addresses[0] = strategyManager;
        allowed[0]   = true;

        vm.prank(operationalAdmin);
        IPoolPermissionManager(poolPermissionManager).setLenderAllowlist(bitcoinRouterProxy, addresses, allowed);

        bytes32[] memory functionIdsToSet = new bytes32[](11);
        uint256[] memory bitmaps          = new uint256[](11);

        uint256 bitmap = 2 ** 5;

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
        bitmaps[9]  = bitmap;
        bitmaps[10] = bitmap;

        // Step 16: Set pool permission level to be function level and set bitmaps

        vm.startPrank(operationalAdmin);
        IPoolPermissionManager(poolPermissionManager).setPoolPermissionLevel(syrupBitcoinPoolManager, 1);
        IPoolPermissionManager(poolPermissionManager).setPoolBitmaps(syrupBitcoinPoolManager, functionIdsToSet, bitmaps);
        vm.stopPrank();
    }

}
