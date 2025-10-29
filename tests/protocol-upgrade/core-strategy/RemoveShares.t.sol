// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    ICoreStrategy,
    IERC20,
    IGlobals,
    IPoolManager,
    IPool,
    IWithdrawalManagerQueue
} from "../../../contracts/interfaces/Interfaces.sol";

import { MapleCoreStrategyUpgradeBaseTest } from "./MapleCoreStrategyUpgradeBase.t.sol";

contract RemoveSharesTests is MapleCoreStrategyUpgradeBaseTest {
    
    function test_removeShares_revert_protocolIsPaused() external {
        vm.prank(governor);
        IGlobals(globals).setProtocolPause(true);

        address poolDelegate = IPoolManager(ICoreStrategy(strategy).poolManager()).poolDelegate();

        vm.prank(poolDelegate);
        vm.expectRevert("MS:PAUSED");
        ICoreStrategy(strategy).removeShares(1);
    }

    function test_removeShares_revert_notStrategyManager() external {
        vm.expectRevert("MS:NOT_MANAGER");
        ICoreStrategy(strategy).removeShares(1);
    }

    function test_removeShares_revert_zeroShares() external {
        address poolDelegate = IPoolManager(ICoreStrategy(strategy).poolManager()).poolDelegate();

        vm.prank(poolDelegate);
        vm.expectRevert("MCS:RS:ZERO_SHARES");
        ICoreStrategy(strategy).removeShares(0);
    }

    function test_removeShares_revert_wmInsufficientShares_notEnoughSharesRequested() external {
        address poolDelegate = IPoolManager(ICoreStrategy(strategy).poolManager()).poolDelegate();

        vm.prank(poolDelegate);
        vm.expectRevert("WM:RS:INSUFFICIENT_SHARES");
        ICoreStrategy(strategy).removeShares(1);
    }

    function test_removeShares_success_partialRemoval_onlyOneRequest() external {
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

        removeSharesCoreStrategy(strategy, sharesToRemove);

        assertEq(IPool(highYieldCorpUSDCPool).balanceOf(strategy), expectedSharesToReceive - expectedSharesToWithdraw + sharesToRemove);

        assertApproxEqAbs(ICoreStrategy(strategy).assetsUnderManagement(), assetsToDeploy,             1);
        assertApproxEqAbs(IPool(syrupUSDCPool).totalAssets(),              syrupUSDCTotalAssetsBefore, 1);

        ( owner, shares ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).requests(lastRequestIdAfter);

        assertEq(owner,  strategy);
        assertEq(shares, expectedSharesToWithdraw - sharesToRemove);
    }

    function test_removeShares_success_multipleRequests_firstRequestPartiallyRemoved_SecondRequestCompletelyRemoved() external {
        uint256 syrupUSDCTotalAssetsBefore = IPool(syrupUSDCPool).totalAssets();
        uint256 syrupUSDCIdleAssetsBefore  = IERC20(IPool(syrupUSDCPool).asset()).balanceOf(syrupUSDCPool);
        uint256 assetsToDeploy             = syrupUSDCIdleAssetsBefore / 4;
        uint256 assetsToWithdraw1          = assetsToDeploy / 3;
        uint256 assetsToWithdraw2          = assetsToDeploy / 4;
        uint256 expectedSharesToWithdraw1  = IPool(highYieldCorpUSDCPool).convertToExitShares(assetsToWithdraw1);
        uint256 expectedSharesToWithdraw2  = IPool(highYieldCorpUSDCPool).convertToExitShares(assetsToWithdraw2);
        uint256 sharesToRemove             = expectedSharesToWithdraw2 + expectedSharesToWithdraw1 / 4;

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

        assertEq(
            IPool(highYieldCorpUSDCPool).balanceOf(strategy),
            expectedSharesToReceive - expectedSharesToWithdraw1 - expectedSharesToWithdraw2
        );

        assertApproxEqAbs(ICoreStrategy(strategy).assetsUnderManagement(), assetsToDeploy,             1);
        assertApproxEqAbs(IPool(syrupUSDCPool).totalAssets(),              syrupUSDCTotalAssetsBefore, 1);

        ( , lastRequestIdAfter ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).queue();

        assertEq(lastRequestIdAfter, lastRequestIdBefore + 2);

        ( owner, shares ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).requests(lastRequestIdAfter);

        assertEq(owner,  strategy);
        assertEq(shares, expectedSharesToWithdraw2);

        /**********************************************************************************************************************************/
        /*** Remove Shares and assert state changes                                                                                     ***/
        /**********************************************************************************************************************************/

        removeSharesCoreStrategy(strategy, sharesToRemove);

        assertEq(
            IPool(highYieldCorpUSDCPool).balanceOf(strategy),
            expectedSharesToReceive - expectedSharesToWithdraw1 - expectedSharesToWithdraw2 + sharesToRemove
        );

        assertApproxEqAbs(ICoreStrategy(strategy).assetsUnderManagement(), assetsToDeploy,             1);
        assertApproxEqAbs(IPool(syrupUSDCPool).totalAssets(),              syrupUSDCTotalAssetsBefore, 1);

        ( owner, shares ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).requests(lastRequestIdAfter);

        assertEq(owner,  address(0));
        assertEq(shares, 0);

        ( owner, shares ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).requests(lastRequestIdAfter - 1);

        assertEq(owner,  strategy);
        assertEq(shares, expectedSharesToWithdraw1 + expectedSharesToWithdraw2 - sharesToRemove);
    }

    function test_removeShares_success_multipleRequests_allRequestsCompletelyRemoved() external {
        uint256 syrupUSDCTotalAssetsBefore = IPool(syrupUSDCPool).totalAssets();
        uint256 syrupUSDCIdleAssetsBefore  = IERC20(IPool(syrupUSDCPool).asset()).balanceOf(syrupUSDCPool);
        uint256 assetsToDeploy             = syrupUSDCIdleAssetsBefore / 4;
        uint256 assetsToWithdraw1          = assetsToDeploy / 3;
        uint256 assetsToWithdraw2          = assetsToDeploy / 4;
        uint256 expectedSharesToWithdraw1  = IPool(highYieldCorpUSDCPool).convertToExitShares(assetsToWithdraw1);
        uint256 expectedSharesToWithdraw2  = IPool(highYieldCorpUSDCPool).convertToExitShares(assetsToWithdraw2);
        uint256 sharesToRemove             = expectedSharesToWithdraw1 + expectedSharesToWithdraw2;

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

        assertEq(
            IPool(highYieldCorpUSDCPool).balanceOf(strategy),
            expectedSharesToReceive - expectedSharesToWithdraw1 - expectedSharesToWithdraw2
        );

        assertApproxEqAbs(ICoreStrategy(strategy).assetsUnderManagement(), assetsToDeploy,             1);
        assertApproxEqAbs(IPool(syrupUSDCPool).totalAssets(),              syrupUSDCTotalAssetsBefore, 1);

        ( , lastRequestIdAfter ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).queue();

        assertEq(lastRequestIdAfter, lastRequestIdBefore + 2);

        ( owner, shares ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).requests(lastRequestIdAfter);

        assertEq(owner,  strategy);
        assertEq(shares, expectedSharesToWithdraw2);

        /**********************************************************************************************************************************/
        /*** Remove Shares and assert state changes                                                                                     ***/
        /**********************************************************************************************************************************/

        removeSharesCoreStrategy(strategy, sharesToRemove);

        assertEq(
            IPool(highYieldCorpUSDCPool).balanceOf(strategy),
            expectedSharesToReceive - expectedSharesToWithdraw1 - expectedSharesToWithdraw2 + sharesToRemove
        );

        assertApproxEqAbs(ICoreStrategy(strategy).assetsUnderManagement(), assetsToDeploy,             1);
        assertApproxEqAbs(IPool(syrupUSDCPool).totalAssets(),              syrupUSDCTotalAssetsBefore, 1);

        ( owner, shares ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).requests(lastRequestIdAfter);

        assertEq(owner,  address(0));
        assertEq(shares, 0);

        ( owner, shares ) = IWithdrawalManagerQueue(highYieldCorpUSDCWithdrawalManagerQueue).requests(lastRequestIdAfter - 1);

        assertEq(owner,  address(0));
        assertEq(shares, 0);
    }

}
