// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address } from "../../../modules/contract-test-utils/contracts/test.sol";

import { TestBase } from "../../utilities/TestBase.sol";

// TODO: instead of putting this into its own file, maybe consider putting all tests that manipulate basic LP token functionality
//       (transfer, deposit, redeem, etc) into the same file.
contract TransferTests is TestBase {

    address internal borrower = address(new Address());
    address internal lp       = address(new Address());

    function setUp() public override {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _createFactories();
        _createAndConfigurePool(1 weeks, 2 days);
        // NOTE: As opposed to super.setUp(), do not open the pool,
        // as tests need to validate that only valid lenders are allowed to transfer Pool tokens.

        start = block.timestamp;
    }

    function test_transfer_protocolPaused() external {
        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();

        uint256 lpShares  = depositLiquidity(lp, 1_000e6);
        address recipient = address(new Address());

        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        pool.transfer(recipient, lpShares);
    }

    function test_transfer_privatePoolInvalidLender() external {
        // Make LP a valid lender in pool manager, to allow the LP to deposit to the pool.
        vm.prank(poolDelegate);
        poolManager.setAllowedLender(lp, true);

        // LP gets pool tokens.
        uint256 lpShares = depositLiquidity(lp, 1_000e6);

        // LP tries to transfer pool tokens, should fail, as recipient is not a valid lender.
        address recipient = address(new Address());
        vm.expectRevert("P:T:RECIPIENT_NOT_ALLOWED");
        pool.transfer(recipient, lpShares);

        // Recipient is made a valid lender, lp should now be allowed to transfer to recipient.
        vm.prank(poolDelegate);
        poolManager.setAllowedLender(recipient, true);

        vm.prank(lp);
        pool.transfer(recipient, lpShares);
    }

    function test_transfer_privatePoolInvalidLender_openPoolToPublic() external {
        // Make LP a valid lender in pool manager, to allow the LP to deposit to the pool.
        vm.prank(poolDelegate);
        poolManager.setAllowedLender(lp, true);

        // LP gets pool tokens.
        uint256 lpShares = depositLiquidity(lp, 1_000e6);

        // LP tries to transfer pool tokens, should fail, as recipient is not a valid lender.
        address recipient = address(new Address());
        vm.expectRevert("P:T:RECIPIENT_NOT_ALLOWED");
        pool.transfer(recipient, lpShares);

        // Pool is opened to public, shares may be transferred to anyone.
        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();

        vm.prank(lp);
        pool.transfer(recipient, lpShares);
    }

    function test_transfer_publicPool() external {
        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();

        uint256 lpShares  = depositLiquidity(lp, 1_000e6);
        address recipient = address(new Address());

        assertEq(pool.balanceOf(lp),        lpShares);
        assertEq(pool.balanceOf(recipient), 0);

        vm.prank(lp);
        pool.transfer(recipient, lpShares);

        assertEq(pool.balanceOf(lp),        0);
        assertEq(pool.balanceOf(recipient), lpShares);
    }

    function test_transferFrom_protocolPaused() external {
        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();

        uint256 lpShares  = depositLiquidity(lp, 1_000e6);
        address recipient = address(new Address());

        vm.prank(lp);
        pool.approve(recipient, lpShares);

        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(recipient);
        vm.expectRevert("PM:CC:PROTOCOL_PAUSED");
        pool.transferFrom(lp, recipient, lpShares);
    }

    function test_transferFrom_privatePoolInvalidLender() external {
        // Make LP a valid lender in pool manager, to allow the LP to deposit to the pool.
        vm.prank(poolDelegate);
        poolManager.setAllowedLender(lp, true);

        // LP gets pool tokens.
        uint256 lpShares   = depositLiquidity(lp, 1_000e6);
        address recipient  = address(new Address());
        address transferer = address(new Address());

        vm.prank(lp);
        pool.approve(transferer, lpShares);

        // Transferer tries to transfer pool tokens for lp, should fail, as recipient is not a valid lender.
        vm.prank(transferer);
        vm.expectRevert("P:TF:RECIPIENT_NOT_ALLOWED");
        pool.transferFrom(lp, recipient, lpShares);

        // Recipient is made a valid lender, lp should now be allowed to transfer to recipient.
        vm.prank(poolDelegate);
        poolManager.setAllowedLender(recipient, true);

        vm.prank(transferer);
        pool.transferFrom(lp, recipient, lpShares);
    }

    function test_transferFrom_privatePoolInvalidLender_openPoolToPublic() external {
        // Make LP a valid lender in pool manager, to allow the LP to deposit to the pool.
        vm.prank(poolDelegate);
        poolManager.setAllowedLender(lp, true);

        // LP gets pool tokens.
        uint256 lpShares   = depositLiquidity(lp, 1_000e6);
        address recipient  = address(new Address());
        address transferer = address(new Address());

        vm.prank(lp);
        pool.approve(transferer, lpShares);

        // Transferer tries to transfer pool tokens for lp, should fail, as recipient is not a valid lender.
        vm.prank(transferer);
        vm.expectRevert("P:TF:RECIPIENT_NOT_ALLOWED");
        pool.transferFrom(lp, recipient, lpShares);

        // Pool is opened to public, shares may be transferred to anyone.
        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();

        vm.prank(transferer);
        pool.transferFrom(lp, recipient, lpShares);
    }

    function test_transferFrom_publicPool_noApproval() external {
        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();

        uint256 lpShares  = depositLiquidity(lp, 1_000e6);
        address recipient = address(new Address());

        vm.prank(recipient);
        vm.expectRevert(ARITHMETIC_ERROR);  // ERC20: subtraction underflow in _decreaseAllowance
        pool.transferFrom(lp, recipient, lpShares);
    }

    function test_transferFrom_publicPool_insufficientApproval() external {
        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();

        uint256 lpShares  = depositLiquidity(lp, 1_000e6);
        address recipient = address(new Address());

        vm.prank(lp);
        pool.approve(recipient, lpShares - 1);

        vm.prank(recipient);
        vm.expectRevert(ARITHMETIC_ERROR);  // ERC20: subtraction underflow in _decreaseAllowance
        pool.transferFrom(lp, recipient, lpShares);
    }

    function test_transferFrom_publicPool() external {
        vm.prank(poolDelegate);
        poolManager.setOpenToPublic();

        uint256 lpShares  = depositLiquidity(lp, 1_000e6);
        address recipient = address(new Address());

        vm.prank(lp);
        pool.approve(recipient, lpShares);

        assertEq(pool.balanceOf(lp),        lpShares);
        assertEq(pool.balanceOf(recipient), 0);

        vm.prank(recipient);
        pool.transferFrom(lp, recipient, lpShares);

        assertEq(pool.balanceOf(lp),        0);
        assertEq(pool.balanceOf(recipient), lpShares);
    }

    // TODO: what if transferer and/or is made an invalid lender? Should this be possible? If yes, should they be able to transfer?
}
