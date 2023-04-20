import { ERC20 } from "./../typechain-types/@openzeppelin/contracts/token/ERC20/ERC20";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { assert, expect } from "chai";
import { network, deployments, ethers } from "hardhat";
import { developmentChains } from "../helper-hardhat-config";
import { IERC20, IPool, ISwapRouter, IWeth, Wallet } from "../typechain-types";

const IPOOL = "0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e";

const DAI = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
const USDC = "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48";
const ISWAPROUTER = "0xE592427A0AEce92De3Edee1F18E0157C05861564";
const WETH9 = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
// const WETH9 = "0x95ad61b0a150d79219dcf64e1e6cc01f0b64c4ce";
// 0x95ad61b0a150d79219dcf64e1e6cc01f0b64c4ce shiba inu

let AMOUNT = 100;

const Weth = ethers.utils.parseEther("1");

!developmentChains.includes(network.name)
  ? describe.skip
  : describe("Wallet Unit Tests", () => {
      let wallet: Wallet;
      let walletContract: Wallet;
      let owner: SignerWithAddress;
      let accounts: SignerWithAddress[];
      let dai: IERC20;
      let usdc: IERC20;
      let iSwapRouter: ISwapRouter;
      let iPool: IPool;
      let IWethContract: IWeth;

      beforeEach(async () => {
        accounts = await ethers.getSigners();
        owner = accounts[0];
        // console.log(owner.address);
        await deployments.fixture(["all"]);
        walletContract = await ethers.getContract("Wallet");
        IWethContract = await ethers.getContractAt("IWeth", WETH9);
        wallet = walletContract.connect(owner);
        dai = await ethers.getContractAt("IERC20", DAI);
        usdc = await ethers.getContractAt("IERC20", USDC);
        iSwapRouter = await ethers.getContractAt("ISwapRouter", ISWAPROUTER);
        iPool = await ethers.getContractAt("IPool", IPOOL);
        await dai.connect(owner).approve(wallet.address, AMOUNT);
        await dai.connect(owner).approve(iPool.address, AMOUNT);
        await IWethContract.deposit({ value: Weth });
        await IWethContract.approve(wallet.address, Weth);
      });

      describe("constructor", () => {
        it("initizlies correctly", async () => {
          const ownerAccount = await wallet.getOwner();

          assert.equal(ownerAccount, owner.address.toString());
        });
      });

      describe("Deposite", () => {
        it("deposits token and correctly update tokenBalance", async () => {
          const previousBalance = await wallet.getTokenBalance(dai.address);
          await wallet.deposit(dai.address, AMOUNT);
          const balance = await wallet.getTokenBalance(dai.address);
          assert.equal(
            balance.toString(),
            (Number(previousBalance) + AMOUNT).toString()
          );
        });

        it("should emit event when deposit", async () => {
          await expect(wallet.deposit(dai.address, AMOUNT)).to.emit(
            wallet,
            "Deposit"
          );
        });
      });

      describe("Withdraw", () => {
        it("should revert when amount is less than 0", async () => {
          await expect(wallet.withdraw(dai.address, 0)).to.be.revertedWith(
            "MoreThanZero"
          );
        });

        it("should revert when insufficient fund", async () => {
          await wallet.deposit(dai.address, AMOUNT);
          await expect(wallet.withdraw(dai.address, 101)).to.be.revertedWith(
            "InsufficientFund"
          );
        });

        it("should correctly update token balance", async () => {
          await wallet.deposit(dai.address, AMOUNT);
          const previousBalance = await wallet.getTokenBalance(dai.address);
          const amount = 50;
          await wallet.withdraw(dai.address, amount);
          const currentBalance = await wallet.getTokenBalance(dai.address);
          assert.equal(
            currentBalance.toString(),
            (Number(previousBalance) - amount).toString()
          );
        });

        it("shuold emit an event after deposit success", async () => {
          expect(await wallet.deposit(dai.address, AMOUNT)).to.emit(
            wallet,
            "Withdraw"
          );
        });
      });
      describe("Swap", () => {
        it("should be able to swap", async () => {
          // await wallet.deposit(dai.address, AMOUNT);

          const daiInitialBal = await dai.balanceOf(owner.address);
          console.log(`dai balance before: ${daiInitialBal.toString()}`);
          const usdcInitialBal = await usdc.balanceOf(owner.address);
          // console.log(`usdc balance before: ${usdcInitialBal.toString()}`);

          const amountIn = ethers.utils.parseUnits("1", "17");
          const amountOutMin = 0;

          await dai.approve(wallet.address, amountIn);
          await dai.approve(iSwapRouter.address, daiInitialBal);
          await wallet.deposit(dai.address, amountIn);

          const tx = await wallet.swap(
            dai.address,
            usdc.address,
            3000,
            amountIn,
            amountOutMin
          );

          const DaiBalanceWallet = await wallet
            .getTokenBalance(dai.address)
            .then((res) => {
              return ethers.utils.parseEther(res.toString());
            });

          assert.equal(DaiBalanceWallet.toString(), "0");
        });
      });

      describe("supplyAaveV3", () => {
        it("should revert when amount is 0", async () => {
          const amountIn = 0;
          await expect(
            wallet.supplyAaveV3(dai.address, amountIn)
          ).to.be.revertedWith("MoreThanZero");
        });

        it("should be able to supply to aave and receive aToken", async () => {
          // console.log(allowance.toString());
          console.log("----");

          await dai.approve(wallet.address, AMOUNT);
          const allowace = await dai.allowance(owner.address, wallet.address);
          // console.log(allowace.toString());
          await dai.approve(iPool.address, AMOUNT);
          await wallet.deposit(dai.address, AMOUNT);

          await wallet.supplyAaveV3(dai.address, AMOUNT);

          const [aTokenAddress, debtTokenAddress] =
            await wallet.getAaveTokenAddress(dai.address);

          const aToken = await ethers.getContractAt("IERC20", aTokenAddress);
          const bal = await aToken.balanceOf(wallet.address);
          // console.log(bal.toString());
          const underlying = (await wallet.balance(dai.address)).underlying;
          // assert.equal(bal.toString(), AMOUNT.toString());
          assert.equal(underlying.toString(), AMOUNT.toString());
        });
      });
      describe("borrowAaveV3", () => {
        beforeEach(async () => {
          const amountIn = ethers.utils.parseEther("1");
          const borrowAmount = ethers.utils.parseEther("0.005");
          await IWethContract.approve(wallet.address, amountIn);
          await wallet.deposit(IWethContract.address, amountIn);
          await wallet.supplyAaveV3(IWethContract.address, amountIn);
        });

        it("should revert when amount is 0", async () => {
          const amountIn = 0;
          await expect(
            wallet.borrowAaveV3(dai.address, amountIn, 1)
          ).to.be.revertedWith("MoreThanZero");
        });

        it("should be able to borrow and update DS", async () => {
          const borrowAmount = ethers.utils.parseEther("0.005");

          const userData = await wallet.getUserData(wallet.address);
          // console.log(tx.totalCollateralBase);
          const LTV = userData.ltv;
          const LTVRatio = LTV;
          console.log(LTVRatio.toString());

          // console.log(
          //   "after supplying total totalCollateralBase:" +
          //     userData.totalCollateralBase.toString()
          // );
          // console.log(
          //   "after supplying total availableBorrowsBase:" +
          //     userData.availableBorrowsBase.toString()
          // );

          const borrowTx = await wallet.borrowAaveV3(
            dai.address,
            borrowAmount,
            2
          );
          // console.log(borrowTx);
          console.log(borrowTx.gasPrice?.toString());

          const daiAfter = await wallet.getTokenBalance(dai.address);

          const txAfter = await wallet.getUserData(wallet.address);

          assert.equal(daiAfter.toString(), borrowAmount.toString());
        });
      });

      describe("repay", () => {
        beforeEach(async () => {
          const amountIn = ethers.utils.parseEther("1");
          const borrowAmount = ethers.utils.parseEther("0.005");
          await IWethContract.approve(wallet.address, amountIn);
          await wallet.deposit(IWethContract.address, amountIn);
          await wallet.supplyAaveV3(IWethContract.address, amountIn);
          const borrowTx = await wallet.borrowAaveV3(
            dai.address,
            borrowAmount,
            2
          );
        });

        it("should be able to repay", async () => {
          const borrowAmount = ethers.utils.parseEther("0.005");
          await wallet.repayAaveV3(dai.address, borrowAmount, 2);
          const daiBal = await wallet.getTokenBalance(dai.address);

          assert.equal(daiBal.toString(), "0");
        });
      });

      describe("withdraw", () => {
        it("should be able to withdraw", async () => {
          const amountIn = ethers.utils.parseEther("1");
          await IWethContract.approve(wallet.address, amountIn);
          await wallet.deposit(IWethContract.address, amountIn);
          await wallet.supplyAaveV3(IWethContract.address, amountIn);
          await wallet.withdrawAaveV3(IWethContract.address, amountIn);
        });
      });
    });
