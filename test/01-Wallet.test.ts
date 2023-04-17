import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { assert, expect } from "chai";
import { BigNumber, Contract, ContractInterface } from "ethers";
import { network, deployments, ethers } from "hardhat";
import { developmentChains } from "../helper-hardhat-config";
import { Wallet, Wmatic, Wmatic__factory } from "../typechain-types";

const ISwapRouter = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
const UniswapV3Pool = "0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8";
const IPool = "0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9";

const WMATIC = "0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270";
let AMOUNT = 100;

!developmentChains.includes(network.name)
  ? describe.skip
  : describe("Wallet Unit Tests", () => {
      let wallet: Wallet;
      let walletContract: Wallet;
      let owner: SignerWithAddress;
      let outsideAccount: SignerWithAddress;
      let accounts: SignerWithAddress[];
      let wmatic: Wmatic;

      beforeEach(async () => {
        // const { deployer } = await getNamedAccounts();
        accounts = await ethers.getSigners();
        owner = accounts[0];
        outsideAccount = accounts[1];
        await deployments.fixture(["all"]);
        walletContract = await ethers.getContract("Wallet");
        wallet = walletContract.connect(owner);
        const Wmatic = (await ethers.getContractFactory(
          "Wmatic",
          owner
        )) as Wmatic__factory;
        wmatic = await Wmatic.deploy();

        await wmatic.connect(owner).approve(wallet.address, 1000);
        const allowance = await wmatic
          .connect(owner)
          .allowance(owner.address, wallet.address);
      });

      describe("constructor", () => {
        it("initizlies correctly", async () => {
          const ownerAccount = await wallet.getOwner();

          assert.equal(ownerAccount, owner.address.toString());
        });
      });

      describe("Deposite", () => {
        it("deposits token and correctly update tokenBalance", async () => {
          const previousBalance = await wallet.getTokenBalance(wmatic.address);
          await wallet.deposit(wmatic.address, AMOUNT);
          const balance = await wallet.getTokenBalance(wmatic.address);
          assert.equal(
            balance.toString(),
            (Number(previousBalance) + AMOUNT).toString()
          );
        });

        it("should emit event when deposit", async () => {
          await expect(wallet.deposit(wmatic.address, AMOUNT)).to.emit(
            wallet,
            "Deposit"
          );
        });
      });

      describe("Withdraw", () => {
        it("should revert when amount is less than 0", async () => {
          await expect(wallet.withdraw(wmatic.address, 0)).to.be.revertedWith(
            "MoreThanZero"
          );
        });

        it("should revert when insufficient fund", async () => {
          await wallet.deposit(wmatic.address, AMOUNT);
          await expect(wallet.withdraw(WMATIC, 101)).to.be.revertedWith(
            "InsufficientFund"
          );
        });

        it("should correctly update token balance", async () => {
          await wallet.deposit(wmatic.address, AMOUNT);
          const previousBalance = await wallet.getTokenBalance(wmatic.address);
          const amount = 50;
          await wallet.withdraw(wmatic.address, amount);
          const currentBalance = await wallet.getTokenBalance(wmatic.address);
          assert.equal(
            currentBalance.toString(),
            (Number(previousBalance) - amount).toString()
          );
        });
      });
    });
