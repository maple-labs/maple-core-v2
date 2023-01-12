// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { LoanManagerHarness } from "./LoanManagerHarness.sol";
import { TestBase }           from "../TestBase.sol";

contract FuzzBase is TestBase {

    LoanManagerHarness internal loanManagerHarness;

    function setUp() public override {
        super.setUp();

        loanManagerHarness = new LoanManagerHarness();
        vm.etch(address(loanManager), address(loanManagerHarness).code);

        loanManagerHarness = LoanManagerHarness(address(loanManager));
    }

    function mintAssets(address account, uint256 assets) internal {
        fundsAsset.mint(address(account), assets);
    }

    function mintShares(address account, uint256 shares, uint256 totalSupply) internal {
        if (totalSupply == 0) {
            return;
        }

        fundsAsset.mint(address(this), totalSupply);
        fundsAsset.approve(address(pool), totalSupply);

        uint256 otherShares = totalSupply - shares;

        if (shares != 0) {
            pool.mint(shares, address(account));
        }

        if (otherShares != 0) {
            pool.mint(otherShares, address(this));
        }

        fundsAsset.burn(address(pool), totalSupply);  // Burn so that assets can be minted into the pool in other functions.
    }

    function setupPool(uint256 totalAssets, uint256 unrealizedLosses, uint256 availableAssets) internal {
        loanManagerHarness.__setPrincipalOut(totalAssets - availableAssets);
        loanManagerHarness.__setUnrealizedLosses(unrealizedLosses);

        fundsAsset.mint(address(pool), availableAssets);
    }

}
