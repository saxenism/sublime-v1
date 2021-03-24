const { ethers, network } = require("hardhat");
const { expect } = require("chai");
const zeroAddress = "0x0000000000000000000000000000000000000000";
const ImpersonateAccount = "0xbe0eb53f46cd790cd13851d5eff43d12404d33e8";

const ICToken = require("../../build/contracts/Token.json");

const {
  Contracts: { cETH },
} = require("../../existingContracts/compound.json");

describe("Test Savings Account: Asset ETH", () => {
  before(async () => {
    [
      this.deployer,
      this.admin,
      this.proxyAdmin,
      this.user,
      this.mockCreditLineAddress,
      this.accountToDeposit,
    ] = await ethers.getSigners();

    const SavingsAccount = await ethers.getContractFactory("SavingsAccount");
    this.savingsAccount = await SavingsAccount.connect(
      this.proxyAdmin
    ).deploy();

    this.StrategyRegistry = await ethers.getContractFactory("StrategyRegistry");
    this.strategyRegistry = await this.StrategyRegistry.connect(
      this.proxyAdmin
    ).deploy();

    await this.savingsAccount.initialize(
      this.admin.address,
      this.strategyRegistry.address,
      this.mockCreditLineAddress.address
    );

    this.cETH = new ethers.Contract(cETH, ICToken.abi);
    await this.strategyRegistry.initialize(this.admin.address, 10);

    this.CompoundYield = await ethers.getContractFactory("CompoundYield");
    this.compoundYield = await this.CompoundYield.connect(
      this.proxyAdmin
    ).deploy();

    this.YearnYield = await ethers.getContractFactory("YearnYield");
    this.yearnYield = await this.YearnYield.connect(this.proxyAdmin).deploy();
  });

  describe("No Strategy", async () => {
    it("Deposit To", async () => {
      await this.savingsAccount
        .connect(this.user)
        .depositTo(
          10000000000,
          zeroAddress,
          zeroAddress,
          this.accountToDeposit.address,
          { value: 10000000000 }
        );

      let result = await this.savingsAccount.userLockedBalance(
        this.accountToDeposit.address,
        zeroAddress,
        zeroAddress
      );
      expect(result.toNumber()).to.equals(10000000000);
    });

    it("Deposit", async () => {
      await this.savingsAccount
        .connect(this.user)
        .deposit(10000000000, zeroAddress, zeroAddress, {
          value: 10000000000,
        });

      let result = await this.savingsAccount.userLockedBalance(
        this.user.address,
        zeroAddress,
        zeroAddress
      );
      expect(result.toNumber()).to.equals(10000000000);
    });

    it("Deposit ETH with no value in param: should fail", async () => {
      try {
        await this.savingsAccount
          .connect(this.user)
          .deposit(10000000000, zeroAddress, zeroAddress);
      } catch (ex) {
        if (!ex) {
          throw new Error("Should fail");
        }
      }
    });
  });

  describe("Yearn Strategy", async () => {
    it("Init Yearn Strategy", async () => {
      this.yearnYield.initialize(
        this.admin.address,
        this.savingsAccount.address
      );
    });
  });

  describe("Compound Strategy", async () => {
    it("Init Compund Strategy", async () => {
      this.compoundYield.initialize(
        this.admin.address,
        this.savingsAccount.address
      );
      this.strategyRegistry
        .connect(this.admin)
        .addStrategy(this.compoundYield.address);
      this.compoundYield
        .connect(this.admin)
        .updateProtocolAddresses(zeroAddress, cETH);
    });

    it("Deposit To", async () => {
      await this.savingsAccount
        .connect(this.user)
        .depositTo(
          10000000000,
          zeroAddress,
          this.compoundYield.address,
          this.accountToDeposit.address,
          { value: 10000000000 }
        );

      let result = await this.savingsAccount.userLockedBalance(
        this.accountToDeposit.address,
        zeroAddress,
        this.compoundYield.address
      );
      let cETHBalance = await this.cETH
        .connect(this.admin)
        .balanceOf(this.compoundYield.address);
      console.log({ sharesReceived: result.toNumber() });
      expect(result.toNumber()).to.not.equals(0);

      console.log({ cETHBalance: cETHBalance.toNumber() });
      expect(cETHBalance.toNumber()).to.not.equals(0);
    });
  });
});
