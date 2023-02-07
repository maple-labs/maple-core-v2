// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IERC20 } from "../../modules/erc20/contracts/interfaces/IERC20.sol";

import { IMapleGlobals }          from "../../modules/globals/contracts/interfaces/IMapleGlobals.sol";
import { INonTransparentProxied } from "../../modules/globals/modules/non-transparent-proxy/contracts/interfaces/INonTransparentProxied.sol";
import { INonTransparentProxy }   from "../../modules/globals/modules/non-transparent-proxy/contracts/interfaces/INonTransparentProxy.sol";

import { ILiquidator } from "../../modules/liquidations/contracts/interfaces/ILiquidator.sol";

import { IMapleLoan }           from "../../modules/loan/contracts/interfaces/IMapleLoan.sol";
import { IMapleLoanFactory }    from "../../modules/loan/contracts/interfaces/IMapleLoanFactory.sol";
import { IMapleLoanFeeManager } from "../../modules/loan/contracts/interfaces/IMapleLoanFeeManager.sol";
import { IRefinancer }          from "../../modules/loan/contracts/interfaces/IRefinancer.sol";

import { ILoanManager }            from "../../modules/pool/contracts/interfaces/ILoanManager.sol";
import { ILoanManagerInitializer } from "../../modules/pool/contracts/interfaces/ILoanManagerInitializer.sol";
import { IMapleProxied }           from "../../modules/pool/modules/maple-proxy-factory/contracts/interfaces/IMapleProxied.sol";
import { IMapleProxyFactory }      from "../../modules/pool/modules/maple-proxy-factory/contracts/interfaces/IMapleProxyFactory.sol";
import { IPool }                   from "../../modules/pool/contracts/interfaces/IPool.sol";
import { IPoolDeployer }           from "../../modules/pool/contracts/interfaces/IPoolDeployer.sol";
import { IPoolManager }            from "../../modules/pool/contracts/interfaces/IPoolManager.sol";
import { IPoolManagerInitializer } from "../../modules/pool/contracts/interfaces/IPoolManagerInitializer.sol";

import { IWithdrawalManager }            from "../../modules/withdrawal-manager/contracts/interfaces/IWithdrawalManager.sol";
import { IWithdrawalManagerInitializer } from "../../modules/withdrawal-manager/contracts/interfaces/IWithdrawalManagerInitializer.sol";

interface IERC20Like {

    function allowance(address owner, address spender) external view returns (uint256 allowance);

    function approve(address spender, uint256 amount) external returns (bool success);

    function balanceOf(address account) external view returns (uint256 balance);

    function burn(address owner, uint256 amount) external;

    function decimals() external view returns (uint8 decimals);

    function mint(address recipient, uint256 amount) external;

    function name() external view returns (string memory name);

    function symbol() external view returns (string memory symbol);

    function totalSupply() external view returns (uint256 totalSupply);

    function transfer(address recipient, uint256 amount) external returns (bool success);

    function transferFrom(address owner, address recipient, uint256 amount) external returns (bool success);

}

interface IHasGLobalsLike {

    function globals() external view returns (address globals);

}
