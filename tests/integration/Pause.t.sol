// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IProxyFactoryLike } from "../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../TestBaseWithAssertions.sol";

contract PauseTests is TestBaseWithAssertions {

    address borrower          = makeAddr("borrower");
    address pausePoolDelegate = makeAddr("pausePoolDelegate");

    address fixedTermLoan;
    address fixedTermLoanManager;
    address liquidator;
    address openTermLoan;
    address openTermLoanManager;

    /**************************************************************************************************************************************/
    /*** Functions Mappings (Need to be continuously updated with new functions)                                                        ***/
    /**************************************************************************************************************************************/

    bytes[] fixedTermLoanFunctions = [
        abi.encodeWithSignature("migrate(address,bytes)", address(0), new bytes(0)),
        abi.encodeWithSignature("setImplementation(address)", address(0)),
        abi.encodeWithSignature("upgrade(uint256,bytes)", 0, new bytes(0)),
        abi.encodeWithSignature("acceptBorrower()"),
        abi.encodeWithSignature("closeLoan(uint256)", 0),
        abi.encodeWithSignature("drawdownFunds(uint256,address)", 0, address(0)),
        abi.encodeWithSignature("makePayment(uint256)", 0),
        abi.encodeWithSignature("postCollateral(uint256)", 0),
        abi.encodeWithSignature("proposeNewTerms(address,uint256,bytes[])", address(0), 0, new bytes[](0)),
        abi.encodeWithSignature("removeCollateral(uint256,address)", 0, address(0)),
        abi.encodeWithSignature("returnFunds(uint256)", 0),
        abi.encodeWithSignature("setPendingBorrower(address)", address(0)),
        abi.encodeWithSignature("acceptLender()"),
        abi.encodeWithSignature("acceptNewTerms(address,uint256,bytes[])", address(0), 0, new bytes[](0)),
        abi.encodeWithSignature("fundLoan()"),
        abi.encodeWithSignature("removeLoanImpairment()"),
        abi.encodeWithSignature("repossess(address)", address(0)),
        abi.encodeWithSignature("setPendingLender(address)", address(0)),
        abi.encodeWithSignature("impairLoan()"),
        abi.encodeWithSignature("rejectNewTerms(address,uint256,bytes[])", address(0), 0, new bytes[](0)),
        abi.encodeWithSignature("skim(address,address)", address(0), address(0))
    ];

    bytes[] fixedTermLoanManagerFunctions = [
        abi.encodeWithSignature("fund(address)", address(0)),
        abi.encodeWithSignature("migrate(address,bytes)", address(0), new bytes(0)),
        abi.encodeWithSignature("setImplementation(address)", address(0)),
        abi.encodeWithSignature("upgrade(uint256,bytes)", 0, new bytes(0)),
        abi.encodeWithSignature("setAllowedSlippage(address,uint256)", address(0), 0),
        abi.encodeWithSignature("setMinRatio(address,uint256)", address(0), 0),
        abi.encodeWithSignature("updateAccounting()"),
        abi.encodeWithSignature("acceptNewTerms(address,address,uint256,bytes[],uint256)",  address(0), address(0), 0, new bytes[](0), 0),
        abi.encodeWithSignature("rejectNewTerms(address,address,uint256,bytes[])", address(0), address(0), 0, new bytes[](0)),
        abi.encodeWithSignature("claim(uint256,uint256,uint256,uint256)", 0, 0, 0, 0),
        abi.encodeWithSignature("impairLoan(address)", address(0)),
        abi.encodeWithSignature("removeLoanImpairment(address)", address(0)),
        abi.encodeWithSignature("finishCollateralLiquidation(address)", address(0)),
        abi.encodeWithSignature("triggerDefault(address,address)", address(0), address(0))
    ];

    bytes[] liquidatorFunctions = [
        // NOTE: Commented functions currently don't implement paused modifier.
        // abi.encodeWithSignature("migrate(address,bytes)", address(0), new bytes(0)),
        // abi.encodeWithSignature("setImplementation(address)", address(0)),
        // abi.encodeWithSignature("upgrade(uint256,bytes)", 0, new bytes(0)),
        // abi.encodeWithSignature("setCollateralRemaining(uint256)", 0),
        // abi.encodeWithSignature("pullFunds(address,address,uint256)", address(0), address(0), 0)
        abi.encodeWithSignature("liquidatePortion(uint256,uint256,bytes)", 0, 0, new bytes(0))
    ];

    bytes[] openTermLoanFunctions = [
        abi.encodeWithSignature("migrate(address,bytes)", address(0), new bytes(0)),
        abi.encodeWithSignature("setImplementation(address)", address(0)),
        abi.encodeWithSignature("upgrade(uint256,bytes)", address(0), new bytes(0)),
        abi.encodeWithSignature("acceptBorrower()"),
        abi.encodeWithSignature("acceptNewTerms(address,uint256,bytes[])", address(0), 0, new bytes[](0)),
        abi.encodeWithSignature("makePayment(uint256)", 0),
        abi.encodeWithSignature("setPendingBorrower(address)", address(0)),
        abi.encodeWithSignature("acceptLender()"),
        abi.encodeWithSignature("callPrincipal(uint256)", 0),
        abi.encodeWithSignature("fund()"),
        abi.encodeWithSignature("impair()"),
        abi.encodeWithSignature("proposeNewTerms(address,uint256,bytes[])", address(0), 0, new bytes[](0)),
        abi.encodeWithSignature("removeCall()"),
        abi.encodeWithSignature("removeImpairment()"),
        abi.encodeWithSignature("repossess(address)", address(0)),
        abi.encodeWithSignature("setPendingLender(address)", address(0)),
        abi.encodeWithSignature("rejectNewTerms(address,uint256,bytes[])", address(0), 0, new bytes[](0)),
        abi.encodeWithSignature("skim(address,address)", address(0), address(0))
    ];

    bytes[] openTermLoanManagerFunctions = [
        abi.encodeWithSignature("fund(address)", address(0)),
        abi.encodeWithSignature("migrate(address,bytes)", address(0), new bytes(0)),
        abi.encodeWithSignature("setImplementation(address)", address(0)),
        abi.encodeWithSignature("upgrade(uint256,bytes)", address(0), new bytes(0)),
        abi.encodeWithSignature("proposeNewTerms(address,address,uint256,bytes[])", address(0), address(0), 0, new bytes[](0)),
        abi.encodeWithSignature("rejectNewTerms(address,address,uint256,bytes[])", address(0), address(0), 0, new bytes[](0)),
        abi.encodeWithSignature("claim(int256,uint256,uint256,uint256,uint40)", int(0), 0, 0, 0, 0),
        abi.encodeWithSignature("callPrincipal(address,uint256)", address(0), 0),
        abi.encodeWithSignature("removeCall(address)", address(0)),
        abi.encodeWithSignature("impairLoan(address)", address(0)),
        abi.encodeWithSignature("removeLoanImpairment(address)", address(0)),
        abi.encodeWithSignature("triggerDefault(address,address)", address(0), address(0)),
        abi.encodeWithSignature("triggerDefault(address)", address(0))
    ];

    bytes[] poolFunctions = [
        abi.encodeWithSignature("deposit(uint256,address)", 0, address(0)),
        abi.encodeWithSignature("depositWithPermit(uint256,address,uint256,uint8,bytes32,bytes32)", 0, address(0), 0, 0, 0, "", ""),
        abi.encodeWithSignature("mintWithPermit(uint256,address,uint256,uint256,uint8,bytes32,bytes32)", 0, address(0), 0, 0, 0, "", ""),
        abi.encodeWithSignature("mint(uint256,address)", 0, address(0)),
        abi.encodeWithSignature("redeem(uint256,address,address)", 0, address(0), address(0)),
        abi.encodeWithSignature("withdraw(uint256,address,address)", 0, address(0), address(0)),
        abi.encodeWithSignature("transfer(address,uint256)", address(0), 0),
        abi.encodeWithSignature("transferFrom(address,address,uint256)", address(0), address(0), 0),
        abi.encodeWithSignature("removeShares(uint256,address)", 0, address(0)),
        abi.encodeWithSignature("requestRedeem(uint256,address)", 0, address(0)),
        abi.encodeWithSignature("requestWithdraw(uint256,address)", 0, address(0))
    ];

    bytes[] poolManagerFunctions = [
        abi.encodeWithSignature("migrate(address,bytes)", address(0), new bytes(0)),
        abi.encodeWithSignature("setImplementation(address)", address(0)),
        abi.encodeWithSignature("upgrade(uint256,bytes)", 0, new bytes(0)),
        abi.encodeWithSignature("completeConfiguration()"),
        abi.encodeWithSignature("acceptPoolDelegate()"),
        abi.encodeWithSignature("setPendingPoolDelegate(address)", address(0)),
        abi.encodeWithSignature("setActive(bool)", false),
        abi.encodeWithSignature("addLoanManager(address)", address(0)),
        abi.encodeWithSignature("setAllowedLender(address,bool)", address(0), false),
        abi.encodeWithSignature("setDelegateManagementFeeRate(uint256)", 0),
        abi.encodeWithSignature("setIsLoanManager(address,bool)", address(0), false),
        abi.encodeWithSignature("setLiquidityCap(uint256)", 0),
        abi.encodeWithSignature("setOpenToPublic()"),
        abi.encodeWithSignature("setWithdrawalManager(address)", address(0)),
        abi.encodeWithSignature("requestFunds(address,uint256)", address(0), 0),
        abi.encodeWithSignature("finishCollateralLiquidation(address)", address(0)),
        abi.encodeWithSignature("triggerDefault(address,address)", address(0), address(0)),
        abi.encodeWithSignature("processRedeem(uint256,address,address)", 0, address(0), address(0)),
        abi.encodeWithSignature("processWithdraw(uint256,address,address)", 0, address(0), address(0)),
        abi.encodeWithSignature("removeShares(uint256,address)", 0, address(0)),
        abi.encodeWithSignature("requestRedeem(uint256,address,address)", 0, address(0), address(0)),
        abi.encodeWithSignature("requestWithdraw(uint256,uint256,address,address)", 0, 0, address(0), address(0)),
        abi.encodeWithSignature("depositCover(uint256)", 0),
        abi.encodeWithSignature("withdrawCover(uint256,address)", 0, address(0))
    ];

    bytes[] proxyFactoryFunctions = [
        abi.encodeWithSignature("createInstance(bytes,bytes32)",  new bytes(0), ""),
        abi.encodeWithSignature("upgradeInstance(uint256,bytes)", 0 , new bytes(0))
    ];

    bytes[] withdrawalManagerFunctions = [
        // abi.encodeWithSignature("migrate(address,bytes)", address(0), new bytes(0)),
        // abi.encodeWithSignature("setImplementation(address)", address(0)),
        // abi.encodeWithSignature("upgrade(uint256,bytes)", 0, new bytes(0)),
        abi.encodeWithSignature("setExitConfig(uint256,uint256)", 0, 0)
        // abi.encodeWithSignature("addShares(uint256,address)", 0, address(0)),
        // abi.encodeWithSignature("removeShares(uint256,address)", 0, address(0))
        // abi.encodeWithSignature("processExit(uint256,address)", 0, address(0))
    ];

    address[] contracts;

    mapping(address => bytes[]) functions;
    mapping(address => string)  messages;
    mapping(address => address) caller;


    function setUp() public override {
        super.setUp();

        deposit(makeAddr("depositor"), 3_500_000e6);

        fixedTermLoanManager = poolManager.loanManagerList(0);
        openTermLoanManager  = poolManager.loanManagerList(1);

        fixedTermLoan = fundAndDrawdownLoan({
            borrower:    borrower,
            termDetails: [uint256(12 hours), uint256(1_000_000), uint256(3)],
            amounts:     [uint256(100e18), uint256(1_000_000e6), uint256(1_000_000e6)],
            rates:       [uint256(0.31536e6), uint256(0), uint256(0), uint256(0)],
            loanManager: fixedTermLoanManager
        });

        openTermLoan = createOpenTermLoan(
            address(borrower),
            address(openTermLoanManager),
            address(fundsAsset),
            1_000_000e6,
            [uint32(2 days), 3 days, 30 days],
            [uint64(0.015768e6), 0.31536e6, 0.01e6, 0.015768e6]
        );

        vm.prank(fixedTermLoanManager);
        liquidator = IProxyFactoryLike(liquidatorFactory).createInstance(abi.encode(address(this), collateralAsset, fundsAsset), "salt");

        // Set up all mappings
        functions[liquidatorFactory]           = proxyFactoryFunctions;
        functions[poolManagerFactory]          = proxyFactoryFunctions;
        functions[fixedTermLoanFactory]        = proxyFactoryFunctions;
        functions[fixedTermLoanManagerFactory] = proxyFactoryFunctions;
        functions[openTermLoanFactory]         = proxyFactoryFunctions;
        functions[openTermLoanManagerFactory]  = proxyFactoryFunctions;
        functions[withdrawalManagerFactory]    = proxyFactoryFunctions;
        functions[fixedTermLoan]               = fixedTermLoanFunctions;
        functions[fixedTermLoanManager]        = fixedTermLoanManagerFunctions;
        functions[address(liquidator)]         = liquidatorFunctions;
        functions[openTermLoan]                = openTermLoanFunctions;
        functions[openTermLoanManager]         = openTermLoanManagerFunctions;
        functions[address(pool)]               = poolFunctions;
        functions[address(poolManager)]        = poolManagerFunctions;
        functions[address(withdrawalManager)]  = withdrawalManagerFunctions;

        messages[liquidatorFactory]           = "MPF:PROTOCOL_PAUSED";
        messages[poolManagerFactory]          = "MPF:PROTOCOL_PAUSED";
        messages[fixedTermLoanFactory]        = "MPF:PROTOCOL_PAUSED";
        messages[fixedTermLoanManagerFactory] = "MPF:PROTOCOL_PAUSED";
        messages[openTermLoanFactory]         = "MPF:PROTOCOL_PAUSED";
        messages[openTermLoanManagerFactory]  = "MPF:PROTOCOL_PAUSED";
        messages[withdrawalManagerFactory]    = "MPF:PROTOCOL_PAUSED";
        messages[fixedTermLoan]               = "L:PAUSED";
        messages[fixedTermLoanManager]        = "LM:PAUSED";
        messages[address(liquidator)]         = "LIQ:PROTOCOL_PAUSED";
        messages[openTermLoan]                = "ML:PAUSED";
        messages[openTermLoanManager]         = "LM:PAUSED";
        messages[address(pool)]               = "PM:CC:PAUSED";
        messages[address(poolManager)]        = "PM:PAUSED";
        messages[address(withdrawalManager)]  = "WM:PROTOCOL_PAUSED";

        // Factories contracts check ACL before pause
        caller[liquidatorFactory]           = address(fixedTermLoanManager);
        caller[poolManagerFactory]          = address(deployer);
        caller[fixedTermLoanManagerFactory] = address(poolManager);
        caller[openTermLoanFactory]         = address(borrower);
        caller[openTermLoanManagerFactory]  = address(poolManager);
        caller[withdrawalManagerFactory]    = address(deployer);
    }

    function test_globalPause() external {
        // All contracts are affected by the global pause
        contracts = [
            address(liquidatorFactory),
            address(poolManagerFactory),
            address(fixedTermLoanFactory),
            address(fixedTermLoanManagerFactory),
            address(openTermLoanFactory),
            address(openTermLoanManagerFactory),
            address(withdrawalManagerFactory),
            address(fixedTermLoan),
            address(fixedTermLoanManager),
            address(liquidator),
            address(openTermLoan),
            address(openTermLoanManager),
            address(pool),
            address(poolManager),
            address(withdrawalManager)
        ];

        vm.prank(governor);
        globals.setProtocolPause(true);

        for (uint256 i = 0; i < contracts.length; i++) {
            _assertAllPaused(contracts[i], functions[contracts[i]], messages[contracts[i]]);
        }

        // Unpause and run again
        vm.prank(governor);
        globals.setProtocolPause(false);

        for (uint256 i = 0; i < contracts.length; i++) {
            _assertNonePaused(contracts[i], functions[contracts[i]], messages[contracts[i]]);
        }
    }

    function test_contractPause() external {
        // Contracts that implement the newer globals pause structure.
        contracts = [
            address(fixedTermLoan),
            address(fixedTermLoanManager),
            address(openTermLoan),
            address(openTermLoanManager),
            address(poolManager)
            // address(pool),             // NOTE: PoolManager::canCall wasn't modified to new structure
        ];

        for (uint256 i = 0; i < contracts.length; i++) {
            vm.prank(governor);
            globals.setContractPause(contracts[i], true);

            _assertAllPaused(contracts[i], functions[contracts[i]], messages[contracts[i]]);

            vm.prank(governor);
            globals.setContractPause(contracts[i], false);

            _assertNonePaused(contracts[i], functions[contracts[i]], messages[contracts[i]]);
        }
    }

    function test_functionUnpauseAfterProtocolPause() external {
        contracts = [
            address(fixedTermLoan),
            address(fixedTermLoanManager),
            address(openTermLoan),
            address(openTermLoanManager),
            address(poolManager)
        ];

        // Set global pause
        vm.prank(governor);
        globals.setProtocolPause(true);

        // Iterate through each of the tested contracts
        for (uint256 i = 0; i < contracts.length; i++) {

            // Iterate through each of the contract's functions
            for (uint256 j = 0; j < functions[contracts[i]].length; j++) {
                bytes4 functionSig = bytes4(functions[contracts[i]][j]);

                vm.prank(governor);
                globals.setFunctionUnpause(contracts[i], functionSig, true);

                _assertFunctionIsNotPaused(contracts[i], functions[contracts[i]][j], messages[contracts[i]]);

                // Iterate again through all other functions to make sure they remain paused.
                for (uint256 k = 0; k < functions[contracts[i]].length; k++) {
                    if (k != j) _assertFunctionIsPaused(contracts[i], functions[contracts[i]][k], messages[contracts[i]]);
                }

                // Unpause function and check again
                vm.prank(governor);
                globals.setFunctionUnpause(contracts[i], functionSig, false);

                _assertFunctionIsPaused(contracts[i], functions[contracts[i]][j], messages[contracts[i]]);
            }
        }
    }

    function test_functionUnpauseAfterContractPause() external {
        contracts = [
            address(fixedTermLoan),
            address(fixedTermLoanManager),
            address(openTermLoan),
            address(openTermLoanManager),
            address(poolManager)
        ];

        // Iterate through each of the tested contracts
        for (uint256 i = 0; i < contracts.length; i++) {

            // Set contract pause
            vm.prank(governor);
            globals.setContractPause(contracts[i], true);

            // Iterate through each of the contract's functions
            for (uint256 j = 0; j < functions[contracts[i]].length; j++) {
                bytes4 functionSig = bytes4(functions[contracts[i]][j]);

                vm.prank(governor);
                globals.setFunctionUnpause(contracts[i], functionSig, true);

                _assertFunctionIsNotPaused(contracts[i], functions[contracts[i]][j], messages[contracts[i]]);

                // Iterate again through all other functions to make sure they remain paused.
                for (uint256 k = 0; k < functions[contracts[i]].length; k++) {
                    if (k != j) _assertFunctionIsPaused(contracts[i], functions[contracts[i]][k], messages[contracts[i]]);
                }

                // Unpause function and check again
                vm.prank(governor);
                globals.setFunctionUnpause(contracts[i], functionSig, false);

                _assertFunctionIsPaused(contracts[i], functions[contracts[i]][j], messages[contracts[i]]);
            }
        }
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _assertAllPaused(address contract_, bytes[] memory calldataArray_, string memory message_) internal {
        for (uint256 i = 0; i < calldataArray_.length; i++) {
            vm.prank(caller[contract_]);
            _assertFunctionIsPaused(contract_, calldataArray_[i], message_);
        }
    }

    function _assertNonePaused(address contract_, bytes[] memory calldataArray_, string memory message_) internal {
        for (uint256 i = 0; i < calldataArray_.length; i++) {
            vm.prank(caller[contract_]);
            _assertFunctionIsNotPaused(contract_, calldataArray_[i], message_);
        }
    }

    function _assertFunctionIsPaused(address contract_, bytes memory data, string memory message_) internal {
        ( bool success, bytes memory returnData ) = contract_.call(data);
        assertTrue(!success);

        string memory returnedMessage = abi.decode(slice(returnData, 4, returnData.length - 4), (string));
        assertEq(returnedMessage, message_, "Wrong message");  // If the call reverted with a different error, than it's not paused.
    }

    function _assertFunctionIsNotPaused(address contract_, bytes memory data, string memory message_) internal {
        ( bool success, bytes memory returnData ) = contract_.call(data);

        // The call didn't revert (or reverted without a message), so it's not pause
        if (success || returnData.length <= 36) return;

        string memory returnedMessage = abi.decode(slice(returnData, 4, returnData.length - 4), (string));
        assertTrue(keccak256(abi.encode(returnedMessage)) != keccak256(abi.encode(message_)), "Not paused message hash");
    }

    function slice(
        bytes memory _bytes,
        uint256 _start,
        uint256 _length
    )
        internal
        pure
        returns (bytes memory)
    {
        require(_length + 31 >= _length, "slice_overflow");
        require(_bytes.length >= _start + _length, "slice_outOfBounds");

        bytes memory tempBytes;

        assembly {
            switch iszero(_length)
            case 0 {
                // Get a location of some free memory and store it in tempBytes as
                // Solidity does for memory variables.
                tempBytes := mload(0x40)

                // The first word of the slice result is potentially a partial
                // word read from the original array. To read it, we calculate
                // the length of that partial word and start copying that many
                // bytes into the array. The first word we copy will start with
                // data we don't care about, but the last `lengthmod` bytes will
                // land at the beginning of the contents of the new array. When
                // we're done copying, we overwrite the full first word with
                // the actual length of the slice.
                let lengthmod := and(_length, 31)

                // The multiplication in the next line is necessary
                // because when slicing multiples of 32 bytes (lengthmod == 0)
                // the following copy loop was copying the origin's length
                // and then ending prematurely not copying everything it should.
                let mc := add(add(tempBytes, lengthmod), mul(0x20, iszero(lengthmod)))
                let end := add(mc, _length)

                for {
                    // The multiplication in the next line has the same exact purpose
                    // as the one above.
                    let cc := add(add(add(_bytes, lengthmod), mul(0x20, iszero(lengthmod))), _start)
                } lt(mc, end) {
                    mc := add(mc, 0x20)
                    cc := add(cc, 0x20)
                } {
                    mstore(mc, mload(cc))
                }

                mstore(tempBytes, _length)

                // Update free-memory pointer
                // Allocating the array padded to 32 bytes like the compiler does now
                mstore(0x40, and(add(mc, 31), not(31)))
            }
            // Return a zero-length array if there is a zero length slice
            default {
                tempBytes := mload(0x40)
                // Zero out the 32 bytes slice we are about to return
                // Needs to be done since Solidity does not garbage collect
                mstore(tempBytes, 0)

                mstore(0x40, add(tempBytes, 0x20))
            }
        }

        return tempBytes;
    }
}
