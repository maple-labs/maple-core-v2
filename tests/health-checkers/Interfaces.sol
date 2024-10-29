// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

interface IOldPoolManagerLike {

    function loanManagerList(uint256 index_) external view returns (address);

    function loanManagerListLength() external view returns (uint256);

}
