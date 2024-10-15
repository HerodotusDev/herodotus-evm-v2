// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {ISatellite} from "interfaces/ISatellite.sol";

import {ISatelliteMaintenanceModule} from "interfaces/modules/ISatelliteMaintenanceModule.sol";
import {ContractsWithSelectors} from "script/helpers/ContractsWithSelectors.s.sol";

abstract contract IDeployModule is Script {
    function deploy() internal virtual returns (address moduleAddress);

    function deployAndPlanMaintenance(
        ISatelliteMaintenanceModule.ModuleMaintenanceAction action
    ) public returns (ISatelliteMaintenanceModule.ModuleMaintenance memory maintenance) {
        ContractsWithSelectors contractsWithSelectors = new ContractsWithSelectors();
        address moduleAddress = deploy();
        console.log("%s:", getContractName(), moduleAddress);
        bytes4[] memory functionSelectors = contractsWithSelectors.getSelectors(getContractName());

        maintenance = ISatelliteMaintenanceModule.ModuleMaintenance({moduleAddress: moduleAddress, action: action, functionSelectors: functionSelectors});
    }

    function run() external {
        address satelliteAddress = vm.envAddress("DEPLOYED_SATELLITE_ADDRESS");
        require(satelliteAddress != address(0), "Satellite address is not set");
        console.log("Maintenance on deployed Satellite:", satelliteAddress);

        ISatellite satellite = ISatellite(satelliteAddress);
        ISatelliteMaintenanceModule.ModuleMaintenance[] memory maintenances = new ISatelliteMaintenanceModule.ModuleMaintenance[](1);
        maintenances[0] = deployAndPlanMaintenance(ISatelliteMaintenanceModule.ModuleMaintenanceAction.Replace);

        vm.startBroadcast(getPrivateKey());
        satellite.satelliteMaintenance(maintenances, address(0), "");
        vm.stopBroadcast();
    }

    function getContractName() public view virtual returns (string memory);

    function getPrivateKey() internal view returns (uint256 privateKey) {
        privateKey = vm.envUint("PRIVATE_KEY");
    }
}
