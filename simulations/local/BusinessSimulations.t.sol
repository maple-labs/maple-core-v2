// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { Address } from "../../contracts/Contracts.sol";

import { LoanScenario }   from "../LoanScenario.sol";
import { SimulationBase } from "../SimulationBase.sol";

contract BusinessSimulations is SimulationBase {

    function setUp() public override {
        super.setUp();

        initialCover     = 0;
        initialLiquidity = 1_000_000e6;

        setupFees({
            delegateOriginationFee:     5_000e6,       // 1,000,000 * 0.5%             = 5000
            delegateServiceFee:         271.232876e6,  // 1,000,000 * 0.33% * 30 / 365 = 271.232876
            delegateManagementFeeRate:  0.10e6,
            platformOriginationFeeRate: 0.0025e6,      // 1,000,000 * 0.25%            = 2500
            platformServiceFeeRate:     0.0066e6,      // 1,000,000 * 0.66% * 30 / 180 = 1100
            platformManagementFeeRate:  0.025e6
        });

        vm.prank(governor);
        globals.setMaxCoverLiquidationPercent(address(poolManager), 0.3e6);
    }

    function _createSimulationLoan(uint256 startingPrincipal, uint256 endingPrincipal, uint256 collateral, string memory loanName) internal {
        scenarios.push(new LoanScenario({
            loan_: address(createLoan({
                borrower:    address(new Address()),
                termDetails: [uint256(0), uint256(30 days), uint256(6)],
                amounts:     [uint256(collateral), uint256(startingPrincipal), uint256(endingPrincipal)],
                rates:       [uint256(0.10e18), uint256(0), uint256(0.01e18), uint256(0.05e18)],
                loanManager: poolManager.loanManagerList(0)
            })),
            poolManager_:       address(poolManager),
            liquidatorFactory_: liquidatorFactory,
            fundingTime_:       start,
            name_:              loanName
        }));
    }

    function test_loanShed_happy() external {
        _createSimulationLoan(1_000_000e6, 0, 0, "loan-1");

        string memory fileName = "business-payment-sim-1";

        setUpSimulation();
        setUpBusinessLogger(fileName);
        simulation.run();
    }

    function test_loanShed_late() external {
        _createSimulationLoan(1_000_000e6, 0, 0, "loan-1");

        scenarios[0].setPaymentOffset(2, 7 days);

        string memory fileName = "business-payment-sim-2";

        setUpSimulation();
        setUpBusinessLogger(fileName);
        simulation.run();
    }

    /******************************************************************************************************************************/
    /*** No Impairment + Uncollateralized                                                                                       ***/
    /******************************************************************************************************************************/

    function test_loanShed_liquidation_fullCover_uncollateralized_noImpairment() external {
        fundsAsset.mint(poolManager.poolDelegateCover(), 100_000_000e6);

        _createSimulationLoan(1_000_000e6, 0, 0, "loan-1");

        scenarios[0].setLiquidation(1, 5 days, 7 days, 2000e6);

        string memory fileName = "business-default-full-cover-no-collat-no-impair";

        setUpSimulation();
        setUpBusinessLogger(fileName);
        simulation.run();
    }

    function test_loanShed_liquidation_partialCover_uncollateralized_noImpairment() external {
        fundsAsset.mint(poolManager.poolDelegateCover(), 1_000_000e6);

        _createSimulationLoan(1_000_000e6, 0, 0, "loan-1");

        scenarios[0].setLiquidation(1, 5 days, 7 days, 2000e6);

        string memory fileName = "business-default-partial-cover-no-collat-no-impair";

        setUpSimulation();
        setUpBusinessLogger(fileName);
        simulation.run();
    }

    function test_loanShed_liquidation_noCover_uncollateralized_noImpairment() external {
        _createSimulationLoan(1_000_000e6, 0, 0, "loan-1");

        scenarios[0].setLiquidation(1, 5 days, 7 days, 2000e6);

        string memory fileName = "business-default-no-cover-no-collat-no-impair";

        setUpSimulation();
        setUpBusinessLogger(fileName);
        simulation.run();
    }

    /******************************************************************************************************************************/
    /*** No Impairment + Collateralized                                                                                         ***/
    /******************************************************************************************************************************/

    function test_loanShed_liquidation_fullCover_partiallyCollateralized_noImpairment() external {
        fundsAsset.mint(poolManager.poolDelegateCover(), 100_000_000e6);

        _createSimulationLoan(1_000_000e6, 0, 100e18, "loan-1");

        scenarios[0].setLiquidation(1, 5 days, 7 days, 2000e6);

        string memory fileName = "business-default-full-cover-partial-collat-no-impair";

        setUpSimulation();
        setUpBusinessLogger(fileName);
        simulation.run();
    }

    function test_loanShed_liquidation_partialCover_partiallyCollateralized_noImpairment() external {
        fundsAsset.mint(poolManager.poolDelegateCover(), 1_000_000e6);

        _createSimulationLoan(1_000_000e6, 0, 100e18, "loan-1");

        scenarios[0].setLiquidation(1, 5 days, 7 days, 2000e6);

        string memory fileName = "business-default-partial-cover-partial-collat-no-impair";

        setUpSimulation();
        setUpBusinessLogger(fileName);
        simulation.run();
    }

    function test_loanShed_liquidation_noCover_partiallyCollateralized_noImpairment() external {
        _createSimulationLoan(1_000_000e6, 0, 100e18, "loan-1");

        scenarios[0].setLiquidation(1, 5 days, 7 days, 2000e6);

        string memory fileName = "business-default-no-cover-partial-collat-no-impair";

        setUpSimulation();
        setUpBusinessLogger(fileName);
        simulation.run();
    }

    /******************************************************************************************************************************/
    /*** Early Impairment - Uncollateralized                                                                                    ***/
    /******************************************************************************************************************************/

    function test_loanShed_liquidation_fullCover_uncollateralized_earlyImpairment() external {
        fundsAsset.mint(poolManager.poolDelegateCover(), 100_000_000e6);

        _createSimulationLoan(1_000_000e6, 0, 0, "loan-1");

        scenarios[0].setLoanImpairment(1, -2 days);
        scenarios[0].setLiquidation(1, 5 days, 7 days, 2000e6);

        string memory fileName = "business-default-full-cover-no-collat-early-impair";

        setUpSimulation();
        setUpBusinessLogger(fileName);
        simulation.run();
    }

    function test_loanShed_liquidation_partialCover_uncollateralized_earlyImpairment() external {
        fundsAsset.mint(poolManager.poolDelegateCover(), 1_000_000e6);

        _createSimulationLoan(1_000_000e6, 0, 0, "loan-1");

        scenarios[0].setLoanImpairment(1, -2 days);
        scenarios[0].setLiquidation(1, 5 days, 7 days, 2000e6);

        string memory fileName = "business-default-partial-cover-no-collat-early-impair";

        setUpSimulation();
        setUpBusinessLogger(fileName);
        simulation.run();
    }

    function test_loanShed_liquidation_noCover_uncollateralized_earlyImpairment() external {
        _createSimulationLoan(1_000_000e6, 0, 0, "loan-1");

        scenarios[0].setLoanImpairment(1, -2 days);
        scenarios[0].setLiquidation(1, 5 days, 7 days, 2000e6);

        string memory fileName = "business-default-no-cover-no-collat-early-impair";

        setUpSimulation();
        setUpBusinessLogger(fileName);
        simulation.run();
    }

    /******************************************************************************************************************************/
    /*** Early Impairment - Collateralized                                                                                      ***/
    /******************************************************************************************************************************/

    function test_loanShed_liquidation_fullCover_partiallyCollateralized_earlyImpairment() external {
        fundsAsset.mint(poolManager.poolDelegateCover(), 100_000_000e6);

        _createSimulationLoan(1_000_000e6, 0, 100e18, "loan-1");

        scenarios[0].setLoanImpairment(1, -2 days);
        scenarios[0].setLiquidation(1, 5 days, 7 days, 2000e6);

        string memory fileName = "business-default-full-cover-partial-collat-early-impair";

        setUpSimulation();
        setUpBusinessLogger(fileName);
        simulation.run();
    }

    function test_loanShed_liquidation_partialCover_partiallyCollateralized_earlyImpairment() external {
        fundsAsset.mint(poolManager.poolDelegateCover(), 1_000_000e6);

        _createSimulationLoan(1_000_000e6, 0, 100e18, "loan-1");

        scenarios[0].setLoanImpairment(1, -2 days);
        scenarios[0].setLiquidation(1, 5 days, 7 days, 2000e6);

        string memory fileName = "business-default-partial-cover-partial-collat-early-impair";

        setUpSimulation();
        setUpBusinessLogger(fileName);
        simulation.run();
    }

    function test_loanShed_liquidation_noCover_partiallyCollateralized_earlyImpairment() external {
        _createSimulationLoan(1_000_000e6, 0, 100e18, "loan-1");

        scenarios[0].setLoanImpairment(1, -2 days);
        scenarios[0].setLiquidation(1, 5 days, 7 days, 2000e6);

        string memory fileName = "business-default-no-cover-partial-collat-early-impair";

        setUpSimulation();
        setUpBusinessLogger(fileName);
        simulation.run();
    }

    /******************************************************************************************************************************/
    /*** Late Impairment - Uncollateralized                                                                                     ***/
    /******************************************************************************************************************************/

    // TODO: Import loan submodule with change to allow late impairments
    function test_loanShed_liquidation_fullCover_uncollateralized_lateImpairment() external {
        fundsAsset.mint(poolManager.poolDelegateCover(), 100_000_000e6);

        _createSimulationLoan(1_000_000e6, 0, 0, "loan-1");

        scenarios[0].setLoanImpairment(1, 2 days);
        scenarios[0].setLiquidation(1, 5 days, 7 days, 2000e6);

        string memory fileName = "business-default-full-cover-no-collat-late-impair";

        setUpSimulation();
        setUpBusinessLogger(fileName);
        simulation.run();
    }

    function test_loanShed_liquidation_partialCover_uncollateralized_lateImpairment() external {
        fundsAsset.mint(poolManager.poolDelegateCover(), 1_000_000e6);

        _createSimulationLoan(1_000_000e6, 0, 0, "loan-1");

        scenarios[0].setLoanImpairment(1, 2 days);
        scenarios[0].setLiquidation(1, 5 days, 7 days, 2000e6);

        string memory fileName = "business-default-partial-cover-no-collat-late-impair";

        setUpSimulation();
        setUpBusinessLogger(fileName);
        simulation.run();
    }

    function test_loanShed_liquidation_noCover_uncollateralized_lateImpairment() external {
        _createSimulationLoan(1_000_000e6, 0, 0, "loan-1");

        scenarios[0].setLoanImpairment(1, 2 days);
        scenarios[0].setLiquidation(1, 5 days, 7 days, 2000e6);

        string memory fileName = "business-default-no-cover-no-collat-late-impair";

        setUpSimulation();
        setUpBusinessLogger(fileName);
        simulation.run();
    }

    /******************************************************************************************************************************/
    /*** Late Impairment - Collateralized                                                                                       ***/
    /******************************************************************************************************************************/

    // TODO: Import loan submodule with change to allow late impairments
    function test_loanShed_liquidation_fullCover_partiallyCollateralized_lateImpairment() external {
        fundsAsset.mint(poolManager.poolDelegateCover(), 100_000_000e6);

        _createSimulationLoan(1_000_000e6, 0, 100e18, "loan-1");

        scenarios[0].setLoanImpairment(1, 2 days);
        scenarios[0].setLiquidation(1, 5 days, 7 days, 2000e6);

        string memory fileName = "business-default-full-cover-partial-collat-late-impair";

        setUpSimulation();
        setUpBusinessLogger(fileName);
        simulation.run();
    }

    function test_loanShed_liquidation_partialCover_partiallyCollateralized_lateImpairment() external {
        fundsAsset.mint(poolManager.poolDelegateCover(), 1_000_000e6);

        _createSimulationLoan(1_000_000e6, 0, 100e18, "loan-1");

        scenarios[0].setLoanImpairment(1, 2 days);
        scenarios[0].setLiquidation(1, 5 days, 7 days, 2000e6);

        string memory fileName = "business-default-partial-cover-partial-collat-late-impair";

        setUpSimulation();
        setUpBusinessLogger(fileName);
        simulation.run();
    }

    function test_loanShed_liquidation_noCover_partiallyCollateralized_lateImpairment() external {
        _createSimulationLoan(1_000_000e6, 0, 100e18, "loan-1");

        scenarios[0].setLoanImpairment(1, 2 days);
        scenarios[0].setLiquidation(1, 5 days, 7 days, 2000e6);

        string memory fileName = "business-default-no-cover-partial-collat-late-impair";

        setUpSimulation();
        setUpBusinessLogger(fileName);
        simulation.run();
    }

}
