// SPDX-License-Identifier: MIT
// SPDX-License_Identifier: APGL-3.0-or-later

pragma solidity 0.8.17;

import {PluginCloneable, IDAO} from "@aragon/osx/core/plugin/PluginCloneable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {BokkyPooBahsDateTimeLibrary} from "./BokkyPooBahsDateTimeLibrary.sol";

contract WorkingCapital is PluginCloneable {
    /// @notice The ID of the permission required to call the `execute` function.
    bytes32 public constant ADMIN_EXECUTE_PERMISSION_ID =
        keccak256("ADMIN_EXECUTE_PERMISSION");

    address public admin;

    uint256 public monthly_limit;

    uint private this_month;

    uint private this_year;

    uint256 private this_month_remained;

    /// @notice Initializes the contract.
    /// @param _dao The associated DAO.
    /// @param _admin The address of the admin.
    function initialize(IDAO _dao, address _admin) external initializer {
        __PluginCloneable_init(_dao);
        admin = _admin;
    }


    /// @notice Checking that can user withdraw this amount
    /// @param _actions actions that would be checked
    function hasRemainingBudget(IDAO.Action[] calldata _actions){
        uint _this_month = BokkyPooBahsDateTimeLibrary.getMonth(block.timestamp);
        uint _this_year = BokkyPooBahsDateTimeLibrary.getYear(block.timestamp);
        uint j=0;
        for (; j < _actions.length; j+=1) {  //for loop example
            // if we are on the month that we were
            if(_this_month==this_month && _this_year==this_year){
                require(this_month_remained>=_actions[j].value, string.concat("In ",Strings.toString(j)," action you want to spend more than your limit monthly") );
                this_month_remained-=_actions[j].value;
            }
            else{
                this_year = _this_year;
                this_month = _this_month;
                this_month_remained=monthly_limit;
                require(this_month_remained>=_actions[j].value, string.concat("In ",Strings.toString(j)," action you want to spend more than your limit monthly") );
                this_month_remained-=_actions[j].value;

            }

        }


    }



    /// @notice Executes actions in the associated DAO.
    /// @param _actions The actions to be executed by the DAO.
    function execute(
        IDAO.Action[] calldata _actions
    ) external auth(ADMIN_EXECUTE_PERMISSION_ID) {
        hasRemainingBudget(_actions);
        dao().execute({_callId: 0x0, _actions: _actions, _allowFailureMap: 0});
    }
}
