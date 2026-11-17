# Maple V2 Core

![Foundry CI](https://github.com/maple-labs/maple-core-v2/actions/workflows/ci.yaml/badge.svg)
[![GitBook - Documentation](https://img.shields.io/badge/GitBook-Documentation-orange?logo=gitbook&logoColor=white)](https://docs.maple.finance/technical-resources/protocol-overview)
[![Foundry][foundry-badge]][foundry]
[![License: BUSL 1.1](https://img.shields.io/badge/License-BUSL%201.1-blue.svg)](https://github.com/maple-labs/maple-core-v2/blob/main/LICENSE)

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

## Overview

This repository brings together the core smart contracts of the Maple V2 protocol as submodules in
order to test and deploy them as a single system. It contains:

| Path | Contents |
|---|---|
| `modules/`     | The protocol contracts, pinned as git submodules. |
| `tests/`       | Integration, end-to-end, fuzz, invariant and protocol-upgrade test suites. |
| `scenarios/`   | CSV-driven pool lifecycle scenarios, converted to Solidity and run as tests. |
| `scripts/`     | Foundry deployment scripts (releases, governor timelock, withdrawal manager, health checkers). |
| `benchmarks/`  | Gas benchmarks. |
| `contracts/`   | Test-side helpers — versioned contract sets (`Contracts@N.sol`), protocol actions, interfaces. |
| `audits/`      | Audit reports, by engagement date. |

The protocol is deployed on multiple chains; RPC endpoints for mainnet, Base, Plasma, Mantle, Ink
and Monad are configured in `foundry.toml` under `[rpc_endpoints]`.

## Submodules

Note that several submodule directory names differ from their repository names.

| Directory | Repository |
|---|---|
| **Core** | |
| `modules/globals`                     | [`maple-labs/globals-v2`](https://github.com/maple-labs/globals-v2) |
| `modules/pool`                        | [`maple-labs/pool-v2`](https://github.com/maple-labs/pool-v2) |
| `modules/pool-permission-manager`     | [`maple-labs/pool-permission-manager`](https://github.com/maple-labs/pool-permission-manager) |
| **Loans** | |
| `modules/open-term-loan`              | [`maple-labs/open-term-loan`](https://github.com/maple-labs/open-term-loan) |
| `modules/open-term-loan-manager`      | [`maple-labs/open-term-loan-manager`](https://github.com/maple-labs/open-term-loan-manager) |
| **Withdrawals** | |
| `modules/withdrawal-manager-cyclical` | [`maple-labs/withdrawal-manager-cyclical`](https://github.com/maple-labs/withdrawal-manager-cyclical) |
| `modules/withdrawal-manager-queue`    | [`maple-labs/withdrawal-manager-queue`](https://github.com/maple-labs/withdrawal-manager-queue) |
| **Strategies** | |
| `modules/strategy-manager`            | [`maple-labs/strategy-manager`](https://github.com/maple-labs/strategy-manager) |
| `modules/defi-strategies`             | [`maple-labs/defi-strategies`](https://github.com/maple-labs/defi-strategies) |
| `modules/allocation-strategy`         | [`maple-labs/allocation-strategy`](https://github.com/maple-labs/allocation-strategy) |
| **Peripheral** | |
| `modules/syrup-utils`                 | [`maple-labs/syrup-utils`](https://github.com/maple-labs/syrup-utils) |
| `modules/address-registry`            | [`maple-labs/address-registry`](https://github.com/maple-labs/address-registry) |
| `modules/erc20`                       | [`maple-labs/erc20`](https://github.com/maple-labs/erc20) |
| `modules/erc20-helper`                | [`maple-labs/erc20-helper`](https://github.com/maple-labs/erc20-helper) |
| `modules/forge-std`                   | [`foundry-rs/forge-std`](https://github.com/foundry-rs/forge-std) |

Versions of dependencies can be checked with `git submodule status`.

## Setup

This project was built using [Foundry](https://book.getfoundry.sh/). Refer to installation
instructions [here](https://github.com/foundry-rs/foundry#installation).

Submodule URLs use SSH. To clone over HTTPS instead, run this first:

```sh
git config --global url."https://github.com/".insteadOf "git@github.com:"
```

```sh
git clone git@github.com:maple-labs/maple-core-v2.git
cd maple-core-v2
make install          # git submodule update --init --recursive
cp .env.example .env  # populate ETH_RPC_URL and ALCHEMY_API_KEY
make build
```

`ETH_RPC_URL` and `ALCHEMY_API_KEY` are needed by the suites that fork mainnet or an L2 — see
[Test Commands](#test-commands).

For generating contract interface docs from natspec, see
[`NATSPEC_DOC_GENERATION.md`](NATSPEC_DOC_GENERATION.md). Note that the module paths in that file
are out of date.

## Commands

To make it easier to perform some tasks within the repo, a few commands are available through a
makefile:

### Build Commands

| Command | Action |
|---|---|
| `make install`        | Initialize and update all submodules recursively. |
| `make update`         | Update submodules to their latest remote commits (`forge update`). |
| `make build`          | Compile all contracts in the repo, including submodules, with the `production` profile. |
| `make clean`          | Delete cached files. |
| `make slither-files`  | Generate the flattened files used for Slither analysis. |

### Test Commands

| Command | Description | Needs RPC |
|---|---|---|
| `make test`             | Run every test in `tests/`. | yes |
| `make integration`      | Run the integration tests in `tests/integration/`. | yes |
| `make protocol-upgrade` | Run the protocol upgrade tests in `tests/protocol-upgrade/`. | yes |
| `make e2e`              | Run the end-to-end tests in `tests/e2e/`. | some |
| `make fuzz`             | Run the fuzz tests in `tests/fuzz/`. | some |
| `make invariant`        | Run the invariant tests in `tests/invariants/`. | no |
| `make gas-benchmarks`   | Run the gas benchmarks in `benchmarks/`. | no |
| `make scenario-v2`      | Run the v2 scenarios found in `scenarios/v2/data/csv/`. | no |

Suites marked "needs RPC" fork mainnet or an L2 and require `ETH_RPC_URL` and `ALCHEMY_API_KEY` to
be set. Within the fuzz suite, only the fork-based setup (`tests/fuzz/FuzzedSetupFork.sol`) forks.

Specific tests can be run using `forge test` conventions, specified in more detail in the Foundry
[Book](https://www.getfoundry.sh/reference/forge/test#forge-test).

#### Profiles

The test targets accept a `profile` variable, which sets `FOUNDRY_PROFILE` for the run:

```sh
make fuzz profile=deep
make integration profile=production
```

| Profile | Effect |
|---|---|
| `default`        | Optimizer off. Fuzz: 100 runs. Invariants: 10 runs × depth 100. |
| `production`     | Optimizer on, 200 runs. |
| `deep`           | Optimizer on. Fuzz: 500 runs. Invariants: 10 runs × depth 250. |
| `super_deep`     | Optimizer on. Fuzz: 5,000 runs. Invariants: 200 runs × depth 250. |
| `gas_benchmarks` | Optimizer on, isolated execution, test directory `benchmarks/`. |
| `scenarios`      | Test directory `scenarios/`, with filesystem read permissions. |

CI (`.github/workflows/ci.yaml`) uses `default` / `deep` on pull requests and `production` /
`super_deep` on pushes to `main`.

### Deployment Commands

| Command | Description |
|---|---|
| `make deploy`                 | Run `deploy.sh`. Every script in it is commented out by default — uncomment the one to run and add `--broadcast` when sending. |
| `make validate step=<Step>`   | Run the `Validate<Step>` script against `ETH_RPC_URL`. |
| `make validateLocal step=<Step>` | Run the `Validate<Step>` script against a local node on `localhost:8545`. |
| `make doLocal step=<Step>`    | Run and broadcast the `Do<Step>` script against a local node, with unlocked accounts. |
| `make deal to=<address>`      | Fund an address with 10,000 ETH on a local Anvil node. |

### Contract Verification Script

```shell
$ ./verify.sh -i "NETWORK_NAME" -k "ETHERSCAN_API_KEY" -a "CONTRACT_ADDRESS" -c "RELATIVE_PATH_TO_CONTRACT_FILE:CONTRACT_NAME" -s "CONSTRUCTOR_SIGNATURE" -g "CONSTRUCTOR_ARGUMENTS_SPACE_DELIMITED"
```

For example:

```shell
$ ./verify.sh -i "mainnet" -k "$ETHERSCAN_API_KEY" -a "0xA756055900D13d62350a882334e5BD196987adcb" -c "./modules/open-term-loan-manager/contracts/MapleLoanManagerFactory.sol:MapleLoanManagerFactory" -s "constructor(address)" -g "0x421c8914B602C4a6A6aec7b4c5F90B9FF5Ef90c6"
```

## Audit Reports

All reports are in [`audits/`](audits), organised by engagement date. Reports scoped to a single
component rather than the whole protocol are marked as such.

| Date | Auditor | Report |
|---|---|---|
| 2026-10 | Cantina       | [Cantina - October 2026 (Modular Release)](audits/2026-november/Cantina-Maple-Finance-Modular-Oct-2026.pdf) |
| 2026-09 | Sherlock      | [Sherlock - September 2026 (Modular Release)](audits/2026-november/Sherlock-Maple-Finance-Modular-Sep-2026.pdf) |
| 2025-11 | Sherlock      | [Sherlock - November 2025 (Withdrawal Manager)](audits/2025-november/Sherlock-Maple-Finance-WM-Nov-2025.pdf) |
| 2025-11 | Spearbit      | [Spearbit - November 2025 (Withdrawal Manager)](audits/2025-november/Spearbit-Maple-Finance-WM-Nov-2025.pdf) |
| 2025-09 | 0xMacro       | [0xMacro - September 2025 (Governor Timelock)](audits/2025-sept-governor-timelock/0xMacro-Maple-Finance-timelock-Sept-2025.pdf) |
| 2025-09 | Sherlock      | [Sherlock - September 2025 (Governor Timelock)](audits/2025-sept-governor-timelock/Sherlock-Maple-Finance-timelock-Sept-2025.pdf) |
| 2024-12 | 0xMacro       | [0xMacro - December 2024](audits/2024-december/0xMacro-Maple-Finance-Dec-2024.pdf) |
| 2024-12 | Three Sigma   | [Three Sigma - December 2024](audits/2024-december/Three-Sigma-Maple-Finance-Dec-2024%20.pdf) |
| 2024-08 | 0xMacro       | [0xMacro - August 2024](audits/2024-august/0xMacro-Maple-Finance-Aug-2024.pdf) |
| 2024-08 | Three Sigma   | [Three Sigma - August 2024](audits/2024-august/Three-Sigma-Maple-Finance-Aug-2024.pdf) |
| 2024-08 | Three Sigma   | [Three Sigma - August 2024 (Syrup)](audits/2024-august/Three-Sigma-Maple-Finance-Aug-2024-Syrup.pdf) |
| 2023-12 | 0xMacro       | [0xMacro - December 2023](audits/2023-december/0xMacro-Maple-Finance-Dec-2023.pdf) |
| 2023-12 | Three Sigma   | [Three Sigma - December 2023](audits/2023-december/Three-Sigma-Maple-Finance-Dec-2023.pdf) |
| 2023-06 | Cantina       | [Cantina - June 2023](audits/2023-june/Cantina-Maple.pdf) |
| 2023-06 | Three Sigma   | [Three Sigma - June 2023](audits/2023-june/Three-Sigma-Maple-Finance-Jun-2023.pdf) |
| 2022-12 | Trail of Bits | [Trail of Bits - December 2022](audits/2022-december/TrailOfBits-Maple.pdf) |
| 2022-12 | Spearbit      | [Spearbit - December 2022](audits/2022-december/Spearbit-maple.pdf) |
| 2022-12 | Three Sigma   | [Three Sigma - December 2022](audits/2022-december/Three-Sigma-Maple-Finance-Dec-2022.pdf) |

## Bug Bounty

For all information related to the ongoing bug bounty for these contracts run by [Immunefi](https://immunefi.com/), please visit this [site](https://immunefi.com/bounty/maple/).

## About Maple

[Maple Finance](https://maple.finance/) is a decentralized corporate credit market. Maple provides capital to institutional borrowers through globally accessible fixed-income yield opportunities.

---

<p align="center">
  <img src="https://github.com/maple-labs/maple-metadata/blob/796e313f3b2fd4960929910cd09a9716688a4410/assets/maplelogo.png" height="100" />
</p>
