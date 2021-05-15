import { Network } from "hardhat/types";

export function getRandomFromArray<T>(items: T[]): T {
  return items[Math.floor(Math.random() * items.length)];
}

export async function incrementChain(
  network: Network,
  blocks: number,
  blockTime: number = 15000
) {
  await network.provider.request({
    method: "evm_increaseTime",
    params: [blocks * blockTime],
  });

  for (let index = 0; index < blocks; index++) {
    await network.provider.request({
      method: "evm_mine",
      params: [],
    });
  }
  return;
}
