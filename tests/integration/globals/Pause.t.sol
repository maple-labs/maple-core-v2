// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IPool, IPoolManager, IProxyFactoryLike, IWithdrawalManagerQueue } from "../../../contracts/interfaces/Interfaces.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

// TODO: Consider adding AaveV3 and Sky modular strategies
contract PauseTests is TestBaseWithAssertions {

    address borrower          = makeAddr("borrower");
    address pausePoolDelegate = makeAddr("pausePoolDelegate");
    address defaultCaller     = makeAddr("DEFAULT_CALLER");

    address openTermLoan;
    address openTermLoanManager;

    /**************************************************************************************************************************************/
    /*** Functions Mappings (Need to be continuously updated with new functions)                                                        ***/
    /**************************************************************************************************************************************/

    bytes[] openTermLoanFunctions = [
        abi.encodeWithSignature("migrate(address,bytes)", address(0), new bytes(0)),
        abi.encodeWithSignature("setImplementation(address)", address(0)),
        abi.encodeWithSignature("upgrade(uint256,bytes)", 0, new bytes(0)),
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
        abi.encodeWithSignature("upgrade(uint256,bytes)", 0, new bytes(0)),
        abi.encodeWithSignature("proposeNewTerms(address,address,uint256,bytes[])", address(0), address(0), 0, new bytes[](0)),
        abi.encodeWithSignature("rejectNewTerms(address,address,uint256,bytes[])", address(0), address(0), 0, new bytes[](0)),
        abi.encodeWithSignature("claim(int256,uint256,uint256,uint256,uint40)", int256(0), 0, 0, 0, 0),
        abi.encodeWithSignature("callPrincipal(address,uint256)", address(0), 0),
        abi.encodeWithSignature("removeCall(address)", address(0)),
        abi.encodeWithSignature("impairLoan(address)", address(0)),
        abi.encodeWithSignature("removeLoanImpairment(address)", address(0)),
        abi.encodeWithSignature("triggerDefault(address,address)", address(0), address(0)),
        abi.encodeWithSignature("triggerDefault(address)", address(0))
    ];

    bytes[] poolFunctions = [
        abi.encodeWithSignature("deposit(uint256,address)", 0, address(0)),
        abi.encodeWithSignature(
            "depositWithPermit(uint256,address,uint256,uint8,bytes32,bytes32)", 0, address(0), 0, 0, bytes32(0), bytes32(0)
        ),
        abi.encodeWithSignature(
            "mintWithPermit(uint256,address,uint256,uint256,uint8,bytes32,bytes32)", 0, address(0), 0, 0, 0, bytes32(0), bytes32(0)
        ),
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
        abi.encodeWithSignature("addStrategy(address,bytes32,bytes)", address(0), bytes32(0), new bytes(0)),
        abi.encodeWithSignature("addStrategyManager(address)", address(0)),
        abi.encodeWithSignature("removeStrategyManager(address)", address(0)),
        abi.encodeWithSignature("setDelegateManagementFeeRate(uint256)", 0),
        abi.encodeWithSignature("setStrategyCap(address,uint256)", address(0), 0),
        abi.encodeWithSignature("setLiquidityCap(uint256)", 0),
        abi.encodeWithSignature("setWithdrawalManager(address)", address(0)),
        abi.encodeWithSignature("setPoolPermissionManager(address)", address(0)),
        abi.encodeWithSignature("requestFunds(address,uint256)", address(0), 0),
        abi.encodeWithSignature("triggerDefault(address)", address(0)),
        abi.encodeWithSignature("processRedeem(uint256,address,address)", 0, address(0), address(0)),
        abi.encodeWithSignature("processWithdraw(uint256,address,address)", 0, address(0), address(0)),
        abi.encodeWithSignature("removeShares(uint256,address)", 0, address(0)),
        abi.encodeWithSignature("requestRedeem(uint256,address,address)", 0, address(0), address(0)),
        abi.encodeWithSignature("requestWithdraw(uint256,uint256,address,address)", 0, 0, address(0), address(0))
    ];

    bytes[] proxyFactoryFunctions = [
        abi.encodeWithSignature("createInstance(bytes,bytes32)", new bytes(0), ""),
        abi.encodeWithSignature("upgradeInstance(uint256,bytes)", 0, new bytes(0))
    ];

    // Withdrawal Manager functions
    bytes[] withdrawalManagerQueueFunctions = [
        // Proxy functions
        abi.encodeWithSignature("migrate(address,bytes)", address(0), new bytes(0)),
        abi.encodeWithSignature("setImplementation(address)", address(0)),
        abi.encodeWithSignature("upgrade(uint256,bytes)", 0, new bytes(0)),
        abi.encodeWithSignature("setManualWithdrawal(address,bool)", address(0), false),
        abi.encodeWithSignature("removeRequest(address,uint256[])", address(0), new uint256[](0)),
        abi.encodeWithSignature("processRedemptions(uint256)", 0),
        abi.encodeWithSignature("processEmptyRedemptions(uint256)", 0),
        abi.encodeWithSignature("removeSharesById(uint256,uint256)", 0, 0)
    ];

    bytes[] poolPermissionManagerFunctions = [
        abi.encodeWithSignature("setLenderBitmaps(address[],uint256[])", new address[](0), new uint256[](0)),
        abi.encodeWithSignature("setPermissionAdmin(address,bool)", address(0), false),
        abi.encodeWithSignature("configurePool(address,uint256,bytes32[],uint256[])", address(0), 0, new bytes32[](0), new uint256[](0)),
        abi.encodeWithSignature("setLenderAllowlist(address,address[],bool[])", address(0), new address[](0), new bool[](0)),
        abi.encodeWithSignature("setPoolBitmaps(address,bytes32[],uint256[])", address(0), new bytes32[](0), new uint256[](0)),
        abi.encodeWithSignature("setPoolPermissionLevel(address,uint256)", address(0), 0)
    ];

    bytes[] strategyManagerFunctions = [
        abi.encodeWithSignature("migrate(address,bytes)", address(0), new bytes(0)),
        abi.encodeWithSignature("setImplementation(address)", address(0)),
        abi.encodeWithSignature("upgrade(uint256,bytes)", 0, new bytes(0)),
        abi.encodeWithSignature("completeConfiguration(uint256,bytes)", 0, new bytes(0)),
        abi.encodeWithSignature("setUnderlyingStrategy(address)", address(0)),
        abi.encodeWithSignature("setActive(bool)", false),
        abi.encodeWithSignature("acceptStrategyDelegate()"),
        abi.encodeWithSignature("setPendingStrategyDelegate(address)", address(0)),
        abi.encodeWithSignature("cancelRedemption(address,uint256)", address(0), 0),
        abi.encodeWithSignature("fundStrategyManager(address,uint256,bytes)", address(0), 0, new bytes(0)),
        abi.encodeWithSignature("processRedemption(address,uint256,bytes)", address(0), 0, new bytes(0)),
        abi.encodeWithSignature("requestRedeem(address,uint256)", address(0), 0),
        abi.encodeWithSignature("setPoolManagerCap(address,uint256)", address(0), 0),
        abi.encodeWithSignature("setStrategyLiquidityCap(uint256)", 0)
    ];

    bytes[] allocationStrategyFunctions = [
        abi.encodeWithSignature("migrate(address,bytes)", address(0), new bytes(0)),
        abi.encodeWithSignature("setImplementation(address)", address(0)),
        abi.encodeWithSignature("upgrade(uint256,bytes)", 0, new bytes(0)),
        abi.encodeWithSignature("deployAssets(uint256,bytes)", 0, new bytes(0)),
        abi.encodeWithSignature("returnAssets(uint256,address,bytes)", 0, address(0), new bytes(0)),
        abi.encodeWithSignature("realizeYield(uint256,uint32,bytes)", 0, 0, new bytes(0)),
        abi.encodeWithSignature("cancelYield(uint256,address)", 0, address(0)),
        abi.encodeWithSignature("impair(uint256)", 0),
        abi.encodeWithSignature("removeImpairment(uint256)", 0),
        abi.encodeWithSignature("recognizeLoss(uint256,address)", 0, address(0)),
        abi.encodeWithSignature("setDeploymentCaps(address[],uint256[])", new address[](0), new uint256[](0)),
        abi.encodeWithSignature("setMetadata(string)", ""),
        abi.encodeWithSignature(
            "setPermissions(address[],bool[],bool[],bool[])", new address[](0), new bool[](0), new bool[](0), new bool[](0)
        ),
        abi.encodeWithSignature("setStrategyDelegateFeeRate(uint32)", 0),
        abi.encodeWithSignature("setStrategyProtocolFeeRate(uint32)", 0),
        abi.encodeWithSignature("fundUnderlyingStrategy(uint256,bytes)", 0, new bytes(0)),
        abi.encodeWithSignature("withdrawFromUnderlyingStrategy(address,uint256,bytes)", address(0), 0, new bytes(0))
    ];

    address[] contracts;

    mapping(address => bytes[]) functions;
    mapping(address => string) messages;
    mapping(address => address) caller;
    // Optional per-function caller override (e.g., functions with different ACL on same contract)
    mapping(address => mapping(bytes4 => address)) functionCallerOverride;

    function setUp() public override {
        super.setUp();
        deposit(makeAddr("depositor"), 3_500_000e6);

        openTermLoanManager = poolManager.strategyList(0);

        openTermLoan = createOpenTermLoan(
            address(borrower),
            address(openTermLoanManager),
            address(fundsAsset),
            1_000_000e6,
            [uint32(2 days), 3 days, 30 days],
            [uint64(0.015768e6), 0.31536e6, 0.01e6, 0.015768e6]
        );

        vm.prank(governor);
        globals.setValidPoolDelegate(address(pausePoolDelegate), true);

        (address pwqPool, address pwqPoolManager, address pwqWithdrawalManager) = _createPoolWithOTLM(pausePoolDelegate);

        // Use the "pool with queue" as the active pool.
        poolManager = IPoolManager(pwqPoolManager);
        pool        = IPool(pwqPool);
        queueWM     = IWithdrawalManagerQueue(pwqWithdrawalManager);

        (allocationStrategyManager, allocationUnderlyingStrategy) = _deployAllocationStrategy({
            strategyDelegate_:        strategyDelegate,
            fundsAsset_:              address(fundsAsset),
            strategyDelegateFeeRate_: 0,
            strategyProtocolFeeRate_: 0,
            strategyLiquidityCap_:    0,
            bootstrapMint_:           0
        });

        addStrategyManagerToPool(address(poolManager), allocationStrategyManager);

        // Set up all mappings
        functions[poolManagerFactory]         = proxyFactoryFunctions;
        functions[openTermLoanFactory]        = proxyFactoryFunctions;
        functions[openTermLoanManagerFactory] = proxyFactoryFunctions;
        functions[queueWMFactory]             = proxyFactoryFunctions;
        functions[openTermLoan]               = openTermLoanFunctions;
        functions[openTermLoanManager]        = openTermLoanManagerFunctions;
        functions[address(pool)] = poolFunctions;
        functions[address(poolManager)] = poolManagerFunctions;
        functions[address(queueWM)] = withdrawalManagerQueueFunctions;
        functions[address(poolPermissionManager)] = poolPermissionManagerFunctions;
        functions[allocationStrategyManager]    = strategyManagerFunctions;
        functions[allocationUnderlyingStrategy] = allocationStrategyFunctions;

        messages[poolManagerFactory]         = "MPF:PROTOCOL_PAUSED";
        messages[openTermLoanFactory]        = "MPF:PROTOCOL_PAUSED";
        messages[openTermLoanManagerFactory] = "MPF:PROTOCOL_PAUSED";
        messages[openTermLoan]               = "ML:PAUSED";
        messages[openTermLoanManager]        = "LM:PAUSED";
        messages[address(pool)] = "PM:CC:PAUSED";
        messages[address(poolManager)] = "PM:PAUSED";
        messages[address(queueWM)] = "WM:PAUSED";
        messages[queueWMFactory] = "MPF:PROTOCOL_PAUSED";
        messages[address(poolPermissionManager)] = "PPM:PAUSED";
        messages[allocationStrategyManager]    = "MSM:PAUSED";
        messages[allocationUnderlyingStrategy] = "MAS:PAUSED";

        // Caller overrides for factories where the implementation expects a specific contract context.
        caller[poolManagerFactory]         = address(poolDeployer);
        caller[openTermLoanManagerFactory] = address(poolManager);
        caller[openTermLoanFactory]        = address(borrower);
        caller[queueWMFactory]             = address(poolDeployer);

        bytes4 upgradeSelector                                              = bytes4(keccak256("upgradeInstance(uint256,bytes)"));
        functionCallerOverride[poolManagerFactory][upgradeSelector]         = address(poolManager);
        functionCallerOverride[openTermLoanFactory][upgradeSelector]        = address(openTermLoan);
        functionCallerOverride[openTermLoanManagerFactory][upgradeSelector] = address(openTermLoanManager);
        functionCallerOverride[queueWMFactory][upgradeSelector]             = address(queueWM);

        // Ensure factory ACL checks pass before pause checks in tests.
        vm.startPrank(governor);
        globals.setCanDeployFrom(openTermLoanFactory, borrower, true);
        globals.setCanDeployFrom(openTermLoanManagerFactory, address(poolManager), true);
        vm.stopPrank();
    }

    function test_globalPause() external {
        // All contracts are affected by the global pause
        contracts = [
            address(poolManagerFactory),
            address(openTermLoanFactory),
            address(openTermLoanManagerFactory),
            address(openTermLoan),
            address(openTermLoanManager),
            address(pool),
            address(poolManager),
            address(queueWMFactory),
            address(queueWM),
            address(poolPermissionManager),
            allocationStrategyManager,
            allocationUnderlyingStrategy
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
            address(openTermLoan),
            address(openTermLoanManager),
            address(poolManager),
            address(queueWM),
            address(poolPermissionManager),
            allocationStrategyManager,
            allocationUnderlyingStrategy
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
            address(openTermLoan),
            address(openTermLoanManager),
            address(poolManager),
            address(queueWM),
            address(poolPermissionManager),
            allocationStrategyManager,
            allocationUnderlyingStrategy
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
        contracts = [address(openTermLoan), address(openTermLoanManager), address(poolManager)];

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

    function test_poolManager_canCall_protocolPause() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        (bool canCall_, string memory err_) =
            poolManager.canCall(bytes32("P:transfer"), address(this), abi.encode(address(this), uint256(1)));

        assertTrue(!canCall_);
        assertEq(err_, "PM:CC:PAUSED");

        vm.prank(governor);
        globals.setProtocolPause(false);

        (canCall_, err_) = poolManager.canCall(bytes32("P:transfer"), address(this), abi.encode(address(this), uint256(1)));

        assertTrue(keccak256(bytes(err_)) != keccak256(bytes("PM:CC:PAUSED")));
    }

    function test_poolManager_canCall_contractPause() external {
        vm.prank(governor);
        globals.setContractPause(address(poolManager), true);

        (bool canCall_, string memory err_) =
            poolManager.canCall(bytes32("P:transfer"), address(this), abi.encode(address(this), uint256(1)));

        assertTrue(!canCall_);
        assertEq(err_, "PM:CC:PAUSED");

        vm.prank(governor);
        globals.setContractPause(address(poolManager), false);

        (canCall_, err_) = poolManager.canCall(bytes32("P:transfer"), address(this), abi.encode(address(this), uint256(1)));

        assertTrue(keccak256(bytes(err_)) != keccak256(bytes("PM:CC:PAUSED")));
    }

    function test_poolManager_canCall_functionUnpauseAfterProtocolPause() external {
        vm.prank(governor);
        globals.setProtocolPause(true);

        vm.prank(governor);
        globals.setFunctionUnpause(address(poolManager), bytes4(keccak256("canCall(bytes32,address,bytes)")), true);

        (bool canCall_, string memory err_) =
            poolManager.canCall(bytes32("P:transfer"), address(this), abi.encode(address(this), uint256(1)));

        assertTrue(keccak256(bytes(err_)) != keccak256(bytes("PM:CC:PAUSED")));

        vm.prank(governor);
        globals.setFunctionUnpause(address(poolManager), bytes4(keccak256("canCall(bytes32,address,bytes)")), false);

        (canCall_, err_) = poolManager.canCall(bytes32("P:transfer"), address(this), abi.encode(address(this), uint256(1)));

        assertTrue(!canCall_);
        assertEq(err_, "PM:CC:PAUSED");
    }

    /**************************************************************************************************************************************/
    /*** Helpers                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function _assertAllPaused(address contract_, bytes[] memory calldataArray_, string memory message_) internal {
        for (uint256 i = 0; i < calldataArray_.length; i++) {
            bytes4  sig  = bytes4(calldataArray_[i]);
            address from = caller[contract_];
            if (from == address(0)) from = defaultCaller;
            // Apply per-function caller override if present.
            address specificCaller = functionCallerOverride[contract_][sig];
            if (specificCaller != address(0)) from = specificCaller;
            vm.prank(from);
            _assertFunctionIsPaused(contract_, calldataArray_[i], message_);
        }
    }

    function _assertNonePaused(address contract_, bytes[] memory calldataArray_, string memory message_) internal {
        for (uint256 i = 0; i < calldataArray_.length; i++) {
            bytes4  sig  = bytes4(calldataArray_[i]);
            address from = caller[contract_];
            if (from == address(0)) from = defaultCaller;
            // Apply per-function caller override if present.
            address specificCaller = functionCallerOverride[contract_][sig];
            if (specificCaller != address(0)) from = specificCaller;
            vm.prank(from);
            _assertFunctionIsNotPaused(contract_, calldataArray_[i], message_);
        }
    }

    function _assertFunctionIsPaused(address contract_, bytes memory data, string memory message_) internal {
        (bool success, bytes memory returnData) = contract_.call(data);
        assertTrue(!success);

        // If there's no revert data then it wasn't paused.
        if (success || returnData.length <= 4) revert("No revert data. Not Paused");

        bytes4 selector;
        assembly {
            selector := mload(add(returnData, 32))
        }

        // 0x08c379a0 selector means the return data is a revert with a string.
        // If its a different selector then its a custom error or panic.
        if (selector != 0x08c379a0) revert("Custom Error. Not Paused");

        string memory returnedMessage = abi.decode(slice(returnData, 4, returnData.length - 4), (string));
        assertEq(returnedMessage, message_, "Wrong message. Not Paused."); // If the call reverted with a different error, then it's not
        // paused.
    }

    function _assertFunctionIsNotPaused(address contract_, bytes memory data, string memory message_) internal {
        (bool success, bytes memory returnData) = contract_.call(data);

        // The call didn't revert (or reverted without a message/only selector), so it's not paused.
        if (success || returnData.length <= 4) return;

        bytes4 selector;
        assembly {
            selector := mload(add(returnData, 32))
        }

        // 0x08c379a0 selector means the return data is a revert with a string.
        // If its a different selector then its a custom error or panic.
        if (selector != 0x08c379a0) return;

        string memory returnedMessage = abi.decode(slice(returnData, 4, returnData.length - 4), (string));
        assertTrue(keccak256(abi.encode(returnedMessage)) != keccak256(abi.encode(message_)), "Not paused message hash");
    }

    function slice(bytes memory _bytes, uint256 _start, uint256 _length) internal pure returns (bytes memory result_) {
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

        // NOTE: Can probably use `result_` in the above assembly instead.
        result_ = tempBytes;
    }

}
