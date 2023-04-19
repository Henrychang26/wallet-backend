import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { Wallet } from "ethers";
import { network, deployments, getNamedAccounts, ethers } from "hardhat";
import { developmentChains } from "../../helper-hardhat-config";
import { IERC20, ISwapRouter, IPool } from "../../typechain-types";

const DAI = "0x6B175474E89094C44Da98b954EedeAC495271d0F";

developmentChains.includes(network.name)
  ? describe.skip
  : describe("Wallet Unit Tests", () => {
      let wallet: Wallet;
      let walletContract: any;
      let owner: SignerWithAddress;

      let dai: IERC20;
      let usdc: IERC20;
      let iSwapRouter: ISwapRouter;
      let iPool: IPool;
      let deployer: string;
      // let IWethContract: IWeth;

      beforeEach(async () => {
        deployer = (await getNamedAccounts()).deployer;
        walletContract = await ethers.getContract("Wallet", deployer);
        dai = await ethers.getContractAt("IERC20", DAI);
      });

      describe("borrow", () => {
        it("should be able to borrow", async () => {
          await wallet.deposit();
        });
      });
    });
