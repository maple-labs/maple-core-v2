// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

struct InvariantCall {
    address target;
    bytes input;
}

struct InvariantResult {
    string name;
    bytes output;
    bool valid;
}

interface IHealthCheckerRouter {

    function check(InvariantCall[] calldata calls) external view returns (InvariantResult[][] memory results);

}
