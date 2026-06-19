// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console, stdJson, StdInvariant, stdMath, StdStyle, Test as T } from "../modules/forge-std/src/Test.sol";

import { MapleAddressRegistryETH as AR }     from "../modules/address-registry/contracts/MapleAddressRegistryETH.sol";
import { MapleAddressRegistryBASEL2 as ARB } from "../modules/address-registry/contracts/MapleAddressRegistryBASEL2.sol";

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

import { MapleLoan as MOTL }                  from "../modules/open-term-loan/contracts/MapleLoan.sol";
import { MapleLoanV202Migrator as MOTLV202M } from "modules/open-term-loan/contracts/MapleLoanV202Migrator.sol";
import { MapleLoanFactory as MOTLF }          from "../modules/open-term-loan/contracts/MapleLoanFactory.sol";
import { MapleLoanInitializer as MOTLI }      from "../modules/open-term-loan/contracts/MapleLoanInitializer.sol";
import { MapleRefinancer as MOTLR }           from "../modules/open-term-loan/contracts/MapleRefinancer.sol";

import { MapleLoanManager as MOTLM }             from "../modules/open-term-loan-manager/contracts/MapleLoanManager.sol";
import { MapleLoanManagerFactory as MOTLMF }     from "../modules/open-term-loan-manager/contracts/MapleLoanManagerFactory.sol";
import { MapleLoanManagerInitializer as MOTLMI } from "../modules/open-term-loan-manager/contracts/MapleLoanManagerInitializer.sol";

import { NonTransparentProxy } from "../modules/globals/modules/non-transparent-proxy/contracts/NonTransparentProxy.sol";

import { MaplePoolManagerFactory as MPMF } from "../modules/pool/contracts/proxy/MaplePoolManagerFactory.sol";

import { MaplePoolPermissionManager as MPPM }
    from "../modules/pool-permission-manager/contracts/MaplePoolPermissionManager.sol";
import { MaplePoolPermissionManagerInitializer as MPPMI }
    from "../modules/pool-permission-manager/contracts/proxy/MaplePoolPermissionManagerInitializer.sol";

import { MapleWithdrawalManager as MWMC } from "../modules/withdrawal-manager-cyclical/contracts/MapleWithdrawalManager.sol";

import { MapleWithdrawalManagerFactory as MWMCF }
    from "../modules/withdrawal-manager-cyclical/contracts/MapleWithdrawalManagerFactory.sol";
import { MapleWithdrawalManagerInitializer as MWMCI }
    from "../modules/withdrawal-manager-cyclical/contracts/MapleWithdrawalManagerInitializer.sol";

import { MapleWithdrawalManager as MWMQ } from "../modules/withdrawal-manager-queue/contracts/MapleWithdrawalManager.sol";

import { MapleWithdrawalManagerFactory as MWMQF }
    from "../modules/withdrawal-manager-queue/contracts/proxy/MapleWithdrawalManagerFactory.sol";
import { MapleWithdrawalManagerInitializer as MWMQI }
    from "../modules/withdrawal-manager-queue/contracts/proxy/MapleWithdrawalManagerInitializer.sol";
// TODO: adjust deploy, upgrade scripts, etc. to use latest version of migrator. Get rid of V200
import { MapleWithdrawalManagerMigratorV300 as MWMQM }
    from "../modules/withdrawal-manager-queue/contracts/proxy/MapleWithdrawalManagerMigratorV300.sol";

import { SyrupRouter as SR } from "../modules/syrup-utils/contracts/SyrupRouter.sol";

import { ConfigurableMockERC20 } from "../tests/mocks/Mocks.sol";

/******************************************************************************************************************************************/
/*** Re-Exports                                                                                                                         ***/
/******************************************************************************************************************************************/

contract AddressRegistry is AR { }

contract AddressRegistryBaseL2 is ARB { }

contract EmptyContract { }

contract MockERC20 is ConfigurableMockERC20 {

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ConfigurableMockERC20(name_, symbol_, decimals_) { }

}

contract OpenTermLoan is MOTL { }

contract OpenTermLoanV202Migrator is MOTLV202M { }

contract OpenTermLoanFactory is MOTLF {

    constructor(address globals_) MOTLF(globals_) { }

}

contract OpenTermLoanInitializer is MOTLI { }

contract OpenTermLoanManager is MOTLM { }

contract OpenTermLoanManagerFactory is MOTLMF {

    constructor(address globals_) MOTLMF(globals_) { }

}

contract OpenTermLoanManagerInitializer is MOTLMI { }

contract OpenTermRefinancer is MOTLR { }

contract PoolManagerFactory is MPMF {

    constructor(address globals_) MPMF(globals_) { }

}

contract PoolPermissionManager is MPPM { }

contract PoolPermissionManagerInitializer is MPPMI { }

contract SyrupRouter is SR {

    constructor(address pool_) SR(pool_) { }

}

contract WithdrawalManagerCyclical is MWMC { }

contract WithdrawalManagerCyclicalFactory is MWMCF {

    constructor(address globals_) MWMCF(globals_) { }

}

contract WithdrawalManagerCyclicalInitializer is MWMCI { }

contract WithdrawalManagerQueue is MWMQ { }

contract WithdrawalManagerQueueFactory is MWMQF {

    constructor(address globals_) MWMQF(globals_) { }

}

contract WithdrawalManagerQueueInitializer is MWMQI { }

contract WithdrawalManagerQueueMigrator is MWMQM { }
