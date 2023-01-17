// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address, console, TestUtils } from "../../../modules/contract-test-utils/contracts/test.sol";

import { MockERC20 }         from "../../../modules/erc20/contracts/test/mocks/MockERC20.sol";
import { WithdrawalManager } from "../../../modules/withdrawal-manager/contracts/WithdrawalManager.sol";

import { IPool, IPoolManager, ILoanManager } from "../../../contracts/interfaces/Interfaces.sol";

import { ITest } from "../interfaces/ITest.sol";

contract LpHandler is TestUtils {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                        ***/
    /**************************************************************************************************************************************/

    address internal currentLp;

    address[] public holders;
    address[] public lps;

    uint256 public numCalls;
    uint256 public numHolders;
    uint256 public numLps;

    mapping(bytes32 => uint256) public numberOfCalls;

    MockERC20         internal fundsAsset;
    IPool             internal pool;
    ITest             internal testContract;
    WithdrawalManager internal withdrawalManager;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor (address pool_, address testContract_, uint256 numLps_) {
        pool              = IPool(pool_);
        testContract      = ITest(testContract_);
        withdrawalManager = WithdrawalManager(IPoolManager(pool.manager()).withdrawalManager());

        fundsAsset = MockERC20(pool.asset());

        numLps     = numLps_;
        numHolders = numLps + 1;  // Include withdrawal manager

        for (uint256 i; i < numLps_; ++i) {
            address lp = address(new Address());
            lps.push(lp);
            holders.push(lp);
        }

        holders.push(address(withdrawalManager));
    }

    /**************************************************************************************************************************************/
    /*** Modifiers                                                                                                                      ***/
    /**************************************************************************************************************************************/

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

    /**************************************************************************************************************************************/
    /*** Pool Functions                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function deposit(uint256 assets_, uint256 lpIndex_) public virtual useTimestamps useRandomLp(lpIndex_) returns (uint256 shares_) {
        numCalls++;
        numberOfCalls["deposit"]++;

        assets_ = constrictToRange(assets_, 100, 1e29);

        fundsAsset.mint(currentLp, assets_);
        fundsAsset.approve(address(pool), assets_);

        shares_ = pool.deposit(assets_, currentLp);  // TODO: Fuzz receiver
    }

    function mint(uint256 shares_, uint256 lpIndex_) public virtual useTimestamps useRandomLp(lpIndex_) returns (uint256 assets_) {
        numCalls++;
        numberOfCalls["mint"]++;

        shares_ = constrictToRange(shares_, 1, 1e29);

        assets_ = pool.totalSupply() == 0 ? shares_ : shares_ * pool.totalAssets() / pool.totalSupply() + 100;

        fundsAsset.mint(currentLp, assets_);
        fundsAsset.approve(address(pool), assets_);

        assets_ = pool.mint(shares_, currentLp);  // TODO: Fuzz receiver
    }

    function redeem(uint256 warpSeed_, uint256 lpIndex_) public virtual useTimestamps useRandomLp(lpIndex_) returns (uint256 assets_) {
        numCalls++;
        numberOfCalls["redeem"]++;

        uint256 exitCycleId_ = withdrawalManager.exitCycleId(currentLp);

        if (exitCycleId_ == 0) return 0;

        ( uint256 windowStart_, uint256 windowEnd_ ) = withdrawalManager.getWindowAtId(withdrawalManager.exitCycleId(currentLp));

        if (block.timestamp > windowStart_) return 0;  // Only warp forward

        vm.warp(constrictToRange(warpSeed_, windowStart_, windowEnd_));

        assets_ = pool.redeem(withdrawalManager.lockedShares(currentLp), currentLp, currentLp);  // TODO: Fuzz owner and receiver
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

        assets_ = pool.removeShares(withdrawalManager.lockedShares(currentLp), currentLp);  // TODO: Fuzz owner and receiver
    }

    function requestRedeem(uint256 shares_, uint256 lpIndex_) public virtual useTimestamps useRandomLp(lpIndex_) returns (uint256 escrowShares_) {
        numCalls++;
        numberOfCalls["requestRedeem"]++;

        if (pool.balanceOf(currentLp) == 0 || withdrawalManager.lockedShares(currentLp) != 0) return 0;

        shares_ = constrictToRange(shares_, 1, pool.balanceOf(currentLp));

        escrowShares_ = pool.requestRedeem(shares_, currentLp);  // TODO: Add fuzzing for users
    }

    /**************************************************************************************************************************************/
    /*** ERC-20 Functions                                                                                                       ***/
    /**************************************************************************************************************************************/

    function transfer(uint256 amount_, uint256 lpIndex_, uint256 recipientIndex_) public virtual useTimestamps useRandomLp(lpIndex_) returns (bool success_) {
        numCalls++;
        numberOfCalls["transfer"]++;

        if (pool.balanceOf(currentLp) == 0) return false;

        amount_ = constrictToRange(amount_, 1, pool.balanceOf(currentLp));

        address recipient_ = lps[constrictToRange(recipientIndex_, 0, lps.length - 1)];  // TODO: Investigate why this is happening

        success_ = pool.transfer(recipient_, amount_);
    }

}
