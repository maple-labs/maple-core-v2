// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IPoolManagerLike, IPoolPermissionManagerLike } from "../interfaces/Interfaces.sol";

import { IHealthChecker } from "../interfaces/IHealthChecker.sol";
import { InvariantResult } from "../interfaces/IHealthCheckerRouter.sol";

contract PoolPermissionManagerHealthChecker is IHealthChecker {

    uint256 internal constant MAXIMUM_BITMAP          = 2 ** 16 - 1;
    uint256 internal constant PUBLIC_PERMISSION_LEVEL = 3;

    bytes32 internal constant FN_REDEEM              = "P:redeem";
    bytes32 internal constant FN_MINT                = "P:mint";
    bytes32 internal constant FN_MINT_WITH_PERMIT    = "P:mintWithPermit";
    bytes32 internal constant FN_WITHDRAW            = "P:withdraw";
    bytes32 internal constant FN_DEPOSIT_WITH_PERMIT = "P:depositWithPermit";
    bytes32 internal constant FN_DEPOSIT             = "P:deposit";
    bytes32 internal constant FN_TRANSFER            = "P:transfer";
    bytes32 internal constant FN_TRANSFER_FROM       = "P:transferFrom";
    bytes32 internal constant FN_REMOVE_SHARES       = "P:removeShares";
    bytes32 internal constant FN_REQUEST_REDEEM      = "P:requestRedeem";
    bytes32 internal constant FN_REQUEST_WITHDRAW    = "P:requestWithdraw";

    function check(bytes calldata input_) external view override returns (InvariantResult[] memory results_) {
        (address poolManager_, address[] memory lenders_) = abi.decode(input_, (address, address[]));

        address poolPermissionManager_ = IPoolManagerLike(poolManager_).poolPermissionManager();

        results_ = new InvariantResult[](3);

        results_[0] = _checkInvariantA(poolPermissionManager_, poolManager_);
        results_[1] = _checkInvariantB(poolPermissionManager_, poolManager_);
        results_[2] = _checkInvariantC(poolPermissionManager_, lenders_);
    }

    /**************************************************************************************************************************************/
    /*** Invariant A: permissionLevel in [0, 3]                                                                                         ***/
    /**************************************************************************************************************************************/

    function _checkInvariantA(address poolPermissionManager_, address poolManager_) internal view returns (InvariantResult memory result_) {
        uint256 permissionLevel_ = IPoolPermissionManagerLike(poolPermissionManager_).permissionLevels(poolManager_);

        result_ = InvariantResult({
            name:   "PPM Invariant A",
            output: abi.encode(permissionLevel_),
            valid:  permissionLevel_ <= PUBLIC_PERMISSION_LEVEL
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant B: poolBitmaps[pm][functionId] in [0, MAX], for every hardcoded functionId                                           ***/
    /**************************************************************************************************************************************/

    function _checkInvariantB(address poolPermissionManager_, address poolManager_) internal view returns (InvariantResult memory result_) {
        bytes32[11] memory functionIds_ = [
            FN_REDEEM,
            FN_MINT,
            FN_MINT_WITH_PERMIT,
            FN_WITHDRAW,
            FN_DEPOSIT_WITH_PERMIT,
            FN_DEPOSIT,
            FN_TRANSFER,
            FN_TRANSFER_FROM,
            FN_REMOVE_SHARES,
            FN_REQUEST_REDEEM,
            FN_REQUEST_WITHDRAW
        ];

        for (uint256 i; i < functionIds_.length; ++i) {
            uint256 bitmap_ = IPoolPermissionManagerLike(poolPermissionManager_).poolBitmaps(poolManager_, functionIds_[i]);

            if (bitmap_ > MAXIMUM_BITMAP) {
                return InvariantResult({
                    name:   "PPM Invariant B",
                    output: abi.encode(functionIds_[i], bitmap_),
                    valid:  false
                });
            }
        }

        result_ = InvariantResult({
            name:   "PPM Invariant B",
            output: "",
            valid:  true
        });
    }

    /**************************************************************************************************************************************/
    /*** Invariant C: lenderBitmaps[lender] in [0, MAX], for every lender                                                               ***/
    /**************************************************************************************************************************************/

    function _checkInvariantC(
        address poolPermissionManager_,
        address[] memory lenders_
    )
        internal
        view
        returns (InvariantResult memory result_)
    {
        for (uint256 i; i < lenders_.length; ++i) {
            uint256 bitmap_ = IPoolPermissionManagerLike(poolPermissionManager_).lenderBitmaps(lenders_[i]);

            if (bitmap_ > MAXIMUM_BITMAP) {
                return InvariantResult({
                    name:   "PPM Invariant C",
                    output: abi.encode(lenders_[i], bitmap_),
                    valid:  false
                });
            }
        }

        result_ = InvariantResult({
            name:   "PPM Invariant C",
            output: "",
            valid:  true
        });
    }

}
