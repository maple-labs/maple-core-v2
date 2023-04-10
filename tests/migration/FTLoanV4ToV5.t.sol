// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { ILoanV4Like, INonTransparentProxy, IProxyFactoryLike } from "../../contracts/interfaces/Interfaces.sol";

import {
    FixedTermLoan,
    FixedTermLoanInitializer,
    FixedTermLoanV5Migrator,
    Globals
} from "../../contracts/Contracts.sol";

import { AddressRegistry, Test } from "../../contracts/Contracts.sol";
import { ProtocolActions }       from "../../contracts/ProtocolActions.sol";

contract FTLoanV4ToV5 is Test, AddressRegistry, ProtocolActions {

    // New contracts
    address newGlobalsImplementation;
    address newFixedTermLoanImplementation;
    address newFixedTermLoanInitializer;
    address newFixedTermLoanMigrator;

    string url = vm.envString("ETH_RPC_URL");

    uint256 blockNumber = 16941500;

    // Avoid stack too deep
    uint256 oldInterestRate;
    uint256 oldLateFeeRate;
    uint256 oldLateInterestPremium;

    uint256 oldInterest;
    uint256 oldFees;
    uint256 oldPrincipal;

    uint256 oldClosingFees;
    uint256 oldClosingInterest;
    uint256 oldClosingPrincipal;

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

    function setUp() public {
        vm.createSelectFork(url, blockNumber);

        // Deploy Contracts
        newGlobalsImplementation       = address(new Globals());
        newFixedTermLoanImplementation = address(new FixedTermLoan());
        newFixedTermLoanInitializer    = address(new FixedTermLoanInitializer());
        newFixedTermLoanMigrator       = address(new FixedTermLoanV5Migrator());

        _upgradeGlobals();

        vm.startPrank(governor);
        // Setup Factory
        IProxyFactoryLike(fixedTermLoanFactory).registerImplementation(500, newFixedTermLoanImplementation, newFixedTermLoanInitializer);
        IProxyFactoryLike(fixedTermLoanFactory).setDefaultVersion(500);
        IProxyFactoryLike(fixedTermLoanFactory).enableUpgradePath(400, 500, newFixedTermLoanMigrator);
        vm.stopPrank();
    }

    function _upgradeGlobals() internal {
        vm.prank(governor);
        INonTransparentProxy(mapleGlobalsV2Proxy).setImplementation(newGlobalsImplementation);
    }

    function test_migrateFTLoanToV5() public {
        for (uint256 i = 0; i < activeLoans.length; i++) {
            // Store Loan State prior to migration
            ( oldPrincipal, oldInterest, oldFees ) = FixedTermLoan(activeLoans[i]).getNextPaymentBreakdown();

            oldInterestRate        = FixedTermLoan(activeLoans[i]).interestRate();
            oldLateInterestPremium = ILoanV4Like(activeLoans[i]).lateInterestPremium();
            oldLateFeeRate         = FixedTermLoan(activeLoans[i]).lateFeeRate();

            (
                oldClosingPrincipal,
                oldClosingInterest,
                oldClosingFees
            ) = FixedTermLoan(activeLoans[i]).getClosingPaymentBreakdown();

            upgradeLoan(activeLoans[i], 500, new bytes(0), securityAdmin);

            ( uint256 newPrincipal, uint256 newInterest, uint256 newFees ) = FixedTermLoan(activeLoans[i]).getNextPaymentBreakdown();

            (
                uint256 newClosingPrincipal,
                uint256 newClosingInterest,
                uint256 newClosingFees
            ) = FixedTermLoan(activeLoans[i]).getClosingPaymentBreakdown();

            assertEq(oldInterestRate,        FixedTermLoan(activeLoans[i]).interestRate() * 1e12);
            assertEq(oldLateInterestPremium, FixedTermLoan(activeLoans[i]).lateInterestPremiumRate() * 1e12);
            assertEq(oldLateFeeRate,         FixedTermLoan(activeLoans[i]).lateFeeRate() * 1e12);

            assertEq(oldPrincipal, newPrincipal);
            assertEq(oldInterest,  newInterest);
            assertEq(oldFees,      newFees);

            assertEq(oldClosingPrincipal, newClosingPrincipal);
            assertEq(oldClosingInterest,  newClosingInterest);
            assertEq(oldClosingFees,      newClosingFees);
        }
    }

}
