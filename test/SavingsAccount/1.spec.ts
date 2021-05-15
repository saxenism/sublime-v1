import { ethers } from "hardhat";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber, BigNumberish } from "@ethersproject/bignumber";
import { expect } from "chai";

import {
  aaveYieldParams,
  depositValueToTest,
  zeroAddress,
} from "../../utils/constants";
import DeployHelper from "../../utils/deploys";
import { SavingsAccount } from "../../typechain/SavingsAccount";
import { StrategyRegistry } from "../../typechain/StrategyRegistry";
import { getRandomFromArray } from "../../utils/helpers";
import { Address } from "hardhat-deploy/dist/types";
import { AaveYield } from "@typechain/AaveYield";
import { ContractTransaction } from "@ethersproject/contracts";

describe("Test Savings Account", async () => {
  var savingsAccount: SavingsAccount;
  var strategyRegistry: StrategyRegistry;

  let mockCreditLinesAddress: SignerWithAddress;
  let proxyAdmin: SignerWithAddress;
  let admin: SignerWithAddress;

  before(async () => {
    [proxyAdmin, admin, mockCreditLinesAddress] = await ethers.getSigners();
  });

  beforeEach(async () => {
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
      await savingsAccount
        .connect(userAccount)
        .depositTo(
          depositValueToTest,
          zeroAddress,
          zeroAddress,
          userAccount.address,
          { value: depositValueToTest }
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

  describe("#When AaveYield is the strategy", async () => {
    let randomAccount: SignerWithAddress;
    let userAccount: SignerWithAddress;

    let aaveYield: AaveYield;

    beforeEach(async () => {
      randomAccount = getRandomFromArray(await ethers.getSigners());
      userAccount = getRandomFromArray(await ethers.getSigners());

      while ([randomAccount.address].includes(userAccount.address)) {
        userAccount = getRandomFromArray(await ethers.getSigners());
      }
    });

    before(async () => {
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
    });

    it("Initialize aaveYield", async () => {
      await expect(
        strategyRegistry.connect(admin).addStrategy(aaveYield.address)
      )
        .to.emit(strategyRegistry, "StrategyAdded")
        .withArgs(aaveYield.address);
    });

    it("Check if aave yield is in strategy registry", async () => {
      expect(await strategyRegistry.connect(admin).getStrategies()).to.include(
        aaveYield.address
      );
    });

    describe("Failed cases", async () => {
      it("Should throw error when same stragegy is added again", async () => {
        await expect(
          strategyRegistry.connect(admin).addStrategy(aaveYield.address)
        ).to.be.revertedWith(
          "StrategyRegistry::addStrategy - Strategy already exists"
        );
      });
    });
  });
});
