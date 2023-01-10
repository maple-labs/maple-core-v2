// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { LoanManager } from "../../../../modules/pool-v2/contracts/LoanManager.sol";

contract LoanManagerHarness is LoanManager {

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
