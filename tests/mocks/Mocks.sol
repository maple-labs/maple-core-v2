// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { MockERC20 } from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";

import { ILiquidatorLike } from "../../contracts/interfaces/Interfaces.sol";

contract ConfigurableMockERC20 is MockERC20 {

    address _caller;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) MockERC20(name_, symbol_, decimals_) { }

    modifier fail {
        if (msg.sender == _caller) {
            require(false);
        }

        _;
    }

    function approve(address spender_, uint256 amount_) public virtual override fail returns (bool success_) {
        success_ = super.approve(spender_, amount_);
    }

    function transfer(address recipient_, uint256 amount_) public virtual override fail returns (bool success_) {
        success_ = super.transfer(recipient_, amount_);
    }

    function transferFrom(address owner_, address recipient_, uint256 amount_) public virtual override fail returns (bool success_) {
        success_ = super.transferFrom(owner_, recipient_, amount_);
    }

    function __failWhenCalledBy(address caller_) external {
        _caller = caller_;
    }

}

contract FakeLoan {

    address public factory;

    function __setFactory(address factory_) external {
        factory = factory_;
    }

}

contract MockLiquidationStrategy {

    function flashBorrowLiquidation(address lender_, uint256 swapAmount_, address collateralAsset_, address fundsAsset_, address) external {
        uint256 repaymentAmount = ILiquidatorLike(lender_).getExpectedAmount(swapAmount_);

        MockERC20(fundsAsset_).approve(lender_, repaymentAmount);

        ILiquidatorLike(lender_).liquidatePortion(
            swapAmount_,
            type(uint256).max,
            abi.encodeWithSelector(this.swap.selector, collateralAsset_, fundsAsset_, swapAmount_, repaymentAmount)
        );
    }

    function swap(address collateralAsset_, address fundsAsset_, uint256 swapAmount_, uint256 repaymentAmount_) external {
        MockERC20(fundsAsset_).mint(address(this), repaymentAmount_);
        MockERC20(collateralAsset_).burn(address(this), swapAmount_);
    }

}
