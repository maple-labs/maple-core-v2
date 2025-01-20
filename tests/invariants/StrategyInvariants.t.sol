// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
	IAaveConfiguratorLike,
	IMockERC20,
	IUSDCLike
} from "../../contracts/interfaces/Interfaces.sol";

import { console2 as console } from "../../contracts/Runner.sol";

import { DepositHandler }         from "./handlers/DepositHandler.sol";
import { DistributionHandler }    from "./handlers/DistributionHandler.sol";
import { OpenTermLoanHandler }    from "./handlers/OpenTermLoanHandler.sol";
import { QueueWithdrawalHandler } from "./handlers/QueueWithdrawalHandler.sol";
import { StrategyHandler }        from "./handlers/StrategyHandler.sol";
import { TransferHandler }        from "./handlers/TransferHandler.sol";

import { BaseInvariants } from "./BaseInvariants.t.sol";

contract StrategyInvariants is BaseInvariants {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    uint256 constant NUM_LPS       = 10;
    uint256 constant NUM_OT_LOANS  = 10;
    uint256 constant NUM_BORROWERS = 5;

    DistributionHandler distributionHandler;

    /**************************************************************************************************************************************/
    /*** Setup Function                                                                                                                 ***/
    /**************************************************************************************************************************************/

    function setUp() public override {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 21325954);

        // Whitelist all LPs and borrowers to mint USDC.
        address masterMinter = IUSDCLike(USDC).masterMinter();

        for (uint256 i; i < NUM_LPS; i++) {
            address lp = makeAddr(string(abi.encode("lp", i)));

            vm.prank(masterMinter);
            IUSDCLike(USDC).configureMinter(lp, type(uint256).max);

            lps.push(lp);
        }

        for (uint256 i; i < NUM_BORROWERS; i++) {
            address borrower = makeAddr(string(abi.encode("borrower", i)));

            vm.prank(masterMinter);
            IUSDCLike(USDC).configureMinter(borrower, type(uint256).max);
        }

        start = currentTimestamp = block.timestamp;

        fundsAsset = IMockERC20(USDC);

        _createAccounts();
        _createGlobals();
        _setTreasury();
        _createFactories();

        address[] memory factories = new address[](4);
        bytes[] memory deploymentData = new bytes[](4);

        factories[0] = fixedTermLoanManagerFactory;
        factories[1] = openTermLoanManagerFactory;
        factories[2] = aaveStrategyFactory;
        factories[3] = skyStrategyFactory;

        deploymentData[0] = "";
        deploymentData[1] = "";
        deploymentData[2] = abi.encode(AAVE_USDC);
        deploymentData[3] = abi.encode(SAVINGS_USDS, USDS_LITE_PSM);

        vm.startPrank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", address(AAVE_USDC),     true);
        globals.setValidInstanceOf("STRATEGY_VAULT", address(SAVINGS_USDS),  true);
        globals.setValidInstanceOf("PSM",            address(USDS_LITE_PSM), true);
        vm.stopPrank();

        _createPoolWithQueueAndStrategies(address(fundsAsset), factories, deploymentData);
        activatePool(address(poolManager), HUNDRED_PERCENT);
        openPool(address(poolManager));

        // Remove Aave supply cap.
        address aclAdmin = 0x5300A1a15135EA4dc7aD5a167152C01EFc9b192A;

        vm.prank(aclAdmin);
        IAaveConfiguratorLike(AAVE_CONFIG).setSupplyCap(USDC, 0);

        // Create and configure handlers.
        depositHandler = new DepositHandler(address(pool), lps);
        transferHandler = new TransferHandler(address(pool), lps);
        queueWithdrawalHandler = new QueueWithdrawalHandler(address(pool), lps);
        strategyHandler = new StrategyHandler(poolManager.strategyList(2), poolManager.strategyList(3));
        otlHandler = new OpenTermLoanHandler({
            loanFactory_:       address(openTermLoanFactory),
            liquidatorFactory_: address(liquidatorFactory),
            poolManager_:       address(poolManager),
            refinancer_:        address(openTermRefinancer),
            maxBorrowers_:      NUM_BORROWERS,
            maxLoans_:          NUM_OT_LOANS
        });

        depositHandler.setSelectorWeight("deposit(uint256)", 7_500);
        depositHandler.setSelectorWeight("mint(uint256)",    2_500);

        transferHandler.setSelectorWeight("transfer(uint256)", 10_000);

        queueWithdrawalHandler.setSelectorWeight("processRedemptions(uint256)",  3_500);
        queueWithdrawalHandler.setSelectorWeight("redeem(uint256)",              1_000);
        queueWithdrawalHandler.setSelectorWeight("removeRequest(uint256)",       1_000);
        queueWithdrawalHandler.setSelectorWeight("removeShares(uint256)",        1_000);
        queueWithdrawalHandler.setSelectorWeight("requestRedeem(uint256)",       3_500);

        strategyHandler.setSelectorWeight("fundStrategy(uint256)",         1_500);
        strategyHandler.setSelectorWeight("withdrawFromStrategy(uint256)", 1_500);
        strategyHandler.setSelectorWeight("setStrategyFeeRate(uint256)",   500);
        strategyHandler.setSelectorWeight("impairStrategy(uint256)",       500);
        strategyHandler.setSelectorWeight("deactivateStrategy(uint256)",   500);
        strategyHandler.setSelectorWeight("reactivateStrategy(uint256)",   500);
        strategyHandler.setSelectorWeight("warp(uint256)",                 5_000);

        otlHandler.setSelectorWeight("callLoan(uint256)",             500);
        otlHandler.setSelectorWeight("fundLoan(uint256)",             1_500);
        otlHandler.setSelectorWeight("impairLoan(uint256)",           0);
        otlHandler.setSelectorWeight("makePayment(uint256)",          3_000);
        otlHandler.setSelectorWeight("refinance(uint256)",            0);
        otlHandler.setSelectorWeight("removeLoanCall(uint256)",       500);
        otlHandler.setSelectorWeight("removeLoanImpairment(uint256)", 500);
        otlHandler.setSelectorWeight("triggerDefault(uint256)",       1_000);
        otlHandler.setSelectorWeight("warp(uint256)",                 3_000);

        address[] memory targetContracts = new address[](5);
        targetContracts[0] = address(depositHandler);
        targetContracts[1] = address(transferHandler);
        targetContracts[2] = address(queueWithdrawalHandler);
        targetContracts[3] = address(strategyHandler);
        targetContracts[4] = address(otlHandler);

        uint256[] memory weightsDistributorHandler = new uint256[](5);
        weightsDistributorHandler[0] = 10;
        weightsDistributorHandler[1] = 5;
        weightsDistributorHandler[2] = 10;
        weightsDistributorHandler[3] = 50;
        weightsDistributorHandler[4] = 25;

        distributionHandler = new DistributionHandler(targetContracts, weightsDistributorHandler);

        targetContract(address(distributionHandler));
    }

    /**************************************************************************************************************************************/
    /*** Strategy Invariants                                                                                                            ***/
    /**************************************************************************************************************************************/

    function statefulFuzz_strategy_A_B_C_D_E_F_G() external useCurrentTimestamp {
        uint256 strategyCount = strategyHandler.strategyCount();

        for (uint i; i < strategyCount; i++) {
            address strategy = strategyHandler.strategies(i);

            assert_strategy_invariant_A(strategy);
            assert_strategy_invariant_B(strategy);
            assert_strategy_invariant_C(strategy);
            assert_strategy_invariant_D(strategy);
            assert_strategy_invariant_E(strategy);
            assert_strategy_invariant_F(strategy);
            assert_strategy_invariant_G(strategy);
        }
    }

}
