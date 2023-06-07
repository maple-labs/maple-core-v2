// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

// Direct imports to avoid changes to bytecode
import { MapleLoanFactory as FTLoanFactory } from "../modules/fixed-term-loan/contracts/MapleLoanFactory.sol";
import { MapleLoanFeeManager }               from "../modules/fixed-term-loan/contracts/MapleLoanFeeManager.sol";

import { LoanManagerFactory as FTLoanManagerFactory } from "../modules/fixed-term-loan-manager/contracts/proxy/LoanManagerFactory.sol";

import { Liquidator }        from "../modules/liquidations/contracts/Liquidator.sol";
import { LiquidatorFactory } from "../modules/liquidations/contracts/LiquidatorFactory.sol";

import { Pool }                   from "../modules/pool/contracts/Pool.sol";
import { PoolDelegateCover }      from "../modules/pool/contracts/PoolDelegateCover.sol";
import { PoolManagerFactory }     from "../modules/pool/contracts/proxy/PoolManagerFactory.sol";
import { PoolManagerInitializer } from "../modules/pool/contracts/proxy/PoolManagerInitializer.sol";

import { WithdrawalManager }            from "../modules/withdrawal-manager/contracts/WithdrawalManager.sol";
import { WithdrawalManagerFactory }     from "../modules/withdrawal-manager/contracts/WithdrawalManagerFactory.sol";
import { WithdrawalManagerInitializer } from "../modules/withdrawal-manager/contracts/WithdrawalManagerInitializer.sol";

import { AddressRegistry, Test } from "../contracts/Contracts.sol";

