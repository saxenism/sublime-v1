import { ethers, network } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber, BigNumberish } from "@ethersproject/bignumber";
import { expect } from "chai";

import {
  aaveYieldParams,
  depositValueToTest,
  ETH_Yearn_Protocol_Address,
  zeroAddress,
} from "../../utils/constants";
import DeployHelper from "../../utils/deploys";
import { SavingsAccount } from "../../typechain/SavingsAccount";
import { StrategyRegistry } from "../../typechain/StrategyRegistry";
import { getRandomFromArray, incrementChain } from "../../utils/helpers";
import { Address } from "hardhat-deploy/dist/types";
import { AaveYield } from "@typechain/AaveYield";
import { YearnYield } from "@typechain/YearnYield";
import { CompoundYield } from "@typechain/CompoundYield";
import { Contracts } from "../../existingContracts/compound.json";

describe("Test Savings Account (with ETH)", async () => {
  var savingsAccount: SavingsAccount;
  var strategyRegistry: StrategyRegistry;

  let mockCreditLinesAddress: SignerWithAddress;
  let proxyAdmin: SignerWithAddress;
  let admin: SignerWithAddress;

  before(async () => {
    [proxyAdmin, admin, mockCreditLinesAddress] = await ethers.getSigners();
    let deployHelper: DeployHelper = new DeployHelper(proxyAdmin);
    savingsAccount = await deployHelper.core.deploySavingsAccount();
    strategyRegistry = await deployHelper.core.deployStrategyRegistry();

    //initialize
    savingsAccount.initialize(
      admin.address,
      strategyRegistry.address,
      mockCreditLinesAddress.address
    );
    strategyRegistry.initialize(admin.address, 10);
  });

  describe("# When NO STRATEGY is preferred", async () => {
    let randomAccount: SignerWithAddress;
    let userAccount: SignerWithAddress;

    beforeEach(async () => {
      randomAccount = getRandomFromArray(await ethers.getSigners());
      userAccount = getRandomFromArray(await ethers.getSigners());

      while ([randomAccount.address].includes(userAccount.address)) {
        userAccount = getRandomFromArray(await ethers.getSigners());
      }
    });

    it("Should successfully deposit into account another account", async () => {
      let balanceLockedBeforeTransaction: BigNumber =
        await savingsAccount.userLockedBalance(
          randomAccount.address,
          zeroAddress,
          zeroAddress
        );
      await savingsAccount
        .connect(userAccount)
        .depositTo(
          depositValueToTest,
          zeroAddress,
          zeroAddress,
          randomAccount.address,
          { value: depositValueToTest }
        );

      let balanceLockedAfterTransaction: BigNumber =
        await savingsAccount.userLockedBalance(
          randomAccount.address,
          zeroAddress,
          zeroAddress
        );

      expect(
        balanceLockedAfterTransaction.sub(balanceLockedBeforeTransaction)
      ).eq(depositValueToTest);
    });

    it("Should successfully deposit into its own accounts", async () => {
      let balanceLockedBeforeTransaction: BigNumber =
        await savingsAccount.userLockedBalance(
          userAccount.address,
          zeroAddress,
          zeroAddress
        );
      await expect(
        savingsAccount
          .connect(userAccount)
          .depositTo(
            depositValueToTest,
            zeroAddress,
            zeroAddress,
            userAccount.address,
            { value: depositValueToTest }
          )
      )
        .to.emit(savingsAccount, "Deposited")
        .withArgs(
          userAccount.address,
          depositValueToTest,
          zeroAddress,
          zeroAddress
        );

      let balanceLockedAfterTransaction: BigNumber =
        await savingsAccount.userLockedBalance(
          userAccount.address,
          zeroAddress,
          zeroAddress
        );

      expect(
        balanceLockedAfterTransaction.sub(balanceLockedBeforeTransaction)
      ).eq(depositValueToTest);
    });

    async function subject(
      to: Address,
      depositValue: BigNumberish,
      ethValue?: BigNumberish
    ): Promise<any> {
      return savingsAccount
        .connect(userAccount)
        .depositTo(depositValue, zeroAddress, zeroAddress, to, {
          value: ethValue,
        });
    }

    describe("Failed cases", async () => {
      it("Should throw error or revert if receiver address is zero_address", async () => {
        await expect(
          subject(zeroAddress, depositValueToTest)
        ).to.be.revertedWith(
          "SavingsAccount::depositTo receiver address should not be zero address"
        );
      });

      it("should throw error or revert if deposit value is 0", async () => {
        await expect(subject(randomAccount.address, 0)).to.be.revertedWith(
          "SavingsAccount::_deposit Amount must be greater than zero"
        );
      });

      it("should throw error or revert if deposit amount and msg.value are different", async () => {
        await expect(
          subject(randomAccount.address, depositValueToTest, 0)
        ).to.be.revertedWith(
          "SavingsAccount::deposit ETH sent must be equal to amount"
        );
      });
    });
  });

  describe("#When YearnYield is the strategy", async () => {
    let randomAccount: SignerWithAddress;
    let userAccount: SignerWithAddress;
    let withdrawAccount: SignerWithAddress;

    let yearnYield: YearnYield;
    let sharesReceivedWithYearn: BigNumberish;

    before(async () => {
      randomAccount = getRandomFromArray(await ethers.getSigners());

      userAccount = getRandomFromArray(await ethers.getSigners());
      while ([randomAccount.address].includes(userAccount.address)) {
        userAccount = getRandomFromArray(await ethers.getSigners());
      }

      withdrawAccount = getRandomFromArray(await ethers.getSigners());
      while (
        [randomAccount.address, userAccount.address].includes(
          withdrawAccount.address
        )
      ) {
        withdrawAccount = getRandomFromArray(await ethers.getSigners());
      }

      let deployHelper: DeployHelper = new DeployHelper(proxyAdmin);
      yearnYield = await deployHelper.core.deployYearnYield();

      await yearnYield.initialize(admin.address, savingsAccount.address);
      await strategyRegistry.connect(admin).addStrategy(yearnYield.address);

      await yearnYield
        .connect(admin)
        .updateProtocolAddresses(zeroAddress, ETH_Yearn_Protocol_Address);
    });

    it("Should deposit into another account", async () => {
      let balanceLockedBeforeTransaction: BigNumber =
        await savingsAccount.userLockedBalance(
          randomAccount.address,
          zeroAddress,
          yearnYield.address
        );
      // gas price put to test
      await expect(
        savingsAccount
          .connect(userAccount)
          .depositTo(
            depositValueToTest,
            zeroAddress,
            yearnYield.address,
            randomAccount.address,
            { value: depositValueToTest, gasPrice: 0 }
          )
      )
        .to.emit(savingsAccount, "Deposited")
        .withArgs(
          randomAccount.address,
          depositValueToTest,
          zeroAddress,
          yearnYield.address
        );

      let balanceLockedAfterTransaction: BigNumber =
        await savingsAccount.userLockedBalance(
          randomAccount.address,
          zeroAddress,
          yearnYield.address
        );

      sharesReceivedWithYearn = balanceLockedAfterTransaction.sub(
        balanceLockedBeforeTransaction
      );
      expect(sharesReceivedWithYearn).lt(depositValueToTest); //@prateek to verify this
    });

    context("Withdraw ETH", async () => {
      it("Withdraw half of shares received to account (withdrawShares = false)", async () => {
        let balanceBeforeWithdraw = await network.provider.request({
          method: "eth_getBalance",
          params: [withdrawAccount.address],
        });

        await incrementChain(network, 12000);
        let sharesToWithdraw = BigNumber.from(sharesReceivedWithYearn).div(2);
        //gas price is put to zero to check amount received
        await expect(
          savingsAccount
            .connect(randomAccount)
            .withdraw(
              withdrawAccount.address,
              sharesToWithdraw,
              zeroAddress,
              yearnYield.address,
              false,
              { gasPrice: 0 }
            )
        )
          .to.emit(savingsAccount, "Withdrawn")
          .withArgs(
            randomAccount.address,
            withdrawAccount.address,
            sharesToWithdraw,
            zeroAddress,
            yearnYield.address
          ); //@prateek: how to precompute the event args

        let balanceAfterWithdraw = await network.provider.request({
          method: "eth_getBalance",
          params: [withdrawAccount.address],
        });

        let amountReceived: BigNumberish = BigNumber.from(
          balanceAfterWithdraw
        ).sub(BigNumber.from(balanceBeforeWithdraw));
        expect(sharesToWithdraw).eq(amountReceived); //@prateek to verify this
      });

      it("Withdraw half of shares received to account (withdrawShares = true)", async () => {
        let balanceBeforeWithdraw = await network.provider.request({
          method: "eth_getBalance",
          params: [withdrawAccount.address],
        });

        await incrementChain(network, 12000);
        let sharesToWithdraw = BigNumber.from(sharesReceivedWithYearn)
          .div(2)
          .sub(1);
        //gas price is put to zero to check amount received
        await expect(
          savingsAccount
            .connect(randomAccount)
            .withdraw(
              withdrawAccount.address,
              sharesToWithdraw,
              zeroAddress,
              yearnYield.address,
              true,
              { gasPrice: 0 }
            )
        )
          .to.emit(savingsAccount, "Withdrawn")
          .withArgs(
            randomAccount.address,
            withdrawAccount.address,
            sharesToWithdraw,
            zeroAddress,
            yearnYield.address
          );

        let balanceAfterWithdraw = await network.provider.request({
          method: "eth_getBalance",
          params: [withdrawAccount.address],
        });

        let amountReceived: BigNumberish = BigNumber.from(
          balanceAfterWithdraw
        ).sub(BigNumber.from(balanceBeforeWithdraw));
        expect(
          sharesToWithdraw.mul(depositValueToTest).div(sharesReceivedWithYearn)
        ).eq(amountReceived);
      });
    });
  });

  describe("#When AaveYield is the strategy", async () => {
    let randomAccount: SignerWithAddress;
    let userAccount: SignerWithAddress;
    let withdrawAccount: SignerWithAddress;

    let aaveYield: AaveYield;
    let sharesReceivedWithAave: BigNumberish;

    before(async () => {
      randomAccount = getRandomFromArray(await ethers.getSigners());

      userAccount = getRandomFromArray(await ethers.getSigners());
      while ([randomAccount.address].includes(userAccount.address)) {
        userAccount = getRandomFromArray(await ethers.getSigners());
      }

      withdrawAccount = getRandomFromArray(await ethers.getSigners());
      while (
        [randomAccount.address, userAccount.address].includes(
          withdrawAccount.address
        )
      ) {
        withdrawAccount = getRandomFromArray(await ethers.getSigners());
      }

      let deployHelper: DeployHelper = new DeployHelper(proxyAdmin);
      aaveYield = await deployHelper.core.deployAaveYield();
      await aaveYield
        .connect(admin)
        .initialize(
          admin.address,
          savingsAccount.address,
          aaveYieldParams._wethGateway,
          aaveYieldParams._protocolDataProvider,
          aaveYieldParams._lendingPoolAddressesProvider
        );

      await strategyRegistry.connect(admin).addStrategy(aaveYield.address);
    });

    it("Should deposit into another account", async () => {
      let balanceLockedBeforeTransaction: BigNumber =
        await savingsAccount.userLockedBalance(
          randomAccount.address,
          zeroAddress,
          aaveYield.address
        );
      await expect(
        savingsAccount
          .connect(userAccount)
          .depositTo(
            depositValueToTest,
            zeroAddress,
            aaveYield.address,
            randomAccount.address,
            { value: depositValueToTest }
          )
      )
        .to.emit(savingsAccount, "Deposited")
        .withArgs(
          randomAccount.address,
          depositValueToTest,
          zeroAddress,
          aaveYield.address
        );

      let balanceLockedAfterTransaction: BigNumber =
        await savingsAccount.userLockedBalance(
          randomAccount.address,
          zeroAddress,
          aaveYield.address
        );

      sharesReceivedWithAave = balanceLockedAfterTransaction.sub(
        balanceLockedBeforeTransaction
      );
      expect(sharesReceivedWithAave).eq(depositValueToTest);
    });

    context("Withdraw ETH", async () => {
      it("Withdraw half of shares received to account (withdrawShares = false)", async () => {
        let balanceBeforeWithdraw = await network.provider.request({
          method: "eth_getBalance",
          params: [withdrawAccount.address],
        });

        await incrementChain(network, 12000);
        let sharesToWithdraw = BigNumber.from(sharesReceivedWithAave).div(2);
        //gas price is put to zero to check amount received
        await expect(
          savingsAccount
            .connect(randomAccount)
            .withdraw(
              withdrawAccount.address,
              sharesToWithdraw,
              zeroAddress,
              aaveYield.address,
              false,
              { gasPrice: 0 }
            )
        )
          .to.emit(savingsAccount, "Withdrawn")
          .withArgs(
            randomAccount.address,
            withdrawAccount.address,
            sharesToWithdraw,
            zeroAddress,
            aaveYield.address
          );

        let balanceAfterWithdraw = await network.provider.request({
          method: "eth_getBalance",
          params: [withdrawAccount.address],
        });

        let amountReceived: BigNumberish = BigNumber.from(
          balanceAfterWithdraw
        ).sub(BigNumber.from(balanceBeforeWithdraw));
        expect(sharesToWithdraw).eq(amountReceived);
      });

      it("Withdraw half of shares received to account (withdrawShares = true)", async () => {
        let balanceBeforeWithdraw = await network.provider.request({
          method: "eth_getBalance",
          params: [withdrawAccount.address],
        });

        await incrementChain(network, 12000);
        let sharesToWithdraw = BigNumber.from(sharesReceivedWithAave).div(2);
        //gas price is put to zero to check amount received
        await expect(
          savingsAccount
            .connect(randomAccount)
            .withdraw(
              withdrawAccount.address,
              sharesToWithdraw,
              zeroAddress,
              aaveYield.address,
              true,
              { gasPrice: 0 }
            )
        )
          .to.emit(savingsAccount, "Withdrawn")
          .withArgs(
            randomAccount.address,
            withdrawAccount.address,
            sharesToWithdraw,
            zeroAddress,
            aaveYield.address
          );

        let balanceAfterWithdraw = await network.provider.request({
          method: "eth_getBalance",
          params: [withdrawAccount.address],
        });

        let amountReceived: BigNumberish = BigNumber.from(
          balanceAfterWithdraw
        ).sub(BigNumber.from(balanceBeforeWithdraw));
        expect(sharesToWithdraw).eq(amountReceived);
      });
    });
  });

  describe("#When CompoundYield is the strategy", async () => {
    let randomAccount: SignerWithAddress;
    let userAccount: SignerWithAddress;
    let withdrawAccount: SignerWithAddress;

    let compoundYield: CompoundYield;
    let sharesReceivedWithCompound: BigNumberish;

    before(async () => {
      randomAccount = getRandomFromArray(await ethers.getSigners());

      userAccount = getRandomFromArray(await ethers.getSigners());
      while ([randomAccount.address].includes(userAccount.address)) {
        userAccount = getRandomFromArray(await ethers.getSigners());
      }

      withdrawAccount = getRandomFromArray(await ethers.getSigners());
      while (
        [randomAccount.address, userAccount.address].includes(
          withdrawAccount.address
        )
      ) {
        withdrawAccount = getRandomFromArray(await ethers.getSigners());
      }

      let deployHelper: DeployHelper = new DeployHelper(proxyAdmin);
      compoundYield = await deployHelper.core.deployCompoundYield();

      await compoundYield.initialize(admin.address, savingsAccount.address);
      await strategyRegistry.connect(admin).addStrategy(compoundYield.address);
      await compoundYield
        .connect(admin)
        .updateProtocolAddresses(zeroAddress, Contracts.cETH);
    });
    it("Should deposit into another account", async () => {
      let balanceLockedBeforeTransaction: BigNumber =
        await savingsAccount.userLockedBalance(
          randomAccount.address,
          zeroAddress,
          compoundYield.address
        );
      await expect(
        savingsAccount
          .connect(userAccount)
          .depositTo(
            depositValueToTest,
            zeroAddress,
            compoundYield.address,
            randomAccount.address,
            { value: depositValueToTest }
          )
      )
        .to.emit(savingsAccount, "Deposited")
        .withArgs(
          randomAccount.address,
          depositValueToTest,
          zeroAddress,
          compoundYield.address
        );

      let balanceLockedAfterTransaction: BigNumber =
        await savingsAccount.userLockedBalance(
          randomAccount.address,
          zeroAddress,
          compoundYield.address
        );

      sharesReceivedWithCompound = balanceLockedAfterTransaction.sub(
        balanceLockedBeforeTransaction
      );
      expect(sharesReceivedWithCompound).eq(depositValueToTest);
    });

    context("Withdraw ETH", async () => {
      it("Withdraw half of shares received to account (withdrawShares = false)", async () => {
        let balanceBeforeWithdraw = await network.provider.request({
          method: "eth_getBalance",
          params: [withdrawAccount.address],
        });

        await incrementChain(network, 12000);
        let sharesToWithdraw = BigNumber.from(sharesReceivedWithCompound).div(
          2
        );
        //gas price is put to zero to check amount received
        await expect(
          savingsAccount
            .connect(randomAccount)
            .withdraw(
              withdrawAccount.address,
              sharesToWithdraw,
              zeroAddress,
              compoundYield.address,
              false,
              { gasPrice: 0 }
            )
        )
          .to.emit(savingsAccount, "Withdrawn")
          .withArgs(
            randomAccount.address,
            withdrawAccount.address,
            sharesToWithdraw,
            zeroAddress,
            compoundYield.address
          );

        let balanceAfterWithdraw = await network.provider.request({
          method: "eth_getBalance",
          params: [withdrawAccount.address],
        });

        let amountReceived: BigNumberish = BigNumber.from(
          balanceAfterWithdraw
        ).sub(BigNumber.from(balanceBeforeWithdraw));
        expect(sharesToWithdraw).eq(amountReceived);
      });

      it("Withdraw half of shares received to account (withdrawShares = true)", async () => {
        let balanceBeforeWithdraw = await network.provider.request({
          method: "eth_getBalance",
          params: [withdrawAccount.address],
        });

        await incrementChain(network, 12000);
        let sharesToWithdraw = BigNumber.from(sharesReceivedWithCompound).div(
          2
        );
        //gas price is put to zero to check amount received
        await expect(
          savingsAccount
            .connect(randomAccount)
            .withdraw(
              withdrawAccount.address,
              sharesToWithdraw,
              zeroAddress,
              compoundYield.address,
              true,
              { gasPrice: 0 }
            )
        )
          .to.emit(savingsAccount, "Withdrawn")
          .withArgs(
            randomAccount.address,
            withdrawAccount.address,
            sharesToWithdraw,
            zeroAddress,
            compoundYield.address
          );

        let balanceAfterWithdraw = await network.provider.request({
          method: "eth_getBalance",
          params: [withdrawAccount.address],
        });

        let amountReceived: BigNumberish = BigNumber.from(
          balanceAfterWithdraw
        ).sub(BigNumber.from(balanceBeforeWithdraw));
        expect(sharesToWithdraw).eq(amountReceived);
      });
    });
  });
});
