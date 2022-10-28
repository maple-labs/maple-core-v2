// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { Address, console, TestUtils } from "../../../modules/contract-test-utils/contracts/test.sol";

import { MockERC20 }          from "../../../modules/erc20/contracts/test/mocks/MockERC20.sol";
import { IPool }              from "../../../modules/pool-v2/contracts/interfaces/IPool.sol";
import { IPoolManager }       from "../../../modules/pool-v2/contracts/interfaces/IPoolManager.sol";
import { ILoanManager }       from "../../../modules/pool-v2/contracts/interfaces/ILoanManager.sol";
import { WithdrawalManager } from "../../../modules/withdrawal-manager/contracts/WithdrawalManager.sol";

import { ITest } from "../interfaces/ITest.sol";

contract LpHander is TestUtils {

    /******************************************************************************************************************************/
    /*** State Variables                                                                                                        ***/
    /******************************************************************************************************************************/

    address currentLp;

    address[] public holders;
    address[] public lps;

    uint256 public numCalls;
    uint256 public numHolders;
    uint256 public numLps;

    mapping(bytes32 => uint256) public numberOfCalls;

    MockERC20         fundsAsset;
    IPool             pool;
    ITest             testContract;
    WithdrawalManager withdrawalManager;

    /******************************************************************************************************************************/
    /*** Constructor                                                                                                            ***/
    /******************************************************************************************************************************/

    constructor (address pool_, address testContract_, uint256 numLps_) {
        pool              = IPool(pool_);
        testContract      = ITest(testContract_);
        withdrawalManager = WithdrawalManager(IPoolManager(pool.manager()).withdrawalManager());

        fundsAsset = MockERC20(pool.asset());

        numLps     = numLps_;
        numHolders = numLps + 1;  // Include withdrawal manager

        for (uint256 i = 0; i < numLps_; i++) {
            address lp = address(new Address());
            lps.push(lp);
            holders.push(lp);
        }

        holders.push(address(withdrawalManager));
    }

    /******************************************************************************************************************************/
    /*** Modifiers                                                                                                              ***/
    /******************************************************************************************************************************/

    modifier useTimestamps {
        vm.warp(testContract.currentTimestamp());
        _;
        testContract.setCurrentTimestamp(block.timestamp);
    }

    modifier useRandomLp(uint256 lpIndex_) {
        currentLp = lps[constrictToRange(lpIndex_, 0, lps.length - 1)];  // TODO: Investigate why this is happening
        vm.startPrank(currentLp);
        _;
        vm.stopPrank();
    }

    /******************************************************************************************************************************/
    /*** Pool Functions                                                                                                         ***/
    /******************************************************************************************************************************/

    function deposit(uint256 assets_, uint256 lpIndex_) public virtual useTimestamps useRandomLp(lpIndex_) returns (uint256 shares_) {
        numCalls++;
        numberOfCalls["deposit"]++;

        assets_ = constrictToRange(assets_, 100, 1e29);

        fundsAsset.mint(currentLp, assets_);
        fundsAsset.approve(address(pool), assets_);

        pool.deposit(assets_, currentLp);  // TODO: Fuzz receiver
    }

    // function depositWithPermit(uint256 assets_, address receiver_, uint256 deadline_, uint256 ownerSk_, uint256 lpIndex_) public virtual useTimestamps useRandomLp(lpIndex_) returns (uint256 shares_) {
        // numCalls++;
    //     assets_   = constrictToRange(assets_,   1,               1e29);
    //     deadline_ = constrictToRange(deadline_, block.timestamp, block.timestamp + 1_000_000 days);

    //     address owner_ = vm.addr(ownerSk_);

    //     ( uint8 v_, bytes32 r_, bytes32 s_ ) = _getValidPermitSignature(address(fundsAsset), owner_, currentLp, assets_, fundsAsset.nonces(owner_), deadline_, ownerSk_);

    //     fundsAsset.mint(owner_, assets_);

    //     return pool.depositWithPermit(assets_, receiver_, deadline_, v_, r_, s_);
    // }

    function mint(uint256 shares_, uint256 lpIndex_) public virtual useTimestamps useRandomLp(lpIndex_) returns (uint256 assets_) {
        numCalls++;
        numberOfCalls["mint"]++;

        shares_ = constrictToRange(shares_, 1, 1e29);

        uint256 assets_ = pool.totalSupply() == 0 ? shares_ : shares_ * pool.totalAssets() / pool.totalSupply() + 100;

        fundsAsset.mint(currentLp, assets_);
        fundsAsset.approve(address(pool), assets_);

        return pool.mint(shares_, currentLp);  // TODO: Fuzz receiver
    }

    // function mintWithPermit(uint256 shares_, address receiver_, uint256 maxAssets_, uint256 deadline_, uint8 v_, bytes32 r_, bytes32 s_, uint256 lpIndex_) public virtual useTimestamps useRandomLp(lpIndex_) returns (uint256 assets_) {
        // numCalls++;
    //     return pool.mintWithPermit(shares_, receiver_, maxAssets_, deadline_, v_, r_, s_);
    // }

    function redeem(uint256 warpSeed_, uint256 lpIndex_) public virtual useTimestamps useRandomLp(lpIndex_) returns (uint256 assets_) {
        numCalls++;
        numberOfCalls["redeem"]++;

        uint256 exitCycleId_ = withdrawalManager.exitCycleId(currentLp);

        if (exitCycleId_ == 0) return 0;

        ( uint256 windowStart_, uint256 windowEnd_ ) = withdrawalManager.getWindowAtId(withdrawalManager.exitCycleId(currentLp));

        if (block.timestamp > windowStart_) return 0;  // Only warp forward

        vm.warp(constrictToRange(warpSeed_, windowStart_, windowEnd_));

        return pool.redeem(withdrawalManager.lockedShares(currentLp), currentLp, currentLp);  // TODO: Fuzz owner and receiver
    }

    // TODO: Add WM interface
    function removeShares(uint256 warpSeed_, uint256 lpIndex_) public virtual useTimestamps useRandomLp(lpIndex_) returns (uint256 assets_) {
        numCalls++;
        numberOfCalls["removeShares"]++;

        uint256 exitCycleId_ = withdrawalManager.exitCycleId(currentLp);

        if (exitCycleId_ == 0) return 0;

        ( uint256 windowStart_, ) = withdrawalManager.getWindowAtId(withdrawalManager.exitCycleId(currentLp));

        if (block.timestamp > windowStart_) return 0;

        vm.warp(constrictToRange(warpSeed_, windowStart_, windowStart_ + 1 days));

        return pool.removeShares(withdrawalManager.lockedShares(currentLp), currentLp);  // TODO: Fuzz owner and receiver
    }

    // function requestWithdraw(uint256 assets_, uint256 lpIndex_) public virtual useTimestamps useRandomLp(lpIndex_) returns (uint256 escrowShares_) {
        // numCalls++;
    //     if (pool.balanceOfAssets(currentLp) == 0) return 0;

    //     assets_ = constrictToRange(assets_, 1, pool.balanceOfAssets(currentLp));

    //     return pool.requestWithdraw(assets_, currentLp); // TODO: Add fuzzing for users
    // }

    function requestRedeem(uint256 shares_, uint256 lpIndex_) public virtual useTimestamps useRandomLp(lpIndex_) returns (uint256 escrowShares_) {
        numCalls++;
        numberOfCalls["requestRedeem"]++;

        if (pool.balanceOf(currentLp) == 0 || withdrawalManager.lockedShares(currentLp) != 0) return 0;

        shares_ = constrictToRange(shares_, 1, pool.balanceOf(currentLp));

        return pool.requestRedeem(shares_, currentLp); // TODO: Add fuzzing for users
    }

    // function withdraw(uint256 assets_, address receiver_, address owner_, uint256 lpIndex_) public virtual useTimestamps useRandomLp(lpIndex_) returns (uint256 shares_) {
        // numCalls++;
    //     if (pool.balanceOfAssets(currentLp) == 0) return 0;

    //     assets_ = constrictToRange(assets_, 1, pool.balanceOfAssets(currentLp));

    //     return pool.withdraw(assets_, receiver_, owner_);
    // }

    /******************************************************************************************************************************/
    /*** ERC-20 Functions                                                                                                       ***/
    /******************************************************************************************************************************/

    // function approve(address spender_, uint256 amount_, uint256 lpIndex_) public virtual useTimestamps useRandomLp(lpIndex_) returns (bool success_) {
    //     numCalls++;
    //     numberOfCalls["approve"]++;

    //     return pool.approve(spender_, amount_);
    // }

    // function decreaseAllowance(address spender_, uint256 subtractedAmount_, uint256 lpIndex_) public virtual useTimestamps useRandomLp(lpIndex_) returns (bool success_) {
    //     numCalls++;
    //     numberOfCalls["decreaseAllowance"]++;
    //     subtractedAmount_ = constrictToRange(subtractedAmount_, 0, pool.allowance(currentLp, spender_));

    //     return pool.decreaseAllowance(spender_, subtractedAmount_);
    // }

    // function increaseAllowance(address spender_, uint256 addedAmount_, uint256 lpIndex_) public virtual useTimestamps useRandomLp(lpIndex_) returns (bool success_) {
    //     numCalls++;
    //     numberOfCalls["increaseAllowance"]++;

    //     return pool.increaseAllowance(spender_, addedAmount_);
    // }

    // function permit(address owner_, address spender_, uint amount_, uint deadline_, uint8 v_, bytes32 r_, bytes32 s_, uint256 lpIndex_) public virtual useTimestamps useRandomLp(lpIndex_) {
    //     pool.permit(owner_, spender_, amount_, deadline_, v_, r_, s_);
    // }

    function transfer(uint256 amount_, uint256 lpIndex_, uint256 recipientIndex_) public virtual useTimestamps useRandomLp(lpIndex_) returns (bool success_) {
        numCalls++;
        numberOfCalls["transfer"]++;

        if (pool.balanceOf(currentLp) == 0) return false;

        amount_ = constrictToRange(amount_, 1, pool.balanceOf(currentLp));

        address recipient_ = lps[constrictToRange(recipientIndex_, 0, lps.length - 1)];  // TODO: Investigate why this is happening

        return pool.transfer(recipient_, amount_);
    }

    // function transferFrom(address owner_, address recipient_, uint256 amount_, uint256 lpIndex_) public virtual useTimestamps useRandomLp(lpIndex_) returns (bool success_) {
        // numCalls++;
    //     return pool.transferFrom(owner_, recipient_, amount_);
    // }

    // function _getDigest(address token_, address owner_, address spender_, uint256 amount_, uint256 nonce_, uint256 deadline_) internal view returns (bytes32 digest_) {
    //     // numCalls++;
    //     return keccak256(
    //         abi.encodePacked(
    //             '\x19\x01',
    //             fundsAsset.DOMAIN_SEPARATOR(),
    //             keccak256(abi.encode(fundsAsset.PERMIT_TYPEHASH(), owner_, spender_, amount_, nonce_, deadline_))
    //         )
    //     );
    // }

    // function _getValidPermitSignature(address token_, address owner_, address spender_, uint256 amount_, uint256 nonce_, uint256 deadline_, uint256 ownerSk_) internal returns (uint8 v_, bytes32 r_, bytes32 s_) {
    //     // numCalls++;
    //     return vm.sign(ownerSk_, _getDigest(token_, owner_, spender_, amount_, nonce_, deadline_));
    // }

}
