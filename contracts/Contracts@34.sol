// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.34;

import { MapleAllocationStrategy as MAS } from "../modules/allocation-strategy/contracts/MapleAllocationStrategy.sol";
import { MapleAllocationStrategyFactory as MASF } from "../modules/allocation-strategy/contracts/MapleAllocationStrategyFactory.sol";

import {
    MapleAllocationStrategyInitializer as MASI
} from "../modules/allocation-strategy/contracts/MapleAllocationStrategyInitializer.sol";

import { MapleAaveV3Strategy as MAV3S } from "../modules/defi-strategies/contracts/aaveV3/MapleAaveV3Strategy.sol";
import { MapleAaveV3StrategyFactory as MAV3SF } from "../modules/defi-strategies/contracts/aaveV3/MapleAaveV3StrategyFactory.sol";
import { MapleAaveV3StrategyInitializer as MAV3SI } from "../modules/defi-strategies/contracts/aaveV3/MapleAaveV3StrategyInitializer.sol";

import { MapleSkyStrategy as MSS } from "../modules/defi-strategies/contracts/sky/MapleSkyStrategy.sol";
import { MapleSkyStrategyFactory as MSSF } from "../modules/defi-strategies/contracts/sky/MapleSkyStrategyFactory.sol";
import { MapleSkyStrategyInitializer as MSSI } from "../modules/defi-strategies/contracts/sky/MapleSkyStrategyInitializer.sol";

import { MapleGlobals as MG } from "../modules/globals/contracts/MapleGlobals.sol";

import { MaplePool as MP } from "../modules/pool/contracts/MaplePool.sol";
import { MaplePoolDeployer as MPD } from "../modules/pool/contracts/MaplePoolDeployer.sol";
import { MaplePoolManager as MPM } from "../modules/pool/contracts/MaplePoolManager.sol";
import { MaplePoolManagerInitializer as MPMI } from "../modules/pool/contracts/proxy/MaplePoolManagerInitializer.sol";
import { MaplePoolManagerMigratorV500 as MPMM } from "../modules/pool/contracts/proxy/MaplePoolManagerMigratorV500.sol";

import { MapleLiquidityRouter as MLR } from "../modules/strategy-manager/contracts/MapleLiquidityRouter.sol";
import { MapleStrategyDeployer as MSD } from "../modules/strategy-manager/contracts/MapleStrategyDeployer.sol";
import { MapleStrategyManager as MSM } from "../modules/strategy-manager/contracts/MapleStrategyManager.sol";
import { MapleStrategyManagerFactory as MSMF } from "../modules/strategy-manager/contracts/MapleStrategyManagerFactory.sol";
import { MapleStrategyManagerInitializer as MSMI } from "../modules/strategy-manager/contracts/MapleStrategyManagerInitializer.sol";

import { MapleWithdrawalManager as MWMQ } from "../modules/withdrawal-manager-queue/contracts/MapleWithdrawalManager.sol";
import {
    MapleWithdrawalManagerInitializer as MWMQI
} from "../modules/withdrawal-manager-queue/contracts/proxy/MapleWithdrawalManagerInitializer.sol";

contract AllocationStrategy is MAS { }

contract AllocationStrategyFactory is MASF {

    constructor(address globals_) MASF(globals_) { }

}

contract AllocationStrategyInitializer is MASI { }

contract AaveV3Strategy is MAV3S { }

contract AaveV3StrategyFactory is MAV3SF {

    constructor(address globals_) MAV3SF(globals_) { }

}

contract AaveV3StrategyInitializer is MAV3SI { }

contract Globals is MG { }

contract Pool is MP {

    constructor(
        address manager_,
        address asset_,
        address destination_,
        uint256 bootstrapMint_,
        uint256 initialSupply_,
        string memory name_,
        string memory symbol_
    )
        MP(manager_, asset_, destination_, bootstrapMint_, initialSupply_, name_, symbol_)
    { }

}

contract PoolDeployer is MPD {

    constructor(address globals_) MPD(globals_) { }

}

contract PoolManager is MPM { }

contract PoolManagerInitializer is MPMI { }

contract PoolManagerMigrator is MPMM { }

contract LiquidityRouter is MLR {

    constructor(address globals_) MLR(globals_) { }

}

contract StrategyDeployer is MSD {

    constructor(address globals_) MSD(globals_) { }

}

contract StrategyManager is MSM { }

contract StrategyManagerInitializer is MSMI { }

contract StrategyManagerFactory is MSMF {

    constructor(address globals_) MSMF(globals_) { }

}

contract SkyStrategy is MSS { }

contract SkyStrategyFactory is MSSF {

    constructor(address globals_) MSSF(globals_) { }

}

contract SkyStrategyInitializer is MSSI { }

contract WithdrawalManagerQueue is MWMQ { }

contract WithdrawalManagerQueueInitializer is MWMQI { }
