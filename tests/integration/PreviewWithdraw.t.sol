// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { TestBase } from "../TestBase.sol";

contract PreviewWithdrawTests is TestBase {

    function setUp() public override virtual {
        start = block.timestamp;

        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
        _createPoolWithQueue();
        _configurePool();

        openPool(address(poolManager));
    }

    function testFuzz_previewWithdraw(
        address lender,
        bool    isManual,
        uint256 amountToRequest,
        uint256 amountToProcess,
        uint256 amountToWithdraw
    )
        external
    {
        vm.assume(lender != address(0));

        amountToRequest = bound(amountToRequest,  0, 1e30);
        amountToProcess = bound(amountToProcess,  0, amountToRequest);

        vm.prank(poolDelegate);
        queueWM.setManualWithdrawal(lender, isManual);

        if (amountToRequest > 0) {
            deposit(lender, amountToRequest);

            vm.prank(lender);
            pool.requestRedeem(amountToRequest, lender);
        }

        if (amountToProcess > 0) {
            vm.prank(poolDelegate);
            queueWM.processRedemptions(amountToProcess);
        }

        vm.prank(lender);
        uint256 sharesToBurn = pool.previewWithdraw(amountToWithdraw);

        assertEq(sharesToBurn, 0);
    }

}
