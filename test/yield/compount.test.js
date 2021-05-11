const { ethers, network } = require("hardhat");
const { expect } = require("chai");

const BigNumber = ethers.BigNumber;

const ICToken = require("../../build/contracts/mocks/Token.sol/Token.json");

const {
  Contracts: { BAT, cBAT },
} = require("../../existingContracts/compound.json");

const depositValueToTest = BigNumber.from("1000000000000000000"); //10^18 Tokens

const Binance7 = "0xbe0eb53f46cd790cd13851d5eff43d12404d33e8";

describe("Compound Yield", () => {
  before(async () => {
    [
      this.deployer,
      this.admin,
      this.proxyAdmin,
      this.user,
      this.mockCreditLineAddress,
      this.accountToDeposit,
      this.mockAddress1,
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

    await this.strategyRegistry.initialize(this.admin.address, 10);

    this.CompoundYield = await ethers.getContractFactory("CompoundYield");
    this.compoundYield = await this.CompoundYield.connect(
      this.proxyAdmin
    ).deploy();

    this.BAT = new ethers.Contract(BAT, ICToken.abi);
    this.cBAT = new ethers.Contract(cBAT, ICToken.abi);

    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [Binance7],
    });

    this.Binance7 = await ethers.provider.getSigner(Binance7);
  });

  describe("Init", async () => {
    it("Init Compound Strategy and generate BAT Tokens", async () => {
      await this.BAT.connect(this.Binance7).transfer(
        this.user.address,
        depositValueToTest
      );

      await this.compoundYield.initialize(
        this.admin.address,
        this.savingsAccount.address
      );
      await this.strategyRegistry
        .connect(this.admin)
        .addStrategy(this.compoundYield.address);
    });
    it("Init again: should fail", async () => {
      try {
        await this.compoundYield.initialize(
          this.admin.address,
          this.savingsAccount.address
        );
        throw null;
      } catch (ex) {
        if (!ex) {
          throw new Error("Should fail");
        }
      }
    });
  });

  describe("Update params", async () => {
    it("Change savings account by admin", async () => {
      await this.compoundYield
        .connect(this.admin)
        .updateSavingsAccount(this.mockAddress1.address);
      await this.compoundYield
        .connect(this.admin)
        .updateSavingsAccount(this.savingsAccount.address);
    });

    it("change savings account non-admin should fail", async () => {
      try {
        let receipt = await this.compoundYield
          .connect(this.mockAddress1)
          .updateSavingsAccount(this.mockAddress1.address);
        console.log(receipt);
        throw null;
      } catch (ex) {
        if (!ex) {
          throw new Error("Should fail");
        }
      }
    });
  });
});
