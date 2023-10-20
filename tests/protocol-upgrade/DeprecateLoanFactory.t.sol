// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IMapleProxyFactory } from "../../contracts/interfaces/Interfaces.sol";

import { AddressRegistry, Test } from "../../contracts/Contracts.sol";

contract DeprecateLoanFactoryTest is AddressRegistry, Test {

    address borrower = 0xDA28e780472B5754a1144bcE6e83aF06a33107D2;

    address[2] assets  = [weth, usdc];
    uint256[3] terms   = [uint256(12 hours), uint256(1_000_000), uint256(3)];
    uint256[3] amounts = [uint256(0), uint256(1_500_000e6), uint256(1_500_000e6)];
    uint256[4] rates   = [uint256(3.1536e6), uint256(0), uint256(0), uint256(0)];
    uint256[2] fees    = [uint256(0), uint256(0)];

    bytes args = abi.encode(borrower, cashManagementUSDCFixedTermLoanManager, fixedTermFeeManagerV1, assets, terms, amounts, rates, fees);

    IMapleProxyFactory loanFactory = IMapleProxyFactory(fixedTermLoanFactory);

    function setUp() external {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 18382132);
    }

    /**************************************************************************************************************************************/
    /*** Deprecation Tests                                                                                                              ***/
    /**************************************************************************************************************************************/

    function testFork_deprecateFactory() external {
        // Successfully deploy loan.
        vm.prank(borrower);
        loanFactory.createInstance(args, "salt-1");

        // Deprecate factory.
        vm.prank(governor);
        loanFactory.setDefaultVersion(0);

        // Fail to deploy loan.
        vm.prank(borrower);
        vm.expectRevert();
        loanFactory.createInstance(args, "salt-2");
    }

}
