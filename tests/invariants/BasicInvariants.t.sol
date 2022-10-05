// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.7;

import { Address, console, InvariantTest } from "../../modules/contract-test-utils/contracts/test.sol";

import { TestBaseWithAssertions } from "../../contracts/utilities/TestBaseWithAssertions.sol";

import { LpBase }     from "./actors/Lp.sol";
import { WarperBase } from "./actors/Warper.sol";

contract BasicInterestAccrualTest is InvariantTest, TestBaseWithAssertions {

    function setUp() public override {
        super.setUp();

        _excludeAllContracts();

        address warper = address(new WarperBase());
        address lp     = address(new LpBase(address(pool)));

        targetContract(lp);
        targetContract(warper);

        targetSender(address(0xbeef));
    }

    function invariant_totalSupplyGtZero() external {
        assertTrue(pool.totalSupply() >= 0);
    }

    function _excludeAllContracts() internal {
        excludeContract(governor);
        excludeContract(poolDelegate);
        excludeContract(treasury);

        excludeContract(liquidatorFactory);
        excludeContract(liquidatorInitializer);
        excludeContract(liquidatorImplementation);

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
        excludeContract(address(deployer));
        excludeContract(address(globals));
        excludeContract(address(feeManager));
        excludeContract(address(fundsAsset));
        excludeContract(address(loanManager));
        excludeContract(address(pool));
        excludeContract(address(poolCover));
        excludeContract(address(poolManager));
        excludeContract(address(withdrawalManager));

        excludeContract(globals.implementation());
    }

}


