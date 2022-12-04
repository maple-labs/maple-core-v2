// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console } from "../modules/contract-test-utils/contracts/test.sol";

import { IMapleLoanLike } from "../simulations/mainnet/Interfaces.sol";
import { SimulationBase } from "../simulations/mainnet/SimulationBase.sol";

contract UpgradeLoansTo301 is SimulationBase {

    address[] LoansThatRequireManualMigration;

    function run() external {
        upgradeLoansTo301(mavenUsdcLoans);
        upgradeLoansTo301(mavenPermissionedLoans);
        upgradeLoansTo301(mavenWethLoans);
        upgradeLoansTo301(orthogonalLoans);
    }

    function upgradeLoansTo301(IMapleLoanLike[] storage loans) internal {
        for (uint256 i; i < loans.length; ++i) {
            IMapleLoanLike loan = loans[i];

            // Note: If borrower is a contract script will fail
            if (address(loan.borrower()).code.length > 0) {
                LoansThatRequireManualMigration.push(address(loan));
                continue;
            }

            if (loanFactory.versionOf(loan.implementation()) == 301) continue;

            if (loanFactory.versionOf(loan.implementation()) == 200) {
                vm.setEnv("ETH_FROM", vm.toString(loan.borrower()));
                vm.startBroadcast();
                loan.upgrade(300, new bytes(0));
                loan.upgrade(301, new bytes(0));
                vm.stopBroadcast();
            }

            if (loanFactory.versionOf(loan.implementation()) == 300) {
                console.log("upgrading", address(loan));
                console.log("borrower", loan.borrower());

                vm.broadcast(loan.borrower());
                loan.upgrade(301, new bytes(0));
            }

            assertVersion(301, address(loan));
        }

        for (uint256 i; i < LoansThatRequireManualMigration.length; ++i) {
            console.log("Loans That Require Manual Migration: ", LoansThatRequireManualMigration[i]);
        }
    }

}
