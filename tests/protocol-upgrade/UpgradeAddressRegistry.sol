// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { MapleAddressRegistryETH as AddressRegistry } from "../../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

contract UpgradeAddressRegistry is AddressRegistry {

    // TODO: Double check addresses using correct deployer 
    // Using deployer 0x14e289f19898a5c16AF00b81180C18A791Fa0979

    address aaveStrategyFactory  = 0x7b7935aB23d7988b8b7AcC4E31eCbD4eaAb86524;
    address basicStrategyFactory = 0xE026F55eb5AA4D1A87fdA934fD604b96bC3244b4;
    address skyStrategyFactory   = 0xc784Ef67b00def57fbE541e8c985f9340a9ecC95;

    address newGlobalsImplementation = 0xDB57b536700B51d7f77013B1541fe4E7495BF451;

    address newBasicStrategyImplementation = 0x4DFc08B9BaC8Ecd73A501E6CBEa1B24D0B54c6F3;
    address newBasicStrategyInitializer    = 0xDf1Cbc08872461EECeb96C816E44cfe29aecCcFf;
    address newAaveStrategyImplementation  = 0x6516B110b6A667d73fEa1C274B66dc83BC534255;
    address newAaveStrategyInitializer     = 0x07D44ed72F1FCF18a47FB87B79c76E24DdCB3473;
    address newSkyStrategyImplementation   = 0x33A90e039532aAb504038A7E37fDf012F7b47489;
    address newSkyStrategyInitializer      = 0xA0029e5dFB20515F080c4298401f2104ab8Ce77c;

    address newPoolManagerImplementation = 0x9ca5b120adBc51d2E231303015223cdcd518297a;
    address newPoolManagerInitializer    = 0x80A9E9FdAF853565EA6fa6f7e498dFd83740755E;
    address newPoolDeployer              = 0x4E54E0752410b12cE96F4F79C15922d0AbA9D28f;

    address newFixedTermLoanImplementation = 0xBA2b97e4E623839C90AD3448B3d3780DB8E92b23;
    address newFixedTermLoanInitializer    = 0x5520Dc65f28fBbE76AD02dc624df2Ea2FC60aA9a;
    address newOpenTermLoanImplementation  = 0x8B87F850A162ef7a627C9e8dAEC376d989D2Ca59;
    address newOpenTermLoanInitializer     = 0x0fC0722c2c4D20B4168E33a2Dc1947EA1d618CC9;

    // TODO: Add all pool managers that need to be upgraded.
    address[] poolManagers = [
        aqruPoolManager,
        cashUSDCPoolManager,
        blueChipSecuredUSDCPoolManager,
        highYieldCorpUSDCPoolManager,
        highYieldCorpWETHPoolManager,
        securedLendingUSDCPoolManager,
        syrupUSDCPoolManager,
        syrupUSDTPoolManager
    ];

    // TODO: Populate and add the same data for other pools.
    address[] syrupUSDCAllowedLenders;
    address[] syrupUSDCFixedTermLoans;
    address[] syrupUSDCOpenTermLoans;

}
