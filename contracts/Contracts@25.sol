// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.25;

import { AssetController as AC }        from "../modules/controller/contracts/AssetController.sol";
import { AssetControllerOracle as ACO } from "../modules/controller/contracts/AssetControllerOracle.sol";
import { CompositeToken as CT }         from "../modules/controller/contracts/CompositeToken.sol";
import { SyrupBitcoinRouter as SBR }    from "../modules/controller/contracts/SyrupBitcoinRouter.sol";

import { AssetControllerInitializer as ACI }     from "../modules/controller/contracts/proxy/AssetControllerInitializer.sol";
import { CompositeTokenInitializer as CTI }      from "../modules/controller/contracts/proxy/CompositeTokenInitializer.sol";
import { SyrupBitcoinRouterInitializer as SBRI } from "../modules/controller/contracts/proxy/SyrupBitcoinRouterInitializer.sol";

import { NonTransparentProxyInitializable as NTPI } from "../modules/controller/contracts/NonTransparentProxyInitializable.sol";

import { GovernorTimelock as GT } from "../modules/globals/contracts/GovernorTimelock.sol";
import { MapleGlobals as MG }     from "../modules/globals/contracts/MapleGlobals.sol";

import { MaplePool as MP }                      from "../modules/pool/contracts/MaplePool.sol";
import { MaplePoolDeployer as MPD }             from "../modules/pool/contracts/MaplePoolDeployer.sol";
import { MaplePoolManager as MPM }              from "../modules/pool/contracts/MaplePoolManager.sol";
import { MaplePoolManagerInitializer as MPMI }  from "../modules/pool/contracts/proxy/MaplePoolManagerInitializer.sol";
import { MaplePoolManagerMigratorV500 as MPMM } from "../modules/pool/contracts/proxy/MaplePoolManagerMigratorV500.sol";

import { MapleBitcoinStrategy as MBTCS } from "../modules/strategies/contracts/MapleBitcoinStrategy.sol";

import { MapleBitcoinStrategyInitializer as MBTCSI }
    from "../modules/strategies/contracts/proxy/bitcoinStrategy/MapleBitcoinStrategyInitializer.sol";

import { MapleStrategyFactory as MSF } from "../modules/strategies/contracts/proxy/MapleStrategyFactory.sol";

import { MapleBorrowerActions }          from "../modules/syrup-utils/contracts/MapleBorrowerActions.sol";
import { MapleRouter as MR }             from "../modules/syrup-utils/contracts/MapleRouter.sol";
import { MapleRouterInitializer as MRI } from "../modules/syrup-utils/contracts/MapleRouterInitializer.sol";
import { NonTransparentProxy as NTP }    from "../modules/syrup-utils/modules/non-transparent-proxy/contracts/NonTransparentProxy.sol";

contract AssetController is AC { }

contract AssetControllerOracle is ACO { }

contract AssetControllerInitializer is ACI { }

contract BitcoinStrategy is MBTCS { }

contract BitcoinStrategyInitializer is MBTCSI { }

contract BorrowerActions is MapleBorrowerActions { }

contract CompositeToken is CT { }

contract CompositeTokenInitializer is CTI { }

contract Globals is MG { }

contract MapleRouter is MR {}

contract MapleRouterInitializer is MRI {}

contract NonTransparentProxyInitializable is NTPI {

    constructor(
        address globals,
        address implementation,
        address initializer,
        bytes   memory calldata_
    ) NTPI(globals, implementation, initializer, calldata_) {}

}

contract Pool is MP {

    constructor(
        address manager_,
        address asset_,
        address destination_,
        uint256 bootstrapMint_,
        uint256 initialSupply_,
        string  memory name_,
        string  memory symbol_
    ) MP(manager_, asset_, destination_, bootstrapMint_, initialSupply_, name_, symbol_) { }

}

contract PoolDeployer is MPD {

    constructor(address globals_) MPD(globals_) { }

}

contract PoolManager is MPM { }

contract PoolManagerInitializer is MPMI { }

contract PoolManagerMigrator is MPMM { }

contract Timelock is GT {

    constructor(address tokenWithdrawer_, address proposer_, address executor_, address canceller_, address roleAdmin_)
        GT(tokenWithdrawer_, proposer_, executor_, canceller_, roleAdmin_) { }

}

contract StrategyFactory is MSF {

    constructor(address globals_) MSF(globals_) { }

}

contract SyrupBitcoinRouter is SBR { }

contract SyrupBitcoinRouterInitializer is SBRI { }
