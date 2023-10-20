// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IGlobals, IProxyFactoryLike } from "../../contracts/interfaces/Interfaces.sol";

import { ProtocolUpgradeBase } from "./ProtocolUpgradeBase.sol";

contract FTLFactoryUpgradeTests is ProtocolUpgradeBase {

    function testFork_upgradeFTLFactory() external {
        _performProtocolUpgrade();

        IGlobals globals_ = IGlobals(globals);

        assertTrue(globals_.isInstanceOf("FT_LOAN_FACTORY", fixedTermLoanFactoryV502));

        assertEq(IProxyFactoryLike(fixedTermLoanFactoryV502).defaultVersion(), 502);

        _assertIsLoan(aqruLoans);
        _assertIsLoan(cashMgmtLoans);
        _assertIsLoan(mavenPermissionedLoans);
        _assertIsLoan(mavenWethLoans);
    }

}
