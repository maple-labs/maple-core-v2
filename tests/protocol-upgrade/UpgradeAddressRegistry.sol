// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { MapleAddressRegistryETH as AddressRegistry } from "../../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

contract UpgradeAddressRegistry is AddressRegistry {

    // Using deployer 0x14e289f19898a5c16AF00b81180C18A791Fa0979

    address aaveStrategyFactory            = 0x01ab799f77F9a9f4dd0D2b6E7C83DCF3F48D5650;
    address newAaveStrategyImplementation  = 0xFc8F7F97165d446B02Cc95363d2cA31154BBe9F9;
    address newAaveStrategyInitializer     = 0x0d2dBb28B1c7d225132722FAdb2402E93A35c1Be;

    address basicStrategyFactory           = 0x876D54DBF61473cA169b89B95344A14E81F37afe;
    address newBasicStrategyImplementation = 0x7a1E281Ec29F3A861f211a28a23161762BD55B73;
    address newBasicStrategyInitializer    = 0x2b9aDDb5244548f126e59FA5483040efc102f69e;

    address skyStrategyFactory             = 0x27327E08de810c687687F95bfCE92088089b56dB;
    address newSkyStrategyImplementation   = 0xBBEe42621499005Ff0dDEF947BBDeFfBBeE77730;
    address newSkyStrategyInitializer      = 0x29199d071717c72baab50eEf9adD6736A18A1d1d;

    address newGlobalsImplementation = 0x9BeAbb1B6F3ad1DdB87b65148BA5Eb6102334956;

    address newPoolManagerImplementation = 0xfE02Be1aD28EdFd8e3dD6F29C402B244C2A258B8;
    address newPoolManagerInitializer    = 0xB33Bfa00E1d92fDaC5AeCB2976d6998C2ecca759;
    address newPoolDeployer              = 0xdaF005B31B10F33EE42cEB1A4b983434FE947488;

    address newFixedTermLoanImplementation = 0xe59afb1A3239a0aE48c9b77a44c3CDf1A3783F9d;
    address newFixedTermLoanInitializer    = 0x37dBaB1Ca75bAf218251F05e4063270cdd5C5FA8;
    address newOpenTermLoanImplementation  = 0x133A6feE09dFb0FD3B0e0f69c8897cCe3798d4bB;
    address newOpenTermLoanInitializer     = 0xBBd0537D68C41Dc3EDa4B362436A119059Be9836;

    address syrupUSDCAaveStrategy = 0x5C3cFc2AFc1C2b96c479713cb49b9D09429F74a0;
    address syrupUSDCSkyStrategy  = 0x5aE349aAcDDcD9a1ec0FcafbdFde96A925cA1145;

    address syrupUSDTAaveStrategy = 0x1DD7F048dDE12E7C963C6699B1603d1a10D17542;

    address securedLendingAaveStrategy = 0x8947af19bDCC7c3f8beeCe7FC1C75e85Aa3F40BC;

    // Pool Delegates
    address aqruPoolDelegate              = 0x39DF355Ae51fDf17aE1a68D00F770701e9627A93;
    address cashUSDCPoolDelegate          = 0x94b8dcbe4c7841B54170925b67918a6312154C9c;
    address blueChipPoolDelegate          = 0x0984af3FcB364c1f30337F9aB453f876e7Ff6D0B;
    address highYieldCorpPoolDelegate     = 0xeb636FF0b27c2EE99731Cb0588DB6DB76DA6e06e;
    address highYieldCorpWETHPoolDelegate = 0x6d03aa567aE55FAd71Fd58D9A4ba44D9dc6aDc5f;
    address secureLendingPoolDelegate     = 0x8c6a34E2b9CeceE4a1fce672ba37e611B1AECebB;
    address syrupUSDCPoolDelegate         = 0xEe3cBEFF9dC14EC9710A643B7624C5BEaF20BCcb;
    address syrupUSDTPoolDelegate         = 0xE512aCb671cCE2c976B151DEC89f9aAf701Bb006;

    address[] poolDelegates = [
        aqruPoolDelegate,
        cashUSDCPoolDelegate,
        blueChipPoolDelegate,
        highYieldCorpPoolDelegate,
        highYieldCorpWETHPoolDelegate,
        secureLendingPoolDelegate,
        syrupUSDCPoolDelegate,
        syrupUSDTPoolDelegate
    ];

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
