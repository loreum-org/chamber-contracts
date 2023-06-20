import { BigNumber } from "ethers";
import { ethers } from "hardhat";
import * as deployments from "./deployments";

type DeploymentParams = {
  LoreumNFT: string;
  name: string;
  symbol: string;
  tokenUri: string;
  mintCost: BigNumber;
  royaltyFraction: number;
  maxSupply: number;
  maxMint: number;
  adminAddress: string;
};

async function main() {
  const network: String = (await ethers.provider.getNetwork()).name;
  console.log("Network:", "\t\t", network);
  switch (network) {
    case "unknown":
      return deploy(deployments["localhost"]);
    case "goerli":
      return deploy(deployments["goerli"]);
    case "homestead":
      return deploy(deployments["mainnet"]);
  }
}

async function deploy({
  name,
  symbol,
  tokenUri,
  mintCost,
  royaltyFraction,
  maxSupply,
  maxMint,
  adminAddress,
}: DeploymentParams) {
  console.log("Name:", "\t\t\t", name);
  console.log("Symbol:", "\t\t", symbol);
  console.log("Token URI:", "\t\t", tokenUri);
  console.log("Mint Cost:", "\t\t", ethers.utils.formatEther(mintCost.toString()), "ether");
  console.log("Royalty Fraction:", "\t", royaltyFraction);
  console.log("Max Supply:", "\t\t", maxSupply);
  console.log("Max Mint per Wallet:", "\t", maxMint);
  console.log("Admin Address", "\t\t", adminAddress);

  const LoreumNFT = await ethers.getContractFactory("LoreumNFT");
  const NFT = await LoreumNFT.deploy(
    name,
    symbol,
    tokenUri,
    mintCost,
    royaltyFraction,
    maxSupply,
    maxMint,
    adminAddress
  );

  await NFT.deployed();
  console.log("NFT Contract:", "\t\t", NFT.address);
}

main()
  .then(() => process.exit())
  .catch((err) => {
    console.error(err);
    return process.exit();
  });
