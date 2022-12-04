// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console } from "../modules/contract-test-utils/contracts/test.sol";

import { IERC20Like, IMapleLoanLike, IPoolLike } from "../simulations/mainnet/Interfaces.sol";
import { SimulationBase }            from "../simulations/mainnet/SimulationBase.sol";

contract GetFrozenPoolState is SimulationBase {

    function run() external {
        console.log("mavenPermissioned");
        getPoolState(mavenPermissionedPoolV1, mavenPermissionedLps);

        console.log("mavenUsdc");
        getPoolState(mavenUsdcPoolV1, mavenUsdcLps);

        console.log("mavenWeth");
        getPoolState(mavenWethPoolV1, mavenWethLps);

        console.log("orthogonal");
        getPoolState(orthogonalPoolV1, orthogonalLps);

        console.log("icebreaker");
        getPoolState(icebreakerPoolV1, icebreakerLps);
    }

    function getPoolState(IPoolLike poolV1, address[] storage lps) internal {
        IERC20Like fundsAsset = IERC20Like(poolV1.liquidityAsset());

        address liquidityLocker = poolV1.liquidityLocker();

        uint256 cash = fundsAsset.balanceOf(liquidityLocker);

        console.log("cash        ", cash);
        console.log("principalOut", poolV1.principalOut());

        console.log("poolValue", getPoolV1TotalValue(poolV1));
        console.log("sumLps   ", getSumPosition(poolV1, lps));
    }

}
