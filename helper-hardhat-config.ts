import { ethers } from "hardhat";

export interface networkConfigItem {
  name?: string;
  gasLane?: string;
  gasLimit?: number;
  addressProvider?: string;
}

export interface networkConfigInfo {
  [key: number]: networkConfigItem;
}

export const networkConfig: networkConfigInfo = {
  31337: {
    name: "localhost",
    gasLimit: 500000,
    addressProvider: "0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e",
  },
  11155111: {
    name: "sepolia",
    addressProvider: "0x0496275d34753A48320CA58103d5220d394FF77F",
  },
  1: {
    name: "mainnet",
    gasLimit: 500000,
    addressProvider: "0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e",
  },
};

export const developmentChains = ["hardhat", "localhost"];
export const VERIFICATION_BLOCK_CONFIRMATIONS = 6;
export const frontEndContractsFile =
  "../nextjs-smartcontract-lottery-fcc/constants/contractAddresses.json";
export const frontEndAbiFile =
  "../nextjs-smartcontract-lottery-fcc/constants/abi.json";
