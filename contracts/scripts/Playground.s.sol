// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console } from "../../modules/contract-test-utils/contracts/test.sol";

import { IERC20Like, IMapleGlobalsV2Like, IMapleLoanLike, IPoolV1Like, IPoolV2Like } from "../mainnet-simulations/Interfaces.sol";

import { MigrationHelper, SimulationBase } from "../mainnet-simulations/SimulationBase.sol";

contract Playground is SimulationBase {

    function run() external {
        // address migrationHelper       = 0xb36419f1790CAebf85dd45dF659199F9957c41A4;
        // address transitionLoanManager = 0x2AD0Fc5d17a1bBb9bC7D85657936F77224397197;
        // address poolManager           = 0x2701e9830e202673115Ed6846787Ecf611914452;
        // address pool                  = 0x0a9d42fE89A0664c4e9439bA4651B18434F63076;
        // address mapleGlobals          = 0x8FA4d5ABCa02d359c142EB703DcD7038BD41eB3D;

        // for (uint256 i; i < mavenPermissionedLoans.length; ++i) {
        //     console.log("loan     ", address(mavenPermissionedLoans[i]));
        //     console.log("principal", mavenPermissionedLoans[i].principal());
        // }

        // console.log("pool.totalSupply()", IPoolV2Like(pool).totalSupply());
        // console.log("pool.totalAssets()", IPoolV2Like(pool).totalAssets());

        // for (uint256 i; i < mavenUsdcLps.length; ++i) {
        //     console.log("");
        //     console.log("lpBal ", IPoolV2Like(pool).balanceOf(mavenUsdcLps[i]));
        //     console.log("lpVal ", IPoolV2Like(pool).convertToAssets(IPoolV1Like(pool).balanceOf(mavenUsdcLps[i])));
        // }

        // orthogonalLoans.push(IMapleLoanLike(0x061fE80139a79DD67eE040c44f19eEe1Fcd04BCC));

        // uint256 sum;

        // for (uint256 i; i < orthogonalLoans.length; ++i) {
        //     sum += orthogonalLoans[i].principal();
        // }

        // console.log("sum         ", sum);
        // console.log("principalOut", orthogonalPoolV1.principalOut());

        // vm.prank(migrationMultisig);
        // MigrationHelper(migrationHelper).addLoansToLoanManager(address(orthogonalPoolV1), 0x84D7a18B7738EBCDc2A5d1AD630A9c7ff08733db, convertToAddresses(orthogonalLoans), 0);

        // vm.prank(tempGovernor);
        // IMapleGlobalsV2Like(mapleGlobals).activatePoolManager(poolManager);

        // vm.prank(migrationMultisig);
        // MigrationHelper(migrationHelper).setPendingLenders(address(mavenPermissionedPoolV1), poolManager, address(loanFactory), convertToAddresses(mavenPermissionedLoans), 0);

        // vm.prank(migrationMultisig);
        // MigrationHelper(migrationHelper).airdropTokens(address(mavenWethPoolV1), 0xa6a1aDB69dC80b9F01e2b7F4cc12Acb94180A22B, mavenWethLps, mavenWethLps, 84);
    }

    // function getPoolState(IPoolV1Like poolV1, address[] storage lps) internal {
    //     IERC20Like fundsAsset = IERC20Like(poolV1.liquidityAsset());

    //     address liquidityLocker = poolV1.liquidityLocker();

    //     uint256 cash = fundsAsset.balanceOf(liquidityLocker);

    //     console.log("cash        ", cash);
    //     console.log("principalOut", poolV1.principalOut());

    //     console.log("poolValue", getPoolV1TotalValue(poolV1));
    //     console.log("sumLps   ", getSumPosition(poolV1, lps));
    // }

}
