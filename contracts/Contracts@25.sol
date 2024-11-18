// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { MapleGlobals as MG }  from "../modules/globals/contracts/MapleGlobals.sol";

import { MaplePool as MP }                     from "../modules/pool/contracts/MaplePool.sol";
import { MaplePoolDelegateCover as MPDC }      from "../modules/pool/contracts/MaplePoolDelegateCover.sol";
import { MaplePoolDeployer as MPD }            from "../modules/pool/contracts/MaplePoolDeployer.sol";
import { MaplePoolManager as MPM }             from "../modules/pool/contracts/MaplePoolManager.sol";
import { MaplePoolManagerInitializer as MPMI } from "../modules/pool/contracts/proxy/MaplePoolManagerInitializer.sol";
import { MaplePoolManagerMigrator as MPMM }    from "../modules/pool/contracts/proxy/MaplePoolManagerMigrator.sol";

import { MapleAaveStrategy as MAS }             from "../modules/strategies/contracts/MapleAaveStrategy.sol";
import { MapleAaveStrategyInitializer as MASI } from "../modules/strategies/contracts/proxy/aaveStrategy/MapleAaveStrategyInitializer.sol";
import { MapleBasicStrategy as MBS }            from "../modules/strategies/contracts/MapleBasicStrategy.sol";
import { MapleSkyStrategy as MSS }              from "../modules/strategies/contracts/MapleSkyStrategy.sol";
import { MapleSkyStrategyInitializer as MSSI }  from "../modules/strategies/contracts/proxy/skyStrategy/MapleSkyStrategyInitializer.sol";
import { MapleStrategyFactory as MSF }          from "../modules/strategies/contracts/proxy/MapleStrategyFactory.sol";

import { MapleBasicStrategyInitializer as MBSI }
    from "../modules/strategies/contracts/proxy/basicStrategy/MapleBasicStrategyInitializer.sol";

contract AaveStrategy is MAS { }

contract AaveStrategyInitializer is MASI { }

contract BasicStrategy is MBS { }

contract BasicStrategyInitializer is MBSI { }

contract Globals is MG { }

contract SkyStrategy is MSS { }

contract SkyStrategyInitializer is MSSI { }

contract StrategyFactory is MSF {

    constructor(address globals_) MSF(globals_) { }

}

contract Pool is MP {

    constructor(
        address manager_,
        address asset_,
        address destination_,
        uint256 bootstrapMint_,
        uint256 initialSupply_,
        string memory name_,
        string memory symbol_
    ) MP(manager_, asset_, destination_, bootstrapMint_, initialSupply_, name_, symbol_) { }

}

contract PoolDelegateCover is MPDC {

    constructor(address poolManager_, address asset_) MPDC(poolManager_, asset_) { }

}

contract PoolDeployer is MPD {

    constructor(address globals_) MPD(globals_) { }

}

contract PoolManager is MPM { }

contract PoolManagerInitializer is MPMI { }

contract PoolManagerMigrator is MPMM { }
