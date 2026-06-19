// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { MockERC20 } from "../../modules/erc20/contracts/test/mocks/MockERC20.sol";

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

contract MockContractWithFallback {

    uint256 public counter;

    fallback() external {
        counter++;
    }

}

contract MockContractWithRevertingFallback {

    fallback() external {
        revert();
    }

}

contract MockFactory {

    function isInstance(address) external pure returns (bool) {
        return true;
    }

}

contract MockGlobals {

    address public governor;

    constructor(address governor_) {
        governor = governor_;
    }

}

contract MockPoolManager {

    address public factory;
    address public poolDelegate;
    bool    public active;

    constructor(address factory_, address poolDelegate_) {
        factory = factory_;
        poolDelegate = poolDelegate_;
    }

    function setActive(bool active_) external {
        active = active_;
    }

}

contract MockMapleWithdrawalManager {

    address public immutable poolManager;

    constructor(address poolManager_) {
        poolManager = poolManager_;
    }

}

contract FakeLoan {

    address public factory;

    function __setFactory(address factory_) external {
        factory = factory_;
    }

}
