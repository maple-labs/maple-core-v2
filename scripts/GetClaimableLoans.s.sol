// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console } from "../modules/contract-test-utils/contracts/test.sol";

import { IMapleLoanLike, IPoolV1Like } from "../simulations/mainnet/Interfaces.sol";
import { SimulationBase }              from "../simulations/mainnet/SimulationBase.sol";

contract GetClaimableLoans is SimulationBase {

    function run() external {
        console.log("mavenPermissioned");
        getClaimableLoans(mavenPermissionedPoolV1, mavenPermissionedLoans);

        console.log("mavenUsdc");
        getClaimableLoans(mavenUsdcPoolV1, mavenUsdcLoans);

        console.log("mavenWeth");
        getClaimableLoans(mavenWethPoolV1, mavenWethLoans);

        console.log("orthogonal");
        getClaimableLoans(orthogonalPoolV1, orthogonalLoans);
    }

    function getClaimableLoans(address poolV1, address[] storage loans) internal {
        address poolDelegate = IPoolV1Like(poolV1).poolDelegate();

        for (uint256 i; i < loans.length; ++i) {
            IMapleLoanLike loan = IMapleLoanLike(loans[i]);

            if (loan.claimableFunds() == 0) continue;

            console.log("claimable loan", address(loan));
            console.log("PD", poolDelegate);
        }
    }

}
