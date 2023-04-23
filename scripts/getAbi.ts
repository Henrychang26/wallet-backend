import axios from "axios";
import { ethers } from "ethers";
import { ethers as ETHERS } from "hardhat";

const address = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const apiKey = "UAGW47SJUA915NFMB3E4A2JMUM7B3ZRHZ5";
const etherScanUrl = `https://api.etherscan.io/api?module=contract&action=getabi&address=${address}&apikey=${apiKey}`;
const infuraUrl =
  "https://eth-mainnet.g.alchemy.com/v2/5AGf94eZJ1ybpz-34w6oxatTfu4OkAKs";

const getAbi = async () => {
  const res = await axios.get(etherScanUrl);
  const abi = JSON.parse(res.data.result);
  // console.log("🚀 ~ file: Axios.ts:12 ~ getAbi ~ abi:", abi);

  const provider = new ethers.providers.JsonRpcProvider(infuraUrl);
  const contract = new ethers.Contract(address, abi, provider);

  const name = await contract.name();
  // console.log("🚀 ~ file: Axios.ts:18 ~ getAbi ~ name:", name.toString());
  const totalSupply = await contract.totalSupply();
  // console.log(
  //   "🚀 ~ file: Axios.ts:20 ~ getAbi ~ totalSupply:",
  //   totalSupply.toString()
  // );

  const accounts = await ETHERS.getSigners();
  const account1 = accounts[0];
  const account2 = accounts[1];

  // await contract.mint(account, 10000, provider);
  // const bal = await contract.balanceOf(account);
  // console.log(bal.toString());

  const IDai = await ETHERS.getContractAt("IDai", address);
  await IDai.mint(account1.address, 100000);
  await IDai.approve(account1.address, 100000);
  // const bal = IDai.balanceOf(account.address);
  const tx = await IDai.connect(account1.address).transfer(
    account2.address,
    100000
  );
  console.log(tx);
  // console.log(bal.toString());
};

getAbi();

// const axios = require("axios");
// const { ethers } = require("ethers");

// const address = "0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599";
// const apiKey = "UAGW47SJUA915NFMB3E4A2JMUM7B3ZRHZ5";
// const url = `https://api.etherscan.io/api?module=contract&action=getabi&address=${address}&apikey=${apiKey}`;
// const rpcURL =
//   "https://eth-mainnet.g.alchemy.com/v2/5AGf94eZJ1ybpz-34w6oxatTfu4OkAKs";

// const getNamedAccounts();

// const ABI = async () => {
//   const res = await axios.get(url);
//   const abi = await JSON.parse(res.data.result);

//   const provider = await ethers.providers.JsonRpcProvider(rpcURL);

//   const wbtc = await ethers.Contract(address, abi, provider);

//   await wbtc.mint(provider, 10000);

//   const bal = wbtc.connect.balanceOf(provider);
//   console.log(bal);
// };

// ABI();
