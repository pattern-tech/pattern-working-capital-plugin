// SPDX-License-Identifier: MIT
// SPDX-License_Identifier: APGL-3.0-or-later

pragma solidity 0.8.17;

import {PluginCloneable, IDAO} from "@aragon/osx/core/plugin/PluginCloneable.sol";
import {IHats} from "./../hatsprotocol/src/Interfaces/IHats.sol";

contract WorkingCapital is PluginCloneable {

    IHats public hatsProtocolInstance;
    uint256 public hatId; 
    uint256 public spendingLimitETH;

    /// @notice Initializes the contract.
    /// @param _dao The associated DAO.
    /// @param _hatId The id of the hat.
    function initialize(IDAO _dao, uint256 _hatId, uint256 _spendingLimitETH) external initializer {
        __PluginCloneable_init(_dao);
        hatId = _hatId;
        // TODO get this from environment per network (this is goerli)
        hatsProtocolInstance = IHats(0x3bc1A0Ad72417f2d411118085256fC53CBdDd137);
        spendingLimitETH = _spendingLimitETH;
    }

    /// @notice Executes actions in the associated DAO.
    /// @param _actions The actions to be executed by the DAO.
    function execute(
        IDAO.Action[] calldata _actions
    ) external {
        if(!hatsProtocolInstance.isWearerOfHat(msg.sender, hatId)){
            revert("Sender is not wearer of the hat");
        }
        dao().execute({_callId: 0x0, _actions: _actions, _allowFailureMap: 0});
    }
}
