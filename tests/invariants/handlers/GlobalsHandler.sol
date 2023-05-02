// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IGlobals, IInvariantTest, IPoolManager } from "../../../contracts/interfaces/Interfaces.sol";

import { HandlerBase } from "./HandlerBase.sol";

contract GlobalsHandler is HandlerBase {

    /**************************************************************************************************************************************/
    /*** State Variables                                                                                                                ***/
    /**************************************************************************************************************************************/

    IGlobals     public globals;
    IPoolManager public poolManager;

    /**************************************************************************************************************************************/
    /*** Constructor                                                                                                                    ***/
    /**************************************************************************************************************************************/

    constructor(address globals_, address poolManager_) {
        globals      = IGlobals(globals_);
        poolManager  = IPoolManager(poolManager_);
        testContract = IInvariantTest(msg.sender);
    }

    /**************************************************************************************************************************************/
    /*** Actions                                                                                                                        ***/
    /**************************************************************************************************************************************/

    function setMaxCoverLiquidationPercent(uint256 seed_) public useTimestamps {
        uint256 maxCoverLiquidationPercent_ = bound(seed_, 0, 1e6);

        setMaxCoverLiquidationPercent(address(globals), address(poolManager), maxCoverLiquidationPercent_);
    }

    function setMinCoverAmount(uint256 seed_) public useTimestamps {
        uint256 minCoverAmount_ = bound(seed_, 0, 10_000_000e6);

        setMinCoverAmount(address(globals), address(poolManager), minCoverAmount_);
    }

    function setPlatformManagementFeeRate(uint256 seed_) public useTimestamps {
        uint256 platformManagementFeeRate_ = bound(seed_, 0, 1e6);

        setPlatformManagementFeeRate(address(globals), address(poolManager), platformManagementFeeRate_);
    }

    function setPlatformOriginationFeeRate(uint256 seed_) public useTimestamps {
        uint256 platformOriginationFeeRate_ = bound(seed_, 0, 1e6);

        setPlatformOriginationFeeRate(address(globals), address(poolManager), platformOriginationFeeRate_);
    }

    function setPlatformServiceFeeRate(uint256 seed_) public useTimestamps {
        uint256 platformServiceFeeRate_ = bound(seed_, 0, 1e6);

        setPlatformServiceFeeRate(address(globals), address(poolManager), platformServiceFeeRate_);
    }

}
