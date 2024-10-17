// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import {ILibSatellite} from "./ILibSatellite.sol";
import {IOwnershipModule} from "./modules/IOwnershipModule.sol";
import {IMMRsCoreModule} from "./modules/IMMRsCoreModule.sol";
import {ISatelliteInspectorModule} from "./modules/ISatelliteInspectorModule.sol";
import {ISatelliteMaintenanceModule} from "./modules/ISatelliteMaintenanceModule.sol";
import {INativeSharpFactsAggregatorModule} from "./modules/INativeSharpFactsAggregatorModule.sol";
import {INativeFactsRegistryModule} from "./modules/INativeFactsRegistryModule.sol";
import {INativeParentHashesFetcherModule} from "./modules/INativeParentHashesFetcherModule.sol";

interface ISatellite is
    ILibSatellite,
    IOwnershipModule,
    IMMRsCoreModule,
    ISatelliteInspectorModule,
    ISatelliteMaintenanceModule,
    INativeSharpFactsAggregatorModule,
    INativeFactsRegistryModule,
    INativeParentHashesFetcherModule
{}
