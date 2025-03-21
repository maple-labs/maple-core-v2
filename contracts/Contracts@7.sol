// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console2, stdJson, StdInvariant, stdMath, StdStyle, Test as T } from "../modules/forge-std/src/Test.sol";

import { MapleAddressRegistryETH as AR }     from "../modules/address-registry/contracts/MapleAddressRegistryETH.sol";
import { MapleAddressRegistryBASEL2 as ARB } from "../modules/address-registry/contracts/MapleAddressRegistryBASEL2.sol";

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

import { MapleLoan as MFTL }                  from "../modules/fixed-term-loan/contracts/MapleLoan.sol";
import { MapleLoanFactory as MFTLF }          from "../modules/fixed-term-loan/contracts/MapleLoanFactory.sol";
import { MapleLoanFeeManager as MFTLFM }      from "../modules/fixed-term-loan/contracts/MapleLoanFeeManager.sol";
import { MapleLoanInitializer as MFTLI }      from "../modules/fixed-term-loan/contracts/MapleLoanInitializer.sol";
import { MapleLoanV5Migrator as MFTLV5M }     from "../modules/fixed-term-loan/contracts/MapleLoanV5Migrator.sol";
import { MapleLoanV502Migrator as MFTLV502M } from "../modules/fixed-term-loan/contracts/MapleLoanV502Migrator.sol";
import { MapleRefinancer as MFTLR }           from "../modules/fixed-term-loan/contracts/MapleRefinancer.sol";

import { LoanManager as MFTLM }             from "../modules/fixed-term-loan-manager/contracts/LoanManager.sol";
import { LoanManagerFactory as MFTLMF }     from "../modules/fixed-term-loan-manager/contracts/proxy/LoanManagerFactory.sol";
import { LoanManagerInitializer as MFTLMI } from "../modules/fixed-term-loan-manager/contracts/proxy/LoanManagerInitializer.sol";

import { MapleLoan as MOTL }             from "../modules/open-term-loan/contracts/MapleLoan.sol";
import { MapleLoanFactory as MOTLF }     from "../modules/open-term-loan/contracts/MapleLoanFactory.sol";
import { MapleLoanInitializer as MOTLI } from "../modules/open-term-loan/contracts/MapleLoanInitializer.sol";
import { MapleRefinancer as MOTLR }      from "../modules/open-term-loan/contracts/MapleRefinancer.sol";

import { LoanManager as MOTLM }             from "../modules/open-term-loan-manager/contracts/LoanManager.sol";
import { LoanManagerFactory as MOTLMF }     from "../modules/open-term-loan-manager/contracts/LoanManagerFactory.sol";
import { LoanManagerInitializer as MOTLMI } from "../modules/open-term-loan-manager/contracts/LoanManagerInitializer.sol";

import { Liquidator as ML }             from "../modules/liquidations/contracts/Liquidator.sol";
import { LiquidatorFactory as MLF }     from "../modules/liquidations/contracts/LiquidatorFactory.sol";
import { LiquidatorInitializer as MLI } from "../modules/liquidations/contracts/LiquidatorInitializer.sol";

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

import { SyrupRouter } from "../modules/syrup-utils/contracts/SyrupRouter.sol";

import { ConfigurableMockERC20 } from "../tests/mocks/Mocks.sol";

/******************************************************************************************************************************************/
/*** Re-Exports                                                                                                                         ***/
/******************************************************************************************************************************************/

contract AddressRegistry is AR { }

contract AddressRegistryBaseL2 is ARB { }

contract EmptyContract { }

contract FeeManager is MFTLFM {

    constructor(address globals_) MFTLFM(globals_) { }

}

contract FixedTermLoan is MFTL { }

contract FixedTermLoanFactory is MFTLF {

    constructor(address globals_, address oldFactory_) MFTLF(globals_, oldFactory_) { }

}

contract FixedTermLoanInitializer is MFTLI { }

contract FixedTermLoanManager is MFTLM { }

contract FixedTermLoanManagerFactory is MFTLMF {

    constructor(address globals_) MFTLMF(globals_) { }

}

contract FixedTermLoanManagerInitializer is MFTLMI { }

contract FixedTermLoanV5Migrator is MFTLV5M { }

contract FixedTermLoanV502Migrator is MFTLV502M { }

contract FixedTermRefinancer is MFTLR { }

contract Liquidator is ML { }

contract LiquidatorFactory is MLF {

    constructor(address globals_) MLF(globals_) { }

}

contract LiquidatorInitializer is MLI { }

contract MockERC20 is ConfigurableMockERC20 {

    constructor(string memory name_, string memory symbol_, uint8 decimals_) ConfigurableMockERC20(name_, symbol_, decimals_) { }

}

contract OpenTermLoan is MOTL { }

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
