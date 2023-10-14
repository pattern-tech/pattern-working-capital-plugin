// SPDX-License-Identifier: MIT
// SPDX-License_Identifier: APGL-3.0-or-later

pragma solidity 0.8.17;

import {PluginCloneable, IDAO} from "@aragon/osx/core/plugin/PluginCloneable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {BokkyPooBahsDateTimeLibrary} from "./BokkyPooBahsDateTimeLibrary.sol";
import {IHats} from "./../hatsprotocol/src/Interfaces/IHats.sol";

contract WorkingCapital is PluginCloneable {


    bytes32 public constant UPDATE_SPENDING_LIMIT_PERMISSION_ID = keccak256('UPDATE_SPENDING_LIMIT_PERMISSION');

    struct WorkingCapitalAction {
        address to;
        uint256 value;
        address erc20Address;
    }

//    struct Budget {
//        address token;
//        uint256 spendingLimit;
//    }


    struct TokenDetails{
        uint lastMonthEdit;
        uint lastYearEdit;
        uint256 spendingLimit;
        uint256 remainingBudget;
    }

    mapping(address => TokenDetails) public budgets;


    IHats public hatsProtocolInstance;
    uint256 public hatId;
//    mapping(address => uint256) public spendingLimit;

//    uint private currentMonth;
//    uint private currentYear;
//    mapping(address => uint256) private remainingBudget;
//    address[] public availableTokens;






    /// @notice Initializes the contract.
    /// @param _dao The associated DAO.
    /// @param _hatId The id of the hat.
    function initialize(IDAO _dao, uint256 _hatId,uint256 _budgetETH) external initializer {
        __PluginCloneable_init(_dao);
        hatId = _hatId;
        // TODO get this from environment per network (this is goerli)
        hatsProtocolInstance = IHats(0x3bc1A0Ad72417f2d411118085256fC53CBdDd137);
        if (_budgetETH>0){
            uint _currentMonth = BokkyPooBahsDateTimeLibrary.getMonth(block.timestamp);
            uint _currentYear = BokkyPooBahsDateTimeLibrary.getYear(block.timestamp);
            budgets[address (0)] = TokenDetails({lastMonthEdit:_currentMonth, lastYearEdit:_currentYear,spendingLimit:_budgetETH,remainingBudget:_budgetETH});
//            availableTokens.push(address (0));
        }

    }


    /// @notice Checking that can user withdraw this amount
    /// @param _actions actions that would be checked
    /// @return generatedDAOActions IDAO.Action generated for use in execute
    function hasRemainingBudget(WorkingCapitalAction[] calldata _actions) internal returns(IDAO.Action[] memory generatedDAOActions){
        uint _currentMonth = BokkyPooBahsDateTimeLibrary.getMonth(block.timestamp);
        uint _currentYear = BokkyPooBahsDateTimeLibrary.getYear(block.timestamp);
        generatedDAOActions = new IDAO.Action[](_actions.length);
        for (uint j=0; j < _actions.length; j+=1) {
            address _to;
            uint256 _value;
            bytes memory _data;
            address _token;
            // it is not an erc20 token
            if(_actions[j].erc20Address == address(0)){
                _to=_actions[j].to;
                _value=_actions[j].value;
                _data= new bytes(0);
                _token=address(0);
                require(budgets[_token].spendingLimit != 0,"It is not available token in this plugin");
            }
            else{
                _to=_actions[j].erc20Address;
                _value=0;
                _data = abi.encodeWithSignature("transfer(address,uint256)", _actions[j].to, _actions[j].value);
                _token=_actions[j].erc20Address;
                require(budgets[_token].spendingLimit !=0,"It is not available token in this plugin");

            }
            // if we are on the month that we were
            if(_currentMonth==budgets[_token].lastMonthEdit && _currentYear==budgets[_token].lastYearEdit){
                require(
                    budgets[_token].remainingBudget >=_actions[j].value,
                    string.concat("In ",Strings.toString(j)," action you want to spend more than your limit monthly") 
                );
                budgets[_token].remainingBudget -=_actions[j].value;
            }
            // if we are on another month
            else{
                budgets[_token].lastYearEdit = _currentYear;
                budgets[_token].lastMonthEdit = _currentMonth;
                budgets[_token].remainingBudget = budgets[_token].spendingLimit;
                require(
                    budgets[_token].remainingBudget>=_actions[j].value,
                    string.concat("In ",Strings.toString(j)," action you want to spend more than your limit monthly") 
                );
                budgets[_token].remainingBudget-=_actions[j].value;
            }

            generatedDAOActions[j]=IDAO.Action(_to, _value, _data);

        }
    }


    /// @notice Executes actions in the associated DAO.
    /// @param _workingCapitalActions The actions to be executed by the DAO.
    function execute(
        WorkingCapitalAction[] calldata _workingCapitalActions
    ) external {
        require(hatsProtocolInstance.isWearerOfHat(msg.sender, hatId), "Sender is not wearer of the hat");
        IDAO.Action [] memory iDAOAction = hasRemainingBudget(_workingCapitalActions);
        dao().execute({_callId: 0x0, _actions: iDAOAction, _allowFailureMap: 0});
    }

    /// @param _spendingLimit spending limit
    function updateSpendingLimit(address _token,uint256 _spendingLimit,bool _restThisMonth) external auth(UPDATE_SPENDING_LIMIT_PERMISSION_ID){
        uint _currentMonth = BokkyPooBahsDateTimeLibrary.getMonth(block.timestamp);
        uint _currentYear = BokkyPooBahsDateTimeLibrary.getYear(block.timestamp);
        if(_restThisMonth){
            budgets[_token]=TokenDetails({lastMonthEdit:_currentMonth,lastYearEdit:_currentYear,spendingLimit:_spendingLimit,remainingBudget:_spendingLimit});
        }
        else{
            budgets[_token]=TokenDetails({lastMonthEdit:_currentMonth,lastYearEdit:_currentYear,spendingLimit:_spendingLimit,remainingBudget:budgets[_token].remainingBudget});
        }
    }
}
