// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console2 as console } from "../../../contracts/Contracts.sol";

import { TestBase } from "../../TestBase.sol";

import {
    Call,
    IERC20Like,
    IEntryPointLike,
    IModularAccountLike,
    IMultiOwnerModularAccountFactoryLike,
    UserOperation
} from "../../../contracts/interfaces/Interfaces.sol";

contract SmartAccountETHTests is TestBase {

    // Values taken from Alchemy test suite.
    uint256 public constant CALL_GAS_LIMIT         = 500000;
    uint256 public constant VERIFICATION_GAS_LIMIT = 2000000;

    // Modular account related contracts.
    address multiOwnerModularAccountFactory         = 0x000000e92D78D90000007F0082006FDA09BD5f11;
    address multiOwnerPlugin                        = 0xcE0000007B008F50d762D155002600004cD6c647;
    address upgradeableModularAccountImplementation = 0x0046000000000151008789797b54fdb500E2a61e;

    address payable beneficiary;
    address owner;

    uint256 privateKey;
    uint256 salt;

    uint256 depositAmount;
    uint256 gasFeeAmount;

    IEntryPointLike entryPoint = IEntryPointLike(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789);

    function setUp() public override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 19617209);

        beneficiary = payable(makeAddr("beneficiary"));

        ( owner, privateKey ) = makeAddrAndKey("owner");

        salt = 1337;

        depositAmount = 1_500_000e6;
        gasFeeAmount  = 1e18;

        super.setUp();
    }

    /**************************************************************************************************************************************/
    /*** Smart Account Tests                                                                                                            ***/
    /**************************************************************************************************************************************/

    function testFork_deposit_predeterminedAddressApproval() external {
        // Fund the owner.
        erc20_mint(address(fundsAsset), owner, depositAmount);

        // Calculate the address the smart account will be deployed on.
        address smartAccount = findSmartAccount(salt, owner);

        console.log("smartAccount", smartAccount);

        // Approve the pre-determined smart account address to transfer the funds.
        vm.prank(owner);
        IERC20Like(address(fundsAsset)).approve(smartAccount, depositAmount);

        // Create the smart account.
        createSmartAccount(salt, owner);

        // Fund the smart account with ETH.
        deal(smartAccount, gasFeeAmount);

        // Allowlist the smart account.
        allowLender(address(poolManager), smartAccount);

        // Define 3 calls.
        Call[] memory calls = new Call[](3);

        // Transfer funds from the owner to the smart account.
        calls[0] = Call({
            target: address(fundsAsset),
            value: 0,
            data: abi.encodeWithSignature("transferFrom(address,address,uint256)", owner, smartAccount, depositAmount)
        });

        // Approve the funds for the pool deposit.
        calls[1] = Call({
            target: address(fundsAsset),
            value: 0,
            data: abi.encodeWithSignature("approve(address,uint256)", address(pool), depositAmount)
        });

        // Perform the pool deposit.
        calls[2] = Call({
            target: address(pool),
            value: 0,
            data: abi.encodeWithSignature("deposit(uint256,address)", depositAmount, smartAccount)
        });

        // Send the transaction.
        sendUserOp(smartAccount, calls);

        // Assert USDC and pool share balances.
        assertEq(IERC20Like(address(fundsAsset)).balanceOf(owner),         0);
        assertEq(IERC20Like(address(fundsAsset)).balanceOf(smartAccount),  0);
        assertEq(IERC20Like(address(fundsAsset)).balanceOf(address(pool)), depositAmount);

        assertEq(pool.balanceOf(owner),        0);
        assertEq(pool.balanceOf(smartAccount), depositAmount);
    }

    /**************************************************************************************************************************************/
    /*** Utility Functions                                                                                                              ***/
    /**************************************************************************************************************************************/

    function createSmartAccount(uint256 salt_, address owner_) public returns (address account_) {
        address[] memory owners_ = new address[](1);
        owners_[0] = owner_;

        account_ = IMultiOwnerModularAccountFactoryLike(multiOwnerModularAccountFactory).createAccount(salt_, owners_);
    }

    function findSmartAccount(uint256 salt_, address owner_) public view returns (address account_) {
        address[] memory owners_ = new address[](1);
        owners_[0] = owner_;

        account_ = IMultiOwnerModularAccountFactoryLike(multiOwnerModularAccountFactory).getAddress(salt_, owners_);
    }

    function sendUserOp(address account, Call[] memory calls) internal {
        UserOperation memory op = UserOperation({
            sender:               account,
            nonce:                IModularAccountLike(account).getNonce(),
            initCode:             new bytes(0),
            callData:             abi.encodeWithSelector(IModularAccountLike.executeBatch.selector, calls),
            callGasLimit:         CALL_GAS_LIMIT,
            verificationGasLimit: VERIFICATION_GAS_LIMIT,
            preVerificationGas:   0,
            maxFeePerGas:         2,
            maxPriorityFeePerGas: 1,
            paymasterAndData:     "",
            signature:            ""
        });

        bytes32 userOpHash = entryPoint.getUserOpHash(op);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, toEthSignedMessageHash(userOpHash));
        op.signature = abi.encodePacked(r, s, v);

        UserOperation[] memory userOps = new UserOperation[](1);
        userOps[0] = op;

        entryPoint.handleOps(userOps, beneficiary);
    }

    // Taken from OpenZeppelins MessageHashUtils.sol
    function toEthSignedMessageHash(bytes32 messageHash) internal pure returns (bytes32 digest) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, "\x19Ethereum Signed Message:\n32") // 32 is the bytes-length of messageHash
            mstore(0x1c, messageHash) // 0x1c (28) is the length of the prefix
            digest := keccak256(0x00, 0x3c) // 0x3c is the length of the prefix (0x1c) + messageHash (0x20)
        }
    }

}
