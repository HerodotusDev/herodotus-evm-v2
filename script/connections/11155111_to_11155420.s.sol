// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {console} from "forge-std/console.sol";
import {ContractsWithSelectors} from "script/helpers/ContractsWithSelectors.s.sol";
import {IDeploy} from "script/deploy/interfaces/IDeploy.sol";
import {ISatellite} from "interfaces/ISatellite.sol";

contract SetupL1 is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        
        address l1SatelliteAddress = vm.envAddress("SATELLITE_ADDRESS_11155111");
        address optimismSatelliteAddress = vm.envAddress("SATELLITE_ADDRESS_11155420");
        address optimismCrossDomainMessenger = vm.envAddress("SEPOLIA_OPTIMISM_CROSS_DOMAIN_MESSENGER");
        bytes4 selector = bytes4(keccak256("sendMessageL1ToOptimism(address,address,bytes,bytes)"));

        ISatellite l1Satellite = ISatellite(l1SatelliteAddress);
        l1Satellite.registerSatellite(11155420, optimismSatelliteAddress, optimismCrossDomainMessenger, address(0x0), selector);
        
        vm.stopBroadcast();
    }
}

contract SetupOptimism is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        
        address l1SatelliteAddress = vm.envAddress("SATELLITE_ADDRESS_11155111");
        address optimismSatelliteAddress = vm.envAddress("SATELLITE_ADDRESS_11155420");

        ISatellite optimismSatellite = ISatellite(optimismSatelliteAddress);

        optimismSatellite.registerSatellite(11155111, l1SatelliteAddress, address(0x0), l1SatelliteAddress, 0);
        
        vm.stopBroadcast();
    }
}