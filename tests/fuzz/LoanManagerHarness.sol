// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { LoanManager } from "../../modules/pool/contracts/LoanManager.sol";

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
