// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { SyrupBitcoinTestBase } from "../../SyrupBitcoinTestBase.sol";

contract PoolAssetTests is SyrupBitcoinTestBase {

    address newConvertableAsset;

    function setUp() public virtual override {
        super.setUp();

        newConvertableAsset = address(deployMock("ConfigurableMockERC20", abi.encode("Random Asset", "RND", 8)));
    }

    function test_poolAsset_modifyViaStorage() external {
        // Using vm.store cheat in this test because poolAsset does not have a setter.
        // Using vm.expectCall here to assert that the assetController is detecting the storage change. 

        uint256 depositAmount = 1e8;

        bytes32 slot = bytes32(uint256(1));

        assertEq(assetController.poolAsset(), address(compositeAsset));

        vm.expectCall(
            address(priceOracle),
            abi.encodeWithSignature(
                "convert(address,address,uint256,bytes32)",
                address(depositAsset),
                address(compositeAsset),
                depositAmount,
                EMPTY_METADATA
            )
        );

        assetController.previewDeploy(address(depositAsset), depositAmount);

        vm.store(address(assetController), slot, bytes32(uint256(uint160(newConvertableAsset))));
        assertEq(assetController.poolAsset(), newConvertableAsset);

        vm.expectCall(
            address(priceOracle),
            abi.encodeWithSignature(
                "convert(address,address,uint256,bytes32)",
                address(depositAsset),
                newConvertableAsset,
                depositAmount,
                EMPTY_METADATA
            )
        );

        assetController.previewDeploy(address(depositAsset), depositAmount);
    }

}
