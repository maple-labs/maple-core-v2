// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { FixedAddresses }     from "./addresses/FixedAddresses.sol";
import { FutureAddresses }    from "./addresses/FutureAddresses.sol";
import { TransientAddresses } from "./addresses/TransientAddresses.sol";

contract AddressRegistry is FixedAddresses, TransientAddresses, FutureAddresses {}
