// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IFixedTermLoanManager } from "../../contracts/interfaces/Interfaces.sol";

import { Address } from "../../contracts/Contracts.sol";

import { TestBase } from "../TestBase.sol";

contract SetMinRatioTests is TestBase {

    address COLLATERAL_ASSET = address(new Address());

    address loanManager;

    function setUp() public override {
        super.setUp();

        loanManager = poolManager.loanManagerList(0);
    }

    function test_setMinRatio_notAuthorized() external {
        vm.expectRevert("PM:SMR:NOT_AUTHORIZED");
        poolManager.setMinRatio(loanManager, COLLATERAL_ASSET, 1000e6);
    }

    function test_setMinRatio_notLoanManager() external {
        address notLoanManager = address(new Address());

        vm.prank(governor);
        vm.expectRevert("PM:SMR:NOT_LM");
        poolManager.setMinRatio(notLoanManager, COLLATERAL_ASSET, 1000e6);
    }

    function test_setMinRatio_notPoolManager() external {
        vm.expectRevert("LM:SMR:NOT_PM");
        IFixedTermLoanManager(loanManager).setMinRatio(COLLATERAL_ASSET, 1000e6);
    }

    function test_setMinRatio_withGovernor() external {
        vm.prank(governor);
        poolManager.setMinRatio(loanManager, COLLATERAL_ASSET, 1000e6);

        assertEq(IFixedTermLoanManager(loanManager).minRatioFor(COLLATERAL_ASSET), 1000e6);
    }

    function test_setMinRatio_withPoolDelegate() external {
        vm.prank(poolDelegate);
        poolManager.setMinRatio(loanManager, COLLATERAL_ASSET, 1000e6);

        assertEq(IFixedTermLoanManager(loanManager).minRatioFor(COLLATERAL_ASSET), 1000e6);
    }

}

contract SetSlippageTests is TestBase {

    address COLLATERAL_ASSET = address(new Address());

    address loanManager;

    function setUp() public override {
        super.setUp();

        loanManager = poolManager.loanManagerList(0);
    }

    function test_setAllowedSlippage_notAuthorized() external {
        vm.expectRevert("PM:SAS:NOT_AUTHORIZED");
        poolManager.setAllowedSlippage(loanManager, COLLATERAL_ASSET, 0.1e6);
    }

    function test_setAllowedSlippage_notLoanManager() external {
        address notLoanManager = address(new Address());

        vm.prank(governor);
        vm.expectRevert("PM:SAS:NOT_LM");
        poolManager.setAllowedSlippage(notLoanManager, COLLATERAL_ASSET, 0.1e6);
    }

    function test_setAllowedSlippage_notPoolManager() external {
        vm.expectRevert("LM:SAS:NOT_PM");
        IFixedTermLoanManager(loanManager).setAllowedSlippage(COLLATERAL_ASSET, 0.1e6);
    }

    function test_setAllowedSlippage_invalidSlippage() external {
        vm.startPrank(governor);
        vm.expectRevert("LM:SAS:INVALID_SLIPPAGE");
        poolManager.setAllowedSlippage(loanManager, COLLATERAL_ASSET, 1e6 + 1);

        poolManager.setAllowedSlippage(loanManager, COLLATERAL_ASSET, 1e6);
    }

    function test_setAllowedSlippage_withGovernor() external {
        vm.startPrank(governor);
        poolManager.setAllowedSlippage(loanManager, COLLATERAL_ASSET, 0.1e6);

        assertEq(IFixedTermLoanManager(loanManager).allowedSlippageFor(COLLATERAL_ASSET), 0.1e6);
    }

    function test_setAllowedSlippage_withPoolDelegate() external {
        vm.startPrank(poolDelegate);
        poolManager.setAllowedSlippage(loanManager, COLLATERAL_ASSET, 0.1e6);

        assertEq(IFixedTermLoanManager(loanManager).allowedSlippageFor(COLLATERAL_ASSET), 0.1e6);
    }

}
