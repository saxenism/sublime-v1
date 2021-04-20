const { ethers, network } = require("hardhat");
const { expect } = require("chai");

const BigNumber = ethers.BigNumber;

const ICToken = require("../../build/contracts/Token.json");

const {
  Contracts: { LINK },
} = require("../../existingContracts/compound.json");

const depositValueToTest = BigNumber.from("1000000000000000000"); //10^18 Tokens

const ETH_Yearn_Protocol_Address = "0xe1237aa7f535b0cc33fd973d66cbf830354d16c7";
const AaveWithdrawAccount = "0x11111111deadbeefdeadbeefdeadbeefdeadbeef";
const Binance7 = "0xbe0eb53f46cd790cd13851d5eff43d12404d33e8";

describe.only("Aave Yield", () => {
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

    this.AaveYield = await ethers.getContractFactory("AaveYield");
    this.aaveYield = await this.AaveYield.connect(this.proxyAdmin).deploy();

    this.LINK = new ethers.Contract(LINK, ICToken.abi);

    await network.provider.request({
      method: "hardhat_impersonateAccount",
      params: [Binance7],
    });

    this.Binance7 = await ethers.provider.getSigner(Binance7);
  });

  describe("Init", async () => {
    it("Init Aave Strategy and generate LINK Tokens", async () => {
      await this.LINK.connect(this.Binance7).transfer(
        this.user.address,
        depositValueToTest
      );

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
    });
    it("Init again: should fail", async () => {
      try {
        await this.aaveYield.initialize(
          this.admin.address,
          this.savingsAccount.address,
          "0xDcD33426BA191383f1c9B431A342498fdac73488",
          "0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d",
          "0xb53c1a33016b2dc2ff3653530bff1848a515c8c5"
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
      await this.aaveYield
        .connect(this.admin)
        .updateSavingsAccount(this.mockAddress1.address);
      await this.aaveYield
        .connect(this.admin)
        .updateSavingsAccount(this.savingsAccount.address);
    });

    it("change savings account non-admin should fail", async () => {
      try {
        let receipt = await this.aaveYield
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
    it("change referral code", async () => {
      let existingReferralCode = await this.aaveYield
        .connect(this.mockAddress1)
        .referralCode();
      await this.aaveYield.connect(this.admin).updateReferralCode(10);
      let newReferalCode = await this.aaveYield
        .connect(this.admin)
        .referralCode();
      expect(newReferalCode).equal(10);
      await this.aaveYield
        .connect(this.admin)
        .updateReferralCode(existingReferralCode);
    });
    it("change referral code non admin should fail", async () => {
      try {
        let receipt = await this.aaveYield
          .connect(this.mockAddress1)
          .updateReferralCode(10);
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
