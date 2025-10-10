// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { ICompositeToken, IERC20, IGlobals } from "../../../../contracts/interfaces/Interfaces.sol";

import { SyrupBitcoinTestBase } from "../SyrupBitcoinTestBase.sol";

contract CompositeTokenInitializerTests is SyrupBitcoinTestBase {

    function setUp() public override {
        start = block.timestamp;

        _createAccounts();
        _createGlobals();
        _createAssets();
        _configureGlobals();
        _createFactories();
    }

    function test_compositeTokenInitializer_revert_invalidGlobals_globalsIsNotAContract() public {
        globals                      = IGlobals(makeAddr("globals"));
        compositeTokenImplementation = deployFromFile("Contracts@25", "CompositeToken");
        compositeTokenInitializer    = deployFromFile("Contracts@25", "CompositeTokenInitializer");

        vm.expectRevert("NTPI:C:INVALID_GLOBALS");
        deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                compositeTokenImplementation,
                compositeTokenInitializer,
                abi.encodeWithSignature("initialize(string,string,uint8)", "Synthetic Bitcoin", "synthBTC", 8)
            )
        );
    } 

    function test_compositeTokenInitializer_revert_invalidImplementation_implementationIsNotAContract() public {
        compositeTokenImplementation = makeAddr("implementation");
        compositeTokenInitializer    = deployFromFile("Contracts@25", "CompositeTokenInitializer");

        vm.expectRevert("NTPI:U:INVALID_IMPLEMENTATION");
        deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                compositeTokenImplementation,
                compositeTokenInitializer,
                abi.encodeWithSignature("initialize(string,string,uint8)", "Synthetic Bitcoin", "synthBTC", 8)
            )
        );
    }

    function test_compositeTokenInitializer_revert_invalidMigrator_migratorIsNotAContract() public {
        compositeTokenImplementation = deployFromFile("Contracts@25", "CompositeToken");
        compositeTokenInitializer    = makeAddr("migrator");

        vm.expectRevert("NTPI:U:INVALID_MIGRATOR");
        deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                compositeTokenImplementation,
                compositeTokenInitializer,
                abi.encodeWithSignature("initialize(string,string,uint8)", "Synthetic Bitcoin", "synthBTC", 8)
            )
        );
    }

    function test_compositeTokenInitializer_revert_unusedCallData_initializerIsZeroAddressAndCallDataIsNotEmpty() public {
        compositeTokenImplementation = deployFromFile("Contracts@25", "CompositeToken");
        compositeTokenInitializer    = address(0);

        vm.expectRevert("NTPI:U:UNUSED_CALLDATA");
        deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                address(globals),
                compositeTokenImplementation,
                compositeTokenInitializer,
                abi.encodeWithSignature("initialize(string,string,uint8)", "Synthetic Bitcoin", "synthBTC", 8)
            )
        );
    }

    function test_compositeTokenInitializer_success() public {
        compositeTokenImplementation = deployFromFile("Contracts@25", "CompositeToken");
        compositeTokenInitializer    = deployFromFile("Contracts@25", "CompositeTokenInitializer");

        address compositeTokenProxyBefore = compositeTokenProxy;

        compositeTokenProxy = deployFromFile(
            "Contracts@25",
            "NonTransparentProxyInitializable",
            abi.encode(
                globals,
                compositeTokenImplementation,
                compositeTokenInitializer,
                abi.encodeWithSignature("initialize(string,string,uint8)", "Synthetic Bitcoin 2", "synthBTC2.0", 8)
            )
        );

        assertNotEq(compositeTokenProxy, compositeTokenProxyBefore);

        assertEq(IERC20(compositeTokenProxy).name(),     "Synthetic Bitcoin 2");
        assertEq(IERC20(compositeTokenProxy).symbol(),   "synthBTC2.0");
        assertEq(IERC20(compositeTokenProxy).decimals(), 8);

        assertEq(ICompositeToken(compositeTokenProxy).allAllowed(), false);
    }

}
