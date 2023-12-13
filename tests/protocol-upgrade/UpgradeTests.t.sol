// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import {
    console2 as console,
    FixedTermLoan,
    FixedTermLoanFactory,
    Globals
} from "../../contracts/Contracts.sol";

import { ProtocolUpgradeBase }          from "./ProtocolUpgradeBase.sol";
import { UpgradeAddressRegistryETH }    from "./UpgradeAddressRegistryETH.sol";
import { UpgradeAddressRegistryBASEL2 } from "./UpgradeAddressRegistryBASEL2.sol";

contract UpgradeTestsETH is ProtocolUpgradeBase, UpgradeAddressRegistryETH {

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 18421300);
    }

    function testFork_upgradeAssertions_ETH() external {
        _performProtocolUpgrade();

        _assertGlobals();
        _assertFactories(poolManagerFactory, fixedTermLoanFactory, withdrawalManagerFactory, queueWMFactory);
        _assertPoolManagers();
        _assertPermissions();
        _assertAllowedLenders();
        _assertLoanVersion(502);
        _assertFTLs();
    }

    function testFork_upgradeToQueueWM_ETH() external {
        _performProtocolUpgrade();

        _upgradeToQueueWM(governor, globals, cashManagementUSDCPoolManager);
        _upgradeToQueueWM(governor, globals, cashManagementUSDTPoolManager);

        _assertGlobals();
        _assertFactories(poolManagerFactory, fixedTermLoanFactory, withdrawalManagerFactory, queueWMFactory);
        _assertQueuePoolManager(cashManagementUSDCPoolManager);
        _assertQueuePoolManager(cashManagementUSDTPoolManager);
        _assertPermissions();
        _assertAllowedLenders();
        _assertLoanVersion(502);
        _assertFTLs();
    }

    function testFork_upgradeFTL_fromNewFactory_ETH() external {
        _performProtocolUpgrade();

        // Deploy a new implementation of loan
        _deployNewLoan(governor);

        // Upgrade old loans to new implementation
        for (uint256 i = 0; i < pools.length; i++) {
            Pool storage pool = pools[i];

            if (pool.ftLoans.length == 0) continue;

            _upgradeFixedTermLoansAsSecurityAdmin(pool.ftLoans, 503, new bytes(0));
        }

        _assertLoanVersion(503);
    }

    function testFork_upgradeFTL_identicalFactory() external {
        _performPartialProtocolUpgrade();

        address securityAdmin = Globals(globals).securityAdmin();

        for (uint256 i = 0; i < pools.length; i++) {
            Pool storage pool = pools[i];

            for (uint256 j = 0; j < pool.ftLoans.length; j++) {
                FixedTermLoan        loan    = FixedTermLoan(pool.ftLoans[j]);
                FixedTermLoanFactory factory = FixedTermLoanFactory(loan.factory());

                vm.prank(securityAdmin);
                vm.expectRevert("MPF:UI:FAILED");
                loan.upgrade(502, abi.encode(fixedTermLoanFactory));

                vm.prank(securityAdmin);
                loan.upgrade(502, abi.encode(fixedTermLoanFactoryV2));

                assertEq(factory.versionOf(loan.implementation()), 502);
            }
        }
    }

}

contract UpgradeTestsBASEL2 is ProtocolUpgradeBase, UpgradeAddressRegistryBASEL2 {

    function setUp() public {
        vm.createSelectFork(vm.envString("BASE_RPC_URL"), 5944426);
    }

    function testFork_upgradeAssertions_BASEL2() external {
        _performProtocolUpgrade();

        _assertGlobals();
        _assertFactories(poolManagerFactory, fixedTermLoanFactory, withdrawalManagerFactory, queueWMFactory);
        _assertPoolManagers();
        _assertPermissions();
        _assertAllowedLenders();
        _assertLoanVersion(502);
        _assertFTLs();
    }

    function testFork_upgradeToQueueWM_BASEL2() external {
        _performProtocolUpgrade();

        _upgradeToQueueWM(governor, globals, cashManagementUSDCPoolManager);

        _assertGlobals();
        _assertFactories(poolManagerFactory, fixedTermLoanFactory, withdrawalManagerFactory, queueWMFactory);
        _assertQueuePoolManager(cashManagementUSDCPoolManager);
        _assertPermissions();
        _assertAllowedLenders();
        _assertLoanVersion(502);
        _assertFTLs();
    }

    function testFork_upgradeFTL_fromNewFactory_BASEL2() external {
        _performProtocolUpgrade();

        // Deploy a new implementation of loan
        _deployNewLoan(governor);

        // Upgrade old loans to new implementation
        for (uint256 i = 0; i < pools.length; i++) {
            Pool storage pool = pools[i];

            if (pool.ftLoans.length == 0) continue;

            _upgradeFixedTermLoansAsSecurityAdmin(pool.ftLoans, 503, new bytes(0));
        }

        _assertLoanVersion(503);
    }

    function testFork_upgradeFTL_identicalFactory() external {
        _performPartialProtocolUpgrade();

        address securityAdmin = Globals(globals).securityAdmin();

        for (uint256 i = 0; i < pools.length; i++) {
            Pool storage pool = pools[i];

            for (uint256 j = 0; j < pool.ftLoans.length; j++) {
                FixedTermLoan        loan    = FixedTermLoan(pool.ftLoans[j]);
                FixedTermLoanFactory factory = FixedTermLoanFactory(loan.factory());

                vm.prank(securityAdmin);
                vm.expectRevert("MPF:UI:FAILED");
                loan.upgrade(502, abi.encode(fixedTermLoanFactory));

                vm.prank(securityAdmin);
                loan.upgrade(502, abi.encode(fixedTermLoanFactoryV2));

                assertEq(factory.versionOf(loan.implementation()), 502);
            }
        }
    }

}
