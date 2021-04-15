const timeTravel = async (network, seconds) => {
  await network.provider.send('evm_increaseTime', [seconds])
  await network.provider.send('evm_mine')
}

module.exports = timeTravel