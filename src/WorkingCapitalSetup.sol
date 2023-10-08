// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.8.17;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {PermissionLib} from "@aragon/osx/core/permission/PermissionLib.sol";
import {PluginSetup, IPluginSetup} from "@aragon/osx/framework/plugin/setup/PluginSetup.sol";
import {WorkingCapital} from "./WorkingCapital.sol";
import {IDAO} from "@aragon/osx/core/plugin/Plugin.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";

contract WorkingCapitalSetup is PluginSetup {
    using Clones for address;

    /// @notice The address of `WorkingCapital` plugin logic contract to be cloned.
    address private immutable workingCapitalImplementation;

    /// @notice The constructor setting the `Admin` implementation contract to clone from.
    constructor() {
        workingCapitalImplementation = address(new WorkingCapital());
    }

    /// @inheritdoc IPluginSetup
    function prepareInstallation(
        address _dao,
        bytes calldata _data
    )
        external
        returns (address plugin, PreparedSetupData memory preparedSetupData)
    {
        // Decode `_data` to extract the params needed for cloning and initializing the `Admin` plugin.
        (address admin, uint256 monthlyLimit) = abi.decode(_data, (address, uint256));

        if (admin == address(0)) {
            revert("The admin address can not be zero");
        }

        // Clone plugin contract.
        plugin = workingCapitalImplementation.clone();

        // Initialize cloned plugin contract.
        WorkingCapital(plugin).initialize(IDAO(_dao), admin,monthlyLimit);

        // Prepare permissions
        PermissionLib.MultiTargetPermission[]
            memory permissions = new PermissionLib.MultiTargetPermission[](2);

        // Grant the `ADMIN_EXECUTE_PERMISSION` of the plugin to the admin.
        permissions[0] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Grant,
            where: plugin,
            who: admin,
            condition: PermissionLib.NO_CONDITION,
            permissionId: WorkingCapital(plugin).ADMIN_EXECUTE_PERMISSION_ID()
        });

        // Grant the `EXECUTE_PERMISSION` on the DAO to the plugin.
        permissions[1] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Grant,
            where: _dao,
            who: plugin,
            condition: PermissionLib.NO_CONDITION,
            permissionId: DAO(payable(_dao)).EXECUTE_PERMISSION_ID()
        });

        preparedSetupData.permissions = permissions;
    }

    /// @inheritdoc IPluginSetup
    function prepareUninstallation(
        address _dao,
        SetupPayload calldata _payload
    )
        external
        view
        returns (PermissionLib.MultiTargetPermission[] memory permissions)
    {
        // Collect addresses
        address plugin = _payload.plugin;
        address admin = WorkingCapital(plugin).admin();

        // Prepare permissions
        permissions = new PermissionLib.MultiTargetPermission[](2);

        permissions[0] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Revoke,
            where: plugin,
            who: admin,
            condition: PermissionLib.NO_CONDITION,
            permissionId: WorkingCapital(plugin).ADMIN_EXECUTE_PERMISSION_ID()
        });

        permissions[1] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Revoke,
            where: _dao,
            who: plugin,
            condition: PermissionLib.NO_CONDITION,
            permissionId: DAO(payable(_dao)).EXECUTE_PERMISSION_ID()
        });
    }

    /// @inheritdoc IPluginSetup
    function implementation() external view returns (address) {
        return workingCapitalImplementation;
    }
}
