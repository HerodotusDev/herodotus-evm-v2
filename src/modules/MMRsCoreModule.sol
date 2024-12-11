// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.27;

import {LibSatellite} from "libraries/LibSatellite.sol";
import {IMMRsCoreModule} from "interfaces/modules/IMMRsCoreModule.sol";
import {ISatellite} from "interfaces/ISatellite.sol";

contract MMRsCoreModule is IMMRsCoreModule {
    // ========================= Constants ========================= //

    bytes32 public constant KECCAK_HASHING_FUNCTION = keccak256("keccak");
    bytes32 public constant POSEIDON_HASHING_FUNCTION = keccak256("poseidon");

    // Default roots for new aggregators:
    // poseidon_hash(1, "brave new world")
    bytes32 public constant POSEIDON_MMR_INITIAL_ROOT = 0x06759138078831011e3bc0b4a135af21c008dda64586363531697207fb5a2bae;

    // keccak_hash(1, "brave new world")
    bytes32 public constant KECCAK_MMR_INITIAL_ROOT = 0x5d8d23518dd388daa16925ff9475c5d1c06430d21e0422520d6a56402f42937b;

    // ========================= Other Satellite Modules Only Functions ========================= //

    /// @notice Receiving a recent block hash obtained on-chain directly on this chain or sent in a message from another one (eg. L1 -> L2)
    /// @notice saves the parent hash of the block number (from a given chain) in the contract storage
    function _receiveBlockHash(uint256 chainId, bytes32 hashingFunction, uint256 blockNumber, bytes32 parentHash) external {
        LibSatellite.enforceIsSatelliteModule();
        ISatellite.SatelliteStorage storage s = LibSatellite.satelliteStorage();
        s.receivedParentHashes[chainId][hashingFunction][blockNumber] = parentHash;
        emit ParentHashReceived(chainId, blockNumber, parentHash, hashingFunction);
    }

    /// @notice Most commonly creates a new branch from an L1 message, the sent MMR info comes from an L1 aggregator
    /// @param newMmrId the ID of the MMR to create
    /// @param rootsForHashingFunctions the roots of the MMR -> abi endoded hashing function => MMR root
    /// @param mmrSize the size of the MMR
    /// @param accumulatedChainId the ID of the chain that the MMR accumulates
    /// @param originChainId the ID of the chain from which the new MMR will be created
    /// @param originalMmrId the ID of the MMR from which the new MMR will be created
    /// @param isSiblingSynced whether the MMR is sibling synced
    function _createMmrFromForeign(
        uint256 newMmrId,
        RootForHashingFunction[] calldata rootsForHashingFunctions,
        uint256 mmrSize,
        uint256 accumulatedChainId,
        uint256 originChainId,
        uint256 originalMmrId,
        bool isSiblingSynced
    ) external {
        LibSatellite.enforceIsSatelliteModule();
        require(newMmrId != LibSatellite.EMPTY_MMR_ID, "NEW_MMR_ID_0_NOT_ALLOWED");

        require(rootsForHashingFunctions.length > 0, "INVALID_ROOTS_LENGTH");

        ISatellite.SatelliteStorage storage s = LibSatellite.satelliteStorage();

        // Create a new MMR
        for (uint256 i = 0; i < rootsForHashingFunctions.length; i++) {
            bytes32 root = rootsForHashingFunctions[i].roots;
            bytes32 hashingFunction = rootsForHashingFunctions[i].hashingFunctions;

            require(root != LibSatellite.NO_MMR_ROOT, "ROOT_0_NOT_ALLOWED");
            require(s.mmrs[accumulatedChainId][newMmrId][hashingFunction].latestSize == LibSatellite.NO_MMR_SIZE, "NEW_MMR_ALREADY_EXISTS");
            s.mmrs[accumulatedChainId][newMmrId][hashingFunction].latestSize = mmrSize;
            s.mmrs[accumulatedChainId][newMmrId][hashingFunction].mmrSizeToRoot[mmrSize] = root;
            s.mmrs[accumulatedChainId][newMmrId][hashingFunction].isSiblingSynced = isSiblingSynced;
        }

        // Emit the event
        emit MmrCreatedFromForeign(newMmrId, mmrSize, accumulatedChainId, originChainId, rootsForHashingFunctions, originalMmrId);
    }

    // ========================= Core Functions ========================= //

    /// @notice Creates a new MMR that is a clone of an already existing MMR or an empty MMR if originalMmrId is 0 (in that case mmrSize is ignored)
    /// @param newMmrId the ID of the new MMR
    /// @param originalMmrId the ID of the MMR from which the new MMR will be created - if 0 it means an empty MMR will be created
    /// @param accumulatedChainId the ID of the chain that the MMR accumulates
    /// @param mmrSize size at which the MMR will be copied
    /// @param hashingFunctions the hashing functions used in the MMR - if more than one, the MMR will be sibling synced and require being a satellite module to call
    function createMmrFromDomestic(uint256 newMmrId, uint256 originalMmrId, uint256 accumulatedChainId, uint256 mmrSize, bytes32[] calldata hashingFunctions) external {
        require(newMmrId != LibSatellite.EMPTY_MMR_ID, "NEW_MMR_ID_0_NOT_ALLOWED");
        require(hashingFunctions.length > 0, "INVALID_HASHING_FUNCTIONS_LENGTH");

        bool isSiblingSynced = hashingFunctions.length > 1;
        if (isSiblingSynced) {
            LibSatellite.enforceIsSatelliteModule();
        }

        RootForHashingFunction[] memory rootsForHashingFunctions = new RootForHashingFunction[](hashingFunctions.length);
        ISatellite.SatelliteStorage storage s = LibSatellite.satelliteStorage();

        for (uint256 i = 0; i < hashingFunctions.length; i++) {
            require(s.mmrs[accumulatedChainId][newMmrId][hashingFunctions[i]].latestSize == LibSatellite.NO_MMR_SIZE, "NEW_MMR_ALREADY_EXISTS");

            bytes32 mmrRoot;
            if (originalMmrId == LibSatellite.EMPTY_MMR_ID) {
                // Create an empty MMR
                mmrRoot = _getInitialMmrRoot(hashingFunctions[i]);
                mmrSize = LibSatellite.EMPTY_MMR_SIZE;
            } else {
                // Load existing MMR data
                mmrRoot = s.mmrs[accumulatedChainId][originalMmrId][hashingFunctions[i]].mmrSizeToRoot[mmrSize];
                // Ensure the given MMR exists
                require(mmrRoot != LibSatellite.NO_MMR_ROOT, "SRC_MMR_NOT_FOUND");

                if (isSiblingSynced) {
                    require(s.mmrs[accumulatedChainId][newMmrId][hashingFunctions[i]].isSiblingSynced == isSiblingSynced, "ORIGINAL_MMR_NOT_SIBLING_SYNCED");
                }
            }

            // Copy the MMR data to the new MMR
            s.mmrs[accumulatedChainId][newMmrId][hashingFunctions[i]].latestSize = mmrSize;
            s.mmrs[accumulatedChainId][newMmrId][hashingFunctions[i]].mmrSizeToRoot[mmrSize] = mmrRoot;
            s.mmrs[accumulatedChainId][newMmrId][hashingFunctions[i]].isSiblingSynced = isSiblingSynced;

            rootsForHashingFunctions[i] = RootForHashingFunction({hashingFunctions: hashingFunctions[i], roots: mmrRoot});
        }

        emit MmrCreatedFromDomestic(newMmrId, mmrSize, accumulatedChainId, originalMmrId, rootsForHashingFunctions);
    }

    /// ========================= Internal functions ========================= //

    function _getInitialMmrRoot(bytes32 hashingFunction) internal pure returns (bytes32) {
        if (hashingFunction == KECCAK_HASHING_FUNCTION) {
            return KECCAK_MMR_INITIAL_ROOT;
        } else if (hashingFunction == POSEIDON_HASHING_FUNCTION) {
            return POSEIDON_MMR_INITIAL_ROOT;
        } else {
            revert("NOT_SUPPORTED_HASHING_FUNCTION");
        }
    }

    // ========================= View functions ========================= //

    function getMMRRoot(uint256 mmrId, uint256 mmrSize, uint256 accumulatedChainId, bytes32 hashingFunction) external view returns (bytes32) {
        ISatellite.SatelliteStorage storage s = LibSatellite.satelliteStorage();
        return s.mmrs[accumulatedChainId][mmrId][hashingFunction].mmrSizeToRoot[mmrSize];
    }

    function getLatestMMRRoot(uint256 mmrId, uint256 accumulatedChainId, bytes32 hashingFunction) external view returns (bytes32) {
        ISatellite.SatelliteStorage storage s = LibSatellite.satelliteStorage();
        uint256 latestSize = s.mmrs[accumulatedChainId][mmrId][hashingFunction].latestSize;
        return s.mmrs[accumulatedChainId][mmrId][hashingFunction].mmrSizeToRoot[latestSize];
    }

    function getLatestMMRSize(uint256 mmrId, uint256 accumulatedChainId, bytes32 hashingFunction) external view returns (uint256) {
        ISatellite.SatelliteStorage storage s = LibSatellite.satelliteStorage();
        return s.mmrs[accumulatedChainId][mmrId][hashingFunction].latestSize;
    }

    function isMMRSiblingSynced(uint256 mmrId, uint256 accumulatedChainId, bytes32 hashingFunction) external view returns (bool) {
        ISatellite.SatelliteStorage storage s = LibSatellite.satelliteStorage();
        return s.mmrs[accumulatedChainId][mmrId][hashingFunction].isSiblingSynced;
    }

    function getReceivedParentHash(uint256 chainId, bytes32 hashingFunction, uint256 blockNumber) external view returns (bytes32) {
        ISatellite.SatelliteStorage storage s = LibSatellite.satelliteStorage();
        return s.receivedParentHashes[chainId][hashingFunction][blockNumber];
    }
}
