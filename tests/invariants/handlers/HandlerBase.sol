// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IHandlerEntryPoint,
    IWithdrawalManagerQueue
} from "../../../contracts/interfaces/Interfaces.sol";

import { ProtocolActions } from "../../../contracts/ProtocolActions.sol";
import { Utils }           from "../../../contracts/Utils.sol";

import { console } from "../../../contracts/Runner.sol";

contract HandlerBase is ProtocolActions, Utils, IHandlerEntryPoint {

    /**************************************************************************************************************************************/
    /*** Constants                                                                                                                      ***/
    /**************************************************************************************************************************************/

    uint256 constant internal WEIGHTS_RANGE = 10_000;

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    uint256 public totalWeight;

    string public handlerName;

    bytes4[] public selectors;

    mapping(bytes4 => string)  public signatureOf;
    mapping(bytes4 => uint256) public weightOf;

    mapping(string => uint256) public numberOfCalls;
    mapping(string => uint256) public numberOfSkips;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(string memory handlerName_) {
        require(bytes(handlerName_).length != 0, "HB:INVALID_NAME");

        handlerName = handlerName_;
    }

    /**************************************************************************************************************************************/
    /*** Configuration                                                                                                                  ***/
    /**************************************************************************************************************************************/

    function addAction(string memory signature_, uint256 weight_) external {
        bytes4 selector_ = bytes4(keccak256(bytes(signature_)));

        require(bytes(signatureOf[selector_]).length == 0, "HB:DUPLICATE_ACTION");

        totalWeight += weight_;

        selectors.push(selector_);

        signatureOf[selector_] = signature_;
        weightOf[selector_]    = weight_;
    }

    /**************************************************************************************************************************************/
    /*** Entry Point                                                                                                                    ***/
    /**************************************************************************************************************************************/

    function entryPoint(uint256 seed_) external override {
        require(totalWeight == WEIGHTS_RANGE, "HB:INVALID_WEIGHTS");

        uint256 range_;
        uint256 value_ = uint256(keccak256(abi.encodePacked(seed_))) % WEIGHTS_RANGE + 1;

        for (uint256 i = 0; i < selectors.length; i++) {
            uint256 weight_ = weightOf[selectors[i]];

            range_ += weight_;

            if (value_ <= range_ && weight_ != 0) {
                string memory actionName_ = _actionName(selectors[i]);

                console.log(string(abi.encodePacked(actionName_, " (seed=%s)")), seed_);

                numberOfCalls[""]++;
                numberOfCalls[actionName_]++;

                ( bool success, ) = address(this).call(abi.encodeWithSelector(selectors[i], seed_));

                require(success, "HB:CALL_FAILED");
                break;
            }
        }
    }

    /**************************************************************************************************************************************/
    /*** Utility Functions                                                                                                              ***/
    /**************************************************************************************************************************************/

    function _actionName() internal view returns (string memory actionName_) {
        actionName_ = _actionName(msg.sig);
    }

    function _actionName(bytes4 selector_) internal view returns (string memory actionName_) {
        actionName_ = string(abi.encodePacked(handlerName, ".", signatureOf[selector_]));
    }

    function _min(uint256 a_, uint256 b_) internal pure returns (uint256 min_) {
        min_ = a_ < b_ ? a_ : b_;
    }

    function _randomize(uint256 seed, string memory salt) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(seed, salt)));
    }

    function _recordSkip() internal {
        numberOfSkips[""]++;
        numberOfSkips[_actionName()]++;
    }

}
