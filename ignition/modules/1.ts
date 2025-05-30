import buildSatelliteDeployment, { ModuleName } from "../SatelliteDeployment";

export const modules: ModuleName[] = [
  "OwnershipModule",
  "SatelliteConnectionRegistryModule",
  "SatelliteInspectorModule",
  "MmrCoreModule",
  "EvmFactRegistryModule",
  "DataProcessorModule",
  "EvmOnChainGrowingModule",
  "EvmSharpMmrGrowingModule",
  "StarknetSharpMmrGrowingModule",
  "NativeParentHashFetcherModule",
  "StarknetParentHashFetcherModule",
  "UniversalSenderModule",
  "L1ToStarknetSenderModule",
  "LegacyContractsInteractionModule",
];
export default buildSatelliteDeployment("11155111", modules);
