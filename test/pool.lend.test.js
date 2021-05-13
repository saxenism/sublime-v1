const { ethers, network } = require("hardhat");
const chai = require("chai");
const { solidity } = require("ethereum-waffle");

chai.use(solidity);
const { expect } = chai;
const Deploy = require("./deploy.helper");

const { encodeUserData } = require("./utils/utils");
const { getPoolAddress } = require("./utils/getAddress");
const timeTravel = require("./utils/time");
let config = require("../config/config.json");

const { getCreate2Address } = require("@ethersproject/address");
const { parseEther } = require("@ethersproject/units");
config = config["ganache"];

const poolCompiled = require("../build/contracts/Pool/Pool.sol/Pool.json");
const poolTokenCompiled = require("../build/contracts/Pool/PoolToken.sol/PoolToken.json");
const CompoundWithdrawAccount = "0x33333333deadbeefdeadbeefdeadbeefdeadbeef";

describe.only("Pool", () => {
  before(async () => {
    const accounts = await ethers.getSigners();
    [
      this.proxyAdmin,
      this.admin,
      this.deployer,
      this.verifier,
      this.borrower,
      this.lender,
      this.address1,
      this.address2,
      this.accountToDeposit,
      this.mockCreditLineAddress,
    ] = accounts;
    this.salt = encodeUserData(config.OpenBorrowPool.salt);

    this.deploy = new Deploy(this.admin, this.deployer, this.verifier);
    const contracts = await this.deploy.init();
    this.contracts = contracts;
    this.poolFactory = await contracts["poolFactory"].connect(this.admin);
    this.token = await contracts["token"].connect(this.admin);

    await this.deploy.verifyBorrower(
      this.borrower.address,
      encodeUserData("borrower")
    );
  });
    describe("when borrowAmount is ERC20", async () => {
      before(async () => {
        const { pool, poolToken } = await this.deploy.deployPool(
          this.poolFactory,
          this.borrower,
          this.token.address,
          ethers.constants.AddressZero
        );

        this.pool = new ethers.Contract(pool, poolCompiled.abi, this.borrower);

        await this.token
          .connect(this.admin)
          .mint(this.lender.address, parseEther("10"));

        this.poolToken = await new ethers.Contract(
          poolToken,
          poolTokenCompiled.abi,
          this.admin
        );
      });
      it("ERC20 lend without overflow", async () => {
        const amountLent = parseEther("0.01");
        await this.token
          .connect(this.lender)
          .approve(this.pool.address, amountLent);

        await this.pool
          .connect(this.lender)
          .lend(this.lender.address, amountLent, false);

        expect(await this.poolToken.balanceOf(this.lender.address)).to.equal(
          amountLent
        );
      });

      it("ERC20 lend with overflow", async () => {
        const amountLent = parseEther("0.04");
        await this.token
          .connect(this.admin)
          .mint(this.address1.address, parseEther("10"));

        await this.token
          .connect(this.address1)
          .approve(this.pool.address, amountLent);

        let iBalance = await this.token.balanceOf(this.address1.address);
        await this.pool
          .connect(this.address1)
          .lend(this.address1.address, amountLent, false);

        let fBalance = await this.token.balanceOf(this.address1.address);

        expect(await this.poolToken.balanceOf(this.address1.address)).to.equal(
          iBalance.sub(fBalance)
        );
      });
    });

    describe("when borrowAmount is Ethereum", async () => {
      before(async () => {
        const { pool, poolToken } = await this.deploy.deployPool(
          this.poolFactory,
          this.borrower,
          ethers.constants.AddressZero,
          ethers.constants.AddressZero
        );

        this.pool = new ethers.Contract(pool, poolCompiled.abi, this.borrower);

        this.poolToken = await new ethers.Contract(
          poolToken,
          poolTokenCompiled.abi,
          this.admin
        );
      });
      it("ETC lend without overflow", async () => {
        const amountLent = parseEther("0.0001");
        const transaction = {
          value: amountLent,
        };
        await this.pool
          .connect(this.lender)
          .lend(this.lender.address, amountLent, false, transaction);

        expect(await this.poolToken.balanceOf(this.lender.address)).to.equal(
          amountLent
        );
      });
      it("ETC lend with overflow", async () => {
        const amountLent = parseEther("0.2");
        const transaction = {
          value: amountLent,
        };
        let iBalance = await this.address1.getBalance();
        await this.pool
          .connect(this.address1)
          .lend(this.address1.address, amountLent, false, transaction);

        let fBalance = await this.address1.getBalance();
        expect(await this.poolToken.balanceOf(this.address1.address)).to.equal(
          iBalance.sub(fBalance)
        );
      });
    });
    describe("when pool tokens are transferred", async () => {
      before(async () => {
        const { pool, poolToken } = await this.deploy.deployPool(
          this.poolFactory,
          this.borrower,
          ethers.constants.AddressZero,
          ethers.constants.AddressZero
        );

        this.pool = new ethers.Contract(pool, poolCompiled.abi, this.borrower);

        this.poolToken = await new ethers.Contract(
          poolToken,
          poolTokenCompiled.abi,
          this.admin
        );
        const amountLent = parseEther("0.0001");
        const transaction = {
          value: amountLent,
        };
        await this.pool
          .connect(this.lender)
          .lend(this.lender.address, amountLent, false, transaction);

        expect(await this.poolToken.balanceOf(this.lender.address)).to.equal(
          amountLent
        );
      });
      it("transferring pool tokens", async () => {
        let iBalance = await this.address1.getBalance();
        await this.poolToken
          .connect(this.lender)
          .transfer(this.address1.address, parseEther("0.00001"));
        let fBalance = await this.address1.getBalance();
        expect(await this.poolToken.balanceOf(this.address1.address)).to.equal(
          fBalance.sub(iBalance)
        );
      });
    });
    describe("lend using savings account", async () => {
      before(async () => {
        const { pool, poolToken } = await this.deploy.deployPool(
          this.poolFactory,
          this.borrower,
          ethers.constants.AddressZero,
          ethers.constants.AddressZero
        );
        this.pool = new ethers.Contract(pool, poolCompiled.abi, this.borrower);

        this.poolToken = await new ethers.Contract(
          poolToken,
          poolTokenCompiled.abi,
          this.admin
        );
       
        const depositValueToTest = parseEther("1");
        await this.deploy.savingsAccount
          .connect(this.lender)
          .depositTo(
            depositValueToTest,
            ethers.constants.AddressZero,
            ethers.constants.AddressZero,
            this.lender.address,
            { value: depositValueToTest }
          );

        await this.deploy.savingsAccount
          .connect(this.lender)
          .approve(
            ethers.constants.AddressZero,
            this.pool.address,
            parseEther("0.01")
          );
      });
      it("should lend using Saving Account", async () => {
        const amountLent = parseEther("0.001");
        let initialBalance = await this.deploy.savingsAccount.userLockedBalance(
          this.lender.address,
          ethers.constants.AddressZero,
          ethers.constants.AddressZero
        );
        await this.pool
          .connect(this.lender)
          .lend(this.lender.address, amountLent, true,{
              value:amountLent
        });
        let finalBalance = await this.deploy.savingsAccount.userLockedBalance(
          this.lender.address,
          ethers.constants.AddressZero,
          ethers.constants.AddressZero
        );
        expect(initialBalance.sub(finalBalance)).to.equal(amountLent);
      });
    });

    describe("when lender withdraw liquidity", async () => {
      before(async () => {
        const { pool, poolToken } = await this.deploy.deployPool(
          this.poolFactory,
          this.borrower,
          ethers.constants.AddressZero,
          ethers.constants.AddressZero
        );

        this.pool = new ethers.Contract(pool, poolCompiled.abi, this.borrower);

        this.poolToken = await new ethers.Contract(
          poolToken,
          poolTokenCompiled.abi,
          this.admin
        );
        const amountLent = parseEther("0.0001");
        const transaction = {
          value: amountLent,
        };
        await this.pool
          .connect(this.lender)
          .lend(this.lender.address, amountLent, false, transaction);

        await this.pool.connect(this.borrower).cancelOpenBorrowPool();
      });
      it("lender withdraw lent liquidity", async () => {
        // This test is failing because the pool transfers get paused when the pool is cancelled.
        let iBalance = await this.lender.getBalance();
        await this.pool
          .connect(this.lender)
          .withdrawLiquidity();
        let fBalance = await this.lender.getBalance();
        expect(amountLent).to.equal(
          fBalance.sub(iBalance)
        );
      });
    });
    describe("when tokens are lent on behalf of other user.", async () => {
      before(async () => {
        const { pool, poolToken } = await this.deploy.deployPool(
          this.poolFactory,
          this.borrower,
          ethers.constants.AddressZero,
          ethers.constants.AddressZero
        );

        this.pool = new ethers.Contract(pool, poolCompiled.abi, this.borrower);
        await this.token
          .connect(this.admin)
          .mint(this.lender.address, parseEther("10"));

        this.poolToken = await new ethers.Contract(
          poolToken,
          poolTokenCompiled.abi,
          this.admin
        );
      });
      it("ETC on behalf of other user.", async () => {
        const amountLent = parseEther("0.2");
        const transaction = {
          value: amountLent,
        };
        let iBalance = await this.lender.getBalance();
        await this.pool
          .connect(this.lender)
          .lend(this.address1.address, amountLent, false, transaction);

        let fBalance = await this.lender.getBalance();
        expect(await this.poolToken.balanceOf(this.address1.address)).to.equal(
          iBalance.sub(fBalance)
        );
      });
    });
  describe("when borrowAmount is lent after the loan has started.", async () => {
    before(async () => {
      const { pool, poolToken } = await this.deploy.deployPool(
        this.poolFactory,
        this.borrower,
        this.token.address,
        ethers.constants.AddressZero
      );

      this.pool = new ethers.Contract(pool, poolCompiled.abi, this.borrower);

      await this.token
        .connect(this.admin)
        .mint(this.lender.address, parseEther("10"));

      this.poolToken = await new ethers.Contract(
        poolToken,
        poolTokenCompiled.abi,
        this.admin
      );
    });
    it("Revert test", async () => {
      const amountLent = parseEther("0.01");
      await this.token
        .connect(this.lender)
        .approve(this.pool.address, amountLent);
      timeTravel(network, config.pool.collectionPeriod + 100);
      await expect(
        this.pool
          .connect(this.lender)
          .lend(this.lender.address, amountLent, false)
      ).to.be.revertedWith(
        "VM Exception while processing transaction: revert 16"
      );
    });
  });
  describe("Cancelling the pool.", async () => {
    before(async () => {
      const { pool, poolToken } = await this.deploy.deployPool(
        this.poolFactory,
        this.borrower,
        this.token.address,
        ethers.constants.AddressZero
      );

      this.pool = new ethers.Contract(pool, poolCompiled.abi, this.borrower);
      await this.token
        .connect(this.admin)
        .mint(this.lender.address, parseEther("10"));

      this.poolToken = await new ethers.Contract(
        poolToken,
        poolTokenCompiled.abi,
        this.admin
      );
    });
    it("is cancelOpenBorrowPool working", async () => {
      let iBalance = await this.deploy.savingsAccount.userLockedBalance(
        this.borrower.address,
				ethers.constants.AddressZero,
        config.OpenBorrowPool.investedTo,
      );
      transaction = this.pool.connect(this.borrower).cancelOpenBorrowPool();
			await expect(transaction)
			.to.emit(this.pool, 'CollateralWithdrawn')
			.withArgs(this.borrower.address, config.OpenBorrowPool.collateralAmount)
			await expect(transaction)
			.to.emit(this.deploy.savingsAccount, 'Transfer')
			.withArgs(ethers.constants.AddressZero, config.OpenBorrowPool.investedTo, this.pool.address, this.borrower.address, config.OpenBorrowPool.collateralAmount)
      let fBalance = await this.deploy.savingsAccount.userLockedBalance(
        this.borrower.address,
        ethers.constants.AddressZero,
        config.OpenBorrowPool.investedTo,
      );
      expect(config.OpenBorrowPool.collateralAmount).to.equal(
				fBalance.sub(iBalance)
      	      )
    });
  });
});
