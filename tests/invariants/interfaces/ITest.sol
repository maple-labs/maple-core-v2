// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

interface ITest {

    function borrowers(uint256 index_) external view returns (address borrower_);

    function currentTimestamp() external view returns (uint256 currentTimestamp_);

    function setCurrentTimestamp(uint256 currentTimestamp_) external;

    function getAllOutstandingInterest() external returns (uint256 sumOutstandingInterest_);

    function getSumIssuanceRates() external returns (uint256 getSumIssuanceRates_);

}
