import { HardhatUserConfig, vars } from "hardhat/config";
import "@nomicfoundation/hardhat-foundry";
import "@nomicfoundation/hardhat-ignition-ethers";
import "@matterlabs/hardhat-zksync";
import "@matterlabs/hardhat-zksync-verify";
import "@nomicfoundation/hardhat-toolbox";

import dotenv from "dotenv";
dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.28",
    settings: {
      viaIR: true,
      optimizer: {
        enabled: true,
        details: {
          yulDetails: {
            optimizerSteps: "u",
          },
        },
      },
    },
  },
  paths: {
    sources: "./src",
  },
  networks: {
    mainnet: {
      url: `https://eth-mainnet.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY as string],
      chainId: 1,
    },
    sepolia: {
      url: `https://eth-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY as string],
      chainId: 11155111,
    },
    zkSyncSepolia: {
      url: "https://sepolia.era.zksync.dev",
      ethNetwork: "sepolia",
      accounts: [process.env.PRIVATE_KEY as string],
      zksync: true,
      verifyURL:
        "https://explorer.sepolia.era.zksync.dev/contract_verification",
      chainId: 300,
    },
    optimismSepolia: {
      url: `https://opt-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY as string],
      chainId: 11155420,
    },
    arbitrumSepolia: {
      url: `https://arb-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY as string],
      chainId: 421614,
    },
    curtis: {
      url: "https://curtis.rpc.caldera.xyz/http",
      accounts: [process.env.PRIVATE_KEY as string],
      chainId: 33111,
    },
    worldChainSepolia: {
      url: `https://worldchain-sepolia.g.alchemy.com/v2/${process.env.ALCHEMY_API_KEY}`,
      accounts: [process.env.PRIVATE_KEY as string],
      chainId: 4801,
    },
  },
  etherscan: {
    apiKey: {
      mainnet: process.env.L1_ETHERSCAN_API_KEY as string,
      sepolia: process.env.L1_ETHERSCAN_API_KEY as string,
      zkSyncSepolia: process.env.ZKSYNC_ETHERSCAN_API_KEY as string,
      optimismSepolia: process.env.OPTIMISM_ETHERSCAN_API_KEY as string,
      arbitrumSepolia: process.env.ARBITRUM_ETHERSCAN_API_KEY as string,
      curtis: process.env.CURTIS_ETHERSCAN_API_KEY as string,
      worldChainSepolia: process.env.WORLDCHAIN_ETHERSCAN_API_KEY as string,
    },
    customChains: [
      {
        network: "mainnet",
        chainId: 1,
        urls: {
          apiURL: "https://api.etherscan.io/api",
          browserURL: "https://etherscan.io",
        },
      },
      {
        network: "sepolia",
        chainId: 11155111,
        urls: {
          apiURL: "https://api-sepolia.etherscan.io/api",
          browserURL: "https://sepolia.etherscan.io",
        },
      },
      {
        network: "zkSyncSepolia",
        chainId: 300,
        urls: {
          apiURL: "https://api-sepolia-era.zksync.network/api",
          browserURL: "https://sepolia-era.zksync.network",
        },
      },
      {
        network: "optimismSepolia",
        chainId: 11155420,
        urls: {
          apiURL: "https://api-sepolia-optimistic.etherscan.io/api",
          browserURL: "https://sepolia-optimism.etherscan.io",
        },
      },
      {
        network: "arbitrumSepolia",
        chainId: 421614,
        urls: {
          apiURL: "https://api-sepolia.arbiscan.io/api",
          browserURL: "https://sepolia.arbiscan.io",
        },
      },
      {
        network: "curtis", // ApeChain sepolia
        chainId: 33111,
        urls: {
          apiURL: "https://curtis.explorer.caldera.xyz/api",
          browserURL: "https://curtis.explorer.caldera.xyz",
        },
      },
      {
        network: "worldChainSepolia",
        chainId: 4801,
        urls: {
          apiURL: "https://api-sepolia.worldscan.org/api",
          browserURL: "https://sepolia.worldscan.org",
        },
      },
      {
        network: "localhost",
        chainId: 31337,
        urls: {
          apiURL: "http://localhost:8545",
          browserURL: "http://localhost:8545",
        },
      },
    ],
  },
};

export default config;
