// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { CSVWriter }                                  from "../modules/contract-test-utils/contracts/csv.sol";
import { Address, console, InvariantTest, TestUtils } from "../modules/contract-test-utils/contracts/test.sol";

import { MockERC20 } from "../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { MapleLoan as MFTL }             from "../modules/fixed-term-loan/contracts/MapleLoan.sol";
import { Refinancer as MFTLR }           from "../modules/fixed-term-loan/contracts/Refinancer.sol";
import { MapleLoanFactory as MFTLF }     from "../modules/fixed-term-loan/contracts/MapleLoanFactory.sol";
import { MapleLoanFeeManager as MFTLFM } from "../modules/fixed-term-loan/contracts/MapleLoanFeeManager.sol";
import { MapleLoanInitializer as MFTLI } from "../modules/fixed-term-loan/contracts/MapleLoanInitializer.sol";

import { LoanManager as MFTLM }             from "../modules/fixed-term-loan-manager/contracts/LoanManager.sol";
import { LoanManagerFactory as MFTLMF }     from "../modules/fixed-term-loan-manager/contracts/proxy/LoanManagerFactory.sol";
import { LoanManagerInitializer as MFTLMI } from "../modules/fixed-term-loan-manager/contracts/proxy/LoanManagerInitializer.sol";

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

/******************************************************************************************************************************************/
/*** Re-Exports                                                                                                                     *******/
/******************************************************************************************************************************************/

contract FixedTermLoan is MFTL {}

contract FixedTermLoanFactory is MFTLF {

    constructor(address globals_) MFTLF(globals_) {}

}

contract FixedTermLoanInitializer is MFTLI {}

contract FeeManager is MFTLFM {

    constructor(address globals_) MFTLFM(globals_) {}

}

contract FixedTermLoanManager is MFTLM {}

contract FixedTermLoanManagerFactory is MFTLMF {

    constructor(address globals_) MFTLMF(globals_) {}

}

contract FixedTermLoanManagerInitializer is MFTLMI {}

contract FixedTermRefinancer is MFTLR {}

contract Globals is MG {}
