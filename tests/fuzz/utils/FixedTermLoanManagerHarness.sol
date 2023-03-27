// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { FixedTermLoanManager } from "../../../contracts/Contracts.sol";

// TODO: This existing implies unit tests are being done somewhere, rather than integration tests.
contract FixedTermLoanManagerHarness is FixedTermLoanManager {

    function __setAccountedInterest(uint256 accountedInterest_) external {
        accountedInterest = uint112(accountedInterest_);
    }

    function __setPrincipalOut(uint256 principalOut_) external {
        principalOut = uint128(principalOut_);
    }

    function __setUnrealizedLosses(uint256 unrealizedLosses_) external {
        unrealizedLosses = uint128(unrealizedLosses_);
    }

}
