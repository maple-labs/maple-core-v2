// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC20,
    Permit
} from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract SyrupBitcoinTestBase is TestBaseWithAssertions {

    function setUp() public virtual override {
        _setupBitcoinPool();
    }

    function calculateFee(uint256 amount, uint256 fee) internal pure returns (uint256 fee_) {
        uint256 HUNDRED_PERCENT = 1e6;  // 100.0000%
        fee_ = (amount * fee + HUNDRED_PERCENT - 1) / HUNDRED_PERCENT;
    }

    function emptyPermit() internal pure returns (Permit memory permit) {
        permit = Permit(false, 0, 0, 0, 0);
    }

    function requestRouterRedeem(address lp, uint256 assets) internal returns (uint256 shares, uint256 requestId) {
        vm.startPrank(lp);

        depositAsset.mint(lp, assets);
        depositAsset.approve(address(bitcoinRouter), assets);
        shares = bitcoinRouter.deposit(address(depositAsset), assets, EMPTY_METADATA, emptyPermit());
        pool.approve(address(bitcoinRouter), shares);
        ( shares, requestId ) = bitcoinRouter.requestRedeem(address(depositAsset), shares, EMPTY_METADATA, emptyPermit());

        vm.stopPrank();
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

}
