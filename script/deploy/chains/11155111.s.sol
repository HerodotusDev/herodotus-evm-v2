// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console} from "forge-std/console.sol";

import {ContractsWithSelectors} from "script/helpers/ContractsWithSelectors.s.sol";
import {IDeploy} from "script/deploy/interfaces/IDeploy.sol";

import {Satellite} from "src/Satellite.sol";
import {SatelliteMaintenanceModule} from "src/modules/SatelliteMaintenanceModule.sol";
import {ISatellite} from "interfaces/ISatellite.sol";
import {ILibSatellite} from "interfaces/ISatellite.sol";
import {ISatelliteMaintenanceModule} from "interfaces/modules/ISatelliteMaintenanceModule.sol";

import {DeployOwnershipModule} from "../modules/DeployOwnershipModule.s.sol";
import {DeploySatelliteInspectorModule} from "../modules/DeploySatelliteInspectorModule.s.sol";
import {DeployMmrCoreModule} from "../modules/DeployMmrCoreModule.s.sol";
import {DeployNativeSharpMmrGrowingModule} from "../modules/growing/DeployNativeSharpMmrGrowingModule.s.sol";
import {DeployEVMFactRegistryModule} from "../modules/DeployEVMFactRegistryModule.s.sol";
import {DeployNativeBlockHashFetcherModule} from "../modules/block-hash-fetching/DeployNativeBlockHashFetcherModule.s.sol";
import {DeployNativeOnChainGrowingModule} from "../modules/growing/DeployNativeOnChainGrowingModule.s.sol";
import {DeployStarknetSharpMmrGrowingModule} from "../modules/growing/DeployStarknetSharpMmrGrowingModule.s.sol";
import {DeployStarknetBlockHashFetcherModule} from "../modules/block-hash-fetching/DeployStarknetBlockHashFetcherModule.s.sol";
import {DeployDataProcessorModule} from "../modules/DeployDataProcessorModule.s.sol";
import {DeploySatelliteConnectionRegistryModule} from "../modules/DeploySatelliteConnectionRegistryModule.s.sol";
import {DeploySimpleReceiverModule} from "../modules/messaging/receiver/DeploySimpleReceiverModule.s.sol";
import {DeployL1ToArbitrumSenderModule} from "../modules/messaging/sender/DeployL1ToArbitrumSenderModule.s.sol";
import {DeployL1ToOptimismSenderModule} from "../modules/messaging/sender/DeployL1ToOptimismSenderModule.s.sol";
import {DeployUniversalSenderModule} from "../modules/messaging/sender/DeployUniversalSenderModule.s.sol";

uint256 constant numberOfModules = 15;

contract Deploy is Script {
    function run() external returns (address satelliteAddress) {
        //? -1 because the SatelliteMaintenanceModule is already deployed
        uint256 moduleCount = numberOfModules - 1;
        ISatellite.ModuleMaintenance[] memory maintenances = new ISatellite.ModuleMaintenance[](moduleCount);
        IDeploy[] memory deployModules = new IDeploy[](moduleCount);
        deployModules[0] = new DeployOwnershipModule();
        deployModules[1] = new DeploySatelliteInspectorModule();
        deployModules[2] = new DeployMmrCoreModule();
        deployModules[3] = new DeployNativeSharpMmrGrowingModule();
        deployModules[4] = new DeployEVMFactRegistryModule();
        deployModules[5] = new DeployNativeBlockHashFetcherModule();
        deployModules[6] = new DeployNativeOnChainGrowingModule();
        deployModules[7] = new DeployStarknetSharpMmrGrowingModule();
        deployModules[8] = new DeployStarknetBlockHashFetcherModule();
        deployModules[9] = new DeployDataProcessorModule();
        deployModules[10] = new DeploySatelliteConnectionRegistryModule();
        deployModules[11] = new DeployUniversalSenderModule();
        deployModules[12] = new DeployL1ToArbitrumSenderModule();
        deployModules[13] = new DeployL1ToOptimismSenderModule();

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        SatelliteMaintenanceModule satelliteMaintenanceModule = new SatelliteMaintenanceModule();
        vm.stopBroadcast();
        address satelliteMaintenanceModuleAddress = address(satelliteMaintenanceModule);
        console.log("SatelliteMaintenanceModule:", address(satelliteMaintenanceModuleAddress));
        vm.startBroadcast(deployerPrivateKey);
        Satellite satelliteDeployment = new Satellite(satelliteMaintenanceModuleAddress);
        vm.stopBroadcast();

        satelliteAddress = address(satelliteDeployment);
        ISatellite satellite = ISatellite(satelliteAddress);
        console.log("Satellite:", address(satellite));

        for (uint256 i = 0; i < moduleCount; i++) {
            maintenances[i] = deployModules[i].deployAndPlanMaintenance(ILibSatellite.ModuleMaintenanceAction.Add);
        }

        vm.startBroadcast(deployerPrivateKey);
        satellite.satelliteMaintenance(maintenances, address(0), "");
        vm.stopBroadcast();
    }
}
