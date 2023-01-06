// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { FuzzBase } from "../../contracts/utilities/FuzzBase.sol";

contract DepositFuzzTests is FuzzBase {

    // Avoid stack too deep in tests
    uint256 internal convertedAssets;
    uint256 internal convertedShares;
    uint256 internal convertedExitAssets;
    uint256 internal convertedExitShares;

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

        vm.assume(depositor != address(pool));
        vm.assume(receiver  != address(pool));

        totalSupply      = constrictToRange(totalSupply,      0, 1e30);
        totalAssets      = constrictToRange(totalAssets,      0, 1e30);
        unrealizedLosses = constrictToRange(unrealizedLosses, 0, totalAssets);
        depositorAssets  = constrictToRange(depositorAssets,  0, 1e30);
        assetsToDeposit  = constrictToRange(assetsToDeposit,  0, depositorAssets);
        receiverShares   = constrictToRange(receiverShares,   0, totalSupply);
        cash             = constrictToRange(receiverShares,   0, totalAssets);

        mintShares(receiver, receiverShares, totalSupply);
        mintAssets(depositor, depositorAssets);
        setupPool(totalAssets, unrealizedLosses, cash);

        vm.startPrank(depositor);
        fundsAsset.approve(address(pool), assetsToDeposit);

        if (totalSupply != 0 && totalAssets == 0) {
            vm.expectRevert(ZERO_DIVISION);
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
