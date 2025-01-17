// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import {IStarknet} from "interfaces/external/IStarknet.sol";

/// @notice Module that fetches the block hash of blocks from Starknet
/// @dev It needs to be deployed on the chain that Starknet settles on (L1)
interface IStarknetBlockHashFetcherModule {
    struct StarknetBlockHashFetcherModuleStorage {
        IStarknet starknetContract;
        // Either Starknet or Starknet Sepolia chain ID
        uint256 chainId;
    }

    function initStarknetBlockHashFetcherModule(IStarknet starknetContract, uint256 chainId) external;

    /// @notice Fetches the block hash of the latest block
    function starknetFetchBlockHash() external;
}
