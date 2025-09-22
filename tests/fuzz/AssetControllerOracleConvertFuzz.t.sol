// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IAssetControllerOracle } from "../../contracts/interfaces/Interfaces.sol";

import { TestBase } from "../TestBase.sol";

contract AssetControllerOracleConvertFuzzTest is TestBase {

    IAssetControllerOracle oracle;

    function setUp() public virtual override {
        super.setUp();

        address priceOracleImplementation = deployFromFile("Contracts@25", "AssetControllerOracle");

        oracle = IAssetControllerOracle(
                deployFromFile(
                "Contracts@25",
                "NonTransparentProxyInitializable",
                abi.encode(
                    address(globals),
                    address(priceOracleImplementation),
                    address(0),
                    ""
                )
            )
        );
    }

    function deployToken(uint8 decimals_) internal returns (address token_) {
        token_ = deployMock("ConfigurableMockERC20", abi.encode("mocktoken", "mt", decimals_));
    }

    function test_convert_revert_decimalMismatch(uint8 decimalsIn_, uint8 decimalsOut_, uint256 amountIn_) external {
        bound(decimalsIn_,  1, 18);
        bound(decimalsOut_, 1, 18);

        vm.assume(decimalsOut_ != decimalsIn_);

        address assetIn  = deployToken(decimalsIn_);
        address assetOut = deployToken(decimalsOut_);

        vm.expectRevert("ACO:C:DECIMALS_MISMATCH");
        oracle.convert(assetIn, assetOut, amountIn_, bytes32(0));
    }

    function testFuzz_convert_success(uint256 amountIn_) external {
        address assetIn  = deployToken(8);
        address assetOut = deployToken(8);

        uint256 amountOut = oracle.convert(assetIn, assetOut, amountIn_, bytes32(0));

        assertEq(amountOut, amountIn_);
    }

}
