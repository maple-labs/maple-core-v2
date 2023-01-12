// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { FuzzBase } from "./FuzzBase.sol";

import { console } from "../../modules/contract-test-utils/contracts/test.sol";

contract MintFuzzTests is FuzzBase {

    // Avoid stack too deep in tests
    uint256 internal convertedAssets;
    uint256 internal convertedShares;
    uint256 internal convertedExitAssets;
    uint256 internal convertedExitShares;

    function testDeepFuzz_mint_all(
        address depositor,
        address receiver,
        uint256 totalSupply,
        uint256 totalAssets,
        uint256 unrealizedLosses,
        uint256 depositorAssets,
        uint256 sharesToMint,
        uint256 receiverShares,
        uint256 cash
    ) external {

        if (depositor == address(0)) depositor = address(1);
        if (receiver  == address(0)) receiver  = address(1);

        vm.assume(depositor != address(pool) && depositor != address(this));
        vm.assume(receiver  != address(pool) && receiver  != address(this));

        totalSupply      = constrictToRange(totalSupply,      0, 1e30);
        totalAssets      = constrictToRange(totalAssets,      0, 1e30);
        unrealizedLosses = constrictToRange(unrealizedLosses, 0, totalAssets);
        depositorAssets  = constrictToRange(depositorAssets,  0, 1e30);
        receiverShares   = constrictToRange(receiverShares,   0, totalSupply);
        cash             = constrictToRange(cash,             0, totalAssets);

        mintShares(receiver, receiverShares, totalSupply);
        mintAssets(depositor, depositorAssets);
        setupPool(totalAssets, unrealizedLosses, cash);

        uint256 maxShares = totalAssets == 0 ? depositorAssets : depositorAssets * totalSupply / totalAssets;

        sharesToMint = constrictToRange(sharesToMint, 0, maxShares);

        uint256 assetsToDeposit = totalSupply == 0 ? sharesToMint : _divRoundUp(sharesToMint * totalAssets, totalSupply);

        vm.startPrank(depositor);
        fundsAsset.approve(address(pool), assetsToDeposit);

        if (sharesToMint == 0) {
            vm.expectRevert("P:M:ZERO_SHARES");
            pool.mint(sharesToMint, receiver);
            return;
        }

        if (pool.previewMint(sharesToMint) == 0) {
            vm.expectRevert("P:M:ZERO_ASSETS");
            pool.mint(sharesToMint, receiver);
            return;
        }

        if (totalSupply != 0 && totalAssets == 0) {
            vm.expectRevert(ZERO_DIVISION);
            pool.mint(sharesToMint, receiver);  // Use assets since conversion fails
            return;
        }

        assertEq(fundsAsset.allowance(depositor, address(pool)), assetsToDeposit);

        assertEq(pool.balanceOf(receiver),            receiverShares);
        assertEq(pool.totalSupply(),                  totalSupply);
        assertEq(pool.totalAssets(),                  totalAssets);
        assertEq(fundsAsset.balanceOf(depositor),     depositorAssets);
        assertEq(fundsAsset.balanceOf(address(pool)), cash);

        uint256 depositedAssets = pool.mint(sharesToMint, receiver);

        assertEq(fundsAsset.allowance(depositor, address(pool)), 0);

        assertEq(depositedAssets,                     assetsToDeposit);
        assertEq(pool.balanceOf(receiver),            receiverShares  + sharesToMint);
        assertEq(pool.totalSupply(),                  totalSupply     + sharesToMint);
        assertEq(pool.totalAssets(),                  totalAssets     + assetsToDeposit);
        assertEq(fundsAsset.balanceOf(depositor),     depositorAssets - assetsToDeposit);
        assertEq(fundsAsset.balanceOf(address(pool)), cash            + assetsToDeposit);
    }

    function _divRoundUp(uint256 numerator_, uint256 divisor_) internal pure returns (uint256 result_) {
        result_ = (numerator_ + divisor_ - 1) / divisor_;
    }

}
