// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.7;

import { IERC20Like, ILoanManager, IPool, IPoolManager } from "../../contracts/interfaces/Interfaces.sol";

import { Logger } from "./Logger.sol";

contract LiquidityMigrationLogger is Logger {

    IERC20Like   internal fundsAsset;
    ILoanManager internal loanManager;
    IPool        internal pool;

    constructor(IPoolManager poolManager_, string memory filepath_) Logger(filepath_) {
        fundsAsset  = IERC20Like(poolManager_.asset());
        loanManager = ILoanManager(poolManager_.loanManagerList(0));
        pool        = IPool(poolManager_.pool());
    }

    function headers() external pure override returns (string[] memory headers_) {
        headers_ = new string[](8);

        headers_[0] = "Day";

        headers_[1] = "Pool Cash";
        headers_[2] = "Outstanding Principal";
        headers_[3] = "Accounted Interest";
        headers_[4] = "Accrued Interest";

        headers_[5] = "Real AUM";
        headers_[6] = "Expected AUM";

        headers_[7] = "Notes";
    }

    function output(string memory notes_) external view override returns (string[] memory values_) {
        values_ = new string[](8);

        values_[0] = _formattedTime();

        values_[1] = convertUintToSixDecimalString(fundsAsset.balanceOf(address(pool)), 1e6);
        values_[2] = convertUintToSixDecimalString(loanManager.principalOut(),          1e6);
        values_[3] = convertUintToSixDecimalString(loanManager.accountedInterest(),     1e6);
        values_[4] = convertUintToSixDecimalString(loanManager.getAccruedInterest(),    1e6);

        values_[5] = convertUintToSixDecimalString(loanManager.assetsUnderManagement(), 1e6);
        // TODO: values_[5] = convertUintToSixDecimalString(loanManager.assetsUnderManagement(), 1e6);

        values_[7] = bytes(notes_).length == 0 ? NULL : notes_;
    }

}
