// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { MapleStrategyDeployer as MSD }            from "../modules/strategy-manager/contracts/MapleStrategyDeployer.sol";
import { MapleStrategyManager as MSM }             from "../modules/strategy-manager/contracts/MapleStrategyManager.sol";
import { MapleStrategyManagerFactory as MSMF }     from "../modules/strategy-manager/contracts/MapleStrategyManagerFactory.sol";
import { MapleStrategyManagerInitializer as MSMI } from "../modules/strategy-manager/contracts/MapleStrategyManagerInitializer.sol";

import { MapleTradingStrategy as MTS }             from "../modules/trading-strategy/contracts/MapleTradingStrategy.sol";
import { MapleTradingStrategyFactory as MTSF }     from "../modules/trading-strategy/contracts/MapleTradingStrategyFactory.sol";
import { MapleTradingStrategyInitializer as MTSI } from "../modules/trading-strategy/contracts/MapleTradingStrategyInitializer.sol";

contract StrategyDeployer is MSD {

    constructor(address globals_) MSD(globals_) { }

}

contract StrategyManager is MSM { }

contract StrategyManagerInitializer is MSMI { }

contract StrategyManagerFactory is MSMF {

    constructor(address globals_) MSMF(globals_) { }

}

contract TradingStrategy is MTS { }

contract TradingStrategyInitializer is MTSI { }

contract TradingStrategyFactory is MTSF {

    constructor(address globals_) MTSF(globals_) { }

}
