import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import * as dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.19",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.8.28", // Versão mais recente para as libs do OpenZeppelin
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
    overrides: {
      "@openzeppelin/contracts/token/ERC20/ERC20.sol": {
        version: "0.8.28",
      },
      "@openzeppelin/contracts/utils/Context.sol": {
        version: "0.8.28",
      },
      "contracts/MockERC20.sol": {
        version: "0.8.28", // Força o MockERC20 a usar 0.8.28
      },
    },
  },
  networks: {
    hardhat: {},
    neuraTestnet: {
      url: process.env.NEURA_RPC_URL || "https://testnet-rpc.neuraprotocol.io",
      chainId: 267,
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : [],
    },
  },
  etherscan: {
    apiKey: {
      neuraTestnet: "empty",
    },
    customChains: [
      {
        network: "neuraTestnet",
        chainId: 267,
        urls: {
          apiURL: "https://testnet-blockscout.infra.neuraprotocol.io/api",
          browserURL: "https://testnet-blockscout.infra.neuraprotocol.io",
        },
      },
    ],
  },
  sourcify: {
    enabled: false,
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
};

export default config;