const { ethers, network } = require("hardhat");
const { expect } = require("chai");
const BigNumber = ethers.BigNumber;

const {
  Contracts: { cETH, DAI, cDAI },
} = require("../../existingContracts/compound.json");

const ICToken = require("../../build/contracts/Token.json");
const DAI_Yearn_Protocol_Address = "0xacd43e627e64355f1861cec6d3a6688b31a6f952";

const zeroAddress = "0x0000000000000000000000000000000000000000";
const Binance7 = "0xbe0eb53f46cd790cd13851d5eff43d12404d33e8";
const depositValueToTest = BigNumber.from("1000000000000000000"); //10^18 Tokens

describe("Testing Savings account features", () => {
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
    this.DAI = new ethers.Contract(DAI, ICToken.abi);
    this.cDAI = new ethers.Contract(cDAI, ICToken.abi);

    await this.strategyRegistry.initialize(this.admin.address, 10);

    this.CompoundYield = await ethers.getContractFactory("CompoundYield");
    this.compoundYield = await this.CompoundYield.connect(
      this.proxyAdmin
    ).deploy();

    this.YearnYield = await ethers.getContractFactory("YearnYield");
    this.yearnYield = await this.YearnYield.connect(this.proxyAdmin).deploy();

    this.AaveYield = await ethers.getContractFactory("AaveYield");
    this.aaveYield = await this.AaveYield.connect(this.proxyAdmin).deploy();

    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [Binance7],
    });

    this.Binance7 = await ethers.provider.getSigner(Binance7);
  });

  describe("Switch Strategy Testing", async () => {
    let NoStrategySharesReceived;
    it("Init Strategies", async () => {
      await this.aaveYield.initialize(
        this.admin.address,
        this.savingsAccount.address,
        "0xDcD33426BA191383f1c9B431A342498fdac73488",
        "0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d",
        "0xb53c1a33016b2dc2ff3653530bff1848a515c8c5"
      );
      await this.strategyRegistry
        .connect(this.admin)
        .addStrategy(this.aaveYield.address);

      await this.compoundYield.initialize(
        this.admin.address,
        this.savingsAccount.address
      );

      await this.strategyRegistry
        .connect(this.admin)
        .addStrategy(this.compoundYield.address);

      await this.compoundYield
        .connect(this.admin)
        .updateProtocolAddresses(DAI, cDAI);

      await this.yearnYield.initialize(
        this.admin.address,
        this.savingsAccount.address
      );

      await this.strategyRegistry
        .connect(this.admin)
        .addStrategy(this.yearnYield.address);

      this.yearnYield
        .connect(this.admin)
        .updateProtocolAddresses(this.DAI.address, DAI_Yearn_Protocol_Address);
    });

    it("Add Tokens to no strategy", async () => {
      const totalAmount = depositValueToTest.mul(3);
      await this.DAI.connect(this.Binance7).transfer(
        this.user.address,
        totalAmount
      );
    });

    it("Deposit DAI Tokens", async () => {
      const totalAmount = depositValueToTest.mul(3);
      await this.DAI.connect(this.user).approve(
        this.savingsAccount.address,
        totalAmount
      );
      await this.savingsAccount
        .connect(this.user)
        .depositTo(
          totalAmount,
          DAI,
          zeroAddress,
          this.accountToDeposit.address
        );

      let result = await this.savingsAccount.userLockedBalance(
        this.accountToDeposit.address,
        DAI,
        zeroAddress
      );
      NoStrategySharesReceived = result;
      console.log({ NoStrategySharesReceived });
      expect(result).equal(totalAmount);
    });

    it("switch strategy 1/3 amount to aave", async () => {
      const amountRemaining = depositValueToTest.mul(2);
      await this.savingsAccount
        .connect(this.accountToDeposit)
        .switchStrategy(
          zeroAddress,
          this.aaveYield.address,
          DAI,
          depositValueToTest
        );
      let result = await this.savingsAccount.userLockedBalance(
        this.accountToDeposit.address,
        DAI,
        zeroAddress
      );
      expect(result).equal(
        amountRemaining,
        "Amount remaining in strategy(0) after switching a fraction to other amount"
      );
    });

    it("switch strategy 1/3 amount to compound", async () => {
      const amountRemaining = depositValueToTest.mul(1);
      await this.savingsAccount
        .connect(this.accountToDeposit)
        .switchStrategy(
          zeroAddress,
          this.compoundYield.address,
          DAI,
          depositValueToTest
        );
      let result = await this.savingsAccount.userLockedBalance(
        this.accountToDeposit.address,
        DAI,
        zeroAddress
      );
      expect(result).equal(
        amountRemaining,
        "Amount remaining in strategy(0) after switching a fraction to other amount"
      );
    });

    it("switch strategy 1/3 amount to yearn", async () => {
      const amountRemaining = depositValueToTest.mul(0);
      await this.savingsAccount
        .connect(this.accountToDeposit)
        .switchStrategy(
          zeroAddress,
          this.yearnYield.address,
          DAI,
          depositValueToTest
        );
      let result = await this.savingsAccount.userLockedBalance(
        this.accountToDeposit.address,
        DAI,
        zeroAddress
      );
      expect(result).equal(
        amountRemaining,
        "Amount remaining in strategy(0) after switching a fraction to other amount"
      );
    });
  });
});
