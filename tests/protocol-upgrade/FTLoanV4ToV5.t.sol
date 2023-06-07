// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    IFixedTermLoan,
    ILoanV4Like,
    INonTransparentProxy,
    IProxyFactoryLike
} from "../../contracts/interfaces/Interfaces.sol";

import {
    FixedTermLoan,
    FixedTermLoanInitializer,
    FixedTermLoanV5Migrator,
    Globals
} from "../../contracts/Contracts.sol";

import { ProtocolActions } from "../../contracts/ProtocolActions.sol";

import { UpgradeAddressRegistry } from "./UpgradeAddressRegistry.sol";

interface IFixedTermLoanV4Like {

    function interestRate() external view returns (uint256 interestRate_);

    function lateInterestPremium() external view returns (uint256 lateInterestPremium_);

    function lateFeeRate() external view returns (uint256 lateFeeRate_);

    function getNextPaymentBreakdown() external view returns (uint256 principal_, uint256 interest_, uint256 fees_);

    function getClosingPaymentBreakdown() external view returns (uint256 principal_, uint256 interest_, uint256 fees_);

}

contract FTLoansFromV4ToV5 is UpgradeAddressRegistry, ProtocolActions {

    uint256 constant blockNumber = 17421835;

    function setUp() external {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), blockNumber);

        upgradeGlobals(mapleGlobalsProxy, address(new Globals()));

        vm.startPrank(governor);

        IProxyFactoryLike(fixedTermLoanFactory).registerImplementation(
            501,
            address(new FixedTermLoan()),
            address(new FixedTermLoanInitializer())
        );

        IProxyFactoryLike(fixedTermLoanFactory).setDefaultVersion(501);
        IProxyFactoryLike(fixedTermLoanFactory).enableUpgradePath(400, 501, address(new FixedTermLoanV5Migrator()));

        vm.stopPrank();
    }

    function test_mainnet_upgradeLoansV4ToV5() external {
        for (uint256 i; i < mavenUsdcLoans.length; ++i) {
            _upgradeLoanFromV4ToV5(mavenUsdcLoans[i]);
        }

        for (uint256 i; i < mavenPermissionedLoans.length; ++i) {
            _upgradeLoanFromV4ToV5(mavenPermissionedLoans[i]);
        }

        for (uint256 i; i < mavenWethLoans.length; ++i) {
            _upgradeLoanFromV4ToV5(mavenWethLoans[i]);
        }

        for (uint256 i; i < orthogonalLoans.length; ++i) {
            _upgradeLoanFromV4ToV5(orthogonalLoans[i]);
        }

        for (uint256 i; i < icebreakerLoans.length; ++i) {
            _upgradeLoanFromV4ToV5(icebreakerLoans[i]);
        }

        for (uint256 i; i < aqruLoans.length; ++i) {
            _upgradeLoanFromV4ToV5(aqruLoans[i]);
        }

        for (uint256 i; i < mavenUsdc3Loans.length; ++i) {
            _upgradeLoanFromV4ToV5(mavenUsdc3Loans[i]);
        }

        for (uint256 i; i < cashMgmtLoans.length; ++i) {
            _upgradeLoanFromV4ToV5(cashMgmtLoans[i]);
        }
    }

    function _upgradeLoanFromV4ToV5(address loan) internal {
        // Store Loan State prior to migration
        uint256 oldInterestRate        = IFixedTermLoanV4Like(loan).interestRate();
        uint256 oldLateInterestPremium = IFixedTermLoanV4Like(loan).lateInterestPremium();
        uint256 oldLateFeeRate         = IFixedTermLoanV4Like(loan).lateFeeRate();

        ( uint256 oldPrincipal, uint256 oldInterest, uint256 oldFees ) = IFixedTermLoanV4Like(loan).getNextPaymentBreakdown();

        (
            uint256 oldClosingPrincipal,
            uint256 oldClosingInterest,
            uint256 oldClosingFees
        ) = IFixedTermLoanV4Like(loan).getClosingPaymentBreakdown();

        upgradeLoanAsSecurityAdmin(loan, 501, new bytes(0));

        assertEq(oldInterestRate,        IFixedTermLoan(loan).interestRate() * 1e12);
        assertEq(oldLateInterestPremium, IFixedTermLoan(loan).lateInterestPremiumRate() * 1e12);
        assertEq(oldLateFeeRate,         IFixedTermLoan(loan).lateFeeRate() * 1e12);

        ( uint256 newPrincipal, uint256 newInterest, uint256 newFees ) = IFixedTermLoan(loan).getNextPaymentBreakdown();

        assertEq(oldPrincipal, newPrincipal);
        assertEq(oldInterest,  newInterest);
        assertEq(oldFees,      newFees);

        (
            uint256 newClosingPrincipal,
            uint256 newClosingInterest,
            uint256 newClosingFees
        ) = IFixedTermLoan(loan).getClosingPaymentBreakdown();

        assertEq(oldClosingPrincipal, newClosingPrincipal);
        assertEq(oldClosingInterest,  newClosingInterest);
        assertEq(oldClosingFees,      newClosingFees);
    }

}
