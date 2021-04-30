const { ethers, network } = require("hardhat");
const { expect } = require("chai");

const BigNumber = ethers.BigNumber;
const {
  Contracts: { cBAT, DAI, LINK, BAT },
} = require("../../existingContracts/compound.json");

const ICToken = require("../../build/contracts/mocks/Token.sol/Token.json");
// console.log({ICToken: ICToken.abi});

const ETH_Yearn_Protocol_Address = "0xe1237aa7f535b0cc33fd973d66cbf830354d16c7";
const DAI_Yearn_Protocol_Address = "0xacd43e627e64355f1861cec6d3a6688b31a6f952";

const AaveWithdrawAccount = "0x11111111deadbeefdeadbeefdeadbeefdeadbeef";
const YearnWithdrawAccount = "0x22222222deadbeefdeadbeefdeadbeefdeadbeef";
const CompoundWithdrawAccount = "0x33333333deadbeefdeadbeefdeadbeefdeadbeef";

const zeroAddress = "0x0000000000000000000000000000000000000000";
const depositValueToTest = BigNumber.from("1000000000000000000"); //10^18 Tokens
const Binance7 = "0xbe0eb53f46cd790cd13851d5eff43d12404d33e8";

describe("Test Savings Account: Asset (ERC20 Token)", () => {
  before(async () => {
    [
      this.deployer,
      this.admin,
      this.proxyAdmin,
      this.user,
      this.mockCreditLineAddress,
      this.accountToDeposit,
      this.mockAccount1,
    ] = await ethers.getSigners();

    const SavingsAccount = await ethers.getContractFactory("SavingsAccount");
    this.savingsAccount = await SavingsAccount.connect(
      this.proxyAdmin
    ).deploy();

    this.BAT = new ethers.Contract(BAT, ICToken.abi);
    this.cBAT = new ethers.Contract(cBAT, ICToken.abi);
    this.DAI = new ethers.Contract(DAI, ICToken.abi);
    this.LINK = new ethers.Contract(LINK, ICToken.abi);

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

  describe("No Strategy", async () => {
    let NoStrategySharesReceived;
    it("Populate address with BAT Tokens", async () => {
      await this.BAT.connect(this.Binance7).transfer(
        this.user.address,
        depositValueToTest
      );
    });

    it("Deposit To (BAT Tokens)", async () => {
      await this.savingsAccount
        .connect(this.user)
        .depositTo(
          depositValueToTest,
          BAT,
          zeroAddress,
          this.accountToDeposit.address
        );

      let result = await this.savingsAccount.userLockedBalance(
        this.accountToDeposit.address,
        BAT,
        zeroAddress
      );
      NoStrategySharesReceived = result;
      console.log({ NoStrategySharesReceived });
      expect(result).equal(depositValueToTest);
    });

    it("Withdraw (BAT Tokens)", async () => {
      let lockedBalanceBeforeWithdraw = await this.savingsAccount.userLockedBalance(
        this.accountToDeposit.address,
        BAT,
        zeroAddress
      );
      console.log({ lockedBalanceBeforeWithdraw });
      let savingsAccountBalance = await this.BAT.connect(
        this.mockAccount1
      ).balanceOf(this.savingsAccount.address);

      console.log({ savingsAccountBalance });

      await this.savingsAccount
        .connect(this.accountToDeposit)
        .withdraw(
          this.accountToDeposit.address,
          NoStrategySharesReceived,
          BAT,
          zeroAddress,
          false
        );

      let balanceAfterWithdraw = await this.BAT.connect(
        this.mockAccount1
      ).balanceOf(this.accountToDeposit.address);
      expect(lockedBalanceBeforeWithdraw.sub(balanceAfterWithdraw)).equal(
        depositValueToTest
      );
    });
  });

  describe("Aave Strategy", async () => {
    let sharesReceivedWithAave;

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

    it("Approve savings account before deposit", async () => {
      // await this.LINK.connect(this.user).approve(this.savingsAccount.address, depositValueToTest);
      await this.LINK.connect(this.user).approve(
        this.aaveYield.address,
        depositValueToTest
      );
    });

    it("Deposit To", async () => {
      await this.savingsAccount
        .connect(this.user)
        .depositTo(
          depositValueToTest,
          LINK,
          this.aaveYield.address,
          this.accountToDeposit.address
        );

      let result = await this.savingsAccount.userLockedBalance(
        this.accountToDeposit.address,
        LINK,
        this.aaveYield.address
      );
      sharesReceivedWithAave = result;
      console.log({ sharesReceivedWithAave });
      expect(result).to.not.equals(0);
    });

    it("Withdraw Tokens (LINK)", async () => {
      let balanceBeforeWithdraw = await this.savingsAccount.userLockedBalance(
        this.accountToDeposit.address,
        BAT,
        this.aaveYield.address
      );

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
          AaveWithdrawAccount,
          sharesReceivedWithAave,
          LINK,
          this.aaveYield.address,
          false
        );

      let balanceAfterWithdraw = await this.LINK.connect(
        this.mockAccount1
      ).balanceOf(AaveWithdrawAccount);

      let amountReceived = BigNumber.from(balanceAfterWithdraw).sub(
        balanceBeforeWithdraw
      );
      expect(amountReceived).gt(depositValueToTest);
    });
  });

  describe("Compound Strategy", async () => {
    let sharesReceivedWithCompound;

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

      await this.compoundYield
        .connect(this.admin)
        .updateProtocolAddresses(BAT, cBAT);
    });

    it("Approve savings account before deposit", async () => {
      // await this.BAT.connect(this.user).approve(this.savingsAccount.address, depositValueToTest);
      await this.BAT.connect(this.user).approve(
        this.compoundYield.address,
        depositValueToTest
      );
    });

    it("Deposit To", async () => {
      await this.savingsAccount
        .connect(this.user)
        .depositTo(
          depositValueToTest,
          BAT,
          this.compoundYield.address,
          this.accountToDeposit.address
        );

      let result = await this.savingsAccount.userLockedBalance(
        this.accountToDeposit.address,
        BAT,
        this.compoundYield.address
      );
      sharesReceivedWithCompound = result;
      console.log({ sharesReceivedWithCompound });
      expect(result).to.not.equals(0);
    });

    it("Withdraw Tokens (BAT)", async () => {
      let balanceBeforeWithdraw = await this.savingsAccount.userLockedBalance(
        this.accountToDeposit.address,
        BAT,
        this.compoundYield.address
      );

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
          sharesReceivedWithCompound,
          BAT,
          this.compoundYield.address,
          false
        );

      let balanceAfterWithdraw = await this.BAT.connect(
        this.mockAccount1
      ).balanceOf(CompoundWithdrawAccount);

      let amountReceived = BigNumber.from(balanceAfterWithdraw).sub(
        balanceBeforeWithdraw
      );
      expect(amountReceived).gt(depositValueToTest);
    });
  });

  describe("Yearn Strategy", async () => {
    let sharesReceivedWithYearn;

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

      this.yearnYield
        .connect(this.admin)
        .updateProtocolAddresses(this.DAI.address, DAI_Yearn_Protocol_Address);
    });

    it("Approve savings account before deposit", async () => {
      // await this.BAT.connect(this.user).approve(this.savingsAccount.address, depositValueToTest);
      await this.DAI.connect(this.user).approve(
        this.yearnYield.address,
        depositValueToTest
      );
    });

    it("Deposit To", async () => {
      await this.savingsAccount
        .connect(this.user)
        .depositTo(
          depositValueToTest,
          DAI,
          this.yearnYield.address,
          this.accountToDeposit.address
        );

      let result = await this.savingsAccount.userLockedBalance(
        this.accountToDeposit.address,
        DAI,
        this.yearnYield.address
      );
      sharesReceivedWithYearn = result;
      console.log({ sharesReceivedWithYearn });
      expect(result).to.not.equals(0);
    });

    it("Withdraw Tokens (DAI)", async () => {
      let balanceBeforeWithdraw = await this.savingsAccount.userLockedBalance(
        this.accountToDeposit.address,
        DAI,
        this.yearnYield.address
      );

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
          this.accountToDeposit.address,
          sharesReceivedWithYearn,
          DAI,
          this.yearnYield.address,
          false
        );

      let balanceAfterWithdraw = await this.DAI.connect(
        this.mockAccount1
      ).balanceOf(this.accountToDeposit.address);

      let amountReceived = BigNumber.from(balanceAfterWithdraw).sub(
        balanceBeforeWithdraw
      );
      expect(amountReceived).gt(depositValueToTest);
    });
  });
});
