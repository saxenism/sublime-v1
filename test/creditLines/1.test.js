const { ethers, network } = require("hardhat");
const { expect } = require("chai");

const BigNumber = ethers.BigNumber;

const ICToken = require("../../build/contracts/Token.json");

const {
  Contracts: { LINK, DAI },
} = require("../../existingContracts/compound.json");

const depositValueToTest = BigNumber.from("1000000000000000000"); //10^18 Tokens

const ETH_Yearn_Protocol_Address = "0xe1237aa7f535b0cc33fd973d66cbf830354d16c7";
const AaveWithdrawAccount = "0x11111111deadbeefdeadbeefdeadbeefdeadbeef";
const Binance7 = "0xbe0eb53f46cd790cd13851d5eff43d12404d33e8";

describe.only("Credit Lines", () => {
  before(async () => {
    [
      this.deployer,
      this.admin,
      this.proxyAdmin,
      this.user,
      this.mockCreditLineAddress,
      this.accountToDeposit,
      this.mockAddress1,
      this.lender,
      this.receiver,
    ] = await ethers.getSigners();

    const CreditLine = await ethers.getContractFactory("CreditLine");
    this.creditLine = await CreditLine.connect(this.proxyAdmin).deploy();

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
      this.creditLine.address
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
    it("Init Credit Line", async () => {
      await this.creditLine
        .connect(this.admin)
        .initialize(this.aaveYield.address);
    });

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

    it("Calculate interest per second", async () => {
      let interest = await this.creditLine
        .connect(this.admin)
        .calculateInterestPerSecond(BigNumber.from("1000000000000000000"), 1);
      expect(interest).gt("0");
    });
  });

  describe("Credit Line core", async () => {
    it("Request Credit Line to Lender", async () => {
      expect(
        this.creditLine
          .connect(this.admin)
          .requestCreditLineToLender(
            this.lender.address,
            BigNumber.from("10000000000000000"),
            BigNumber.from("20000000000000000"),
            BigNumber.from("1000"),
            true,
            BigNumber.from("45"),
            DAI,
            LINK
          )
      ).to.emit("CreditLineRequestedToLender");
    });

    it("Request Credit Line to Borrower", async () => {
      expect(
        this.creditLine
          .connect(this.admin)
          .requestCreditLineToBorrower(
            this.lender.address,
            BigNumber.from("10000000000000000"),
            BigNumber.from("20000000000000000"),
            BigNumber.from("1000"),
            true,
            BigNumber.from("45"),
            DAI,
            LINK
          )
      ).to.emit("CreditLineRequestedToBorrower");
    });

    describe("#Accept Credit Line", async () => {
      it("When send input is lender generated hash", async () => {
        let transaction = await this.creditLine
          .connect(this.admin)
          .requestCreditLineToLender(
            this.lender.address,
            BigNumber.from("10000000000000000"),
            BigNumber.from("20000000000000000"),
            BigNumber.from("1000"),
            true,
            BigNumber.from("45"),
            DAI,
            LINK
          );

        let receipt = await transaction.wait();
        let relevantEvent = receipt.events.filter(
          (item) => item.event === "CreditLineRequestedToLender"
        );
        expect(relevantEvent.length).gt(0);
        let hash = relevantEvent[0].args[0];
        // use this this hash for further tests
        print({ hash });
      });
      it("When send input is borrower generated hash", async () => {
        let transaction = await this.creditLine
          .connect(this.admin)
          .requestCreditLineToBorrower(
            this.lender.address,
            BigNumber.from("10000000000000000"),
            BigNumber.from("20000000000000000"),
            BigNumber.from("1000"),
            true,
            BigNumber.from("45"),
            DAI,
            LINK
          );

        let receipt = await transaction.wait();
        let relevantEvent = receipt.events.filter(
          (item) => item.event === "CreditLineRequestedToBorrower"
        );
        expect(relevantEvent.length).gt(0);
        let hash = relevantEvent[0].args[0];
        // use this this hash for further tests
        print({ hash });
      });
    });
  });
});

function print(data) {
  console.log(JSON.stringify(data, null, 4));
}
