// SPDX-License-Identifier: MIT
// SPDX-License_Identifier: APGL-3.0-or-later

pragma solidity 0.8.17;

import {PluginCloneable, IDAO} from "@aragon/osx/core/plugin/PluginCloneable.sol";

contract WorkingCapital is PluginCloneable {
    /// @notice The ID of the permission required to call the `execute` function.
    bytes32 public constant ADMIN_EXECUTE_PERMISSION_ID =
        keccak256("ADMIN_EXECUTE_PERMISSION");

    address public admin;

    /// @notice Initializes the contract.
    /// @param _dao The associated DAO.
    /// @param _admin The address of the admin.
    function initialize(IDAO _dao, address _admin) external initializer {
        __PluginCloneable_init(_dao);
        admin = _admin;
    }

    /// @notice Executes actions in the associated DAO.
    /// @param _actions The actions to be executed by the DAO.
    function execute(
        IDAO.Action[] calldata _actions
    ) external auth(ADMIN_EXECUTE_PERMISSION_ID) {
        dao().execute({_callId: 0x0, _actions: _actions, _allowFailureMap: 0});
    }
}
