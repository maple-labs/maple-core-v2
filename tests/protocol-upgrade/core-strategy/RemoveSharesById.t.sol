
// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    ICoreStrategy,
    IERC20,
    IGlobals,
    IPool,
    IPoolManager,
    IWithdrawalManagerQueue
} from "../../../contracts/interfaces/Interfaces.sol";

import { MapleCoreStrategyUpgradeBaseTest } from "./MapleCoreStrategyUpgradeBase.t.sol";

contract RemoveSharesByIdTests is MapleCoreStrategyUpgradeBaseTest {

    function test_removeSharesById_revert_protocolIsPaused() external {
        vm.prank(governor);
        IGlobals(globals).setProtocolPause(true);

        address poolDelegate = IPoolManager(ICoreStrategy(strategy).poolManager()).poolDelegate();

        vm.prank(poolDelegate);
        vm.expectRevert("MS:PAUSED");
        ICoreStrategy(strategy).removeSharesById(1, 1);
    }

    function test_removeSharesById_revert_notStrategyManager() external {
        vm.expectRevert("MS:NOT_MANAGER");
        ICoreStrategy(strategy).removeSharesById(1, 1);
    }

    function test_removeSharesById_revert_invalidRequest() external {
        address poolDelegate = IPoolManager(ICoreStrategy(strategy).poolManager()).poolDelegate();

        vm.prank(poolDelegate);
        vm.expectRevert("WM:RSBI:INVALID_REQUEST");
        ICoreStrategy(strategy).removeSharesById(0, 0);
    }

    function test_removeSharesById_revert_notOwner() external {
        address user          = makeAddr("user");
        uint256 depositAmount = 1e6;
        uint256 redeemAmount  = 0.1e6;

        deposit(highYieldCorpUSDCPool, user, depositAmount);
        requestRedeem(highYieldCorpUSDCPool, user, redeemAmount);

        ( , uint256 lastRequestId ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).queue();

        address poolDelegate = IPoolManager(ICoreStrategy(strategy).poolManager()).poolDelegate();

        vm.prank(poolDelegate);
        vm.expectRevert("WM:RSBI:NOT_OWNER");
        ICoreStrategy(strategy).removeSharesById(lastRequestId, 0);
    }

    function test_removeSharesById_revert_noChange() external {
        uint256 idleAssets               = IERC20(IPool(syrupUSDCPool).asset()).balanceOf(syrupUSDCPool);
        uint256 assetsToDeploy           = idleAssets / 4;
        uint256 assetsToWithdraw         = assetsToDeploy / 3;

        fundStrategy(strategy, assetsToDeploy);
        requestWithdrawFromStrategy(strategy, assetsToWithdraw);

        ( , uint256 lastRequestId ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).queue();

        address poolDelegate = IPoolManager(ICoreStrategy(strategy).poolManager()).poolDelegate();

        vm.prank(poolDelegate);
        vm.expectRevert("WM:RSBI:NO_CHANGE");
        ICoreStrategy(strategy).removeSharesById(lastRequestId, 0);
    }

    function test_removeSharesById_revert_wmInsufficientShares() external {
        uint256 idleAssets               = IERC20(IPool(syrupUSDCPool).asset()).balanceOf(syrupUSDCPool);
        uint256 assetsToDeploy           = idleAssets / 4;
        uint256 assetsToWithdraw         = assetsToDeploy / 3;
        uint256 expectedSharesToWithdraw = IPool(highYieldCorpUSDCPool).convertToExitShares(assetsToWithdraw);

        fundStrategy(strategy, assetsToDeploy);
        requestWithdrawFromStrategy(strategy, assetsToWithdraw);

        ( , uint256 lastRequestId ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).queue();

        address poolDelegate = IPoolManager(ICoreStrategy(strategy).poolManager()).poolDelegate();

        vm.prank(poolDelegate);
        vm.expectRevert("WM:RSBI:INSUFFICIENT_SHARES");
        ICoreStrategy(strategy).removeSharesById(lastRequestId, expectedSharesToWithdraw + 1);
    }

    function test_removeSharesById_success_singleRequest_partialRemoval_followedByCompleteRemoval() external {
        uint256 syrupUSDCTotalAssetsBefore = IPool(syrupUSDCPool).totalAssets();
        uint256 syrupUSDCIdleAssetsBefore  = IERC20(IPool(syrupUSDCPool).asset()).balanceOf(syrupUSDCPool);
        uint256 assetsToDeploy             = syrupUSDCIdleAssetsBefore / 4;
        uint256 assetsToWithdraw           = assetsToDeploy / 3;
        uint256 expectedSharesToWithdraw   = IPool(highYieldCorpUSDCPool).convertToExitShares(assetsToWithdraw);
        uint256 sharesToRemove             = expectedSharesToWithdraw / 5;

        ( , uint256 lastRequestIdBefore ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).queue();

        /**********************************************************************************************************************************/
        /*** Fund Strategy and assert state changes                                                                                     ***/
        /**********************************************************************************************************************************/

        assertEq(ICoreStrategy(strategy).assetsUnderManagement(), 0);
        
        fundStrategy(strategy, assetsToDeploy);

        uint256 expectedSharesToReceive = IPool(highYieldCorpUSDCPool).previewDeposit(assetsToDeploy);

        assertEq(IPool(highYieldCorpUSDCPool).balanceOf(strategy), expectedSharesToReceive);

        assertApproxEqAbs(ICoreStrategy(strategy).assetsUnderManagement(), assetsToDeploy,             1);
        assertApproxEqAbs(IPool(syrupUSDCPool).totalAssets(),              syrupUSDCTotalAssetsBefore, 1);

        assertApproxEqAbs(
            IERC20(IPool(syrupUSDCPool).asset()).balanceOf(syrupUSDCPool),
            syrupUSDCIdleAssetsBefore - assetsToDeploy,
            1
        );

        /**********************************************************************************************************************************/
        /*** Request Withdraw and assert state changes                                                                                  ***/
        /**********************************************************************************************************************************/

        requestWithdrawFromStrategy(strategy, assetsToWithdraw);

        assertEq(IPool(highYieldCorpUSDCPool).balanceOf(strategy), expectedSharesToReceive - expectedSharesToWithdraw);

        assertApproxEqAbs(ICoreStrategy(strategy).assetsUnderManagement(), assetsToDeploy,             1);
        assertApproxEqAbs(IPool(syrupUSDCPool).totalAssets(),              syrupUSDCTotalAssetsBefore, 1);

        ( , uint256 lastRequestIdAfter ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).queue();

        assertEq(lastRequestIdAfter, lastRequestIdBefore + 1);

        ( address owner, uint256 shares ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).requests(lastRequestIdAfter);

        assertEq(owner,  strategy);
        assertEq(shares, expectedSharesToWithdraw);

        /**********************************************************************************************************************************/
        /*** Remove Shares and assert state changes                                                                                     ***/
        /**********************************************************************************************************************************/

        removeSharesByIdCoreStrategy(strategy, lastRequestIdAfter, sharesToRemove);

        assertEq(IPool(highYieldCorpUSDCPool).balanceOf(strategy), expectedSharesToReceive - expectedSharesToWithdraw + sharesToRemove);

        assertApproxEqAbs(ICoreStrategy(strategy).assetsUnderManagement(), assetsToDeploy,             1);
        assertApproxEqAbs(IPool(syrupUSDCPool).totalAssets(),              syrupUSDCTotalAssetsBefore, 1);

        ( owner, shares ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).requests(lastRequestIdAfter);

        assertEq(owner,  strategy);
        assertEq(shares, expectedSharesToWithdraw - sharesToRemove);

        /**********************************************************************************************************************************/
        /*** Remove Shares and assert state changes                                                                                     ***/
        /**********************************************************************************************************************************/

        sharesToRemove = expectedSharesToWithdraw - sharesToRemove;
        removeSharesByIdCoreStrategy(strategy, lastRequestIdAfter, sharesToRemove);

        assertEq(IPool(highYieldCorpUSDCPool).balanceOf(strategy), expectedSharesToReceive);

        assertApproxEqAbs(ICoreStrategy(strategy).assetsUnderManagement(), assetsToDeploy,             1);
        assertApproxEqAbs(IPool(syrupUSDCPool).totalAssets(),              syrupUSDCTotalAssetsBefore, 1);

        ( owner, shares ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).requests(lastRequestIdAfter);

        assertEq(owner,  address(0));
        assertEq(shares, 0);
    }

    function test_removeSharesById_success_multipleRequests_completelyRemoveMidRequest() public {
        uint256 syrupUSDCTotalAssetsBefore = IPool(syrupUSDCPool).totalAssets();
        uint256 syrupUSDCIdleAssetsBefore  = IERC20(IPool(syrupUSDCPool).asset()).balanceOf(syrupUSDCPool);
        uint256 assetsToDeploy             = syrupUSDCIdleAssetsBefore / 4;
        uint256 assetsToWithdraw1          = assetsToDeploy / 8;
        uint256 assetsToWithdraw2          = assetsToDeploy / 7;
        uint256 assetsToWithdraw3          = assetsToDeploy / 5;
        uint256 expectedSharesToWithdraw1  = IPool(highYieldCorpUSDCPool).convertToExitShares(assetsToWithdraw1);
        uint256 expectedSharesToWithdraw2  = IPool(highYieldCorpUSDCPool).convertToExitShares(assetsToWithdraw2);
        uint256 expectedSharesToWithdraw3  = IPool(highYieldCorpUSDCPool).convertToExitShares(assetsToWithdraw3);

        ( , uint256 lastRequestIdBefore ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).queue();

        /**********************************************************************************************************************************/
        /*** Fund Strategy and assert state changes                                                                                     ***/
        /**********************************************************************************************************************************/

        assertEq(ICoreStrategy(strategy).assetsUnderManagement(), 0);

        fundStrategy(strategy, assetsToDeploy);

        uint256 expectedSharesToReceive = IPool(highYieldCorpUSDCPool).previewDeposit(assetsToDeploy);

        assertEq(IPool(highYieldCorpUSDCPool).balanceOf(strategy), expectedSharesToReceive);

        assertApproxEqAbs(ICoreStrategy(strategy).assetsUnderManagement(), assetsToDeploy,             1);
        assertApproxEqAbs(IPool(syrupUSDCPool).totalAssets(),              syrupUSDCTotalAssetsBefore, 1);

        assertApproxEqAbs(
            IERC20(IPool(syrupUSDCPool).asset()).balanceOf(syrupUSDCPool),
            syrupUSDCIdleAssetsBefore - assetsToDeploy,
            1
        );

        /**********************************************************************************************************************************/
        /*** Request Withdraw and assert state changes                                                                                  ***/
        /**********************************************************************************************************************************/

        requestWithdrawFromStrategy(strategy, assetsToWithdraw1);

        assertEq(IPool(highYieldCorpUSDCPool).balanceOf(strategy), expectedSharesToReceive - expectedSharesToWithdraw1);

        assertApproxEqAbs(ICoreStrategy(strategy).assetsUnderManagement(), assetsToDeploy,             1);
        assertApproxEqAbs(IPool(syrupUSDCPool).totalAssets(),              syrupUSDCTotalAssetsBefore, 1);

        ( , uint256 lastRequestIdAfter ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).queue();

        assertEq(lastRequestIdAfter, lastRequestIdBefore + 1);

        ( address owner, uint256 shares ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).requests(lastRequestIdAfter);

        assertEq(owner,  strategy);
        assertEq(shares, expectedSharesToWithdraw1);

        /**********************************************************************************************************************************/
        /*** Request Withdraw and assert state changes                                                                                  ***/
        /**********************************************************************************************************************************/

        requestWithdrawFromStrategy(strategy, assetsToWithdraw2);

        assertEq(IPool(highYieldCorpUSDCPool).balanceOf(strategy), expectedSharesToReceive - expectedSharesToWithdraw1 - expectedSharesToWithdraw2);

        assertApproxEqAbs(ICoreStrategy(strategy).assetsUnderManagement(), assetsToDeploy,             1);
        assertApproxEqAbs(IPool(syrupUSDCPool).totalAssets(),              syrupUSDCTotalAssetsBefore, 1);

        ( , lastRequestIdAfter ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).queue();

        assertEq(lastRequestIdAfter, lastRequestIdBefore + 2);

        ( owner, shares ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).requests(lastRequestIdAfter);

        assertEq(owner,  strategy);
        assertEq(shares, expectedSharesToWithdraw2);

        /**********************************************************************************************************************************/
        /*** Request Withdraw and assert state changes                                                                                  ***/
        /**********************************************************************************************************************************/

        requestWithdrawFromStrategy(strategy, assetsToWithdraw3);

        assertEq(
            IPool(highYieldCorpUSDCPool).balanceOf(strategy),
            expectedSharesToReceive - expectedSharesToWithdraw1 - expectedSharesToWithdraw2 - expectedSharesToWithdraw3
        );

        assertApproxEqAbs(ICoreStrategy(strategy).assetsUnderManagement(), assetsToDeploy,             1);
        assertApproxEqAbs(IPool(syrupUSDCPool).totalAssets(),              syrupUSDCTotalAssetsBefore, 1);

        ( , lastRequestIdAfter ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).queue();

        assertEq(lastRequestIdAfter, lastRequestIdBefore + 3);

        ( owner, shares ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).requests(lastRequestIdAfter);

        assertEq(owner,  strategy);
        assertEq(shares, expectedSharesToWithdraw3);

        /**********************************************************************************************************************************/
        /*** Remove Shares and assert state changes                                                                                     ***/
        /**********************************************************************************************************************************/

        removeSharesByIdCoreStrategy(strategy, lastRequestIdAfter - 1, expectedSharesToWithdraw2);

        assertEq(
            IPool(highYieldCorpUSDCPool).balanceOf(strategy),
            expectedSharesToReceive - expectedSharesToWithdraw1 - expectedSharesToWithdraw3
        );

        assertApproxEqAbs(ICoreStrategy(strategy).assetsUnderManagement(), assetsToDeploy,             1);
        assertApproxEqAbs(IPool(syrupUSDCPool).totalAssets(),              syrupUSDCTotalAssetsBefore, 1);

        ( owner, shares ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).requests(lastRequestIdAfter - 1);

        assertEq(owner,  address(0));
        assertEq(shares, 0);
    }

}
