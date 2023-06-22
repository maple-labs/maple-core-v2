// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { ILoanLike, ILoanManagerLike } from "../contracts/interfaces/Interfaces.sol";

import { console2 as console, stdJson, stdMath, StdStyle } from "../contracts/Contracts.sol";

import { TestBase } from "../tests/TestBase.sol";

// NOTE: All Converting basis points into basis points scaled by 100.

// TODO: Add color logging (eg. `console.log(StdStyle.red("Red Bold String"), StdStyle.blue("Blue Bold String"));`).

contract Scenario is TestBase {

    // TODO: Withdraw.

    struct CreatePoolParameters {
        string  asset;
        uint256 delegateManagementFeeRate;
        uint256 liquidityCap;
        string  name;
        uint256 platformManagementFeeRate;
        uint256 platformOriginationFeeRate;
        uint256 platformServiceFeeRate;
    }

    struct DepositParameters {
        uint256 assets;
        string  name;
    }

    struct FundFixedTermLoanParameters {
        uint256 closingFeeRate;
        uint256 collateral;
        uint256 delegateOriginationFee;
        uint256 delegateServiceFee;
        uint256 endingPrincipal;
        uint256 gracePeriod;
        uint256 interestRate;
        bool    isOpenTerm;
        uint256 lateFeeRate;
        uint256 lateInterestPremiumRate;
        string  name;
        uint256 paymentInterval;
        uint256 payments;
        uint256 principal;
    }

    struct FundOpenTermLoanParameters {
        uint256 delegateServiceFeeRate;
        uint256 gracePeriod;
        uint256 interestRate;
        bool    isOpenTerm;
        uint256 lateFeeRate;
        uint256 lateInterestPremiumRate;
        string  name;
        uint256 noticePeriod;
        uint256 paymentInterval;
        uint256 principal;
    }

    struct PayLoanParameters {
        uint256 delegateManagementFee;
        uint256 delegateServiceFee;
        uint256 interest;
        string  name;
        uint256 platformManagementFee;
        uint256 platformServiceFee;
        uint256 principal;
    }

    struct CallOpenTermLoanParameters {
        string  name;
        uint256 principal;
    }

    struct UncallOpenTermLoanParameters {
        string  name;
    }

    struct ImpairLoanParameters {
        string name;
    }

    struct UnimpairLoanParameters {
        string name;
    }

    struct RefinanceLoanParameters {
        string    name;
        string[]  terms;
        uint256[] values;
    }

    struct DefaultLoanParameters {
        uint256 interest;
        string  name;
        uint256 platformManagementFee;
        uint256 platformServiceFee;
        uint256 poolLosses;
        uint256 principal;
    }

    struct ExpectedValues {
        uint256 accruedInterest;
        uint256 cash;
        uint256 principalOutstanding;
        uint256 totalAssets;
        uint256 totalSupply;
        uint256 unrealizedLosses;
    }

    mapping(string => address) loanNamed;
    mapping(string => address) poolNamed;

    mapping(string => bool) isLoanOpenTerm;

    using stdJson for string;

    function concat(string memory a_, string memory b_) internal pure returns (string memory output_) {
        output_ = string(abi.encodePacked(a_, b_));
    }

    function concat(string memory a_, string memory b_, string memory c_) internal pure returns (string memory output_) {
        output_ = string(abi.encodePacked(a_, b_, c_));
    }

    function concat(string memory a_, string memory b_, string memory c_, string memory d_) internal pure returns (string memory output_) {
        output_ = string(abi.encodePacked(a_, b_, c_, d_));
    }

    function toString(uint256 i_) internal pure returns (string memory output_) {
        output_ = vm.toString(i_);
    }

    function handleCreatePool(bytes memory rawParameters_) internal returns (bool failure_) {
        CreatePoolParameters memory parameters = abi.decode(rawParameters_, (CreatePoolParameters));

        // TODO: For now, ignoring name, asset, capacity

        _createAndConfigurePool(1, 1);
        openPool(address(poolManager));

        setupFees({
            platformOriginationFeeRate: parameters.platformOriginationFeeRate * 100,
            platformServiceFeeRate:     parameters.platformServiceFeeRate * 100,
            platformManagementFeeRate:  parameters.platformManagementFeeRate * 100,
            delegateOriginationFee:     0,
            delegateServiceFee:         0,
            delegateManagementFeeRate:  parameters.delegateManagementFeeRate * 100
        });
    }

    function handleDeposit(bytes memory rawParameters_) internal returns (bool failure_) {
        DepositParameters memory parameters = abi.decode(rawParameters_, (DepositParameters));

        deposit(address(pool), makeAddr(parameters.name), parameters.assets);
    }

    function handleFundFixedTermLoan(bytes memory rawParameters_) internal returns (bool failure_) {
        FundFixedTermLoanParameters memory parameters = abi.decode(rawParameters_, (FundFixedTermLoanParameters));

        address loan = loanNamed[parameters.name] = createFixedTermLoan(
            makeAddr("borrower"),
            poolManager.loanManagerList(0),
            address(fixedTermFeeManager),
            [address(collateralAsset), address(fundsAsset)],
            [
                parameters.gracePeriod * 1 days,
                parameters.paymentInterval * 1 days,
                parameters.payments
            ],
            [
                parameters.collateral,
                parameters.principal,
                parameters.endingPrincipal
            ],
            [
                parameters.interestRate * 100,
                parameters.closingFeeRate * 100,
                parameters.lateFeeRate * 100,
                parameters.lateInterestPremiumRate * 100
            ],
            [
                parameters.delegateOriginationFee,
                parameters.delegateServiceFee
            ]
        );

        fundLoan(loan);
    }

    function handleFundOpenTermLoan(bytes memory rawParameters_) internal returns (bool failure_) {
        FundOpenTermLoanParameters memory parameters = abi.decode(rawParameters_, (FundOpenTermLoanParameters));

        address loan = loanNamed[parameters.name] = createOpenTermLoan(
            makeAddr("borrower"),
            poolManager.loanManagerList(1),
            address(fundsAsset),
            parameters.principal,
            [
                uint32(parameters.gracePeriod * 1 days),
                uint32(parameters.noticePeriod * 1 days),
                uint32(parameters.paymentInterval * 1 days)
            ],
            [
                uint64(parameters.delegateServiceFeeRate * 100),
                uint64(parameters.interestRate * 100),
                uint64(parameters.lateFeeRate * 100),
                uint64(parameters.lateInterestPremiumRate * 100)
            ]
        );

        isLoanOpenTerm[parameters.name] = true;

        fundLoan(loan);
    }

    function _makeFixedTermLoanPayment(PayLoanParameters memory parameters) internal returns (bool failure_) {
        ( uint256 principal_, uint256 interest_, uint256 fees_ ) = makePaymentFT(loanNamed[parameters.name]);

        uint256 expectedFees_ =
            parameters.delegateServiceFee +
            parameters.platformServiceFee +
            parameters.delegateManagementFee +
            parameters.platformManagementFee;

        if (stdMath.delta(principal_, parameters.principal) > 1) {
            console.log("    Expected principal is", toString(parameters.principal), "but actually is", toString(principal_));
            failure_ = true;
        }

        if (stdMath.delta(interest_, parameters.interest) > 3) {
            console.log("    Expected principal is", toString(parameters.interest), "but actually is", toString(interest_));
            failure_ = true;
        }

        if (stdMath.delta(fees_, expectedFees_) > 4) {
            console.log("    Expected fees is", toString(expectedFees_), "but actually is", toString(fees_));
            failure_ = true;
        }
    }

    function _makeOpenTermLoanPayment(PayLoanParameters memory parameters) internal returns (bool failure_) {
        (
            uint256 interest_,
            uint256 lateInterest_,
            uint256 delegateServiceFee_,
            uint256 platformServiceFee_
        ) = makePaymentOT(loanNamed[parameters.name], parameters.principal);

        if (stdMath.delta(interest_ + lateInterest_, parameters.interest) > 3) {
            console.log(
                "    Expected interest is",
                toString(parameters.interest),
                "but actually is",
                toString(interest_ + lateInterest_)
            );

            failure_ = true;
        }

        if (stdMath.delta(delegateServiceFee_, parameters.delegateServiceFee) > 1) {
            console.log(
                "    Expected delegateServiceFee is",
                toString(parameters.delegateServiceFee),
                "but actually is",
                toString(delegateServiceFee_)
            );

            failure_ = true;
        }

        if (stdMath.delta(platformServiceFee_, parameters.platformServiceFee) > 1) {
            console.log(
                "    Expected platformServiceFee is",
                toString(parameters.platformServiceFee),
                "but actually is",
                toString(platformServiceFee_)
            );

            failure_ = true;
        }
    }

    function handleLoanPayment(bytes memory rawParameters_) internal returns (bool failure_) {
        PayLoanParameters memory parameters = abi.decode(rawParameters_, (PayLoanParameters));

        uint256 poolBalance         = fundsAsset.balanceOf(poolManager.pool());
        uint256 poolDelegateBalance = fundsAsset.balanceOf(poolManager.poolDelegate());
        uint256 treasuryBalance     = fundsAsset.balanceOf(treasury);

        if (isLoanOpenTerm[parameters.name]) {
            _makeOpenTermLoanPayment(parameters);
        } else {
            _makeFixedTermLoanPayment(parameters);
        }

        uint256 delegateFees_ = parameters.delegateServiceFee + parameters.delegateManagementFee;
        uint256 platformFees_ = parameters.platformServiceFee + parameters.platformManagementFee;

        uint256 toPool_ =
            parameters.principal +
            parameters.interest -
            parameters.delegateManagementFee -
            parameters.platformManagementFee;

        if (stdMath.delta(fundsAsset.balanceOf(poolManager.pool()) - poolBalance, toPool_) > 6) {
            console.log(
                "    Expected toPool is",
                toString(toPool_),
                "but actually is",
                toString(fundsAsset.balanceOf(poolManager.pool()) - poolBalance)
            );

            failure_ = true;
        }

        if (stdMath.delta(fundsAsset.balanceOf(poolManager.poolDelegate()) - poolDelegateBalance, delegateFees_) > 3) {
            console.log(
                "    Expected delegateFees is",
                toString(delegateFees_),
                "but actually is",
                toString(fundsAsset.balanceOf(poolManager.poolDelegate()) - poolDelegateBalance)
            );

            failure_ = true;
        }

        if (stdMath.delta(fundsAsset.balanceOf(treasury) - treasuryBalance, platformFees_) > 2) {
            console.log(
                "    Expected platformFees is",
                toString(platformFees_),
                "but actually is",
                toString(fundsAsset.balanceOf(treasury) - treasuryBalance)
            );

            failure_ = true;
        }
    }

    function handleCallOpenTermLoan(bytes memory rawParameters_) internal returns (bool failure_) {
        CallOpenTermLoanParameters memory parameters = abi.decode(rawParameters_, (CallOpenTermLoanParameters));

        callLoan(loanNamed[parameters.name], parameters.principal);
    }

    function handleUncallOpenTermLoan(bytes memory rawParameters_) internal returns (bool failure_) {
        UncallOpenTermLoanParameters memory parameters = abi.decode(rawParameters_, (UncallOpenTermLoanParameters));

        removeLoanCall(loanNamed[parameters.name]);
    }

    function handleImpairLoan(bytes memory rawParameters_) internal returns (bool failure_) {
        ImpairLoanParameters memory parameters = abi.decode(rawParameters_, (ImpairLoanParameters));

        impairLoan(loanNamed[parameters.name]);
    }

    function handleUnimpairLoan(bytes memory rawParameters_) internal returns (bool failure_) {
        UnimpairLoanParameters memory parameters = abi.decode(rawParameters_, (UnimpairLoanParameters));

        removeLoanImpairment(loanNamed[parameters.name]);
    }

    function handleRefinanceLoan(bytes memory rawParameters_) internal returns (bool failure_) {
        RefinanceLoanParameters memory parameters = abi.decode(rawParameters_, (RefinanceLoanParameters));

        bytes[] memory calls = new bytes[](parameters.terms.length);

        address refinancer_;
        uint256 principalDecrease_;
        uint256 principalIncrease_;

        for (uint256 i; i < parameters.terms.length; ++i) {
            bytes32 term = bytes32(bytes(parameters.terms[i]));

            if (isLoanOpenTerm[parameters.name]) {
                if (term == "decreasePrincipal") {
                    calls[i] = abi.encodeWithSignature("decreasePrincipal(uint256)", principalDecrease_ = parameters.values[i]);
                } else if (term == "increasePrincipal") {
                    calls[i] = abi.encodeWithSignature("increasePrincipal(uint256)", principalIncrease_ = parameters.values[i]);
                } else if (term == "setDelegateServiceFeeRate") {
                    calls[i] = abi.encodeWithSignature("setDelegateServiceFeeRate(uint64)", uint64(parameters.values[i]));
                } else if (term == "setGracePeriod") {
                    calls[i] = abi.encodeWithSignature("setGracePeriod(uint64)", uint32(parameters.values[i]));
                } else if (term == "setInterestRate") {
                    calls[i] = abi.encodeWithSignature("setInterestRate(uint64)", uint64(parameters.values[i]));
                } else if (term == "setLateFeeRate") {
                    calls[i] = abi.encodeWithSignature("setLateFeeRate(uint64)", uint64(parameters.values[i]));
                } else if (term == "setLateInterestPremiumRate") {
                    calls[i] = abi.encodeWithSignature("setLateInterestPremiumRate(uint64)", uint64(parameters.values[i]));
                } else if (term == "setNoticePeriod") {
                    calls[i] = abi.encodeWithSignature("setNoticePeriod(uint64)", uint32(parameters.values[i]));
                } else if (term == "setPaymentInterval") {
                    calls[i] = abi.encodeWithSignature("setPaymentInterval(uint64)", uint32(parameters.values[i]));
                } else {
                    revert("UNSUPPORTED");
                }

                refinancer_ = address(openTermRefinancer);
            } else {
                if (term == "increasePrincipal") {
                    calls[i] = abi.encodeWithSignature("increasePrincipal(uint256)", principalIncrease_ = parameters.values[i]);
                } else if (term == "setClosingRate") {
                    calls[i] = abi.encodeWithSignature("setClosingRate(uint256)", parameters.values[i]);
                } else if (term == "setCollateralRequired") {
                    calls[i] = abi.encodeWithSignature("setCollateralRequired(uint256)", parameters.values[i]);
                } else if (term == "setEndingPrincipal") {
                    calls[i] = abi.encodeWithSignature("setEndingPrincipal(uint256)", parameters.values[i]);
                } else if (term == "setGracePeriod") {
                    calls[i] = abi.encodeWithSignature("setGracePeriod(uint256)", parameters.values[i]);
                } else if (term == "setInterestRate") {
                    calls[i] = abi.encodeWithSignature("setInterestRate(uint256)", parameters.values[i]);
                } else if (term == "setLateFeeRate") {
                    calls[i] = abi.encodeWithSignature("setLateFeeRate(uint256)", parameters.values[i]);
                } else if (term == "setLateInterestPremiumRate") {
                    calls[i] = abi.encodeWithSignature("setLateInterestPremiumRate(uint256)", parameters.values[i]);
                } else if (term == "setPaymentInterval") {
                    calls[i] = abi.encodeWithSignature("setPaymentInterval(uint256)", parameters.values[i]);
                } else if (term == "setPaymentsRemaining") {
                    calls[i] = abi.encodeWithSignature("setPaymentsRemaining(uint256)", parameters.values[i]);
                } else {
                    revert("UNSUPPORTED");
                }

                // TODO: `updateDelegateFeeTerms` takes 2 arguments.

                refinancer_ = address(fixedTermRefinancer);
            }
        }

        if (principalDecrease_ > 0) {
            erc20_mint(address(fundsAsset), ILoanLike(loanNamed[parameters.name]).borrower(), principalDecrease_);

            erc20_approve(
                address(fundsAsset),
                ILoanLike(loanNamed[parameters.name]).borrower(),
                loanNamed[parameters.name],
                principalDecrease_
            );
        }

        proposeRefinance(loanNamed[parameters.name], refinancer_, block.timestamp, calls);
        acceptRefinance(loanNamed[parameters.name],  refinancer_, block.timestamp, calls, principalIncrease_);
    }

    function handleDefaultLoan(bytes memory rawParameters_) internal returns (bool failure_) {
        DefaultLoanParameters memory parameters = abi.decode(rawParameters_, (DefaultLoanParameters));

        // TODO: Check other parameters.

        triggerDefault(loanNamed[parameters.name], liquidatorFactory);

        if (isLoanOpenTerm[parameters.name]) return false;

        finishCollateralLiquidation(loanNamed[parameters.name]);
    }

    function handleNone(bytes memory rawParameters_) internal returns (bool failure_) {}

    function checkExpected(bytes memory rawExpected_) internal returns (bool failure_) {
        ExpectedValues memory parameters = abi.decode(rawExpected_, (ExpectedValues));

        uint256 accruedInterest =
            ILoanManagerLike(poolManager.loanManagerList(0)).accruedInterest() +
            ILoanManagerLike(poolManager.loanManagerList(1)).accruedInterest();

        if (stdMath.delta(accruedInterest, parameters.accruedInterest) > 5) {
            console.log(
                "    Expected accruedInterest is",
                toString(parameters.accruedInterest),
                "but actually is",
                toString(accruedInterest)
            );

            failure_ = true;
        }

        // TODO: Reduce `3e4` to 3.
        if (stdMath.delta(fundsAsset.balanceOf(address(pool)), parameters.cash) > 3e4) {
            console.log(
                "    Expected cash is",
                toString(parameters.cash),
                "but actually is",
                toString(fundsAsset.balanceOf(address(pool)))
            );

            failure_ = true;
        }

        uint256 principalOut =
            ILoanManagerLike(poolManager.loanManagerList(0)).principalOut() +
            ILoanManagerLike(poolManager.loanManagerList(1)).principalOut();

        // TODO: Reduce `3e4` to 3.
        if (stdMath.delta(principalOut, parameters.principalOutstanding) > 3e4) {
            console.log(
                "    Expected principalOutstanding is",
                toString(parameters.principalOutstanding),
                "but actually is",
                toString(principalOut)
            );

            failure_ = true;
        }

        // TODO: Reduce `1e4` to 1.
        if (stdMath.delta(poolManager.totalAssets(), parameters.totalAssets) > 1e4) {
            console.log(
                "    Expected totalAssets is",
                toString(parameters.totalAssets),
                "but actually is",
                toString(poolManager.totalAssets())
            );

            failure_ = true;
        }

        // TODO: Reduce `1e4` to 1.
        if (stdMath.delta(pool.totalSupply(), parameters.totalSupply) > 1e4) {
            console.log("    Expected totalSupply is", toString(parameters.totalSupply), "but actually is", toString(pool.totalSupply()));
            failure_ = true;
        }

        // TODO: Reduce `1e4` to 1.
        if (stdMath.delta(poolManager.unrealizedLosses(), parameters.unrealizedLosses) > 1e4) {
            console.log(
                "    Expected unrealizedLosses is",
                toString(parameters.unrealizedLosses),
                "but actually is",
                toString(poolManager.unrealizedLosses())
            );

            failure_ = true;
        }
    }

    function getHandler(string memory json_, string memory actionKey_) internal returns (function(bytes memory) returns (bool)) {
        bytes32 actionType_ = bytes32(bytes(json_.readString(concat(actionKey_, ".actionType"))));

        console.log("  action:", json_.readString(concat(actionKey_, ".actionType")));

        if (actionType_ == "createPool") return handleCreatePool;

        if (actionType_ == "deposit") return handleDeposit;

        if (actionType_ == "fundLoan") {
            return json_.readBool(concat(actionKey_, ".parameters.isOpenTerm")) ? handleFundOpenTermLoan : handleFundFixedTermLoan;
        }

        if (actionType_ == "payLoan") return handleLoanPayment;

        if (actionType_ == "callLoan") return handleCallOpenTermLoan;

        if (actionType_ == "uncallLoan") return handleUncallOpenTermLoan;

        if (actionType_ == "impairLoan") return handleImpairLoan;

        if (actionType_ == "unimpairLoan") return handleUnimpairLoan;

        if (actionType_ == "refiLoan") return handleRefinanceLoan;

        if (actionType_ == "defaultLoan") return handleDefaultLoan;

        if (actionType_ == "none") return handleNone;

        revert("INVALID_ACTION_TYPE");
    }

    function runScenario(string memory scenarioId) internal {
        console.log("\nScenario", scenarioId, "\n");

        string memory json = vm.readFile(concat(vm.projectRoot(), "/scenarios/data/json/", scenarioId, ".json"));

        string[] memory actions = json.readStringArray(".actions");

        for (uint256 i; i < actions.length; ++i) {
            console.log("Action", i);

            vm.warp(json.readUint(concat(".actions[", toString(i), "].timestamp")));

            console.log("  timestamp:", block.timestamp);

            bool failure_ = getHandler(json, concat(".actions[", toString(i), "]"))(
                json.parseRaw(concat(".actions[", toString(i), "].parameters"))
            );

            if (failure_) {
                console.log("    STOPPING DUE TO ACTION FAILURE");
                fail();
            }

            failure_ = checkExpected(json.parseRaw(concat(".actions[", toString(i), "].expected")));

            if (failure_) {
                console.log("    STOPPING DUE TO CHECK FAILURE");
                fail();
            }

            console.log("");
        }
    }

    function setUp() public override {
        _createAccounts();
        _createAssets();
        _createGlobals();
        _setTreasury();
        _createFactories();
    }

    function test_sim() external {
        runScenario(vm.envString("SCENARIO"));
    }

}
