// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { DistributionHandler } from "./handlers/DistributionHandler.sol";
import { PermissionHandler }   from "./handlers/PermissionHandler.sol";

import { BaseInvariants } from "./BaseInvariants.t.sol";

contract PermissionInvariants is BaseInvariants {

    /**************************************************************************************************************************************/
    /*** Constants                                                                                                                      ***/
    /**************************************************************************************************************************************/

    uint256 constant NUM_LPS = 100;

    /**************************************************************************************************************************************/
    /*** Setup Function                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function setUp() public override {
        _setUpClosedPool();

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

        permissionHandler = new PermissionHandler({
            handlerName_:           "permissionHandler",
            poolPermissionManager_: address(poolPermissionManager),
            globals_:               address(globals),
            lenders_:               lps,
            poolManagers_:          poolManagers,
            functionIds_:           functionIds
        });

        permissionHandler.addAction("setPoolPermissionLevel(uint256)", 1_000);
        permissionHandler.addAction("setLenderBitmaps(uint256)",       7_000);
        permissionHandler.addAction("setPoolBitmaps(uint256)",         2_000);

        address[] memory targetContracts = new address[](1);
        targetContracts[0] = address(permissionHandler);

        uint256[] memory weightsDistributorHandler = new uint256[](1);
        weightsDistributorHandler[0] = 100;

        address distributionHandler = address(new DistributionHandler(targetContracts, weightsDistributorHandler));

        targetContract(distributionHandler);
    }

    function statefulFuzz_permissionManager_invariants() external view {
        assert_ppm_invariants(address(poolPermissionManager));
    }

}
