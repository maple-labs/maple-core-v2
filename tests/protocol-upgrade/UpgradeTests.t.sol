// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IGlobals, IProxyFactoryLike } from "../../contracts/interfaces/Interfaces.sol";

import { ProtocolUpgradeBase } from "./ProtocolUpgradeBase.sol";

contract UpgradeTests is ProtocolUpgradeBase {

    function testFork_upgradeAssertions() external {
        _performProtocolUpgrade();

        _assertGlobals();
        _assertFactories();
        _assertPoolManagers();
        _assertPermissions();
        _assertAllowedLenders();

        _assertIsLoan(aqruFixedTermLoans);
        _assertIsLoan(cashMgmtUSDCFixedTermLoans);
        _assertIsLoan(mavenPermissionedFixedTermLoans);
        _assertIsLoan(mavenWethFixedTermLoans);
    }

}

contract UpgradeToQueueWMTests is ProtocolUpgradeBase {

    function testFork_upgradeToQueueWM() external {
        _performProtocolUpgrade();

        _upgradeToQueueWM(cashManagementUSDCPoolManager);
        _upgradeToQueueWM(cashManagementUSDTPoolManager);

        _assertGlobals();
        _assertFactories();
        _assertCashPoolManagers();
        _assertPermissions();
        _assertAllowedLenders();
    }

}

contract UpgradeFTLoansAgain is ProtocolUpgradeBase {

    function testFork_upgradeFTL_fromNewFactory() external {
        _performProtocolUpgrade();

        // Deploy a new implementation of loan
        _deployNewLoan();

        // Upgrade old loans to new implementation
        upgradeLoansAsSecurityAdmin(aqruFixedTermLoans,              503, new bytes(0));
        upgradeLoansAsSecurityAdmin(cashMgmtUSDCFixedTermLoans,      503, new bytes(0));
        upgradeLoansAsSecurityAdmin(cashMgmtUSDTFixedTermLoans,      503, new bytes(0));
        upgradeLoansAsSecurityAdmin(cicadaFixedTermLoans,            503, new bytes(0));
        upgradeLoansAsSecurityAdmin(mapleDirectFixedTermLoans,       503, new bytes(0));
        upgradeLoansAsSecurityAdmin(mavenPermissionedFixedTermLoans, 503, new bytes(0));
        upgradeLoansAsSecurityAdmin(mavenWethFixedTermLoans,         503, new bytes(0));

        _assertLoanVersion(aqruFixedTermLoans,              503);
        _assertLoanVersion(cashMgmtUSDCFixedTermLoans,      503);
        _assertLoanVersion(cashMgmtUSDTFixedTermLoans,      503);
        _assertLoanVersion(cicadaFixedTermLoans,            503);
        _assertLoanVersion(mapleDirectFixedTermLoans,       503);
        _assertLoanVersion(mavenPermissionedFixedTermLoans, 503);
        _assertLoanVersion(mavenWethFixedTermLoans,         503);
    }

}
