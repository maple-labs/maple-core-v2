// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import { console as console, Test } from "../../../contracts/Runner.sol";

import { IGovernorTimelock, ISyrupUSDCrossChainLike } from "../../../contracts/interfaces/Interfaces.sol";

import { UpgradeAddressRegistry } from "../UpgradeAddressRegistry.sol";

contract CCIPUpgradeValidationScriptBase is UpgradeAddressRegistry, Test {

    bytes32 constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");

    uint256 constant MINTER_PROPOSAL_ID = 4;
    uint256 constant BURNER_PROPOSAL_ID = 5;

    address constant TOKEN_POOL_ARBITRUM  = 0x3d15345Abe64d51e85e49DAf2DFa46175AEB5097;
    address constant TOKEN_POOL_BASE      = 0x3b916abC1811c9e1C69B41bF469733A0B2d1e05C;
    address constant TOKEN_POOL_INK       = 0xeaF5B8241D843439994725CFB21b98d726d21D8e;
    address constant TOKEN_POOL_MONAD     = 0x76E1D575363ECEf97d02F58884638c7154f4454c;
    address constant TOKEN_POOL_ROBINHOOD = 0xBFE1826919A643fE20913447e126Aa2720436931;
    address constant TOKEN_POOL_TEMPO     = 0xB72B8cf2b626B7766FE448be2C40a2633Dce4dBE;

    function _proposalHash(address target, bytes memory calldata_) internal pure returns (bytes32) {
        return keccak256(abi.encode(target, calldata_));
    }

}

contract ValidateRoleSchedulingBase is CCIPUpgradeValidationScriptBase {

    IGovernorTimelock tl = IGovernorTimelock(timelockBase);

    ISyrupUSDCrossChainLike token = ISyrupUSDCrossChainLike(syrupUSDCBase);

    bytes32 minterProposalHash =
        _proposalHash(syrupUSDCBase, abi.encodeWithSignature("grantRole(bytes32,address)", MINTER_ROLE, TOKEN_POOL_BASE));

    bytes32 burnerProposalHash =
        _proposalHash(syrupUSDCBase, abi.encodeWithSignature("grantRole(bytes32,address)", BURNER_ROLE, TOKEN_POOL_BASE));

    function run() external view {
        assertEq(token.MINTER_ROLE(), MINTER_ROLE, "Invalid minter role!");
        assertEq(token.BURNER_ROLE(), BURNER_ROLE, "Invalid burner role!");

        assertEq(token.hasRole(token.DEFAULT_ADMIN_ROLE(), timelockBase), true, "Timelock is not the default admin!");

        assertEq(token.hasRole(MINTER_ROLE, TOKEN_POOL_BASE), false, "Token pool is already a minter!");
        assertEq(token.hasRole(BURNER_ROLE, TOKEN_POOL_BASE), false, "Token pool is already a burner!");

        assertEq(tl.latestProposalId(), BURNER_PROPOSAL_ID, "Invalid latest proposal id!");

        (bytes32 proposalHash, bool isUnschedulable, uint32 scheduledAt, uint32 delayedUntil, uint32 validUntil) =
            tl.proposals(MINTER_PROPOSAL_ID);

        uint32 batchTimestamp = scheduledAt;

        assertEq(proposalHash,    minterProposalHash,            "Invalid proposal hash! (id: 4)");
        assertEq(isUnschedulable, true,                          "Proposal is not unschedulable! (id: 4)");
        assertEq(delayedUntil,    scheduledAt + 3 days,          "Invalid execution window! (id: 4)");
        assertEq(validUntil,      scheduledAt + 3 days + 2 days, "Invalid execution window! (id: 4)");

        (proposalHash, isUnschedulable, scheduledAt, delayedUntil, validUntil) = tl.proposals(BURNER_PROPOSAL_ID);

        assertEq(proposalHash,    burnerProposalHash,            "Invalid proposal hash! (id: 5)");
        assertEq(isUnschedulable, true,                          "Proposal is not unschedulable! (id: 5)");
        assertEq(scheduledAt,     batchTimestamp,                "Invalid proposal date! (id: 5)");
        assertEq(delayedUntil,    scheduledAt + 3 days,          "Invalid execution window! (id: 5)");
        assertEq(validUntil,      scheduledAt + 3 days + 2 days, "Invalid execution window! (id: 5)");
    }

}

