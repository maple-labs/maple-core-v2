// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { InvariantResult } from "./IHealthCheckerRouter.sol";

interface IHealthChecker {

    function check(bytes calldata input) external view returns (InvariantResult[] memory results);

}
