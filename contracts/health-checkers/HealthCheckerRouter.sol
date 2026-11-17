// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IHealthChecker } from "../interfaces/IHealthChecker.sol";

import { InvariantCall, InvariantResult, IHealthCheckerRouter } from "../interfaces/IHealthCheckerRouter.sol";

contract HealthCheckerRouter is IHealthCheckerRouter {

    function check(InvariantCall[] calldata calls_) external view override returns (InvariantResult[][] memory results_) {
        results_ = new InvariantResult[][](calls_.length);

        for (uint256 i; i < calls_.length; ++i) {
            try IHealthChecker(calls_[i].target).check(calls_[i].input) returns (InvariantResult[] memory checkerResults_) {
                results_[i] = checkerResults_;
            } catch (bytes memory revertData_) {
                results_[i] = new InvariantResult[](1);
                results_[i][0] = InvariantResult({
                    name:   "target reverted",
                    output: revertData_,
                    valid:  false
                });
            }
        }
    }

}
