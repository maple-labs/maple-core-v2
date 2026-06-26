// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { 
    IMapleProxyFactory,
    IProxiedLike
} from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

contract WithdrawalManagerQueueViewFunctionsAdditionalTests is TestBaseWithAssertions {

    address lp = makeAddr("lp");

    function setUp() public override {
        super.setUp();

        deposit(lp, 1_000e6);
    }

    function test_factory() external view {
        assertEq(queueWM.factory(), queueWMFactory);
    }

    function test_implementation_updatesAfterUpgrade() external {
        address oldImplementation = queueWM.implementation();

        address newImplementation = deployFromFile("Contracts@7", "WithdrawalManagerQueue");

        uint256 oldVersion = IMapleProxyFactory(queueWMFactory).versionOf(oldImplementation);
        uint256 newVersion = 201;

        vm.startPrank(governor);
        IMapleProxyFactory(queueWMFactory).registerImplementation(newVersion, newImplementation, address(0));
        IMapleProxyFactory(queueWMFactory).enableUpgradePath(oldVersion, newVersion, address(0));
        vm.stopPrank();

        vm.prank(securityAdmin);
        IProxiedLike(address(queueWM)).upgrade(newVersion, "");

        assertEq(queueWM.implementation(), newImplementation);
    }

    function test_globals_updatesAfterFactorySetGlobals() external {
        assertEq(queueWM.globals(), address(globals));

        address newGovernor = makeAddr("newGovernor");
        address newGlobals  = deployNTP(newGovernor, deploy("MapleGlobals"));

        vm.prank(governor);
        IMapleProxyFactory(queueWMFactory).setGlobals(newGlobals);

        assertEq(queueWM.globals(), newGlobals);
    }

    function test_governor_updatesWhenGlobalsChanges() external {
        assertEq(queueWM.governor(), globals.governor());

        address newGovernor = makeAddr("newGovernor2");
        address newGlobals  = deployNTP(newGovernor, deploy("MapleGlobals"));

        vm.prank(governor);
        IMapleProxyFactory(queueWMFactory).setGlobals(newGlobals);

        assertEq(queueWM.governor(), newGovernor);
    }

    function test_isInExitWindow() external view {
        assertTrue(queueWM.isInExitWindow(lp));
    }

    function test_lockedLiquidity_constantZero() external {
        assertEq(queueWM.lockedLiquidity(), 0);

        requestRedeem(lp, 50e6);
        processRedemptionByOwners(address(pool), array(lp));
        assertEq(queueWM.lockedLiquidity(), 0);
    }

    function test_lockedShares_updatesAfterProcessing() external {
        assertEq(queueWM.lockedShares(lp), 0);

        setManualWithdrawal(address(poolManager), lp, true);
        requestRedeem(lp, 100e6);
        processRedemptionByOwners(address(pool), array(lp));

        assertEq(queueWM.lockedShares(lp), 100e6);
    }

    function test_poolDelegate_updatesAfterTransfer() external {
        address initialPD = queueWM.poolDelegate();
        assertEq(initialPD, poolManager.poolDelegate());

        address newPD = makeAddr("newPD");

        vm.prank(initialPD);
        poolManager.setPendingPoolDelegate(newPD);

        vm.prank(governor);
        globals.setValidPoolDelegate(newPD, true);

        vm.prank(newPD);
        poolManager.acceptPoolDelegate();

        assertEq(queueWM.poolDelegate(), newPD);
    }

    function test_previewRedeem_reflectsUpdatedManualShares() external {
        ( uint256 rs0, uint256 ra0 ) = queueWM.previewRedeem(lp, 1);
        assertEq(rs0, 0);
        assertEq(ra0, 0);

        setManualWithdrawal(address(poolManager), lp, true);
        requestRedeem(lp, 200e6);
        processRedemptionByOwners(address(pool), array(lp));

        ( uint256 rs1, uint256 ra1 ) = queueWM.previewRedeem(lp, 50e6);
        assertEq(rs1, 50e6);
        assertTrue(ra1 > 0);
    }

    function test_previewWithdraw_alwaysZero() external {
        ( uint256 redeemableAssets_, uint256 resultingShares_ ) = queueWM.previewWithdraw(address(0), 0);
        assertEq(redeemableAssets_, 0);
        assertEq(resultingShares_,  0);

        requestRedeem(lp, 10e6);
        ( redeemableAssets_, resultingShares_ ) = queueWM.previewWithdraw(address(lp), 1);
        assertEq(redeemableAssets_, 0);
        assertEq(resultingShares_,  0);
    }

    function test_requestIds_updatesAfterRequestRedeem() external {
        assertEq(queueWM.requestIds(lp), 0);

        requestRedeem(lp, 100e6);

        assertEq(queueWM.requestIds(lp), 1);
    }

    function test_requests_updatesAfterAddAndRemove() external {
        requestRedeem(lp, 75e6);

        ( address ownerAdd_, uint256 sharesAdd_ ) = queueWM.requests(1);
        assertEq(ownerAdd_,  lp);
        assertEq(sharesAdd_, 75e6);

        address[] memory owners     = new address[](1);
        uint256[] memory requestIds = new uint256[](1);
        owners[0]                   = lp;
        requestIds[0]               = 1;

        vm.prank(poolManager.poolDelegate());
        queueWM.removeRequest(lp, requestIds);

        ( address ownerRem_, uint256 sharesRem_ ) = queueWM.requests(1);
        assertEq(ownerRem_,  address(0));
        assertEq(sharesRem_, 0);
    }

    function test_pool_address_constant() external view {
        assertEq(queueWM.pool(), address(pool));
    }

    function test_poolManager_address_constant() external view {
        assertEq(queueWM.poolManager(), address(poolManager));
    }

    function test_asset_constantAddress() external {
        assertEq(queueWM.asset(), address(fundsAsset));

        requestRedeem(lp, 10e6);
        processRedemptionByOwners(address(pool), array(lp));

        assertEq(queueWM.asset(), address(fundsAsset));
    }

    function test_queue_updatesAfterRequestAndProcess() external {
        ( uint128 nextId0, uint128 lastId0 ) = queueWM.queue();
        assertEq(nextId0, 1);
        assertEq(lastId0, 0);

        requestRedeem(lp, 100e6);

        ( uint128 nextId1, uint128 lastId1 ) = queueWM.queue();
        assertEq(nextId1, 1);
        assertEq(lastId1, 1);

        processRedemptionByOwners(address(pool), array(lp));

        ( uint128 nextId2, uint128 lastId2 ) = queueWM.queue();
        assertEq(nextId2, 2);
        assertEq(lastId2, 1);
    }

    function test_pendingRequestIds_updatesAfterProcessingWithPagination() external {
        address lp2 = makeAddr("lp2");
        address lp3 = makeAddr("lp3");

        deposit(lp2, 2_000e6);
        deposit(lp3, 3_000e6);

        requestRedeem(lp,  1_000e6);
        requestRedeem(lp2, 2_000e6);
        requestRedeem(lp3, 3_000e6);

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp,  shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: lp2, shares: 2_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp3, shares: 3_000e6 });

        // remove the middle request
        processRedemptionByIds(address(pool), array(2));

        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp,         shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 2, owner: address(0), shares: 0 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp3,        shares: 3_000e6 });

        (
            uint256[] memory requestIds,
            address[] memory owners,
            uint256[] memory shares
        ) = queueWM.pendingRequestIds(0, type(uint256).max);

        assertEq(requestIds.length, 2);
        assertEq(owners.length,     2);
        assertEq(shares.length,     2);

        assertEq(requestIds[0], 1);
        assertEq(requestIds[1], 3);
        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp,  shares: 1_000e6 });
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp3, shares: 3_000e6 });

        // pagination should give first request
        ( requestIds, owners, shares ) = queueWM.pendingRequestIds(0, 1);

        assertEq(requestIds.length, 1);
        assertEq(owners.length,     1);
        assertEq(shares.length,     1);

        assertEq(requestIds[0], 1);
        assertRequest({ poolManager: address(poolManager), requestId: 1, owner: lp, shares: 1_000e6 });

        // pagination should give second request
        ( requestIds, owners, shares ) = queueWM.pendingRequestIds(1, 1);

        assertEq(requestIds.length, 1);
        assertEq(owners.length,     1);
        assertEq(shares.length,     1);

        assertEq(requestIds[0], 3);
        assertRequest({ poolManager: address(poolManager), requestId: 3, owner: lp3, shares: 3_000e6 });

        // pagination should return empty arrays when start is out of bounds
        ( requestIds, owners, shares ) = queueWM.pendingRequestIds(2, 1);

        assertEq(requestIds.length, 0);
        assertEq(owners.length,     0);
        assertEq(shares.length,     0);

        // pagination should return empty arrays when limit is zero
        ( requestIds, owners, shares ) = queueWM.pendingRequestIds(0, 0);

        assertEq(requestIds.length, 0);
        assertEq(owners.length,     0);
        assertEq(shares.length,     0);
    }

    function test_securityAdmin_updatesAfterChange() external {
        assertEq(queueWM.securityAdmin(), securityAdmin);

        address newSA = makeAddr("newSecAdmin");

        vm.prank(governor);
        globals.setSecurityAdmin(newSA);

        assertEq(queueWM.securityAdmin(), newSA);
    }

}
