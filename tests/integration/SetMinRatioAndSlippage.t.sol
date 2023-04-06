// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IFixedTermLoanManager } from "../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../TestBase.sol";

contract SetMinRatioTests is TestBase {

    address COLLATERAL_ASSET = makeAddr("collateralAsset");

    IFixedTermLoanManager loanManager;

    function setUp() public override {
        super.setUp();

        loanManager = IFixedTermLoanManager(poolManager.loanManagerList(0));
    }

    function test_setMinRatio_notAuthorized() external {
        vm.expectRevert("LM:SMR:NO_AUTH");
        loanManager.setMinRatio(COLLATERAL_ASSET, 1000e6);
    }

    function test_setMinRatio_notPoolManager() external {
        vm.expectRevert("LM:SMR:NO_AUTH");
        loanManager.setMinRatio(COLLATERAL_ASSET, 1000e6);
    }

    function test_setMinRatio_withGovernor() external {
        vm.prank(governor);
        loanManager.setMinRatio(COLLATERAL_ASSET, 1000e6);

        assertEq(loanManager.minRatioFor(COLLATERAL_ASSET), 1000e6);
    }

    function test_setMinRatio_withPoolDelegate() external {
        vm.prank(poolDelegate);
        loanManager.setMinRatio(COLLATERAL_ASSET, 1000e6);

        assertEq(loanManager.minRatioFor(COLLATERAL_ASSET), 1000e6);
    }

}

contract SetSlippageTests is TestBase {

    address COLLATERAL_ASSET = makeAddr("collateralAsset");

    IFixedTermLoanManager loanManager;

    function setUp() public override {
        super.setUp();

        loanManager = IFixedTermLoanManager(poolManager.loanManagerList(0));
    }

    function test_setAllowedSlippage_notAuthorized() external {
        vm.expectRevert("LM:SAS:NO_AUTH");
        loanManager.setAllowedSlippage(COLLATERAL_ASSET, 0.1e6);
    }

    function test_setAllowedSlippage_notPoolManager() external {
        vm.expectRevert("LM:SAS:NO_AUTH");
        loanManager.setAllowedSlippage(COLLATERAL_ASSET, 0.1e6);
    }

    function test_setAllowedSlippage_invalidSlippage() external {
        vm.startPrank(governor);
        vm.expectRevert("LM:SAS:INV_SLIPPAGE");
        loanManager.setAllowedSlippage(COLLATERAL_ASSET, 1e6 + 1);

        loanManager.setAllowedSlippage(COLLATERAL_ASSET, 1e6);
    }

    function test_setAllowedSlippage_withGovernor() external {
        vm.startPrank(governor);
        loanManager.setAllowedSlippage(COLLATERAL_ASSET, 0.1e6);

        assertEq(loanManager.allowedSlippageFor(COLLATERAL_ASSET), 0.1e6);
    }

    function test_setAllowedSlippage_withPoolDelegate() external {
        vm.startPrank(poolDelegate);
        loanManager.setAllowedSlippage(COLLATERAL_ASSET, 0.1e6);

        assertEq(loanManager.allowedSlippageFor(COLLATERAL_ASSET), 0.1e6);
    }

}
