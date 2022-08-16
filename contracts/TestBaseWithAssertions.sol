// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestBase } from "./TestBase.sol";

contract TestBaseWithAssertions is TestBase {

    /***********************************/
    /*** Balance Assertion Functions ***/
    /***********************************/

    function assertAssetBalances(address[3] memory addresses, uint40[3] memory assets) internal {
        for (uint i; i < addresses.length; i++) {
            assertEq(fundsAsset.balanceOf(addresses[i]), assets[i]);
        }
    }

    function assertAssetBalances(address[3] memory addresses, uint48[3] memory assets) internal {
        for (uint i; i < addresses.length; i++) {
            assertEq(fundsAsset.balanceOf(addresses[i]), assets[i]);
        }
    }

    function assertAssetBalances(address[4] memory addresses, uint40[4] memory assets) internal {
        for (uint i; i < addresses.length; i++) {
            assertEq(fundsAsset.balanceOf(addresses[i]), assets[i]);
        }
    }

    function assertShareBalances(address[] memory addresses, uint256[] memory shares) internal {
        for (uint i; i < addresses.length; i++) {
            assertEq(pool.balanceOf(addresses[i]), shares[i]);
        }
    }

    /*********************************/
    /*** State Assertion Functions ***/
    /*********************************/

    function assertFeeManagerState(
        address[1] memory loanAddresses,
         uint32[1] memory delegateServiceFees,
         uint32[1] memory platformServiceFees
    ) internal {
        for (uint i; i < loanAddresses.length; i++) {
            assertEq(feeManager.delegateServiceFee(loanAddresses[i]), delegateServiceFees[i]);
            assertEq(feeManager.platformServiceFee(loanAddresses[i]), platformServiceFees[i]);
        }
    }

    function assertGlobalState() internal {
        // TODO
    }

    function assertLoanState() internal {
        // TODO
    }

    function assertLoanManagerState(
        uint256 principalOut,
        uint256 accountedInterest,
        uint256 issuanceRate,
        uint256 domainStart,
        uint256 domainEnd
    )
        internal
    {
        assertEq(loanManager.principalOut(),      principalOut);
        assertEq(loanManager.accountedInterest(), accountedInterest);
        assertEq(loanManager.issuanceRate(),      issuanceRate);
        assertEq(loanManager.domainStart(),       domainStart);
        assertEq(loanManager.domainEnd(),         domainEnd);
    }

    function assertTotalAssets(uint256 totalAssets) internal {
        assertEq(poolManager.totalAssets(), totalAssets);
    }

    function assertWithdrawalManagerState() internal {
        // TODO
    }

}