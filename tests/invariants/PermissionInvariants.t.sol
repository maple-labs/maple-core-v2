// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { DistributionHandler } from "./handlers/DistributionHandler.sol";
import { PermissionHandler }   from "./handlers/PermissionHandler.sol";

import { BaseInvariants } from "./BaseInvariants.t.sol";

contract PermissionInvariants is BaseInvariants {

    uint256 constant NUM_LPS = 100;

    /**************************************************************************************************************************************/
    /*** Setup Function                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function setUp() public override {
        start = currentTimestamp = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createAndConfigurePool(start, 1 weeks, 2 days);

        for (uint256 i; i < NUM_LPS; i++) {
            lps.push(makeAddr(string(abi.encode("lp", i))));
        }

        functionIds.push("P:redeem");
        functionIds.push("P:mint");
        functionIds.push("P:mintWithPermit");
        functionIds.push("P:withdraw");
        functionIds.push("P:depositWithPermit");
        functionIds.push("P:deposit");
        functionIds.push("P:transfer");
        functionIds.push("P:transferFrom");
        functionIds.push("P:removeShares");
        functionIds.push("P:requestRedeem");
        functionIds.push("P:requestWithdraw");

        permissionHandler = new PermissionHandler(address(poolPermissionManager), address(globals), lps, poolManagers, functionIds);

        permissionHandler.setSelectorWeight("setPoolPermissionLevel(uint256)", 1_000);
        permissionHandler.setSelectorWeight("setLenderBitmaps(uint256)",       7_000);
        permissionHandler.setSelectorWeight("setPoolBitmaps(uint256)",         2_000);

        address[] memory targetContracts = new address[](1);
        targetContracts[0] = address(permissionHandler);

        uint256[] memory weightsDistributorHandler = new uint256[](1);
        weightsDistributorHandler[0] = 100;

        address distributionHandler = address(new DistributionHandler(targetContracts, weightsDistributorHandler));

        targetContract(distributionHandler);
    }

    /**************************************************************************************************************************************/
    /*** Invariants                                                                                                                     ***/
    /**************************************************************************************************************************************/

    function statefulFuzz_permissionManager_A_B_C() external useCurrentTimestamp {
        assert_ppm_invariant_A(address(poolPermissionManager), address(poolManager));
        assert_ppm_invariant_B(address(poolPermissionManager), address(poolManager), functionIds);
        assert_ppm_invariant_C(address(poolPermissionManager), lps);
    }

}
