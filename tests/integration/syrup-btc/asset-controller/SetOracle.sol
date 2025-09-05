// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { 
    IAssetControllerOracle 
} from "../../../../contracts/interfaces/Interfaces.sol";

import { AssetControllerTestBase } from "../AssetControllerTestBase.sol";

contract AssetControllerSetOracleTests is AssetControllerTestBase {

    IAssetControllerOracle newPriceOracle;

    function setUp() public virtual override {
        super.setUp();

        address priceOracleImplementation_ = deployFromFile("Contracts@25", "AssetControllerOracle");

        newPriceOracle = IAssetControllerOracle(deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                address(priceOracleImplementation_),
                address(0),
                new bytes(0)
            )
        ));

        vm.prank(governor);
        globals.setValidInstanceOf("CONTROLLER_ORACLE", address(newPriceOracle), true);
    }

    function test_setOracle_revert_notGovernor() external  {
        vm.expectRevert("AC:NOT_GOVERNOR");
        assetController.setOracle(address(newPriceOracle));
    }

    function test_setOracle_revert_notOracle() external {
        vm.startPrank(governor);

        globals.setValidInstanceOf("CONTROLLER_ORACLE", address(newPriceOracle), false);

        vm.expectRevert("AC:SO:NOT_ORACLE");
        assetController.setOracle(address(newPriceOracle));

        vm.stopPrank();
    }

    function test_setOracle_success() external {
        uint256 input_ = 1234;

        assertEq(assetController.oracle(), address(priceOracle));

        vm.prank(governor);
        assetController.setOracle(address(newPriceOracle));

        assertEq(assetController.oracle(), address(newPriceOracle));

        uint256 oracleResult_          = newPriceOracle.convert(address(0), address(0), input_, "");
        uint256 assetControllerResult_ = assetController.previewDeploy(address(0), input_);

        assertEq(oracleResult_,          input_);
        assertEq(assetControllerResult_, input_);
    }

}
