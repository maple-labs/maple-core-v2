// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { DebtLocker as DebtLockerV4 } from "../../modules/debt-locker-v4/contracts/DebtLocker.sol";
import { DebtLockerFactory }          from "../../modules/debt-locker-v4/contracts/DebtLockerFactory.sol";
import { DebtLockerV4Migrator }       from "../../modules/debt-locker-v4/contracts/DebtLockerV4Migrator.sol";

import { IDebtLockerLike, IMapleLoanLike, IMapleProxyFactoryLike } from "../mainnet-simulations/Interfaces.sol";

import { SimulationBase } from "../mainnet-simulations/SimulationBase.sol";

contract UpgradeDebtLockersTo400 is SimulationBase {

    function run() external {
        upgradeDebtLockersTo400(mavenPermissionedLoans);
        upgradeDebtLockersTo400(mavenUsdcLoans);
        upgradeDebtLockersTo400(mavenWethLoans);
        upgradeDebtLockersTo400(orthogonalLoans);
        upgradeDebtLockersTo400(icebreakerLoans);

        address[] memory migrationLoans = new address[](5);
        migrationLoans[0] = mavenPermissionedMigrationLoan;
        migrationLoans[1] = mavenUsdcMigrationLoan;
        migrationLoans[2] = mavenWethMigrationLoan;
        migrationLoans[3] = orthogonalMigrationLoan;
        migrationLoans[4] = icebreakerMigrationLoan;

        upgradeDebtLockersTo400(migrationLoans);
    }

    function upgradeDebtLockersTo400(address[] memory loans) internal {
        for (uint256 i; i < loans.length; ++i) {
            IDebtLockerLike debtLocker = IDebtLockerLike(IMapleLoanLike(loans[i]).lender());

            if (IMapleProxyFactoryLike(debtLockerFactory).versionOf(debtLocker.implementation()) == 400) continue;

            if (IMapleProxyFactoryLike(debtLockerFactory).versionOf(debtLocker.implementation()) == 200) {
                vm.broadcast(debtLocker.poolDelegate());
                debtLocker.upgrade(300, abi.encode(migrationHelperProxy));
            }

            if (IMapleProxyFactoryLike(debtLockerFactory).versionOf(debtLocker.implementation()) == 300) {
                vm.broadcast(debtLocker.poolDelegate());
                debtLocker.upgrade(400, abi.encode(migrationHelperProxy));
            }

            assertVersion(400, address(debtLocker));
        }
    }

}
