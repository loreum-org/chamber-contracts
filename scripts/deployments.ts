import { ethers } from "ethers";

export const localhost = {
  erc721: {
    address: "0x5FbDB2315678afecb367f032d93F642f64180aa3",
    name: "Blackholes",
    symbol: "HOLES",
    tokenUri: "ipfs://QmdmSzXAHnQW2ufFp9eApwb1HQQkrZAAnZqtzfb9bbXVqn/",
    mintCost: ethers.BigNumber.from("10").pow(16).mul(5),
    royaltyFraction: 500,
    maxSupply: 100,
    maxMint: 100,
    adminAddress: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
  },
  erc20: {
    address: "0xe7f1725e7734ce288f8367e1bb143e90bb3f0512",
    premintReceiver: "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266",
    premintAmount: ethers.BigNumber.from("10").pow(17),
    _maxSupply: ethers.BigNumber.from("10").pow(18),
  },
  chamber: {
    quorum: 3,
    leaders: 5,
  }
};

export const goerli = {
  //LoreumNFT: "0x2b1f4f3ddc5689967Efa315d28ACb9da7582A3B7",
  LoreumNFT: "0x854D64C2c2595B92A2A4FaB4a6e96625CcEAd89B",
  name: "Blackholes",
  symbol: "HOLES",
  tokenUri: "ipfs://QmdmSzXAHnQW2ufFp9eApwb1HQQkrZAAnZqtzfb9bbXVqn/",
  mintCost: ethers.BigNumber.from("10").pow(16).mul(5),
  royaltyFraction: 500,
  maxSupply: 100,
  maxMint: 100,
  adminAddress: "0xA9bF0E34859870cF14102dC6894a7B2AC3ceDf83", // EOA
};

export const mainnet = {
  LoreumNFT: "0xB99DEdbDe082B8Be86f06449f2fC7b9FED044E15",
  name: "Loreum Explorers",
  symbol: "LOREUM",
  tokenUri: "ipfs://QmcTBMUiaDQTCt3KT3JLadwKMcBGKTYtiuhopTUafo1h9L/",
  mintCost: ethers.BigNumber.from("10").pow(16).mul(5), // 0.05 ether
  royaltyFraction: 500,
  maxSupply: 10000,
  maxMint: 100,
  adminAddress: "0x5d45A213B2B6259F0b3c116a8907B56AB5E22095",
};
