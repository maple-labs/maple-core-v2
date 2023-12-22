// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console2 as console } from "../../../contracts/Contracts.sol";

import { IHandlerEntryPoint } from "../../../contracts/interfaces/Interfaces.sol";

contract DistributionHandler {

    uint256 constant internal WEIGHTS_RANGE = 100;

    uint256 public numOfCallsTotal;

    address[] public targetContracts;

    uint256[] public weights;

    mapping(address => uint256) public numOfCalls;

    constructor(address[] memory targetContracts_, uint256[] memory weights_) {
        // NOTE: Order of arrays must match
        require(targetContracts_.length == weights_.length, "DH:INVALID_LENGTHS");

        uint256 weightsTotal;

        for (uint256 i; i < weights_.length; ++i) {
            weightsTotal += weights_[i];
        }

        require(weightsTotal == WEIGHTS_RANGE, "DH:INVALID_WEIGHTS");

        targetContracts = targetContracts_;
        weights         = weights_;
    }

    function distributorEntryPoint(uint256 seed_) external {
        numOfCallsTotal++;

        uint256 range_;
        uint256 value_ = uint256(keccak256(abi.encodePacked(seed_))) % WEIGHTS_RANGE + 1;

        for (uint256 i = 0; i < targetContracts.length; i++) {
            range_ += weights[i];
            if (value_ <= range_ && weights[i] != 0) {
                numOfCalls[targetContracts[i]]++;
                IHandlerEntryPoint(targetContracts[i]).entryPoint(seed_);
                break;
            }
        }
    }

}
