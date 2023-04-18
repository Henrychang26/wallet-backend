import { ethers } from "hardhat";

export interface networkConfigItem {
  name?: string;
  subscriptionId?: string;
  gasLane?: string;
  keepersUpdateInterval?: string;
  raffleEntranceFee?: string;
  callbackGasLimit?: string;
  vrfCoordinatorV2?: string;
  gasLimit?: number;
}

export interface networkConfigInfo {
  [key: number]: networkConfigItem;
}

export const networkConfig: networkConfigInfo = {
  31337: {
    name: "localhost",
    gasLimit: 500000,
  },
  11155111: {
    name: "sepolia",
  },
  1: {
    name: "mainnet",
    gasLimit: 500000,
  },
};

export const developmentChains = ["hardhat", "localhost"];
export const VERIFICATION_BLOCK_CONFIRMATIONS = 6;
export const frontEndContractsFile =
  "../nextjs-smartcontract-lottery-fcc/constants/contractAddresses.json";
export const frontEndAbiFile =
  "../nextjs-smartcontract-lottery-fcc/constants/abi.json";
