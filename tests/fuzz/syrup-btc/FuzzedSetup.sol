// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.7;

import {
    IBitcoinStrategy,
    IERC20Like,
    IPool,
    IPoolManager,
    ISyrupBitcoinRouter,
    IWithdrawalManagerQueue as IMapleWithdrawalManager,
    Permit
} from "../../../contracts/interfaces/Interfaces.sol";

import { ProtocolActions } from "../../../contracts/ProtocolActions.sol";

import { TestBaseWithAssertions } from "../../TestBaseWithAssertions.sol";

enum Action {
    Deposit,
    RequestRedeem,
    RemoveSharesById,
    RemoveRequestFromRouter,
    WmProcessRedeemRequest,
    BitcoinRouterProcessRedemptions,
    Deploy,
    Reconcile,
    Default,
    Impair,
    ScheduleYield,
    SetFeeRate
}

contract FuzzedUtils is ProtocolActions {

    uint256 maxDepositAmount = 1e8;
    uint256 maxTimeToPass    = 100 days;

    uint256 seed;

    address _bitcoinRouter;
    address _depositAsset;
    address _pool;
    address _poolAsset;
    address _poolDelegate;
    address _redeemer;
    address _strategyManager;
    address _withdrawalManager;

    address[] lps;
    address[] strategies;

    uint256[] requestsOnRouter;

    function fuzzedSetup(Action[] memory actions) internal {
        for (uint256 i = 0; i < actions.length; i++) {
            if (actions[i] == Action.Deposit) {
                deposit();
            } else if (actions[i] == Action.RequestRedeem) {
                requestRedeem();
            } else if (actions[i] == Action.RemoveSharesById) {
                removeSharesById();
            } else if (actions[i] == Action.RemoveRequestFromRouter) {
                removeRequestFromRouter();
            } else if (actions[i] == Action.WmProcessRedeemRequest) {
                wmProcessRedeemRequest();
            } else if (actions[i] == Action.BitcoinRouterProcessRedemptions) {
                bitcoinRouterProcessRedemptions();
            } else if (actions[i] == Action.Deploy) {
                deployInStrategy();
            } else if (actions[i] == Action.Reconcile) {
                reconcileFromStrategy();
            } else if (actions[i] == Action.Default) {
                defaultStrategy();
            } else if (actions[i] == Action.Impair) {
                impairStrategy();
            } else if (actions[i] == Action.ScheduleYield) {
                scheduleYieldOnStrategy();
            } else if (actions[i] == Action.SetFeeRate) {
                setFeeRateOnStrategy();
            }

            uint256 currentTimestamp = block.timestamp;
            uint256 timeToPass       = getSomeValue(0, maxTimeToPass);
            vm.warp(currentTimestamp + timeToPass);
        }
    }

    function deposit() internal {
        address user   = lps[getSomeValue(0, lps.length - 1)];
        uint256 amount = getSomeValue(0, maxDepositAmount);

        if (amount == 0) {
            return;
        }

        depositInSyrupBtc(user, _bitcoinRouter, _depositAsset, amount);
    }

    function requestRedeem() internal {
        uint256 randomUserIndex = getSomeValue(0, lps.length - 1);
        address user            = lps[randomUserIndex];
        uint256 maxAmount       = IERC20Like(_pool).balanceOf(user);
        uint256 amount          = getSomeValue(0, maxAmount);

        if (amount == 0) {
            return;
        }

        requestRedeemFromSyrupBtc(user, _bitcoinRouter, _depositAsset, amount);

        uint256 requestId = IMapleWithdrawalManager(_withdrawalManager).requestIds(_bitcoinRouter);
        requestsOnRouter.push(requestId);
    }

    function removeSharesById() internal {
        ( uint256[] memory requestIds, ) = IMapleWithdrawalManager(_withdrawalManager).requestsByOwner(_bitcoinRouter);

        if (requestIds.length == 0) {
            return;
        }

        uint256 indexOfRequestToRemove = getSomeValue(0, requestIds.length - 1);
        uint256 requestIdToRemove      = requestIds[indexOfRequestToRemove];

        ( , uint256 maxSharesToRemove ) = IMapleWithdrawalManager(_withdrawalManager).requests(requestIdToRemove);
        uint256 sharesToRemove          = getSomeValue(0, maxSharesToRemove);

        if (sharesToRemove == 0) {
            return;
        }

        ( , address user, ) = ISyrupBitcoinRouter(_bitcoinRouter).redeemRequests(requestIdToRemove);

        vm.prank(user);
        ISyrupBitcoinRouter(_bitcoinRouter).removeSharesById(requestIdToRemove, sharesToRemove);
    }

    function removeRequestFromRouter() internal {
        if (requestsOnRouter.length == 0) {
            return;
        }

        uint256 indexOfRequestToRemove = getSomeValue(0, requestsOnRouter.length - 1);
        uint256 requestToRemove        = requestsOnRouter[indexOfRequestToRemove];

        ( , address owner, )         = ISyrupBitcoinRouter(_bitcoinRouter).redeemRequests(requestToRemove);
        ( , uint256 sharesLeftOnWm ) = IMapleWithdrawalManager(_withdrawalManager).requests(requestToRemove);

        if (owner == address(0) || sharesLeftOnWm == 0) {
            return;
        }

        uint256[] memory requestIds = new uint256[](1);
        requestIds[0]               = requestToRemove;

        vm.prank(_redeemer);
        ISyrupBitcoinRouter(_bitcoinRouter).removeRequests(owner, requestIds);

        requestsOnRouter[indexOfRequestToRemove] = requestsOnRouter[requestsOnRouter.length - 1];
        requestsOnRouter.pop();
    }

    function wmProcessRedeemRequest() internal {
        uint256 poolTotalSupply       = IPool(_pool).totalSupply();
        uint256 idleAssets            = IERC20Like(_poolAsset).balanceOf(_pool);
        uint256 totalAssetsWithLosses = IPool(_pool).totalAssets() - IPool(_pool).unrealizedLosses();

        if (poolTotalSupply == 0 || totalAssetsWithLosses == 0) {
            return;
        }

        uint256 maxAvailableLiquidity = idleAssets * poolTotalSupply / totalAssetsWithLosses;
        uint256 sharesToProcess       = getSomeValue(0, maxAvailableLiquidity);

        if (sharesToProcess == 0) {
            return;
        }

        vm.prank(_poolDelegate);
        IMapleWithdrawalManager(_withdrawalManager).processRedemptions(sharesToProcess);
    }

    function bitcoinRouterProcessRedemptions() internal {
        if (requestsOnRouter.length == 0) {
            return;
        }

        uint256 requestToProcess = requestsOnRouter[getSomeValue(0, requestsOnRouter.length - 1)];

        ( , , uint256 sharesOnRouter ) = ISyrupBitcoinRouter(_bitcoinRouter).redeemRequests(requestToProcess);
        ( ,   uint256 sharesLeftOnWm ) = IMapleWithdrawalManager(_withdrawalManager).requests(requestToProcess);

        if (sharesOnRouter == 0 || sharesLeftOnWm == sharesOnRouter) {
            return;
        }

        uint256 sharesToRedeem        = sharesOnRouter - sharesLeftOnWm;
        uint256 idleAssets            = IPool(_poolAsset).balanceOf(_pool);
        uint256 totalSupply           = IPool(_pool).totalSupply();
        uint256 totalAssetsWithLosses = IPool(_pool).totalAssets() - IPool(_pool).unrealizedLosses();

        if (totalAssetsWithLosses == 0) {
            return;
        }

        uint256 maxAvailableLiquidity = idleAssets * totalSupply / totalAssetsWithLosses;

        if (sharesToRedeem > maxAvailableLiquidity) {
            return;
        }

        uint256[] memory requestIds = new uint256[](1);
        requestIds[0]               = requestToProcess;

        vm.prank(_redeemer);
        ISyrupBitcoinRouter(_bitcoinRouter).processRedemptions(requestIds);
    }

    function deployInStrategy() internal {
        uint256 indexOfStrategy = getSomeValue(0, strategies.length - 1);
        address strategy        = strategies[indexOfStrategy];
        uint256 idleAssets      = IERC20Like(_poolAsset).balanceOf(_pool);
        uint256 amountToDeploy  = getSomeValue(0, idleAssets);

        if (amountToDeploy == 0 || IPool(_pool).totalSupply() == 0) {
            return;
        }

        vm.prank(_strategyManager);
        IBitcoinStrategy(strategy).deploy(address(_depositAsset), amountToDeploy);
    }

    function reconcileFromStrategy() internal {
        uint256 indexOfStrategy   = getSomeValue(0, strategies.length - 1);
        address strategy          = strategies[indexOfStrategy];
        uint256 amountToReconcile = getSomeValue(0, IBitcoinStrategy(strategy).assetsUnderManagement());

        if (amountToReconcile == 0) {
            return;
        }

        reconcile_syrupBTC(strategy, _strategyManager, _depositAsset, amountToReconcile);
    }

    function defaultStrategy() internal {
        uint256 indexOfStrategy = getSomeValue(0, strategies.length - 1);
        address strategy        = strategies[indexOfStrategy];
        uint256 aum             = IBitcoinStrategy(strategy).assetsUnderManagement();
        uint256 amountToDefault = getSomeValue(0, aum);

        vm.prank(_poolDelegate);
        IBitcoinStrategy(strategy).setDefault(amountToDefault);
    }

    function impairStrategy() internal {
        uint256 indexOfStrategy = getSomeValue(0, strategies.length - 1);
        address strategy        = strategies[indexOfStrategy];
        uint256 aum             = IBitcoinStrategy(strategy).assetsUnderManagement();
        uint256 amountToImpair  = getSomeValue(0, aum);

        vm.prank(_poolDelegate);
        IBitcoinStrategy(strategy).setImpairment(amountToImpair);
    }

    function scheduleYieldOnStrategy() internal {
        // Do not allow for yield scheduling if the pool total supply is 0.
        // This breaks the pool invariant A and pool invariant D and represent invalid production scenario.
        if (IPool(_pool).totalSupply() == 0) {
            return;
        }

        uint256 currentTimestamp = block.timestamp;
        uint256 indexOfStrategy  = getSomeValue(0, strategies.length - 1);
        address strategy         = strategies[indexOfStrategy];
        uint256 yieldAmount      = getSomeValue(0, maxDepositAmount);
        uint32  deadline         = uint32(currentTimestamp + getSomeValue(0, maxTimeToPass));

        scheduleYield_syrupBTC(strategy, _strategyManager, _depositAsset, yieldAmount, deadline);
    }

    function setFeeRateOnStrategy() internal {
        uint256 indexOfStrategy = getSomeValue(0, strategies.length - 1);
        address strategy        = strategies[indexOfStrategy];
        uint256 feeRate         = getSomeValue(0, IBitcoinStrategy(strategy).HUNDRED_PERCENT() - 1);

        vm.prank(_poolDelegate);
        IBitcoinStrategy(strategy).setFeeRate(feeRate);
    }

    function getSomeValue(uint256 min_, uint256 max_) internal returns (uint256 value_) {
        value_ = _bound(seed = uint256(keccak256(abi.encode(seed))), min_, max_);
    }

}

contract FuzzedSetup is TestBaseWithAssertions, FuzzedUtils {

    function setUp() public virtual override {
        _setUpBitcoinPool();

        _depositAsset      = address(depositAsset);
        _pool              = address(pool);
        _poolAsset         = address(compositeAsset);
        _bitcoinRouter     = address(bitcoinRouter);
        _withdrawalManager = address(withdrawalManager);
        _poolDelegate      = poolDelegate;
        _redeemer          = redeemer;
        _strategyManager   = strategyManager;

        uint256 strategyCount = IPoolManager(poolManager).strategyListLength();

        for (uint256 i; i < strategyCount; i++) {
            strategies.push(IPoolManager(poolManager).strategyList(i));
        }

        lps.push(makeAddr("lp1"));
        lps.push(makeAddr("lp2"));
        lps.push(makeAddr("lp3"));
    }

}
