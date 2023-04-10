// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console, StdInvariant, Test as T } from "../modules/forge-std/src/Test.sol";

import { AddressRegistry } from "../modules/address-registry/contracts/MapleAddressRegistry.sol";

import { MapleLoan as MFTL }              from "../modules/fixed-term-loan/contracts/MapleLoan.sol";
import { Refinancer as MFTLR }            from "../modules/fixed-term-loan/contracts/Refinancer.sol";
import { MapleLoanFactory as MFTLF }      from "../modules/fixed-term-loan/contracts/MapleLoanFactory.sol";
import { MapleLoanFeeManager as MFTLFM }  from "../modules/fixed-term-loan/contracts/MapleLoanFeeManager.sol";
import { MapleLoanInitializer as MFTLI }  from "../modules/fixed-term-loan/contracts/MapleLoanInitializer.sol";
import { MapleLoanV5Migrator as MFTLV5M } from "../modules/fixed-term-loan/contracts/MapleLoanV5Migrator.sol";

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

import { Liquidator }            from "../modules/liquidations/contracts/Liquidator.sol";
import { LiquidatorFactory }     from "../modules/liquidations/contracts/LiquidatorFactory.sol";
import { LiquidatorInitializer } from "../modules/liquidations/contracts/LiquidatorInitializer.sol";

import { MapleGlobals as MG }  from "../modules/globals/contracts/MapleGlobals.sol";
import { NonTransparentProxy } from "../modules/globals/modules/non-transparent-proxy/contracts/NonTransparentProxy.sol";

import { Pool }                   from "../modules/pool/contracts/Pool.sol";
import { PoolDelegateCover }      from "../modules/pool/contracts/PoolDelegateCover.sol";
import { PoolDeployer }           from "../modules/pool/contracts/PoolDeployer.sol";
import { PoolManager }            from "../modules/pool/contracts/PoolManager.sol";
import { PoolManagerFactory }     from "../modules/pool/contracts/proxy/PoolManagerFactory.sol";
import { PoolManagerInitializer } from "../modules/pool/contracts/proxy/PoolManagerInitializer.sol";

import { WithdrawalManager }            from "../modules/withdrawal-manager/contracts/WithdrawalManager.sol";
import { WithdrawalManagerFactory }     from "../modules/withdrawal-manager/contracts/WithdrawalManagerFactory.sol";
import { WithdrawalManagerInitializer } from "../modules/withdrawal-manager/contracts/WithdrawalManagerInitializer.sol";

import { ConfigurableMockERC20 } from "../tests/mocks/Mocks.sol";

/******************************************************************************************************************************************/
/*** Re-Exports                                                                                                                         ***/
/******************************************************************************************************************************************/

contract EmptyContract { }

contract FixedTermLoan is MFTL { }

contract FixedTermLoanFactory is MFTLF {

    constructor(address globals_) MFTLF(globals_) { }

}

contract FixedTermLoanInitializer is MFTLI { }

contract FixedTermLoanV5Migrator is MFTLV5M { }

contract FeeManager is MFTLFM {

    constructor(address globals_) MFTLFM(globals_) { }

}

contract FixedTermLoanManager is MFTLM { }

contract FixedTermLoanManagerFactory is MFTLMF {

    constructor(address globals_) MFTLMF(globals_) { }

}

contract FixedTermLoanManagerInitializer is MFTLMI { }

contract FixedTermRefinancer is MFTLR { }

contract Globals is MG { }

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

// Test does not import stdError which contain the error constants.
contract Test is T {

    bytes public constant assertionError      = abi.encodeWithSignature("Panic(uint256)", 0x01);
    bytes public constant arithmeticError     = abi.encodeWithSignature("Panic(uint256)", 0x11);
    bytes public constant divisionError       = abi.encodeWithSignature("Panic(uint256)", 0x12);
    bytes public constant enumConversionError = abi.encodeWithSignature("Panic(uint256)", 0x21);
    bytes public constant encodeStorageError  = abi.encodeWithSignature("Panic(uint256)", 0x22);
    bytes public constant popError            = abi.encodeWithSignature("Panic(uint256)", 0x31);
    bytes public constant indexOOBError       = abi.encodeWithSignature("Panic(uint256)", 0x32);
    bytes public constant memOverflowError    = abi.encodeWithSignature("Panic(uint256)", 0x41);
    bytes public constant zeroVarError        = abi.encodeWithSignature("Panic(uint256)", 0x51);

}
