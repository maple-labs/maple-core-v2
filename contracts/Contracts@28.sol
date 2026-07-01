// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import { MapleAaveV3Strategy as MAV3S }             from "../modules/defi-strategies/contracts/aaveV3/MapleAaveV3Strategy.sol";
import { MapleAaveV3StrategyFactory as MAV3SF }     from "../modules/defi-strategies/contracts/aaveV3/MapleAaveV3StrategyFactory.sol";
import { MapleAaveV3StrategyInitializer as MAV3SI } from "../modules/defi-strategies/contracts/aaveV3/MapleAaveV3StrategyInitializer.sol";

import { MapleSkyStrategy as MSS }             from "../modules/defi-strategies/contracts/sky/MapleSkyStrategy.sol";
import { MapleSkyStrategyFactory as MSSF }     from "../modules/defi-strategies/contracts/sky/MapleSkyStrategyFactory.sol";
import { MapleSkyStrategyInitializer as MSSI } from "../modules/defi-strategies/contracts/sky/MapleSkyStrategyInitializer.sol";

import { MapleStrategyDeployer as MSD }            from "../modules/strategy-manager/contracts/MapleStrategyDeployer.sol";
import { MapleStrategyManager as MSM }             from "../modules/strategy-manager/contracts/MapleStrategyManager.sol";
import { MapleStrategyManagerFactory as MSMF }     from "../modules/strategy-manager/contracts/MapleStrategyManagerFactory.sol";
import { MapleStrategyManagerInitializer as MSMI } from "../modules/strategy-manager/contracts/MapleStrategyManagerInitializer.sol";

import { MapleTradingStrategy as MTS }             from "../modules/trading-strategy/contracts/MapleTradingStrategy.sol";
import { MapleTradingStrategyFactory as MTSF }     from "../modules/trading-strategy/contracts/MapleTradingStrategyFactory.sol";
import { MapleTradingStrategyInitializer as MTSI } from "../modules/trading-strategy/contracts/MapleTradingStrategyInitializer.sol";

contract AaveV3Strategy is MAV3S { }

contract AaveV3StrategyFactory is MAV3SF {

    constructor(address globals_) MAV3SF(globals_) { }

}

contract AaveV3StrategyInitializer is MAV3SI { }

contract StrategyDeployer is MSD {

    constructor(address globals_) MSD(globals_) { }

}

contract StrategyManager is MSM { }

contract StrategyManagerInitializer is MSMI { }

contract StrategyManagerFactory is MSMF {

    constructor(address globals_) MSMF(globals_) { }

}

contract TradingStrategy is MTS { }

contract TradingStrategyFactory is MTSF {

    constructor(address globals_) MTSF(globals_) { }

}

contract TradingStrategyInitializer is MTSI { }

contract SkyStrategy is MSS { }

contract SkyStrategyFactory is MSSF {

    constructor(address globals_) MSSF(globals_) { }

}

contract SkyStrategyInitializer is MSSI { }
