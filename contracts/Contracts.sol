// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { CSVWriter }                                  from "../modules/contract-test-utils/contracts/csv.sol";
import { Address, console, InvariantTest, TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

import { MapleLoan as MFTL }             from "../modules/fixed-term-loan/contracts/MapleLoan.sol";
import { Refinancer as MFTLR }           from "../modules/fixed-term-loan/contracts/Refinancer.sol";
import { MapleLoanFactory as MFTLF }     from "../modules/fixed-term-loan/contracts/MapleLoanFactory.sol";
import { MapleLoanFeeManager as MFTLFM } from "../modules/fixed-term-loan/contracts/MapleLoanFeeManager.sol";
import { MapleLoanInitializer as MFTLI } from "../modules/fixed-term-loan/contracts/MapleLoanInitializer.sol";

import { LoanManager as MFTLM }             from "../modules/fixed-term-loan-manager/contracts/LoanManager.sol";
import { LoanManagerFactory as MFTLMF }     from "../modules/fixed-term-loan-manager/contracts/proxy/LoanManagerFactory.sol";
import { LoanManagerInitializer as MFTLMI } from "../modules/fixed-term-loan-manager/contracts/proxy/LoanManagerInitializer.sol";

import { MapleLoan as MOTL }             from "../modules/open-term-loan/contracts/MapleLoan.sol";
import { MapleRefinancer as MOTLR }      from "../modules/open-term-loan/contracts/MapleRefinancer.sol";
import { MapleLoanFactory as MOTLF }     from "../modules/open-term-loan/contracts/MapleLoanFactory.sol";
import { MapleLoanInitializer as MOTLI } from "../modules/open-term-loan/contracts/MapleLoanInitializer.sol";

import { LoanManager as MOTLM }             from "../modules/open-term-loan-manager/contracts/LoanManager.sol";
import { LoanManagerFactory as MOTLMF }     from "../modules/open-term-loan-manager/contracts/LoanManagerFactory.sol";
import { LoanManagerInitializer as MOTLMI } from "../modules/open-term-loan-manager/contracts/LoanManagerInitializer.sol";

import { Liquidator }            from "../modules/liquidations/contracts/Liquidator.sol";
import { LiquidatorFactory }     from "../modules/liquidations/contracts/LiquidatorFactory.sol";
import { LiquidatorInitializer } from "../modules/liquidations/contracts/LiquidatorInitializer.sol";

import { MapleGlobals as MG } from "../modules/globals/contracts/MapleGlobals.sol";

import { Pool }              from "../modules/pool/contracts/Pool.sol";
import { PoolDelegateCover } from "../modules/pool/contracts/PoolDelegateCover.sol";
import { PoolDeployer }      from "../modules/pool/contracts/PoolDeployer.sol";
import { PoolManager }       from "../modules/pool/contracts/PoolManager.sol";

import { WithdrawalManager } from "../modules/withdrawal-manager/contracts/WithdrawalManager.sol";

import { NonTransparentProxy } from "../modules/globals/modules/non-transparent-proxy/contracts/NonTransparentProxy.sol";

import { ConfigurableMockERC20 } from "../tests/mocks/Mocks.sol";

/******************************************************************************************************************************************/
/*** Re-Exports                                                                                                                     *******/
/******************************************************************************************************************************************/

contract FixedTermLoan is MFTL { }

contract FixedTermLoanFactory is MFTLF {

    constructor(address globals_) MFTLF(globals_) { }

}

contract FixedTermLoanInitializer is MFTLI { }

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
