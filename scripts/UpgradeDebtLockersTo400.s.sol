// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { console } from "../modules/contract-test-utils/contracts/test.sol";

import { DebtLocker as DebtLockerV4 } from "../modules/debt-locker-v4/contracts/DebtLocker.sol";
import { DebtLockerFactory }          from "../modules/debt-locker-v4/contracts/DebtLockerFactory.sol";
import { DebtLockerV4Migrator }       from "../modules/debt-locker-v4/contracts/DebtLockerV4Migrator.sol";

import { IDebtLockerLike, IMapleLoanLike } from "../simulations/mainnet/Interfaces.sol";
import { SimulationBase }                  from "../simulations/mainnet/SimulationBase.sol";

contract UpgradeDebtLockersTo400 is SimulationBase {

    // Note: Update Address of Migration Admin if needed
    address migrationAdminScript = 0xb36419f1790CAebf85dd45dF659199F9957c41A4;

    function run() external {
        upgradeDebtLockersTo400(mavenPermissionedLoans);
        upgradeDebtLockersTo400(mavenUsdcLoans);
        upgradeDebtLockersTo400(mavenWethLoans);
        upgradeDebtLockersTo400(orthogonalLoans);
        upgradeDebtLockersTo400(icebreakerLoans);
        // upgradeDebtLockersTo400(unorderedMigrationLoans);
    }

    function upgradeDebtLockersTo400(IMapleLoanLike[] storage loans) internal {
        for (uint256 i = 0; i < loans.length; i++) {
            IDebtLockerLike debtLocker = IDebtLockerLike(loans[i].lender());

            if (debtLockerFactory.versionOf(debtLocker.implementation()) == 400) continue;

            if (debtLockerFactory.versionOf(debtLocker.implementation()) == 300) {
                vm.broadcast(debtLocker.poolDelegate());
                debtLocker.upgrade(400, abi.encode(migrationAdminScript));
            }

            if (debtLockerFactory.versionOf(debtLocker.implementation()) == 200) {
                vm.broadcast(debtLocker.poolDelegate());
                debtLocker.upgrade(400, abi.encode(migrationAdminScript));
            }

            assertVersion(400, address(debtLocker));
        }
    }

}