contract ValidateRoleExecutionBase is CCIPUpgradeValidationScriptBase {

    IGovernorTimelock tl = IGovernorTimelock(timelockBase);

    ISyrupUSDCrossChainLike token = ISyrupUSDCrossChainLike(syrupUSDCBase);

    function run() external view {
        assertEq(token.MINTER_ROLE(), MINTER_ROLE, "Invalid minter role!");
        assertEq(token.BURNER_ROLE(), BURNER_ROLE, "Invalid burner role!");

        assertEq(token.hasRole(token.DEFAULT_ADMIN_ROLE(), timelockBase), true, "Timelock is not the default admin!");

        assertEq(token.hasRole(MINTER_ROLE, TOKEN_POOL_BASE), true, "Token pool is not a minter!");
        assertEq(token.hasRole(BURNER_ROLE, TOKEN_POOL_BASE), true, "Token pool is not a burner!");

        assertEq(tl.latestProposalId(), BURNER_PROPOSAL_ID, "Invalid latest proposal id!");

        (bytes32 proposalHash,,,,) = tl.proposals(MINTER_PROPOSAL_ID);

        assertEq(proposalHash, bytes32(0), "Proposal was not executed! (id: 4)");

        (proposalHash,,,,) = tl.proposals(BURNER_PROPOSAL_ID);

        assertEq(proposalHash, bytes32(0), "Proposal was not executed! (id: 5)");
    }

}

contract ValidateRoleSchedulingInk is CCIPUpgradeValidationScriptBase {

    IGovernorTimelock tl = IGovernorTimelock(timelockInk);

    ISyrupUSDCrossChainLike token = ISyrupUSDCrossChainLike(syrupUSDCInk);

    bytes32 minterProposalHash =
        _proposalHash(syrupUSDCInk, abi.encodeWithSignature("grantRole(bytes32,address)", MINTER_ROLE, TOKEN_POOL_INK));

    bytes32 burnerProposalHash =
        _proposalHash(syrupUSDCInk, abi.encodeWithSignature("grantRole(bytes32,address)", BURNER_ROLE, TOKEN_POOL_INK));

    function run() external view {
        assertEq(token.MINTER_ROLE(), MINTER_ROLE, "Invalid minter role!");
        assertEq(token.BURNER_ROLE(), BURNER_ROLE, "Invalid burner role!");

        assertEq(token.hasRole(token.DEFAULT_ADMIN_ROLE(), timelockInk), true, "Timelock is not the default admin!");

        assertEq(token.hasRole(MINTER_ROLE, TOKEN_POOL_INK), false, "Token pool is already a minter!");
        assertEq(token.hasRole(BURNER_ROLE, TOKEN_POOL_INK), false, "Token pool is already a burner!");

        assertEq(tl.latestProposalId(), BURNER_PROPOSAL_ID, "Invalid latest proposal id!");

        (bytes32 proposalHash, bool isUnschedulable, uint32 scheduledAt, uint32 delayedUntil, uint32 validUntil) =
            tl.proposals(MINTER_PROPOSAL_ID);

        uint32 batchTimestamp = scheduledAt;

        assertEq(proposalHash,    minterProposalHash,            "Invalid proposal hash! (id: 4)");
        assertEq(isUnschedulable, true,                          "Proposal is not unschedulable! (id: 4)");
        assertEq(delayedUntil,    scheduledAt + 3 days,          "Invalid execution window! (id: 4)");
        assertEq(validUntil,      scheduledAt + 3 days + 2 days, "Invalid execution window! (id: 4)");

        (proposalHash, isUnschedulable, scheduledAt, delayedUntil, validUntil) = tl.proposals(BURNER_PROPOSAL_ID);

        assertEq(proposalHash,    burnerProposalHash,            "Invalid proposal hash! (id: 5)");
        assertEq(isUnschedulable, true,                          "Proposal is not unschedulable! (id: 5)");
        assertEq(scheduledAt,     batchTimestamp,                "Invalid proposal date! (id: 5)");
        assertEq(delayedUntil,    scheduledAt + 3 days,          "Invalid execution window! (id: 5)");
        assertEq(validUntil,      scheduledAt + 3 days + 2 days, "Invalid execution window! (id: 5)");
    }

}

