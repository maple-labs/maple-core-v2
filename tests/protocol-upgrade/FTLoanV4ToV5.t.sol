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

import { AddressRegistry } from "../../contracts/Contracts.sol";
import { ProtocolActions } from "../../contracts/ProtocolActions.sol";

interface IFixedTermLoanV4Like {

    function interestRate() external view returns (uint256 interestRate_);

    function lateInterestPremium() external view returns (uint256 lateInterestPremium_);

    function lateFeeRate() external view returns (uint256 lateFeeRate_);

    function getNextPaymentBreakdown() external view returns (uint256 principal_, uint256 interest_, uint256 fees_);

    function getClosingPaymentBreakdown() external view returns (uint256 principal_, uint256 interest_, uint256 fees_);

}

contract FTLoansFromV4ToV5 is AddressRegistry, ProtocolActions {

    uint256 constant blockNumber = 16941500;

    // Current Fixed-term Loans
    address[] activeLoans = [
        0xfb520De9e8CaD09a28A06E5fE27b8e392bffc209,
        0x0cbc028614F164A085fa24a895FE5E954faC5000,
        0x1b42E16958ed30dd3750d765C243BdDE980fdf64,
        0x1F2bCA37106b30C4d72d8E60eBD2bFeAa10BFfE2,
        0x3E36372119f12DEe3De6C260CC7283557C24f471,
        0xeB4F034958C6D3da0293142dd11F9EE2e2ad5019,
        0x48a89E5267Dd3e22822C99D0bf60a8A4CFd48B48,
        0xE12c3B659bc734b20f45FF35970bB2e892A1387C,
        0xE6E0586F009241b7A16EBe05d828d9e8231F3ADe,
        0x023Db56966858d139FE6406Ae927275490715a3a
    ];

    function setUp() external {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), blockNumber);

        upgradeGlobals(mapleGlobalsV2Proxy, address(new Globals()));

        vm.startPrank(governor);

        IProxyFactoryLike(fixedTermLoanFactory).registerImplementation(
            500,
            address(new FixedTermLoan()),
            address(new FixedTermLoanInitializer())
        );

        IProxyFactoryLike(fixedTermLoanFactory).setDefaultVersion(500);
        IProxyFactoryLike(fixedTermLoanFactory).enableUpgradePath(400, 500, address(new FixedTermLoanV5Migrator()));

        vm.stopPrank();
    }

    function test_mainnet_upgradeLoansV4ToV5() external {
        for (uint256 i; i < activeLoans.length; ++i) {
            address loan = activeLoans[i];

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

            upgradeLoanAsSecurityAdmin(loan, 500, new bytes(0));

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

}
