// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { AddressRegistry, Test } from "../../contracts/Contracts.sol";

import { FixedTermLoanHealthChecker } from "./FixedTermLoanHealthChecker.sol";
import { LPHealthChecker }            from "./LPHealthChecker.sol";
import { OpenTermLoanHealthChecker }  from "./OpenTermLoanHealthChecker.sol";
import { ProtocolHealthChecker }      from "./ProtocolHealthChecker.sol";

contract HealthCheckerMainnetTests is AddressRegistry, Test {

    address[] cashManagementUSDCLps = [
        0x03969341cd113Fb53b18414673fa24200CAFeb66,
        0x28EC3d03eED0a770bb4943846549738cf78BD990,
        0x2B72D6b9D1E63547A2fE8aDD3D982F250ccD0b2a,
        0x3295B00134a1Ca31f2cFB7FB381644D289009407,
        0x3c81F398f059d75FdA0D2AF11D62EBA204FECf3D,
        0x3FeA230F9dc9Ca2e1AaA471E8E9E83e8a3212a97,
        0x486467BA5FCD74943a308D9A8900B8d6B6272Ad4,
        0x561df751FcD725908AA74f4f7d0D1Cb324f5BC95,
        0x5Db0dC77F6E1Ad9dd959c60Da0D6F39c75e1C2E5,
        0x6a4d361B7d0daDF8146DcfE6258A8699ea35eB81,
        0x85b330c31C2FdE35Ca4B53c27EBFF8873B8E4aC1,
        0x86A07dDED024121b282362f4e7A249b00F5dAB37,
        0x938ca185a477868FbdC5AE29454a2Db5C32ae41F,
        0x94F98416CA0DC0310Bcaeda0e16903e19307539F,
        0xc6971260EfDfd0fFfC4fB6E9Fe18Faf2e2dE56d5,
        0xdc21a6BfcBD5B520B59C0cED9fe8231278706045,
        0x0000000000000000000000000000000000000000,  // bootstrap mint
        0x1146691782c089bCF0B19aCb8620943a35eebD12
    ];

    address[] mapleDirectUSDCLps = [
        0x0c209Cc80faA42031484621788Ef97CB1A9C917e,
        0x251119e2938485018b3862b767f40879B00EB577,
        0x329c2E91cD0db437021A70aa31C5E5a919125555,
        0x6a4d361B7d0daDF8146DcfE6258A8699ea35eB81,
        0x6D7F31cDbE68e947fAFaCad005f6495eDA04cB12,
        0x6E3fddab68Bf1EBaf9daCF9F7907c7Bc0951D1dc,
        0x7674C0ad7Cc25B1003104399F1Da46ebdEF787D5,
        0x9928C2751aff664Cec0a100F36bf2A31c5dcd8c7,
        0x9f412598c64585C2120849E76b8993948D175D0d,
        0xA7eFB5163163b07E75A5C1AC687D74b8bA68d3A0,
        0xa931b486F661540c6D709aE6DfC8BcEF347ea437,
        0xad4645dF2aF7B9bC79042aA7ec8D88ddd7933f8A,
        0xc337C76158c131beDf95a5D4e0C27EC8eFdb7f02,
        0xE0e37f5B35e653aE63B3D782A15b104cD834198b,
        0x0000000000000000000000000000000000000000  // bootstrap mint
    ];

    FixedTermLoanHealthChecker fixedTermHC;
    LPHealthChecker            lpHealthChecker_;
    OpenTermLoanHealthChecker  openTermHC;
    ProtocolHealthChecker      protocolHealthChecker_;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 19016556);

        lpHealthChecker_       = new LPHealthChecker();
        protocolHealthChecker_ = new ProtocolHealthChecker();
    }

    function testFork_lpHealthChecker_mainnet() public {
        _checkLPInvariants(cashUSDCPoolManager, cashManagementUSDCLps);
        _checkLPInvariants(blueChipSecuredUSDCPoolManager, mapleDirectUSDCLps);

        _checkProtocolInvariants(cashUSDCPoolManager);
        _checkProtocolInvariants(blueChipSecuredUSDCPoolManager);
    }

    function testFork_protocolHealthChecker_mainnet() public {
        _checkProtocolInvariants(cashUSDCPoolManager);
        _checkProtocolInvariants(blueChipSecuredUSDCPoolManager);
    }

    /**************************************************************************************************************************************/
    /*** Internal Functions                                                                                                             ***/
    /**************************************************************************************************************************************/

    function _checkProtocolInvariants(address poolManager_) internal {
        ProtocolHealthChecker.Invariants memory results;

        results = protocolHealthChecker_.checkInvariants(poolManager_);

        assertTrue(results.fixedTermLoanManagerInvariantA);
        assertTrue(results.fixedTermLoanManagerInvariantB);
        assertTrue(results.fixedTermLoanManagerInvariantF);
        assertTrue(results.fixedTermLoanManagerInvariantI);
        assertTrue(results.fixedTermLoanManagerInvariantJ);
        assertTrue(results.fixedTermLoanManagerInvariantK);
        assertTrue(results.openTermLoanManagerInvariantE);
        assertTrue(results.openTermLoanManagerInvariantG);
        assertTrue(results.poolInvariantA);
        assertTrue(results.poolInvariantD);
        assertTrue(results.poolInvariantE);
        assertTrue(results.poolInvariantI);
        assertTrue(results.poolInvariantJ);
        assertTrue(results.poolInvariantK);
        assertTrue(results.poolManagerInvariantA);
        assertTrue(results.poolManagerInvariantB);
        assertTrue(results.poolPermissionManagerInvariantA);
        assertTrue(results.withdrawalManagerCyclicalInvariantC);
        assertTrue(results.withdrawalManagerCyclicalInvariantD);
        assertTrue(results.withdrawalManagerCyclicalInvariantE);
        assertTrue(results.withdrawalManagerCyclicalInvariantM);
        assertTrue(results.withdrawalManagerCyclicalInvariantN);
        assertTrue(results.withdrawalManagerQueueInvariantA);
        assertTrue(results.withdrawalManagerQueueInvariantB);
        assertTrue(results.withdrawalManagerQueueInvariantD);
        assertTrue(results.withdrawalManagerQueueInvariantE);
        assertTrue(results.withdrawalManagerQueueInvariantF);
        assertTrue(results.withdrawalManagerQueueInvariantI);
    }

    function _checkLPInvariants(address poolManager_, address[] memory lenders_) internal {
        LPHealthChecker.Invariants memory results;

        results = lpHealthChecker_.checkInvariants(poolManager_, lenders_);

        assertTrue(results.poolInvariantB);
        assertTrue(results.poolInvariantG);
        assertTrue(results.withdrawalManagerCyclicalInvariantA);
        assertTrue(results.withdrawalManagerCyclicalInvariantB);
        assertTrue(results.withdrawalManagerCyclicalInvariantF);
        assertTrue(results.withdrawalManagerCyclicalInvariantG);
        assertTrue(results.withdrawalManagerCyclicalInvariantH);
        assertTrue(results.withdrawalManagerCyclicalInvariantI);
        assertTrue(results.withdrawalManagerCyclicalInvariantJ);
        assertTrue(results.withdrawalManagerCyclicalInvariantK);
        assertTrue(results.withdrawalManagerCyclicalInvariantL);
        assertTrue(results.withdrawalManagerQueueInvariantC);
        assertTrue(results.withdrawalManagerQueueInvariantG);
        assertTrue(results.withdrawalManagerQueueInvariantH);
    }

}