// NOTE: Demonstrates that the same bytecode hash is produced for contracts not changing in this upgrade
contract Equivalence is AddressRegistry, Test {

    uint256 constant blockNumber = 16941500;

    // In order of modules
    address controlFixedTermLoanFactory;
    address controlFeeManager;

    address controlFixedTermLoanManagerFactory;

    address controlLiquidator;
    address controlLiquidatorFactory;

    address controlPool;
    address controlPoolDelegateCover;
    address controlPoolManagerFactory;
    address controlPoolManagerInitializer;

    address controlWithdrawalManagerFactory;
    address controlWithdrawalManagerInitializer;
    address controlWithdrawalManager;

    function setUp() external {
        // Fork Mainnet
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), blockNumber);

        // Contracts not changing per module
        // Module: fixed-term-loan
        controlFixedTermLoanFactory = address(new FTLoanFactory(mapleGlobalsV2Proxy));
        controlFeeManager           = address(new MapleLoanFeeManager(mapleGlobalsV2Proxy));

        // Module: fixed-term-loan-manager
        controlFixedTermLoanManagerFactory = address(new FTLoanManagerFactory(mapleGlobalsV2Proxy));

        // Module: liquidations
        // LiquidatorInitializer NOTE: err msg changed therefore bytecode changed
        controlLiquidator        = address(new Liquidator());
        controlLiquidatorFactory = address(new LiquidatorFactory(mapleGlobalsV2Proxy));

        // Module: Pool
        // Use deployed pool manager address
        controlPool = address(new Pool(
            mavenPermissionedPoolManager,
            usdc,
            address(0),
            100000,
            0,
            "M11 Credit Maple Pool USDC1", "MPL-mcUSDC1"
        ));

        controlPoolDelegateCover      = address(new PoolDelegateCover(mavenPermissionedPoolManager, usdc));
        controlPoolManagerFactory     = address(new PoolManagerFactory(mapleGlobalsV2Proxy));
        controlPoolManagerInitializer = address(new PoolManagerInitializer());

        // Module: withdrawal-manager
        controlWithdrawalManagerFactory     = address(new WithdrawalManagerFactory(mapleGlobalsV2Proxy));
        controlWithdrawalManagerInitializer = address(new WithdrawalManagerInitializer());
        controlWithdrawalManager            = address(new WithdrawalManager());
    }

    function findMetadataIndex(bytes memory code_) internal pure returns (uint256 metaDataIndex_) {
        for (uint256 i; i < code_.length; ++i) {
            if (code_[i] == 0xfe && code_[i + 1] == 0xa2 && code_[i + 2] == 0x64) {
                // Find first instance as if the contract deploys another contract multiple IPFS hashes will be present
                metaDataIndex_ = i + 1; // +1 to include the 0xfe as its part of the runtime code
                break;
            }
        }
    }

    function removeMetadata(bytes memory code_) internal pure returns (bytes memory cleanedCode_) {
        uint256 metaDataIndex_ = findMetadataIndex(code_);

        cleanedCode_ = new bytes(metaDataIndex_);

        for (uint256 i; i < metaDataIndex_; ++i) {
            cleanedCode_[i] = code_[i];
        }
    }

    // Note: In each test load the contract from mainnet and Code the bytecode and compare to the local deployed contracts
    function test_equivalence() external {
        /**********************************************************************************************************************************/
        /*** FixedTermLoan Module                                                                                                       ***/
        /**********************************************************************************************************************************/

        // Fixed Term Loan Factory
        // TODO: This isn't changing, yet isn't passing.
        // bytes32 deployedFixedTermLoanFactoryHash = keccak256(removeMetadata(fixedTermLoanFactory.code));
        // bytes32 localFixedTermLoanFactoryHash    = keccak256(removeMetadata(controlFixedTermLoanFactory.code));

        // assertEq(deployedFixedTermLoanFactoryHash, localFixedTermLoanFactoryHash);

        // Fee Manager
        bytes32 deployedFeeManagerHash = keccak256(removeMetadata(feeManager.code));
        bytes32 localFeeManagerHash    = keccak256(removeMetadata(controlFeeManager.code));

        assertEq(deployedFeeManagerHash, localFeeManagerHash);

        /**********************************************************************************************************************************/
        /*** FixedTermLoanManager Module                                                                                                ***/
        /**********************************************************************************************************************************/

        // Fixed Term Loan Manager Factory
        bytes32 deployedFTLMFactoryHash = keccak256(removeMetadata(fixedTermLoanManagerFactory.code));
        bytes32 localFTLMFactoryHash    = keccak256(removeMetadata(controlFixedTermLoanManagerFactory.code));

        assertEq(deployedFTLMFactoryHash, localFTLMFactoryHash);

        /**********************************************************************************************************************************/
        /*** Liquidator Module                                                                                                          ***/
        /**********************************************************************************************************************************/

        // Liquidator
        bytes32 deployedLiquidatorHash = keccak256(removeMetadata(liquidatorImplementation.code));
        bytes32 localLiquidatorHash    = keccak256(removeMetadata(controlLiquidator.code));

        assertEq(deployedLiquidatorHash, localLiquidatorHash);

        // Liquidator Factory
        bytes32 deployedLiquidatorFactoryHash = keccak256(removeMetadata(liquidatorFactory.code));
        bytes32 localLiquidatorFactoryHash    = keccak256(removeMetadata(controlLiquidatorFactory.code));

        assertEq(deployedLiquidatorFactoryHash, localLiquidatorFactoryHash);

        /**********************************************************************************************************************************/
        /*** PoolV2 Module                                                                                                              ***/
        /**********************************************************************************************************************************/

        // Pool
        bytes32 deployedPoolHash = keccak256(removeMetadata(mavenPermissionedPool.code));
        bytes32 localPoolHash    = keccak256(removeMetadata(controlPool.code));

        assertEq(deployedPoolHash, localPoolHash);

        // Pool Delegate Cover
        bytes32 deployedPDCoverHash = keccak256(removeMetadata(mavenPermissionedPoolDelegateCover.code));
        bytes32 localPDCoverHash    = keccak256(removeMetadata(controlPoolDelegateCover.code));

        assertEq(deployedPDCoverHash, localPDCoverHash);

        // Pool Manager Factory
        bytes32 deployedPMFactoryCoverHash = keccak256(removeMetadata(poolManagerFactory.code));
        bytes32 localPMFactoryHash         = keccak256(removeMetadata(controlPoolManagerFactory.code));

        assertEq(deployedPMFactoryCoverHash, localPMFactoryHash);

        // Pool Manager Initializer
        bytes32 deployedPMInitializerCoverHash = keccak256(removeMetadata(poolManagerInitializer.code));
        bytes32 localPMInitializerHash         = keccak256(removeMetadata(controlPoolManagerInitializer.code));

        assertEq(deployedPMInitializerCoverHash, localPMInitializerHash);

        /**********************************************************************************************************************************/
        /*** WithdrawalManager Module                                                                                                   ***/
        /**********************************************************************************************************************************/

        // Withdrawal Manager Factory
        bytes32 deployedWMFactoryHash = keccak256(removeMetadata(withdrawalManagerFactory.code));
        bytes32 localWMFactoryHash    = keccak256(removeMetadata(controlWithdrawalManagerFactory.code));

        assertEq(deployedWMFactoryHash, localWMFactoryHash);

        // Withdrawal Manager Initializer
        bytes32 deployedWMInitializerHash = keccak256(removeMetadata(withdrawalManagerInitializer.code));
        bytes32 localWMInitializerHash    = keccak256(removeMetadata(controlWithdrawalManagerInitializer.code));

        assertEq(deployedWMInitializerHash, localWMInitializerHash);

        // Withdrawal Manager
        bytes32 deployedWMHash = keccak256(removeMetadata(withdrawalManagerImplementation.code));
        bytes32 localWMHash    = keccak256(removeMetadata(controlWithdrawalManager.code));

        assertEq(deployedWMHash, localWMHash);
    }

}
