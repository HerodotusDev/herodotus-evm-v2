// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import {LibSatellite} from "libraries/LibSatellite.sol";
import {IOwnershipModule} from "interfaces/modules/IOwnershipModule.sol";
import {AccessController} from "libraries/AccessController.sol";

contract OwnershipModule is IOwnershipModule, AccessController {
    function transferOwnership(address _newOwner) external override onlyOwner {
        LibSatellite.setContractOwner(_newOwner);
    }

    function owner() external view override returns (address owner_) {
        owner_ = LibSatellite.contractOwner();
    }
}
