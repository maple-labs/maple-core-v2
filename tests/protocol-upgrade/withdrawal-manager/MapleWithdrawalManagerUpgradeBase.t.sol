// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IMapleProxyFactory, IPool, IWithdrawalManagerQueue } from "../../../contracts/interfaces/Interfaces.sol";

import { ProtocolActions } from "../../../contracts/ProtocolActions.sol";
import { Runner }          from "../../../contracts/Runner.sol";

import { UpgradeAddressRegistry } from "../UpgradeAddressRegistry.sol";

contract MapleWithdrawalManagerUpgradeBaseTest is Runner, UpgradeAddressRegistry, ProtocolActions {

    address accountA                = makeAddr("accountA");
    address accountB                = makeAddr("accountB");
    address cancelledRequestAccount = makeAddr("cancelledRequestAccount");

    uint256 accountARequestAmount        = 2e6;
    uint256 accountBRequestAmount        = 4e6;
    uint256 cancelledRequestAmount       = 9e6;
    uint256 accountAPartialProcessAmount = 1e6;

    mapping(address => QueueState) internal queueStateBefore;

    struct QueueState {
        uint256 nextRequestId;
        uint256 lastRequestId;
        uint256 accountARequestId;
        uint256 accountBRequestId;
    }

    function setUp() public virtual {
        // Block 23211261 has no pending redemption requests.
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 23211261);

        for (uint256 i; i < withdrawalManagerQueuesToUpgrade.length; ++i) {
            address wm      = withdrawalManagerQueuesToUpgrade[i];
            address pool    = IWithdrawalManagerQueue(wm).pool();
            uint256 version = IMapleProxyFactory(withdrawalManagerQueueFactory).versionOf(IWithdrawalManagerQueue(wm).implementation());

            assertEq(version, 100);

            queueStateBefore[wm] = _seedQueueRequests(pool, wm);
        }

        _upgradeWithdrawalManagers();
    }

    function _upgradeWithdrawalManagers() internal {
        mapleWithdrawalManagerV200Implementation = deployFromFile("Contracts@7", "WithdrawalManagerQueue");
        mapleWithdrawalManagerV200Migrator       = deployFromFile("Contracts@7", "WithdrawalManagerQueueMigrator");
        mapleWithdrawalManagerV200Initializer    = deployFromFile("Contracts@7", "WithdrawalManagerQueueInitializer");

        vm.startPrank(governor);

        IMapleProxyFactory(withdrawalManagerQueueFactory).registerImplementation(
            200,
            mapleWithdrawalManagerV200Implementation,
            mapleWithdrawalManagerV200Initializer
        );

        IMapleProxyFactory(withdrawalManagerQueueFactory).enableUpgradePath(100, 200, mapleWithdrawalManagerV200Migrator);
        IMapleProxyFactory(withdrawalManagerQueueFactory).setDefaultVersion(200);

        vm.stopPrank();

        for (uint256 i; i < withdrawalManagerQueuesToUpgrade.length; ++i) {
            IWithdrawalManagerQueue wm = IWithdrawalManagerQueue(withdrawalManagerQueuesToUpgrade[i]);

            vm.prank(securityAdmin);
            wm.upgrade(200, "");

            assertEq(wm.implementation(), mapleWithdrawalManagerV200Implementation);
            
            assertEq(IMapleProxyFactory(withdrawalManagerQueueFactory).versionOf(wm.implementation()), 200);
        }
    }

    function _seedQueueRequests(address pool_, address wmQueue_) internal returns (QueueState memory queueState) {
        IWithdrawalManagerQueue wm = IWithdrawalManagerQueue(wmQueue_);
        address poolManager        = wm.poolManager();
        uint256 totalSharesLocked  = wm.totalShares();

        openPool(poolManager);
        setLiquidityCap(poolManager, type(uint256).max);

        // Clear Queue before seeding
        if (totalSharesLocked > 0) {
            // mint pool underlying to pool to cover share processing
            uint256 assetAmount = IPool(pool_).convertToExitAssets(totalSharesLocked);
            address asset       = IPool(pool_).asset();

            erc20_mint(asset, pool_, assetAmount);

            processRedemptions(pool_, totalSharesLocked);
        }

        mint(pool_, accountA,                accountARequestAmount);
        mint(pool_, cancelledRequestAccount, cancelledRequestAmount);
        mint(pool_, accountB,                accountBRequestAmount);

        ( uint256 nextRequestIdBefore, uint256 lastRequestIdBefore ) = wm.queue();

        requestRedeem(pool_, accountA, accountARequestAmount);

        uint256 sharesToCancel = requestRedeem(pool_, cancelledRequestAccount, cancelledRequestAmount);

        removeShares(pool_, cancelledRequestAccount, sharesToCancel);

        requestRedeem(pool_, accountB, accountBRequestAmount);

        ( queueState.nextRequestId, queueState.lastRequestId ) = wm.queue();

        queueState.accountARequestId = wm.requestIds(accountA);
        queueState.accountBRequestId = wm.requestIds(accountB);

        assertEq(queueState.nextRequestId, nextRequestIdBefore);
        assertEq(queueState.lastRequestId, lastRequestIdBefore + 3);  // Note: +3 as 3 new requests were created during seeding.

        processRedemptions(pool_, accountAPartialProcessAmount);
    }

}
