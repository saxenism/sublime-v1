const { ethers, network } = require("hardhat");
const { expect } = require("chai");

const BigNumber = ethers.BigNumber;

const ICToken = require("../../build/contracts/mocks/Token.sol/Token.json");

const {
  Contracts: { DAI },
} = require("../../existingContracts/compound.json");

const depositValueToTest = BigNumber.from("1000000000000000000"); //10^18 Tokens

const Binance7 = "0xbe0eb53f46cd790cd13851d5eff43d12404d33e8";
const DAI_Yearn_Protocol_Address = "0xacd43e627e64355f1861cec6d3a6688b31a6f952";

describe.only("Yearn Yield", () => {
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

    this.YearnYield = await ethers.getContractFactory("YearnYield");
    this.yearnYield = await this.YearnYield.connect(this.proxyAdmin).deploy();

    this.DAI = new ethers.Contract(DAI, ICToken.abi);

    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [Binance7],
    });

    this.Binance7 = await ethers.provider.getSigner(Binance7);
  });

  describe("Init", async () => {
    it("Init Yearn Strategy and generate DAI Tokens", async () => {
      await this.DAI.connect(this.Binance7).transfer(
        this.user.address,
        depositValueToTest
      );

      await this.yearnYield.initialize(
        this.admin.address,
        this.savingsAccount.address
      );
      await this.strategyRegistry
        .connect(this.admin)
        .addStrategy(this.yearnYield.address);
    });
    it("Init again: should fail", async () => {
      try {
        await this.yearnYield.initialize(
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
      await this.yearnYield
        .connect(this.admin)
        .updateSavingsAccount(this.mockAddress1.address);
      await this.yearnYield
        .connect(this.admin)
        .updateSavingsAccount(this.savingsAccount.address);
    });

    it("change savings account non-admin should fail", async () => {
      try {
        let receipt = await this.yearnYield
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
