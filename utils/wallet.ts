import { ethers } from "ethers";
import { Provider } from "@ethersproject/providers";

// Dont use 0x prefix in private key
const temp = [
  "6029243356ca0bbc9a9af7daa15ea9c3cb2e113157d3fe7b70047bdf2d69bdb3",
  "9178dc78ec190be46f91b8f01da07e3384e38850189bfd5768b47da7be1951d9",
  "6f59567a7059244b595bcce9646cd6c7bef949500f42aa1da6d898a9b4f31f10",
  "49cc55af035baf53c862cfe1520b438fe9a351d5f5aa7c3cc442953c2303ab1b",
  "3e8077859a437acf4066c399c0b5f371acf787875717f5c129dc4026bd1d3fc0",
  "10ebf2c84b3dab19ac4827fcc509b12342db133395b10face100c33a71a8419a",
  "4f511a888839c9707a0faa9853bc4f9e45988ea0910df536621dc39aecc01044",
  "67070b6f610d268d6a66126a6fd77566f5a46cf5d77818b7cec96092343a2d07",
  "4a69cdf060bc2ddaf3678decd61deacd59c8282c0476a194767ea8167cda07a7",
  "6a538e44cca04d67a6cdc58f655999be4822a39cc5a3c7f83e9314502734e16e",
  "e1999ff19390a6179fe204dd3bfbcadfa5cfb8a7e3aa430c1ae1ae62fc8c93b6",
  "1c1427ceed51224be2f97d7a4e025d9bbbdcd6c7a905e8f036875657495f57f1",
  "44ab8be4e17f61f922aa07211fa9aa55760b26378d5274641ffe0a235e0331db",
  "d28915cc7336c1e55da36aab1a2f0d878b03749f8e168c2dad62299ef8e1e2f0",
];

const privateKeys = temp.map((key) => `0x${key}`);

export { privateKeys };

export function generatedWallets(provider: Provider) {
  return privateKeys.map((key: string) => {
    return new ethers.Wallet(key, provider);
  });
}
