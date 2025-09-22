// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract OracleTests is SyrupBitcoinTestBase {

    address newOracleProxy;

    function setUp() public virtual override {
        super.setUp();

        address newOracleImplementation = deployFromFile("Contracts@25", "AssetControllerOracle");

        newOracleProxy = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                address(newOracleImplementation),
                address(0),
                ""
            )
        );

        vm.prank(governor);
        globals.setValidInstanceOf("CONTROLLER_ORACLE", newOracleProxy, true);

        assertEq(globals.isInstanceOf("CONTROLLER_ORACLE", newOracleProxy), true);
    }

    function test_oracle_success() external {
        uint256 deployAmount = 1e6;

        assertEq(assetController.oracle(), address(priceOracle));        

        vm.prank(governor);
        assetController.setOracle(newOracleProxy);

        assertEq(assetController.oracle(),                                              newOracleProxy);
        assertEq(assetController.previewDeploy(address(depositAsset), deployAmount),    deployAmount);
        assertEq(assetController.previewReconcile(address(depositAsset), deployAmount), deployAmount);
    }

}
