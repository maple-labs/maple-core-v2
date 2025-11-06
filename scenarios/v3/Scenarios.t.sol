// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { IERC20, IBitcoinStrategy }           from "../../contracts/interfaces/Interfaces.sol";

import { console, stdJson, stdMath } from "../../modules/forge-std/src/Test.sol";

import { SyrupBitcoinTestBase } from "../../tests/integration/syrup-btc/SyrupBitcoinTestBase.sol";

contract Scenario is SyrupBitcoinTestBase {

    using stdJson for string;

    struct CreatePoolParameters {
        string  asset;
        string  name;
        uint256 strategyFeeRate_A;
        uint256 strategyFeeRate_B;
    }

    struct DepositParameters {
        uint256 assets;
        string  name;
    }

    struct DeployParameters {
        uint256 assets;
        string  name;
    }

    struct PassTimeParameters {
        uint256 seconds_;
    }

    struct ScheduleParameters {
        uint32  deadline;
        string  name;
        uint256 yield;
    }

    struct RequestRedeemParameters {
        string  name;
        uint256 shares;
    }

    struct ReconcileParameters {
        uint256 assets;
        string  name;
    }

    uint256 constant ACCEPTABLE_DELTA = 4; 

    mapping(string => address) private strategyByName;

    uint256 private previousTimestamp;

    string private activeScenarioJson;

    function setUp() public virtual override {
        super.setUp();
        previousTimestamp = block.timestamp;
    }

    function test_sim() external {
        // This is the entry point for running a scenario.
        // Set the SCENARIO environment variable to the filename you want to run. The filename should be without the extension. 
        runScenario(vm.envString("SCENARIO"));
    }

    function runScenario(string memory scenarioId_) internal {
        console.log("\nScenario", scenarioId_, "\n");

        string memory json = vm.readFile(concat(vm.projectRoot(), "/scenarios/v3/data/json/", scenarioId_, ".json"));

        activeScenarioJson = json;

        uint256 actionsLength = getActionsLength(json);

        for (uint256 i; i < actionsLength; ++i) {
            console.log("Action", i);

            uint256 targetTimestamp = json.readUint(concat(".actions[", vm.toString(i), "].timestamp"));

            require(targetTimestamp >= previousTimestamp, "NON_SEQUENTIAL_TIMESTAMP");

            vm.warp(targetTimestamp);

            console.log("  timestamp:", block.timestamp);

            function(bytes memory) internal handler = getHandler(
                json,
                concat(".actions[", vm.toString(i), "]")
            );

            handler(
                json.parseRaw(concat(".actions[", vm.toString(i), "].parameters"))
            );

            // Header before the assertion logs below.
            console.log("  assertions:");

            bool failure = checkExpected(json, i);

            if (failure) {
                console.log("    STOPPING DUE TO CHECK FAILURE");
                fail();
            }

            console.log("");

            previousTimestamp = targetTimestamp;
        }
    }

    function getHandler(
        string memory json_, 
        string memory actionKey_
    ) 
        internal pure returns (function(bytes memory) internal) 
    {
        bytes32 actionType = bytes32(bytes(json_.readString(concat(actionKey_, ".actionType"))));

        console.log("  action:", json_.readString(concat(actionKey_, ".actionType")));

        if (actionType == "createPool")    return handleCreatePool;
        if (actionType == "deposit")       return handleDeposit;
        if (actionType == "deploy")        return handleDeploy;
        if (actionType == "schedule")      return handleSchedule;
        if (actionType == "passTime")      return handlePassTime;
        if (actionType == "requestRedeem") return handleRequestRedeem;
        if (actionType == "reconcile")     return handleReconcile;
        if (actionType == "impair")        return handleImpair;
        if (actionType == "default")       return handleDefault;

        revert("INVALID_ACTION_TYPE");
    }

    function handleCreatePool(bytes memory rawParameters_) internal {
        // The pool is already created by our test base, we are just setting the appropriate fees here.
        CreatePoolParameters memory parameters = abi.decode(rawParameters_, (CreatePoolParameters));

        strategyByName["strategyA"] = poolManager.strategyList(0);
        strategyByName["strategyB"] = poolManager.strategyList(1);

        address poolDelegate = poolManager.poolDelegate();
        address strategyA    = strategyByName["strategyA"];
        address strategyB    = strategyByName["strategyB"];

        bool isMulti = isMultiStrategyAction();

        console.log("  parameters:");
        console.log("    asset:",             parameters.asset);
        console.log("    name:",              parameters.name);
        console.log("    strategyFeeRate_A:", parameters.strategyFeeRate_A);

        if (isMulti) {
            console.log("    strategyFeeRate_B:", parameters.strategyFeeRate_B);
        }

        if (strategyA != address(0)) {
            vm.prank(poolDelegate);
            IBitcoinStrategy(strategyA).setFeeRate(parameters.strategyFeeRate_A);
        }

        if (isMulti && strategyB != address(0)) {
            vm.prank(poolDelegate);
            IBitcoinStrategy(strategyB).setFeeRate(parameters.strategyFeeRate_B);
        }

        vm.prank(governor);
        bitcoinRouter.setFees(address(depositAsset), 0, 0);
    }

    function handleDeposit(bytes memory rawParameters_) internal {
        DepositParameters memory parameters = abi.decode(rawParameters_, (DepositParameters));

        console.log("  parameters:");
        console.log("    name:",   parameters.name);
        console.log("    assets:", parameters.assets);

        address lender = makeAddr(parameters.name);

        depositAsset.mint(lender, parameters.assets);

        vm.startPrank(lender);
        depositAsset.approve(address(bitcoinRouter), parameters.assets);
        bitcoinRouter.deposit(address(depositAsset), parameters.assets, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();
    }

    function handleDeploy(bytes memory rawParameters_) internal {
        DeployParameters memory parameters = abi.decode(rawParameters_, (DeployParameters));

        console.log("  parameters:");
        console.log("    name:",   parameters.name);
        console.log("    assets:", parameters.assets);

        address strategyAddress = getStrategy(parameters.name);

        vm.prank(strategyManager);
        IBitcoinStrategy(strategyAddress).deploy(address(depositAsset), parameters.assets);
    }

    function handleSchedule(bytes memory rawParameters_) internal {
        ScheduleParameters memory parameters = abi.decode(rawParameters_, (ScheduleParameters));

        console.log("  parameters:");
        console.log("    name:",     parameters.name);
        console.log("    yield:",    parameters.yield);
        console.log("    deadline:", parameters.deadline);

        address strategyAddress = getStrategy(parameters.name);

        uint32 deadline = parameters.deadline == 0
            ? uint32(block.timestamp)
            : uint32(block.timestamp + parameters.deadline);

        vm.prank(strategyManager);
        IBitcoinStrategy(strategyAddress).schedule(parameters.yield, deadline);
    }

    function handlePassTime(bytes memory rawParameters_) internal view {
        // This function just asserts that the expected seconds_ value has passed.
        // We are warping on the timestamp value in the runScenario loop.
        PassTimeParameters memory parameters = abi.decode(rawParameters_, (PassTimeParameters));

        console.log("  parameters:");
        console.log("    seconds:", parameters.seconds_);

        require(parameters.seconds_ == block.timestamp - previousTimestamp, "UNEXPECTED_PASSTIME_DELTA");
    }

    function handleRequestRedeem(bytes memory rawParameters_) internal {
        RequestRedeemParameters memory parameters = abi.decode(rawParameters_, (RequestRedeemParameters));

        console.log("  parameters:");
        console.log("    name:",   parameters.name);
        console.log("    shares:", parameters.shares);

        address lender = makeAddr(parameters.name);

        vm.startPrank(lender);
        IERC20(address(pool)).approve(address(bitcoinRouter), parameters.shares);
        bitcoinRouter.requestRedeem(address(depositAsset), parameters.shares, EMPTY_METADATA, emptyPermit());
        vm.stopPrank();
    }

    function handleReconcile(bytes memory rawParameters_) internal {
        ReconcileParameters memory parameters = abi.decode(rawParameters_, (ReconcileParameters));

        console.log("  parameters:");
        console.log("    name:",   parameters.name);
        console.log("    assets:", parameters.assets);

        address strategyAddress = getStrategy(parameters.name);

        vm.startPrank(strategyManager);
        depositAsset.approve(strategyAddress, parameters.assets);
        IBitcoinStrategy(strategyAddress).reconcile(address(depositAsset), parameters.assets);
        vm.stopPrank();
    }

    function handleImpair(bytes memory rawParameters_) internal {
        ReconcileParameters memory parameters = abi.decode(rawParameters_, (ReconcileParameters));

        console.log("  parameters:");
        console.log("    name:",   parameters.name);
        console.log("    assets:", parameters.assets);

        address strategyAddress = getStrategy(parameters.name);

        address poolDelegate = poolManager.poolDelegate();

        vm.prank(poolDelegate);
        IBitcoinStrategy(strategyAddress).setImpairment(parameters.assets);
    }

    function handleDefault(bytes memory rawParameters_) internal {
        ReconcileParameters memory parameters = abi.decode(rawParameters_, (ReconcileParameters));

        console.log("  parameters:");
        console.log("    name:",   parameters.name);
        console.log("    assets:", parameters.assets);

        address strategyAddress = getStrategy(parameters.name);

        address poolDelegate = poolManager.poolDelegate();

        vm.prank(poolDelegate);
        IBitcoinStrategy(strategyAddress).setDefault(parameters.assets);
    }

    function getActionsLength(string memory json_) internal view returns (uint256 length) {
        while (vm.keyExists(json_, concat(".actions[", vm.toString(length), "]"))) {
            unchecked { ++length; }
        }
    }

    function checkExpected(string memory json_, uint256 index_) internal view returns (bool failure) {
        string memory basePath = string(abi.encodePacked(".actions[", vm.toString(index_), "].expected"));

        string memory systemAumPath = string(abi.encodePacked(basePath, ".system.aum"));

        if (vm.keyExists(json_, systemAumPath)) {
            uint256 expectedAum = json_.readUint(systemAumPath);
            uint256 actualAum   = poolManager.totalAssets();

            logComparisonData("system", "aum", expectedAum, actualAum);

            if (stdMath.delta(expectedAum, actualAum) > ACCEPTABLE_DELTA) {
                failure = true;
            }
        }

        if (vm.keyExists(json_, string(abi.encodePacked(basePath, ".strategies.strategyA")))) {
            if (checkStrategy(json_, basePath, "strategyA")) failure = true;
        }

        if (vm.keyExists(json_, string(abi.encodePacked(basePath, ".strategies.strategyB")))) {
            if (checkStrategy(json_, basePath, "strategyB")) failure = true;
        }

        return failure;
    }

    function checkStrategy(string memory json_, string memory basePath_, string memory name_) internal view returns (bool failure) {
        address strategyAddress = strategyByName[name_];

        if (strategyAddress == address(0)) {
            console.log("    unknown strategy", name_);
            return true;
        }

        string memory prefix = string(abi.encodePacked(basePath_, ".strategies.", name_));

        IBitcoinStrategy strategy = IBitcoinStrategy(strategyAddress);

        string memory realizedFeesPath = string(abi.encodePacked(prefix, ".realizedFees"));

        if (vm.keyExists(json_, realizedFeesPath)) {
            uint256 expected = json_.readUint(realizedFeesPath);
            uint256 actual   = strategy.realizedFees();

            logComparisonData(name_, "realizedFees", expected, actual);

            if (stdMath.delta(expected, actual) > ACCEPTABLE_DELTA) {
                return true;
            }
        }

        string memory accruedYieldPath = string(abi.encodePacked(prefix, ".accruedYield"));

        if (vm.keyExists(json_, accruedYieldPath)) {
            uint256 expected = json_.readUint(accruedYieldPath);
            uint256 actual   = strategy.accruedYield();

            logComparisonData(name_, "accruedYield", expected, actual);

            if (stdMath.delta(expected, actual) > ACCEPTABLE_DELTA) {
                return true;
            }
        }

        string memory accruedFeesPath = string(abi.encodePacked(prefix, ".accruedFees"));

        if (vm.keyExists(json_, accruedFeesPath)) {
            uint256 expected = json_.readUint(accruedFeesPath);
            uint256 actual   = strategy.accruedFees();

            logComparisonData(name_, "accruedFees", expected, actual);

            if (stdMath.delta(expected, actual) > ACCEPTABLE_DELTA) {
                return true;
            }
        }

        string memory aumPath = string(abi.encodePacked(prefix, ".aum"));

        if (vm.keyExists(json_, aumPath)) {
            uint256 expected = json_.readUint(aumPath);
            uint256 actual   = strategy.assetsUnderManagement();

            logComparisonData(name_, "aum", expected, actual);

            if (stdMath.delta(expected, actual) > ACCEPTABLE_DELTA) {
                return true;
            }
        }

        string memory outstandingPath = string(abi.encodePacked(prefix, ".outstanding"));

        if (vm.keyExists(json_, outstandingPath)) {
            uint256 expected = json_.readUint(outstandingPath);
            uint256 actual   = strategy.outstandingAssets();

            logComparisonData(name_, "outstanding", expected, actual);

            if (stdMath.delta(expected, actual) > ACCEPTABLE_DELTA) {
                return true;
            }
        }

        return false;
    }

    function getStrategy(string memory name_) internal view returns (address strategyAddress) {
        strategyAddress = strategyByName[name_];
        require(strategyAddress != address(0), "UNKNOWN_STRATEGY");
    }

    function isMultiStrategyAction() internal view returns (bool) {
        string memory strategiesPath = ".actions[0].expected.strategies";

        if (!vm.keyExists(activeScenarioJson, strategiesPath)) return false;

        return vm.keyExists(activeScenarioJson, ".actions[0].expected.strategies.strategyB");
    }

    function concat(string memory a_, string memory b_) internal pure returns (string memory output_) {
        output_ = string(abi.encodePacked(a_, b_));
    }

    function concat(string memory a_, string memory b_, string memory c_) internal pure returns (string memory output_) {
        output_ = string(abi.encodePacked(a_, b_, c_));
    }

    function concat(string memory a_, string memory b_, string memory c_, string memory d_) internal pure returns (string memory output_) {
        output_ = string(abi.encodePacked(a_, b_, c_, d_));
    }

    function logComparisonData(
        string memory name_,
        string memory field_,
        uint256 expected_,
        uint256 actual_
    )
        internal pure
    {
        uint256 COL_WIDTH = 30;

        uint256 delta = stdMath.delta(expected_, actual_);

        string memory label         = string(abi.encodePacked(name_, ".", field_));
        string memory expectedString = string(abi.encodePacked("expected: ", vm.toString(expected_)));
        string memory actualString   = string(abi.encodePacked("actual: ",   vm.toString(actual_)));
        string memory deltaString    = string(abi.encodePacked("delta: ",    vm.toString(delta)));

        string memory line = string(
            abi.encodePacked(
                "    ", padRight(label,         COL_WIDTH),
                " ",    padRight(expectedString, COL_WIDTH),
                " ",    padRight(actualString,   COL_WIDTH),
                " ",    padRight(deltaString,    COL_WIDTH)
            )
        );

        console.log(line);
    }

    function padRight(string memory string_, uint256 width_) internal pure returns (string memory formattedString) {
        bytes memory stringBytes = bytes(string_);

        if (stringBytes.length >= width_)
            return string_;

        uint256 pad = width_ - stringBytes.length;
        bytes memory spaces = new bytes(pad);
        bytes1 space = bytes(" ")[0];

        for (uint256 i; i < pad; ++i) {
            spaces[i] = space;
        }

        formattedString = string(abi.encodePacked(string_, spaces));
    }

}