contract ValidateRoleExecutionInk is CCIPUpgradeValidationScriptBase {

    IGovernorTimelock tl = IGovernorTimelock(timelockInk);

    ISyrupUSDCrossChainLike token = ISyrupUSDCrossChainLike(syrupUSDCInk);

    function run() external view {
        assertEq(token.MINTER_ROLE(), MINTER_ROLE, "Invalid minter role!");
        assertEq(token.BURNER_ROLE(), BURNER_ROLE, "Invalid burner role!");

        assertEq(token.hasRole(token.DEFAULT_ADMIN_ROLE(), timelockInk), true, "Timelock is not the default admin!");

        assertEq(token.hasRole(MINTER_ROLE, TOKEN_POOL_INK), true, "Token pool is not a minter!");
        assertEq(token.hasRole(BURNER_ROLE, TOKEN_POOL_INK), true, "Token pool is not a burner!");

        assertEq(tl.latestProposalId(), BURNER_PROPOSAL_ID, "Invalid latest proposal id!");

        (bytes32 proposalHash,,,,) = tl.proposals(MINTER_PROPOSAL_ID);

        assertEq(proposalHash, bytes32(0), "Proposal was not executed! (id: 4)");

        (proposalHash,,,,) = tl.proposals(BURNER_PROPOSAL_ID);

        assertEq(proposalHash, bytes32(0), "Proposal was not executed! (id: 5)");
    }

}

contract ValidateRoleSchedulingMonad is CCIPUpgradeValidationScriptBase {

    IGovernorTimelock tl = IGovernorTimelock(timelockMonad);

    ISyrupUSDCrossChainLike token = ISyrupUSDCrossChainLike(syrupUSDCMonad);

    bytes32 minterProposalHash =
        _proposalHash(syrupUSDCMonad, abi.encodeWithSignature("grantRole(bytes32,address)", MINTER_ROLE, TOKEN_POOL_MONAD));

    bytes32 burnerProposalHash =
        _proposalHash(syrupUSDCMonad, abi.encodeWithSignature("grantRole(bytes32,address)", BURNER_ROLE, TOKEN_POOL_MONAD));

    function run() external view {
        assertEq(token.MINTER_ROLE(), MINTER_ROLE, "Invalid minter role!");
        assertEq(token.BURNER_ROLE(), BURNER_ROLE, "Invalid burner role!");

        assertEq(token.hasRole(token.DEFAULT_ADMIN_ROLE(), timelockMonad), true, "Timelock is not the default admin!");

        assertEq(token.hasRole(MINTER_ROLE, TOKEN_POOL_MONAD), false, "Token pool is already a minter!");
        assertEq(token.hasRole(BURNER_ROLE, TOKEN_POOL_MONAD), false, "Token pool is already a burner!");

        assertEq(tl.latestProposalId(), BURNER_PROPOSAL_ID, "Invalid latest proposal id!");

        (bytes32 proposalHash, bool isUnschedulable, uint32 scheduledAt, uint32 delayedUntil, uint32 validUntil) =
            tl.proposals(MINTER_PROPOSAL_ID);

        uint32 batchTimestamp = scheduledAt;

        assertEq(proposalHash,    minterProposalHash,            "Invalid proposal hash! (id: 4)");
        assertEq(isUnschedulable, true,                          "Proposal is not unschedulable! (id: 4)");
        assertEq(delayedUntil,    scheduledAt + 3 days,          "Invalid execution window! (id: 4)");
        assertEq(validUntil,      scheduledAt + 3 days + 2 days, "Invalid execution window! (id: 4)");

        (proposalHash, isUnschedulable, scheduledAt, delayedUntil, validUntil) = tl.proposals(BURNER_PROPOSAL_ID);

        assertEq(proposalHash,    burnerProposalHash,            "Invalid proposal hash! (id: 5)");
        assertEq(isUnschedulable, true,                          "Proposal is not unschedulable! (id: 5)");
        assertEq(scheduledAt,     batchTimestamp,                "Invalid proposal date! (id: 5)");
        assertEq(delayedUntil,    scheduledAt + 3 days,          "Invalid execution window! (id: 5)");
        assertEq(validUntil,      scheduledAt + 3 days + 2 days, "Invalid execution window! (id: 5)");
    }

}

