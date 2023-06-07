// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IInvariantTest, IPool, IPoolManager, IWithdrawalManager } from "../../../contracts/interfaces/Interfaces.sol";

// TODO: MockERC20 is not needed if protocol actions are used which handle minting.
import { console2, MockERC20 } from "../../../contracts/Contracts.sol";

import { HandlerBase } from "./HandlerBase.sol";

contract LpHandler is HandlerBase {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    address currentLp;

    uint256 public numHolders;
    uint256 public numLps;

    address[] public holders;
    address[] public lps;

    MockERC20          fundsAsset;
    IPool              pool;
    IWithdrawalManager withdrawalManager;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(address pool_, address testContract_, uint256 numLps_) {
        pool              = IPool(pool_);
        testContract      = IInvariantTest(testContract_);
        withdrawalManager = IWithdrawalManager(IPoolManager(pool.manager()).withdrawalManager());

        fundsAsset = MockERC20(pool.asset());

        numLps     = numLps_;
        numHolders = numLps + 1;  // Include withdrawal manager

        for (uint256 i; i < numLps_; ++i) {
            address lp = makeAddr(string(abi.encode("lp", i)));
            lps.push(lp);
            holders.push(lp);
        }

        holders.push(address(withdrawalManager));
    }

    /**************************************************************************************************************************************/
    /*** Modifiers                                                                                                                      ***/
    /**************************************************************************************************************************************/

    modifier useRandomLp(uint256 lpIndex_) {
        currentLp = lps[_bound(lpIndex_, 0, lps.length - 1)];  // TODO: Investigate why this is happening
        vm.startPrank(currentLp);
        _;
        vm.stopPrank();
    }

    /**************************************************************************************************************************************/
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function deposit(uint256 seed_) public virtual useTimestamps useRandomLp(seed_) returns (uint256 shares_) {
        console2.log("lpHandler.deposit(%s)", seed_);

        numberOfCalls["deposit"]++;

        uint256 assets_ = _bound(_randomize(seed_, "assets"), 100, 1e26); // Set to max resolution / 10 of LM

        fundsAsset.mint(currentLp, assets_);
        fundsAsset.approve(address(pool), assets_);

        shares_ = pool.deposit(assets_, currentLp);  // TODO: Fuzz receiver
    }

    function mint(uint256 seed_) public virtual useTimestamps useRandomLp(seed_) returns (uint256 assets_) {
        console2.log("lpHandler.mint(%s)", seed_);

        numberOfCalls["mint"]++;

        // The first mint needs to be large enough to not lock mints if total assets eventually become zero due to defaults.
        uint256 shares_ = _bound(_randomize(seed_, "shares"), 10, 1e26);

        assets_ = pool.totalSupply() == 0 ? shares_ : shares_ * pool.totalAssets() / pool.totalSupply() + 100;

        fundsAsset.mint(currentLp, assets_);
        fundsAsset.approve(address(pool), assets_);

        assets_ = pool.mint(shares_, currentLp);  // TODO: Fuzz receiver
    }

    function redeem(uint256 seed_) public virtual useTimestamps useRandomLp(seed_) returns (uint256 assets_) {
        console2.log("lpHandler.redeem(%s)", seed_);

        numberOfCalls["redeem"]++;

        uint256 exitCycleId_ = withdrawalManager.exitCycleId(currentLp);

        if (exitCycleId_ == 0) return 0;

        ( uint256 windowStart_, uint256 windowEnd_ ) = withdrawalManager.getWindowAtId(withdrawalManager.exitCycleId(currentLp));

        if (block.timestamp > windowStart_) return 0;  // Only warp forward

        vm.warp(_bound(_randomize(seed_, "warp"), windowStart_, windowEnd_ - 1 seconds));

        assets_ = pool.redeem(withdrawalManager.lockedShares(currentLp), currentLp, currentLp);  // TODO: Fuzz owner and receiver
    }

    // TODO: Add WM interface
    function removeShares(uint256 seed_) public virtual useTimestamps useRandomLp(seed_) returns (uint256 assets_) {
        console2.log("lpHandler.removeShares(%s)", seed_);

        numberOfCalls["removeShares"]++;

        uint256 exitCycleId_ = withdrawalManager.exitCycleId(currentLp);

        if (exitCycleId_ == 0) return 0;

        ( uint256 windowStart_, ) = withdrawalManager.getWindowAtId(withdrawalManager.exitCycleId(currentLp));

        if (block.timestamp > windowStart_) return 0;

        vm.warp(_bound(_randomize(seed_, "warp"), windowStart_, windowStart_ + 1 days));

        assets_ = pool.removeShares(withdrawalManager.lockedShares(currentLp), currentLp);  // TODO: Fuzz owner and receiver
    }

    function requestRedeem(uint256 seed_) public virtual useTimestamps useRandomLp(seed_) returns (uint256 escrowShares_) {
        console2.log("lpHandler.requestRedeem(%s)", seed_);

        numberOfCalls["requestRedeem"]++;

        if (pool.balanceOf(currentLp) == 0 || withdrawalManager.lockedShares(currentLp) != 0) return 0;

        uint256 shares_ = _bound(_randomize(seed_, "shares"), 1, pool.balanceOf(currentLp));

        escrowShares_ = pool.requestRedeem(shares_, currentLp);  // TODO: Add fuzzing for users
    }

    /**************************************************************************************************************************************/
    /*** ERC-20 Functions                                                                                                               ***/
    /**************************************************************************************************************************************/

    function transfer(uint256 seed_) public virtual useTimestamps useRandomLp(seed_) returns (bool success_) {
        console2.log("lpHandler.transfer(%s)", seed_);

        numberOfCalls["transfer"]++;

        if (pool.balanceOf(currentLp) == 0) return false;

        uint256 amount_ = _bound(_randomize(seed_, "amount"), 1, pool.balanceOf(currentLp));

        // TODO: Investigate why this is happening
        address recipient_ = lps[_bound(_randomize(seed_, "recipient"), 0, lps.length - 1)];

        success_ = pool.transfer(recipient_, amount_);
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _randomize(uint256 seed, string memory salt) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(seed, salt)));
    }

}
