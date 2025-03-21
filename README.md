# Maple V2 Core

![Foundry CI](https://github.com/maple-labs/maple-core-v2/actions/workflows/ci.yaml/badge.svg)
[![GitBook - Documentation](https://img.shields.io/badge/GitBook-Documentation-orange?logo=gitbook&logoColor=white)](https://maplefinance.gitbook.io/maple/maple-for-developers/protocol-overview)
[![Foundry][foundry-badge]][foundry]
[![License: BUSL 1.1](https://img.shields.io/badge/License-BUSL%201.1-blue.svg)](https://github.com/maple-labs/maple-core-v2/blob/main/LICENSE)

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

## Overview

This repository brings together the core smart contracts of the Maple V2 protocol as dependencies in order to perform integration tests and simulations.

## Submodules

Submodules imported:
- [`maple-labs/forge-std` (for testing)](https://github.com/maple-labs/forge-std)
- [`maple-labs/address-registry`](https://github.com/maple-labs/address-registry)
- [`maple-labs/erc20`](https://github.com/maple-labs/erc20)
- [`maple-labs/erc20-helper`](https://github.com/maple-labs/erc20-helper)
- [`maple-labs/globals-v2`](https://github.com/maple-labs/globals-v2)
- [`maple-labs/liquidations`](https://github.com/maple-labs/liquidations)
- [`maple-labs/fixed-term-loan`](https://github.com/maple-labs/fixed-term-loan)
- [`maple-labs/fixed-term-loan-manager`](https://github.com/maple-labs/fixed-term-loan-manager)
- [`maple-labs/open-term-loan`](https://github.com/maple-labs/open-term-loan)
- [`maple-labs/open-term-loan-manager`](https://github.com/maple-labs/open-term-loan-manager)
- [`maple-labs/pool-v2`](https://github.com/maple-labs/pool-v2)
- [`maple-labs/pool-permission-manager`](https://github.com/maple-labs/pool-permission-manager)
- [`maple-labs/withdrawal-manager-cyclical`](https://github.com/maple-labs/withdrawal-manager-cyclical)
- [`maple-labs/withdrawal-manager-queue`](https://github.com/maple-labs/withdrawal-manager-queue)
- [`maple-labs/strategies`](https://github.com/maple-labs/strategies)
- [`maple-labs/syrup-utils`](https://github.com/maple-labs/syrup-utils)

Versions of dependencies can be checked with `git submodule status`.

## Setup

This project was built using [Foundry](https://book.getfoundry.sh/). Refer to installation instructions [here](https://github.com/foundry-rs/foundry#installation).

```sh
git clone git@github.com:maple-labs/maple-core-v2.git
cd maple-core-v2
forge install
```

## Commands
To make it easier to perform some tasks within the repo, a few commands are available through a makefile:

### Build Commands

| Command | Action |
|---|---|
| `make build`       | Compile all contracts in the repo, including submodules. |
| `make clean`       | Delete cached files. |

### Test Commands

| Command | Description |
|---|---|
| `make test`        | Run all tests located in `contracts/tests/`. |
| `make e2e`         | Run all end-to-end tests. |
| `make fuzz`        | Run all fuzz tests. |
| `make integration` | Run all integration tests (Must have `ETH_RPC_URL` configured to mainnet). |
| `make invariant`   | Run the invariant tests. |

Specific tests can be run using `forge test` conventions, specified in more detail in the Foundry [Book](https://book.getfoundry.sh/reference/forge/forge-test#test-options).

### Scenario Commands

| Command | Description |
|---|---|
| `make scenario` | Run the scenarios found in `./scenarios/data/csv/` |

## Audit Reports

All audit reports can be found at [https://github.com/maple-labs/maple-core-v2/tree/main/audits](https://github.com/maple-labs/maple-core-v2/tree/main/audits)

## Bug Bounty

For all information related to the ongoing bug bounty for these contracts run by [Immunefi](https://immunefi.com/), please visit this [site](https://immunefi.com/bounty/maple/).

## About Maple

[Maple Finance](https://maple.finance/) is a decentralized corporate credit market. Maple provides capital to institutional borrowers through globally accessible fixed-income yield opportunities.

---

<p align="center">
  <img src="https://user-images.githubusercontent.com/44272939/196706799-fe96d294-f700-41e7-a65f-2d754d0a6eac.gif" height="100" />
</p>
