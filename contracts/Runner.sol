// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { Test, console2 } from "../modules/forge-std/src/Test.sol";

import { ERC20Helper } from "../modules/erc20-helper/src/ERC20Helper.sol";

import { MapleAddressRegistryETH } from "../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

contract EmptyContract { }

contract Runner is Test {

    bytes public constant assertionError      = abi.encodeWithSignature("Panic(uint256)", 0x01);
    bytes public constant arithmeticError     = abi.encodeWithSignature("Panic(uint256)", 0x11);
    bytes public constant divisionError       = abi.encodeWithSignature("Panic(uint256)", 0x12);
    bytes public constant enumConversionError = abi.encodeWithSignature("Panic(uint256)", 0x21);
    bytes public constant encodeStorageError  = abi.encodeWithSignature("Panic(uint256)", 0x22);
    bytes public constant popError            = abi.encodeWithSignature("Panic(uint256)", 0x31);
    bytes public constant indexOOBError       = abi.encodeWithSignature("Panic(uint256)", 0x32);
    bytes public constant memOverflowError    = abi.encodeWithSignature("Panic(uint256)", 0x41);
    bytes public constant zeroVarError        = abi.encodeWithSignature("Panic(uint256)", 0x51);

    function deploy(string memory contractName) internal returns (address contract_) {
        contract_ = deployCode(string(abi.encodePacked("./out/", contractName, ".sol/", contractName, ".json")));
    }

    function deploy(string memory contractName, bytes memory data) internal returns (address contract_) {
        contract_ = deployCode(string(abi.encodePacked("./out/", contractName, ".sol/", contractName, ".json")), data);
    }

    function deployFromFile(string memory folder, string memory contractName) internal returns (address contract_) {
        contract_ = deployCode(string(abi.encodePacked("./out/", folder, ".sol/", contractName, ".json")));
    }

    function deployFromFile(string memory folder, string memory contractName, bytes memory data) internal returns (address contract_) {
        contract_ = deployCode(string(abi.encodePacked("./out/", folder, ".sol/", contractName, ".json")), data);
    }

    function deployMock(string memory mockName) internal returns (address mock_) {
        mock_ = deployCode(string(abi.encodePacked("./out/Mocks.sol/", mockName, ".json")));
    }

    function deployMock(string memory mockName, bytes memory data) internal returns (address mock_) {
        mock_ = deployCode(string(abi.encodePacked("./out/Mocks.sol/", mockName, ".json")), data);
    }

    function deployNPT(address owner, address impl) internal returns (address npt_) {
        npt_ = deployCode(string(abi.encodePacked("./out/NonTransparentProxy.sol/NonTransparentProxy.json")), abi.encode(owner, impl));
    }

}
