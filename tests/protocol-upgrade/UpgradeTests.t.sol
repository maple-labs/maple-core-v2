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

        _assertIsLoan(aqruLoans);
        _assertIsLoan(cashMgmtLoans);
        _assertIsLoan(mavenPermissionedLoans);
        _assertIsLoan(mavenWethLoans);
    }

}
