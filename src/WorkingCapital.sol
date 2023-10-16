// SPDX-License-Identifier: MIT
// SPDX-License_Identifier: APGL-3.0-or-later

pragma solidity 0.8.17;

import {PluginCloneable, IDAO} from "@aragon/osx/core/plugin/PluginCloneable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {BokkyPooBahsDateTimeLibrary} from "./BokkyPooBahsDateTimeLibrary.sol";
import {IHats} from "./../hatsprotocol/src/Interfaces/IHats.sol";

contract WorkingCapital is PluginCloneable {
    bytes32 public constant UPDATE_SPENDING_LIMIT_PERMISSION_ID =
        keccak256("UPDATE_SPENDING_LIMIT_PERMISSION");

    struct WorkingCapitalAction {
        address to;
        uint256 value;
        address erc20Address;
    }

    struct TokenDetails {
        uint lastMonthEdit;
        uint lastYearEdit;
        uint256 spendingLimit;
        uint256 remainingBudget;
    }

    mapping(address => TokenDetails) public budgets;

    IHats public hatsProtocolInstance;
    uint256 public hatId;

    /// @notice Initializes the contract.
    /// @param _dao The associated DAO.
    /// @param _hatId The id of the hat.
    /// @param _budgetETH the limit of budget in ETH
    function initialize(
        IDAO _dao,
        uint256 _hatId,
        uint256 _budgetETH
    ) external initializer {
        __PluginCloneable_init(_dao);
        hatId = _hatId;
        // TODO get this from environment per network (this is goerli)
        // get instance of Hats protocol
        hatsProtocolInstance = IHats(
            0x3bc1A0Ad72417f2d411118085256fC53CBdDd137
        );
        // can hats owner spend any ETH
        if (_budgetETH > 0) {
            // get current month from timestamp
            uint _currentMonth = BokkyPooBahsDateTimeLibrary.getMonth(
                block.timestamp
            );
            // get current year from timestamp
            uint _currentYear = BokkyPooBahsDateTimeLibrary.getYear(
                block.timestamp
            );
            // add limitation of ETH ,remainingBudget ,currentMonth and currentYear in budgets map in address(0)
            budgets[address(0)] = TokenDetails({
                lastMonthEdit: _currentMonth,
                lastYearEdit: _currentYear,
                spendingLimit: _budgetETH,
                remainingBudget: _budgetETH
            });
        }
    }

    /// @notice Checking that can user withdraw this amount
    /// @param _actions actions that would be checked
    /// @return generatedDAOActions IDAO.Action generated for use in execute
    function hasRemainingBudget(
        WorkingCapitalAction[] calldata _actions
    ) internal returns (IDAO.Action[] memory generatedDAOActions) {
        // get current month from timestamp
        uint _currentMonth = BokkyPooBahsDateTimeLibrary.getMonth(
            block.timestamp
        );
        // get current year from timestamp
        uint _currentYear = BokkyPooBahsDateTimeLibrary.getYear(
            block.timestamp
        );
        // create generated Dao action that includes consistent actions with dao().execute()
        generatedDAOActions = new IDAO.Action[](_actions.length);
        for (uint j = 0; j < _actions.length; j += 1) {
            address _to;
            uint256 _value;
            bytes memory _data;
            address _token;
            // it is not an erc20 token
            if (_actions[j].erc20Address == address(0)) {
                // which token has been spent
                _token = address(0);
                require(
                    budgets[_token].spendingLimit != 0,
                    "It is not available token in this plugin"
                );
                _to = _actions[j].to;
                _value = _actions[j].value;
                _data = new bytes(0);

            } else {
                // which token has been spent
                _token = _actions[j].erc20Address;
                require(
                    budgets[_token].spendingLimit != 0,
                    "It is not available token in this plugin"
                );
                // address of token that we must call
                _to = _actions[j].erc20Address;
                _value = 0;
                // encode transaction that dao().execute() must run
                _data = abi.encodeWithSignature(
                    "transfer(address,uint256)",
                    _actions[j].to,
                    _actions[j].value
                );

            }
            // if we are on the month that we were in last modification of this token
            if (
                _currentMonth == budgets[_token].lastMonthEdit &&
                _currentYear == budgets[_token].lastYearEdit
            ) {
                // check that we have enough remaining budget
                require(
                    budgets[_token].remainingBudget >= _actions[j].value,
                    string.concat(
                        "In ",
                        Strings.toString(j),
                        " action you want to spend more than your limit monthly"
                    )
                );
                // reduce from this token budget of hats owner(s) in this month
                budgets[_token].remainingBudget -= _actions[j].value;
            }
            // if we are on another month after modification this token
            else {
                // update token lastYearEdit and lastMonthEdit
                budgets[_token].lastYearEdit = _currentYear;
                budgets[_token].lastMonthEdit = _currentMonth;
                // reset this month budget
                budgets[_token].remainingBudget = budgets[_token].spendingLimit;
                require(
                    budgets[_token].remainingBudget >= _actions[j].value,
                    string.concat(
                        "In ",
                        Strings.toString(j),
                        " action you want to spend more than your limit monthly"
                    )
                );
                // reduce from this token budget of hats owner(s) in this month
                budgets[_token].remainingBudget -= _actions[j].value;
            }
            // add this new action to generatedDAOActions to call them together
            generatedDAOActions[j] = IDAO.Action(_to, _value, _data);
        }
    }

    /// @notice Executes actions in the associated DAO.
    /// @param _workingCapitalActions The actions to be executed by the DAO.
    function execute(
        WorkingCapitalAction[] calldata _workingCapitalActions
    ) external {
        // check that caller of this transaction is hats owner(s)
        require(
            hatsProtocolInstance.isWearerOfHat(msg.sender, hatId),
            "Sender is not wearer of the hat"
        );
        // get generated actions
        IDAO.Action[] memory iDAOAction = hasRemainingBudget(
            _workingCapitalActions
        );
        // execute generated actions
        dao().execute({
            _callId: 0x0,
            _actions: iDAOAction,
            _allowFailureMap: 0
        });
    }

    /// @notice UpdateSpendingLimit is an function that just would call with dao and must create proposal for that
    /// @param _token which token budget you want to modify
    /// @param _spendingLimit spending limit
    /// @param _restThisMonth reset remaining budget of this month or not
    function updateSpendingLimit(
        address _token,
        uint256 _spendingLimit,
        bool _restThisMonth
    ) external auth(UPDATE_SPENDING_LIMIT_PERMISSION_ID) {
        // get current month from timestamp
        uint _currentMonth = BokkyPooBahsDateTimeLibrary.getMonth(
            block.timestamp
        );
        // get current year from timestamp
        uint _currentYear = BokkyPooBahsDateTimeLibrary.getYear(
            block.timestamp
        );
        // to reset budget of this token
        if (_restThisMonth) {
            budgets[_token] = TokenDetails({
                lastMonthEdit: _currentMonth,
                lastYearEdit: _currentYear,
                spendingLimit: _spendingLimit,
                remainingBudget: _spendingLimit
            });
        } else {
            // remainingBudget will not update
            budgets[_token] = TokenDetails({
                lastMonthEdit: _currentMonth,
                lastYearEdit: _currentYear,
                spendingLimit: _spendingLimit,
                remainingBudget: budgets[_token].remainingBudget
            });
        }
    }
}
