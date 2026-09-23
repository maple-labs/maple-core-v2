// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IMapleCCIPReceiverLike, IPool, IWithdrawalManagerQueue } from "../../contracts/interfaces/Interfaces.sol";

import { MapleAddressRegistryETH as AddressRegistry } from "../../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

import { ProtocolActions } from "../../contracts/ProtocolActions.sol";

import { ProtocolHealthChecker } from "../health-checkers/ProtocolHealthChecker.sol";

import { HealthCheckerAssertions } from "../HealthCheckerAssertions.sol";

interface IProtocolHealthCheckerV2 {

    function checkInvariants(address poolManager_) external view returns (ProtocolHealthChecker.Invariants memory invariants_);

}

interface IProtocolHealthCheckerV3 {

    function checkInvariants(
        address poolManager_,
        address[] memory manualRedeemers_
    )
        external
        view
        returns (ProtocolHealthChecker.Invariants memory invariants_);

}

contract ProtocolHealthCheckerV3Tests is AddressRegistry, HealthCheckerAssertions, ProtocolActions {

    uint64 constant BASE_CHAIN_SELECTOR = 15971525489660198786;

    /**************************************************************************************************************************************/
    /*** Mainnet Addresses                                                                                                              ***/
    /**************************************************************************************************************************************/

    address protocolHealthCheckerV2 = 0xfb8F87D716ac3fC54f33664F51E3961bc2DD3EDb;
    address redemptionExecutor      = 0xfB2C579c1D5f82C7b0f2a3479e5F9bC26bd22b62;

    address[] manualRedeemers = [mapleCCIPReceiverProxy];

    /**************************************************************************************************************************************/
    /*** New Addresses                                                                                                                  ***/
    /**************************************************************************************************************************************/

    address protocolHealthCheckerV3;

    function setUp() public {
        // In this block protocol health checker failed for SyrupUSDC pool due to CCIP receiver deployment.
        // CCIP Receiver was the first manual redeemer.
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 24376311);

        protocolHealthCheckerV3 = address(new ProtocolHealthChecker());
    }

    function testFork_protocolHealthCheckerV2_syrupUSDC_reverts_withdrawalManagerQueueInvariantA() public view {
        ProtocolHealthChecker.Invariants memory results =
            IProtocolHealthCheckerV2(protocolHealthCheckerV2).checkInvariants(syrupUSDCPoolManager);

        assertFalse(results.withdrawalManagerQueueInvariantA, "ProtocolHealthCheckerV2 should fail invariant A");
    }

    function testFork_protocolHealthCheckerV3_syrupUSDC_success_withdrawalManagerQueueInvariantA() public view {
        assertProtocolInvariants(syrupUSDCPoolManager, protocolHealthCheckerV3, manualRedeemers);

        ProtocolHealthChecker.Invariants memory results =
            IProtocolHealthCheckerV3(protocolHealthCheckerV3).checkInvariants(syrupUSDCPoolManager, manualRedeemers);

        assertTrue(results.withdrawalManagerQueueInvariantA, "ProtocolHealthCheckerV3 should pass invariant A");
    }

    function testFork_protocolHealthCheckerV3_securedLendingUSDC_syrupUSDT_success() public view {
        assertProtocolInvariants(securedLendingUSDCPoolManager, protocolHealthCheckerV3, new address[](0));
        assertProtocolInvariants(syrupUSDTPoolManager, protocolHealthCheckerV3, new address[](0));
    }

    function testFork_protocolHealthCheckerV3_syrupUSDC_ccipReceiverDoingWithdrawals_success() public {
        /**********************************************************************************************************************************/
        /*** Step 1: Check protocol health checker invariants at the beginning and show that CCIP receiver is owner of only request     ***/
        /**********************************************************************************************************************************/

        assertProtocolInvariants(syrupUSDCPoolManager, protocolHealthCheckerV3, manualRedeemers);

        uint256 expectedSharesAmountInTheQueue = 0.4e6;

        (uint256 nextRequestId, uint256 lastRequestId) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();

        assertEq(nextRequestId, lastRequestId);

        (address owner, uint256 sharesInTheQueue) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(nextRequestId);

        assertEq(owner,            mapleCCIPReceiverProxy);
        assertEq(sharesInTheQueue, expectedSharesAmountInTheQueue);

        assertEq(IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).totalShares(), expectedSharesAmountInTheQueue);
        assertEq(IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).manualSharesAvailable(mapleCCIPReceiverProxy), 0);

        /**********************************************************************************************************************************/
        /*** Step 2: Deposit funds into the pool and check protocol health checker invariants                                           ***/
        /**********************************************************************************************************************************/

        uint256 depositAmount = 100e6;
        uint256 redeemAmount  = 1e6;

        deposit(syrupUSDCPool, mapleCCIPReceiverProxy, depositAmount);

        assertProtocolInvariants(syrupUSDCPoolManager, protocolHealthCheckerV3, manualRedeemers);

        /**********************************************************************************************************************************/
        /*** Step 3: Request cross chain redemption and check protocol health checker invariants                                        ***/
        /**********************************************************************************************************************************/

        requestCrossChainRedeem(mapleCCIPReceiverProxy, syrupUSDCPool, redeemAmount, BASE_CHAIN_SELECTOR);

        (nextRequestId, lastRequestId) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).queue();

        // Check new request is in the queue and owned by CCIP receiver proxy with the correct shares amount.
        (owner, sharesInTheQueue) = IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).requests(lastRequestId);

        assertEq(owner,            mapleCCIPReceiverProxy);
        assertEq(sharesInTheQueue, redeemAmount);

        assertProtocolInvariants(syrupUSDCPoolManager, protocolHealthCheckerV3, manualRedeemers);

        assertEq(IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).totalShares(), expectedSharesAmountInTheQueue + redeemAmount);

        /**********************************************************************************************************************************/
        /*** Step 4: Process first request entirely and second request partially                                                        ***/
        /**********************************************************************************************************************************/

        uint256 sharesToProcess    = expectedSharesAmountInTheQueue + redeemAmount / 2;
        uint256 expectedSharesLeft = redeemAmount / 2;

        processRedemptions(syrupUSDCPool, sharesToProcess);

        assertProtocolInvariants(syrupUSDCPoolManager, protocolHealthCheckerV3, manualRedeemers);

        assertEq(IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).totalShares(), sharesToProcess + expectedSharesLeft);

        assertEq(IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).manualSharesAvailable(mapleCCIPReceiverProxy), sharesToProcess);

        /**********************************************************************************************************************************/
        /*** Step 5: Execute manual redemption on CCIP receiver proxy and check protocol health checker invariants                      ***/
        /**********************************************************************************************************************************/

        vm.prank(redemptionExecutor);

        uint128[] memory requestIds = new uint128[](1);
        requestIds[0]               = uint128(nextRequestId);

        IMapleCCIPReceiverLike(mapleCCIPReceiverProxy).executeRedeemList(requestIds);

        assertEq(IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).totalShares(), redeemAmount);

        assertEq(
            IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).manualSharesAvailable(mapleCCIPReceiverProxy),
            redeemAmount - expectedSharesLeft
        );

        assertProtocolInvariants(syrupUSDCPoolManager, protocolHealthCheckerV3, manualRedeemers);

        /**********************************************************************************************************************************/
        /*** Step 6: Process remaining shares                                                                                           ***/
        /**********************************************************************************************************************************/

        processRedemptions(syrupUSDCPool, redeemAmount / 2);

        assertProtocolInvariants(syrupUSDCPoolManager, protocolHealthCheckerV3, manualRedeemers);

        assertEq(IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).totalShares(),                                 redeemAmount);
        assertEq(IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).manualSharesAvailable(mapleCCIPReceiverProxy), redeemAmount);

        /**********************************************************************************************************************************/
        /*** Step 7: Execute manual redemption on CCIP receiver proxy and check protocol health checker invariants                      ***/
        /**********************************************************************************************************************************/

        requestIds[0] = uint128(nextRequestId + 1);

        vm.prank(redemptionExecutor);
        IMapleCCIPReceiverLike(mapleCCIPReceiverProxy).executeRedeemList(requestIds);

        assertEq(IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).totalShares(),                                 0);
        assertEq(IWithdrawalManagerQueue(syrupUSDCWithdrawalManagerQueue).manualSharesAvailable(mapleCCIPReceiverProxy), 0);

        assertProtocolInvariants(syrupUSDCPoolManager, protocolHealthCheckerV3, manualRedeemers);
    }

}
