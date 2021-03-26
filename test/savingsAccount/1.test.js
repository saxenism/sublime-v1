const { ethers, network } = require("hardhat");
const { expect } = require("chai");

const BigNumber = ethers.BigNumber;

const ICToken = require("../../build/contracts/Token.json");

const {
  Contracts: { cETH },
} = require("../../existingContracts/compound.json");

const ETH_Yearn_Protocol_Address = "0xe1237aa7f535b0cc33fd973d66cbf830354d16c7";

const AaveWithdrawAccount = "0x11111111deadbeefdeadbeefdeadbeefdeadbeef";
const YearnWithdrawAccount = "0x22222222deadbeefdeadbeefdeadbeefdeadbeef";
const CompoundWithdrawAccount = "0x33333333deadbeefdeadbeefdeadbeefdeadbeef";

const zeroAddress = "0x0000000000000000000000000000000000000000";

const depositValueToTest = BigNumber.from(10000000000); //1 ETH

describe.only("Test Savings Account: Asset ETH", () => {
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

    this.AaveYield = await ethers.getContractFactory("AaveYield");
    this.aaveYield = await this.AaveYield.connect(this.proxyAdmin).deploy();
  });

  describe("No Strategy", async () => {
    let NoStrategySharesReceived;
    it("Deposit To", async () => {
      await this.savingsAccount
        .connect(this.user)
        .depositTo(
          depositValueToTest,
          zeroAddress,
          zeroAddress,
          this.accountToDeposit.address,
          { value: depositValueToTest }
        );

      let result = await this.savingsAccount.userLockedBalance(
        this.accountToDeposit.address,
        zeroAddress,
        zeroAddress
      );
      NoStrategySharesReceived = result;
      console.log({ NoStrategySharesReceived });
      expect(result).equal(depositValueToTest);
    });

    it("Deposit", async () => {
      await this.savingsAccount
        .connect(this.user)
        .deposit(depositValueToTest, zeroAddress, zeroAddress, {
          value: depositValueToTest,
        });

      let result = await this.savingsAccount.userLockedBalance(
        this.user.address,
        zeroAddress,
        zeroAddress
      );
      expect(result).equal(depositValueToTest);
    });

    it("Deposit ETH with no value in param: should fail", async () => {
      try {
        await this.savingsAccount
          .connect(this.user)
          .deposit(depositValueToTest, zeroAddress, zeroAddress);
        throw null;
      } catch (ex) {
        if (!ex) {
          throw new Error("Should fail");
        }
      }
    });

    it("Withdraw ETH asset", async () => {
      let lockedBalanceBeforeWithdraw = await this.savingsAccount.userLockedBalance(
        this.user.address,
        zeroAddress,
        zeroAddress
      );
      await this.savingsAccount
        .connect(this.user)
        .withdraw(
          this.user.address,
          depositValueToTest,
          zeroAddress,
          zeroAddress,
          false
        );
      let lockedBalanceAfterWithdraw = await this.savingsAccount.userLockedBalance(
        this.user.address,
        zeroAddress,
        zeroAddress
      );
      expect(lockedBalanceBeforeWithdraw.sub(lockedBalanceAfterWithdraw)).equal(
        depositValueToTest
      );
    });

    it("Withraw ETH shares: should fail", async () => {
      try {
        await this.savingsAccount
          .connect(this.user)
          .withdraw(this.user.address, 1, zeroAddress, zeroAddress, true);
        throw null;
      } catch (ex) {
        if (!ex) {
          throw new Error("Should Fail");
        }
      }
    });
  });

  describe("Aave Strategy", async () => {
    let sharesReceivedWithAave;
    it("Init Aave Strategy", async () => {
      this.aaveYield.initialize(
        this.admin.address,
        this.savingsAccount.address,
        "0xDcD33426BA191383f1c9B431A342498fdac73488",
        "0x057835Ad21a177dbdd3090bB1CAE03EaCF78Fc6d",
        "0xb53c1a33016b2dc2ff3653530bff1848a515c8c5"
      );
      this.strategyRegistry
        .connect(this.admin)
        .addStrategy(this.aaveYield.address);
    });

    it("Deposit To", async () => {
      await this.savingsAccount
        .connect(this.user)
        .depositTo(
          depositValueToTest,
          zeroAddress,
          this.aaveYield.address,
          this.accountToDeposit.address,
          { value: depositValueToTest }
        );

      let result = await this.savingsAccount.userLockedBalance(
        this.accountToDeposit.address,
        zeroAddress,
        this.aaveYield.address
      );
      sharesReceivedWithAave = result;
      console.log({ sharesReceivedWithAave });
      expect(result).to.not.equals(0);
    });

    it("Withdraw ETH: shares (after evm_increaseTime anv evm_mine 1000 blocks)", async () => {
      let balanceBeforeWithdraw = await network.provider.request({
        method: "eth_getBalance",
        params: [AaveWithdrawAccount],
      });

      await network.provider.request({
        method: "evm_increaseTime",
        params: [8640000000],
      });

      for (let index = 0; index < 10000; index++) {
        await network.provider.request({
          method: "evm_mine",
          params: [],
        });
      }

      await this.savingsAccount
        .connect(this.accountToDeposit)
        .withdraw(
          AaveWithdrawAccount,
          sharesReceivedWithAave,
          zeroAddress,
          this.aaveYield.address,
          false
        );
      let balanceAfterWithdraw = await network.provider.request({
        method: "eth_getBalance",
        params: [AaveWithdrawAccount],
      });

      let amountReceived =
        parseInt(balanceAfterWithdraw) - parseInt(balanceBeforeWithdraw);
      console.log({ amountReceived });
      expect(amountReceived).gt(
        depositValueToTest,
        "AaveYield does't return amount more than deposited"
      );
    });

    it.skip("Withdraw ETH: asset", async () => {
      await this.savingsAccount
        .connect(this.accountToDeposit)
        .withdraw(
          this.accountToDeposit.address,
          depositValueToTest,
          zeroAddress,
          this.aaveYield.address,
          true
        );
    });
  });

  describe("Yearn Strategy", async () => {
    let sharesReceivedWithYearn;
    it("Init Yearn Strategy", async () => {
      this.yearnYield.initialize(
        this.admin.address,
        this.savingsAccount.address
      );
      this.strategyRegistry
        .connect(this.admin)
        .addStrategy(this.yearnYield.address);
      this.yearnYield
        .connect(this.admin)
        .updateProtocolAddresses(zeroAddress, ETH_Yearn_Protocol_Address);
    });

    it("Deposit To", async () => {
      await this.savingsAccount
        .connect(this.user)
        .depositTo(
          depositValueToTest,
          zeroAddress,
          this.yearnYield.address,
          this.accountToDeposit.address,
          { value: depositValueToTest }
        );

      let result = await this.savingsAccount.userLockedBalance(
        this.accountToDeposit.address,
        zeroAddress,
        this.yearnYield.address
      );
      sharesReceivedWithYearn = result;
      console.log({ sharesReceivedWithYearn });
      expect(result).to.not.equals(0);
    });

    it("Withdraw ETH: shares (after evm_increaseTime anv evm_mine 1000 blocks)", async () => {
      let balanceBeforeWithdraw = await network.provider.request({
        method: "eth_getBalance",
        params: [YearnWithdrawAccount],
      });

      await network.provider.request({
        method: "evm_increaseTime",
        params: [8640000000000],
      });

      for (let index = 0; index < 10000; index++) {
        await network.provider.request({
          method: "evm_mine",
          params: [],
        });
      }
      await this.savingsAccount
        .connect(this.accountToDeposit)
        .withdraw(
          YearnWithdrawAccount,
          sharesReceivedWithYearn,
          zeroAddress,
          this.yearnYield.address,
          false
        );

      let balanceAfterWithdraw = await network.provider.request({
        method: "eth_getBalance",
        params: [YearnWithdrawAccount],
      });

      let amountReceived =
        parseInt(balanceAfterWithdraw) - parseInt(balanceBeforeWithdraw);

      console.log({ amountReceived });

      expect(parseInt(amountReceived)).gt(
        depositValueToTest,
        "Amount should be more than depositValueToTest, after withdrawing"
      );
    });
  });

  describe("Compound Strategy", async () => {
    let sharesReceivedWithCompound;
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
          depositValueToTest,
          zeroAddress,
          this.compoundYield.address,
          this.accountToDeposit.address,
          { value: depositValueToTest }
        );

      let result = await this.savingsAccount.userLockedBalance(
        this.accountToDeposit.address,
        zeroAddress,
        this.compoundYield.address
      );
      sharesReceivedWithCompound = result;
      console.log({ sharesReceivedWithCompound });
      expect(result).to.not.equals(0);
    });

    it("Withdraw ETH: shares (after evm_increaseTime anv evm_mine 1000 blocks)", async () => {
      let balanceBeforeWithdraw = await network.provider.request({
        method: "eth_getBalance",
        params: [CompoundWithdrawAccount],
      });

      await network.provider.request({
        method: "evm_increaseTime",
        params: [8640000000000],
      });

      for (let index = 0; index < 10000; index++) {
        await network.provider.request({
          method: "evm_mine",
          params: [],
        });
      }
      await this.savingsAccount
        .connect(this.accountToDeposit)
        .withdraw(
          CompoundWithdrawAccount,
          1,
          zeroAddress,
          this.compoundYield.address,
          false
        );

      let balanceAfterWithdraw = await network.provider.request({
        method: "eth_getBalance",
        params: [CompoundWithdrawAccount],
      });

      let amountReceived =
        parseInt(balanceAfterWithdraw) - parseInt(balanceBeforeWithdraw);

      console.log({ amountReceived });

      expect(parseInt(amountReceived)).gt(
        depositValueToTest,
        "Amount should be more than depositValueToTest, after withdrawing"
      );
    });
  });
});
