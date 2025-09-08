// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC20,
    Permit 
} from "../../../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../../../TestBase.sol";

contract SyrupBTCRouterTestBase is TestBase {

    function setUp() public virtual override {
        _setupBitcoinPool();
    }

    function emptyPermit() internal pure returns (Permit memory permit) {
        permit = Permit(false, 0, 0, 0, 0);
    }

    function signPermit(
        uint256 userPrivateKey,
        address asset,
        address owner,
        uint256 value,
        uint256 deadline
    )
        internal view returns (Permit memory permit)
    {
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                IERC20(asset).DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(IERC20(asset).PERMIT_TYPEHASH(),
                    owner,
                    address(bitcoinRouter),
                    value,
                    IERC20(asset).nonces(owner),
                    deadline)
                )
            )
        );

        ( permit.v, permit.r, permit.s ) = vm.sign(userPrivateKey, digest);
        permit.deadline = deadline;
        permit.enabled = true;
    }

    function calculateFee(uint256 amount, uint256 fee) internal pure returns (uint256 fee_) {
        uint256 HUNDRED_PERCENT = 1e6;  // 100.0000%
        fee_ = (amount * fee) / HUNDRED_PERCENT;
    }

}
