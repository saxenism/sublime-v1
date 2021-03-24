const { ethers } = require("hardhat");
const { expect } = require("chai");

const zeroAddress = "0x0000000000000000000000000000000000000000";
const wethGateway = "0xDcD33426BA191383f1c9B431A342498fdac73488";
const protocolDataProvider = "0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d";
const lendingPoolAddressesProvider =
  "0xb53c1a33016b2dc2ff3653530bff1848a515c8c5";

const {
  Contracts: { cETH },
} = require("../existingContracts/compound.json");

describe("Savings account tests", () => {
  before(async () => {
    [
      this.deployer,
      this.admin,
      this.proxyAdmin,
      this.otherAccount,
      this.tempCreditLine,
      this.depositToAccount,
      this.savings,

      // AAVE Related Addresses
      this.wethGateway,
      this.protocolDataProvider,
      this.lendingPoolAddressesProvider,
    ] = await ethers.getSigners();

    const SavingsAccount = await ethers.getContractFactory("SavingsAccount");
    this.savingsAccount = await SavingsAccount.connect(
      this.proxyAdmin
    ).deploy();

    this.StrategyRegistry = await ethers.getContractFactory("StrategyRegistry");
    this.strategyRegistry = await this.StrategyRegistry.connect(
      this.proxyAdmin
    ).deploy();

    this.AaveYield = await ethers.getContractFactory("AaveYield");
    this.CompoundYield = await ethers.getContractFactory("CompoundYield");
    this.YearnYield = await ethers.getContractFactory("YearnYield");

    this.aaveYield = await this.AaveYield.connect(this.proxyAdmin).deploy();
    this.compoundYield = await this.CompoundYield.connect(
      this.proxyAdmin
    ).deploy();
    this.yearnYield = await this.YearnYield.connect(this.proxyAdmin).deploy();

    this.Token = await ethers.getContractFactory("Token");
    this.token = await this.Token.connect(this.proxyAdmin).deploy(
      "Some Token",
      "TKN",
      "100000000000000000000"
    );

    // const CreditLine = await ethers.getContractFactory("CreditLine");
    // this.creditLine = await CreditLine.connect(this.proxyAdmin).deploy();
  });

  describe("Contract Deployments", async () => {
    it("Check deployment", async () => {
      expect(this.savingsAccount.address).is.not.null;
      expect(this.strategyRegistry.address).is.not.null;
      expect(this.compoundYield.address).is.not.null;
      expect(this.token.address).is.not.null;
      expect(this.aaveYield.address).is.not.null;
      expect(this.yearnYield.address).is.not.null;
    });
  });

  describe("Token", async () => {
    it("Transfer to depositToAccount", async () => {
      await this.token
        .connect(this.proxyAdmin)
        .transfer(this.depositToAccount.address, "10000000000000000000");
    });
  });

  describe("Yields", async () => {
    it("Initialize", async () => {
      this.aaveYield.initialize(
        this.admin.address,
        this.savingsAccount.address,
        wethGateway,
        protocolDataProvider,
        lendingPoolAddressesProvider
      );
      this.compoundYield.initialize(
        this.admin.address,
        this.savingsAccount.address
      );
      this.yearnYield.initialize(
        this.admin.address,
        this.savingsAccount.address
      );
    });
  });

  describe("Strategy Registry", async () => {
    it("Initialize Contract", async () => {
      await this.strategyRegistry.initialize(this.admin.address, 10);
    });

    it("Add Strategy", async () => {
      await this.strategyRegistry
        .connect(this.admin)
        .addStrategy(this.aaveYield.address);

      await this.strategyRegistry
        .connect(this.admin)
        .addStrategy(this.compoundYield.address);

      await this.strategyRegistry
        .connect(this.admin)
        .addStrategy(this.yearnYield.address);
    });
  });

  describe("Savings account", async () => {
    it("Initialize contract", async () => {
      await this.savingsAccount.initialize(
        this.admin.address,
        this.strategyRegistry.address,
        this.tempCreditLine.address
      );
    });

    it("Check owner", async () => {
      let owner = await this.savingsAccount.owner();
      expect(owner).to.equals(this.admin.address);
    });

    it("Update Strategy: owner", async () => {
      await this.savingsAccount
        .connect(this.admin)
        .updateStrategyRegistry(this.strategyRegistry.address);
    });

    it("Update Strategy: non-owner: should fail", async () => {
      try {
        await this.savingsAccount
          .connect(this.otherAccount)
          .updateStrategyRegistry(this.strategyRegistry.address);
      } catch (ex) {
        if (!ex) {
          throw new Error(
            "Update Strategy: non-owner: should fail. (It is passing)"
          );
        }
      }
    });

    it("Increase Allowance: Savings Account", async () => {
      await this.token
        .connect(this.depositToAccount)
        .increaseAllowance(this.savingsAccount.address, "10000000000000000000");
    });

    it("DepositTo: strategy 0", async () => {
      for (let index = 0; index < 2; index++) {
        await this.savingsAccount
          .connect(this.depositToAccount)
          .depositTo(
            "1",
            this.token.address,
            zeroAddress,
            this.otherAccount.address
          );
      }
      let result = await this.savingsAccount.userLockedBalance(
        this.otherAccount.address,
        this.token.address,
        zeroAddress
      );
      expect(result).equal("2");
    });

    it("Approve Allowance: Strategy Compound", async () => {
      await this.token
        .connect(this.depositToAccount)
        .approve(this.compoundYield.address, "10000000000000000000");
    });

    it("Strategy Compound: Update Protocol Address", async () => {
      await this.compoundYield
        .connect(this.admin)
        .updateProtocolAddresses(this.token.address, cETH);
    });

    it("DepositTo: Strategy Compound", async () => {
      await this.savingsAccount
        .connect(this.depositToAccount)
        .depositTo(
          "1",
          this.token.address,
          this.compoundYield.address,
          this.otherAccount.address
        );
    });
  });
});
