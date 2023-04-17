// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console } from "../../modules/forge-std/src/Test.sol";

import { IFixedTermLoanManager, ILoanLike, ILoanManagerLike } from "../../contracts/interfaces/Interfaces.sol";

import { BaseInvariants }       from "../invariants/BaseInvariants.t.sol";
import { FixedTermLoanHandler } from "../invariants/actors/FixedTermLoanHandler.sol";
import { LpHandler }            from "../invariants/actors/LpHandler.sol";

// NOTE: Placeholder for regression tests.
contract RegressionTest is BaseInvariants {

    // NOTE: Refer to specific invariant test suite for setup.
    function setUp() public override {
        super.setUp();

        currentTimestamp = block.timestamp;
    }

}
