const { ethers } = require('hardhat')
const chai = require('chai')
const { solidity } = require('ethereum-waffle')

chai.use(solidity)
const { expect } = chai

const Deploy = require("./deploy.helper")
const { encodeUserData } = require('./utils/utils')

describe('Verification', () => {
  before(async () => {
    ;[
      this.deployer,
      this.admin,
      this.proxyAdmin,
      this.verifier,
      this.borrower1,
      this.borrower2,
    ] = await ethers.getSigners()

    this.deploy = new Deploy(this.admin, this.deployer, this.verifier);

    const contracts = await this.deploy.init()
    this.verification = contracts['verification'].connect(this.verifier)
  })

  describe('registerUser', async () => {
    it('should revert if incorrect offchain details', async () => {
      await expect(
        this.verification.registerUser(
          this.borrower1.address,
          encodeUserData(''),
        ),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Verification: Offchain details should not be empty',
      )
    })

    it('should revert if zero address provided for user', async () => {
      await expect(
        this.verification.registerUser(
          ethers.constants.AddressZero,
          encodeUserData('borrower'),
        ),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Verification: Invalid entity address',
      )
    })

    it('should revert if not called by owner', async () => {
      await expect(
        this.verification
          .connect(this.admin)
          .registerUser(this.borrower1.address, encodeUserData('borrower')),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Ownable: caller is not the owner',
      )
    })

    it('should register user', async () => {
      await expect(
        this.verification.registerUser(
          this.borrower1.address,
          encodeUserData('borrower'),
        ),
      )
        .to.emit(this.verification, 'UserRegistered')
        .withArgs(this.borrower1.address, encodeUserData('borrower'))

      const isUser = await this.verification.isUser(this.borrower1.address)
      expect(isUser).to.equal(true)
    })

    it('should revert if already registered', async () => {
      await expect(
        this.verification.registerUser(
          this.borrower1.address,
          encodeUserData('borrower'),
        ),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Verification: User already registered',
      )
    })
  })

  describe('updateUserDetails', async () => {
    it('should update registered user details', async () => {
      await expect(
        this.verification.updateUserDetails(
          this.borrower1.address,
          encodeUserData('borrower1'),
        ),
      )
        .to.emit(this.verification, 'UserDetailsUpdated')
        .withArgs(this.borrower1.address, encodeUserData('borrower1'))

      const userDetails = await this.verification.registeredUsers(
        this.borrower1.address,
      )
      expect(userDetails).to.equal(encodeUserData('borrower1'))
    })

    it('should revert if incorrect offchain details', async () => {
      await expect(
        this.verification.updateUserDetails(
          this.borrower1.address,
          encodeUserData(''),
        ),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Verification: Offchain details should not be empty',
      )
    })

    it('should revert if user not registered', async () => {
      await expect(
        this.verification.updateUserDetails(
          this.borrower2.address,
          encodeUserData('borrower'),
        ),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Verification: User must be registered',
      )
    })

    it('should revert if not called by owner', async () => {
      await expect(
        this.verification
          .connect(this.admin)
          .updateUserDetails(
            this.borrower1.address,
            encodeUserData('borrower'),
          ),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Ownable: caller is not the owner',
      )
    })
  })

  describe('isUser', async () => {
    it('should return user registration status', async () => {
      let isUser = await this.verification.isUser(this.borrower1.address)
      expect(isUser).to.equal(true)

      isUser = await this.verification.isUser(this.borrower2.address)
      expect(isUser).to.equal(false)
    })
  })

  describe('unregisterUser', async () => {
    it('should revert if user not registered', async () => {
      await expect(
        this.verification.unregisterUser(this.borrower2.address),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Verification: User must be registered',
      )
    })

    it('should revert if not called by owner', async () => {
      await expect(
        this.verification
          .connect(this.admin)
          .unregisterUser(this.borrower1.address),
      ).to.be.revertedWith(
        'VM Exception while processing transaction: revert Ownable: caller is not the owner',
      )
    })

    it('should unregister user', async () => {
      await expect(this.verification.unregisterUser(this.borrower1.address))
        .to.emit(this.verification, 'UserUnregistered')
        .withArgs(this.borrower1.address)

      const userDetails = await this.verification.registeredUsers(
        this.borrower1.address,
      )
      expect(userDetails).to.equal(encodeUserData(''))
    })
  })
})
