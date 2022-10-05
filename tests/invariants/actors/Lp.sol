// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { TestUtils } from "../../../modules/contract-test-utils/contracts/test.sol";
import { MockERC20 } from "../../../modules/erc20/contracts/test/mocks/MockERC20.sol";
import { IPool }     from "../../../modules/pool-v2/contracts/interfaces/IPool.sol";

contract LpBase is TestUtils {

    MockERC20 fundsAsset;
    IPool     pool;

    constructor (address pool_) {
        pool = IPool(pool_);

        fundsAsset = MockERC20(pool.asset());
    }

    /******************************************************************************************************************************/
    /*** Pool Functions                                                                                                         ***/
    /******************************************************************************************************************************/

    function deposit(uint256 assets_) public virtual returns (uint256 shares_) {
        assets_ = constrictToRange(assets_, 1, 1e29);

        fundsAsset.mint(address(this), assets_);
        fundsAsset.approve(address(pool), assets_);

        return pool.deposit(assets_, address(this));  // TODO: Fuzz receiver
    }

    // function depositWithPermit(uint256 assets_, address receiver_, uint256 deadline_, uint256 ownerSk_) public virtual returns (uint256 shares_) {
    //     assets_   = constrictToRange(assets_,   1,               1e29);
    //     deadline_ = constrictToRange(deadline_, block.timestamp, block.timestamp + 1_000_000 days);

    //     address owner_ = vm.addr(ownerSk_);

    //     ( uint8 v_, bytes32 r_, bytes32 s_ ) = _getValidPermitSignature(address(fundsAsset), owner_, address(this), assets_, fundsAsset.nonces(owner_), deadline_, ownerSk_);

    //     fundsAsset.mint(owner_, assets_);

    //     return pool.depositWithPermit(assets_, receiver_, deadline_, v_, r_, s_);
    // }

    function mint(uint256 shares_) public virtual returns (uint256 assets_) {
        shares_ = constrictToRange(shares_, 1, 1e29);

        uint256 assets_ = pool.totalSupply() == 0 ? shares_ : shares_ * pool.totalAssets() / pool.totalSupply() + 100;

        fundsAsset.mint(address(this), assets_);
        fundsAsset.approve(address(pool), assets_);

        return pool.mint(shares_, address(this));  // TODO: Fuzz receiver
    }

    // function mintWithPermit(uint256 shares_, address receiver_, uint256 maxAssets_, uint256 deadline_, uint8 v_, bytes32 r_, bytes32 s_) public virtual returns (uint256 assets_) {
    //     return pool.mintWithPermit(shares_, receiver_, maxAssets_, deadline_, v_, r_, s_);
    // }

    // function redeem(uint256 shares_) public virtual returns (uint256 assets_) {
    //     if (pool.balanceOf(address(this)) == 0) return 0;

    //     shares_ = constrictToRange(shares_, 1, pool.balanceOf(address(this)));

    //     return pool.redeem(shares_, address(this), address(this));  // TODO: Fuzz owner and receiver
    // }

    // TODO: Add WM interface
    // function removeShares(uint256 shares_, address owner_) public virtual returns (uint256 sharesReturned_) {
    //     if (pool.balanceOf(address(this)) == 0) return 0;

    //     shares_ = constrictToRange(shares_, 1, pool.balanceOf(address(this)));

    //     return pool.removeShares(shares_, owner_);
    // }

    // function requestWithdraw(uint256 assets_) public virtual returns (uint256 escrowShares_) {
    //     if (pool.balanceOfAssets(address(this)) == 0) return 0;

    //     assets_ = constrictToRange(assets_, 1, pool.balanceOfAssets(address(this)));

    //     return pool.requestWithdraw(assets_, address(this)); // TODO: Add fuzzing for users
    // }

    // function requestRedeem(uint256 shares_) public virtual returns (uint256 escrowShares_) {
    //     if (pool.balanceOf(address(this)) == 0) return 0;

    //     shares_ = constrictToRange(shares_, 1, pool.balanceOf(address(this)));

    //     return pool.requestRedeem(shares_, address(this)); // TODO: Add fuzzing for users
    // }

    // function withdraw(uint256 assets_, address receiver_, address owner_) public virtual returns (uint256 shares_) {
    //     if (pool.balanceOfAssets(address(this)) == 0) return 0;

    //     assets_ = constrictToRange(assets_, 1, pool.balanceOfAssets(address(this)));

    //     return pool.withdraw(assets_, receiver_, owner_);
    // }

    /******************************************************************************************************************************/
    /*** ERC-20 Functions                                                                                                       ***/
    /******************************************************************************************************************************/

    function approve(address spender_, uint256 amount_) public virtual returns (bool success_) {
        return pool.approve(spender_, amount_);
    }

    // function decreaseAllowance(address spender_, uint256 subtractedAmount_) public virtual returns (bool success_) {
    //     subtractedAmount_ = constrictToRange(subtractedAmount_, 0, pool.allowance(address(this), spender_));

    //     return pool.decreaseAllowance(spender_, subtractedAmount_);
    // }

    function increaseAllowance(address spender_, uint256 addedAmount_) public virtual returns (bool success_) {
        return pool.increaseAllowance(spender_, addedAmount_);
    }

    // function permit(address owner_, address spender_, uint amount_, uint deadline_, uint8 v_, bytes32 r_, bytes32 s_) public virtual {
    //     pool.permit(owner_, spender_, amount_, deadline_, v_, r_, s_);
    // }

    function transfer(address recipient_, uint256 amount_) public virtual returns (bool success_) {
        if (pool.balanceOf(address(this)) == 0) return false;

        amount_ = constrictToRange(amount_, 1, pool.balanceOf(address(this)));

        return pool.transfer(recipient_, amount_);
    }

    // function transferFrom(address owner_, address recipient_, uint256 amount_) public virtual returns (bool success_) {
    //     return pool.transferFrom(owner_, recipient_, amount_);
    // }

    function _getDigest(address token_, address owner_, address spender_, uint256 amount_, uint256 nonce_, uint256 deadline_) internal view returns (bytes32 digest_) {
        return keccak256(
            abi.encodePacked(
                '\x19\x01',
                fundsAsset.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(fundsAsset.PERMIT_TYPEHASH(), owner_, spender_, amount_, nonce_, deadline_))
            )
        );
    }

    function _getValidPermitSignature(address token_, address owner_, address spender_, uint256 amount_, uint256 nonce_, uint256 deadline_, uint256 ownerSk_) internal returns (uint8 v_, bytes32 r_, bytes32 s_) {
        return vm.sign(ownerSk_, _getDigest(token_, owner_, spender_, amount_, nonce_, deadline_));
    }


}
