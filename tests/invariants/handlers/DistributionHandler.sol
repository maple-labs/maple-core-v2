// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { Test } from "../../../modules/forge-std/src/Test.sol";

import { IHandlerEntryPoint } from "../../../contracts/interfaces/Interfaces.sol";

contract DistributionHandler is Test {

    /**************************************************************************************************************************************/
    /*** Constants                                                                                                                      ***/
    /**************************************************************************************************************************************/

    uint256 internal constant WEIGHTS_RANGE    = 100;
    uint256 internal constant MAX_TIME_TO_PASS = 2 days;

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    address[] public contracts;

    uint256[] public weights;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    // NOTE: Order of arrays must match.
    constructor(address[] memory contracts_, uint256[] memory weights_) {
        require(contracts_.length == weights_.length, "DH:INVALID_LENGTHS");

        uint256 weightsTotal;

        for (uint256 i; i < weights_.length; ++i) {
            weightsTotal += weights_[i];
        }

        require(weightsTotal == WEIGHTS_RANGE, "DH:INVALID_WEIGHTS");

        contracts = contracts_;
        weights   = weights_;
    }

    /**************************************************************************************************************************************/
    /*** Entry Point                                                                                                                    ***/
    /**************************************************************************************************************************************/

    function distributorEntryPoint(uint256 seed_) external {
        uint256 range_;
        uint256 value_ = uint256(keccak256(abi.encodePacked(seed_))) % WEIGHTS_RANGE + 1;

        for (uint256 i = 0; i < contracts.length; i++) {
            range_ += weights[i];

            if (value_ <= range_ && weights[i] != 0) {
                uint256 currentTimestamp_ = block.timestamp;
                uint256 timeToPass_       = _bound(seed_, 0, MAX_TIME_TO_PASS);

                vm.warp(currentTimestamp_ + timeToPass_);

                IHandlerEntryPoint(contracts[i]).entryPoint(seed_);
                break;
            }
        }
    }

}
