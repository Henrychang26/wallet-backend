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

let AMOUNT = 100;

const Weth = ethers.utils.parseEther("1");

!developmentChains.includes(network.name)
  ? describe.skip
  : describe("Wallet Unit Tests", () => {
      let wallet: Wallet;
      let walletContract: Wallet;
      let owner: SignerWithAddress;
      let outsideAccount: SignerWithAddress;
      let accounts: SignerWithAddress[];
      let dai: IERC20;
      let usdc: IERC20;
      let iSwapRouter: ISwapRouter;
      let iPool: IPool;
      let IWethContract: IWeth;

      beforeEach(async () => {
        accounts = await ethers.getSigners();
        owner = accounts[0];
        outsideAccount = accounts[1];
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
        // const wethBal = await wallet.getTokenBalance(IWethContract.address);
        const wethBal = await IWethContract.balanceOf(owner.address);
        console.log(wethBal.toString());
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

          console.log("----");

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
      describe.only("borrowAaveV3", () => {
        it("should revert when amount is 0", async () => {
          const amountIn = 0;
          await expect(
            wallet.borrowAaveV3(dai.address, amountIn, 1)
          ).to.be.revertedWith("MoreThanZero");
        });

        it("should be able to borrow and update DS", async () => {
          const amountIn = ethers.utils.parseEther("1");
          const borrowAmount = ethers.utils.parseEther("0.005");
          await IWethContract.approve(wallet.address, amountIn);
          await IWethContract.approve(iPool.address, amountIn);
          await wallet.deposit(IWethContract.address, amountIn);

          const bal = await wallet.getTokenBalance(IWethContract.address);
          console.log("after deposited weth wallet balance " + bal.toString());

          await wallet.supplyAaveV3(IWethContract.address, amountIn);
          // await wallet.enableReserveAsCollateral(IWethContract.address);
          // ^does not have any impact for supported tokens

          const bal1 = await wallet.getTokenBalance(IWethContract.address);
          console.log(
            "after supplying weth wallet balance (should be 0)" +
              bal1.toString()
          );

          const tx = await wallet.getUserData(wallet.address);
          // console.log(tx.totalCollateralBase);
          console.log(
            "after supplying total totalCollateralBase:" +
              tx.totalCollateralBase.toString()
          );
          console.log(
            "after supplying total availableBorrowsBase:" +
              tx.availableBorrowsBase.toString()
          );

          const daiBefore = await wallet.getTokenBalance(dai.address);
          console.log("Dai before borrowing:" + daiBefore.toString());
          await wallet.borrowAaveV3(dai.address, borrowAmount, 1);

          const daiAfter = await wallet.getTokenBalance(dai.address);
          console.log("Dai after borrowing" + daiAfter.toString());

          const txAfter = await wallet.getUserData(wallet.address);
          // console.log(txAfter.totalCollateralBase);
          console.log("Total Debt:" + txAfter.totalDebtBase.toString());
        });
      });
    });
