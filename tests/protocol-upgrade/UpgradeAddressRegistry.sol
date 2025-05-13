// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { MapleAddressRegistryETH as AddressRegistry } from "../../modules/address-registry/contracts/MapleAddressRegistryETH.sol";

contract UpgradeAddressRegistry is AddressRegistry {

    address openTermLoanV202Implementation;
    address openTermLoanV202Initializer;
    address openTermLoanV202Migrator;
    address openTermLoanManagerV101Implementation;
    address openTermLoanManagerV101Initializer;

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
        syrupUSDTPoolManager,
        LendAndLongUSDC1PoolManager,
        LendAndLongUSDC2PoolManager
    ];

    address[] openTermLoanManagers = [
        aqruOpenTermLoanManager,
        cashUSDCOpenTermLoanManager,
        blueChipSecuredUSDCOpenTermLoanManager,
        highYieldCorpUSDCOpenTermLoanManager,
        highYieldCorpWETHOpenTermLoanManager,
        securedLendingUSDCOpenTermLoanManager,
        LendAndLongUSDC1OpenTermLoanManager,
        LendAndLongUSDC2OpenTermLoanManager,
        syrupUSDCOpenTermLoanManager,
        syrupUSDTOpenTermLoanManager
    ];

    address[] openTermLoans = [
        0x1C1412B76156D78273F6A922E90F28954C0265E9,  // Syrup USDT 101
        0x51CB55cC626B7045d83A0a7B5E222C04f9246B94,  // Syrup USDT 101
        0x02a8ECBCCc5bF0e6eD2fcd9546248D18061811e2,  // Opportunistic High Yield Maple Pool USDC1 101
        0x446AC61b1053f8c33C40afF7E65B7Cb9f790935A,  // Opportunistic High Yield Maple Pool USDC1 201
        0x5CB3baE99e9A5809c52d7211f828d4F7289e0A1a,  // Opportunistic High Yield Maple Pool USDC1 101
        0x0763D79123387D2C43D604EDdB8B4ae6EF3E62d1,  // Syrup USDC 201
        0x133973dD3C4A2b7edb2CefD3CCC178964987bd08,  // Syrup USDC 201
        0x15814EB6648d0f688A4da6b69a839Ac21eD08dbe,  // Syrup USDC 201
        0x20D4cce9e045c9948FF7b28A62394c4A4ab14303,  // Syrup USDC 101
        0x29a631F43c020B4EF128c309E0B69c5e78819A53,  // Syrup USDC 101
        0x300f67060815db7509ADD4AC75287D0f00beD79C,  // Syrup USDC 201
        0x387Ce5F00F0CCaba7cDc9af35E72A6FF6A7F2627,  // Syrup USDC 201
        0x41B0f02E967Fb61A5606086D6705B0211b2Dbb39,  // Syrup USDC 101
        0x466B89CFB6D646c4ceD84f3EB00c80Cf25c28B69,  // Syrup USDC 201
        0x54C6367e94BF4341110f168A9cA20Eee11fCA529,  // Syrup USDC 201
        0x663F33d60708497a0876eD8D65474009bE65dbee,  // Syrup USDC 201
        0x7C752aB82B2E418584a83CB936b803B991874B82,  // Syrup USDC 201
        0xA3B8c8891E9c96452f9fF42598942eb36d6B8710,  // Syrup USDC 101
        0xAef98677ED594127a9402A0f66c13f8B598a851D,  // Syrup USDC 201
        0xBf25523b66B83612ac8267bA84D8fdB86432ec6e,  // Syrup USDC 201
        0xC9853ffD9339EA27Fc0eb52f8316cb8678823701,  // Syrup USDC 201
        0xCaE42E4158746c1115c72e1C7D09143df41C2dC7,  // Syrup USDC 201
        0xD8581582f578ecFEB245798583fb53c2E35fDeE5,  // Syrup USDC 201
        0xdBE714A8b70F11B257436E7a870f7420432e9a64,  // Syrup USDC 101
        0x138A9DaBA413410ED796185346Ac64016CE387C2,  // Maple Direct USDC1 201
        0x4E9E3c5fEE726151E29121c1588259F4310B89ab,  // Maple Direct USDC1 101
        0x755c19eb94ca78C7554582B71b6428305D63b4d7,  // Maple Direct USDC1 101
        0x98aAf57E9E5637eb435c2515e7FfF4Aa72df581d,  // Maple Direct USDC1 101
        0xbA782A156129E2d115FB0076Eb0F77e45aCe654B,  // Maple Direct USDC1 101
        0xC51ef20d4327010fa49Ade9FDEDE324dF7AfD600,  // Maple Direct USDC1 101
        0x1BB6Cb596c00d2285181FA5603fc383fCD0EA3E9,  // High Yield Secured Lending Maple Pool USDC1 101
        0x287233F22BA23F2934fC03385aF5cF761Bfa9c75,  // High Yield Secured Lending Maple Pool USDC1 201
        0x6D995973F22C18Ce413870BC865f0AA73B2B8810,  // High Yield Secured Lending Maple Pool USDC1 101
        0x84e72d17215c605b06E08a26dCBE221995549C58,  // High Yield Secured Lending Maple Pool USDC1 101
        0x869E450FD7c5239568b2a87964cF42Bf91D1C430,  // High Yield Secured Lending Maple Pool USDC1 101
        0x9eFCD695BC5261ec4CaDcc7CBA0a3D51B0AF1aE8,  // High Yield Secured Lending Maple Pool USDC1 101
        0xAd7EE604DE7D5d2AE81cEd0C220EC86A4702409c,  // High Yield Secured Lending Maple Pool USDC1 101
        0xb4CB9affB100506600C79cC6D8834Cc0D93e9C36,  // High Yield Secured Lending Maple Pool USDC1 101
        0xcC780873D96E03FE618B09538c7b38728942E11d,  // High Yield Secured Lending Maple Pool USDC1 101
        0xCDB19ac0092477e3C81E5cA8Fc9A8f65d8459C50,  // High Yield Secured Lending Maple Pool USDC1 201
        0xDB025Cc4238B84BfeB1b323D432de29e69e93Fde,  // High Yield Secured Lending Maple Pool USDC1 200
        0xA025a8b4d06619B38b87b5BdF2cF3EF40D1aBede,  // Maple Lend + Long USDC2 201
        0x05221299F05D04Fad6ca95f431223B330ae8B5F7,  // High Yield Corporate Loan Maple Pool WETH1 201
        0x29356F80d6016583C03991Cda7Dd42259517c005,  // AQRU Maple Pool USDC1 101
        0x51d8cd0f68f3A9D4ab7Ce4062bc89B5C47A96818,  // AQRU Maple Pool USDC1 101
        0xf2FDA7D97CF9920E0857Ec60416eD0006ea610f9   // AQRU Maple Pool USDC1 101
    ];

}
