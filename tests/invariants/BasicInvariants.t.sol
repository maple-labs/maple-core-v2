// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { Address, console, InvariantTest } from "../../modules/contract-test-utils/contracts/test.sol";

import { TestBaseWithAssertions } from "../../contracts/utilities/TestBaseWithAssertions.sol";

contract BasicInterestAccrualTest is InvariantTest, TestBaseWithAssertions {

    function setUp() public override {
        super.setUp();
        _excludeAllContracts();
    }

    function invariant_totalSupplyGtZero() external {
        // assertTrue(pool.totalSupply() >= 0);
    }

    function _excludeAllContracts() internal {
        excludeContract(governor);
        excludeContract(poolDelegate);
        excludeContract(treasury);

        excludeContract(loanFactory);
        excludeContract(loanImplementation);
        excludeContract(loanInitializer);

        excludeContract(loanManagerFactory);
        excludeContract(loanManagerInitializer);
        excludeContract(loanManagerImplementation);

        excludeContract(poolManagerFactory);
        excludeContract(poolManagerImplementation);
        excludeContract(poolManagerInitializer);

        excludeContract(withdrawalManagerFactory);
        excludeContract(withdrawalManagerImplementation);
        excludeContract(withdrawalManagerInitializer);

        excludeContract(address(collateralAsset));
        excludeContract(address(fundsAsset));
        excludeContract(address(globals));
        excludeContract(address(deployer));
        excludeContract(address(feeManager));
        excludeContract(address(loanManager));
        excludeContract(address(pool));
        excludeContract(address(poolCover));
        excludeContract(address(poolManager));
        excludeContract(address(withdrawalManager));

        excludeContract(globals.implementation());
        excludeContract(loanManager.implementation());
        excludeContract(poolManager.implementation());
        excludeContract(withdrawalManager.implementation());
    }

}


