// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console } from "../../contracts/Runner.sol";

import {
	IAaveConfiguratorLike,
	IMockERC20,
    IPool,
    IPoolManager,
    IProxyFactoryLike,
	IUSDCLike,
    IWithdrawalManagerQueue
} from "../../contracts/interfaces/Interfaces.sol";

import { DepositHandler }         from "./handlers/DepositHandler.sol";
import { DistributionHandler }    from "./handlers/DistributionHandler.sol";
import { OpenTermLoanHandler }    from "./handlers/OpenTermLoanHandler.sol";
import { QueueWithdrawalHandler } from "./handlers/QueueWithdrawalHandler.sol";
import { StrategyHandler }        from "./handlers/StrategyHandler.sol";
import { TransferHandler }        from "./handlers/TransferHandler.sol";
import { FixedTermLoanHandler }   from "./handlers/FixedTermLoanHandler.sol";

import { MockERC20 } from "../mocks/Mocks.sol";

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

        start = block.timestamp;

        collateralAsset = IMockERC20(address(new MockERC20("Wrapper Ether", "WETH", 18)));
        fundsAsset      = IMockERC20(USDC);

        _createAccounts();
        _createGlobals();
        _configureGlobals();
        _createFactories();
        _upgradeSyrupUSDCWithdrawalManager();

        address[] memory factories = new address[](5);
        bytes[] memory deploymentData = new bytes[](5);

        factories[0] = fixedTermLoanManagerFactory;
        factories[1] = openTermLoanManagerFactory;
        factories[2] = aaveStrategyFactory;
        factories[3] = skyStrategyFactory;
        factories[4] = coreStrategyFactory;

        deploymentData[0] = "";
        deploymentData[1] = "";
        deploymentData[2] = abi.encode(AAVE_USDC);
        deploymentData[3] = abi.encode(SAVINGS_USDS, USDS_LITE_PSM);
        deploymentData[4] = abi.encode(SYRUP_USDC);

        vm.startPrank(governor);
        globals.setValidInstanceOf("STRATEGY_VAULT", address(AAVE_USDC),     true);
        globals.setValidInstanceOf("STRATEGY_VAULT", address(SAVINGS_USDS),  true);
        globals.setValidInstanceOf("PSM",            address(USDS_LITE_PSM), true);
        globals.setValidInstanceOf("STRATEGY_VAULT", address(SYRUP_USDC),    true);
        vm.stopPrank();

        // Whitelist Syrup USDC contracts on globals.
        address syrupUsdcPoolManager       = IPool(SYRUP_USDC).manager();
        address syrupUsdcWithdrawalManager = IPoolManager(syrupUsdcPoolManager).withdrawalManager();

        vm.startPrank(governor);
        globals.setValidInstanceOf("POOL_MANAGER_FACTORY",             IPoolManager(syrupUsdcPoolManager).factory(),                  true);
        globals.setValidInstanceOf("WITHDRAWAL_MANAGER_QUEUE_FACTORY", IWithdrawalManagerQueue(syrupUsdcWithdrawalManager).factory(), true);
        vm.stopPrank();

        // Create a new pool, activate and open it.
        _createPoolWithQueueAndStrategies(address(fundsAsset), factories, deploymentData);

        activatePool(address(poolManager), HUNDRED_PERCENT);
        openPool(address(poolManager));

        // Set Syrup USDC to public.
        openPool(IPool(SYRUP_USDC).manager());

        // Remove Aave supply cap.
        address aclAdmin = 0x5300A1a15135EA4dc7aD5a167152C01EFc9b192A;

        vm.prank(aclAdmin);
        IAaveConfiguratorLike(AAVE_CONFIG).setSupplyCap(USDC, 0);

        // Create and configure handlers.
        depositHandler = new DepositHandler(address(pool), lps);
        transferHandler = new TransferHandler(address(pool), lps);
        queueWithdrawalHandler = new QueueWithdrawalHandler(address(pool), lps);
        strategyHandler = new StrategyHandler({
            aaveStrategy_: poolManager.strategyList(2),
            skyStrategy_:  poolManager.strategyList(3),
            coreStrategy_: poolManager.strategyList(4)
        });
        ftlHandler = new FixedTermLoanHandler({
            collateralAsset_:   address(collateralAsset),
            feeManager_:        address(fixedTermFeeManager),
            governor_:          governor,
            liquidatorFactory_: liquidatorFactory,
            loanFactory_:       fixedTermLoanFactory,
            poolManager_:       address(poolManager),
            refinancer_:        address(fixedTermRefinancer),
            numBorrowers_:      NUM_BORROWERS
        });
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

        queueWithdrawalHandler.setSelectorWeight("processRedemptions(uint256)",      2_700);
        queueWithdrawalHandler.setSelectorWeight("redeem(uint256)",                  1_000);
        queueWithdrawalHandler.setSelectorWeight("removeRequest(uint256)",           1_000);
        queueWithdrawalHandler.setSelectorWeight("removeShares(uint256)",            1_000);
        queueWithdrawalHandler.setSelectorWeight("removeSharesById(uint256)",        1_000);
        queueWithdrawalHandler.setSelectorWeight("requestRedeem(uint256)",           3_300);

        strategyHandler.setSelectorWeight("fundStrategy(uint256)",                2_000);
        strategyHandler.setSelectorWeight("withdrawFromStrategy(uint256)",        2_000);
        strategyHandler.setSelectorWeight("requestWithdrawFromStrategy(uint256)", 1_000);
        strategyHandler.setSelectorWeight("processRedemptions(uint256)",          1_000);
        strategyHandler.setSelectorWeight("setStrategyFeeRate(uint256)",          1_000);
        strategyHandler.setSelectorWeight("impairStrategy(uint256)",              1_000);
        strategyHandler.setSelectorWeight("deactivateStrategy(uint256)",          1_000);
        strategyHandler.setSelectorWeight("reactivateStrategy(uint256)",          1_000);

        ftlHandler.setSelectorWeight("createLoanAndFund(uint256)",           1_000);
        ftlHandler.setSelectorWeight("makePayment(uint256)",                 0);
        ftlHandler.setSelectorWeight("impairmentMakePayment(uint256)",       1_000);
        ftlHandler.setSelectorWeight("defaultMakePayment(uint256)",          2_000);
        ftlHandler.setSelectorWeight("impairLoan(uint256)",                  1_500);
        ftlHandler.setSelectorWeight("triggerDefault(uint256)",              2_000);
        ftlHandler.setSelectorWeight("finishCollateralLiquidation(uint256)", 1_500);
        ftlHandler.setSelectorWeight("refinance(uint256)",                   1_000);

        otlHandler.setSelectorWeight("callLoan(uint256)",             1_000);
        otlHandler.setSelectorWeight("fundLoan(uint256)",             1_000);
        otlHandler.setSelectorWeight("impairLoan(uint256)",           500);
        otlHandler.setSelectorWeight("makePayment(uint256)",          3_500);
        otlHandler.setSelectorWeight("refinance(uint256)",            500);
        otlHandler.setSelectorWeight("removeLoanCall(uint256)",       1_000);
        otlHandler.setSelectorWeight("removeLoanImpairment(uint256)", 1_000);
        otlHandler.setSelectorWeight("triggerDefault(uint256)",       1_500);

        address[] memory targetContracts = new address[](6);
        targetContracts[0] = address(depositHandler);
        targetContracts[1] = address(transferHandler);
        targetContracts[2] = address(queueWithdrawalHandler);
        targetContracts[3] = address(strategyHandler);
        targetContracts[4] = address(ftlHandler);
        targetContracts[5] = address(otlHandler);

        uint256[] memory weightsDistributorHandler = new uint256[](6);
        weightsDistributorHandler[0] = 10;
        weightsDistributorHandler[1] = 5;
        weightsDistributorHandler[2] = 10;
        weightsDistributorHandler[3] = 50;
        weightsDistributorHandler[4] = 15;
        weightsDistributorHandler[5] = 10;

        distributionHandler = new DistributionHandler(targetContracts, weightsDistributorHandler);

        console.log("distributionHandler", address(distributionHandler));
        console.log("targetContracts[0]", targetContracts[0]);
        console.log("targetContracts[1]", targetContracts[1]);
        console.log("targetContracts[2]", targetContracts[2]);
        console.log("targetContracts[3]", targetContracts[3]);
        console.log("targetContracts[4]", targetContracts[4]);
        console.log("targetContracts[5]", targetContracts[5]);

        targetContract(address(distributionHandler));
    }

    // TODO: Update with Migrator once available
    function _upgradeSyrupUSDCWithdrawalManager() internal {
        address syrupUsdcPoolManager       = IPool(SYRUP_USDC).manager();
        address syrupUsdcWithdrawalManager = IPoolManager(syrupUsdcPoolManager).withdrawalManager();

        address governor = 0xd6d4Bcde6c816F17889f1Dd3000aF0261B03a196;

        vm.startPrank(governor);
        address factory = IWithdrawalManagerQueue(syrupUsdcWithdrawalManager).factory();
        IProxyFactoryLike(factory).registerImplementation(101, queueWMImplementation, address(0));
        IProxyFactoryLike(factory).setDefaultVersion(101);
        IProxyFactoryLike(factory).enableUpgradePath(100, 101, address(0));
        vm.stopPrank();

        address securityAdmin = 0x6b1A78C1943b03086F7Ee53360f9b0672bD60818;

        vm.prank(securityAdmin);
        IWithdrawalManagerQueue(syrupUsdcWithdrawalManager).upgrade(101, "");
    }

    /**************************************************************************************************************************************/
    /*** Strategy Invariants                                                                                                            ***/
    /**************************************************************************************************************************************/

    function statefulFuzz_strategyInvariants() external {
        assert_poolManager_invariant_B();

        assert_ftl_invariants();
        assert_ftlm_invariants_A_B_C_D_E_F_H_I_J_K_L();

        assert_otl_invariants();
        assert_otlm_invariants_B_C_F_H_I_J_L_M();

        assert_wm_queue_invariants(poolManager.withdrawalManager(), lps);
        assert_strategy_invariants();
    }

}
