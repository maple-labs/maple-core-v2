// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { FuzzBase } from "./FuzzBase.sol";

contract DepositFuzzTests is FuzzBase {

    // Avoid stack too deep in tests
    uint256 convertedAssets;
    uint256 convertedShares;
    uint256 convertedExitAssets;
    uint256 convertedExitShares;

    function testDeepFuzz_deposit_all(
        address depositor,
        address receiver,
        uint256 totalSupply,
        uint256 totalAssets,
        uint256 unrealizedLosses,
        uint256 depositorAssets,
        uint256 assetsToDeposit,
        uint256 receiverShares,
        uint256 cash
    ) external {
        if (depositor == address(0)) depositor = address(1);
        if (receiver  == address(0)) receiver  = address(1);

        vm.assume(depositor != address(pool) && depositor != address(this));
        vm.assume(receiver  != address(pool) && receiver  != address(this));

        totalSupply      = bound(totalSupply,      0, 1e30);
        totalAssets      = bound(totalAssets,      0, 1e30);
        unrealizedLosses = bound(unrealizedLosses, 0, totalAssets);
        depositorAssets  = bound(depositorAssets,  0, 1e30);
        assetsToDeposit  = bound(assetsToDeposit,  0, depositorAssets);
        receiverShares   = bound(receiverShares,   0, totalSupply);
        cash             = bound(receiverShares,   0, totalAssets);

        mintShares(receiver, receiverShares, totalSupply);
        mintAssets(depositor, depositorAssets);
        setupPool(totalAssets, unrealizedLosses, cash);

        vm.startPrank(depositor);
        fundsAsset.approve(address(pool), assetsToDeposit);

        if (totalSupply != 0 && totalAssets == 0) {
            vm.expectRevert(divisionError);
            pool.deposit(assetsToDeposit, receiver);
            return;
        }

        uint256 expectedShares = totalSupply == 0 ? assetsToDeposit : assetsToDeposit * totalSupply / totalAssets;

        if (expectedShares == 0) {
            vm.expectRevert("P:M:ZERO_SHARES");
            pool.deposit(assetsToDeposit, receiver);
            return;
        }

        assertEq(fundsAsset.allowance(depositor, address(pool)), assetsToDeposit);

        assertEq(pool.balanceOf(receiver),            receiverShares);
        assertEq(pool.totalSupply(),                  totalSupply);
        assertEq(pool.totalAssets(),                  totalAssets);
        assertEq(fundsAsset.balanceOf(depositor),     depositorAssets);
        assertEq(fundsAsset.balanceOf(address(pool)), cash);

        uint256 mintedShares = pool.deposit(assetsToDeposit, receiver);

        assertEq(fundsAsset.allowance(depositor, address(pool)), 0);

        assertEq(mintedShares,                        expectedShares);
        assertEq(pool.balanceOf(receiver),            receiverShares  + mintedShares);
        assertEq(pool.totalSupply(),                  totalSupply     + mintedShares);
        assertEq(pool.totalAssets(),                  totalAssets     + assetsToDeposit);
        assertEq(fundsAsset.balanceOf(depositor),     depositorAssets - assetsToDeposit);
        assertEq(fundsAsset.balanceOf(address(pool)), cash            + assetsToDeposit);
    }

}
