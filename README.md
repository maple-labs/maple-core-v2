# Maple V2 Core

[![Foundry][foundry-badge]][foundry]
![Foundry CI](https://github.com/maple-labs/maple-v2-core/actions/workflows/forge.yaml/badge.svg)

[foundry]: https://getfoundry.sh/
[foundry-badge]: https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg

## Overview

This repository brings together the core smart contracts of the Maple V2 protocol as dependencies in order to perform integration tests and simulations.

## Submodules

Submodules imported:
- [`maple-labs/contract-test-utils` (for testing)](https://github.com/maple-labs/contract-test-utils)
- [`maple-labs/debt-locker` (for V1 Migration testing)](https://github.com/maple-labs/debt-locker)
- [`maple-labs/erc20`](https://github.com/maple-labs/erc20)
- [`maple-labs/globals-v2`](https://github.com/maple-labs/globals-v2)
- [`maple-labs/liquidations`](https://github.com/maple-labs/liquidations)
- [`maple-labs/loan`](https://github.com/maple-labs/loan)
- [`maple-labs/migration-helpers`](https://github.com/maple-labs/migration-helpers)
- [`maple-labs/pool-v2`](https://github.com/maple-labs/pool-v2)
- [`maple-labs/withdrawal-manager`](https://github.com/maple-labs/withdrawal-manager)

Versions of dependencies can be checked with `git submodule status`.

## Setup

This project was built using [Foundry](https://book.getfoundry.sh/). Refer to installation instructions [here](https://github.com/foundry-rs/foundry#installation).

```sh
git clone git@github.com:maple-labs/maple-core-v2.git
cd maple-core-v2
forge install
```

## Running Tests

- To run all tests: `forge test`
- To run specific tests: `forge test --match <test_name>`

`./scripts/test.sh` is used to enable Foundry profile usage with the `-p` flag. Profiles are used to specify the number of fuzz runs.

## Audit Reports

| Auditor | Report Link |
|---|---|
| Trail of Bits | [`2022-08-24 - Trail of Bits Report`](https://docs.google.com/viewer?url=https://github.com/maple-labs/maple-v2-audits/files/10246688/Maple.Finance.v2.-.Final.Report.-.Fixed.-.2022.pdf) |
| Spearbit | [`2022-10-17 - Spearbit Report`](https://docs.google.com/viewer?url=https://github.com/maple-labs/maple-v2-audits/files/10223545/Maple.Finance.v2.-.Spearbit.pdf) |
| Three Sigma | [`2022-10-24 - Three Sigma Report`](https://docs.google.com/viewer?url=https://github.com/maple-labs/maple-v2-audits/files/10223541/three-sigma_maple-finance_code-audit_v1.1.1.pdf) |

## Bug Bounty

For all information related to the ongoing bug bounty for these contracts run by [Immunefi](https://immunefi.com/), please visit this [site](https://immunefi.com/bounty/maple/).

## About Maple

[Maple Finance](https://maple.finance/) is a decentralized corporate credit market. Maple provides capital to institutional borrowers through globally accessible fixed-income yield opportunities.

For all technical documentation related to the Maple V2 protocol, please refer to the GitHub [wiki](https://github.com/maple-labs/maple-core-v2/wiki).

---

<p align="center">
  <img src="https://user-images.githubusercontent.com/44272939/196706799-fe96d294-f700-41e7-a65f-2d754d0a6eac.gif" height="100" />
</p>
