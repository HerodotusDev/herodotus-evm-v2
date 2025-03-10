// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import {ISatellite} from "src/interfaces/ISatellite.sol";
import {INativeParentHashFetcherModule} from "src/interfaces/modules/parent-hash-fetching/INativeParentHashFetcherModule.sol";

/// @notice Fetches parent hashes for the native chain
/// @notice for example if deployed on Ethereum, it will fetch parent hashes from Ethereum
contract NativeParentHashFetcherModule is INativeParentHashFetcherModule {
    bytes32 public constant KECCAK_HASHING_FUNCTION = keccak256("keccak");

    /// @inheritdoc INativeParentHashFetcherModule
    function nativeFetchParentHash(uint256 blockNumber) external {
        bytes32 parentHash = blockhash(blockNumber - 1);
        require(parentHash != bytes32(0), "ERR_PARENT_HASH_NOT_AVAILABLE");

        ISatellite(address(this))._receiveParentHash(block.chainid, KECCAK_HASHING_FUNCTION, blockNumber, parentHash);
    }
}
