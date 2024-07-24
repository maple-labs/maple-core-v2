// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { ProtocolUpgradeBase } from "./ProtocolUpgradeBase.sol";

import {
    console2 as console,
    FixedTermLoan,
    FixedTermLoanManager,
    FixedTermRefinancer,
    PoolManager,
    OpenTermLoan,
    OpenTermLoanManager
} from "../../contracts/Contracts.sol";

contract LoanScenarioTests is ProtocolUpgradeBase {

    function testFork_fixedTermPreALTFailures() external {
        // Hardcoded seed, doesn't need to be fuzzed.
        seed = 112233;

        _setUpAddresses();

        // Perform the upgrade
        _upgradeAndAssert();

        // Deploy a fixed term loan
        FixedTermLoan ftLoan = FixedTermLoan(createSomeFixedTermLoan());

        address borrower_ = ftLoan.borrower();
        uint256 amount_   = getSomeValue(10_000e6, 1_000_000e6);

        erc20_mint(_fundsAsset, borrower_, amount_);
        erc20_approve(_fundsAsset, borrower_, address(ftLoan), amount_);

        // Fund Failure
        vm.expectRevert("ML:FL:TERMS_NOT_ACCEPTED");
        vm.prank(poolDelegate);
        FixedTermLoanManager(_fixedTermLoanManager).fund(address(ftLoan));

        // Make Payment Failure
        vm.expectRevert(arithmeticError);
        vm.prank(borrower_);
        ftLoan.makePayment(amount_);

        // Accept New Terms Failure
        bytes[] memory calls =  new bytes[](1);
        calls[0] = abi.encodeWithSignature("setClosingRate(uint256)", uint256(0));

        vm.prank(borrower_);
        ftLoan.proposeNewTerms(fixedTermRefinancerV2, block.timestamp, calls);

        vm.expectRevert("LM:HPPA:NOT_LOAN");
        vm.prank(poolDelegate);
        FixedTermLoanManager(_fixedTermLoanManager).acceptNewTerms(address(ftLoan), fixedTermRefinancerV2, block.timestamp, calls, 0);

        // Trigger default failure
        vm.prank(poolDelegate);
        vm.expectRevert("LM:TD:NOT_LOAN");
        PoolManager(_poolManager).triggerDefault(address(ftLoan), liquidatorFactory);
    }

    function testFork_openTermPreALTFailures() external {
        // Hardcoded seed, doesn't need to be fuzzed.
        seed = 112233;

        _setUpAddresses();

        // Perform the upgrade
        _upgradeAndAssert();

        // Deploy a fixed term loan
        OpenTermLoan otLoan = OpenTermLoan(createSomeOpenTermLoan());

        address borrower_ = otLoan.borrower();
        uint256 amount_   = getSomeValue(10_000e6, 1_000_000e6);

        erc20_mint(_fundsAsset, borrower_, amount_);
        erc20_approve(_fundsAsset, borrower_, address(otLoan), amount_);

        // Fund Failure
        vm.expectRevert("ML:F:TERMS_NOT_ACCEPTED");
        vm.prank(poolDelegate);
        OpenTermLoanManager(_openTermLoanManager).fund(address(otLoan));

        // Make Payment Failure
        vm.expectRevert("ML:MP:LOAN_INACTIVE");
        vm.prank(borrower_);
        otLoan.makePayment(amount_);

        // Propose New Terms Failure
        bytes[] memory calls =  new bytes[](1);
        calls[0] = abi.encodeWithSignature("setGracePeriod(uint256)", uint256(0));

        vm.expectRevert("LM:NOT_LOAN");
        vm.prank(poolDelegate);
        OpenTermLoanManager(_openTermLoanManager).proposeNewTerms(address(otLoan), openTermRefinancer, block.timestamp, calls);

        // Call loan Failure
        vm.expectRevert("LM:NOT_LOAN");
        vm.prank(poolDelegate);
        OpenTermLoanManager(_openTermLoanManager).callPrincipal(address(otLoan), 1e6);
    }

}
