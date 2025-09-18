// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IERC20,
    Permit
} from "../../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../../TestBase.sol";

contract SyrupBitcoinTestBase is TestBase {

    bytes32 public constant EMPTY_METADATA = "";

    function setUp() public virtual override {
        _setupBitcoinPool();
    }

    function assertAccounting(
        uint256 outstandingAssets,
        uint256 realizedFees,
        uint256 accruedYield,
        uint256 accruedFees,
        uint256 assetsUnderManagement
    )
        internal
    {
        assertEq(bitcoinStrategy.outstandingAssets(),     outstandingAssets);
        assertEq(bitcoinStrategy.realizedFees(),          realizedFees);
        assertEq(bitcoinStrategy.accruedYield(),          accruedYield);
        assertEq(bitcoinStrategy.accruedFees(),           accruedFees);
        assertEq(bitcoinStrategy.assetsUnderManagement(), assetsUnderManagement);
    }

    function assertImpairment(uint256 impairedAssets, uint256 unrealizedLosses) internal {
        assertEq(bitcoinStrategy.impairedAssets(),   impairedAssets);
        assertEq(bitcoinStrategy.unrealizedLosses(), unrealizedLosses);
    }

    function assertSchedule(
        uint256 remainingYield,
        uint32  remainingDuration,
        uint32  lastUpdated,
        uint256 yieldRate
    )
        internal
    {
        ( uint256 remainingYield_, uint32 lastUpdated_, uint32 remainingDuration_ ) = bitcoinStrategy.schedules(0);

        uint256 yieldRate_ = bitcoinStrategy.yieldRate();

        assertEq(remainingYield_,    remainingYield);
        assertEq(remainingDuration_, remainingDuration);
        assertEq(lastUpdated_,       lastUpdated);
        assertEq(yieldRate_,         yieldRate);
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
        fee_ = (amount * fee + HUNDRED_PERCENT - 1) / HUNDRED_PERCENT;
    }

}
