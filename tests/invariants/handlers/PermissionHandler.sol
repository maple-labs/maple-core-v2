// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IGlobals, IPoolPermissionManager } from "../../../contracts/interfaces/Interfaces.sol";

import { HandlerBase } from "./HandlerBase.sol";

contract PermissionHandler is HandlerBase {

    /**************************************************************************************************************************************/
    /*** Constants                                                                                                                      ***/
    /**************************************************************************************************************************************/

    uint256 constant MAX_BITMAP = 1e4;
    uint256 constant MIN_DEPTH  = 20;
    uint256 constant POOL_LEVEL = 2;
    uint256 constant PUBLIC     = 3;

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    address governor;

    address[] lenders;
    address[] poolManagers;

    bytes32[] functionIds;

    IPoolPermissionManager public ppm;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(
        string memory handlerName_,
        address poolPermissionManager_,
        address globals_,
        address[] memory lenders_,
        address[] memory poolManagers_,
        bytes32[] memory functionIds_
    )
        HandlerBase(handlerName_)
    {
        ppm      = IPoolPermissionManager(poolPermissionManager_);
        governor = IGlobals(globals_).governor();

        lenders      = lenders_;
        poolManagers = poolManagers_;
        functionIds  = functionIds_;
    }

    /**************************************************************************************************************************************/
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function setLenderBitmaps(uint256 seed_) public {
        uint256[] memory bitmaps = _selectBitmaps(seed_, lenders.length);

        vm.prank(governor);
        ppm.setLenderBitmaps(lenders, bitmaps);
    }

    function setPoolBitmaps(uint256 seed_) public {
        address          poolManager = _selectPoolManager(seed_);
        uint256[] memory bitmaps     = _selectBitmaps(seed_, functionIds.length);

        vm.prank(governor);
        ppm.setPoolBitmaps(poolManager, functionIds, bitmaps);
    }

    function setPoolPermissionLevel(uint256 seed_) public {
        address poolManager     = _selectPoolManager(seed_);
        uint256 permissionLevel = _selectPermissionLevel(seed_, numberOfCalls[_actionName()]);

        if (ppm.permissionLevels(poolManager) == PUBLIC) {
            _recordSkip();
            return;
        }

        vm.prank(governor);
        ppm.setPoolPermissionLevel(poolManager, permissionLevel);
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _selectPoolManager(uint256 seed_) internal view returns (address poolManager_) {
        uint256 index = _bound(seed_, 0, poolManagers.length - 1);

        poolManager_ = poolManagers[index];
    }

    function _selectPermissionLevel(uint256 seed_, uint256 numberOfCalls_) internal pure returns (uint256 permissionLevel_) {
        uint256 maxPermissionLevel = numberOfCalls_ > 20 ? PUBLIC : POOL_LEVEL;

        permissionLevel_ = _bound(seed_, 0, maxPermissionLevel);
    }

    function _selectBitmaps(uint256 seed_, uint256 size_) internal pure returns (uint256[] memory bitmaps) {
        bitmaps = new uint256[](size_);

        for (uint256 i; i < size_; i++) {
            bitmaps[i] = _bound(uint256(keccak256(abi.encode(seed_, i))), 0, MAX_BITMAP);
        }
    }

}