contract ValidateRoleExecutionMonad is CCIPUpgradeValidationScriptBase {

    IGovernorTimelock tl = IGovernorTimelock(timelockMonad);

    ISyrupUSDCrossChainLike token = ISyrupUSDCrossChainLike(syrupUSDCMonad);

    function run() external view {
        assertEq(token.MINTER_ROLE(), MINTER_ROLE, "Invalid minter role!");
        assertEq(token.BURNER_ROLE(), BURNER_ROLE, "Invalid burner role!");

        assertEq(token.hasRole(token.DEFAULT_ADMIN_ROLE(), timelockMonad), true, "Timelock is not the default admin!");

        assertEq(token.hasRole(MINTER_ROLE, TOKEN_POOL_MONAD), true, "Token pool is not a minter!");
        assertEq(token.hasRole(BURNER_ROLE, TOKEN_POOL_MONAD), true, "Token pool is not a burner!");

        assertEq(tl.latestProposalId(), BURNER_PROPOSAL_ID, "Invalid latest proposal id!");

        (bytes32 proposalHash,,,,) = tl.proposals(MINTER_PROPOSAL_ID);

        assertEq(proposalHash, bytes32(0), "Proposal was not executed! (id: 4)");

        (proposalHash,,,,) = tl.proposals(BURNER_PROPOSAL_ID);

        assertEq(proposalHash, bytes32(0), "Proposal was not executed! (id: 5)");
    }

}

contract ValidateRoleGrantArbitrum is CCIPUpgradeValidationScriptBase {

    ISyrupUSDCrossChainLike token = ISyrupUSDCrossChainLike(syrupUSDCArbitrum);

    function run() external view {
        assertEq(token.MINTER_ROLE(), MINTER_ROLE, "Invalid minter role!");
        assertEq(token.BURNER_ROLE(), BURNER_ROLE, "Invalid burner role!");

        assertEq(token.hasRole(token.DEFAULT_ADMIN_ROLE(), syrupUSDCArbitrumDefaultAdmin), true, "Safe is not the default admin!");

        assertEq(token.hasRole(MINTER_ROLE, TOKEN_POOL_ARBITRUM), true, "Token pool is not a minter!");
        assertEq(token.hasRole(BURNER_ROLE, TOKEN_POOL_ARBITRUM), true, "Token pool is not a burner!");
    }

}

contract ValidateRoleGrantRobinhood is CCIPUpgradeValidationScriptBase {

    ISyrupUSDCrossChainLike token = ISyrupUSDCrossChainLike(syrupUSDCRobinhood);

    function run() external view {
        assertEq(token.MINTER_ROLE(), MINTER_ROLE, "Invalid minter role!");
        assertEq(token.BURNER_ROLE(), BURNER_ROLE, "Invalid burner role!");

        assertEq(token.hasRole(token.DEFAULT_ADMIN_ROLE(), syrupUSDCRobinhoodDefaultAdmin), true, "Safe is not the default admin!");

        assertEq(token.hasRole(MINTER_ROLE, TOKEN_POOL_ROBINHOOD), true, "Token pool is not a minter!");
        assertEq(token.hasRole(BURNER_ROLE, TOKEN_POOL_ROBINHOOD), true, "Token pool is not a burner!");
    }

}

contract ValidateRoleGrantTempo is CCIPUpgradeValidationScriptBase {

    ISyrupUSDCrossChainLike token = ISyrupUSDCrossChainLike(syrupUSDCTempo);

    function run() external view {
        assertEq(token.hasRole(token.DEFAULT_ADMIN_ROLE(), syrupUSDCTempoDefaultAdmin), true, "Safe is not the default admin!");

        assertEq(token.hasRole(ISSUER_ROLE, TOKEN_POOL_TEMPO), true, "Token pool is not an issuer!");
    }

}
