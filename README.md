# Maple V2 Core

![Foundry CI](https://github.com/maple-labs/maple-core-v2/actions/workflows/forge.yaml/badge.svg)
[![GitBook - Documentation](https://img.shields.io/badge/GitBook-Documentation-orange?logo=gitbook&logoColor=white)](https://maplefinance.gitbook.io/maple/technical-resources/protocol-overview)
[![Foundry][foundry-badge]][foundry]
[![License: BUSL 1.1](https://img.shields.io/badge/License-BUSL%201.1-blue.svg)](https://github.com/maple-labs/maple-core-v2/blob/main/LICENSE)

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

## Overview

This repository brings together the core smart contracts of the Maple V2 protocol as dependencies in order to perform integration tests and simulations.

## Submodules

This repository uses git submodules to manage dependencies which can be checked with `git submodule status`.

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
| `make build` | Compile all contracts in the repo, including submodules. |
| `make clean` | Delete cached files. |

### Test Commands

| Command | Description |
|---|---|
| `make test`        | Run all tests located in `contracts/tests/`. |
| `make e2e`         | Run all end-to-end tests. |
| `make fuzz`        | Run all fuzz tests. |
| `make integration` | Run all integration tests (Must have `ETH_RPC_URL` configured to mainnet). |
| `make invariant`   | Run the invariant tests. |

Specific tests can be run using `forge test` conventions, specified in more detail in the Foundry [Book](https://book.getfoundry.sh/reference/forge/forge-test#test-options).


## Audit Reports

### December 2022 Release

| Auditor | Report Link |
|---|---|
| Trail of Bits | [`2022-08-24 - Trail of Bits Report`](https://docs.google.com/viewer?url=https://github.com/maple-labs/maple-v2-audits/files/10246688/Maple.Finance.v2.-.Final.Report.-.Fixed.-.2022.pdf) |
| Spearbit | [`2022-10-17 - Spearbit Report`](https://docs.google.com/viewer?url=https://github.com/maple-labs/maple-v2-audits/files/10223545/Maple.Finance.v2.-.Spearbit.pdf) |
| Three Sigma | [`2022-10-24 - Three Sigma Report`](https://docs.google.com/viewer?url=https://github.com/maple-labs/maple-v2-audits/files/10223541/three-sigma_maple-finance_code-audit_v1.1.1.pdf) |

<br>

### June 2023 Release

| Auditor | Report Link |
|---|---|
| Spearbit Auditors via Cantina | [`2023-06-05 - Cantina Report`](https://docs.google.com/viewer?url=https://github.com/maple-labs/maple-v2-audits/files/11667848/cantina-maple.pdf) |
| Three Sigma | [`2023-04-10 - Three Sigma Report`](https://docs.google.com/viewer?url=https://github.com/maple-labs/maple-v2-audits/files/11663546/maple-v2-audit_three-sigma_2023.pdf) |

<br>

### December 2023 Release
| Auditor | Report Link |
|---|---|
| Three Sigma | [`2023-11-06 - Three Sigma Report`](https://docs.google.com/viewer?url=https://github.com/maple-labs/maple-v2-audits/files/13707288/Maple-Q4-Three-Sigma-Audit.pdf) |
| 0xMacro | [`2023-11-27 - 0xMacro Report`](https://docs.google.com/viewer?url=https://github.com/maple-labs/maple-v2-audits/files/13707291/Maple-Q4-0xMacro-Audit.pdf) |

## Bug Bounty

For all information related to the ongoing bug bounty for these contracts run by [Immunefi](https://immunefi.com/), please visit this [site](https://immunefi.com/bounty/maple/).

## About Maple

[Maple Finance](https://maple.finance/) is a decentralized corporate credit market. Maple provides capital to institutional borrowers through globally accessible fixed-income yield opportunities.

---

<p align="center">
  <img src="https://user-images.githubusercontent.com/44272939/196706799-fe96d294-f700-41e7-a65f-2d754d0a6eac.gif" height="100" />
</p>
