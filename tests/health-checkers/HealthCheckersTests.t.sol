// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { ProtocolUpgradeBase }       from "../protocol-upgrade/ProtocolUpgradeBase.sol";
import { UpgradeAddressRegistryETH } from "../protocol-upgrade/UpgradeAddressRegistryETH.sol";

import { ProtocolHealthChecker } from "./ProtocolHealthChecker.sol";

import { OpenTermLoanHealthChecker } from "./OpenTermLoanHealthChecker.sol";

import { FixedTermLoanHealthChecker } from "./FixedTermLoanHealthChecker.sol";

import { LPHealthChecker } from "./LPHealthChecker.sol";

// TODO: Update post upgrade to use AddressRegistry and Test for inheritance
contract HealthCheckerMainnetTests is ProtocolUpgradeBase, UpgradeAddressRegistryETH {

    address[] cashManagementUSDCLps = [
        0x08D64d365Bf7BF47869E0e5e95Ef07bFEbA6152a,
        0x184e46651946B861654436027bffdC97f9a45079,
        0x1Cb7F3EaB52BbE5F6635378b09d4856FB43FF7bE,
        0x2425809c5e907d46d0F1d1b25C8458A40368b3AD,
        0x28EC3d03eED0a770bb4943846549738cf78BD990,
        0x2B72D6b9D1E63547A2fE8aDD3D982F250ccD0b2a,
        0x3295B00134a1Ca31f2cFB7FB381644D289009407,
        0x3410bfe770C08457Ca29B5b69C39dB4A697AA892,
        0x3c81F398f059d75FdA0D2AF11D62EBA204FECf3D,
        0x3FeA230F9dc9Ca2e1AaA471E8E9E83e8a3212a97,
        0x426B93769dac3357254fcae28a032Cef54870B4A,
        0x486467BA5FCD74943a308D9A8900B8d6B6272Ad4,
        0x509b302E20b24e33710B51056A0f815808261181,
        0x561df751FcD725908AA74f4f7d0D1Cb324f5BC95,
        0x5a0F7dbDD1AB03ab5Bd35D9211a2f9DB4e1D3d42,
        0x5Db0dC77F6E1Ad9dd959c60Da0D6F39c75e1C2E5,
        0x675D786f754577825eA39d30708a709205A4ddbd,
        0x6a1485fB832e98fdBd839a116e187cfbC9065B9b,
        0x6a4d361B7d0daDF8146DcfE6258A8699ea35eB81,
        0x6b7873Ba6D71D9c3478F8F9b1D6cE3fB3662C063,
        0x7674C0ad7Cc25B1003104399F1Da46ebdEF787D5,
        0x82886Ad5e67d5142d44eD1449c2E41B988BFc0ab,
        0x85b330c31C2FdE35Ca4B53c27EBFF8873B8E4aC1,
        0x86A07dDED024121b282362f4e7A249b00F5dAB37,
        0x938ca185a477868FbdC5AE29454a2Db5C32ae41F,
        0x93C740b81ce34958B7203C8e50bFBa335C36e7A7,
        0x94F98416CA0DC0310Bcaeda0e16903e19307539F,
        0x99C941636A7E9fCF1FC3b27E142825cbBDC064d5,
        0xa931b486F661540c6D709aE6DfC8BcEF347ea437,
        0xad4645dF2aF7B9bC79042aA7ec8D88ddd7933f8A,
        0xbB432C675F74C784723c38eaFe216Cc62b3dC38D,
        0xBbA4C8eB57DF16c4CfAbe4e9A3Ab697A3e0C65D8,
        0xC09bD180ba12b837d4A0Ca163025FB5F8f86d711,
        0xc6971260EfDfd0fFfC4fB6E9Fe18Faf2e2dE56d5,
        0x0000000000000000000000000000000000000000,  // bootstrap mint
        cashManagementUSDCWithdrawalManager
    ];

    address[] mapleDirectUSDCLps = [
        0x0b3F0255a2B74392A60A1F4EdAD1345c2438D02e,
        0x0c209Cc80faA42031484621788Ef97CB1A9C917e,
        0x251119e2938485018b3862b767f40879B00EB577,
        0x329c2E91cD0db437021A70aa31C5E5a919125555,
        0x3410bfe770C08457Ca29B5b69C39dB4A697AA892,
        0x6a4d361B7d0daDF8146DcfE6258A8699ea35eB81,
        0x6D7F31cDbE68e947fAFaCad005f6495eDA04cB12,
        0x6E3fddab68Bf1EBaf9daCF9F7907c7Bc0951D1dc,
        0x7674C0ad7Cc25B1003104399F1Da46ebdEF787D5,
        0x94F98416CA0DC0310Bcaeda0e16903e19307539F,
        0x9f412598c64585C2120849E76b8993948D175D0d,
        0xA7eFB5163163b07E75A5C1AC687D74b8bA68d3A0,
        0xa931b486F661540c6D709aE6DfC8BcEF347ea437,
        0xad4645dF2aF7B9bC79042aA7ec8D88ddd7933f8A,
        0xC09bD180ba12b837d4A0Ca163025FB5F8f86d711,
        0xE0e37f5B35e653aE63B3D782A15b104cD834198b,
        0x0000000000000000000000000000000000000000  // bootstrap mint
    ];

    FixedTermLoanHealthChecker fixedTermHC;
    OpenTermLoanHealthChecker  openTermHC;
    LPHealthChecker            lpHealthChecker_;
    ProtocolHealthChecker      protocolHealthChecker_;

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 18723285);

        protocolHealthChecker_ = new ProtocolHealthChecker();

        lpHealthChecker_ = new LPHealthChecker();
    }

    function testFork_lpHealthChecker_mainnet() public {
        upgradeAndSetupPools();

        _checkLPInvariants(cashManagementUSDCPoolManager, cashManagementUSDCLps);

        _checkLPInvariants(mapleDirectUSDCPoolManager, mapleDirectUSDCLps);

        _checkProtocolInvariants(cashManagementUSDCPoolManager);

        _checkProtocolInvariants(mapleDirectUSDCPoolManager);
    }

    function testFork_protocolHealthChecker_mainnet() public {
        upgradeAndSetupPools();

        _checkProtocolInvariants(cashManagementUSDCPoolManager);

        _checkProtocolInvariants(mapleDirectUSDCPoolManager);
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

    function appendLpsToCashManagementUSDCLpsArray(address[] memory lps_) internal {
        for (uint256 i; i < lps_.length; i++) {
            cashManagementUSDCLps.push(lps_[i]);
        }
    }

    function upgradeAndSetupPools() internal {
        address[] memory lps;

        _performProtocolUpgrade();

        _upgradeToQueueWM(governor, globals, cashManagementUSDCPoolManager);

        lps = _approveAndAddLpsToQueueWM(cashManagementUSDCPoolManager);

        appendLpsToCashManagementUSDCLpsArray(lps);
    }

}
