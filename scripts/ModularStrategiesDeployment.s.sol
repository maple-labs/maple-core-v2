// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

import { console, Script } from "../modules/forge-std/src/Script.sol";

import {
    AaveV3StrategyInitializerParams,
    AllocationStrategyInitializerParams,
    IStrategyDeployer
} from "../contracts/interfaces/Interfaces.sol";

import { UpgradeAddressRegistry } from "../tests/protocol-upgrade/UpgradeAddressRegistry.sol";

contract ModularStrategiesDeployment is UpgradeAddressRegistry, Script {

    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDG = 0xe343167631d89B6Ffc58B88d6b7fB0228795491D;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    uint256 constant BOOTSTRAP_MINT = 1e6;
    uint256 constant YIELD_CAP      = 0;

    uint32 constant PROTOCOL_FEE_RATE      = 0.1e6;
    uint32 constant MISL_PROTOCOL_FEE_RATE = 0.08333e6;

    function run() public {
        deployAllocation("DEX LP - USDC",            "DEX LP",          dexLpUSDCDelegate,     USDC, PROTOCOL_FEE_RATE);
        deployAllocation("PYUSD - USDC",             "U.S. Treasuries", pyusdUSDCDelegate,     USDC, PROTOCOL_FEE_RATE);
        deployAllocation("PYUSD - USDC (PPOA only)", "U.S. Treasuries", pyusdMislUSDCDelegate, USDC, MISL_PROTOCOL_FEE_RATE);
        deployAllocation("USDtb - USDC",             "U.S. Treasuries", usdtbUSDCDelegate,     USDC, PROTOCOL_FEE_RATE);
        deployAllocation("USTB - USDC",              "U.S. Treasuries", ustbUSDCDelegate,      USDC, PROTOCOL_FEE_RATE);
        deployAllocation("USTB - USDC (PPOA only)",  "U.S. Treasuries", ustbMislUSDCDelegate,  USDC, MISL_PROTOCOL_FEE_RATE);
        deployAllocation("DeFi - USDC",              "DeFi",            defiUSDCDelegate,      USDC, PROTOCOL_FEE_RATE);
        deployAave("Aave V3 - USDC",                 "DeFi",            aaveV3USDCDelegate,    USDC, aUsdc, PROTOCOL_FEE_RATE);

        deployAllocation("DEX LP - USDT",            "DEX LP",          dexLpUSDTDelegate,     USDT, PROTOCOL_FEE_RATE);
        deployAllocation("Basis - USDT",             "Maple Trading",   basisUSDTDelegate,     USDT, PROTOCOL_FEE_RATE);
        deployAllocation("PYUSD - USDT",             "U.S. Treasuries", pyusdUSDTDelegate,     USDT, PROTOCOL_FEE_RATE);
        deployAllocation("USDtb - USDT",             "U.S. Treasuries", usdtbUSDTDelegate,     USDT, PROTOCOL_FEE_RATE);
        deployAllocation("USTB - USDT",              "U.S. Treasuries", ustbUSDTDelegate,      USDT, PROTOCOL_FEE_RATE);
        deployAllocation("DeFi - USDT",              "DeFi",            defiUSDTDelegate,      USDT, PROTOCOL_FEE_RATE);
        deployAave("Aave V3 - USDT",                 "DeFi",            aaveV3USDTDelegate,    USDT, aUsdt, PROTOCOL_FEE_RATE);

        deployAllocation("DEX LP - USDG",            "DEX LP",          dexLpUSDGDelegate,     USDG, PROTOCOL_FEE_RATE);
        deployAllocation("PYUSD - USDG",             "U.S. Treasuries", pyusdUSDGDelegate,     USDG, PROTOCOL_FEE_RATE);
        deployAllocation("DeFi - USDG",              "DeFi",            defiUSDGDelegate,      USDG, PROTOCOL_FEE_RATE);
    }

    function deployAllocation(
        string memory name,
        string memory metadata,
        address delegate,
        address asset,
        uint32 protocolFeeRate
    )
        internal
    {
        bytes memory deploymentData = abi.encode(
            AllocationStrategyInitializerParams({
                fundsAsset: asset,
                strategyMetadata: metadata,
                strategyDelegateFeeRate: 0,
                strategyProtocolFeeRate: protocolFeeRate,
                yieldCap: YIELD_CAP
            })
        );

        deploy(name, delegate, asset, allocationStrategyFactory, deploymentData);
    }

    function deployAave(
        string memory name,
        string memory metadata,
        address delegate,
        address asset,
        address aaveToken,
        uint32 protocolFeeRate
    )
        internal
    {
        bytes memory deploymentData = abi.encode(
            AaveV3StrategyInitializerParams({
                aaveToken: aaveToken,
                strategyDelegateFeeRate: 0,
                strategyProtocolFeeRate: protocolFeeRate,
                referralCode: 0,
                useVirtualUnderlyingBalance: true,
                strategyMetadata: metadata
            })
        );

        deploy(name, delegate, asset, modularAaveStrategyFactory, deploymentData);
    }

    function deploy(
        string memory name,
        address delegate,
        address asset,
        address strategyFactory,
        bytes memory deploymentData
    )
        internal
    {
        vm.startBroadcast(delegate);

        ERC20Helper.approve(asset, strategyDeployerV100, BOOTSTRAP_MINT);

        (address strategyManager, address underlyingStrategy) = IStrategyDeployer(strategyDeployerV100).deploy({
            strategyManagerFactory: strategyManagerFactory,
            strategyFactory:        strategyFactory,
            strategyLiquidityCap:   0,
            strategyDeploymentData: deploymentData,
            bootstrapFundingData:   ""
        });

        vm.stopBroadcast();

        console.log(name);
        console.log("StrategyManager:   ", strategyManager);
        console.log("UnderlyingStrategy:", underlyingStrategy);
    }

}
